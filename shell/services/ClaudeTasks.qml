pragma Singleton
import QtQuick
import Quickshell
import Quickshell.Io
import qs.config

// Claude-Aufgaben im Hintergrund („Ask Claude…“ im Popout der Claude-Zentrale).
// scripts/claude-task startet pro Aufgabe eine eigene `claude -p`-Sitzung als systemd-User-Unit
// (übersteht Shell-Neustarts) und legt Meta + Ergebnis in ~/.local/state/desktop/claude-tasks/ ab.
// Die Shell beobachtet nur den Stempel .changed und holt die Liste per `claude-task list`.
// Der Aufgabentext geht per Umgebung ans Skript (nie als Argument, nie ins Log).
Singleton {
    id: root

    readonly property string script: Config.repo + "/scripts/claude-task"
    readonly property string dir: Quickshell.env("HOME") + "/.local/state/desktop/claude-tasks"

    // [{ id, session, cwd, project, title, state: "starting"|"running"|"done"|"failed"|"stopped"|"lost",
    //    started, finished, steps, cost, turns, denials, error, seen, result, cut }]
    property var list: []
    readonly property int running: list.filter(t => active(t)).length
    // Popout offen -> öfter nachsehen (Schritte zählen hoch)
    property bool watching: false
    // per Klick auf die Meldung angefordert: Popout zeigt dieses Ergebnis
    signal showRequested(string id)

    function active(t: var): bool {
        return t.state === "starting" || t.state === "running";
    }
    function finished(t: var): bool {
        return !active(t);
    }
    // "your turn": fertig/fehlgeschlagen und noch nicht angesehen
    function unseen(t: var): bool {
        return (t.state === "done" || t.state === "failed") && !t.seen;
    }

    function refresh(): void {
        if (lister.running)
            again = true;
        else
            lister.running = true;
    }
    property bool again: false

    // neue Aufgabe; Starts nacheinander (ein Process), Text nur in der Warteschlange im Speicher
    property var _queue: []
    function start(path: string, text: string): void {
        const t = String(text || "").trim();
        if (!path || !t)
            return;
        _queue = _queue.concat([{ path: path, text: t }]);
        _next();
    }
    function _next(): void {
        if (starter.running || !_queue.length)
            return;
        const job = _queue[0];
        _queue = _queue.slice(1);
        starter.environment = { CLAUDE_TASK_TEXT: job.text };
        starter.command = [script, "start", job.path];
        starter.running = true;
    }
    function stop(id: string): void {
        _mark(id, { state: "stopped" });
        Quickshell.execDetached([script, "stop", id]);
    }
    function seen(id: string): void {
        const t = list.find(x => x.id === id);
        if (!t || t.seen)
            return;
        _mark(id, { seen: true });
        Quickshell.execDetached([script, "seen", id]);
    }
    function remove(id: string): void {
        list = list.filter(x => x.id !== id);
        Quickshell.execDetached([script, "remove", id]);
    }
    // sofort anzeigen, das Skript zieht nach
    function _mark(id: string, fields: var): void {
        list = list.map(x => x.id === id ? Object.assign({}, x, fields) : x);
    }
    function byId(id: string): var {
        return list.find(x => x.id === id) ?? null;
    }

    Process {
        id: starter
        stdout: StdioCollector {}
        onExited: {
            // Text nicht länger im Prozess-Objekt halten
            starter.environment = {};
            root.refresh();
            root._next();
        }
    }

    Process {
        id: lister
        command: [root.script, "list"]
        stdout: StdioCollector {
            onStreamFinished: {
                try {
                    const l = JSON.parse(text || "[]");
                    if (Array.isArray(l))
                        root.list = l;
                } catch (e) {}
            }
        }
        onExited: {
            if (root.again) {
                root.again = false;
                running = true;
            }
        }
    }

    // Ordner + Stempel anlegen, damit FileView von Anfang an etwas zu beobachten hat
    Process {
        running: true
        command: ["sh", "-c", "mkdir -p -m 700 \"$1\" && { [ -e \"$1/.changed\" ] || echo 0 > \"$1/.changed\"; }", "sh", root.dir]
        onExited: {
            stamp.reload();
            root.refresh();
        }
    }
    FileView {
        id: stamp
        path: root.dir + "/.changed"
        watchChanges: true
        printErrors: false
        onFileChanged: {
            reload();
            root.refresh();
        }
    }
    // Schritte/Laufzeit nachziehen, solange etwas läuft
    Timer {
        interval: root.watching ? 4000 : 20000
        repeat: true
        running: root.running > 0
        onTriggered: root.refresh()
    }
}
