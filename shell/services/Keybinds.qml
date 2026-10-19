pragma Singleton
import QtQuick
import Quickshell
import Quickshell.Io

// Tastenkürzel zur Laufzeit: live gebundene Kürzel aus `hyprctl binds -j` + Beschreibungen/Abschnitte aus den
// #-Kommentaren der Hyprland-Konfiguration (modules/keys/keybinds.py liest beides, folgt den source-Zeilen).
// Nichts ist hartcodiert: ein neuer Bind in hypr/binds.conf taucht nach refresh() von selbst auf.
//
// Ergebnis `cats`: [{ name, media, rows: [{ title, sub, chords: [{ mods, keys, tag }], search }] }]
//  - Varianten desselben Kürzels (Super+1…9, Pfeile) und gleiche Aktion auf mehreren Tasten ("Print / Super+Shift+S")
//    sind zu EINER Zeile zusammengefasst
//  - Loslassen-Binds von Modifikatoren (bindirt , SUPER_L) sind technisch und fehlen; "Super antippen" bleibt
//  - XF86-Tasten bilden die Kategorie "Media keys" (media: true, in der Ansicht eingeklappt)
//  - Titel: Inline-Kommentar am Bind ("bind = … # Next window") > kurzer Einzel-Kommentar darüber > aus Dispatcher/Arg abgeleitet
//  - Beschreibung: Kommentar über den Binds, nur wenn er eindeutig zu genau einer Zeile gehört (sonst Notiz, wird ignoriert)
//  - Kategorien: Abschnittsnamen "# ---------- Name ----------" in hypr/binds.conf
Singleton {
    id: root

    property var cats: []
    property int count: 0
    property bool loaded: false
    property bool failed: false

    // App-Kürzel (Cheat-Sheet) aus config/appkeys/*.json, gelesen von modules/keys/appkeys.py:
    // [{ id, name, about, group ("app" | "shell"), classes: [klein], title: Regex, cats: [{ name, note, rows }] }]
    // Zeilen haben dasselbe Format wie oben (title, sub, chords, search).
    property var apps: []
    property var appErrors: []

    function refresh(): void {
        if (!proc.running)
            proc.running = true;
        if (!appProc.running)
            appProc.running = true;
    }

    // Apps, deren Kürzel zum Fenster passen (Klasse, optional Titel-Regex). Titel-Treffer (yazi in Kitty) zuerst,
    // dann die App, deren Klassenliste diese Klasse weiter vorn hat (sshs vor Kitty).
    function appsFor(cls: string, title: string): var {
        const c = (cls || "").toLowerCase();
        if (!c)
            return [];
        const hits = [];
        for (const a of apps) {
            if (a.group !== "app")
                continue;
            const i = a.classes.indexOf(c);
            if (i < 0)
                continue;
            if (a.title) {
                let ok = false;
                try {
                    ok = new RegExp(a.title, "i").test(title || "");
                } catch (e) {}
                if (!ok)
                    continue;
            }
            hits.push({ app: a, rank: (a.title ? 0 : 100) + i });
        }
        return hits.sort((x, y) => x.rank - y.rank).map(h => h.app);
    }

    // Suchtext einer Zeile: Tasten (auch ausgeschrieben), Titel, Beschreibung, Kategorie, Gruppe/App
    function searchOf(chords: var, title: string, sub: string, cat: string, extra: string): string {
        const kw = [];
        for (const c of chords) {
            kw.push(c.mods.join(" "), c.keys.join(" "), c.mods.concat(c.keys).join("+"));
            if (c.mods.includes("Super"))
                kw.push("win windows meta");
            if (c.mods.includes("Ctrl"))
                kw.push("strg control");
            if (c.keys.some(k => "←↑↓→".includes(k)))
                kw.push("arrow arrows");
        }
        return (kw.join(" ") + " " + title + " " + sub + " " + cat + " " + extra).toLowerCase();
    }

    Process {
        id: appProc
        command: ["python3", "-I", Quickshell.shellDir + "/modules/keys/appkeys.py"]
        stdout: StdioCollector {
            onStreamFinished: {
                try {
                    const d = JSON.parse(text);
                    root.apps = d.apps.map(a => ({
                        id: a.id, name: a.name, about: a.about, group: a.group, classes: a.classes, title: a.title,
                        cats: a.sections.map(s => ({
                            name: s.name, note: s.note, media: false,
                            rows: s.rows.map((r, i) => Object.assign({}, r, {
                                order: i,
                                search: root.searchOf(r.chords, r.title, r.sub, s.name, a.name + " " + a.id + " " + a.classes.join(" "))
                            }))
                        }))
                    }));
                    root.appErrors = d.errors;
                    for (const e of d.errors)
                        console.warn("Keybinds appkeys: " + e);
                } catch (e) {
                    console.warn("Keybinds appkeys: " + e);
                    root.appErrors = [String(e)];
                }
            }
        }
    }

    Process {
        id: proc
        command: ["python3", "-I", Quickshell.shellDir + "/modules/keys/keybinds.py"]
        stdout: StdioCollector {
            onStreamFinished: {
                try {
                    const r = root.build(JSON.parse(text));
                    root.cats = r.cats;
                    root.count = r.count;
                    root.failed = false;
                } catch (e) {
                    console.warn("Keybinds: " + e);
                    root.failed = true;
                }
                root.loaded = true;
            }
        }
    }

    // ---------- Namen ----------
    readonly property var modDefs: [[64, "Super"], [4, "Ctrl"], [8, "Alt"], [1, "Shift"]]
    readonly property var modKeyMask: ({ super_l: 64, super_r: 64, meta_l: 64, meta_r: 64, alt_l: 8, alt_r: 8, control_l: 4, control_r: 4, shift_l: 1, shift_r: 1 })
    readonly property var confMods: ({ SUPER: 64, WIN: 64, SUPER_L: 64, MOD4: 64, SHIFT: 1, CTRL: 4, CONTROL: 4, ALT: 8, MOD1: 8 })
    readonly property var arrowGlyph: ({ left: "←", right: "→", up: "↑", down: "↓" })
    readonly property var arrowOrder: ["←", "↑", "↓", "→"]
    readonly property var dirName: ({ l: "left", r: "right", u: "up", d: "down" })
    readonly property var keyNames: ({
        return: "Enter", escape: "Esc", space: "Space", period: ".", comma: ",", minus: "-", equal: "=", slash: "/", backslash: "\\",
        tab: "Tab", delete: "Del", backspace: "⌫", print: "Print", grave: "`", home: "Home", end: "End", prior: "PgUp", next: "PgDn",
        xf86audioraisevolume: "Vol +", xf86audiolowervolume: "Vol −", xf86audiomute: "Mute", xf86audiomicmute: "Mic mute",
        xf86audioplay: "Play", xf86audiopause: "Pause", xf86audionext: "Next", xf86audioprev: "Prev", xf86audiostop: "Stop",
        xf86monbrightnessup: "Bright +", xf86monbrightnessdown: "Bright −", xf86poweroff: "Power",
        "mouse:272": "Mouse left", "mouse:273": "Mouse right", "mouse:274": "Mouse middle"
    })

    function cap(s: string): string {
        return s ? s[0].toUpperCase() + s.slice(1) : s;
    }
    // "goDesk" -> "go desk", "move_to" -> "move to"
    function words(s: string): string {
        return String(s).replace(/([a-z0-9])([A-Z])/g, "$1 $2").replace(/[_-]+/g, " ").toLowerCase();
    }
    function modNames(mask: int): var {
        return modDefs.filter(m => mask & m[0]).map(m => m[1]);
    }
    function maskOfConf(mods: string): int {
        let m = 0;
        for (const t of String(mods).toUpperCase().split(/[\s,+]+/))
            m |= confMods[t] || 0;
        return m;
    }
    // Zifferreihe liegt auf den Keycodes 10…19 (layoutunabhängig), 49 ist die Taste links neben der 1
    function codeNum(key: string): int {
        const m = /^code:(\d+)$/.exec(key);
        return m ? parseInt(m[1]) : -1;
    }
    function keyClass(key: string): string {
        const c = codeNum(key);
        if (c >= 10 && c <= 19)
            return "digit";
        if (/^[0-9]$/.test(key))
            return "digit";
        if (arrowGlyph[key.toLowerCase()])
            return "arrow";
        return "";
    }
    function digitOf(key: string): int {
        const c = codeNum(key);
        return c >= 10 ? (c - 9) % 10 : parseInt(key);
    }
    function prettyKey(key: string, layout: string): string {
        const lk = key.toLowerCase();
        if (arrowGlyph[lk])
            return arrowGlyph[lk];
        if (keyNames[lk])
            return keyNames[lk];
        const c = codeNum(key);
        if (c >= 10 && c <= 19)
            return String((c - 9) % 10);
        if (c === 49)
            return /^us|^en/.test(layout) ? "`" : "^";
        if (c >= 0)
            return "Key " + c;
        if (/^xf86/.test(lk))
            return cap(words(key.slice(4)));
        if (key.length === 1)
            return key.toUpperCase();
        if (/^f\d+$/.test(lk))
            return key.toUpperCase();
        return cap(key);
    }

    // ---------- Titel aus Dispatcher/Arg ----------
    function appName(token: string): string {
        const id = token.replace(/\.desktop$/, "");
        const e = DesktopEntries.byId(id) ?? DesktopEntries.heuristicLookup(id);
        if (e && e.name)
            return e.name;
        return cap(id.split(".").pop());
    }
    function deriveExec(arg: string): string {
        let t = arg.trim().split(/\s+/).filter(x => x);
        if (!t.length)
            return "Run command";
        // uwsm app -- <ziel>
        if (t[0] === "uwsm" && t[1] === "app") {
            t = t.slice(t.indexOf("--") + 1);
            if (t.length && /\.desktop$/.test(t[0]))
                return "Launch " + appName(t[0]);
        }
        // qs ipc … call <target> <funktion> [args]
        if (t[0] === "qs" && t.includes("ipc") && t.includes("call")) {
            const k = t.indexOf("call");
            const rest = t.slice(k + 3).join(" ");
            return cap(t[k + 1] || "shell") + (t[k + 2] ? " " + words(t[k + 2]) : "") + (rest ? " " + rest : "");
        }
        // hyprctl [--batch] "dispatch <name> <arg> ; …": erster Dispatch gibt den Titel
        if (t[0] === "hyprctl") {
            const d = /dispatch\s+(\w+)\s*([^;"']*)/.exec(arg);
            if (d)
                return derive(d[1], d[2].trim(), false);
        }
        // wpctl (Lautstärke/Stumm)
        if (t[0] === "wpctl") {
            const src = /SOURCE/.test(arg);
            const pct = (/(\d+)%([+-])/.exec(arg) || [])[0];
            if (t[1] === "set-mute")
                return src ? "Mute microphone" : "Mute";
            if (t[1] === "set-volume")
                return pct ? "Volume " + (pct.endsWith("+") ? "up " : "down ") + pct.slice(0, -1) : "Set volume";
        }
        const base = t[0].split("/").pop();
        const rest = t.slice(1).filter(x => !x.startsWith("-")).slice(0, 2).join(" ");
        return cap(base) + (rest ? " " + rest : "");
    }
    function derive(disp: string, arg: string, clustered: bool): string {
        arg = (arg || "").trim();
        switch (disp) {
        case "exec":
            return deriveExec(arg);
        case "mouse":
            return arg === "movewindow" ? "Move window (drag)" : arg === "resizewindow" ? "Resize window (drag)" : cap(words(arg)) + " (drag)";
        case "movefocus":
            return clustered ? "Focus window" : "Focus " + (dirName[arg] || arg);
        case "movewindow":
            if (arg.startsWith("mon:"))
                return "Move window to monitor" + (clustered ? "" : " " + arg.slice(4));
            return clustered ? "Move window" : "Move window " + (dirName[arg] || arg);
        case "fullscreen":
            return arg === "1" ? "Maximize" : arg === "0" ? "Fullscreen" : "Fullscreen (" + arg + ")";
        case "focusmonitor":
            return "Focus monitor " + arg;
        case "killactive":
            return "Close window";
        case "togglefloating":
            return "Toggle floating";
        case "layoutmsg":
            return arg === "togglesplit" ? "Toggle split" : cap(words(arg));
        case "workspace":
            return "Go to workspace " + arg;
        case "movetoworkspace":
        case "movetoworkspacesilent":
            return "Move to workspace " + arg;
        case "exit":
            return "Exit Hyprland";
        case "releaseinputcapture":
            return "Release input capture";
        }
        return cap(words(disp)) + (arg ? " " + arg : "");
    }

    // ---------- Aufbau ----------
    function build(data: var): var {
        const layout = data.layout || "";
        // Konfig-Infos (Abschnitt, Kommentar) je Kürzel: Maske|losgelassen|Maus|Taste
        const confOf = {};
        data.conf.forEach((c, i) => {
            const k = [maskOfConf(c.mods) & ~18, c.flags.includes("r") ? 1 : 0, c.flags.includes("m") ? 1 : 0, c.key.toLowerCase()].join("|");
            if (!(k in confOf))
                confOf[k] = Object.assign({ order: i }, c);
        });
        const blockSize = {};
        const entries = [];
        data.binds.forEach((b, i) => {
            const key = (b.key || (b.keycode ? "code:" + b.keycode : "")).trim();
            const mask = b.modmask & ~18;   // CapsLock/NumLock ignorieren
            const rel = b.release ? 1 : 0;
            const mouse = b.mouse ? 1 : 0;
            // technisch: Modifier loslassen ohne Modifier (bindirt , SUPER_L)
            if (rel && !mask && modKeyMask[key.toLowerCase()])
                return;
            // Submap „modal“ (Kürzel-Sperre hinter offenen Panels, Hypr.setModal) ist kein eigenes Kürzel
            if (b.submap)
                return;
            const c = confOf[[mask, rel, mouse, key.toLowerCase()].join("|")] || null;
            const e = {
                mask: mask, key: key, rel: rel, mouse: mouse, disp: b.dispatcher, arg: b.arg || "",
                section: c ? c.section : "", comment: c ? c.comment : "", block: c ? c.block : 0,
                first: c ? c.first : false, trail: c ? c.trail : "", order: c ? c.order : 100000 + i
            };
            e.cat = /^xf86/i.test(key) ? "Media keys" : (e.section || "Other");
            if (e.block)
                blockSize[e.block] = (blockSize[e.block] || 0) + 1;
            entries.push(e);
        });
        entries.sort((a, b) => a.order - b.order);

        // Schritt A: Ziffern-/Pfeilvarianten desselben Kürzels zu einem Akkord
        const chords = [];
        const open = new Map();
        for (const e of entries) {
            // Pfeile bei exec nicht bündeln: die Richtung steckt im letzten Wort (nextDesk/prevDesk), nicht im Ziel
            let cls = e.rel || e.mouse ? "" : keyClass(e.key);
            if (cls === "arrow" && e.disp === "exec")
                cls = "";
            if (cls) {
                // gleicher Inline-Titel = vom Autor gewollte Gruppe, sonst gleicher Arg-Stamm (letztes Wort variiert)
                const stem = e.trail ? "T:" + e.trail : e.arg.replace(/\s*\S+$/, "");
                const sig = [e.cat, e.mask, e.disp, stem, cls].join("|");
                let g = open.get(sig);
                if (!g) {
                    g = { members: [], cls: cls, stem: stem };
                    open.set(sig, g);
                    chords.push(g);
                }
                g.members.push(e);
            } else {
                chords.push({ members: [e], cls: "", stem: "" });
            }
        }

        // Schritt B: gleiche Aktion auf mehreren Tasten = eine Zeile mit mehreren Akkorden
        const rows = new Map();
        for (const g of chords) {
            const e = g.members[0];
            if (g.members.length < 2)
                g.cls = "";
            const argKey = g.cls ? g.stem : e.arg;
            const sig = [e.cat, e.disp, argKey, e.rel, e.mouse, g.cls].join("|");
            let r = rows.get(sig);
            if (!r) {
                r = { cat: e.cat, disp: e.disp, argKey: argKey, cls: g.cls, chords: [], members: [], order: e.order };
                rows.set(sig, r);
            }
            r.chords.push(g);
            r.members.push(...g.members);
        }

        // Kommentarblock gilt nur dann als Beschreibung, wenn er sich auf genau EINE Zeile bezieht
        const blockRows = {};
        for (const [sig, r] of rows)
            for (const m of r.members)
                if (m.block)
                    (blockRows[m.block] = blockRows[m.block] || new Set()).add(sig);
        const byCat = new Map();
        for (const [sig, r] of rows) {
            const first = r.members.slice().sort((a, b) => a.order - b.order)[0];
            const trail = r.members.map(m => m.trail).find(t => t) || "";
            const flat = first.comment.length > 0 && first.first;
            const blockTitle = flat && blockSize[first.block] === 1 && first.comment.length <= 44 ? first.comment : "";
            const title = trail || blockTitle || derive(first.disp, r.argKey, !!r.cls);
            let sub = "";
            if (!blockTitle && flat && blockRows[first.block].size === 1)
                sub = first.comment;

            const outChords = r.chords.map(g => {
                const m = g.members[0];
                let mask = m.mask;
                let keys, tag = "";
                if (g.cls === "digit") {
                    const v = g.members.map(x => digitOf(x.key)).sort((a, b) => a - b);
                    const contiguous = v.every((x, i) => i === 0 || x === v[i - 1] + 1);
                    keys = [contiguous ? v[0] + "…" + v[v.length - 1] : v.join(" ")];
                } else if (g.cls === "arrow") {
                    keys = g.members.map(x => prettyKey(x.key, layout)).sort((a, b) => arrowOrder.indexOf(a) - arrowOrder.indexOf(b));
                } else if (m.rel && modKeyMask[m.key.toLowerCase()]) {
                    // Modifier allein antippen (bindr = SUPER, SUPER_L)
                    mask &= ~modKeyMask[m.key.toLowerCase()];
                    keys = [modNames(modKeyMask[m.key.toLowerCase()])[0]];
                    tag = "tap";
                } else {
                    keys = [prettyKey(m.key, layout)];
                    if (m.rel)
                        tag = "on release";
                }
                return { mods: modNames(mask), keys: keys, tag: tag };
            }).sort((a, b) => a.mods.length - b.mods.length);

            // Suchtext: Tasten (auch ausgeschrieben), Titel, Beschreibung, Kategorie
            const kw = ["shell desktop hyprland"];
            if (r.cls === "digit")
                kw.push("0 1 2 3 4 5 6 7 8 9 number digit");
            if (r.cls === "arrow")
                kw.push("arrow arrows left right up down");
            const search = searchOf(outChords, title, sub, r.cat, kw.join(" "));

            let c = byCat.get(r.cat);
            if (!c) {
                c = { name: r.cat, media: r.cat === "Media keys", rows: [], order: r.order };
                byCat.set(r.cat, c);
            }
            c.rows.push({ title: title, sub: sub, chords: outChords, search: search, order: r.order });
        }
        const cats = Array.from(byCat.values()).sort((a, b) => (a.media - b.media) || (a.order - b.order));
        cats.forEach(c => c.rows.sort((a, b) => a.order - b.order));
        return { cats: cats, count: cats.reduce((n, c) => n + c.rows.length, 0) };
    }
}
