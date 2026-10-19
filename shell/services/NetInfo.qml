pragma Singleton
import QtQuick
import Quickshell
import Quickshell.Io

// Netz-Daten für den Netz-Chip und das Netz-Popout (scripts/netinfo, JSON). Doku: docs/NET.md
//  - Verbindung (Kabel/WLAN, Name, IP, Tempo): bei Netz-Änderungen (`ip monitor`, entprellt), beim Öffnen und alle ~15 s solange offen.
//  - Ping zu den Zielen aus ~/.config/desktop/net.json: NUR solange das Popout offen ist (`active`), alle 3 s.
Singleton {
    id: root

    readonly property string script: Quickshell.shellDir + "/../scripts/netinfo"

    // Popout offen -> Ping abfragen
    property bool active: false

    // Verbindung
    property bool ready: false
    property bool up: false
    property string kind: "none"       // ethernet | wifi | vpn | none
    property string name: "…"
    property string iface: ""
    property string ip: ""
    property string gateway: ""
    property int speed: 0              // Mbit/s (0 = unbekannt)
    property var signalDbm: null       // nur WLAN

    // Latenz: [{ name, host, ms, loss }]; history[host] = letzte Werte (ms, Zeitüberschreitung = 0)
    property var pings: []
    property var history: ({})

    readonly property string label: up ? name : "Offline"
    // Online = mindestens ein Ziel außer dem Router antwortet (nur der Router = „No internet“)
    readonly property bool online: up && pings.length > 0 ? pings.some(p => p.ms !== null && p.host !== gateway) : up

    function fmtSpeed(mbit: int): string {
        if (mbit <= 0)
            return "–";
        return mbit >= 1000 ? (mbit / 1000).toFixed(mbit % 1000 === 0 ? 0 : 1) + " Gbit/s" : mbit + " Mbit/s";
    }

    function refreshLink(): void {
        if (!linkProc.running)
            linkProc.running = true;
    }
    function refreshPing(): void {
        if (!pingProc.running)
            pingProc.running = true;
    }
    function refresh(): void {
        refreshLink();
        refreshPing();
    }

    function summary(): string {
        const out = [];
        out.push("link: " + (up ? kind + " " + name + " " + iface + " " + ip + " gw " + gateway + " " + fmtSpeed(speed) : "offline") + (signalDbm !== null ? " " + signalDbm + " dBm" : ""));
        for (const p of pings)
            out.push("ping: " + p.name + " " + p.host + " " + (p.ms === null ? "timeout" : p.ms + " ms") + " loss " + p.loss + "%");
        return out.join("\n");
    }

    onActiveChanged: if (active) tick = 0
    property int tick: 0

    // ---- Abfragen ----
    Process {
        id: linkProc
        command: [root.script, "link"]
        stdout: StdioCollector {
            onStreamFinished: {
                try {
                    const d = JSON.parse(text);
                    root.up = !!d.up;
                    root.kind = d.kind || "none";
                    root.name = d.name || "";
                    root.iface = d.iface || "";
                    root.ip = d.ip || "";
                    root.gateway = d.gateway || "";
                    root.speed = d.speed || 0;
                    root.signalDbm = d.signal === undefined ? null : d.signal;
                    root.ready = true;
                } catch (e) {
                    console.warn("netinfo link: unlesbar");
                }
            }
        }
    }
    Process {
        id: pingProc
        command: [root.script, "ping"]
        stdout: StdioCollector {
            onStreamFinished: {
                try {
                    const d = JSON.parse(text);
                    const h = Object.assign({}, root.history);
                    for (const p of d.targets) {
                        h[p.host] = (h[p.host] || []).concat([p.ms === null ? 0 : p.ms]).slice(-30);
                    }
                    root.history = h;
                    root.pings = d.targets;
                } catch (e) {
                    console.warn("netinfo ping: unlesbar");
                }
            }
        }
    }
    // ---- Takt nur bei offenem Popout ----
    Timer {
        interval: 3000
        repeat: true
        running: root.active
        triggeredOnStart: true
        onTriggered: {
            root.refreshPing();
            if (root.tick % 5 === 0)
                root.refreshLink();
            root.tick++;
        }
    }

    // ---- Netz-Ereignisse (kein Dauer-Polling): Kabel, Adresse, Route ändern sich -> Verbindung neu lesen ----
    Process {
        running: true
        command: ["ip", "monitor", "link", "address", "route"]
        stdout: SplitParser {
            onRead: line => debounce.restart()
        }
    }
    Timer {
        id: debounce
        interval: 1200
        onTriggered: root.refreshLink()
    }

    Component.onCompleted: refreshLink()
}
