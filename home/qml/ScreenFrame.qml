import Quickshell
import Quickshell.Wayland
import Quickshell.Io
import Quickshell.Services.SystemTray
import QtQuick
import QtQuick.Layouts
import QtQuick.Shapes
import "theme"

Item {
    id: root
    required property var screen
    signal controlCenterToggled()

    property int borderWidth: Metrics.totalBorderWidth
    property int barHeight: Metrics.barHeight
    property int outerRadius: Metrics.frameCornerRadius  // Outer screen corner radius
    property int innerRadius: Metrics.frameCornerRadius  // Inner content area corner radius
    property color frameColor: Gruvbox.screenBorder

    property string currentTime: ""

    // ==================== TOP BAR ====================
    // Shaped bar with rounded outer corners (top-left, top-right of screen)
    PanelWindow {
        id: topBar
        screen: root.screen
        anchors {
            top: true
            left: true
            right: true
        }
        height: barHeight
        color: "transparent"
        exclusionMode: ExclusionMode.Normal
        WlrLayershell.layer: WlrLayer.Top
        WlrLayershell.namespace: "screen-frame"

        Shape {
            id: topBarShape
            anchors.fill: parent
            antialiasing: true

            ShapePath {
                fillColor: frameColor
                strokeColor: "transparent"

                // Start at left edge, below outer corner
                startX: 0
                startY: outerRadius

                // Outer top-left corner (rounded)
                PathArc {
                    x: outerRadius
                    y: 0
                    radiusX: outerRadius
                    radiusY: outerRadius
                    direction: PathArc.Counterclockwise
                }

                // Top edge
                PathLine { x: topBarShape.width - outerRadius; y: 0 }

                // Outer top-right corner (rounded)
                PathArc {
                    x: topBarShape.width
                    y: outerRadius
                    radiusX: outerRadius
                    radiusY: outerRadius
                    direction: PathArc.Counterclockwise
                }

                // Right edge down
                PathLine { x: topBarShape.width; y: barHeight }

                // Bottom edge
                PathLine { x: 0; y: barHeight }

                // Left edge back up
                PathLine { x: 0; y: outerRadius }
            }
        }

        // Inner corner fills (create rounded content area corners)
        // Bottom-left inner corner
        Shape {
            x: borderWidth - innerRadius
            y: barHeight - innerRadius
            width: innerRadius
            height: innerRadius
            antialiasing: true

            ShapePath {
                fillColor: frameColor
                strokeColor: "transparent"
                startX: innerRadius
                startY: 0

                PathArc {
                    x: 0
                    y: innerRadius
                    radiusX: innerRadius
                    radiusY: innerRadius
                    direction: PathArc.Clockwise
                }

                PathLine { x: innerRadius; y: innerRadius }
                PathLine { x: innerRadius; y: 0 }
            }
        }

        // Bottom-right inner corner
        Shape {
            x: topBarShape.width - borderWidth
            y: barHeight - innerRadius
            width: innerRadius
            height: innerRadius
            antialiasing: true

            ShapePath {
                fillColor: frameColor
                strokeColor: "transparent"
                startX: 0
                startY: 0

                PathArc {
                    x: innerRadius
                    y: innerRadius
                    radiusX: innerRadius
                    radiusY: innerRadius
                    direction: PathArc.Counterclockwise
                }

                PathLine { x: 0; y: innerRadius }
                PathLine { x: 0; y: 0 }
            }
        }

        // Bar content overlay
        RowLayout {
            anchors.fill: parent
            anchors.leftMargin: borderWidth + Metrics.paddingLarge
            anchors.rightMargin: borderWidth + Metrics.paddingLarge
            anchors.topMargin: Metrics.paddingSmall
            anchors.bottomMargin: Metrics.paddingSmall
            spacing: Metrics.paddingNormal

            // Left: Control center button
            Rectangle {
                Layout.preferredWidth: 28
                Layout.preferredHeight: 28
                color: controlCenterMouse.containsMouse ? Gruvbox.hoverBg : "transparent"
                radius: Metrics.radiusSmall

                Text {
                    anchors.centerIn: parent
                    text: ""
                    color: Gruvbox.fg
                    font.family: Metrics.fontFamily
                    font.pixelSize: Metrics.fontSizeNormal
                }

                MouseArea {
                    id: controlCenterMouse
                    anchors.fill: parent
                    hoverEnabled: true
                    onClicked: root.controlCenterToggled()
                }
            }

            // Spacer
            Item { Layout.fillWidth: true }

            // Center: Clock
            Text {
                text: root.currentTime
                color: Gruvbox.fg
                font.family: Metrics.fontFamily
                font.pixelSize: Metrics.fontSizeNormal
                font.bold: true
            }

            // Spacer
            Item { Layout.fillWidth: true }

            // Right: System tray
            RowLayout {
                spacing: Metrics.paddingSmall

                Repeater {
                    model: SystemTray.items

                    Rectangle {
                        required property SystemTrayItem modelData
                        Layout.preferredWidth: 24
                        Layout.preferredHeight: 24
                        color: trayMouse.containsMouse ? Gruvbox.hoverBg : "transparent"
                        radius: Metrics.radiusSmall

                        Image {
                            anchors.centerIn: parent
                            width: 18
                            height: 18
                            source: modelData.icon ? Quickshell.iconPath(modelData.icon) : ""
                            sourceSize: Qt.size(18, 18)
                        }

                        MouseArea {
                            id: trayMouse
                            anchors.fill: parent
                            hoverEnabled: true
                            acceptedButtons: Qt.LeftButton | Qt.RightButton

                            onClicked: (mouse) => {
                                if (mouse.button === Qt.LeftButton) {
                                    modelData.activate()
                                } else {
                                    modelData.secondaryActivate()
                                }
                            }
                        }
                    }
                }
            }
        }
    }

    // ==================== BOTTOM BORDER ====================
    // Shaped bar with rounded outer corners (bottom-left, bottom-right of screen)
    PanelWindow {
        id: bottomBar
        screen: root.screen
        anchors {
            bottom: true
            left: true
            right: true
        }
        height: borderWidth
        color: "transparent"
        exclusionMode: ExclusionMode.Normal
        WlrLayershell.layer: WlrLayer.Top
        WlrLayershell.namespace: "screen-frame"

        Shape {
            id: bottomBarShape
            anchors.fill: parent
            antialiasing: true

            ShapePath {
                fillColor: frameColor
                strokeColor: "transparent"

                // Start at top-left
                startX: 0
                startY: 0

                // Top edge
                PathLine { x: bottomBarShape.width; y: 0 }

                // Right edge down to corner
                PathLine { x: bottomBarShape.width; y: borderWidth - outerRadius }

                // Outer bottom-right corner (rounded)
                PathArc {
                    x: bottomBarShape.width - outerRadius
                    y: borderWidth
                    radiusX: outerRadius
                    radiusY: outerRadius
                    direction: PathArc.Counterclockwise
                }

                // Bottom edge
                PathLine { x: outerRadius; y: borderWidth }

                // Outer bottom-left corner (rounded)
                PathArc {
                    x: 0
                    y: borderWidth - outerRadius
                    radiusX: outerRadius
                    radiusY: outerRadius
                    direction: PathArc.Counterclockwise
                }

                // Left edge back up
                PathLine { x: 0; y: 0 }
            }
        }

        // Inner corner fills (create rounded content area corners)
        // Top-left inner corner
        Shape {
            x: borderWidth - innerRadius
            y: 0
            width: innerRadius
            height: innerRadius
            antialiasing: true

            ShapePath {
                fillColor: frameColor
                strokeColor: "transparent"
                startX: innerRadius
                startY: innerRadius

                PathArc {
                    x: 0
                    y: 0
                    radiusX: innerRadius
                    radiusY: innerRadius
                    direction: PathArc.Counterclockwise
                }

                PathLine { x: innerRadius; y: 0 }
                PathLine { x: innerRadius; y: innerRadius }
            }
        }

        // Top-right inner corner
        Shape {
            x: bottomBarShape.width - borderWidth
            y: 0
            width: innerRadius
            height: innerRadius
            antialiasing: true

            ShapePath {
                fillColor: frameColor
                strokeColor: "transparent"
                startX: 0
                startY: innerRadius

                PathArc {
                    x: innerRadius
                    y: 0
                    radiusX: innerRadius
                    radiusY: innerRadius
                    direction: PathArc.Clockwise
                }

                PathLine { x: 0; y: 0 }
                PathLine { x: 0; y: innerRadius }
            }
        }
    }

    // ==================== LEFT BORDER ====================
    PanelWindow {
        screen: root.screen
        anchors {
            top: true
            bottom: true
            left: true
        }
        width: borderWidth
        margins {
            top: barHeight
            bottom: borderWidth
        }
        color: "transparent"
        exclusionMode: ExclusionMode.Normal
        WlrLayershell.layer: WlrLayer.Top
        WlrLayershell.namespace: "screen-frame"

        Rectangle {
            anchors.fill: parent
            color: frameColor
        }
    }

    // ==================== RIGHT BORDER ====================
    PanelWindow {
        screen: root.screen
        anchors {
            top: true
            bottom: true
            right: true
        }
        width: borderWidth
        margins {
            top: barHeight
            bottom: borderWidth
        }
        color: "transparent"
        exclusionMode: ExclusionMode.Normal
        WlrLayershell.layer: WlrLayer.Top
        WlrLayershell.namespace: "screen-frame"

        Rectangle {
            anchors.fill: parent
            color: frameColor
        }
    }

    // ==================== CLOCK UPDATER ====================
    Process {
        id: clockProc
        command: ["date", "+%a %b %d  %H:%M"]
        running: true
        stdout: StdioCollector {
            onStreamFinished: {
                root.currentTime = this.text.trim()
            }
        }
    }

    Timer {
        interval: 1000
        running: true
        repeat: true
        onTriggered: clockProc.running = true
    }
}
