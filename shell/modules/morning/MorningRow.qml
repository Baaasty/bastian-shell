import QtQuick
import qs.config
import qs.components

// Eine Zeile der Morgen-Übersicht: Symbol-Kachel links, Titel + bis zu ein paar Detailzeilen rechts.
Item {
    id: root

    property string icon: "info"
    property string title: ""
    property var lines: []          // [{ left, text }]  (left = kleine Spalte links, z. B. Uhrzeit)
    property string more: ""        // z. B. "+ 2 more"

    width: parent ? parent.width : 400
    implicitHeight: Math.max(36, col.implicitHeight)

    Rectangle {
        id: tile
        width: 36
        height: 36
        radius: Theme.radiusSm
        color: Theme.accentFill
        Icon {
            anchors.centerIn: parent
            name: root.icon
            size: 20
            color: Theme.accentText
        }
    }

    Column {
        id: col
        x: tile.width + 14
        width: root.width - x
        spacing: 3

        Txt {
            width: parent.width
            height: 36
            text: root.title
            font.pixelSize: 15
            font.weight: Font.DemiBold
            // Titel mittig zur Kachel, solange keine Zeilen darunter hängen
            verticalAlignment: Text.AlignVCenter
        }
        Repeater {
            model: root.lines
            Row {
                required property var modelData
                width: col.width
                spacing: 10
                MonoTxt {
                    width: modelData.left !== undefined && modelData.left !== "" ? 62 : 0
                    visible: width > 0
                    text: modelData.left ?? ""
                    color: Theme.textFaint
                    font.pixelSize: 12
                    elide: Text.ElideRight
                }
                Txt {
                    width: col.width - (modelData.left ? 72 : 0)
                    text: modelData.text
                    color: Theme.textMuted
                    font.pixelSize: 13
                    font.weight: Font.Normal
                }
            }
        }
        Txt {
            visible: root.more !== ""
            text: root.more
            color: Theme.textFaint
            font.pixelSize: 12
            font.weight: Font.Normal
        }
    }
}
