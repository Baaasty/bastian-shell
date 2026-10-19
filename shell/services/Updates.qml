pragma Singleton
import QtQuick
import Quickshell
import Quickshell.Io

// Verfügbare Updates (dnf inkl. COPR + Flatpak) für den Update-Chip in der Bar. Nur lesen – installiert wird im Paketmanager (Super+P).
// Prüft im Hintergrund mit niedriger Priorität (nice 19, ionice idle) über scripts/pkg (dasselbe Backend wie der Paketmanager):
//   - 3 min nach dem Start, dann alle 4 h; dnf-Metadaten werden höchstens 1× am Tag erzwungen neu geladen (pkg refresh),
//     sonst lädt dnf sie nur, wenn sie abgelaufen sind.
//   - hat sich die RPM-Datenbank oder Flatpak geändert (installiert/aktualisiert), nach 1 min erneut.
// Letztes Ergebnis liegt in ~/.local/state/desktop/updates.json: nach einem Shell-Neustart steht die Zahl sofort da.
// Doku: docs/knowledge/shell-features.md
Singleton {
    id: root

    readonly property string pkgBin: Quickshell.shellDir + "/../scripts/pkg"
    readonly property var low: ["nice", "-n", "19", "ionice", "-c", "3"]
    readonly property int everyMs: 4 * 3600 * 1000
    readonly property int refreshEveryMs: 24 * 3600 * 1000
    readonly property int startDelayMs: 3 * 60 * 1000

    property var system: []          // [{ name, version, current, repo, copr }]
    property var flatpak: []         // [{ name, id, version, runtime, scope }]
    property real checkedAt: 0
    property real refreshedAt: 0
    property bool checking: false
    property string error: ""
    property real nextAt: 0          // nächste geplante Prüfung
    property string _stamps: ""      // letzte mtimes von RPM-DB / Flatpak (Änderung -> neu prüfen)

    readonly property int countSystem: system.length
    readonly property int countFlatpak: flatpak.length
    readonly property int count: countSystem + countFlatpak

    // Kurztext für Chip/IPC: "9 system · 3 Flatpak"
    function summary(): string {
        const p = [];
        if (countSystem)
            p.push(countSystem + " system");
        if (countFlatpak)
            p.push(countFlatpak + " Flatpak");
        return p.length ? p.join(" · ") : "Up to date";
    }

    // Jetzt prüfen (force = dnf-Metadaten erzwungen neu laden)
    function check(force: bool): void {
        if (checking)
            return;
        checking = true;
        error = "";
        const needRefresh = force || Date.now() - refreshedAt > refreshEveryMs;
        if (needRefresh) {
            refreshProc.running = true;
        } else {
            sysProc.running = true;
            fpProc.running = true;
        }
    }

    // Paketmanager auf dem Reiter „Updates“ öffnen (IPC an dieselbe Shell)
    function openManager(): void {
        Quickshell.execDetached(["qs", "ipc", "--any-display", "-p", Quickshell.shellDir, "call", "packages", "page", "updates"]);
    }

    function _parse(text: string): var {
        try {
            return JSON.parse(text);
        } catch (e) {
            return { ok: false, error: "bad output" };
        }
    }
    function _done(): void {
        if (sysProc.running || fpProc.running || refreshProc.running)
            return;
        checking = false;
        checkedAt = Date.now();
        save();
        _schedule(60000);
    }
    function save(): void {
        state.setText(JSON.stringify({ checkedAt: checkedAt, refreshedAt: refreshedAt, system: system, flatpak: flatpak }));
    }
    // nächste Prüfung relativ zur letzten, frühestens nach minMs (beim Start startDelay: die Shell lädt beim Speichern oft neu)
    function _schedule(minMs: int): void {
        const due = checkedAt > 0 ? checkedAt + everyMs - Date.now() : 0;
        timer.interval = Math.max(minMs, due);
        timer.restart();
        nextAt = Date.now() + timer.interval;
    }

    Process {
        id: refreshProc
        command: root.low.concat([root.pkgBin, "refresh"])
        stdout: StdioCollector {
            onStreamFinished: {
                const d = root._parse(text);
                if (d.ok)
                    root.refreshedAt = Date.now();
                // auch bei Fehler (z. B. offline) mit dem vorhandenen Cache weiterprüfen
                sysProc.running = true;
                fpProc.running = true;
            }
        }
    }
    Process {
        id: sysProc
        command: root.low.concat([root.pkgBin, "updates", "system"])
        stdout: StdioCollector {
            onStreamFinished: {
                const d = root._parse(text);
                if (d.ok)
                    root.system = d.items.map(u => ({ name: u.name, version: u.version, current: u.current, repo: u.repo, copr: u.copr || "" }));
                else
                    root.error = "dnf: " + (d.error || "failed");
                Qt.callLater(root._done);
            }
        }
    }
    Process {
        id: fpProc
        command: root.low.concat([root.pkgBin, "updates", "flatpak"])
        stdout: StdioCollector {
            onStreamFinished: {
                const d = root._parse(text);
                if (d.ok)
                    root.flatpak = d.items.map(u => ({ name: u.name, id: u.id, version: u.version, runtime: !!u.runtime, scope: u.scope }));
                else
                    root.error = "flatpak: " + (d.error || "failed");
                Qt.callLater(root._done);
            }
        }
    }

    // regelmäßige Prüfung (Intervall setzt _schedule)
    Timer {
        id: timer
        // nach jeder Prüfung plant _done die nächste (_schedule)
        onTriggered: root.check(false)
    }

    // wurde etwas installiert/aktualisiert? (alle 5 min ein stat; bei Änderung 1 min später neu prüfen)
    Process {
        id: stampProc
        command: ["sh", "-c", "stat -c %Y /usr/lib/sysimage/rpm/rpmdb.sqlite /var/lib/flatpak/.changed \"$HOME/.local/share/flatpak/.changed\" 2>/dev/null | tr '\\n' ' '"]
        stdout: StdioCollector {
            onStreamFinished: {
                const s = text.trim();
                if (root._stamps !== "" && s !== root._stamps)
                    afterChange.restart();
                root._stamps = s;
            }
        }
    }
    Timer {
        interval: 300000
        running: true
        repeat: true
        triggeredOnStart: true
        onTriggered: stampProc.running = true
    }
    Timer {
        id: afterChange
        interval: 60000
        onTriggered: root.check(false)
    }

    FileView {
        id: state
        path: Quickshell.env("HOME") + "/.local/state/desktop/updates.json"
        printErrors: false
        blockLoading: true
        onLoaded: {
            try {
                const d = JSON.parse(text());
                root.system = d.system || [];
                root.flatpak = d.flatpak || [];
                root.checkedAt = d.checkedAt || 0;
                root.refreshedAt = d.refreshedAt || 0;
            } catch (e) {}
            root._schedule(root.startDelayMs);
        }
    }

    Component.onCompleted: _schedule(startDelayMs)

    // qs ipc --any-display -p ~/Workspace/bastian-shell/shell call updates status|check|refresh|open|fake <n>
    IpcHandler {
        target: "updates"
        function status(): string {
            return JSON.stringify({ count: root.count, system: root.countSystem, flatpak: root.countFlatpak, checking: root.checking,
                checkedAt: root.checkedAt ? new Date(root.checkedAt).toISOString() : null,
                refreshedAt: root.refreshedAt ? new Date(root.refreshedAt).toISOString() : null,
                nextInMin: Math.round((root.nextAt - Date.now()) / 60000), error: root.error });
        }
        function check(): void {
            root.check(false);
        }
        function refresh(): void {
            root.check(true);
        }
        function open(): void {
            root.openManager();
        }
        // zum Testen des Chips: n erfundene System-Updates (nicht gespeichert; nächste Prüfung überschreibt)
        function fake(n: int): void {
            const a = [];
            for (let i = 0; i < n; i++)
                a.push({ name: "example-" + (i + 1), version: "1.0", current: "0.9", repo: "updates", copr: "" });
            root.system = a;
        }
    }
}
