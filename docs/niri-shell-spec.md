# Niri Shell Specification

This document catalogs all Caelestia features for planning a custom niri shell implementation.

**Instructions**: Mark each feature with your preference:
- `[KEEP]` - Want this exactly as Caelestia does it
- `[MODIFY]` - Want this but with changes (describe in notes)
- `[SKIP]` - Don't want this feature
- `[LATER]` - Maybe later, not priority

---

## Architecture Overview

> **See also:** [Daemon Specification](./niri-shell-daemon-spec.md) for detailed DBus interface specs.

### Backend Requirements
| Component | Caelestia Uses | Our Approach | Notes |
|-----------|---------------|--------------|-------|
| Window Manager IPC | Hyprland socket | niri-shell-ipc (Rust DBus) | Already started |
| Native Plugin | C++ Qt plugin | Rust DBus daemon | See daemon spec |
| Config Storage | JSON files | `~/.config/niri-shell/` | Themes + config |

---

## 1. BAR (Vertical Side Panel)
I WANT EVERYTHING IN THIS SECTION
### Bar Basics
| Feature | Description | Decision | Notes |
|---------|-------------|----------|-------|
| Vertical orientation | Bar on left edge of screen | | |
| Auto-hide | Hide when not hovered, show on hover | | |
| Persistent mode | Always visible option | | |
| Drag threshold | Configurable drag sensitivity | | |
| Scroll actions | Different actions for scroll zones | | |

### Bar Widgets (top to bottom, configurable order)
| Widget | Description | Decision | Notes |
|--------|-------------|----------|-------|
| **Logo/OS Icon** | Distro logo at top | | |
| **Workspaces** | Workspace indicators with window previews | | |
| **Active Window** | Current window title/icon | | |
| **System Tray** | SNI tray icons | | |
| **Clock** | Time display (vertical text) | | |
| **Status Icons** | Battery, wifi, bluetooth, audio, etc. | | |
| **Power Button** | Opens session menu | | |

### Bar - Workspace Widget Options
| Option | Description | Decision | Notes |
|--------|-------------|----------|-------|
| Max shown | Limit visible workspaces | | |
| Active indicator style | How to show active workspace | | |
| Occupied background | Different bg for occupied ws | | |
| Show windows | Mini window previews in ws | | |
| Active trail animation | Visual trail effect | | |
| Per-monitor workspaces | Separate ws per monitor | | |
| Custom labels | Text/icons for workspaces | | |

### Bar - Status Icons Options
| Icon | Description | Decision | Notes |
|------|-------------|----------|-------|
| Audio volume | Speaker icon + level | | |
| Microphone | Mic status | | |
| Keyboard layout | Current kb layout | | |
| Network/Wifi | Connection status | | |
| Bluetooth | BT status | | |
| Battery | Charge level + icon | | |
| Lock indicators | Caps/Num lock | | |

### Bar - Popouts (hover panels)
| Popout | Description | Decision | Notes |
|--------|-------------|----------|-------|
| Active window info | Window details on hover | | |
| Tray item menus | Right-click menus | | |
| Status icon details | Detailed info on hover | | |

### Bar - Scroll Actions
| Zone | Default Action | Decision | Notes |
|------|----------------|----------|-------|
| Workspaces area | Switch workspace | | |
| Top half | Volume control | | |
| Bottom half | Brightness control | | |

---

## 2. LAUNCHER (App Launcher)

### Launcher Basics
| Feature | Description | Decision | Notes |
|---------|-------------|----------|-------|
| Fuzzy search | Fuzzy match app names | | |
| Frequency sorting | Most used apps first | | |
| Vim keybinds | j/k navigation | | |
| Hidden apps list | Apps to exclude | | |
| Grid layout | App grid display | | |
I WANT EVERYTHING IN LAUNCHER Basics

### Launcher Services (special prefixes)
| Service | Prefix | Description | Decision | Notes |
|---------|--------|-------------|----------|-------|
| Apps | (none) | Application launcher |WANT | |
| Calculator | `=` | Qalculate integration |DO NOT WANT | Needs native code |
| Actions | `:` | Custom shell commands |WANT | |
| Color schemes | `>scheme` | Switch M3 color scheme |WANT BUT VERY DIFFERENT. TALK TO ME | |
| Color variants | `>variant` | Switch M3 variant |SAME AS SCHEMES | |
| Wallpapers | `>wall` | Wallpaper picker |SAME AS SCHEMES | |

