import qs.components
import qs.services
import qs.config
import QtQuick.Layouts

ColumnLayout {
    spacing: Appearance.spacing.small

    StyledText {
        text: qsTr("Capslock: %1").arg(Niri.capsLock ? "Enabled" : "Disabled")
    }

    StyledText {
        text: qsTr("Numlock: %1").arg(Niri.numLock ? "Enabled" : "Disabled")
    }
}
