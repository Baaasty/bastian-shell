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
// Einzeichen-Präfixe: # Projekte, = Rechner, : Emoji, ; Zwischenablage, / Dateien, @ Browser-Tabs (Helium), ? Hilfe (leer) bzw. Websuche (?<text>)
// Wort-Präfixe (mit Leerzeichen): pw Passwörter, cal Termine, c Claude fragen, dazu die Web-Kürzel aus config/launcher/web.json (g, yt, gh …)
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

    // Quellen mit Präfix: die Hilfe (?) und die Modus-Chips werden daraus gebaut.
    // Web-Kürzel kommen dynamisch aus config/launcher/web.json (WebShortcuts).
    readonly property var sources: [
        { prefix: "", label: "All", hint: "Apps, windows, projects, tabs, actions · Tab switches mode" },
        { prefix: "#", label: "Projects", hint: "Start a project workspace or create a new one" },
        { prefix: "=", label: "Calculator", hint: "Calculate · ↵ copies the result" },
        { prefix: ":", label: "Emoji", hint: "Find an emoji · ↵ copies it" },
        { prefix: ";", label: "Clipboard", hint: "History and pins · ↵ pastes · Shift+↵ copies · Ctrl+P pins" },
        { prefix: "/", label: "Files", hint: "Find files by name · ↵ opens" },
        { prefix: "@", label: "Tabs", hint: "Open Helium tabs · ↵ jumps to the tab" },
        { prefix: "pw ", label: "Passwords", hint: "Title, website or user · ↵ copies the password" },
        { prefix: "cal ", label: "Calendar", hint: "Upcoming events · ↵ opens the calendar" },
        { prefix: "m ", label: "Mail", hint: "Unread mail · ↵ opens it in Thunderbird and marks it read · Ctrl+R marks read · Ctrl+D deletes" },
        { prefix: "c ", label: "Claude", hint: "Ask Claude · ↵ starts a new chat with your text" },
        { prefix: "?", label: "Web search", hint: "Search the web (default engine) · ↵ opens in Helium · ? alone shows this help" }
    ]
    readonly property var modes: WebShortcuts.chipPrefix ? sources.concat([{ prefix: WebShortcuts.chipPrefix, label: "Web" }]) : sources
    readonly property var parsed: parse(query)
    readonly property string mode: parsed.mode
    readonly property string term: parsed.term

    // Suchtext -> { mode, term, key }; mode "" = alles, sonst Einzeichen- oder Wort-Präfix
    // (rebuild() ruft das direkt auf: onQueryChanged kann vor den Bindings laufen)
    function parse(q: string): var {
        if (q.length && "#=:;/@?".includes(q[0]))
            return { mode: q[0], term: q.slice(1).trim(), key: "" };
        return LauncherSources.parse(q) ?? { mode: "", term: q.trim(), key: "" };
    }

    // Launcher mit Text öffnen (Hilfe-Zeilen)
    function openWith(text: string): void {
        open = true;
        query = text;
        selected = 0;
        Clipboard.refresh();
    }

    function toggle(): void {
        open = !open;
        if (open) {
            query = "";
            selected = 0;
            Clipboard.refresh();
            rebuild();
        }
    }

    // frisch fürs Dashboard (ohne eigenes Fenster)
    function reset(): void {
        query = "";
        selected = 0;
        Clipboard.refresh();
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
        if (mode === ":") {
            for (const [ch, name] of Emoji.list)
                add({ id: "emoji:" + ch, emoji: ch, title: name, sub: "Copy", kind: "Emoji", run: () => Emoji.copy(ch) }, t ? Fuzzy.score(t, name) : 1);
        }
        if (mode === ";") {
            for (const p of Clipboard.pins)
                add({ id: "pin:" + p, glyph: "push_pin", pinText: p, title: p, sub: "Pinned · Ctrl+P to unpin", kind: "Pinned", run: copyOnly => Clipboard.copyText(p, !copyOnly, null) }, t ? Fuzzy.score(t, p) : 2);
            for (const c of Clipboard.entries) {
                if (!c.image && Clipboard.isPinned(c.text))
                    continue;
                add({
                    id: "clip:" + c.id, clipId: c.id, glyph: "content_paste",
                    thumb: c.image ? Clipboard.thumb(c.id) : "",
                    pinText: c.image ? "" : c.text,
                    title: c.image ? "Image · " + c.w + " × " + c.h : c.text,
                    sub: c.image ? c.image.toUpperCase() : "",
                    kind: "Clipboard", run: copyOnly => Clipboard.copy(c.id, !copyOnly, null)
                }, t ? Fuzzy.score(t, c.image ? "image picture bild " + c.image : c.text) : 1);
            }
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
        // kein Treffer-Ersatz im Hauptmodus: unten immer die Websuche anbieten
        if (mode === "" && t && WebShortcuts.defaultKey) {
            const w = WebShortcuts.find(WebShortcuts.defaultKey);
            out.push({ id: "web:fallback", glyph: "travel_explore", title: "Search the web for “" + t + "”", sub: w.name + " · " + w.host, kind: w.key, score: 0.5, run: () => WebShortcuts.open(w, t) });
        }
        // Passwörter (nur Metadaten): Enter kopiert das Passwort, kein Klartext in der Liste
        if (mode === "pw ") {
            LauncherSources.pwEnsure();
            if (LauncherSources.pwError)
                add({ id: "pw:err", glyph: "key_off", title: "Passwords not available", sub: LauncherSources.pwError, kind: "Passwords", run: () => {} }, 1);
            else if (!LauncherSources.pwReady)
                add({ id: "pw:load", glyph: "key", title: "Loading passwords…", sub: "", kind: "Passwords", run: () => {} }, 1);
            else if (!t)
                add({ id: "pw:hint", glyph: "key", title: "Type a title, website or username", sub: LauncherSources.pwItems.length + " logins · ↵ copies the password (cleared after 30 s)", kind: "Passwords", run: () => Quickshell.execDetached(["qs", "ipc", "--any-display", "-p", Quickshell.shellDir, "call", "passwords", "open"]) }, 1);
            else {
                for (const m of LauncherSources.pwSearch(t)) {
                    const e = m.e;
                    add({ id: "pw:" + e.id, glyph: "key", title: e.title || m.host || "(no title)", sub: [m.host, e.user].filter(x => x).join(" · ") + (e.hasPassword || e.hasTotp ? "" : " · nothing to copy"), kind: "Password", run: () => LauncherSources.pwCopy(e) }, m.score);
                }
                add({ id: "pw:open", glyph: "open_in_new", title: "Open Passwords panel", sub: "Details, 2FA code, websites", kind: "Passwords", run: () => Quickshell.execDetached(["qs", "ipc", "--any-display", "-p", Quickshell.shellDir, "call", "passwords", "search", t]) }, 0.2);
            }
        }
        // Termine (aus dem Agenda-Dienst)
        if (mode === "cal ") {
            if (!Agenda.configured)
                add({ id: "cal:setup", glyph: "event_busy", title: "Calendar not set up", sub: "See docs/setup/mail-calendar.md", kind: "Calendar", run: () => {} }, 1);
            else {
                let n = 0;
                for (const ev of LauncherSources.upcoming()) {
                    const sc = t ? Math.max(Fuzzy.score(t, ev.title), Fuzzy.score(t, ev.location || "") - 80, Fuzzy.score(t, ev.calendar || "") - 80) : 1000 - n;
                    n++;
                    add({ id: "cal:" + ev.start + ev.title, glyph: "event", title: ev.title || "(no title)", sub: LauncherSources.when(ev) + (ev.location ? " · " + ev.location : ""), kind: ev.calendar || "Event", run: () => Agenda.openClient() }, sc);
                }
                if (out.length === 0)
                    add({ id: "cal:none", glyph: "event_available", title: t ? "No event matches" : "No upcoming events", sub: "↵ opens the calendar", kind: "Calendar", run: () => Agenda.openClient() }, 1);
            }
        }
        // Ungelesene Mails (Mail-Dienst): ↵ öffnet in Thunderbird + gelesen, Ctrl+R nur gelesen, Ctrl+D Papierkorb (LauncherPanel)
        if (mode === "m ") {
            if (!Mail.configured)
                add({ id: "mail:setup", glyph: "mail_lock", title: "Mail not set up", sub: "See docs/setup/mail-calendar.md", kind: "Mail", run: () => {} }, 1);
            else {
                let n = 0;
                for (const m of Mail.latest) {
                    const sc = t ? Math.max(Fuzzy.score(t, m.from || ""), Fuzzy.score(t, m.subject || "") - 40) : 1000 - n;
                    n++;
                    add({ id: "mail:" + m.accountName + ":" + m.uid + ":" + m.mid, glyph: "mail", title: m.from || "?", sub: (m.subject || "(no subject)") + " · " + Mail.when(m.date), kind: Mail.accounts.length > 1 ? m.account : "Mail", keys: Mail.canMarkRead(m) ? "↵ open · ^R read · ^D delete" : "↵ open", mail: m, run: () => Mail.openMessage(m) }, sc);
                }
                if (out.length === 0)
                    add({ id: "mail:none", glyph: "done_all", title: t ? "No unread mail matches" : "Inbox zero", sub: "↵ opens Thunderbird", kind: "Mail", run: () => Mail.openClient() }, 1);
            }
        }
        // Claude fragen (c <text>): neuer Chat mit dem Text – Claude Desktop, sonst claude.ai in Helium
        if (mode === "c ") {
            LauncherSources.claudeEnsure();
            const where = LauncherSources.claudeHandler ? "Claude Desktop" : "claude.ai in Helium";
            add({ id: "claude:ask", glyph: "chat", title: t ? "Ask Claude: “" + t + "”" : "Type what you want to ask Claude", sub: (t ? "New chat · " : "↵ opens a new chat · ") + where, kind: "Claude", run: () => LauncherSources.askClaude(t) }, 1);
        }
        // Websuche (?<text>): Standard-Suchmaschine (erstes Kürzel in config/launcher/web.json)
        if (mode === "?" && t) {
            const w = WebShortcuts.find(WebShortcuts.defaultKey);
            if (w)
                add({ id: "web:help", glyph: "travel_explore", title: "Search the web for “" + t + "”", sub: w.name + " · " + w.host + " · opens in Helium", kind: w.key, run: () => WebShortcuts.open(w, t) }, 1);
            else
                add({ id: "web:none", glyph: "warning", title: "No search engine", sub: WebShortcuts.problem || "config/launcher/web.json has no entries", kind: "Web", run: () => {} }, 1);
        }
        // Hilfe: alle Präfixe aus den Quellen (+ Web-Kürzel dynamisch)
        if (mode === "?" && !t) {
            for (const src of sources) {
                if (src.prefix === "")
                    continue;
                const px = src.prefix;
                add({ id: "help:" + px, glyph: "keyboard_command_key", title: px === "?" ? "?<text>" : px === "c " ? "c <prompt>" : px.trim() + " " + (px.length > 1 && px.endsWith(" ") ? "<search>" : ""), sub: src.hint, kind: src.label, run: () => root.openWith(px) }, 1000 - sources.indexOf(src));
            }
            if (WebShortcuts.list.length) {
                const first = WebShortcuts.list[0];
                add({ id: "help:web", glyph: "travel_explore", title: first.key + " <search>", sub: WebShortcuts.list.map(w => w.key + " " + w.name).join("  ·  "), kind: "Web", run: () => root.openWith(first.key + " ") }, 1);
            }
            if (WebShortcuts.problem)
                add({ id: "help:problem", glyph: "warning", title: "Config problem", sub: WebShortcuts.problem, kind: "Help", run: () => {} }, 2000);
        }

        if (mode === ";" && !t)
            out = out.slice(0, 50); // Favoriten, dann neueste zuerst
        else
            out.sort((a, b) => b.score - a.score);
        results = out.slice(0, mode === "?" && !t ? 12 : 8);
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

    // copyOnly (Shift+Enter): Zwischenablage-Treffer nur kopieren statt einfügen; andere Treffer ignorieren es
    function activate(i: int, copyOnly: bool): void {
        const r = results[i];
        if (!r)
            return;
        counts[r.id] = (counts[r.id] || 0) + 1;
        countsFile.setText(JSON.stringify(counts));
        open = false;
        r.run(!!copyOnly);
    }

    onQueryChanged: if (searching) rebuild()

    // Listen kommen asynchron: neu suchen, sobald sie da sind
    Connections {
        target: Projects
        function onListChanged() { if (root.searching) root.rebuild(); }
    }
    Connections {
        target: Emoji
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
        function onPwItemsChanged() { if (root.searching && root.mode === "pw ") root.rebuild(); }
        function onPwErrorChanged() { if (root.searching && root.mode === "pw ") root.rebuild(); }
        function onClaudeHandlerChanged() { if (root.searching && root.mode === "c ") root.rebuild(); }
    }
    Connections {
        target: WebShortcuts
        function onListChanged() { if (root.searching) root.rebuild(); }
    }
    Connections {
        target: Agenda
        function onAllEventsChanged() { if (root.searching && root.mode === "cal ") root.rebuild(); }
    }
    Connections {
        target: Mail
        function onAccountsChanged() { if (root.searching && root.mode === "m ") root.rebuild(); }
    }
    Connections {
        target: Clipboard
        function onEntriesChanged() { if (root.searching) root.rebuild(); }
        function onThumbsVersionChanged() { if (root.searching) root.rebuild(); }
    }
    // Dienste schon beim Start laden (Singletons entstehen sonst erst beim ersten Zugriff)
    Component.onCompleted: [Projects.list, Emoji.list, Clipboard.entries, ChromeTabs.tabs, WebShortcuts.list]

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
        function clipboard(): void {
            if (root.open && root.mode === ";") {
                root.open = false;
                return;
            }
            if (!root.open)
                root.toggle();
            root.query = ";";
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