### Launcher - Calculator
| Feature | Description | Decision | Notes |
|---------|-------------|----------|-------|
| Live evaluation | Results as you type | | Needs qalculate |
| Copy result | Click to copy | | |
| Unit conversion | Qalculate units | | |
DO NOT NEED ANYTHING IN CALCULATOR
---

## 3. DASHBOARD (Left Side Panel)

### Dashboard Tabs
| Tab | Description | Decision | Notes |
|-----|-------------|----------|-------|
| **Dash** | Quick info overview | | |
| **Media** | Full media controls | | |
| **Weather** | Weather details | | |
| **Performance** | System resources | | |

### Dashboard - Dash Tab Widgets
| Widget | Description | Decision | Notes |
|--------|-------------|----------|-------|
| Date/Time | Large clock display | | |
| User info | Username, uptime | | |
| Calendar | Month calendar view | | |
| Media mini | Compact now playing | | |
| Weather mini | Current conditions | | |
| Resources mini | CPU/RAM/disk bars | | |

### Dashboard - Media Tab
| Feature | Description | Decision | Notes |
|---------|-------------|----------|-------|
| Album art | Large cover display | | |
| Track info | Title, artist, album | | |
| Progress bar | Seek control |DO NOT WANT | |
| Playback controls | Play/pause/skip | | |
| Audio visualizer | Waveform display | DO NOT WANT| Needs pipewire |
| Player switching | Multiple players |DO NOT WANT | |

### Dashboard - Weather Tab
| Feature | Description | Decision | Notes |
|---------|-------------|----------|-------|
| Current conditions | Temp, humidity, etc. | | |
| Forecast | Multi-day forecast | | |
| Location config | City/coords setting | | |
| Fahrenheit/Celsius | Unit preference | | |
DO NOT WANT ANY WEATHER

### Dashboard - Performance Tab
| Feature | Description | Decision | Notes |
|---------|-------------|----------|-------|
| CPU usage | Per-core or total | | |
| RAM usage | Used/total | | |
| GPU usage | If available | | |
| Disk usage | Mount points | | |
| Network stats | Up/down speed | | |
| Temperature | CPU/GPU temps | | Needs lm_sensors |
WANT EVERYTHING IN PERF
---

## 4. SIDEBAR (Right Side - Notifications)
WANT EVERYTHING IN SIDEBAR
### Notification Features
| Feature | Description | Decision | Notes |
|---------|-------------|----------|-------|
| Notification list | Scrollable notif list | | |
| Grouped by app | Group same-app notifs | | |
| Actions | Notification buttons | | |
| Clear all | Dismiss all button | | |
| Do not disturb | DND toggle | | |
| Expire timeout | Auto-dismiss time | | |
| Images | Notification images | | |

---

## 5. OSD (On-Screen Display)
WANT EVERYTHING IN OSD
### OSD Triggers
| Trigger | Description | Decision | Notes |
|---------|-------------|----------|-------|
| Volume change | Show volume slider | | |
| Brightness change | Show brightness slider | | |
| Microphone mute | Show mic status | | |

### OSD Options
| Option | Description | Decision | Notes |
|--------|-------------|----------|-------|
| Hide delay | Time before auto-hide | | |
| Slider style | Appearance of slider | | |
| Enable per-type | Toggle each OSD type | | |

---

## 6. SESSION MENU (Power Menu)
WANT ALL OF THIS
### Session Actions
| Action | Command | Decision | Notes |
|--------|---------|----------|-------|
| Lock | Lock screen | | |
| Logout | Exit compositor | | |
| Suspend | Suspend system | | |
| Hibernate | Hibernate system | | |
| Reboot | Reboot system | | |
| Shutdown | Power off | | |

### Session Options
| Option | Description | Decision | Notes |
|--------|-------------|----------|-------|
| Vim keybinds | j/k navigation | | |
| Confirmation | Confirm dangerous actions | | |
| Custom commands | Override default cmds | | |

---

## 7. LOCK SCREEN
WANT ALL OF THIS
### Lock Features
| Feature | Description | Decision | Notes |
|---------|-------------|----------|-------|
| Password entry | PAM authentication | | |
| Clock display | Time on lock screen | | |
| User avatar | Profile picture | | |
| Fingerprint | fprintd integration | | |
| Failed attempts | Show attempt count | | |
| Background blur | Blur desktop behind | | |

---

## 8. CONTROL CENTER (Settings App)
WANT ALL OF THIS
### Control Center Panes
| Pane | Description | Decision | Notes |
|------|-------------|----------|-------|
| **Appearance** | Theme settings | | |
| **Network** | WiFi/ethernet config | | |
| **Bluetooth** | BT device management | | |
| **Audio** | Sound settings | | |

