import QtQuick
import Quickshell
import Quickshell.Io
import Quickshell.Wayland
import Quickshell.Hyprland
import Quickshell.Widgets
import qs.config
import qs.services
import qs.components

// Launcher: ein Feld, Tastatur zuerst – die eine Suche für alles (Doku: docs/knowledge/shell-features.md).
// Einzeichen-Präfixe: # Projekte, = Rechner, / Dateien, @ Browser-Tabs (Helium)
// Wort-Präfixe (mit Leerzeichen): c Claude fragen, dazu die Web-Kürzel aus config/launcher/web.json (g, yt, gh …).
// Ohne Präfix steht unten immer „Search the web“ – darum kein eigener Websuche-Präfix.
// Emoji und Zwischenablage sind eigene Popups an der Eingabe (modules/clip), Passwörter/Termine/Mail eigene Panels und Kacheln.
Scope {
    id: root

    property bool open: false
    onOpenChanged: if (open) Hypr.panelOpened("launcher")

    // Anderes Panel geht auf → dieses zu (Hypr.panelOpened)
    Connections {
        target: Hypr
        function onPanelOpened(name: string): void {
            if (name !== "launcher" && root.open)
                root.open = false;
        }
    }
    property string query: ""
    property int selected: 0
    property var results: []
    property var counts: ({})   // Häufigkeit je Treffer-ID
    property bool embedded: false   // Panel steckt gerade im offenen Dashboard
    readonly property bool searching: open || embedded   // vom Dashboard aus sitzt das Feld dort, wo dessen Suchleiste war

    // Quellen mit Präfix: die Modus-Chips (und der Abschnitt in Super+K, shell/modules/keys/appkeys.py) werden daraus gebaut.
    // Web-Kürzel kommen dynamisch aus config/launcher/web.json (WebShortcuts).
    readonly property var sources: [
        { prefix: "", label: "All", hint: "Apps, windows, projects, tabs, actions · Tab switches mode" },
        { prefix: "#", label: "Projects", hint: "Start a project workspace or create a new one" },
        { prefix: "=", label: "Calculator", hint: "Calculate · ↵ copies the result" },
        { prefix: "/", label: "Files", hint: "Find files by name · ↵ opens" },
        { prefix: "@", label: "Tabs", hint: "Open Helium tabs · ↵ jumps to the tab" },
        { prefix: "c ", label: "Claude", hint: "Ask Claude · ↵ starts a new chat with your text" }
    ]
    readonly property var modes: WebShortcuts.chipPrefix ? sources.concat([{ prefix: WebShortcuts.chipPrefix, label: "Web" }]) : sources
    readonly property var parsed: parse(query)
    readonly property string mode: parsed.mode
    readonly property string term: parsed.term

    // Suchtext -> { mode, term, key }; mode "" = alles, sonst Einzeichen- oder Wort-Präfix
    // (rebuild() ruft das direkt auf: onQueryChanged kann vor den Bindings laufen)
    function parse(q: string): var {
        if (q.length && "#=/@".includes(q[0]))
            return { mode: q[0], term: q.slice(1).trim(), key: "" };
        return LauncherSources.parse(q) ?? { mode: "", term: q.trim(), key: "" };
    }

    function toggle(): void {
        open = !open;
        if (open) {
            query = "";
            selected = 0;
            rebuild();
        }
    }

    // frisch fürs Dashboard (ohne eigenes Fenster)
    function reset(): void {
        query = "";
        selected = 0;
        rebuild();
    }

    function boost(id) {
        return Math.log((counts[id] || 0) + 1) * 40;
    }

    function rebuild(): void {
        // mode/term hier direkt aus query ableiten: onQueryChanged kann vor den Bindings laufen
        const pr = parse(query);
        const mode = pr.mode;
        const t = pr.term;
        let out = [];
        const add = (item, score) => {
            if (score >= 0)
                out.push(Object.assign({ score: score + boost(item.id) }, item));
        };

        if (mode === "" || mode === "=") {
            const v = Calc.evaluate(t, mode === "=");
            if (v !== null)
                out.push({ id: "calc", glyph: "calculate", title: "= " + Calc.format(v), sub: "Copy result", kind: "Calculator", score: 5000, run: () => Quickshell.execDetached(["wl-copy", Calc.format(v)]) });
        }
        if (mode === "") {
            for (const e of DesktopEntries.applications.values) {
                if (e.noDisplay)
                    continue;
                const s = Math.max(Fuzzy.score(t, e.name), Fuzzy.score(t, e.genericName) - 50, (e.keywords || []).some(k => Fuzzy.score(t, k) > 500) ? 300 : -1);
                add({ id: "app:" + e.id, icon: e.icon, title: e.name, sub: e.genericName || e.comment || "", kind: "App", run: () => Launch.app(e.id) }, t ? s : 1);
            }
            const actions = [
                { id: "act:desktop", glyph: "add", title: "New Desktop", sub: "Empty, no apps", run: () => Desktops.add("", null) },
                { id: "act:focus", glyph: "timer", title: Focus.mode === "idle" ? "Start Focus" : "End Focus", sub: Focus.blockMin + " min block", run: () => Focus.toggle() },
                { id: "act:task", glyph: "checklist", title: "Add Task", sub: "to " + Todos.current, run: () => Prompt.ask("checklist", "New task for " + Todos.current, "", x => Todos.add(Todos.current, x)) },
                { id: "act:passwords", glyph: "key", title: "Passwords", sub: "iCloud Keychain · Super+O", run: () => Quickshell.execDetached(["qs", "ipc", "--any-display", "-p", Quickshell.shellDir, "call", "passwords", "open"]) },
                { id: "act:icloud", glyph: "cloud_sync", title: "iCloud Sync", sub: "Sync iCloud Drive now", run: () => ICloud.syncNow() },
                { id: "act:lock", glyph: "lock", title: "Lock", sub: "Lock screen", run: () => Quickshell.execDetached(["loginctl", "lock-session"]) }
            ];
            for (const a of actions)
                add(Object.assign({ kind: "Action" }, a), t ? Fuzzy.score(t, a.title) : -1);
        }
        if (mode === "#") {
            // neue Projekte / beliebiger Ordner
            const newName = Templates.projectName(t);
            add({ id: "proj:new", glyph: "create_new_folder", title: newName ? "New Project “" + newName + "”" : "New Project…", sub: "~/Workspace/" + (newName || "<name>") + " · project workspace · VS Code + Claude /new-project", kind: "New", run: () => {
                if (newName)
                    Templates.newProject(newName);
                else
                    Prompt.ask("create_new_folder", "Name of the new project", "", x => Templates.newProject(x));
            } }, 3000);
            add({ id: "proj:pick", glyph: "folder_open", title: "Choose Folder…", sub: "Open any folder as a project workspace", kind: "New", run: () => root.pickProjectFolder() }, 2900);
        }
        if (mode === "" || mode === "#") {
            for (const p of Projects.list) {
                const sc = t ? Fuzzy.score(t, p.name) : (mode === "#" ? 1 : -1);
                add({ id: "proj:" + p.path, glyph: p.workspace ? "folder_copy" : "folder_open", title: p.name, sub: p.workspace ? "Start project workspace · VS Code workspace (several folders) + Helium" : "Start project workspace · VS Code + Helium", kind: p.workspace ? "Workspace" : "Project", run: () => Templates.openProject(p.path, p.name) }, sc >= 0 ? sc + (p.workspace ? 50 : 0) : sc);
                add({ id: "projvs:" + p.path, glyph: "code", title: p.name + " in VS Code only", sub: p.rel + " · no new workspace", kind: "Project", run: () => Projects.open(p.path) }, sc >= 0 ? sc - 200 : -1);
            }
        }
        // offene Fenster (alle Desktops): Enter springt hin
        if (mode === "" && t) {
            for (const tl of Hypr.toplevels.values) {
                const title = Hypr.title(tl);
                if (!Hypr.usable(tl) || !title || Parked.isParked(Hypr.appId(tl)))
                    continue;
                const w = tl;
                add({ id: "win:" + title, icon: Hypr.iconName(tl), title: title, sub: "Window · jump to this window", kind: "Window", run: () => Hypr.activate(w) }, Fuzzy.score(t, title) - 30);
            }
        }
        // Chrome-Tabs (über die Erweiterung „Desktop“): ohne Präfix nur klare Treffer, mit @ alle (zuletzt benutzte zuerst)
        if ((mode === "" && t) || mode === "@") {
            for (const tab of ChromeTabs.tabs) {
                const host = ChromeTabs.host(tab.url);
                let sc = Math.max(Fuzzy.score(t, tab.title), Fuzzy.score(t, host) - 60);
                if (mode === "")
                    sc = sc >= 300 ? sc - 40 : -1;
                else if (!t)
                    sc = 1 + (tab.lastAccessed || 0) / 1e13;
                const tb = tab;
                add({ id: "tab:" + tab.url, icon: "helium", title: tab.title, sub: host + (tab.audible ? " · playing" : "") + " · jump to this tab", kind: "Tab", run: () => root.openTab(tb) }, sc);
            }
        }
        // Dateien (Präfix /)
        if (mode === "/") {
            if (!_noSearch)
                Files.search(t);
            for (const f of Files.results)
                add({ id: "file:" + f.path, glyph: "description", title: f.name, sub: f.rel, kind: "File", run: () => Files.open(f.path) }, Fuzzy.score(t, f.name));
        }

        // Web-Kürzel (g, yt, …): gewähltes zuerst; ohne Suchtext die Liste aller Kürzel
        if (mode === WebShortcuts.chipPrefix && mode !== "") {
            WebShortcuts.list.forEach((w, i) => {
                const chosen = w.key === pr.key;
                if (t && !chosen)
                    return;
                add({ id: "web:" + w.key, glyph: "travel_explore", title: t ? "Search “" + t + "”" : w.name, sub: (t ? w.name + " · " : "") + w.host + " · " + (t ? "opens in Helium" : "type " + w.key + " <search>"), kind: w.key, run: () => WebShortcuts.open(w, t) }, (chosen ? 5000 : 1000) - i);
            });
        }
        // Web-Kürzel-Liste: kaputte Einträge in web.json melden
        if (mode === WebShortcuts.chipPrefix && mode !== "" && !t && WebShortcuts.problem)
            add({ id: "web:problem", glyph: "warning", title: "Config problem", sub: WebShortcuts.problem, kind: "Web", run: () => {} }, 6000);
        // kein Treffer-Ersatz im Hauptmodus: unten immer die Websuche (erstes Kürzel in config/launcher/web.json)
        if (mode === "" && t) {
            const w = WebShortcuts.find(WebShortcuts.defaultKey);
            if (w)
                out.push({ id: "web:fallback", glyph: "travel_explore", title: "Search the web for “" + t + "”", sub: w.name + " · " + w.host, kind: w.key, score: 0.5, run: () => WebShortcuts.open(w, t) });
            else
                out.push({ id: "web:none", glyph: "warning", title: "No search engine", sub: WebShortcuts.problem || "config/launcher/web.json has no entries", kind: "Web", score: 0.5, run: () => {} });
        }
        // Claude fragen (c <text>): neuer Chat mit dem Text – Claude Desktop, sonst claude.ai in Helium
        if (mode === "c ") {
            LauncherSources.claudeEnsure();
            const where = LauncherSources.claudeHandler ? "Claude Desktop" : "claude.ai in Helium";
            add({ id: "claude:ask", glyph: "chat", title: t ? "Ask Claude: “" + t + "”" : "Type what you want to ask Claude", sub: (t ? "New chat · " : "↵ opens a new chat · ") + where, kind: "Claude", run: () => LauncherSources.askClaude(t) }, 1);
        }
        out.sort((a, b) => b.score - a.score);
        results = out.slice(0, 8);
        selected = 0;
    }

    // Tab vorholen (Erweiterung) + Chrome-Fenster über Hyprland aktivieren: Fenstertitel beginnt mit dem Titel des aktiven Tabs
    function openTab(tab: var): void {
        ChromeTabs.activate(tab);
        const want = ChromeTabs.activeTitles[tab.windowId] || "";
        let fallback = null;
        let several = false;   // mehrere Chrome-Fenster, keins passt
        for (const w of Hypr.toplevels.values) {
            if (!/chrome|helium/i.test(Hypr.appId(w)))
                continue;
            if (want && Hypr.title(w).startsWith(want)) {
                Hypr.activate(w);
                return;
            }
            several = !!fallback;
            fallback = fallback ?? w;
        }
        if (fallback && !several)
            Hypr.activate(fallback);
    }

    property bool _noSearch: false
    function rebuildNoSearch(): void {
        _noSearch = true;
        rebuild();
        _noSearch = false;
    }

    function activate(i: int): void {
        const r = results[i];
        if (!r)
            return;
        counts[r.id] = (counts[r.id] || 0) + 1;
        countsFile.setText(JSON.stringify(counts));
        open = false;
        r.run();
    }

    onQueryChanged: if (searching) rebuild()

    // Listen kommen asynchron: neu suchen, sobald sie da sind
    Connections {
        target: Projects
        function onListChanged() { if (root.searching) root.rebuild(); }
    }
    Connections {
        target: Files
        function onResultsChanged() { if (root.searching && root.mode === "/") root.rebuildNoSearch(); }
    }
    Connections {
        target: ChromeTabs
        function onTabsChanged() { if (root.searching && root.mode === "@") root.rebuild(); }
    }
    Connections {
        target: LauncherSources
        function onClaudeHandlerChanged() { if (root.searching && root.mode === "c ") root.rebuild(); }
    }
    Connections {
        target: WebShortcuts
        function onListChanged() { if (root.searching) root.rebuild(); }
    }
    // Dienste schon beim Start laden (Singletons entstehen sonst erst beim ersten Zugriff)
    Component.onCompleted: [Projects.list, ChromeTabs.tabs, WebShortcuts.list]

    // „Choose Folder…“: eigener Ordner-Wähler der Shell (services/FilePicker.qml, früher kdialog)
    function pickProjectFolder(): void {
        FilePicker.pickFolder("~/Workspace", path => {
            if (path)
                Templates.openProject(path, path.split("/").pop());
        }, { title: "Choose project folder" });
    }

    FileView {
        id: countsFile
        path: Quickshell.env("HOME") + "/.local/state/desktop/launcher.json"
        printErrors: false
        onLoaded: {
            try {
                root.counts = JSON.parse(text());
            } catch (e) {}
        }
    }

    IpcHandler {
        target: "launcher"

        function toggle(): void {
            root.toggle();
        }
        // zum Testen: Launcher mit Suchbegriff öffnen
        function search(text: string): void {
            if (!root.open)
                root.toggle();
            root.query = text;
        }
    }

    Variants {
        model: Config.mainScreens

        PanelWindow {
            id: win

            required property var modelData

            // weich auf, aber sofort tippbar (Fokus ist schon während der Animation da)
            property real progress: root.open ? 1 : 0
            Behavior on progress { NumberAnimation { duration: root.open ? 150 : 110; easing.type: Easing.OutCubic } }

            screen: modelData
            visible: root.open || progress > 0
            anchors {
                top: true
                bottom: true
                left: true
                right: true
            }
            exclusionMode: ExclusionMode.Ignore
            color: "transparent"
            WlrLayershell.namespace: "dock" // "dock": ohne Öffnen-Animation (Hyprland: layerrule noanim)
            WlrLayershell.layer: WlrLayer.Overlay
            WlrLayershell.keyboardFocus: root.open ? WlrKeyboardFocus.OnDemand : WlrKeyboardFocus.None
            // Klick irgendwo daneben (auch auf den anderen Monitoren) schließt; der Abdunkel-Klick unten bleibt
            HyprlandFocusGrab {
                active: root.open
                windows: [win]
                onCleared: root.open = false
            }

            // wie im Dashboard: ganzer Hintergrund leise geblurrt (erst ab 40 % eingeblendet, beim Schließen sofort weg)
            readonly property bool blurOn: root.open && progress > 0.4
            BackgroundEffect.blurRegion: Region {
                Region { x: 0; y: 0; width: 1; height: 1 }
                Region { item: win.blurOn ? backdrop : null }
                Region { item: panel.card; radius: Theme.radiusXl }
                Region { item: panel.padShown ? panel.pad : null; radius: Theme.radiusXl }
            }

            onVisibleChanged: if (visible) panel.input.forceActiveFocus()
            Connections {
                target: root
                function onOpenChanged() { if (root.open) panel.input.forceActiveFocus(); }
            }

            Rectangle {
                id: backdrop
                anchors.fill: parent
                opacity: win.progress
                color: Theme.dim
                MouseArea {
                    anchors.fill: parent
                    onClicked: root.open = false
                }
            }

            LauncherPanel {
                id: panel

                launcher: root
                x: (parent.width - width) / 2
                y: (Theme.layout.launcherTop || 300) - (1 - win.progress) * 14
                opacity: win.progress
                scale: 0.98 + 0.02 * win.progress
                onDismissed: root.open = false
            }
        }
    }
}
