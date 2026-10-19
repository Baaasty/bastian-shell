pragma Singleton
import QtQuick
import Quickshell
import Quickshell.Io

// Dev-Dienste fürs Bar-Popout (DevPopout.qml): lauschende Ports eigener Prozesse, Container (podman/docker), eigene
// devserver-*-Units – alles aus scripts/devservices (eine JSON-Messung). Prüft alle 5 s, solange das Popout offen ist
// (`active`), sonst alle 30 s (der Chip braucht nur die Zahl); im Vollbild/Spiel (Windows.bare) gar nicht.
// Aktionen gehen ebenfalls über das Skript (Eigentümer/Startzeit geprüft, Dev-Befehl als eigene User-Unit). Doku: docs/DEVSERVICES.md
Singleton {
    id: root

    property bool active: false
    property bool ready: false
    property bool busy: false
    property var servers: []            // [{port, pid, st, label, cmd, cwd, project, how, kind: dev|app, unit, stop, lan}]
    property var containers: []         // [{engine, id, name, image, state, running, status, ports, project, compose, systemd, background}]
    property var units: []              // [{unit, project, active, sub}]
    property var engines: []
    property string note: ""
    property bool noteOk: true
    property string _last: ""

    readonly property string script: Quickshell.shellDir + "/../scripts/devservices"
    readonly property var devServers: servers.filter(s => s.kind === "dev")
    readonly property var runningContainers: containers.filter(c => c.running)
    // Zahl im Chip: Dev-Prozesse (einer je PID, auch mit mehreren Ports) + laufende Container, die nicht nur im Hintergrund laufen
    readonly property int count: {
        const pids = {};
        for (const s of devServers)
            pids[s.pid] = true;
        return Object.keys(pids).length + runningContainers.filter(c => !c.background).length;
    }

    signal acted(string text, bool ok)

    onActiveChanged: if (active) refresh()

    function refresh(): void {
        if (!scanProc.running)
            scanProc.running = true;
    }

    Process {
        id: scanProc
        command: [root.script, "scan"]
        stdout: StdioCollector {
            onStreamFinished: {
                try {
                    const d = JSON.parse(text);
                    // nur bei Änderungen neu setzen: sonst baut das Popout alle 5 s jede Zeile neu
                    const key = JSON.stringify([d.servers, d.containers, d.units, d.engines]);
                    if (key !== root._last) {
                        root._last = key;
                        root.servers = d.servers || [];
                        root.containers = d.containers || [];
                        root.units = d.units || [];
                        root.engines = d.engines || [];
                    }
                    root.ready = true;
                } catch (e) {
                    console.warn("devservices: unlesbare Messung");
                }
            }
        }
    }

    Timer {
        interval: root.active ? 5000 : 30000
        repeat: true
        running: !Windows.bare || root.active
        triggeredOnStart: true
        onTriggered: root.refresh()
    }

    // ---------- Aktionen ----------
    function _run(args: var): void {
        if (actProc.running)
            return;
        busy = true;
        actProc.command = [script].concat(args);
        actProc.running = true;
    }
    // s: Eintrag aus servers (pid + st gegen PID-Wiederverwendung)
    function stop(s: var): void {
        _run(["stop", s.pid + ":" + s.st]);
    }
    function start(projectId: string): void {
        _run(["start", projectId]);
    }
    function container(c: var, action: string): void {
        _run(["container", c.engine, action, c.id]);
    }
    function openPort(port: int): void {
        openUrl("http://localhost:" + port);
    }
    // auch für die Web-Konsolen im Reiter Server (Servers.consoles)
    function openUrl(url: string): void {
        Launch.cmd(["helium", url]);
    }
    // Log einer eigenen Unit im Terminal (journalctl folgt)
    function logs(unit: string): void {
        Launch.cmd(["xdg-terminal-exec", "journalctl", "--user", "-f", "-n", "200", "-u", unit]);
    }

    Process {
        id: actProc
        stdout: StdioCollector {
            onStreamFinished: {
                let ok = false, msg = "Done";
                try {
                    const r = JSON.parse(text);
                    ok = !!r.ok;
                    msg = r.msg || msg;
                } catch (e) {
                    msg = "Action failed";
                }
                root.note = msg;
                root.noteOk = ok;
                root.busy = false;
                root.acted(msg, ok);
                // Dienste brauchen einen Moment zum Hoch-/Runterfahren
                again.restart();
                root.refresh();
            }
        }
    }
    Timer {
        id: again
        interval: 2500
        onTriggered: root.refresh()
    }

    function summary(): string {
        return JSON.stringify({
            count: count,
            servers: devServers.map(s => ({ port: s.port, label: s.label, project: s.project, pid: s.pid, stop: s.stop ? s.stop.mode : "" })),
            containers: containers.map(c => ({ name: c.name, state: c.state, project: c.project, background: c.background })),
            units: units
        });
    }
}
