pragma Singleton
import QtQuick
import Quickshell
import Quickshell.Io

// Zwischenablage-Historie über cliphist (lokal, kein Sync). Bilder mit Vorschau, Favoriten (angepinnt).
Singleton {
    id: root

    property var entries: []   // [{ id, text, image, w, h }]
    property var pins: []      // angepinnte Texte
    readonly property string thumbDir: Quickshell.env("XDG_RUNTIME_DIR") + "/desktop-clip"
    property int thumbsVersion: 0   // zählt hoch, wenn Vorschaubilder fertig sind

    // Wächter: speichert jede neue Kopie
    Process {
        id: watcher
        running: true
        command: ["wl-paste", "--watch", "cliphist", "-max-items", "300", "store"]
        onRunningChanged: if (running) root._startedAt = Date.now()
        // neu starten – bei Fehlstarts mit wachsender Pause (3, 6, 12, 24 s), nach 5 in Folge 10 min Ruhe
        onExited: {
            root._fails = Date.now() - root._startedAt > 60000 ? 1 : root._fails + 1;
            if (root._fails >= 5) {
                console.warn("Clipboard: wl-paste --watch keeps exiting, pausing for 10 min");
                root._fails = 0;
                restart.interval = 10 * 60 * 1000;
            } else {
                restart.interval = 3000 * Math.pow(2, root._fails - 1);
            }
            restart.start();
        }
    }
    property int _fails: 0
    property real _startedAt: 0
    Timer {
        id: restart
        interval: 3000
        onTriggered: watcher.running = true
    }

    Process {
        id: lister
        command: ["cliphist", "list"]
        stdout: StdioCollector {
            onStreamFinished: {
                const list = text.split("\n").filter(l => l).slice(0, 100).map(l => {
                    const tab = l.indexOf("\t");
                    const t = l.slice(tab + 1);
                    const m = /^\[\[ binary data .* (png|jpeg|jpg|webp|bmp|gif) (\d+)x(\d+) \]\]$/.exec(t);
                    return { id: l.slice(0, tab), text: t, image: m ? m[1] : "", w: m ? +m[2] : 0, h: m ? +m[3] : 0 };
                });
                root.entries = list;
                const imgs = list.filter(e => e.image).map(e => e.id).join(" ");
                if (imgs) {
                    thumbs.command = ["sh", "-c", "mkdir -p \"$0\" && for id in $1; do [ -s \"$0/$id\" ] || cliphist decode \"$id\" > \"$0/$id\"; done", root.thumbDir, imgs];
                    thumbs.running = true;
                }
            }
        }
    }

    Process {
        id: thumbs
        onExited: root.thumbsVersion++
    }

    function refresh(): void {
        lister.running = true;
    }
    function thumb(id: string): string {
        return "file://" + thumbDir + "/" + id;
    }

    function copy(id: string): void {
        if (/^\d+$/.test(id))
            Quickshell.execDetached(["sh", "-c", "cliphist decode " + id + " | wl-copy"]);
    }
    function copyText(text: string): void {
        Quickshell.execDetached(["wl-copy", text]);
    }
    function remove(id: string): void {
        if (!/^\d+$/.test(id))
            return;
        Quickshell.execDetached(["sh", "-c", "printf '" + id + "\\t\\n' | cliphist delete"]);
        entries = entries.filter(e => e.id !== id);
    }

    // Favoriten
    function isPinned(text: string): bool {
        return pins.indexOf(text) >= 0;
    }
    function togglePin(text: string): void {
        pins = isPinned(text) ? pins.filter(p => p !== text) : [text].concat(pins);
        pinFile.setText(JSON.stringify(pins));
    }
    FileView {
        id: pinFile
        path: Quickshell.env("HOME") + "/.local/state/desktop/clip-pins.json"
        printErrors: false
        onLoaded: {
            try {
                root.pins = JSON.parse(text());
            } catch (e) {}
        }
    }
}
