pragma Singleton

import qs.services
import qs.config
import Quickshell
import Quickshell.Io
import QtQuick

// Game mode functionality is Hyprland-specific
// Niri doesn't have the same runtime config manipulation
// This service is disabled for niri compatibility
Singleton {
    id: root

    // Always disabled on niri
    readonly property bool enabled: false

    // Placeholder functions for compatibility
    function setDynamicConfs(): void {
        console.log("GameMode: Not available on niri");
    }

    IpcHandler {
        target: "gameMode"

        function isEnabled(): bool {
            return false;
        }

        function toggle(): void {
            console.log("GameMode: Not available on niri");
        }

        function enable(): void {
            console.log("GameMode: Not available on niri");
        }

        function disable(): void {
            console.log("GameMode: Not available on niri");
        }
    }
}
