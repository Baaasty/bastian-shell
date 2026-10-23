pragma Singleton
import QtQuick
import Quickshell
import Quickshell.Io

// Reiter „Server“ im Dev-Popout (DevPopout.qml): Web-Konsolen aus config/consoles.json und Server aus scripts/sshs.
// Doku: docs/knowledge/shell-features.md
// Konsolen: config/consoles.json (feste Liste), private Adressen in ~/.config/desktop/consoles.json (gleiche id ersetzt
// Felder), beide live gelesen. Öffnen wie die Ports im Dev-Popout (DevServices.openUrl).
// Liste: `sshs list --json` (liest nur die SSH-Konfiguration, verbindet nicht), zuletzt benutzte zuerst – sshs merkt sich
// das selbst (~/.local/state/sshs/recent.json), auch für Verbindungen aus dem Terminal.
// Aktionen:
//   terminal(name)  sshs <name>          eigenes Kitty-Fenster (Klasse sshs)
//   files(name)     sshs <name> --files  dasselbe Fenster, schaltet nach der Anmeldung auf Dateien (yazi per SFTP)
//   upload(name)    Datei-Wähler der Shell (mehrere, FilePicker.openFiles) → sshs put <name> ~ <dateien…> --notify
// Container: loadContainers(name) → sshs ps <name> --json (als Anmelde-Benutzer, BatchMode), Ergebnis in ps/psHost.
// sshs startet Kitty selbst über uwsm app; der Upload läuft in einer eigenen systemd-Scope (übersteht Shell-Neustarts),
// Fortschritt + Ergebnis meldet sshs als Benachrichtigung.
Singleton {
    id: root

    readonly property string sshs: Quickshell.shellDir + "/../scripts/sshs"
    readonly property string home: Quickshell.env("HOME")

    property var list: []               // [{name, host, user, port, last}]
    property bool ready: false
    property string error: ""
    // laufender Upload (nur einer gleichzeitig)
    property string upHost: ""
    property int upCount: 0
    property string note: ""            // letzte Rückmeldung (kurz im Popout)
    property string lastDir: home       // lokaler Ordner des letzten Uploads (Startordner des Wählers)
    readonly property bool uploading: upHost !== ""
    // Container (sshs ps): nur ein Server gleichzeitig
    property string psHost: ""
    property var ps: null               // {ok, user, engines, denied, groups:[{name, running, total, containers}], error}
    readonly property bool psLoading: psProc.running

    // ---------- Web-Konsolen ----------
    property var _baseConsoles: []
    property var _userConsoles: []
    readonly property var consoles: _baseConsoles.map(c => {
        const u = _userConsoles.find(x => x && x.id === c.id);
        return Object.assign({}, c, u || {});
    })
    function host(url: string): string {
        return String(url || "").replace(/^https?:\/\//, "").replace(/\/$/, "");
    }
    function openConsole(c: var): void {
        if (c && c.url)
            DevServices.openUrl(c.url);
    }
    function _consoles(t: string, which: string): var {
        try {
            const d = JSON.parse(t);
            return d && Array.isArray(d.consoles) ? d.consoles.filter(c => c && typeof c.id === "string") : [];
        } catch (e) {
            console.warn("servers: " + which + " is not valid JSON, ignoring it");
            return [];
        }
    }
    FileView {
        path: Quickshell.shellDir + "/../config/consoles.json"
        blockLoading: true
        watchChanges: true
        printErrors: false
        onFileChanged: reload()
        onLoaded: root._baseConsoles = root._consoles(text(), "config/consoles.json")
        onLoadFailed: root._baseConsoles = []
    }
    FileView {
        path: root.home + "/.config/desktop/consoles.json"
        blockLoading: true
        watchChanges: true
        printErrors: false
        onFileChanged: reload()
        onLoaded: root._userConsoles = root._consoles(text(), "~/.config/desktop/consoles.json")
        onLoadFailed: root._userConsoles = []
    }

    function refresh(): void {
        if (!lister.running)
            lister.running = true;
    }
    function where(s: var): string {
        return (s.user ? s.user + "@" : "") + s.host + (s.port && s.port !== 22 ? ":" + s.port : "");
    }
    // „vor 5 min“ als „5m ago“ (englische Oberfläche)
    function ago(ts: int): string {
        if (!ts)
            return "";
        const s = Math.max(0, Math.floor(Date.now() / 1000) - ts);
        if (s < 60)
            return "just now";
        if (s < 3600)
            return Math.floor(s / 60) + "m ago";
        if (s < 86400)
            return Math.floor(s / 3600) + "h ago";
        return Math.floor(s / 86400) + "d ago";
    }
    // gleich oben einsortieren, ohne auf die nächste Liste zu warten
    function touch(name: string): void {
        const now = Math.floor(Date.now() / 1000);
        list = list.map(s => s.name === name ? Object.assign({}, s, { last: now }) : s).sort((a, b) => b.last - a.last);
    }

    function terminal(name: string): void {
        touch(name);
        Launch.cmd([sshs, name]);
    }
    function files(name: string): void {
        touch(name);
        Launch.cmd([sshs, name, "--files"]);
    }
    function loadContainers(name: string): void {
        if (psHost !== name)
            ps = null;
        psHost = name;
        if (psProc.running)
            return;
        psProc.host = name;
        psProc.command = [sshs, "ps", name, "--json"];
        psProc.running = true;
    }
    function upload(name: string): void {
        if (uploading) {
            flash("Upload to " + upHost + " still running");
            return;
        }
        FilePicker.openFiles(lastDir, [], paths => {
            if (!paths.length)
                return;
            const p = paths[0];
            const i = p.lastIndexOf("/");
            if (i > 0)
                lastDir = p.slice(0, i);
            put(name, "~", paths);
        }, { title: "Upload to " + name, action: "Upload" });
    }
    function put(name: string, dir: string, paths: var): void {
        touch(name);
        upHost = name;
        upCount = paths.length;
        note = "";
        uploader.command = Launch.scope.concat([sshs, "put", name, dir].concat(paths).concat(["--notify"]));
        uploader.running = true;
    }
    function flash(text: string): void {
        note = text;
        noteTimer.restart();
    }

    Process {
        id: lister
        command: [root.sshs, "list", "--json"]
        stdout: StdioCollector {
            onStreamFinished: {
                try {
                    const d = JSON.parse(text || "[]");
                    root.list = Array.isArray(d) ? d : [];
                    root.error = "";
                } catch (e) {
                    root.error = "sshs list failed";
                }
                root.ready = true;
            }
        }
        onExited: code => {
            if (code !== 0) {
                root.error = "sshs list failed (" + code + ")";
                root.ready = true;
            }
        }
    }
    Process {
        id: uploader
        stdout: StdioCollector {}
        stderr: StdioCollector {}
        onExited: code => {
            root.flash(code === 0 ? "Uploaded " + root.upCount + (root.upCount === 1 ? " item" : " items") + " to " + root.upHost
                : "Upload to " + root.upHost + " failed");
            root.upHost = "";
            root.upCount = 0;
        }
    }
    Process {
        id: psProc
        property string host: ""
        stdout: StdioCollector {
            onStreamFinished: {
                if (psProc.host !== root.psHost)
                    return;               // inzwischen anderer Server gewählt
                try {
                    root.ps = JSON.parse(text);
                } catch (e) {
                    root.ps = { ok: false, error: "sshs ps failed" };
                }
            }
        }
    }
    Timer {
        id: noteTimer
        interval: 8000
        onTriggered: root.note = ""
    }

    Component.onCompleted: refresh()
}
