import QtQuick
import qs.config
import qs.components

// Ein Tastenkästchen („Keycap“): helle Kappe über einer dunkleren Kante, Mono-Schrift
Item {
    id: cap

    property string label
    property bool main: false   // eigentliche Taste (heller) statt Modifier

    implicitWidth: Math.max(26, txt.implicitWidth + 16)
    implicitHeight: 28

    // Kante unten (Holz)
    Rectangle {
        y: 2
        width: parent.width
        height: 26
        radius: 7
        color: Qt.alpha(Theme.wood, 0.7)
    }
    // Kappe
    Rectangle {
        width: parent.width
        height: 26
        radius: 7
        color: Qt.tint(Theme.surface, Qt.alpha(Theme.text, cap.main ? 0.12 : 0.07))
        border.width: 1
        border.color: Theme.border

        MonoTxt {
            id: txt
            anchors.centerIn: parent
            text: cap.label
            font.pixelSize: 12
            color: cap.main ? Theme.text : Theme.textMuted
        }
    }
}
