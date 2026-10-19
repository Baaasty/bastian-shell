pragma Singleton
import QtQuick
import Quickshell
import Quickshell.Io
import qs.config

// Eine Icon-Sprache für Benachrichtigungen (Popups + Verlauf im Dashboard).
// Tabelle: shell/config/notif-icons.json (von Hand pflegbar, live neu geladen). Hier nur: Regeln anwenden
// und Töne auf Theme-Farben abbilden (deckend, kein Neon).
Singleton {
    id: root

    property var kinds: ({})
    property var rules: []
    property string fallback: "info"

    // Kachelfarben je Ton: bg deckend, fg = Symbolfarbe
    function tone(name) {
        switch (name) {
        case "accent":
            return { bg: Theme.accentFill, fg: Theme.accentText };
        case "success":
            return { bg: Qt.tint(Theme.surfaceRaised, Qt.alpha(Theme.success, 0.2)), fg: Theme.success };
        case "warning":
            return { bg: Qt.tint(Theme.surfaceRaised, Qt.alpha(Theme.warning, 0.2)), fg: Theme.warning };
        case "error":
            // freundliches Rot: Palette-Fehlerfarbe, abgedunkelt auf deckendem Grund
            return { bg: Qt.tint(Theme.surfaceRaised, Qt.alpha(Theme.error, 0.24)), fg: Qt.lighter(Theme.error, 1.12) };
        default:
            return { bg: Theme.wood, fg: Theme.text };
        }
    }

    function _rx(s) {
        try {
            return new RegExp(s, "i");
        } catch (e) {
            return null;
        }
    }

    // Art bestimmen: Regeln von oben, erste Treffer gewinnt
    function kindOf(app: string, summary: string, category: string, urgency: string, desktop: string): string {
        const a = ((app || "") + " " + (desktop || "")).trim();
        for (const r of rules) {
            if (r.urgency && r.urgency !== (urgency || "normal"))
                continue;
            if (r.app && !(r._app && r._app.test(a)))
                continue;
            if (r.summary && !(r._summary && r._summary.test(summary || "")))
                continue;
            if (r.category && !(r._category && r._category.test(category || "")))
                continue;
            if (kinds[r.kind])
                return r.kind;
        }
        return fallback;
    }

    // { icon, appIcon, bg, fg } für eine Art
    function style(kind: string): var {
        const k = kinds[kind] || kinds[fallback] || {};
        const t = tone(k.tone);
        return { icon: k.icon || "notifications", appIcon: !!k.appIcon, bg: t.bg, fg: t.fg };
    }

    FileView {
        path: Quickshell.shellDir + "/config/notif-icons.json"
        blockLoading: true
        watchChanges: true
        onFileChanged: reload()
        onLoaded: {
            try {
                const d = JSON.parse(text());
                const rs = d.rules || [];
                for (const r of rs) {
                    r._app = r.app ? root._rx(r.app) : null;
                    r._summary = r.summary ? root._rx(r.summary) : null;
                    r._category = r.category ? root._rx(r.category) : null;
                }
                root.kinds = d.kinds || {};
                root.fallback = d["default"] || "info";
                root.rules = rs;
            } catch (e) {
                console.warn("notif-icons.json:", e);
            }
        }
    }
}
