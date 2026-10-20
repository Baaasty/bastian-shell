pragma Singleton
import QtQuick
import Quickshell
import Quickshell.Io
import Quickshell.Services.Pipewire

// Privatsphäre-Anzeige: wer nutzt gerade Mikrofon, Kamera oder Bildschirmfreigabe? (Punkt in der Bar: PrivacyDot.qml)
// Quellen – alles ereignisgesteuert, kein Dauer-Polling:
//  - Mikrofon: PipeWire-Aufnahme-Streams (Stream/Input/Audio) mit Verbindung zu einem echten Mikrofon (nicht zu einem Lautsprecher-Monitor)
//  - Kamera:   PipeWire-Video-Streams, die an einer Kamera hängen (v4l2/libcamera, media.role Camera), plus Programme, die /dev/video direkt
//              geöffnet haben (Camera.apps, Wächter scripts/privacy-cam per inotify)
//  - Teilen:   PipeWire-Video-Streams, die an einer Bildschirm-Quelle hängen (xdg-desktop-portal-hyprland: Discord, Browser, OBS …)
// Aktualisiert bei Änderungen der PipeWire-Verbindungen (Link-Gruppen) und Eigenschaften. Doku: docs/knowledge/shell-features.md
Singleton {
    id: root

    property var mics: []            // App-Namen
    property var cams: []
    property var shares: []
    readonly property bool any: mics.length + cams.length + shares.length > 0

    // Test: Einträge von Hand (IPC privacy simulate), ersetzen nichts Echtes
    property var sim: ({ mic: [], cam: [], share: [] })
    // Kamera direkt über /dev/video – kommt vom Kamera-Wächter in Camera.qml (ein Prozess für beide)
    readonly property var camDirect: Camera.apps
    // Kamera wirklich in Benutzung (ohne Test-Einträge) – dafür schaltet CamLight.qml das Key Light
    property bool camLive: false

    // eigene Prozesse nicht melden (die Shell selbst nimmt weder auf noch teilt sie)
    readonly property var ignore: ["quickshell", "qs"]

    function pretty(raw: string): string {
        const r = String(raw);
        const l = r.toLowerCase();
        for (const [k, v] of [["equibop", "Equibop"], ["discord", "Discord"], ["webrtc", "Discord"], ["spotify", "Spotify"], ["helium", "Helium"], ["chrom", "Chrome"], ["firefox", "Firefox"], ["obs", "OBS"], ["zoom", "Zoom"]])
            if (l.includes(k))
                return v;
        return r.charAt(0).toUpperCase() + r.slice(1);
    }

    function add(list: var, name: string): void {
        const n = pretty(name);
        if (!root.ignore.includes(n.toLowerCase()) && !list.includes(n))
            list.push(n);
    }

    function recompute(): void {
        const m = [], c = [], s = [];
        for (const g of Pipewire.linkGroups.values) {
            const t = g.target, src = g.source;
            if (!t || !src)
                continue;
            const tp = t.properties || {};
            const cls = tp["media.class"] || "";
            if (cls === "Stream/Input/Audio") {
                // nimmt die Wiedergabe eines Ausgangs auf (Monitor) -> kein Mikrofon
                if (tp["stream.capture.sink"] === "true" || src.isSink)
                    continue;
                // Discord/Equibop hält das Mikro nach einem Call (oder Mikrotest) offen, ohne etwas zu senden: nur im
                // Sprachkanal melden. Ist der Discord-Status unbekannt (state ≠ ok), lieber melden.
                const app = pretty(AudioOut.appName(t));
                if ((app === "Discord" || app === "Equibop") && Discord.state === "ok" && !Discord.inVoice)
                    continue;
                add(m, AudioOut.appName(t));
            } else if (cls === "Stream/Input/Video") {
                const sp = src.properties || {};
                const isCam = sp["media.role"] === "Camera" || /^(v4l2|libcamera)/.test(src.name || "");
                add(isCam ? c : s, AudioOut.appName(t));
            }
        }
        for (const n of camDirect)
            add(c, n);
        const live = c.length > 0;
        for (const n of sim.mic)
            add(m, n);
        for (const n of sim.cam)
            add(c, n);
        for (const n of sim.share)
            add(s, n);
        if (JSON.stringify(m) !== JSON.stringify(mics))
            mics = m;
        if (JSON.stringify(c) !== JSON.stringify(cams))
            cams = c;
        if (live !== camLive)
            camLive = live;
        if (JSON.stringify(s) !== JSON.stringify(shares))
            shares = s;
    }

    function summary(): string {
        return "mic: " + (mics.join(", ") || "-") + " | camera: " + (cams.join(", ") || "-") + " | sharing: " + (shares.join(", ") || "-");
    }
    function simulate(kind: string, app: string): void {
        const d = { mic: sim.mic.slice(), cam: sim.cam.slice(), share: sim.share.slice() };
        if (d[kind] !== undefined && !d[kind].includes(app))
            d[kind].push(app);
        sim = d;
        recompute();
    }
    function clearSim(): void {
        sim = { mic: [], cam: [], share: [] };
        recompute();
    }

    // ---- PipeWire: Neuberechnung bei Änderungen (entprellt) ----
    Timer {
        id: soon
        interval: 150
        onTriggered: root.recompute()
    }
    // Discord betritt/verlässt einen Sprachkanal: Mikro-Anzeige neu (siehe recompute)
    Connections {
        target: Discord
        function onInVoiceChanged(): void {
            soon.restart();
        }
        function onStateChanged(): void {
            soon.restart();
        }
    }
    Connections {
        target: Camera
        function onAppsChanged(): void {
            soon.restart();
        }
    }
    Connections {
        target: Pipewire.linkGroups
        function onValuesChanged(): void {
            soon.restart();
        }
    }
    Connections {
        target: Pipewire.nodes
        function onValuesChanged(): void {
            soon.restart();
        }
    }
    // Namen/Rollen stehen erst in properties, wenn der Tracker den Node gebunden hat
    Instantiator {
        model: (Pipewire.nodes?.values ?? []).filter(n => !/^(alsa_|Midi|bluez_midi|Dummy|Freewheel)/.test(n?.name || ""))
        delegate: Connections {
            required property PwNode modelData
            // Ziel einmal setzen statt binden (pro Delegat bleibt das Objekt dasselbe): die Bindung wertete beim
            // Neuladen/Entfernen ohne Kontext zu undefined aus („Unable to assign [undefined] to QObject*“).
            // Startwert null, sonst wäre das Ziel kurz der Elternteil (Warnungen „Detected function …“)
            target: null
            ignoreUnknownSignals: true
            Component.onCompleted: target = modelData ?? null
            function onPropertiesChanged(): void {
                soon.restart();
            }
        }
    }
    PwObjectTracker {
        objects: (Pipewire.nodes?.values ?? []).filter(n => !/^(alsa_|Midi|bluez_midi|Dummy|Freewheel)/.test(n?.name || ""))
    }
    Component.onCompleted: soon.restart()

    IpcHandler {
        target: "privacy"
        function status(): string {
            return root.summary();
        }
        // Test: zeigt einen Eintrag an, ohne etwas zu aktivieren. kind = mic | cam | share
        function simulate(kind: string, app: string): void {
            root.simulate(kind, app);
        }
        function clear(): void {
            root.clearSim();
        }
    }
}
