import QtQuick
import qs.config
import qs.services
import qs.components

// Eine Bubble für normale Claude-Chats (Claude Desktop + claude.ai in Chrome), neben der Claude-Zentrale.
// Nur sichtbar, wenn es etwas gibt: "✦ 2 replies" in Ember (bzw. "✦ Claude", wenn das Fenster nur blinkt).
// Sonst unsichtbar – links steht schon die Claude-Zentrale, ein Dauer-Symbol wäre nur Rauschen.
// Klick = Claude nach vorn (startet Claude Desktop, wenn nichts offen ist), Rechtsklick = Zähler leeren.
Chip {
    id: chip

    readonly property int n: ClaudeChats.count

    visible: ClaudeChats.pending
    onClicked: mouse => {
        if (mouse.button === Qt.RightButton)
            ClaudeChats.dismiss();
        else
            ClaudeChats.open();
    }

    Icon {
        anchors.verticalCenter: parent.verticalCenter
        name: "auto_awesome"
        size: 15
        fill: true
        color: Theme.accentText
    }
    Txt {
        anchors.verticalCenter: parent.verticalCenter
        color: Theme.accentText
        text: chip.n === 0 ? "Claude" : chip.n === 1 ? "1 reply" : chip.n + " replies"
    }
}
