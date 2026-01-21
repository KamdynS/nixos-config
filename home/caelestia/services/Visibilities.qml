pragma Singleton

import Quickshell

Singleton {
    property var screens: new Map()
    property var bars: new Map()

    function load(screen: ShellScreen, visibilities: var): void {
        screens.set(Niri.monitorFor(screen), visibilities);
    }

    function getForActive(): PersistentProperties {
        return screens.get(Niri.focusedMonitor);
    }
}
