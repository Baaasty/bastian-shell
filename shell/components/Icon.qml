import QtQuick
import qs.config

// Material Symbols Rounded (Ligaturen: Icon-Name als Text)
Text {
    property string name
    property bool fill: false
    property int size: 18

    text: name
    color: Theme.textMuted
    font.family: Theme.fontIcon
    font.pixelSize: size
    font.variableAxes: ({ "FILL": fill ? 1 : 0, "wght": 400, "opsz": 24 })
    horizontalAlignment: Text.AlignHCenter
    verticalAlignment: Text.AlignVCenter
}
