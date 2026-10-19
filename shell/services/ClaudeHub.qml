pragma Singleton
import QtQuick
import Quickshell
import Quickshell.Io
import qs.config

// Claude-Zentrale oben links: alle aktiven Projekte auf einen Blick.
// Aktiv = Claude-Sitzung jünger als 6 h (Claude.sessions) oder offenes VS-Code-Fenster (Context.openProjects).
// Pro Projekt: Farbe (theme/projects.json), Sitzungen samt Aufgabenliste, dazu – nur solange das Popout
// offen ist – Branch, Änderungen und Roadmap-Fortschritt (scripts/project-info).
// Subagents je Sitzung aus scripts/claude-agents (alle 5 s bei offenem Popout, sonst alle 30 s für den Chip),
// dazu Sitzungstitel, Modell und Tokens im Kontext. Die Agent-Map (modules/bar/AgentMap.qml) zeigt eine Sitzung als Baum.
// "Braucht dich": Claude wartet (Erlaubnis/Frage) oder ist fertig und du hast das Projekt seitdem nicht angesehen.
// Hintergrund-Aufgaben (ClaudeTasks, „Ask Claude…“) hängen als bgTasks am Projekt; ihre Sitzung steht dann
// nicht zusätzlich unter sessions, sondern als live-Info an der Aufgabe.
// Statusfragen („status“ an einer Sitzung, ClaudeAsks/scripts/claude-ask) laufen als Abzweig; dessen
// Sitzungs-ID wird hier nie als eigene Sitzung gezeigt.
Singleton {
    id: root

    // [{ name, path, color, open, current, sessions: [{ id, state, since, updated, tasks, needsYou, agents, agentsRunning,
    //    title, model, context, agentsTotal }], needs, working, last, agents, agentsRunning, info: { dir, branch, changes, roadmap } | null,
    //    bgTasks: [ClaudeTasks-Eintrag + { needsYou, live: { state, agentsRunning } | null }] }]
    // agents: [{ id, description, type, state: "running"|"done", since, updated, last, duration, tokens, file }] (laufende zuerst)
    readonly property var projects: build(Claude.sessions, Context.openProjects, Context.project, Projects.list, acked, colors, info, agents, ClaudeTasks.list, ClaudeGate.items, ClaudeAsks.forks, now)
    readonly property int count: projects.length
    readonly property int needsCount: projects.reduce((n, p) => n + p.needs, 0)
    readonly property int workingCount: projects.filter(p => p.working).length
    readonly property int agentsRunning: projects.reduce((n, p) => n + p.agentsRunning, 0)

    // Popout offen -> Git/Roadmap regelmäßig nachladen
    property bool watching: false
    property var info: ({})      // Pfad -> project-info-Ergebnis
    property var acked: ({})     // Sitzungs-ID -> since des gesehenen "done"
    property var colors: ({})    // Projektname -> Farbe
    property var agents: ({})    // Sitzungs-ID -> { title, model, context, file, total, agents } (claude-agents)
    // Agent-Map: welche Sitzung gerade als Baum offen ist ("" = zu)
    property string mapSession: ""
    property string _agentsText: ""
    property real now: Date.now()
    // per IPC angefordert (claudehub open <projekt>): Popout öffnen
    signal openRequested(string name)

    function projectColor(name: string): color {
        return colors[name] ?? Theme.woodLight;
    }

    // Projekt zu einem Arbeitsordner: längster passender Repo-Pfad (Workspaces zählen hier nicht)
    function _projectFor(cwd, list) {
        let best = null;
        for (const p of list) {
            if (p.workspace || !(cwd === p.path || cwd.startsWith(p.path + "/")))
                continue;
            if (!best || p.path.length > best.path.length)
                best = p;
        }
        return best;
    }
    // Pfad für Git/Roadmap/Öffnen: Repo-Ordner vor Workspace-Datei
    function _pathFor(name, list) {
        const lower = name.toLowerCase();
        const hits = list.filter(p => p.name === name || p.name.toLowerCase() === lower);
        const repo = hits.find(p => !p.workspace);
        return repo ? repo.path : (hits[0] ? hits[0].path : "");
    }

    function build(sessions, open, current, list, acked, colors, info, agents, tasks, gate, forks, now) {
        const map = {};
        const get = (name, path) => {
            if (!map[name])
                map[name] = { name: name, path: path || _pathFor(name, list), sessions: [], bgTasks: [], open: false, last: 0 };
            return map[name];
        };
        // Sitzungen der Hintergrund-Aufgaben: live-Status sammeln statt eigener Zeile
        const bgLive = {};
        for (const t of tasks)
            if (t.session)
                bgLive[t.session] = null;
        for (const id in sessions) {
            const s = sessions[id];
            if (!s || !Claude.rank[s.state] || now - (s.updated || s.since || 0) > Claude.maxAge)
                continue;
            // Abzweig einer Statusfrage (ClaudeAsks): läuft ohne Hooks, falls doch gemeldet -> nicht zeigen
            if (forks.includes(id))
                continue;
            const proj = s.cwd ? _projectFor(s.cwd, list) : null;
            const name = proj ? proj.name : (s.project || "");
            if (!name)
                continue;
            const p = get(name, proj ? _pathFor(proj.name, list) : s.cwd);
            const needsYou = s.state === "waiting" || (s.state === "done" && acked[id] !== s.since);
            const extra = agents[id] || {};
            const ag = extra.agents || [];
            if (id in bgLive) {
                bgLive[id] = { state: s.state, agentsRunning: ag.filter(a => a.state === "running").length };
                continue;
            }
            p.sessions.push({ id: id, cwd: s.cwd || "", state: s.state, since: s.since || 0, updated: s.updated || 0, tasks: s.tasks || null, needsYou: needsYou,
                agents: ag, agentsRunning: ag.filter(a => a.state === "running").length,
                title: extra.title || "", model: extra.model || "", context: extra.context || 0, agentsTotal: extra.total || ag.length });
            p.last = Math.max(p.last, s.updated || s.since || 0);
        }
        for (const t of tasks) {
            const proj = t.cwd ? _projectFor(t.cwd, list) : null;
            const name = proj ? proj.name : (t.project || "");
            if (!name)
                continue;
            const p = get(name, proj ? _pathFor(proj.name, list) : t.cwd);
            const live = t.session ? bgLive[t.session] ?? null : null;
            const running = ClaudeTasks.active(t);
            // wartet: laut Hook (claude-status) oder eine offene Antwort-Karte gehört zu dieser Sitzung
            const asks = running && gate.some(e => e.session === t.session);
            const needsYou = running ? (asks || (live !== null && live.state === "waiting")) : ClaudeTasks.unseen(t);
            p.bgTasks.push(Object.assign({}, t, { needsYou: needsYou, waiting: running && needsYou, live: running ? live : null }));
            p.last = Math.max(p.last, t.finished || t.started || 0);
        }
        for (const name of open)
            get(name, "").open = true;

        const out = Object.values(map).map(p => {
            p.sessions.sort((a, b) => b.updated - a.updated);
            p.needs = p.sessions.filter(s => s.needsYou).length + p.bgTasks.filter(t => t.needsYou).length;
            p.working = p.sessions.some(s => s.state === "working") || p.bgTasks.some(t => ClaudeTasks.active(t));
            p.agents = [].concat(...p.sessions.map(s => s.agents));
            p.agentsRunning = p.sessions.reduce((n, s) => n + s.agentsRunning, 0) + p.bgTasks.reduce((n, t) => n + (t.live ? t.live.agentsRunning : 0), 0);
            p.current = p.name === current;
            p.color = colors[p.name] ?? Theme.woodLight;
            p.info = info[p.path] ?? null;
            return p;
        });
        const score = p => p.needs > 0 ? 3 : p.working ? 2 : 1;
        out.sort((a, b) => score(b) - score(a) || (b.current - a.current) || (b.last - a.last) || a.name.localeCompare(b.name));
        return out;
    }

    // fertige Sitzung gilt als gesehen, sobald ihr VS-Code-Fenster vorn ist
    function ack(): void {
        const name = Context.activeProject;
        if (!name)
            return;
        let changed = false;
        const a = Object.assign({}, acked);
        for (const p of projects) {
            if (p.name !== name)
                continue;
            for (const s of p.sessions) {
                if (s.state === "done" && a[s.id] !== s.since) {
                    a[s.id] = s.since;
                    changed = true;
                }
            }
        }
        if (changed)
            acked = a;
    }
    Connections {
        target: Context
        function onActiveProjectChanged() { root.ack(); }
    }
    Connections {
        target: Claude
        function onSessionsChanged() { ackLater.restart(); }
    }
    // erst nach dem Neuaufbau von projects
    Timer {
        id: ackLater
        interval: 50
        onTriggered: root.ack()
    }

    // Projekt nach vorn: eigenes VS-Code-Fenster, sonst öffnen
    function activate(p: var): void {
        if (Context.hasWindow(p.name))
            Context.activateCode(p.name);
        else if (p.path)
            Projects.open(p.path);
        else
            Context.activateCode(p.name);
    }
    // Hintergrund-Sitzung in VS Code weitermachen: Projektfenster nach vorn, dann die Sitzung über den
    // URI-Handler der Claude-Extension öffnen (vscode://anthropic.claude-code/open?session=<uuid>, landet im
    // zuletzt aktiven Fenster). Startet VS Code erst, länger warten.
    property string _resumeUri: ""
    function continueInCode(p: var, t: var): void {
        const had = p && Context.hasWindow(p.name);
        if (p)
            activate(p);
        const sid = t ? String(t.session || "") : "";
        if (!/^[0-9a-f]{8}-[0-9a-f]{4}-[0-9a-f]{4}-[0-9a-f]{4}-[0-9a-f]{12}$/i.test(sid))
            return;
        _resumeUri = "vscode://anthropic.claude-code/open?session=" + sid;
        resumeLater.interval = had ? 700 : 5000;
        resumeLater.restart();
    }
    Timer {
        id: resumeLater
        onTriggered: Launch.code(["--open-url", root._resumeUri])
    }
    // Roadmap-Datei in VS Code (landet im Fenster, das den Ordner offen hat)
    function openRoadmap(p: var): void {
        if (p.info && p.info.roadmap)
            Launch.code([p.info.roadmap.file]);
    }

    function refresh(): void {
        const paths = projects.map(p => p.path).filter(x => x);
        if (!paths.length || scan.running)
            return;
        scan.command = [Quickshell.shellDir + "/../scripts/project-info"].concat(paths);
        scan.running = true;
    }
    onWatchingChanged: {
        ClaudeTasks.watching = watching;
        ClaudeAsks.watching = watching;
        if (watching) {
            refresh();
            refreshAgents();
            ClaudeTasks.refresh();
        }
    }

    // Subagents: nur übernehmen, wenn sich wirklich etwas geändert hat (sonst baut projects ständig neu)
    function refreshAgents(): void {
        if (!agentScan.running)
            agentScan.running = true;
    }
    Process {
        id: agentScan
        command: [Quickshell.shellDir + "/../scripts/claude-agents"]
        stdout: StdioCollector {
            onStreamFinished: {
                const t = text.trim();
                if (t === root._agentsText)
                    return;
                try {
                    root.agents = JSON.parse(t);
                    root._agentsText = t;
                } catch (e) {}
            }
        }
    }
    Timer {
        interval: root.watching ? 5000 : 30000
        repeat: true
        running: true
        triggeredOnStart: true
        onTriggered: root.refreshAgents()
    }
    // eine Sitzung fängt an oder hört auf -> gleich nachsehen (neue Agents kommen meist dann)
    Connections {
        target: Claude
        function onSessionsChanged() { agentLater.restart(); }
    }
    Timer {
        id: agentLater
        interval: 1500
        onTriggered: root.refreshAgents()
    }

    Process {
        id: scan
        stdout: StdioCollector {
            onStreamFinished: {
                try {
                    root.info = Object.assign({}, root.info, JSON.parse(text));
                } catch (e) {}
            }
        }
    }

    Timer {
        interval: 20000
        repeat: true
        running: root.watching
        onTriggered: root.refresh()
    }
    // Zeitangaben ("seit 12 min") + Ablauf nach 6 h
    Timer {
        interval: root.watching ? 15000 : 60000
        repeat: true
        running: true
        onTriggered: root.now = Date.now()
    }

    // Projektfarben: Name -> Farbwert aus palette.json (projectAccents)
    FileView {
        id: colorFile
        path: Quickshell.shellDir + "/../theme/projects.json"
        watchChanges: true
        printErrors: false
        onFileChanged: reload()
        onLoaded: root._loadColors()
    }
    function _loadColors(): void {
        try {
            const c = {};
            for (const p of JSON.parse(colorFile.text()).projects || []) {
                // Farbname aus projectAccents oder eigene Farbe als #RRGGBB
                const hex = /^#[0-9a-f]{6}$/i.test(p.color || "") ? p.color : Theme.projectAccents[p.color];
                if (p.name && hex && !c[p.name])
                    c[p.name] = hex;
            }
            colors = c;
        } catch (e) {}
    }
    // Palette kommt asynchron bzw. ändert sich live
    Connections {
        target: Theme
        function onProjectAccentsChanged() { root._loadColors(); }
    }

    // Agent-Map öffnen/schließen
    function openMap(sid: string): void {
        mapSession = sid;
    }
    function closeMap(): void {
        mapSession = "";
    }
    // Projekt + Sitzung zu einer Sitzungs-ID (für die Map)
    function findSession(sid: string): var {
        for (const p of projects) {
            const s = p.sessions.find(x => x.id === sid);
            if (s)
                return { project: p, session: s };
        }
        return null;
    }

    // Tokens kurz: 940 · 88.8k · 1.24M
    function fmtTokens(n: real): string {
        if (!n)
            return "0";
        if (n < 1000)
            return String(Math.round(n));
        if (n < 1e6)
            return (n / 1000).toFixed(1) + "k";
        return (n / 1e6).toFixed(2) + "M";
    }
    // Laufzeit kurz: 42s · 3m 12s · 1h 32m
    function fmtDuration(ms: real): string {
        const s = Math.max(0, Math.round(ms / 1000));
        if (s < 60)
            return s + "s";
        if (s < 3600)
            return Math.floor(s / 60) + "m " + String(s % 60).padStart(2, "0") + "s";
        return Math.floor(s / 3600) + "h " + String(Math.floor(s % 3600 / 60)).padStart(2, "0") + "m";
    }
    // "claude-opus-5-5" -> "Opus 5.5"
    function prettyModel(m: string): string {
        const r = /^claude-([a-z]+)-(\d+)(?:-(\d+))?/.exec(m || "");
        if (!r)
            return m || "";
        return r[1].charAt(0).toUpperCase() + r[1].slice(1) + " " + r[2] + (r[3] && r[3].length < 3 ? "." + r[3] : "");
    }

    // Zeit seit: "just now", "12 min", "1 h 05"
    function ago(ms: real): string {
        if (!ms)
            return "";
        const min = Math.max(0, Math.floor((now - ms) / 60000));
        if (min < 1)
            return "just now";
        if (min < 60)
            return min + " min";
        return Math.floor(min / 60) + " h " + String(min % 60).padStart(2, "0");
    }

    IpcHandler {
        target: "claudehub"

        function status(): string {
            return JSON.stringify({ count: root.count, needs: root.needsCount, working: root.workingCount, agentsRunning: root.agentsRunning,
                projects: root.projects.map(p => ({ name: p.name, path: p.path, open: p.open, needs: p.needs, agentsRunning: p.agentsRunning,
                    sessions: p.sessions.map(s => ({ state: s.state, needsYou: s.needsYou, tasks: s.tasks ? { done: s.tasks.done, total: s.tasks.total } : null,
                        model: s.model, context: s.context, agentsTotal: s.agentsTotal,
                        agents: s.agents.map(a => ({ state: a.state, type: a.type, since: a.since, updated: a.updated, duration: a.duration, tokens: a.tokens })) })),
                    bgTasks: p.bgTasks.map(t => ({ id: t.id, state: t.state, needsYou: t.needsYou, steps: t.steps, started: t.started, finished: t.finished })),
                    info: p.info ? { branch: p.info.branch, changes: p.info.changes, roadmap: p.info.roadmap ? { done: p.info.roadmap.done, total: p.info.roadmap.total } : null } : null })) });
        }
        function refresh(): void {
            root.refresh();
            root.refreshAgents();
        }
        function closeMap(): void {
            root.closeMap();
        }
        // Klick auf „Claude task done“: Popout mit diesem Ergebnis öffnen
        function showTask(id: string): void {
            ClaudeTasks.showRequested(id);
        }
        // Popout öffnen, Projekt aufgeklappt ("" = wie beim Klick auf den Chip)
        function open(name: string): void {
            root.openRequested(name);
        }
    }
}
