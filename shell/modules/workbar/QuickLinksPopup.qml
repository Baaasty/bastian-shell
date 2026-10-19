import QtQuick
import Quickshell
import Quickshell.Io
import Quickshell.Wayland
import qs.config
import qs.services
import qs.components

// Quicklinks eines Projekt-Workspaces (Idee n): localhost-Ports aus dev.ports (mit „läuft“-Punkt) und Links aus
// projects.json (links). Klick öffnet in Helium. „Add link“ und das X an einem Link gehen über scripts/project
// (link add / link rm) – die Datei wird nie von Hand oder aus QML geschrieben. Doku: docs/QUICKLINKS.md
// Tastatur (Workspace-Modus, Q): ↑↓ wählen, Enter öffnet, 1–9 direkt, A Link ergänzen, Entf zweimal entfernt, Esc zurück.
// Dann ohne eigenen Fokus-Grab: die Tasten liefert die Leiste (WorkBar.modeKey → key()), sie behält die Tastatur.
PopupWindow {
    id: pop

    required property var host          // die Leiste (PanelWindow): Anker, openMenus, stick()
    property string deskId: ""          // Workspace-ID, für den das Popup offen ist
    readonly property var proj: GitInfo.projectForId(deskId)
    readonly property var ports: {
        const p = (proj && proj.dev && proj.dev.ports) || {};
        return Object.keys(p).map(k => ({ role: k, port: Number(p[k]) }));
    }
    readonly property var links: (proj && proj.links) || []
    property var listening: ({})        // Port -> true, nur solange das Popup offen ist (ss -ltn)
    readonly property var git: proj ? GitInfo.git[proj.id] : undefined
    readonly property var ci: proj ? GitInfo.ci[proj.id] : undefined
    // Repo-Seite (aus git remote), nur wenn sie nicht schon als Link drinsteht
    readonly property string repoUrl: {
        const u = git && git.repoUrl ? String(git.repoUrl) : "";
        return u && !links.some(l => String(l.url || "").replace(/\/+$/, "") === u.replace(/\/+$/, "")) ? u : "";
    }
    readonly property string ciUrl: ci && ci.url ? String(ci.url) : ""

    // ---------- Tastatur ----------
    property bool kb: false             // per Taste geöffnet (Workspace-Modus)
    property bool kbBack: false         // mit Esc zu: zurück in den Workspace-Modus (sonst endet er)
    property int sel: 0
    property int armed: -1              // Zeile, deren Link nach dem ersten Entf auf „Remove?“ steht
    // Zeilen in Bildschirm-Reihenfolge: Ports, Links, Repo, CI, Add link
    readonly property var items: {
        const out = [];
        for (const p of ports)
            out.push({ kind: "url", url: url(p.port) });
        for (const l of links)
            out.push({ kind: "link", url: l.url, name: l.name });
        if (repoUrl)
            out.push({ kind: "url", url: repoUrl });
        if (ciUrl)
            out.push({ kind: "url", url: ciUrl });
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
        else
            openUrl(it.url);
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
                    sub: "localhost:" + modelData.port
                    showDot: true
                    dotOn: !!pop.listening[modelData.port]
                    dotColor: Theme.success
                    onActivated: pop.openUrl(pop.url(modelData.port))
                }
            }

            // Links
            Label {
                visible: pop.links.length > 0
                leftPadding: 10
                topPadding: 8
                bottomPadding: 4
                text: "Links"
            }
            Repeater {
                model: pop.links
                QuickLinksRow {
                    required property var modelData
                    required property int index
                    readonly property int idx: pop.ports.length + index
                    kbMark: pop.kb && pop.sel === idx
                    kbConfirm: pop.armed === idx
                    hint: pop.hintFor(idx)
                    width: col.width
                    icon: modelData.icon || "link"
                    title: modelData.name
                    sub: pop.hostOf(modelData.url)
                    removable: true
                    onActivated: pop.openUrl(modelData.url)
                    onRemoved: pop.removeLink(modelData.name)
                }
            }

            // Repo-Seite (git remote), falls nicht schon als Link eingetragen
            QuickLinksRow {
                readonly property int idx: pop.ports.length + pop.links.length
                visible: pop.repoUrl !== ""
                height: visible ? 36 : 0
                width: col.width
                kbMark: visible && pop.kb && pop.sel === idx
                hint: visible ? pop.hintFor(idx) : ""
                icon: "code"
                title: "Repository"
                sub: pop.hostOf(pop.repoUrl)
                onActivated: pop.openUrl(pop.repoUrl)
            }

            // letzter CI-Lauf (nur wenn gh ihn kennt): Klick öffnet ihn auf GitHub
            QuickLinksRow {
                readonly property var c: pop.ci
                readonly property int idx: pop.ports.length + pop.links.length + (pop.repoUrl !== "" ? 1 : 0)
                visible: pop.ciUrl !== ""
                height: visible ? 36 : 0
                width: col.width
                kbMark: visible && pop.kb && pop.sel === idx
                hint: visible ? pop.hintFor(idx) : ""
                icon: "play_circle"
                title: "Last CI run"
                sub: c ? (c.workflow || c.state) : ""
                onActivated: pop.openUrl(pop.ciUrl)
            }

            Txt {
                visible: pop.ports.length === 0 && pop.links.length === 0
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
