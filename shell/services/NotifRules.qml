pragma Singleton
import QtQuick
import Quickshell
import Quickshell.Io
import "timewin.js" as TW

// Regeln für Benachrichtigungen: Ruhezeiten, Ausnahmen, App-Regeln.
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

    // ---------- Entscheidung für eine neue Meldung ----------
    // n = { app, desktop, summary, urgent }  ->  { popup, hide, held, transient, why }
    //   hide      = gar nicht anzeigen und nicht im Panel (App-Regel)
    //   popup     = darf als Popup erscheinen
    //   held      = wegen der Ruhezeit zurückgehalten (zählt für „N while you were away“)
    //   transient = nur Popup, nicht in den Verlauf (App-Regel; Ruhezeit gilt trotzdem)
    // „Nicht stören“ / Fokus-Modus prüft Notifs selbst (bleibt wie es war).
    function decide(n: var): var {
        const apps = Array.isArray(cfg.apps) ? cfg.apps : [];
        let tr = false;
        if (!n.urgent) {
            for (const r of apps) {
                if (!TW.ruleMatches(r, n))
                    continue;
                if (r.when === "quiet" && !quietNow)
                    continue;
                if (r.mode === "hide")
                    return { popup: false, hide: true, held: false, transient: false, why: "app rule: hide" };
                if (r.mode === "panel")
                    return { popup: false, hide: false, held: false, transient: false, why: "app rule: panel only" };
                if (r.mode === "transient") {
                    tr = true;
                    break;
                }
            }
        }
        const why = tr ? "app rule: transient" : "";
        if (quietNow) {
            const th = cfg.through && typeof cfg.through === "object" ? cfg.through : ({});
            if (n.urgent && th.critical !== false)
                return { popup: true, hide: false, held: false, transient: tr, why: "critical" };
            const rules = Array.isArray(th.rules) ? th.rules : [];
            if (rules.some(r => TW.ruleMatches(r, n)))
                return { popup: true, hide: false, held: false, transient: tr, why: why || "exception" };
            // flüchtige Meldung fällt ganz weg, liegt also auch nicht im Panel -> zählt nicht als verpasst
            return { popup: false, hide: false, held: !tr, transient: tr, why: why ? why + ", quiet hours" : "quiet hours" };
        }
        return { popup: true, hide: false, held: false, transient: tr, why: why };
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
