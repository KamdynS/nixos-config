import qs.components
import qs.services
import qs.utils
import qs.config
import Quickshell
import QtQuick
import QtQuick.Layouts

ColumnLayout {
    id: root

    required property var workspace
    required property int activeWsId
    required property var occupied
    property int globalIdx: workspace?.idx ?? 1  // Global sequential number for display

    readonly property bool isWorkspace: true // Flag for finding workspace children
    // Unanimated prop for others to use as reference
    readonly property int size: implicitHeight + (hasWindows ? Appearance.padding.small : 0)

    // Use the workspace's global ID for identification and navigation
    readonly property int wsId: workspace?.id ?? 1
    // Use the workspace's idx (per-monitor index, kept for compatibility)
    readonly property int wsIdx: workspace?.idx ?? 1
    readonly property bool isOccupied: occupied[wsId] ?? false
    readonly property bool hasWindows: isOccupied && Config.bar.workspaces.showWindows

    Layout.alignment: Qt.AlignHCenter
    Layout.preferredHeight: size

    spacing: 0

    Rectangle {
        id: indicator

        readonly property bool isActive: root.activeWsId === root.wsId
        readonly property int circleSize: Config.bar.sizes.innerWidth - Appearance.padding.small * 2

        // Normal state colors - subtle surface for inactive workspaces
        readonly property color normalBgColor: Colours.palette.m3surfaceContainerHigh
        readonly property color normalTextColor: Colours.palette.m3onSurfaceVariant

        // Active state colors - primary accent for current workspace
        readonly property color activeBgColor: Colours.palette.m3primary
        readonly property color activeTextColor: Colours.palette.m3onPrimary

        // Hovered state: slightly more prominent surface
        readonly property color hoveredBgColor: Colours.palette.m3surfaceContainerHighest
        readonly property color hoveredTextColor: Colours.palette.m3onSurface

        Layout.alignment: Qt.AlignHCenter | Qt.AlignTop
        Layout.preferredWidth: circleSize
        Layout.preferredHeight: circleSize

        radius: circleSize / 2
        color: isActive ? activeBgColor : (hoverArea.containsMouse ? hoveredBgColor : normalBgColor)
        border.width: 0

        Text {
            anchors.centerIn: parent
            text: root.globalIdx.toString()
            renderType: Text.NativeRendering
            font.family: Appearance.font.family.sans
            font.pixelSize: parent.circleSize * 0.55
            font.weight: Font.Medium
            color: indicator.isActive ? indicator.activeTextColor : (hoverArea.containsMouse ? indicator.hoveredTextColor : indicator.normalTextColor)
        }

        MouseArea {
            id: hoverArea
            anchors.fill: parent
            hoverEnabled: true
            acceptedButtons: Qt.NoButton  // Let clicks pass through to parent MouseArea
        }

        Behavior on color {
            ColorAnimation { duration: Appearance.anim.durations.normal }
        }
        Behavior on border.color {
            ColorAnimation { duration: Appearance.anim.durations.normal }
        }
    }

    Loader {
        id: windows

        Layout.alignment: Qt.AlignHCenter
        Layout.fillHeight: true
        Layout.topMargin: -Config.bar.sizes.innerWidth / 10

        visible: active
        active: root.hasWindows

        sourceComponent: Column {
            spacing: 0

            add: Transition {
                Anim {
                    properties: "scale"
                    from: 0
                    to: 1
                    easing.bezierCurve: Appearance.anim.curves.standardDecel
                }
            }

            move: Transition {
                Anim {
                    properties: "scale"
                    to: 1
                    easing.bezierCurve: Appearance.anim.curves.standardDecel
                }
                Anim {
                    properties: "x,y"
                }
            }

            Repeater {
                model: ScriptModel {
                    values: Niri.toplevels.values.filter(c => c.workspace_id === root.wsId)
                }

                MaterialIcon {
                    required property var modelData

                    grade: 0
                    text: Icons.getAppCategoryIcon(modelData.app_id ?? "", "terminal")
                    color: Colours.palette.m3onSurfaceVariant
                }
            }
        }
    }

    Behavior on Layout.preferredHeight {
        Anim {}
    }
}
