import QtQuick
import Quickshell
import Quickshell.Wayland
import qs.config
import qs.services
import qs.components

// Oben links: nächster offener Punkt des aktuellen Desktops (+ Anzahl). Klick = Liste.
// Später kommen hier Kalender (iCloud) und Claude-Sitzungen als weitere Abschnitte dazu.
Row {
    id: root

    property var barWindow

    // Popouts sitzen wie die Benachrichtigungen mit Lücke unter der Bar (nicht am Chip)
    function placeUnderBar(popup, item) {
        const p = item.mapToItem(null, 0, 0);
        popup.anchor.rect.x = p.x;
        popup.anchor.rect.y = Theme.barMargin + Theme.barHeight + Theme.windowGap - 1;
        popup.anchor.rect.width = item.width;
        popup.anchor.rect.height = 1;
    }

    Chip {
        id: chip
        hintKey: BarKeys.keyFor("todo")   // Bar-Modus (Super+B)
        active: pop.visible
        onClicked: {
            if (pop.visible)
                return pop.close();
            root.placeUnderBar(pop, chip);
            pop.visible = true;
        }

        Icon {
            anchors.verticalCenter: parent.verticalCenter
            name: "checklist"
            size: 16
            color: Todos.nextItem ? Theme.textMuted : Theme.textFaint
        }
        Txt {
            anchors.verticalCenter: parent.verticalCenter
            width: Math.min(implicitWidth, 460)
            text: Todos.nextItem ? Todos.nextItem.text : Todos.current + " · no tasks"
            color: Todos.nextItem ? Theme.text : Theme.textFaint
            font.weight: Todos.nextItem ? Font.Medium : Font.Normal
        }
        Rectangle {
            anchors.verticalCenter: parent.verticalCenter
            visible: Todos.openCount > 1
            width: 20
            height: 18
            radius: 9
            color: Theme.raise
            MonoTxt {
                anchors.centerIn: parent
                text: Todos.openCount
                color: Theme.textMuted
                font.pixelSize: 11
            }
        }
    }

    component TodoList: Column {
        id: list
        property string name
        width: parent.width
        spacing: 2

        Repeater {
            model: Todos.items(list.name)
            Rectangle {
                id: item
                required property var modelData
                width: list.width
                height: 34
                radius: Theme.radiusSm
                color: itemHover.hovered ? Theme.raise : "transparent"
                HoverHandler {
                    id: itemHover
                }
                Row {
                    x: 8
                    anchors.verticalCenter: parent.verticalCenter
                    spacing: 10
                    Rectangle {
                        anchors.verticalCenter: parent.verticalCenter
                        width: 18
                        height: 18
                        radius: 9
                        color: item.modelData.done ? Theme.accentSoft : "transparent"
                        border.width: 1.5
                        border.color: item.modelData.done ? Theme.accent : Theme.borderStrong
                        Icon {
                            anchors.centerIn: parent
                            visible: item.modelData.done
                            name: "check"
                            size: 13
                            color: Theme.accentText
                        }
                        MouseArea {
                            anchors.fill: parent
                            anchors.margins: -6
                            cursorShape: Qt.PointingHandCursor
                            onClicked: Todos.toggle(list.name, item.modelData.id)
                        }
                    }
                    Txt {
                        anchors.verticalCenter: parent.verticalCenter
                        width: list.width - 80
                        text: item.modelData.text
                        color: item.modelData.done ? Theme.textFaint : Theme.text
                        font.strikeout: item.modelData.done
                        font.weight: Font.Normal
                    }
                }
                Icon {
                    anchors.right: parent.right
                    anchors.rightMargin: 8
                    anchors.verticalCenter: parent.verticalCenter
                    visible: itemHover.hovered
                    name: "close"
                    size: 15
                    color: Theme.textFaint
                    MouseArea {
                        anchors.fill: parent
                        anchors.margins: -6
                        cursorShape: Qt.PointingHandCursor
                        onClicked: Todos.remove(list.name, item.modelData.id)
                    }
                }
            }
        }
        Txt {
            visible: Todos.items(list.name).length === 0
            leftPadding: 8
            text: "All done"
            color: Theme.textFaint
            font.weight: Font.Normal
        }
    }

    PopupWindow {
        id: pop

        anchor.window: root.barWindow
        anchor.edges: Edges.Bottom
        anchor.gravity: Edges.Bottom
        grabFocus: true
        // gewollt schließen (Esc, Chip, Weghovern); schließt der Compositor es, holt PopoutGuard es zurück
        function close(): void {
            guard.intended = true;
            visible = false;
        }
        implicitWidth: 460
        implicitHeight: Math.min(720, col.implicitHeight + 24)
        color: "transparent"
        onVisibleChanged: {
            if (root.barWindow)
                root.barWindow.openMenus += visible ? 1 : -1;
            if (visible)
                Popouts.claim("todo");
            else
                Popouts.release("todo");
            if (visible)
                input.forceActiveFocus();
        }
        // nur ein Bar-Popout gleichzeitig
        Connections {
            target: Popouts
            function onCurrentChanged() {
                if (Popouts.current !== "todo" && pop.visible)
                    pop.visible = false;
            }
        }


        BackgroundEffect.blurRegion: Region {
            Region { x: 0; y: 0; width: 1; height: 1 }
            Region { item: card; radius: Theme.radiusLg }
        }

        Glass {
            id: card
            anchors.fill: parent
            strong: true
            // offen bis zum Weghovern (PopoutGuard.qml)
            PopoutGuard { id: guard; popout: pop; chip: chip; name: "todo" }
            // Tastatur: Pfeile/Tab/Enter, Bar-Modus „O“ (KeyNav.qml)
            Keys.onPressed: e => nav.key(e)
            KeyNav {
                id: nav
                root: card
                popout: pop
                guard: guard
                name: "todo"
                openFn: () => {
                    root.placeUnderBar(pop, chip);
                    pop.visible = true;
                }
            }

            Column {
                id: col
                x: 12
                y: 12
                width: parent.width - 24
                spacing: 8

                Label {
                    leftPadding: 8
                    text: Todos.current
                }

                // neue Aufgabe
                Rectangle {
                    width: col.width
                    height: 40
                    radius: Theme.radiusMd
                    color: Theme.raise
                    border.width: 1
                    border.color: input.activeFocus ? Qt.alpha(Theme.accent, 0.5) : Theme.border
                    Behavior on border.color { ColorAnimation { duration: Theme.fade } }
                    Icon {
                        id: plus
                        x: 10
                        anchors.verticalCenter: parent.verticalCenter
                        name: "add"
                        size: 17
                        color: Theme.textFaint
                    }
                    TextInput {
                        id: input
                        anchors.left: plus.right
                        anchors.leftMargin: 8
                        anchors.right: parent.right
                        anchors.rightMargin: 10
                        anchors.verticalCenter: parent.verticalCenter
                        color: Theme.text
                        selectionColor: Theme.accentSoft
                        selectedTextColor: Theme.text
                        font.family: Theme.fontUi
                        font.pixelSize: 14
                        clip: true
                        Keys.onReturnPressed: {
                            Todos.add(Todos.current, text);
                            text = "";
                        }
                        Keys.onEnterPressed: Keys.onReturnPressed(event)
                        Keys.onEscapePressed: pop.close()
                        Txt {
                            anchors.fill: parent
                            visible: input.text === ""
                            text: "New task for " + Todos.current + "…"
                            color: Theme.textFaint
                            font.weight: Font.Normal
                        }
                    }
                }

                TodoList {
                    name: Todos.current
                }

                Rectangle {
                    width: col.width
                    height: 1
                    color: Theme.border
                    visible: Todos.current !== Todos.general
                }
                Label {
                    leftPadding: 8
                    visible: Todos.current !== Todos.general
                    text: Todos.general
                }
                TodoList {
                    visible: Todos.current !== Todos.general
                    name: Todos.general
                }

                // Gedanken parken (Super+N): offene Notizen der Inbox, nur zum Lesen
                Txt {
                    leftPadding: 8
                    visible: Notes.openCount > 0
                    text: "Inbox · " + Notes.openCount + (Notes.openCount === 1 ? " open note" : " open notes")
                    color: Theme.textFaint
                    font.pixelSize: 12
                    font.weight: Font.Normal
                }
            }
        }
    }
}
