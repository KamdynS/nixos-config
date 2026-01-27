# niri-shell-ipc Daemon Specification

This document specifies the Rust daemon that provides system services to the Quickshell UI via DBus.

## Design Principle

**Quickshell handles UI, the daemon handles everything else.**

- QML: Rendering, animations, user input, layout, property bindings
- Rust: All async I/O, system integrations, heavy computation, protocol handling

---

## Architecture Overview

```
┌─────────────────────────────────────────────────────────────────────┐
│                        Quickshell (QML)                             │
│    Reads properties, listens to signals, calls methods              │
└─────────────────────────────┬───────────────────────────────────────┘
                              │ DBus Session Bus
┌─────────────────────────────▼───────────────────────────────────────┐
│                     niri-shell-ipc (Rust)                           │
│  ┌──────────────────────────────────────────────────────────────┐   │
│  │                    DBus Interfaces                            │   │
│  │  org.caelestia.Niri          - Window manager state          │   │
│  │  org.caelestia.Apps          - App database & launcher       │   │
│  │  org.caelestia.System        - CPU, RAM, disk, temps         │   │
│  │  org.caelestia.Audio         - PipeWire/Pulse volume         │   │
│  │  org.caelestia.Power         - Battery, charging state       │   │
│  │  org.caelestia.Network       - NetworkManager proxy          │   │
│  │  org.caelestia.Bluetooth     - BlueZ proxy                   │   │
│  │  org.caelestia.Brightness    - Backlight + DDC/CI            │   │
│  │  org.caelestia.Media         - MPRIS aggregator              │   │
│  │  org.caelestia.Notifications - freedesktop notif daemon      │   │
│  │  org.caelestia.Idle          - Idle state & inhibitors       │   │
│  │  org.caelestia.Theme         - Theme/wallpaper management    │   │
│  └──────────────────────────────────────────────────────────────┘   │
│                              │                                       │
│  ┌───────────────────────────▼──────────────────────────────────┐   │
│  │                    Backend Connections                        │   │
│  │  - Niri IPC socket                                           │   │
│  │  - PipeWire / PulseAudio                                     │   │
│  │  - /sys, /proc (sysfs)                                       │   │
│  │  - NetworkManager DBus                                       │   │
│  │  - BlueZ DBus                                                │   │
│  │  - UPower DBus                                               │   │
│  │  - DDC/CI (i2c-dev)                                          │   │
│  │  - MPRIS DBus                                                │   │
│  │  - XDG .desktop files                                        │   │
│  └──────────────────────────────────────────────────────────────┘   │
└─────────────────────────────────────────────────────────────────────┘
```

---

## DBus Interface Specifications

### 1. org.caelestia.Niri (IMPLEMENTED)

Window manager state and control. Already working.

**Object Path:** `/org/caelestia/Niri`

| Type | Name | Signature | Description |
|------|------|-----------|-------------|
| Property | Workspaces | `s` (JSON) | Array of workspace objects |
| Property | Windows | `s` (JSON) | Array of window objects |
| Property | Outputs | `s` (JSON) | Array of output objects |
| Property | FocusedWorkspace | `t` | Workspace ID (0 if none) |
| Property | FocusedWindow | `t` | Window ID (0 if none) |
| Property | FocusedOutput | `s` | Output name |
| Property | KeyboardLayouts | `s` (JSON) | Layout names + current index |
| Method | FocusWorkspace | `u` → `s` | Focus workspace by index |
| Method | FocusWorkspaceRelative | `i` → `s` | Focus relative (+1/-1) |
| Method | MoveWindowToWorkspace | `u` → `s` | Move window to workspace |
| Method | CloseWindow | → `s` | Close focused window |
| Method | FocusWindow | `t` → `s` | Focus window by ID |
| Method | Action | `s` → `s` | Send raw niri action JSON |
| Signal | WorkspacesUpdated | | Workspaces changed |
| Signal | WindowsUpdated | | Windows changed |
| Signal | FocusUpdated | | Focus changed |
| Signal | KeyboardLayoutUpdated | | Layout changed |

