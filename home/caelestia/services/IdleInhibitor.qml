pragma Singleton

import Quickshell
import Quickshell.Io

Singleton {
    id: root

    property alias enabled: props.enabled
    readonly property alias enabledSince: props.enabledSince

    onEnabledChanged: {
        if (enabled) {
            props.enabledSince = new Date();
            // Use systemd-inhibit for niri
            inhibitProc.running = true;
        } else {
            inhibitProc.running = false;
        }
    }

    PersistentProperties {
        id: props

        property bool enabled
        property date enabledSince

        reloadableId: "idleInhibitor"
    }

    // Use systemd-inhibit for niri instead of Wayland protocol
    Process {
        id: inhibitProc
        command: ["systemd-inhibit", "--what=idle", "--who=caelestia-shell", "--why=User requested", "sleep", "infinity"]
    }

    IpcHandler {
        target: "idleInhibitor"

        function isEnabled(): bool {
            return props.enabled;
        }

        function toggle(): void {
            props.enabled = !props.enabled;
        }

        function enable(): void {
            props.enabled = true;
        }

        function disable(): void {
            props.enabled = false;
        }
    }
}
