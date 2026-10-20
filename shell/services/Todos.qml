pragma Singleton
import QtQuick
import Quickshell
import Quickshell.Io

// To-dos pro Desktop (nach Desktop-Name) + allgemeine Liste. Zustand in ~/.local/state/desktop/todos.json
// Der erste offene Punkt des aktuellen Desktops steht oben links und auf dem Lockscreen.
// Projekte: Projekt-Desktops heißen wie das Projekt, die Liste "<Projekt>" ist also zugleich die Projektliste
// (Claude-Zentrale). Dazu pro Projekt Ideen (Brainstorming) – getrennt, zählen nicht als Aufgaben.
// Ideen von Repo-Projekten stehen im Projekt selbst: docs/BACKLOG.md (Standard v2) über scripts/backlog –
// die Datei wird nur geändert, nie committet. Workspaces (.code-workspace) und Ordner ohne Git: lokal wie bisher.
Singleton {
    id: root

    readonly property string general: "General"
    property var lists: ({})   // { "<Name>": [{ id, text, done }] }
    property var ideas: ({})   // { "<Projekt>": [{ id, text, created }] }
    readonly property string current: Desktops.names[Desktops.ids.indexOf(Desktops.current)] ?? root.general
    readonly property var currentItems: lists[current] ?? []
    readonly property var nextItem: currentItems.find(t => !t.done) ?? (lists[general] ?? []).find(t => !t.done) ?? null
    readonly property int openCount: currentItems.filter(t => !t.done).length

    function items(list: string): var {
        return lists[list] ?? [];
    }
    function _set(list, arr) {
        const l = Object.assign({}, lists);
        l[list] = arr;
        lists = l;
        save();
    }
    function add(list: string, text: string): void {
        const t = text.trim();
        if (t)
            _set(list, items(list).concat([{ id: Date.now() + "-" + Math.floor(Math.random() * 1000), text: t, done: false }]));
    }
    function toggle(list: string, id: string): void {
        _set(list, items(list).map(t => t.id === id ? Object.assign({}, t, { done: !t.done }) : t));
    }
    function remove(list: string, id: string): void {
        _set(list, items(list).filter(t => t.id !== id));
    }
    function clearDone(list: string): void {
        _set(list, items(list).filter(t => !t.done));
    }
    function openItems(list: string): var {
        return items(list).filter(t => !t.done);
    }

    // Ideen pro Projekt
    function ideasOf(list: string): var {
        return ideas[list] ?? [];
    }
    function _setIdeas(list, arr) {
        const l = Object.assign({}, ideas);
        if (arr.length)
            l[list] = arr;
        else
            delete l[list];
        ideas = l;
        save();
    }
    function addIdea(list: string, text: string): void {
        const t = text.trim();
        if (t)
            _setIdeas(list, ideasOf(list).concat([{ id: Date.now() + "-" + Math.floor(Math.random() * 1000), text: t, created: Date.now() }]));
    }
    function removeIdea(list: string, id: string): void {
        _setIdeas(list, ideasOf(list).filter(t => t.id !== id));
    }
    // Idee wird Aufgabe
    function promoteIdea(list: string, id: string): void {
        const idea = ideasOf(list).find(t => t.id === id);
        if (!idea)
            return;
        add(list, idea.text);
        removeIdea(list, id);
    }

    // ---------- Ideen im Projekt: docs/BACKLOG.md (scripts/backlog) ----------

    // Pfad -> letzte Ausgabe von scripts/backlog: { ok: true, file, exists, ideas: [{ id, text, … }], changed: [...] }
    // oder { ok: false, reason: "workspace" | "no-dir" | "no-repo" } (= lokal). Fehlt der Pfad: noch nicht geladen.
    property var backlogs: ({})
    property var _jobs: []

    function _repoPath(path) {
        return !!path && !path.endsWith(".code-workspace");
    }
    // true = Ideen dieses Projekts kommen aus docs/BACKLOG.md
    function usesBacklog(path: string): bool {
        const b = backlogs[path];
        return _repoPath(path) && !!b && b.ok === true;
    }
    // Ideen zur Anzeige: BACKLOG.md, sonst lokal; Repo noch nicht geladen -> leer statt kurz die lokalen
    function ideasFor(list: string, path: string): var {
        if (usesBacklog(path))
            return backlogs[path].ideas;
        if (_repoPath(path) && !(path in backlogs))
            return [];
        return ideasOf(list);
    }
    // lokale Ideen, die noch nicht im BACKLOG stehen (Hinweis „move to BACKLOG?“)
    function strayIdeas(list: string, path: string): var {
        return usesBacklog(path) ? ideasOf(list) : [];
    }
    // ungesicherte Änderungen an BACKLOG.md/ROADMAP.md (Git), z. B. ["docs/BACKLOG.md"]
    function backlogChanged(path: string): var {
        return usesBacklog(path) ? backlogs[path].changed || [] : [];
    }

    function loadBacklog(path: string): void {
        if (_repoPath(path) && !_jobs.some(j => j.args[0] === "list" && j.args[1] === path))
            _run({ args: ["list", path] });
    }
    function addIdeaFor(list: string, path: string, text: string): void {
        const t = text.trim();
        if (!t)
            return;
        if (usesBacklog(path))
            _run({ args: ["add", path, t] });
        else
            addIdea(list, t);
    }
    function removeIdeaFor(list: string, path: string, id: string): void {
        if (usesBacklog(path))
            _run({ args: ["rm", path, id] });
        else
            removeIdea(list, id);
    }
    // Idee -> eigene Aufgabe (lokal); aus dem BACKLOG verschwindet sie erst, wenn die Aufgabe steht
    function promoteIdeaFor(list: string, path: string, id: string): void {
        if (!usesBacklog(path))
            return promoteIdea(list, id);
        const idea = backlogs[path].ideas.find(t => t.id === id);
        if (idea)
            _run({ args: ["rm", path, id], ok: () => root.add(list, idea.text) });
    }
    // Idee -> offener Punkt in der ROADMAP (Abschnitt „Neu (aus Backlog)“), im BACKLOG unter „Übernommen“
    function toRoadmap(path: string, id: string): void {
        if (usesBacklog(path))
            _run({ args: ["promote", path, id] });
    }
    // Gedanke aus der Inbox (Notes.qml) als Idee ins docs/BACKLOG.md eines Repos; ok() erst nach Erfolg
    // (Workspace/kein Git: scripts/backlog lehnt ab, der Gedanke bleibt dann in der Inbox)
    function backlogAdd(path: string, text: string, ok: var): void {
        const t = text.trim();
        if (_repoPath(path) && t)
            _run({ args: ["add", path, t], ok: ok });
    }
    // lokale Ideen einmalig ins BACKLOG (mit ihrem Datum); lokal gelöscht wird jede erst nach Erfolg
    function moveIdeasToBacklog(list: string, path: string): void {
        if (!usesBacklog(path))
            return;
        for (const i of ideasOf(list)) {
            if (_jobs.concat(backlogProc.job ? [backlogProc.job] : []).some(j => j.localId === i.id))
                continue;   // schon unterwegs (Doppelklick)
            const d = new Date(i.created || Date.now());
            const date = d.getFullYear() + "-" + String(d.getMonth() + 1).padStart(2, "0") + "-" + String(d.getDate()).padStart(2, "0");
            const id = i.id;
            _run({ args: ["add", path, "--date", date, i.text], localId: id, ok: () => root.removeIdea(list, id) });
        }
    }

    // nacheinander, damit sich zwei Schreibvorgänge nie überholen
    function _run(job) {
        _jobs = _jobs.concat([job]);
        _next();
    }
    function _next() {
        if (backlogProc.running || backlogProc.job || !_jobs.length)
            return;
        const job = _jobs[0];
        _jobs = _jobs.slice(1);
        backlogProc.job = job;
        backlogProc.result = null;
        backlogProc.command = [Quickshell.shellDir + "/../scripts/backlog"].concat(job.args);
        backlogProc.running = true;
    }
    function _finish(job, r) {
        const path = job.args[1];
        if (r && r.ok) {
            const b = Object.assign({}, backlogs);
            b[path] = r;
            backlogs = b;
            if (job.ok)
                job.ok();
        } else if (r && ["workspace", "no-dir", "no-repo"].includes(r.reason)) {
            const b = Object.assign({}, backlogs);
            b[path] = { ok: false, reason: r.reason };
            backlogs = b;
        } else {
            // z. B. Zeile inzwischen von Hand geändert (not-found): Stand neu holen
            console.warn("backlog:", job.args[0], r ? r.reason + (r.error ? " " + r.error : "") : "no output");
            if (job.args[0] !== "list")
                loadBacklog(path);
        }
    }
    Process {
        id: backlogProc
        property var job: null
        property var result: null
        stdout: SplitParser {
            onRead: line => {
                try {
                    backlogProc.result = JSON.parse(line);
                } catch (e) {}
            }
        }
        onExited: {
            const job = backlogProc.job;
            const r = backlogProc.result;
            backlogProc.job = null;
            if (job)
                root._finish(job, r);
            Qt.callLater(root._next);
        }
    }

    FileView {
        id: file
        path: Quickshell.env("HOME") + "/.local/state/desktop/todos.json"
        blockLoading: true
        printErrors: false
        onLoaded: {
            try {
                const d = JSON.parse(text());
                const l = d.lists || {};
                root.ideas = d.ideas || {};
                // alte deutsche Liste "Allgemein" -> "General"
                if (l.Allgemein && !l[root.general]) {
                    l[root.general] = l.Allgemein;
                    delete l.Allgemein;
                }
                root.lists = l;
            } catch (e) {
                if (text().trim() === "")
                    return;
                // kaputte Datei nicht mit leeren Listen überschreiben: erst sichern, bis dahin nicht speichern
                console.warn("Todos: todos.json is broken (" + e + "), backing it up before the next save");
                root.broken = true;
                backup.command = ["cp", "--", file.path, file.path + ".broken-" + Date.now() + ".bak"];
                backup.running = true;
            }
        }
    }
    // true = todos.json war kaputt und ist noch nicht gesichert → save() schreibt nichts
    property bool broken: false
    Process {
        id: backup
        onExited: code => {
            if (code === 0)
                root.broken = false;
            else
                console.warn("Todos: backup of broken todos.json failed, not saving");
        }
    }
    function save(): void {
        if (broken)
            return;
        file.setText(JSON.stringify({ lists: lists, ideas: ideas }, null, 1));
    }

    // Lockscreen: "Wenn du zurück bist: …" = nächster offener Punkt
    onNextItemChanged: Focus.setTask(nextItem ? nextItem.text : "")

    IpcHandler {
        target: "todos"
        function add(text: string): void {
            root.add(root.current, text);
        }
        function list(): string {
            return JSON.stringify({ current: root.current, items: root.currentItems });
        }
        // Punkt mit genau diesem Text aus der Liste des aktuellen Desktops löschen (zum Testen)
        function remove(text: string): string {
            const t = root.currentItems.find(x => x.text === text.trim());
            if (!t)
                return "not found";
            root.remove(root.current, t.id);
            return "ok";
        }
    }
}
