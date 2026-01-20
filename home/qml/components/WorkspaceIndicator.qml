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
                workspacePopup.visible = true
            }
        }
    }

    // Delay before hiding popup
    Timer {
        id: hideTimer
        interval: 200
        onTriggered: {
            if (!popupMouseArea.containsMouse) {
                workspacePopup.visible = false
                root.hoveredWorkspace = -1
                root.hoveredIndicator = null
            }
        }
    }

    // The popup window
    PanelWindow {
        id: workspacePopup
        screen: root.screen
        visible: false

        anchors {
            top: true
            left: true
        }

        margins {
            top: 42  // Below the top bar (strut height)
            left: root.hoveredIndicator ? root.hoveredIndicator.globalX - 70 : 0
        }

        implicitWidth: 160
        implicitHeight: popupContent.implicitHeight + stemHeight + 24
        color: "transparent"

        property int stemWidth: 32
        property int stemHeight: 10
        property int stemRadius: 6
        property int popupRadius: Metrics.radiusLarge

        WlrLayershell.namespace: "workspace-popup"
        WlrLayershell.layer: WlrLayer.Overlay

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

        // Popup background with stem
        Canvas {
            id: popupCanvas
            anchors.fill: parent
            antialiasing: true

            onPaint: {
                let ctx = getContext("2d")
                ctx.clearRect(0, 0, width, height)

                let sw = workspacePopup.stemWidth
                let sh = workspacePopup.stemHeight
                let sr = workspacePopup.stemRadius
                let pr = workspacePopup.popupRadius
                let cx = width / 2  // Center X for stem

                // Begin path
                ctx.beginPath()

                // Start at top-left of stem
                ctx.moveTo(cx - sw/2, 0)

                // Stem top edge
                ctx.lineTo(cx + sw/2, 0)

                // Stem right edge down
                ctx.lineTo(cx + sw/2, sh - sr)

                // Curve to popup (right side of stem)
                ctx.quadraticCurveTo(cx + sw/2, sh, cx + sw/2 + sr, sh)

                // Top edge to right corner
                ctx.lineTo(width - pr, sh)

                // Top-right corner
                ctx.quadraticCurveTo(width, sh, width, sh + pr)

                // Right edge
                ctx.lineTo(width, height - pr)

                // Bottom-right corner
                ctx.quadraticCurveTo(width, height, width - pr, height)

                // Bottom edge
                ctx.lineTo(pr, height)

                // Bottom-left corner
                ctx.quadraticCurveTo(0, height, 0, height - pr)

                // Left edge
                ctx.lineTo(0, sh + pr)

                // Top-left corner
                ctx.quadraticCurveTo(0, sh, pr, sh)

                // Top edge to stem
                ctx.lineTo(cx - sw/2 - sr, sh)

                // Curve to stem (left side)
                ctx.quadraticCurveTo(cx - sw/2, sh, cx - sw/2, sh - sr)

                // Close to start
                ctx.lineTo(cx - sw/2, 0)

                ctx.closePath()

                // Fill popup body
                ctx.fillStyle = Gruvbox.panelBg.toString()
                ctx.fill()

                // Stroke border
                ctx.strokeStyle = Gruvbox.panelBorder.toString()
                ctx.lineWidth = 1
                ctx.stroke()
            }
        }

        // Stem overlay (border color for morph effect)
        Rectangle {
            x: (parent.width - workspacePopup.stemWidth) / 2
            y: 0
            width: workspacePopup.stemWidth
            height: workspacePopup.stemHeight + 1
            color: Gruvbox.screenBorder
        }

        // Popup content
        Column {
            id: popupContent
            x: Metrics.paddingLarge
            y: workspacePopup.stemHeight + Metrics.paddingLarge
            width: parent.width - Metrics.paddingLarge * 2
            spacing: Metrics.paddingNormal

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
                spacing: Metrics.paddingSmall

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
}
