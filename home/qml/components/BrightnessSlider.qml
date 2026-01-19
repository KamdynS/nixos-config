import QtQuick
import QtQuick.Layouts
import "../theme"

Rectangle {
    id: root

    property real value: 1.0

    signal valueChanged(real value)

    implicitHeight: 48
    color: Gruvbox.bg1
    radius: Gruvbox.radiusNormal

    RowLayout {
        anchors.fill: parent
        anchors.margins: Gruvbox.paddingNormal
        spacing: Gruvbox.paddingNormal

        // Brightness icon
        Rectangle {
            Layout.preferredWidth: 32
            Layout.preferredHeight: 32
            color: "transparent"

            Text {
                anchors.centerIn: parent
                text: root.value > 0.5 ? "" : ""
                color: Gruvbox.fg
                font.family: Gruvbox.fontFamily
                font.pixelSize: Gruvbox.fontSizeLarge
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
                    color: Gruvbox.sliderFill
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
                    let newValue = Math.max(0.05, Math.min(1, mouse.x / width))  // Min 5% brightness
                    root.valueChanged(newValue)
                }
            }
        }

        // Percentage
        Text {
            Layout.preferredWidth: 40
            text: Math.round(root.value * 100) + "%"
            color: Gruvbox.fg
            font.family: Gruvbox.fontFamily
            font.pixelSize: Gruvbox.fontSizeSmall
            horizontalAlignment: Text.AlignRight
        }
    }
}
