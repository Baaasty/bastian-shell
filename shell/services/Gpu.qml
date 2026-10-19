pragma Singleton
import QtQuick
import Quickshell
import Quickshell.Io

// NVIDIA: ein Dauerprozess statt Aufruf pro Abfrage (nvidia-smi kostet ~30 ms je Start)
Singleton {
    id: root

    property int temp: -1
    property int util: 0
    property int memUsed: 0
    property int memTotal: 0

    Process {
        id: smi
        running: true
        command: ["nvidia-smi", "--query-gpu=temperature.gpu,utilization.gpu,memory.used,memory.total", "--format=csv,noheader,nounits", "-lms", "2000"]
        stdout: SplitParser {
            onRead: line => {
                const p = line.split(",").map(v => parseInt(v.trim()));
                if (p.length >= 4 && !isNaN(p[0])) {
                    root.temp = p[0];
                    root.util = p[1];
                    root.memUsed = p[2];
                    root.memTotal = p[3];
                }
            }
        }
        onRunningChanged: if (running) root._startedAt = Date.now()
        // z. B. nach Standby: neu starten – bei Fehlstarts mit wachsender Pause (5, 10, 20, 40 s),
        // nach 5 Fehlstarten in Folge 10 min Ruhe (kein Treiber, kein nvidia-smi …)
        onExited: {
            root._fails = Date.now() - root._startedAt > 60000 ? 1 : root._fails + 1;
            if (root._fails >= 5) {
                console.warn("Gpu: nvidia-smi keeps exiting, pausing for 10 min");
                root._fails = 0;
                restart.interval = 10 * 60 * 1000;
            } else {
                restart.interval = 5000 * Math.pow(2, root._fails - 1);
            }
            restart.start();
        }
    }
    property int _fails: 0
    property real _startedAt: 0

    Timer {
        id: restart
        interval: 5000
        onTriggered: smi.running = true
    }
}
