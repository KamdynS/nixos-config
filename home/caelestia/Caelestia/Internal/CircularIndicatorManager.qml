import QtQuick

// Stub for CircularIndicatorManager - manages circular progress animation
Item {
    id: root

    enum IndeterminateAnimationType {
        Advance,
        Retreat
    }

    property real startFraction: 0
    property real endFraction: 0.25
    property real rotation: 0
    property real progress: 0
    property real completeEndProgress: 0
    property int indeterminateAnimationType: CircularIndicatorManager.IndeterminateAnimationType.Advance

    readonly property real duration: 1333
    readonly property real completeEndDuration: 333

    onProgressChanged: update()
    onIndeterminateAnimationTypeChanged: update()

    function update() {
        if (indeterminateAnimationType === CircularIndicatorManager.IndeterminateAnimationType.Advance) {
            // Advance animation
            let p = progress;
            startFraction = Math.min(p * 0.75, 0.25);
            endFraction = Math.min(0.25 + p * 0.75, 1);
            rotation = p * 360;
        } else {
            // Retreat animation
            let p = progress;
            startFraction = Math.max(0, p * 0.75 - 0.5);
            endFraction = Math.max(0.25, 1 - p * 0.75);
            rotation = 360 + p * 180;
        }
    }

    Component.onCompleted: update()
}