---

### 2. org.caelestia.Apps

Application database for launcher.

**Object Path:** `/org/caelestia/Apps`

| Type | Name | Signature | Description |
|------|------|-----------|-------------|
| Property | Apps | `s` (JSON) | All apps: `[{id, name, icon, exec, keywords}]` |
| Property | RecentApps | `s` (JSON) | Recently used apps (ordered) |
| Method | Search | `s` → `s` | Fuzzy search, returns JSON array |
| Method | Launch | `s` → `b` | Launch app by ID, returns success |
| Method | RecordLaunch | `s` | Record app was launched (for frequency) |
| Signal | AppsChanged | | Desktop files changed, rescan complete |

**Implementation Notes:**
- Scan XDG_DATA_DIRS for `.desktop` files on startup
- Watch directories with inotify for changes
- Fuzzy match on name + keywords + exec
- Optional: SQLite for launch frequency tracking

**App Object:**
```json
{
  "id": "firefox.desktop",
  "name": "Firefox",
  "generic_name": "Web Browser",
  "icon": "firefox",
  "exec": "firefox %u",
  "keywords": ["web", "browser", "internet"],
  "categories": ["Network", "WebBrowser"],
  "no_display": false
}
```

---

### 3. org.caelestia.System

System resource monitoring.

**Object Path:** `/org/caelestia/System`

| Type | Name | Signature | Description |
|------|------|-----------|-------------|
| Property | Cpu | `s` (JSON) | CPU usage info |
| Property | Memory | `s` (JSON) | RAM usage info |
| Property | Disk | `s` (JSON) | Disk usage per mount |
| Property | Network | `s` (JSON) | Network throughput |
| Property | Temperatures | `s` (JSON) | CPU/GPU temps |
| Property | Uptime | `t` | Seconds since boot |
| Property | Hostname | `s` | System hostname |
| Property | Username | `s` | Current user |
| Signal | StatsUpdated | | Stats refreshed (every 1-2s) |

**CPU Object:**
```json
{
  "usage_percent": 23.5,
  "per_core": [20.0, 25.0, 22.0, 27.0],
  "frequency_mhz": 3200,
  "core_count": 4,
  "thread_count": 8
}
```

**Memory Object:**
```json
{
  "total_bytes": 17179869184,
  "used_bytes": 8589934592,
  "available_bytes": 8589934592,
  "swap_total": 8589934592,
  "swap_used": 0,
  "usage_percent": 50.0
}
```

**Implementation Notes:**
- Read from `/proc/stat`, `/proc/meminfo`, `/proc/mounts`, `/sys/class/hwmon`
- Update every 1-2 seconds
- Use async file I/O

---

### 4. org.caelestia.Audio

Audio control via PipeWire or PulseAudio.

**Object Path:** `/org/caelestia/Audio`

| Type | Name | Signature | Description |
|------|------|-----------|-------------|
| Property | Volume | `d` | Master volume 0.0-1.0 |
| Property | Muted | `b` | Master mute state |
| Property | MicVolume | `d` | Mic volume 0.0-1.0 |
| Property | MicMuted | `b` | Mic mute state |
| Property | Sinks | `s` (JSON) | Output devices |
| Property | Sources | `s` (JSON) | Input devices |
| Property | DefaultSink | `s` | Default output name |
| Property | DefaultSource | `s` | Default input name |
| Property | Streams | `s` (JSON) | Per-app audio streams |
| Method | SetVolume | `d` → `b` | Set master volume |
| Method | SetMuted | `b` → `b` | Set master mute |
| Method | SetMicVolume | `d` → `b` | Set mic volume |
| Method | SetMicMuted | `b` → `b` | Set mic mute |
| Method | SetDefaultSink | `s` → `b` | Set default output |
| Method | SetDefaultSource | `s` → `b` | Set default input |
| Method | SetStreamVolume | `us` → `b` | Set app stream volume (id, vol) |
| Signal | VolumeChanged | `d` | Volume changed |
| Signal | MutedChanged | `b` | Mute changed |
| Signal | SinksChanged | | Outputs changed |
| Signal | SourcesChanged | | Inputs changed |
| Signal | StreamsChanged | | App streams changed |

