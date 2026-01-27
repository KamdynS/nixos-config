pragma Singleton
import QtQuick

QtObject {
    // Spacing (padding)
    readonly property int paddingSmall: 4
    readonly property int paddingNormal: 8
    readonly property int paddingLarge: 12

    // Corner radii for UI elements
    readonly property int radiusSmall: 4
    readonly property int radiusNormal: 8
    readonly property int radiusLarge: 12

    // Font sizes
    readonly property int fontSizeSmall: 11
    readonly property int fontSizeNormal: 13
    readonly property int fontSizeLarge: 16

    // Font family
    readonly property string fontFamily: "JetBrainsMono Nerd Font"
}
