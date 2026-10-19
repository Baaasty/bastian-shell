pragma Singleton
import QtQuick
import Quickshell
import Quickshell.Io

// GoXLR-Routing über die GoXLR Utility (Daemon auf localhost:14564).
// Lesen: GET /api/get-devices, Schreiben: goxlr-client router … (nacheinander).
// Polling alle 5 s nur, solange jemand zuschaut (watch(): GoxlrPanel in Dashboard-Kachel und Sound-Popout).
// Pegel (levels) nur zum Ansehen: [{ key, label, pct, muted }] aus levels.volumes (0-255) und fader_status.
Singleton {
    id: root

    readonly property string api: "http://localhost:14564/api/get-devices"

    // Zuschauer zählen (mehrere Panels gleichzeitig): active = mindestens einer sieht zu
    property int watchers: 0
    readonly property bool active: watchers > 0
    property bool online: false
    property bool ready: false
    property string serial: ""
    property var router: ({})         // router[Eingang][Ausgang] = bool (Namen wie im JSON)
    property var levels: []           // Pegel zum Ansehen (siehe oben)

    // Kanäle der Pegel-Anzeige [JSON-Name, Anzeige] – Reihenfolge wie Bastians Setup: System (Speakers), Music, Rest, Chat zuletzt, dann Mic
    readonly property var levelChannels: [["System", "System"], ["Music", "Music"], ["Game", "Game"], ["Sample", "Sample"], ["Headphones", "Headphones"], ["Chat", "Chat"], ["Mic", "Mic"]]

    function watch(on: bool): void {
        watchers = Math.max(0, watchers + (on ? 1 : -1));
    }

    property var queue: []            // ausstehende Befehle [[eingang, ausgang, an]]
    property double lastChange: 0

    // JSON-Namen -> goxlr-client-Werte
    readonly property var cliIn: ({ Microphone: "microphone", Chat: "chat", Music: "music", Game: "game", Console: "console", LineIn: "line-in", System: "system", Samples: "samples" })
    readonly property var cliOut: ({ Headphones: "headphones", BroadcastMix: "broadcast-mix", ChatMic: "chat-mic", Sampler: "sampler", LineOut: "line-out", StreamMix2: "stream-mix2" })

    function route(input: string, output: string): bool {
        return !!(router[input] && router[input][output]);
    }

    function setRoute(input: string, output: string, on: bool): void {
        setRoutes([[input, output, on]]);
    }
    function toggle(input: string, output: string): void {
        setRoute(input, output, !route(input, output));
    }

    // mehrere Routen (Presets); nur echte Änderungen werden gesendet
    function setRoutes(list: var): void {
        const r = JSON.parse(JSON.stringify(router));
        const todo = [];
        for (const [i, o, on] of list) {
            if (!cliIn[i] || !cliOut[o] || !r[i] || !!r[i][o] === on)
                continue;
            r[i][o] = on;
            todo.push([i, o, on]);
        }
        if (todo.length === 0)
            return;
        router = r;
        lastChange = Date.now();
        queue = queue.concat(todo);
        pump();
    }

    // stimmen alle Routen eines Presets schon?
    function matches(list: var): bool {
        return list.every(([i, o, on]) => route(i, o) === on);
    }

    function pump(): void {
        if (cmd.running || queue.length === 0)
            return;
        const [i, o, on] = queue[0];
        queue = queue.slice(1);
        const c = ["goxlr-client"];
        if (serial)
            c.push("--device", serial);
        cmd.command = c.concat(["router", cliIn[i], cliOut[o], on ? "true" : "false"]);
        cmd.running = true;
    }

    function refresh(): void {
        const xhr = new XMLHttpRequest();
        xhr.timeout = 3000;
        xhr.onreadystatechange = () => {
            if (xhr.readyState !== XMLHttpRequest.DONE)
                return;
            root.ready = true;
            if (xhr.status !== 200) {
                root.online = false;
                return;
            }
            // nicht dazwischenfunken, solange eigene Befehle laufen
            if (cmd.running || root.queue.length > 0 || Date.now() - root.lastChange < 1500)
                return;
            try {
                const d = JSON.parse(xhr.responseText);
                const serials = Object.keys(d.mixers || {});
                const s = serials.includes(root.serial) ? root.serial : (serials[0] || "");
                root.serial = s;
                root.online = s !== "";
                root.router = s ? (d.mixers[s].router || {}) : {};
                if (s) {
                    const m = d.mixers[s];
                    const vols = (m.levels && m.levels.volumes) || {};
                    const muted = {};
                    for (const f of Object.values(m.fader_status || {}))
                        if (f.channel && f.mute_state && f.mute_state !== "Unmuted")
                            muted[f.channel] = true;
                    root.levels = root.levelChannels.filter(c => vols[c[0]] !== undefined).map(c => ({
                        key: c[0], label: c[1], pct: Math.round(vols[c[0]] / 255 * 100), muted: !!muted[c[0]]
                    }));
                } else {
                    root.levels = [];
                }
            } catch (e) {
                root.online = false;
            }
        };
        xhr.open("GET", api);
        xhr.send();
    }

    Process {
        id: cmd
        stderr: StdioCollector {
            onStreamFinished: if (text.trim() !== "") console.warn("GoXLR:", text.trim())
        }
        onExited: code => {
            if (root.queue.length > 0) {
                root.pump();
            } else {
                // echten Zustand nachlesen (auch nach Fehlern)
                root.lastChange = 0;
                settle.restart();
            }
        }
    }

    Timer {
        id: settle
        interval: 400
        onTriggered: root.refresh()
    }

    Timer {
        interval: 5000
        repeat: true
        running: root.active
        triggeredOnStart: true
        onTriggered: root.refresh()
    }
}
