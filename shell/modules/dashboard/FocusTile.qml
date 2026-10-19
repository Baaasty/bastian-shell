import QtQuick
import QtQuick.Layouts
import qs.config
import qs.services
import qs.components

// Fokus kompakt: Ring mit Restzeit links, rechts Start/Pause/Stopp, Tagesziel + Bildschirmzeit.
// Im Leerlauf: Vorgaben-Chips (Klick startet), Feld für eigene Zeit ("40", "1h30", "until 14:30") + Start.
Tile {
    id: tile

    // beim Schließen des Dashboards: Eingaben leeren (Dashboard soll jedes Mal frisch aufgehen)
    function reset(): void {
        input.text = "";
        input.focus = false;
    }
    title: "Focus"
    note: "Block " + Focus.block + " / " + Focus.blocksPerRound

    readonly property bool idle: Focus.mode === "idle"
    readonly property bool custom: input.text.trim() !== ""
    readonly property var parsed: Focus.parseTime(input.text)
    property string error: ""

    // Enter / Start: eigene Eingabe, sonst die gewählte Vorgabe
    function go(): void {
        if (!custom) {
            Focus.start();
            return;
        }
        error = Focus.startText(input.text);
        if (error === "")
            input.text = "";
    }

    // kleiner Auswahl-Chip (wie im Fokus-Popout der Bar)
    component Pick: Rectangle {
        id: pk
        property string text
        property bool current: false
        signal picked()
        width: pkTxt.implicitWidth + 20
        height: 28
        radius: Theme.radiusSm
        color: current ? Theme.accentSoft : pkArea.containsMouse ? Qt.alpha(Theme.text, 0.1) : Theme.raise
        border.width: 1
        border.color: current ? Qt.alpha(Theme.accent, 0.55) : Theme.border
        Behavior on color { ColorAnimation { duration: Theme.fade } }
        Txt {
            id: pkTxt
            anchors.centerIn: parent
            text: pk.text
            color: pk.current ? Theme.accentText : Theme.text
            font.pixelSize: 12
            font.weight: Font.Normal
        }
        MouseArea {
            id: pkArea
            anchors.fill: parent
            hoverEnabled: true
            cursorShape: Qt.PointingHandCursor
            onClicked: pk.picked()
        }
    }

    // Ring + Steuerung als Gruppe mittig in der Kachel
    RowLayout {
        anchors.centerIn: parent
        height: parent.height
        spacing: 28

        Ring {
            Layout.alignment: Qt.AlignVCenter
            implicitWidth: Math.min(parent.height, 150)
            implicitHeight: implicitWidth
            stroke: 9
            value: tile.idle ? 0 : Focus.progress
            color: Focus.mode === "break" ? Theme.success : Theme.accent

            MonoTxt {
                anchors.horizontalCenter: parent.horizontalCenter
                // Leerlauf: was Start gerade starten würde (eigene Eingabe oder Vorgabe)
                text: tile.idle && tile.custom && tile.parsed.ok ? Focus.fmt(tile.parsed.min * 60000) : Focus.fmt(Focus.remaining)
                font.pixelSize: tile.idle && tile.custom && tile.parsed.ok && tile.parsed.min >= 100 ? 26 : 32
                font.weight: Font.DemiBold
            }
            Txt {
                anchors.horizontalCenter: parent.horizontalCenter
                text: Focus.mode === "focus" ? "left" : Focus.mode === "paused" ? "paused" : Focus.mode === "break" ? "break" : "ready"
                color: Theme.textFaint
                font.pixelSize: 12
                font.weight: Font.Normal
            }
        }

        ColumnLayout {
            Layout.alignment: Qt.AlignVCenter
            spacing: tile.idle ? 10 : 14

            // Vorgaben + zuletzt benutzte eigene Werte (nur im Leerlauf)
            Flow {
                visible: tile.idle
                Layout.preferredWidth: 330
                spacing: 6
                Repeater {
                    model: Focus.presets.filter(p => !p.label.startsWith("until")).concat(Focus.recentChoices.map(r => ({ label: r.text, key: r.text })))
                    Pick {
                        required property var modelData
                        text: modelData.label
                        current: !tile.custom && !modelData.key && Focus.preset.label === modelData.label
                        onPicked: modelData.key ? (tile.error = Focus.startText(modelData.key)) : Focus.start(modelData.min)
                    }
                }
            }

            Row {
                spacing: 8
                // eigene Zeit
                Rectangle {
                    visible: tile.idle
                    width: 170
                    height: 36
                    radius: Theme.radiusMd
                    color: Theme.raise
                    border.width: 1
                    border.color: tile.error !== "" || (tile.custom && !tile.parsed.ok) ? Qt.alpha(Theme.error, 0.6)
                        : input.activeFocus ? Qt.alpha(Theme.accent, 0.5) : Theme.border
                    Icon {
                        id: glyph
                        x: 10
                        anchors.verticalCenter: parent.verticalCenter
                        name: "schedule"
                        size: 16
                        color: Theme.textFaint
                    }
                    TextInput {
                        id: input
                        anchors.left: glyph.right
                        anchors.leftMargin: 8
                        anchors.right: parent.right
                        anchors.rightMargin: 10
                        anchors.verticalCenter: parent.verticalCenter
                        color: Theme.text
                        selectionColor: Theme.accentSoft
                        selectedTextColor: Theme.text
                        font.family: Theme.fontUi
                        font.pixelSize: 13
                        clip: true
                        onTextChanged: tile.error = ""
                        Keys.onReturnPressed: tile.go()
                        Keys.onEnterPressed: tile.go()
                        // Esc nicht abfangen: geht weiter ans Dashboard (schließt es)
                        Txt {
                            anchors.fill: parent
                            visible: input.text === ""
                            text: "40 · 1h30 · until 14:30"
                            color: Theme.textFaint
                            font.pixelSize: 13
                            font.weight: Font.Normal
                        }
                    }
                }
                Button {
                    visible: tile.idle
                    primary: true
                    icon: "play_arrow"
                    text: "Start"
                    opacity: !tile.custom || tile.parsed.ok ? 1 : 0.5
                    onClicked: tile.go()
                }
                Button {
                    visible: Focus.mode === "focus"
                    icon: "pause"
                    text: "Pause"
                    onClicked: Focus.pause()
                }
                Button {
                    visible: Focus.mode === "paused"
                    primary: true
                    icon: "play_arrow"
                    text: "Resume"
                    onClicked: Focus.resume()
                }
                Button {
                    visible: Focus.mode !== "idle"
                    icon: "stop"
                    text: "Stop"
                    onClicked: Focus.stop()
                }
            }

            // Hinweis zur Eingabe (falsch / Uhrzeit vorbei); sonst Tagesziel
            Txt {
                visible: tile.idle && (tile.error !== "" || (tile.custom && !tile.parsed.ok && tile.parsed.error !== ""))
                Layout.preferredWidth: 330
                text: tile.error !== "" ? tile.error : tile.parsed.error ?? ""
                color: Theme.error
                font.pixelSize: 12
                font.weight: Font.Normal
            }

            Row {
                visible: !(tile.idle && (tile.error !== "" || (tile.custom && !tile.parsed.ok && tile.parsed.error !== "")))
                spacing: 10
                Ring {
                    anchors.verticalCenter: parent.verticalCenter
                    implicitWidth: 26
                    implicitHeight: 26
                    stroke: 4
                    value: Focus.focusMin / Focus.goalMin
                }
                Column {
                    anchors.verticalCenter: parent.verticalCenter
                    Txt {
                        text: "Daily goal " + Focus.focusMin + " / " + Focus.goalMin + " min"
                        color: Theme.textMuted
                        font.pixelSize: 12
                        font.weight: Font.Normal
                    }
                    Txt {
                        text: "Screen time " + Math.floor(Focus.screenMin / 60) + " h " + (Focus.screenMin % 60) + " min"
                            // Hyperfokus-Wecker (services/Breaks.qml): wann der nächste Pausen-Hinweis kommt
                            + (Breaks.enabled && !Breaks.offToday ? (Breaks.leftMin > 0 ? "  ·  break in " + Breaks.fmt(Breaks.leftMin) : "  ·  break due") : "")
                        color: Theme.textFaint
                        font.pixelSize: 12
                        font.weight: Font.Normal
                    }
                }
            }
        }
    }
}