### Appearance Settings
| Setting | Description | Decision | Notes |
|---------|-------------|----------|-------|
| Color scheme | M3 color palette | | |
| Color variant | Tonal/vibrant/etc | | |
| Dark/light mode | Theme mode | | |
| Transparency | Panel transparency | | |
| Rounding scale | Corner radius | | |
| Spacing scale | Element spacing | | |
| Font families | Sans/mono/icon fonts | | |
| Animation speed | Duration scale | | |

### Network Settings
| Feature | Description | Decision | Notes |
|---------|-------------|----------|-------|
| WiFi list | Available networks | | |
| WiFi connect | Password dialog | | |
| Ethernet | Wired connections | | |
| VPN | VPN connections | | |

### Bluetooth Settings
| Feature | Description | Decision | Notes |
|---------|-------------|----------|-------|
| Device list | Paired/available | | |
| Pairing | Pair new devices | | |
| Connect/disconnect | Toggle connection | | |

### Audio Settings
| Feature | Description | Decision | Notes |
|---------|-------------|----------|-------|
| Output devices | Speaker selection | | |
| Input devices | Mic selection | | |
| Volume sliders | Per-device volume | | |
| App volumes | Per-app mixer | | |

---

## 9. BACKGROUND

WANT EVERYTHING EXCEPT AUDIO VISUALIZER
| Feature | Description | Decision | Notes |
|---------|-------------|----------|-------|
| Wallpaper display | Show wallpaper image | | |
| Color extraction | Get colors from wallpaper | | Needs native code |
| Desktop clock | Large clock on desktop | | |
| Audio visualizer | Bars behind windows | | Needs pipewire/cava |

### Wallpaper Color Extraction
| Feature | Description | Decision | Notes |
|---------|-------------|----------|-------|
| Dominant color | Main color from image | | |
| Luminance | Light/dark detection | | |
| M3 scheme gen | Generate Material You colors | | |

---

## 10. AREA PICKER (Screenshot Tool)
YES WANT
### Screenshot Features
| Feature | Description | Decision | Notes |
|---------|-------------|----------|-------|
| Region select | Click-drag selection | | |
| Full screen | Capture whole screen | | |
| Window capture | Capture single window | | |
| Copy to clipboard | Copy instead of save | | |
| Save to file | Save screenshot | | |
| Annotation | Draw on screenshot | | |

---

## 11. UTILITIES / TOASTS
YES I WANT
### Toast Notifications
| Toast Type | Trigger | Decision | Notes |
|------------|---------|----------|-------|
| Config loaded | On config reload | | |
| Charging changed | Plug/unplug power | | |
| Audio output changed | Switch speakers | | |
| Audio input changed | Switch mic | | |
| Caps/Num lock | Toggle lock keys | | |
| Keyboard layout | Switch layout | | |
| VPN changed | VPN connect/disconnect | | |
| Now playing | Track change | | |

---

## 12. GLOBAL SHORTCUTS

YES I WANT
### Shortcut Bindings
| Shortcut | Action | Decision | Notes |
|----------|--------|----------|-------|
| Toggle launcher | Open/close launcher | | |
| Toggle dashboard | Open/close dashboard | | |
| Toggle session | Open/close power menu | | |
| Toggle all | Show/hide all panels | | |
| Open control center | Open settings | | |

---

## 13. SERVICES (Background Functionality)

YES I WANT
### Service Modules
| Service | Description | Decision | Notes |
|---------|-------------|----------|-------|
| **Audio** | PipeWire/PulseAudio volume | | |
| **Brightness** | Screen brightness (brightnessctl) | | |
| **Network** | NetworkManager state | | |
| **Bluetooth** | Bluez state | | |
| **Battery** | UPower battery info | | |
| **MPRIS** | Media player control | | |
| **Weather** | Weather API fetching | | |
| **System Usage** | CPU/RAM/disk monitoring | | |
| **Notifications** | Notification daemon | | |
| **Idle Inhibitor** | Prevent sleep | | |
| **Wallpapers** | Wallpaper management | | |
| **Niri IPC** | Window manager state | | Via niri-shell-ipc |

---

## 14. THEMING / APPEARANCE
WANT BUT HIGHLY DIFFERENT
### Material Design 3 Integration
| Feature | Description | Decision | Notes |
|---------|-------------|----------|-------|
| Color schemes | Predefined palettes | | |
| Dynamic colors | From wallpaper | | Needs native code |
| Tonal variants | Different saturation | | |
| Light/dark mode | Theme switching | | |

