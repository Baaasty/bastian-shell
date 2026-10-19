pragma Singleton
import QtQuick
import Quickshell
import Quickshell.Io

// Prozessliste fürs Ressourcen-Popout: scripts/procs läuft nur, solange `active` (Popout offen), und liefert alle 2 s
// eine JSON-Zeile (nach Nutzer+Name zu Gruppen zusammengefasst, siehe Skript). Beenden: kill() -> Skript prüft Eigentümer + Startzeit.
Singleton {
    id: root

    property bool active: false
    property bool ready: false          // seit dem Öffnen kam mindestens eine Messung
    property var rows: []
    property string host: ""
    property string osName: ""
    property int uptime: 0              // Sekunden
    property real cpu: 0                // gesamt, 0..100
    property int ncpu: 1
    property real memUsed: 0            // Byte
    property real memTotal: 0
    property real memCache: 0           // Puffer + Cache (frei verfügbar)
    property real swapUsed: 0
    property real swapTotal: 0
    property int procCount: 0
    property int threadCount: 0
    property int uid: -1
    property string lastKill: ""        // Ergebnis der letzten Aktion (für die Statuszeile)

    signal sampled()
    signal killed(string text, bool ok)

    onActiveChanged: if (!active) ready = false

    Process {
        running: root.active
        command: [Quickshell.shellDir + "/../scripts/procs", "watch", "2"]
        stdout: SplitParser {
            onRead: line => {
                try {
                    const d = JSON.parse(line);
                    root.host = d.host;
                    root.osName = d.os;
                    root.uptime = d.uptime;
                    root.cpu = d.cpu;
                    root.ncpu = d.ncpu;
                    root.memUsed = d.memUsed;
                    root.memTotal = d.memTotal;
                    root.memCache = d.memCache || 0;
                    root.swapUsed = d.swapUsed || 0;
                    root.swapTotal = d.swapTotal || 0;
                    root.procCount = d.procs;
                    root.threadCount = d.threads;
                    root.uid = d.uid;
                    root.rows = d.rows;
                    root.ready = true;
                    root.sampled();
                } catch (e) {
                    console.warn("procs: unlesbare Zeile");
                }
            }
        }
    }

    // sig: "TERM" | "KILL"; targets: [{pid, st}] (st = Startzeit aus der Liste)
    function kill(sig: string, targets: var, label: string): void {
        killer.label = label;
        killer.sig = sig;
        killer.command = [Quickshell.shellDir + "/../scripts/procs", "kill", sig].concat(targets.map(t => t.pid + ":" + t.st));
        killer.running = true;
    }

    Process {
        id: killer
        property string label: ""
        property string sig: "TERM"
        stdout: StdioCollector {
            onStreamFinished: {
                let ok = 0, failed = [];
                try {
                    const r = JSON.parse(text);
                    ok = r.ok;
                    failed = r.failed || [];
                } catch (e) {
                    failed = [{ error: "no answer" }];
                }
                const verb = killer.sig === "KILL" ? "Force-killed " : "Ended ";
                let msg = ok > 0 ? verb + killer.label : "";
                if (failed.length > 0)
                    msg += (msg ? " · " : "") + failed.length + " failed (" + failed[0].error + ")";
                root.killed(msg, failed.length === 0);
            }
        }
    }
}
