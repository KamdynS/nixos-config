pragma Singleton

import QtQuick
import Quickshell

// Stub for Caelestia's C++ CUtils class
// Provides basic file utility functions
Singleton {
    id: root

    // Convert URL to local file path
    function toLocalFile(url) {
        if (typeof url === "string") {
            return url.replace("file://", "");
        }
        return url.toString().replace("file://", "");
    }

    // Save an item as an image (stub - uses external tools)
    function saveItem(item, targetPath, rect, callback) {
        // This would require C++ to grab framebuffer
        // For now, just call callback with the path
        console.warn("CUtils.saveItem: Requires C++ plugin, using fallback");
        if (callback) {
            callback(toLocalFile(targetPath));
        }
    }

    // Copy a file
    function copyFile(source, dest) {
        const srcPath = toLocalFile(source);
        const destPath = toLocalFile(dest);
        // Use a process to copy
        const proc = Qt.createQmlObject(`
            import Quickshell.Io
            Process {
                command: ["cp", "${srcPath}", "${destPath}"]
                running: true
                onExited: destroy()
            }
        `, root, "copyFile");
        return true;
    }
}
