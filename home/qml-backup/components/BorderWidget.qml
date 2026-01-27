import QtQuick
import QtQuick.Shapes
import Quickshell
import Quickshell.Wayland
import "../theme"

// Base component for widgets that live in the screen border.
// Handles the popup with "morph stem" effect - the popup appears to grow
// out of the border itself via a connecting stem piece.
Item {
    id: root

    // Position determines popup direction and stem placement
    // "top" = popup extends downward, stem at top
    // "left" = popup extends rightward, stem at left
    // "right" = popup extends leftward, stem at right
    // "bottom" = popup extends upward, stem at bottom
    property string position: "top"

    // Popup state
    property bool popupVisible: false

    // Stem dimensions (the connector between border and popup)
    property int stemWidth: 40      // Width of the stem where it meets popup
    property int stemHeight: 12     // How far the stem extends from border
    property int stemRadius: 8      // Corner radius for stem-to-popup blend

    // Popup dimensions
    property int popupWidth: 200
    property int popupHeight: 150
    property int popupRadius: Metrics.radiusLarge

    // Colors
    property color stemColor: Gruvbox.screenBorder  // Same as border
    property color popupColor: Gruvbox.panelBg
    property color popupBorderColor: Gruvbox.panelBorder

    // Offset from widget center (positive = right/down, negative = left/up)
    property int popupOffset: 0

    // Content to display inside the popup body
    property alias popupContent: popupContentLoader.sourceComponent

    // The screen this widget belongs to (for PanelWindow)
    property var screen

    // Signal when popup visibility changes (for animations)
    signal popupOpened()
    signal popupClosed()

    // Hover detection for the widget itself
    property alias hovered: widgetMouseArea.containsMouse

    // Widget content area - implementations put their widget UI here
    default property alias widgetContent: widgetContainer.data

    // The clickable/hoverable widget area
    Item {
        id: widgetContainer
        anchors.fill: parent

        MouseArea {
            id: widgetMouseArea
            anchors.fill: parent
            hoverEnabled: true

            onContainsMouseChanged: {
                if (containsMouse) {
                    hoverTimer.start()
                } else {
                    hoverTimer.stop()
                    if (root.popupVisible) {
                        root.popupVisible = false
                        root.popupClosed()
                    }
                }
            }
        }
    }

    // Delay before showing popup on hover
    Timer {
        id: hoverTimer
        interval: 300
        onTriggered: {
            root.popupVisible = true
            root.popupOpened()
        }
    }

    // The popup window with morphing stem
    PanelWindow {
        id: popupPanel
        screen: root.screen
        visible: root.popupVisible && root.screen

        // Position the popup based on widget position
        anchors {
            top: root.position === "top" ? true : false
            bottom: root.position === "bottom" ? true : false
            left: root.position === "left" ? true : false
            right: root.position === "right" ? true : false
        }

        // Calculate margins to position popup relative to widget
        margins {
            top: root.position === "top" ? calculateTopMargin() : 0
            left: root.position === "left" ? calculateLeftMargin() : calculateHorizontalOffset()
            right: root.position === "right" ? calculateRightMargin() : 0
            bottom: root.position === "bottom" ? calculateBottomMargin() : 0
        }

        implicitWidth: root.popupWidth
        implicitHeight: root.popupHeight + root.stemHeight
        color: "transparent"

        WlrLayershell.namespace: "border-widget-popup"
        WlrLayershell.layer: WlrLayer.Overlay

        // Keep popup open when mouse enters it
        MouseArea {
            anchors.fill: parent
            hoverEnabled: true
            onContainsMouseChanged: {
                if (containsMouse) {
                    hoverTimer.stop()
                } else if (!widgetMouseArea.containsMouse) {
                    root.popupVisible = false
                    root.popupClosed()
                }
            }
        }

        // Draw the popup with stem using Shape
        Shape {
            id: popupShape
            anchors.fill: parent
            antialiasing: true

            ShapePath {
                fillColor: root.popupColor
                strokeColor: root.popupBorderColor
                strokeWidth: 1

                // For top position: stem at top, popup body below
                // Start at top-left of stem
                startX: (popupPanel.width - root.stemWidth) / 2
                startY: 0

                // Stem top edge (connects to border)
                PathLine {
                    x: (popupPanel.width + root.stemWidth) / 2
                    y: 0
                }

                // Stem right edge down to popup
                PathLine {
                    x: (popupPanel.width + root.stemWidth) / 2
                    y: root.stemHeight - root.stemRadius
                }

                // Curve from stem to popup right side
                PathArc {
                    x: (popupPanel.width + root.stemWidth) / 2 + root.stemRadius
                    y: root.stemHeight
                    radiusX: root.stemRadius
                    radiusY: root.stemRadius
                    direction: PathArc.Counterclockwise
                }

                // Top edge of popup to right corner
                PathLine {
                    x: popupPanel.width - root.popupRadius
                    y: root.stemHeight
                }

                // Top-right corner
                PathArc {
                    x: popupPanel.width
                    y: root.stemHeight + root.popupRadius
                    radiusX: root.popupRadius
                    radiusY: root.popupRadius
                }

                // Right edge
                PathLine {
                    x: popupPanel.width
                    y: popupPanel.height - root.popupRadius
                }

                // Bottom-right corner
                PathArc {
                    x: popupPanel.width - root.popupRadius
                    y: popupPanel.height
                    radiusX: root.popupRadius
                    radiusY: root.popupRadius
                }

                // Bottom edge
                PathLine {
                    x: root.popupRadius
                    y: popupPanel.height
                }

                // Bottom-left corner
                PathArc {
                    x: 0
                    y: popupPanel.height - root.popupRadius
                    radiusX: root.popupRadius
                    radiusY: root.popupRadius
                }

                // Left edge
                PathLine {
                    x: 0
                    y: root.stemHeight + root.popupRadius
                }

                // Top-left corner
                PathArc {
                    x: root.popupRadius
                    y: root.stemHeight
                    radiusX: root.popupRadius
                    radiusY: root.popupRadius
                }

                // Top edge of popup to stem
                PathLine {
                    x: (popupPanel.width - root.stemWidth) / 2 - root.stemRadius
                    y: root.stemHeight
                }

                // Curve from popup to stem left side
                PathArc {
                    x: (popupPanel.width - root.stemWidth) / 2
                    y: root.stemHeight - root.stemRadius
                    radiusX: root.stemRadius
                    radiusY: root.stemRadius
                    direction: PathArc.Counterclockwise
                }

                // Close path back to start
                PathLine {
                    x: (popupPanel.width - root.stemWidth) / 2
                    y: 0
                }
            }
        }

        // Draw stem overlay in border color (creates the morph effect)
        Rectangle {
            x: (popupPanel.width - root.stemWidth) / 2
            y: 0
            width: root.stemWidth
            height: root.stemHeight + 2  // Slight overlap
            color: root.stemColor
        }

        // Popup content area (inside the body, below stem)
        Item {
            id: popupContentArea
            x: Metrics.paddingNormal
            y: root.stemHeight + Metrics.paddingNormal
            width: parent.width - Metrics.paddingNormal * 2
            height: parent.height - root.stemHeight - Metrics.paddingNormal * 2

            Loader {
                id: popupContentLoader
                anchors.fill: parent
            }
        }
    }

    // Helper functions for positioning
    function calculateTopMargin() {
        // Position below the top bar
        return 32  // topHeight from ScreenFrame
    }

    function calculateHorizontalOffset() {
        // Center the popup on the widget
        return root.mapToGlobal(root.width / 2, 0).x - root.popupWidth / 2 + root.popupOffset
    }

    function calculateLeftMargin() {
        return 0
    }

    function calculateRightMargin() {
        return 0
    }

    function calculateBottomMargin() {
        return 0
    }
}
