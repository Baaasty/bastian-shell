pragma Singleton
import QtQuick
import Quickshell
import Quickshell.Io

// Gedanken parken (Super+N): Notizen landen als Markdown-Zeilen in einer Inbox-Datei (Standard ~/Notes/inbox.md).
//   - [ ] 2026-10-18 20:15 Text #projekt        (weitere Zeilen eingerückt; "t "/"!" am Anfang = zusätzlich To-do)
// Einstellungen von Hand in ~/.config/desktop/notes.json (path, todoPrefixes, todoList, savedMs) – siehe docs/knowledge/shell-features.md.
// Kein Netz, keine KI. Entwurf bleibt in ~/.local/state/desktop/notes-draft.txt, bis er gespeichert wird.
Singleton {
    id: root

    readonly property string home: Quickshell.env("HOME")
    property var cfg: ({})   // Inhalt von notes.json (fehlt die Datei: Standardwerte)

    readonly property string path: expand(typeof cfg.path === "string" && cfg.path ? cfg.path : "~/Notes/inbox.md")
    readonly property var todoPrefixes: Array.isArray(cfg.todoPrefixes) ? cfg.todoPrefixes.filter(p => typeof p === "string" && p) : ["t ", "!"]
    readonly property string todoList: typeof cfg.todoList === "string" && cfg.todoList ? cfg.todoList : "current"   // "current" = Liste des aktuellen Desktops
    readonly property int savedMs: cfg.savedMs > 0 ? cfg.savedMs : 1000

    property string draft: ""     // Entwurf (bleibt bis zum nächsten Öffnen)
    property int openCount: 0     // offene Zeilen "- [ ]" in der Inbox (nur lesen)

    signal saved(bool todo)
    signal failed

    function expand(p: string): string {
        return p === "~" ? home : p.startsWith("~/") ? home + p.slice(1) : p;
    }

    // "t einkaufen" / "!einkaufen" -> { todo: true, body: "einkaufen" }
    function parse(text: string): var {
        const t = text.trim();
        const low = t.toLowerCase();
        for (const p of todoPrefixes) {
            if (low.startsWith(p.toLowerCase()) && t.slice(p.length).trim())
                return { todo: true, body: t.slice(p.length).trim() };
        }
        return { todo: false, body: t };
    }

    // Eintrag als Markdown: erste Zeile mit Kästchen + Zeitstempel, Folgezeilen eingerückt
    function format(body: string, todo: bool): string {
        const lines = body.split("\n").map(l => l.replace(/\s+$/, ""));
        const stamp = Qt.formatDateTime(new Date(), "yyyy-MM-dd HH:mm");
        let out = "- [ ] " + stamp + " " + lines[0] + (todo ? " #todo" : "");
        for (const l of lines.slice(1))
            out += "\n" + (l ? "    " + l : "");
        return out;
    }

    // speichern: an die Inbox anhängen (Datei und Ordner werden bei Bedarf angelegt), danach saved/failed
    function add(text: string): bool {
        const r = parse(text);
        if (!r.body)
            return false;
        const job = { entry: format(r.body, r.todo), todo: r.todo, body: r.body };
        _queue = _queue.concat([job]);
        _next();
        return true;
    }

    property var _queue: []
    function _next(): void {
        if (writer.running || writer.job || !_queue.length)
            return;
        writer.job = _queue[0];
        _queue = _queue.slice(1);
        writer.command = ["sh", "-c", 'mkdir -p "$(dirname "$1")" && printf "%s\\n" "$2" >> "$1"', "sh", path, writer.job.entry];
        writer.running = true;
    }
    Process {
        id: writer
        property var job: null
        onExited: code => {
            const j = writer.job;
            writer.job = null;
            if (j) {
                if (code === 0) {
                    if (j.todo)
                        Todos.add(root.todoList === "current" ? Todos.current : root.todoList, j.body.replace(/\s*\n\s*/g, " "));
                    inbox.reload();   // Datei kann neu entstanden sein (dann greift watchChanges erst danach)
                    root.saved(j.todo);
                } else {
                    console.warn("notes: could not write " + root.path + " (exit " + code + ")");
                    root.failed();
                }
            }
            Qt.callLater(root._next);
        }
    }

    // ---------- Einstellungen ----------
    FileView {
        path: root.home + "/.config/desktop/notes.json"
        watchChanges: true
        printErrors: false
        onFileChanged: reload()
        onLoaded: {
            try {
                const d = JSON.parse(text());
                root.cfg = d && typeof d === "object" ? d : ({});
            } catch (e) {
                console.warn("notes: notes.json is not valid JSON, using defaults");
                root.cfg = ({});
            }
        }
        onLoadFailed: root.cfg = ({})
    }

    // ---------- Zähler offener Notizen (billig: Datei lesen, bei Änderung neu zählen) ----------
    FileView {
        id: inbox
        path: root.path
        watchChanges: true
        printErrors: false
        onFileChanged: reload()
        onLoaded: root.openCount = (text().match(/^- \[ \] /gm) || []).length
        onLoadFailed: root.openCount = 0
    }

    // ---------- Entwurf ----------
    property bool _draftReady: false
    FileView {
        id: draftFile
        path: root.home + "/.local/state/desktop/notes-draft.txt"
        printErrors: false
        onLoaded: {
            if (!root.draft)
                root.draft = text();
            root._draftReady = true;
        }
        onLoadFailed: root._draftReady = true
    }
    Timer {
        id: persist
        interval: 700
        onTriggered: draftFile.setText(root.draft)
    }
    onDraftChanged: if (_draftReady) persist.restart()

    IpcHandler {
        target: "notes"
        function open(): void {
            root.requestOpen(true);
        }
        function toggle(): void {
            root.requestOpen(false);
        }
        function close(): void {
            root.requestClose();
        }
        // zum Testen: speichert direkt (ohne Fenster), gleiche Regeln wie Enter im Feld
        function add(text: string): void {
            root.add(text);
        }
        function count(): string {
            return String(root.openCount);
        }
    }

    // Fenster (NotesWindow) lauscht darauf
    signal openRequested(bool forceOpen)
    signal closeRequested
    function requestOpen(forceOpen: bool): void {
        openRequested(forceOpen);
    }
    function requestClose(): void {
        closeRequested();
    }
}
