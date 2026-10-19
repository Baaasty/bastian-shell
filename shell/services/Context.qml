pragma Singleton
import QtQuick
import Quickshell
import Quickshell.Io

// Automatischer Kontext: Projekt aus dem VS-Code-Fenstertitel ("datei — projekt — Visual Studio Code",
// bei Arbeitsbereichen "… — projekt (Workspace) — …", Wrapper-Namen über Projects.wrapperNames),
// dazu Branch und Anzahl Änderungen per git. Neu bei Fokuswechsel und alle 30 s.
Singleton {
    id: root

    property string project: ""
    property string path: ""
    property string branch: ""
    property int changes: 0
    readonly property bool valid: project !== ""
    // alle Projekte mit offenem VS-Code-Fenster (Namen) + Projekt des gerade aktiven VS-Code-Fensters ("" = anderes Fenster)
    property var openProjects: []
    property string activeProject: ""

    // Projektname aus dem Titel: vorletzter Teil vor "Visual Studio Code"
    function parseTitle(title: string): string {
        const parts = (title || "").split(/\s+[—–-]\s+/).map(p => p.trim()).filter(p => p);
        if (parts.length < 2 || !/Visual Studio Code/.test(parts[parts.length - 1]))
            return "";
        let name = parts[parts.length - 2].replace(/^[●•]\s*/, "");
        name = name.replace(/\s*\[[^\]]*\]$/, "");
        // Arbeitsbereich „<name> (Workspace)“: Wrapper aus scripts/vscode-colors -> Projektname des Repos
        const ws = /\s*\((Workspace|Arbeitsbereich)\)$/;
        if (ws.test(name)) {
            name = name.replace(ws, "");
            name = Projects.wrapperNames[name] ?? name;
        }
        return name;
    }
    // VS-Code-Fenster: Flatpak "com.visualstudio.code(.desktop)", natives RPM "com.microsoft.VSCode(.desktop)"
    // (ältere RPMs: "code" / "code-url-handler"), jeweils auch die URL-Handler-Variante
    function isCode(appId: string): bool {
        return /^(com\.visualstudio\.code|com\.microsoft\.vscode|code)([.-]url-?handler)?(\.desktop)?$/i.test(appId || "");
    }

    // VS-Code-Fenster (alle Desktops/Bildschirme) als { t, active, title, appId }; neu nur, wenn sich
    // bei VS Code etwas ändert (Titel anderer Fenster wie Terminals lösen nichts aus)
    property var windows: []
    property string _key: ""
    function collect(): void {
        const out = [];
        let key = "";
        for (const t of Hypr.toplevels.values) {
            const appId = Hypr.appId(t);
            if (!isCode(appId))
                continue;
            const active = Hypr.isActive(t);
            const w = { t: t, active: active, title: Hypr.title(t), appId: appId };
            out.push(w);
            key += appId + "|" + w.title + "|" + active + "\n";
        }
        windows = out;
        if (key !== _key) {
            _key = key;
            debounce.restart();
        }
    }
    Connections {
        target: Hypr
        function onVersionChanged() { root.collect(); }
    }
    Component.onCompleted: collect()

    // Fokus wechselt oft in Schüben: kurz sammeln
    Timer {
        id: debounce
        interval: 400
        onTriggered: root.refresh()
    }
    Timer {
        interval: 30000
        repeat: true
        running: true
        onTriggered: root.refresh()
    }

    function refresh(): void {
        let name = "";
        let first = "";
        const open = [];
        for (const w of windows) {
            const p = parseTitle(w.title);
            if (p)
                open.push(p);
            if (w.active)
                name = p;
        }
        // anderes Fenster aktiv: letztes VS-Code-Projekt bleibt, solange es noch offen ist,
        // sonst irgendein offenes VS-Code-Projekt
        const uniq = open.filter((p, i) => open.indexOf(p) === i);
        if (uniq.join("\n") !== openProjects.join("\n"))
            openProjects = uniq;
        activeProject = name;
        if (!name)
            name = open.includes(project) ? project : (open[0] ?? "");
        const proj = name ? findProject(name) : null;
        if (!proj) {
            project = name;
            path = "";
            branch = "";
            changes = 0;
            return;
        }
        project = proj.name;
        path = proj.path;
        if (!git.running) {
            // --no-optional-locks: status schreibt sonst den Index neu und hält .git/index.lock – parallele
            // git-Befehle im Projekt (Claude, Bastian) scheiterten dann alle 30 s mit „index.lock exists“
            git.command = ["git", "--no-optional-locks", "-C", proj.path, "status", "--porcelain", "-b"];
            git.running = true;
        }
    }

    function findProject(name: string): var {
        const list = Projects.list;
        const lower = name.toLowerCase();
        return list.find(p => p.name === name) ?? list.find(p => p.name.toLowerCase() === lower) ?? null;
    }

    Process {
        id: git
        stdout: StdioCollector {
            onStreamFinished: {
                const lines = text.split("\n").filter(l => l);
                const head = lines.length && lines[0].startsWith("## ") ? lines.shift().slice(3) : "";
                // "main...origin/main [ahead 1]" | "No commits yet on main" | "HEAD (no branch)"
                let b = head.split("...")[0].split(" [")[0];
                b = b.replace(/^No commits yet on /, "").replace(/^Initial commit on /, "");
                root.branch = b === "HEAD (no branch)" ? "detached" : b;
                root.changes = lines.length;
            }
        }
    }

    // Projektliste kommt asynchron: danach einmal neu zuordnen
    Connections {
        target: Projects
        function onListChanged() {
            debounce.restart();
        }
        function onWrapperNamesChanged() {
            debounce.restart();
        }
    }

    // hat das Projekt ein eigenes VS-Code-Fenster?
    function hasWindow(name: string): bool {
        return !!name && openProjects.includes(name);
    }

    // VS Code nach vorn holen, bevorzugt das Fenster mit dem Projekt im Titel
    function activateCode(name: string): bool {
        let fallback = null;
        for (const w of windows) {
            if (name && parseTitle(w.title) === name) {
                Hypr.activate(w.t);
                return true;
            }
            if (!fallback)
                fallback = w.t;
        }
        if (fallback) {
            Hypr.activate(fallback);
            return true;
        }
        return false;
    }

    IpcHandler {
        target: "context"

        function status(): string {
            const ws = [];
            for (const w of root.windows)
                ws.push({ appId: w.appId, active: w.active, project: root.parseTitle(w.title) });
            return JSON.stringify({ project: root.project, path: root.path, branch: root.branch, changes: root.changes, code: ws });
        }
        function activate(name: string): string {
            return root.activateCode(name) ? "ok" : "no VS Code window";
        }
    }
}
