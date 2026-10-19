pragma Singleton
import QtQuick
import Quickshell
import Quickshell.Io

// Website-Icons für das Passwort-Panel. Abruf macht scripts/favicons (direkt von der Seite, nur die Domain,
// kein Dritter); Cache ~/.cache/desktop/favicons/<domain>.png. Hier: Liste der vorhandenen Icons, Lauf mit Fortschritt,
// Einstellung „Auto“ (lädt beim Öffnen des Panels fehlende Icons nach; Datei ~/.config/desktop/favicons.json).
Singleton {
    id: root

    readonly property string bin: Quickshell.shellDir + "/../scripts/favicons"
    readonly property string dir: Quickshell.env("HOME") + "/.cache/desktop/favicons"

    property var have: ({})          // domain -> Zähler (ändert sich bei neuem Icon -> Bild lädt neu)
    property bool auto: false
    property bool running: false
    property int total: 0
    property int done: 0
    property int fetched: 0          // neu geholt in diesem Lauf
    property int failed: 0           // Netzfehler in diesem Lauf (nächster Lauf versucht es wieder)
    property string msg: ""
    property double lastAuto: 0
    property int counter: 0
    readonly property int haveCount: Object.keys(have).length

    function hostOf(url: string): string {
        return (url || "").replace(/^[a-z]+:\/\//i, "").split("/")[0].replace(/^[^@]*@/, "").replace(/:\d+$/, "").replace(/^www\./, "").toLowerCase();
    }
    // file://-URL des Icons, "" wenn keins da ist (dann Buchstaben-Kachel)
    function src(domain: string): string {
        const v = have[domain];
        return v ? "file://" + dir + "/" + domain + ".png?v=" + v : "";
    }

    // Domains der Einträge, in der Reihenfolge der Liste ab `from` (sichtbare zuerst), ohne Doppelte
    function domainsOf(items: var, getDomain: var, from: int): var {
        const out = [], seen = {};
        const n = items.length;
        for (let k = 0; k < n; k++) {
            const d = getDomain(items[(from + k) % n]);
            if (d && !seen[d]) {
                seen[d] = true;
                out.push(d);
            }
        }
        return out;
    }

    function refresh(): void {
        listProc.running = true;
    }
    // domains: Liste von Hosts; force: alles neu holen (auch vorhandene)
    function start(domains: var, force: bool): void {
        if (running || !domains || domains.length === 0)
            return;
        total = domains.length;
        done = 0;
        fetched = 0;
        failed = 0;
        msg = "";
        running = true;
        runProc.command = [bin, "run"].concat(force ? ["--force"] : []).concat(domains);
        runProc.running = true;
    }
    function stop(): void {
        if (running)
            runProc.running = false;
    }
    function setAuto(on: bool): void {
        auto = on;
        cfgSet.command = [bin, "config", "auto", on ? "on" : "off"];
        cfgSet.running = true;
    }
    function markHave(d: string): void {
        const h = Object.assign({}, have);
        h[d] = ++counter;
        have = h;
    }

    Component.onCompleted: {
        refresh();
        cfgGet.running = true;
    }

    Process {
        id: listProc
        command: [root.bin, "list"]
        stdout: StdioCollector {
            onStreamFinished: {
                const h = {};
                for (const d of text.split("\n"))
                    if (d.trim())
                        h[d.trim()] = root.have[d.trim()] || ++root.counter;
                root.have = h;
            }
        }
    }
    Process {
        id: cfgGet
        command: [root.bin, "config"]
        stdout: StdioCollector {
            onStreamFinished: {
                try {
                    root.auto = !!JSON.parse(text).auto;
                } catch (e) {}
            }
        }
    }
    Process { id: cfgSet }

    Process {
        id: runProc
        stdout: SplitParser {
            onRead: line => {
                const p = line.trim().split(" ");
                if (p[0] === "done") {
                    root.msg = root.fetched + " new";
                    return;
                }
                root.done++;
                if (p[1] === "ok") {
                    root.fetched++;
                    root.markHave(p[0]);
                } else if (p[1] === "error") {
                    root.failed++;
                }
            }
        }
        onExited: {
            root.running = false;
            root.lastAuto = Date.now();
            root.refresh();
        }
    }
}
