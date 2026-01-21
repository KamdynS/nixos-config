pragma ComponentBehavior: Bound

import qs.components
import qs.services
import qs.config
import Quickshell
import Quickshell.Wayland
// Hyprland import removed for niri compatibility
import QtQuick
import QtQuick.Layouts

Item {
    id: root

    required property ShellScreen screen
    required property var client  // Changed from HyprlandToplevel for niri compatibility

    Layout.preferredWidth: preview.implicitWidth + Appearance.padding.large * 2
    Layout.fillHeight: true

    StyledClippingRect {
        id: preview

        anchors.horizontalCenter: parent.horizontalCenter
        anchors.top: parent.top
        anchors.bottom: label.top
        anchors.topMargin: Appearance.padding.large
        anchors.bottomMargin: Appearance.spacing.normal

        implicitWidth: parent.height * (root.screen.width / root.screen.height)

        color: Colours.tPalette.m3surfaceContainer
        radius: Appearance.rounding.small

        // Preview disabled for niri - would need wayland toplevel access
        ColumnLayout {
            anchors.centerIn: parent
            visible: !root.client
            spacing: 0

            MaterialIcon {
                Layout.alignment: Qt.AlignHCenter
                text: "web_asset_off"
                color: Colours.palette.m3outline
                font.pointSize: Appearance.font.size.extraLarge * 3
            }

            StyledText {
                Layout.alignment: Qt.AlignHCenter
                text: qsTr("No active client")
                color: Colours.palette.m3outline
                font.pointSize: Appearance.font.size.extraLarge
                font.weight: 500
            }

            StyledText {
                Layout.alignment: Qt.AlignHCenter
                text: qsTr("Try switching to a window")
                color: Colours.palette.m3outline
                font.pointSize: Appearance.font.size.large
            }
        }

        // Show placeholder when there is a client (preview not available on niri)
        ColumnLayout {
            anchors.centerIn: parent
            visible: root.client
            spacing: 0

            MaterialIcon {
                Layout.alignment: Qt.AlignHCenter
                text: "preview"
                color: Colours.palette.m3outline
                font.pointSize: Appearance.font.size.extraLarge * 3
            }

            StyledText {
                Layout.alignment: Qt.AlignHCenter
                text: qsTr("Preview unavailable")
                color: Colours.palette.m3outline
                font.pointSize: Appearance.font.size.large
            }

            StyledText {
                Layout.alignment: Qt.AlignHCenter
                text: qsTr("Not supported on niri")
                color: Colours.palette.m3outline
                font.pointSize: Appearance.font.size.normal
            }
        }
    }

    StyledText {
        id: label

        anchors.horizontalCenter: parent.horizontalCenter
        anchors.bottom: parent.bottom
        anchors.bottomMargin: Appearance.padding.large

        animate: true
        text: {
            const client = root.client;
            if (!client)
                return qsTr("No active client");

            return qsTr("%1 (Workspace %2)").arg(client.title ?? "Unknown").arg(client.workspace_id ?? "?");
        }
    }
}
