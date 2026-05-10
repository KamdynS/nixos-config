# CLAUDE.md

This file provides guidance to Claude Code when working with this repository.

## Overview

NixOS flake configuration for a niri-based Wayland desktop. Rice v2 - minimal, fast, themeable.

**Hosts:**
- `desktop` (AMD workstation, GRUB dual-boot) - rice v2, primary development target

## Common Commands

```bash
# Rebuild desktop
sudo nixos-rebuild switch --flake /home/kamdyns/nixos-config#desktop

# Test without switching
sudo nixos-rebuild test --flake /home/kamdyns/nixos-config#desktop

# Update flake inputs
nix flake update

# Check syntax
nix flake check

# Switch theme at runtime
theme-switch gruvbox-light
theme-pick  # fuzzel menu
```

## Architecture

### Entry Points
- `flake.nix` - Defines nixosConfigurations for desktop and lg-gram
- `hosts/desktop/configuration.nix` - System config (AMD GPU, GDM, niri, pipewire)
- `home/desktop.nix` - Home-manager entry for desktop user

### Module Structure
```
home/
  desktop.nix              # Entry point, imports all modules
  modules/
    theming.nix            # Theme system (generates configs, switch scripts)
    niri.nix               # Compositor config
    waybar.nix             # Bar (minimal: clock, workspaces, network)
    fuzzel.nix             # App launcher
    mako.nix               # Notifications
    cliphist.nix           # Clipboard manager
    swww.nix               # Wallpaper daemon
    ghostty.nix            # Terminal
    apps.nix               # Zen Browser, Spotify, Discord
    shell.nix              # zsh + oh-my-zsh + starship
    editor.nix             # neovim + LSPs
themes/
  gruvbox-light.nix        # Default theme
  gruvbox-dark.nix
  catppuccin-mocha.nix
  kanagawa.nix
  rose-pine.nix
  tokyonight.nix
wallpapers/
  (user adds wallpapers here, named to match themes)
dotfiles/
  nvim/                    # Symlinked, edit without rebuild
  lazygit/                 # Symlinked
```

### Theming System

Themes are defined in `themes/*.nix` using `nix-colors` for base16 palettes. At build time, `theming.nix` generates themed config files for each app:
- `~/.config/waybar/themes/<name>.css`
- `~/.config/ghostty/themes/<name>`
- `~/.config/mako/themes/<name>.conf`
- `~/.config/fuzzel/themes/<name>.ini`
- `~/.config/nvim/lua/themes/<name>.lua`
- `~/.config/starship.toml` (all palettes embedded)

At runtime, `theme-switch <name>`:
1. Updates symlinks to point active config at chosen theme
2. Sets wallpaper via swww with transition
3. Reloads services (waybar, mako, ghostty via SIGUSR2)
4. Updates starship palette in config file

### Keybinds (niri)

| Key | Action |
|-----|--------|
| Mod+Return | ghostty |
| Mod+B | Zen Browser |
| Mod+S | Spotify |
| Mod+D | Discord |
| Mod+Space | fuzzel |
| Mod+V | cliphist picker |
| Mod+Shift+S | screenshot region → clipboard |
| Mod+T | theme picker |
| Mod+Shift+/ | show hotkey overlay |
| Mod+Q | close window |
| Mod+R | cycle column widths |
| Mod+1-9 | workspace |
| Mod+H/L | focus column left/right |
| Mod+J/K | focus workspace down/up |
| Mod+Shift+H/L | move column left/right |
| Mod+Shift+J/K | move column to workspace down/up |

### Stack

| Role | Tool |
|------|------|
| Compositor | niri |
| Bar | waybar |
| Launcher | fuzzel |
| Notifications | mako |
| Clipboard | cliphist |
| Wallpaper | swww |
| Terminal | ghostty |
| Shell | zsh + oh-my-zsh + starship |
| Editor | neovim |
| Browser | Zen |

## Notes

- Wallpapers go in `wallpapers/` directory, named `<theme-name>.jpg`
- Theme switching is instant (<1s), no rebuild needed
- Dotfiles (nvim, lazygit) are symlinked - edit without rebuild
- Font: JetBrains Mono Nerd Font everywhere
