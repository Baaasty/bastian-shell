pragma Singleton
import QtQuick
import Quickshell
import Quickshell.Io

// Verbindung zum Discord-Plugin „DesktopBridge“ (eigener Equicord-Build) (über scripts/cam-relay): Call-Zustand + angepinnte Kameras.
// Das Relay läuft immer und versucht leise, sich mit dem Plugin zu verbinden. Ohne Plugin (Flatpak-Discord, Equibop ohne Plugin)
// bleibt connected = false, und Discord.qml nutzt weiter die alte RPC-Bridge.
// Pins (= was das Plugin abgreift): ergeben sich aus dem Schalter, bis zu maxPins Kacheln. Schlüssel: "<userId>" (Kamera) oder "<userId>:stream" (Bildschirmübertragung).
// Bilder kommen als Dateien im RAM (XDG_RUNTIME_DIR/desktop), das Signal frame meldet jeweils ein neues.
// Einstellungen (von Hand pflegbar): ~/.config/desktop/cams.json  { "width": 300, "show": true, "corner": "top-right", "screen": "DP-2" }
//   width: Kachelbreite in px (Eck-Griff oder Mausrad am Overlay); screen: Monitor (Overlay auf einen anderen Monitor ziehen); show: Kameras an/aus – an = alle Kameras der anderen im Call
//   zusammen im Overlay (Schalter im Discord-Popout); corner: Ecke des Overlays (top-right|top-left|bottom-right|bottom-left, Knopf im Overlay).
// Doku: docs/knowledge/discord.md
Singleton {
    id: root

    readonly property string home: Quickshell.env("HOME")
    readonly property string configDir: (Quickshell.env("XDG_CONFIG_HOME") || home + "/.config") + "/desktop"
    property bool show: true             // Kameras an/aus (Schalter im Discord-Popout)
    property string corner: "top-right"
    property string screen: ""           // Monitor des Overlays (leer = Hauptmonitor)
    readonly property var corners: ["top-right", "bottom-right", "bottom-left", "top-left"]
    // Kachelbreite stufenlos (Eck-Griff am Overlay, Mausrad in Schritten); alte Größen S/M/L werden übernommen
    readonly property int minWidth: 160
    readonly property int maxWidth: 640      // das Overlay deckelt zusätzlich auf halbe Monitorbreite
    readonly property var widths: ({ S: 220, M: 300, L: 420 })
    property int tileWidth: 300
    property string focusKey: ""         // Klick auf eine Kachel: nur diese groß, nochmal = alle
    // Fläche gerade nicht sichtbar (Vollbild/Spiel): keine Bilder anfordern
    property bool paused: false
    property var members: []             // Leute im Call (letzter Zustand des Plugins)
    function setWidth(w: int, persist: bool): void {
        tileWidth = Math.max(minWidth, Math.min(maxWidth, Math.round(w)));
        if (persist)
            save();
    }
    function setScreen(name: string): void {
        if (name === screen)
            return;
        screen = name;
        save();
    }
    function toggleFocus(key: string): void {
        focusKey = focusKey === key ? "" : key;
    }
    // Ecke reihum im Uhrzeigersinn
    function cycleCorner(): void {
        setCorner(corners[(corners.indexOf(corner) + 1) % corners.length]);
    }
    function setCorner(c: string): void {
        if (corners.indexOf(c) < 0 || c === corner)
            return;
        corner = c;
        save();
    }
    function save(): void {
        Quickshell.execDetached(["mkdir", "-p", configDir]);
        cfg.setText(JSON.stringify({ width: tileWidth, show: show, corner: corner, screen: screen }, null, 2) + "\n");
    }
    function stepSize(dir: int): void {
        setWidth(tileWidth + dir * 60, true);
    }

    readonly property int maxPins: 6     // gleich wie MAX_PINS im Plugin (equicord/desktopBridge/native.ts)
    property bool connected: false
    property var pinned: []              // Schlüssel in Pin-Reihenfolge
    property var tiles: ({})             // Schlüssel -> { w, h }: was Equibop gerade als <video> zeigt (nur dann kommen Bilder)

    signal message(var data)             // Zustand/Ereignisse des Plugins (Discord.qml wertet aus)
    signal frame(string key, string path, int n)

    function userOf(key: string): string {
        return key.split(":")[0];
    }
    // welcher Schlüssel gehört zu dieser Person (Kamera zuerst, sonst Übertragung)
    function keyFor(member: var, stream: bool): string {
        if (!member || !member.id)
            return "";
        const wantStream = stream === true || (member.video !== true && member.stream === true);
        return wantStream ? member.id + ":stream" : member.id;
    }
    function isPinned(key: string): bool {
        return pinned.indexOf(key) >= 0;
    }
    // Kameras: ein Schalter für alle (kein Einzel-Anpinnen). An = jede Kamera der anderen im Call im Overlay, bis maxPins
    // (deine eigene nicht: Discords eigene Vorschau liefert kaum Bilder, Bastian: raus).
    function setShow(on: bool): void {
        if (show === on)
            return;
        show = on;
        save();
        sync();
    }
    function toggleShow(): void {
        setShow(!show);
    }
    // Soll-Liste aus dem letzten Zustand bilden und nur die Unterschiede ans Plugin melden
    function sync(): void {
        const want = connected && show ? members.filter(m => m.video === true && m.isSelf !== true).map(m => m.id).slice(0, maxPins) : [];
        if (want.join() === pinned.join())
            return;
        // vorher merken: Liste leer -> Overlay unsichtbar -> paused springt sofort auf true
        const wasPaused = paused;
        const gone = pinned.filter(k => want.indexOf(k) < 0);
        const added = want.filter(k => pinned.indexOf(k) < 0);
        pinned = want;
        if (focusKey !== "" && want.indexOf(focusKey) < 0)
            focusKey = "";
        if (!wasPaused)
            for (const k of gone)
                write("unpin " + k);
        if (!paused)
            for (const k of added)
                write("pin " + k);
    }
    // Leute, die den Call verlassen haben, verlieren ihre Kachel (Discord.qml ruft das bei jedem Zustand)
    function prune(ids: var): void {
        sync();
    }
    onPausedChanged: {
        if (!connected)
            return;
        for (const k of pinned)
            relay.write((paused ? "unpin " : "pin ") + k + "\n");
    }
    function write(cmd: string): bool {
        if (!relay.running || !connected)
            return false;
        relay.write(cmd + "\n");
        return true;
    }

    function apply(line: string): void {
        let d;
        try {
            d = JSON.parse(line);
        } catch (e) {
            return;
        }
        if (d.relay === "up") {
            connected = true;
            if (!paused)
                for (const k of pinned)
                    relay.write("pin " + k + "\n");
            return;
        }
        if (d.relay === "down") {
            connected = false;
            pinned = [];
            return;
        }
        if (d.event === "frame") {
            root.frame(d.id, d.path, d.n);
            return;
        }
        if (d.state === "ok") {
            const t = {};
            for (const x of d.tiles || [])
                t[x.key] = { w: x.w, h: x.h };
            tiles = t;
            members = d.inVoice ? d.members || [] : [];
            sync();
        }
        root.message(d);
    }

    FileView {
        id: cfg
        path: root.configDir + "/cams.json"
        watchChanges: true
        printErrors: false
        onFileChanged: reload()
        onLoaded: {
            try {
                const d = JSON.parse(text());
                if (typeof d.width === "number")
                    root.tileWidth = Math.max(root.minWidth, Math.min(root.maxWidth, d.width));
                else if (root.widths[d.size])
                    root.tileWidth = root.widths[d.size];
                if (typeof d.screen === "string")
                    root.screen = d.screen;
                root.show = d.show !== false;
                if (root.corners.indexOf(d.corner) >= 0)
                    root.corner = d.corner;
            } catch (e) {}
        }
    }

    Process {
        id: relay
        command: [Quickshell.shellDir + "/../scripts/cam-relay"]
        running: true
        stdinEnabled: true
        stdout: SplitParser {
            onRead: line => root.apply(line)
        }
        onExited: {
            root.connected = false;
            restart.start();
        }
    }
    Timer {
        id: restart
        interval: 3000
        onTriggered: relay.running = true
    }

    IpcHandler {
        target: "cams"

        function status(): string {
            return JSON.stringify({ connected: root.connected, pinned: root.pinned, tiles: Object.keys(root.tiles) });
        }
        function on(): void {
            root.setShow(true);
        }
        function off(): void {
            root.setShow(false);
        }
        function toggle(): void {
            root.toggleShow();
        }
        // Overlay in eine Richtung andocken: left|right wechselt die Seite, up|down oben/unten (Super+Strg+Pfeile)
        function move(dir: string): void {
            const v = root.corner.split("-");
            if (dir === "left" || dir === "right")
                v[1] = dir;
            else if (dir === "up" || dir === "down")
                v[0] = dir === "up" ? "top" : "bottom";
            root.setCorner(v.join("-"));
        }
    }
}
