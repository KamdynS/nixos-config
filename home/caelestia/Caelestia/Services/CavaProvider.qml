import QtQuick

// Stub for CavaProvider - requires C++ cava library
Item {
    id: root

    property int bars: 32
    property var values: {
        let arr = [];
        for (let i = 0; i < bars; i++) {
            arr.push(0);
        }
        return arr;
    }

    // Simulate some activity for testing
    Timer {
        interval: 100
        running: false // Set to true to see fake visualizer activity
        repeat: true
        onTriggered: {
            let arr = [];
            for (let i = 0; i < root.bars; i++) {
                arr.push(Math.random() * 0.3);
            }
            root.values = arr;
        }
    }
}