**Sink Object:**
```json
{
  "name": "alsa_output.pci-0000_00_1f.3.analog-stereo",
  "description": "Built-in Audio Analog Stereo",
  "volume": 0.75,
  "muted": false,
  "is_default": true
}
```

**Implementation Notes:**
- Use `libpulse` bindings or PipeWire native API
- Consider: `pulsectl-rs` or `pipewire-rs` crates
- Stream volume for per-app mixer

---

### 5. org.caelestia.Power

Battery and power state via UPower.

**Object Path:** `/org/caelestia/Power`

| Type | Name | Signature | Description |
|------|------|-----------|-------------|
| Property | HasBattery | `b` | System has battery |
| Property | BatteryPercent | `d` | Charge level 0-100 |
| Property | BatteryState | `s` | "charging", "discharging", "full", "empty" |
| Property | TimeToEmpty | `t` | Seconds until empty (0 if N/A) |
| Property | TimeToFull | `t` | Seconds until full (0 if N/A) |
| Property | PowerProfile | `s` | Current power profile |
| Property | OnBattery | `b` | Running on battery |
| Method | SetPowerProfile | `s` → `b` | Set power profile |
| Signal | BatteryChanged | | Battery state changed |
| Signal | PowerProfileChanged | `s` | Profile changed |

**Implementation Notes:**
- Proxy `org.freedesktop.UPower` DBus interface
- Watch for property changes
- Support power-profiles-daemon if available

---

### 6. org.caelestia.Network

Network state via NetworkManager.

**Object Path:** `/org/caelestia/Network`

| Type | Name | Signature | Description |
|------|------|-----------|-------------|
| Property | State | `s` | "connected", "disconnected", "connecting" |
| Property | PrimaryConnection | `s` (JSON) | Current connection info |
| Property | Wifi | `s` (JSON) | WiFi state + signal |
| Property | WifiEnabled | `b` | WiFi radio on/off |
| Property | WifiNetworks | `s` (JSON) | Available networks |
| Property | ActiveConnections | `s` (JSON) | All active connections |
| Method | SetWifiEnabled | `b` → `b` | Enable/disable WiFi |
| Method | ConnectWifi | `ss` → `b` | Connect to SSID with password |
| Method | Disconnect | `s` → `b` | Disconnect connection by ID |
| Method | ScanWifi | → `b` | Trigger WiFi scan |
| Signal | StateChanged | `s` | Connection state changed |
| Signal | WifiNetworksChanged | | Scan results updated |

**WiFi Network Object:**
```json
{
  "ssid": "MyNetwork",
  "signal_strength": 75,
  "security": "wpa2",
  "connected": false,
  "saved": true
}
```

**Implementation Notes:**
- Proxy `org.freedesktop.NetworkManager` DBus
- Handle WiFi scanning and connection
- Support VPN connections if present

---

### 7. org.caelestia.Bluetooth

Bluetooth state via BlueZ.

**Object Path:** `/org/caelestia/Bluetooth`

| Type | Name | Signature | Description |
|------|------|-----------|-------------|
| Property | Powered | `b` | Bluetooth on/off |
| Property | Discoverable | `b` | Discoverable mode |
| Property | Discovering | `b` | Currently scanning |
| Property | Devices | `s` (JSON) | All known devices |
| Property | ConnectedDevices | `s` (JSON) | Currently connected |
| Method | SetPowered | `b` → `b` | Turn bluetooth on/off |
| Method | StartDiscovery | → `b` | Start scanning |
| Method | StopDiscovery | → `b` | Stop scanning |
| Method | Connect | `s` → `b` | Connect device by address |
| Method | Disconnect | `s` → `b` | Disconnect device |
| Method | Pair | `s` → `b` | Pair with device |
| Method | Remove | `s` → `b` | Remove/forget device |
| Signal | DevicesChanged | | Device list changed |
| Signal | DeviceConnected | `s` | Device connected (address) |
| Signal | DeviceDisconnected | `s` | Device disconnected |

