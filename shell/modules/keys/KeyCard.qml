import QtQuick
import qs.config
import qs.components

// Karte einer Kategorie (oder ein Stück davon). Eingeklappt (Media keys): nur Kopf, Klick klappt auf.
Rectangle {
    id: card

    required property var modelData   // { name, note, cont, rows, media, collapsed, count }
    property bool hot: false           // gehört zur fokussierten App: Glut-Rand
    signal toggled()

    implicitHeight: 14 + head.height + (body.visible ? body.implicitHeight + 4 : 0) + 14
    radius: Theme.radiusLg
    color: Qt.alpha(Theme.text, 0.035)
    border.width: 1
    border.color: hot ? Qt.alpha(Theme.accent, 0.45) : Theme.border

    Item {
        id: head
        x: 18
        y: 14
        width: parent.width - 36
        height: 26

        Txt {
            id: name
            anchors.verticalCenter: parent.verticalCenter
            text: card.modelData.name.toUpperCase()
            color: Theme.accentText
            font.pixelSize: 12
            font.weight: Font.DemiBold
            font.letterSpacing: 1.4
        }
        Txt {
            anchors.left: name.right
            anchors.leftMargin: 10
            anchors.right: parent.right
            anchors.verticalCenter: parent.verticalCenter
            visible: text !== ""
            text: card.modelData.cont ? "continued" : (card.modelData.note || "")
            elide: Text.ElideRight
            color: Theme.textFaint
            font.pixelSize: 11
            font.weight: Font.Normal
        }
        Row {
            visible: card.modelData.media
            anchors.right: parent.right
            anchors.verticalCenter: parent.verticalCenter
            spacing: 6
            Txt {
                anchors.verticalCenter: parent.verticalCenter
                visible: card.modelData.collapsed
                text: card.modelData.count + " keys"
                color: Theme.textFaint
                font.pixelSize: 12
                font.weight: Font.Normal
            }
            Icon {
                anchors.verticalCenter: parent.verticalCenter
                name: card.modelData.collapsed ? "expand_more" : "expand_less"
                size: 20
                color: Theme.textMuted
            }
        }
        MouseArea {
            anchors.fill: parent
            enabled: card.modelData.media
            cursorShape: Qt.PointingHandCursor
            onClicked: card.toggled()
        }
    }

    Column {
        id: body
        visible: !card.modelData.collapsed
        x: 18
        y: head.y + head.height + 4
        width: parent.width - 36

        Repeater {
            model: card.modelData.rows
            KeyRow {
                width: body.width
            }
        }
    }
}
