pragma Singleton
import QtQuick
import Quickshell
import Quickshell.Io

// Dienste-Status: iCloud-Sync, Platten (Updates: Updates.qml)
Singleton {
    id: root

    property string icloudResult: ""      // success | failed | …
    property string icloudTime: ""        // HH:mm des letzten Laufs
    property bool icloudFailed: false
    property real rootFreeGb: 0
    property real dataFreeGb: 0
    property real rootSizeGb: 0
    property real dataSizeGb: 0
    // belegt 0..1 (für die Ringe im Dashboard)
    readonly property real rootUsed: rootSizeGb > 0 ? 1 - rootFreeGb / rootSizeGb : 0
    readonly property real dataUsed: dataSizeGb > 0 ? 1 - dataFreeGb / dataSizeGb : 0

    Process {
        id: icloud
        command: ["sh", "-c", "systemctl --user show icloud-sync.service -p Result --value; systemctl --user show icloud-sync.service -p ExecMainExitTimestamp --value; test -e \"$HOME/.local/state/icloud-sync/failed\" && echo failed || echo ok"]
        stdout: StdioCollector {
            onStreamFinished: {
                const l = text.trim().split("\n");
                root.icloudResult = l[0] || "";
                const m = /(\d\d:\d\d):\d\d/.exec(l[1] || "");
                root.icloudTime = m ? m[1] : "";
                root.icloudFailed = l[0] !== "success" || l[2] === "failed";
            }
        }
    }

    Process {
        id: disks
        command: ["df", "-B1", "--output=target,avail,size", "/", Quickshell.env("HOME") + "/Data"]
        stdout: StdioCollector {
            onStreamFinished: {
                for (const line of text.trim().split("\n").slice(1)) {
                    const [target, avail, size] = line.trim().split(/\s+/);
                    if (target === "/") {
                        root.rootFreeGb = parseFloat(avail) / 1e9;
                        root.rootSizeGb = parseFloat(size) / 1e9;
                    } else {
                        root.dataFreeGb = parseFloat(avail) / 1e9;
                        root.dataSizeGb = parseFloat(size) / 1e9;
                    }
                }
            }
        }
    }

    Timer {
        interval: 60000
        repeat: true
        running: true
        triggeredOnStart: true
        onTriggered: {
            icloud.running = true;
            disks.running = true;
        }
    }

    function openFolder(path: string): void {
        Launch.cmd(["xdg-open", path]);
    }

    function fmtGb(gb: real): string {
        return gb >= 1000 ? (gb / 1000).toFixed(1) + " TB" : Math.round(gb) + " GB";
    }
}
