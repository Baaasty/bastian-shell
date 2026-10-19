pragma Singleton
import QtQuick
import Quickshell
import Quickshell.Io

// Git-Repos in ~/Workspace (Tiefe 4, ohne node_modules/refs) + VS-Code-Workspaces (*.code-workspace,
// mehrere Ordner zusammen, Tiefe 2), alle 10 min neu eingelesen. Workspaces stehen vorn.
// Öffnen immer über openTarget(): Repos mit eingecheckter .vscode/settings.json haben einen zentralen
// Arbeitsbereich ~/.config/desktop/workspaces/<name>.code-workspace (scripts/vscode-colors, „wrapper“) –
// nur so bekommt VS Code dort die Projekt-Tönung, ohne das Repo anzufassen.
Singleton {
    id: root

    property var list: []   // [{ name, path, rel, workspace }]
    readonly property string base: Quickshell.env("HOME") + "/Workspace"
    // Repo-Pfad -> Wrapper-Datei (aus workspaces/index.json, geschrieben von scripts/vscode-colors)
    property var wrappers: ({})
    // Wrapper-Name (Titel „… - <name> (Workspace) - Visual Studio Code“) -> Projektname (Repo-Ordner)
    property var wrapperNames: ({})
    // Desktop-Einstellungen pro Projekt (projects/projects.json, nur lesen – schreiben: scripts/project)
    property var settings: ({})
    readonly property var globalLinks: _global.links || []
    property var _global: ({})

    // projects.json ist lokal (gitignored); fehlt sie, gilt projects.example.json aus dem Repo
    property bool _localMissing: false
    property var _example: null
    function _apply(j: var): void {
        root.settings = (j && j.projects) || {};
        root._global = (j && j.global) || {};
    }

    FileView {
        path: Quickshell.shellDir + "/../projects/projects.json"
        watchChanges: true
        printErrors: false
        onFileChanged: reload()
        onLoadFailed: {
            root._localMissing = true;
            root._apply(root._example);
        }
        onLoaded: {
            try {
                const j = JSON.parse(text() || "{}");
                root._localMissing = false;
                root._apply(j);
            } catch (e) {
                console.warn("projects/projects.json: " + e);
            }
        }
    }

    FileView {
        path: Quickshell.shellDir + "/../projects/projects.example.json"
        printErrors: false
        onLoaded: {
            try {
                root._example = JSON.parse(text() || "{}");
                if (root._localMissing)
                    root._apply(root._example);
            } catch (e) {
                console.warn("projects/projects.example.json: " + e);
            }
        }
    }

    // Einstellungen zu einem Pfad (Repo, *.code-workspace oder Ordner darin; längster Treffer) – sonst null.
    // Ergebnis: Eintrag aus projects.json + id
    function settingsFor(path: string): var {
        const home = Quickshell.env("HOME");
        const p = String(path || "").replace(/^~(?=\/)/, home).replace(/\/+$/, "");
        let best = null, len = -1;
        for (const id in settings) {
            const e = settings[id];
            for (const t of (e.workspace ? [e.workspace] : []).concat(e.paths || [])) {
                const a = String(t).replace(/^~(?=\/)/, home);
                if ((p === a || p.startsWith(a + "/")) && a.length > len) {
                    best = Object.assign({ id: id }, e);
                    len = a.length;
                }
            }
        }
        return best;
    }

    // Browser-Ziele beim Öffnen: open.browser (Port-Namen aus dev.ports oder URLs); ohne Angabe der erste Port
    function browserUrls(s: var): var {
        if (!s)
            return [];
        const ports = (s.dev && s.dev.ports) || {};
        const want = s.open && s.open.browser ? s.open.browser : Object.keys(ports).slice(0, 1);
        return want.map(b => /^[a-z]+:\/\//.test(b) ? b : (ports[b] ? "http://localhost:" + ports[b] : "")).filter(u => u);
    }

    FileView {
        path: Quickshell.env("HOME") + "/.config/desktop/workspaces/index.json"
        watchChanges: true
        printErrors: false
        onFileChanged: reload()
        onLoadFailed: {
            root.wrappers = {};
            root.wrapperNames = {};
        }
        onLoaded: {
            const w = {};
            const n = {};
            try {
                const j = JSON.parse(text() || "{}");
                for (const k in j) {
                    if (!j[k] || !j[k].file)
                        continue;
                    w[k] = j[k].file;
                    n[j[k].file.split("/").pop().replace(/\.code-workspace$/, "")] = k.split("/").pop();
                }
            } catch (e) {
                console.warn("workspaces/index.json: " + e);
            }
            root.wrappers = w;
            root.wrapperNames = n;
        }
    }

    Process {
        id: scan
        command: ["sh", "-c", "find \"$HOME/Workspace\" -maxdepth 2 -name '*.code-workspace' -not -path '*/node_modules/*' 2>/dev/null | sort; "
            + "find \"$HOME/Workspace\" -maxdepth 4 -name .git -not -path '*/node_modules/*' -not -path '*/refs/*' -printf '%h\\n' 2>/dev/null | sort"]
        stdout: StdioCollector {
            onStreamFinished: root.list = text.trim().split("\n").filter(p => p).map(p => {
                const ws = p.endsWith(".code-workspace");
                return {
                    name: p.split("/").pop().replace(/\.code-workspace$/, ""),
                    path: p,
                    rel: p.replace(root.base + "/", "~/Workspace/"),
                    workspace: ws
                };
            })
        }
    }

    Timer {
        interval: 600000
        repeat: true
        running: true
        triggeredOnStart: true
        onTriggered: scan.running = true
    }

    // Was VS Code öffnen soll: Wrapper-Arbeitsbereich, wenn es einen gibt, sonst der Pfad selbst
    function openTarget(path: string): string {
        const p = String(path || "").replace(/^~(?=\/)/, Quickshell.env("HOME")).replace(/\/+$/, "");
        return wrappers[p] ?? path;
    }

    function open(path: string): void {
        Launch.code([openTarget(path)]);
    }
}
