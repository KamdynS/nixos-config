pragma Singleton

import QtQuick
import Quickshell

// Stub replacement for Caelestia.Toaster
// Provides a simple toast notification system without C++ plugin
Singleton {
    id: root

    property list<Toast> toasts: []

    function toast(title, message, icon, type, timeout) {
        icon = icon || "";
        type = type || Toast.Info;
        timeout = timeout !== undefined ? timeout : 5000;
        const t = toastComponent.createObject(root, {
            title: title,
            message: message,
            icon: icon,
            type: type,
            timeout: timeout
        });
        toasts.push(t);
        toastsChanged();

        if (timeout > 0) {
            Qt.callLater(() => {
                t.closeTimer.start();
            });
        }
    }

    Component {
        id: toastComponent
        Toast {}
    }
}
