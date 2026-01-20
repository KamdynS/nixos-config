import QtQuick
import QtQuick.Layouts
import Quickshell
import Quickshell.Wayland
import Quickshell.Io
import "../theme"

// Workspace indicator showing squircles for each workspace.
// Active workspace is larger and uses accent color.
// Hovering shows a popup with workspace info.
Item {
    id: root

    // Workspace data from shell.qml
    property var workspaces: []
    property int activeWorkspace: 1

    // Sizing
    property int inactiveSize: 12
    property int activeSize: 18
    property int activeWidth: 28  // Rectangle width for active workspace
    property int spacing: 6
    property int squircleRadius: 4

    // Colors
    property color inactiveColor: Gruvbox.bg3
    property color activeColor: Gruvbox.yellow
    property color hoverColor: Gruvbox.bg4

    // For popup positioning
    property var screen

    // Signal to switch workspace
    signal workspaceClicked(int idx)

    // Currently hovered workspace (for popup)
    property int hoveredWorkspace: -1
    property var hoveredIndicator: null

    implicitWidth: workspaceRow.implicitWidth
    implicitHeight: activeSize

    RowLayout {
        id: workspaceRow
        anchors.centerIn: parent
        spacing: root.spacing

        Repeater {
            model: root.workspaces

            Rectangle {
                id: indicator
                required property var modelData
                property bool isActive: modelData.is_active
                property bool isHovered: indicatorMouse.containsMouse
                property int workspaceIdx: modelData.idx

                Layout.preferredWidth: isActive ? root.activeWidth : root.inactiveSize
                Layout.preferredHeight: isActive ? root.activeSize : root.inactiveSize
                Layout.alignment: Qt.AlignVCenter

                color: {
                    if (isActive) return root.activeColor
                    if (isHovered) return root.hoverColor
                    return root.inactiveColor
                }

                radius: root.squircleRadius

                // Workspace number (only shown when active)
                Text {
                    anchors.centerIn: parent
                    text: indicator.workspaceIdx
                    color: Gruvbox.bg
                    font.family: Metrics.fontFamily
                    font.pixelSize: Metrics.fontSizeSmall
                    font.bold: true
                    opacity: indicator.isActive ? 1 : 0
                    Behavior on opacity {
                        NumberAnimation { duration: 150 }
                    }
                }

                // Smooth size transition
                Behavior on Layout.preferredWidth {
                    NumberAnimation { duration: 150; easing.type: Easing.OutQuad }
                }
                Behavior on Layout.preferredHeight {
                    NumberAnimation { duration: 150; easing.type: Easing.OutQuad }
                }
                Behavior on color {
                    ColorAnimation { duration: 150 }
                }

                MouseArea {
                    id: indicatorMouse
                    anchors.fill: parent
                    hoverEnabled: true

                    onClicked: {
                        root.workspaceClicked(indicator.workspaceIdx)
                    }

                    onContainsMouseChanged: {
                        if (containsMouse) {
                            root.hoveredWorkspace = indicator.workspaceIdx
                            root.hoveredIndicator = indicator
                            popupTimer.restart()
                        } else {
                            popupTimer.stop()
                            // Small delay before hiding to allow moving to popup
                            hideTimer.restart()
                        }
                    }
                }

                // Store position for popup
                property real globalX: {
                    let pos = indicator.mapToGlobal(0, 0)
                    return pos.x
                }
                property real globalY: {
                    let pos = indicator.mapToGlobal(0, 0)
                    return pos.y
                }
            }
        }
    }

    // Delay before showing popup
    Timer {
        id: popupTimer
        interval: 400
        onTriggered: {
            if (root.hoveredWorkspace >= 0) {
                popupState.shouldShow = true
            }
        }
    }

    // Delay before hiding popup
    Timer {
        id: hideTimer
        interval: 200
        onTriggered: {
            if (!popupMouseArea.containsMouse) {
                popupState.shouldShow = false
                // Don't clear hoveredIndicator here - let closeTimer do it
                // to prevent position jump during close animation
            }
        }
    }

    // Animation state controller
    QtObject {
        id: popupState
        property bool shouldShow: false
        property bool active: false
    }

    // The popup window
    PanelWindow {
        id: workspacePopup
        screen: root.screen
        visible: popupState.active

        anchors {
            top: true
            left: true
        }

        margins {
            top: 32  // Align with bottom of the bar frame
            left: root.hoveredIndicator ? root.hoveredIndicator.globalX - 70 : 0
        }

        implicitWidth: 160
        implicitHeight: popupContainer.height
        color: "transparent"

        property int popupRadius: Metrics.radiusLarge
        property int animDuration: 200

        WlrLayershell.namespace: "workspace-popup"
        WlrLayershell.layer: WlrLayer.Overlay

        // Animate in/out
        Item {
            id: popupContainer
            width: 160
            height: 120

            // Animation properties
            property real animProgress: 0
            opacity: animProgress
            transform: Translate { y: (1 - popupContainer.animProgress) * -20 }

            Behavior on animProgress {
                NumberAnimation {
                    duration: workspacePopup.animDuration
                    easing.type: Easing.OutCubic
                }
            }

            // Background that melts into the border
            Rectangle {
                id: popupBackground
                anchors.fill: parent
                color: "transparent"

                // Main popup body (below the melt zone)
                Rectangle {
                    id: popupBody
                    anchors.left: parent.left
                    anchors.right: parent.right
                    anchors.top: parent.top
                    anchors.topMargin: 6  // Small gap where it "emerges" from border
                    anchors.bottom: parent.bottom
                    color: Gruvbox.bg1
                    radius: workspacePopup.popupRadius

                    // Subtle inner shadow/highlight at top
                    Rectangle {
                        anchors.top: parent.top
                        anchors.left: parent.left
                        anchors.right: parent.right
                        anchors.topMargin: 1
                        anchors.leftMargin: 1
                        anchors.rightMargin: 1
                        height: 1
                        color: Gruvbox.bg3
                        opacity: 0.5
                    }

                    // Border
                    border.color: Gruvbox.bg4
                    border.width: 1
                }

                // Connection strip that blends with the frame
                Rectangle {
                    id: connectionStrip
                    anchors.top: parent.top
                    anchors.horizontalCenter: parent.horizontalCenter
                    width: 40
                    height: 8
                    color: Gruvbox.screenBorder

                    // Rounded bottom corners only
                    Rectangle {
                        anchors.top: parent.top
                        anchors.left: parent.left
                        anchors.right: parent.right
                        height: parent.height / 2
                        color: parent.color
                    }
                    Rectangle {
                        anchors.bottom: parent.bottom
                        anchors.left: parent.left
                        anchors.right: parent.right
                        height: parent.height / 2 + 2
                        color: parent.color
                        radius: 4
                    }
                }
            }

            MouseArea {
                id: popupMouseArea
                anchors.fill: parent
                hoverEnabled: true

                onContainsMouseChanged: {
                    if (!containsMouse) {
                        hideTimer.restart()
                    } else {
                        hideTimer.stop()
                    }
                }
            }

            // Popup content
            Column {
                id: popupContent
                anchors.top: popupBody.top
                anchors.topMargin: 14
                anchors.left: parent.left
                anchors.right: parent.right
                anchors.leftMargin: 14
                anchors.rightMargin: 14
                spacing: 8

                // Workspace number
                Text {
                    text: "Workspace " + root.hoveredWorkspace
                    color: Gruvbox.fg
                    font.family: Metrics.fontFamily
                    font.pixelSize: Metrics.fontSizeLarge
                    font.bold: true
                }

                // Separator
                Rectangle {
                    width: parent.width
                    height: 1
                    color: Gruvbox.bg3
                }

                // Workspace info
                Column {
                    width: parent.width
                    spacing: 4

                    Text {
                        property var ws: root.workspaces.find(w => w.idx === root.hoveredWorkspace)
                        text: ws ? (ws.is_active ? "● Active" : "○ Inactive") : ""
                        color: ws && ws.is_active ? Gruvbox.green : Gruvbox.fg3
                        font.family: Metrics.fontFamily
                        font.pixelSize: Metrics.fontSizeNormal
                    }

                    Text {
                        property var ws: root.workspaces.find(w => w.idx === root.hoveredWorkspace)
                        text: ws && ws.active_window_id ? "Has windows" : "Empty"
                        color: Gruvbox.fg4
                        font.family: Metrics.fontFamily
                        font.pixelSize: Metrics.fontSizeSmall
                    }
                }
            }
        }

        // Handle show/hide with animation
        onVisibleChanged: {
            if (visible) {
                popupContainer.animProgress = 1
            }
        }

        Connections {
            target: popupState
            function onShouldShowChanged() {
                if (popupState.shouldShow) {
                    popupState.active = true
                    popupContainer.animProgress = 1
                } else {
                    popupContainer.animProgress = 0
                    // Delay hiding until animation completes
                    closeTimer.start()
                }
            }
        }

        Timer {
            id: closeTimer
            interval: workspacePopup.animDuration
            onTriggered: {
                if (!popupState.shouldShow) {
                    popupState.active = false
                    // Now safe to clear position - popup is hidden
                    root.hoveredWorkspace = -1
                    root.hoveredIndicator = null
                }
            }
        }
    }
}
