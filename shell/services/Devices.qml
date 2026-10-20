pragma Singleton
import QtQuick
import Quickshell
import Quickshell.Io

// Gear (Gear-Popout in der Bar): PC-Licht über scripts/rgb, Maus G502 X PLUS über scripts/mouse (Solaar).
// Abfragen nur, solange jemand zusieht (watch()): rgb status alle 5 s (liest nur Dateien, kein Scan), mouse status alle 60 s.
// Ohne Zuschauer nur alle 10 min mouse status – für die Akku-Warnung am Chip.
// PC-Licht: Farbe/Ein sofort setzen (ein Lauf dauert ~25 s); Balken als Entwurf, gesendet 1,5 s nach der letzten Bewegung.
// Maus: alles Entwurf (draft…, dirty), erst saveMouse() schreibt ins Onboard-Profil (Flash) – darum nie bei jeder Bewegung.
Singleton {
    id: root

    readonly property string rgbBin: Quickshell.shellDir + "/../scripts/rgb"
    readonly property string mouseBin: Quickshell.shellDir + "/../scripts/mouse"

    property int watchers: 0
    readonly property bool active: watchers > 0
    function watch(on: bool): void {
        watchers = Math.max(0, watchers + (on ? 1 : -1));
    }
    onActiveChanged: {
        if (active) {
            rgbStatus.running = true;
            if (!mouseDirty)
                mouseDump();
        }
    }

    // ---------- PC-Licht ----------
    property bool rgbReady: false
    property bool rgbInstalled: true
    property bool rgbOn: true
    property string rgbToken: "accent"
    property var rgbTokens: []          // [{name, hex, led}] – led = so, wie die LEDs es zeigen
    property real rgbSat: 1
    property real rgbBri: 1
    property var rgbLast: ({ ok: 0, total: 0, at: 0, running: false })
    property string rgbError: ""
    // Balken-Entwurf (-1 = keiner): sofort sichtbar, gesendet nach der Pause
    property real draftSat: -1
    property real draftBri: -1
    readonly property real shownSat: draftSat >= 0 ? draftSat : rgbSat
    readonly property real shownBri: draftBri >= 0 ? draftBri : rgbBri
    readonly property bool rgbRunning: rgbProc.running || !!rgbLast.running
    readonly property string rgbLed: {
        const t = rgbTokens.find(x => x.name === rgbToken);
        return t ? t.led : "";
    }

    function setRgb(token: string): void {
        if (token === "off")
            rgbOn = false;
        else {
            rgbOn = true;
            rgbToken = token;
        }
        rgbRun(["set", token]);
    }
    function toggleRgb(): void {
        setRgb(rgbOn ? "off" : rgbToken);
    }
    function reapplyRgb(): void {
        rgbRun(["apply"]);
    }
    function tuneRgb(sat: real, bri: real): void {
        draftSat = Math.max(0, Math.min(1, sat));
        draftBri = Math.max(0, Math.min(1, bri));
        tuneTimer.restart();
    }
    Timer {
        id: tuneTimer
        interval: 1500
        onTriggered: root.rgbRun(["tune", root.draftSat.toFixed(2), root.draftBri.toFixed(2)])
    }
    // ein Lauf auf einmal; was währenddessen kommt, läuft danach (nur das Letzte)
    function rgbRun(args: var): void {
        if (rgbProc.running) {
            rgbProc.pending = args;
            return;
        }
        rgbProc.command = [rgbBin].concat(args);
        rgbProc.running = true;
        rgbStatus.running = true;
    }
    Process {
        id: rgbProc
        property var pending: null
        stdout: StdioCollector {}
        stderr: StdioCollector {
            onStreamFinished: if (text.trim() !== "") console.warn("rgb:", text.trim())
        }
        onExited: {
            if (pending) {
                const a = pending;
                pending = null;
                root.rgbRun(a);
                return;
            }
            rgbStatus.running = true;
        }
    }
    Process {
        id: rgbStatus
        command: [root.rgbBin, "status", "--json"]
        stdout: StdioCollector {
            onStreamFinished: {
                let j = null;
                try {
                    j = JSON.parse(text);
                } catch (e) {
                    root.rgbError = "rgb status unreadable";
                    return;
                }
                root.rgbError = j.error || "";
                root.rgbInstalled = !!j.installed;
                root.rgbTokens = j.tokens || [];
                root.rgbLast = j.last || ({});
                // eigene Wünsche nicht von einer älteren Antwort überschreiben lassen
                if (!rgbProc.running && !rgbProc.pending && !tuneTimer.running) {
                    root.rgbOn = j.on !== false;
                    root.rgbToken = j.color || "accent";
                    root.rgbSat = j.saturation ?? 1;
                    root.rgbBri = j.brightness ?? 1;
                    root.draftSat = -1;
                    root.draftBri = -1;
                }
                root.rgbReady = true;
            }
        }
    }
    Timer {
        interval: 5000
        repeat: true
        running: root.active
        onTriggered: if (!rgbStatus.running) rgbStatus.running = true
    }

    // ---------- Maus ----------
    // state: "" (noch nichts) | ok | asleep | absent | nosolaar | noprofile | error; busy = Empfänger gerade belegt (alte Werte bleiben)
    property string mouseState: ""
    property string mouseError: ""
    property int battery: -1
    property bool charging: false
    property int profile: 0
    property int dpi: 0
    property var resolutions: []
    property int defaultIndex: 0
    property string mouseColor: ""
    property bool mouseLoaded: false     // Profil mindestens einmal gelesen
    property bool saving: false
    property string saveNote: ""
    readonly property bool mouseOk: mouseState === "ok"
    readonly property bool lowBattery: battery >= 0 && battery < 15 && !charging

    // Entwurf
    property var draftRes: null
    property int draftDefault: -1
    property string draftColor: ""
    readonly property var shownRes: draftRes ?? resolutions
    readonly property int shownDefault: draftDefault >= 0 ? draftDefault : defaultIndex
    readonly property string shownColor: draftColor !== "" ? draftColor : mouseColor
    readonly property bool mouseDirty: draftRes !== null || draftDefault >= 0 || draftColor !== ""

    function setStageDpi(i: int, v: real): void {
        const r = shownRes.slice();
        if (i < 0 || i >= r.length)
            return;
        r[i] = Math.round(v / 50) * 50;
        draftRes = JSON.stringify(r) === JSON.stringify(resolutions) ? null : r;
    }
    function setDefaultStage(i: int): void {
        draftDefault = i === defaultIndex ? -1 : i;
    }
    function setMouseColor(hex: string): void {
        const h = String(hex).toUpperCase();
        draftColor = h === mouseColor.toUpperCase() ? "" : h;
    }
    function revertMouse(): void {
        draftRes = null;
        draftDefault = -1;
        draftColor = "";
        saveNote = "";
    }
    function saveMouse(): void {
        if (!mouseDirty || saving || !mouseOk)
            return;
        const req = {};
        if (draftRes !== null)
            req.resolutions = draftRes;
        if (draftDefault >= 0)
            req.defaultIndex = draftDefault;
        if (draftColor !== "")
            req.color = draftColor;
        saving = true;
        saveNote = "";
        mouseSave.command = [mouseBin, "save", JSON.stringify(req)];
        mouseSave.running = true;
    }
    function mouseDump(): void {
        if (!mouseDumpProc.running && !mouseSave.running)
            mouseDumpProc.running = true;
    }

    function applyMouse(j: var, full: bool): void {
        if (!j || j.state === "busy")
            return;
        mouseState = j.state || "error";
        mouseError = j.error || "";
        if (j.state !== "ok")
            return;          // schläft / weg: letzte Werte bleiben stehen (grau)
        battery = j.battery ?? -1;
        charging = !!j.charging;
        profile = j.profile || 0;
        dpi = j.dpi || 0;
        if (full) {
            resolutions = j.resolutions || [];
            defaultIndex = j.defaultIndex || 0;
            mouseColor = j.color || "";
            mouseLoaded = true;
        }
    }
    Process {
        id: mouseStatus
        command: [root.mouseBin, "status", "--json"]
        stdout: StdioCollector {
            onStreamFinished: {
                try {
                    root.applyMouse(JSON.parse(text), false);
                } catch (e) {}
            }
        }
    }
    Process {
        id: mouseDumpProc
        command: [root.mouseBin, "profile", "dump", "--json"]
        stdout: StdioCollector {
            onStreamFinished: {
                try {
                    const j = JSON.parse(text);
                    root.applyMouse(j, true);
                    // Empfänger gerade belegt (PC-Licht-Lauf): kurz danach nochmal
                    if (j.state === "busy")
                        dumpRetry.restart();
                } catch (e) {}
            }
        }
    }
    Timer {
        id: dumpRetry
        interval: 4000
        onTriggered: if (root.active) root.mouseDump()
    }
    Process {
        id: mouseSave
        stdout: StdioCollector {
            onStreamFinished: {
                root.saving = false;
                let j = null;
                try {
                    j = JSON.parse(text);
                } catch (e) {
                    root.saveNote = "Save failed";
                    return;
                }
                if (j.state === "ok") {
                    root.applyMouse(j, true);
                    root.revertMouse();
                    root.saveNote = j.written > 0 ? "Saved to mouse" : "Nothing changed";
                } else {
                    root.saveNote = j.state === "busy" ? "Receiver busy – try again" : j.state === "asleep" ? "Mouse asleep – move it, then save"
                        : "Save failed" + (j.error ? ": " + j.error : "");
                    if (j.state !== "busy")
                        root.applyMouse(j, false);
                }
            }
        }
        onExited: root.saving = false
    }
    Timer {
        interval: root.active ? 60000 : 600000
        repeat: true
        running: true
        triggeredOnStart: true
        onTriggered: {
            if (mouseStatus.running || mouseSave.running || mouseDumpProc.running)
                return;
            // Profil noch nie gelesen (Maus schlief beim Öffnen): ganz lesen
            if (root.active && !root.mouseLoaded)
                root.mouseDump();
            else
                mouseStatus.running = true;
        }
    }
}
