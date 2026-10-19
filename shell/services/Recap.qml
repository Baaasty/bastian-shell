pragma Singleton
import QtQuick
import Quickshell
import Quickshell.Io
import qs.config

// Tagesrückblick (Doku docs/knowledge/shell-features.md): ruhige Karte „das hast du heute geschafft“
// (shell/modules/recap/RecapCard.qml) mit Commits (scripts/recap), Projektzeit (ProjectTime), Fokuszeit (Focus),
// abgehakten To-dos und fertigen Claude-Aufgaben. Kommt von selbst, wenn die Feierabend-Szene „evening“
// angeht (Super+Alt+B), sonst per Kürzel/IPC. Einstellungen (optional, live):
// ~/.config/desktop/recap.json  { "onEvening": true, "closeSec": 60 }
// Abgehakte To-dos merkt sich der Dienst selbst (Todos.qml kennt keine Zeit): ~/.local/state/desktop/recap.json
// { "day": "…", "todos": [{ key, list, text, at }] } – bleibt auch, wenn die Liste danach aufgeräumt wird.
// IPC "recap": open|hide|toggle|refresh|status.
Singleton {
    id: root

    readonly property string home: Quickshell.env("HOME")
    property var cfg: ({})
    readonly property bool onEvening: cfg.onEvening !== false
    readonly property int closeSec: cfg.closeSec >= 10 && cfg.closeSec <= 600 ? Math.round(cfg.closeSec) : 60

    property bool open: false

    function show(): void {
        refresh();
        open = true;
    }
    function hide(): void {
        open = false;
    }

    function today(): string {
        return Qt.formatDate(new Date(), "yyyy-MM-dd");
    }
    function midnight(): real {
        const d = new Date();
        d.setHours(0, 0, 0, 0);
        return d.getTime();
    }

    // ---------- Commits (scripts/recap commits --json) ----------
    // { day, total, projects: [{ id, name, count, commits: [{ time, subject }] }] }
    property var commits: null
    property bool commitsLoading: false
    function refresh(): void {
        ProjectTime.account();
        if (gitProc.running)
            return;
        commitsLoading = true;
        gitProc.running = true;
    }
    Process {
        id: gitProc
        command: [Config.repo + "/scripts/recap", "commits", "--json"]
        stdout: StdioCollector {
            onStreamFinished: {
                try {
                    root.commits = JSON.parse(text);
                } catch (e) {
                    root.commits = null;
                }
            }
        }
        onExited: root.commitsLoading = false
    }

    // ---------- Claude-Aufgaben, heute fertig ----------
    readonly property var claudeDone: ClaudeTasks.list.filter(t => t.state === "done" && (t.finished || 0) >= midnight())
        .sort((a, b) => b.finished - a.finished)

    // ---------- abgehakte To-dos ----------
    property var doneLog: []          // heute: [{ key, list, text, at }]
    property string logDay: ""
    property var _snap: ({})          // key -> done
    property bool _snapReady: false
    readonly property var todosDone: logDay === today() ? doneLog : []

    function _key(list: string, id: string): string {
        return list + "\u0001" + id;
    }
    function _snapshot(): var {
        const s = {};
        for (const list in Todos.lists)
            for (const t of Todos.lists[list] || [])
                s[_key(list, t.id)] = { done: !!t.done, text: t.text, list: list };
        return s;
    }
    // Vergleich mit dem letzten Stand: neu abgehakt -> ins Log, wieder offen -> raus
    function _diff(): void {
        const now = _snapshot();
        if (!_snapReady) {
            _snap = now;
            _snapReady = true;
            return;
        }
        let log = logDay === today() ? doneLog.slice() : [];
        let changed = logDay !== today();
        for (const k in now) {
            const was = _snap[k];
            if (now[k].done && (!was || !was.done) && !log.some(e => e.key === k)) {
                log.push({ key: k, list: now[k].list, text: now[k].text, at: Date.now() });
                changed = true;
            } else if (!now[k].done && was && was.done && log.some(e => e.key === k)) {
                log = log.filter(e => e.key !== k);
                changed = true;
            }
        }
        _snap = now;
        if (changed) {
            doneLog = log;
            logDay = today();
            stateFile.setText(JSON.stringify({ day: logDay, todos: doneLog }, null, 1));
        }
    }
    Connections {
        target: Todos
        function onListsChanged() { root._diff(); }
    }

    FileView {
        id: stateFile
        path: root.home + "/.local/state/desktop/recap.json"
        blockLoading: true
        printErrors: false
        onLoaded: {
            try {
                const d = JSON.parse(text());
                root.logDay = String(d.day || "");
                root.doneLog = Array.isArray(d.todos) ? d.todos.filter(e => e && typeof e.key === "string") : [];
            } catch (e) {}
            root._diff();
        }
        onLoadFailed: root._diff()
    }

    FileView {
        path: root.home + "/.config/desktop/recap.json"
        blockLoading: true
        watchChanges: true
        printErrors: false
        onFileChanged: reload()
        onLoaded: {
            try {
                const d = JSON.parse(text());
                root.cfg = d && typeof d === "object" && !Array.isArray(d) ? d : ({});
            } catch (e) {
                console.warn("recap: recap.json is not valid JSON, using defaults");
                root.cfg = ({});
            }
        }
        onLoadFailed: root.cfg = ({})
    }

    // ---------- Feierabend: Szene „evening“ geht an -> Karte zeigen ----------
    // Nur beim echten Einschalten (busy = evening), nicht wenn der gespeicherte Zustand beim Start geladen wird
    property bool _eveningOn: false
    Connections {
        target: Scenes
        function onActiveChanged() {
            const on = Scenes.isOn("evening");
            if (on && !root._eveningOn && Scenes.busy === "evening" && root.onEvening)
                root.show();
            root._eveningOn = on;
        }
    }
    Component.onCompleted: _eveningOn = Scenes.isOn("evening")

    IpcHandler {
        target: "recap"

        function open(): void {
            root.show();
        }
        function hide(): void {
            root.hide();
        }
        function toggle(): void {
            if (root.open)
                root.hide();
            else
                root.show();
        }
        // Commits neu zählen (ohne Karte)
        function refresh(): void {
            root.refresh();
        }
        // Zahlen ohne Inhalte
        function status(): string {
            return JSON.stringify({ open: root.open, onEvening: root.onEvening, commits: root.commits ? root.commits.total : null,
                todosDone: root.todosDone.length, claudeDone: root.claudeDone.length, focusMin: Focus.focusMin, projectSec: ProjectTime.todaySec });
        }
    }
}
