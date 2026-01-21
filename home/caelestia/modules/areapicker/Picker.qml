pragma ComponentBehavior: Bound

import qs.components
import qs.services
import qs.config
import Quickshell
import Quickshell.Wayland
import QtQuick
import QtQuick.Effects

// Area picker for screenshots
// Note: Client window detection is disabled for niri as it requires
// window position/size data not available via niri's IPC
MouseArea {
    id: root

    required property LazyLoader loader
    required property ShellScreen screen

    property bool onClient: false

    // Fixed values since Hypr.options is not available
    property real realBorderWidth: 2
    property real realRounding: 12  // Match niri config

    property real ssx
    property real ssy

    property real sx: 0
    property real sy: 0
    property real ex: screen.width
    property real ey: screen.height

    property real rsx: Math.min(sx, ex)
    property real rsy: Math.min(sy, ey)
    property real sw: Math.abs(sx - ex)
    property real sh: Math.abs(sy - ey)

    // Window-based selection disabled for niri
    property list<var> clients: []

    function checkClientRects(x: real, y: real): void {
        // Disabled for niri - no window position data available
        onClient = false;
    }

    function save(): void {
        const tmpfile = Qt.resolvedUrl(`/tmp/caelestia-picker-${Quickshell.processId}-${Date.now()}.png`);
        // Note: CUtils may need the Caelestia plugin - fallback to grim if needed
        try {
            CUtils.saveItem(screencopy, tmpfile, Qt.rect(Math.ceil(rsx), Math.ceil(rsy), Math.floor(sw), Math.floor(sh)), path => {
                if (root.loader.clipboardOnly) {
                    Quickshell.execDetached(["sh", "-c", "wl-copy --type image/png < " + path]);
                    Quickshell.execDetached(["notify-send", "-a", "caelestia-cli", "-i", path, "Screenshot taken", "Screenshot copied to clipboard"]);
                } else {
                    Quickshell.execDetached(["swappy", "-f", path]);
                }
            });
        } catch (e) {
            console.error("Screenshot save failed:", e);
        }
        closeAnim.start();
    }

    anchors.fill: parent
    opacity: 0
    hoverEnabled: true
    cursorShape: Qt.CrossCursor

    Component.onCompleted: {
        opacity = 1;

        // Initialize with a default region in the center
        sx = screen.width / 2 - 100;
        sy = screen.height / 2 - 100;
        ex = screen.width / 2 + 100;
        ey = screen.height / 2 + 100;
    }

    onPressed: event => {
        ssx = event.x;
        ssy = event.y;
    }

    onReleased: {
        if (closeAnim.running)
            return;

        if (root.loader.freeze) {
            save();
        } else {
            overlay.visible = border.visible = false;
            screencopy.visible = false;
            screencopy.active = true;
        }
    }

    onPositionChanged: event => {
        const x = event.x;
        const y = event.y;

        if (pressed) {
            onClient = false;
            sx = ssx;
            sy = ssy;
            ex = x;
            ey = y;
        }
    }

    focus: true
    Keys.onEscapePressed: closeAnim.start()

    SequentialAnimation {
        id: closeAnim

        PropertyAction {
            target: root.loader
            property: "closing"
            value: true
        }
        ParallelAnimation {
            Anim {
                target: root
                property: "opacity"
                to: 0
                duration: Appearance.anim.durations.large
            }
            ExAnim {
                target: root
                properties: "rsx,rsy"
                to: 0
            }
            ExAnim {
                target: root
                property: "sw"
                to: root.screen.width
            }
            ExAnim {
                target: root
                property: "sh"
                to: root.screen.height
            }
        }
        PropertyAction {
            target: root.loader
            property: "activeAsync"
            value: false
        }
    }

    Loader {
        id: screencopy

        anchors.fill: parent

        active: root.loader.freeze

        sourceComponent: ScreencopyView {
            captureSource: root.screen

            onHasContentChanged: {
                if (hasContent && !root.loader.freeze) {
                    overlay.visible = border.visible = true;
                    root.save();
                }
            }
        }
    }

    StyledRect {
        id: overlay

        anchors.fill: parent
        color: Colours.palette.m3secondaryContainer
        opacity: 0.3

        layer.enabled: true
        layer.effect: MultiEffect {
            maskSource: selectionWrapper
            maskEnabled: true
            maskInverted: true
            maskSpreadAtMin: 1
            maskThresholdMin: 0.5
        }
    }

    Item {
        id: selectionWrapper

        anchors.fill: parent
        layer.enabled: true
        visible: false

        Rectangle {
            id: selectionRect

            radius: root.realRounding
            x: root.rsx
            y: root.rsy
            implicitWidth: root.sw
            implicitHeight: root.sh
        }
    }

    Rectangle {
        id: border

        color: "transparent"
        radius: root.realRounding > 0 ? root.realRounding + root.realBorderWidth : 0
        border.width: root.realBorderWidth
        border.color: Colours.palette.m3primary

        x: selectionRect.x - root.realBorderWidth
        y: selectionRect.y - root.realBorderWidth
        implicitWidth: selectionRect.implicitWidth + root.realBorderWidth * 2
        implicitHeight: selectionRect.implicitHeight + root.realBorderWidth * 2

        Behavior on border.color {
            CAnim {}
        }
    }

    Behavior on opacity {
        Anim {
            duration: Appearance.anim.durations.large
        }
    }

    Behavior on rsx {
        enabled: !root.pressed

        ExAnim {}
    }

    Behavior on rsy {
        enabled: !root.pressed

        ExAnim {}
    }

    Behavior on sw {
        enabled: !root.pressed

        ExAnim {}
    }

    Behavior on sh {
        enabled: !root.pressed

        ExAnim {}
    }

    component ExAnim: Anim {
        duration: Appearance.anim.durations.expressiveDefaultSpatial
        easing.bezierCurve: Appearance.anim.curves.expressiveDefaultSpatial
    }
}
