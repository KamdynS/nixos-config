import Quickshell
import Quickshell.Wayland
import QtQuick
import "theme"

Item {
    id: root
    required property var screen

    property int borderWidth: Gruvbox.screenBorderWidth
    property color borderColor: Gruvbox.screenBorder

    // Top border
    PanelWindow {
        screen: root.screen
        anchors {
            top: true
            left: true
            right: true
        }
        height: borderWidth
        exclusionMode: ExclusionMode.Ignore
        WlrLayershell.layer: WlrLayer.Bottom
        WlrLayershell.namespace: "screen-border"

        Rectangle {
            anchors.fill: parent
            color: borderColor
        }
    }

    // Bottom border
    PanelWindow {
        screen: root.screen
        anchors {
            bottom: true
            left: true
            right: true
        }
        height: borderWidth
        exclusionMode: ExclusionMode.Ignore
        WlrLayershell.layer: WlrLayer.Bottom
        WlrLayershell.namespace: "screen-border"

        Rectangle {
            anchors.fill: parent
            color: borderColor
        }
    }

    // Left border
    PanelWindow {
        screen: root.screen
        anchors {
            top: true
            bottom: true
            left: true
        }
        width: borderWidth
        exclusionMode: ExclusionMode.Ignore
        WlrLayershell.layer: WlrLayer.Bottom
        WlrLayershell.namespace: "screen-border"

        Rectangle {
            anchors.fill: parent
            color: borderColor
        }
    }

    // Right border
    PanelWindow {
        screen: root.screen
        anchors {
            top: true
            bottom: true
            right: true
        }
        width: borderWidth
        exclusionMode: ExclusionMode.Ignore
        WlrLayershell.layer: WlrLayer.Bottom
        WlrLayershell.namespace: "screen-border"

        Rectangle {
            anchors.fill: parent
            color: borderColor
        }
    }
}
