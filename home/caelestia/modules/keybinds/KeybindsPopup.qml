pragma ComponentBehavior: Bound

import qs.components
import qs.config
import qs.services
import Quickshell
import QtQuick
import QtQuick.Layouts

Scope {
    id: root

    Variants {
        model: Quickshell.screens

        PanelWindow {
            id: window

            required property ShellScreen modelData

            screen: modelData
            visible: Visibilities.keybinds.get(modelData).visible
            color: "transparent"

            anchors {
                top: true
                left: true
                right: true
                bottom: true
            }

            // Click outside to close
            MouseArea {
                anchors.fill: parent
                onClicked: Visibilities.keybinds.get(window.modelData).visible = false
            }

            // Keyboard handler for closing with Escape
            Keys.onPressed: event => {
                if (event.key === Qt.Key_Escape) {
                    Visibilities.keybinds.get(window.modelData).visible = false;
                    event.accepted = true;
                }
            }

            // Main popup panel
            StyledRect {
                id: panel

                anchors.centerIn: parent
                width: Math.min(800, parent.width - 80)
                height: Math.min(600, parent.height - 80)

                color: Colours.layer(Colours.palette.m3surfaceContainer, 0)
                radius: Appearance.rounding.large

                // Fade in animation
                opacity: window.visible ? 1 : 0
                scale: window.visible ? 1 : 0.95

                Behavior on opacity { Anim { duration: Appearance.anim.durations.normal } }
                Behavior on scale { Anim { duration: Appearance.anim.durations.normal } }

                ColumnLayout {
                    anchors.fill: parent
                    anchors.margins: Appearance.padding.large
                    spacing: Appearance.spacing.normal

                    // Header
                    RowLayout {
                        Layout.fillWidth: true
                        spacing: Appearance.spacing.normal

                        MaterialIcon {
                            text: "keyboard"
                            font.pixelSize: Appearance.font.size.larger
                            color: Colours.palette.m3primary
                        }

                        StyledText {
                            text: qsTr("Keyboard Shortcuts")
                            font.pixelSize: Appearance.font.size.large
                            font.weight: Font.Medium
                            color: Colours.palette.m3onSurface
                        }

                        Item { Layout.fillWidth: true }

                        // Close button
                        StyledRect {
                            width: 32
                            height: 32
                            radius: Appearance.rounding.full
                            color: closeMouseArea.containsMouse ? Colours.palette.m3surfaceContainerHigh : "transparent"

                            MaterialIcon {
                                anchors.centerIn: parent
                                text: "close"
                                color: Colours.palette.m3onSurface
                            }

                            MouseArea {
                                id: closeMouseArea
                                anchors.fill: parent
                                hoverEnabled: true
                                onClicked: Visibilities.keybinds.get(window.modelData).visible = false
                            }
                        }
                    }

                    // Hint text
                    StyledText {
                        text: qsTr("Press Escape to close")
                        font.pixelSize: Appearance.font.size.smaller
                        color: Colours.palette.m3onSurfaceVariant
                    }

                    // Scrollable keybinds list
                    Flickable {
                        Layout.fillWidth: true
                        Layout.fillHeight: true
                        contentHeight: keybindsColumn.height
                        clip: true
                        boundsBehavior: Flickable.StopAtBounds

                        ColumnLayout {
                            id: keybindsColumn
                            width: parent.width
                            spacing: Appearance.spacing.large

                            // Window Management
                            KeybindSection {
                                title: "Window Management"
                                keybinds: [
                                    { key: "Mod + Q", desc: "Close window" },
                                    { key: "Mod + F", desc: "Maximize column" },
                                    { key: "Mod + Shift + F", desc: "Fullscreen window" },
                                    { key: "Mod + H/J/K/L", desc: "Focus left/down/up/right" },
                                    { key: "Mod + Shift + H/J/K/L", desc: "Move window left/down/up/right" }
                                ]
                            }

                            // Workspaces
                            KeybindSection {
                                title: "Workspaces"
                                keybinds: [
                                    { key: "Mod + 1-9", desc: "Switch to workspace 1-9" },
                                    { key: "Mod + Shift + 1-9", desc: "Move window to workspace 1-9" },
                                    { key: "Mod + Scroll", desc: "Cycle workspaces" }
                                ]
                            }

                            // Apps & Launchers
                            KeybindSection {
                                title: "Apps & Launchers"
                                keybinds: [
                                    { key: "Mod + Return", desc: "Open terminal (Ghostty)" },
                                    { key: "Mod + D", desc: "Open app launcher" },
                                    { key: "Mod + A", desc: "Toggle dashboard" }
                                ]
                            }

                            // Shell Controls
                            KeybindSection {
                                title: "Shell Controls"
                                keybinds: [
                                    { key: "Mod + X", desc: "Open session menu (power)" },
                                    { key: "Mod + T", desc: "Open theme picker" },
                                    { key: "Mod + F1", desc: "Show this help" }
                                ]
                            }

                            // Screenshots
                            KeybindSection {
                                title: "Screenshots"
                                keybinds: [
                                    { key: "Print", desc: "Screenshot (save to file)" },
                                    { key: "Alt + Print", desc: "Screenshot window" },
                                    { key: "Ctrl + Print", desc: "Screenshot region to clipboard" },
                                    { key: "Ctrl + Alt + Print", desc: "Screenshot all to clipboard" }
                                ]
                            }

                            // System
                            KeybindSection {
                                title: "System"
                                keybinds: [
                                    { key: "Mod + Shift + P", desc: "Power off monitors" },
                                    { key: "Mod + Shift + E", desc: "Exit niri" }
                                ]
                            }
                        }
                    }
                }
            }
        }
    }

    // Keybind section component
    component KeybindSection: ColumnLayout {
        property string title
        property var keybinds: []

        Layout.fillWidth: true
        spacing: Appearance.spacing.small

        StyledText {
            text: title
            font.pixelSize: Appearance.font.size.normal
            font.weight: Font.Medium
            color: Colours.palette.m3primary
        }

        Repeater {
            model: keybinds

            RowLayout {
                required property var modelData
                Layout.fillWidth: true
                spacing: Appearance.spacing.normal

                // Key badge
                StyledRect {
                    Layout.preferredWidth: keyText.width + Appearance.padding.normal * 2
                    Layout.preferredHeight: 28
                    radius: Appearance.rounding.small
                    color: Colours.palette.m3surfaceContainerHigh
                    border.width: 1
                    border.color: Colours.palette.m3outline

                    StyledText {
                        id: keyText
                        anchors.centerIn: parent
                        text: modelData.key
                        font.pixelSize: Appearance.font.size.small
                        font.family: Appearance.font.family.mono
                        font.weight: Font.Medium
                        color: Colours.palette.m3onSurface
                    }
                }

                // Description
                StyledText {
                    Layout.fillWidth: true
                    text: modelData.desc
                    font.pixelSize: Appearance.font.size.small
                    color: Colours.palette.m3onSurfaceVariant
                }
            }
        }
    }
}
