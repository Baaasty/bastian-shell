pragma Singleton
import QtQuick
import Quickshell
import Quickshell.Io
import "inbox.js" as Inbox

// Gedanken parken: das Eingabefeld oben im To-dos-Popout (TodoPopout.qml) schreibt Gedanken als Markdown-Zeilen in
// eine Inbox-Datei (Standard ~/Notes/inbox.md), dort werden sie auch abgearbeitet (abhaken, zur Aufgabe, ins Backlog, löschen).
//   - [ ] 2026-10-18 20:15 Text #projekt        (weitere Zeilen eingerückt; erledigt = "- [x]", bleibt als Verlauf)
// "t "/"!" am Anfang = gleich eine Aufgabe (To-dos des aktuellen Desktops), landet dann nicht in der Inbox.
// Einstellungen von Hand in ~/.config/desktop/notes.json (path, todoPrefixes, todoList) – siehe docs/knowledge/shell-features.md.
// Text-Logik (Lesen, Abhaken, Löschen) in inbox.js, Test: scripts/tests/inbox-test.js. Kein Netz, keine KI.
Singleton {
    id: root

    readonly property string home: Quickshell.env("HOME")
    property var cfg: ({})   // Inhalt von notes.json (fehlt die Datei: Standardwerte)

    readonly property string path: expand(typeof cfg.path === "string" && cfg.path ? cfg.path : "~/Notes/inbox.md")
    readonly property var todoPrefixes: Array.isArray(cfg.todoPrefixes) ? cfg.todoPrefixes.filter(p => typeof p === "string" && p) : ["t ", "!"]
    readonly property string todoList: typeof cfg.todoList === "string" && cfg.todoList ? cfg.todoList : "current"   // "current" = Liste des aktuellen Desktops

    property var entries: []   // alle Einträge der Datei (inbox.js parse)
    // offene Gedanken, neueste zuerst: der gerade geparkte steht direkt unter dem Eingabefeld
    readonly property var items: entries.filter(e => !e.done).reverse()
    readonly property int openCount: items.length

    signal saved(bool todo)
    signal failed

    function expand(p: string): string {
        return p === "~" ? home : p.startsWith("~/") ? home + p.slice(1) : p;
    }
    function parse(text: string): var {
        return Inbox.parsePrefix(text, todoPrefixes);
    }
    function _todoTarget(): string {
        return root.todoList === "current" ? Todos.current : root.todoList;
    }

    // Enter im Eingabefeld: Gedanke an die Inbox anhängen (Datei und Ordner werden bei Bedarf angelegt) – mit Präfix
    // direkt als Aufgabe. Danach saved/failed.
    function add(text: string): bool {
        const r = parse(text);
        if (!r.body)
            return false;
        if (r.todo) {
            Todos.add(_todoTarget(), r.body.replace(/\s*\n\s*/g, " "));
            root.saved(true);
            return true;
        }
        _run({ entry: Inbox.format(r.body, Qt.formatDateTime(new Date(), "yyyy-MM-dd HH:mm")) });
        return true;
    }

    // ---------- Abarbeiten (Eintrag = Objekt aus items) ----------
    function done(e: var): void {
        _run({ edit: t => Inbox.markDone(t, e.key, e.nth) });
    }
    function remove(e: var): void {
        _run({ edit: t => Inbox.remove(t, e.key, e.nth) });
    }
    // wird Aufgabe (To-dos des aktuellen Desktops), in der Inbox abgehakt
    function toTodo(e: var): void {
        Todos.add(_todoTarget(), e.text.replace(/\s*\n\s*/g, " "));
        done(e);
    }
    // wird Idee im docs/BACKLOG.md des Projekts (scripts/backlog); abgehakt erst, wenn das geklappt hat
    function toBacklog(e: var, projectPath: string): void {
        Todos.backlogAdd(projectPath, e.text.replace(/\s*\n\s*/g, " "), () => root.done(e));
    }

    // Schreiben nacheinander (Anhängen läuft als Prozess, Ändern direkt), damit sich nichts überholt
    property var _queue: []
    function _run(job: var): void {
        _queue = _queue.concat([job]);
        _next();
    }
    function _next(): void {
        while (!writer.running && !writer.job && _queue.length) {
            const job = _queue[0];
            _queue = _queue.slice(1);
            if (job.edit) {
                _edit(job.edit);
                continue;
            }
            writer.job = job;
            writer.command = ["sh", "-c", 'mkdir -p "$(dirname "$1")" && printf "%s\\n" "$2" >> "$1"', "sh", path, job.entry];
            writer.running = true;
        }
    }
    // frisch lesen (Datei kann von Hand geändert sein), ändern, schreiben; null = Eintrag nicht mehr da
    function _edit(fn: var): void {
        inbox.reload();
        const before = inbox.text();
        const after = fn(before);
        if (after === null) {
            console.warn("notes: entry no longer in " + root.path + " (changed by hand?)");
            root.entries = Inbox.parse(before);
            return;
        }
        inbox.setText(after);
        root.entries = Inbox.parse(after);
    }
    Process {
        id: writer
        property var job: null
        onExited: code => {
            const j = writer.job;
            writer.job = null;
            if (j) {
                if (code === 0) {
                    inbox.reload();   // Datei kann neu entstanden sein (dann greift watchChanges erst danach)
                    root.saved(false);
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

    // ---------- Inbox-Datei (bei Änderung neu einlesen; blockierend, damit _edit immer den frischen Stand ändert) ----------
    FileView {
        id: inbox
        path: root.path
        watchChanges: true
        blockAllReads: true
        printErrors: false
        onFileChanged: reload()
        onLoaded: root.entries = Inbox.parse(text())
        onLoadFailed: root.entries = []
    }

    // qs ipc --any-display -p ~/Workspace/bastian-shell/shell call inbox …
    IpcHandler {
        target: "inbox"
        // gleiche Regeln wie Enter im Eingabefeld ("t …" = Aufgabe)
        function add(text: string): void {
            root.add(text);
        }
        function count(): string {
            return String(root.openCount);
        }
        function list(): string {
            return JSON.stringify(root.items.map(e => ({ date: e.date, time: e.time, text: e.text })));
        }
        // neuesten offenen Gedanken mit genau diesem Text abhaken (zum Testen)
        function done(text: string): string {
            const e = root.items.find(x => x.text === text.trim());
            if (!e)
                return "not found";
            root.done(e);
            return "ok";
        }
        // neuesten offenen Gedanken mit genau diesem Text löschen (zum Testen)
        function remove(text: string): string {
            const e = root.items.find(x => x.text === text.trim());
            if (!e)
                return "not found";
            root.remove(e);
            return "ok";
        }
    }
}
