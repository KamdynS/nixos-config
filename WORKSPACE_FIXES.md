# Workspace Indicator Fixes (2026-02-02)

## Problems Fixed

1. **Active workspace highlight stuck** - QML binding went through `monitorFor()` function which didn't create reactive dependency on `workspaceList`
2. **Wrong sort order** - Was sorting by `id` (global unique ID) instead of `idx` (workspace number)
3. **Wrong display number** - Showed global ID instead of workspace index (mod+N number)
4. **Click handler** - Was passing global ID to `focusWorkspace()` which expects index

## Files Changed

### `home/caelestia/modules/bar/components/workspaces/Workspaces.qml`
- Sort by `idx` instead of `id`
- Rewrote `activeWsId` to directly reference `Niri.workspaceList` for reactivity
- Fixed click handler to use `wsIdx` for focus call

### `home/caelestia/modules/bar/components/workspaces/Workspace.qml`
- Added `wsIdx` property (workspace number for display)
- Changed text to show `wsIdx` instead of `wsId`

## Test Command
```bash
systemctl --user restart quickshell
```

## Debug Commands
```bash
# Check daemon workspace data
busctl --user get-property org.caelestia.Niri /org/caelestia/Niri org.caelestia.Niri Workspaces

# Monitor signals
busctl --user monitor org.caelestia.Niri

# Check quickshell logs
journalctl --user -fu quickshell
```

---

# Global Workspace Numbering (2026-02-02)

## Problem

Niri uses per-output workspace indices by default. Each monitor has its own workspace 1, 2, 3, etc. This means:
- Mod+1 goes to workspace 1 on the *currently focused* monitor
- You can't directly jump from monitor 1 to workspace 3 on monitor 2

## Goal

Global workspace numbering across all monitors:
- Monitor 1 (HDMI-A-1): workspaces 1, 2
- Monitor 2 (DP-3): workspaces 3, 4, 5
- Mod+3 should always go to workspace 3 (on monitor 2), regardless of which monitor is focused
- Bar on each monitor only shows its own workspaces, but displays global numbers

## Solution

### 1. Daemon: New DBus methods (`packages/niri-shell-ipc/src/dbus.rs`)

Added two new methods that work with global indices:

- `FocusWorkspaceByGlobalIndex(u32)` - Focus a workspace by its global index (1-based)
- `MoveWindowToWorkspaceByGlobalIndex(u32)` - Move window to workspace by global index

The global index is calculated by sorting all workspaces by:
1. Output name (alphabetically: DP-3, HDMI-A-1, etc.)
2. Per-output index (1, 2, 3...)

This gives consistent global numbering: first monitor's workspaces come first, then second monitor's, etc.

### 2. Quickshell: Enable per-monitor filtering (`home/caelestia/config/BarConfig.qml`)

Changed `perMonitorWorkspaces: false` to `perMonitorWorkspaces: true`

This makes each monitor's bar only show workspaces belonging to that monitor, while still displaying the global index number.

### 3. Niri keybinds: Use daemon methods (`home/niri.nix`)

Replaced:
```nix
"Mod+1".action.focus-workspace = [ 1 ];
```

With:
```nix
"Mod+1".action.spawn = [ "busctl" "--user" "call" "org.caelestia.Niri" "/org/caelestia/Niri" "org.caelestia.Niri" "FocusWorkspaceByGlobalIndex" "u" "1" ];
```

Same for Mod+Shift+N (move window to workspace).

### 4. QML service methods (`home/caelestia/services/Niri.qml`)

Added QML wrapper functions:
- `focusWorkspaceByGlobalIndex(globalIndex)`
- `moveWindowToWorkspaceByGlobalIndex(globalIndex)`

## Files Changed

| File | Change |
|------|--------|
| `packages/niri-shell-ipc/src/dbus.rs` | Added `FocusWorkspaceByGlobalIndex` and `MoveWindowToWorkspaceByGlobalIndex` methods |
| `home/caelestia/config/BarConfig.qml` | Set `perMonitorWorkspaces: true` |
| `home/niri.nix` | Changed Mod+N keybinds to spawn busctl calls to daemon |
| `home/caelestia/services/Niri.qml` | Added `focusWorkspaceByGlobalIndex()` and `moveWindowToWorkspaceByGlobalIndex()` functions |

## Rebuild Steps

```bash
# 1. Rebuild NixOS (includes daemon and niri config)
sudo nixos-rebuild switch --flake /home/kamdyns/nixos-config#desktop

# 2. Restart services
systemctl --user restart niri-shell-ipc
systemctl --user restart quickshell
```

## Testing

```bash
# Test the new daemon method directly
busctl --user call org.caelestia.Niri /org/caelestia/Niri org.caelestia.Niri FocusWorkspaceByGlobalIndex u 1

# Check workspace data (verify output and idx fields)
busctl --user get-property org.caelestia.Niri /org/caelestia/Niri org.caelestia.Niri Workspaces | jq

# Monitor daemon logs
RUST_LOG=debug niri-shell-ipc
```

## How Global Index Works

Example with 2 monitors:
```
HDMI-A-1 (first alphabetically):
  - workspace id=5, idx=1 -> global index 1
  - workspace id=8, idx=2 -> global index 2

DP-3 (second alphabetically - wait, D comes before H!):
  - workspace id=3, idx=1 -> global index 1
  - workspace id=6, idx=2 -> global index 2
```

Actually, alphabetically: DP-3 < HDMI-A-1, so:
```
DP-3:
  - idx=1 -> global index 1
  - idx=2 -> global index 2

HDMI-A-1:
  - idx=1 -> global index 3
  - idx=2 -> global index 4
```

The exact mapping depends on your output names. Check with:
```bash
busctl --user get-property org.caelestia.Niri /org/caelestia/Niri org.caelestia.Niri Outputs
```
