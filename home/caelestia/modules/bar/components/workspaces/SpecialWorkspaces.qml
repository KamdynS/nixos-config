pragma ComponentBehavior: Bound

import qs.components
import qs.services
import qs.config
import Quickshell
// Hyprland import removed for niri compatibility
import QtQuick

// Special workspaces are a Hyprland-only feature
// Niri does not have special/scratchpad workspaces
// This component is kept as a placeholder but renders nothing
Item {
    id: root

    required property ShellScreen screen

    // Niri doesn't have special workspaces, so this is always hidden
    visible: false
    implicitWidth: 0
    implicitHeight: 0
}
