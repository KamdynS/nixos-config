pragma Singleton

import Quickshell
import Quickshell.Io
import QtQuick

Singleton {
    id: root

    // Stable data stores - these get updated in-place, not replaced
    property var workspaceList: []
    property var windowList: []
    property var outputList: []
    property var keyboardLayouts: ({ names: [], current_idx: 0 })

    // Focused state - read directly from daemon's scalar properties
    property string focusedOutputName: ""
    property int focusedWorkspaceId: 0
    property int focusedWindowId: 0

    // Convenience getters matching Hyprland API style
    readonly property var toplevels: {
        let map = new Map();
        for (const w of windowList) {
            map.set(w.id, w);
        }
        return { values: windowList };
    }

    readonly property var workspaces: {
        let map = new Map();
        for (const ws of workspaceList) {
            map.set(ws.id, ws);
        }
        return { values: workspaceList };
    }

    readonly property var monitors: {
        let map = new Map();
        for (const out of outputList) {
            map.set(out.name, out);
        }
        return { values: outputList };
    }

    // Active/focused items derived from the scalar properties
    readonly property var activeToplevel: windowList.find(w => w.id === focusedWindowId) ?? null
    readonly property var focusedWorkspace: {
        const ws = workspaceList.find(ws => ws.id === focusedWorkspaceId);
        if (!ws) return null;
        // Add toplevels property - filter windows by workspace
        const wsWindows = windowList.filter(w => w.workspace_id === ws.id);
        // QML doesn't support spread, use Object.assign
        return Object.assign({}, ws, { toplevels: { values: wsWindows } });
    }
    // Return a simple object with the name - stable reference since it's derived from string
    readonly property var focusedMonitor: focusedOutputName ? { name: focusedOutputName } : null
    readonly property int activeWsId: focusedWorkspaceId
    readonly property int focusedWorkspaceIdx: focusedWorkspace?.idx ?? 1

    // Keyboard layout
    readonly property string kbLayout: {
        const layouts = keyboardLayouts;
        if (layouts.names && layouts.names.length > 0) {
            return layouts.names[layouts.current_idx] ?? "??";
        }
        return "??";
    }
    readonly property string kbLayoutFull: kbLayout
    readonly property bool capsLock: false  // Not available via niri IPC
    readonly property bool numLock: false   // Not available via niri IPC

    // Signals for compatibility
    signal configReloaded

    // Dispatch actions to niri
    function dispatch(request: string): void {
        const parts = request.split(" ");
        const cmd = parts[0];

        if (cmd === "workspace") {
            const wsNum = parseInt(parts[1]);
            if (!isNaN(wsNum)) {
                focusWorkspace(wsNum);
            }
        } else if (cmd === "movetoworkspace") {
            const wsNum = parseInt(parts[1]);
            if (!isNaN(wsNum)) {
                moveWindowToWorkspace(wsNum);
            }
        } else if (cmd === "togglespecialworkspace") {
            console.log("Niri: special workspaces not supported");
        } else {
            console.log("Niri: unknown dispatch command:", request);
        }
    }

    // Focus workspace by index (1-based, on current output only)
    function focusWorkspace(index: int): void {
        dbusCall.call("FocusWorkspace", "u", [index]);
    }

    // Focus workspace by global ID (works across outputs)
    function focusWorkspaceById(id: int): void {
        dbusCall.call("FocusWorkspaceById", "t", [id]);
    }

    // Focus workspace relatively
    function focusWorkspaceRelative(delta: int): void {
        dbusCall.call("FocusWorkspaceRelative", "i", [delta]);
    }

    // Move window to workspace
    function moveWindowToWorkspace(index: int): void {
        dbusCall.call("MoveWindowToWorkspace", "u", [index]);
    }

    // Close focused window
    function closeWindow(): void {
        dbusCall.call("CloseWindow", "", []);
    }

    // Focus a specific window
    function focusWindow(id: int): void {
        dbusCall.call("FocusWindow", "t", [id]);
    }

    // Send raw action
    function action(actionJson: string): void {
        dbusCall.call("Action", "s", [actionJson]);
    }

    // Switch keyboard layout
    function switchKeyboardLayout(direction: string): void {
        dbusCall.call("SwitchKeyboardLayout", "s", [direction]);
    }

    // Quit niri
    function quit(): void {
        dbusCall.call("Quit", "", []);
    }

    // Power off monitors
    function powerOffMonitors(): void {
        dbusCall.call("PowerOffMonitors", "", []);
    }

    // Get monitor info for a shell screen (by matching output name)
    function monitorFor(screen: ShellScreen): var {
        const out = outputList.find(out => out.name === screen.name);
        if (!out) return null;

        // Find the active workspace for this output
        const ws = workspaceList.find(ws => ws.output === out.name && ws.is_active);
        const wsWindows = ws ? windowList.filter(w => w.workspace_id === ws?.id) : [];

        // Build workspace with toplevels (QML doesn't support spread)
        const activeWorkspace = ws ? Object.assign({}, ws, { toplevels: { values: wsWindows } }) : null;

        // Return enriched output info with compatibility aliases
        return Object.assign({}, out, {
            // Alias for compatibility (struct has is_focused, code expects focused)
            focused: out.is_focused,
            // Alias id to name for code that expects numeric id
            id: out.name,
            activeWorkspace: activeWorkspace
        });
    }

    // Helper for DBus method calls
    QtObject {
        id: dbusCall

        function call(method: string, signature: string, args: list<var>): void {
            const cmd = ["busctl", "--user", "call", "org.caelestia.Niri",
                        "/org/caelestia/Niri", "org.caelestia.Niri", method];
            if (signature) {
                cmd.push(signature);
                for (const arg of args) {
                    cmd.push(String(arg));
                }
            }

            const process = Qt.createQmlObject(`
                import Quickshell.Io
                Process {
                    command: ${JSON.stringify(cmd)}
                    running: true
                    onExited: destroy()
                }
            `, root, "dbusCall");
        }
    }

    // Parse busctl property output (format: s "json_string" or t 123 etc)
    function parseStringProperty(data: string): string {
        if (!data.startsWith('s "') || !data.endsWith('"')) return "";
        let str = data.slice(3, -1);
        str = str.replace(/\\"/g, '"').replace(/\\\\/g, '\\');
        return str;
    }

    function parseIntProperty(data: string): int {
        const match = data.match(/^[tu]\s+(\d+)/);
        return match ? parseInt(match[1]) : 0;
    }

    function parseJsonProperty(data: string): var {
        const str = parseStringProperty(data);
        if (!str) return null;
        try {
            // Handle octal escapes for UTF-8
            const decoded = str.replace(/(\\[0-7]{3})+/g, function(match) {
                const bytes = [];
                const octals = match.match(/\\([0-7]{3})/g);
                for (const oct of octals) {
                    bytes.push(parseInt(oct.slice(1), 8));
                }
                try {
                    return decodeURIComponent(bytes.map(b => '%' + b.toString(16).padStart(2, '0')).join(''));
                } catch (e) {
                    return bytes.map(b => String.fromCharCode(b)).join('');
                }
            });
            return JSON.parse(decoded);
        } catch (e) {
            console.error("Niri: Failed to parse JSON:", e);
            return null;
        }
    }

    // Property readers - only run when triggered by signals or on startup
    Process {
        id: workspacesReader
        command: ["busctl", "--user", "get-property", "org.caelestia.Niri",
                  "/org/caelestia/Niri", "org.caelestia.Niri", "Workspaces"]
        stdout: StdioCollector {
            onStreamFinished: {
                const result = root.parseJsonProperty(text.trim());
                if (result) root.workspaceList = result;
            }
        }
    }

    Process {
        id: windowsReader
        command: ["busctl", "--user", "get-property", "org.caelestia.Niri",
                  "/org/caelestia/Niri", "org.caelestia.Niri", "Windows"]
        stdout: StdioCollector {
            onStreamFinished: {
                const result = root.parseJsonProperty(text.trim());
                if (result) root.windowList = result;
            }
        }
    }

    Process {
        id: outputsReader
        command: ["busctl", "--user", "get-property", "org.caelestia.Niri",
                  "/org/caelestia/Niri", "org.caelestia.Niri", "Outputs"]
        stdout: StdioCollector {
            onStreamFinished: {
                const result = root.parseJsonProperty(text.trim());
                if (result) root.outputList = result;
            }
        }
    }

    Process {
        id: keyboardReader
        command: ["busctl", "--user", "get-property", "org.caelestia.Niri",
                  "/org/caelestia/Niri", "org.caelestia.Niri", "KeyboardLayouts"]
        stdout: StdioCollector {
            onStreamFinished: {
                const result = root.parseJsonProperty(text.trim());
                if (result) root.keyboardLayouts = result;
            }
        }
    }

    // Scalar property readers - lightweight, just read simple values
    Process {
        id: focusedOutputReader
        command: ["busctl", "--user", "get-property", "org.caelestia.Niri",
                  "/org/caelestia/Niri", "org.caelestia.Niri", "FocusedOutput"]
        stdout: StdioCollector {
            onStreamFinished: {
                root.focusedOutputName = root.parseStringProperty(text.trim());
            }
        }
    }

    Process {
        id: focusedWorkspaceReader
        command: ["busctl", "--user", "get-property", "org.caelestia.Niri",
                  "/org/caelestia/Niri", "org.caelestia.Niri", "FocusedWorkspace"]
        stdout: StdioCollector {
            onStreamFinished: {
                root.focusedWorkspaceId = root.parseIntProperty(text.trim());
            }
        }
    }

    Process {
        id: focusedWindowReader
        command: ["busctl", "--user", "get-property", "org.caelestia.Niri",
                  "/org/caelestia/Niri", "org.caelestia.Niri", "FocusedWindow"]
        stdout: StdioCollector {
            onStreamFinished: {
                root.focusedWindowId = root.parseIntProperty(text.trim());
            }
        }
    }

    // Signal monitor - listens for daemon signals and triggers appropriate refreshes
    Process {
        id: signalMonitor
        running: true
        command: ["busctl", "--user", "monitor", "org.caelestia.Niri"]
        stdout: SplitParser {
            onRead: data => {
                if (data.includes("WorkspacesUpdated")) {
                    workspacesReader.running = true;
                } else if (data.includes("WindowsUpdated")) {
                    windowsReader.running = true;
                } else if (data.includes("OutputsUpdated")) {
                    outputsReader.running = true;
                } else if (data.includes("FocusUpdated")) {
                    // Only refresh the lightweight scalar properties
                    focusedOutputReader.running = true;
                    focusedWorkspaceReader.running = true;
                    focusedWindowReader.running = true;
                } else if (data.includes("KeyboardLayoutUpdated")) {
                    keyboardReader.running = true;
                }
            }
        }
    }

    // Initial state fetch on startup
    Component.onCompleted: {
        Qt.callLater(() => {
            workspacesReader.running = true;
            windowsReader.running = true;
            outputsReader.running = true;
            keyboardReader.running = true;
            focusedOutputReader.running = true;
            focusedWorkspaceReader.running = true;
            focusedWindowReader.running = true;
        });
    }
}
