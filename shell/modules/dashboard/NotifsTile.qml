import QtQuick
import Quickshell
import qs.config
import qs.services
import qs.components
import "../notifications"

// Verlauf der letzten Benachrichtigungen; ✕ beim Überfahren löscht einen Eintrag, „Clear all“ alle
Tile {
    title: "Notifications"

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
                // löschen: ✕ beim Überfahren an der Stelle der Uhrzeit
                Icon {
                    anchors.right: parent.right
                    anchors.rightMargin: 10
                    anchors.verticalCenter: parent.verticalCenter
                    visible: rowHover.hovered
                    name: "close"
                    size: 16
                    color: delArea.containsMouse ? Theme.accentText : Theme.textFaint
                    MouseArea {
                        id: delArea
                        anchors.fill: parent
                        anchors.margins: -8
                        hoverEnabled: true
                        cursorShape: Qt.PointingHandCursor
                        onClicked: Notifs.removeHistory(row.modelData.key)
                    }
                }
            }
        }
    }
}
