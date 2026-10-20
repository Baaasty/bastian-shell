pragma Singleton
import QtQuick
import Quickshell
import Quickshell.Hyprland
import qs.config

// Fensterlage auf dem Hauptmonitor: ragt ein Fenster oben in die Bar? Läuft etwas im Vollbild?
// Quelle: Hyprland (Hypr.toplevels), Fenster auf dem sichtbaren Workspace des Hauptmonitors
// (+ seinem offenen Spezial-Workspace).
Singleton {
    id: root

    property bool topBlocked: false
    property bool fullscreen: false
    // Vollbild-Fenster ist ein Spiel (Inhaltstyp "game": Regel in hypr/rules.conf für steam_app_…, oder das Spiel
    // meldet es selbst). Dann nehmen Bar und Arbeitsplatz-Leiste ihre Overlay-Flächen ganz weg: jede Overlay-Fläche
    // auf dem Monitor verhindert in Hyprland direct scanout und Tearing (CMonitor::isSolitaryBlocked, SC_OVERLAYS).
    property bool game: false
    // Echtes Vollbild (Super+↑ zweimal, Hyprland fullscreen 0) oder Spiel: Bar, Arbeitsplatz-Leiste und die
    // Rand-Streifen nehmen ihre Overlay-Flächen ganz weg (kein Einblenden am Rand, kein Overlay über dem Fenster).
    // Maximiert (Super+↑, fullscreen 1) zählt nicht: dort weichen sie nur aus und kommen am Rand zurück.
    // Benachrichtigungen und OSD bleiben erlaubt (eigene Fenster, nur kurz da).
    readonly property bool bare: fullscreen || game
    readonly property var screen: Quickshell.screens.find(s => s.name === Config.mainScreen) ?? null
    // Unterkante der Bar in Bildschirm-Koordinaten (+ etwas Luft)
    readonly property int barBottom: Theme.barMargin + Theme.barHeight + 4

    Connections {
        target: Hypr
        function onVersionChanged() { root.recompute(); }
    }
    // Vollbild → maximiert (Super+↓, Hyprland fullscreen 2 → 1) kam nicht zuverlässig als Ereignis an: der Stand
    // blieb auf Vollbild, Bar und Leisten blieben weg. Solange Vollbild gilt, die echte Lage nachfragen (1×/s, billig).
    Timer {
        interval: 1000
        repeat: true
        running: root.fullscreen
        onTriggered: Hyprland.refreshToplevels()
    }
    onScreenChanged: recompute()
    Component.onCompleted: recompute()

    // Fenster, die gerade auf dem Hauptmonitor zu sehen sind
    function visibleOnMain(): var {
        const mon = Hypr.mainMonitor;
        if (!mon)
            return [];
        const ws = mon.activeWorkspace?.id ?? -1;
        const special = mon.lastIpcObject?.specialWorkspace?.name ?? "";
        return Hypr.toplevels.values.filter(t => Hypr.usable(t)
            && (Hypr.wsId(t) === ws || (special !== "" && Hypr.wsName(t) === special)));
    }

    function recompute(): void {
        if (!screen) {
            topBlocked = false;
            fullscreen = false;
            game = false;
            return;
        }
        let blocked = false;
        let full = false;
        let isGame = false;
        for (const t of visibleOnMain()) {
            if (Hypr.isFullscreen(t)) {
                full = true;
                if (Hypr.ipc(t).contentType === "game")
                    isGame = true;
            }
            const g = Hypr.geo(t);
            const top = g.y - screen.y;
            const bottom = top + g.height;
            if (g.x < screen.x + screen.width && g.x + g.width > screen.x && top < barBottom && bottom > 0)
                blocked = true;
        }
        topBlocked = blocked || full;
        fullscreen = full;
        game = isGame;
    }
}
