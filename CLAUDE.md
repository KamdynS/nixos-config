# CLAUDE.md

This file provides guidance to Claude Code when working with this repository.

## Overview

NixOS flake configuration for a niri-based Wayland desktop. Rice v2 - minimal, fast, themeable.

**Hosts:**
- `desktop` (AMD workstation, GRUB dual-boot) - rice v2, the only host in the flake

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
theme-pick                    # fuzzel menu, theme only
wallpaper-switch <wallpaper>  # set wallpaper + its theme (keys from wallpapers/config.json)
wallpaper-pick                # rofi carousel (Mod+T)
```

New files under `themes/` or `wallpapers/` must be `git add`ed before
`nix flake check` / rebuild, or the flake won't see them.

## Architecture

### Entry Points
- `flake.nix` - Defines `nixosConfigurations.desktop`
- `hosts/desktop/configuration.nix` - System config (AMD GPU, GDM, niri, pipewire)
- `home/desktop.nix` - Home-manager entry for desktop user

### Module Structure
```
home/
  desktop.nix              # Entry point, imports all modules
  modules/
    theming.nix            # Theme registry, generated configs, theme/wallpaper scripts
    niri.nix               # Compositor config + keybinds
    waybar.nix             # Bar (minimal: clock, workspaces, network)
    fuzzel.nix             # App launcher
    rofi.nix               # rofi + imagemagick for the wallpaper carousel
    mako.nix               # Notifications
    cliphist.nix           # Clipboard manager
    swww.nix               # Wallpaper daemon (awww package)
    ghostty.nix            # Terminal
    apps.nix               # Zen Browser, Discord, etc.
    spicetify.nix          # Spotify (Flatpak) theming
    shell.nix              # zsh + oh-my-zsh + starship
    editor.nix             # neovim + LSPs
themes/                    # One .nix per theme (see Themes below)
wallpapers/
  config.json              # Wallpaper registry: key -> { path, theme }
  <theme>-<description>.<jpg|png|webp>
dotfiles/
  nvim/                    # Symlinked, edit without rebuild
  claude/
```

### Theming System

Each `themes/<name>.nix` returns `{ name, palette, polarity, wallpaper }`.
`palette` is a base16 attrset, either taken from `nix-colors.colorSchemes.<x>.palette`
or written out by hand. `wallpaper` is the default wallpaper for `theme-switch`.

Themes are registered in the `themes = { ... }` attrset at the top of
`home/modules/theming.nix`. **A theme file that isn't listed there does nothing.**
At build time, `theming.nix` generates themed config files for each registered theme:
- `~/.config/waybar/themes/<name>.css`
- `~/.config/ghostty/themes/<name>`
- `~/.config/mako/themes/<name>.conf`
- `~/.config/fuzzel/themes/<name>.ini`
- `~/.config/rofi/themes/<name>.rasi`
- `~/.config/nvim-theme/<name>.lua`
- `~/.config/zen-chrome/<name>.css`
- `~/.config/spicetify/Themes/base16/color.ini` (one section per theme)
- `~/.config/starship.toml` (all palettes embedded)

At runtime, `theme-switch <name>`:
1. Updates symlinks to point active config at chosen theme
2. Sets wallpaper via swww with transition
3. Reloads services (waybar, mako, ghostty via SIGUSR2)
4. Updates starship palette in config file
5. Re-applies spicetify (restarts Spotify if running)

The active theme is stored in `~/.cache/rice/current-theme`.

### Wallpapers

`wallpapers/config.json` maps every wallpaper to a theme:

```json
"nord-black-moon": {
  "path": "/home/kamdyns/nixos-config/wallpapers/nord-black-moon.jpg",
  "theme": "nord"
}
```

- `wallpaper-switch <key>` sets that wallpaper and switches to its theme.
- `wallpaper-pick` (Mod+T) is a rofi carousel. **h/l** cycles wallpapers within a theme,
  **j/k** cycles themes, and **Enter** applies. The theme order is the order in which
  themes first appear in `config.json`, so keep each theme's entries grouped together.
- Thumbnails (800x500) are pre-rendered to `~/.cache/rice/wallpaper-thumbs/<key>.png`
  during home-manager activation, so new wallpapers show up in the picker after a rebuild.
- File naming: `<theme>-<description>.<ext>`. jpg, png and webp all work.
- A few original wallpapers (bookshelf, castle, waterfall, …) don't use the theme prefix.

### Themes

| Theme | Source | Polarity |
|-------|--------|----------|
| gruvbox-light (default) | nix-colors | light |
| gruvbox-dark | nix-colors | dark |
| catppuccin-mocha | nix-colors | dark |
| kanagawa | nix-colors | dark |
| rose-pine | nix-colors | dark |
| tokyonight | nix-colors | dark |
| catppuccin-latte | omarchy (nix-colors palette) | light |
| everforest | omarchy (nix-colors palette) | dark |
| nord | omarchy (nix-colors palette) | dark |
| ethereal, hackerman, last-horizon, lumon, matte-black, miasma, osaka-jade, retro-82, ristretto, solitude, vantablack | omarchy (hand-written palette) | dark |
| flexoki-light, white | omarchy (hand-written palette) | light |
| jade-horse, starship | omarchy (generated from colors.toml, Nov 2026) | dark |
| lupine | omarchy (generated from colors.toml, Nov 2026) | light |

`osaka-jade` no longer exists upstream in omarchy. We keep our copy.

### Importing from Omarchy

Many themes and most wallpapers come from [omarchy](https://github.com/basecamp/omarchy)
(`themes/<name>/backgrounds/` and `themes/<name>/colors.toml`). Imports so far:

- **May 2026** (`9a1460c`): 16 themes, 49 wallpapers.
- **Nov 2026** (upstream `c3c8acf`): 3 new themes (jade-horse, lupine, starship) and
  32 wallpapers. 12 went to the 3 new themes. The other 20 went to existing themes:
  catppuccin-mocha, ethereal, gruvbox-dark, kanagawa, rose-pine and tokyonight.

To import again:

1. `git clone --depth 1 https://github.com/basecamp/omarchy` into a scratch dir.
2. Diff by **name**, not checksum. Upstream re-encodes images (jpg → webp), so the
   same picture gets a different hash. Strip the `N-` prefix from the upstream
   filename and check whether `wallpapers/<theme>-<desc>.*` exists.
