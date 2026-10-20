import QtQuick
import QtQuick.Layouts
import qs.config
import qs.services
import qs.components

// Mail: links ungelesen gesamt + pro Konto (ruhig), rechts die neuesten ungelesenen (Absender, Betreff, Zeit).
// Klick auf eine Mail öffnet sie in Thunderbird und markiert sie gelesen; beim Überfahren: Häkchen = nur gelesen,
// Mülleimer = in den Papierkorb. Klick auf den Zähler = Posteingang. Per Tastatur: Launcher „m “ (↵, Ctrl+R, Ctrl+D).
// Daten: Mail-Service (IMAP-Header über scripts/mail-status, Aktionen über scripts/mail-action).
Tile {
    id: tile

    readonly property var okAccounts: Mail.accounts.filter(a => a.status === "ok")
    readonly property bool ready: Mail.configured && okAccounts.length > 0
    readonly property int rowH: 46
    readonly property int maxRows: Math.max(1, Math.floor((list.height + 6) / (rowH + 6)))

    title: "Mail"
    // Probleme einzelner Konten leise oben rechts, solange die anderen laufen
    note: ready && Mail.problems.length ? Mail.problems[0].label + " · " + (Mail.problems[0].error || Mail.problems[0].status) : ""

    // ---------- ohne Konto: leiser Hinweis ----------
    AccountHint {
        anchors.left: parent.left
        anchors.right: parent.right
        anchors.verticalCenter: parent.verticalCenter
        visible: !tile.ready
        status: Mail.status
        problems: Mail.problems
    }

    RowLayout {
        anchors.fill: parent
        visible: tile.ready
        spacing: 24

        // ---------- Zähler ----------
        ColumnLayout {
            Layout.fillHeight: true
            Layout.preferredWidth: 110
            spacing: 4

            // Klick auf den Zähler = Posteingang
            TapHandler {
                enabled: Mail.clientInstalled
                onTapped: Mail.openClient()
            }
            HoverHandler {
                cursorShape: Mail.clientInstalled ? Qt.PointingHandCursor : Qt.ArrowCursor
            }

            Item {
                Layout.fillHeight: true
            }
            Icon {
                Layout.alignment: Qt.AlignHCenter
                name: Mail.total > 0 ? "mark_email_unread" : "drafts"
                size: 28
                color: Mail.total > 0 ? Theme.accentText : Theme.textFaint
            }
            MonoTxt {
                Layout.alignment: Qt.AlignHCenter
                Layout.topMargin: 6
                text: String(Mail.total)
                font.pixelSize: 22
                font.weight: Font.DemiBold
            }
            Txt {
                Layout.alignment: Qt.AlignHCenter
                text: "unread"
                color: Theme.textMuted
                font.pixelSize: 13
                font.weight: Font.Normal
            }
            // pro Konto nur, wenn es mehrere gibt; bei einem steht nur der Name
            Repeater {
                model: tile.okAccounts.length > 1 ? tile.okAccounts : []
                MonoTxt {
                    required property var modelData
                    Layout.alignment: Qt.AlignHCenter
                    Layout.maximumWidth: 110
                    text: modelData.label + " " + modelData.unread
                    color: Theme.textFaint
                    font.pixelSize: 12
                    elide: Text.ElideRight
                }
            }
            MonoTxt {
                Layout.alignment: Qt.AlignHCenter
                Layout.maximumWidth: 110
                visible: tile.okAccounts.length === 1
                text: tile.okAccounts.length === 1 ? tile.okAccounts[0].label : ""
                color: Theme.textFaint
                font.pixelSize: 12
                elide: Text.ElideRight
            }
            Item {
                Layout.fillHeight: true
            }
        }

        Rectangle {
            Layout.fillHeight: true
            implicitWidth: 1
            color: Theme.border
        }

        // ---------- neueste ungelesene ----------
        Item {
            id: list
            Layout.fillWidth: true
            Layout.fillHeight: true

            Column {
                anchors.centerIn: parent
                visible: Mail.latest.length === 0
                spacing: 6
                TapHandler {
                    enabled: Mail.clientInstalled
                    onTapped: Mail.openClient()
                }
                HoverHandler {
                    cursorShape: Mail.clientInstalled ? Qt.PointingHandCursor : Qt.ArrowCursor
                }
                Icon {
                    anchors.horizontalCenter: parent.horizontalCenter
                    name: "done_all"
                    size: 22
                    color: Theme.textFaint
                }
                Txt {
                    anchors.horizontalCenter: parent.horizontalCenter
                    text: "Inbox zero."
                    color: Theme.textFaint
                    font.weight: Font.Normal
                }
            }

            Column {
                width: parent.width
                spacing: 6

                Repeater {
                    model: Mail.latest.slice(0, tile.maxRows)

                    Rectangle {
                        id: row
                        required property var modelData
                        width: parent.width
                        height: tile.rowH
                        radius: Theme.radiusMd
                        readonly property bool hovered: area.containsMouse || readArea.containsMouse || trashArea.containsMouse
                        color: hovered && Mail.clientInstalled ? Qt.alpha(Theme.text, 0.1) : Theme.raise
                        Behavior on color { ColorAnimation { duration: Theme.fade } }

                        Txt {
                            id: from
                            x: 12
                            y: 6
                            width: parent.width - 24 - Math.max(tm.width, actions.width) - 10
                            text: row.modelData.from || "?"
                        }
                        MonoTxt {
                            id: tm
                            anchors.right: parent.right
                            anchors.rightMargin: 12
                            anchors.verticalCenter: from.verticalCenter
                            text: Mail.when(row.modelData.date)
                            color: Theme.textFaint
                            font.pixelSize: 12
                            opacity: actions.visible ? 0 : 1
                        }
                        Txt {
                            x: 12
                            anchors.top: from.bottom
                            anchors.topMargin: 1
                            width: parent.width - 24
                            text: row.modelData.subject || "(no subject)"
                            color: Theme.textMuted
                            font.pixelSize: 12
                            font.weight: Font.Normal
                        }
                        MouseArea {
                            id: area
                            anchors.fill: parent
                            hoverEnabled: true
                            cursorShape: Mail.clientInstalled ? Qt.PointingHandCursor : Qt.ArrowCursor
                            onClicked: Mail.openMessage(row.modelData)
                        }
                        // Beim Überfahren statt der Uhrzeit: gelesen / Papierkorb (wie „Später“ bei den Benachrichtigungen)
                        Row {
                            id: actions
                            anchors.right: parent.right
                            anchors.rightMargin: 12
                            anchors.verticalCenter: from.verticalCenter
                            spacing: 14
                            visible: row.hovered && Mail.canMarkRead(row.modelData)
                            Icon {
                                name: "mark_email_read"
                                size: 18
                                color: readArea.containsMouse ? Theme.accentText : Theme.textFaint
                                MouseArea {
                                    id: readArea
                                    anchors.fill: parent
                                    anchors.margins: -6
                                    hoverEnabled: true
                                    cursorShape: Qt.PointingHandCursor
                                    onClicked: Mail.markRead(row.modelData)
                                }
                            }
                            Icon {
                                name: "delete"
                                size: 18
                                color: trashArea.containsMouse ? Theme.accentText : Theme.textFaint
                                MouseArea {
                                    id: trashArea
                                    anchors.fill: parent
                                    anchors.margins: -6
                                    hoverEnabled: true
                                    cursorShape: Qt.PointingHandCursor
                                    onClicked: Mail.trash(row.modelData)
                                }
                            }
                        }
                    }
                }
            }
        }
    }
}
