import QtQuick
import qs.config

// Ein Tastenkästchen („Keycap“): helle Kappe über einer dunkleren Holzkante, Mono-Schrift.
// Eine Optik für alle Tasten-Einblendungen: Kürzel-Menü (normal), Tooltips und Bar-Modus (small) – damit
// dieselbe Taste überall gleich aussieht
Item {
    id: cap

    property string label
    property bool main: false   // eigentliche Taste (heller) statt Modifier
    property bool small: false  // kompakt: Tooltip (KeyTip) und Buchstabe am Chip (KeyHint)

    readonly property int capHeight: small ? 18 : 26

    implicitWidth: Math.max(small ? 18 : 26, txt.implicitWidth + (small ? 10 : 16))
    implicitHeight: capHeight + 2

    // Kante unten (Holz)
    Rectangle {
        y: 2
        width: parent.width
        height: cap.capHeight
        radius: cap.small ? 5 : 7
        color: Qt.tint(Theme.surface, Qt.alpha(Theme.wood, 0.7))   // deckend, auch über der Bar-Kante
    }
    // Kappe
    Rectangle {
        width: parent.width
        height: cap.capHeight
        radius: cap.small ? 5 : 7
        color: Qt.tint(Theme.surface, Qt.alpha(Theme.text, cap.main ? 0.12 : 0.07))
        border.width: 1
        border.color: Theme.border

        MonoTxt {
            id: txt
            anchors.centerIn: parent
            text: cap.label
            font.pixelSize: cap.small ? 11 : 12
            font.weight: cap.main && cap.small ? Font.Bold : Font.Normal
            color: cap.main ? Theme.text : Theme.textMuted
        }
    }
}
