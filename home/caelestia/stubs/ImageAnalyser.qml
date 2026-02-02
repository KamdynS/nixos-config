import QtQuick

// Stub for ImageAnalyser - requires C++ plugin for image analysis
Item {
    id: root

    property string source: ""
    property Item sourceItem: null
    property int rescaleSize: 100
    property color dominantColour: "#666666"
    property real luminance: 0.5

    function requestUpdate() {
        // No-op in stub
    }
}
