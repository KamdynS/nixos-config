import qs.components
import qs.components.effects
import qs.services
import qs.config
import QtQuick

StyledRect {
    id: root

    required property int activeWsId
    required property Repeater workspaces
    required property var monitorWorkspaces
    required property Item mask

    // Find index of active workspace in the filtered monitor workspaces
    // Returns -1 if the active workspace is not on this monitor
    readonly property int currentWsIdx: {
        if (!monitorWorkspaces) return -1;
        return monitorWorkspaces.findIndex(ws => ws.id === activeWsId);
    }

    // Only show the indicator if the active workspace is on this monitor
    readonly property bool isActiveOnThisMonitor: currentWsIdx >= 0

    property real leading: workspaces.count > 0 && isActiveOnThisMonitor ? workspaces.itemAt(currentWsIdx)?.y ?? 0 : 0
    property real trailing: workspaces.count > 0 && isActiveOnThisMonitor ? workspaces.itemAt(currentWsIdx)?.y ?? 0 : 0
    property real currentSize: workspaces.count > 0 && isActiveOnThisMonitor ? workspaces.itemAt(currentWsIdx)?.size ?? 0 : 0
    property real offset: Math.min(leading, trailing)
    property real size: {
        const s = Math.abs(leading - trailing) + currentSize;
        if (Config.bar.workspaces.activeTrail && lastWs > currentWsIdx) {
            const ws = workspaces.itemAt(lastWs);
            // console.log(ws, lastWs);
            return ws ? Math.min(ws.y + ws.size - offset, s) : 0;
        }
        return s;
    }

    property int cWs
    property int lastWs

    onCurrentWsIdxChanged: {
        lastWs = cWs;
        cWs = currentWsIdx;
    }

    clip: true
    visible: isActiveOnThisMonitor
    y: offset + mask.y
    implicitWidth: Config.bar.sizes.innerWidth - Appearance.padding.small * 2
    implicitHeight: size
    radius: Appearance.rounding.full
    color: Colours.palette.m3primary

    Colouriser {
        source: root.mask
        sourceColor: Colours.palette.m3onSurface
        colorizationColor: Colours.palette.m3onPrimary

        x: 0
        y: -parent.offset
        implicitWidth: root.mask.implicitWidth
        implicitHeight: root.mask.implicitHeight

        anchors.horizontalCenter: parent.horizontalCenter
    }

    Behavior on leading {
        enabled: Config.bar.workspaces.activeTrail

        EAnim {}
    }

    Behavior on trailing {
        enabled: Config.bar.workspaces.activeTrail

        EAnim {
            duration: Appearance.anim.durations.normal * 2
        }
    }

    Behavior on currentSize {
        enabled: Config.bar.workspaces.activeTrail

        EAnim {}
    }

    Behavior on offset {
        enabled: !Config.bar.workspaces.activeTrail

        EAnim {}
    }

    Behavior on size {
        enabled: !Config.bar.workspaces.activeTrail

        EAnim {}
    }

    component EAnim: Anim {
        easing.bezierCurve: Appearance.anim.curves.emphasized
    }
}
