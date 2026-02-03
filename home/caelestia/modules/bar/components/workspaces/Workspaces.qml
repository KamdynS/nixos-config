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

    // All workspaces sorted globally: by output name, then by idx
    // This gives consistent ordering like: DP-3:1, DP-3:2, HDMI-A-1:1, HDMI-A-1:2
    readonly property var globalWorkspaces: {
        return Niri.workspaceList
            .slice() // copy to avoid mutating original
            .sort((a, b) => {
                if (a.output !== b.output) return a.output.localeCompare(b.output);
                return a.idx - b.idx;
            });
    }

    // Map workspace id -> global index (1-based)
    readonly property var globalIndexMap: {
        const map = {};
        globalWorkspaces.forEach((ws, i) => {
            map[ws.id] = i + 1; // 1-based indexing
        });
        return map;
    }

    // For per-monitor mode, filter to this screen only
    readonly property var monitorWorkspaces: {
        if (!Config.bar.workspaces.perMonitorWorkspaces) {
            return globalWorkspaces;
        }
        const screenName = screen?.name ?? "";
        if (!screenName) return [];
        return globalWorkspaces.filter(ws => ws.output === screenName);
    }

    // Active workspace ID - always use the globally focused one
    readonly property int activeWsId: Niri.activeWsId

    // Build occupied map for displayed workspaces
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
                    globalIdx: root.globalIndexMap[modelData.id] ?? (index + 1)
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
                    // Use focusWorkspaceById to support cross-monitor navigation
                    if (root.activeWsId !== child.wsId)
                        Niri.focusWorkspaceById(child.wsId);
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
