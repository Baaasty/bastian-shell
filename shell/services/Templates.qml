pragma Singleton
import QtQuick
import Quickshell
import Quickshell.Io

// Desktop-Vorlagen aus profiles/profiles.json: neuer benannter Desktop, Apps starten,
// vorhandene Fenster (z. B. Spotify, Discord) herüberholen. Monitor-Platzierung kommt mit R12.
Singleton {
    id: root

    property var list: []

    // profiles.json ist lokal (gitignored); fehlt sie, gilt profiles.example.json aus dem Repo
    property bool _localMissing: false
    property var _example: []

    FileView {
        path: Quickshell.shellDir + "/../profiles/profiles.json"
        watchChanges: true
        printErrors: false
        onFileChanged: reload()
        onLoadFailed: {
            root._localMissing = true;
            root.list = root._example;
        }
        onLoaded: {
            try {
                const j = JSON.parse(text());
                root._localMissing = false;
                root.list = j.templates || [];
            } catch (e) {
                console.warn("profiles.json: " + e);
            }
        }
    }

    FileView {
        path: Quickshell.shellDir + "/../profiles/profiles.example.json"
        printErrors: false
        onLoaded: {
            try {
                root._example = JSON.parse(text()).templates || [];
                if (root._localMissing)
                    root.list = root._example;
            } catch (e) {
                console.warn("profiles.example.json: " + e);
            }
        }
    }

    function home(path) {
        return path.replace(/^~/, Quickshell.env("HOME"));
    }

    // Projekt-Desktop (z. B. "my-app"): VS Code mit dem Ordner bzw. seinem Wrapper-Arbeitsbereich (Mitte) + Helium Live-Preview
    // (rechts, per Fensterregel). Was aufgeht, steht in projects/projects.json (open, dev.ports; scripts/project):
    // Helium nur, wenn ein Port bzw. eine URL bekannt ist. Dev-Server startet nicht von selbst (open.terminal: dev|shell|null).
    // Terminal/Dev-Server laufen im integrierten Terminal von VS Code (unteres Panel), nie in einem eigenen Fenster:
    // vor dem VS-Code-Start eine Einmal-Marke ~/.cache/desktop/open-terminal/<id>.json, die Erweiterung
    // „Desktop Projekte“ (theme/gen/vscode.py) öffnet damit im passenden Fenster das Terminal und löscht sie.
    function openProject(path: string, name: string): void {
        const s = Projects.settingsFor(path);
        const o = (s && s.open) || {};
        const urls = Projects.browserUrls(s);
        // Terminal im Haupt-Repo (bei einem *.code-workspace dessen erstes Repo)
        const dir = home(path.endsWith(".code-workspace") && s && s.paths && s.paths.length ? s.paths[0] : path);
        const target = Projects.openTarget(path);
        const term = o.terminal === "shell" ? { name: "shell", command: null }
            : o.terminal === "dev" && s.dev && s.dev.command ? { name: "dev", command: (s.dev.services ? s.dev.services + " && " : "") + s.dev.command }
            : null;
        Desktops.add(name, desktopId => {
            if (term && o.code === false)
                console.warn("Projekt " + s.id + ": open.terminal braucht VS Code (open.code ist aus) – kein Terminal");
            else if (term)
                terminalMark(s.id, { dir: dir, target: home(target), command: term.command, name: term.name, created: Date.now() });
            if (o.code !== false)
                Launch.code(["--new-window", target]);
            if (urls.length)
                Launch.cmd(["helium", "--new-window"].concat(urls));
        });
    }

    // Marke atomar schreiben (Ordner 700, Datei 600). Ohne Erweiterung (keine extension.js mit „open-terminal“):
    // nichts starten, nur leise Meldung + Log.
    function terminalMark(id: string, mark: var): void {
        const marks = Quickshell.env("HOME") + "/.cache/desktop/open-terminal";
        const file = String(id).replace(/[^A-Za-z0-9._-]/g, "_").replace(/^\.+/, "") || "projekt";
        Quickshell.execDetached(["sh", "-c",
            "umask 077; mkdir -p \"$1\" && chmod 700 \"$1\" && printf '%s\\n' \"$3\" > \"$1/.$2.tmp\" && mv -f \"$1/.$2.tmp\" \"$1/$2.json\" || exit 1\n"
            + "for e in \"$HOME\"/.vscode/extensions/desktop.desktop-projects-*/extension.js "
            + "\"$HOME\"/.var/app/com.visualstudio.code/data/vscode/extensions/desktop.desktop-projects-*/extension.js; do\n"
            + "  [ -f \"$e\" ] && grep -q open-terminal \"$e\" && exit 0\n"
            + "done\n"
            + "echo 'desktop: Dev-Terminal braucht die Erweiterung Desktop Projekte (python3 -I theme/gen/vscode.py)' >&2\n"
            + "notify-send -u low -a Desktop -i utilities-terminal 'Dev-Terminal braucht die Erweiterung „Desktop Projekte“' 'Installieren: python3 -I theme/gen/vscode.py, dann in VS Code „Reload Window“.' 2>/dev/null || true",
            "sh", marks, file, JSON.stringify(mark)]);
    }

    // Projektname wie scripts/new-project: Umlaute umschreiben, Leerzeichen -> "-", nur A-Z a-z 0-9 . _ -
    function projectName(name: string): string {
        const um = { "ä": "ae", "ö": "oe", "ü": "ue", "Ä": "Ae", "Ö": "Oe", "Ü": "Ue", "ß": "ss" };
        return name.trim().replace(/[äöüÄÖÜß]/g, c => um[c]).replace(/\s+/g, "-").replace(/[^A-Za-z0-9._-]/g, "").replace(/^[.-]+/, "");
    }

    // Neues Projekt: Projekt-Desktop + ~/Workspace/<name> + VS Code mit Claude-Tab „/new-project <name>“
    // (scripts/new-project; Skill: claude/skills/new-project). Kein Browser – da läuft noch nichts.
    function newProject(name: string): void {
        const clean = projectName(name);
        if (!clean)
            return;
        Desktops.add(clean, desktopId => Launch.cmd([Quickshell.shellDir + "/../scripts/new-project", clean]));
    }

    function open(id: string): void {
        // Code-Desktop: erst Projekt wählen (oder neu anlegen) – im Launcher-Projektmodus
        if (id === "code") {
            Quickshell.execDetached(["qs", "ipc", "--any-display", "-p", Quickshell.shellDir, "call", "launcher", "search", "#"]);
            return;
        }
        const t = list.find(x => x.id === id);
        if (!t)
            return;
        Desktops.add(t.name, desktopId => {
            // "@code" am Anfang = VS Code (nativ oder Flatpak, siehe Launch.code)
            for (const cmd of t.apps || []) {
                const args = cmd.map(home);
                if (args[0] === "@code")
                    Launch.code(args.slice(1).map(a => Projects.openTarget(a)));
                else
                    Launch.cmd(args);
            }
        });
    }
}
