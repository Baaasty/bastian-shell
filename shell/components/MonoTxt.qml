import QtQuick
import qs.config

// Zahlen, Uhr, Stats (JetBrains Mono, tabellarische Ziffern)
Text {
    color: Theme.text
    font.family: Theme.fontMono
    font.pixelSize: 13
    font.features: { "tnum": 1 }
    verticalAlignment: Text.AlignVCenter
    textFormat: Text.PlainText
}
