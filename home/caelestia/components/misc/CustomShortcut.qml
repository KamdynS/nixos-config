import QtQuick

// GlobalShortcut from Hyprland is not available in niri
// Global shortcuts should be configured in niri.kdl instead
// This is a placeholder component that does nothing
Item {
    property string appid: "caelestia"
    property string name: ""
    property string description: ""

    signal pressed()
    signal released()

    visible: false
}
