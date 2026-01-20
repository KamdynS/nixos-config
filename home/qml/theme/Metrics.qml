pragma Singleton
import QtQuick

QtObject {
    // Screen frame dimensions
    // SYNC: These values must match layout.struts in home/niri.nix
    readonly property int screenBorderWidth: 6      // Visible border thickness
    readonly property int windowGap: 10             // Gap between border and windows
    readonly property int totalBorderWidth: screenBorderWidth + windowGap  // = 26 = struts left/right/bottom
    readonly property int barHeight: 32             // Top bar height = struts top
    readonly property int frameCornerRadius: 12    // Outer corner radius for screen frame

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
