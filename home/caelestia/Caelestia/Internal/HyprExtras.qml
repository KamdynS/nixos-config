import QtQuick

// Stub for HyprExtras - disabled for niri
// This was Hyprland-specific functionality
Item {
    id: root

    property var options: ({})
    property var devices: ({ keyboards: [] })

    function batchMessage(messages) {
        console.log("HyprExtras.batchMessage: Not available on niri");
    }

    function refreshDevices() {
        console.log("HyprExtras.refreshDevices: Not available on niri");
    }
}
