//@ pragma Env QS_NO_RELOAD_POPUP=1
//@ pragma Env QSG_RENDER_LOOP=threaded
//@ pragma Env QT_QUICK_FLICKABLE_WHEEL_DECELERATION=10000

import "stubs" as Stubs
import "services"
import "modules"
import "modules/drawers"
import "modules/background"
import "modules/areapicker"
import "modules/lock"
import "modules/themepicker"
import "modules/keybinds"
import Quickshell
import QtQuick

ShellRoot {
    id: root

    // Initialize stubs for theme and toaster
    readonly property var theme: Stubs.Theme
    readonly property var toaster: Stubs.Toaster

    Background {}
    Drawers {}
    AreaPicker {}
    ThemePicker {}
    KeybindsPopup {}
    Lock {
        id: lock
    }

    Shortcuts {}
    BatteryMonitor {}
    IdleMonitors {
        lock: lock
    }
}
