import QtQuick

// Stub for AppEntry - wraps a DesktopEntry
QtObject {
    required property var entry
    property int frequency: 0

    readonly property string id: entry?.id ?? ""
    readonly property string name: entry?.name ?? ""
    readonly property string comment: entry?.comment ?? ""
    readonly property string execString: entry?.execString ?? ""
    readonly property string startupClass: entry?.startupClass ?? ""
    readonly property string genericName: entry?.genericName ?? ""
    readonly property string categories: entry?.categories?.join(",") ?? ""
    readonly property string keywords: entry?.keywords?.join(",") ?? ""
}
