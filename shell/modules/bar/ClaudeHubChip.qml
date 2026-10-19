import QtQuick
import Quickshell
import qs.config
import qs.services
import qs.components

// Claude-Zentrale oben links (ersetzt Kontext- und Claude-Chip): "✦ 3 projects · 1 needs you".
// Ember, sobald eine Sitzung auf dich wartet; sonst ruhig ("2 projects · working", mit Subagents
// "desktop · 3 agents"). Ohne laufende
// Sitzung steht wie früher das aktuelle Projekt da (Name · Branch · Änderungen, +n weitere).
// Klick = Popout mit allen aktiven Projekten.
Chip {
    id: chip
    hintKey: BarKeys.keyFor("claudehub")   // Bar-Modus (Super+B)

    property var barWindow: QsWindow.window

    readonly property int n: ClaudeHub.count
    readonly property bool needs: ClaudeHub.needsCount > 0
    readonly property int agents: ClaudeHub.agentsRunning
    readonly property bool working: ClaudeHub.workingCount > 0 || agents > 0
    readonly property bool idle: !needs && !working
    readonly property string head: n === 1 ? ClaudeHub.projects[0].name : n + " projects"
    readonly property int more: idle && Context.valid ? n - 1 : 0

    visible: n > 0
    active: popout.visible
    onClicked: popout.toggle()

    Icon {
        anchors.verticalCenter: parent.verticalCenter
        name: chip.idle ? "code" : "auto_awesome"
        size: 15
        fill: chip.needs
        color: chip.needs ? Theme.accentText : chip.idle ? Theme.textFaint : Theme.textMuted
    }
    Txt {
        anchors.verticalCenter: parent.verticalCenter
        width: Math.min(implicitWidth, 360)
        color: chip.needs ? Theme.accentText : Theme.textMuted
        text: {
            if (chip.needs)
                return chip.head + " · " + (ClaudeHub.needsCount === 1 ? "needs you" : ClaudeHub.needsCount + " need you");
            if (chip.agents > 0)
                return chip.head + " · " + chip.agents + (chip.agents === 1 ? " agent" : " agents");
            if (chip.working)
                return chip.head + " · working";
            if (!Context.valid)
                return chip.head;
            // wie der alte Kontext-Chip: aktuelles Projekt
            let s = Context.project;
            if (Context.branch)
                s += " · " + Context.branch;
            if (Context.path)
                s += " · " + (Context.changes === 0 ? "clean" : Context.changes === 1 ? "1 change" : Context.changes + " changes");
            return s;
        }
    }
    // weitere Projekte (nur im Ruhe-Modus, dort steht sonst nur eins)
    Rectangle {
        anchors.verticalCenter: parent.verticalCenter
        visible: chip.more > 0
        width: moreTxt.implicitWidth + 12
        height: 18
        radius: 9
        color: Theme.raise
        MonoTxt {
            id: moreTxt
            anchors.centerIn: parent
            text: "+" + chip.more
            color: Theme.textMuted
            font.pixelSize: 11
        }
    }

    ClaudeHubPopout {
        id: popout
        barWindow: chip.barWindow
        chip: chip
    }
}
