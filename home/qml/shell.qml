import Quickshell
import Quickshell.Wayland
import Quickshell.Io
import QtQuick

ShellRoot {
    id: root

    // Global state
    property bool controlCenterVisible: false
    property real volume: 0.5
    property bool muted: false
    property real brightness: 1.0
    property string wifiNetwork: "..."
    property bool wifiEnabled: true

    // Unified screen frame (border + bar) on each screen
    Variants {
        model: Quickshell.screens

        ScreenFrame {
            property var modelData
            screen: modelData

            onControlCenterToggled: {
                root.controlCenterVisible = !root.controlCenterVisible
            }
        }
    }

    // Control center (single instance, follows focused screen)
    ControlCenter {
        visible: root.controlCenterVisible
        screen: Quickshell.screens[0]

        onCloseRequested: {
            root.controlCenterVisible = false
        }

        volume: root.volume
        muted: root.muted
        brightness: root.brightness
        wifiNetwork: root.wifiNetwork
        wifiEnabled: root.wifiEnabled

        onVolumeAdjusted: (val) => {
            root.volume = val
            volumeProc.command = ["wpctl", "set-volume", "@DEFAULT_AUDIO_SINK@", val.toString()]
            volumeProc.running = true
        }

        onMuteToggled: (val) => {
            root.muted = val
            muteProc.running = true
        }

        onBrightnessAdjusted: (val) => {
            root.brightness = val
            brightnessProc.command = ["brightnessctl", "set", Math.round(val * 100) + "%"]
            brightnessProc.running = true
        }

        onWifiToggled: {
            wifiToggleProc.command = ["nmcli", "radio", "wifi", root.wifiEnabled ? "off" : "on"]
            wifiToggleProc.running = true
        }
    }

    // Volume control
    Process {
        id: volumeProc
        command: ["wpctl", "set-volume", "@DEFAULT_AUDIO_SINK@", "0.5"]
    }

    Process {
        id: muteProc
        command: ["wpctl", "set-mute", "@DEFAULT_AUDIO_SINK@", "toggle"]
    }

    // Brightness control
    Process {
        id: brightnessProc
        command: ["brightnessctl", "set", "100%"]
    }

    // WiFi toggle
    Process {
        id: wifiToggleProc
        command: ["nmcli", "radio", "wifi", "on"]
        onRunningChanged: {
            if (!running) {
                root.wifiEnabled = !root.wifiEnabled
            }
        }
    }

    // Poll current volume
    Process {
        id: volumePoll
        command: ["wpctl", "get-volume", "@DEFAULT_AUDIO_SINK@"]
        running: true
        stdout: StdioCollector {
            onStreamFinished: {
                let text = this.text.trim()
                let match = text.match(/Volume:\s*([\d.]+)/)
                if (match) {
                    root.volume = parseFloat(match[1])
                }
                root.muted = text.includes("[MUTED]")
            }
        }
    }

    // Poll current brightness
    Process {
        id: brightnessPoll
        command: ["brightnessctl", "info", "-m"]
        running: true
        stdout: StdioCollector {
            onStreamFinished: {
                let parts = this.text.trim().split(",")
                if (parts.length >= 4) {
                    let pct = parseInt(parts[3])
                    if (!isNaN(pct)) {
                        root.brightness = pct / 100
                    }
                }
            }
        }
    }

    // Poll current WiFi network
    Process {
        id: wifiPoll
        command: ["nmcli", "-t", "-f", "active,ssid", "dev", "wifi"]
        running: true
        stdout: StdioCollector {
            onStreamFinished: {
                let lines = this.text.trim().split("\n")
                for (let line of lines) {
                    if (line.startsWith("yes:")) {
                        root.wifiNetwork = line.substring(4) || "Connected"
                        return
                    }
                }
                root.wifiNetwork = "Not connected"
            }
        }
    }

    // Refresh state periodically
    Timer {
        interval: 2000
        running: true
        repeat: true
        onTriggered: {
            volumePoll.running = true
            brightnessPoll.running = true
            wifiPoll.running = true
        }
    }
}
