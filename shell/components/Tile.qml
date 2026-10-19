import QtQuick
import QtQuick.Layouts
import qs.config

// Dashboard-Kachel: Glas + Überschrift rechts/links, Inhalt als Kinder
Glass {
    id: tile

    property string title
    property string note
    default property alias content: body.data
    // kleine Knöpfe oben rechts (neben der Notiz)
    property alias actions: actionRow.data

    // Klicks auf leere Kachelfläche schlucken: sonst fallen sie zum Dashboard-Hintergrund durch
    // („Klick daneben schließt“) und ein knapp verfehlter Knopf macht das Dashboard zu
    MouseArea {
        anchors.fill: parent
        acceptedButtons: Qt.AllButtons
    }

    Label {
        id: head
        x: 24
        y: 22
        text: tile.title
        visible: text !== ""
    }
    Row {
        id: actionRow
        anchors.right: parent.right
        anchors.rightMargin: 16
        anchors.verticalCenter: head.verticalCenter
        spacing: 4
    }
    Txt {
        anchors.right: actionRow.children.length > 0 ? actionRow.left : parent.right
        anchors.rightMargin: actionRow.children.length > 0 ? 10 : 24
        anchors.verticalCenter: head.verticalCenter
        text: tile.note
        visible: text !== ""
        color: Theme.textFaint
        font.pixelSize: 12
        font.weight: Font.Normal
    }

    Item {
        id: body
        anchors.fill: parent
        anchors.margins: 24
        anchors.topMargin: tile.title !== "" ? 50 : 24
    }
}
