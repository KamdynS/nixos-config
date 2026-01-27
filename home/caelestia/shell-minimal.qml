//@ pragma Env QS_NO_RELOAD_POPUP=1
//@ pragma Env QSG_RENDER_LOOP=threaded
//@ pragma Env QT_QUICK_FLICKABLE_WHEEL_DECELERATION=10000

import "stubs" as Stubs
import "services"
import Quickshell
import Quickshell.Wayland
import QtQuick

ShellRoot {
    id: root

    // Access our static theme
    readonly property var theme: Stubs.Theme

    // Simple bar on each screen
    Variants {
        model: Quickshell.screens

        PanelWindow {
            id: panel

            required property ShellScreen modelData
            property var niri: Niri

            screen: modelData

            // Layer shell config
            WlrLayershell.layer: WlrLayer.Top
            WlrLayershell.namespace: "niri-shell-bar"

            // Left edge vertical bar
            anchors {
                left: true
                top: true
                bottom: true
            }
            width: 48
            color: root.theme.surface

            // Top section - Logo and Workspaces
            Column {
                id: topSection
                anchors.top: parent.top
                anchors.left: parent.left
                anchors.right: parent.right
                anchors.margins: 4
                spacing: 8

                // Logo/top icon
                Rectangle {
                    width: 40
                    height: 40
                    radius: 8
                    color: root.theme.primaryContainer
                    anchors.horizontalCenter: parent.horizontalCenter

                    Text {
                        anchors.centerIn: parent
                        text: "N"
                        font.pixelSize: 20
                        font.bold: true
                        color: root.theme.onPrimaryContainer
                    }
                }

                // Spacer
                Item { width: 1; height: 8 }

                // Workspaces
                Column {
                    spacing: 4
                    anchors.horizontalCenter: parent.horizontalCenter

                    Repeater {
                        model: panel.niri.workspaceList

                        Rectangle {
                            required property var modelData
                            property bool isActive: modelData.is_focused
                            property bool hasWindows: modelData.active_window_id !== null

                            width: 32
                            height: 32
                            radius: 6
                            color: isActive ? root.theme.primary : (hasWindows ? root.theme.surfaceContainerHigh : root.theme.surfaceVariant)

                            Text {
                                anchors.centerIn: parent
                                text: modelData.idx ?? modelData.id
                                font.pixelSize: 14
                                font.bold: isActive
                                color: isActive ? root.theme.onPrimary : root.theme.onSurface
                            }

                            MouseArea {
                                anchors.fill: parent
                                onClicked: panel.niri.focusWorkspace(modelData.id)
                            }
                        }
                    }
                }
            }

            // Bottom section - Clock
            Column {
                anchors.horizontalCenter: parent.horizontalCenter
                anchors.bottom: parent.bottom
                anchors.bottomMargin: 8

                // Clock - vertical style
                Text {
                    id: clockText
                    anchors.horizontalCenter: parent.horizontalCenter
                    text: Qt.formatTime(new Date(), "hh")
                    font.pixelSize: 18
                    font.bold: true
                    color: root.theme.onSurface
                }

                Text {
                    id: clockMinutes
                    anchors.horizontalCenter: parent.horizontalCenter
                    text: Qt.formatTime(new Date(), "mm")
                    font.pixelSize: 18
                    color: root.theme.onSurfaceVariant
                }
            }

            // Clock update timer
            Timer {
                interval: 1000
                running: true
                repeat: true
                onTriggered: {
                    var now = new Date();
                    clockText.text = Qt.formatTime(now, "hh");
                    clockMinutes.text = Qt.formatTime(now, "mm");
                }
            }
        }
    }
}
