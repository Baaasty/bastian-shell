import QtQuick
import Quickshell
import Quickshell.Io
import Quickshell.Wayland
import Quickshell.Hyprland
import qs.config
import qs.services

// Layout-Menü (Super+Alt+K): gespeicherte Fenster-Layouts anwenden, diesen Desktop speichern, löschen.
// Die Logik bleibt in scripts/layout (list --json · restore · save [--force] · rm); hier nur Liste + Aufrufe.
// Ohne laufende Shell fällt das Kürzel auf den kdialog-Dialog zurück (scripts/layout menu). Anleitung: docs/knowledge/shell-features.md
// qs ipc --any-display -p ~/Workspace/bastian-shell/shell call layouts toggle
Scope {
    id: root

    property bool open: false
    property string screenName: Config.mainScreen

    property var items: []              // [{name, windows, classes, monitors, saved, project, broken}]
    property var desk: null             // aktueller Desktop (Zahl) oder null
    property string suggest: ""         // Name des Desktops als Vorschlag beim Speichern
    property string loadState: ""       // "" | loading | ready | error:…
    property string query: ""
    // Auswahl: 0 … rows.length-1 = Layouts, rows.length = Zeile „Save this desktop as…“
    property int sel: 0
    readonly property var rows: filterRows(items, query)
    readonly property int saveIndex: rows.length
    readonly property var cur: sel >= 0 && sel < rows.length ? rows[sel] : null

    property bool naming: false         // Namensfeld offen
    property string saveError: ""
    property string overwrite: ""       // Name, der schon existiert -> Rückfrage
    property bool saving: false
    property string deleting: ""        // Name in der Lösch-Rückfrage
    property string status: ""          // kurze Rückmeldung unten
    property bool statusError: false
    property int keepSel: -1            // Auswahl nach dem Neuladen (Löschen: Zeile bleibt an ihrem Platz)

    readonly property string bin: Quickshell.shellDir + "/../scripts/layout"
    readonly property var nameRe: /^[A-Za-z0-9._-]{1,64}$/

    function filterRows(list: var, q: string): var {
        q = q.trim();
        if (!q)
            return list;
        const out = [];
        for (const e of list) {
            const s = Math.max(Fuzzy.score(q, e.name), Fuzzy.score(q, (e.classes || []).join(" ")) - 40);
            if (s > 0)
                out.push({ e: e, s: s });
        }
        out.sort((a, b) => b.s - a.s);
        return out.map(x => x.e);
    }
    onQueryChanged: {
        deleting = "";
        sel = 0;
    }

    function moveSel(d: int): void {
        deleting = "";
        sel = Math.max(0, Math.min(saveIndex, sel + d));
    }
    function selectName(name: string): void {
        const i = rows.findIndex(r => r.name === name);
        if (i >= 0)
            sel = i;
    }

    // ------------------------------------------------------------ öffnen / schließen
    function toggle(): void {
        if (open) close(); else openIt();
    }
    function openIt(): void {
        if (open)
            return;
        screenName = Hyprland.focusedMonitor?.name ?? Config.mainScreen;
        query = "";
        sel = 0;
        naming = false;
        saveError = "";
        overwrite = "";
        deleting = "";
        status = "";
        load("");
        Hypr.panelOpened("layouts");
        open = true;
    }

    // Anderes Panel geht auf → dieses zu (Hypr.panelOpened)
    Connections {
        target: Hypr
        function onPanelOpened(name: string): void {
            if (name !== "layouts" && root.open)
                root.close();
        }
    }
    function close(): void {
        open = false;
        naming = false;
        deleting = "";
        overwrite = "";
    }

    // ------------------------------------------------------------ Backend (scripts/layout)
    function run(args: var, cb: var): void {
        jobComp.createObject(root, { command: [bin].concat(args), cb: cb, running: true });
    }
    function load(keep: string): void {
        if (loadState !== "ready")
            loadState = "loading";
        run(["list", "--json"], (text, code, err) => {
            let d = null;
            try {
                d = code === 0 ? JSON.parse(text) : null;
            } catch (e) {
                d = null;
            }
            if (!d) {
                loadState = "error:" + (err || "no answer from scripts/layout");
                return;
            }
            items = d.layouts || [];
            desk = d.desk;
            suggest = d.suggest || "";
            loadState = "ready";
            if (keep)
                selectName(keep);
            else if (keepSel >= 0)
                sel = Math.min(keepSel, Math.max(0, rows.length - 1));
            else
                sel = items.length ? 0 : saveIndex;
            keepSel = -1;
        });
    }
    function say(msg: string, error: bool): void {
        status = msg;
        statusError = error;
        statusTimer.restart();
    }
    // Fehlertexte des Skripts (deutsch) für die Oberfläche kürzen
    function friendly(err: string): string {
        const e = (err || "").trim().split("\n").pop();
        if (/Positivliste/.test(e))
            return "Nothing to save here · only Kitty, Konsole, VS Code and Helium windows count";
        if (/nicht erkannt/.test(e))
            return "Could not detect the current desktop";
        return e || "Failed";
    }

    // Anwenden: Panel zu, Skript läuft losgelöst weiter (startet Fenster über uwsm), Ergebnis als Benachrichtigung
    function restore(e: var): void {
        if (!e)
            return;
        if (e.broken) {
            say("“" + e.name + "” is unreadable · fix config/layouts/" + e.name + ".toml", true);
            return;
        }
        close();
        Quickshell.execDetached(["sh", "-c", "err=$(\"$0\" restore \"$1\" 2>&1 >/dev/null); if [ $? = 0 ]; then notify-send -a Desktop -u low \"Layout “$1”\" restored; else notify-send -a Desktop \"Layout “$1”\" \"${err:-failed}\"; fi", bin, e.name]);
    }

    // Speichern: Namensfeld öffnen (Vorschlag = Name des Desktops)
    function startSave(): void {
        deleting = "";
        saveError = "";
        overwrite = "";
        sel = saveIndex;
        naming = true;
    }
    function cancelSave(): void {
        naming = false;
        saveError = "";
        overwrite = "";
    }
    function cleanName(text: string): string {
        return (text || "").trim().replace(/\s+/g, "-");
    }
    function submitSave(text: string): void {
        if (saving)
            return;
        const name = cleanName(text);
        if (!name) {
            saveError = "Enter a name";
            return;
        }
        if (!nameRe.test(name)) {
            saveError = "Only letters, digits and . _ - (up to 64)";
            return;
        }
        const exists = items.some(e => e.name === name);
        if (exists && overwrite !== name) {
            overwrite = name;
            saveError = "";
            return;
        }
        saving = true;
        saveError = "";
        const args = ["save", name].concat(exists ? ["--force"] : []);
        run(args, (out, code, err) => {
            saving = false;
            overwrite = "";
            if (code !== 0) {
                saveError = friendly(err);
                return;
            }
            naming = false;
            query = "";
            const m = /\((\d+) Fenster/.exec(out || "");
            say("Saved “" + name + "”" + (m ? " · " + m[1] + (m[1] === "1" ? " window" : " windows") : ""), false);
            load(name);
        });
    }

    // Löschen: erst Rückfrage in der Zeile (deleting), dann scripts/layout rm (Datei wandert in den Papierkorb)
    function askDelete(e: var): void {
        if (e)
            deleting = e.name;
    }
    function confirmDelete(): void {
        const name = deleting;
        if (!name)
            return;
        deleting = "";
        run(["rm", name], (out, code, err) => {
            if (code !== 0) {
                say(friendly(err), true);
                return;
            }
            say("Deleted “" + name + "” · copy in ~/.local/state/desktop/layouts-trash", false);
            keepSel = sel;
            load("");
        });
    }

    Timer {
        id: statusTimer
        interval: 4000
        onTriggered: root.status = ""
    }

    Component {
        id: jobComp

        Process {
            id: job

            property var cb
            property int left: 3            // stdout fertig + stderr fertig + beendet
            property int code: -1

            function step(): void {
                if (--left > 0)
                    return;
                job.cb(out.text, job.code, (errOut.text || "").trim());
                job.destroy();
            }

            stdout: StdioCollector {
                id: out
                onStreamFinished: job.step()
            }
            stderr: StdioCollector {
                id: errOut
                onStreamFinished: job.step()
            }
            onExited: c => {
                job.code = c;
                job.step();
            }
        }
    }

    IpcHandler {
        target: "layouts"

        function toggle(): void {
            root.toggle();
        }
        function open(): void {
            root.openIt();
        }
        function close(): void {
            root.close();
        }
        // ohne UI: was das Menü zeigen würde
        function list(): string {
            return JSON.stringify(root.items.map(e => e.name));
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
        WlrLayershell.keyboardFocus: root.open ? WlrKeyboardFocus.OnDemand : WlrKeyboardFocus.None

        // Klick daneben (auch auf anderen Monitoren) schließt
        HyprlandFocusGrab {
            active: root.open
            windows: [win]
            onCleared: root.close()
        }

        readonly property bool blurOn: root.open && progress > 0.4
        BackgroundEffect.blurRegion: Region {
            Region { x: 0; y: 0; width: 1; height: 1 }
            Region { item: win.blurOn ? backdrop : null }
            Region { item: menu; radius: Theme.radiusLg }
        }

        onVisibleChanged: if (visible && root.open) menu.focusInput()
        Connections {
            target: root
            function onOpenChanged() { if (root.open) menu.focusInput(); }
        }

        Rectangle {
            id: backdrop
            anchors.fill: parent
            opacity: win.progress
            color: Theme.dim
            MouseArea {
                anchors.fill: parent
                onClicked: root.close()
            }
        }

        LayoutMenu {
            id: menu

            lm: root
            x: (parent.width - width) / 2
            y: Math.round(parent.height * 0.42 - height / 2) + (1 - win.progress) * 14
            opacity: win.progress
            scale: 0.98 + 0.02 * win.progress
        }
    }
}
