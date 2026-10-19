pragma Singleton
import QtQuick
import Quickshell
import Quickshell.Io

// Hintergrund-Apps (Spotify, Chat-Client Discord, siehe Chat.qml): keine eigenen Fenster im Alltag, nur Einbettungen.
// "Rausholen" holt das Fenster auf den aktuellen Desktop (Hyprland: ein Fenster liegt auf genau einem
// Workspace, es wandert also her), nochmal = weggeräumt (Spezial-Workspace "parked", unsichtbar).
// Solange sie draußen sind (gekachelt), folgen sie jedem Workspace-Wechsel (siehe _follow), ohne Pin.
// Die Arbeit macht die Arbeitsplatz-Leiste über impl.
Singleton {
    id: root

    // Die Arbeitsplatz-Leiste prüft jeden Eintrag als Teilstring der Fensterklasse (WorkBar.findApp)
    // und startet mit Launch.run(Eintrag), wenn es noch kein Fenster gibt.
    readonly property var apps: ["spotify"].concat(Chat.parts)
    property var impl: null
    property var out: ({})   // { spotify: true, discord: true, … } – gerade sichtbar auf dem aktuellen Desktop

    // Der Chat-Client heißt für alle Aufrufer "discord" (Chip, Popout, Dashboard, IPC): egal ob Discord (RPM/Flatpak)
    // oder ein alter Rückfall (Equibop/Vesktop) läuft, out.discord stimmt und toggle("discord") trifft das laufende Fenster.
    readonly property string chatKey: "discord"
    onOutChanged: {
        const v = Chat.parts.some(p => out[p] === true);
        if ((out[chatKey] === true) !== v)
            out = Object.assign({}, out, { [chatKey]: v });
    }
    // Teil des Chat-Fensters, das gerade läuft (laufen mehrere, gewinnt der bevorzugte Client, also Discord vor
    // Equibop); läuft keins, der bevorzugte Client (wird dann gestartet)
    function chatPart(): string {
        const ids = Hypr.toplevels.values.map(t => Hypr.appId(t).toLowerCase());
        return Chat.parts.find(p => ids.some(a => a.indexOf(p) >= 0)) || Chat.runName;
    }

    function isParked(appId: string): bool {
        const a = (appId || "").toLowerCase();
        return apps.some(p => a.indexOf(p) >= 0);
    }
    function toggle(part: string): void {
        if (impl)
            impl.toggle(part === chatKey || part === "chat" ? chatPart() : part);
    }
    // Fenster einer App nach vorn (Hintergrund-Apps auf den aktuellen Desktop), z. B. nach Klick auf eine Benachrichtigung
    function focus(name: string): void {
        if (impl && name)
            impl.focus(name === chatKey || name === "chat" ? chatPart() : name.toLowerCase());
    }

    // ---------- auf allen Workspaces sichtbar (gekachelt, ohne Pin) ----------
    // Nicht pinnen (Hyprland sperrt dann movetoworkspace → Wegräumen ginge nicht) und nicht floaten: gekachelte,
    // nicht weggeräumte Discord/Spotify-Fenster ziehen nach jedem Workspace-Wechsel auf den aktiven Workspace
    // ihres Monitors nach, links→rechts (Reihenfolge bleibt). Hypr.switchCmds schiebt sie schon vor dem Umschalten
    // mit (kein Flackern); das hier fängt alle anderen Wechsel ab. Weggeräumte (special:parked) bleiben liegen.
    // Gegen Endlosschleifen: ein Fenster wird höchstens alle 400 ms angefasst, und ohne Abweichung passiert nichts.
    property var _sent: ({})   // Adresse → Zeitpunkt des letzten Nachziehens
    function _follow(): void {
        if (!Hypr.running)
            return;
        const now = Date.now();
        const cmds = Hypr.followCmds(t => {
            const key = Hypr.sel(t);
            if (now - (_sent[key] ?? 0) < 400)
                return 0;
            const m = Hypr.monitors.values.find(m => m.name === Hypr.monitorName(t));
            const target = m?.activeWorkspace?.id ?? 0;
            if (target > 0 && target !== Hypr.wsId(t))
                _sent[key] = now;
            return target;
        });
        if (cmds.length)
            Hypr.batch(cmds, null);
    }
    // ---------- Aufteilung nach dem Holen/Start ----------
    // Chat links (füllt den Rest), Spotify rechts mit fester Breite. Hyprland teilt neue Kacheln 50:50; beim
    // Workspace-Wechsel stellt followCmds die Breite her, beim Holen (Parked.toggle) oder Start eines der beiden
    // Fenster nicht. Darum: ändert sich das Paar (Adressen + Workspace), gilt 2,5 s lang "prüfen" – jede
    // Änderung stößt nach 150 ms (entprellt) die Prüfung an; weicht Spotifys Breite ab, wird sie einmal gesetzt
    // (höchstens alle 600 ms). Danach passiert nichts mehr: manuelles Ziehen bleibt, bis das Paar wieder wechselt.
    readonly property int spotifyWidth: 800
    property string _pairSig: ""
    property double _layoutUntil: 0
    property double _layoutSent: 0
    function _pair(): var {
        const vis = t => Hypr.follows(t) && !Hypr.isStashed(t) && !Hypr.isMinimized(t);
        // laufen zwei Chat-Clients (Umstieg Equibop -> Discord), zählt der bevorzugte (Chat.parts-Reihenfolge)
        const chats = Hypr.toplevels.values.filter(t => vis(t) && Chat.matches(Hypr.appId(t)));
        const chat = chats.find(t => Chat.partOf(Hypr.appId(t)) === Chat.parts[0]) || chats[0];
        const spot = Hypr.toplevels.values.find(t => vis(t) && /spotify/i.test(Hypr.appId(t)));
        if (!chat || !spot || Hypr.wsId(chat) !== Hypr.wsId(spot))
            return null;
        return { chat: chat, spot: spot };
    }
    function _layout(): void {
        if (!Hypr.running)
            return;
        const p = _pair();
        const sig = p ? Hypr.sel(p.chat) + Hypr.sel(p.spot) + Hypr.wsId(p.chat) : "";
        const now = Date.now();
        if (sig !== _pairSig) {
            _pairSig = sig;
            _layoutUntil = sig ? now + 2500 : 0;
            if (sig)
                layoutTimer.restart();
            return;
        }
        if (!p || now > _layoutUntil || now - _layoutSent < 600)
            return;
        const g = Hypr.geo(p.spot);
        // nebeneinander (nicht übereinander) und Breite weicht ab
        if (g.width <= 0 || Math.abs(g.width - spotifyWidth) <= 6 || Math.abs(Hypr.geo(p.chat).y - g.y) > 20)
            return;
        // Hyprland verschiebt beim Ziehen die Trennlinie: darum die Breite des LINKEN (Chat) setzen,
        // so wie followCmds es auch macht (resize auf Spotify selbst trifft die falsche Kante).
        const c = Hypr.geo(p.chat);
        const gap = g.x - (c.x + c.width);
        const chatW = Math.round(g.x + g.width - c.x - gap - spotifyWidth);
        if (chatW < 300)
            return;
        _layoutSent = now;
        Hypr.batch(["dispatch resizewindowpixel exact " + chatW + " " + Math.round(c.height) + "," + Hypr.sel(p.chat)], null);
    }
    Timer {
        id: layoutTimer
        interval: 150
        onTriggered: root._layout()
    }
    Connections {
        target: Hypr
        function onVersionChanged(): void {
            followTimer.restart();
            layoutTimer.restart();
        }
    }
    Timer {
        id: followTimer
        interval: 40
        onTriggered: root._follow()
    }

    IpcHandler {
        target: "parked"
        // z. B. qs ipc call parked toggle discord (trifft den laufenden Chat-Client, Discord zuerst)
        function toggle(part: string): void {
            if (part)
                root.toggle(part.toLowerCase());
        }
        function status(): string {
            return JSON.stringify(root.out);
        }
        // Super+Q: Discord/Spotify nur wegräumen (zurück in die Bar), alles andere schließen; Alt+F4 beendet wirklich
        function closeActive(): void {
            const t = Hypr.activeToplevel;
            if (t && root.isParked(Hypr.appId(t)))
                Hypr.stash(t);
            else
                Hypr.batch(["dispatch killactive"], null);
        }
    }
}
