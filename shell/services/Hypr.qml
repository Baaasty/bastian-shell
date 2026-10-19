pragma Singleton
import QtQuick
import Quickshell
import Quickshell.Io
import Quickshell.Hyprland
import qs.config

// Hyprland-Anbindung an einer Stelle: Fenster (Hyprland.toplevels), Monitore, Workspaces, Befehle.
// Ersetzt unter Hyprland TasksModel/VirtualDesktopInfo (org.kde.taskmanager) und den KWin-D-Bus.
//
// Desktops (wie unter KWin über alle Monitore, siehe Config.globalDesktops):
//   Desktop d = Workspace d auf dem Hauptmonitor, 100+d auf dem 1. Nebenmonitor, 200+d auf dem 2. …
//   Minimiert (Hyprland kennt kein Minimieren) = Spezial-Workspace "special:m<ws>": merkt sich, wohin zurück.
//   Weggeräumte Hintergrund-Apps (Parked) = "special:parked<slot>" (slot = Monitor, auf dem sie lag).
// Fenster-Geometrie kommt aus lastIpcObject (hyprctl clients) und wird bei passenden Events neu geholt –
// kein Polling. Lücke: Verschieben eines schwebenden Fensters mit der Maus meldet Hyprland nicht.
//
// Herkunft Event-Liste (welches Event welches refresh braucht): caelestia-shell services/Hypr.qml (GPL-3.0)
Singleton {
    id: root

    // läuft überhaupt ein Hyprland? (sonst bleiben alle Aufrufe stumm, z. B. beim Test unter KWin)
    readonly property bool running: !!Quickshell.env("HYPRLAND_INSTANCE_SIGNATURE")
    // zählt hoch, wenn sich an Fenstern/Workspaces etwas geändert hat (für Bindings und Neuberechnungen)
    property int version: 0

    readonly property var toplevels: Hyprland.toplevels
    readonly property var monitors: Hyprland.monitors
    readonly property var activeToplevel: Hyprland.activeToplevel
    readonly property var mainMonitor: {
        version;
        return monitors.values.find(m => m.name === Config.mainScreen) ?? null;
    }
    // Monitor-Plätze: Hauptmonitor 0, die anderen von links nach rechts 1, 2, …
    readonly property var slots: {
        version;
        const others = monitors.values.filter(m => m.name !== Config.mainScreen).sort((a, b) => a.x - b.x);
        const out = {};
        out[Config.mainScreen] = 0;
        others.forEach((m, i) => out[m.name] = i + 1);
        return out;
    }
    // aktueller Desktop = Workspace des Hauptmonitors
    readonly property int currentDesk: deskOfWs(mainMonitor?.activeWorkspace?.id ?? 1) || 1

    // ---------- Fenster-Infos ----------
    function ipc(t): var {
        return t?.lastIpcObject ?? ({});
    }
    function sel(t): string {
        return "address:0x" + String(t?.address ?? "").replace(/^0x/, "");
    }
    function appId(t): string {
        return ipc(t).class || t?.wayland?.appId || "";
    }
    function title(t): string {
        return t?.title || ipc(t).title || "";
    }
    function wsName(t): string {
        return t?.workspace?.name ?? ipc(t).workspace?.name ?? "";
    }
    function wsId(t): int {
        return t?.workspace?.id ?? ipc(t).workspace?.id ?? 0;
    }
    function monitorName(t): string {
        return t?.monitor?.name ?? "";
    }
    // Lage in Bildschirm-Koordinaten (wie KWin Geometry)
    function geo(t): rect {
        const o = ipc(t);
        return o.at && o.size ? Qt.rect(o.at[0], o.at[1], o.size[0], o.size[1]) : Qt.rect(0, 0, 0, 0);
    }
    function isMinimized(t): bool {
        return /^special:m\d+$/.test(wsName(t));
    }
    function isStashed(t): bool {
        return /^special:parked\d*$/.test(wsName(t));
    }
    // echtes Vollbild (Bit 2); maximiert (Bit 1) zählt über die Geometrie
    function isFullscreen(t): bool {
        const f = ipc(t).fullscreen;
        return typeof f === "number" ? (f & 2) !== 0 : f === true;
    }
    function isUrgent(t): bool {
        return t?.urgent === true;
    }
    function isActive(t): bool {
        return !!t && t === Hyprland.activeToplevel;
    }
    // Stapel: 0 = zuletzt fokussiert. Für z in Vorschauen: größer = weiter vorne
    function stacking(t): int {
        const h = ipc(t).focusHistoryID;
        return (ipc(t).floating ? 1000 : 0) + (typeof h === "number" ? 500 - h : 0);
    }
    function usable(t): bool {
        const o = ipc(t);
        return !!t && o.mapped !== false && !!(o.class || t.wayland) && !helperClasses.includes(appId(t));
    }
    // Unsichtbare Hilfsfenster, die nie als Fenster zählen
    readonly property var helperClasses: ["xwaylandvideobridge", "org.kde.xwaylandvideobridge"]
    // Icon-Name aus der .desktop-Datei (natives VS Code: Klasse "code", Icon "vscode"), sonst die Klasse
    function iconName(t): string {
        const id = appId(t).replace(/\.desktop$/, "");
        const e = id ? (DesktopEntries.byId(id) ?? DesktopEntries.heuristicLookup(id)) : null;
        return e && e.icon ? e.icon : id;
    }
    function iconPath(t): string {
        return Quickshell.iconPath(iconName(t), "application-x-executable");
    }

    // ---------- Desktops <-> Workspaces ----------
    function slotOfMonitor(name: string): int {
        return slots[name] ?? 0;
    }
    function wsFor(slot: int, desk: int): int {
        return slot * 100 + desk;
    }
    function deskOfWs(id: int): int {
        return id > 0 ? id % 100 : 0;
    }
    // Chat-Client (Chat.qml) und Spotify (gekachelt, nicht weggeräumt) folgen jedem Workspace-Wechsel: siehe followCmds und Parked.qml.
    // Ungepinnt und ungefloatet, damit Kacheln, Wegräumen (Parked) und Verschieben normal funktionieren.
    function follows(t): bool {
        return ipc(t).floating !== true && wsId(t) > 0 && !isFullscreen(t) && (/spotify/i.test(appId(t)) || Chat.matches(appId(t)));
    }
    // Befehle, die folgende Fenster auf ihren Ziel-Workspace schieben (target(t) = Workspace-ID, 0 = bleibt).
    // Von links nach rechts, damit die Reihenfolge (Discord links, Spotify rechts) bleibt; die Breite
    // des linken wird danach wiederhergestellt (sonst teilt die neue Kachel 50:50).
    function followCmds(target): var {
        const list = toplevels.values.filter(follows).map(t => ({ t: t, to: target(t) })).filter(x => x.to > 0 && x.to !== wsId(x.t))
            .sort((a, b) => geo(a.t).x - geo(b.t).x);
        const cmds = list.map(x => "dispatch movetoworkspacesilent " + x.to + "," + sel(x.t));
        if (list.length > 1 && list[0].to === list[list.length - 1].to) {
            const g = geo(list[0].t);
            if (g.width > 0)
                cmds.push("dispatch resizewindowpixel exact " + Math.round(g.width) + " " + Math.round(g.height) + "," + sel(list[0].t));
        }
        return cmds;
    }

    // Desktop eines Fensters (minimierte zählen zu ihrem Desktop, weggeräumte zu keinem)
    function deskOf(t): int {
        // angepinnte und folgende Fenster zeigen auf jedem Workspace (Zahl stabil, bis das Nachziehen durch ist)
        if (ipc(t).pinned === true || follows(t))
            return currentDesk;
        const n = wsName(t);
        const m = /^special:m(\d+)$/.exec(n);
        if (m)
            return deskOfWs(Number(m[1]));
        return n.startsWith("special:") ? 0 : deskOfWs(wsId(t));
    }
    // Platz des Monitors, auf dem das Fenster liegt (oder lag)
    function slotOf(t): int {
        if (ipc(t).pinned === true)
            return slotOfMonitor(monitorName(t));
        const n = wsName(t);
        const m = /^special:m(\d+)$/.exec(n);
        if (m)
            return Math.floor(Number(m[1]) / 100);
        const p = /^special:parked(\d+)$/.exec(n);
        if (p)
            return Number(p[1]);
        const id = wsId(t);
        return id > 0 ? Math.floor(id / 100) : slotOfMonitor(monitorName(t));
    }
    function windowsOnDesk(desk: int): var {
        return toplevels.values.filter(t => usable(t) && deskOf(t) === desk);
    }

    // Befehle, um alle Monitore auf Desktop d zu stellen. Der Fokus landet zum Schluss wieder auf dem
    // Monitor, der ihn hatte; cursor:no_warps verhindert dabei Mausspringen.
    function switchCmds(desk: int): var {
        const focused = Hyprland.focusedMonitor?.name ?? Config.mainScreen;
        const change = monitors.values.filter(m => {
            const slot = slotOfMonitor(m.name);
            return (slot === 0 || Config.globalDesktops) && (m.activeWorkspace?.id ?? -1) !== wsFor(slot, desk);
        });
        if (!change.length)
            return [];
        const others = change.filter(m => m.name !== focused);
        // Discord/Spotify zuerst auf die neuen Workspaces schieben (noch unsichtbar), dann umschalten: kein Flackern
        const cmds = followCmds(t => {
            const m = change.find(c => c.name === monitorName(t));
            return m ? wsFor(slotOfMonitor(m.name), desk) : 0;
        });
        for (const m of others)
            cmds.push("dispatch focusmonitor " + m.name, "dispatch workspace " + wsFor(slotOfMonitor(m.name), desk));
        if (others.length)
            cmds.push("dispatch focusmonitor " + focused);
        if (change.some(m => m.name === focused))
            cmds.push("dispatch workspace " + wsFor(slotOfMonitor(focused), desk));
        if (others.length)
            return ["keyword cursor:no_warps 1"].concat(cmds, ["keyword cursor:no_warps " + (noWarps ? 1 : 0)]);
        return cmds;
    }

    // ---------- Kürzel-Sperre ----------
    // Solange ein Panel mit Tastatur offen ist (Passwörter …), sind die globalen Kürzel aus: Hyprland wechselt in die
    // Submap „modal“ (hypr/binds.conf, dort nur Esc, das Panel-Kürzel und der Not-Aus). Name pro Panel, damit sich
    // zwei offene Panels nicht gegenseitig freischalten.
    property var modals: []
    function setModal(name: string, on: bool): void {
        const next = modals.filter(n => n !== name);
        if (on)
            next.push(name);
        if (next.length === modals.length && on === modals.includes(name))
            return;
        modals = next;
        dispatch("submap " + (next.length ? "modal" : "reset"));
    }

    // ---------- Aktionen ----------
    function dispatch(request: string): void {
        if (running)
            Hyprland.dispatch(request);
    }
    // mehrere Befehle in einem hyprctl --batch (z. B. "dispatch workspace 3"), danach optional done()
    function batch(cmds: var, done: var): void {
        if (!running || !cmds.length) {
            if (done)
                done();
            return;
        }
        _queue.push({ cmds: cmds, done: done ?? null });
        _next();
    }
    property var _queue: []
    function _next(): void {
        if (batchProc.running || !_queue.length)
            return;
        const job = _queue.shift();
        batchProc.done = job.done;
        batchProc.command = ["hyprctl", "--batch", job.cmds.join(" ; ")];
        batchProc.running = true;
    }
    Process {
        id: batchProc
        property var done: null
        onExited: {
            const d = done;
            done = null;
            Hyprland.refreshToplevels();
            Hyprland.refreshWorkspaces();
            if (d)
                d();
            root._next();
        }
    }

    // nach vorn holen: minimierte zurück auf ihren Workspace, anderer Desktop = erst dorthin wechseln
    function activate(t): void {
        if (!t)
            return;
        const cmds = [];
        const m = /^special:m(\d+)$/.exec(wsName(t));
        if (m)
            cmds.push("dispatch movetoworkspacesilent " + m[1] + "," + sel(t));
        const d = deskOf(t);
        if (d > 0 && d !== currentDesk)
            for (const c of switchCmds(d))
                cmds.push(c);
        cmds.push("dispatch focuswindow " + sel(t));
        batch(cmds, null);
    }
    function close(t): void {
        if (t)
            dispatch("closewindow " + sel(t));
    }
    function minimize(t): void {
        const id = wsId(t);
        if (t && id > 0)
            dispatch("movetoworkspacesilent special:m" + id + "," + sel(t));
    }
    function toggleMinimized(t): void {
        if (isMinimized(t))
            activate(t);
        else
            minimize(t);
    }
    // auf Desktop d (gleicher Monitor-Platz) schieben, ohne mitzugehen
    function moveToDesk(t, desk: int): void {
        if (t && desk > 0)
            dispatch("movetoworkspacesilent " + wsFor(slotOf(t), desk) + "," + sel(t));
    }
    // weg (Hintergrund-App): unsichtbar, merkt sich den Monitor
    function stash(t): void {
        if (t)
            dispatch("movetoworkspacesilent special:parked" + slotOf(t) + "," + sel(t));
    }

    // ---------- aktuell halten (Events statt Polling) ----------
    property bool noWarps: false
    Process {
        id: warpsProc
        command: ["hyprctl", "getoption", "cursor:no_warps", "-j"]
        stdout: StdioCollector {
            onStreamFinished: {
                try {
                    root.noWarps = !!JSON.parse(text).int;
                } catch (e) {}
            }
        }
    }

    // Bursts (Fenster öffnet = openwindow + activewindow + …) sammeln: ein refresh pro Schub
    Timer {
        id: refreshTop
        interval: 30
        onTriggered: Hyprland.refreshToplevels()
    }
    // zweite Abfrage, wenn Fenster-Animationen durch sind (Endlage statt Zwischenstand)
    Timer {
        id: refreshAfterAnim
        interval: 600
        onTriggered: Hyprland.refreshToplevels()
    }
    Timer {
        id: refreshWs
        interval: 30
        onTriggered: {
            Hyprland.refreshWorkspaces();
            Hyprland.refreshMonitors();
        }
    }

    Connections {
        target: Hyprland
        enabled: root.running
        function onRawEvent(event): void {
            const n = event.name;
            if (n.endsWith("v2"))
                return;
            // Versteck nie zeigen: blendet irgendetwas special:parked<n> ein (Fokus/Aktivierung eines weggeräumten
            // Discord/Spotify), sofort wieder aus. Holen läuft über movetoworkspace, nie über das Einblenden.
            if (n === "activespecial") {
                const m = /^special:(parked\d*),(.+)$/.exec(event.data || "");
                if (m)
                    root.batch(["dispatch focusmonitor " + m[2], "dispatch togglespecialworkspace " + m[1]], null);
            }
            if (n === "configreloaded") {
                warpsProc.running = true;
                refreshWs.restart();
                refreshTop.restart();
            } else if (["workspace", "moveworkspace", "activespecial", "focusedmon", "createworkspace", "destroyworkspace", "renameworkspace"].includes(n) || n.includes("mon")) {
                refreshWs.restart();
                refreshTop.restart();
            } else if (["openwindow", "closewindow", "movewindow", "activewindow", "changefloatingmode", "fullscreen", "pin", "minimized", "moveintogroup", "moveoutofgroup", "togglegroup"].includes(n)) {
                refreshTop.restart();
                if (n === "movewindow" || n === "closewindow" || n === "openwindow")
                    refreshWs.restart();
                // Lage ändert sich danach noch per Animation, ohne weiteres Event (Vollbild aus -> Bar blieb weg)
                if (n === "fullscreen" || n === "changefloatingmode" || n === "closewindow")
                    refreshAfterAnim.restart();
            }
        }
    }

    // jede Änderung an einem Fenster zählt version hoch (Titel, Fokus, Lage nach refresh)
    Instantiator {
        model: root.toplevels
        delegate: Connections {
            required property var modelData
            // Ziel einmal setzen statt binden (pro Delegat bleibt das Objekt dasselbe): die Bindung wertete beim
            // Neuladen/Entfernen ohne Kontext zu undefined aus („Unable to assign [undefined] to QObject*“).
            // Startwert null, sonst wäre das Ziel kurz der Elternteil (Warnungen „Detected function …“)
            target: null
            ignoreUnknownSignals: true
            Component.onCompleted: target = modelData ?? null
            function onLastIpcObjectChanged() { root.bump(); }
            function onWorkspaceChanged() { root.bump(); }
            function onTitleChanged() { root.bump(); }
            function onUrgentChanged() { root.bump(); }
            function onWaylandHandleChanged() { root.bump(); }
        }
        onObjectAdded: root.bump()
        onObjectRemoved: root.bump()
    }
    Connections {
        target: Hyprland
        function onActiveToplevelChanged() { root.bump(); }
        function onFocusedWorkspaceChanged() { root.bump(); }
    }
    Instantiator {
        model: root.monitors
        delegate: Connections {
            required property var modelData
            target: modelData
            function onActiveWorkspaceChanged() { root.bump(); }
            function onXChanged() { root.bump(); }
        }
        onObjectAdded: root.bump()
        onObjectRemoved: root.bump()
    }

    // mehrere Änderungen in einem Schritt zusammenfassen
    property bool _bumpQueued: false
    function bump(): void {
        if (_bumpQueued)
            return;
        _bumpQueued = true;
        Qt.callLater(() => {
            root._bumpQueued = false;
            root.version++;
        });
    }

    // Erstabfrage macht Quickshell selbst. Nicht zusätzlich refresh*() rufen: das liefe vor dessen Start-Abfrage
    // (die als einzige Monitore/Workspaces anlegen darf) und blockierte sie – Monitore blieben leer.
    Component.onCompleted: {
        if (!running)
            return;
        warpsProc.running = true;
        dispatch("submap reset");       // falls die Shell mit offenem Panel abgestürzt ist
    }

    IpcHandler {
        target: "hypr"
        // alle Fenster mit Desktop/Workspace/Lage – zum Prüfen
        function windows(): string {
            return JSON.stringify(root.toplevels.values.map(t => ({
                app: root.appId(t), title: root.title(t), ws: root.wsName(t), desk: root.deskOf(t), slot: root.slotOf(t),
                active: root.isActive(t), urgent: root.isUrgent(t), fullscreen: root.isFullscreen(t), geo: root.geo(t)
            })));
        }
        // nach Fenster-Befehlen von außen (hypr/window.py): Lage neu holen (Hyprland meldet Verschieben nicht)
        function refresh(): void {
            if (root.running)
                refreshTop.restart();
        }
        function status(): string {
            return JSON.stringify({ running: root.running, currentDesk: root.currentDesk, slots: root.slots, noWarps: root.noWarps,
                monitors: root.monitors.values.map(m => ({ name: m.name, x: m.x, ws: m.activeWorkspace?.id ?? null, focused: m.focused })),
                workspaces: Hyprland.workspaces.values.map(w => ({ id: w.id, name: w.name, monitor: w.monitor?.name ?? null })) });
        }
    }
}
