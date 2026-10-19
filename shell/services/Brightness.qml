pragma Singleton
import QtQuick
import Quickshell
import Quickshell.Io
import qs.config

// Bildschirmhelligkeit unter Hyprland: kein PowerDevil mehr, also selbst per DDC/CI (ddcutil, VCP 10).
// Kein Polling: gelesen/geschrieben wird nur, wenn ein Kürzel/eine Taste es verlangt (IPC brightness up/down/set).
// Displays heißen wie die Anschlüsse (DP-2, …); Zuordnung zu ddcutil einmal über "ddcutil detect --terse".
Singleton {
    id: root

    // Hauptmonitor (Osd zeigt den bevorzugt)
    readonly property string mainDisplay: Config.mainScreen

    // Name -> { value, max, label, num }
    property var displays: ({})
    readonly property var names: Object.keys(displays)
    // 0..1 des Hauptmonitors
    readonly property real brightness: ratio(mainDisplay)

    // bei jeder Änderung über die Shell
    signal changed(string display, real value)

    function ratio(name: string): real {
        const d = displays[name];
        return d && d.max > 0 ? d.value / d.max : 0;
    }

    function update(name: string, patch: var): void {
        const next = Object.assign({}, displays);
        next[name] = Object.assign({ value: 0, max: 0, label: name, num: 0 }, next[name], patch);
        displays = next;
    }

    // Aufträge nacheinander (ddcutil verträgt keine parallelen Zugriffe auf denselben Bus)
    property var _jobs: []
    property bool _detected: false
    function _run(job: var): void {
        _jobs.push(job);
        _next();
    }
    function _next(): void {
        if (proc.running || !_jobs.length)
            return;
        if (!_detected) {
            detect.running = true;
            return;
        }
        const job = _jobs.shift();
        const d = displays[job.display];
        if (!d || !d.num) {
            _next();
            return;
        }
        proc.job = job;
        // lesen (aktueller Wert + Maximum), neuen Wert rechnen, schreiben, Ergebnis "wert max" ausgeben
        proc.command = ["sh", "-c",
            "n=$1; to=$2; by=$3\n"
            + "set -- $(ddcutil --display \"$n\" --brief getvcp 10)\n"
            + "cur=$4; max=$5; [ -n \"$max\" ] || exit 1\n"
            + "if [ \"$to\" -ge 0 ]; then v=$(( to * max / 1000 )); else v=$(( cur + by * max / 1000 )); fi\n"
            + "[ $v -lt 0 ] && v=0; [ $v -gt $max ] && v=$max\n"
            + "[ $v -ne $cur ] && ddcutil --display \"$n\" --noverify setvcp 10 $v\n"
            + "echo \"$v $max\"",
            "sh", String(d.num), String(job.set >= 0 ? Math.round(job.set * 1000) : -1), String(Math.round(job.step * 1000))];
        proc.running = true;
    }

    Process {
        id: detect
        command: ["ddcutil", "detect", "--terse"]
        stdout: StdioCollector {
            onStreamFinished: {
                let num = 0;
                for (const line of text.split("\n")) {
                    const m = /^Display\s+(\d+)/.exec(line);
                    if (m)
                        num = Number(m[1]);
                    const c = /DRM[_ ]connector:\s+card\d+-(\S+)/i.exec(line);
                    if (c && num)
                        root.update(c[1], { num: num });
                }
            }
        }
        onExited: {
            root._detected = true;
            root._next();
        }
    }

    Process {
        id: proc
        property var job: null
        stdout: StdioCollector {
            onStreamFinished: {
                const job = proc.job;
                const m = /^(\d+)\s+(\d+)/.exec(text.trim());
                if (!job || !m)
                    return;
                root.update(job.display, { value: Number(m[1]), max: Number(m[2]) });
                root.changed(job.display, root.ratio(job.display));
            }
        }
        onExited: {
            job = null;
            root._next();
        }
    }

    // step: Anteil (0.05 = 5 %), display leer = alle bekannten Displays (Hauptmonitor zuerst)
    function step(delta: real, display: string): void {
        for (const n of _targets(display))
            _run({ display: n, step: delta, set: -1 });
    }
    function set(value: real, display: string): void {
        for (const n of _targets(display))
            _run({ display: n, step: 0, set: Math.max(0, Math.min(1, value)) });
    }
    function _targets(display: string): var {
        if (display)
            return [display];
        if (!_detected)
            return [mainDisplay];   // vor der Erkennung: wenigstens der Hauptmonitor
        return [mainDisplay].concat(names.filter(n => n !== mainDisplay));
    }

    IpcHandler {
        target: "brightness"
        // Helligkeitstasten: up/down (Shift = fein: fineUp/fineDown)
        function up(): void {
            root.step(0.1, "");
        }
        function down(): void {
            root.step(-0.1, "");
        }
        function fineUp(): void {
            root.step(0.02, "");
        }
        function fineDown(): void {
            root.step(-0.02, "");
        }
        // 0..100 in Prozent
        function set(percent: int): void {
            root.set(percent / 100, "");
        }
        function status(): string {
            return JSON.stringify(root.displays);
        }
    }
}
