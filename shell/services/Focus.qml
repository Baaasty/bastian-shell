pragma Singleton
import QtQuick
import Quickshell
import Quickshell.Io
import Quickshell.Wayland

// Fokus: Pomodoro (zeitstempelbasiert, übersteht Neustarts), Jetzt-Aufgabe, Bildschirmzeit,
// Tagesziel und Pausen-Erinnerung. Zustand in ~/.local/state/desktop/focus.json
// Fokus ohne Zeit (openEnded): mode "focus" ohne Ende – gleiche Ruhe (Benachrichtigungen, Bar), kein Block-Ende, keine Pause.
// (Hyperfokus-Wecker: eigener Dienst services/Breaks.qml)
Singleton {
    id: root

    // Länge des laufenden Blocks (beim Start aus der gewählten Vorgabe gesetzt, wird gespeichert)
    property int blockMin: 25
    // Vorgaben im Leerlauf (Mausrad am Fokus-Chip): feste Längen + "bis zur nächsten vollen Stunde" (3 Stück)
    property int presetIdx: 1
    readonly property var presets: {
        const out = [15, 25, 45, 60, 90].map(m => ({ label: m + " min", min: m }));
        const d = new Date(now);
        d.setMinutes(0, 0, 0);
        for (let i = 1; out.length < 8 && i <= 4; i++) {
            const t = new Date(d.getTime() + i * 3600000);
            const min = Math.ceil((t.getTime() - now) / 60000);
            if (min >= 15)
                out.push({ label: "until " + Qt.formatTime(t, "HH:mm"), min: min, until: t.getTime() });
        }
        return out;
    }
    readonly property var preset: presets[Math.min(presetIdx, presets.length - 1)]
    readonly property int breakMin: 5
    readonly property int goalMin: 180
    readonly property int blocksPerRound: 4
    readonly property string home: Quickshell.env("HOME")

    property string task: ""
    property string mode: "idle"      // idle | focus | paused | break
    property real endsAt: 0
    property real pausedMs: 0
    property bool openEnded: false    // Fokus ohne Zeit: läuft, bis man ihn ausschaltet
    property real startedAt: 0        // Beginn des offenen Fokus (für „seit“)
    property int block: 1
    property string day: ""
    // Zeiten zählen in ms über Zeitstempel (übersteht Shell-Reloads), nach außen weiter ganze Minuten
    property real focusMs: 0
    property real screenMs: 0
    property real lastTick: 0         // letzter verbuchter Zeitpunkt
    readonly property int focusMin: Math.floor(focusMs / 60000)      // heute
    readonly property int screenMin: Math.floor(screenMs / 60000)    // heute, ohne Leerlauf
    property bool breakDue: false     // Pausen-Banner
    property real now: Date.now()

    readonly property bool active: mode === "focus"
    readonly property bool openOn: mode === "focus" && openEnded
    // offener Fokus: keine Restzeit, kein Fortschritt (Glutlinie bleibt leer), stattdessen elapsed
    readonly property real elapsed: openOn ? Math.max(0, now - startedAt) : 0
    readonly property real remaining: openOn ? 0
        : (mode === "focus" || mode === "break") ? Math.max(0, endsAt - now)
        : mode === "paused" ? pausedMs : preset.min * 60000   // Leerlauf: was „Start“ jetzt starten würde
    readonly property real progress: openOn ? 0
        : mode === "focus" ? 1 - remaining / (blockMin * 60000)
        : mode === "paused" ? 1 - pausedMs / (blockMin * 60000)
        : mode === "break" ? 1 - remaining / (breakMin * 60000) : 0

    function fmt(ms: real): string {
        const s = Math.ceil(ms / 1000);
        return Math.floor(s / 60) + ":" + String(s % 60).padStart(2, "0");
    }
    // offener Fokus im Chip: ruhig in Minuten („12 min“, „1 h 05“), keine Sekunden
    function sinceLabel(ms: real): string {
        return durLabel(Math.floor(ms / 60000));
    }
    function today(): string {
        return Qt.formatDate(new Date(), "yyyy-MM-dd");
    }

    // nächste/vorige Vorgabe (nur im Leerlauf, sonst stimmen Restzeit und Fortschritt nicht)
    function cyclePreset(dir: int): void {
        if (mode !== "idle")
            return;
        presetIdx = Math.max(0, Math.min(presets.length - 1, presetIdx + dir));
        save();
    }
    // Start: ohne Wert (Launcher, IPC, Kürzel, „Keep Going“) wie bisher mit der gewählten Vorgabe;
    // mit Minuten = eigene Länge. blockMin = Länge dieses Blocks (Restzeit/Fortschritt rechnen damit).
    function start(minutes): void {
        const m = Math.round(Number(minutes) || 0);
        if (m > 0)
            blockMin = Math.min(maxMin, m);
        else if (mode === "idle") {
            // „until HH:mm“: genau bis dahin. preset.min ist aufgerundet und hängt an now, das im Leerlauf nur
            // minütlich läuft – „until 15:00“ endete sonst bis zu ~1 min zu spät
            if (preset.until && startUntil(preset.until))
                return;
            blockMin = preset.min;
        }
        mode = "focus";
        openEnded = false;
        endsAt = Date.now() + blockMin * 60000;
        now = Date.now();   // im Leerlauf läuft now nur minütlich (siehe Sekundentakt)
        breakDue = false;
        save();
    }
    // bis zu einer Uhrzeit (Zeitstempel in ms): endet genau dann, blockMin aufgerundet für den Fortschritt
    function startUntil(ms: real): bool {
        const left = ms - Date.now();
        if (left < 60000 || left > maxMin * 60000)
            return false;
        blockMin = Math.ceil(left / 60000);
        mode = "focus";
        openEnded = false;
        endsAt = ms;
        now = Date.now();
        breakDue = false;
        save();
        return true;
    }

    // ---------- eigene Zeit: Eingabe verstehen ----------
    // Dauer: "40", "40m", "40 min", "1h30", "1h 30m", "1.5h", "1:30" (einstellige Stunde = Dauer)
    // Uhrzeit: "14:30", "9:30 uhr", "bis 14:30", "until 9", "um 14.30" (zweistellige Stunde oder Wort davor)
    // Ergebnis: { ok, kind: "dur"|"until", min, endsAt, label, key, error }
    readonly property int maxMin: 600
    function parseTime(input: string): var {
        let s = String(input ?? "").trim().toLowerCase().replace(/\s+/g, " ");
        if (s === "")
            return { ok: false, error: "" };
        let until = false;
        const pre = s.match(/^(until|till|til|bis|um|at|to|@)\s*/);
        if (pre) {
            until = true;
            s = s.slice(pre[0].length).trim();
        }
        if (/\s*uhr$/.test(s)) {
            until = true;
            s = s.replace(/\s*uhr$/, "");
        }
        // Uhrzeit: H:MM / HH:MM / HH.MM, mit Wort davor auch nur "14"
        let t = s.match(/^(\d{1,2})(?:[:.](\d{2}))?$/);
        if (t && (until || (t[2] !== undefined && t[1].length === 2 && s.includes(":")))) {
            const h = parseInt(t[1]), mi = t[2] !== undefined ? parseInt(t[2]) : 0;
            if (h > 23 || mi > 59)
                return { ok: false, error: "That's not a time of day" };
            const d = new Date();
            d.setHours(h, mi, 0, 0);
            const hm = Qt.formatTime(d, "HH:mm");
            const left = d.getTime() - Date.now();
            if (left <= 0)
                return { ok: false, error: hm + " has already passed today" };
            if (left < 60000)
                return { ok: false, error: hm + " is less than a minute away" };
            if (left > maxMin * 60000)
                return { ok: false, error: hm + " is more than " + (maxMin / 60) + " hours away" };
            return { ok: true, kind: "until", min: Math.ceil(left / 60000), endsAt: d.getTime(), label: "until " + hm, key: "until " + hm };
        }
        if (until)
            return { ok: false, error: "Try a time like 14:30" };
        let min = -1;
        // 1:30 = 1 h 30 min
        t = s.match(/^(\d{1,2}):(\d{2})$/);
        if (t)
            min = parseInt(t[1]) * 60 + parseInt(t[2]);
        // 1h30 / 1 h 30 min / 1.5h / 2h / 40m / 40
        t = min < 0 ? s.match(/^(?:(\d+(?:[.,]\d+)?) ?(?:h|hr|hrs|hours?|std|stunden?))? ?(?:(\d+) ?(?:m|min|mins|minutes?|minuten?)?)?$/) : null;
        if (t && (t[1] !== undefined || t[2] !== undefined))
            min = Math.round(parseFloat((t[1] ?? "0").replace(",", ".")) * 60 + parseInt(t[2] ?? "0"));
        if (min < 0)
            return { ok: false, error: "Try 40, 1h30, 1:30 or until 14:30" };
        if (min < 1)
            return { ok: false, error: "At least 1 minute" };
        if (min > maxMin)
            return { ok: false, error: "At most " + (maxMin / 60) + " hours" };
        return { ok: true, kind: "dur", min: min, endsAt: Date.now() + min * 60000, label: durLabel(min), key: durLabel(min) };
    }
    function durLabel(min: int): string {
        if (min < 60)
            return min + " min";
        return Math.floor(min / 60) + " h" + (min % 60 ? " " + String(min % 60).padStart(2, "0") : "");
    }
    // Eingabe starten; gibt "" zurück oder den Hinweis, warum nicht
    function startText(input: string): string {
        const r = parseTime(input);
        if (!r.ok)
            return r.error || "Enter a duration or a time";
        if (r.kind === "until") {
            if (!startUntil(r.endsAt))
                return "That's too far away";
        } else {
            start(r.min);
        }
        remember(r);
        return "";
    }

    // zuletzt benutzte eigene Werte (max. 3, ohne die festen Vorgaben) als Schnellwahl-Chips.
    // Gespeichert wird der Text ("40 min", "1 h 30", "until 14:30"); vergangene Uhrzeiten blendet recentChoices aus.
    property var recent: []
    readonly property var recentChoices: {
        void now;   // „until“ verfällt mit der Zeit
        return recent.map(k => Object.assign(parseTime(k), { text: k })).filter(r => r.ok);
    }
    function remember(r: var): void {
        if (r.kind === "dur" && [15, 25, 45, 60, 90].includes(r.min))
            return;
        recent = [r.key].concat(recent.filter(k => k !== r.key)).slice(0, 3);
        save();
    }
    function forget(key: string): void {
        recent = recent.filter(k => k !== key);
        save();
    }

    function stop(): void {
        mode = "idle";
        openEnded = false;
        breakDue = false;
        save();
    }
    // Fokus ohne Zeit: an bis zum Ausschalten. Läuft schon ein Block, wird er offen (Zeit „seit“ ab jetzt).
    function startOpen(): void {
        if (openOn)
            return;
        openEnded = true;
        startedAt = Date.now();
        mode = "focus";
        now = Date.now();
        breakDue = false;
        save();
    }
    function setOpen(on: bool): void {
        if (on)
            startOpen();
        else if (openOn)
            stop();
    }
    // ohne Zeit gibt es nichts anzuhalten: Pause = aus (Chip/Popout schalten direkt aus)
    function pause(): void {
        if (mode !== "focus" || openEnded)
            return;
        pausedMs = endsAt - Date.now();
        mode = "paused";
        save();
    }
    function resume(): void {
        if (mode !== "paused")
            return;
        endsAt = Date.now() + pausedMs;
        now = Date.now();
        mode = "focus";
        save();
    }
    // Meta+F: starten bzw. beenden
    function toggle(): void {
        if (mode === "idle")
            start();
        else
            stop();
    }
    function startBreak(): void {
        mode = "break";
        openEnded = false;
        endsAt = Date.now() + breakMin * 60000;
        now = Date.now();
        breakDue = false;
        save();
    }
    function setTask(text: string): void {
        task = text.trim();
        if (!ready)
            pendingTask = task;   // Todos setzt die Aufgabe schon vor dem Laden der Datei
        save();
        writeLockInfo();
    }

    // Sekundentakt: Ablauf von Block/Pause
    Timer {
        interval: 1000
        repeat: true
        running: true
        onTriggered: {
            // im Leerlauf hängen nur die „until HH:mm“-Vorgaben an now: dann reicht ein Update pro Minute,
            // statt jede Sekunde presets/preset (und den Fokus-Chip) neu zu bauen
            const t = Date.now();
            if (root.mode !== "idle" || Math.floor(t / 60000) !== Math.floor(root.now / 60000))
                root.now = t;
            if (root.mode === "focus" && !root.openEnded && root.now >= root.endsAt) {
                root.mode = "idle";
                root.block = root.block % root.blocksPerRound + 1;
                root.breakDue = true;
                root.save();
            } else if (root.mode === "break" && root.now >= root.endsAt) {
                root.mode = "idle";
                root.save();
            }
        }
    }

    // Bildschirmzeit, Fokus-Minuten: alle 15 s die echte Zeit seit dem letzten Takt gutschreiben.
    // Früher +1 pro 60-s-Timer: jeder Shell-Reload (beim Basteln alle paar Minuten) setzte den Timer zurück,
    // daher stand da tagelang „0 h 0 min“.
    function account(): void {
        if (!ready)
            return;
        const now = Date.now();
        // Lücken > 90 s (Ruhezustand, Shell war aus) nicht zählen
        const dt = lastTick > 0 && now - lastTick < 90000 ? Math.max(0, now - lastTick) : 0;
        lastTick = now;
        if (day !== today()) {
            day = today();
            focusMs = 0;
            screenMs = 0;
        }
        if (dt > 0 && !idle.isIdle) {
            screenMs += dt;
            if (mode === "focus")
                focusMs += dt;
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

    // 5 min ohne Eingabe = Leerlauf (zählt nicht als Bildschirmzeit)
    IdleMonitor {
        id: idle
        timeout: 300
        respectInhibitors: true
        onIsIdleChanged: root.account()
    }

    IpcHandler {
        target: "focus"

        function toggle(): void {
            root.toggle();
        }
        // eigene Zeit, z. B. qs ipc call focus startFor "1h30" oder "until 14:30"; Antwort: "" oder Hinweis
        function startFor(text: string): string {
            return root.startText(text);
        }
        // Fokus ohne Zeit: qs ipc call focus openEnded on|off|toggle
        function openEnded(state: string): string {
            const s = String(state).toLowerCase();
            if (s !== "on" && s !== "off" && s !== "toggle")
                return "use on, off or toggle";
            root.setOpen(s === "toggle" ? !root.openOn : s === "on");
            return root.openOn ? "on" : "off";
        }
        function task(text: string): void {
            root.setTask(text);
        }
        function status(): string {
            return JSON.stringify({ mode: root.mode, openEnded: root.openOn, elapsed: root.fmt(root.elapsed), remaining: root.fmt(root.remaining), task: root.task, focusMin: root.focusMin, screenMin: root.screenMin, idle: idle.isIdle });
        }
    }

    FileView {
        id: stateFile
        path: root.home + "/.local/state/desktop/focus.json"
        blockLoading: true
        blockWrites: true
        printErrors: false
        onLoaded: {
            if (root.ready)
                return;
            try {
                const s = JSON.parse(text());
                root.task = s.task ?? "";
                root.mode = s.mode ?? "idle";
                root.blockMin = s.blockMin ?? 25;
                root.presetIdx = s.presetIdx ?? 1;
                root.recent = Array.isArray(s.recent) ? s.recent.filter(k => typeof k === "string").slice(0, 3) : [];
                root.endsAt = s.endsAt ?? 0;
                root.pausedMs = s.pausedMs ?? 0;
                root.openEnded = s.openEnded === true && root.mode === "focus";
                root.startedAt = s.startedAt ?? 0;
                root.block = s.block ?? 1;
                root.day = s.day ?? "";
                const same = s.day === root.today();
                // ms-Felder neu; ältere Dateien hatten nur Minuten
                root.focusMs = same ? (s.focusMs ?? (s.focusMin ?? 0) * 60000) : 0;
                root.screenMs = same ? (s.screenMs ?? (s.screenMin ?? 0) * 60000) : 0;
                // Reload: die Sekunden seit dem letzten Speichern weiterzählen
                const fresh = same && s.savedAt > 0 && Date.now() - s.savedAt < 90000;
                root.lastTick = fresh ? s.savedAt : 0;
            } catch (e) {}
            root.begin();
        }
        onLoadFailed: if (!root.ready) root.begin()
    }

    // Erst nach dem Laden zählen und speichern: FileView lädt asynchron, ein früheres save()
    // (z. B. setTask beim Start) hat sonst die Bildschirmzeit des Tages mit 0 überschrieben.
    property bool ready: false
    property var pendingTask: null
    function begin(): void {
        if (pendingTask !== null)
            task = pendingTask;
        if (day !== today())
            day = today();
        ready = true;
        account();
        save();
        writeLockInfo();
    }

    function save(): void {
        if (!ready)
            return;
        stateFile.setText(JSON.stringify({ task: task, mode: mode, blockMin: blockMin, presetIdx: presetIdx, recent: recent, endsAt: endsAt, pausedMs: pausedMs, openEnded: openEnded, startedAt: startedAt, block: block, day: day,
            focusMin: focusMin, screenMin: screenMin, focusMs: Math.round(focusMs), screenMs: Math.round(screenMs),
            savedAt: lastTick }, null, 1));
    }

    // Der Lockscreen kann keine Dateien lesen, lädt aber QML: Aufgabe als kleines QML-Objekt
    FileView {
        id: lockInfo
        path: root.home + "/.local/share/plasma/shells/de.bastian.desktop/contents/lockscreen/DesktopLockInfo.qml"
        printErrors: false
    }
    function writeLockInfo(): void {
        lockInfo.setText("import QtQuick\nQtObject { property string task: " + JSON.stringify(task) + " }\n");
    }
}
