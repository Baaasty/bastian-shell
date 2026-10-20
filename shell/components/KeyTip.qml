import QtQuick
import qs.config
import "keytip.js" as KT

// Gemeinsame Hinweis-Karte für alles, was „Name · Kürzel“ zeigt: Chip-Tooltips (ChipTip), Privacy-Tooltip,
// Zeile und gewählter Chip im Bar-Modus. Deckende Fläche wie die Popouts (Glass strong), Text in Inter,
// Kürzel-Abschnitte als kleine Tastenkappen (KeyCap small) – dieselben Kappen wie am Chip im Bar-Modus (KeyHint)
Glass {
    id: card

    property string text: ""
    // statt text: fertige Teile (keytip.js), z. B. wenn Tasten mitten im Satz stehen
    property var parts: null
    property color textColor: Theme.text

    strong: true
    radius: Theme.radiusMd
    width: row.implicitWidth + 2 * Theme.padCard
    height: Theme.buttonHeightSm

    Row {
        id: row
        anchors.centerIn: parent
        spacing: Theme.space1

        Repeater {
            model: card.parts || KT.parts(card.text)

            Item {
                id: part

                required property var modelData
                readonly property string kind: modelData.kind
                anchors.verticalCenter: parent ? parent.verticalCenter : undefined
                implicitWidth: kind === "key" ? cap.implicitWidth : kind === "sep" ? word.implicitWidth + Theme.space2 : word.implicitWidth
                implicitHeight: kind === "key" ? cap.implicitHeight : word.implicitHeight

                Txt {
                    id: word
                    visible: part.kind !== "key"
                    anchors.centerIn: parent
                    text: part.kind === "sep" ? "·" : part.kind === "plus" ? "+" : (part.modelData.text || "")
                    color: part.kind === "text" ? card.textColor : Theme.textFaint
                    font.pixelSize: part.kind === "plus" ? Theme.fontXs : Theme.fontSm
                    font.weight: part.kind === "text" ? Font.Medium : Font.Normal
                    elide: Text.ElideNone
                }
                KeyCap {
                    id: cap
                    visible: part.kind === "key"
                    small: true
                    label: part.kind === "key" ? part.modelData.text : ""
                    main: !!part.modelData.main
                }
            }
        }
    }
}
