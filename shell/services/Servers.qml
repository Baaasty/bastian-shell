pragma Singleton
import QtQuick
import Quickshell
import Quickshell.Io

// Server aus scripts/sshs für den Server-Chip in der Bar (ServerChip/ServerPopout). Doku: docs/SSHS.md
// Liste: `sshs list --json` (liest nur die SSH-Konfiguration, verbindet nicht), zuletzt benutzte zuerst – sshs merkt sich
// das selbst (~/.local/state/sshs/recent.json), auch für Verbindungen aus dem Terminal.
// Aktionen:
//   terminal(name)  sshs <name>          eigenes Kitty-Fenster (Klasse sshs)
//   files(name)     sshs <name> --files  dasselbe Fenster, schaltet nach der Anmeldung auf Dateien (yazi per SFTP)
//   upload(name)    Datei-Wähler der Shell (mehrere, FilePicker.openFiles) → sshs put <name> ~ <dateien…> --notify
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
    Timer {
        id: noteTimer
        interval: 8000
        onTriggered: root.note = ""
    }

    Component.onCompleted: refresh()
}
