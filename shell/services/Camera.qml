pragma Singleton
import QtQuick
import Quickshell
import Quickshell.Io

// Kamera (Elgato Facecam) über scripts/camera: Auto-Belichtung immer an, nur die Helligkeit ist einstellbar.
// Die Facecam nimmt Einstellungen nur an, solange sie streamt. Darum: Wunsch-Helligkeit merken
// (~/.local/state/desktop/camera.json) und beim Einschalten der Kamera (z. B. Discord-Call) neu setzen,
// zusammen mit Auto-Belichtung und Anti-Flimmern 50 Hz. Hintergrund: docs/knowledge/hardware.md
Singleton {
    id: root

    readonly property string script: Quickshell.shellDir + "/../scripts/camera"

    // Zuschauer zählen (Dashboard-Kachel, Licht-Popout): active = mindestens einer sieht zu -> öfter nachsehen
    property int watchers: 0
    readonly property bool active: watchers > 0
    function watch(on: bool): void {
        watchers = Math.max(0, watchers + (on ? 1 : -1));
    }
    property bool ready: false
    property bool present: false
    property bool busy: false            // streamt gerade (eine App nutzt sie)

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

    Timer {
        interval: root.active ? 2000 : 5000
        repeat: true
        running: true
        triggeredOnStart: true
        onTriggered: if (!statusProc.running) statusProc.running = true
    }

    Process {
        id: statusProc
        command: [root.script, "status"]
        stdout: StdioCollector {
            onStreamFinished: {
                let j = {};
                try {
                    j = JSON.parse(text);
                } catch (e) {
                    return;
                }
                // erste Antwort nach dem (Neu-)Start der Shell zählt nicht als "eingeschaltet":
                // ein laufender Call behält seine Werte, die Kamera vergisst sie erst beim Abstecken
                const wasBusy = root.ready ? root.busy : j.busy === true;
                root.present = !!j.device;
                root.busy = j.busy === true;
                root.ready = true;
                if (!root.hasWant && typeof j.brightness === "number") {
                    root.wantBrightness = j.brightness;
                    root.hasWant = true;
                }
                if (root.busy && !wasBusy)
                    applyOnStart.restart();
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
