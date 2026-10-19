import QtQuick
import qs.config
import qs.services

// Buchstabe am Chip, solange der Bar-Modus (Super+B) läuft: kleine Taste unten mittig, ragt etwas aus der Bar
Rectangle {
    id: hint

    property string key: ""

    visible: BarKeys.modeOn && key !== ""
    anchors.horizontalCenter: parent.horizontalCenter
    y: parent.height - 8
    z: 10
    width: Math.max(18, keyTxt.implicitWidth + 8)
    height: 18
    radius: 6
    color: Theme.surfaceRaised
    border.width: 1
    border.color: Theme.accent

    MonoTxt {
        id: keyTxt
        anchors.centerIn: parent
        text: hint.key
        font.pixelSize: 11
        font.weight: Font.Bold
        color: Theme.accentText
    }
}
