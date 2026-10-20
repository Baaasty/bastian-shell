import QtQuick
import qs.config
import qs.components

// Eine Zeile: links Titel + Beschreibung, rechts die Tasten (mehrere Akkorde untereinander)
Item {
    id: row

    required property var modelData   // { title, sub, chords: [{ mods, keys, tag }] }

    implicitHeight: Math.max(chordCol.implicitHeight, textCol.implicitHeight) + 12

    Column {
        id: textCol
        anchors.left: parent.left
        anchors.right: chordCol.left
        anchors.rightMargin: 14
        anchors.verticalCenter: parent.verticalCenter
        spacing: 2

        Txt {
            width: parent.width
            text: row.modelData.title
            font.pixelSize: Theme.fontMd
            font.weight: Font.Medium
            wrapMode: Text.WordWrap
            maximumLineCount: 2
        }
        Txt {
            visible: row.modelData.sub !== ""
            width: parent.width
            text: row.modelData.sub
            color: Theme.textFaint
            font.pixelSize: Theme.fontSm
            font.weight: Font.Normal
            wrapMode: Text.NoWrap
        }
    }

    Column {
        id: chordCol
        anchors.right: parent.right
        anchors.verticalCenter: parent.verticalCenter
        spacing: Theme.space1

        Repeater {
            model: row.modelData.chords

            Row {
                id: chord

                required property var modelData
                anchors.right: parent.right
                spacing: 4

                Repeater {
                    model: chord.modelData.mods
                    Row {
                        id: modItem
                        required property string modelData
                        spacing: 4
                        KeyCap { label: modItem.modelData }
                        Txt {
                            anchors.verticalCenter: parent.verticalCenter
                            text: "+"
                            color: Theme.textFaint
                            font.pixelSize: Theme.fontXs
                        }
                    }
                }
                Repeater {
                    model: chord.modelData.keys
                    KeyCap {
                        required property string modelData
                        label: modelData
                        main: true
                    }
                }
                Txt {
                    visible: chord.modelData.tag !== ""
                    anchors.verticalCenter: parent.verticalCenter
                    text: chord.modelData.tag
                    color: Theme.textFaint
                    font.pixelSize: Theme.fontSm
                    font.weight: Font.Normal
                }
            }
        }
    }
}
