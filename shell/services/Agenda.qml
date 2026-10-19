pragma Singleton
import QtQuick
import Quickshell
import Quickshell.Io

// Termine und offene Todos aus ~/.cache/desktop/agenda.json (gepflegt von scripts/agenda-status
// über desktop-agenda.timer, CalDAV). Zeiten in ms seit Epoche.
// Die Datei deckt Anfang Vormonat bis Ende übernächster Monat ab (allEvents, für den Monatskalender);
// events/today/upcoming bleiben wie bisher auf heute + 7 Tage beschränkt.
Singleton {
    id: root

    property string status: "loading"   // ok | no-config | config-error | loading
    property var accounts: []
    property var allEvents: []          // [{ title, start, end, allDay, location, calendar, color, account }], ganzer Zeitraum
    property real rangeStart: 0         // abgefragter Zeitraum [rangeStart, rangeEnd) laut Datei
    property real rangeEnd: 0
    property var todos: []              // [{ title, due, allDay, priority, calendar, account }]
    property real updated: 0
    readonly property bool configured: status === "ok"
    readonly property var problems: accounts.filter(a => a.status !== "ok")

    // "jetzt" minütlich, damit heute/überfällig und die Jetzt-Markierung mitlaufen
    property real now: Date.now()
    readonly property real dayStart: { const d = new Date(now); d.setHours(0, 0, 0, 0); return d.getTime(); }
    readonly property real dayEnd: { const d = new Date(dayStart); d.setDate(d.getDate() + 1); return d.getTime(); }
    readonly property real weekEnd: { const d = new Date(dayStart); d.setDate(d.getDate() + 8); return d.getTime(); }

    // Mitternacht des Tages von t
    function dayOf(t: real): real {
        const d = new Date(t);
        d.setHours(0, 0, 0, 0);
        return d.getTime();
    }

    // heute + 7 Tage (wie früher die ganze Datei)
    readonly property var events: allEvents.filter(e => e.start < weekEnd && (e.end > dayStart || e.start >= dayStart))

    // Termine je Tag: { Mitternacht (ms): [Termine] }; mehrtägige stehen an jedem ihrer Tage
    readonly property var byDay: {
        const m = {};
        for (const e of allEvents) {
            const d = new Date(dayOf(e.start));
            const last = e.end > e.start ? e.end : e.start + 1;   // Ende exklusiv
            for (let i = 0; i < 62 && d.getTime() < last; i++) {
                const k = d.getTime();
                (m[k] = m[k] || []).push(e);
                d.setDate(d.getDate() + 1);
            }
        }
        return m;
    }
    function eventsOn(day: real): var {
        return byDay[dayOf(day)] || [];
    }
    // liegt der Tag im abgefragten Zeitraum? (sonst heißt "keine Termine" nur "nicht geladen")
    function synced(day: real): bool {
        const d = dayOf(day);
        return rangeEnd > 0 ? d >= dayOf(rangeStart) && d < rangeEnd : d >= dayStart && d < weekEnd;
    }

    readonly property var today: events.filter(e => e.start < dayEnd && (e.end > dayStart || e.start >= dayStart))
    readonly property var todayAllDay: today.filter(e => e.allDay)
    readonly property var todayTimed: today.filter(e => !e.allDay)
    // nächste Tage: [{ day (ms), events }], ohne heute
    readonly property var upcoming: {
        const out = [];
        for (const e of events) {
            if (e.start < dayEnd)
                continue;
            const day = dayOf(e.start);
            let g = out.find(x => x.day === day);
            if (!g) {
                g = { day: day, events: [] };
                out.push(g);
            }
            g.events.push(e);
        }
        return out;
    }
    // fällig heute oder überfällig
    readonly property var dueTodos: todos.filter(t => t.due > 0 && t.due < dayEnd)
    readonly property int otherTodos: todos.length - dueTodos.length

    // Klick auf Termine (Dashboard, Bar) = Thunderbird-Kalender
    function openClient(): void {
        Mail.openCalendar();
    }

    Timer {
        interval: 60000
        repeat: true
        running: true
        onTriggered: root.now = Date.now()
    }

    FileView {
        path: Quickshell.env("HOME") + "/.cache/desktop/agenda.json"
        watchChanges: true
        printErrors: false
        onFileChanged: reload()
        onLoaded: {
            try {
                const d = JSON.parse(text());
                root.status = d.status || "ok";
                root.accounts = d.accounts || [];
                root.allEvents = d.events || [];
                root.rangeStart = d.range ? d.range.from || 0 : 0;
                root.rangeEnd = d.range ? d.range.to || 0 : 0;
                root.todos = d.todos || [];
                root.updated = d.updated || 0;
                root.now = Date.now();
            } catch (e) {}
        }
        onLoadFailed: root.status = "no-config"
    }
}
