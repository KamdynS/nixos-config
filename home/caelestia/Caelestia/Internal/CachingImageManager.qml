import QtQuick

// Stub for CachingImageManager - just passes through source without caching
Item {
    id: root

    required property Item item
    required property url cacheDir

    property string path: ""
    property url cachePath: path ? Qt.resolvedUrl("file://" + path) : ""

    function updateSource() {
        cachePath = path ? Qt.resolvedUrl("file://" + path) : "";
    }

    onPathChanged: updateSource()
}
