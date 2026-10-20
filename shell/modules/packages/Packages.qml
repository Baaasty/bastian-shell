import QtQuick
import Quickshell
import Quickshell.Io
import Quickshell.Wayland
import Quickshell.Hyprland
import qs.config
import qs.components
import qs.services

// Paketmanager (Super+P): System (dnf) · COPR · Flatpak · AppImage · Updates.
// Backend: scripts/pkg (JSON). Schreibende Aktionen laufen als systemd-run --user Unit (überleben einen qs-Neustart)
// mit Live-Ausgabe in der Log-Leiste; Root nur per pkexec (Polkit-Dialog).
Scope {
    id: root

    property bool open: false
    // immer der Hauptmonitor, nie der fokussierte: große Panels öffnen stets dort mittig
    readonly property string screenName: Config.mainScreen

    // --- Ansicht
    property string page: "updates"     // updates | system | copr | flatpak | appimage
    property string query: ""
    property string filter: "all"       // all | explicit | updates
    property string view: "list"        // list | repos
    property string groupFilter: ""     // Quelle (Repo-Gruppe / Flatpak-Remote) innerhalb einer Liste
    property var meta: ({})             // page -> Zusatzdaten vom Backend (z. B. appimage.updater)
    property int sel: -1
    property string expandedKey: ""

    // --- Daten (immer komplett neu zuweisen, damit Bindings feuern)
    property var lists: ({})            // page -> installierte Einträge
    property var loadState: ({})        // page -> "loading" | "ready" | "error:…"
    property var repoLists: ({})        // page -> Paketquellen / Remotes
    property var upd: ({ system: [], flatpak: [] })
    property bool updBusy: false
    property real updAt: 0
    property var results: ({ key: "", items: [], error: "" })
    property bool searchBusy: false
    property var infos: ({})

    // --- Aktion / Log
    property bool busy: false
    property string busyTitle: ""
    property bool authWait: false       // Polkit-Dialog offen: Overlay weg, damit man ihn sieht
    property int doneCode: -1
    property bool logOpen: false
    property bool logShown: false
    property var confirm: null          // { title, text, rows, summary, warn, danger, okLabel, loading, run }
    property alias log: logModel

    readonly property string pkgBin: Quickshell.shellDir + "/../scripts/pkg"
    readonly property var pages: [
        { id: "updates", label: "Updates", icon: "update", hint: "All sources together", group: "" },
        { id: "system", label: "System", icon: "package_2", hint: "Fedora · Updates · RPM Fusion", group: "Core" },
        { id: "copr", label: "COPR", icon: "groups", hint: "Community repos", group: "Community" },
        { id: "terra", label: "Terra", icon: "forest", hint: "Fyra Labs repo", group: "Community" },
        { id: "flatpak", label: "Flatpak", icon: "deployed_code", hint: "Flathub · Fedora · user + system", group: "Sandboxed" },
        { id: "appimage", label: "AppImage", icon: "folder_zip", hint: "Single files", group: "Sandboxed" },
        { id: "vendors", label: "Vendors", icon: "storefront", hint: "Chrome · VS Code · Docker …", group: "Vendor repos" },
        { id: "devtools", label: "Dev tools", icon: "terminal", hint: "pipx · npm · cargo · go", group: "Dev tools" },
        { id: "local", label: "Local", icon: "folder_special", hint: "Own repos · .rpm files", group: "Local" }
    ]
    readonly property int updSystem: upd.system.filter(u => !u.copr).length
    readonly property int updCopr: upd.system.filter(u => u.copr).length
    readonly property int updFlatpak: upd.flatpak.length
    readonly property int updTotal: upd.system.length + upd.flatpak.length

    function pageInfo(id: string): var {
        return pages.find(p => p.id === id) || pages[0];
    }
    function countFor(id: string): int {
        if (id === "updates") return updTotal;
        if (id === "system") return updSystem;
        if (id === "copr") return updCopr;
        if (id === "flatpak") return updFlatpak;
        return 0;
    }

    // ------------------------------------------------------------ öffnen / schließen
    function toggle(): void {
        if (open) close(); else openIt();
    }
    function openIt(): void {
        if (open)
            return;
        sel = -1;
        expandedKey = "";
        view = "list";
        filter = "all";
        groupFilter = "";
        query = "";
        ensure(page);
        checkUpdates(false);
        Hypr.panelOpened("packages");
        open = true;
    }

    // Anderes Panel geht auf → dieses zu (Hypr.panelOpened)
    Connections {
        target: Hypr
        function onPanelOpened(name: string): void {
            if (name !== "packages" && root.open)
                root.close();
        }
    }
    function close(): void {
        open = false;
        confirm = null;
    }
    // Klick ins Leere (hinter dem Fenster): schließt – nicht mitten in einer Aktion, bei offener Bestätigung
    // oder solange der Passwort-Dialog (authWait) offen ist
    function dismiss(): void {
        if (!open || busy || authWait || confirm)
            return;
        close();
    }
    // Fokus-Grab hat sich gelöst: entweder Klick außerhalb (→ schließen) oder Fokus ging woanders hin
    // (neues Fenster, Dialog …) → nur schließen, wenn der Mauszeiger NICHT über dem Panel steht, sonst Grab neu setzen
    property bool grabArmed: true
    function grabCleared(): void {
        if (!open || busy || authWait || confirm) {
            grabArmed = false;
            rearm.restart();
            return;
        }
        cursorProc.running = true;
    }
    function cursorChecked(out: string): void {
        const m = out.trim().match(/^(-?\d+),\s*(-?\d+)/);
        const scr = win.screen;
        if (m && scr) {
            const px = parseInt(m[1]) - scr.x, py = parseInt(m[2]) - scr.y;
            const inside = px >= panel.x && px <= panel.x + panel.width && py >= panel.y && py <= panel.y + panel.height;
            if (inside && open) {
                grabArmed = false;
                rearm.restart();
                return;
            }
        }
        dismiss();
    }
    Timer {
        id: rearm
        interval: 400
        onTriggered: root.grabArmed = true
    }
    Process {
        id: cursorProc
        command: ["hyprctl", "cursorpos"]
        stdout: StdioCollector {
            onStreamFinished: root.cursorChecked(text)
        }
        onExited: (code, status) => { if (code !== 0) root.dismiss(); }
    }
    function setPage(id: string): void {
        if (id === page)
            return;
        page = id;
        query = "";
        filter = "all";
        groupFilter = "";
        view = "list";
        sel = -1;
        expandedKey = "";
        results = { key: "", items: [], error: "" };
        ensure(id);
        if (id === "updates")
            checkUpdates(false);
    }
    function cyclePage(delta: int): void {
        const i = pages.findIndex(p => p.id === page);
        setPage(pages[(i + delta + pages.length) % pages.length].id);
    }

    // ------------------------------------------------------------ Hilfsfunktionen
    // Backend-Aufruf: args -> JSON-Objekt an cb
    function pkg(args: var, cb: var): void {
        jobComp.createObject(root, { command: [pkgBin].concat(args), cb: cb, running: true });
    }
    function setMap(name: string, key: string, value: var): void {
        const m = Object.assign({}, root[name]);
        m[key] = value;
        root[name] = m;
    }

    // Liste einer Quelle laden (einmal, danach aus dem Cache)
    function ensure(p: string, force: bool): void {
        if (p === "updates")
            return;
        if (p === "terra")
            p = "vendors";
        if (!force && (loadState[p] === "loading" || loadState[p] === "ready"))
            return;
        setMap("loadState", p, "loading");
        pkg(["list", p], d => {
            if (d.ok) {
                setMap("lists", p, d.items);
                setMap("meta", p, d);
                setMap("loadState", p, "ready");
            } else {
                setMap("loadState", p, "error:" + (d.error || "failed"));
            }
        });
    }
    function loadRepos(p: string): void {
        if (p !== "system" && p !== "flatpak")
            return;
        setMap("loadState", p + ":repos", "loading");
        pkg(["repos", p], d => {
            if (d.ok)
                setMap("repoLists", p, d.items);
            setMap("loadState", p + ":repos", d.ok ? "ready" : "error:" + d.error);
        });
    }
    function setView(v: string): void {
        view = v;
        groupFilter = "";
        sel = -1;
        expandedKey = "";
        if (v === "repos" && !repoLists[page])
            loadRepos(page);
    }

    // Updates: System (dnf, inkl. COPR) + Flatpak parallel
    function checkUpdates(force: bool): void {
        if (updBusy || (!force && Date.now() - updAt < 600000))
            return;
        updBusy = true;
        let left = 2;
        const done = () => {
            if (--left === 0) {
                updBusy = false;
                updAt = Date.now();
            }
        };
        pkg(["updates", "system"], d => {
            if (d.ok)
                upd = { system: d.items, flatpak: upd.flatpak };
            done();
        });
        pkg(["updates", "flatpak"], d => {
            if (d.ok)
                upd = { system: upd.system, flatpak: d.items };
            done();
        });
    }
    function refreshAll(): void {
        pkg(["refresh"], () => checkUpdates(true));
        updBusy = true;
    }

    // ------------------------------------------------------------ Suche (Debounce, immer nur eine Anfrage)
    function searchable(): bool {
        return (page === "system" || page === "flatpak") && view === "list";
    }
    onQueryChanged: {
        sel = -1;
        expandedKey = "";
        if (searchable() && query.trim().length >= 2)
            debounce.restart();
        else
            debounce.stop();
    }
    Timer {
        id: debounce
        interval: 220
        onTriggered: root.runSearch(root.page, root.query.trim(), false)
    }
    function runSearch(p: string, q: string, isCopr: bool): void {
        if (!q)
            return;
        if (searchBusy)
            return;   // läuft schon eine: danach wird die neueste nachgeholt
        searchBusy = true;
        const key = p + "\n" + q;
        pkg(["search", p, q], d => {
            searchBusy = false;
            const cur = root.page + "\n" + root.query.trim();
            if (key === cur)
                results = { key: key, items: d.ok ? d.items : [], error: d.ok ? "" : (d.error || "search failed") };
            else if (root.searchable() && root.query.trim().length >= 2)
                root.runSearch(root.page, root.query.trim(), false);
        });
    }
    function searchCopr(): void {
        const q = query.trim();
        if (q)
            runSearch("copr", q, true);
    }
    readonly property bool resultsReady: results.key === page + "\n" + query.trim()

    // ------------------------------------------------------------ Zeilen für die Liste
    function tokens(q: string): var {
        return q.toLowerCase().split(/\s+/).filter(x => x);
    }
    function rank(it: var, toks: var): int {
        const n = (it.name || "").toLowerCase();
        const s = n + " " + (it.desc || "").toLowerCase() + " " + (it.id || "").toLowerCase();
        for (const t of toks)
            if (!s.includes(t))
                return -1;
        const q = toks.join(" ");
        if (n === q) return 0;
        if (n.startsWith(q)) return 1;
        if (toks.every(t => n.includes(t))) return 2;
        return 3;
    }
    readonly property var sysGroups: ({
        fedora: "Fedora", updates: "Updates", testing: "Updates testing", "rpmfusion-free": "RPM Fusion Free", "rpmfusion-nonfree": "RPM Fusion Nonfree",
        copr: "COPR", terra: "Terra", vendor: "Vendor", local: "Local", image: "Base image"
    })
    readonly property var sysGroupOrder: ["fedora", "updates", "testing", "rpmfusion-free", "rpmfusion-nonfree", "copr", "terra", "vendor", "local", "image"]
    readonly property var trustLabels: ({ official: "official", community: "community", "third-party": "third-party", local: "local" })

    // Flatpak: Remote -> lesbarer Name
    function flatGroup(repo: string): string {
        const r = (repo || "").split(",")[0];
        if (!r) return "other";
        if (r === "flathub") return "Flathub";
        if (r === "flathub-beta") return "Flathub Beta";
        if (r === "fedora") return "Fedora Flatpaks";
        if (r.endsWith("-origin")) return "Bundles";
        return r;
    }

    function computeRows(page: string, query: string, filter: string, view: string, lists: var, upd: var, results: var, repoLists: var): var {
        const q = query.trim();
        const toks = tokens(q);
        const um = {};
        for (const u of upd.system)
            um[u.id] = u;
        for (const u of upd.flatpak)
            um[u.id + "@" + u.scope] = u;
        const decorate = (it, src) => {
            const u = src === "system" ? um[it.id] : src === "flatpak" ? um[it.id + "@" + it.scope] : null;
            return Object.assign({}, it, { src: src, kind: "pkg", key: src + ":" + it.id + ":" + (it.scope || ""), upgrade: u ? u.version : "",
                group: src === "flatpak" ? flatGroup(it.repo) : it.group });
        };
        const filt = list => list.filter(r => !toks.length || rank(r, toks) >= 0);

        if (page === "updates") {
            const out = [];
            const section = (title, items, src, all) => {
                const sel = items.filter(u => !toks.length || rank(u, toks) >= 0);
                if (!sel.length)
                    return;
                out.push({ kind: "header", key: "h:" + title, title: title, count: sel.length, updateAll: all });
                for (const u of sel)
                    out.push(Object.assign({}, u, { src: src, kind: "pkg", key: "u:" + src + ":" + u.id + ":" + (u.scope || ""), upgrade: u.version, installed: true, group: src === "flatpak" ? flatGroup(u.repo) : u.group }));
            };
            section("System", upd.system.filter(u => !u.copr), "system", ["system", "update"]);
            section("COPR", upd.system.filter(u => u.copr), "system", null);
            section("Flatpak", upd.flatpak, "flatpak", ["flatpak", "update", "all"]);
            return out;
        }

        if (view === "repos") {
            const list = filt(repoLists[page] || []);
            const out = [];
            if (page === "system") {
                for (const g of sysGroupOrder) {
                    const grp = list.filter(r => r.group === g);
                    if (!grp.length)
                        continue;
                    out.push({ kind: "header", key: "hg:" + g, title: sysGroups[g], count: grp.length, sub: grp[0].note });
                    for (const r of grp)
                        out.push(Object.assign({}, r, { name: r.id, desc: r.desc, src: "system", kind: "dnfrepo", key: "r:system:" + r.id }));
                }
                return out;
            }
            return list.map(r => Object.assign({}, r, { src: page, kind: "remote", key: "r:" + page + ":" + r.id + ":" + (r.scope || "") }));
        }

        if (page === "copr") {
            const out = filt(lists.copr || []).map(r => Object.assign({}, r, { src: "copr", kind: "repo", key: "c:" + r.id }));
            if (q) {
                out.push({ kind: "coprsearch", key: "cs:" + q, q: q, busy: root.searchBusy, done: results.key === "copr\n" + q });
                if (results.key === "copr\n" + q)
                    for (const r of results.items)
                        out.push(Object.assign({}, r, { src: "copr", kind: "coprresult", key: "cr:" + r.id }));
            }
            return out;
        }

        if (page === "terra" || page === "vendors") {
            const sec = page === "terra" ? "community" : "vendor";
            const out = filt(lists.vendors || []).filter(v => v.section === sec).map(v => Object.assign({}, v, { src: "vendor", kind: "vendor", key: "v:" + v.id }));
            if (page === "terra")
                out.push({ kind: "note", key: "n:terra", text: "Terra is a community repo. Once it is set up, its packages show up in System under the Terra source." });
            else
                out.push({ kind: "note", key: "n:vendor", text: "Not included: " + ((root.meta.vendors && root.meta.vendors.notIncluded) || "") + ". Spotify: install it from the Flatpak tab." });
            return out;
        }

        if (page === "local") {
            const out = filt(lists.local || []).map(r => Object.assign({}, r, { name: r.id, src: "local", kind: "dnfrepo", key: "l:" + r.id }));
            if (/^(https:\/\/\S+|\/\S+)\.repo$/.test(q))
                out.unshift({ kind: "addrepo", key: "ar:" + q, url: q });
            if (!out.length || !q)
                out.push({ kind: "note", key: "n:local", text: "Type an https:// URL or an absolute path ending in .repo to add a repo (you confirm the command first). Drop a .rpm file onto this window to install it." });
            return out;
        }

        if (page === "devtools") {
            const items = filt(lists.devtools || []);
            const tools = (root.meta.devtools && root.meta.devtools.tools) || [];
            const out = [];
            for (const t of tools) {
                const mine = items.filter(i => i.tool === t.id);
                if (!t.present) {
                    out.push({ kind: "note", key: "n:" + t.id, text: t.id + " is not installed." });
                    continue;
                }
                out.push({ kind: "header", key: "h:" + t.id, title: t.id, count: mine.length, updateAll: t.id === "pipx" || t.id === "npm" ? ["devtools", "update", t.id] : null, noRoot: true });
                for (const i of mine)
                    out.push(Object.assign({}, i, { src: "devtools", kind: "pkg", key: "d:" + i.id, upgrade: "" }));
            }
            return out;
        }

        if (page === "appimage")
            return filt(lists.appimage || []).map(r => Object.assign({}, r, { src: "appimage", kind: "appimage", key: "a:" + r.id, updater: !!(root.meta.appimage && root.meta.appimage.updater) }));

        // system / flatpak
        const installed = lists[page] || [];
        if (q.length >= 2 && results.key === page + "\n" + q) {
            const instMap = {};
            for (const i of installed)
                instMap[i.id] = i;
            return results.items.map(r => decorate(Object.assign({}, r, instMap[r.id] ? { installed: true, scope: instMap[r.id].scope || r.scope } : {}), page));
        }
        let items = installed;
        if (toks.length) {
            items = [];
            for (const i of installed) {
                const k = rank(i, toks);
                if (k >= 0)
                    items.push([k, i]);
            }
            items.sort((a, b) => a[0] - b[0] || a[1].name.length - b[1].name.length);
            items = items.map(x => x[1]);
        }
        let rows = items.map(i => decorate(i, page));
        if (filter === "explicit")
            rows = rows.filter(r => r.explicit);
        else if (filter === "updates")
            rows = rows.filter(r => r.upgrade);
        return rows;
    }
    readonly property var baseRows: computeRows(page, query, filter, view, lists, upd, results, repoLists)
    readonly property bool chipsOn: view === "list" && (page === "system" || page === "flatpak")
    readonly property var rows: chipsOn && groupFilter ? baseRows.filter(r => r.group === groupFilter) : baseRows
    // Quellen-Chips mit Zähler (aus den Zeilen vor dem Quellenfilter)
    readonly property var chips: {
        if (!chipsOn)
            return [];
        const cnt = {};
        for (const r of baseRows)
            if (r.group)
                cnt[r.group] = (cnt[r.group] || 0) + 1;
        const keys = page === "system" ? sysGroupOrder.filter(g => cnt[g]) : Object.keys(cnt).sort((a, b) => cnt[b] - cnt[a]);
        return keys.map(g => ({ id: g, label: page === "system" ? sysGroups[g] : g, n: cnt[g] }));
    }

    function moveSel(d: int): void {
        let i = sel;
        const n = rows.length;
        if (!n)
            return;
        for (let k = 0; k < n; k++) {
            i = i + d;
            if (i < 0) i = 0;
            if (i >= n) i = n - 1;
            if (rows[i].kind !== "header")
                break;
        }
        sel = i;
    }
    function toggleExpand(r: var): void {
        if (!r || r.kind === "header" || r.kind === "coprsearch")
            return;
        expandedKey = expandedKey === r.key ? "" : r.key;
        if (expandedKey)
            loadInfo(r);
    }
    function loadInfo(r: var): void {
        if (infos[r.key])
            return;
        if (r.kind === "pkg" && (r.src === "system" || r.src === "flatpak")) {
            setMap("infos", r.key, { loading: true });
            pkg(["info", r.src, r.id, r.scope || "user"], d => setMap("infos", r.key, d.ok ? d : { error: d.error || "no info" }));
        } else if (r.kind === "repo") {
            setMap("infos", r.key, { loading: true });
            pkg(["copr-packages", r.id], d => setMap("infos", r.key, d.ok ? d : { error: d.error || "no packages" }));
        }
    }

    // ------------------------------------------------------------ Aktionen
    // Zeile + Verb -> (Bestätigung) -> Ausführen
    function request(op: string, r: var): void {
        if (busy)
            return;
        const nm = r.name || r.id;
        if (r.kind === "dnfrepo" && op === "repo-toggle") {
            const en = !r.enabled;
            const cmd = "pkexec dnf config-manager setopt " + r.id + ".enabled=" + (en ? "1" : "0");
            return ask({ title: (en ? "Enable " : "Disable ") + r.id + "?", text: r.note || "", code: [cmd, "(one-off alternative: dnf --enablerepo=" + r.id + " install <package>)"],
                danger: false, okLabel: en ? "Enable" : "Disable", run: () => runExec((en ? "Enable " : "Disable ") + r.id, ["system", en ? "repo-enable" : "repo-disable", r.id], true) });
        }
        if (r.kind === "addrepo") {
            const cmd = "pkexec dnf config-manager addrepo --from-repofile=" + r.url;
            return ask({ title: "Add repo from this file?", text: "Adds a third-party software source. Packages from it are installed as root, so only continue if you trust the source.", code: [cmd],
                danger: true, okLabel: "Add repo", run: () => runExec("Add repo " + r.url, ["system", "repo-add", r.url], true) });
        }
        if (r.src === "vendor" && op === "add")
            return vendorPreview(r);
        if (r.src === "system") {
            if (op === "update")
                return runExec("Update " + nm, ["system", "update", r.id], true);
            return whatif(op, r);
        }
        if (r.src === "flatpak") {
            if (op === "install")
                return flatpakInstall(r);
            if (op === "update")
                return runExec("Update " + nm, ["flatpak", "update", r.scope, r.id], r.scope === "system");
            if (op === "remove")
                return ask({ title: "Remove " + nm + "?", text: "Flatpak app (" + r.scope + "). Its settings and data stay in ~/.var/app.", danger: true, okLabel: "Remove",
                    run: () => runExec("Remove " + nm, ["flatpak", "remove", r.scope, r.id], r.scope === "system") });
            if (op === "remote-toggle")
                return runExec((r.enabled ? "Disable " : "Enable ") + r.name, ["flatpak", r.enabled ? "remote-disable" : "remote-enable", r.scope, r.id], r.scope === "system");
        }
        if (r.src === "copr") {
            if (op === "enable")
                return ask({ title: "Enable " + r.id + "?", text: "COPR repos are community builds without Fedora review. Packages from it can replace system packages.", danger: false, okLabel: "Enable",
                    run: () => runExec("Enable " + r.id, ["copr", "enable", r.id], true) });
            if (op === "disable")
                return runExec("Disable " + r.id, ["copr", "disable", r.id], true);
            if (op === "remove")
                return ask({ title: "Remove repo " + r.id + "?", text: "Deletes the repo file. Installed packages stay but get no more updates.", danger: true, okLabel: "Remove repo",
                    run: () => runExec("Remove repo " + r.id, ["copr", "remove", r.id], true) });
            if (op === "install-pkg")
                return whatif("install", r);
        }
        if (r.src === "appimage") {
            if (op === "run") {
                Quickshell.execDetached(["systemd-run", "--user", "--scope", "--quiet", "--collect", r.path]);
                return;
            }
            if (op === "remove")
                return ask({ title: "Delete " + r.name + "?", text: r.path + " will be deleted (and its desktop entry).", danger: true, okLabel: "Delete",
                    run: () => runExec("Delete " + r.name, ["appimage", "remove", r.path], false) });
            return runExec(({ "desktop-add": "Add menu entry for ", "desktop-remove": "Remove menu entry of ", chmod: "Make executable: ", update: "Update " })[op] + r.name, ["appimage", op, r.path], false);
        }
    }
    function ask(c: var): void {
        confirm = Object.assign({ rows: [], code: [], summary: "", warn: "", loading: false, refreshing: false, opt: null }, c);
    }
    // Hersteller-Repo: genau die Schritte zeigen, die als EIN pkexec laufen
    function vendorPreview(r: var): void {
        ask({ title: "Add repo: " + r.name + "?", text: "Loading the steps…", loading: true, danger: true, okLabel: "Add repo", run: null });
        const myTitle = confirm.title;
        pkg(["vendor-preview", r.id], d => {
            if (!confirm || confirm.title !== myTitle)
                return;
            confirm = Object.assign({}, confirm, {
                loading: false, blocked: !d.ok, code: d.ok ? d.commands : [],
                text: d.ok ? "Adds a third-party software source" + (r.section === "community" ? " (community, not reviewed by Fedora)" : " run by the vendor") + ". Its packages are installed as root, so only continue if you trust it. You get one password prompt."
                    + (d.note ? " " + d.note : "") : (d.error || "failed"),
                run: () => runExec("Add repo " + r.name, ["vendor", "add", r.id], true)
            });
        });
    }
    // .rpm-Datei(en) auf das Fenster gezogen: Vorschau (dnf --assumeno), dann bestätigen
    function dropFiles(urls: var): void {
        const f = urls.map(u => decodeURIComponent(String(u).replace(/^file:\/\//, ""))).find(p => p.toLowerCase().endsWith(".rpm"));
        if (f)
            whatif("install", { id: f, name: f.split("/").pop(), src: "system", file: true });
        else
            ask({ title: "Only .rpm files can be installed this way", text: "Dropped: " + urls.map(u => String(u).split("/").pop()).join(", "), okLabel: "OK", blocked: true });
    }
    // dnf-Transaktion vorab zeigen (--assumeno): was kommt dazu / geht sonst noch mit.
    // Beim Installieren zusätzlich Recommended (vorab an) und Suggested (aus), Befehlsvorschau = pkg preview.
    function whatifFields(op: string, d: var): var {
        const flat = [];
        for (const sec of (d.sections || [])) {
            flat.push({ h: sec.title });
            for (const p of sec.pkgs)
                flat.push({ name: p.name, version: p.version, size: p.size, repo: p.repo });
        }
        const extra = Math.max(0, (d.total || 0) - 1);
        const text = d.ok ? (op === "remove"
            ? (extra > 0 ? "dnf would also remove " + extra + " unused " + (extra === 1 ? "package" : "packages") + ": dependencies (also recommended ones) that nothing else needs." : "Nothing else is affected.")
            : (extra > 0 ? "Pulls in " + extra + " more " + (extra === 1 ? "package" : "packages") + "." : "No extra dependencies.")) : (d.error || "dnf refused");
        const crit = d.critical || [];
        return {
            rows: flat, summary: d.summary || "", text: text, blocked: !d.ok,
            warn: crit.length ? "Careful: this removes core packages (" + crit.join(", ") + ")." : (op === "remove" && (d.total || 0) >= 15 ? "That is a lot of packages. Check the list." : "")
        };
    }
    function whatif(op: string, r: var): void {
        const nm = r.name || r.id;
        const verb = op === "remove" ? "Remove" : "Install";
        const withOpt = op === "install" && !r.file && r.src === "system";
        ask({ title: verb + " " + nm + "?", text: "Checking what dnf would do…", loading: true, danger: op === "remove", okLabel: verb, run: null });
        const myTitle = confirm.title;
        const st = { wi: null, od: null, pv: null };
        let left = withOpt ? 3 : 2;
        const fin = () => {
            if (--left > 0 || !confirm || confirm.title !== myTitle)
                return;
            const c = Object.assign({}, confirm, whatifFields(op, st.wi), { loading: false, code: st.pv && st.pv.ok ? st.pv.commands : [] });
            if (withOpt) {
                const od = st.od && st.od.ok ? st.od.items[r.id] : null;
                c.optBase = r;
                c.optKind = "system";
                c.opt = od ? { rec: od.recommends.map(x => Object.assign({ on: true }, x)), sug: od.suggests.map(x => Object.assign({ on: false }, x)) } : { rec: [], sug: [] };
                c.run = cc => {
                    const sel = sysSel(cc);
                    runExec(verb + " " + nm, ["system", "install"].concat(sel.noWeak ? ["--no-weak"] : [], sel.names), true);
                };
            } else {
                c.run = () => runExec(verb + " " + nm, ["system", op === "install" && r.file ? "install-file" : op, r.id], true);
            }
            confirm = c;
        };
        pkg(["whatif", op, r.id], d => { st.wi = d; fin(); });
        pkg(["preview", "system", op === "install" && r.file ? "install-file" : op, r.id], d => { st.pv = d; fin(); });
        if (withOpt)
            pkg(["optdeps", r.id], d => { st.od = d; fin(); });
    }

    // Auswahl im Bestätigungsdialog -> Befehlsargumente. Etwas aus Recommended abgewählt: weak deps aus, gewählte Recommends explizit.
    function sysSel(c: var): var {
        const target = c.optBase.id;
        const rec = c.opt.rec.filter(x => !x.installed);
        const noWeak = rec.some(x => !x.on);
        const names = [target];
        if (noWeak)
            for (const x of rec)
                if (x.on)
                    names.push(x.name);
        for (const x of c.opt.sug)
            if (x.on && !x.installed)
                names.push(x.name);
        return { noWeak: noWeak, names: names };
    }
    function flatNames(c: var): var {
        return [c.optBase.id].concat(c.opt.sug.filter(x => x.on && !x.installed).map(x => x.name));
    }
    function toggleOpt(kind: string, i: int): void {
        if (!confirm || !confirm.opt || confirm.loading)
            return;
        const o = { rec: confirm.opt.rec.slice(), sug: confirm.opt.sug.slice() };
        const it = Object.assign({}, o[kind][i]);
        if (it.installed)
            return;
        it.on = !it.on;
        o[kind][i] = it;
        confirm = Object.assign({}, confirm, { opt: o, refreshing: true });
        optTimer.restart();
    }
    property int optSeq: 0
    Timer {
        id: optTimer
        interval: 350
        onTriggered: root.refreshOpt()
    }
    // Vorschau und (bei dnf) Transaktion für die aktuelle Auswahl neu holen
    function refreshOpt(): void {
        const c = confirm;
        if (!c || !c.optBase)
            return;
        const r = c.optBase;
        const tag = ++optSeq;
        let args, wiArgs = null;
        if (c.optKind === "flatpak") {
            args = ["flatpak", "install", r.scope, r.remote].concat(flatNames(c));
        } else {
            const sel = sysSel(c);
            args = ["system", "install"].concat(sel.noWeak ? ["--no-weak"] : [], sel.names);
            wiArgs = ["install"].concat(sel.noWeak ? ["--no-weak"] : [], sel.names);
        }
        let wi = null, pv = null, left = wiArgs ? 2 : 1;
        const fin = () => {
            if (--left > 0 || tag !== optSeq || !confirm || confirm.title !== c.title)
                return;
            const extra = wi ? whatifFields("install", wi) : {};
            confirm = Object.assign({}, confirm, extra, { refreshing: false, code: pv && pv.ok ? pv.commands : confirm.code });
        };
        pkg(["preview"].concat(args), d => { pv = d; fin(); });
        if (wiArgs)
            pkg(["whatif"].concat(wiArgs), d => { wi = d; fin(); });
    }
    // Flatpak-Installation: optionale Extensions anbieten (nur wenn es welche gibt), sonst direkt installieren
    function flatpakInstall(r: var): void {
        const nm = r.name || r.id;
        const direct = () => runExec("Install " + nm, ["flatpak", "install", r.scope, r.remote, r.id], r.scope === "system");
        ask({ title: "Install " + nm + "?", text: "Looking for optional extensions…", loading: true, danger: false, okLabel: "Install", run: null });
        const myTitle = confirm.title;
        pkg(["optdeps", "--flatpak", r.scope, r.remote, r.id], d => {
            if (!confirm || confirm.title !== myTitle)
                return;
            const sug = d.ok ? (d.items[r.id].suggests || []).filter(x => !x.installed) : [];
            if (!sug.length) {
                confirm = null;
                direct();
                return;
            }
            const c = Object.assign({}, confirm, { loading: false, optBase: r, optKind: "flatpak", opt: { rec: [], sug: sug.map(x => Object.assign({ on: false }, x)) },
                text: "From " + r.remote + " (" + r.scope + "). Optional extensions are not installed unless you tick them.",
                run: cc => runExec("Install " + nm, ["flatpak", "install", r.scope, r.remote].concat(flatNames(cc)), r.scope === "system") });
            confirm = c;
            refreshOpt();
        });
    }
    function confirmYes(): void {
        const c = confirm;
        if (!c || c.loading || c.refreshing || c.blocked || !c.run)
            return;
        confirm = null;
        c.run(c);
    }

    // Lange Aktion: systemd-run --user --pipe (überlebt qs-Neustart), Ausgabe live ins Log
    function runExec(title: string, args: var, needsAuth: bool): void {
        if (busy)
            return;
        logModel.clear();
        logShown = true;
        busy = true;
        busyTitle = title;
        doneCode = -1;
        authWait = needsAuth && open;
        if (authWait)
            authTimer.restart();
        logModel.append({ line: title + "…", kind: "head" });
        actProc.command = ["systemd-run", "--user", "--pipe", "--wait", "--collect", "--quiet", "--unit=pkg-act-" + Date.now(), pkgBin, "exec"].concat(args);
        actProc.running = true;
    }
    function logLine(line: string): void {
        if (line.startsWith("@@done ")) {
            doneCode = parseInt(line.slice(7));
            return;
        }
        if (authWait && !line.startsWith("$ "))
            authWait = false;
        const kind = line.startsWith("$ ") ? "cmd" : /^(error|Error|Failed|Problem)/.test(line) ? "err" : "out";
        logModel.append({ line: line, kind: kind });
        if (logModel.count > 500)
            logModel.remove(0, 100);
    }
    function actDone(code: int): void {
        const ok = doneCode >= 0 ? doneCode === 0 : code === 0;
        busy = false;
        authWait = false;
        authTimer.stop();
        logModel.append({ line: ok ? "Done." : "Failed (exit " + (doneCode >= 0 ? doneCode : code) + ").", kind: ok ? "ok" : "err" });
        if (ok)
            doneOk = true;
        else
            doneOk = false;
        // Listen neu, Zähler neu
        lists = {};
        loadState = {};
        repoLists = {};
        infos = {};
        results = { key: "", items: [], error: "" };
        if (open) {
            ensure(page);
            if (view === "repos")
                loadRepos(page);
        }
        updAt = 0;
        checkUpdates(true);
        if (!open)
            Quickshell.execDetached(["notify-send", "-a", "Packages", ok ? "Done" : "Failed", busyTitle]);
        else if (!ok)
            logOpen = true;
        if (root.query.trim().length >= 2 && searchable())
            debounce.restart();
    }
    property bool doneOk: true

    Timer {
        id: authTimer
        interval: 120000
        onTriggered: root.authWait = false
    }

    Process {
        id: actProc
        stdout: SplitParser {
            onRead: line => root.logLine(line)
        }
        onExited: (code, status) => root.actDone(code)
    }
    ListModel {
        id: logModel
    }

    Component {
        id: jobComp

        Process {
            id: job

            property var cb

            stdout: StdioCollector {
                onStreamFinished: {
                    let d;
                    try {
                        d = JSON.parse(text);
                    } catch (e) {
                        d = { ok: false, error: "no answer from scripts/pkg" };
                    }
                    job.cb(d);
                }
            }
            onExited: job.destroy(2000)
        }
    }

    IpcHandler {
        target: "packages"

        function toggle(): void {
            root.toggle();
        }
        function open(): void {
            root.openIt();
        }
        function close(): void {
            root.close();
        }
        // zum Testen: Reiter wählen / Suchtext setzen / Zeile aufklappen
        function page(name: string): void {
            root.openIt();
            root.setPage(name);
        }
        function search(text: string): void {
            root.query = text;
        }
        // zum Testen: Aktionspfad ohne Wirkung (pkg exec --dry-run über systemd-run, wie echt, aber nur Befehl ausgeben)
        function dry(): void {
            root.runExec("Dry run (nothing is changed)", ["--dry-run", "system", "install", "htop"], false);
        }
        // zum Testen: Bestätigungsdialog (nur --assumeno, ändert nichts, solange man nicht bestätigt)
        function preview(op: string, name: string): void {
            root.whatif(op, { id: name, name: name, src: "system" });
        }
        // zum Testen: Vorschau "Add repo" eines Herstellers (nur Anzeige, nichts passiert ohne Klick auf Add)
        function vendor(id: string): void {
            const v = (root.lists.vendors || []).find(x => x.id === id);
            if (v)
                root.request("add", Object.assign({ src: "vendor" }, v));
        }
        function opt(kind: string, i: int): void {
            root.toggleOpt(kind, i);
        }
        function repos(): void {
            root.setView("repos");
        }
        // zum Testen: .rpm-Vorschau
        function rpm(path: string): void {
            root.dropFiles(["file://" + path]);
        }
        function expand(i: int): void {
            root.toggleExpand(root.rows[i]);
        }
    }

    PanelWindow {
        id: win

        // weich auf, sofort tippbar
        property real progress: root.open ? 1 : 0
        Behavior on progress { NumberAnimation { duration: root.open ? 150 : 110; easing.type: Easing.OutCubic } }

        screen: Quickshell.screens.find(s => s.name === root.screenName) ?? Quickshell.screens[0]
        visible: (root.open || progress > 0) && !root.authWait
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

        // Klick auf ein anderes Fenster/einen anderen Monitor schließt – nicht mitten in einer Aktion
        // (Passwort-Dialog nimmt sonst den Fokus). Fokus-Wechsel ohne Klick schließt nicht (root.grabCleared).
        HyprlandFocusGrab {
            active: root.open && win.visible && !root.busy && !root.authWait && root.grabArmed && Quickshell.env("PKG_NOGRAB") !== "1"   // PKG_NOGRAB=1 nur zum Testen
            windows: [win]
            onCleared: root.grabCleared()
        }

        readonly property bool blurOn: root.open && progress > 0.4
        BackgroundEffect.blurRegion: Region {
            Region { x: 0; y: 0; width: 1; height: 1 }
            Region { item: win.blurOn ? backdrop : null }
            Region { item: panel; radius: Theme.radiusXl }
        }

        onVisibleChanged: if (visible && root.open) panel.focusSearch()
        Connections {
            target: root
            function onOpenChanged() { if (root.open) panel.focusSearch(); }
        }

        Rectangle {
            id: backdrop
            anchors.fill: parent
            opacity: win.progress
            color: Theme.dim
            // Klick ins Leere hinter dem Panel: sofort beim Drücken (jede Taste), nicht erst beim Loslassen
            MouseArea {
                anchors.fill: parent
                acceptedButtons: Qt.AllButtons
                onPressed: root.dismiss()
            }
        }

        PkgPanel {
            id: panel

            pk: root
            width: Math.min(1140, parent.width - 80)
            height: Math.min(780, parent.height - 100)
            x: (parent.width - width) / 2
            y: (parent.height - height) / 2 - 10 + (1 - win.progress) * 14
            opacity: win.progress
            scale: 0.98 + 0.02 * win.progress

            // Klick auf freie Fläche im Fenster schluckt das Fenster selbst – sonst fiele er auf backdrop und schlösse
            MouseArea {
                anchors.fill: parent
                z: -1
                acceptedButtons: Qt.AllButtons
            }
        }
    }
}
