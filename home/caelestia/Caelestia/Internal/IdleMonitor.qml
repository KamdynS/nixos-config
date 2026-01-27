import QtQuick

// Stub for IdleMonitor - Quickshell.Wayland component not available on niri
// This stub doesn't actually monitor idle state but can be enhanced later with swayidle
Item {
    id: root

    property bool enabled: true
    property int timeout: 60000 // milliseconds
    property bool respectInhibitors: true
    property bool isIdle: false
}
