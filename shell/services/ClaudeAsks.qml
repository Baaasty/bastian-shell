pragma Singleton
import QtQuick
import Quickshell
import Quickshell.Io
import qs.config

// „Wie weit bist du?“ an eine Claude-Sitzung (Knopf „status“ an einer Sitzung im Popout der Claude-Zentrale).
// scripts/claude-ask fragt einen Abzweig der Sitzung (--resume … --fork-session, ohne Werkzeuge, ohne Hooks,
// nicht gespeichert) als eigene systemd-User-Unit; die laufende Sitzung bleibt unberührt.
// Ablage ~/.local/state/desktop/claude-status/ (700/600), die Shell beobachtet nur den Stempel .changed.
// Antworten stehen 10 min nach Abschluss im Popout, dann verschwinden sie von selbst.
Singleton {
    id: root

    readonly property string script: Config.repo + "/scripts/claude-ask"
    readonly property string dir: Quickshell.env("HOME") + "/.local/state/desktop/claude-status"
    readonly property real showMs: 10 * 60000

    // [{ id, session, fork, cwd, project, state: "starting"|"running"|"done"|"failed"|"stopped"|"lost",
    //    started, finished, result, cut, error }]
    property var list: []
    readonly property int running: list.filter(a => active(a)).length
    // Sitzungs-ID -> neueste Frage (für die Zeilen im Popout); abgelaufene fliegen raus
    readonly property var bySession: _index(list, now)
    // Abzweig-Sitzungen: nie als eigene Sitzung zeigen (ClaudeHub filtert sie)
    readonly property var forks: list.map(a => a.fork).filter(f => !!f)
    property real now: Date.now()
    property bool watching: false

    function active(a: var): bool {
        return !!a && (a.state === "starting" || a.state === "running");
    }
    function _index(l, now) {
        const m = {};
        for (const a of l) {
            if (!a.session || m[a.session])
                continue;
            if (!active(a) && now - (a.finished || 0) > showMs)
                continue;
            m[a.session] = a;
        }
        return m;
    }
    function forSession(sid: string): var {
        return bySession[sid] ?? null;
    }

    function ask(sid: string, cwd: string): void {
        if (!/^[0-9a-f]{8}-[0-9a-f]{4}-[0-9a-f]{4}-[0-9a-f]{4}-[0-9a-f]{12}$/i.test(sid || ""))
            return;
        if (active(forSession(sid)))
            return;
        // sofort „asking…“ zeigen, das Skript zieht nach
        list = [{ id: "pending-" + sid, session: sid, cwd: cwd, state: "starting", started: Date.now(), finished: 0 }].concat(list);
        _queue = _queue.concat([{ sid: sid, cwd: cwd || "" }]);
        _next();
    }
    property var _queue: []
    property var _job: null
    function _next(): void {
        if (starter.running || !_queue.length)
            return;
        const job = _queue[0];
        _queue = _queue.slice(1);
        _job = job;
        starter.command = [script, "start", job.sid, job.cwd || Quickshell.env("HOME")];
        starter.running = true;
    }
    function stop(id: string): void {
        list = list.map(x => x.id === id ? Object.assign({}, x, { state: "stopped", finished: Date.now() }) : x);
        if (!id.startsWith("pending-"))
            Quickshell.execDetached([script, "stop", id]);
    }
    function remove(id: string): void {
        list = list.filter(x => x.id !== id);
        if (!id.startsWith("pending-"))
            Quickshell.execDetached([script, "remove", id]);
    }

    function refresh(): void {
        if (lister.running)
            again = true;
        else
            lister.running = true;
    }
    property bool again: false

    Process {
        id: starter
        stdout: StdioCollector {}
        onExited: (code, status) => {
            // Start abgelehnt (Sitzung nicht gefunden …): Platzhalter als Fehler zeigen
            if (code !== 0 && root._job) {
                const sid = root._job.sid;
                root.list = root.list.map(x => x.id === "pending-" + sid
                    ? Object.assign({}, x, { state: "failed", finished: Date.now(), error: "could not ask this session" }) : x);
            }
            root._job = null;
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
                    if (!Array.isArray(l))
                        return;
                    // noch nicht gestartete Platzhalter behalten, bis das Skript die echte Frage meldet
                    const pend = root.list.filter(x => String(x.id).startsWith("pending-") && !l.some(y => y.session === x.session)
                        && (x.state === "starting" ? Date.now() - x.started < 30000 : Date.now() - x.finished < root.showMs));
                    root.list = pend.concat(l);
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
        command: ["sh", "-c", "umask 077; mkdir -p -m 700 \"$1\" && { [ -e \"$1/.changed\" ] || echo 0 > \"$1/.changed\"; }", "sh", root.dir]
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
    // Sicherheitsnetz, solange gefragt wird (Stempel kommt sonst sowieso)
    Timer {
        interval: 5000
        repeat: true
        running: root.running > 0
        onTriggered: root.refresh()
    }
    // Ablauf nach 10 min (nur solange überhaupt etwas angezeigt wird)
    Timer {
        interval: root.watching ? 15000 : 60000
        repeat: true
        running: root.list.length > 0
        onTriggered: {
            root.now = Date.now();
            // Abgelaufenes auch aus der Liste werfen (dann steht der Timer still)
            if (root.list.some(a => !root.active(a) && root.now - (a.finished || 0) > root.showMs))
                root.refresh();
        }
    }
    onWatchingChanged: {
        now = Date.now();
        if (watching)
            refresh();
    }

    IpcHandler {
        target: "claudeask"

        // Statusfrage an eine Sitzung (zum Testen; im Alltag über den Knopf im Popout)
        function ask(session: string, cwd: string): void {
            root.ask(session, cwd);
        }
        // nur Zustand, keine Antworttexte (die bleiben im Popout)
        function status(): string {
            return JSON.stringify(root.list.map(a => ({ id: a.id, session: a.session, fork: a.fork || "", state: a.state,
                started: a.started, finished: a.finished, chars: String(a.result || "").length, error: a.error || "" })));
        }
    }
}
