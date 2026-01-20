import Quickshell
import Quickshell.Wayland
import Quickshell.Io
import Quickshell.Services.SystemTray
import QtQuick
import QtQuick.Layouts
import QtQuick.Shapes
import "theme"
import "components"

Item {
    id: root
    required property var screen
    signal controlCenterToggled()
    signal workspaceSwitchRequested(int idx)

    // Workspace state from shell.qml
    property var workspaces: []
    property int activeWorkspace: 1

    // Frame dimensions (struts minus gap for breathing room)
    property int topHeight: 32      // niri struts.top (42) minus 10px gap
    property int sideWidth: 16      // niri struts.sides (26) minus 10px gap
    property int innerRadius: 12    // niri window corner radius
    property color frameColor: Gruvbox.screenBorder

    property string currentTime: ""

    // ==================== UNIFIED FRAME VISUAL ====================
    // Single full-screen panel that draws the entire border frame
    // Square outer edges, rounded inner edges (matching window corners)
    PanelWindow {
        id: framePanel
        screen: root.screen
        anchors {
            top: true
            bottom: true
            left: true
            right: true
        }
        color: "transparent"
        exclusionMode: ExclusionMode.Ignore  // niri handles struts
        WlrLayershell.layer: WlrLayer.Bottom
        WlrLayershell.namespace: "screen-frame"

        Shape {
            id: frameShape
            anchors.fill: parent
            antialiasing: true

            ShapePath {
                fillColor: root.frameColor
                strokeColor: "transparent"
                fillRule: ShapePath.OddEvenFill

                // Outer rectangle (clockwise) - square corners at screen edges
                startX: 0
                startY: 0
                PathLine { x: frameShape.width; y: 0 }
                PathLine { x: frameShape.width; y: frameShape.height }
                PathLine { x: 0; y: frameShape.height }
                PathLine { x: 0; y: 0 }

                // Inner rounded rectangle (counter-clockwise) - creates the cutout
                // Start at top-left inner corner, on the left edge
                PathMove { x: sideWidth; y: topHeight + innerRadius }

                // Left edge going down
                PathLine { x: sideWidth; y: frameShape.height - sideWidth - innerRadius }

                // Bottom-left corner (rounded)
                PathArc {
                    x: sideWidth + innerRadius
                    y: frameShape.height - sideWidth
                    radiusX: innerRadius
                    radiusY: innerRadius
                    direction: PathArc.Counterclockwise
                }

                // Bottom edge going right
                PathLine { x: frameShape.width - sideWidth - innerRadius; y: frameShape.height - sideWidth }

                // Bottom-right corner (rounded)
                PathArc {
                    x: frameShape.width - sideWidth
                    y: frameShape.height - sideWidth - innerRadius
                    radiusX: innerRadius
                    radiusY: innerRadius
                    direction: PathArc.Counterclockwise
                }

                // Right edge going up
                PathLine { x: frameShape.width - sideWidth; y: topHeight + innerRadius }

                // Top-right corner (rounded)
                PathArc {
                    x: frameShape.width - sideWidth - innerRadius
                    y: topHeight
                    radiusX: innerRadius
                    radiusY: innerRadius
                    direction: PathArc.Counterclockwise
                }

                // Top edge going left
                PathLine { x: sideWidth + innerRadius; y: topHeight }

                // Top-left corner (rounded) - closes the inner path
                PathArc {
                    x: sideWidth
                    y: topHeight + innerRadius
                    radiusX: innerRadius
                    radiusY: innerRadius
                    direction: PathArc.Counterclockwise
                }
            }
        }
    }

    // ==================== TOP BAR (Interactive Layer) ====================
    // Separate panel for interactive elements, positioned above windows
    PanelWindow {
        id: topBar
        screen: root.screen
        anchors {
            top: true
            left: true
            right: true
        }
        height: topHeight
        color: "transparent"
        exclusionMode: ExclusionMode.Ignore  // niri handles struts
        WlrLayershell.layer: WlrLayer.Top
        WlrLayershell.namespace: "screen-frame-bar"

        // Left section
        RowLayout {
            anchors {
                left: parent.left
                leftMargin: sideWidth + Metrics.paddingLarge
                verticalCenter: parent.verticalCenter
            }
            spacing: Metrics.paddingNormal

            // Control center button
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

            // Clock
            Text {
                text: root.currentTime
                color: Gruvbox.fg3
                font.family: Metrics.fontFamily
                font.pixelSize: Metrics.fontSizeSmall
            }
        }

        // Center: Workspace indicator (truly centered)
        WorkspaceIndicator {
            anchors.centerIn: parent
            workspaces: root.workspaces
            activeWorkspace: root.activeWorkspace
            screen: root.screen

            onWorkspaceClicked: (idx) => {
                root.workspaceSwitchRequested(idx)
            }
        }

        // Right section: System tray
        RowLayout {
            anchors {
                right: parent.right
                rightMargin: sideWidth + Metrics.paddingLarge
                verticalCenter: parent.verticalCenter
            }
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
