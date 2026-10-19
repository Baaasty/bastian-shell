import QtQuick
import Qt.labs.folderlistmodel
import Quickshell
import Quickshell.Io
import Quickshell.Wayland
import Quickshell.Hyprland
import qs.config
import qs.services

// Datei-/Ordner-Wähler der Shell (Oberfläche zu services/FilePicker.qml): Brotkrumen, Favoriten + Projektordner
// (projects/projects.json), Liste (Ordner zuerst), Tippen filtert, ↵ öffnet/wählt, ⌫ = hoch, Strg+H = versteckte Dateien,
// beim Speichern Dateiname + Format + Überschreiben-Rückfrage. Verzeichnis lesen: Qt FolderListModel (nur solange offen).
// Mehrfachauswahl (FilePicker.openFiles): Tab markiert Datei/Ordner (auch über mehrere Ordner), Strg+A alle Dateien hier,
// ↵ nimmt die markierten (ohne Markierung die gewählte Datei).
// Zum Ansehen ohne Aufrufer: qs ipc … call filepicker demo folder|open|save|multi
Scope {
    id: root

    readonly property bool open: FilePicker.active
    readonly property string mode: FilePicker.mode
    readonly property var filters: FilePicker.filters
    readonly property string home: FilePicker.home
    property string screenName: Config.mainScreen

    property string dir: ""             // aktueller Ordner (absolut, ohne / am Ende außer „/“)
    property bool showHidden: false     // bleibt für die Sitzung
    property string query: ""
    property int sel: 0
    property var entries: []            // [{name, path, isDir, size, modified, suffix, hidden}]
    property string notice: ""          // Hinweis (Ordner fehlt …)
    property string confirm: ""         // Zielpfad, der überschrieben würde (Rückfrage)
    property string ext: ""             // gewähltes Format beim Speichern
    property string pendingSelect: ""   // nach „hoch“: den Ordner wählen, aus dem man kam
    readonly property bool multi: FilePicker.multi
    property var marked: ({})           // Mehrfachauswahl: Pfad → true (bleibt beim Ordnerwechsel)
    readonly property var markedPaths: Object.keys(marked)
    readonly property bool loading: fmLoader.item ? fmLoader.item.status === FolderListModel.Loading : false

    readonly property bool pathQuery: /^(\/|~)/.test(query.trim())
    readonly property var rows: filterRows(entries, query)
    readonly property var cur: sel >= 0 && sel < rows.length ? rows[sel] : null

    // ------------------------------------------------------------ Favoriten / Projekte
    readonly property var favorites: [
        { icon: "home", label: "Home", path: home },
        { icon: "code", label: "Workspace", path: home + "/Workspace" },
        { icon: "download", label: "Downloads", path: home + "/Downloads" },
        { icon: "image", label: "Pictures", path: home + "/Pictures" },
        { icon: "description", label: "Documents", path: home + "/Documents" }
    ]
    readonly property var projects: {
        const out = [];
        const s = Projects.settings || {};
        for (const id in s) {
            const p = (s[id].paths || [])[0];
            if (p)
                out.push({ id: id, label: id, path: FilePicker.expand(p).replace(/\/+$/, ""), color: projectColor(s[id].color) });
        }
        out.sort((a, b) => a.label.localeCompare(b.label));
        return out;
    }
    readonly property var projectByPath: {
        const m = {};
        for (const p of projects)
            m[p.path] = p;
        return m;
    }
    function projectColor(c: string): color {
        return /^#[0-9a-f]{6}$/i.test(c || "") ? c : (Theme.projectAccents[c] || Theme.woodLight);
    }

    // Brotkrumen: unter ~ ab „Home“, sonst ab „/“
    readonly property var crumbs: {
        const d = dir;
        if (!d)
            return [];
        const out = [];
        let base = "", rest = d;
        if (d === home || d.startsWith(home + "/")) {
            out.push({ label: "Home", path: home, icon: "home" });
            base = home;
            rest = d.slice(home.length);
        } else {
            out.push({ label: "/", path: "/", icon: "" });
        }
        for (const part of rest.split("/").filter(x => x)) {
            base = base + "/" + part;
            out.push({ label: part, path: base, icon: "" });
        }
        return out;
    }

    // ------------------------------------------------------------ Liste
    function filterRows(list: var, q: string): var {
        q = q.trim();
        if (!q || pathQuery)
            return list;
        const out = [];
        for (const e of list) {
            const s = Fuzzy.score(q, e.name);
            if (s > 0)
                out.push({ e: e, s: s + (e.isDir ? 1 : 0) });
        }
        out.sort((a, b) => b.s - a.s);
        return out.map(x => x.e);
    }
    onQueryChanged: {
        sel = 0;
        confirm = "";
    }
    function moveSel(d: int): void {
        if (rows.length)
            sel = Math.max(0, Math.min(rows.length - 1, sel + d));
    }

    function rebuild(): void {
        const fm = fmLoader.item;
        if (!fm || !open)
            return;
        const out = [];
        for (let i = 0; i < fm.count; i++) {
            const name = fm.get(i, "fileName");
            out.push({
                name: name,
                path: fm.get(i, "filePath"),
                isDir: fm.get(i, "fileIsDir"),
                size: fm.get(i, "fileSize"),
                modified: fm.get(i, "fileModified"),
                suffix: String(fm.get(i, "fileSuffix") || "").toLowerCase(),
                hidden: name.startsWith(".")
            });
        }
        entries = out;
        if (pendingSelect) {
            const i = rows.findIndex(e => e.name === pendingSelect);
            sel = Math.max(0, i);
            pendingSelect = "";
        } else if (sel >= rows.length) {
            sel = Math.max(0, rows.length - 1);
        }
    }

    // ------------------------------------------------------------ Navigation
    function go(path: string): void {
        const d = path.length > 1 ? path.replace(/\/+$/, "") : path;
        confirm = "";
        notice = "";
        query = "";
        sel = 0;
        if (d === dir)
            return;
        entries = [];
        dir = d;
    }
    // Pfad prüfen (gibt es ihn nicht, nächster vorhandener Elternordner) – für Start, Favoriten, getippte Pfade
    function goChecked(path: string): void {
        const want = FilePicker.expand(path).replace(/\/+$/, "") || "/";
        run(["sh", "-c", "p=$1; while [ ! -d \"$p\" ] && [ \"$p\" != / ]; do p=$(dirname \"$p\"); done; printf %s \"$p\"", "sh", want], (out, code) => {
            const got = (out || "").trim() || home;
            go(got);
            if (got !== want)
                notice = "“" + want.replace(home, "~") + "” not found · showing " + (got.replace(home, "~") || "/");
        });
    }
    function up(): void {
        if (!dir || dir === "/")
            return;
        const i = dir.lastIndexOf("/");
        const parent = i <= 0 ? "/" : dir.slice(0, i);
        const child = dir.slice(i + 1);
        go(parent);
        pendingSelect = child;
    }
    function toggleHidden(): void {
        showHidden = !showHidden;
        pendingSelect = cur ? cur.name : "";
    }

    // ------------------------------------------------------------ Markieren (Mehrfachauswahl)
    function isMarked(path: string): bool {
        return marked[path] === true;
    }
    function toggleMark(e: var): void {
        if (!multi || !e)
            return;
        const m = Object.assign({}, marked);
        if (m[e.path])
            delete m[e.path];
        else
            m[e.path] = true;
        marked = m;
    }
    // Strg+A: alle Dateien der Liste markieren, sind schon alle markiert: wieder ab
    function markAll(): void {
        if (!multi)
            return;
        const files = rows.filter(e => !e.isDir);
        const m = Object.assign({}, marked);
        const all = files.length > 0 && files.every(e => m[e.path]);
        for (const e of files) {
            if (all)
                delete m[e.path];
            else
                m[e.path] = true;
        }
        marked = m;
    }
    // Mehrfachauswahl abschließen: markierte, sonst die gewählte Datei
    function takeMarked(): void {
        if (markedPaths.length)
            FilePicker.finish(markedPaths);
        else if (cur && !cur.isDir)
            FilePicker.finish([cur.path]);
    }

    // ------------------------------------------------------------ Wählen
    function enter(e: var): void {
        if (!e)
            return;
        if (e.isDir)
            go(e.path);
        else if (mode === "open" && multi)
            takeMarked();
        else if (mode === "open")
            FilePicker.finish(e.path);
        else if (mode === "save")
            card.setName(e.name, true);
    }
    // ↵ in der Suche: getippter Pfad > Ordner öffnen > Datei wählen
    function activate(): void {
        if (pathQuery) {
            goChecked(query.trim());
            return;
        }
        enter(cur);
    }
    function chooseFolder(path: string): void {
        if (mode === "folder" && path)
            FilePicker.finish(path);
    }
    function joinPath(name: string): string {
        return (dir === "/" ? "" : dir) + "/" + name;
    }
    function baseName(p: string): string {
        return p === "/" ? "/" : p.slice(p.lastIndexOf("/") + 1);
    }
    function extOf(name: string): string {
        const i = name.lastIndexOf(".");
        return i > 0 ? name.slice(i + 1).toLowerCase() : "";
    }
    // Format umschalten: Endung im Namen tauschen
    function withExt(name: string, e: string): string {
        const i = name.lastIndexOf(".");
        const stem = i > 0 && filters.includes(name.slice(i + 1).toLowerCase()) ? name.slice(0, i) : name;
        return stem + "." + e;
    }
    // Speichern: Name prüfen, Endung ergänzen, vorhandene Datei erst nach Rückfrage überschreiben
    function save(text: string): string {
        let name = (text || "").trim();
        if (!dir)
            return "Still loading the folder…";
        if (!name)
            return "Enter a file name";
        if (name.includes("/"))
            return "No “/” in the name · pick the folder in the list";
        if (name === "." || name === "..")
            return "Not a valid file name";
        if (filters.length && !filters.includes(extOf(name)))
            name = name + "." + (ext || filters[0]);
        const target = joinPath(name);
        if (confirm === target) {
            FilePicker.finish(target);
            return "";
        }
        run(["sh", "-c", "[ -e \"$1\" ] && { [ -d \"$1\" ] && echo dir || echo file; } || echo none", "sh", target], out => {
            const what = (out || "").trim();
            if (what === "dir")
                card.setError("“" + name + "” is a folder");
            else if (what === "file")
                confirm = target;
            else
                FilePicker.finish(target);
        });
        return "";
    }

    function begin(): void {
        screenName = Hyprland.focusedMonitor?.name ?? Config.mainScreen;
        query = "";
        confirm = "";
        notice = "";
        pendingSelect = "";
        marked = {};
        const e = extOf(FilePicker.fileName);
        ext = filters.includes(e) ? e : (filters[0] || "");
        card.reset();
        goChecked(FilePicker.startDir);
    }
    Connections {
        target: FilePicker
        function onSerialChanged() {
            root.begin();
        }
        function onActiveChanged() {
            if (!FilePicker.active) {
                root.dir = "";
                root.entries = [];
            }
        }
    }

    // ------------------------------------------------------------ Hilfsprozesse
    function run(args: var, cb: var): void {
        jobComp.createObject(root, { command: args, cb: cb, running: true });
    }
    Component {
        id: jobComp
        Process {
            id: job
            property var cb
            property int left: 2            // stdout fertig + beendet
            property int code: -1
            function step(): void {
                if (--left > 0)
                    return;
                job.cb(out.text, job.code);
                job.destroy();
            }
            stdout: StdioCollector {
                id: out
                onStreamFinished: job.step()
            }
            onExited: c => {
                job.code = c;
                job.step();
            }
        }
    }

    // Verzeichnis nur laden, solange der Wähler offen ist (beim Start nichts lesen, nichts zeigen)
    Loader {
        id: fmLoader
        active: root.open && root.dir !== ""
        sourceComponent: FolderListModel {
            folder: "file://" + root.dir.split("/").map(encodeURIComponent).join("/")
            showDirsFirst: true
            showDotAndDotDot: false
            showHidden: root.showHidden
            showFiles: root.mode !== "folder"
            showOnlyReadable: true
            sortCaseSensitive: false
            caseSensitive: false
            nameFilters: root.mode === "folder" || !root.filters.length ? [] : root.filters.map(f => "*." + f)
            onStatusChanged: if (status === FolderListModel.Ready) Qt.callLater(root.rebuild)
            onCountChanged: Qt.callLater(root.rebuild)
        }
    }

    // zum Testen/Ansehen: Ergebnis landet nur als Benachrichtigung (nichts wird gespeichert)
    IpcHandler {
        target: "filepicker"

        function demo(mode: string): string {
            const show = p => Quickshell.execDetached(["notify-send", "-a", "Desktop", "-u", "low", "File picker", p || "cancelled"]);
            if (mode === "save")
                FilePicker.saveFile("~/Pictures/Screenshots", "Snip_demo.png", ["png", "jpg", "webp"], show, { title: "Save Snip (demo)" });
            else if (mode === "open")
                FilePicker.openFile("~/Pictures", ["png", "jpg", "jpeg", "webp", "svg"], show, { title: "Open image (demo)" });
            else if (mode === "multi")
                FilePicker.openFiles("~", [], paths => show(paths.join("\n")), { title: "Choose files (demo)", action: "Take" });
            else
                FilePicker.pickFolder("~/Workspace", show, { title: "Choose project folder (demo)" });
            return "ok";
        }
        function cancel(): void {
            FilePicker.cancel();
        }
        function state(): string {
            return JSON.stringify({ open: root.open, mode: root.mode, multi: root.multi, marked: root.markedPaths.length, dir: root.dir, entries: root.entries.length, rows: root.rows.length });
        }
    }

    PanelWindow {
        id: win

        property real progress: root.open ? 1 : 0
        Behavior on progress { NumberAnimation { duration: root.open ? 150 : 110; easing.type: Easing.OutCubic } }

        screen: Quickshell.screens.find(s => s.name === root.screenName) ?? Quickshell.screens[0]
        visible: root.open || progress > 0
        anchors {
            top: true
            bottom: true
            left: true
            right: true
        }
        exclusionMode: ExclusionMode.Ignore
        color: "transparent"
        WlrLayershell.namespace: "dock" // ohne Öffnen-Animation (Hyprland: layerrule noanim)
        WlrLayershell.layer: WlrLayer.Overlay
        // Dialog: Tastatur gehört ihm, bis gewählt oder abgebrochen ist (Esc)
        WlrLayershell.keyboardFocus: root.open ? WlrKeyboardFocus.Exclusive : WlrKeyboardFocus.None

        readonly property bool blurOn: root.open && progress > 0.4
        BackgroundEffect.blurRegion: Region {
            Region { x: 0; y: 0; width: 1; height: 1 }
            Region { item: win.blurOn ? backdrop : null }
            Region { item: card; radius: Theme.radiusXl }
        }

        onVisibleChanged: if (visible && root.open) card.focusInput()

        Rectangle {
            id: backdrop
            anchors.fill: parent
            opacity: win.progress
            color: Theme.dim
            MouseArea {
                anchors.fill: parent
                onClicked: FilePicker.cancel()
            }
        }

        FilePickerCard {
            id: card

            fp: root
            width: Math.min(920, parent.width - 80)
            height: Math.min(620, parent.height - 100)
            x: (parent.width - width) / 2
            y: (parent.height - height) / 2 - 10 + (1 - win.progress) * 14
            opacity: win.progress
            scale: 0.98 + 0.02 * win.progress
        }
    }
}
