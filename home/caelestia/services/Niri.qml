pragma Singleton

import Quickshell
import Quickshell.Io
import QtQuick

Singleton {
    id: root

    // Parsed workspace/window/output data from DBus
    readonly property var workspaceList: internal.workspaces
    readonly property var windowList: internal.windows
    readonly property var outputList: internal.outputs
    readonly property var keyboardLayouts: internal.keyboardLayouts

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

    // Active/focused items
    readonly property var activeToplevel: windowList.find(w => w.is_focused) ?? null
    readonly property var focusedWorkspace: {
        const ws = workspaceList.find(ws => ws.is_focused);
        if (!ws) return null;
        // Add toplevels property - filter windows by workspace
        const wsWindows = windowList.filter(w => w.workspace_id === ws.id);
        ws.toplevels = { values: wsWindows };
        return ws;
    }
    readonly property var focusedMonitor: outputList.find(out => out.is_focused) ?? null
    readonly property int activeWsId: focusedWorkspace?.id ?? 1
    readonly property int focusedWorkspaceIdx: focusedWorkspace?.idx ?? 1

    // Keyboard layout (simplified for niri)
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
        // Parse hyprland-style requests and convert to niri actions
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
            // Niri doesn't have special workspaces, ignore
            console.log("Niri: special workspaces not supported");
        } else {
            console.log("Niri: unknown dispatch command:", request);
        }
    }

    // Focus workspace by index (1-based)
    function focusWorkspace(index: int): void {
        dbusCall("FocusWorkspace", [index]);
    }

    // Focus workspace relatively
    function focusWorkspaceRelative(delta: int): void {
        dbusCall("FocusWorkspaceRelative", [delta]);
    }

    // Move window to workspace
    function moveWindowToWorkspace(index: int): void {
        dbusCall("MoveWindowToWorkspace", [index]);
    }

    // Close focused window
    function closeWindow(): void {
        dbusCall("CloseWindow", []);
    }

    // Focus a specific window
    function focusWindow(id: int): void {
        dbusCall("FocusWindow", [id]);
    }

    // Send raw action
    function action(actionJson: string): void {
        dbusCall("Action", [actionJson]);
    }

    // Switch keyboard layout
    function switchKeyboardLayout(direction: string): void {
        dbusCall("SwitchKeyboardLayout", [direction]);
    }

    // Quit niri
    function quit(): void {
        dbusCall("Quit", []);
    }

    // Power off monitors
    function powerOffMonitors(): void {
        dbusCall("PowerOffMonitors", []);
    }

    // Get monitor for a shell screen (by matching output name)
    function monitorFor(screen: ShellScreen): var {
        const out = outputList.find(out => out.name === screen.name);
        if (!out) return null;

        // Find the active workspace for this output
        const ws = workspaceList.find(ws => ws.output === out.name && ws.is_active);
        const wsWindows = ws ? windowList.filter(w => w.workspace_id === ws?.id) : [];

        if (ws) {
            ws.toplevels = { values: wsWindows };
        }
        out.activeWorkspace = ws ?? null;
        return out;
    }

    // Internal helper for DBus calls
    function dbusCall(method: string, args: list<var>): void {
        const process = Qt.createQmlObject(`
            import Quickshell.Io
            Process {
                command: ["busctl", "--user", "call", "org.caelestia.Niri",
                         "/org/caelestia/Niri", "org.caelestia.Niri",
                         "${method}", ${args.length > 0 ? '"' + getSignature(args) + '"' : '""'}${args.map(a => ', "' + a + '"').join('')}]
                running: true
                onExited: destroy()
            }
        `, root, "dbusCall");
    }

    function getSignature(args: list<var>): string {
        return args.map(a => {
            if (typeof a === "number") return Number.isInteger(a) ? "i" : "d";
            if (typeof a === "string") return "s";
            if (typeof a === "boolean") return "b";
            return "v";
        }).join("");
    }

    // Internal state management
    QtObject {
        id: internal

        property var workspaces: []
        property var windows: []
        property var outputs: []
        property var keyboardLayouts: ({ names: [], current_idx: 0 })

        // Poll state from DBus (we'll improve this with property monitoring later)
        function refreshWorkspaces(): void {
            workspacesProcess.running = true;
        }

        function refreshWindows(): void {
            windowsProcess.running = true;
        }

        function refreshOutputs(): void {
            outputsProcess.running = true;
        }

        function refreshKeyboardLayouts(): void {
            keyboardProcess.running = true;
        }

        function refreshAll(): void {
            refreshWorkspaces();
            refreshWindows();
            refreshOutputs();
            refreshKeyboardLayouts();
        }
    }

    // Helper to parse busctl property output
    function parseBusctlOutput(data: string): var {
        // Output format: s "json_string" with escaped characters
        // Match from 's "' to the last '"'
        if (!data.startsWith('s "') || !data.endsWith('"')) return null;
        let json = data.slice(3, -1);  // Remove 's "' and final '"'
        // Unescape: \" -> ", \\ -> \, and handle octal escapes
        json = json.replace(/\\"/g, '"');
        json = json.replace(/\\\\/g, '\\');
        // Handle octal escapes (e.g. \302\267 for UTF-8)
        json = json.replace(/\\([0-7]{3})/g, function(m, oct) { return String.fromCharCode(parseInt(oct, 8)); });
        return JSON.parse(json);
    }

    // DBus property readers using busctl
    Process {
        id: workspacesProcess
        command: ["busctl", "--user", "get-property", "org.caelestia.Niri",
                  "/org/caelestia/Niri", "org.caelestia.Niri", "Workspaces"]
        stdout: StdioCollector {
            onStreamFinished: {
                try {
                    const result = root.parseBusctlOutput(text.trim());
                    if (result) internal.workspaces = result;
                } catch (e) {
                    console.error("Failed to parse workspaces:", e);
                }
            }
        }
    }

    Process {
        id: windowsProcess
        command: ["busctl", "--user", "get-property", "org.caelestia.Niri",
                  "/org/caelestia/Niri", "org.caelestia.Niri", "Windows"]
        stdout: StdioCollector {
            onStreamFinished: {
                try {
                    const result = root.parseBusctlOutput(text.trim());
                    if (result) internal.windows = result;
                } catch (e) {
                    console.error("Failed to parse windows:", e);
                }
            }
        }
    }

    Process {
        id: outputsProcess
        command: ["busctl", "--user", "get-property", "org.caelestia.Niri",
                  "/org/caelestia/Niri", "org.caelestia.Niri", "Outputs"]
        stdout: StdioCollector {
            onStreamFinished: {
                try {
                    const result = root.parseBusctlOutput(text.trim());
                    if (result) internal.outputs = result;
                } catch (e) {
                    console.error("Failed to parse outputs:", e);
                }
            }
        }
    }

    Process {
        id: keyboardProcess
        command: ["busctl", "--user", "get-property", "org.caelestia.Niri",
                  "/org/caelestia/Niri", "org.caelestia.Niri", "KeyboardLayouts"]
        stdout: StdioCollector {
            onStreamFinished: {
                try {
                    const result = root.parseBusctlOutput(text.trim());
                    if (result) internal.keyboardLayouts = result;
                } catch (e) {
                    console.error("Failed to parse keyboard layouts:", e);
                }
            }
        }
    }

    // Monitor DBus signals for state changes
    Process {
        id: signalMonitor
        running: true
        command: ["busctl", "--user", "monitor", "org.caelestia.Niri"]
        stdout: SplitParser {
            onRead: data => {
                if (data.includes("WorkspacesChanged")) {
                    internal.refreshWorkspaces();
                } else if (data.includes("WindowsChanged")) {
                    internal.refreshWindows();
                } else if (data.includes("OutputsChanged")) {
                    internal.refreshOutputs();
                } else if (data.includes("FocusChanged")) {
                    internal.refreshWorkspaces();
                    internal.refreshWindows();
                } else if (data.includes("KeyboardLayoutChanged")) {
                    internal.refreshKeyboardLayouts();
                }
            }
        }
    }

    // Initial state fetch
    Component.onCompleted: {
        // Small delay to ensure DBus daemon is ready
        Qt.callLater(() => {
            internal.refreshAll();
        });
    }

    // Fallback polling timer in case signals are missed
    Timer {
        interval: 100
        running: true
        repeat: true
        onTriggered: internal.refreshAll()
    }
}
