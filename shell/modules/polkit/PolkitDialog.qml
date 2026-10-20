import QtQuick
import qs.config
import qs.components

// Passwort-Karte (Polkit): rein darstellend, Daten + Signale kommen aus Polkit.qml.
// Deckend, ohne Glas/Glühen. Tastaturfokus liegt immer im Feld (Esc = Cancel, Enter = Bestätigen).
Glass {
    id: card

    property string message: ""
    property string actionId: ""
    property var identities: []          // Anzeigenamen
    property int identityIndex: 0
    property string prompt: "Password"
    property bool echo: false            // Eingabe sichtbar (z. B. Benutzername) statt Punkte
    property bool inputEnabled: true     // false, solange PAM prüft
    property string info: ""             // Hinweis des Agents (Fingerabdruck …)
    property bool infoIsError: false
    property bool failed: false          // letzter Versuch war falsch
    property bool checking: false

    signal submitted(string text)
    signal cancelled()
    signal identityPicked(int index)

    function reset(): void {
        input.text = "";
        input.forceActiveFocus();
    }
    function focusField(): void {
        input.forceActiveFocus();
    }

    strong: true
    radius: Theme.radiusXl
    border.color: Theme.borderStrong
    width: 440
    height: col.implicitHeight + 56

    // Klicks auf der Karte nicht durchreichen
    MouseArea {
        anchors.fill: parent
        onPressed: input.forceActiveFocus()
    }

    Column {
        id: col
        x: 28
        y: 28
        width: parent.width - 56
        spacing: 16

        Row {
            spacing: 14

            Rectangle {
                width: 44
                height: 44
                radius: Theme.radiusMd
                color: Theme.accentFill
                Icon {
                    anchors.centerIn: parent
                    name: "lock"
                    size: 24
                    color: Theme.accentText
                }
            }
            Column {
                anchors.verticalCenter: parent.verticalCenter
                spacing: 2
                Txt {
                    text: "Authentication required"
                    font.pixelSize: Theme.fontXl
                    font.weight: Font.DemiBold
                }
                Txt {
                    text: "Admin permission needed"
                    color: Theme.textFaint
                    font.pixelSize: Theme.fontSm
                    font.weight: Font.Normal
                }
            }
        }

        Txt {
            width: parent.width
            text: card.message
            visible: text !== ""
            wrapMode: Text.WordWrap
            elide: Text.ElideNone
            maximumLineCount: 5
            color: Theme.textMuted
            font.weight: Font.Normal
            lineHeight: 1.15
        }

        // App/Aktion
        Rectangle {
            visible: card.actionId !== ""
            width: parent.width
            height: 30
            radius: Theme.radiusSm
            color: Theme.surfaceSunken
            MonoTxt {
                anchors.fill: parent
                anchors.leftMargin: 12
                anchors.rightMargin: 12
                text: card.actionId
                color: Theme.textFaint
                font.pixelSize: Theme.fontSm
                elide: Text.ElideMiddle
            }
        }

        // Benutzer-Auswahl (nur bei mehreren Identitäten)
        Column {
            visible: card.identities.length > 1
            width: parent.width
            spacing: 6
            Txt {
                text: "Authenticate as"
                color: Theme.textFaint
                font.pixelSize: Theme.fontSm
                font.weight: Font.Normal
            }
            Flow {
                width: parent.width
                spacing: 6
                Repeater {
                    model: card.identities
                    Rectangle {
                        id: chip
                        required property string modelData
                        required property int index
                        readonly property bool on: card.identityIndex === index
                        height: 32
                        width: chipTxt.implicitWidth + 28
                        radius: Theme.radiusSm
                        color: on ? Theme.accentSoft : chipArea.containsMouse ? Theme.surfaceRaised : "transparent"
                        border.width: 1
                        border.color: on ? Theme.accent : Theme.borderStrong
                        Txt {
                            id: chipTxt
                            anchors.centerIn: parent
                            text: chip.modelData
                            color: chip.on ? Theme.accentText : Theme.text
                            font.pixelSize: Theme.fontSm
                        }
                        MouseArea {
                            id: chipArea
                            anchors.fill: parent
                            hoverEnabled: true
                            cursorShape: Qt.PointingHandCursor
                            onClicked: {
                                card.identityPicked(chip.index);
                                input.forceActiveFocus();
                            }
                        }
                    }
                }
            }
        }

        // Eingabefeld
        Column {
            width: parent.width
            spacing: 8

            Txt {
                text: card.prompt
                color: Theme.textFaint
                font.pixelSize: Theme.fontSm
                font.weight: Font.Normal
            }
            Rectangle {
                width: parent.width
                height: 48
                radius: Theme.radiusMd
                color: Theme.surfaceRaised
                border.width: 2
                border.color: card.failed ? Theme.error : input.activeFocus ? Theme.accent : Theme.borderStrong
                opacity: card.inputEnabled ? 1 : 0.6

                TextInput {
                    id: input
                    anchors.fill: parent
                    anchors.leftMargin: 16
                    anchors.rightMargin: 16
                    verticalAlignment: TextInput.AlignVCenter
                    echoMode: card.echo ? TextInput.Normal : TextInput.Password
                    passwordCharacter: "•"
                    passwordMaskDelay: 0
                    inputMethodHints: Qt.ImhSensitiveData | Qt.ImhNoPredictiveText | Qt.ImhNoAutoUppercase
                    readOnly: !card.inputEnabled
                    clip: true
                    focus: true
                    color: Theme.text
                    selectionColor: Theme.accentSoft
                    font.family: Theme.fontUi
                    font.pixelSize: Theme.fontLg
                    font.letterSpacing: card.echo ? 0 : 2
                    onAccepted: {
                        if (card.inputEnabled) {
                            const t = text;
                            text = "";
                            card.submitted(t);
                        }
                    }
                    Keys.onEscapePressed: card.cancelled()
                    // Fokus nie verlieren (Mausklick daneben o. Ä.)
                    onActiveFocusChanged: if (!activeFocus && card.visible) Qt.callLater(() => input.forceActiveFocus())
                }
            }

            // Fehlversuch / Info
            Row {
                visible: card.failed || card.info !== ""
                spacing: 8
                Icon {
                    anchors.verticalCenter: parent.verticalCenter
                    name: card.failed || card.infoIsError ? "error" : "fingerprint"
                    size: 16
                    color: card.failed || card.infoIsError ? Theme.error : Theme.textMuted
                }
                Txt {
                    width: col.width - 24
                    text: card.failed ? "Wrong password, please try again." : card.info
                    wrapMode: Text.WordWrap
                    elide: Text.ElideNone
                    color: card.failed || card.infoIsError ? Theme.error : Theme.textMuted
                    font.pixelSize: Theme.fontSm
                    font.weight: Font.Normal
                }
            }
        }

        // Knöpfe
        Row {
            anchors.right: parent.right
            spacing: 10

            Button {
                text: "Cancel"
                onClicked: card.cancelled()
            }
            Button {
                primary: true
                enabled: card.inputEnabled
                text: card.checking ? "Checking…" : "Authenticate"
                onClicked: input.accepted()
            }
        }

        KeyHintRow {
            anchors.horizontalCenter: parent.horizontalCenter
            hints: [["Enter", "confirm"], ["Esc", "cancel"]]
        }
    }
}
