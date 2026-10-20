pragma Singleton
import QtQuick
import Quickshell
import Quickshell.Io

// Kamera (Elgato Facecam) über scripts/camera: Auto-Belichtung immer an, nur die Helligkeit ist einstellbar.
// Die Facecam nimmt Einstellungen nur an, solange sie streamt. Darum: Wunsch-Helligkeit merken
// (~/.local/state/desktop/camera.json) und beim Einschalten der Kamera (z. B. Discord-Call) neu setzen,
// zusammen mit Auto-Belichtung und Anti-Flimmern 50 Hz. Hintergrund: docs/knowledge/hardware.md
// Status kommt ereignisgesteuert vom Kamera-Wächter scripts/privacy-cam (inotify, eine Zeile je Änderung) –
// derselbe Prozess liefert auch die Kamera-Apps für die Privatsphäre-Punkte (apps → Privacy.qml), kein eigenes Polling.
Singleton {
    id: root

    readonly property string script: Quickshell.shellDir + "/../scripts/camera"

    property bool ready: false
    property bool present: false
    property bool busy: false            // streamt gerade (eine App nutzt sie)
    property var apps: []                // Programme mit offenem /dev/video* (ohne PipeWire), für Privacy.qml

    readonly property int brightnessMin: 0
    readonly property int brightnessMax: 255
    // gewünscht (gespeichert); ohne gespeicherten Wert gilt der erste gelesene Kamerawert
    property int wantBrightness: 35
    property bool hasWant: false

    readonly property int percent: Math.round(wantBrightness / brightnessMax * 100)

    function setBrightness(v: real): void {
        wantBrightness = Math.round(Math.max(brightnessMin, Math.min(brightnessMax, v)));
        hasWant = true;
        saveLater.restart();
        if (present && busy && !throttle.running)
            throttle.start();
    }

    // Einschalten: alles setzen; Fader: nur die Helligkeit
    function applyAll(): void {
        run(["apply", String(wantBrightness)]);
    }
    function applyBrightness(): void {
        run(["set", "brightness", String(wantBrightness)]);
    }
    function run(args: var): void {
        if (!present || !busy)
            return;
        if (setProc.running) {
            setProc.pending = args;
            return;
        }
        setProc.command = [script].concat(args);
        setProc.running = true;
    }

    // beim Ziehen höchstens alle 150 ms an die Kamera schicken (letzter Wert gewinnt)
    Timer {
        id: throttle
        interval: 150
        onTriggered: root.applyBrightness()
    }
    Timer {
        id: saveLater
        interval: 400
        onTriggered: prefs.setText(JSON.stringify({ brightness: root.wantBrightness }))
    }
    // gerade eingeschaltet: kurz warten, bis der Stream steht
    Timer {
        id: applyOnStart
        interval: 1500
        onTriggered: root.applyAll()
    }

    function update(line: string): void {
        let j;
        try {
            j = JSON.parse(line);
        } catch (e) {
            return;
        }
        if (JSON.stringify(j.apps || []) !== JSON.stringify(apps))
            apps = j.apps || [];
        // erste Zeile nach dem (Neu-)Start der Shell zählt nicht als "eingeschaltet":
        // ein laufender Call behält seine Werte, die Kamera vergisst sie erst beim Abstecken
        const wasBusy = ready ? busy : j.busy === true;
        present = !!j.device;
        busy = j.busy === true;
        ready = true;
        if (busy && !wasBusy) {
            // ohne gespeicherten Wunsch gilt einmal der Kamerawert (nur im Stream lesbar)
            if (!hasWant && !statusProc.running)
                statusProc.running = true;
            applyOnStart.restart();
        }
    }

    // Kamera-Wächter (Dauerlauf). Stirbt er, Neustart mit Backoff 2 s … 60 s; lief er lange, zählt es neu
    Process {
        id: watcher
        property real startedAt: 0
        property int failures: 0
        command: [Quickshell.shellDir + "/../scripts/privacy-cam"]
        running: true
        stdout: SplitParser {
            onRead: line => root.update(line)
        }
        stderr: SplitParser {
            onRead: line => console.warn("camera watcher:", line)
        }
        onRunningChanged: if (running) startedAt = Date.now()
        onExited: (code, status) => {
            failures = Date.now() - startedAt > 120000 ? 1 : failures + 1;
            restartWatcher.interval = Math.min(60000, 2000 * Math.pow(2, failures - 1));
            console.warn("camera watcher exited (" + code + "), restart in " + restartWatcher.interval / 1000 + " s");
            restartWatcher.start();
        }
    }
    Timer {
        id: restartWatcher
        onTriggered: watcher.running = true
    }

    // nur für den Startwert der Helligkeit (einmal pro Einschalten, wenn noch nichts gespeichert ist)
    Process {
        id: statusProc
        command: [root.script, "status"]
        stdout: StdioCollector {
            onStreamFinished: {
                try {
                    const j = JSON.parse(text);
                    if (!root.hasWant && typeof j.brightness === "number") {
                        root.wantBrightness = j.brightness;
                        root.hasWant = true;
                    }
                } catch (e) {}
            }
        }
    }

    Process {
        id: setProc
        property var pending: null
        stderr: StdioCollector {
            onStreamFinished: if (text.trim() !== "") console.warn("camera:", text.trim())
        }
        onExited: {
            if (pending) {
                const args = pending;
                pending = null;
                root.run(args);
            }
        }
    }

    FileView {
        id: prefs
        path: (Quickshell.env("XDG_STATE_HOME") || Quickshell.env("HOME") + "/.local/state") + "/desktop/camera.json"
        printErrors: false
        onLoaded: {
            try {
                const d = JSON.parse(text());
                if (typeof d.brightness === "number") {
                    root.wantBrightness = Math.max(root.brightnessMin, Math.min(root.brightnessMax, d.brightness));
                    root.hasWant = true;
                }
            } catch (e) {}
        }
    }
}
