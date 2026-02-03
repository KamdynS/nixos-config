pragma ComponentBehavior: Bound

import qs.services
import qs.config
import qs.components
import Quickshell
import QtQuick
import QtQuick.Layouts
import QtQuick.Effects

StyledClippingRect {
    id: root

    required property ShellScreen screen

    // Niri doesn't have special workspaces
    readonly property bool onSpecial: false

    // Filter workspaces to only this monitor's workspaces, sorted by idx (workspace number)
    readonly property var monitorWorkspaces: {
        const screenName = screen?.name ?? "";
        if (!screenName) return [];
        return Niri.workspaceList
            .filter(ws => ws.output === screenName)
            .sort((a, b) => a.idx - b.idx);
    }

    // Active workspace ID for this monitor - directly reference workspaceList for reactivity
    readonly property int activeWsId: {
        if (!Config.bar.workspaces.perMonitorWorkspaces) {
            return Niri.activeWsId;
        }
        const screenName = screen?.name ?? "";
        const activeWs = Niri.workspaceList.find(ws => ws.output === screenName && ws.is_active);
        return activeWs?.id ?? 1;
    }

    // Build occupied map for this monitor's workspaces
    readonly property var occupied: monitorWorkspaces.reduce((acc, ws) => {
        const hasWindows = Niri.windowList.some(w => w.workspace_id === ws.id);
        acc[ws.id] = hasWindows;
        return acc;
    }, {})

    property real blur: onSpecial ? 1 : 0

    implicitWidth: Config.bar.sizes.innerWidth
    implicitHeight: layout.implicitHeight + Appearance.padding.small * 2

    color: Colours.tPalette.m3surfaceContainer
    radius: Appearance.rounding.full

    Item {
        anchors.fill: parent
        scale: root.onSpecial ? 0.8 : 1
        opacity: root.onSpecial ? 0.5 : 1

        layer.enabled: root.blur > 0
        layer.effect: MultiEffect {
            blurEnabled: true
            blur: root.blur
            blurMax: 32
        }

        Loader {
            active: Config.bar.workspaces.occupiedBg

            anchors.fill: parent
            anchors.margins: Appearance.padding.small

            sourceComponent: OccupiedBg {
                workspaces: workspaces
                occupied: root.occupied
                monitorWorkspaces: root.monitorWorkspaces
            }
        }

        ColumnLayout {
            id: layout

            anchors.centerIn: parent
            spacing: Math.floor(Appearance.spacing.small / 2)

            Repeater {
                id: workspaces

                model: root.monitorWorkspaces

                Workspace {
                    required property var modelData
                    required property int index

                    workspace: modelData
                    activeWsId: root.activeWsId
                    occupied: root.occupied
                }
            }
        }

        Loader {
            anchors.horizontalCenter: parent.horizontalCenter
            active: Config.bar.workspaces.activeIndicator

            sourceComponent: ActiveIndicator {
                activeWsId: root.activeWsId
                workspaces: workspaces
                monitorWorkspaces: root.monitorWorkspaces
                mask: layout
            }
        }

        MouseArea {
            anchors.fill: layout
            onClicked: event => {
                // Find which workspace was clicked by checking y position
                const child = layout.childAt(event.x, event.y);
                if (child && child.isWorkspace) {
                    // Use wsId for comparison, wsIdx for focus (niri expects index)
                    if (root.activeWsId !== child.wsId)
                        Niri.focusWorkspace(child.wsIdx);
                }
            }
        }

        Behavior on scale {
            Anim {}
        }

        Behavior on opacity {
            Anim {}
        }
    }

    Loader {
        id: specialWs

        anchors.fill: parent
        anchors.margins: Appearance.padding.small

        active: opacity > 0

        scale: root.onSpecial ? 1 : 0.5
        opacity: root.onSpecial ? 1 : 0

        sourceComponent: SpecialWorkspaces {
            screen: root.screen
        }

        Behavior on scale {
            Anim {}
        }

        Behavior on opacity {
            Anim {}
        }
    }

    Behavior on blur {
        Anim {
            duration: Appearance.anim.durations.small
        }
    }
}
