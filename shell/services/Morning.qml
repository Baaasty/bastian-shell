pragma Singleton
import QtQuick
import Quickshell
import Quickshell.Io
import Quickshell.Wayland
import "timewin.js" as TW

// Morgen-Übersicht: einmal pro Kalendertag eine ruhige Karte (shell/modules/morning/MorningCard.qml) mit Termine, Mail,
// Wetter, To-dos, Inbox. Wann sie kommt, steht von Hand pflegbar in ~/.config/desktop/morning.json (Doku docs/knowledge/shell-features.md):
//   { "enabled": true, "from": "05:00", "to": "11:00", "delaySec": 30, "closeSec": 20 }
// Auslöser: alle 15 s prüfen. Sie kommt, sobald (1) die Uhrzeit im Fenster liegt, (2) heute noch keine war,
// (3) die Shell seit delaySec läuft, (4) du da bist (nicht gesperrt, nicht im Leerlauf, kein Spiel/Vollbild, kein Nicht stören/Fokus),
// (5) Termine/Mail/Wetter geladen sind (oder 15 s Geduld um sind). Das deckt Login, Aufwachen und Entsperren ab.
// Zustand: ~/.local/state/desktop/morning.json ({ "day": "2026-10-18" }). IPC: morning open|hide|toggle|status|reset.
Singleton {
    id: root

    readonly property string home: Quickshell.env("HOME")
    property var cfg: ({})

    readonly property bool enabled: cfg.enabled !== false
    readonly property string from: typeof cfg.from === "string" && TW.hm(cfg.from) >= 0 ? cfg.from : "05:00"
    readonly property string to: typeof cfg.to === "string" && TW.hm(cfg.to) >= 0 ? cfg.to : "11:00"
    readonly property int delaySec: cfg.delaySec >= 0 && cfg.delaySec <= 600 ? Math.round(cfg.delaySec) : 30
    readonly property int closeSec: cfg.closeSec >= 5 && cfg.closeSec <= 300 ? Math.round(cfg.closeSec) : 20

    property bool open: false         // Karte zeigen
    property string lastDay: ""       // Tag, an dem sie zuletzt kam
    readonly property bool locked: lockText.trim() === "locked"
    property string lockText: ""
    property real startedAt: Date.now()
    property real eligibleSince: 0

    function inWindow(date): bool {
        return TW.inWindow({ from: from, to: to }, date);
    }

    function greeting(date): string {
        return TW.greeting(date);
    }

    function show(): void {
        open = true;
    }
    function hide(): void {
        open = false;
    }
    // für die Karte: heute als gesehen merken (wird beim automatischen Zeigen gesetzt)
    function markShown(): void {
        lastDay = TW.dayKey(new Date());
        saveState();
    }

    // Daten da? (Dienste melden „loading“, bis ihre Datei gelesen ist; Wetter braucht das Netz)
    readonly property bool dataReady: Agenda.status !== "loading" && Mail.status !== "loading" && Weather.ready

    function check(): void {
        const now = new Date();
        if (open || !stateReady || !enabled || !inWindow(now) || lastDay === TW.dayKey(now)) {
            eligibleSince = 0;
            return;
        }
        const here = !locked && !idle.isIdle && !Focus.active && !Windows.fullscreen && !Windows.game;
        if (!here || Date.now() - startedAt < delaySec * 1000) {
            eligibleSince = 0;
            return;
        }
        if (eligibleSince === 0)
            eligibleSince = Date.now();
        if (dataReady || Date.now() - eligibleSince > 15000) {
            markShown();
            open = true;
        }
    }
    Timer {
        interval: 15000
        repeat: true
        running: root.enabled
        triggeredOnStart: true
        onTriggered: root.check()
    }

    IdleMonitor {
        id: idle
        timeout: 120
    }

    // ---------- Dateien ----------
    property bool stateReady: false
    FileView {
        id: stateFile
        path: root.home + "/.local/state/desktop/morning.json"
        blockLoading: true
        printErrors: false
        onLoaded: {
            try {
                root.lastDay = String(JSON.parse(text()).day || "");
            } catch (e) {}
            root.stateReady = true;
        }
        onLoadFailed: root.stateReady = true
    }
    function saveState() {
        stateFile.setText(JSON.stringify({ day: lastDay }));
    }

    FileView {
        path: root.home + "/.config/desktop/morning.json"
        blockLoading: true
        watchChanges: true
        printErrors: false
        onFileChanged: reload()
        onLoaded: {
            try {
                const d = JSON.parse(text());
                root.cfg = d && typeof d === "object" && !Array.isArray(d) ? d : ({});
            } catch (e) {
                console.warn("morning: morning.json is not valid JSON, using defaults");
                root.cfg = ({});
            }
        }
        onLoadFailed: root.cfg = ({})
    }

    // Sperrzustand der Shell (Lock.qml schreibt „locked“/„unlocked“)
    FileView {
        path: Quickshell.env("XDG_RUNTIME_DIR") + "/desktop-lock"
        blockLoading: true
        watchChanges: true
        printErrors: false
        onFileChanged: reload()
        onLoaded: root.lockText = text()
        onLoadFailed: root.lockText = ""
    }

    IpcHandler {
        target: "morning"

        // „show“ kann qs ipc nicht aufrufen (die Kommandozeile hält es für den Befehl „qs ipc show“): darum „open“
        function open(): void {
            root.show();
        }
        function hide(): void {
            root.hide();
        }
        function toggle(): void {
            root.open = !root.open;
        }
        // Zustand ohne Inhalte
        function status(): string {
            return JSON.stringify({ enabled: root.enabled, window: root.from + "-" + root.to, inWindow: root.inWindow(new Date()), shownToday: root.lastDay === TW.dayKey(new Date()),
                open: root.open, locked: root.locked, dataReady: root.dataReady });
        }
        // „heute war noch keine“ (damit sie im Zeitfenster wieder von selbst kommt)
        function reset(): void {
            root.lastDay = "";
            root.saveState();
        }
        // Liegt diese Zeit ("2026-10-18T08:00") im Morgen-Fenster? Nur Logik.
        function inWindowAt(iso: string): string {
            const d = new Date(iso);
            return isNaN(d.getTime()) ? "invalid time" : String(root.inWindow(d));
        }
    }
}
