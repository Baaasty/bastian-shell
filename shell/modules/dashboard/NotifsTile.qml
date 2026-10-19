import QtQuick
import Quickshell
import qs.config
import qs.services
import qs.components
import "../notifications"

// Verlauf der letzten Benachrichtigungen
Tile {
    title: "Notifications"

    // zurückgestellte Meldungen (Später erinnern): nur Anzahl + nächste Uhrzeit
    Txt {
        anchors.right: clearAll.visible ? clearAll.left : parent.right
        anchors.rightMargin: clearAll.visible ? 14 : 0
        y: -28
        visible: Notifs.snoozed.length > 0
        text: Notifs.snoozed.length + " snoozed · next " + Qt.formatTime(new Date(Notifs.nextSnooze), "HH:mm")
        color: Theme.textFaint
        font.pixelSize: 12
        font.weight: Font.Normal
    }

    Txt {
        id: clearAll
        anchors.right: parent.right
        y: -28
        visible: Notifs.history.length > 0
        text: "Clear all"
        color: clearArea.containsMouse ? Theme.accentText : Theme.textFaint
        font.pixelSize: 12
        font.weight: Font.Normal
        MouseArea {
            id: clearArea
            anchors.fill: parent
            anchors.margins: -6
            hoverEnabled: true
            cursorShape: Qt.PointingHandCursor
            onClicked: Notifs.clearHistory()
        }
    }

    Txt {
        anchors.centerIn: parent
        visible: Notifs.history.length === 0
        text: "All quiet."
        color: Theme.textFaint
        font.weight: Font.Normal
    }

    Column {
        width: parent.width
        spacing: 8

        Repeater {
            model: Notifs.history.slice(0, 3)

            Rectangle {
                id: row
                required property var modelData
                property bool snoozing: false
                width: parent.width
                height: 46
                radius: Theme.radiusMd
                color: Theme.raise

                NotifIcon {
                    id: ico
                    x: 8
                    anchors.verticalCenter: parent.verticalCenter
                    size: 30
                    kind: modelData.kind || NotifIcons.kindOf(modelData.app, modelData.summary, "", modelData.urgent ? "critical" : "normal", modelData.desktop)
                    appIcon: modelData.icon || ""
                    desktop: modelData.desktop || ""
                }
                Column {
                    anchors.left: ico.right
                    anchors.leftMargin: 10
                    anchors.right: tm.left
                    anchors.rightMargin: 8
                    anchors.verticalCenter: parent.verticalCenter
                    Txt {
                        width: parent.width
                        maximumLineCount: 1
                        text: (modelData.summary || modelData.app || "").replace(/\s*\n+\s*/g, " · ")
                    }
                    Txt {
                        width: parent.width
                        // mehrzeilige Meldungen (Browser: "Seite\n\nText") in eine Zeile, sonst überlappen die Einträge
                        maximumLineCount: 1
                        text: (modelData.body || "").replace(/\s*\n+\s*/g, " · ")
                        visible: text !== ""
                        color: Theme.textMuted
                        font.pixelSize: 12
                        font.weight: Font.Normal
                    }
                }
                // Screenshot/Aufnahme: Klick = Datei öffnen, Rechtsklick = im Ordner zeigen
                MouseArea {
                    anchors.fill: parent
                    enabled: !!modelData.file
                    acceptedButtons: Qt.LeftButton | Qt.RightButton
                    cursorShape: Qt.PointingHandCursor
                    onClicked: e => e.button === Qt.RightButton ? Notifs.showFile(modelData.file) : Notifs.openFile(modelData.file)
                }
                MonoTxt {
                    id: tm
                    anchors.right: parent.right
                    anchors.rightMargin: 10
                    anchors.verticalCenter: parent.verticalCenter
                    text: modelData.time
                    color: Theme.textFaint
                    font.pixelSize: 11
                    opacity: rowHover.hovered ? 0 : 1
                }
                HoverHandler {
                    id: rowHover
                }
                // Später erinnern: Uhr beim Überfahren, Klick öffnet die Auswahl über der Zeile
                Icon {
                    anchors.right: parent.right
                    anchors.rightMargin: 10
                    anchors.verticalCenter: parent.verticalCenter
                    visible: rowHover.hovered && !row.snoozing
                    name: "snooze"
                    size: 18
                    color: snoozeArea.containsMouse ? Theme.accentText : Theme.textFaint
                    MouseArea {
                        id: snoozeArea
                        anchors.fill: parent
                        anchors.margins: -8
                        hoverEnabled: true
                        cursorShape: Qt.PointingHandCursor
                        onClicked: row.snoozing = true
                    }
                }
                Rectangle {
                    anchors.fill: parent
                    visible: row.snoozing
                    radius: parent.radius
                    color: Theme.surfaceSunken
                    border.width: 1
                    border.color: Theme.border
                    // Klicks nicht an die Zeile darunter (Datei öffnen) durchlassen
                    MouseArea {
                        anchors.fill: parent
                    }
                    Icon {
                        id: snoozeIco
                        x: 12
                        anchors.verticalCenter: parent.verticalCenter
                        name: "snooze"
                        size: 18
                        color: Theme.accentText
                    }
                    SnoozeChips {
                        anchors.left: snoozeIco.right
                        anchors.leftMargin: 10
                        anchors.verticalCenter: parent.verticalCenter
                        cancelable: true
                        onPicked: spec => Notifs.snoozeHistory(row.modelData, spec)
                        onCancelled: row.snoozing = false
                    }
                }
            }
        }
    }
}
