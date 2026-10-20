import QtQuick
import qs.config

// Kopf eines Popouts/einer Karte: Symbol in einer kleinen Akzent-Kachel, Titel (fontLg, 600), optional leise Meta-Angabe
// dahinter. Überall gleich, damit jedes Popout auf einen Blick gleich „anfängt“ (Design-System light)
Row {
    id: title

    property string icon: ""
    property string text: ""
    property string meta: ""
    property bool metaMono: false
    property color iconColor: Theme.accentText
    property color metaColor: Theme.textFaint
    property color tile: Theme.accentFill
    // Titel darf kürzen (Kopf mit Knöpfen rechts): maximale Breite des Titeltexts, 0 = frei
    property real maxTextWidth: 0
    // große Panels (Passwörter, Pakete, Teilen …) nehmen fontXl
    property int textSize: Theme.fontLg

    spacing: Theme.space3

    Rectangle {
        visible: title.icon !== ""
        anchors.verticalCenter: parent.verticalCenter
        width: Theme.iconButton
        height: Theme.iconButton
        radius: Theme.radiusSm
        color: title.tile

        Icon {
            anchors.centerIn: parent
            name: title.icon
            size: Theme.iconSize
            color: title.iconColor
        }
    }
    Txt {
        anchors.verticalCenter: parent.verticalCenter
        width: title.maxTextWidth > 0 ? Math.min(implicitWidth, title.maxTextWidth) : implicitWidth
        text: title.text
        font.pixelSize: title.textSize
        font.weight: Font.DemiBold
    }
    Txt {
        anchors.verticalCenter: parent.verticalCenter
        visible: title.meta !== "" && !title.metaMono
        text: title.meta
        color: title.metaColor
        font.pixelSize: Theme.fontSm
        font.weight: Font.Normal
    }
    MonoTxt {
        anchors.verticalCenter: parent.verticalCenter
        visible: title.meta !== "" && title.metaMono
        text: title.meta
        color: title.metaColor
        font.pixelSize: Theme.fontSm
    }
}
