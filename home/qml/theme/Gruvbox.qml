pragma Singleton
import QtQuick

QtObject {
    // Backgrounds (dark)
    readonly property color bgHard: "#1d2021"
    readonly property color bg: "#282828"
    readonly property color bgSoft: "#32302f"
    readonly property color bg1: "#3c3836"
    readonly property color bg2: "#504945"
    readonly property color bg3: "#665c54"
    readonly property color bg4: "#7c6f64"

    // Foregrounds
    readonly property color fg: "#ebdbb2"
    readonly property color fg1: "#ebdbb2"
    readonly property color fg2: "#d5c4a1"
    readonly property color fg3: "#bdae93"
    readonly property color fg4: "#a89984"
    readonly property color gray: "#928374"

    // Accent colors
    readonly property color red: "#cc241d"
    readonly property color redBright: "#fb4934"
    readonly property color green: "#98971a"
    readonly property color greenBright: "#b8bb26"
    readonly property color yellow: "#d79921"
    readonly property color yellowBright: "#fabd2f"
    readonly property color blue: "#458588"
    readonly property color blueBright: "#83a598"
    readonly property color purple: "#b16286"
    readonly property color purpleBright: "#d3869b"
    readonly property color aqua: "#689d6a"
    readonly property color aquaBright: "#8ec07c"
    readonly property color orange: "#d65d0e"
    readonly property color orangeBright: "#fe8019"

    // Semantic colors
    readonly property color accent: yellow
    readonly property color accentBright: yellowBright
    readonly property color success: greenBright
    readonly property color warning: orangeBright
    readonly property color error: redBright

    // Component-specific
    readonly property color panelBg: bg
    readonly property color panelBorder: bg3
    readonly property color hoverBg: bg1
    readonly property color activeBg: bg2
    readonly property color sliderTrack: bg3
    readonly property color sliderFill: yellow

    // Fonts
    readonly property string fontFamily: "JetBrainsMono Nerd Font"
    readonly property int fontSizeSmall: 11
    readonly property int fontSizeNormal: 13
    readonly property int fontSizeLarge: 16

    // Spacing
    readonly property int paddingSmall: 4
    readonly property int paddingNormal: 8
    readonly property int paddingLarge: 12
    readonly property int radiusSmall: 4
    readonly property int radiusNormal: 8
    readonly property int radiusLarge: 12
}
