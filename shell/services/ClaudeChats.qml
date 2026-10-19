pragma Singleton
import QtQuick
import Quickshell
import Quickshell.Io

// Normale Claude-Chats (Claude Desktop in der Ubuntu-Box + claude.ai in Chrome) – eine Bubble, nicht pro Projekt.
// Zwei Signale:
//  1. Benachrichtigungen (Notifs.received): Claude Desktop (appName/desktop-entry „Claude“/„com.anthropic“)
//     und Chrome mit „claude.ai“ im Text (Chrome schreibt die Herkunft in den Body)
//  2. Fenster verlangt Aufmerksamkeit (Hyprland „urgent“) – Claude Desktop blinkt so bei „Draw attention“
// Zurückgesetzt wird, sobald ein Claude-Fenster aktiv ist, per Klick auf die Bubble oder Rechtsklick.
Singleton {
    id: root

    readonly property string desktopId: "ubuntu-com.anthropic.Claude"

    property int count: 0                // ungelesene Antworten/Meldungen seit dem letzten Hinschauen
    property bool attention: false       // ein Claude-Fenster will Aufmerksamkeit (und ist nicht aktiv)
    property bool activeClaude: false    // gerade aktiv: Claude Desktop oder Chrome mit claude.ai-Tab vorne
    property string source: ""           // woher die letzte Meldung kam: "desktop" | "chrome"
    property string last: ""             // Titel der letzten Meldung (Tooltip/Status)
    property real launchedAt: 0          // Claude Desktop gerade gestartet: sein erstes Fenster nach vorn holen
    property bool muted: false           // Rechtsklick: aktuelles Blinken ignorieren, bis ein neues kommt
    readonly property bool pending: count > 0 || attention

    // Claude Desktop: Wayland-app_id „com.anthropic.Claude“, Desktop-Datei der Box „ubuntu-com.anthropic.Claude“
    function isDesktopApp(appId: string): bool {
        return /anthropic\.claude|claude-desktop/i.test(appId || "");
    }
    // Browser-Fenster (Chrome/Helium), dessen aktiver Tab claude.ai ist: „Chat-Titel - Claude - Google Chrome“
    function isChromeClaude(appId: string, title: string): bool {
        return /chrome|helium/i.test(appId || "") && /(^|\s[-–—]\s)Claude\s[-–—]\s.*(Chrome|Helium)$/.test(title || "");
    }

    // Quelle einer Meldung ("" = nicht von Claude)
    function sourceOf(n): string {
        const app = n.appName || "";
        const entry = n.desktopEntry || "";
        const text = (n.summary || "") + "\n" + (n.body || "");
        if (/chrom/i.test(app) || /chrom/i.test(entry))
            return /claude\.ai/i.test(text) ? "chrome" : "";
        if (/^claude$/i.test(app) || /anthropic/i.test(app + " " + entry) || /^(ubuntu-)?claude/i.test(entry))
            return "desktop";
        return "";
    }

    Connections {
        target: Notifs
        function onReceived(n) {
            const src = root.sourceOf(n);
            // schaut Bastian gerade in Claude, zählt nichts
            if (!src || root.activeClaude)
                return;
            root.source = src;
            root.last = n.summary || "";
            root.count++;
        }
    }

    function clear(): void {
        count = 0;
        last = "";
    }
    // Rechtsklick: Zähler leeren und laufendes Blinken übergehen
    function dismiss(): void {
        clear();
        muted = true;
        recompute();
    }

    // --- Fensterliste (alle Desktops/Bildschirme) aus Hyprland ---
    // { t, active, demanding, title, appId, desktop, chrome } je Fenster, neu bei jeder Fensteränderung
    property var windows: []
    property var _seen: ({})
    function collect(): void {
        const out = [];
        const seen = {};
        for (const t of Hypr.toplevels.values) {
            const appId = Hypr.appId(t);
            if (!appId)
                continue;
            const title = Hypr.title(t);
            const w = { t: t, active: Hypr.isActive(t), demanding: Hypr.isUrgent(t), title: title, appId: appId,
                desktop: isDesktopApp(appId), chrome: isChromeClaude(appId, title) };
            out.push(w);
            seen[t.address] = w.demanding;
            // Claude Desktop frisch gestartet (über distrobox): Fenster selbst nach vorn holen
            if (!(t.address in _seen) && w.desktop && Date.now() - launchedAt < 30000) {
                launchedAt = 0;
                Hypr.activate(t);
            }
            // neues Blinken zählt wieder
            if (w.demanding && _seen[t.address] === false)
                muted = false;
        }
        _seen = seen;
        windows = out;
        recompute();
    }
    Connections {
        target: Hypr
        function onVersionChanged() { root.collect(); }
    }
    Component.onCompleted: collect()

    function recompute(): void {
        let act = false;
        let att = false;
        for (const w of windows) {
            if (!(w.desktop || w.chrome))
                continue;
            if (w.active)
                act = true;
            else if (w.demanding && w.desktop)
                att = true;
        }
        activeClaude = act;
        attention = att && !act && !muted;
    }
    onActiveClaudeChanged: if (activeClaude) clear()

    // Claude nach vorn: Fenster, das Aufmerksamkeit will > Quelle der letzten Meldung > Claude Desktop > Chrome.
    // Kein Fenster: Claude Desktop starten (läuft es schon im Tray, holt die zweite Instanz das Hauptfenster).
    function open(): void {
        const all = windows.filter(w => w.desktop || w.chrome);
        const pick = all.find(w => w.demanding)
            ?? (source === "chrome" ? all.find(w => w.chrome) : null)
            ?? all.find(w => w.desktop)
            ?? all.find(w => w.chrome);
        clear();
        if (pick) {
            Hypr.activate(pick.t);
            return;
        }
        if (source === "chrome" && openChromeTab())
            return;
        launchedAt = Date.now();
        Launch.app(desktopId);
    }

    // claude.ai-Tab im Hintergrund: Tab per Erweiterung vorholen, Chrome-Fenster über Hyprland heben (wie der Launcher)
    function openChromeTab(): bool {
        const tabs = ChromeTabs.tabs.filter(t => ChromeTabs.host(t.url) === "claude.ai");
        if (!tabs.length)
            return false;
        tabs.sort((a, b) => (b.lastAccessed || 0) - (a.lastAccessed || 0));
        const tab = tabs[0];
        ChromeTabs.activate(tab);
        const want = ChromeTabs.activeTitles[tab.windowId] || "";
        let fallback = null;
        let several = false;   // mehrere Chrome-Fenster, keins passt
        for (const w of windows) {
            if (!/chrome|helium/i.test(w.appId))
                continue;
            if (want && w.title.startsWith(want)) {
                Hypr.activate(w.t);
                return true;
            }
            several = !!fallback;
            fallback = fallback ?? w.t;
        }
        if (fallback && !several)
            Hypr.activate(fallback);
        return true;
    }

    IpcHandler {
        target: "claudechats"

        function status(): string {
            const ws = [];
            for (const w of root.windows) {
                if (w.desktop || w.chrome || /chrome|helium/i.test(w.appId))
                    ws.push({ appId: w.appId, title: w.title, active: w.active, demanding: w.demanding, claude: w.desktop || w.chrome });
            }
            return JSON.stringify({ count: root.count, attention: root.attention, activeClaude: root.activeClaude, source: root.source, last: root.last, windows: ws });
        }
        function clear(): void {
            root.dismiss();
        }
        function open(): void {
            root.open();
        }
    }
}
