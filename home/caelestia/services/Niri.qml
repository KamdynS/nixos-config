pragma Singleton

import qs.components.misc
import qs.config
import Quickshell
import Quickshell.DBusMenu
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
    readonly property var focusedWorkspace: workspaceList.find(ws => ws.is_focused) ?? null
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
        return outputList.find(out => out.name === screen.name) ?? null;
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

    // DBus property readers using busctl
    Process {
        id: workspacesProcess
        command: ["busctl", "--user", "get-property", "org.caelestia.Niri",
                  "/org/caelestia/Niri", "org.caelestia.Niri", "Workspaces"]
        stdout: SplitParser {
            onRead: data => {
                // Output format: s "json_string"
                const match = data.match(/^s "(.*)"/);
                if (match) {
                    try {
                        // Unescape the JSON string
                        const json = match[1].replace(/\\"/g, '"').replace(/\\\\/g, '\\');
                        internal.workspaces = JSON.parse(json);
                    } catch (e) {
                        console.error("Failed to parse workspaces:", e);
                    }
                }
            }
        }
    }

    Process {
        id: windowsProcess
        command: ["busctl", "--user", "get-property", "org.caelestia.Niri",
                  "/org/caelestia/Niri", "org.caelestia.Niri", "Windows"]
        stdout: SplitParser {
            onRead: data => {
                const match = data.match(/^s "(.*)"/);
                if (match) {
                    try {
                        const json = match[1].replace(/\\"/g, '"').replace(/\\\\/g, '\\');
                        internal.windows = JSON.parse(json);
                    } catch (e) {
                        console.error("Failed to parse windows:", e);
                    }
                }
            }
        }
    }

    Process {
        id: outputsProcess
        command: ["busctl", "--user", "get-property", "org.caelestia.Niri",
                  "/org/caelestia/Niri", "org.caelestia.Niri", "Outputs"]
        stdout: SplitParser {
            onRead: data => {
                const match = data.match(/^s "(.*)"/);
                if (match) {
                    try {
                        const json = match[1].replace(/\\"/g, '"').replace(/\\\\/g, '\\');
                        internal.outputs = JSON.parse(json);
                    } catch (e) {
                        console.error("Failed to parse outputs:", e);
                    }
                }
            }
        }
    }

    Process {
        id: keyboardProcess
        command: ["busctl", "--user", "get-property", "org.caelestia.Niri",
                  "/org/caelestia/Niri", "org.caelestia.Niri", "KeyboardLayouts"]
        stdout: SplitParser {
            onRead: data => {
                const match = data.match(/^s "(.*)"/);
                if (match) {
                    try {
                        const json = match[1].replace(/\\"/g, '"').replace(/\\\\/g, '\\');
                        internal.keyboardLayouts = JSON.parse(json);
                    } catch (e) {
                        console.error("Failed to parse keyboard layouts:", e);
                    }
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
        interval: 2000
        running: true
        repeat: true
        onTriggered: internal.refreshAll()
    }
}