**Device Object:**
```json
{
  "address": "AA:BB:CC:DD:EE:FF",
  "name": "AirPods Pro",
  "icon": "audio-headphones",
  "paired": true,
  "connected": true,
  "battery": 85
}
```

**Implementation Notes:**
- Proxy `org.bluez` DBus interface
- Handle pairing agents for PIN entry
- Get battery level if device supports it

---

### 8. org.caelestia.Brightness

Screen brightness control.

**Object Path:** `/org/caelestia/Brightness`

| Type | Name | Signature | Description |
|------|------|-----------|-------------|
| Property | Brightness | `d` | Current brightness 0.0-1.0 |
| Property | Displays | `s` (JSON) | Per-display brightness |
| Property | DdcSupported | `b` | DDC/CI available |
| Method | SetBrightness | `d` → `b` | Set brightness |
| Method | SetDisplayBrightness | `sd` → `b` | Set specific display |
| Method | IncreaseBrightness | `d` → `d` | Increase by delta, return new |
| Method | DecreaseBrightness | `d` → `d` | Decrease by delta, return new |
| Signal | BrightnessChanged | `d` | Brightness changed |

**Display Object:**
```json
{
  "name": "eDP-1",
  "type": "backlight",
  "brightness": 0.75,
  "max": 100
}
```

**Implementation Notes:**
- Internal displays: `/sys/class/backlight/`
- External displays: DDC/CI via `ddcutil` or `i2c-dev`
- DDC/CI needs root or udev rules for i2c access
- Cache DDC values (slow protocol)

---

### 9. org.caelestia.Media

MPRIS media player aggregation.

**Object Path:** `/org/caelestia/Media`

| Type | Name | Signature | Description |
|------|------|-----------|-------------|
| Property | Playing | `b` | Any player currently playing |
| Property | CurrentPlayer | `s` | Active player name |
| Property | Players | `s` (JSON) | All MPRIS players |
| Property | Metadata | `s` (JSON) | Current track metadata |
| Property | PlaybackStatus | `s` | "Playing", "Paused", "Stopped" |
| Property | Position | `t` | Position in microseconds |
| Property | ArtUrl | `s` | Album art URL/path |
| Method | Play | → `b` | Play |
| Method | Pause | → `b` | Pause |
| Method | PlayPause | → `b` | Toggle |
| Method | Next | → `b` | Next track |
| Method | Previous | → `b` | Previous track |
| Method | SetPlayer | `s` → `b` | Switch active player |
| Signal | MetadataChanged | | Track changed |
| Signal | PlaybackStatusChanged | `s` | Play/pause state changed |
| Signal | PlayersChanged | | Player list changed |

**Metadata Object:**
```json
{
  "title": "Song Name",
  "artist": "Artist Name",
  "album": "Album Name",
  "art_url": "file:///tmp/cover.jpg",
  "length_us": 210000000
}
```

**Implementation Notes:**
- Watch `org.mpris.MediaPlayer2.*` on DBus
- Aggregate multiple players
- Prefer currently playing player

---

### 10. org.caelestia.Notifications

Freedesktop notification daemon.

**Object Path:** `/org/freedesktop/Notifications` (standard path)

This implements the standard `org.freedesktop.Notifications` interface so apps send notifs to us.

| Type | Name | Signature | Description |
|------|------|-----------|-------------|
| Method | Notify | standard | Receive notification |
| Method | CloseNotification | `u` | Close by ID |
| Method | GetCapabilities | → `as` | Return capabilities |
| Method | GetServerInformation | → `ssss` | Server info |
| Signal | NotificationClosed | `uu` | Notif closed (id, reason) |
| Signal | ActionInvoked | `us` | Action clicked |

