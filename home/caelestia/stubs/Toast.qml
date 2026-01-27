import QtQuick

// Stub replacement for Caelestia.Toast
QtObject {
    id: root

    enum Type {
        Info = 0,
        Success = 1,
        Warning = 2,
        Error = 3
    }

    property bool closed: false
    property string title: ""
    property string message: ""
    property string icon: ""
    property int timeout: 5000
    property int type: Toast.Info

    property list<QtObject> locks: []

    signal finishedClose()

    property Timer closeTimer: Timer {
        interval: root.timeout
        onTriggered: root.close()
    }

    function close() {
        if (locks.length > 0) return;
        closed = true;
        finishedClose();
    }

    function lock(sender) {
        if (!locks.includes(sender)) {
            locks.push(sender);
        }
    }

    function unlock(sender) {
        const idx = locks.indexOf(sender);
        if (idx >= 0) {
            locks.splice(idx, 1);
        }
    }
}
