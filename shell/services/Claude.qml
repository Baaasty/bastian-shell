pragma Singleton
import QtQuick
import Quickshell
import Quickshell.Io

// Claude-Code-Status aus ~/.local/state/desktop/claude.json (gepflegt von scripts/claude-status über Hooks).
// Bei mehreren Sitzungen zählt die wichtigste: waiting > done > working.
Singleton {
    id: root

    property var sessions: ({})
    property string state: ""        // "working" | "waiting" | "done" | ""
    property string project: ""
    property string cwd: ""
    property real since: 0
    property int count: 0
    readonly property bool waiting: state === "waiting" || state === "done"

    readonly property var rank: ({ "waiting": 3, "done": 2, "working": 1 })
    readonly property real maxAge: 6 * 3600000

    function pick(): void {
        const now = Date.now();
        let best = null;
        let n = 0;
        for (const id in sessions) {
            const s = sessions[id];
            if (!s || !rank[s.state] || now - (s.updated || s.since || 0) > maxAge)
                continue;
            n++;
            // gleicher Rang: die jüngste Änderung gewinnt
            if (!best || rank[s.state] > rank[best.state] || (rank[s.state] === rank[best.state] && (s.since || 0) > (best.since || 0)))
                best = s;
        }
        count = n;
        state = best ? best.state : "";
        project = best ? (best.project || "") : "";
        cwd = best ? (best.cwd || "") : "";
        since = best ? (best.since || 0) : 0;
    }

    FileView {
        id: file
        path: Quickshell.env("HOME") + "/.local/state/desktop/claude.json"
        watchChanges: true
        printErrors: false
        onFileChanged: reload()
        onLoaded: {
            try {
                root.sessions = JSON.parse(text()).sessions || {};
            } catch (e) {
                root.sessions = {};
            }
            root.pick();
        }
        onLoadFailed: {
            root.sessions = {};
            root.pick();
        }
    }

    // alte Einträge auch ohne Dateiänderung ausblenden
    Timer {
        interval: 60000
        repeat: true
        running: true
        onTriggered: root.pick()
    }

    IpcHandler {
        target: "claude"

        function status(): string {
            return JSON.stringify({ state: root.state, project: root.project, since: root.since, count: root.count });
        }
    }
}
