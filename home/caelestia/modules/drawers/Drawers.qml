pragma ComponentBehavior: Bound

import qs.components
import qs.components.containers
import qs.services
import qs.config
import qs.modules.bar
import Quickshell
import Quickshell.Wayland
// Hyprland import removed for niri compatibility
import QtQuick
import QtQuick.Effects

Variants {
    model: Quickshell.screens

    Scope {
        id: scope

        required property ShellScreen modelData
        readonly property bool barDisabled: {
            const regexChecker = /^\^.*\$$/;
            for (const filter of Config.bar.excludedScreens) {
                // If filter is a regex
                if (regexChecker.test(filter)) {
                    if ((new RegExp(filter)).test(modelData.name))
                        return true;
                } else {
                    if (filter === modelData.name)
                        return true;
                }
            }
            return false;
        }

        Exclusions {
            screen: scope.modelData
            bar: bar
        }

        StyledWindow {
            id: win

            // Niri doesn't expose fullscreen state via IPC in the same way
            readonly property bool hasFullscreen: false
            readonly property int dragMaskPadding: {
                if (focusGrabActive || panels.popouts.isDetached)
                    return 0;

                // Check if current workspace has windows
                const mon = Niri.monitorFor(screen);
                const wsId = mon?.active_workspace_id;
                const hasWindows = Niri.windowList.some(w => w.workspace_id === wsId);
                if (hasWindows)
                    return 0;

                const thresholds = [];
                for (const panel of ["dashboard", "launcher", "session", "sidebar"])
                    if (Config[panel].enabled)
                        thresholds.push(Config[panel].dragThreshold);
                return Math.max(...thresholds);
            }

            // Focus grab state for niri (simpler than HyprlandFocusGrab)
            property bool focusGrabActive: (visibilities.launcher && Config.launcher.enabled) || (visibilities.session && Config.session.enabled) || (visibilities.sidebar && Config.sidebar.enabled) || (!Config.dashboard.showOnHover && visibilities.dashboard && Config.dashboard.enabled) || (panels.popouts.currentName.startsWith("traymenu") && panels.popouts.current?.depth > 1)

            onHasFullscreenChanged: {
                visibilities.launcher = false;
                visibilities.session = false;
                visibilities.dashboard = false;
            }

            screen: scope.modelData
            name: "drawers"
            WlrLayershell.exclusionMode: ExclusionMode.Ignore
            WlrLayershell.keyboardFocus: visibilities.launcher || visibilities.session ? WlrKeyboardFocus.OnDemand : WlrKeyboardFocus.None

            mask: Region {
                x: bar.implicitWidth + win.dragMaskPadding
                y: Config.border.thickness + win.dragMaskPadding
                width: win.width - bar.implicitWidth - Config.border.thickness - win.dragMaskPadding * 2
                height: win.height - Config.border.thickness * 2 - win.dragMaskPadding * 2
                intersection: Intersection.Xor

                regions: regions.instances
            }

            anchors.top: true
            anchors.bottom: true
            anchors.left: true
            anchors.right: true

            Variants {
                id: regions

                model: panels.children

                Region {
                    required property Item modelData

                    x: modelData.x + bar.implicitWidth
                    y: modelData.y + Config.border.thickness
                    width: modelData.width
                    height: modelData.height
                    intersection: Intersection.Combine
                }
            }

            // Click-away detection for closing popups (replaces HyprlandFocusGrab)
            MouseArea {
                id: focusGrab

                anchors.fill: parent
                visible: win.focusGrabActive
                z: -1  // Behind everything else

                onClicked: {
                    visibilities.launcher = false;
                    visibilities.session = false;
                    visibilities.sidebar = false;
                    visibilities.dashboard = false;
                    panels.popouts.hasCurrent = false;
                    bar.closeTray();
                }
            }

            StyledRect {
                anchors.fill: parent
                opacity: visibilities.session && Config.session.enabled ? 0.5 : 0
                color: Colours.palette.m3scrim

                Behavior on opacity {
                    Anim {}
                }
            }

            Item {
                anchors.fill: parent
                opacity: Colours.transparency.enabled ? Colours.transparency.base : 1
                layer.enabled: true
                layer.effect: MultiEffect {
                    shadowEnabled: true
                    blurMax: 15
                    shadowColor: Qt.alpha(Colours.palette.m3shadow, 0.7)
                }

                Border {
                    bar: bar
                }

                Backgrounds {
                    panels: panels
                    bar: bar
                }
            }

            PersistentProperties {
                id: visibilities

                property bool bar
                property bool osd
                property bool session
                property bool launcher
                property bool dashboard
                property bool utilities
                property bool sidebar

                Component.onCompleted: Visibilities.load(scope.modelData, this)
            }

            Interactions {
                screen: scope.modelData
                popouts: panels.popouts
                visibilities: visibilities
                panels: panels
                bar: bar

                Panels {
                    id: panels

                    screen: scope.modelData
                    visibilities: visibilities
                    bar: bar
                }

                BarWrapper {
                    id: bar

                    anchors.top: parent.top
                    anchors.bottom: parent.bottom

                    screen: scope.modelData
                    visibilities: visibilities
                    popouts: panels.popouts

                    disabled: scope.barDisabled

                    Component.onCompleted: Visibilities.bars.set(scope.modelData, this)
                }
            }
        }
    }
}
