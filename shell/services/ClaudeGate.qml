pragma Singleton
import QtQuick
import Quickshell
import Quickshell.Io
import qs.config

// Offene Claude-Code-Rückfragen (Erlaubnis/Frage), die auf dem Desktop beantwortet werden können.
// Quelle: scripts/claude-gate (Hooks) legt sie in ~/.local/state/desktop/claude-pending/ ab und stempelt
// danach .changed; die Shell beobachtet nur den Stempel und holt die Liste per `claude-gate list`
// (das Skript räumt dabei Tote/Abgelaufene weg). Antworten gehen per `claude-gate decide` zurück.
// tool_input kann sensibel sein: hier wird nichts geloggt, die Dateien enthalten nur eine gekürzte Anzeige.
Singleton {
    id: root

    readonly property string gate: Config.repo + "/scripts/claude-gate"
    readonly property string dir: Quickshell.env("HOME") + "/.local/state/desktop/claude-pending"

    // [{ id, kind: "permission"|"question", session, agent, cwd, repo, project, tool, toolLabel,
    //    created, expires, detail, note, mono, canAlways, alwaysNote, questions }]
    property var list: []
    // schon beantwortet (lokal sofort ausblenden, bis das Skript die Datei wegräumt)
    property var answered: ({})
    readonly property var items: list.filter(e => !answered[e.id])
    readonly property int count: items.length

    // Projektfarben: theme/projects.json (Pfad → Farbname) + palette.json projectAccents (Name → Farbe)
    property var projects: []

    function refresh(): void {
        if (lister.running)
            again = true;
        else
            lister.running = true;
    }
    property bool again: false

    // decision: { behavior: "allow"|"deny"|"pass", always?: bool,
    //             answers?: { frage: label | eigener Text | [labels…, eigener Text] }, notes?: { frage: notiz } }
    function decide(id: string, decision: var): void {
        const a = Object.assign({}, answered);
        a[id] = true;
        answered = a;
        Quickshell.execDetached([gate, "decide", id, JSON.stringify(decision)]);
    }

    function byId(id: string): var {
        return list.find(e => e.id === id) ?? null;
    }

    function colorFor(entry: var): color {
        const accents = Theme.data.projectAccents || {};
        const home = Quickshell.env("HOME");
        const where = entry ? (entry.cwd || entry.repo || "") : "";
        let best = null;
        for (const p of projects) {
            const path = String(p.path || "").replace(/^~/, home);
            if (!path || path.endsWith(".code-workspace"))
                continue;
            if ((where === path || where.startsWith(path + "/")) && (!best || path.length > best.len))
                best = { len: path.length, color: p.color };
        }
        const c = !best ? "" : /^#[0-9a-f]{6}$/i.test(best.color || "") ? best.color : accents[best.color];
        return c ? c : Theme.woodLight;
    }

    // VS-Code-Fenster des Projekts nach vorn
    function open(entry: var): void {
        Context.activateCode(entry ? (entry.project || "") : "");
    }

    Process {
        id: lister
        command: [root.gate, "list"]
        stdout: StdioCollector {
            onStreamFinished: {
                let l = [];
                try {
                    l = JSON.parse(text || "[]");
                } catch (e) {
                    l = [];
                }
                root.list = Array.isArray(l) ? l : [];
                // erledigte Antworten vergessen, sobald die Datei weg ist
                const a = {};
                for (const id in root.answered)
                    if (root.list.some(e => e.id === id))
                        a[id] = true;
                root.answered = a;
            }
        }
        onExited: {
            if (root.again) {
                root.again = false;
                running = true;
            }
        }
    }

    // Ordner + Stempel anlegen, damit FileView von Anfang an etwas zu beobachten hat
    Process {
        id: prepare
        running: true
        command: ["sh", "-c", "mkdir -p -m 700 \"$1\" && { [ -e \"$1/.changed\" ] || echo 0 > \"$1/.changed\"; }", "sh", root.dir]
        onExited: {
            stamp.reload();
            root.refresh();
        }
    }

    FileView {
        id: stamp
        path: root.dir + "/.changed"
        watchChanges: true
        printErrors: false
        onFileChanged: {
            reload();
            root.refresh();
        }
    }

    FileView {
        path: Config.repo + "/theme/projects.json"
        watchChanges: true
        printErrors: false
        onFileChanged: reload()
        onLoaded: {
            try {
                root.projects = JSON.parse(text()).projects || [];
            } catch (e) {
                root.projects = [];
            }
        }
    }

    // Sicherheitsnetz: solange etwas offen ist, ab und zu nachsehen (abgelaufene/tote Hooks)
    Timer {
        interval: 3000
        repeat: true
        running: root.list.length > 0
        onTriggered: root.refresh()
    }

    // qs ipc --any-display -p ~/Workspace/desktop/shell call claudegate status
    IpcHandler {
        target: "claudegate"

        function status(): string {
            return JSON.stringify({ count: root.count, items: root.items.map(e => ({ id: e.id, kind: e.kind, project: e.project, tool: e.tool })) });
        }
        function refresh(): void {
            root.refresh();
        }
        // Test: Projektfarbe zu einem Ordner
        function color(cwd: string): string {
            return String(root.colorFor({ cwd: cwd })) + " (" + root.projects.length + " projects)";
        }
        // Test: neueste Karte zurück an VS Code geben
        function pass(): string {
            const e = root.items[root.items.length - 1];
            if (!e)
                return "none";
            root.decide(e.id, { behavior: "pass" });
            return e.id;
        }
    }
}
