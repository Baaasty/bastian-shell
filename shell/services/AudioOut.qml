pragma Singleton
import QtQuick
import Quickshell
import Quickshell.Services.Pipewire

// Audio-Ausgänge (Sinks) + Lautstärke pro App über PipeWire.
// Apps = Stream/Output/Audio, gruppiert nach App (Discord/Helium haben mehrere Streams).
Singleton {
    id: root

    readonly property PwNode sink: Pipewire.defaultAudioSink
    property list<PwNode> sinks: []
    property list<PwNode> streams: []
    property var apps: []             // [{ name, nodes }], wichtigste zuerst

    // Reihenfolge der wichtigen Apps; der Rest alphabetisch dahinter
    readonly property var priority: ["Spotify", "Discord", "Equibop", "Helium", "Chrome", "Firefox"]

    // "GoXLRMini System" -> "GoXLR · System"
    function sinkLabel(n: PwNode): string {
        if (!n)
            return "–";
        const d = n.description || n.nickname || n.name || "?";
        return d.replace(/^GoXLR(Mini)?\s+/, "GoXLR · ");
    }

    // Anzeigename einer App; Discord meldet sich als "WEBRTC VoiceEngine"
    function appName(n: PwNode): string {
        const p = (n && n.properties) || {};
        const raw = p["application.name"] || n.description || n.name || "?";
        const hay = [p["pipewire.access.portal.app_id"], p["application.process.binary"], p["application.id"], raw].join(" ");
        if (/equibop/i.test(hay))
            return "Equibop";
        if (/discord/i.test(hay))
            return "Discord";
        if (/spotify/i.test(hay))
            return "Spotify";
        if (/helium/i.test(hay))
            return "Helium";
        if (/chrom/i.test(hay))
            return "Chrome";
        if (/firefox/i.test(hay))
            return "Firefox";
        return raw;
    }

    function setDefault(n: PwNode): void {
        if (n)
            Pipewire.preferredDefaultAudioSink = n;
    }

    function appVolume(app: var): real {
        const n = app && app.nodes && app.nodes[0];
        return (n && n.audio) ? n.audio.volume : 0;
    }
    function setAppVolume(app: var, v: real): void {
        if (!app)
            return;
        const vol = Math.max(0, Math.min(1, v));
        for (const n of app.nodes)
            if (n && n.ready && n.audio)
                n.audio.volume = vol;
    }

    function refresh(): void {
        const ss = [], st = [];
        // Typ kommt aus media.class; Internal-/Split-Knoten sind "Untracked"
        for (const n of Pipewire.nodes.values) {
            if (n.type === PwNodeType.AudioSink)
                ss.push(n);
            else if (n.type === PwNodeType.AudioOutStream)
                st.push(n);
        }
        ss.sort((a, b) => sinkLabel(a).localeCompare(sinkLabel(b)));
        sinks = ss;
        streams = st;

        const by = {};
        for (const n of st) {
            const name = appName(n);
            (by[name] = by[name] || []).push(n);
        }
        const rank = name => {
            const i = priority.indexOf(name);
            return i < 0 ? priority.length : i;
        };
        apps = Object.keys(by).sort((a, b) => rank(a) - rank(b) || a.localeCompare(b)).map(name => ({ name: name, nodes: by[name] }));
    }

    Component.onCompleted: refresh()

    Connections {
        target: Pipewire.nodes
        function onValuesChanged(): void {
            root.refresh();
        }
    }

    // App-Namen stehen erst in properties, wenn der Tracker den Node gebunden hat
    Timer {
        id: late
        interval: 300
        onTriggered: root.refresh()
    }
    Instantiator {
        model: root.streams
        delegate: Connections {
            required property PwNode modelData
            // Ziel einmal setzen statt binden (pro Delegat bleibt das Objekt dasselbe): die Bindung wertete beim
            // Neuladen/Entfernen ohne Kontext zu undefined aus („Unable to assign [undefined] to QObject*“).
            // Startwert null, sonst wäre das Ziel kurz der Elternteil (Warnungen „Detected function …“)
            target: null
            ignoreUnknownSignals: true
            Component.onCompleted: target = modelData ?? null
            function onPropertiesChanged(): void {
                late.restart();
            }
        }
    }

    // nötig, damit Lautstärke/ready der Nodes gebunden sind
    PwObjectTracker {
        objects: [root.sink, ...root.sinks, ...root.streams].filter(n => n)
    }
}
