import Quickshell
import Quickshell.Wayland
import Quickshell.Io
import Quickshell.Services.SystemTray
import QtQuick
import QtQuick.Layouts
import "theme"

Scope {
    id: root

    required property var screen
    signal controlCenterToggled()

    property string currentTime: ""

    PanelWindow {
        id: panel
        screen: root.screen

        anchors {
            top: true
            left: true
            right: true
        }

        implicitHeight: 32
        color: "transparent"

        // Main bar background
        Rectangle {
            anchors.fill: parent
            anchors.margins: 4
            anchors.topMargin: 4
            anchors.bottomMargin: 0

            color: Gruvbox.panelBg
            radius: Gruvbox.radiusNormal

            RowLayout {
                anchors.fill: parent
                anchors.leftMargin: Gruvbox.paddingLarge
                anchors.rightMargin: Gruvbox.paddingLarge
                spacing: Gruvbox.paddingNormal

                // Left: Control center button
                Rectangle {
                    Layout.preferredWidth: 28
                    Layout.preferredHeight: 28
                    color: controlCenterMouse.containsMouse ? Gruvbox.hoverBg : "transparent"
                    radius: Gruvbox.radiusSmall

                    Text {
                        anchors.centerIn: parent
                        text: ""  // Nerd font icon for grid/apps
                        color: Gruvbox.fg
                        font.family: Gruvbox.fontFamily
                        font.pixelSize: Gruvbox.fontSizeNormal
                    }

                    MouseArea {
                        id: controlCenterMouse
                        anchors.fill: parent
                        hoverEnabled: true
                        onClicked: root.controlCenterToggled()
                    }
                }

                // Spacer
                Item { Layout.fillWidth: true }

                // Center: Clock
                Text {
                    text: root.currentTime
                    color: Gruvbox.fg
                    font.family: Gruvbox.fontFamily
                    font.pixelSize: Gruvbox.fontSizeNormal
                    font.bold: true
                }

                // Spacer
                Item { Layout.fillWidth: true }

                // Right: System tray
                RowLayout {
                    spacing: Gruvbox.paddingSmall

                    Repeater {
                        model: SystemTray.items

                        Rectangle {
                            required property SystemTrayItem modelData
                            Layout.preferredWidth: 24
                            Layout.preferredHeight: 24
                            color: trayMouse.containsMouse ? Gruvbox.hoverBg : "transparent"
                            radius: Gruvbox.radiusSmall

                            Image {
                                anchors.centerIn: parent
                                width: 18
                                height: 18
                                source: modelData.icon ? Quickshell.iconPath(modelData.icon) : ""
                                sourceSize: Qt.size(18, 18)
                            }

                            MouseArea {
                                id: trayMouse
                                anchors.fill: parent
                                hoverEnabled: true
                                acceptedButtons: Qt.LeftButton | Qt.RightButton

                                onClicked: (mouse) => {
                                    if (mouse.button === Qt.LeftButton) {
                                        modelData.activate()
                                    } else {
                                        modelData.secondaryActivate()
                                    }
                                }
                            }
                        }
                    }
                }
            }
        }
    }

    // Clock updater
    Process {
        id: clockProc
        command: ["date", "+%a %b %d  %H:%M"]
        running: true
        stdout: StdioCollector {
            onStreamFinished: {
                root.currentTime = this.text.trim()
            }
        }
    }

    Timer {
        interval: 1000
        running: true
        repeat: true
        onTriggered: clockProc.running = true
    }
}
