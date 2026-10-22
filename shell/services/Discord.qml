pragma Singleton
import QtQuick
import Quickshell
import Quickshell.Io

// Voice-Status des Chat-Clients (Chat.qml). Zwei Quellen, gleiche Daten:
//  1. Plugin „desktopBridge“ im eigenen Equicord-Build, eingespielt ins Discord-RPM (Cams.qml / scripts/cam-relay): hat Vorrang, sobald es verbunden ist (Köpfe, Steuerung, Kameras).
//  2. Offizielle lokale Discord-RPC (scripts/discord-bridge, JSON-Zeilen auf stdout) – geht nur mit dem echten Discord-Client
//     (RPM/Flatpak, Socket discord-ipc-N); ein arRPC (alter Rückfall Equibop/Vesktop) kennt nur Rich Presence -> wird
//     übersprungen, lauscht nur arRPC: Zustand "unsupported", Fenster/Chip/Starten funktionieren trotzdem.
//     Läuft beides, zeigt die Shell das Plugin; fällt es weg, gilt wieder der letzte Stand der Bridge.
// Kanal, wer drin ist, wer spricht, eigene Mic/Kopfhörer/Cam. Steuerung (rpc.voice.write): eigenes Mic/Taub,
// Kanal verlassen, Lautstärke/Stumm pro Person (gilt, solange die Bridge verbunden ist – Discord-Regel).
// Ohne Call: Kanal-Auswahl (Favoriten, zuletzt genutzt, Server → Sprachkanäle; Klick = beitreten).
// Chats: feste Liste aus secrets.json (discord.chats) – RPC liefert keine DM-Liste.
// Einrichtung: docs/setup/discord.md
Singleton {
    id: root

    readonly property string secretsPath: Quickshell.shellDir + "/../secrets.json"

    // unconfigured | offline | unsupported (nur arRPC von Equibop/Vesktop: kennt keine Call-Befehle) | connecting | authorizing | denied | error | ok
    property string state: "connecting"
    property string message: ""
    readonly property bool configured: state !== "unconfigured"
    readonly property bool ready: state === "ok"

    property bool inVoice: false
    property string channelId: ""
    property string channelName: ""
    property string guildName: ""
    property real since: 0               // ms, Beginn des Calls (so weit die Bridge es weiß)
    property string connection: ""
    property var members: []             // [{ id, name, avatarUrl, speaking, mute, deaf, video, stream, isSelf }]
    // für Repeater: Ids ändern sich nur bei Beitritt/Austritt -> Avatare werden nicht bei jedem Sprechen neu geladen
    property var memberIds: []
    property var memberMap: ({})
    property var self: ({ mute: false, deaf: false, video: null, stream: null })
    readonly property int speakingCount: members.filter(m => m.speaking).length
    property bool canControl: false      // Kopplung enthält rpc.voice.write (Plugin: immer)
    readonly property bool viaPlugin: Cams.connected   // Daten kommen aus dem Equicord-Plugin desktopBridge
    // Plugin fehlt, obwohl Discord läuft und es an sein soll – meist nach einem Discord-Update (neuer app-Ordner ohne
    // Equicord, Discord hat sich am app-run vorbei selbst neu gestartet). Quelle: scripts/equicord status --json.
    property bool pluginMissing: false
    property string pluginMissingReason: ""   // update (nicht eingespielt) | socket (eingespielt, aber kein Socket)
    property bool restarting: false           // „Restart Discord“ läuft (beenden, einspielen, neu starten)
    property string notifiedFor: ""           // Vorfall, zu dem schon benachrichtigt wurde (einmal pro Vorfall)
    readonly property string equicordBin: Quickshell.shellDir + "/../scripts/equicord"
    // beendet Discord (auch einen laufenden Call), spielt Equicord ein, startet über scripts/app-run neu
    function restartDiscord(): void {
        if (restarting)
            return;
        restarting = true;
        restartGiveUp.restart();
        Launch.cmd([equicordBin, "restart"]);
    }
    property string lastBridgeLine: ""   // letzter Stand der RPC-Bridge (sie meldet Gleiches nicht noch einmal)
    property string lastError: ""        // kurz sichtbar nach fehlgeschlagener Aktion

    // Lieblingskanäle, zuletzt genutzt – gemerkt in ~/.local/state/desktop/discord.json
    property var favorites: []           // [{ id, name, guildId, guildName, type }]
    property var recents: []             // die letzten 3 Kanäle, in denen du warst
    function savePrefs(): void {
        prefs.setText(JSON.stringify({ favorites: favorites, recents: recents }));
    }
    function isFavorite(id: string): bool {
        return favorites.some(f => f.id === id);
    }
    function toggleFavorite(ch: var): void {
        if (!ch || !ch.id)
            return;
        favorites = isFavorite(ch.id) ? favorites.filter(f => f.id !== ch.id)
            : favorites.concat([{ id: ch.id, name: ch.name || "?", guildId: ch.guildId || "", guildName: ch.guildName || "", type: ch.type || 2 }]);
        savePrefs();
    }
    function noteRecent(): void {
        if (!inVoice || !channelId || !guildId || (recents.length && recents[0].id === channelId))
            return;
        const ch = { id: channelId, name: channelName, guildId: guildId, guildName: guildName, type: 2 };
        recents = [ch].concat(recents.filter(r => r.id !== channelId)).slice(0, 3);
        savePrefs();
    }

    // ---------- Kanal-Auswahl (nur auf Abruf, Bridge cacht kurz) ----------
    property string guildId: ""
    property var guilds: []              // [{ id, name, iconUrl }]
    property bool guildsLoading: false
    property real guildsAt: 0
    property var channels: ({})          // guildId -> { loading, at, list: [{ id, name, type, members }] }
    property var peeks: ({})             // channelId -> { at, members: [{ id, name, avatarUrl }], missing }
    property var switchAsk: null         // Kanal, für den "schon in einem Call" kam -> Rückfrage
    property var lastJoin: null

    function loadGuilds(): void {
        if (guildsLoading || (guilds.length && Date.now() - guildsAt < 300000))
            return;
        if (send("guilds"))
            guildsLoading = true;
    }
    function loadChannels(gid: string): void {
        const c = channels[gid];
        if (!/^\d+$/.test(gid) || (c && (c.loading || Date.now() - c.at < 45000)))
            return;
        if (!send("channels " + gid))
            return;
        const map = Object.assign({}, channels);
        map[gid] = { loading: true, at: 0, list: c ? c.list : [] };
        channels = map;
    }
    // wer ist gerade in den Favoriten/zuletzt genutzten Kanälen
    function peekSaved(): void {
        const now = Date.now();
        const ids = favorites.concat(recents).map(c => c.id)
            .filter((id, i, a) => a.indexOf(id) === i && (!peeks[id] || now - peeks[id].at > 30000)).slice(0, 8);
        if (ids.length)
            send("peek " + ids.join(" "));
    }
    function join(ch: var, force: bool): void {
        if (!ch || !/^\d+$/.test(ch.id))
            return;
        switchAsk = null;
        lastJoin = ch;
        send("join " + ch.id + (force ? " 1" : ""));
    }

    // Zufalls-Call über alle Server (Plugin sucht aus: Leute drin, nicht voll); im Call = nächster Call
    function randomCall(): void {
        if (!viaPlugin)
            lastError = "Random call needs the Discord plugin";
        else if (send("random"))
            return;
        else
            lastError = "Discord isn’t reachable";
        errorClear.restart();
    }

    property var dms: []                 // [{ id, name }] aus secrets.json

    // Chat im Discord-Fenster öffnen und das Fenster rausholen
    function openChat(id: string): void {
        if (!/^\d+$/.test(id))
            return;
        if (ready && (viaPlugin || bridge.running))
            send("open " + id);
        else
            deepLink(id);
        if (Parked.out.discord !== true)
            Parked.toggle("discord");
    }

    function deepLink(id: string): void {
        Launch.cmd(["xdg-open", "discord://-/channels/@me/" + id]);
    }

    // nach "Abgelehnt"/Fehler erneut koppeln
    function retry(): void {
        if (!bridge.running)
            start();
        else
            bridge.write(state === "denied" ? "reauth\n" : "retry\n");
    }
    // neu koppeln (z. B. damit die Steuerung freigegeben wird)
    function reauth(): void {
        if (bridge.running)
            bridge.write("reauth\n");
    }

    // ---------- Steuerung (Bridge prüft und meldet Fehler) ----------
    function send(cmd: string): bool {
        if (viaPlugin)
            return ready && Cams.write(cmd);
        if (!ready || !bridge.running)
            return false;
        bridge.write(cmd + "\n");
        return true;
    }
    // Eigener Klick gewinnt kurz: Discord meldet Mic/Taub teils mehrfach und in zwei Schritten
    // (erst Einstellung, dann voice_state). 800 ms lang zählt der gewünschte Stand, danach Discords.
    readonly property int holdMs: 800
    property var wish: ({})              // key -> { value, until }
    property var bridgeSelf: ({ mute: false, deaf: false, video: null, stream: null })
    property bool muteBeforeDeaf: false
    function hold(patch: var, ms: int): void {
        const until = Date.now() + ms;
        const w = Object.assign({}, wish);
        for (const k in patch)
            w[k] = { value: patch[k], until: until };
        wish = w;
        root.self = Object.assign({}, root.self, patch);
        endWishes();
    }
    // abgelaufene Wünsche raus, Timer auf den nächsten Ablauf
    function endWishes(): void {
        const now = Date.now();
        const w = {};
        let next = 0;
        for (const k in wish)
            if (wish[k].until > now) {
                w[k] = wish[k];
                next = next ? Math.min(next, wish[k].until) : wish[k].until;
            }
        wish = w;
        applySelf();
        if (next) {
            wishEnd.interval = next - now + 30;
            wishEnd.restart();
        }
    }
    function applySelf(): void {
        const now = Date.now();
        const out = Object.assign({}, bridgeSelf);
        for (const k in wish)
            if (wish[k].until > now)
                out[k] = wish[k].value;
        root.self = out;
    }
    function setMute(on: bool): void {
        if (!send("mute " + (on ? 1 : 0)))
            return;
        // Entstummen hebt in Discord auch Taub auf
        hold(!on && root.self.deaf ? { mute: false, deaf: false } : { mute: on }, holdMs);
    }
    function setDeaf(on: bool): void {
        if (!send("deaf " + (on ? 1 : 0)))
            return;
        // Taub schaltet in Discord auch das Mic stumm; danach kommt der vorige Mic-Stand zurück
        if (on)
            muteBeforeDeaf = root.self.mute === true;
        hold({ deaf: on, mute: on ? true : muteBeforeDeaf }, holdMs);
    }
    // Kamera/Bildschirm gibt es nur übers Plugin (Discords RPC kann das nicht)
    // Kamera: Discord öffnet das Gerät erst (1–3 s), bis dahin meldet es „aus“ → Knopf solange auf dem Wunsch halten
    function setVideo(on: bool): void {
        if (viaPlugin && send("video " + (on ? 1 : 0)))
            hold({ video: on }, 5000);
    }
    // Start fragt unter Wayland erst das Portal → kein hold, Anzeige folgt Discords Stand.
    // Vorher dem Share-Picker ansagen, dass Discord fragt (sonst zählt das aktive Fenster, oft VS Code, und die
    // gemerkte Auswahl für Discord griff nicht) – erst danach den Befehl schicken (Screenshare.expect).
    function setStream(on: bool): void {
        if (!viaPlugin)
            return;
        if (on)
            Screenshare.expect("discord", () => root.send("stream 1"));
        else
            send("stream 0");
    }
    // Prüfen statt glauben: bleibt Discord nach 4 s im selben Kanal, kurz sagen, dass es nicht ging
    property string leaveFrom: ""
    function leave(): void {
        if (send("leave")) {
            leaveFrom = channelId;
            leaveCheck.restart();
        }
    }
    function setUserVolume(id: string, volume: real): void {
        const v = Math.round(Math.max(0, Math.min(200, volume)));
        if (/^\d+$/.test(id) && send("uvol " + id + " " + v))
            patchMember(id, { volume: v });
    }
    function setUserMute(id: string, on: bool): void {
        if (/^\d+$/.test(id) && send("umute " + id + " " + (on ? 1 : 0)))
            patchMember(id, { localMute: on });
    }
    // sofort anzeigen; der nächste Schnappschuss der Bridge bestätigt oder korrigiert
    function patchMember(id: string, patch: var): void {
        if (!memberMap[id])
            return;
        const map = Object.assign({}, memberMap);
        map[id] = Object.assign({}, map[id], patch);
        memberMap = map;
    }

    function start(): void {
        restart.stop();
        bridge.running = true;
    }

    // Koppel-Dialog erscheint im Discord-Fenster -> Fenster rausholen, sonst sieht man ihn nicht
    onStateChanged: if (state === "authorizing" && Parked.out.discord !== true) Parked.toggle("discord")

    // Zeile der RPC-Bridge: merken; gilt nur, solange das Plugin nicht verbunden ist
    function apply(line: string): void {
        let d;
        try {
            d = JSON.parse(line);
        } catch (e) {
            return;
        }
        if (d.state)
            lastBridgeLine = line;
        if (viaPlugin)
            return;
        applyData(d);
    }

    Connections {
        target: Cams
        function onMessage(d) {
            root.applyData(d);
        }
        function onConnectedChanged() {
            eqCheck.running = true;
            if (Cams.connected) {
                root.restarting = false;
                root.pluginMissing = false;
                return;   // der Zustand des Plugins kommt mit dem ersten Paket
            }
            // Plugin weg: zurück zur Bridge (letzter bekannter Stand), sonst leer
            root.clear();
            if (root.lastBridgeLine)
                root.apply(root.lastBridgeLine);
            else
                root.state = "connecting";
        }
    }

    function applyData(d: var): void {
        if (d.event === "openFailed") {
            deepLink(d.id);
            return;
        }
        if (d.event === "guilds") {
            guilds = d.guilds || [];
            guildsAt = Date.now();
            guildsLoading = false;
            return;
        }
        if (d.event === "channels") {
            const map = Object.assign({}, channels);
            map[d.guildId] = { loading: d.partial === true, at: Date.now(), list: d.channels || [] };
            channels = map;
            return;
        }
        if (d.event === "peek") {
            const map = Object.assign({}, peeks);
            for (const c of d.channels || [])
                map[c.id] = { at: Date.now(), members: c.members || [], missing: c.missing === true };
            peeks = map;
            return;
        }
        if (d.event === "actionFailed") {
            // Kamera ging nicht: nicht 5 s lang „an“ zeigen
            if (d.action === "video" && wish.video) {
                const w = Object.assign({}, wish);
                delete w.video;
                wish = w;
                applySelf();
            }
            if (d.action === "guilds")
                guildsLoading = false;
            if (d.action === "channels") {
                const map = Object.assign({}, channels);
                for (const k in map)
                    map[k] = Object.assign({}, map[k], { loading: false });
                channels = map;
            }
            // schon in einem anderen Call -> nachfragen statt einfach wechseln
            if (d.action === "join" && d.code === 5003 && lastJoin) {
                switchAsk = lastJoin;
                return;
            }
            lastError = d.message || "That didn’t work";
            errorClear.restart();
            return;
        }
        if (d.event || !d.state)
            return;
        state = d.state;
        message = d.message || "";
        if (d.state !== "ok") {
            clear();
            return;
        }
        inVoice = !!d.inVoice;
        const prevChannel = channelId;
        channelId = d.channelId || "";
        guildId = d.guildId || "";
        if (channelId !== prevChannel)
            switchAsk = null;
        channelName = d.channelName || "";
        guildName = d.guildName || "";
        since = d.since || 0;
        connection = d.connection || "";
        canControl = d.canControl === true;
        bridgeSelf = d.self || ({ mute: false, deaf: false, video: null, stream: null });
        applySelf();
        setMembers(d.members || []);
        if (viaPlugin)
            Cams.prune(memberIds);
        noteRecent();
    }

    function setMembers(list: var): void {
        const map = {};
        for (const m of list)
            map[m.id] = m;
        memberMap = map;
        const ids = list.map(m => m.id);
        if (ids.join(",") !== memberIds.join(","))
            memberIds = ids;
        members = list;
    }

    function clear(): void {
        inVoice = false;
        setMembers([]);
    }

    Process {
        id: bridge

        property real startedAt: 0
        property int failures: 0

        command: [Quickshell.shellDir + "/../scripts/discord-bridge"]
        running: true
        stdinEnabled: true
        stdout: SplitParser {
            onRead: line => root.apply(line)
        }
        onRunningChanged: if (running) startedAt = Date.now()
        onExited: (code, status) => {
            if (root.state === "unconfigured")
                return;   // wartet auf secrets.json (FileView unten)
            // Absturz/keine Verbindung: Neustart mit Backoff 2 s … 15 s; lief sie lange, zählt es neu
            failures = Date.now() - startedAt > 120000 ? 1 : failures + 1;
            restart.interval = Math.min(15000, 2000 * Math.pow(2, failures - 1));
            if (!root.viaPlugin) {
                root.state = "offline";
                root.clear();
            }
            restart.start();
        }
    }

    Timer {
        id: restart
        onTriggered: bridge.running = true
    }

    // Halten vorbei -> Discords Stand übernehmen
    Timer {
        id: wishEnd
        interval: root.holdMs + 30
        onTriggered: root.endWishes()
    }

    Timer {
        id: leaveCheck
        interval: 4000
        onTriggered: {
            if (root.inVoice && root.leaveFrom !== "" && root.channelId === root.leaveFrom) {
                root.lastError = "Discord stayed in the call – hang up in Discord.";
                errorClear.restart();
            }
            root.leaveFrom = "";
        }
    }

    // ---------- Equicord-Plugin weg? (alle 20 s, solange es nicht verbunden ist) ----------
    Process {
        id: eqCheck
        command: [root.equicordBin, "status", "--json"]
        stdout: StdioCollector {
            onStreamFinished: {
                let d;
                try {
                    d = JSON.parse(text);
                } catch (e) {
                    return;
                }
                root.pluginMissing = d.missing === true && !Cams.connected;
                root.pluginMissingReason = root.pluginMissing ? (d.reason || "") : "";
                if (!d.running && root.restarting)
                    return;   // Neustart läuft: Discord ist gerade beendet
                if (!root.pluginMissing) {
                    root.notifiedFor = "";
                    return;
                }
                // einmal pro Vorfall (= dieser Discord-Prozess) benachrichtigen
                const key = d.pid + ":" + d.reason;
                if (root.notifiedFor !== key) {
                    root.notifiedFor = key;
                    Quickshell.execDetached(["notify-send", "-a", "Discord", "Desktop plugin missing",
                        d.reason === "update" ? "Discord updated itself and dropped Equicord. Discord popout → Restart Discord."
                                              : "Equicord is in, but the plugin isn’t talking. Discord popout → Restart Discord."]);
                }
            }
        }
    }
    Timer {
        interval: 20000
        repeat: true
        running: !Cams.connected
        triggeredOnStart: true
        onTriggered: eqCheck.running = true
    }
    // Neustart: fertig, sobald das Plugin wieder da ist (Cams.onConnectedChanged oben), spätestens nach 90 s freigeben
    Timer {
        id: restartGiveUp
        interval: 90000
        onTriggered: root.restarting = false
    }

    Timer {
        id: errorClear
        interval: 4000
        onTriggered: root.lastError = ""
    }

    FileView {
        id: prefs
        path: (Quickshell.env("XDG_STATE_HOME") || Quickshell.env("HOME") + "/.local/state") + "/desktop/discord.json"
        printErrors: false
        onLoaded: {
            try {
                const d = JSON.parse(text());
                root.favorites = Array.isArray(d.favorites) ? d.favorites.filter(c => c && /^\d+$/.test(c.id)) : [];
                root.recents = Array.isArray(d.recents) ? d.recents.filter(c => c && /^\d+$/.test(c.id)).slice(0, 3) : [];
            } catch (e) {}
        }
    }

    FileView {
        id: secrets
        path: root.secretsPath
        watchChanges: true
        printErrors: false
        onFileChanged: reload()
        onLoaded: {
            let list = [];
            try {
                const d = JSON.parse(text()).discord || {};
                list = (d.chats || []).filter(c => c && /^\d+$/.test(String(c.id))).map(c => ({ id: String(c.id), name: String(c.name || c.id) }));
            } catch (e) {}
            root.dms = list;
            // eben eingetragene Zugangsdaten -> Bridge starten
            if (root.state === "unconfigured" && !bridge.running)
                root.start();
        }
        onLoadFailed: root.dms = []
    }

    IpcHandler {
        target: "discord"

        function status(): string {
            return JSON.stringify({ source: root.viaPlugin ? "plugin" : "bridge", state: root.state, inVoice: root.inVoice, channel: root.channelName, members: root.members.length, speaking: root.speakingCount, pluginMissing: root.pluginMissing, reason: root.pluginMissingReason });
        }
        // Equicord neu einspielen und Discord neu starten (beendet einen laufenden Call)
        function restartDiscord(): void {
            root.restartDiscord();
        }
        function retry(): void {
            root.retry();
        }
        function reauth(): void {
            root.reauth();
        }
        // Super+Alt+J: zufälliger Call mit Leuten, der nicht voll ist; im Call der nächste
        function randomCall(): void {
            root.randomCall();
        }
    }
}
