pragma Singleton
import QtQuick
import Quickshell
import Quickshell.Io

// Dev heute: Claude-Code-Verbrauch (scripts/claude-usage), Code (git log über alle Projekte).
// Alles alle 5 min, Commits der Woche alle 10 min. GitHub-Abruf gibt es nicht mehr (Commits zeigt die Coding-Kachel).
Singleton {
    id: root

    // Claude
    property real tokens: 0
    property real cacheRead: 0
    property real input: 0
    property real output: 0
    property real cacheCreate: 0
    // Wasser (grobe Schätzung, von Hand anpassbar): Tokens nach Rechenaufwand gewichtet wie Anthropics Preise
    // (Output 1, Input 1/5, Cache schreiben 1,25/5, Cache lesen 0,1/5) -> Energie 0,6 mWh pro gewichtetem Token
    // (Epoch AI 2025: ~0,3 Wh pro Antwort mit ~500 Tokens) -> 3,7 L Wasser pro kWh (Li et al. 2023 „Making AI Less Thirsty“:
    // Kühlung im Rechenzentrum + Stromerzeugung, US-Schnitt). Anzeige: Coding-Kachel (DevTile.qml).
    readonly property real whPerToken: 0.0006
    readonly property real litersPerKwh: 3.7
    readonly property real waterLiters: litersOf(root)
    // Liter für einen Tag/Zähler mit input, output, cacheCreate, cacheRead
    function litersOf(c: var): real {
        const weighted = (c.output || 0) + ((c.input || 0) + 1.25 * (c.cacheCreate || 0) + 0.1 * (c.cacheRead || 0)) / 5;
        return weighted * whPerToken / 1000 * litersPerKwh;
    }
    property int requests: 0
    property bool windowActive: false
    property real windowStart: 0
    property real windowReset: 0
    property real windowTokens: 0
    property bool usageOk: false
    // Sitzungen heute (Stats-Kachel)
    property int sessions: 0
    property int agents: 0
    property real activeMs: 0
    property string claudeProject: ""
    // Claude je Tag der letzten 7 Tage: { "YYYY-MM-DD": { tokens, input, output, cacheCreate, cacheRead, requests } }
    property var claudeDays: ({})
    // Code
    property int added: 0
    property int removed: 0
    property int commits: 0
    property bool codeOk: false
    property string topRepo: ""     // aktivstes Repo heute (meiste Commits)
    property int topRepoCommits: 0
    // Woche: 7 Tage, ältester zuerst, letzter = heute; je { date: "YYYY-MM-DD", label: "Mo", count, added, removed, claude }
    // (claude = Tageszähler aus claudeDays oder null)
    property var weekBase: []
    // heute immer mit dem frischeren Tageszähler; Claude je Tag dazu
    readonly property var week: weekBase.map((d, i) => Object.assign({}, d, { claude: claudeDays[d.date] || null },
        i === weekBase.length - 1 && d.date === dayKey(new Date(now)) && codeOk ? { count: commits, added: added, removed: removed } : {}))
    readonly property int weekMax: week.reduce((m, d) => Math.max(m, d.count), 0)
    readonly property int weekLinesMax: week.reduce((m, d) => Math.max(m, d.added + d.removed), 0)
    readonly property int weekCommits: week.reduce((s, d) => s + d.count, 0)
    readonly property int weekAdded: week.reduce((s, d) => s + d.added, 0)
    readonly property int weekRemoved: week.reduce((s, d) => s + d.removed, 0)
    property real now: Date.now()
    readonly property real windowProgress: windowActive ? Math.min(1, Math.max(0, (now - windowStart) / (windowReset - windowStart))) : 0
    readonly property real resetIn: windowActive ? Math.max(0, windowReset - now) : 0

    // 412000 -> "412k", 1850000 -> "1,9 M"
    function fmtTokens(n: real): string {
        if (n >= 1e6)
            return (n / 1e6).toFixed(1) + " M";
        if (n >= 1e3)
            return Math.round(n / 1e3) + "k";
        return String(Math.round(n));
    }
    // Liter -> "0.4 L", "12 L", "1.3 m³"
    function fmtLiters(l: real): string {
        if (l >= 1000)
            return (l / 1000).toFixed(1) + " m³";
        if (l >= 10)
            return Math.round(l) + " L";
        return l.toFixed(1) + " L";
    }
    // ms -> "2 h 10" bzw. "45 min"
    function fmtDur(ms: real): string {
        const m = Math.ceil(ms / 60000);
        return m >= 60 ? Math.floor(m / 60) + " h " + String(m % 60).padStart(2, "0") : m + " min";
    }

    // Date -> "2026-10-18" (lokale Zeit)
    function dayKey(d: var): string {
        return d.getFullYear() + "-" + String(d.getMonth() + 1).padStart(2, "0") + "-" + String(d.getDate()).padStart(2, "0");
    }

    function refreshWeek(): void {
        if (weekProc.running || !Projects.list.length)
            return;
        const start = new Date();
        start.setHours(0, 0, 0, 0);
        start.setDate(start.getDate() - 6);
        weekProc.since = root.dayKey(start);
        weekProc.command = ["sh", "-c", weekProc.script, "sh", weekProc.since + " 00:00"].concat(Projects.list.map(p => p.path));
        weekProc.running = true;
    }

    function refresh(): void {
        if (!usage.running)
            usage.running = true;
        if (!code.running && Projects.list.length) {
            code.command = ["sh", "-c", code.script, "sh"].concat(Projects.list.map(p => p.path));
            code.running = true;
        }
    }

    Timer {
        interval: 300000
        repeat: true
        running: true
        triggeredOnStart: true
        onTriggered: root.refresh()
    }
    Timer {
        interval: 600000
        repeat: true
        running: true
        triggeredOnStart: true
        onTriggered: root.refreshWeek()
    }
    // Restzeit des Fensters weiterzählen
    Timer {
        interval: 30000
        repeat: true
        running: root.windowActive
        onTriggered: root.now = Date.now()
    }
    // erste Projektliste abwarten
    Connections {
        target: Projects
        function onListChanged() {
            if (!root.codeOk)
                root.refresh();
            if (!root.weekBase.length)
                root.refreshWeek();
        }
    }

    Process {
        id: usage
        command: [Quickshell.shellDir + "/../scripts/claude-usage"]
        stdout: StdioCollector {
            onStreamFinished: {
                try {
                    const d = JSON.parse(text);
                    root.tokens = d.today.tokens;
                    root.cacheRead = d.today.cacheRead;
                    root.input = d.today.input || 0;
                    root.output = d.today.output || 0;
                    root.cacheCreate = d.today.cacheCreate || 0;
                    root.requests = d.today.requests;
                    root.sessions = d.today.sessions || 0;
                    root.agents = d.today.agents || 0;
                    root.activeMs = d.today.activeMs || 0;
                    root.claudeProject = d.today.topProject || "";
                    root.claudeDays = d.days || {};
                    root.windowActive = d.window.active;
                    root.windowStart = d.window.start;
                    root.windowReset = d.window.reset;
                    root.windowTokens = d.window.tokens;
                    root.now = Date.now();
                    root.usageOk = true;
                } catch (e) {
                    root.usageOk = false;
                }
            }
        }
    }

    Process {
        id: code
        // eigene Commits seit Mitternacht (lokale Branches), Ausgabe: "#<pfad>" je Repo, "@" je Commit, numstat-Zeilen
        readonly property string script: "email=$(git config --global user.email); [ -n \"$email\" ] || exit 0; "
            + "for r in \"$@\"; do printf '#%s\\n' \"$r\"; git -C \"$r\" log --branches --no-merges --since=midnight --author=\"$email\" --numstat --pretty=tformat:@ 2>/dev/null; done"
        stdout: StdioCollector {
            onStreamFinished: {
                let a = 0, r = 0, c = 0, repo = "";
                const per = {};
                for (const line of text.split("\n")) {
                    if (line.startsWith("#")) {
                        repo = line.slice(1).split("/").pop();
                        continue;
                    }
                    if (line === "@") {
                        c++;
                        per[repo] = (per[repo] || 0) + 1;
                        continue;
                    }
                    const m = /^(\d+)\t(\d+)\t/.exec(line);
                    if (m) {
                        a += parseInt(m[1]);
                        r += parseInt(m[2]);
                    }
                }
                root.added = a;
                root.removed = r;
                root.commits = c;
                let top = "", topN = 0;
                for (const k in per) {
                    if (per[k] > topN) {
                        top = k;
                        topN = per[k];
                    }
                }
                root.topRepo = top;
                root.topRepoCommits = topN;
                root.now = Date.now();
                root.codeOk = true;
                // Tageswechsel: Woche gleich mitziehen
                const wb = root.weekBase;
                if (wb.length && wb[wb.length - 1].date !== root.dayKey(new Date()))
                    root.refreshWeek();
            }
        }
    }

    Process {
        id: weekProc
        property string since
        // eigene Commits der letzten 7 Tage, Ausgabe: "@<datum>" (lokal) je Commit, numstat-Zeilen
        readonly property string script: "email=$(git config --global user.email); [ -n \"$email\" ] || exit 0; since=$1; shift; "
            + "for r in \"$@\"; do git -C \"$r\" log --branches --no-merges --since=\"$since\" --author=\"$email\" --numstat --pretty=tformat:@%cd --date=format-local:%Y-%m-%d 2>/dev/null; done"
        stdout: StdioCollector {
            onStreamFinished: {
                const per = {};
                let cur = null;
                for (const line of text.split("\n")) {
                    if (/^@\d{4}-\d\d-\d\d$/.test(line)) {
                        const key = line.slice(1);
                        cur = per[key] || (per[key] = { count: 0, added: 0, removed: 0 });
                        cur.count++;
                        continue;
                    }
                    const m = /^(\d+)\t(\d+)\t/.exec(line);
                    if (m && cur) {
                        cur.added += parseInt(m[1]);
                        cur.removed += parseInt(m[2]);
                    }
                }
                const names = ["Sun", "Mon", "Tue", "Wed", "Thu", "Fri", "Sat"];
                const days = [];
                const d = new Date();
                d.setHours(12, 0, 0, 0);
                d.setDate(d.getDate() - 6);
                for (let i = 0; i < 7; i++) {
                    const key = root.dayKey(d);
                    const p = per[key] || { count: 0, added: 0, removed: 0 };
                    days.push({ date: key, label: names[d.getDay()], count: p.count, added: p.added, removed: p.removed });
                    d.setDate(d.getDate() + 1);
                }
                root.weekBase = days;
                root.now = Date.now();
            }
        }
    }

    IpcHandler {
        target: "devstats"

        function status(): string {
            return JSON.stringify({
                tokens: root.tokens, requests: root.requests, cacheRead: root.cacheRead,
                sessions: root.sessions, agents: root.agents, activeMs: root.activeMs, claudeProject: root.claudeProject,
                window: { active: root.windowActive, progress: root.windowProgress.toFixed(2), resetIn: root.fmtDur(root.resetIn), tokens: root.windowTokens },
                code: { added: root.added, removed: root.removed, commits: root.commits, topRepo: root.topRepo, topRepoCommits: root.topRepoCommits },
                week: root.week.map(d => d.label + " " + d.count + " +" + d.added + " −" + d.removed).join(" · ")
            });
        }
        function refresh(): void {
            root.refresh();
            root.refreshWeek();
        }
    }
}
