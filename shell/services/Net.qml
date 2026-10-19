pragma Singleton
import QtQuick
import Quickshell
import Quickshell.Io

// Netz-Durchsatz der aktiven Schnittstelle (NetInfo.iface) + Speedtest auf Knopfdruck. Doku: docs/NET.md
//  - Durchsatz: alle 5 s die Byte-Zähler lesen (/sys/class/net/<iface>/statistics), pro Minute mitteln,
//    die letzten 60 Minuten im Speicher (rxHistory/txHistory, Byte/s). Sparsam: zwei kleine Datei-Lesungen alle 5 s.
//  - Speedtest: nur auf Knopfdruck (nie automatisch), curl lädt 25 MB von speed.cloudflare.com, Ergebnis in Mbit/s.
Singleton {
    id: root

    readonly property string iface: NetInfo.iface
    // neue Schnittstelle: nicht über die Lücke mitteln (Verlauf bleibt)
    onIfaceChanged: _last = null

    property real rxRate: 0   // Byte/s, letzte 5 s
    property real txRate: 0
    property var rxHistory: []   // Minutenmittel, Byte/s, ältester zuerst (max. 60)
    property var txHistory: []
    // laufende Minute (Summe der Raten + Anzahl Proben)
    property real _rxSum: 0
    property real _txSum: 0
    property int _n: 0
    property real _minuteStart: Date.now()
    property var _last: null

    // Verlauf inkl. angefangener Minute (für das Diagramm)
    readonly property var rxSeries: (_n > 0 ? rxHistory.concat([_rxSum / _n]) : rxHistory).slice(-60)
    readonly property var txSeries: (_n > 0 ? txHistory.concat([_txSum / _n]) : txHistory).slice(-60)
    readonly property real rxAvg: avg(rxSeries)
    readonly property real txAvg: avg(txSeries)
    readonly property real rxPeak: rxSeries.length ? Math.max(...rxSeries) : 0

    function avg(a: var): real {
        return a.length ? a.reduce((s, v) => s + v, 0) / a.length : 0;
    }

    FileView {
        id: rx
        path: root.iface ? "/sys/class/net/" + root.iface + "/statistics/rx_bytes" : ""
    }
    FileView {
        id: tx
        path: root.iface ? "/sys/class/net/" + root.iface + "/statistics/tx_bytes" : ""
    }

    Timer {
        interval: 5000
        repeat: true
        running: root.iface !== ""
        triggeredOnStart: true
        onTriggered: {
            rx.reload();
            tx.reload();
            const now = { rx: parseFloat(rx.text()), tx: parseFloat(tx.text()), t: Date.now() };
            if (isNaN(now.rx) || isNaN(now.tx)) {
                root._last = null;
                return;
            }
            const last = root._last;
            root._last = now;
            // Lücke (Ruhezustand, Schnittstelle neu): nicht mitteln
            if (!last || now.t - last.t > 30000)
                return;
            const dt = (now.t - last.t) / 1000;
            root.rxRate = Math.max(0, (now.rx - last.rx) / dt);
            root.txRate = Math.max(0, (now.tx - last.tx) / dt);
            root._rxSum += root.rxRate;
            root._txSum += root.txRate;
            root._n++;
            if (now.t - root._minuteStart >= 60000) {
                root.rxHistory = root.rxHistory.concat([root._rxSum / root._n]).slice(-60);
                root.txHistory = root.txHistory.concat([root._txSum / root._n]).slice(-60);
                root._rxSum = 0;
                root._txSum = 0;
                root._n = 0;
                root._minuteStart = now.t;
            }
        }
    }

    // ---------- Speedtest (nur auf Knopfdruck) ----------
    readonly property string speedUrl: "https://speed.cloudflare.com/__down?bytes=25000000"
    property bool testing: false
    property real speedMbit: -1      // letztes Ergebnis (-1 = noch keins)
    property real speedAt: 0         // Zeitpunkt (ms)
    property string speedError: ""

    function speedtest(): void {
        if (testing)
            return;
        testing = true;
        speedError = "";
        speedProc.running = true;
    }

    Process {
        id: speedProc
        command: ["curl", "-s", "-o", "/dev/null", "--max-time", "25", "-w", "%{http_code} %{speed_download} %{size_download}", root.speedUrl]
        stdout: StdioCollector {
            onStreamFinished: {
                const f = text.trim().split(/\s+/);
                const code = parseInt(f[0]), bps = parseFloat(f[1]), size = parseFloat(f[2]);
                if (code === 200 && bps > 0 && size > 1000000) {
                    root.speedMbit = bps * 8 / 1e6;
                    root.speedAt = Date.now();
                } else {
                    root.speedError = code > 0 ? "Test failed (HTTP " + code + ")" : "Test failed – no connection";
                }
                root.testing = false;
            }
        }
    }

    // Byte/s -> „12.3 Mbit/s“
    function fmtMbit(bps: real): string {
        const m = bps * 8 / 1e6;
        if (m >= 100)
            return Math.round(m) + " Mbit/s";
        if (m >= 0.1)
            return m.toFixed(1) + " Mbit/s";
        const k = bps * 8 / 1e3;
        return Math.round(k) + " kbit/s";
    }
    function fmtRate(bps: real): string {
        if (bps >= 1048576)
            return (bps / 1048576).toFixed(1) + " MB/s";
        if (bps >= 1024)
            return Math.round(bps / 1024) + " KB/s";
        return Math.round(bps) + " B/s";
    }
}
