pragma Singleton

import QtQuick
import Quickshell
import Quickshell.Io

// Static theme loader - replaces dynamic Caelestia color extraction
Singleton {
    id: root

    property string currentThemeName: "gruvbox-dark"
    property bool isDark: true
    property var colors: ({})
    property var wallpapers: []
    property int wallpaperIndex: 0

    readonly property string homeDir: Quickshell.env("HOME")

    readonly property string currentWallpaper: wallpapers.length > 0
        ? wallpapers[wallpaperIndex % wallpapers.length].replace("~", homeDir)
        : ""

    readonly property string themesDir: homeDir + "/.config/niri-shell/themes"
    readonly property string configPath: homeDir + "/.config/niri-shell/config.json"

    // M3 color accessors with defaults
    readonly property color primary: colors.primary ?? "#d79921"
    readonly property color onPrimary: colors.onPrimary ?? "#282828"
    readonly property color primaryContainer: colors.primaryContainer ?? "#504945"
    readonly property color onPrimaryContainer: colors.onPrimaryContainer ?? "#fabd2f"

    readonly property color secondary: colors.secondary ?? "#689d6a"
    readonly property color onSecondary: colors.onSecondary ?? "#282828"
    readonly property color secondaryContainer: colors.secondaryContainer ?? "#3c3836"
    readonly property color onSecondaryContainer: colors.onSecondaryContainer ?? "#8ec07c"

    readonly property color tertiary: colors.tertiary ?? "#b16286"
    readonly property color onTertiary: colors.onTertiary ?? "#282828"
    readonly property color tertiaryContainer: colors.tertiaryContainer ?? "#3c3836"
    readonly property color onTertiaryContainer: colors.onTertiaryContainer ?? "#d3869b"

    readonly property color error: colors.error ?? "#cc241d"
    readonly property color onError: colors.onError ?? "#ebdbb2"
    readonly property color errorContainer: colors.errorContainer ?? "#3c3836"
    readonly property color onErrorContainer: colors.onErrorContainer ?? "#fb4934"

    readonly property color background: colors.background ?? "#282828"
    readonly property color onBackground: colors.onBackground ?? "#ebdbb2"

    readonly property color surface: colors.surface ?? "#282828"
    readonly property color onSurface: colors.onSurface ?? "#ebdbb2"
    readonly property color surfaceVariant: colors.surfaceVariant ?? "#3c3836"
    readonly property color onSurfaceVariant: colors.onSurfaceVariant ?? "#d5c4a1"
    readonly property color surfaceContainer: colors.surfaceContainer ?? "#32302f"
    readonly property color surfaceContainerHigh: colors.surfaceContainerHigh ?? "#3c3836"
    readonly property color surfaceContainerHighest: colors.surfaceContainerHighest ?? "#504945"

    readonly property color outline: colors.outline ?? "#665c54"
    readonly property color outlineVariant: colors.outlineVariant ?? "#504945"

    function loadTheme(themeName) {
        themeFileView.path = `${themesDir}/${themeName}.json`;
        themeFileView.reload();
    }

    function setTheme(themeName) {
        currentThemeName = themeName;
        loadTheme(themeName);
        saveConfig();
    }

    function nextWallpaper() {
        if (wallpapers.length > 0) {
            wallpaperIndex = (wallpaperIndex + 1) % wallpapers.length;
            saveConfig();
        }
    }

    function saveConfig() {
        configFileView.setText(JSON.stringify({
            currentTheme: currentThemeName,
            wallpaperIndex: wallpaperIndex
        }, null, 2));
    }

    // Load main config on startup
    FileView {
        id: configFileView
        path: root.configPath
        watchChanges: true
        onLoaded: {
            try {
                const config = JSON.parse(text());
                root.currentThemeName = config.currentTheme ?? "gruvbox-dark";
                root.wallpaperIndex = config.wallpaperIndex ?? 0;
                root.loadTheme(root.currentThemeName);
            } catch (e) {
                console.warn("Failed to load config:", e);
                root.loadTheme("gruvbox-dark");
            }
        }
        onLoadFailed: {
            console.warn("Config file not found, using defaults");
            root.loadTheme("gruvbox-dark");
        }
    }

    // Load theme file
    FileView {
        id: themeFileView
        path: `${root.themesDir}/${root.currentThemeName}.json`
        onLoaded: {
            try {
                const theme = JSON.parse(text());
                root.isDark = theme.isDark ?? true;
                root.colors = theme.colors ?? {};
                root.wallpapers = theme.wallpapers ?? [];
                console.log("Loaded theme:", theme.name);
            } catch (e) {
                console.warn("Failed to parse theme:", e);
            }
        }
        onLoadFailed: err => {
            console.warn("Failed to load theme file:", err);
        }
    }
}
