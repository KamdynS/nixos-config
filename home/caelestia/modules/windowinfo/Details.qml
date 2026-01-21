import qs.components
import qs.services
import qs.config
// Hyprland import removed for niri compatibility
import QtQuick
import QtQuick.Layouts

ColumnLayout {
    id: root

    // Changed from HyprlandToplevel for niri compatibility
    required property var client

    anchors.fill: parent
    spacing: Appearance.spacing.small

    Label {
        Layout.topMargin: Appearance.padding.large * 2

        text: root.client?.title ?? qsTr("No active client")
        wrapMode: Text.WrapAtWordBoundaryOrAnywhere

        font.pointSize: Appearance.font.size.large
        font.weight: 500
    }

    Label {
        text: root.client?.app_id ?? qsTr("No active client")
        color: Colours.palette.m3tertiary

        font.pointSize: Appearance.font.size.larger
    }

    StyledRect {
        Layout.fillWidth: true
        Layout.preferredHeight: 1
        Layout.leftMargin: Appearance.padding.large * 2
        Layout.rightMargin: Appearance.padding.large * 2
        Layout.topMargin: Appearance.spacing.normal
        Layout.bottomMargin: Appearance.spacing.large

        color: Colours.palette.m3secondary
    }

    Detail {
        icon: "fingerprint"
        text: qsTr("Window ID: %1").arg(root.client?.id ?? "unknown")
        color: Colours.palette.m3primary
    }

    Detail {
        icon: "workspaces"
        text: qsTr("Workspace ID: %1").arg(root.client?.workspace_id ?? "unknown")
        color: Colours.palette.m3secondary
    }

    Detail {
        icon: "check_circle"
        text: qsTr("Focused: %1").arg(root.client?.is_focused ? "yes" : "no")
    }

    Detail {
        icon: "picture_in_picture_center"
        text: qsTr("Floating: %1").arg(root.client?.is_floating ? "yes" : "unknown")
        color: Colours.palette.m3tertiary
    }

    // Note: Niri provides less window metadata than Hyprland
    // Properties like position, size, pid, xwayland, pinned, fullscreen
    // are not exposed via niri's IPC

    Item {
        Layout.fillHeight: true
    }

    component Detail: RowLayout {
        id: detail

        required property string icon
        required property string text
        property alias color: icon.color

        Layout.leftMargin: Appearance.padding.large
        Layout.rightMargin: Appearance.padding.large
        Layout.fillWidth: true

        spacing: Appearance.spacing.smaller

        MaterialIcon {
            id: icon

            Layout.alignment: Qt.AlignVCenter
            text: detail.icon
        }

        StyledText {
            Layout.fillWidth: true
            Layout.alignment: Qt.AlignVCenter

            text: detail.text
            elide: Text.ElideRight
            font.pointSize: Appearance.font.size.normal
        }
    }

    component Label: StyledText {
        Layout.leftMargin: Appearance.padding.large
        Layout.rightMargin: Appearance.padding.large
        Layout.fillWidth: true
        elide: Text.ElideRight
        horizontalAlignment: Text.AlignHCenter
        animate: true
    }
}
