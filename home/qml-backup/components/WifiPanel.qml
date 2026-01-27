import QtQuick
import QtQuick.Layouts
import "../theme"

// Placeholder for WiFi network selector
// Can be expanded to show network list when clicking WiFi toggle

Rectangle {
    id: root

    property bool enabled: true
    property string currentNetwork: ""
    property var networks: []

    signal networkSelected(string ssid)
    signal refreshRequested()

    implicitHeight: networkList.implicitHeight + 48
    color: Gruvbox.bg1
    radius: Gruvbox.radiusNormal

    ColumnLayout {
        id: networkList
        anchors.fill: parent
        anchors.margins: Gruvbox.paddingNormal
        spacing: Gruvbox.paddingSmall

        // Header
        RowLayout {
            Layout.fillWidth: true

            Text {
                text: "WiFi Networks"
                color: Gruvbox.fg
                font.family: Gruvbox.fontFamily
                font.pixelSize: Gruvbox.fontSizeNormal
                font.bold: true
            }

            Item { Layout.fillWidth: true }

            // Refresh button
            Rectangle {
                Layout.preferredWidth: 24
                Layout.preferredHeight: 24
                color: refreshMouse.containsMouse ? Gruvbox.hoverBg : "transparent"
                radius: Gruvbox.radiusSmall

                Text {
                    anchors.centerIn: parent
                    text: ""
                    color: Gruvbox.fg4
                    font.family: Gruvbox.fontFamily
                    font.pixelSize: Gruvbox.fontSizeNormal
                }

                MouseArea {
                    id: refreshMouse
                    anchors.fill: parent
                    hoverEnabled: true
                    onClicked: root.refreshRequested()
                }
            }
        }

        // Network list
        Repeater {
            model: root.networks

            Rectangle {
                required property var modelData
                Layout.fillWidth: true
                implicitHeight: 36
                color: netMouse.containsMouse ? Gruvbox.hoverBg : "transparent"
                radius: Gruvbox.radiusSmall

                RowLayout {
                    anchors.fill: parent
                    anchors.margins: Gruvbox.paddingSmall

                    Text {
                        text: ""
                        color: modelData.ssid === root.currentNetwork ? Gruvbox.accent : Gruvbox.fg4
                        font.family: Gruvbox.fontFamily
                        font.pixelSize: Gruvbox.fontSizeNormal
                    }

                    Text {
                        Layout.fillWidth: true
                        text: modelData.ssid
                        color: modelData.ssid === root.currentNetwork ? Gruvbox.fg : Gruvbox.fg2
                        font.family: Gruvbox.fontFamily
                        font.pixelSize: Gruvbox.fontSizeSmall
                        font.bold: modelData.ssid === root.currentNetwork
                        elide: Text.ElideRight
                    }

                    // Signal strength indicator
                    Text {
                        text: modelData.signal > 75 ? "" : (modelData.signal > 50 ? "" : "")
                        color: Gruvbox.fg4
                        font.family: Gruvbox.fontFamily
                        font.pixelSize: Gruvbox.fontSizeSmall
                    }
                }

                MouseArea {
                    id: netMouse
                    anchors.fill: parent
                    hoverEnabled: true
                    onClicked: root.networkSelected(modelData.ssid)
                }
            }
        }

        // Empty state
        Text {
            visible: root.networks.length === 0
            text: root.enabled ? "Scanning..." : "WiFi disabled"
            color: Gruvbox.fg4
            font.family: Gruvbox.fontFamily
            font.pixelSize: Gruvbox.fontSizeSmall
            Layout.alignment: Qt.AlignHCenter
        }
    }
}
