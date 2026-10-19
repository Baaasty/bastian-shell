import QtQuick
import Quickshell
import qs.config
import qs.services
import qs.components

// GoXLR-Teil, gemeinsam genutzt von der Dashboard-Kachel „Light & Sound“ (breit) und dem Sound-Popout der Bar (compact):
//  - Pegel der Kanäle, nur zum Ansehen (GoxlrLevel). nur Hauptkanäle System (Speakers), Music, Chat, Mic –
//    Chat steht hinten (Discord-Ohren), danach das Mikro.
//  - Routing wie bisher im Dashboard: „Speakers“ (System/Music/Chat -> LineOut) und „Discord hears“ (System/Music -> ChatMic),
//    geschaltet über GoXLR.toggle (nacheinander, siehe GoXLR.qml). Die System-Lautstärke bleibt fest auf 100 % (docs/setup/goxlr.md).
// Teile einzeln abschaltbar (showLevels / showSpeakers / showChat): das Sound-Popout nutzt nur das Routing (oben, beide Zeilen),
// die Pegel setzt es selbst als Zeilen (GoxlrLevel mit nameW).
// compact: Pegel in 2 Spalten (~420 px); sonst 4 Spalten (breite Kachel). Fragt die GoXLR Utility nur ab, solange sichtbar.
// outlined: inaktive Chips nur umrandet statt gefüllt (Popout: aktiv/inaktiv deutlicher); das Dashboard bleibt beim Stil seiner Szenen-Chips.
Item {
    id: panel

    property bool compact: false
    property string title: "GoXLR"
    property bool showLevels: true
    property bool showSpeakers: true
    property bool showChat: true
    property bool showOffline: true      // Hinweis „Utility läuft nicht“ (bei mehreren Panels nur einmal)
    // Breite der Namensspalte der Routing-Zeilen (Dashboard: 96 + 12 + 44, damit die Chips mit den anderen Zeilen fluchten)
    property int nameW: 96
    property bool outlined: false

    readonly property bool shown: visible && !!QsWindow.window && QsWindow.window.visible
    // Eingänge in der Reihenfolge System, Music, Chat (Chat zuletzt)
    readonly property var speakerInputs: [["System", "System"], ["Music", "Music"], ["Chat", "Chat"]]
    readonly property var chatInputs: [["System", "System"], ["Music", "Music"]]

    implicitWidth: 360
    implicitHeight: col.implicitHeight

    // Zuschauer melden (GoXLR.qml zählt mit: Dashboard und Popout können gleichzeitig offen sein)
    property bool _watching: false
    onShownChanged: sync()
    Component.onCompleted: sync()
    Component.onDestruction: {
        if (_watching)
            GoXLR.watch(false);
    }
    function sync(): void {
        if (shown !== _watching) {
            _watching = shown;
            GoXLR.watch(shown);
        }
    }

    // Auswahl-Chip: aktiv = Glut-Ton (wie in der Dashboard-Kachel); outlined: inaktiv nur Rahmen, Hover leise gefüllt
    component Pick: Chip {
        id: pk
        property string label
        padding: 12
        color: active ? Theme.accentSoft : hovered ? Qt.alpha(Theme.text, 0.1) : panel.outlined ? "transparent" : Theme.raise
        border.width: panel.outlined ? 1 : 0
        border.color: active ? Qt.alpha(Theme.accent, 0.45) : Theme.borderStrong
        Txt {
            anchors.verticalCenter: parent.verticalCenter
            text: pk.label
            color: pk.active ? Theme.accentText : Theme.textMuted
        }
    }

    component Name: Txt {
        width: panel.nameW
        anchors.verticalCenter: parent ? parent.verticalCenter : undefined
        color: Theme.textMuted
        font.pixelSize: 13
        font.weight: Font.Normal
    }

    Column {
        id: col
        width: panel.width
        spacing: 8

        Label {
            visible: panel.title !== ""
            text: panel.title
        }

        Txt {
            visible: !GoXLR.online && panel.showOffline
            width: parent.width
            height: GoXLR.online || !panel.showOffline ? 0 : 28
            text: GoXLR.ready ? "GoXLR Utility isn’t running" : "Loading…"
            color: Theme.textFaint
            font.pixelSize: 13
            font.weight: Font.Normal
        }

        // ---------- Pegel (nur lesen) ----------
        Grid {
            id: levels
            visible: GoXLR.online && panel.showLevels
            columns: panel.compact ? 2 : 4
            columnSpacing: 20
            rowSpacing: 6
            Repeater {
                // nur die Hauptkanäle (Game, Sample, Headphones bleiben weg)
                model: GoXLR.levels.filter(l => ["System", "Music", "Chat", "Mic"].includes(l.key))
                GoxlrLevel {
                    required property var modelData
                    key: modelData.key
                    width: (col.width - (levels.columns - 1) * levels.columnSpacing) / levels.columns
                }
            }
        }

        // ---------- Routing: Lautsprecher = Routing nach LineOut ----------
        Item {
            visible: GoXLR.online && panel.showSpeakers
            width: parent.width
            height: 30
            Name { text: "Speakers" }
            Row {
                x: panel.nameW + 12
                spacing: 6
                Repeater {
                    model: GoXLR.online ? panel.speakerInputs : []
                    Pick {
                        required property var modelData
                        label: modelData[1]
                        active: GoXLR.route(modelData[0], "LineOut")
                        onClicked: GoXLR.toggle(modelData[0], "LineOut")
                    }
                }
            }
        }

        // Discord hört = Routing nach ChatMic
        Item {
            visible: GoXLR.online && panel.showChat
            width: parent.width
            height: 30
            Name { text: "Discord hears" }
            Row {
                x: panel.nameW + 12
                spacing: 6
                Repeater {
                    model: GoXLR.online ? panel.chatInputs : []
                    Pick {
                        required property var modelData
                        label: modelData[1]
                        active: GoXLR.route(modelData[0], "ChatMic")
                        onClicked: GoXLR.toggle(modelData[0], "ChatMic")
                    }
                }
            }
        }
    }
}
