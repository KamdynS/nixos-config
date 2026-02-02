pragma Singleton

import qs.services
import Quickshell
import QtQuick

Singleton {
    id: root

    property var screens: new Map()
    property var bars: new Map()

    function load(screen: ShellScreen, visibilities: var): void {
        // Use screen name directly - stable string key
        screens.set(screen.name, visibilities);
    }

    function getForActive(): PersistentProperties {
        // Use the focusedOutputName string directly from daemon
        const focusedName = Niri.focusedOutputName;
        if (focusedName) {
            return screens.get(focusedName);
        }
        return null;
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
            const focusedName = Niri.focusedOutputName;
            if (!focusedName) {
                // Fallback: show on first screen if no focused monitor yet
                const screens = Quickshell.screens;
                if (screens.length > 0) {
                    get(screens[0]).visible = true;
                }
                return;
            }
            const activeScreen = Quickshell.screens.find(s => s.name === focusedName);
            if (activeScreen) {
                get(activeScreen).visible = true;
            }
        }

        function hideAll() {
            const screens = Quickshell.screens;
            for (let i = 0; i < screens.length; i++) {
                get(screens[i]).visible = false;
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
            const focusedName = Niri.focusedOutputName;
            if (!focusedName) {
                // Fallback: show on first screen if no focused monitor yet
                const screens = Quickshell.screens;
                if (screens.length > 0) {
                    get(screens[0]).visible = true;
                }
                return;
            }
            const activeScreen = Quickshell.screens.find(s => s.name === focusedName);
            if (activeScreen) {
                get(activeScreen).visible = true;
            }
        }

        function hideAll() {
            const screens = Quickshell.screens;
            for (let i = 0; i < screens.length; i++) {
                get(screens[i]).visible = false;
            }
        }
    }
}
