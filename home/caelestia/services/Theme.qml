pragma Singleton

import qs.config
import qs.utils
import Quickshell
import Quickshell.Io
import QtQuick

Singleton {
    id: root

    // Current state
    property string currentThemeId: "gruvbox-dark"
    property int currentWallpaperIndex: 0
    property var currentTheme: null
    property var availableThemes: []

    // Convenience properties
    readonly property bool isDark: currentTheme?.isDark ?? true
    readonly property string currentWallpaper: {
        if (!currentTheme?.wallpapers?.length) return "";
        const wp = currentTheme.wallpapers[currentWallpaperIndex % currentTheme.wallpapers.length];
        return wp.replace("~", Quickshell.env("HOME"));
    }
    readonly property var colors: currentTheme?.colors ?? ({})
    readonly property string themeName: currentTheme?.name ?? "Unknown"
    readonly property int wallpaperCount: currentTheme?.wallpapers?.length ?? 0

    // Signals for UI updates
    signal themeChanged()
    signal wallpaperChanged()

    // Theme management
    function setTheme(themeId) {
        if (currentThemeId === themeId) return;
        currentThemeId = themeId;
        currentWallpaperIndex = 0;
        loadCurrentTheme();
        saveState();
        themeChanged();
        wallpaperChanged();
    }

    function nextWallpaper() {
        if (wallpaperCount <= 1) return;
        currentWallpaperIndex = (currentWallpaperIndex + 1) % wallpaperCount;
        applyWallpaper();
        saveState();
        wallpaperChanged();
    }

    function prevWallpaper() {
        if (wallpaperCount <= 1) return;
        currentWallpaperIndex = (currentWallpaperIndex - 1 + wallpaperCount) % wallpaperCount;
        applyWallpaper();
        saveState();
        wallpaperChanged();
    }

    function setWallpaperIndex(index) {
        if (index < 0 || index >= wallpaperCount) return;
        currentWallpaperIndex = index;
        applyWallpaper();
        saveState();
        wallpaperChanged();
    }

    // Apply current wallpaper using swaybg or similar
    function applyWallpaper() {
        if (!currentWallpaper) return;
        wallpaperProc.running = true;
    }

    // Apply colors to the Colours service
    function applyColors() {
        if (!currentTheme?.colors) return;
        Colours.loadFromTheme(currentTheme);
    }

    // Internal: load current theme from file
    function loadCurrentTheme() {
        themeLoader.path = Qt.resolvedUrl(`../themes/${currentThemeId}.json`).toString().replace("file://", "");
        themeLoader.reload();
    }

    // Internal: scan for available themes
    function scanThemes() {
        themeScanProc.running = true;
    }

    // Internal: save state to disk
    function saveState() {
        stateFile.setText(JSON.stringify({
            themeId: currentThemeId,
            wallpaperIndex: currentWallpaperIndex
        }, null, 2));
    }

    // Theme file loader
    FileView {
        id: themeLoader
        path: Qt.resolvedUrl(`../themes/${root.currentThemeId}.json`).toString().replace("file://", "")

        onLoaded: {
            try {
                root.currentTheme = JSON.parse(text());
                root.applyColors();
                root.applyWallpaper();
                console.log("Theme loaded:", root.currentTheme.name);
            } catch (e) {
                console.error("Failed to parse theme:", e);
            }
        }
        onLoadFailed: err => console.error("Failed to load theme file:", err)
    }

    // State persistence
    FileView {
        id: stateFile
        path: `${Paths.state}/theme.json`

        onLoaded: {
            try {
                const state = JSON.parse(text());
                root.currentThemeId = state.themeId ?? "gruvbox-dark";
                root.currentWallpaperIndex = state.wallpaperIndex ?? 0;
                root.loadCurrentTheme();
            } catch (e) {
                console.warn("Failed to load theme state:", e);
                root.loadCurrentTheme();
            }
        }
        onLoadFailed: {
            console.log("No theme state found, using defaults");
            root.loadCurrentTheme();
        }
    }

    // Scan for available theme files
    Process {
        id: themeScanProc
        command: ["find", Qt.resolvedUrl("../themes").toString().replace("file://", ""), "-name", "*.json", "-type", "f"]
        stdout: StdioCollector {
            onStreamFinished: {
                const files = text.trim().split("\n").filter(f => f.length > 0);
                const themes = [];

                for (const file of files) {
                    const id = file.split("/").pop().replace(".json", "");
                    themes.push({ id: id, path: file });
                }

                root.availableThemes = themes;
                console.log("Found themes:", themes.map(t => t.id).join(", "));
            }
        }
    }

    // Wallpaper setter using swaybg
    Process {
        id: wallpaperProc
        command: ["swaybg", "-i", root.currentWallpaper, "-m", "fill"]

        onStarted: {
            // Kill any existing swaybg first
            if (killProc.running) return;
            killProc.running = true;
        }
    }

    Process {
        id: killProc
        command: ["pkill", "-x", "swaybg"]
        onExited: {
            // Start new swaybg after killing old one
            Qt.callLater(() => { wallpaperProc.running = true; });
        }
    }

    Component.onCompleted: {
        scanThemes();
        // State file will trigger theme load when ready
    }
}
