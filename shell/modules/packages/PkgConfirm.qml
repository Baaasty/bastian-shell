import QtQuick
import qs.config
import qs.components

// Bestätigung vor Entfernen/Installieren: zeigt die dnf-Transaktion (was sonst noch mit geht)
Rectangle {
    id: ov

    property var pk
    readonly property var c: pk.confirm

    visible: !!c
    color: Qt.alpha(Theme.bg, 0.6)
    radius: Theme.radiusXl

    MouseArea {
        anchors.fill: parent
        onClicked: ov.pk.confirm = null
    }

    Glass {
        id: dlg
        anchors.centerIn: parent
        width: 560
        height: col.implicitHeight + 40
        strong: true
        radius: Theme.radiusLg
        border.color: ov.c && ov.c.danger ? Qt.alpha(Theme.error, 0.45) : Theme.borderStrong

        MouseArea {
            anchors.fill: parent   // Klicks im Dialog nicht durchreichen
        }

        Column {
            id: col
            x: 24
            y: 22
            width: parent.width - 48
            spacing: 14

            Row {
                spacing: 10
                Icon {
                    anchors.verticalCenter: parent.verticalCenter
                    name: ov.c && ov.c.danger ? "warning" : "help"
                    size: 22
                    color: ov.c && ov.c.danger ? Theme.warning : Theme.accentText
                }
                Txt {
                    anchors.verticalCenter: parent.verticalCenter
                    text: ov.c ? ov.c.title : ""
                    font.pixelSize: Theme.fontLg
                    font.weight: Font.DemiBold
                    width: col.width - 40
                }
            }

            Row {
                visible: !!ov.c && ov.c.loading
                spacing: 8
                PkgSpinner { size: 16 }
                Txt { text: "Asking dnf (nothing is changed yet)…"; color: Theme.textFaint; font.pixelSize: Theme.fontSm }
            }

            Txt {
                visible: !!ov.c && !ov.c.loading
                width: parent.width
                text: ov.c ? ov.c.text : ""
                color: ov.c && ov.c.blocked ? Theme.error : Theme.textMuted
                font.pixelSize: Theme.fontSm
                font.weight: Font.Normal
                wrapMode: Text.Wrap
                elide: Text.ElideNone
            }

            Rectangle {
                visible: !!ov.c && !!ov.c.warn
                width: parent.width
                height: warnT.implicitHeight + 16
                radius: Theme.radiusSm
                color: Qt.alpha(Theme.error, 0.14)
                Txt {
                    id: warnT
                    anchors.fill: parent
                    anchors.margins: 8
                    text: ov.c ? ov.c.warn : ""
                    color: Theme.error
                    font.pixelSize: Theme.fontSm
                    wrapMode: Text.Wrap
                    elide: Text.ElideNone
                }
            }

            // Recommended (vorab an) / Suggested (aus) beim Installieren
            Repeater {
                model: ov.c && ov.c.opt ? [
                    { kind: "rec", title: "Recommended", hint: "installed by default" },
                    { kind: "sug", title: ov.c.optKind === "flatpak" ? "Optional extensions" : "Suggested", hint: "not installed unless ticked" }
                ] : []

                Column {
                    id: optSec
                    required property var modelData
                    readonly property var items: ov.c && ov.c.opt ? ov.c.opt[modelData.kind] : []
                    visible: items.length > 0
                    width: col.width
                    spacing: 4

                    Row {
                        spacing: 10
                        Label { text: optSec.modelData.title }
                        Txt {
                            text: optSec.modelData.hint
                            color: Theme.textFaint
                            font.pixelSize: Theme.fontXs
                            font.weight: Font.Normal
                        }
                    }
                    Repeater {
                        model: optSec.items

                        Item {
                            id: orow
                            required property var modelData
                            required property int index
                            width: optSec.width
                            height: 28
                            opacity: modelData.installed ? 0.55 : 1

                            Rectangle {
                                id: box
                                anchors.left: parent.left
                                anchors.verticalCenter: parent.verticalCenter
                                width: 18
                                height: 18
                                radius: Theme.radii.xs || 6
                                color: orow.modelData.on || orow.modelData.installed ? Theme.accentSoft : "transparent"
                                border.width: 1
                                border.color: orow.modelData.on || orow.modelData.installed ? Qt.alpha(Theme.accent, 0.7) : Theme.borderStrong
                                Icon {
                                    anchors.centerIn: parent
                                    visible: orow.modelData.on || orow.modelData.installed
                                    name: "check"
                                    size: 14
                                    color: Theme.accentText
                                }
                            }
                            Txt {
                                id: onm
                                anchors.left: box.right
                                anchors.leftMargin: 10
                                anchors.verticalCenter: parent.verticalCenter
                                text: orow.modelData.name
                                font.pixelSize: Theme.fontSm
                            }
                            Txt {
                                anchors.left: onm.right
                                anchors.leftMargin: 10
                                anchors.right: parent.right
                                anchors.verticalCenter: parent.verticalCenter
                                text: orow.modelData.installed ? "already installed" : (orow.modelData.desc || "")
                                color: Theme.textFaint
                                font.pixelSize: Theme.fontSm
                                font.weight: Font.Normal
                            }
                            MouseArea {
                                anchors.fill: parent
                                enabled: !orow.modelData.installed
                                cursorShape: Qt.PointingHandCursor
                                onClicked: ov.pk.toggleOpt(optSec.modelData.kind, orow.index)
                            }
                        }
                    }
                }
            }

            Row {
                visible: !!ov.c && ov.c.refreshing
                spacing: 8
                PkgSpinner { size: 16 }
                Txt { text: "Updating the preview…"; color: Theme.textFaint; font.pixelSize: Theme.fontSm }
            }

            // Befehle, die gleich (als Root) laufen
            Rectangle {
                visible: !!ov.c && ov.c.code.length > 0 && !ov.c.loading
                width: parent.width
                height: visible ? Math.min(220, codeCol.implicitHeight + 20) : 0
                radius: Theme.radiusSm
                color: Theme.surfaceSunken
                border.width: 1
                border.color: Theme.border
                clip: true
                Flickable {
                    anchors.fill: parent
                    anchors.margins: 10
                    contentHeight: codeCol.implicitHeight
                    boundsBehavior: Flickable.StopAtBounds
                    Column {
                        id: codeCol
                        width: parent.width
                        Repeater {
                            model: ov.c ? ov.c.code : []
                            MonoTxt {
                                required property string modelData
                                width: codeCol.width
                                text: modelData
                                wrapMode: Text.WrapAnywhere
                                font.pixelSize: Theme.fontXs
                                color: modelData.startsWith("(") || modelData.startsWith("#") ? Theme.textFaint : Theme.text
                            }
                        }
                    }
                }
            }

            ListView {
                id: lv
                visible: !!ov.c && ov.c.rows.length > 0
                width: parent.width
                height: visible ? Math.min(260, contentHeight) : 0
                clip: true
                model: ov.c ? ov.c.rows : []
                boundsBehavior: Flickable.StopAtBounds
                delegate: Item {
                    id: d
                    required property var modelData
                    width: ListView.view.width
                    height: modelData.h ? 30 : 24
                    Label {
                        visible: !!d.modelData.h
                        anchors.bottom: parent.bottom
                        anchors.bottomMargin: 4
                        text: d.modelData.h || ""
                    }
                    Txt {
                        visible: !d.modelData.h
                        anchors.left: parent.left
                        anchors.right: dv.left
                        anchors.rightMargin: 10
                        anchors.verticalCenter: parent.verticalCenter
                        text: d.modelData.name || ""
                        font.pixelSize: Theme.fontSm
                    }
                    MonoTxt {
                        id: dv
                        visible: !d.modelData.h
                        anchors.right: ds.left
                        anchors.rightMargin: 14
                        anchors.verticalCenter: parent.verticalCenter
                        text: d.modelData.version || ""
                        color: Theme.textFaint
                        font.pixelSize: Theme.fontXs
                    }
                    MonoTxt {
                        id: ds
                        visible: !d.modelData.h
                        anchors.right: parent.right
                        anchors.verticalCenter: parent.verticalCenter
                        width: 72
                        horizontalAlignment: Text.AlignRight
                        text: d.modelData.size || ""
                        color: Theme.textMuted
                        font.pixelSize: Theme.fontXs
                    }
                }
            }

            Txt {
                visible: !!ov.c && !!ov.c.summary
                width: parent.width
                text: ov.c ? ov.c.summary : ""
                color: Theme.textFaint
                font.pixelSize: Theme.fontSm
            }

            Row {
                anchors.right: parent.right
                spacing: 8
                Button {
                    small: true
                    text: "Cancel"
                    onClicked: ov.pk.confirm = null
                }
                Button {
                    small: true
                    enabled: !!ov.c && !ov.c.loading && !ov.c.blocked && !ov.c.refreshing
                    kind: ov.c && ov.c.danger ? "danger" : "primary"
                    text: ov.c ? ov.c.okLabel : ""
                    onClicked: ov.pk.confirmYes()
                }
            }
        }
    }
}
