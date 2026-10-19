pragma Singleton
import QtQuick
import Quickshell
import Quickshell.Io

// Dateisuche für den Launcher (Präfix /): Workspace, Dokumente, Downloads, Bilder, iCloud Drive.
// Bewusst ohne Index: find mit Tiefenlimit, ohne node_modules/.git/refs, max. 40 Treffer.
Singleton {
    id: root

    property var results: []   // [{ name, path, rel, dir }]
    property string _pending: ""
    readonly property string home: Quickshell.env("HOME")

    function search(term: string): void {
        _pending = term;
        debounce.restart();
    }

    Timer {
        id: debounce
        interval: 180
        onTriggered: {
            const t = root._pending.trim();
            if (t.length < 2) {
                root.results = [];
                return;
            }
            finder.running = false;
            finder.command = ["sh", "-c",
                "cd \"$HOME\" && find Workspace Documents Downloads Pictures Data/iCloud/Drive -maxdepth 6 " +
                "\\( -name node_modules -o -name .git -o -name refs -o -name .cache \\) -prune -o " +
                "-iname \"*$1*\" -print 2>/dev/null | head -40", "sh", t];
            finder.running = true;
        }
    }

    Process {
        id: finder
        stdout: StdioCollector {
            onStreamFinished: root.results = text.split("\n").filter(l => l).map(rel => ({
                name: rel.split("/").pop(),
                path: root.home + "/" + rel,
                rel: "~/" + rel.split("/").slice(0, -1).join("/")
            }))
        }
    }

    function open(path: string): void {
        Launch.cmd(["xdg-open", path]);
    }
}
