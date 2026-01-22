import QtQuick

// Stub for AppDb - wraps DesktopEntries without frequency tracking
Item {
    id: root

    required property string path
    required property var entries

    readonly property string uuid: Math.random().toString(36).substring(2)
    readonly property var apps: {
        let result = [];
        for (let i = 0; i < entries.length; i++) {
            result.push(appEntryComponent.createObject(root, { entry: entries[i] }));
        }
        return result;
    }

    function incrementFrequency(id) {
        // No-op in stub - frequency tracking requires C++ sqlite
    }

    Component {
        id: appEntryComponent
        AppEntry {}
    }
}
