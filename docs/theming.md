# Theming System

Documentation for the Caelestia shell theming architecture.

## Overview

The shell supports dynamic theming with colors loaded from JSON theme files. Theme changes propagate to all UI components and optionally to external applications (Ghostty, Neovim, Zen browser).

## Architecture

```
Theme Files (themes/*.json)
        │
        ▼
stubs/Theme.qml (loads theme, stores state)
        │
        ▼
services/Colours.qml (M3 palette singleton)
        │
        ▼
UI Components (Workspace.qml, etc.)
```

### Key Files

| File | Purpose |
|------|---------|
| `themes/gruvbox-dark.json` | Dark theme colors and wallpapers |
| `themes/gruvbox-light.json` | Light theme colors and wallpapers |
| `stubs/Theme.qml` | Theme loader singleton, manages current theme state |
| `services/Colours.qml` | M3 color palette singleton, used by all UI components |
| `services/ThemePropagator.qml` | Propagates theme to external apps (optional) |

### Color Flow

1. **Theme.qml** loads the theme JSON from `themes/` directory
2. **Theme.qml** calls `Colours.loadFromTheme(theme)` to update the palette
3. **Colours.qml** updates its `M3Palette` properties with colors from the theme
4. **UI components** bind to `Colours.palette.m3*` properties and update automatically

## Theme File Format

```json
{
  "name": "Theme Name",
  "id": "theme-id",
  "isDark": true,
  "wallpapers": ["~/Pictures/wallpapers/1.jpg"],
  "colors": {
    "primary": "#hexcolor",
    "onPrimary": "#hexcolor",
    "m3primary": "#hexcolor",
    "m3onPrimary": "#hexcolor",
    ...
  }
}
```

Theme files must include both unprefixed (`primary`) and prefixed (`m3primary`) color keys for compatibility with different parts of the system.

## User Configuration

Theme state is persisted at `~/.config/niri-shell/config.json`:

```json
{
  "currentTheme": "gruvbox-light",
  "wallpaperIndex": 0
}
```

## Known Issues / TODO

### Completed
- [x] Theme files created for gruvbox-dark and gruvbox-light
- [x] Theme.qml loads themes from correct path (`themes/` directory)
- [x] Theme.qml calls `Colours.loadFromTheme()` to propagate colors

### To Verify
- [x] Restart quickshell and confirm workspace colors update correctly
- [ ] Test theme switching between light and dark modes
- [ ] Verify colors look correct in both themes

### Potential Issues
- Both `services/Theme.qml` and `stubs/Theme.qml` exist as singletons in different modules (`qs.services` vs `Caelestia`)
- ThemePropagator connects to `qs.services.Theme`
- If workspace colors still don't appear, check:
  1. Check quickshell logs: `journalctl --user -fu quickshell`
  2. Verify theme file loads: look for "Colors loaded from theme:" with actual color values
  3. Confirm colors show m3primary and m3surfaceContainerHigh values from theme JSON

## Debugging

```bash
# Check quickshell logs for theme loading
journalctl --user -fu quickshell | grep -i theme

# Verify config file
cat ~/.config/niri-shell/config.json

# Restart quickshell to apply changes
systemctl --user restart quickshell
```

## Recent Changes

### 2026-02-02 (Part 2) - QML Property Assignment Fix

**Problem**: Workspace indicator colors still showing pink defaults despite logs showing correct theme colors loaded.

**Root Cause**: In `Colours.loadFromTheme()`, the code used JavaScript bracket notation:
```javascript
current[name] = value;  // Creates JS shadow property, not QML property!
```
This creates a JavaScript shadow property instead of setting the actual QML `property color` declaration. The console.log reads the shadow property (showing correct value), but QML bindings read the original QML property (still pink defaults).

**Fix Applied**: Changed to explicit direct property assignment for each M3 color:
```javascript
if (c.m3primary) current.m3primary = c.m3primary;  // Properly sets QML property
```

**Files Modified**:
- `home/caelestia/services/Colours.qml` - explicit property assignment in `loadFromTheme()`

**Key Lesson**: When setting QML object properties from JavaScript, always use direct property access (`obj.prop = value`), never bracket notation (`obj[name] = value`).

---

### 2026-02-02 (Part 1) - Theme Loading Path Fix

**Problem**: Workspace indicator colors were not showing - they appeared washed out/invisible because the `Colours.qml` M3Palette had hardcoded pink theme defaults instead of loading from theme files.

**Root Cause**: `stubs/Theme.qml` was loading theme files but:
1. Looking in wrong directory (`~/.config/niri-shell/themes/` instead of `themes/`)
2. Not calling `Colours.loadFromTheme()` to propagate colors to the Colours service

**Fix Applied**:
1. Changed `themesDir` to use `Qt.resolvedUrl("../themes")` for correct path resolution
2. Added `import qs.services` to access Colours singleton
3. Added `Colours.loadFromTheme(theme)` call after loading theme JSON

**Files Modified**:
- `home/caelestia/stubs/Theme.qml` - theme loading and color propagation fix
- `docs/workspaces.md` - updated color documentation
