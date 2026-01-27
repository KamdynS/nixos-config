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
            visible: Visibilities.themePicker.get(modelData).visible
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
                onClicked: Visibilities.themePicker.get(window.modelData).visible = false
            }

            // Main picker panel
            StyledRect {
                id: panel

                anchors.centerIn: parent
                width: Math.min(600, parent.width - 40)
                height: Math.min(500, parent.height - 40)

                color: Colours.layer(Colours.palette.m3surfaceContainer, 0)
                radius: Appearance.rounding.large

                ColumnLayout {
                    anchors.fill: parent
                    anchors.margins: Appearance.padding.large
                    spacing: Appearance.spacing.normal

                    // Header
                    RowLayout {
                        Layout.fillWidth: true
                        spacing: Appearance.spacing.normal

                        StyledText {
                            text: qsTr("Theme & Wallpaper")
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
                            color: mouseArea.containsMouse ? Colours.palette.m3surfaceContainerHigh : "transparent"

                            MaterialIcon {
                                anchors.centerIn: parent
                                text: "close"
                                color: Colours.palette.m3onSurface
                            }

                            MouseArea {
                                id: mouseArea
                                anchors.fill: parent
                                hoverEnabled: true
                                onClicked: Visibilities.themePicker.get(window.modelData).visible = false
                            }
                        }
                    }

                    // Theme selection
                    StyledText {
                        text: qsTr("Color Theme")
                        font.pixelSize: Appearance.font.size.smaller
                        font.weight: Font.Medium
                        color: Colours.palette.m3onSurfaceVariant
                    }

                    // Theme cards row
                    RowLayout {
                        Layout.fillWidth: true
                        spacing: Appearance.spacing.normal

                        Repeater {
                            model: Theme.availableThemes

                            ThemeCard {
                                required property var modelData
                                themeId: modelData.id
                                isSelected: Theme.currentThemeId === modelData.id
                                onClicked: Theme.setTheme(modelData.id)
                            }
                        }

                        Item { Layout.fillWidth: true }
                    }

                    // Wallpaper section
                    StyledText {
                        text: qsTr("Wallpaper") + ` (${Theme.currentWallpaperIndex + 1}/${Theme.wallpaperCount})`
                        font.pixelSize: Appearance.font.size.smaller
                        font.weight: Font.Medium
                        color: Colours.palette.m3onSurfaceVariant
                    }

                    // Wallpaper preview with navigation
                    Item {
                        Layout.fillWidth: true
                        Layout.fillHeight: true

                        StyledRect {
                            anchors.fill: parent
                            radius: Appearance.rounding.normal
                            color: Colours.palette.m3surfaceContainerLow
                            clip: true

                            // Wallpaper image
                            Image {
                                id: wallpaperImage
                                anchors.fill: parent
                                anchors.margins: 2
                                source: Theme.currentWallpaper ? `file://${Theme.currentWallpaper}` : ""
                                fillMode: Image.PreserveAspectCrop
                                asynchronous: true

                                // Rounded corners
                                layer.enabled: true
                                layer.effect: Item {
                                    ShaderEffectSource {
                                        anchors.fill: parent
                                        sourceItem: wallpaperImage
                                    }
                                }
                            }

                            // Loading indicator
                            StyledText {
                                anchors.centerIn: parent
                                text: wallpaperImage.status === Image.Loading ? qsTr("Loading...") :
                                      wallpaperImage.status === Image.Error ? qsTr("No wallpaper") : ""
                                color: Colours.palette.m3onSurfaceVariant
                                visible: wallpaperImage.status !== Image.Ready
                            }

                            // Navigation arrows
                            RowLayout {
                                anchors.bottom: parent.bottom
                                anchors.left: parent.left
                                anchors.right: parent.right
                                anchors.margins: Appearance.padding.normal
                                spacing: Appearance.spacing.small

                                WallpaperNavButton {
                                    icon: "chevron_left"
                                    onClicked: Theme.prevWallpaper()
                                    visible: Theme.wallpaperCount > 1
                                }

                                Item { Layout.fillWidth: true }

                                // Wallpaper dots
                                Row {
                                    spacing: 6
                                    visible: Theme.wallpaperCount > 1 && Theme.wallpaperCount <= 10

                                    Repeater {
                                        model: Theme.wallpaperCount

                                        Rectangle {
                                            required property int index
                                            width: 8
                                            height: 8
                                            radius: 4
                                            color: index === Theme.currentWallpaperIndex
                                                ? Colours.palette.m3primary
                                                : Colours.palette.m3outline

                                            MouseArea {
                                                anchors.fill: parent
                                                onClicked: Theme.setWallpaperIndex(parent.index)
                                            }

                                            Behavior on color { CAnim {} }
                                        }
                                    }
                                }

                                Item { Layout.fillWidth: true }

                                WallpaperNavButton {
                                    icon: "chevron_right"
                                    onClicked: Theme.nextWallpaper()
                                    visible: Theme.wallpaperCount > 1
                                }
                            }
                        }
                    }

                    // Current theme info
                    RowLayout {
                        Layout.fillWidth: true
                        spacing: Appearance.spacing.small

                        MaterialIcon {
                            text: Theme.isDark ? "dark_mode" : "light_mode"
                            color: Colours.palette.m3primary
                        }

                        StyledText {
                            text: Theme.themeName
                            color: Colours.palette.m3onSurface
                        }

                        Item { Layout.fillWidth: true }
                    }
                }
            }
        }
    }

    // Theme card component
    component ThemeCard: StyledRect {
        id: card

        property string themeId
        property bool isSelected: false

        signal clicked()

        width: 100
        height: 80
        radius: Appearance.rounding.normal
        color: isSelected ? Colours.palette.m3primaryContainer : Colours.palette.m3surfaceContainerHigh
        border.width: isSelected ? 2 : 0
        border.color: Colours.palette.m3primary

        ColumnLayout {
            anchors.fill: parent
            anchors.margins: Appearance.padding.small
            spacing: 4

            // Color preview row
            Row {
                Layout.alignment: Qt.AlignHCenter
                spacing: 4

                Repeater {
                    model: [
                        themeId.includes("light") ? "#fbf1c7" : "#1d2021",  // bg
                        themeId.includes("light") ? "#b57614" : "#d79921",  // primary
                        themeId.includes("light") ? "#427b58" : "#689d6a",  // secondary
                        themeId.includes("light") ? "#8f3f71" : "#b16286"   // tertiary
                    ]

                    Rectangle {
                        required property string modelData
                        width: 16
                        height: 16
                        radius: 4
                        color: modelData
                        border.width: 1
                        border.color: Qt.rgba(0, 0, 0, 0.2)
                    }
                }
            }

            Item { Layout.fillHeight: true }

            StyledText {
                Layout.alignment: Qt.AlignHCenter
                text: themeId.includes("light") ? "Light" : "Dark"
                font.pixelSize: Appearance.font.size.small
                color: isSelected ? Colours.palette.m3onPrimaryContainer : Colours.palette.m3onSurface
            }
        }

        MouseArea {
            anchors.fill: parent
            hoverEnabled: true
            onClicked: card.clicked()
        }

        Behavior on color { CAnim {} }
        Behavior on border.width { Anim { duration: Appearance.anim.durations.small } }
    }

    // Wallpaper navigation button component
    component WallpaperNavButton: StyledRect {
        property string icon
        signal clicked()

        width: 36
        height: 36
        radius: Appearance.rounding.full
        color: navMouse.containsMouse ? Qt.rgba(0, 0, 0, 0.5) : Qt.rgba(0, 0, 0, 0.3)

        MaterialIcon {
            anchors.centerIn: parent
            text: parent.icon
            color: "white"
        }

        MouseArea {
            id: navMouse
            anchors.fill: parent
            hoverEnabled: true
            onClicked: parent.clicked()
        }

        Behavior on color { CAnim {} }
    }
}
