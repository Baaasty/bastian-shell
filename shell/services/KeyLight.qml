pragma Singleton
import QtQuick
import Quickshell
import Quickshell.Io

// Elgato Key Light Air per HTTP (Port 9123, kein Key). Adresse aus secrets.json: keylight.host (mDNS-Name)
// und keylight.ip (Fallback, falls mDNS scheitert). Beides leer = nicht eingerichtet (kein Polling).
// Polling alle 10 s nur, solange active (watch(): Dashboard-Kachel oder Licht-Popout offen).
Singleton {
    id: root

    property string host: ""
    property string fallbackIp: ""
    readonly property bool configured: host !== "" || fallbackIp !== ""
    property bool useIp: host === ""
    readonly property string url: "http://" + (useIp ? fallbackIp : host) + ":9123/elgato/lights"

    // Zuschauer zählen (wie GoXLR.qml): active = mindestens einer sieht zu
    property int watchers: 0
    readonly property bool active: watchers > 0
    function watch(on: bool): void {
        watchers = Math.max(0, watchers + (on ? 1 : -1));
    }
    property bool online: false
    property bool ready: false        // mindestens einmal gelesen
    property bool on: false
    property int brightness: 0        // 3–100 %
    property int kelvin: 0            // 2900–7000 K (Gerät: 143–344 mired)

    readonly property int kelvinMin: 2900
    readonly property int kelvinMax: 7000

    property var pending: ({})        // gesammelte Änderungen bis zum nächsten PUT
    property double lastChange: 0     // ms; kurz danach keine Poll-Werte übernehmen

    function toMired(k: real): int {
        return Math.max(143, Math.min(344, Math.round(1000000 / k)));
    }
    function toKelvin(m: real): int {
        return Math.round(1000000 / m / 50) * 50;
    }
    function label(): string {
        if (!configured)
            return "not configured";
        if (!online)
            return ready ? "offline" : "…";
        return brightness + " % · " + kelvin + " K";
    }

    function refresh(): void {
        if (!configured) {
            ready = true;
            return;
        }
        if (Object.keys(pending).length === 0)
            request("GET", null, false);
    }
    function toggle(): void {
        change({ on: on ? 0 : 1 });
        on = !on;
    }
    function setOn(v: bool): void {
        change({ on: v ? 1 : 0 });
        on = v;
    }
    function setBrightness(p: real): void {
        const b = Math.max(3, Math.min(100, Math.round(p)));
        change({ brightness: b });
        brightness = b;
    }
    function setKelvin(k: real): void {
        const m = toMired(k);
        change({ temperature: m });
        kelvin = toKelvin(m);
    }

    // Änderung merken, gebündelt senden (Slider feuert oft)
    function change(fields: var): void {
        const p = Object.assign({}, pending, fields);
        pending = p;
        lastChange = Date.now();
        debounce.restart();
    }

    function apply(d: var): void {
        const l = d && d.lights && d.lights[0];
        if (!l)
            return;
        root.on = l.on === 1;
        root.brightness = l.brightness;
        root.kelvin = toKelvin(l.temperature);
        root.ready = true;
    }

    function request(method: string, body: var, retried: bool): void {
        if (!configured)
            return;
        const xhr = new XMLHttpRequest();
        xhr.timeout = 3000;
        xhr.onreadystatechange = () => {
            if (xhr.readyState !== XMLHttpRequest.DONE)
                return;
            if (xhr.status === 200) {
                root.online = true;
                // Poll-Antwort ignorieren, wenn gerade jemand am Regler ist
                if (method === "PUT" || Date.now() - root.lastChange > 1500) {
                    try {
                        root.apply(JSON.parse(xhr.responseText));
                    } catch (e) {}
                }
            } else if (!retried && !root.useIp && root.fallbackIp !== "") {
                root.useIp = true;
                root.request(method, body, true);
            } else {
                root.online = false;
                root.ready = true;
            }
        };
        xhr.open(method, root.url);
        if (body) {
            xhr.setRequestHeader("Content-Type", "application/json");
            xhr.send(JSON.stringify(body));
        } else {
            xhr.send();
        }
    }

    Timer {
        id: debounce
        interval: 120
        onTriggered: {
            const p = root.pending;
            root.pending = {};
            if (Object.keys(p).length > 0)
                root.request("PUT", { numberOfLights: 1, lights: [p] }, false);
        }
    }

    FileView {
        path: Quickshell.shellDir + "/../secrets.json"
        watchChanges: true
        printErrors: false
        onFileChanged: reload()
        onLoaded: {
            let k = {};
            try {
                k = JSON.parse(text()).keylight || {};
            } catch (e) {}
            root.host = k.host || "";
            root.fallbackIp = k.ip || "";
            root.useIp = root.host === "";
            if (root.active)
                root.refresh();
        }
        onLoadFailed: {
            root.host = "";
            root.fallbackIp = "";
        }
    }

    Timer {
        interval: 10000
        repeat: true
        running: root.active
        triggeredOnStart: true
        onTriggered: root.refresh()
    }
}
