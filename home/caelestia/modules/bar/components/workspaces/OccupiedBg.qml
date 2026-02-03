pragma ComponentBehavior: Bound

import qs.components
import qs.services
import qs.config
import Quickshell
import QtQuick

Item {
    id: root

    required property Repeater workspaces
    required property var occupied
    required property var monitorWorkspaces

    property list<var> pills: []

    onOccupiedChanged: {
        if (!occupied || !monitorWorkspaces) return;
        let count = 0;

        // Iterate through monitor workspaces by index to find contiguous occupied groups
        for (let i = 0; i < monitorWorkspaces.length; i++) {
            const ws = monitorWorkspaces[i];
            const wsId = ws.id;
            const isOccupied = occupied[wsId] ?? false;

            if (isOccupied) {
                const prevWs = i > 0 ? monitorWorkspaces[i - 1] : null;
                const nextWs = i < monitorWorkspaces.length - 1 ? monitorWorkspaces[i + 1] : null;
                const prevOccupied = prevWs ? (occupied[prevWs.id] ?? false) : false;
                const nextOccupied = nextWs ? (occupied[nextWs.id] ?? false) : false;

                // Start of a new contiguous group
                if (!prevOccupied) {
                    if (pills[count])
                        pills[count].start = i;
                    else
                        pills.push(pillComp.createObject(root, { start: i }));
                    count++;
                }
                // End of contiguous group
                if (!nextOccupied && pills[count - 1])
                    pills[count - 1].end = i;
            }
        }
        if (pills.length > count)
            pills.splice(count, pills.length - count).forEach(p => p.destroy());
    }

    Repeater {
        model: ScriptModel {
            values: root.pills.filter(p => p)
        }

        StyledRect {
            id: rect

            required property var modelData

            // modelData.start and modelData.end are now indices into the Repeater
            readonly property Workspace start: root.workspaces.count > 0 ? root.workspaces.itemAt(modelData.start) ?? null : null
            readonly property Workspace end: root.workspaces.count > 0 ? root.workspaces.itemAt(modelData.end) ?? null : null

            anchors.horizontalCenter: root.horizontalCenter

            y: (start?.y ?? 0) - 1
            implicitWidth: Config.bar.sizes.innerWidth - Appearance.padding.small * 2 + 2
            implicitHeight: start && end ? end.y + end.size - start.y + 2 : 0

            color: Colours.layer(Colours.palette.m3surfaceContainerHigh, 2)
            radius: Appearance.rounding.full

            scale: 0
            Component.onCompleted: scale = 1

            Behavior on scale {
                Anim {
                    easing.bezierCurve: Appearance.anim.curves.standardDecel
                }
            }

            Behavior on y {
                Anim {}
            }

            Behavior on implicitHeight {
                Anim {}
            }
        }
    }

    component Pill: QtObject {
        property int start
        property int end
    }

    Component {
        id: pillComp

        Pill {}
    }
}
