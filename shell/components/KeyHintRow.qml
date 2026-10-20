import QtQuick
import qs.config
import "keytip.js" as KT

// Hinweis-/Fußzeile „Taste Wort · Taste Wort“: überall dieselbe Form (Workspace-Modus, Launcher, Clipboard,
// Super+K, Panels), damit man Tasten auf einen Blick findet. hints = [["Enter", "open"], ["Shift+↵", "copy"], …];
// Kürzel mit Modifier werden zu einzelnen Kappen (keytip.js keys). small = kleine Kappen (enge Leisten).
// Ohne gesetzte Breite eine Zeile; mit Breite (schmale Karten) bricht sie um statt abzuschneiden.
// gap = Abstand zwischen den Einträgen (spacing ist hier der Zeilenabstand beim Umbruch)
Flow {
    id: hintRow

    property var hints: []
    property bool small: false
    property color textColor: Theme.textMuted
    property int gap: Theme.space4

    spacing: Theme.space1

    Repeater {
        model: hintRow.hints

        Row {
            id: hint

            required property var modelData
            required property int index
            // Paar ["Taste", "Wort"] oder {key, label}; QML reicht Arrays als Sequenz durch (kein echtes Array) → per Feld prüfen
            readonly property string key: modelData.key !== undefined ? modelData.key : (modelData[0] || "")
            readonly property string label: modelData.label !== undefined ? modelData.label : (modelData[1] || "")

            spacing: Theme.space2
            rightPadding: index < hintRow.hints.length - 1 ? hintRow.gap : 0

            Row {
                anchors.verticalCenter: parent.verticalCenter
                spacing: Theme.space1

                Repeater {
                    model: KT.keys(hint.key)

                    Item {
                        id: part

                        required property var modelData
                        anchors.verticalCenter: parent ? parent.verticalCenter : undefined
                        implicitWidth: modelData.kind === "key" ? cap.implicitWidth : plus.implicitWidth
                        implicitHeight: cap.implicitHeight

                        Txt {
                            id: plus
                            visible: part.modelData.kind === "plus"
                            anchors.centerIn: parent
                            text: "+"
                            color: Theme.textFaint
                            font.pixelSize: Theme.fontXs
                            font.weight: Font.Normal
                        }
                        KeyCap {
                            id: cap
                            visible: part.modelData.kind === "key"
                            small: hintRow.small
                            label: part.modelData.kind === "key" ? part.modelData.text : ""
                            main: !!part.modelData.main
                        }
                    }
                }
            }
            Txt {
                anchors.verticalCenter: parent.verticalCenter
                visible: hint.label !== ""
                text: hint.label
                color: hintRow.textColor
                font.pixelSize: Theme.fontSm
                font.weight: Font.Normal
            }
        }
    }
}