### Configurable Scales
| Scale | What it affects | Decision | Notes |
|-------|-----------------|----------|-------|
| Rounding | Corner radius | | |
| Spacing | Gaps between elements | | |
| Padding | Internal padding | | |
| Font size | Text scaling | | |
| Animation duration | Speed of transitions | | |

---

## Native Code Requirements Summary

> **Full specification:** [Daemon Specification](./niri-shell-daemon-spec.md)

The Rust daemon (`niri-shell-ipc`) provides all system integration via DBus:

| Interface | Status | Priority | Phase |
|-----------|--------|----------|-------|
| org.caelestia.Niri | **Done** | - | 1 |
| org.caelestia.Apps | **Done** | High | 2 |
| org.caelestia.Audio | **Done** | High | 2 |
| org.caelestia.Power | **Done** | High | 2 |
| org.caelestia.System | TODO | Medium | 3 |
| org.caelestia.Media | TODO | Medium | 3 |
| org.caelestia.Notifications | TODO | Medium | 3 |
| org.caelestia.Network | TODO | Medium | 4 |
| org.caelestia.Bluetooth | TODO | Medium | 4 |
| org.caelestia.Brightness | TODO | Medium | 4 |
| org.caelestia.Theme | TODO | Low | 4 |
| org.caelestia.Idle | TODO | Low | 5 |

**Skipped features** (no daemon work needed):
- ~~Image color extraction~~ - using static schemes
- ~~Calculator (qalculate)~~ - not wanted
- ~~Audio visualizer~~ - not wanted
- ~~Weather API~~ - not wanted

---

## Implementation Phases (Suggested)

### Phase 1: Minimal Viable Shell ✅ COMPLETE
- [x] Static theme system (Gruvbox light/dark JSON files)
- [x] Basic bar with workspaces + clock
- [x] niri-shell-ipc integration (workspaces, windows, outputs)
- [x] Fixed event stream processing bug

### Phase 2: Core Interactions
- [ ] Full bar widgets (tray, all status icons, popouts)
- [ ] App launcher with fuzzy search
- [ ] OSD for volume/brightness
- [ ] Session menu (power options)

### Phase 3: Panels & Info
- [ ] Dashboard (Dash tab + Performance tab + Media basic)
- [ ] Sidebar/Notifications
- [ ] Window Info panel

### Phase 4: Full Experience
- [ ] Lock screen
- [ ] Control center (appearance, network, bluetooth, audio)
- [ ] Screenshot/Area picker
- [ ] Theme switcher in launcher
- [ ] Wallpaper cycling per-theme
- [ ] Idle management

### Phase 5: Polish
- [ ] App frequency tracking (optional, needs SQLite)
- [ ] DDC brightness for external monitors
- [ ] IPC commands for scripting
- [ ] GTK/app theming integration

---

## Your Notes

### Theming Approach - STATIC SCHEMES (Not Dynamic)

**No wallpaper color extraction.** Instead:

1. **Static color schemes** - Predefined palettes (starting with Gruvbox Light + Gruvbox Dark)
2. **Theme config files** - Each theme has a file like:
   ```
   ~/.config/niri-shell/themes/gruvbox-dark.json
   {
     "name": "Gruvbox Dark",
     "colors": { ... M3 color tokens ... },
     "wallpapers": [
       "~/Pictures/wallpapers/gruvbox/forest.png",
       "~/Pictures/wallpapers/gruvbox/mountains.png"
     ]
   }
   ```
3. **Wallpaper cycling** - Wallpapers defined per-theme, cycle within that list
4. **Easy to add themes** - Just create a new JSON file
5. **System-wide theming** - Apps should follow the current scheme (via GTK theme, etc.)

### Feature Decisions Summary

**WANT:**
- Bar (everything)
- Launcher (apps, actions, scheme/wallpaper picker - but static schemes)
- Dashboard (Dash tab, Media partial, Performance)
- Sidebar/Notifications (everything)
- OSD (everything)
- Session Menu (everything)
- Lock Screen (everything)
- Control Center (everything)
- Background (wallpaper, desktop clock optional)
- Screenshot/Area Picker
- Toasts
- Shortcuts
- Window Info Panel
- IPC/Remote Control
- Idle Management
- DDC Brightness

**SKIP:**
- Calculator in launcher
- Weather (anywhere)
- Audio visualizer (anywhere)
- Dynamic color extraction from wallpaper
- Game Mode tracking
- Desktop clock (time is in bar)
- Media: progress bar seek, player switching