**Additional interface at `/org/caelestia/Notifications`:**

| Type | Name | Signature | Description |
|------|------|-----------|-------------|
| Property | Notifications | `s` (JSON) | All current notifications |
| Property | DoNotDisturb | `b` | DND mode |
| Method | SetDoNotDisturb | `b` → `b` | Toggle DND |
| Method | ClearAll | → `b` | Dismiss all |
| Method | ClearApp | `s` → `b` | Dismiss by app name |
| Signal | NotificationAdded | `s` | New notification (JSON) |
| Signal | NotificationRemoved | `u` | Notification dismissed |

**Notification Object:**
```json
{
  "id": 1,
  "app_name": "Discord",
  "app_icon": "discord",
  "summary": "New Message",
  "body": "User: Hello!",
  "actions": [["default", "Open"], ["dismiss", "Dismiss"]],
  "urgency": "normal",
  "timestamp": 1705890000,
  "image_path": "/tmp/notif-image.png"
}
```

**Implementation Notes:**
- Must claim `org.freedesktop.Notifications` name on session bus
- Handle images (data vs path)
- Persist notifications until dismissed
- Support actions and callbacks

---

### 11. org.caelestia.Idle

Idle detection and inhibitors.

**Object Path:** `/org/caelestia/Idle`

| Type | Name | Signature | Description |
|------|------|-----------|-------------|
| Property | IdleTime | `t` | Seconds idle |
| Property | IsIdle | `b` | Currently idle |
| Property | Inhibitors | `s` (JSON) | Active inhibitors |
| Property | IdleThreshold | `t` | Seconds before idle |
| Method | Inhibit | `ss` → `u` | Add inhibitor (app, reason), return ID |
| Method | Uninhibit | `u` → `b` | Remove inhibitor by ID |
| Method | SetIdleThreshold | `t` → `b` | Set idle threshold |
| Signal | IdleChanged | `b` | Idle state changed |

**Implementation Notes:**
- Use `ext-idle-notify-v1` Wayland protocol or
- Monitor KDE idle DBus or
- Fall back to polling input devices
- Track video players as automatic inhibitors

---

### 12. org.caelestia.Theme

Theme and wallpaper management.

**Object Path:** `/org/caelestia/Theme`

| Type | Name | Signature | Description |
|------|------|-----------|-------------|
| Property | CurrentTheme | `s` | Current theme name |
| Property | IsDark | `b` | Dark mode active |
| Property | Themes | `s` (JSON) | Available themes |
| Property | CurrentWallpaper | `s` | Current wallpaper path |
| Property | Wallpapers | `s` (JSON) | Wallpapers for current theme |
| Method | SetTheme | `s` → `b` | Switch theme |
| Method | NextWallpaper | → `s` | Cycle wallpaper, return new path |
| Method | SetWallpaper | `s` → `b` | Set specific wallpaper |
| Method | ReloadThemes | → `b` | Rescan theme directory |
| Signal | ThemeChanged | `s` | Theme switched |
| Signal | WallpaperChanged | `s` | Wallpaper changed |

**Theme Object:**
```json
{
  "name": "gruvbox-dark",
  "display_name": "Gruvbox Dark",
  "is_dark": true,
  "colors": {
    "primary": "#d79921",
    "surface": "#282828"
  },
  "wallpapers": [
    "~/Pictures/gruvbox/1.png",
    "~/Pictures/gruvbox/2.png"
  ]
}
```

**Implementation Notes:**
- Watch `~/.config/niri-shell/themes/` for changes
- Notify GTK/Qt apps of theme changes (portal?)
- This could stay in QML if simpler, but daemon gives:
  - File watching
  - DBus control from scripts
  - Single source of truth

---

## Implementation Priority

