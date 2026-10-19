pragma Singleton
import QtQuick
import Quickshell
import Quickshell.Io

// RAM aus /proc/meminfo (benutzt = Total - Available), Uptime aus /proc/uptime
Singleton {
    id: root

    property real totalGb: 0
    property real usedGb: 0
    readonly property real usage: totalGb > 0 ? usedGb / totalGb : 0
    property int uptimeMin: 0
    // RAM und Uptime stehen nur im Dashboard: offen (Binding in SystemTile) alle 5 s, sonst alle 30 s
    property bool active: false
    // Technik-Chips in der Bar (ResourcesChip) sichtbar -> auch ohne Dashboard im kurzen Takt
    property bool watch: false
    onActiveChanged: if (active) {
        meminfo.reload();
        uptime.reload();
    }

    FileView {
        id: meminfo
        path: "/proc/meminfo"
        onLoaded: {
            const kb = key => {
                const m = new RegExp("^" + key + ":\\s+(\\d+)", "m").exec(text());
                return m ? parseInt(m[1]) : 0;
            };
            root.totalGb = kb("MemTotal") / 1048576;
            root.usedGb = (kb("MemTotal") - kb("MemAvailable")) / 1048576;
        }
    }

    FileView {
        id: uptime
        path: "/proc/uptime"
        onLoaded: root.uptimeMin = Math.floor(parseFloat(text().split(" ")[0]) / 60)
    }

    Timer {
        interval: root.active || root.watch ? 5000 : 30000
        repeat: true
        running: true
        triggeredOnStart: true
        onTriggered: {
            meminfo.reload();
            uptime.reload();
        }
    }
}
