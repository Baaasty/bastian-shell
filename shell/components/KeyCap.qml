import QtQuick
import qs.config

// Ein Tastenkästchen („Keycap“): dunkle Mulde (surfaceSunken) mit dunkler Fuge darunter, Mono-Schrift.
// Die einzige Tasten-Optik der Shell: Hinweiszeilen (KeyHintRow), Super+K, Tooltips (KeyTip) und Bar-Modus (KeyHint) –
// damit dieselbe Taste überall gleich aussieht. Haupttaste warm (accentText), Modifier leise (textMuted).
// small: kompakt für Chip-Buchstaben und Tooltips
Item {
    id: cap

    property string label
    property bool main: false   // eigentliche Taste (warm) statt Modifier
    property bool small: false  // kompakt: Tooltip (KeyTip) und Buchstabe am Chip (KeyHint)

    readonly property int capHeight: small ? Theme.keyCapHeightSm : Theme.keyCapHeight
    readonly property int pad: small ? Theme.space1 : Theme.space2

    implicitWidth: Math.max(capHeight + Theme.keyCapLip, txt.implicitWidth + 2 * pad)
    implicitHeight: capHeight + Theme.keyCapLip

    // Fuge unten (eine Stufe dunkler als die Mulde): gibt der Kappe Tiefe ohne Glanz
    Rectangle {
        y: Theme.keyCapLip
        width: parent.width
        height: cap.capHeight
        radius: face.radius
        color: Theme.keyLip
    }
    // Kappe
    Rectangle {
        id: face
        width: parent.width
        height: cap.capHeight
        radius: Theme.radiusXs
        color: Theme.surfaceSunken
        border.width: 1
        border.color: Theme.borderStrong

        MonoTxt {
            id: txt
            anchors.centerIn: parent
            text: cap.label
            font.pixelSize: cap.small ? Theme.fontXs : Theme.fontSm
            font.weight: cap.main ? Font.DemiBold : Font.Medium
            color: cap.main ? Theme.accentText : Theme.textMuted
        }
    }
}
