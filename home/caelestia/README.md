# Caelestia Shell for Niri

A Quickshell-based desktop shell adapted for the [Niri](https://github.com/YaLTeR/niri) Wayland compositor.

**This is a fork/adaptation of [caelestia-dots/shell](https://github.com/caelestia-dots/shell)** by [@soramane](https://github.com/soramane), originally built for Hyprland. All credit for the beautiful design, animations, and architecture goes to the original project.

## What is this?

This is the Caelestia shell ported to work with Niri instead of Hyprland. It provides:

- Bar with workspaces, system tray, clock, and status icons
- Dashboard drawer with system info, media controls, and quick settings
- Launcher drawer for applications
- Session menu for power options
- OSD (on-screen display) for volume/brightness
- Lock screen
- Notification system
- Theme picker for switching color schemes and wallpapers

## Key Differences from Original

### Compositor
- **Original**: Hyprland (wlroots-based tiling compositor)
- **This fork**: Niri (scrollable tiling compositor)

### IPC Bridge
Since Niri uses a different socket protocol than Hyprland, this fork includes `niri-shell-ipc`, a Rust daemon that bridges the Niri socket to DBus for Quickshell communication.

### Theme System
The original Caelestia uses a wallpaper-first approach where the color scheme is derived from the wallpaper. This fork uses a **theme-first approach**:

1. Define color themes (e.g., Gruvbox Dark, Gruvbox Light)
2. Each theme has associated wallpapers
3. When you select a theme, the colors are applied and you can cycle through that theme's wallpapers

### C++ Plugin Stubs
The original Caelestia has C++ plugins for features like:
- Audio visualization (Cava)
- Beat detection
- Image analysis
- App database

This fork includes QML stubs for these components. Some features (like audio visualization) are placeholder-only until native implementations are added.

## Installation (NixOS)

This shell is designed to be used with NixOS and home-manager.

### Prerequisites

Ensure you have:
- NixOS with Niri configured
- home-manager

### Setup

1. The shell files go in `~/.config/quickshell/` (handled by home-manager)

2. Add to your home-manager configuration:

```nix
{ config, pkgs, ... }:

{
  home.packages = with pkgs; [
    quickshell
    brightnessctl
    playerctl
    ddcutil
    lm_sensors
    swaybg
    material-symbols
    nerd-fonts.jetbrains-mono
  ];

  xdg.configFile."quickshell" = {
    source = ./caelestia;
    recursive = true;
  };

  systemd.user.services.quickshell = {
    Unit = {
      Description = "Caelestia Quickshell";
      After = [ "graphical-session.target" "niri-shell-ipc.service" ];
      PartOf = [ "graphical-session.target" ];
      Requires = [ "niri-shell-ipc.service" ];
    };
    Service = {
      Type = "simple";
      Environment = [
        "QML_IMPORT_PATH=${config.xdg.configHome}/quickshell"
      ];
      ExecStart = "${pkgs.quickshell}/bin/quickshell -p ${config.xdg.configHome}/quickshell/shell.qml";
      Restart = "on-failure";
      RestartSec = 3;
    };
    Install = {
      WantedBy = [ "graphical-session.target" ];
    };
  };
}
```

3. Build the `niri-shell-ipc` daemon and set it up as a systemd service (see packages/niri-shell-ipc)

4. Rebuild your NixOS configuration:
```sh
sudo nixos-rebuild switch
```

## Configuration

### Themes

Themes are defined as JSON files in `themes/`. Each theme specifies:

```json
{
  "id": "gruvbox-dark",
  "name": "Gruvbox Dark",
  "isDark": true,
  "colors": {
    "primary": "#d79921",
    "secondary": "#b8bb26",
    "background": "#282828",
    "onBackground": "#ebdbb2",
    ...
  },
  "wallpapers": [
    "~/Pictures/Wallpapers/gruvbox-1.png",
    "~/Pictures/Wallpapers/gruvbox-2.png"
  ]
}
```

Available themes:
- `gruvbox-dark` - Gruvbox dark color scheme
- `gruvbox-light` - Gruvbox light color scheme

To add your own theme, create a JSON file in `themes/` following the same format.

### Shell Configuration

The shell reads configuration from `~/.config/caelestia/shell.json`. See the original [Caelestia documentation](https://github.com/caelestia-dots/shell#configuring) for configuration options.

## Keybindings

Keybindings are configured in your Niri config (`niri.nix` or `niri.kdl`). Recommended bindings:

| Key | Action |
|-----|--------|
| `Mod+T` | Toggle theme picker |
| `Mod+D` | Toggle launcher |
| `Mod+X` | Toggle session menu |

IPC commands can be called directly:

```sh
# Toggle drawers
qs ipc call drawers toggle launcher
qs ipc call drawers toggle dashboard
qs ipc call drawers toggle session

# Theme picker
qs ipc call themePicker toggle

# List available drawers
qs ipc call drawers list
```

## Architecture

```
shell.qml                 # Main entry point
├── modules/
│   ├── drawers/          # Bar, dashboard, launcher, session, sidebar, osd
│   ├── background/       # Wallpaper and desktop clock
│   ├── lock/             # Lock screen
│   ├── themepicker/      # Theme selection widget
│   └── areapicker/       # Screenshot region picker
├── services/             # Singletons for system state
│   ├── Niri.qml          # Niri IPC (workspaces, windows)
│   ├── Colours.qml       # Color scheme management
│   ├── Theme.qml         # Theme and wallpaper management
│   ├── Visibilities.qml  # Drawer visibility state
│   └── ...
├── components/           # Reusable UI components
├── config/               # Configuration schemas
├── themes/               # Color theme definitions
├── Caelestia/            # Stubs for C++ plugin compatibility
└── stubs/                # Additional compatibility stubs
```

## What Works

- Bar with workspaces, clock, tray, status icons
- Dashboard drawer with system info
- Launcher drawer for applications
- Session menu for power options
- Lock screen
- OSD for volume/brightness
- Theme picker with wallpaper cycling
- Notifications
- All QML animations

## What's Stubbed/Limited

- **Audio visualization**: Cava integration requires C++ plugin
- **Beat detection**: Aubio integration requires C++ plugin
- **Image analysis**: Color extraction from wallpapers requires C++ plugin
- **App database**: Uses system application list instead of custom database

## Credits

This project would not exist without:

- **[caelestia-dots/shell](https://github.com/caelestia-dots/shell)** by [@soramane](https://github.com/soramane) - The original Caelestia shell for Hyprland. This fork is an adaptation of their beautiful work.

- **[Quickshell](https://quickshell.outfoxxed.me)** by [@outfoxxed](https://github.com/outfoxxed) - The QML-based shell framework that makes this possible.

- **[Niri](https://github.com/YaLTeR/niri)** by [@YaLTeR](https://github.com/YaLTeR) - The scrollable-tiling Wayland compositor.

- **[end-4/dots-hyprland](https://github.com/end-4/dots-hyprland)** - Inspiration for Quickshell usage patterns.

If you like this shell, please star the [original Caelestia repository](https://github.com/caelestia-dots/shell) and consider [supporting the original author](https://ko-fi.com/soramane).

## License

This adaptation follows the same license as the original Caelestia shell. See the original repository for license details.
