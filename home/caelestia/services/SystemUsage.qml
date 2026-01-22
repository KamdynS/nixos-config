pragma Singleton

import qs.config
import Quickshell
import Quickshell.Io
import QtQuick

Singleton {
    id: root

    property real cpuPerc
    property real cpuTemp
    readonly property string gpuType: Config.services.gpuType.toUpperCase() || autoGpuType
    property string autoGpuType: "NONE"
    property real gpuPerc
    property real gpuTemp
    property real memUsed
    property real memTotal
    readonly property real memPerc: memTotal > 0 ? memUsed / memTotal : 0
    property real storageUsed
    property real storageTotal
    property real storagePerc: storageTotal > 0 ? storageUsed / storageTotal : 0

    property int refCount

    // Internal parsed data from daemon
    property var cpuData: ({})
    property var memoryData: ({})
    property var diskData: []
    property var tempData: []

    function formatKib(kib: real): var {
        const mib = 1024;
        const gib = 1024 ** 2;
        const tib = 1024 ** 3;

        if (kib >= tib)
            return {
                value: kib / tib,
                unit: "TiB"
            };
        if (kib >= gib)
            return {
                value: kib / gib,
                unit: "GiB"
            };
        if (kib >= mib)
            return {
                value: kib / mib,
                unit: "MiB"
            };
        return {
            value: kib,
            unit: "KiB"
        };
    }

    // Parse busctl property output (format: s "json_string")
    function parseProperty(data: string): var {
        const match = data.match(/^s "(.*)"/);
        if (match) {
            try {
                const json = match[1].replace(/\\"/g, '"').replace(/\\\\/g, '\\');
                return JSON.parse(json);
            } catch (e) {
                console.error("SystemUsage: Failed to parse:", e);
            }
        }
        return null;
    }

    Timer {
        running: root.refCount > 0
        interval: 2000
        repeat: true
        triggeredOnStart: true
        onTriggered: {
            cpuProcess.running = true;
            memoryProcess.running = true;
            diskProcess.running = true;
            tempProcess.running = true;
            gpuUsage.running = true;
        }
    }

    // GPU type detection (still needed as daemon doesn't track GPU)
    Process {
        id: gpuTypeCheck
        running: !Config.services.gpuType
        command: ["sh", "-c", "if command -v nvidia-smi &>/dev/null && nvidia-smi -L &>/dev/null; then echo NVIDIA; elif ls /sys/class/drm/card*/device/gpu_busy_percent 2>/dev/null | grep -q .; then echo GENERIC; else echo NONE; fi"]
        stdout: StdioCollector {
            onStreamFinished: root.autoGpuType = text.trim()
        }
    }

    // GPU usage (still external - daemon doesn't track GPU)
    Process {
        id: gpuUsage
        command: root.gpuType === "GENERIC" ? ["sh", "-c", "cat /sys/class/drm/card*/device/gpu_busy_percent"] : root.gpuType === "NVIDIA" ? ["nvidia-smi", "--query-gpu=utilization.gpu,temperature.gpu", "--format=csv,noheader,nounits"] : ["echo"]
        stdout: StdioCollector {
            onStreamFinished: {
                if (root.gpuType === "GENERIC") {
                    const percs = text.trim().split("\n");
                    const sum = percs.reduce((acc, d) => acc + parseInt(d, 10), 0);
                    root.gpuPerc = sum / percs.length / 100;
                } else if (root.gpuType === "NVIDIA") {
                    const [usage, temp] = text.trim().split(",");
                    root.gpuPerc = parseInt(usage, 10) / 100;
                    root.gpuTemp = parseInt(temp, 10);
                } else {
                    root.gpuPerc = 0;
                    root.gpuTemp = 0;
                }
            }
        }
    }

    // CPU stats from daemon
    Process {
        id: cpuProcess
        command: ["busctl", "--user", "get-property", "org.caelestia.Niri",
                  "/org/caelestia/System", "org.caelestia.System", "Cpu"]
        stdout: SplitParser {
            onRead: data => {
                const parsed = root.parseProperty(data);
                if (parsed) {
                    root.cpuData = parsed;
                    root.cpuPerc = (parsed.usage_percent ?? 0) / 100;
                }
            }
        }
    }

    // Memory stats from daemon
    Process {
        id: memoryProcess
        command: ["busctl", "--user", "get-property", "org.caelestia.Niri",
                  "/org/caelestia/System", "org.caelestia.System", "Memory"]
        stdout: SplitParser {
            onRead: data => {
                const parsed = root.parseProperty(data);
                if (parsed) {
                    root.memoryData = parsed;
                    // Convert bytes to KiB to match original API
                    root.memTotal = (parsed.total_bytes ?? 0) / 1024;
                    root.memUsed = (parsed.used_bytes ?? 0) / 1024;
                }
            }
        }
    }

    // Disk stats from daemon
    Process {
        id: diskProcess
        command: ["busctl", "--user", "get-property", "org.caelestia.Niri",
                  "/org/caelestia/System", "org.caelestia.System", "Disk"]
        stdout: SplitParser {
            onRead: data => {
                const parsed = root.parseProperty(data);
                if (parsed && Array.isArray(parsed)) {
                    root.diskData = parsed;
                    // Sum up all disk usage (convert bytes to KiB)
                    let totalUsed = 0;
                    let totalSpace = 0;
                    for (const disk of parsed) {
                        totalUsed += disk.used_bytes ?? 0;
                        totalSpace += disk.total_bytes ?? 0;
                    }
                    root.storageUsed = totalUsed / 1024;
                    root.storageTotal = totalSpace / 1024;
                }
            }
        }
    }

    // Temperature from daemon
    Process {
        id: tempProcess
        command: ["busctl", "--user", "get-property", "org.caelestia.Niri",
                  "/org/caelestia/System", "org.caelestia.System", "Temperatures"]
        stdout: SplitParser {
            onRead: data => {
                const parsed = root.parseProperty(data);
                if (parsed && Array.isArray(parsed)) {
                    root.tempData = parsed;
                    // Find CPU temperature (Package id 0, Tdie, or Tctl)
                    const cpuTemp = parsed.find(t =>
                        t.label.includes("Package id") ||
                        t.label === "Tdie" ||
                        t.label === "Tctl"
                    );
                    if (cpuTemp) {
                        root.cpuTemp = cpuTemp.temperature_celsius ?? 0;
                    }

                    // For generic GPU, find GPU temp if not using NVIDIA
                    if (root.gpuType === "GENERIC") {
                        const gpuTemp = parsed.find(t =>
                            t.label.includes("edge") ||
                            t.label.includes("GPU") ||
                            t.label.includes("junction")
                        );
                        if (gpuTemp) {
                            root.gpuTemp = gpuTemp.temperature_celsius ?? 0;
                        }
                    }
                }
            }
        }
    }

    // Monitor daemon signals for updates
    Process {
        id: signalMonitor
        running: root.refCount > 0
        command: ["busctl", "--user", "monitor", "org.caelestia.Niri"]
        stdout: SplitParser {
            onRead: data => {
                if (data.includes("StatsUpdated")) {
                    cpuProcess.running = true;
                    memoryProcess.running = true;
                    diskProcess.running = true;
                    tempProcess.running = true;
                }
            }
        }
    }
}
