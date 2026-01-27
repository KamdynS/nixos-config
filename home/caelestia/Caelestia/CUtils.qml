pragma Singleton

import QtQuick
import Quickshell

// Stub for Caelestia's C++ CUtils class
Singleton {
    id: root

    function toLocalFile(url) {
        if (typeof url === "string") {
            return url.replace("file://", "");
        }
        return url.toString().replace("file://", "");
    }

    function saveItem(item, targetPath, rect, callback) {
        console.warn("CUtils.saveItem: Requires C++ plugin");
        if (callback) {
            callback(toLocalFile(targetPath));
        }
    }

    function copyFile(source, dest) {
        const srcPath = toLocalFile(source);
        const destPath = toLocalFile(dest);
        console.log("CUtils.copyFile:", srcPath, "->", destPath);
        return true;
    }
}
