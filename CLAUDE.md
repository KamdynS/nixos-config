# CLAUDE.md

This file provides guidance to Claude Code (claude.ai/code) when working with code in this repository.

## Overview

This is a NixOS flake configuration for a Niri-based Wayland desktop with a custom Quickshell (Caelestia) shell. It supports two hosts: `lg-gram` (Intel laptop with systemd-boot) and `desktop` (AMD workstation with GRUB dual-boot).

## Common Commands

### System Rebuild
```bash
# Rebuild and switch (laptop)
sudo nixos-rebuild switch --flake /home/kamdyns/nixos-config#lg-gram

# Rebuild and switch (desktop)
sudo nixos-rebuild switch --flake /home/kamdyns/nixos-config#desktop

# Test without switching
sudo nixos-rebuild test --flake /home/kamdyns/nixos-config#lg-gram
```

### Home-Manager
```bash
home-manager switch --flake /home/kamdyns/nixos-config#kamdyns
```

### Flake Operations
```bash
nix flake check                                    # Verify configuration syntax
nix flake update --flake /home/kamdyns/nixos-config  # Update inputs
nix build /home/kamdyns/nixos-config#desktop       # Test build
```

### Service Management
```bash
systemctl --user status quickshell
systemctl --user status niri-shell-ipc
journalctl --user -fu quickshell
```

### DBus Testing (niri-shell-ipc)
```bash
busctl --user introspect org.caelestia.Niri /org/caelestia/Niri
busctl --user get-property org.caelestia.Niri /org/caelestia/Niri org.caelestia.Niri Workspaces
busctl --user call org.caelestia.Apps /org/caelestia/Apps org.caelestia.Apps Search s "firefox"
busctl --user monitor org.caelestia.Niri
RUST_LOG=debug niri-shell-ipc  # Run daemon in foreground with debug logs
```

## Architecture

### Entry Points
- `flake.nix` - Defines `nixosConfigurations.lg-gram` and `nixosConfigurations.desktop`
- `hosts/{hostname}/configuration.nix` - Per-host system configuration
- `home/home.nix` - Main home-manager config, imports niri.nix, waybar.nix, wofi.nix, quickshell.nix
- `home/caelestia/shell.qml` - Quickshell entry point

### Custom Daemon: niri-shell-ipc
Located in `packages/niri-shell-ipc/`, this Rust daemon bridges Niri's IPC socket to DBus for the Quickshell UI. It exposes interfaces for:
- `org.caelestia.Niri` - Workspaces, windows, layouts
- `org.caelestia.Apps` - Application search/launch
- `org.caelestia.System` - CPU/memory/disk/temp monitoring
- `org.caelestia.Audio` - PipeWire volume control
- `org.caelestia.Power` - Battery via UPower
- `org.caelestia.Network` - NetworkManager proxy
- `org.caelestia.Bluetooth` - BlueZ proxy
- `org.caelestia.Brightness` - Backlight + DDC/CI
- `org.caelestia.Media` - MPRIS aggregation
- `org.caelestia.Notifications` - freedesktop notifications

See `docs/niri-shell-daemon-spec.md` for complete interface specifications.

### Caelestia Shell (QML)
Located in `home/caelestia/`, this is a Quickshell-based desktop shell forked from caelestia-dots/shell. Components:
- `modules/` - UI components (bar, dashboard, launcher, session menu, OSD, lock screen)
- `services/` - QML singletons for system state (Niri.qml, Colours.qml, Theme.qml)
- `themes/` - Color theme definitions (JSON files, Gruvbox theme)

### Host Differences
| | lg-gram | desktop |
|---|---------|---------|
| CPU | Intel | AMD |
| Boot | systemd-boot | GRUB (dual-boot) |
| Hostname | nixos | desktop |
| I2C/DDC | Enabled | N/A |

### Dependency Flow
```
graphical-session.target
    └── niri-shell-ipc.service (DBus daemon)
            └── quickshell.service (UI shell)
```

## Development Notes

- Wayland-native setup; XWayland available for X11 app compatibility
- Consistent Gruvbox theming across Niri, Waybar, Wofi, Ghostty, and Caelestia
- Theme changes in Niri require rebuild; Quickshell supports hot reload
- Dotfiles (nvim, zsh, lazygit) symlinked from `dotfiles/` directory
- The Caelestia shell has C++ plugin stubs (audio visualization, beat detection) that are placeholder-only
