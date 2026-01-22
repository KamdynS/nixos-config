import QtQuick
import Quickshell
import Quickshell.Io

// Stub for FileSystemModel - requires C++ plugin for full functionality
// This is a simplified QML version that uses Process to list files
Item {
    id: root

    enum Filter {
        NoFilter,
        Images,
        Files,
        Dirs
    }

    property string path: ""
    property bool recursive: false
    property bool watchChanges: true
    property bool showHidden: false
    property bool sortReverse: false
    property int filter: FileSystemModel.NoFilter
    property var nameFilters: []
    property var entries: []

    onPathChanged: Qt.callLater(reload)
    onRecursiveChanged: Qt.callLater(reload)
    onFilterChanged: Qt.callLater(reload)
    onShowHiddenChanged: Qt.callLater(reload)

    function reload() {
        if (!path) {
            entries = [];
            return;
        }
        listProc.running = true;
    }

    Process {
        id: listProc

        property string filterArg: {
            switch (root.filter) {
            case FileSystemModel.Images:
                return "-e jpg -e jpeg -e png -e gif -e webp -e bmp -e svg";
            case FileSystemModel.Files:
                return "--type f";
            case FileSystemModel.Dirs:
                return "--type d";
            default:
                return "";
            }
        }

        command: {
            let cmd = ["find", root.path];
            if (!root.recursive) {
                cmd.push("-maxdepth", "1");
            }
            if (root.filter === FileSystemModel.Images) {
                cmd.push("-type", "f", "(", "-iname", "*.jpg", "-o", "-iname", "*.jpeg", "-o", "-iname", "*.png", "-o", "-iname", "*.gif", "-o", "-iname", "*.webp", "-o", "-iname", "*.bmp", "-o", "-iname", "*.svg", ")");
            } else if (root.filter === FileSystemModel.Files) {
                cmd.push("-type", "f");
            } else if (root.filter === FileSystemModel.Dirs) {
                cmd.push("-type", "d");
            }
            if (!root.showHidden) {
                cmd.push("-not", "-path", "*/.*");
            }
            return cmd;
        }

        stdout: StdioCollector {
            onStreamFinished: {
                const lines = text.trim().split("\n").filter(l => l.length > 0);
                const newEntries = [];

                for (const line of lines) {
                    if (line === root.path) continue;

                    const parts = line.split("/");
                    const name = parts[parts.length - 1];
                    const baseName = name.includes(".") ? name.substring(0, name.lastIndexOf(".")) : name;
                    const suffix = name.includes(".") ? name.substring(name.lastIndexOf(".") + 1) : "";
                    const isImage = ["jpg", "jpeg", "png", "gif", "webp", "bmp", "svg"].includes(suffix.toLowerCase());
                    const relativePath = line.replace(root.path + "/", "");

                    newEntries.push({
                        path: line,
                        relativePath: relativePath,
                        name: name,
                        baseName: baseName,
                        parentDir: line.substring(0, line.lastIndexOf("/")),
                        suffix: suffix,
                        size: 0,
                        isDir: false,
                        isImage: isImage,
                        mimeType: isImage ? "image/" + suffix : "application/octet-stream"
                    });
                }

                if (root.sortReverse) {
                    newEntries.reverse();
                }

                root.entries = newEntries;
            }
        }
    }

    Component.onCompleted: Qt.callLater(reload)
}
