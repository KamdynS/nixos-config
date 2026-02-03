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
