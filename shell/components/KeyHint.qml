import QtQuick
import qs.services

// Buchstabe am Chip, solange der Bar-Modus läuft: dieselbe kleine Tastenkappe wie im Tooltip (KeyTip),
// unten mittig, ragt etwas aus der Bar
KeyCap {
    id: hint

    property string key: ""

    visible: BarKeys.modeOn && key !== ""
    anchors.horizontalCenter: parent.horizontalCenter
    y: parent.height - 8
    z: 10
    small: true
    main: true
    label: key
}
