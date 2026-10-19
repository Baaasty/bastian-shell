pragma Singleton
import QtQuick
import Quickshell
import Quickshell.Io
import "timewin.js" as TW

// Regeln für Benachrichtigungen: Ruhezeiten, Ausnahmen, App-Regeln, Snooze-Auswahl.
// Standard: config/notifications.json im Repo; eigene Werte in ~/.config/desktop/notifications.json
// (dort ersetzt jeder Schlüssel den aus dem Repo). Beide Dateien werden live gelesen. Format: docs/knowledge/shell-features.md.
// Die Zeit-/Regex-Logik steht in timewin.js (Test: scripts/tests/timewin-test.js).
Singleton {
    id: root

    property var base: ({})
    property var user: ({})
    readonly property var cfg: Object.assign({}, base, user)

    // „jetzt“ alle 20 s, damit quietNow beim Ende der Ruhezeit von selbst umspringt
    property real now: Date.now()
    Timer {
        interval: 20000
        repeat: true
        running: true
        onTriggered: root.now = Date.now()
    }

    // ---------- Ruhezeiten ----------
    readonly property var quiet: cfg.quiet && typeof cfg.quiet === "object" ? cfg.quiet : ({})
    readonly property var windows: Array.isArray(quiet.windows) ? quiet.windows : []
    readonly property bool quietEnabled: quiet.enabled !== false && windows.length > 0
    readonly property bool quietNow: quietEnabled && TW.inAnyWindow(windows, new Date(now))
    readonly property bool summaryEnabled: quiet.summary !== false
    // Ende der laufenden Ruhezeit (ms) oder 0
    readonly property real quietEnd: {
        const e = quietNow ? TW.windowEnd(windows, new Date(now)) : null;
        return e ? e.getTime() : 0;
    }
    function quietAt(date): bool {
        return quietEnabled && TW.inAnyWindow(windows, date);
    }

    // ---------- Snooze-Auswahl: [{ label, min } | { label, morning: true }] ----------
    readonly property var snooze: cfg.snooze && typeof cfg.snooze === "object" ? cfg.snooze : ({})
    readonly property string morningTime: typeof snooze.morning === "string" ? snooze.morning : "08:00"
    readonly property var snoozeOptions: {
        const mins = Array.isArray(snooze.minutes) ? snooze.minutes.filter(m => typeof m === "number" && m > 0 && m < 1440) : [10, 60];
        const out = mins.slice(0, 3).map(m => ({ label: label(m), min: m }));
        out.push({ label: "Tomorrow", morning: true });
        return out;
    }
    function label(min: int): string {
        if (min < 60)
            return min + " min";
        const h = Math.floor(min / 60), m = min % 60;
        return m === 0 ? (h === 1 ? "1 hour" : h + " hours") : h + " h " + m + " min";
    }
    // Ziel in ms für eine Auswahl
    function snoozeTarget(spec, from): real {
        return TW.snoozeUntil(from ? new Date(from) : new Date(), spec, morningTime);
    }

    // ---------- Entscheidung für eine neue Meldung ----------
    // n = { app, desktop, summary, urgent }  ->  { popup, hide, held, why }
    //   hide  = gar nicht anzeigen und nicht im Panel (App-Regel)
    //   popup = darf als Popup erscheinen
    //   held  = wegen der Ruhezeit zurückgehalten (zählt für „N while you were away“)
    // „Nicht stören“ / Fokus-Modus prüft Notifs selbst (bleibt wie es war).
    function decide(n: var): var {
        const apps = Array.isArray(cfg.apps) ? cfg.apps : [];
        if (!n.urgent) {
            for (const r of apps) {
                if (!TW.ruleMatches(r, n))
                    continue;
                if (r.when === "quiet" && !quietNow)
                    continue;
                if (r.mode === "hide")
                    return { popup: false, hide: true, held: false, why: "app rule: hide" };
                if (r.mode === "panel")
                    return { popup: false, hide: false, held: false, why: "app rule: panel only" };
            }
        }
        if (quietNow) {
            const th = cfg.through && typeof cfg.through === "object" ? cfg.through : ({});
            if (n.urgent && th.critical !== false)
                return { popup: true, hide: false, held: false, why: "critical" };
            const rules = Array.isArray(th.rules) ? th.rules : [];
            if (rules.some(r => TW.ruleMatches(r, n)))
                return { popup: true, hide: false, held: false, why: "exception" };
            return { popup: false, hide: false, held: true, why: "quiet hours" };
        }
        return { popup: true, hide: false, held: false, why: "" };
    }

    // ---------- Dateien ----------
    function _parse(t, which) {
        try {
            const d = JSON.parse(t);
            return d && typeof d === "object" && !Array.isArray(d) ? d : ({});
        } catch (e) {
            console.warn("notifications: " + which + " is not valid JSON, ignoring it");
            return ({});
        }
    }
    FileView {
        path: Quickshell.shellDir + "/../config/notifications.json"
        blockLoading: true
        watchChanges: true
        printErrors: false
        onFileChanged: reload()
        onLoaded: root.base = root._parse(text(), "config/notifications.json")
        onLoadFailed: root.base = ({})
    }
    FileView {
        path: Quickshell.env("HOME") + "/.config/desktop/notifications.json"
        blockLoading: true
        watchChanges: true
        printErrors: false
        onFileChanged: reload()
        onLoaded: root.user = root._parse(text(), "~/.config/desktop/notifications.json")
        onLoadFailed: root.user = ({})
    }
}
