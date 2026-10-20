pragma Singleton
import QtQuick
import Quickshell
import Quickshell.Io
import qs.config

// Bildschirm teilen aus der Shell heraus (Teilen-Menü am Privatsphäre-Punkt, Discord-Popout „Stream“).
// Gemerkte Auswahl je App liest scripts/share-pick aus ~/.local/state/desktop/share-picker.json (hier nur gelesen,
// Vergessen über `share-pick --forget`). Vor jedem Teilen aus der Shell sagt expect() dem Share-Picker an, welche App
// fragt – sonst zählt das aktive Fenster (beim Klick in der Bar oft VS Code) und die Merkung für Discord griff nicht.
Singleton {
    id: root

    readonly property string pick: Config.repo + "/scripts/share-pick"
    readonly property string memPath: (Quickshell.env("XDG_STATE_HOME") || Quickshell.env("HOME") + "/.local/state") + "/desktop/share-picker.json"
    property var memory: ({})          // app → { sel: "screen:DP-2" | "window" | "region:…", cls?, at }

    function remembered(app: string): var {
        return memory[String(app).toLowerCase()] ?? null;
    }
    // „DP-2“, „a Helium window“, „a region on DP-2“
    function describe(e: var): string {
        if (!e)
            return "";
        const sel = String(e.sel || "");
        if (sel === "window")
            return "a " + (e.cls || "app") + " window";
        if (sel.startsWith("screen:"))
            return sel.slice(7);
        if (sel.startsWith("region:"))
            return "a region on " + sel.slice(7).split("@")[0];
        return sel;
    }

    // Ansage an share-pick, danach then() – erst wenn die Datei steht, sonst gewinnt evtl. das Portal das Rennen
    function expect(app: string, then: var): void {
        const p = runner.createObject(root, { command: [pick, "--expect", app], then: then });
        p.running = true;
    }
    // Was eine App gerade teilt (letzte Antwort von share-pick an sie, $XDG_RUNTIME_DIR/desktop-share-pick/answers.json).
    // PipeWire nennt den Programmnamen („Discord“, „Chromium“), share-pick den Programm-Schlüssel – locker abgleichen.
    property var answers: ({})
    function whatFor(raw: string): string {
        const r = String(raw).toLowerCase();
        for (const k in answers)
            if (k === r || r.includes(k) || k.includes(r))
                return describe(answers[k]);
        return "";
    }
    // Freigabe beenden – für jede App gleich (scripts/share-stop: Screencast-Node von xdph in PipeWire beenden)
    function stop(node: int): void {
        if (node < 0)
            return;
        const p = runner.createObject(root, { command: [Config.repo + "/scripts/share-stop", "stop", String(node)], then: null });
        p.running = true;
    }
    function forget(app: string): void {
        const p = runner.createObject(root, { command: [pick, "--forget", String(app).toLowerCase()], then: null });
        p.running = true;
    }

    Component {
        id: runner
        Process {
            property var then: null       // immer danach (Ansage: ohne sie fragt share-pick eben das aktive Fenster)
            onExited: (code, status) => {
                if (typeof then === "function")
                    then();
                destroy();
            }
        }
    }

    // beim Öffnen des Menüs neu lesen (die Dateien entstehen erst beim ersten Teilen – davor gibt es nichts zu beobachten)
    function refresh(): void {
        answersFile.reload();
        mem.reload();
    }
    FileView {
        id: answersFile
        path: (Quickshell.env("XDG_RUNTIME_DIR") || "/tmp") + "/desktop-share-pick/answers.json"
        watchChanges: true
        printErrors: false
        onFileChanged: reload()
        onLoaded: {
            try {
                const a = JSON.parse(text());
                root.answers = a && typeof a === "object" ? a : {};
            } catch (e) {
                root.answers = {};
            }
        }
        onLoadFailed: root.answers = {}
    }
    FileView {
        id: mem
        path: root.memPath
        watchChanges: true
        printErrors: false
        onFileChanged: reload()
        onLoaded: {
            try {
                const m = JSON.parse(text());
                root.memory = m && typeof m === "object" ? m : {};
            } catch (e) {
                root.memory = {};
            }
        }
        onLoadFailed: root.memory = {}
    }
}
