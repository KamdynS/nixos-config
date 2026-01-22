pragma Singleton

import qs.services
import Quickshell
import QtQuick

Singleton {
    id: root

    property var screens: new Map()
    property var bars: new Map()

    function load(screen: ShellScreen, visibilities: var): void {
        screens.set(Niri.monitorFor(screen), visibilities);
    }

    function getForActive(): PersistentProperties {
        return screens.get(Niri.focusedMonitor);
    }

    // Theme picker visibility - simple object with get/toggle methods
    readonly property var themePicker: QtObject {
        property var _map: new Map()

        function get(screen) {
            if (!_map.has(screen)) {
                const obj = Qt.createQmlObject('import QtQuick; QtObject { property bool visible: false }', root);
                _map.set(screen, obj);
            }
            return _map.get(screen);
        }

        function toggle(screen) {
            const vis = get(screen);
            vis.visible = !vis.visible;
        }

        function showOnActive() {
            const screens = Quickshell.screens;
            for (let i = 0; i < screens.length; i++) {
                get(screens[i]).visible = true;
            }
        }
    }

    // Keybinds popup visibility
    readonly property var keybinds: QtObject {
        property var _map: new Map()

        function get(screen) {
            if (!_map.has(screen)) {
                const obj = Qt.createQmlObject('import QtQuick; QtObject { property bool visible: false }', root);
                _map.set(screen, obj);
            }
            return _map.get(screen);
        }

        function toggle(screen) {
            const vis = get(screen);
            vis.visible = !vis.visible;
        }

        function showOnActive() {
            const screens = Quickshell.screens;
            for (let i = 0; i < screens.length; i++) {
                get(screens[i]).visible = true;
            }
        }
    }
}
