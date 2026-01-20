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

    property int borderWidth: Layout.totalBorderWidth
    property int barHeight: Layout.barHeight
    property int cornerRadius: Layout.frameCornerRadius
    property color frameColor: Gruvbox.screenBorder

    property string currentTime: ""

    // Reusable inverted corner component
    component InvertedCorner: Shape {
        id: cornerShape
        required property int corner  // 0=topLeft, 1=topRight, 2=bottomLeft, 3=bottomRight
        required property color fillColor
        required property int radius

        width: radius
        height: radius
        antialiasing: true

        ShapePath {
            fillColor: cornerShape.fillColor
            strokeColor: "transparent"

            // Start point depends on corner
            startX: cornerShape.corner === 0 || cornerShape.corner === 2 ? cornerShape.radius : 0
            startY: cornerShape.corner === 0 || cornerShape.corner === 1 ? cornerShape.radius : 0

            PathArc {
                x: cornerShape.corner === 0 || cornerShape.corner === 2 ? 0 : cornerShape.radius
                y: cornerShape.corner === 0 || cornerShape.corner === 1 ? 0 : cornerShape.radius
                radiusX: cornerShape.radius
                radiusY: cornerShape.radius
                direction: cornerShape.corner === 0 || cornerShape.corner === 3 ? PathArc.Counterclockwise : PathArc.Clockwise
            }

            PathLine {
                x: cornerShape.corner === 1 || cornerShape.corner === 3 ? cornerShape.radius : 0
                y: cornerShape.corner === 2 || cornerShape.corner === 3 ? cornerShape.radius : 0
            }

            PathLine {
                x: cornerShape.corner === 0 || cornerShape.corner === 2 ? cornerShape.radius : 0
                y: cornerShape.corner === 0 || cornerShape.corner === 1 ? cornerShape.radius : 0
            }
        }
    }

    // ==================== TOP BAR ====================
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

        // Main bar background
        Rectangle {
            anchors.fill: parent
            color: frameColor

            // Bar content
            RowLayout {
                anchors.fill: parent
                anchors.leftMargin: borderWidth + Layout.paddingLarge
                anchors.rightMargin: borderWidth + Layout.paddingLarge
                anchors.topMargin: Layout.paddingSmall
                anchors.bottomMargin: Layout.paddingSmall
                spacing: Layout.paddingNormal

                // Left: Control center button
                Rectangle {
                    Layout.preferredWidth: 28
                    Layout.preferredHeight: 28
                    color: controlCenterMouse.containsMouse ? Gruvbox.hoverBg : "transparent"
                    radius: Layout.radiusSmall

                    Text {
                        anchors.centerIn: parent
                        text: ""
                        color: Gruvbox.fg
                        font.family: Layout.fontFamily
                        font.pixelSize: Layout.fontSizeNormal
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
                    font.family: Layout.fontFamily
                    font.pixelSize: Layout.fontSizeNormal
                    font.bold: true
                }

                // Spacer
                Item { Layout.fillWidth: true }

                // Right: System tray
                RowLayout {
                    spacing: Layout.paddingSmall

                    Repeater {
                        model: SystemTray.items

                        Rectangle {
                            required property SystemTrayItem modelData
                            Layout.preferredWidth: 24
                            Layout.preferredHeight: 24
                            color: trayMouse.containsMouse ? Gruvbox.hoverBg : "transparent"
                            radius: Layout.radiusSmall

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

            // Inverted corner - bottom left of top bar
            InvertedCorner {
                anchors.left: parent.left
                anchors.bottom: parent.bottom
                anchors.leftMargin: borderWidth - cornerRadius
                corner: 2  // bottomLeft
                fillColor: frameColor
                radius: cornerRadius
            }

            // Inverted corner - bottom right of top bar
            InvertedCorner {
                anchors.right: parent.right
                anchors.bottom: parent.bottom
                anchors.rightMargin: borderWidth - cornerRadius
                corner: 3  // bottomRight
                fillColor: frameColor
                radius: cornerRadius
            }
        }
    }

    // ==================== BOTTOM BORDER ====================
    PanelWindow {
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

        Rectangle {
            anchors.fill: parent
            color: frameColor

            // Inverted corner - top left of bottom bar
            InvertedCorner {
                anchors.left: parent.left
                anchors.top: parent.top
                anchors.leftMargin: borderWidth - cornerRadius
                corner: 0  // topLeft
                fillColor: frameColor
                radius: cornerRadius
            }

            // Inverted corner - top right of bottom bar
            InvertedCorner {
                anchors.right: parent.right
                anchors.top: parent.top
                anchors.rightMargin: borderWidth - cornerRadius
                corner: 1  // topRight
                fillColor: frameColor
                radius: cornerRadius
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
