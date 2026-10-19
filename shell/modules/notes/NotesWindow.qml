import QtQuick
import Quickshell
import Quickshell.Wayland
import Quickshell.Hyprland
import qs.config
import qs.services
import qs.components

// Gedanken parken (Super+N): kleines Eingabefeld mit Fokus im Feld.
// Enter speichert (-> Notes.add, Inbox-Datei) und schließt, Shift+Enter = neue Zeile, Esc/Klick daneben schließt – der Entwurf bleibt.
// Danach kurz „Saved“ als Mini-Hinweis unten (ohne Benachrichtigung).
Scope {
    id: root

    property bool open: false
    property string screenName: Config.mainScreen
    readonly property bool todoNow: Notes.parse(Notes.draft).todo

    // Mini-Hinweis
    property bool pillShown: false
    property string pillText: "Saved"
    property bool pillError: false

    function openIt(): void {
        if (open)
            return;
        screenName = Hyprland.focusedMonitor?.name ?? Config.mainScreen;
        open = true;
    }
    function close(): void {
        open = false;
    }

    Connections {
        target: Notes
        function onOpenRequested(forceOpen) {
            if (root.open && !forceOpen)
                root.close();
            else
                root.openIt();
        }
        function onCloseRequested() {
            root.close();
        }
        function onSaved(todo) {
            Notes.draft = "";
            root.pillError = false;
            root.pillText = todo ? "Saved · added to tasks" : "Saved";
            root.pillShown = true;
            pillTimer.restart();
            root.open = false;
        }
        function onFailed() {
            root.pillError = true;
            root.pillText = "Could not save";
            root.pillShown = true;
            pillTimer.restart();
        }
    }
    Timer {
        id: pillTimer
        interval: Notes.savedMs
        onTriggered: root.pillShown = false
    }

    // ---------- Eingabefenster ----------
    Variants {
        model: Quickshell.screens

        PanelWindow {
            id: win

            required property var modelData

            screen: modelData
            visible: root.open && modelData.name === root.screenName
            anchors {
                top: true
                bottom: true
                left: true
                right: true
            }
            exclusionMode: ExclusionMode.Ignore
            color: "transparent"
            WlrLayershell.namespace: "dock" // "dock": ohne Öffnen-Animation (Hyprland: layerrule noanim)
            WlrLayershell.layer: WlrLayer.Overlay
            WlrLayershell.keyboardFocus: visible ? WlrKeyboardFocus.OnDemand : WlrKeyboardFocus.None

            BackgroundEffect.blurRegion: Region {
                Region { x: 0; y: 0; width: 1; height: 1 }
            }

            onVisibleChanged: {
                if (!visible)
                    return;
                editor.text = Notes.draft;
                editor.cursorPosition = editor.length;
                editor.forceActiveFocus();
            }

            // Hintergrund nur leicht abgedunkelt; Klick daneben schließt (Entwurf bleibt)
            Rectangle {
                anchors.fill: parent
                color: Qt.alpha(Theme.dim, 0.4)
                opacity: win.visible ? 1 : 0
                Behavior on opacity { NumberAnimation { duration: Theme.fade; easing.type: Easing.OutCubic } }
                MouseArea {
                    anchors.fill: parent
                    onClicked: root.close()
                }
            }

            Glass {
                id: card
                strong: true
                radius: Theme.radiusLg
                width: 560
                height: col.implicitHeight + 36
                x: (parent.width - width) / 2
                y: Math.round(parent.height * 0.22)
                opacity: win.visible ? 1 : 0
                Behavior on opacity { NumberAnimation { duration: Theme.fade; easing.type: Easing.OutCubic } }

                // Klicks im Fenster nicht an den Hintergrund durchreichen
                MouseArea {
                    anchors.fill: parent
                }

                Column {
                    id: col
                    x: 18
                    y: 18
                    width: parent.width - 36
                    spacing: 12

                    Item {
                        width: col.width
                        height: 18
                        Row {
                            spacing: 8
                            anchors.verticalCenter: parent.verticalCenter
                            Icon {
                                anchors.verticalCenter: parent.verticalCenter
                                name: "edit_note"
                                size: 18
                                color: Theme.textMuted
                            }
                            Label {
                                anchors.verticalCenter: parent.verticalCenter
                                text: "Park a thought"
                            }
                        }
                        // Hinweis, wenn „t “ / „!“ davorsteht
                        Txt {
                            anchors.right: parent.right
                            anchors.verticalCenter: parent.verticalCenter
                            visible: root.todoNow
                            text: "also becomes a task"
                            color: Theme.accentText
                            font.pixelSize: 12
                            font.weight: Font.Normal
                        }
                    }

                    Rectangle {
                        width: col.width
                        height: Math.min(Math.max(flick.contentHeight, 66), 200) + 24
                        radius: Theme.radiusMd
                        color: Theme.surfaceSunken
                        border.width: 1
                        border.color: editor.activeFocus ? Qt.alpha(Theme.accent, 0.5) : Theme.border

                        Flickable {
                            id: flick
                            x: 12
                            y: 12
                            width: parent.width - 24
                            height: parent.height - 24
                            contentWidth: width
                            contentHeight: editor.implicitHeight
                            clip: true
                            boundsBehavior: Flickable.StopAtBounds

                            TextEdit {
                                id: editor
                                width: flick.width
                                color: Theme.text
                                selectionColor: Theme.accentSoft
                                selectedTextColor: Theme.text
                                font.family: Theme.fontUi
                                font.pixelSize: Theme.fontSize
                                wrapMode: TextEdit.Wrap
                                persistentSelection: true
                                onTextChanged: if (win.visible) Notes.draft = text
                                // Cursor bleibt im sichtbaren Bereich
                                onCursorRectangleChanged: {
                                    const r = cursorRectangle;
                                    if (r.y < flick.contentY)
                                        flick.contentY = r.y;
                                    else if (r.y + r.height > flick.contentY + flick.height)
                                        flick.contentY = r.y + r.height - flick.height;
                                }

                                Keys.onPressed: event => {
                                    if (event.key === Qt.Key_Return || event.key === Qt.Key_Enter) {
                                        if (event.modifiers & Qt.ShiftModifier)
                                            editor.insert(editor.cursorPosition, "\n");
                                        else if (editor.text.trim() === "")
                                            root.close();
                                        else
                                            Notes.add(editor.text);
                                        event.accepted = true;
                                    } else if (event.key === Qt.Key_Escape) {
                                        root.close();
                                        event.accepted = true;
                                    }
                                }

                                Txt {
                                    visible: editor.text === "" && editor.preeditText === ""
                                    text: "What's on your mind?"
                                    color: Theme.textFaint
                                    font.weight: Font.Normal
                                    elide: Text.ElideNone
                                }
                            }
                        }
                    }

                    Txt {
                        text: "Enter save · Shift+Enter new line · Esc close · t / ! at the start = task"
                        color: Theme.textFaint
                        font.pixelSize: 12
                        font.weight: Font.Normal
                    }
                }
            }
        }
    }

    // ---------- Mini-Hinweis „Saved“ (OSD-Stil, keine Eingaben) ----------
    Variants {
        model: Quickshell.screens

        PanelWindow {
            id: pillWin

            required property var modelData

            screen: modelData
            visible: modelData.name === root.screenName && (root.pillShown || pill.opacity > 0)
            anchors.bottom: true
            margins.bottom: 96
            implicitWidth: pillRow.implicitWidth + 48
            implicitHeight: 48
            exclusionMode: ExclusionMode.Ignore
            color: "transparent"
            WlrLayershell.namespace: "dock"
            WlrLayershell.layer: WlrLayer.Top
            WlrLayershell.keyboardFocus: WlrKeyboardFocus.None
            mask: Region {}

            BackgroundEffect.blurRegion: Region {
                Region { x: 0; y: 0; width: 1; height: 1 }
            }

            Glass {
                id: pill
                anchors.fill: parent
                strong: true
                radius: height / 2
                opacity: root.pillShown ? 1 : 0
                scale: root.pillShown ? 1 : 0.96
                Behavior on opacity { NumberAnimation { duration: Theme.slide; easing.type: Easing.OutCubic } }
                Behavior on scale { NumberAnimation { duration: Theme.slide; easing.type: Easing.OutCubic } }

                Row {
                    id: pillRow
                    anchors.centerIn: parent
                    spacing: 10
                    Icon {
                        anchors.verticalCenter: parent.verticalCenter
                        name: root.pillError ? "error" : "check"
                        size: 18
                        color: root.pillError ? Theme.error : Theme.success
                    }
                    Txt {
                        anchors.verticalCenter: parent.verticalCenter
                        text: root.pillText
                        color: Theme.text
                        font.weight: Font.Normal
                    }
                }
            }
        }
    }
}
