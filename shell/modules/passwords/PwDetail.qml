import QtQuick
import qs.config
import qs.components

// Rechte Seite (nur Anzeige – icp liest nur, Änderungen auf iPhone/Mac): Titel, Benutzer, Passwort (verdeckt),
// 2FA-Code mit Ring, Notiz (verdeckt), Websites
Item {
    id: d

    required property var pw
    readonly property var e: pw.cur

    // Feld-Kachel: Symbol + Beschriftung links, Inhalt (default) in der Mitte, Knöpfe rechts
    component Field: Rectangle {
        id: f
        property string label
        property string icon
        default property alias content: body.data
        property alias buttons: btns.data

        width: parent ? parent.width : 0
        height: 64
        radius: Theme.radiusMd
        color: Theme.raise
        border.width: 1
        border.color: Theme.border

        Icon {
            id: fIcon
            anchors.left: parent.left
            anchors.leftMargin: 16
            anchors.verticalCenter: parent.verticalCenter
            name: f.icon
            size: 20
            color: Theme.woodLight
        }
        Txt {
            id: fLabel
            anchors.left: fIcon.right
            anchors.leftMargin: 12
            anchors.top: parent.top
            anchors.topMargin: 11
            text: f.label
            font.pixelSize: 11
            font.weight: Font.Normal
            color: Theme.textFaint
        }
        Item {
            id: body
            anchors.left: fLabel.left
            anchors.right: btns.left
            anchors.rightMargin: 10
            anchors.top: fLabel.bottom
            anchors.topMargin: 2
            anchors.bottom: parent.bottom
            anchors.bottomMargin: 10
        }
        Row {
            id: btns
            anchors.right: parent.right
            anchors.rightMargin: 14
            anchors.verticalCenter: parent.verticalCenter
            spacing: 6
        }
    }

    // ---------------------------------------------------------------- leer
    Column {
        anchors.centerIn: parent
        spacing: 10
        visible: !d.e
        Icon {
            anchors.horizontalCenter: parent.horizontalCenter
            name: "key"
            size: 40
            color: Theme.wood
        }
        Txt {
            anchors.horizontalCenter: parent.horizontalCenter
            text: "Pick a login"
            color: Theme.textMuted
        }
    }

    // ---------------------------------------------------------------- Inhalt
    Flickable {
        id: detailFlick
        anchors.left: parent.left
        anchors.right: parent.right
        anchors.top: parent.top
        anchors.bottom: parent.bottom
        visible: !!d.e
        clip: true
        contentHeight: col.implicitHeight
        boundsBehavior: Flickable.StopAtBounds
        interactive: false

        WheelScroll {
            flick: detailFlick
            step: 160
        }

        Column {
            id: col
            width: detailFlick.width
            spacing: 10

            // Titel + Haupt-Website
            Item {
                width: parent.width
                height: 64

                FavIcon {
                    id: avatar
                    anchors.left: parent.left
                    anchors.verticalCenter: parent.verticalCenter
                    width: 48
                    height: 48
                    radius: Theme.radiusMd
                    title: d.e ? d.e.title : ""
                    domain: d.e ? d.pw.domainOf(d.e) : ""
                    strongTone: true
                    letterSize: 22
                }
                Txt {
                    id: titleTxt
                    anchors.left: avatar.right
                    anchors.leftMargin: 16
                    anchors.right: parent.right
                    y: 8
                    elide: Text.ElideRight
                    text: d.e ? d.e.title : ""
                    font.pixelSize: 20
                    font.weight: Font.DemiBold
                }
                Row {
                    anchors.left: titleTxt.left
                    anchors.top: titleTxt.bottom
                    anchors.topMargin: 5
                    spacing: 8
                    Txt {
                        text: d.e ? (d.pw.domainOf(d.e) || "no website") : ""
                        font.pixelSize: 12
                        font.weight: Font.Normal
                        color: Theme.textFaint
                    }
                    // geteilte Passwort-Gruppe (z. B. WebBude)
                    Row {
                        visible: !!(d.e && d.e.group)
                        spacing: 4
                        Txt {
                            text: "·"
                            font.pixelSize: 12
                            color: Theme.textFaint
                        }
                        Icon {
                            anchors.verticalCenter: parent.verticalCenter
                            name: "group"
                            size: 14
                            color: Theme.woodLight
                        }
                        Txt {
                            text: d.e ? (d.e.group || "") : ""
                            font.pixelSize: 12
                            font.weight: Font.Normal
                            color: Theme.textMuted
                        }
                    }
                }
            }

            Item { width: 1; height: 4 }

            Field {
                label: "Username"
                icon: "person"
                Txt {
                    anchors.left: parent.left
                    anchors.right: parent.right
                    anchors.verticalCenter: parent.verticalCenter
                    text: d.e ? (d.e.user || "—") : ""
                    font.pixelSize: 15
                }
                buttons: [
                    PwBtn {
                        icon: "content_copy"
                        enabled: !!(d.e && d.e.user)
                        onClicked: d.pw.copy("user")
                    }
                ]
            }

            Field {
                label: "Password"
                icon: "password"
                MonoTxt {
                    anchors.left: parent.left
                    anchors.right: parent.right
                    anchors.verticalCenter: parent.verticalCenter
                    elide: Text.ElideRight
                    text: !d.e || !d.e.hasPassword ? "—" : d.pw.revealOn ? d.pw.revealed : "••••••••••••"
                    font.pixelSize: d.pw.revealOn ? 15 : 16
                    color: d.pw.revealOn ? Theme.text : Theme.textMuted
                }
                buttons: [
                    PwBtn {
                        icon: d.pw.revealOn ? "visibility_off" : "visibility"
                        enabled: !!(d.e && d.e.hasPassword)
                        onClicked: d.pw.toggleReveal()
                    },
                    PwBtn {
                        icon: "content_copy"
                        tone: "accent"
                        enabled: !!(d.e && d.e.hasPassword)
                        onClicked: d.pw.copy("password")
                    }
                ]
            }

            Field {
                id: totpField
                visible: !!(d.e && d.e.hasTotp)
                label: "2FA code"
                icon: "lock_clock"
                readonly property var t: d.pw.totp
                readonly property real secs: t ? Math.max(0, (t.expires - d.pw.now) / 1000) : 0
                MonoTxt {
                    anchors.left: parent.left
                    anchors.verticalCenter: parent.verticalCenter
                    text: totpField.t ? totpField.t.code.replace(/^(\d{3})(\d{3})$/, "$1 $2") : "··· ···"
                    font.pixelSize: 20
                    font.weight: Font.DemiBold
                    color: totpField.t && totpField.secs < 6 ? Theme.warning : Theme.text
                }
                buttons: [
                    Ring {
                        anchors.verticalCenter: parent.verticalCenter
                        width: 32
                        height: 32
                        stroke: 3
                        value: totpField.t ? totpField.secs / totpField.t.period : 0
                        color: totpField.secs < 6 ? Theme.warning : Theme.accent
                        MonoTxt {
                            text: Math.ceil(totpField.secs)
                            font.pixelSize: 10
                            color: Theme.textMuted
                        }
                    },
                    Item { width: 4; height: 1 },
                    PwBtn {
                        icon: "content_copy"
                        enabled: !!totpField.t
                        onClicked: d.pw.copy("totp")
                    }
                ]
            }

            // Notiz: verdeckt wie das Passwort (steht oft ein API-Key drin); aufgedeckt markier- und kopierbar
            Field {
                id: notesField
                visible: !!(d.e && d.e.hasNotes)
                label: "Notes"
                icon: "notes"
                height: d.pw.notesOn ? Math.max(64, notesText.contentHeight + 44) : 64
                MonoTxt {
                    anchors.left: parent.left
                    anchors.right: parent.right
                    anchors.verticalCenter: parent.verticalCenter
                    visible: !d.pw.notesOn
                    text: "••••••••••••"
                    font.pixelSize: 16
                    color: Theme.textMuted
                }
                TextEdit {
                    id: notesText
                    anchors.fill: parent
                    visible: d.pw.notesOn
                    text: d.pw.notesOn ? d.pw.notes : ""
                    readOnly: true
                    selectByMouse: true
                    wrapMode: TextEdit.Wrap
                    textFormat: TextEdit.PlainText
                    color: Theme.text
                    selectionColor: Theme.accentSoft
                    font.family: Theme.fontMono
                    font.pixelSize: 13
                }
                buttons: [
                    PwBtn {
                        icon: d.pw.notesOn ? "visibility_off" : "visibility"
                        onClicked: d.pw.toggleNotes()
                    },
                    PwBtn {
                        icon: "content_copy"
                        onClicked: d.pw.copy("notes")
                    }
                ]
            }

            // Websites
            Item {
                width: parent.width
                height: 34
                Txt {
                    anchors.left: parent.left
                    anchors.leftMargin: 2
                    anchors.bottom: parent.bottom
                    anchors.bottomMargin: 4
                    text: "Websites"
                    font.pixelSize: 12
                    font.weight: Font.DemiBold
                    color: Theme.textMuted
                }
                Txt {
                    anchors.right: parent.right
                    anchors.bottom: parent.bottom
                    anchors.bottomMargin: 4
                    text: "used for autofill"
                    font.pixelSize: 11
                    font.weight: Font.Normal
                    color: Theme.textFaint
                }
            }

            Repeater {
                model: d.e ? d.e.urls : []
                delegate: Rectangle {
                    id: urlRow
                    required property string modelData
                    width: col.width
                    height: 38
                    radius: Theme.radiusSm
                    color: "transparent"
                    border.width: 1
                    border.color: Theme.border
                    Icon {
                        id: gIcon
                        anchors.left: parent.left
                        anchors.leftMargin: 12
                        anchors.verticalCenter: parent.verticalCenter
                        name: "language"
                        size: 17
                        color: Theme.textFaint
                    }
                    Txt {
                        anchors.left: gIcon.right
                        anchors.leftMargin: 10
                        anchors.right: parent.right
                        anchors.rightMargin: 12
                        anchors.verticalCenter: parent.verticalCenter
                        text: urlRow.modelData.replace(/^https:\/\//, "")
                        font.pixelSize: 13
                        font.weight: Font.Normal
                    }
                }
            }

        }
    }
}
