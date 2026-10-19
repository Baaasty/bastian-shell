import QtQuick
import qs.config
import qs.services
import qs.components

// Oben links: nächster Termin heute oder morgen (ganztägige zählen nicht). Läuft er gerade: "now · …",
// bis 60 min vorher "in 25 min · …" in Akzentfarbe, sonst "14:30 · …" bzw. "tomorrow 21:00 · …". Klick = Kalender-App.
Chip {
    id: root

    readonly property var next: {
        const now = Agenda.now;
        const limit = Agenda.dayEnd + 86400000;
        let best = null;
        for (const e of Agenda.events) {
            if (e.allDay || e.end <= now || e.start >= limit)
                continue;
            if (!best || e.start < best.start)
                best = e;
        }
        return best;
    }
    readonly property bool running: next !== null && next.start <= Agenda.now
    readonly property int minutes: next ? Math.ceil((next.start - Agenda.now) / 60000) : 0
    readonly property bool soon: running || (next !== null && minutes <= 60)
    readonly property bool tomorrow: next !== null && next.start >= Agenda.dayEnd

    visible: next !== null
    onClicked: Agenda.openClient()

    Icon {
        anchors.verticalCenter: parent.verticalCenter
        name: "event"
        size: 15
        fill: root.soon
        color: root.soon ? Theme.accentText : Theme.textFaint
    }
    Txt {
        anchors.verticalCenter: parent.verticalCenter
        width: Math.min(implicitWidth, 280)
        color: root.soon ? Theme.accentText : Theme.textMuted
        text: {
            if (!root.next)
                return "";
            const when = root.running ? "now" : root.minutes <= 60 ? "in " + root.minutes + " min" : (root.tomorrow ? "tomorrow " : "") + Qt.formatTime(new Date(root.next.start), "HH:mm");
            return when + " · " + (root.next.title || "Event");
        }
    }
}
