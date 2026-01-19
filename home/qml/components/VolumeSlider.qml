import QtQuick
import QtQuick.Layouts
import "../theme"

Rectangle {
    id: root

    property real value: 0.5
    property bool muted: false

    signal sliderMoved(real newValue)
    signal muteClicked()

    implicitHeight: 48
    color: Gruvbox.bg1
    radius: Gruvbox.radiusNormal

    RowLayout {
        anchors.fill: parent
        anchors.margins: Gruvbox.paddingNormal
        spacing: Gruvbox.paddingNormal

        // Mute button / volume icon
        Rectangle {
            Layout.preferredWidth: 32
            Layout.preferredHeight: 32
            color: muteMouse.containsMouse ? Gruvbox.hoverBg : "transparent"
            radius: Gruvbox.radiusSmall

            Text {
                anchors.centerIn: parent
                text: root.muted ? "" : (root.value > 0.5 ? "" : (root.value > 0 ? "" : ""))
                color: root.muted ? Gruvbox.fg4 : Gruvbox.fg
                font.family: Gruvbox.fontFamily
                font.pixelSize: Gruvbox.fontSizeLarge
            }

            MouseArea {
                id: muteMouse
                anchors.fill: parent
                hoverEnabled: true
                onClicked: root.muteClicked()
            }
        }

        // Slider track
        Item {
            Layout.fillWidth: true
            Layout.preferredHeight: 24

            // Track background
            Rectangle {
                anchors.verticalCenter: parent.verticalCenter
                width: parent.width
                height: 6
                radius: 3
                color: Gruvbox.sliderTrack

                // Fill
                Rectangle {
                    width: parent.width * root.value
                    height: parent.height
                    radius: parent.radius
                    color: root.muted ? Gruvbox.fg4 : Gruvbox.sliderFill
                }
            }

            // Knob
            Rectangle {
                x: (parent.width - width) * root.value
                anchors.verticalCenter: parent.verticalCenter
                width: 14
                height: 14
                radius: 7
                color: sliderMouse.pressed ? Gruvbox.accentBright : Gruvbox.fg
                visible: !root.muted

                Behavior on x {
                    NumberAnimation { duration: 50 }
                }
            }

            MouseArea {
                id: sliderMouse
                anchors.fill: parent
                hoverEnabled: true

                onPressed: (mouse) => updateValue(mouse)
                onPositionChanged: (mouse) => {
                    if (pressed) updateValue(mouse)
                }

                function updateValue(mouse) {
                    let newValue = Math.max(0, Math.min(1, mouse.x / width))
                    root.sliderMoved(newValue)
                }
            }
        }

        // Percentage
        Text {
            Layout.preferredWidth: 40
            text: Math.round(root.value * 100) + "%"
            color: root.muted ? Gruvbox.fg4 : Gruvbox.fg
            font.family: Gruvbox.fontFamily
            font.pixelSize: Gruvbox.fontSizeSmall
            horizontalAlignment: Text.AlignRight
        }
    }
}
