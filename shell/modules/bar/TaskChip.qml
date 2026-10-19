import QtQuick
import qs.config
import qs.services
import qs.components

// Jetzt-Aufgabe: ein Satz, Klick = bearbeiten
Chip {
    onClicked: Prompt.ask("flag", "What are you working on?", Focus.task, text => Focus.setTask(text))

    Icon {
        anchors.verticalCenter: parent.verticalCenter
        name: "flag"
        size: 15
        color: Focus.task ? Theme.textFaint : Qt.alpha(Theme.textFaint, 0.7)
    }
    Txt {
        anchors.verticalCenter: parent.verticalCenter
        width: Math.min(implicitWidth, 520)
        text: Focus.task || "What are you working on?"
        color: Focus.task ? Theme.text : Theme.textFaint
        font.weight: Focus.task ? Font.Medium : Font.Normal
    }
}
