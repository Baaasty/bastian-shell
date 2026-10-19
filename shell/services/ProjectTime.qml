pragma Singleton
import QtQuick
import Quickshell
import Quickshell.Io
import Quickshell.Wayland
import qs.config

// Zeit pro Projekt (Doku docs/PROJECTTIME.md): zählt automatisch, solange ein Projekt-Workspace der aktuelle
// Desktop ist (Name = Projekt aus projects/projects.json, GitInfo.projectFor) – nur wenn du da bist:
// nicht im Leerlauf (idleSec ohne Eingabe; die Leerlauf-Minuten davor werden wieder abgezogen), nicht gesperrt.
// Lücken > 90 s (Ruhezustand, Shell aus) zählen nicht.
// Speichert alle 15 s ~/.local/state/desktop/projecttime/YYYY-MM-DD.json (Gesamt + Zeitspannen, Unix-Sekunden),
// übersteht Shell-Neustarts. Auswertung: scripts/projecttime. Einstellungen (optional, live):
// ~/.config/desktop/projecttime.json  { "enabled": true, "idleSec": 300 }
// IPC "projecttime": open|hide|toggle (Wochen-Karte), status, today, week, flush.
Singleton {
    id: root

    readonly property string home: Quickshell.env("HOME")
    readonly property string dir: home + "/.local/state/desktop/projecttime"
    readonly property string script: Config.repo + "/scripts/projecttime"
    property var cfg: ({})
    readonly property bool enabled: cfg.enabled !== false
    readonly property int idleSec: cfg.idleSec >= 60 && cfg.idleSec <= 1800 ? Math.round(cfg.idleSec) : 300

    property string day: today()
    property var total: ({})          // Projekt-ID -> Sekunden heute
    property var spans: []            // [[id, start, ende]] heute
    property string current: ""       // Projekt, das seit lastTick zählt ("" = keins)
    property real lastTick: 0
    property bool ready: false
    property string lockText: ""
    readonly property bool locked: lockText.trim() === "locked"
    readonly property bool isIdle: idle.isIdle
    // Projekt des aktuellen Desktops (null = kein Projekt-Workspace)
    readonly property var deskProject: GitInfo.projectForId(Desktops.current)
    readonly property bool counting: ready && enabled && !!deskProject && !idle.isIdle && !locked

    // Wochen-Karte (shell/modules/recap/ProjectTimeCard.qml)
    property bool open: false

    // heute je Projekt, größte zuerst: [{ id, name, color, sec }]
    readonly property var todayList: Object.keys(total).map(id => ({ id: id, name: nameOf(id), color: colorOf(id), sec: total[id] }))
        .filter(p => p.sec >= 30).sort((a, b) => b.sec - a.sec)
    readonly property int todaySec: Object.keys(total).reduce((n, id) => n + total[id], 0)

    function today(): string {
        return Qt.formatDate(new Date(), "yyyy-MM-dd");
    }
    function nameOf(id: string): string {
        const e = Projects.settings[id];
        return e && e.name ? e.name : id;
    }
    // Projektfarbe: #RRGGBB oder Name aus palette.json projectAccents, sonst Holz
    function colorOf(id: string): color {
        const c = (Projects.settings[id] || {}).color || "";
        return /^#[0-9a-f]{6}$/i.test(c) ? c : (Theme.projectAccents[c] || Theme.woodLight);
    }
    // 4520 s -> "1 h 15 min", 600 -> "10 min"
    function fmt(sec: real): string {
        const m = Math.round(sec / 60);
        return m < 60 ? m + " min" : Math.floor(m / 60) + " h" + (m % 60 ? " " + String(m % 60).padStart(2, "0") + " min" : "");
    }
    // 4520 s -> "1:15"
    function hm(sec: real): string {
        const m = Math.round(sec / 60);
        return Math.floor(m / 60) + ":" + String(m % 60).padStart(2, "0");
    }

    // ---------- Zählen ----------
    function _add(id: string, from: real, to: real): void {
        const s = Math.round(from / 1000), e = Math.round(to / 1000);
        if (e <= s)
            return;
        const t = Object.assign({}, total);
        t[id] = (t[id] || 0) + (e - s);
        total = t;
        const sp = spans.slice();
        const last = sp.length ? sp[sp.length - 1] : null;
        if (last && last[0] === id && s - last[2] <= 2)
            sp[sp.length - 1] = [id, last[1], e];
        else
            sp.push([id, s, e]);
        spans = sp;
    }

    // Zeit seit dem letzten Aufruf dem bisherigen Projekt gutschreiben, dann neu bestimmen, was jetzt zählt.
    // Aufruf bei jedem Wechsel (Desktop, Leerlauf, Sperre) und alle 15 s.
    function account(): void {
        if (!ready)
            return;
        const now = Date.now();
        const prev = lastTick;
        lastTick = now;
        if (day !== today()) {
            // Mitternacht: alten Tag abschließen, neuen beginnen (die paar Sekunden davor zählen schon zum neuen)
            save();
            day = today();
            total = {};
            spans = [];
        }
        if (current && prev > 0 && now - prev < 90000)
            _add(current, prev, now);
        current = counting && deskProject ? deskProject.id : "";
    }

    // Leerlauf beginnt erst nach idleSec ohne Eingabe: diese Zeit war schon Leerlauf -> wieder abziehen
    function _trimIdle(): void {
        const cut = Math.round(Date.now() / 1000) - idleSec;
        const sp = spans.slice();
        const t = Object.assign({}, total);
        for (let i = sp.length - 1; i >= 0 && sp[i][2] > cut; i--) {
            const end = Math.max(sp[i][1], cut);
            t[sp[i][0]] = Math.max(0, (t[sp[i][0]] || 0) - (sp[i][2] - end));
            if (end <= sp[i][1])
                sp.splice(i, 1);
            else
                sp[i] = [sp[i][0], sp[i][1], end];
        }
        spans = sp;
        total = t;
    }

    onDeskProjectChanged: account()
    onLockedChanged: account()
    onEnabledChanged: account()

    IdleMonitor {
        id: idle
        timeout: root.idleSec
        respectInhibitors: true
        onIsIdleChanged: {
            root.account();
            if (isIdle) {
                root._trimIdle();
                root.save();
            }
        }
    }

    Timer {
        interval: 15000
        repeat: true
        running: root.ready
        onTriggered: {
            root.account();
            root.save();
        }
    }
    Component.onDestruction: {
        account();
        save();
    }

    // ---------- Dateien ----------
    Process {
        id: mkdir
        command: ["mkdir", "-p", root.dir]
        running: true
    }
    FileView {
        id: dayFile
        path: root.dir + "/" + root.day + ".json"
        blockLoading: true
        blockWrites: true
        printErrors: false
        onLoaded: {
            if (root.ready)
                return;
            try {
                const d = JSON.parse(text());
                root.total = d.total && typeof d.total === "object" ? d.total : {};
                root.spans = Array.isArray(d.spans) ? d.spans.filter(s => Array.isArray(s) && s.length === 3) : [];
                // Reload: die Sekunden seit dem letzten Speichern dem damaligen Projekt gutschreiben
                if (d.savedAt > 0 && Date.now() - d.savedAt < 90000 && typeof d.current === "string") {
                    root.lastTick = d.savedAt;
                    root.current = d.current;
                }
            } catch (e) {}
            root._begin();
        }
        onLoadFailed: if (!root.ready) root._begin()
    }
    function _begin(): void {
        ready = true;
        account();
    }
    function save(): void {
        if (!ready)
            return;
        const t = {};
        for (const id in total)
            if (total[id] > 0)
                t[id] = Math.round(total[id]);
        dayFile.setText(JSON.stringify({ day: day, total: t, spans: spans, current: current, savedAt: lastTick }));
    }

    FileView {
        path: root.home + "/.config/desktop/projecttime.json"
        blockLoading: true
        watchChanges: true
        printErrors: false
        onFileChanged: reload()
        onLoaded: {
            try {
                const d = JSON.parse(text());
                root.cfg = d && typeof d === "object" && !Array.isArray(d) ? d : ({});
            } catch (e) {
                console.warn("projecttime: projecttime.json is not valid JSON, using defaults");
                root.cfg = ({});
            }
        }
        onLoadFailed: root.cfg = ({})
    }

    // Sperrzustand (Lock.qml schreibt „locked“/„unlocked“)
    FileView {
        path: Quickshell.env("XDG_RUNTIME_DIR") + "/desktop-lock"
        blockLoading: true
        watchChanges: true
        printErrors: false
        onFileChanged: reload()
        onLoaded: root.lockText = text()
        onLoadFailed: root.lockText = ""
    }

    // ---------- Woche (für Kachel/Karte, gerechnet von scripts/projecttime) ----------
    // { from, to, today, total, days: [{ day, total, projects }], projects: [{ id, name, sec }] }
    property var week: null
    property int weekOffset: 0
    property bool _again: false
    function refreshWeek(): void {
        save();
        if (weekProc.running) {
            _again = true;
            return;
        }
        weekProc.command = [root.script, "week", "--json", "--offset", String(weekOffset)];
        weekProc.running = true;
    }
    function shiftWeek(dir: int): void {
        weekOffset = Math.min(0, weekOffset + dir);
        refreshWeek();
    }
    Process {
        id: weekProc
        stdout: StdioCollector {
            onStreamFinished: {
                try {
                    root.week = JSON.parse(text);
                } catch (e) {}
            }
        }
        onExited: if (root._again) {
            root._again = false;
            Qt.callLater(root.refreshWeek);
        }
    }

    IpcHandler {
        target: "projecttime"

        // Wochen-Karte zeigen („show“ kann qs ipc nicht aufrufen)
        function open(): void {
            root.weekOffset = 0;
            root.open = true;
        }
        function hide(): void {
            root.open = false;
        }
        function toggle(): void {
            if (!root.open)
                root.weekOffset = 0;
            root.open = !root.open;
        }
        function status(): string {
            return JSON.stringify({ enabled: root.enabled, counting: root.counting, project: root.deskProject ? root.deskProject.id : null,
                idle: idle.isIdle, idleSec: root.idleSec, locked: root.locked, todaySec: root.todaySec });
        }
        function today(): string {
            return JSON.stringify(root.todayList.map(p => ({ id: p.id, name: p.name, sec: p.sec })));
        }
        // Woche neu rechnen lassen; Antwort = letzter Stand (zum Prüfen ohne Karte)
        function week(): string {
            root.refreshWeek();
            return JSON.stringify(root.week);
        }
        // jetzt verbuchen und speichern (z. B. vor scripts/projecttime)
        function flush(): void {
            root.account();
            root.save();
        }
    }
}