### Tier 1: Core (Phase 2)
| Interface | Why | Effort | Status |
|-----------|-----|--------|--------|
| Apps | Launcher needs it | Medium | **DONE** |
| Audio | Volume OSD, bar icon | Medium | **DONE** |
| Power | Bar battery indicator | Low | **DONE** |

### Tier 2: Dashboard (Phase 3)
| Interface | Why | Effort | Status |
|-----------|-----|--------|--------|
| System | Performance tab | Medium | **DONE** |
| Media | Media widget | Medium | **DONE** |
| Notifications | Sidebar | High | **DONE** |

### Tier 3: Control Center (Phase 4)
| Interface | Why | Effort | Status |
|-----------|-----|--------|--------|
| Network | WiFi settings | Medium | **DONE** |
| Bluetooth | BT settings | Medium | **DONE** |
| Brightness | DDC for externals | Medium | **DONE** (backlight only, no DDC) |
| Theme | Theme switcher | Low | TODO |

### Tier 4: Polish (Phase 5)
| Interface | Why | Effort | Status |
|-----------|-----|--------|--------|
| Idle | Idle management | Low | TODO |

---

## Crate Dependencies

```toml
[dependencies]
# Async runtime
tokio = { version = "1", features = ["full"] }

# DBus
zbus = "4"

# Niri IPC (existing)
serde = { version = "1", features = ["derive"] }
serde_json = "1"

# System stats
sysinfo = "0.30"              # CPU, RAM, disk, temps

# Audio (pick one)
libpulse-binding = "2"        # PulseAudio
# OR
pipewire = "0.8"              # PipeWire native

# Desktop entries
freedesktop-entry-parser = "1"
freedesktop-desktop-entry = "0.5"

# Fuzzy search
fuzzy-matcher = "0.3"
nucleo-matcher = "0.3"        # Alternative, faster

# File watching
notify = "6"

# Logging
tracing = "0.1"
tracing-subscriber = "0.3"

# Error handling
anyhow = "1"
thiserror = "1"

# Optional: DDC/CI
ddc-hi = "0.5"                # High-level DDC

# Optional: Frequency database
rusqlite = "0.31"
```

---

## Module Structure

```
src/
├── main.rs              # Entry point, tokio runtime
├── state.rs             # Shared state (existing)
├── niri.rs              # Niri IPC client (existing)
├── dbus/
│   ├── mod.rs           # DBus server setup
│   ├── niri.rs          # org.caelestia.Niri (existing, move here)
│   ├── apps.rs          # org.caelestia.Apps
│   ├── system.rs        # org.caelestia.System
│   ├── audio.rs         # org.caelestia.Audio
│   ├── power.rs         # org.caelestia.Power
│   ├── network.rs       # org.caelestia.Network
│   ├── bluetooth.rs     # org.caelestia.Bluetooth
│   ├── brightness.rs    # org.caelestia.Brightness
│   ├── media.rs         # org.caelestia.Media
│   ├── notifications.rs # org.freedesktop.Notifications
│   ├── idle.rs          # org.caelestia.Idle
│   └── theme.rs         # org.caelestia.Theme
└── services/
    ├── mod.rs
    ├── desktop_entries.rs  # .desktop file scanning
    ├── sysinfo.rs          # System stats collection
    ├── pulse.rs            # PulseAudio client
    ├── upower.rs           # UPower proxy
    ├── nm.rs               # NetworkManager proxy
    ├── bluez.rs            # BlueZ proxy
    ├── mpris.rs            # MPRIS aggregator
    ├── backlight.rs        # sysfs backlight
    └── ddc.rs              # DDC/CI brightness
```

---

## Testing

```bash
# Introspect interfaces
busctl --user introspect org.caelestia.Niri /org/caelestia/Niri

# Get property
busctl --user get-property org.caelestia.Niri /org/caelestia/Niri org.caelestia.Niri Workspaces

# Call method
busctl --user call org.caelestia.Apps /org/caelestia/Apps org.caelestia.Apps Search s "fire"

# Monitor signals
busctl --user monitor org.caelestia.Niri
```
