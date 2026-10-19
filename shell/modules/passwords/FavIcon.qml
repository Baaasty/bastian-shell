import QtQuick
import qs.config
import qs.components
import qs.services

// Kachel eines Logins: Website-Icon (falls geholt) auf heller Platte, sonst Buchstabe.
// Icons liegen im Cache (scripts/favicons); fehlt eins oder lädt nicht, bleibt der Buchstabe.
Rectangle {
    id: tile

    property string title
    property string domain
    property bool selected: false
    property bool strongTone: false          // Detailkopf: kräftigerer Buchstaben-Ton
    property int letterSize: 15

    readonly property string iconSrc: Favicons.src(Favicons.hostOf(domain))
    readonly property bool hasIcon: iconSrc !== "" && img.status === Image.Ready

    radius: Theme.radiusSm
    color: hasIcon ? Qt.alpha(Theme.text, 0.9) : strongTone ? Qt.alpha(Theme.accent, 0.22) : selected ? Qt.alpha(Theme.accent, 0.3) : Qt.alpha(Theme.wood, 0.55)
    border.width: 1
    border.color: hasIcon ? Qt.alpha(Theme.text, 0.2) : strongTone ? Qt.alpha(Theme.accent, 0.4) : Theme.border
    Behavior on color { ColorAnimation { duration: Theme.fade } }

    Txt {
        anchors.centerIn: parent
        visible: !tile.hasIcon
        text: (tile.title || "?").replace(/^[^A-Za-z0-9]+/, "").charAt(0).toUpperCase() || "?"
        color: tile.strongTone || tile.selected ? Theme.accentText : Theme.text
        font.pixelSize: tile.letterSize
        font.weight: Font.DemiBold
    }
    Image {
        id: img
        anchors.fill: parent
        anchors.margins: Math.round(parent.width * 0.14)
        source: tile.iconSrc
        visible: tile.hasIcon
        sourceSize: Qt.size(64, 64)
        fillMode: Image.PreserveAspectFit
        smooth: true
        asynchronous: true
        cache: true
    }
}
