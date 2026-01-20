import Quickshell
import Quickshell.Wayland
import Quickshell.Io
import Quickshell.Services.SystemTray
import QtQuick
import QtQuick.Layouts
import "theme"

Item {
    id: root
    required property var screen
    signal controlCenterToggled()

    property int borderWidth: Gruvbox.totalBorderWidth  // Total reserved space (border + gap)
    property int barHeight: Gruvbox.barHeight
    property int cornerRadius: Gruvbox.frameCornerRadius
    property color frameColor: Gruvbox.screenBorder

    property string currentTime: ""

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
                anchors.leftMargin: borderWidth + Gruvbox.paddingLarge
                anchors.rightMargin: borderWidth + Gruvbox.paddingLarge
                anchors.topMargin: Gruvbox.paddingSmall
                anchors.bottomMargin: Gruvbox.paddingSmall
                spacing: Gruvbox.paddingNormal

                // Left: Control center button
                Rectangle {
                    Layout.preferredWidth: 28
                    Layout.preferredHeight: 28
                    color: controlCenterMouse.containsMouse ? Gruvbox.hoverBg : "transparent"
                    radius: Gruvbox.radiusSmall

                    Text {
                        anchors.centerIn: parent
                        text: ""
                        color: Gruvbox.fg
                        font.family: Gruvbox.fontFamily
                        font.pixelSize: Gruvbox.fontSizeNormal
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
                    font.family: Gruvbox.fontFamily
                    font.pixelSize: Gruvbox.fontSizeNormal
                    font.bold: true
                }

                // Spacer
                Item { Layout.fillWidth: true }

                // Right: System tray
                RowLayout {
                    spacing: Gruvbox.paddingSmall

                    Repeater {
                        model: SystemTray.items

                        Rectangle {
                            required property SystemTrayItem modelData
                            Layout.preferredWidth: 24
                            Layout.preferredHeight: 24
                            color: trayMouse.containsMouse ? Gruvbox.hoverBg : "transparent"
                            radius: Gruvbox.radiusSmall

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

            // Inverted corner - bottom left
            Canvas {
                id: topLeftCorner
                anchors.left: parent.left
                anchors.bottom: parent.bottom
                anchors.leftMargin: borderWidth - cornerRadius
                width: cornerRadius
                height: cornerRadius
                onPaint: {
                    var ctx = getContext("2d")
                    ctx.reset()
                    ctx.fillStyle = frameColor
                    ctx.fillRect(0, 0, width, height)
                    ctx.globalCompositeOperation = "destination-out"
                    ctx.beginPath()
                    ctx.arc(width, 0, cornerRadius, 0.5 * Math.PI, Math.PI)
                    ctx.lineTo(width, height)
                    ctx.lineTo(width, 0)
                    ctx.fill()
                }
            }

            // Inverted corner - bottom right
            Canvas {
                id: topRightCorner
                anchors.right: parent.right
                anchors.bottom: parent.bottom
                anchors.rightMargin: borderWidth - cornerRadius
                width: cornerRadius
                height: cornerRadius
                onPaint: {
                    var ctx = getContext("2d")
                    ctx.reset()
                    ctx.fillStyle = frameColor
                    ctx.fillRect(0, 0, width, height)
                    ctx.globalCompositeOperation = "destination-out"
                    ctx.beginPath()
                    ctx.arc(0, 0, cornerRadius, 0, 0.5 * Math.PI)
                    ctx.lineTo(0, height)
                    ctx.lineTo(0, 0)
                    ctx.fill()
                }
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

            // Inverted corner - top left
            Canvas {
                anchors.left: parent.left
                anchors.top: parent.top
                anchors.leftMargin: borderWidth - cornerRadius
                width: cornerRadius
                height: cornerRadius
                onPaint: {
                    var ctx = getContext("2d")
                    ctx.reset()
                    ctx.fillStyle = frameColor
                    ctx.fillRect(0, 0, width, height)
                    ctx.globalCompositeOperation = "destination-out"
                    ctx.beginPath()
                    ctx.arc(width, height, cornerRadius, Math.PI, 1.5 * Math.PI)
                    ctx.lineTo(width, 0)
                    ctx.lineTo(width, height)
                    ctx.fill()
                }
            }

            // Inverted corner - top right
            Canvas {
                anchors.right: parent.right
                anchors.top: parent.top
                anchors.rightMargin: borderWidth - cornerRadius
                width: cornerRadius
                height: cornerRadius
                onPaint: {
                    var ctx = getContext("2d")
                    ctx.reset()
                    ctx.fillStyle = frameColor
                    ctx.fillRect(0, 0, width, height)
                    ctx.globalCompositeOperation = "destination-out"
                    ctx.beginPath()
                    ctx.arc(0, height, cornerRadius, 1.5 * Math.PI, 2 * Math.PI)
                    ctx.lineTo(0, 0)
                    ctx.lineTo(0, height)
                    ctx.fill()
                }
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
