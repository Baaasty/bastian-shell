pragma Singleton
import QtQuick
import Quickshell
import Quickshell.Io

// Letzte Downloads für das Downloads-Popout (Rechtsklick auf den Dateimanager-Chip: FilesChip/DownloadsPopout).
// Liest ~/Downloads (nur oberste Ebene, ohne versteckte Dateien) nach Änderungszeit; neu gelesen nur bei Ereignissen
// (inotifywait, kein Dauer-Polling). Halbfertige Downloads (.part = Firefox, .crdownload = Chrome/Brave) zählen als „lädt…“,
// ihre Größe wird nur bei offenem Popout alle 1,5 s nachgelesen.
// Aufräumen: Einträge älter als N Tage per `gio trash` in den Papierkorb (nie löschen), nur nach Bestätigung im Popout.
// Einstellungen (optional): ~/.config/desktop/downloads.json  { "dir": "~/Downloads", "count": 12, "cleanupDays": 30 }
// Doku: docs/knowledge/shell-features.md
Singleton {
    id: root

    readonly property string home: Quickshell.env("HOME")
    property var cfg: ({})
    property string testDir: ""          // nur IPC-Test (nicht gespeichert)
    readonly property string dir: testDir !== "" ? testDir : String(cfg.dir || "~/Downloads").replace(/^~(?=\/|$)/, home)
    readonly property int count: cfg.count || 12
    readonly property int cleanupDays: cfg.cleanupDays || 30

    // alle Einträge, neueste zuerst: [{ name, path, size, mtime (ms), dir, loading, ext }]
    property var items: []
    readonly property var recent: items.slice(0, count)
    readonly property bool loading: items.some(i => i.loading)
    property bool ready: false

    // „neu“: ein Download ist fertig geworden, seit das Popout zuletzt offen war (für 15 min auffällig)
    property real freshAt: 0
    property string freshName: ""
    property real _now: Date.now()
    readonly property bool fresh: freshAt > 0 && _now - freshAt < 15 * 60000
    property bool active: false          // Popout offen -> Größen laufender Downloads nachlesen
    property var _pending: ({})          // Namen aus Ereignissen, die fertig sein könnten

    readonly property var partialRe: /\.(part|crdownload|download|partial)$/i

    function seen(): void {
        freshAt = 0;
        freshName = "";
    }

    function refresh(): void {
        lister.running = false;
        lister.running = true;
    }

    // Öffnen/Zeigen laufen nie als Kind der Shell (Launch.cmd)
    function open(path: string): void {
        Launch.cmd(["xdg-open", path]);
    }
    function showInFolder(path: string): void {
        // Dateimanager per D-Bus (FileManager1, z. B. Dolphin) – markiert die Datei; sonst Ordner öffnen
        Launch.cmd(["sh", "-c", "gdbus call --session --dest org.freedesktop.FileManager1 --object-path /org/freedesktop/FileManager1 " +
            "--method org.freedesktop.FileManager1.ShowItems \"['$1']\" '' >/dev/null 2>&1 || xdg-open \"$2\"",
            "sh", uri(path), path.replace(/\/[^\/]*$/, "")]);
    }
    function openFolder(): void {
        Launch.cmd(["sh", "-c", "gdbus call --session --dest org.freedesktop.FileManager1 --object-path /org/freedesktop/FileManager1 " +
            "--method org.freedesktop.FileManager1.ShowFolders \"['$1']\" '' >/dev/null 2>&1 || xdg-open \"$2\"",
            "sh", uri(dir), dir]);
    }
    function uri(path: string): string {
        return "file://" + path.split("/").map(s => encodeURIComponent(s).replace(/'/g, "%27")).join("/");
    }

    // Kandidaten fürs Aufräumen: älter als days Tage, nichts, was gerade lädt
    function oldItems(days: int): var {
        const cut = Date.now() - days * 86400000;
        return items.filter(i => !i.loading && i.mtime < cut);
    }
    property bool trashing: false
    property string note: ""
    function trashOld(days: int): void {
        const old = oldItems(days);
        if (!old.length || trashing)
            return;
        trashing = true;
        trashProc.n = old.length;
        trashProc.command = ["gio", "trash", "--"].concat(old.map(i => i.path));
        trashProc.running = true;
    }

    function fmtSize(b: real): string {
        if (b < 1024)
            return b + " B";
        const u = ["KB", "MB", "GB", "TB"];
        let i = -1;
        do {
            b /= 1024;
            i++;
        } while (b >= 1024 && i < u.length - 1);
        return (b >= 100 ? Math.round(b) : b.toFixed(1)) + " " + u[i];
    }
    function fmtAge(ms: real): string {
        const s = Math.max(0, (_now - ms) / 1000);
        if (s < 60)
            return "just now";
        if (s < 3600)
            return Math.floor(s / 60) + " min ago";
        if (s < 86400)
            return Math.floor(s / 3600) + " h ago";
        const d = Math.floor(s / 86400);
        if (d === 1)
            return "yesterday";
        if (d < 30)
            return d + " days ago";
        return new Date(ms).toLocaleDateString(Qt.locale("en_GB"), "d MMM yyyy");
    }
    // Material-Symbol je Dateityp
    function glyph(it: var): string {
        if (it.dir)
            return "folder";
        const e = it.ext;
        if (["png", "jpg", "jpeg", "gif", "webp", "avif", "svg", "heic", "bmp"].includes(e)) return "image";
        if (["mp4", "mkv", "webm", "mov", "avi"].includes(e)) return "movie";
        if (["mp3", "flac", "ogg", "wav", "m4a", "opus"].includes(e)) return "music_note";
        if (["zip", "tar", "gz", "xz", "zst", "7z", "rar", "bz2", "tgz"].includes(e)) return "folder_zip";
        if (e === "pdf") return "picture_as_pdf";
        if (["rpm", "flatpakref", "flatpak", "appimage", "deb"].includes(e)) return "deployed_code";
        if (["sh", "py", "js", "ts", "json", "toml", "yaml", "yml", "conf", "qml"].includes(e)) return "code";
        if (["iso", "img", "raw"].includes(e)) return "album";
        if (["txt", "md", "doc", "docx", "odt", "rtf", "csv", "xlsx", "ods"].includes(e)) return "description";
        return "draft";
    }

    function _parse(text: string): void {
        const raw = text.split("\0").filter(l => l).map(l => {
            const p = l.split("\t");
            const name = p.slice(3).join("\t");
            return { name: name, mtime: parseFloat(p[0]) * 1000, size: parseInt(p[1]) || 0, dir: p[2] === "d" };
        });
        // Firefox legt beim Start eine leere Datei mit dem Endnamen an + "<name>.part": die leere nicht doppelt zeigen
        const parts = new Set(raw.filter(r => partialRe.test(r.name)).map(r => r.name.replace(partialRe, "")));
        const list = [];
        for (const r of raw) {
            const isPart = partialRe.test(r.name);
            if (!isPart && !r.dir && r.size === 0 && parts.has(r.name))
                continue;
            const shown = isPart ? r.name.replace(partialRe, "") : r.name;
            const m = /\.([^.\/]+)$/.exec(shown);
            list.push({ name: shown, file: r.name, path: dir + "/" + r.name, size: r.size, mtime: r.mtime, dir: r.dir,
                loading: isPart, ext: m && !r.dir ? m[1].toLowerCase() : "" });
        }
        list.sort((a, b) => b.mtime - a.mtime);
        // fertig gewordene Downloads aus den Ereignissen
        for (const n in _pending) {
            const it = list.find(i => i.file === n);
            if (it && !it.loading && !it.dir && it.size > 0 && !parts.has(n)) {
                freshAt = Date.now();
                freshName = it.name;
            }
        }
        _pending = {};
        items = list;
        ready = true;
    }

    Process {
        id: lister
        // \0-getrennt (Namen dürfen alles außer / enthalten); -L: Symlinks wie ihr Ziel
        command: ["find", "-L", root.dir, "-mindepth", "1", "-maxdepth", "1", "!", "-name", ".*", "-printf", "%T@\\t%s\\t%y\\t%f\\0"]
        stdout: StdioCollector {
            onStreamFinished: root._parse(text)
        }
    }

    // Ereignisse im Ordner (nur Anlegen/Umbenennen/Löschen/Fertigschreiben, keine Schreib-Ereignisse)
    Process {
        id: watcher
        running: root.dir !== ""
        command: ["inotifywait", "-m", "-q", "-e", "create,moved_to,moved_from,delete,close_write", "--format", "%e\t%f", root.dir]
        stdout: SplitParser {
            onRead: line => {
                const p = line.split("\t");
                const ev = p[0], name = p.slice(1).join("\t");
                if (/MOVED_TO|CLOSE_WRITE/.test(ev) && !root.partialRe.test(name) && !name.startsWith(".")) {
                    const m = Object.assign({}, root._pending);
                    m[name] = true;
                    root._pending = m;
                }
                debounce.restart();
            }
        }
        // inotifywait beendet (Ordner weg o. ä.): später erneut
        onExited: retry.restart()
    }
    Timer {
        id: retry
        interval: 30000
        onTriggered: {
            watcher.running = true;
            root.refresh();
        }
    }
    Timer {
        id: debounce
        interval: 400
        onTriggered: root.refresh()
    }
    // laufende Downloads: Größe nachlesen, nur bei offenem Popout
    Timer {
        interval: 1500
        repeat: true
        running: root.active && root.loading
        onTriggered: root.refresh()
    }
    // „vor x min“ und Ablauf von „neu“
    Timer {
        interval: 30000
        repeat: true
        running: true
        onTriggered: root._now = Date.now()
    }
    onActiveChanged: {
        _now = Date.now();
        if (active)
            refresh();
    }

    Process {
        id: trashProc
        property int n: 0
        stderr: StdioCollector {
            id: trashErr
        }
        onExited: code => {
            root.trashing = false;
            root.note = code === 0 ? "Moved " + n + (n === 1 ? " item" : " items") + " to the trash"
                                   : "Trash failed: " + (trashErr.text.trim().split("\n").pop() || "code " + code);
            noteClear.restart();
            root.refresh();
        }
    }
    Timer {
        id: noteClear
        interval: 6000
        onTriggered: root.note = ""
    }

    FileView {
        path: Quickshell.env("HOME") + "/.config/desktop/downloads.json"
        printErrors: false
        watchChanges: true
        onFileChanged: reload()
        onLoaded: {
            try {
                root.cfg = JSON.parse(text()) || {};
            } catch (e) {
                root.cfg = {};
            }
        }
        onLoadFailed: root.cfg = {}
    }

    // erst nach dem Umbinden der Befehle (sonst liest find noch den alten Ordner)
    onDirChanged: Qt.callLater(() => {
        watcher.running = false;
        watcher.running = true;
        refresh();
    })
    Component.onCompleted: refresh()
}
