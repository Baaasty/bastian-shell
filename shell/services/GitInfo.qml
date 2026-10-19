pragma Singleton
import QtQuick
import Quickshell
import Quickshell.Io

// Zuordnung Workspace -> Projekt (für Quicklinks, Idee n) und Git-/CI-Status je Projekt-Workspace (Idee o).
// Ein Workspace gehört zu einem Projekt, wenn sein (eigener) Name der Projekt-ID oder dem Anzeigenamen
// aus projects/projects.json entspricht (Groß-/Kleinschreibung egal). Ohne eigenen Namen: kein Projekt.
// Registry nur lesen – schreiben nur über scripts/project (docs/QUICKLINKS.md).
//
// Git-/CI-Status (Idee o): nur für Projekte, die gerade einen Workspace haben, und nur solange die Leiste
// sichtbar ist (WorkBar setzt `active`). Git alle 30 s über `scripts/gitinfo <ordner>…` (ein Aufruf, nur lesen),
// CI (gh) je Projekt höchstens alle 5 min über `scripts/gitinfo --ci-only` (5 s Timeout, Fehler still = unbekannt).
Singleton {
    id: root

    function home(path: string): string {
        return String(path || "").replace(/^~(?=\/)/, Quickshell.env("HOME"));
    }

    // Projekt zu einem Workspace-Namen: Eintrag aus projects.json + id, sonst null
    function projectFor(name: var): var {
        const raw = String(name ?? "").trim();
        if (!raw)
            return null;
        const want = [raw.toLowerCase(), Templates.projectName(raw).toLowerCase()];
        const s = Projects.settings;
        for (const id in s) {
            const e = s[id];
            if (want.includes(id.toLowerCase()) || want.includes(String(e.name || "").toLowerCase()))
                return Object.assign({ id: id }, e);
        }
        return null;
    }

    // Projekt zu einer Workspace-ID (wie Desktops.ids)
    function projectForId(deskId: string): var {
        const d = Desktops.list.find(x => String(x.id) === String(deskId));
        return d ? projectFor(d.name) : null;
    }

    // ---------- Git-/CI-Status ----------
    property bool active: false       // Leiste sichtbar -> Daten holen und aktuell halten
    property var git: ({})            // Projekt-ID -> { branch, changes, ahead, behind, upstream, repoUrl }
    property var ci: ({})             // Projekt-ID -> { state: ok|fail|running|none, workflow, url } oder null (unbekannt)
    property var _ciAt: ({})          // Projekt-ID -> Zeitpunkt des letzten CI-Abrufs (auch bei Fehler: 5 min Ruhe)
    property double _gitAt: 0
    readonly property string script: Quickshell.shellDir + "/../scripts/gitinfo"
    readonly property int gitEvery: 30000
    readonly property int ciEvery: 300000

    // Projekte mit Workspace: [{ id, dir }] (dir = Haupt-Repo)
    readonly property var targets: {
        const out = [], seen = {};
        for (const d of Desktops.list) {
            const p = projectFor(d.name);
            if (p && !seen[p.id] && p.paths && p.paths.length) {
                seen[p.id] = true;
                out.push({ id: p.id, dir: home(p.paths[0]) });
            }
        }
        return out;
    }
    readonly property string targetKey: targets.map(t => t.id + "=" + t.dir).join("|")
    onTargetKeyChanged: if (active) refresh()
    onActiveChanged: if (active) refresh()

    function refresh(): void {
        if (Date.now() - _gitAt > 10000 || !Object.keys(git).length || targets.some(t => !git[t.id]))
            refreshGit();
        refreshCi();
    }

    function refreshGit(): void {
        if (gitProc.running || !targets.length)
            return;
        _gitAt = Date.now();
        gitProc.dirs = targets;
        gitProc.command = [script].concat(targets.map(t => t.dir));
        gitProc.running = true;
    }
    function refreshCi(): void {
        if (ciProc.running)
            return;
        const now = Date.now();
        const stale = targets.filter(t => now - (_ciAt[t.id] || 0) > ciEvery);
        if (!stale.length)
            return;
        const at = Object.assign({}, _ciAt);
        for (const t of stale)
            at[t.id] = now;
        _ciAt = at;
        ciProc.dirs = stale;
        ciProc.command = [script, "--ci-only"].concat(stale.map(t => t.dir));
        ciProc.running = true;
    }

    // Ergebnis (Schlüssel = Ordner) auf Projekt-IDs abbilden und in die Eigenschaft einmischen
    function _merge(current: var, dirs: var, text: string, pick: var): var {
        let j = {};
        try {
            j = JSON.parse(text || "{}");
        } catch (e) {
            return current;
        }
        const next = Object.assign({}, current);
        for (const t of dirs)
            if (j[t.dir] !== undefined)
                next[t.id] = pick(j[t.dir]);
        return next;
    }

    Process {
        id: gitProc
        property var dirs: []
        stdout: StdioCollector {
            onStreamFinished: root.git = root._merge(root.git, gitProc.dirs, text, x => x)
        }
    }
    Process {
        id: ciProc
        property var dirs: []
        stdout: StdioCollector {
            onStreamFinished: root.ci = root._merge(root.ci, ciProc.dirs, text, x => x.ci)
        }
    }

    // Nur bei sichtbarer Leiste: Git alle 30 s, CI-Check (je Projekt 5 min Cache) jede Minute
    Timer {
        interval: root.gitEvery
        repeat: true
        running: root.active
        onTriggered: root.refreshGit()
    }
    Timer {
        interval: 60000
        repeat: true
        running: root.active
        onTriggered: root.refreshCi()
    }
}
