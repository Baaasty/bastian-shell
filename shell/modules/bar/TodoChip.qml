import QtQuick
import Quickshell
import qs.config
import qs.services
import qs.components

// Oben links: nächster offener Punkt des aktuellen Desktops (+ Anzahl), daneben geparkte Gedanken der Inbox.
// Klick / Super+T = Tasks-Popout (TodoPopout.qml): oben Gedanken parken, darunter Inbox und To-dos.
// Später kommen hier Kalender (iCloud) und Claude-Sitzungen als weitere Abschnitte dazu.
Row {
    id: root

    property var barWindow

    Chip {
        id: chip
        hintKey: BarKeys.keyFor("todo")   // Bar-Modus (Super+Leertaste)
        tip: "Tasks · Super+T"
        active: pop.visible
        onClicked: pop.toggle()

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
        // geparkte, noch nicht abgearbeitete Gedanken (eigener Zähler: sind keine Aufgaben)
        Rectangle {
            anchors.verticalCenter: parent.verticalCenter
            visible: Notes.openCount > 0
            width: inboxRow.implicitWidth + 12
            height: 18
            radius: 9
            color: Theme.raise
            Row {
                id: inboxRow
                anchors.centerIn: parent
                spacing: 3
                Icon {
                    anchors.verticalCenter: parent.verticalCenter
                    name: "edit_note"
                    size: 13
                    color: Theme.textMuted
                }
                MonoTxt {
                    anchors.verticalCenter: parent.verticalCenter
                    text: Notes.openCount
                    color: Theme.textMuted
                    font.pixelSize: 11
                }
            }
        }
    }

    TodoPopout {
        id: pop
        barWindow: root.barWindow
        chip: chip
    }
}
