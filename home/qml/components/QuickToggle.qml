import QtQuick
import QtQuick.Layouts
import "../theme"

Rectangle {
    id: root

    property string icon
    property string label
    property string sublabel
    property bool active: false

    signal clicked()

    implicitHeight: 72
    color: mouse.containsMouse ? Gruvbox.hoverBg : (active ? Gruvbox.bg2 : Gruvbox.bg1)
    radius: Layout.radiusNormal

    border.color: active ? Gruvbox.accent : "transparent"
    border.width: active ? 1 : 0

    ColumnLayout {
        anchors.centerIn: parent
        spacing: 4

        Text {
            Layout.alignment: Qt.AlignHCenter
            text: root.icon
            color: root.active ? Gruvbox.accent : Gruvbox.fg
            font.family: Layout.fontFamily
            font.pixelSize: 20
        }

        Text {
            Layout.alignment: Qt.AlignHCenter
            text: root.label
            color: root.active ? Gruvbox.fg : Gruvbox.fg2
            font.family: Layout.fontFamily
            font.pixelSize: Layout.fontSizeSmall
            font.bold: true
        }

        Text {
            Layout.alignment: Qt.AlignHCenter
            text: root.sublabel
            color: Gruvbox.fg4
            font.family: Layout.fontFamily
            font.pixelSize: 10
            elide: Text.ElideRight
            Layout.maximumWidth: parent.width - 8
        }
    }

    MouseArea {
        id: mouse
        anchors.fill: parent
        hoverEnabled: true
        onClicked: root.clicked()
    }
}
