import QtQuick
import QtQuick.Layouts
import Quickshell
import Quickshell.Wayland
import "../theme"

// Workspace indicator showing squircles for each workspace.
// Active workspace is larger, shows number, and uses accent color.
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

    // Signal to switch workspace
    signal workspaceClicked(int idx)

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
                    cursorShape: Qt.PointingHandCursor

                    onClicked: {
                        root.workspaceClicked(indicator.workspaceIdx)
                    }
                }
            }
        }
    }
}
