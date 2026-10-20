pragma Singleton
import QtQuick
import Quickshell
import Quickshell.Io

// Web-Kürzel für den Launcher: config/launcher/web.json
//   { "g": { "name": "Google", "url": "https://www.google.com/search?q={q}" }, … }
// Tippen: „g wetter berlin“ + Enter -> öffnet die Seite in Helium. {q} wird URL-kodiert eingesetzt.
// Datei wird beobachtet (Änderung gilt sofort). Ungültige Einträge werden übersprungen, Grund steht in `problem`.
// Reserviert (gehört dem Launcher): c
Singleton {
    id: root

    readonly property string file: Quickshell.shellDir + "/../config/launcher/web.json"
    readonly property var reserved: ["c"]

    property var list: []          // [{ key, name, url, host }] in Dateireihenfolge
    property string problem: ""    // leer = alles ok
    readonly property string defaultKey: list.length ? list[0].key : ""
    readonly property string chipPrefix: defaultKey ? defaultKey + " " : ""

    function find(key: string): var {
        const k = String(key || "").toLowerCase();
        return list.find(w => w.key === k) ?? null;
    }

    // Adresse für Kürzel + Suchtext; leerer Text -> Startseite der Seite
    function urlFor(w: var, q: string): string {
        const t = String(q || "").trim();
        if (!t)
            return w.url.replace(/^(https?:\/\/[^\/?#]+).*$/i, "$1/");
        return w.url.split("{q}").join(encodeURIComponent(t));
    }

    function open(w: var, q: string): void {
        // nur http(s); als Argument-Liste, nie über eine Shell
        Launch.cmd(["helium", urlFor(w, q)]);
    }

    function parse(txt: string): void {
        let d;
        try {
            d = JSON.parse(txt);
        } catch (e) {
            problem = "web.json is not valid JSON";
            return;
        }
        const out = [];
        const bad = [];
        for (const key of Object.keys(d || {})) {
            const w = d[key];
            const k = key.toLowerCase();
            if (!/^[a-z0-9_.-]+$/.test(k) || root.reserved.includes(k) || out.some(o => o.key === k)) {
                bad.push(key);
                continue;
            }
            if (!w || typeof w.url !== "string" || !/^https?:\/\/[^\s]+$/i.test(w.url) || !w.url.includes("{q}")) {
                bad.push(key);
                continue;
            }
            out.push({ key: k, name: String(w.name || key), url: w.url, host: w.url.replace(/^https?:\/\//i, "").split(/[\/?#]/)[0].replace(/^www\./, "") });
        }
        list = out;
        problem = bad.length ? "web.json: skipped " + bad.join(", ") + " (needs http(s) url with {q}; key not reserved)" : "";
    }

    FileView {
        path: root.file
        watchChanges: true
        printErrors: false
        onFileChanged: reload()
        onLoaded: root.parse(text())
        onLoadFailed: { root.list = []; root.problem = "config/launcher/web.json not found"; }
    }
}
