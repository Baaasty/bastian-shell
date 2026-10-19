import QtQuick
import qs.config

// UI-Text (Inter)
Text {
    color: Theme.text
    font.family: Theme.fontUi
    font.pixelSize: Theme.fontSize
    font.weight: Font.Medium
    verticalAlignment: Text.AlignVCenter
    elide: Text.ElideRight
    textFormat: Text.PlainText
}
