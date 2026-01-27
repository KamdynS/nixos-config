import QtQuick

// Toast notification object
QtObject {
    id: root

    // Toast types
    enum Type { Info, Success, Warning, Error }

    property string title: ""
    property string message: ""
    property string icon: ""
    property int type: Toast.Info
    property int timeout: 5000

    readonly property Timer closeTimer: Timer {
        interval: root.timeout
        onTriggered: root.close()
    }

    function close() {
        const idx = Toaster.toasts.indexOf(this);
        if (idx >= 0) {
            Toaster.toasts.splice(idx, 1);
            Toaster.toastsChanged();
        }
        destroy();
    }
}
