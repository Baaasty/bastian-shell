pragma Singleton
import QtQuick
import Quickshell
import Quickshell.Io

// CPU: Temperatur (k10temp/Tctl, hwmon per Name gesucht) + Auslastung aus /proc/stat
Singleton {
    id: root

    property int temp: -1
    property real usage: 0
    property string hwmon: ""
    property var _last: null
    // Dashboard offen (Binding in SystemTile) -> alle 2 s; sonst reicht alle 5 s
    // (dann zählt nur die Temperatur für die Hitze-Warnung in der Bar)
    property bool active: false
    // Technik-Chips in der Bar (ResourcesChip) sichtbar -> auch ohne Dashboard im kurzen Takt
    property bool watch: false

    Process {
        running: true
        command: ["sh", "-c", "for d in /sys/class/hwmon/hwmon*; do [ \"$(cat \"$d/name\" 2>/dev/null)\" = k10temp ] && echo \"$d\" && break; done"]
        stdout: StdioCollector {
            onStreamFinished: root.hwmon = text.trim()
        }
    }

    FileView {
        id: tempFile
        path: root.hwmon ? root.hwmon + "/temp1_input" : ""
        onLoaded: root.temp = Math.round(parseInt(text()) / 1000)
    }

    FileView {
        id: stat
        path: "/proc/stat"
        onLoaded: {
            const f = text().split("\n")[0].trim().split(/\s+/).slice(1).map(Number);
            const idle = f[3] + f[4];
            const total = f.reduce((a, b) => a + b, 0);
            if (root._last) {
                const dt = total - root._last.total;
                if (dt > 0)
                    root.usage = 1 - (idle - root._last.idle) / dt;
            }
            root._last = { idle: idle, total: total };
        }
    }

    Timer {
        interval: root.active || root.watch ? 2000 : 5000
        repeat: true
        running: true
        triggeredOnStart: true
        onTriggered: {
            if (root.hwmon)
                tempFile.reload();
            stat.reload();
        }
    }
}