3. Upstream → local theme names: `catppuccin` → `catppuccin-mocha`,
   `gruvbox` → `gruvbox-dark`, `tokyo-night` → `tokyonight`. Everything else is the same.
4. Skip `backgrounds/omarchy.webp` and other logo-only images, plus the `intros/`
   videos (mp4, which swww can't use).
5. Copy files as `wallpapers/<theme>-<desc>.<ext>` and add entries to `config.json`
   next to that theme's existing entries.
6. For new themes, map `colors.toml` to base16 like this:
   `base00`=background, `base01`=lighter_background (light mode: dark_background),
   `base02`=selection, `base03`=muted, `base04`=dark_foreground, `base05`=foreground,
   `base06`=light_foreground, `base07`=bright_foreground, `base08`=red, `base09`=orange,
   `base0A`=yellow, `base0B`=green, `base0C`=cyan, `base0D`=blue, `base0E`=magenta,
   `base0F`=brown. `polarity` comes from `mode`. Add a
   `# <Name> (imported from omarchy)` header and register the theme in `theming.nix`.
7. `git add` the new files, then run `nix flake check` and rebuild.

### Keybinds (niri)

| Key | Action |
|-----|--------|
| Mod+Return | ghostty |
| Mod+B | Zen Browser |
| Mod+S | Spotify |
| Mod+D | Discord |
| Mod+Space | fuzzel |
| Mod+V | cliphist picker |
| Mod+T | wallpaper carousel (rofi) |
| Mod+Escape | power menu |
| Mod+Shift+S | screenshot region → clipboard |
| Print / Alt+Print | screenshot / window screenshot (to file) |
| Mod+Shift+/ | show hotkey overlay |
| Mod+Q | close window |
| Mod+F / Mod+Shift+F | maximize column / fullscreen |
| Mod+R | cycle column widths |
| Mod+1-9 | workspace |
| Mod+Shift+1-9 | move column to workspace |
| Mod+H/L | focus column left/right |
| Mod+J/K | focus workspace down/up |
| Mod+Shift+H/L | move column left/right |
| Mod+Shift+J/K | move column to workspace down/up |
| Mod+Tab | focus next monitor |
| Mod+Shift+, / . | move column to monitor left/right |
| Mod+Shift+E | quit niri |
| Mod+Shift+P | power off monitors |

Media keys control Spotify playback and volume.

### Stack

| Role | Tool |
|------|------|
| Compositor | niri |
| Bar | waybar |
| Launcher | fuzzel (apps) + rofi (wallpaper carousel) |
| Notifications | mako |
| Clipboard | cliphist |
| Wallpaper | swww (`awww` package) |
| Terminal | ghostty |
| Shell | zsh + oh-my-zsh + starship |
| Editor | neovim |
| Browser | Zen (themed via userChrome.css) |
| Music | Spotify (Flatpak) + spicetify-cli |

### Zen Browser

Per-theme `userChrome.css` files are generated in `~/.config/zen-chrome/`.
`theme-switch` symlinks the active one into `~/.zen/<profile>/chrome/userChrome.css`.
Zen reads `userChrome.css` only at launch, so **theme changes apply on the next Zen
restart**, not instantly. On first activation, any existing `userChrome.css` is backed
up once to `userChrome.css.pre-rice`.

Requires `toolkit.legacyUserProfileCustomizations.stylesheets = true` in
`about:config` (already on in this profile).

### Spotify / Spicetify

Spotify is installed via Flatpak so spicetify-cli can patch a writable install
(NixOS `/nix/store` is read-only). Every registered theme is written as a section in
`~/.config/spicetify/Themes/base16/color.ini`. `theme-switch` swaps between them with
`spicetify config color_scheme <name> && spicetify apply`.
Spotify restarts on apply if it's running.

One-time bootstrap after first rebuild:

```bash
flatpak remote-add --if-not-exists --user flathub https://flathub.org/repo/flathub.flatpakrepo
flatpak install --user -y flathub com.spotify.Client
# Then re-run a home-manager activation OR manually:
spicetify backup apply --no-restart
```

## Notes

- Wallpapers live in `wallpapers/` and must be registered in `wallpapers/config.json`.
- Theme switching is instant (<1s) for live apps. Spotify restarts on theme swap,
  and Zen picks up the change on its next launch.
- Dotfiles (nvim) are symlinked, so you can edit them without a rebuild.
- Font: JetBrains Mono Nerd Font everywhere
