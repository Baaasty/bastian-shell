import QtQuick
import Quickshell
import Quickshell.Io
import Quickshell.Wayland
import qs.config
import qs.services
import qs.components

// Quicklinks eines Projekt-Workspaces (Idee n): localhost-Ports aus dev.ports (mit „läuft“-Punkt), Container des
// Projekts (Zuordnung aus DevServices, dieselbe wie im Dev-Popout) und Links aus projects.json (links). Klick öffnet in Helium. „Add link“ und das X an einem Link gehen über scripts/project
// (link add / link rm) – die Datei wird nie von Hand oder aus QML geschrieben. Doku: docs/QUICKLINKS.md
// Reihenfolge fest: Local (Ports nach Nummer) · Containers · Repos · übrige Links · Add link; ein Icon je Kategorie
// (icon aus projects.json zählt hier nicht). Mit-Projekte aus der
// .code-workspace (soulwick → soulwick-platform) liefern Ports, Container und Repo-Links dazu.
// Tastatur (Workspace-Modus, Q): ↑↓ wählen, Enter öffnet, 1–9 direkt, A Link ergänzen, Entf zweimal entfernt, Esc zurück.
// Dann ohne eigenen Fokus-Grab: die Tasten liefert die Leiste (WorkBar.modeKey → key()), sie behält die Tastatur.
PopupWindow {
    id: pop

    required property var host          // die Leiste (PanelWindow): Anker, openMenus, stick()
    property string deskId: ""          // Workspace-ID, für den das Popup offen ist
    readonly property var proj: GitInfo.projectForId(deskId)
    // Mit-Projekte: andere Projekte, deren Ordner im .code-workspace dieses Projekts stecken (soulwick → soulwick-platform).
    // Ihre Ports, Container und Repo-Links stehen mit im Popup (nur öffnen, entfernen geht nur am eigenen Projekt).
    property var wsFolders: []
    readonly property var related: {
        if (!proj)
            return [];
        const out = [], seen = {};
        seen[proj.id] = true;
        for (const f of wsFolders) {
            const s = Projects.settingsFor(f);
            if (s && !seen[s.id]) {
                seen[s.id] = true;
                out.push(s);
            }
        }
        return out;
    }
    readonly property var family: proj ? [proj].concat(related) : []
    readonly property var ports: {
        const out = [];
        for (const e of family) {
            const p = (e.dev && e.dev.ports) || {};
            for (const k of Object.keys(p))
                out.push({ role: k, port: Number(p[k]), from: e.id === proj.id ? "" : (e.name || e.id) });
        }
        return out.sort((a, b) => a.port - b.port);
    }
    readonly property var links: (proj && proj.links) || []
    // feste Reihenfolge: Local (Ports) · Containers · Repos · übrige Links · Add link
    function isRepo(l: var): bool {
        return l.icon === "code" || /^https?:\/\/(www\.)?(github\.com|gitlab\.com|codeberg\.org|bitbucket\.org)\//i.test(String(l.url || ""));
    }
    // Repo-Links der Mit-Projekte heißen nach ihrem Projekt und haben `from` (nicht entfernbar)
    readonly property var repoLinks: {
        const out = links.filter(l => isRepo(l));
        const norm = u => String(u || "").replace(/\/+$/, "").toLowerCase();
        const have = out.map(l => norm(l.url));
        for (const e of related)
            for (const l of (e.links || []).filter(l => isRepo(l) && !have.includes(norm(l.url)))) {
                have.push(norm(l.url));
                out.push({ name: e.name || e.id, url: l.url, from: e.id });
            }
        return out;
    }
    readonly property var otherLinks: links.filter(l => !isRepo(l))
    readonly property int nLocal: ports.length + containers.length

    FileView {
        path: pop.proj && pop.proj.workspace ? GitInfo.home(pop.proj.workspace) : ""
        printErrors: false
        watchChanges: true
        onPathChanged: pop.wsFolders = []
        onFileChanged: reload()
        onLoadFailed: pop.wsFolders = []
        onLoaded: pop.wsFolders = pop.foldersOf(text(), path)
    }
    // Ordner einer .code-workspace (JSONC: Kommentare außerhalb von Strings und Kommas vor } ] weg), absolut
    function foldersOf(text: string, file: string): var {
        const clean = String(text).replace(/("(?:\\.|[^"\\])*")|\/\/[^\n]*|\/\*[\s\S]*?\*\//g, (m, str) => str || "").replace(/,(\s*[}\]])/g, "$1");
        try {
            const dir = String(file).replace(/\/[^/]*$/, "");
            return (JSON.parse(clean).folders || []).map(f => {
                const p = GitInfo.home(String(f.path || ""));
                const out = [];
                for (const seg of (p.startsWith("/") ? p : dir + "/" + p).split("/"))
                    seg === ".." ? out.pop() : seg !== "." && out.push(seg);
                return out.join("/");
            });
        } catch (e) {
            return [];
        }
    }
    // Container des Projekts: [{ name, running, ports: [int], web: int }] – web = Port mit Weboberfläche (Rolle in
    // dev.infra wie „minio-console“), Klick öffnet ihn; ohne (postgres …) kopiert der Klick localhost:<port>
    readonly property var containers: {
        if (!proj)
            return [];
        const infra = Object.assign({}, ...family.map(e => (e.dev && e.dev.infra) || {}));
        const ids = family.map(e => e.id);
        const roleOf = port => Object.keys(infra).find(k => Number(infra[k]) === port) || "";
        return DevServices.containers.filter(c => ids.includes(c.project)).map(c => {
            const ports = [...new Set((c.ports || []).filter(p => p.proto === "tcp").map(p => p.host))].sort((a, b) => a - b);
            const web = ports.find(p => /console|web|ui|admin|dashboard/i.test(roleOf(p))) || 0;
            return { name: c.name, running: !!c.running, ports: ports, web: web };
        }).sort((a, b) => a.name.localeCompare(b.name));
    }
    property var listening: ({})        // Port -> true, nur solange das Popup offen ist (ss -ltn)
    readonly property var git: proj ? GitInfo.git[proj.id] : undefined
    // Repo-Seite (aus git remote), nur wenn sie nicht schon als Link drinsteht
    readonly property string repoUrl: {
        const u = git && git.repoUrl ? String(git.repoUrl) : "";
        return u && !links.some(l => String(l.url || "").replace(/\/+$/, "") === u.replace(/\/+$/, "")) ? u : "";
    }

    // ---------- Tastatur ----------
    property bool kb: false             // per Taste geöffnet (Workspace-Modus)
    property bool kbBack: false         // mit Esc zu: zurück in den Workspace-Modus (sonst endet er)
    property int sel: 0
    property int armed: -1              // Zeile, deren Link nach dem ersten Entf auf „Remove?“ steht
    // Zeilen in Bildschirm-Reihenfolge: Ports, Container, Repo-Links, Repo (git remote), übrige Links, Add link
    readonly property var items: {
        const out = [];
        for (const p of ports)
            out.push({ kind: "url", url: url(p.port) });
        for (const c of containers)
            out.push(containerItem(c));
        for (const l of repoLinks)
            out.push(l.from ? { kind: "url", url: l.url } : { kind: "link", url: l.url, name: l.name });
        if (repoUrl)
            out.push({ kind: "url", url: repoUrl });
        for (const l of otherLinks)
            out.push({ kind: "link", url: l.url, name: l.name });
        out.push({ kind: "add" });
        return out;
    }
    function hintFor(i: int): string {
        return kb && i < 9 ? String(i + 1) : "";
    }
    function run(i: int): void {
        const it = items[i];
        if (!it)
            return;
        if (it.kind === "add")
            askLink();
        else if (it.kind === "copy")
            copyAddr(it.text);
        else if (it.kind === "url" || it.kind === "link")
            openUrl(it.url);
    }
    function containerItem(c: var): var {
        if (c.web)
            return { kind: "url", url: url(c.web) };
        if (c.ports.length)
            return { kind: "copy", text: "localhost:" + c.ports[0] };
        return { kind: "none" };
    }
    // Datenbank & Co. haben keine Weboberfläche: Adresse in die Zwischenablage
    function copyAddr(text: string): void {
        visible = false;
        Clipboard.copyText(text);
        Quickshell.execDetached(["notify-send", "-a", "Desktop", "-u", "low", "Copied " + text]);
    }
    function askLink(): void {
        visible = false;
        Qt.callLater(() => Prompt.askAt("bottom", "add_link", "Add link: Name https://…", "", t => pop.addLink(t)));
    }
    // Tasten aus dem Workspace-Modus; true = verbraucht
    function key(e): bool {
        const k = e.key;
        const n = items.length;
        if (sel >= n)
            sel = n - 1;        // Link inzwischen entfernt
        if (k !== Qt.Key_Delete && k !== Qt.Key_Backspace)
            armed = -1;
        if (k === Qt.Key_Escape) {
            kbBack = true;
            visible = false;
        } else if (k === Qt.Key_Up || k === Qt.Key_K || k === Qt.Key_Backtab) {
            sel = (sel - 1 + n) % n;
        } else if (k === Qt.Key_Down || k === Qt.Key_J || k === Qt.Key_Tab) {
            sel = (sel + 1) % n;
        } else if (e.isAutoRepeat) {
            return true;
        } else if (k === Qt.Key_Return || k === Qt.Key_Enter || k === Qt.Key_Space) {
            run(sel);
        } else if (k >= Qt.Key_1 && k <= Qt.Key_9) {
            const i = k - Qt.Key_1;
            if (i < n)
                run(i);
        } else if (k === Qt.Key_A) {
            askLink();
        } else if (k === Qt.Key_Delete || k === Qt.Key_Backspace) {
            const it = items[sel];
            if (!it || it.kind !== "link") {
                armed = -1;
            } else if (armed === sel) {
                armed = -1;
                removeLink(it.name);
            } else {
                armed = sel;
                disarm.restart();
            }
        }
        return true;
    }
    Timer {
        id: disarm
        interval: 3000
        onTriggered: pop.armed = -1
    }

    anchor.window: host
    anchor.edges: Edges.Top
    anchor.gravity: Edges.Top
    grabFocus: !kb
    implicitWidth: 340
    implicitHeight: col.implicitHeight + 12
    color: "transparent"

    function openFor(id: string): void {
        deskId = id;
        kb = false;
        visible = true;
    }
    // aus dem Workspace-Modus: ohne Grab, erste Zeile markiert
    function openKb(id: string): void {
        deskId = id;
        kb = true;
        kbBack = false;
        sel = 0;
        armed = -1;
        visible = true;
    }

    onVisibleChanged: {
        host.openMenus += visible ? 1 : -1;
        if (visible) {
            scan.running = true;
            DevServices.refresh();
        } else {
            host.stick();
            listening = ({});
        }
    }

    function url(port: int): string {
        return "http://localhost:" + port;
    }
    function hostOf(u: string): string {
        return String(u).replace(/^[a-z][a-z0-9+.-]*:\/\//i, "").split("/")[0];
    }
    // Pfad dazu, damit zwei Repos auf demselben Host unterscheidbar sind (github.com/org/repo)
    function pathOf(u: string): string {
        return String(u).replace(/^[a-z][a-z0-9+.-]*:\/\/[^/]*/i, "").replace(/\/+$/, "");
    }
    function openUrl(u: string): void {
        visible = false;
        Launch.cmd(["helium", u]);
    }

    // „läuft“: lauschende TCP-Ports, nur solange das Popup offen ist
    Process {
        id: scan
        command: ["ss", "-ltnH"]
        stdout: StdioCollector {
            onStreamFinished: {
                const m = {};
                for (const line of text.split("\n")) {
                    const f = line.trim().split(/\s+/);
                    const local = f[3] || "";
                    const port = Number(local.substring(local.lastIndexOf(":") + 1));
                    if (port > 0)
                        m[port] = true;
                }
                pop.listening = m;
            }
        }
    }
    Timer {
        interval: 3000
        repeat: true
        running: pop.visible
        onTriggered: if (!scan.running) scan.running = true
    }

    // Link ergänzen: „Name URL“ (nur URL geht auch) -> scripts/project link <id> add
    function addLink(text: string): void {
        if (!proj)
            return;
        const tokens = String(text).trim().split(/\s+/).filter(t => t);
        if (!tokens.length)
            return;
        let u = tokens.pop();
        if (!/^[a-z][a-z0-9+.-]*:\/\//i.test(u)) {
            if (/^[\w.-]+\.[a-z]{2,}(\/\S*)?$/i.test(u))
                u = "https://" + u;
            else {
                Quickshell.execDetached(["notify-send", "-a", "Desktop", "-u", "low", "Link not saved", "Format: Name https://example.com"]);
                return;
            }
        }
        const name = tokens.join(" ") || hostOf(u);
        project(["link", proj.id, "add", name, u]);
    }
    function removeLink(name: string): void {
        if (proj)
            project(["link", proj.id, "rm", name]);
    }
    // scripts/project – meldet Fehler leise per Benachrichtigung; Projects lädt die Datei danach selbst neu
    function project(args: var): void {
        Quickshell.execDetached(["sh", "-c",
            "out=$(\"$@\" 2>&1) || notify-send -a Desktop -u low 'Quick links: not saved' \"$(printf '%s' \"$out\" | head -c 160)\"",
            "sh", Quickshell.shellDir + "/../scripts/project"].concat(args));
    }

    BackgroundEffect.blurRegion: Region {
        Region { x: 0; y: 0; width: 1; height: 1 }
        Region { item: card; radius: Theme.radiusMd }
    }

    Glass {
        id: card
        anchors.fill: parent
        strong: true
        radius: Theme.radiusMd

        Column {
            id: col
            x: 6
            y: 6
            width: parent.width - 12
            spacing: 2

            // Kopf: Projektname
            Item {
                width: col.width
                height: 38
                Txt {
                    anchors.verticalCenter: parent.verticalCenter
                    x: 10
                    width: parent.width - 20
                    text: pop.proj ? pop.proj.name || pop.proj.id : ""
                    font.pixelSize: 17
                    font.weight: Font.DemiBold
                }
            }

            QuickLinksTip {
                visible: !!g && g.branch !== ""
                x: 10
                height: visible ? 24 : 0
                proj: pop.proj
            }

            // localhost
            Label {
                visible: pop.ports.length > 0
                leftPadding: 10
                topPadding: 4
                bottomPadding: 4
                text: "Local"
            }
            Repeater {
                model: pop.ports
                QuickLinksRow {
                    required property var modelData
                    required property int index
                    kbMark: pop.kb && pop.sel === index
                    hint: pop.hintFor(index)
                    width: col.width
                    icon: "language"
                    title: modelData.role
                    sub: "localhost:" + modelData.port + (modelData.from ? "  ·  " + modelData.from : "")
                    showDot: true
                    dotOn: !!pop.listening[modelData.port]
                    dotColor: Theme.success
                    onActivated: pop.openUrl(pop.url(modelData.port))
                }
            }

            // Container des Projekts (eigene Kategorie unter Local)
            Label {
                visible: pop.containers.length > 0
                leftPadding: 10
                topPadding: pop.ports.length > 0 ? 8 : 4
                bottomPadding: 4
                text: "Containers"
            }
            Repeater {
                model: pop.containers
                QuickLinksRow {
                    required property var modelData
                    required property int index
                    readonly property int idx: pop.ports.length + index
                    kbMark: pop.kb && pop.sel === idx
                    hint: pop.hintFor(idx)
                    width: col.width
                    icon: "deployed_code"
                    title: modelData.name
                    sub: modelData.ports.map(p => ":" + p).join(", ")
                    showDot: true
                    dotOn: modelData.running
                    dotColor: Theme.success
                    onActivated: pop.run(idx)
                }
            }

            // Repos: eingetragene Repo-Links, dann die Repo-Seite aus git remote
            Label {
                visible: pop.repoLinks.length > 0 || pop.repoUrl !== ""
                leftPadding: 10
                topPadding: 8
                bottomPadding: 4
                text: "Repos"
            }
            Repeater {
                model: pop.repoLinks
                QuickLinksRow {
                    required property var modelData
                    required property int index
                    readonly property int idx: pop.nLocal + index
                    kbMark: pop.kb && pop.sel === idx
                    kbConfirm: pop.armed === idx
                    hint: pop.hintFor(idx)
                    width: col.width
                    icon: "code"
                    title: modelData.name
                    sub: pop.hostOf(modelData.url) + pop.pathOf(modelData.url)
                    removable: !modelData.from
                    onActivated: pop.openUrl(modelData.url)
                    onRemoved: pop.removeLink(modelData.name)
                }
            }

            // Repo-Seite (git remote), falls nicht schon als Link eingetragen
            QuickLinksRow {
                readonly property int idx: pop.nLocal + pop.repoLinks.length
                visible: pop.repoUrl !== ""
                height: visible ? 36 : 0
                width: col.width
                kbMark: visible && pop.kb && pop.sel === idx
                hint: visible ? pop.hintFor(idx) : ""
                icon: "code"
                title: "Repository"
                sub: pop.hostOf(pop.repoUrl) + pop.pathOf(pop.repoUrl)
                onActivated: pop.openUrl(pop.repoUrl)
            }

            // übrige Links (Website, Board, Doku …)
            Label {
                visible: pop.otherLinks.length > 0
                leftPadding: 10
                topPadding: 8
                bottomPadding: 4
                text: "Links"
            }
            Repeater {
                model: pop.otherLinks
                QuickLinksRow {
                    required property var modelData
                    required property int index
                    readonly property int idx: pop.nLocal + pop.repoLinks.length + (pop.repoUrl !== "" ? 1 : 0) + index
                    kbMark: pop.kb && pop.sel === idx
                    kbConfirm: pop.armed === idx
                    hint: pop.hintFor(idx)
                    width: col.width
                    icon: "link"
                    title: modelData.name
                    sub: pop.hostOf(modelData.url)
                    removable: true
                    onActivated: pop.openUrl(modelData.url)
                    onRemoved: pop.removeLink(modelData.name)
                }
            }

            Txt {
                visible: pop.nLocal === 0 && pop.repoLinks.length === 0 && pop.otherLinks.length === 0 && pop.repoUrl === ""
                leftPadding: 10
                topPadding: 4
                bottomPadding: 8
                text: "No ports or links yet."
                color: Theme.textFaint
                font.weight: Font.Normal
            }

            Rectangle {
                x: 10
                width: col.width - 20
                height: 1
                color: Theme.border
            }
            Chip {
                width: col.width
                alignLeft: true
                height: 36
                readonly property bool kbMark: pop.kb && pop.sel === pop.items.length - 1
                active: kbMark
                border.width: kbMark ? 2 : 0
                border.color: Theme.accent
                onClicked: pop.askLink()
                Icon {
                    anchors.verticalCenter: parent.verticalCenter
                    name: "add_link"
                    size: 17
                }
                Txt {
                    anchors.verticalCenter: parent.verticalCenter
                    text: "Add link"
                }
                MonoTxt {
                    visible: pop.kb
                    anchors.verticalCenter: parent.verticalCenter
                    text: "A"
                    color: Theme.accentText
                    font.pixelSize: 13
                    font.weight: Font.Bold
                }
            }

            // Tastenzeile (nur im Tastatur-Betrieb)
            Row {
                visible: pop.kb
                x: 10
                height: visible ? 28 : 0
                spacing: 12
                Repeater {
                    model: [["↑↓", "select"], ["Enter", "open"], ["1–9", "direct"], ["Del", "remove"], ["Esc", "back"]]
                    Row {
                        required property var modelData
                        anchors.verticalCenter: parent.verticalCenter
                        spacing: 4
                        MonoTxt {
                            anchors.verticalCenter: parent.verticalCenter
                            text: modelData[0]
                            color: Theme.accentText
                            font.pixelSize: 11
                            font.weight: Font.Bold
                        }
                        Txt {
                            anchors.verticalCenter: parent.verticalCenter
                            text: modelData[1]
                            color: Theme.textFaint
                            font.pixelSize: 11
                            font.weight: Font.Normal
                        }
                    }
                }
            }
        }
    }
}
