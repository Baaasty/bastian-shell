import QtQuick
import qs.config
import qs.components

// Rechte Seite im Bearbeiten-Modus (F2) bzw. „Neuer Login“ (Ctrl+N, pw.creating): Titel, Benutzer, Passwort,
// Websites, 2FA, Notizen. Speichern schreibt über scripts/passwords edit bzw. create → icp nach iCloud
// (Passwort/Notiz/2FA nur über stdin). Bearbeiten: leeres Passwort- bzw. 2FA-Feld = unverändert.
// Tastatur: Tab/Shift+Tab Felder, Ctrl+S speichern, Esc abbrechen, Ctrl+G Passwort erzeugen,
// Ctrl+D zweimal = löschen (landet wie in der Passwörter-App unter „Zuletzt gelöscht“; nicht beim Neuanlegen).
Item {
    id: f

    required property var pw
    readonly property var e: pw.creating ? null : pw.cur
    property bool removeTotp: false
    property bool showPw: false         // erzeugtes Passwort sichtbar, damit man es sieht, bevor es gespeichert wird
    property bool deleteArmed: false    // erster Druck/Klick scharf, zweiter innerhalb 4 s löscht

    function askDelete(): void {
        if (pw.editBusy || pw.creating)
            return;
        if (deleteArmed) {
            deleteArmed = false;
            pw.saveEdit({ delete: true });
        } else {
            deleteArmed = true;
            disarm.restart();
        }
    }
    Timer {
        id: disarm
        interval: 4000
        onTriggered: f.deleteArmed = false
    }

    function generate(): void {
        pw.run(["generate"], (t, code) => {
            if (code === 0 && t.trim()) {
                pwIn.text = t.trim();
                showPw = true;
            }
        });
    }
    function begin(): void {
        const e = f.e;
        titleIn.text = e ? e.title : "";
        userIn.text = e ? e.user : "";
        pwIn.text = "";
        urlsIn.text = e ? (e.urls || []).map(u => u.replace(/^https:\/\//, "")).join("\n") : "";
        totpIn.text = "";
        notesIn.text = pw.editNotes;
        removeTotp = false;
        deleteArmed = false;
        showPw = false;
        if (pw.creating) {
            // Suchtext wie „github.com“ gleich als Website übernehmen; starkes Passwort schon vorschlagen
            const q = pw.query.trim();
            urlsIn.text = /^[^\s\/]+\.[a-z]{2,}$/i.test(q) ? q.toLowerCase() : "";
            generate();
            (urlsIn.text ? userIn : urlsIn).forceActiveFocus();
            return;
        }
        titleIn.forceActiveFocus();
        titleIn.selectAll();
    }
    function save(): void {
        if (pw.editBusy)
            return;
        const form = {
            title: titleIn.text,
            user: userIn.text,
            notes: notesIn.text,
            urls: urlsIn.text.split("\n").map(s => s.trim()).filter(s => s)
        };
        if (pwIn.text)
            form.password = pwIn.text;
        if (totpIn.text.trim())
            form.totp = totpIn.text.trim();
        else if (removeTotp)
            form.removeTotp = true;
        if (pw.creating)
            pw.saveCreate(form);
        else
            pw.saveEdit(form);
    }
    // gemeinsame Tasten aller Felder
    function keys(event: var): void {
        if (event.key === Qt.Key_Escape) {
            pw.cancelEdit();
            event.accepted = true;
        } else if (event.modifiers & Qt.ControlModifier && (event.key === Qt.Key_S || event.key === Qt.Key_Return || event.key === Qt.Key_Enter)) {
            save();
            event.accepted = true;
        } else if (event.modifiers & Qt.ControlModifier && event.key === Qt.Key_D) {
            askDelete();
            event.accepted = true;
        } else if (event.modifiers & Qt.ControlModifier && event.key === Qt.Key_G) {
            generate();
            event.accepted = true;
        }
    }

    // Beschriftung + Eingabefläche; `tall` = mehrzeilig
    component Box: Rectangle {
        id: box
        property string label
        property string icon
        property bool active
        property int bodyHeight: 22
        default property alias content: body.data

        width: parent ? parent.width : 0
        height: bodyHeight + 42
        radius: Theme.radiusMd
        color: Theme.raise
        border.width: 1
        border.color: active ? Qt.alpha(Theme.accent, 0.55) : Theme.border
        Behavior on border.color { ColorAnimation { duration: Theme.fade } }

        Icon {
            id: bIcon
            anchors.left: parent.left
            anchors.leftMargin: 16
            anchors.top: parent.top
            anchors.topMargin: 12
            name: box.icon
            size: 18
            color: box.active ? Theme.accentText : Theme.woodLight
        }
        Txt {
            id: bLabel
            anchors.left: bIcon.right
            anchors.leftMargin: 12
            anchors.verticalCenter: bIcon.verticalCenter
            text: box.label
            font.pixelSize: Theme.fontXs
            font.weight: Font.Normal
            color: Theme.textFaint
        }
        Item {
            id: body
            anchors.left: bLabel.left
            anchors.right: parent.right
            anchors.rightMargin: 14
            anchors.top: bLabel.bottom
            anchors.topMargin: 6
            height: box.bodyHeight
        }
    }

    component Line: TextInput {
        property string hint
        anchors.left: parent.left
        anchors.right: parent.right
        anchors.verticalCenter: parent.verticalCenter
        clip: true
        color: Theme.text
        selectionColor: Theme.accentSoft
        font.family: Theme.fontUi
        font.pixelSize: Theme.fontMd
        Keys.onPressed: event => f.keys(event)
        Txt {
            anchors.fill: parent
            visible: parent.text === "" && parent.hint !== ""
            text: parent.hint
            color: Theme.textFaint
            font.pixelSize: Theme.fontMd
            font.weight: Font.Normal
            elide: Text.ElideRight
        }
    }

    component Area: TextEdit {
        property string hint
        property Item next
        property Item prev
        anchors.fill: parent
        wrapMode: TextEdit.Wrap
        textFormat: TextEdit.PlainText
        color: Theme.text
        selectionColor: Theme.accentSoft
        font.family: Theme.fontMono
        font.pixelSize: Theme.fontSm
        // Tab springt weiter statt ein Tab-Zeichen einzufügen
        Keys.onPressed: event => {
            if (event.key === Qt.Key_Tab && next) {
                next.forceActiveFocus();
                event.accepted = true;
            } else if (event.key === Qt.Key_Backtab && prev) {
                prev.forceActiveFocus();
                event.accepted = true;
            } else {
                f.keys(event);
            }
        }
        Txt {
            anchors.fill: parent
            visible: parent.text === "" && parent.hint !== ""
            text: parent.hint
            color: Theme.textFaint
            font.pixelSize: Theme.fontSm
            font.weight: Font.Normal
            wrapMode: Text.Wrap
        }
    }

    Flickable {
        id: flick
        anchors.left: parent.left
        anchors.right: parent.right
        anchors.top: parent.top
        anchors.bottom: foot.top
        anchors.bottomMargin: 12
        clip: true
        contentHeight: col.implicitHeight
        boundsBehavior: Flickable.StopAtBounds
        interactive: false

        WheelScroll {
            flick: flick
            step: 160
        }

        Column {
            id: col
            width: flick.width
            spacing: 10

            Item {
                width: parent.width
                height: 40
                Icon {
                    id: hIcon
                    anchors.left: parent.left
                    anchors.verticalCenter: parent.verticalCenter
                    name: f.pw.creating ? "add_circle" : "edit"
                    size: 22
                    color: Theme.accentText
                }
                Txt {
                    anchors.left: hIcon.right
                    anchors.leftMargin: 10
                    anchors.verticalCenter: parent.verticalCenter
                    text: f.pw.creating ? "New login" : "Edit login"
                    font.pixelSize: Theme.fontLg
                    font.weight: Font.DemiBold
                }
                Txt {
                    anchors.right: parent.right
                    anchors.verticalCenter: parent.verticalCenter
                    text: "saves to iCloud"
                    font.pixelSize: Theme.fontXs
                    font.weight: Font.Normal
                    color: Theme.textFaint
                }
            }

            Box {
                label: "Title"
                icon: "label"
                active: titleIn.activeFocus
                Line {
                    id: titleIn
                    hint: f.pw.creating ? "optional · defaults to the website" : ""
                    KeyNavigation.tab: userIn
                    KeyNavigation.backtab: notesIn
                }
            }
            Box {
                label: "Username"
                icon: "person"
                active: userIn.activeFocus
                Line {
                    id: userIn
                    KeyNavigation.tab: pwIn
                    KeyNavigation.backtab: titleIn
                }
            }
            Box {
                label: "Password"
                icon: "password"
                active: pwIn.activeFocus
                Line {
                    id: pwIn
                    anchors.rightMargin: genBtn.width + 8
                    hint: f.pw.creating ? "Ctrl+G for a strong one" : "unchanged · Ctrl+G for a new strong one"
                    echoMode: f.showPw ? TextInput.Normal : TextInput.Password
                    font.family: Theme.fontMono
                    KeyNavigation.tab: urlsIn
                    KeyNavigation.backtab: userIn
                }
                // starkes Passwort erzeugen (wie Ctrl+G)
                Button {
                    id: genBtn
                    small: true
                    anchors.right: parent.right
                    anchors.verticalCenter: parent.verticalCenter
                    text: "Generate"
                    icon: "casino"
                    onClicked: f.generate()
                }
            }
            Box {
                label: f.pw.creating ? "Website · more can be added later with F2" : "Websites · one per line, the first is the main one"
                icon: "language"
                active: urlsIn.activeFocus
                bodyHeight: Math.max(22, urlsIn.contentHeight)
                Area {
                    id: urlsIn
                    hint: "example.com"
                    next: totpIn
                    prev: pwIn
                }
            }
            Box {
                label: f.e && f.e.hasTotp ? (f.removeTotp ? "2FA code · will be removed" : "2FA code · set, paste a new key to replace it") : "2FA code"
                icon: "lock_clock"
                active: totpIn.activeFocus
                Line {
                    id: totpIn
                    anchors.rightMargin: removeBtn.visible ? removeBtn.width + 8 : 0
                    hint: f.e && f.e.hasTotp ? "unchanged" : "setup key or otpauth:// link"
                    font.family: Theme.fontMono
                    KeyNavigation.tab: notesIn
                    KeyNavigation.backtab: urlsIn
                    onTextChanged: if (text) f.removeTotp = false
                }
                Button {
                    small: true
                    id: removeBtn
                    anchors.right: parent.right
                    anchors.verticalCenter: parent.verticalCenter
                    visible: !!(f.e && f.e.hasTotp)
                    icon: f.removeTotp ? "undo" : "delete"
                    onClicked: f.removeTotp = !f.removeTotp
                }
            }
            Box {
                label: "Notes"
                icon: "notes"
                active: notesIn.activeFocus
                bodyHeight: Math.max(44, notesIn.contentHeight)
                Area {
                    id: notesIn
                    next: titleIn
                    prev: totpIn
                }
            }
        }
    }

    // Fuß: Fehler bzw. Tasten, Knöpfe
    Item {
        id: foot
        anchors.left: parent.left
        anchors.right: parent.right
        anchors.bottom: parent.bottom
        height: 36

        Txt {
            anchors.left: parent.left
            anchors.right: btns.left
            anchors.rightMargin: 12
            anchors.verticalCenter: parent.verticalCenter
            elide: Text.ElideRight
            maximumLineCount: 2
            wrapMode: Text.Wrap
            text: f.deleteArmed ? "Moves it to Recently Deleted on all devices" : f.pw.editError || (f.pw.creating ? "Ctrl+S save  ·  Esc cancel  ·  Tab next  ·  Ctrl+G new password" : "Ctrl+S save  ·  Esc cancel  ·  Tab next  ·  Ctrl+G new password  ·  Ctrl+D delete")
            font.pixelSize: Theme.fontXs
            font.weight: Font.Normal
            color: (f.pw.editError || f.deleteArmed) && !f.pw.editBusy ? Theme.error : Theme.textFaint
        }
        Row {
            id: btns
            anchors.right: parent.right
            anchors.verticalCenter: parent.verticalCenter
            spacing: 8
            Button {
                small: true
                text: "Cancel"
                enabled: !f.pw.editBusy
                onClicked: f.pw.cancelEdit()
            }
            Button {
                small: true
                visible: !f.pw.creating
                text: f.deleteArmed ? "Are you sure?" : "Delete"
                icon: "delete"
                enabled: !f.pw.editBusy
                onClicked: f.askDelete()
            }
            Button {
                small: true
                text: "Save"
                icon: "cloud_upload"
                kind: "primary"
                enabled: !f.pw.editBusy
                onClicked: f.save()
            }
        }
    }
}
