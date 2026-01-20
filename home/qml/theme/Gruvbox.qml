pragma Singleton
import QtQuick

QtObject {
    // Light mode toggle (set to true for light theme)
    readonly property bool lightMode: true

    // Backgrounds - Dark
    readonly property color darkBgHard: "#1d2021"
    readonly property color darkBg: "#282828"
    readonly property color darkBgSoft: "#32302f"
    readonly property color darkBg1: "#3c3836"
    readonly property color darkBg2: "#504945"
    readonly property color darkBg3: "#665c54"
    readonly property color darkBg4: "#7c6f64"

    // Backgrounds - Light
    readonly property color lightBgHard: "#f9f5d7"
    readonly property color lightBg: "#fbf1c7"
    readonly property color lightBgSoft: "#f2e5bc"
    readonly property color lightBg1: "#ebdbb2"
    readonly property color lightBg2: "#d5c4a1"
    readonly property color lightBg3: "#bdae93"
    readonly property color lightBg4: "#a89984"

    // Foregrounds - Dark theme
    readonly property color darkFg: "#ebdbb2"
    readonly property color darkFg1: "#ebdbb2"
    readonly property color darkFg2: "#d5c4a1"
    readonly property color darkFg3: "#bdae93"
    readonly property color darkFg4: "#a89984"

    // Foregrounds - Light theme
    readonly property color lightFg: "#3c3836"
    readonly property color lightFg1: "#3c3836"
    readonly property color lightFg2: "#504945"
    readonly property color lightFg3: "#665c54"
    readonly property color lightFg4: "#7c6f64"

    // Active colors based on mode
    readonly property color bgHard: lightMode ? lightBgHard : darkBgHard
    readonly property color bg: lightMode ? lightBg : darkBg
    readonly property color bgSoft: lightMode ? lightBgSoft : darkBgSoft
    readonly property color bg1: lightMode ? lightBg1 : darkBg1
    readonly property color bg2: lightMode ? lightBg2 : darkBg2
    readonly property color bg3: lightMode ? lightBg3 : darkBg3
    readonly property color bg4: lightMode ? lightBg4 : darkBg4

    readonly property color fg: lightMode ? lightFg : darkFg
    readonly property color fg1: lightMode ? lightFg1 : darkFg1
    readonly property color fg2: lightMode ? lightFg2 : darkFg2
    readonly property color fg3: lightMode ? lightFg3 : darkFg3
    readonly property color fg4: lightMode ? lightFg4 : darkFg4

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

    // Screen border (always uses light bg for the frame effect)
    readonly property color screenBorder: lightBg
    readonly property int screenBorderWidth: 6
    readonly property int barHeight: 32
    readonly property int windowGap: 10  // Gap between windows and screen border
    readonly property int totalBorderWidth: screenBorderWidth + windowGap  // Total reserved space for borders
    readonly property int frameCornerRadius: 8  // Inverted corner radius for smooth transition to windows

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