**MODIFY:**
- Theming: M3 design but static schemes, not dynamic

---

## Implementation Notes (Technical Reference)

### Architecture

```
┌─────────────────────────────────────────────────────────────┐
│                     Quickshell (QML)                        │
│  ┌─────────────┐  ┌─────────────┐  ┌─────────────────────┐  │
│  │ shell.qml   │  │ stubs/      │  │ services/           │  │
│  │ (entry)     │  │ Theme.qml   │  │ Niri.qml (wm)       │  │
│  │             │  │ Toaster.qml │  │ (TODO: Apps, Audio) │  │
│  └─────────────┘  └─────────────┘  └──────────┬──────────┘  │
└───────────────────────────────────────────────┼─────────────┘
                                                │ DBus
┌───────────────────────────────────────────────┼─────────────┐
│              niri-shell-ipc (Rust daemon)                   │
│  ┌─────────┐ ┌─────────┐ ┌─────────┐ ┌─────────┐            │
│  │ niri.rs │ │ apps.rs │ │audio.rs │ │power.rs │            │
│  │ (wm)    │ │(launcher│ │(pulse)  │ │(upower) │            │
│  └────┬────┘ └─────────┘ └────┬────┘ └────┬────┘            │
│       │                       │           │                 │
│       │ Niri Socket      PulseAudio   UPower DBus           │
└───────┼───────────────────────┼───────────┼─────────────────┘
        │                       │           │
┌───────▼────┐          ┌───────▼───┐  ┌────▼─────┐
│   Niri     │          │ PipeWire/ │  │  UPower  │
│ Compositor │          │ PulseAudio│  │  Daemon  │
└────────────┘          └───────────┘  └──────────┘
```

### File Locations

**Source Code:**
- `home/caelestia/` - Main QML shell code
- `home/caelestia/shell-minimal.qml` - Minimal working shell (Phase 1)
- `home/caelestia/stubs/` - QML replacements for C++ Caelestia plugin
  - `Theme.qml` - Static theme loader
  - `Toaster.qml` - Toast notification system
  - `Toast.qml` - Toast data type
- `home/caelestia/services/Niri.qml` - Niri IPC service (DBus client)
- `packages/niri-shell-ipc/` - Rust DBus daemon

**Runtime Config:**
- `~/.config/niri-shell/config.json` - Current theme selection
- `~/.config/niri-shell/themes/*.json` - Theme definitions

**DBus Interfaces (all on `org.caelestia.Niri` service):**

| Object Path | Purpose | Status |
|-------------|---------|--------|
| `/org/caelestia/Niri` | Window manager state & control | Done |
| `/org/caelestia/Apps` | App database, fuzzy search, launch | Done |
| `/org/caelestia/Audio` | PulseAudio volume/mute control | Done |
| `/org/caelestia/Power` | Battery state via UPower | Done |

See `docs/niri-shell-daemon-spec.md` for full interface details.

### Known Issues / TODOs

1. **Polling vs signals** - QML polls DBus every 100ms; should use proper DBus property change signals for efficiency
2. **Config not in Nix** - `~/.config/niri-shell/` files should be managed by home-manager eventually
3. **libpulseaudio runtime dep** - Daemon needs libpulseaudio.so at runtime (handled by Nix package)

### How to Run (Development)

```bash
# Build the Rust daemon (needs libpulseaudio)
cd packages/niri-shell-ipc
nix-shell -p pkg-config dbus libpulseaudio --run "cargo build --release"

# Start the daemon (needs libpulseaudio in LD_LIBRARY_PATH, or use nix-built binary)
RUST_LOG=debug ./target/release/niri-shell-ipc

# Start the minimal shell
quickshell -p /path/to/caelestia/shell-minimal.qml
```

### Rebuilding niri-shell-ipc

```bash
cd packages/niri-shell-ipc
nix-shell -p pkg-config dbus libpulseaudio --run "cargo build --release"
# Or build via Nix: nix-build -E 'with import <nixpkgs> {}; callPackage ./default.nix {}'
```

### Next Implementation Steps

1. **Bring in Caelestia bar components** - Replace minimal bar with styled version
2. **Create QML services for new DBus interfaces** - Apps.qml, Audio.qml, Power.qml
3. **Build launcher UI** - Using Apps interface for fuzzy search
4. **Build OSD** - Using Audio interface for volume changes
5. **Tier 2 daemon work** - System stats, Media (MPRIS), Notifications
4. **Proper DBus signals** - Replace polling with signal-based updates

