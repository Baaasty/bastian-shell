pragma Singleton
import QtQuick
import Quickshell
import Quickshell.Io
import Quickshell.Wayland
import "timewin.js" as TW

// Hyperfokus-Wecker (Doku docs/BREAKS.md): nach afterMin Minuten am Stück am PC eine ruhige Karte unter der Bar
// (shell/modules/breaks/BreakCard.qml). Pause = breakMin Minuten ohne Maus/Tastatur (IdleMonitor, auch während ein Video
// Idle-Inhibit hält) oder Fokus-Pause.
// Schweigt bei Vollbild, Spiel, Discord-Call, laufendem Fokus-Block, Sperre und in den Szenen aus silentScenes
// (game, evening) – ist der Hinweis fällig, kommt er, sobald nichts mehr dagegen spricht.
// Einstellungen: config/breaks.json, eigene Werte in ~/.config/desktop/breaks.json (beide live gelesen).
// Zustand: ~/.local/state/desktop/breaks.json (übersteht Shell-Reloads). IPC: breaks status|snooze|snoozeFor|reset|test|hide|off.
Singleton {
    id: root

    readonly property string home: Quickshell.env("HOME")

    // ---------- Einstellungen ----------
    property var base: ({})
    property var user: ({})
    readonly property var cfg: Object.assign({}, base, user)
    function num(v, lo: real, hi: real, def: real): real {
        return typeof v === "number" && v >= lo && v <= hi ? v : def;
    }
    readonly property bool enabled: cfg.enabled !== false
    readonly property int afterMin: Math.round(num(cfg.afterMin, 5, 600, 90))
    readonly property int breakMin: Math.round(num(cfg.breakMin, 1, 60, 5))
    readonly property int snoozeMin: Math.round(num(cfg.snoozeMin, 1, 120, 10))
    // Standard aus: Video/Idle-Inhibit ohne Eingabe zählt als Pause (nur Maus/Tastatur zählen als Arbeit)
    readonly property bool respectInhibitors: cfg.respectInhibitors === true
    readonly property var silentScenes: Array.isArray(cfg.silentScenes) ? cfg.silentScenes.filter(s => typeof s === "string") : ["game", "evening"]
    readonly property var messages: {
        const m = Array.isArray(cfg.messages) ? cfg.messages.filter(s => typeof s === "string" && s.trim() !== "") : [];
        return m.length ? m : ["Water, stretch, look away."];
    }

    // ---------- Zustand ----------
    property real since: 0          // Beginn der Strecke am Stück (0 = gerade Pause/Leerlauf)
    property real lastSeen: 0       // letzter Takt (Lücken > breakMin = Ruhezustand/Shell aus = Pause)
    property real snoozeUntil: 0
    property string offDay: ""      // „Not today“: dieser Tag ist still
    property real now: Date.now()
    property bool testing: false    // IPC test: Karte sofort, ohne Bedingungen
    property string message: messages[0]

    readonly property real activeMs: since > 0 ? Math.max(0, now - since) : 0
    readonly property int activeMin: Math.floor(activeMs / 60000)
    readonly property bool offToday: offDay === TW.dayKey(new Date(now))
    readonly property bool snoozed: snoozeUntil > now
    // noch so viele Minuten bis zum Hinweis (für Tooltip/Status)
    readonly property int leftMin: Math.max(0, Math.ceil(((snoozed ? snoozeUntil - now : 0) + Math.max(0, afterMin * 60000 - activeMs)) / 60000))
    readonly property real progress: Math.min(1, activeMs / (afterMin * 60000))
    readonly property bool due: enabled && ready && since > 0 && activeMs >= afterMin * 60000 && !snoozed && !offToday

    property bool locked: false
    // warum er gerade schweigt ("" = darf)
    readonly property string silentWhy: {
        if (Windows.game)
            return "game";
        for (const s of silentScenes)
            if (Scenes.isOn(s))
                return "scene " + s;
        if (Windows.fullscreen)
            return "fullscreen";
        if (Discord.inVoice)
            return "call";
        if (Focus.mode === "focus")
            return "focus";
        if (locked)
            return "locked";
        return "";
    }
    readonly property bool shown: testing || (due && silentWhy === "")

    onShownChanged: if (shown) message = messages[Math.floor(Math.random() * messages.length)]

    function fmt(min: int): string {
        return min < 60 ? min + " min" : Math.floor(min / 60) + " h" + (min % 60 ? " " + min % 60 + " min" : "");
    }

    // ---------- Aktionen ----------
    // „Taking a break“: Strecke beginnt neu (wer wirklich weggeht, setzt sie nach breakMin ohnehin zurück)
    function takeBreak(): void {
        since = Date.now();
        snoozeUntil = 0;
        testing = false;
        save();
    }
    function snooze(min): void {
        const m = Math.round(Number(min) || snoozeMin);
        snoozeUntil = Date.now() + Math.max(1, m) * 60000;
        now = Date.now();
        testing = false;
        save();
    }
    function notToday(): void {
        offDay = TW.dayKey(new Date());
        testing = false;
        save();
    }
    // alles zurück: Strecke, Snooze, „Not today“
    function reset(): void {
        since = Date.now();
        snoozeUntil = 0;
        offDay = "";
        testing = false;
        now = Date.now();
        save();
    }

    // Pause aus dem Fokus-Timer zählt
    Connections {
        target: Focus
        function onModeChanged() {
            if (Focus.mode === "break" && root.ready)
                root.takeBreak();
        }
    }

    // breakMin ohne Eingabe = Pause: Strecke weg; erste Eingabe danach startet eine neue
    IdleMonitor {
        id: idle
        enabled: root.enabled
        timeout: root.breakMin * 60
        respectInhibitors: root.respectInhibitors
        onIsIdleChanged: {
            if (!root.ready)
                return;
            root.now = Date.now();
            root.since = isIdle ? 0 : Date.now();
            if (isIdle) {
                root.snoozeUntil = 0;
                root.testing = false;
            }
            root.save();
        }
    }

    // Takt: Zeit weiter, Lücken (Ruhezustand, Shell aus) als Pause werten, speichern
    Timer {
        interval: 30000
        repeat: true
        running: root.ready && root.enabled
        onTriggered: root.tick()
    }
    function tick(): void {
        const t = Date.now();
        if (lastSeen > 0 && t - lastSeen > breakMin * 60000)
            since = idle.isIdle ? 0 : t;
        else if (since === 0 && !idle.isIdle)
            since = t;
        lastSeen = t;
        now = t;
        save();
    }

    FileView {
        path: Quickshell.env("XDG_RUNTIME_DIR") + "/desktop-lock"
        blockLoading: true
        watchChanges: true
        printErrors: false
        onFileChanged: reload()
        onLoaded: root.locked = text().trim() === "locked"
        onLoadFailed: root.locked = false
    }

    // ---------- Dateien ----------
    function _parse(t, which) {
        try {
            const d = JSON.parse(t);
            return d && typeof d === "object" && !Array.isArray(d) ? d : ({});
        } catch (e) {
            console.warn("breaks: " + which + " is not valid JSON, ignoring it");
            return ({});
        }
    }
    FileView {
        path: Quickshell.shellDir + "/../config/breaks.json"
        blockLoading: true
        watchChanges: true
        printErrors: false
        onFileChanged: reload()
        onLoaded: root.base = root._parse(text(), "config/breaks.json")
        onLoadFailed: root.base = ({})
    }
    FileView {
        path: root.home + "/.config/desktop/breaks.json"
        blockLoading: true
        watchChanges: true
        printErrors: false
        onFileChanged: reload()
        onLoaded: root.user = root._parse(text(), "~/.config/desktop/breaks.json")
        onLoadFailed: root.user = ({})
    }

    property bool ready: false
    FileView {
        id: stateFile
        path: root.home + "/.local/state/desktop/breaks.json"
        blockLoading: true
        blockWrites: true
        printErrors: false
        onLoaded: {
            if (root.ready)
                return;
            try {
                const s = JSON.parse(text());
                const t = Date.now();
                // Reload: Strecke weiterzählen, nach langer Lücke (Ruhezustand, Shell aus) neu beginnen
                const fresh = s.lastSeen > 0 && t - s.lastSeen < root.breakMin * 60000;
                root.since = fresh && s.since > 0 ? s.since : t;
                root.snoozeUntil = s.snoozeUntil > t ? s.snoozeUntil : 0;
                root.offDay = typeof s.offDay === "string" ? s.offDay : "";
            } catch (e) {}
            root.begin();
        }
        onLoadFailed: if (!root.ready) root.begin()
    }
    function begin(): void {
        if (since === 0)
            since = Date.now();
        lastSeen = Date.now();
        now = Date.now();
        ready = true;
        save();
    }
    function save(): void {
        if (!ready)
            return;
        stateFile.setText(JSON.stringify({ since: Math.round(since), lastSeen: Math.round(lastSeen), snoozeUntil: Math.round(snoozeUntil), offDay: offDay }));
    }

    // qs ipc --any-display -p ~/Workspace/bastian-shell/shell call breaks status
    IpcHandler {
        target: "breaks"

        function status(): string {
            root.now = Date.now();
            return JSON.stringify({ enabled: root.enabled, activeMin: root.activeMin, afterMin: root.afterMin, leftMin: root.leftMin, due: root.due,
                shown: root.shown, silent: root.silentWhy, snoozedMin: root.snoozed ? Math.ceil((root.snoozeUntil - root.now) / 60000) : 0,
                offToday: root.offToday, idle: idle.isIdle, breakMin: root.breakMin });
        }
        function snooze(): void {
            root.snooze(root.snoozeMin);
        }
        function snoozeFor(min: int): void {
            root.snooze(min);
        }
        function reset(): void {
            root.reset();
        }
        function test(): void {
            root.testing = true;
        }
        function hide(): void {
            root.testing = false;
        }
        function off(): void {
            root.notToday();
        }
    }
}
