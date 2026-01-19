import Quickshell
import Quickshell.Wayland
import QtQuick
import QtQuick.Layouts
import "theme"
import "components"

Scope {
    id: root

    required property var screen
    required property bool visible
    required property real volume
    required property bool muted
    required property real brightness
    required property string wifiNetwork
    required property bool wifiEnabled

    signal closeRequested()
    signal volumeChanged(real value)
    signal mutedChanged(bool value)
    signal brightnessChanged(real value)
    signal wifiToggled()

    PanelWindow {
        id: panel
        screen: root.screen
        visible: root.visible

        // Position: top-left, below the bar
        anchors {
            top: true
            left: true
        }

        margins {
            top: 40  // Below bar
            left: 8
        }

        implicitWidth: 320
        implicitHeight: contentColumn.implicitHeight + 24
        color: "transparent"

        WlrLayershell.namespace: "quickshell-control-center"
        WlrLayershell.layer: WlrLayer.Overlay
        WlrLayershell.keyboardFocus: WlrKeyboardFocus.OnDemand

        // Click outside to close
        MouseArea {
            anchors.fill: parent
            onClicked: {} // absorb clicks on panel
        }

        // Background
        Rectangle {
            anchors.fill: parent
            color: Gruvbox.panelBg
            radius: Gruvbox.radiusLarge
            border.color: Gruvbox.panelBorder
            border.width: 1

            // Content
            ColumnLayout {
                id: contentColumn
                anchors.fill: parent
                anchors.margins: Gruvbox.paddingLarge
                spacing: Gruvbox.paddingNormal

                // Header
                RowLayout {
                    Layout.fillWidth: true
                    spacing: Gruvbox.paddingNormal

                    Text {
                        text: "Quick Settings"
                        color: Gruvbox.fg
                        font.family: Gruvbox.fontFamily
                        font.pixelSize: Gruvbox.fontSizeLarge
                        font.bold: true
                    }

                    Item { Layout.fillWidth: true }

                    // Close button
                    Rectangle {
                        Layout.preferredWidth: 24
                        Layout.preferredHeight: 24
                        color: closeMouse.containsMouse ? Gruvbox.hoverBg : "transparent"
                        radius: Gruvbox.radiusSmall

                        Text {
                            anchors.centerIn: parent
                            text: ""
                            color: Gruvbox.fg4
                            font.family: Gruvbox.fontFamily
                            font.pixelSize: Gruvbox.fontSizeNormal
                        }

                        MouseArea {
                            id: closeMouse
                            anchors.fill: parent
                            hoverEnabled: true
                            onClicked: root.closeRequested()
                        }
                    }
                }

                // Separator
                Rectangle {
                    Layout.fillWidth: true
                    Layout.preferredHeight: 1
                    color: Gruvbox.bg3
                }

                // Quick toggles row
                RowLayout {
                    Layout.fillWidth: true
                    spacing: Gruvbox.paddingNormal

                    QuickToggle {
                        Layout.fillWidth: true
                        icon: root.wifiEnabled ? "" : ""
                        label: "WiFi"
                        sublabel: root.wifiEnabled ? root.wifiNetwork : "Off"
                        active: root.wifiEnabled
                        onClicked: root.wifiToggled()
                    }

                    QuickToggle {
                        Layout.fillWidth: true
                        icon: ""
                        label: "Bluetooth"
                        sublabel: "Off"
                        active: false
                        onClicked: {} // TODO: implement
                    }

                    QuickToggle {
                        Layout.fillWidth: true
                        icon: ""
                        label: "DND"
                        sublabel: "Off"
                        active: false
                        onClicked: {} // TODO: implement
                    }
                }

                // Volume slider
                VolumeSlider {
                    Layout.fillWidth: true
                    value: root.volume
                    muted: root.muted
                    onValueChanged: (v) => root.volumeChanged(v)
                    onMuteClicked: root.mutedChanged(!root.muted)
                }

                // Brightness slider
                BrightnessSlider {
                    Layout.fillWidth: true
                    value: root.brightness
                    onValueChanged: (v) => root.brightnessChanged(v)
                }

                // Separator
                Rectangle {
                    Layout.fillWidth: true
                    Layout.preferredHeight: 1
                    color: Gruvbox.bg3
                }

                // Power buttons
                RowLayout {
                    Layout.fillWidth: true
                    spacing: Gruvbox.paddingNormal

                    PowerButton {
                        Layout.fillWidth: true
                        icon: ""
                        label: "Lock"
                        command: ["swaylock"]
                    }

                    PowerButton {
                        Layout.fillWidth: true
                        icon: ""
                        label: "Logout"
                        command: ["niri", "msg", "action", "quit"]
                    }

                    PowerButton {
                        Layout.fillWidth: true
                        icon: ""
                        label: "Reboot"
                        command: ["systemctl", "reboot"]
                    }

                    PowerButton {
                        Layout.fillWidth: true
                        icon: ""
                        label: "Power"
                        command: ["systemctl", "poweroff"]
                    }
                }
            }
        }
    }

    // Power button component (inline since it's simple)
    component PowerButton: Rectangle {
        property string icon
        property string label
        property var command

        implicitHeight: 56
        color: powerMouse.containsMouse ? Gruvbox.hoverBg : Gruvbox.bg1
        radius: Gruvbox.radiusNormal

        ColumnLayout {
            anchors.centerIn: parent
            spacing: 4

            Text {
                Layout.alignment: Qt.AlignHCenter
                text: icon
                color: Gruvbox.fg
                font.family: Gruvbox.fontFamily
                font.pixelSize: Gruvbox.fontSizeLarge
            }

            Text {
                Layout.alignment: Qt.AlignHCenter
                text: label
                color: Gruvbox.fg3
                font.family: Gruvbox.fontFamily
                font.pixelSize: Gruvbox.fontSizeSmall
            }
        }

        MouseArea {
            id: powerMouse
            anchors.fill: parent
            hoverEnabled: true
            onClicked: {
                root.closeRequested()
                Quickshell.exec(command)
            }
        }
    }
}
