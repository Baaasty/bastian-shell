import QtQuick
import Quickshell
import Quickshell.Io
import Quickshell.Hyprland
import Quickshell.Wayland
import qs.config
import qs.services
import qs.components

// Ausschneiden (Druck / Super+Shift+S): Bildschirm einfrieren, Bereich ziehen, kopieren + speichern.
// Einfrieren macht grim (wlr-screencopy unter Hyprland): ein Bild aller Monitore, Auswahl und Zuschnitt darauf.
// Aufnahme (Meta+R): erst die Quellwahl im Teilen-Stil (SharePicker, Modus „record“, nichts gemerkt), Region = diese Auswahl,
// danach nimmt Recording.qml den Bereich als Video auf.
// Extras (docs/knowledge/shell-features.md): T = Text aus Bild (OCR, scripts/snip-ocr) · C = Farbpipette (scripts/snip-color,
// eigenes Kürzel gibt es nicht mehr – eine Pipette, im Snip) · P = Ausschnitt anpinnen (SnipPin.qml).
Scope {
    id: root

    property bool active: false
    property bool busy: false
    readonly property string dir: Quickshell.env("XDG_RUNTIME_DIR") + "/desktop-snip"
    readonly property string full: dir + "/full.png"
    // Auswahl in globalen Koordinaten (ganze Pixel)
    property real sx: 0
    property real sy: 0
    property real ex: 0
    property real ey: 0
    // idle = noch nichts gewählt · drag = Ziehen · key = Startpunkt per Tastatur gesetzt, Zielpunkt zieht das Ende
    // adjust = Auswahl steht, feinjustieren, Enter kopiert
    property string mode: "idle"
    // Zielpunkt (Lupe/Fadenkreuz) in globalen Bildkoordinaten, ganze Pixel: Maus und Pfeiltasten teilen ihn,
    // damit man abwechseln kann (Maus bewegt → Pfeile machen dort weiter und umgekehrt)
    property int ax: 0
    property int ay: 0
    property bool aimSet: false
    property bool kbAim: false     // zuletzt per Pfeil bewegt: eigenes Fadenkreuz statt Zeiger
    property var warps: []         // per movecursor angefordert, noch nicht als Bewegung zurückgekommen ([x, y] global)
    property int kx: 0             // Startpixel der Tastatur-Auswahl
    property int ky: 0
    // zuletzt gezogene Ecke (l/r, t/b): Pfeile im Feinjustier-Modus bewegen genau sie weiter
    property string cornerX: "r"
    property string cornerY: "b"
    property var pressedArea: null    // Maus-Fläche mit gedrückter Taste: Pfeile schieben dann den Zeiger
    property bool dragging: false
    property int shot: 0   // erzwingt neues Laden des Bildes
    property var pendingCrop: null
    property bool recordMode: false   // Auswahl für Videoaufnahme statt Bild
    // was Enter mit der Auswahl macht: copy = kopieren + speichern · text = OCR · pin = anpinnen
    property string intent: "copy"
    property bool pickMode: false     // Farbpipette: ein Klick = ein Pixel
    property var pendingPick: null    // ohne Maus: [x, y] global
    property var pins: []             // angepinnte Bilder: {id, path, w, h, x, y, zoom, screen}
    property int pinSeq: 0
    property var pinJob: null
    // Bildpixel je logischem Pixel (grim nimmt die größte Monitor-Skalierung; bei Skalierung 1 überall = 1)
    property real px: 1

    readonly property real selX: Math.min(sx, ex)
    readonly property real selY: Math.min(sy, ey)
    readonly property real selW: Math.abs(ex - sx)
    readonly property real selH: Math.abs(ey - sy)
    readonly property bool hasSel: mode !== "idle" && selW > 0 && selH > 0

    function start(record: bool, what: string, pick: bool): void {
        if (busy || active)
            return;
        busy = true;
        mode = "idle";
        aimSet = false;
        kbAim = false;
        warps = [];
        cornerX = "r";
        cornerY = "b";
        recordMode = record;
        intent = what;
        pickMode = pick;
        capture.running = true;
        captureTimeout.restart();
    }
    function cancel(): void {
        active = false;
        dragging = false;
        mode = "idle";
        pickMode = false;
        intent = "copy";
    }
    // Esc: aus der Pipette zurück zur Auswahl, Tastatur-Startpunkt verwerfen, sonst abbrechen
    function goBack(): void {
        if (pickMode)
            pickMode = false;
        else if (mode === "key")
            mode = "idle";
        else
            cancel();
    }
    // Zielpunkt setzen (Maus oder Pfeile); bei Tastatur-Auswahl zieht er das Ende mit.
    // Start- und Endpixel gehören beide zur Auswahl (+1), so wie die Lupe sie markiert.
    function setAim(x: int, y: int): void {
        ax = x;
        ay = y;
        aimSet = true;
        if (mode === "key") {
            sx = Math.min(kx, x);
            ex = Math.max(kx, x) + 1;
            sy = Math.min(ky, y);
            ey = Math.max(ky, y) + 1;
        }
    }
    // Pfeile im Ziel-Modus: über Monitorgrenzen nur, wo wirklich ein Monitor ist, sonst am Rand stehen bleiben.
    // Der echte Zeiger springt mit (movecursor), damit die Maus von dort weitermacht.
    function moveAim(dx: int, dy: int): void {
        let nx = ax + dx, ny = ay + dy;
        if (!aimSet) {
            // Zeiger noch nicht gesehen: Mitte des fokussierten Monitors
            const m = Quickshell.screens.find(s => s.name === Hyprland.focusedMonitor?.name) ?? Quickshell.screens[0];
            nx = Math.floor(m.x + m.width / 2 - originX);
            ny = Math.floor(m.y + m.height / 2 - originY);
        } else if (!screenAt(nx + originX, ny + originY)) {
            const s = screenAt(ax + originX, ay + originY);
            nx = s ? Math.max(s.x - originX, Math.min(s.x + s.width - 1 - originX, nx)) : ax;
            ny = s ? Math.max(s.y - originY, Math.min(s.y + s.height - 1 - originY, ny)) : ay;
        }
        kbAim = true;
        setAim(nx, ny);
        warps = warps.concat([[nx, ny]]).slice(-20);
        Hypr.dispatch("movecursor " + Math.round(nx + originX) + " " + Math.round(ny + originY));
    }
    // Bewegung, die nur unser movecursor ausgelöst hat? Dann verbrauchen statt den Zielpunkt zu versetzen.
    function takeWarp(gx: int, gy: int): bool {
        const i = warps.findIndex(w => w[0] === gx && w[1] === gy);
        warps = i < 0 ? [] : warps.slice(i + 1);
        return i >= 0;
    }
    // Enter/Leertaste: 1. = Startpunkt, 2. = Endpunkt (Auswahl steht, danach greifen die Aktionstasten)
    function keyStart(): void {
        if (!aimSet) {
            moveAim(0, 0);
            return;
        }
        kx = ax;
        ky = ay;
        mode = "key";
        setAim(ax, ay);
    }
    function keyEnd(): void {
        if (!hasSel)
            return;
        cornerX = ax < kx ? "l" : "r";
        cornerY = ay < ky ? "t" : "b";
        normalize();
        mode = "adjust";
        kbAim = false; // Zeiger wieder zeigen: jetzt wird an den Griffen gezogen
    }
    // T / P / Enter-Ziel: steht schon eine Auswahl, wird sofort ausgeführt
    function chooseAction(what: string): void {
        if (recordMode)
            return;
        pickMode = false;
        intent = what;
        if (mode === "adjust")
            confirm(false);
    }
    function startPick(): void {
        if (!recordMode)
            pickMode = true;
    }
    function screenAt(gx: real, gy: real): var {
        return Quickshell.screens.find(s => gx >= s.x && gx < s.x + s.width && gy >= s.y && gy < s.y + s.height) ?? null;
    }
    function confirm(saveAs: bool): void {
        if (hasSel)
            finish(selX, selY, selW, selH, saveAs);
    }
    function normalize(): void {
        const x = selX, y = selY, w = selW, h = selH;
        sx = x; sy = y; ex = x + w; ey = y + h;
    }
    // Pfeile bei stehender Auswahl: zuletzt gezogene Ecke weiterschieben (min. 1 px, kein Umklappen),
    // whole (Strg) = ganze Auswahl verschieben. Alt+Pfeile sind in Hyprland belegt (Arbeitsflächen).
    function nudge(dx: int, dy: int, whole: bool): void {
        if (mode !== "adjust")
            return;
        normalize();
        if (whole) {
            sx += dx; ex += dx; sy += dy; ey += dy;
            return;
        }
        if (cornerX === "l")
            sx = Math.min(ex - 1, sx + dx);
        else
            ex = Math.max(sx + 1, ex + dx);
        if (cornerY === "t")
            sy = Math.min(ey - 1, sy + dy);
        else
            ey = Math.max(sy + 1, ey + dy);
    }
    // saveAs = false: kopieren + Kopie in Bilder/Screenshots · true: "Speichern unter …" (auch kopiert)
    function finish(x: real, y: real, w: real, h: real, saveAs: bool): void {
        active = false;
        dragging = false;
        mode = "idle";
        pickMode = false;
        if (recordMode) {
            record(Math.round(x + originX), Math.round(y + originY), Math.round(w), Math.round(h));
            return;
        }
        const what = intent;
        intent = "copy";
        if (what === "text") {
            ocr(x, y, w, h);
            return;
        }
        if (what === "pin") {
            pin(x, y, w, h);
            return;
        }
        const stamp = Qt.formatDateTime(new Date(), "yyyyMMdd_HHmmss");
        const out = Quickshell.env("HOME") + "/Pictures/Screenshots/Snip_" + stamp + ".png";
        const crop = "magick \"$0\" -crop " + Math.round(w * px) + "x" + Math.round(h * px) + "+" + Math.round(x * px) + "+" + Math.round(y * px) + " +repage";
        const size = Math.round(w) + " × " + Math.round(h);
        if (saveAs) {
            // „Speichern unter …“: erst ausschneiden, dann der eigene Datei-Wähler (services/FilePicker.qml, früher kdialog)
            saveAsJob = { cut: dir + "/cut-" + stamp + ".png", out: out, size: size };
            cutProc.command = ["sh", "-c", "mkdir -p \"$(dirname \"$2\")\" && " + crop + " \"$1\"", full, saveAsJob.cut, out];
            cutProc.running = true;
            return;
        }
        save.command = ["sh", "-c", "mkdir -p \"$(dirname \"$1\")\" && " + crop + " \"$1\" && wl-copy -t image/png < \"$1\" && notify-send -a Snip -i \"$1\" 'Snip copied' \"" + size + " · in Pictures/Screenshots\"", full, out];
        save.running = true;
    }

    // ---- Text aus Bild (OCR): Ausschnitt -> temporäres PNG im RAM -> scripts/snip-ocr -> Zwischenablage, Bild sofort weg
    function ocr(x: real, y: real, w: real, h: real): void {
        const s = screenAt(x + w / 2 + originX, y + h / 2 + originY);
        ocrScreen = s ? s.name : "";
        const crop = "magick \"$0\" -crop " + Math.round(w * px) + "x" + Math.round(h * px) + "+" + Math.round(x * px) + "+" + Math.round(y * px) + " +repage";
        ocrProc.command = ["sh", "-c", crop + " \"$1\" && \"$2\" \"$1\"; rm -f \"$1\"", full, dir + "/ocr.png", Quickshell.shellDir + "/../scripts/snip-ocr"];
        ocrProc.running = true;
    }
    property string ocrScreen: ""
    Process {
        id: ocrProc
        stdout: StdioCollector {
            onStreamFinished: {
                const r = text.trim();
                const scr = root.ocrScreen;
                if (r.startsWith("OK ")) {
                    const n = parseInt(r.slice(3));
                    toast.show({ screen: scr, icon: "document_scanner", text: "Text copied · " + n + (n === 1 ? " char" : " chars") });
                } else if (r === "EMPTY")
                    toast.show({ screen: scr, icon: "document_scanner", text: "No text found" });
                else if (r === "NOTOOL")
                    toast.show({ screen: scr, icon: "download", text: "Install tesseract", sub: "install command copied · sudo dnf install tesseract …", ms: 7000 });
                else if (r === "NOLANG")
                    toast.show({ screen: scr, icon: "download", text: "Install tesseract language packs", sub: "install command copied · deu + eng", ms: 7000 });
                else
                    toast.show({ screen: scr, icon: "error", text: "Text recognition failed" });
            }
        }
    }

    // ---- Farbpipette: Pixel des eingefrorenen Bildes (Bildkoordinaten) -> #RRGGBB in die Zwischenablage
    function pickAt(gx: real, gy: real): void {
        active = false;
        dragging = false;
        mode = "idle";
        pickMode = false;
        intent = "copy";
        const s = screenAt(gx + originX, gy + originY);
        pickScreen = s ? s.name : "";
        pickProc.command = [Quickshell.shellDir + "/../scripts/snip-color", full, String(Math.floor((gx + 0.5) * px)), String(Math.floor((gy + 0.5) * px))];
        pickProc.running = true;
    }
    property string pickScreen: ""
    Process {
        id: pickProc
        stdout: StdioCollector {
            onStreamFinished: {
                const r = text.trim();
                if (/^#[0-9A-F]{6}$/.test(r))
                    toast.show({ screen: root.pickScreen, swatch: r, text: r, sub: "color copied" });
                else
                    toast.show({ screen: root.pickScreen, icon: "error", text: "Could not read color" });
            }
        }
    }

    // ---- Anpinnen: Ausschnitt als PNG in $XDG_RUNTIME_DIR, eigenes kleines Overlay-Fenster je Pin (max. 4)
    function pin(x: real, y: real, w: real, h: real): void {
        const gx = Math.round(x + originX), gy = Math.round(y + originY);
        const s = screenAt(gx + w / 2, gy + h / 2) ?? Quickshell.screens[0];
        const id = "p" + (++pinSeq);
        const out = dir + "/pin_" + id + ".png";
        const zoom = Math.min(1, 0.45 * s.width / w, 0.45 * s.height / h);
        const wz = Math.round(w * zoom) + 10, hz = Math.round(h * zoom) + 10;
        pinJob = {
            id: id, path: out, w: Math.round(w), h: Math.round(h), zoom: zoom, screen: s.name,
            x: Math.max(0, Math.min(s.width - wz, gx - s.x)),
            y: Math.max(0, Math.min(s.height - hz, gy - s.y))
        };
        const crop = "magick \"$0\" -crop " + Math.round(w * px) + "x" + Math.round(h * px) + "+" + Math.round(x * px) + "+" + Math.round(y * px) + " +repage";
        pinProc.command = ["sh", "-c", crop + " \"$1\"", full, out];
        pinProc.running = true;
    }
    function unpin(id: string): void {
        const p = pins.find(p => p.id === id);
        if (!p)
            return;
        pins = pins.filter(q => q.id !== id);
        Quickshell.execDetached(["rm", "-f", p.path]);
    }
    Process {
        id: pinProc
        onExited: code => {
            const job = root.pinJob;
            root.pinJob = null;
            if (!job)
                return;
            if (code !== 0) {
                toast.show({ screen: job.screen, icon: "error", text: "Pin failed" });
                return;
            }
            // mehr als 4: ältesten schließen
            while (root.pins.length >= 4)
                root.unpin(root.pins[0].id);
            root.pins = root.pins.concat([job]);
        }
    }
    SnipToast {
        id: toast
    }
    Variants {
        model: root.pins

        SnipPin {
            required property var modelData
            screen: Quickshell.screens.find(s => s.name === modelData.screen) ?? null
            path: modelData.path
            natW: modelData.w
            natH: modelData.h
            startX: modelData.x
            startY: modelData.y
            startZoom: modelData.zoom
            onUnpinRequested: root.unpin(modelData.id)
        }
    }

    // Bereich (global) aufnehmen; Skalierung vom Monitor, auf dem die Mitte liegt.
    // Die Aufnahme (gpu-screen-recorder/wf-recorder) kann nur einen Monitor: auf diesen zuschneiden.
    function record(x: int, y: int, w: int, h: int): void {
        const cx = x + w / 2, cy = y + h / 2;
        const s = Quickshell.screens.find(s => cx >= s.x && cx < s.x + s.width && cy >= s.y && cy < s.y + s.height);
        if (s) {
            const x0 = Math.max(x, s.x), y0 = Math.max(y, s.y);
            const x1 = Math.min(x + w, s.x + s.width), y1 = Math.min(y + h, s.y + s.height);
            x = x0;
            y = y0;
            w = x1 - x0;
            h = y1 - y0;
        }
        rec.start(x, y, w, h, s ? s.devicePixelRatio : 1);
    }

    Recording {
        id: rec
    }

    // ---- Quellwahl der Aufnahme (shell.qml reicht den SharePicker herein) ----
    property var picker: null
    property var recPick: null
    function recordPicked(p): void {
        recPick = p;
        recDelay.restart();
    }
    // erst starten, wenn die Wahl-Karte weg ist (sonst wäre sie im ersten Bild bzw. im eingefrorenen Bild der Region)
    Timer {
        id: recDelay
        interval: 250
        onTriggered: {
            const p = root.recPick;
            root.recPick = null;
            if (!p || rec.busy)
                return;
            if (p.kind === "region")
                root.start(true, "copy", false);
            else if (p.kind === "screen" && p.screen)
                root.record(p.screen.x, p.screen.y, p.screen.width, p.screen.height);
            else if (p.kind === "window") {
                // wf-recorder kann nur Bildschirmbereiche: das Fenster als seine Fläche aufnehmen (was darüber liegt, ist mit drin)
                const g = Hypr.geo(p.top);
                if (g.width > 0 && g.height > 0)
                    root.record(Math.round(g.x), Math.round(g.y), Math.round(g.width), Math.round(g.height));
                else
                    toast.show({ icon: "error", text: "Window not found" });
            }
        }
    }

    // grim schreibt das Gesamtbild, danach gibt od die Bildbreite aus dem PNG-Kopf aus (Bytes 16–19, für px).
    // Fertig = Breite gelesen (kommt nur, wenn grim geklappt hat); Fehler = Exit-Code ≠ 0.
    Process {
        id: capture
        // dazu die Zeigerposition: Pfeile starten dort, auch wenn sich die Maus noch nicht bewegt hat
        command: ["sh", "-c", "mkdir -p \"$0\" && grim \"$0/full.png\" && od -An -tu1 -j16 -N4 \"$0/full.png\" && { hyprctl cursorpos 2>/dev/null || true; }", root.dir]
        stdout: StdioCollector {
            onStreamFinished: {
                const lines = text.trim().split("\n");
                const b = lines[0].trim().split(/\s+/).map(Number);
                if (b.length !== 4 || !root.busy)
                    return;
                const imgW = ((b[0] * 256 + b[1]) * 256 + b[2]) * 256 + b[3];
                const logicalW = Math.max(...Quickshell.screens.map(s => s.x + s.width)) - root.originX;
                root.px = imgW > 0 && logicalW > 0 ? imgW / logicalW : 1;
                const c = /^(-?\d+),\s*(-?\d+)$/.exec((lines[1] ?? "").trim());
                if (c && root.screenAt(Number(c[1]), Number(c[2])))
                    root.setAim(Number(c[1]) - root.originX, Number(c[2]) - root.originY);
                root.captured();
            }
        }
        onExited: (code) => {
            if (code === 0)
                return;
            captureTimeout.stop();
            root.pendingCrop = null;
            root.pendingPick = null;
            root.busy = false;
        }
    }
    function captured(): void {
        captureTimeout.stop();
        busy = false;
        shot++;
        if (pendingCrop) {
            const c = pendingCrop;
            pendingCrop = null;
            finish(c[0] - originX, c[1] - originY, c[2], c[3], false);
        } else if (pendingPick) {
            const c = pendingPick;
            pendingPick = null;
            pickAt(c[0] - originX, c[1] - originY);
        } else
            active = true;
    }
    Process {
        id: save
    }
    // Speichern unter: Ausschnitt liegt in $XDG_RUNTIME_DIR/desktop-snip/cut-….png, Ziel kommt aus dem Datei-Wähler.
    // Abbrechen = nichts gespeichert, nichts kopiert (wie früher mit kdialog).
    property var saveAsJob: null      // {cut, out, size}
    Process {
        id: cutProc
        onExited: code => {
            const j = root.saveAsJob;
            root.saveAsJob = null;
            if (!j)
                return;
            if (code !== 0) {
                Quickshell.execDetached(["rm", "-f", j.cut]);
                return;
            }
            const i = j.out.lastIndexOf("/");
            FilePicker.saveFile(j.out.slice(0, i), j.out.slice(i + 1), ["png", "jpg", "webp"], dest => {
                if (!dest) {
                    Quickshell.execDetached(["rm", "-f", j.cut]);
                    return;
                }
                Quickshell.execDetached(["sh", "-c", "magick \"$0\" \"$1\" && wl-copy -t image/png < \"$0\" && notify-send -a Snip -i \"$1\" 'Snip saved' \"$2 · $1\" || notify-send -a Snip 'Snip not saved' \"$1\"; rm -f \"$0\"", j.cut, dest, j.size]);
            }, { title: "Save Snip" });
        }
    }
    // Alle Monitore: grim direkt in die Datei (kein Einfrieren, keine Auswahl)
    Process {
        id: saveAll
        command: ["sh", "-c", "out=\"$HOME/Pictures/Screenshots/Screen_$(date +%Y%m%d_%H%M%S).png\"; mkdir -p \"$(dirname \"$out\")\" && grim \"$out\" && wl-copy -t image/png < \"$out\" && notify-send -a Snip -i \"$out\" 'Screenshot saved' 'All monitors · in Pictures/Screenshots'"]
    }
    // hängt grim, nicht für immer "busy" bleiben (sonst gehen Druck/Super+S/Super+R nicht mehr)
    Timer {
        id: captureTimeout
        interval: 10000
        onTriggered: {
            root.pendingCrop = null;
            root.pendingPick = null;
            capture.running = false;
            root.busy = false;
        }
    }

    IpcHandler {
        target: "snip"

        // Druck / Super+S: nochmal drücken bricht ab (falls die Auswahl hängt oder keinen Tastaturfokus hat)
        function region(): void {
            if (root.active)
                root.cancel();
            else
                root.start(false, "copy", false);
        }
        // Super+Shift+T: Bereich wählen, Text daraus lesen (OCR) und kopieren
        function text(): void {
            if (root.active)
                root.cancel();
            else
                root.start(false, "text", false);
        }
        // Super+Shift+P: Bereich wählen und als Referenz-Bild anpinnen · closePins schließt alle
        function pin(): void {
            if (root.active)
                root.cancel();
            else
                root.start(false, "pin", false);
        }
        function closePins(): void {
            while (root.pins.length > 0)
                root.unpin(root.pins[0].id);
        }
        // ohne Maus (Tests): festen Bereich (globale Koordinaten) lesen / anpinnen, festen Pixel lesen
        function ocrArea(x: int, y: int, w: int, h: int): void {
            root.pendingCrop = [x, y, w, h];
            root.start(false, "text", false);
        }
        function pinArea(x: int, y: int, w: int, h: int): void {
            root.pendingCrop = [x, y, w, h];
            root.start(false, "pin", false);
        }
        function pickAt(x: int, y: int): void {
            root.pendingPick = [x, y];
            root.start(false, "copy", true);
        }
        // Strg+Druck: alle Monitore als ein Bild speichern (Bilder/Screenshots) + kopieren + Benachrichtigung
        function all(): void {
            if (root.active)
                root.cancel();
            else
                saveAll.running = true;
        }
        // Meta+R: Bereich wählen und als Video aufnehmen · läuft schon eine Aufnahme → stoppen
        // erst Quellwahl (Monitor / Fenster / Region); nochmal drücken schließt sie wieder
        function record(): void {
            if (rec.recording)
                rec.stop();
            else if (root.active)
                root.cancel();
            else if (root.picker && root.picker.open) {
                if (root.picker.recordMode)
                    root.picker.cancel();   // offene Teilen-Anfrage einer App nie anfassen
            } else if (!rec.busy && !root.busy && !(root.picker && root.picker.openRecord(root.recordPicked)))
                root.start(true, "copy", false);
        }
        function stopRecording(): void {
            rec.stop();
        }
        // ohne Maus: festen Bereich (globale Koordinaten) aufnehmen
        function recordArea(x: int, y: int, w: int, h: int): void {
            if (!rec.busy)
                root.record(x, y, w, h);
        }
        function cancel(): void {
            root.cancel();
        }
        // ohne Maus: festen Bereich (globale Koordinaten) ausschneiden
        function crop(x: int, y: int, w: int, h: int): void {
            root.pendingCrop = [x, y, w, h];
            root.start(false, "copy", false);
        }
    }

    // Ursprung des Gesamtbilds = linke obere Ecke aller Monitore
    readonly property real originX: Math.min(...Quickshell.screens.map(s => s.x))
    readonly property real originY: Math.min(...Quickshell.screens.map(s => s.y))

    Variants {
        model: Quickshell.screens

        PanelWindow {
            id: win

            required property var modelData

            screen: modelData
            visible: root.active
            anchors {
                top: true
                bottom: true
                left: true
                right: true
            }
            // keine mask: das Fenster ist nur sichtbar, solange die Auswahl aktiv ist, und nimmt dann alle Klicks.
            // (Eine an „active“ gebundene mask kam beim Aufgehen zu spät – Klicks gingen durch das eingefrorene Bild
            // auf die echten Fenster, man hat z. B. VS Code verschoben statt einen Bereich zu ziehen.)
            exclusionMode: ExclusionMode.Ignore
            color: Theme.bg // liegt hinter dem eingefrorenen Bild
            WlrLayershell.namespace: "dock" // "dock": ohne Öffnen-Animation (Hyprland: layerrule noanim)
            WlrLayershell.layer: WlrLayer.Overlay
            WlrLayershell.keyboardFocus: root.active ? WlrKeyboardFocus.Exclusive : WlrKeyboardFocus.None

            // beim Schließen Maus-Zustand zurücksetzen (Griff, Fein-Modus/Cursor), damit nichts hängen bleibt
            Connections {
                target: root
                function onActiveChanged(): void {
                    if (root.active)
                        return;
                    area.grab = "";
                    area.zone = "";
                    area.fine = false;
                    area.start = null;
                    area.confirmOnRelease = false;
                    root.pressedArea = null;
                }
            }

            readonly property real ox: modelData.x - root.originX
            readonly property real oy: modelData.y - root.originY

            // eingefrorenes Bild dieses Monitors
            Image {
                id: frozen
                anchors.fill: parent
                source: root.active ? "file://" + root.full + "#" + root.shot : ""
                sourceClipRect: Qt.rect(win.ox * root.px, win.oy * root.px, win.width * root.px, win.height * root.px)
                cache: false
                smooth: false
            }

            // Auswahl in lokalen Koordinaten
            readonly property real lx: root.selX - win.ox
            readonly property real ly: root.selY - win.oy
            // Zielpunkt (lokal, ganze Pixel) und ob er auf diesem Monitor liegt
            readonly property int mx: root.ax - ox
            readonly property int my: root.ay - oy
            readonly property bool aimHere: root.aimSet && mx >= 0 && my >= 0 && mx < width && my < height

            // abdunkeln außer Auswahl
            Item {
                anchors.fill: parent
                readonly property color shade: Qt.alpha(Theme.dim, 0.55)
                readonly property bool has: root.hasSel
                Rectangle { x: 0; y: 0; width: parent.width; height: parent.has ? Math.max(0, win.ly) : parent.height; color: parent.shade }
                Rectangle { visible: parent.has; x: 0; y: Math.max(0, win.ly); width: Math.max(0, win.lx); height: root.selH; color: parent.shade }
                Rectangle { visible: parent.has; x: win.lx + root.selW; y: Math.max(0, win.ly); width: Math.max(0, parent.width - win.lx - root.selW); height: root.selH; color: parent.shade }
                Rectangle { visible: parent.has; x: 0; y: win.ly + root.selH; width: parent.width; height: Math.max(0, parent.height - win.ly - root.selH); color: parent.shade }
            }

            // Rahmen liegt außen, damit der Inhalt pixelgenau sichtbar bleibt
            Rectangle {
                visible: root.hasSel
                x: win.lx - 1
                y: win.ly - 1
                width: root.selW + 2
                height: root.selH + 2
                color: "transparent"
                border.width: 1
                border.color: Theme.accent
            }

            // Griffe (Ecken + Kantenmitten) zum Feinjustieren
            Repeater {
                model: root.mode === "adjust" ? [[0, 0], [0.5, 0], [1, 0], [0, 0.5], [1, 0.5], [0, 1], [0.5, 1], [1, 1]] : []
                Rectangle {
                    required property var modelData
                    width: 8
                    height: 8
                    radius: 2
                    x: win.lx + modelData[0] * root.selW - 4
                    y: win.ly + modelData[1] * root.selH - 4
                    color: Theme.accent
                    border.width: 1
                    border.color: Theme.bg
                }
            }

            // Größe + Position
            Rectangle {
                visible: root.hasSel
                x: Math.min(win.lx, win.width - width - 8)
                y: win.ly + root.selH + 8 + height > win.height ? win.ly + root.selH - height - 8 : win.ly + root.selH + 8
                width: sizeTxt.implicitWidth + 16
                height: 26
                radius: Theme.radiusSm
                color: Theme.glassStrong
                MonoTxt {
                    id: sizeTxt
                    anchors.centerIn: parent
                    text: Math.round(root.selW) + " × " + Math.round(root.selH) + "   " + Math.round(win.lx) + ", " + Math.round(win.ly)
                    font.pixelSize: Theme.fontSm
                }
            }

            // Aktionen unter der Auswahl (rechtsbündig), für die Maus · vor der Auswahl: Werkzeuge mittig unter dem Hinweis
            Row {
                id: actions
                z: 5 // über der Maus-Fläche
                readonly property bool tools: root.mode === "idle" && !root.recordMode && !root.dragging
                visible: (root.mode === "adjust" || tools) && !root.pickMode
                spacing: 6
                x: tools ? Math.round((win.width - width) / 2) : Math.max(8, Math.min(win.lx + root.selW - width, win.width - width - 8))
                // schmale Auswahl: unter die Größenanzeige statt daneben
                readonly property real gapY: root.selW < width + 180 ? 42 : 8
                y: tools ? 88 : win.ly + root.selH + gapY + 30 > win.height ? win.ly + root.selH - gapY - 30 : win.ly + root.selH + gapY
                Repeater {
                    // [Icon, Name, Taste, Art] · Art: 0 Hauptaktion (Enter) · 1 Speichern · 2 Schließen · 3 Text · 4 Farbe · 5 Anpinnen
                    model: root.recordMode
                        ? [["radio_button_checked", "Record", "Enter", 0], ["close", "", "Esc", 2]]
                        : actions.tools
                            ? [["document_scanner", "Text", "T", 3], ["colorize", "Color", "C", 4], ["push_pin", "Pin", "P", 5]]
                            : [["content_copy", "Copy", "Enter", 0], ["save", "Save", "S", 1], ["document_scanner", "Text", "T", 3], ["colorize", "Color", "C", 4], ["push_pin", "Pin", "P", 5], ["close", "", "Esc", 2]]
                    Rectangle {
                        id: act
                        required property var modelData
                        width: actRow.implicitWidth + 2 * Theme.space3
                        height: Theme.buttonHeightSm
                        radius: Theme.radiusSm
                        // Hauptaktion bzw. gewähltes Werkzeug (Text/Anpinnen statt Kopieren): Akzentfläche wie ein
                        // eingeschalteter Knopf (Button „on“), sonst deckend wie die Leiste
                        readonly property bool chosen: act.modelData[3] === 0
                            || (actions.tools && (act.modelData[3] === 3 && root.intent === "text" || act.modelData[3] === 5 && root.intent === "pin"))
                        color: chosen ? Theme.accentFill : actArea.containsMouse ? Theme.surfaceRaised : Theme.glassStrong
                        border.width: chosen ? 0 : 1
                        border.color: actArea.containsMouse ? Theme.borderStrong : Theme.border
                        Row {
                            id: actRow
                            anchors.centerIn: parent
                            spacing: Theme.space2
                            Icon {
                                anchors.verticalCenter: parent.verticalCenter
                                name: act.modelData[0]
                                size: Theme.iconSize
                                color: act.chosen ? Theme.accentText : Theme.text
                            }
                            Txt {
                                anchors.verticalCenter: parent.verticalCenter
                                visible: text !== ""
                                text: act.modelData[1]
                                color: act.chosen ? Theme.accentText : Theme.text
                                font.pixelSize: Theme.fontSm
                            }
                            KeyCap {
                                anchors.verticalCenter: parent.verticalCenter
                                small: true
                                main: true
                                label: act.modelData[2]
                            }
                        }
                        MouseArea {
                            id: actArea
                            anchors.fill: parent
                            hoverEnabled: true
                            cursorShape: Qt.PointingHandCursor
                            onClicked: {
                                const k = act.modelData[3];
                                if (k === 2)
                                    root.cancel();
                                else if (k === 3 || k === 5) {
                                    // vor der Auswahl: nochmal klicken = zurück zu Kopieren
                                    const what = k === 3 ? "text" : "pin";
                                    if (actions.tools && root.intent === what)
                                        root.intent = "copy";
                                    else
                                        root.chooseAction(what);
                                } else if (k === 4)
                                    root.startPick();
                                else {
                                    if (k === 1 || k === 0)
                                        root.intent = "copy";
                                    root.confirm(k === 1);
                                }
                            }
                        }
                    }
                }
            }

            // Hinweis oben: kurzer Satz + Tastenzeile, dieselbe Hinweis-Karte wie in der Bar (KeyHintRow)
            Glass {
                id: hintCard
                // Arrows/Shift/Ctrl stehen als Kappen, Maus-Gesten als Text davor
                readonly property string arrows: "←↑↓→"
                readonly property string lead: root.mode === "key" && !root.pickMode ? ""
                    : root.recordMode ? (root.mode === "adjust" ? "Drag edges" : "Select area to record · click = whole screen")
                    : root.pickMode ? "Click to copy the color"
                    : root.mode === "adjust" ? ""
                    : (root.intent === "text" ? "Select the text to read" : root.intent === "pin" ? "Select the area to pin" : "Drag to select") + " · click = whole screen"
                readonly property var hints: root.mode === "key" && !root.pickMode
                    ? [[arrows, "move the end"], ["Shift", "10 px"], ["Enter", "done"], ["Esc", "back"]]
                    : root.recordMode
                    ? (root.mode === "adjust"
                        ? [["Enter", "record"], [arrows, "corner"], ["Ctrl+" + arrows, "move all"], ["Shift", "10 px"], ["Esc", "cancel"]]
                        : [[arrows, "aim"], ["Shift", "fine · 10 px"], ["Enter", "start"], ["Esc", "cancel"]])
                    : root.pickMode
                        ? [["Enter", "copy"], [arrows, "aim"], ["Shift", "fine · 10 px"], ["Esc", "back"]]
                        : root.mode === "adjust"
                            ? [["Enter", root.intent === "text" ? "read text" : root.intent === "pin" ? "pin" : "copy"], ["S", "save"], ["T", "text"], ["C", "color"], ["P", "pin"], [arrows, "corner"], ["Ctrl+" + arrows, "move"], ["Shift", "10 px"], ["Esc", "cancel"]]
                            : (root.intent === "copy" ? [["T", "text"], ["C", "color"], ["P", "pin"]] : [["C", "color"]])
                                .concat([[arrows, "aim"], ["Shift", "fine · 10 px"], ["Enter", "start"], ["Esc", "cancel"]])
                visible: !root.dragging
                strong: true
                anchors.horizontalCenter: parent.horizontalCenter
                y: root.hasSel && win.ly < 100 ? parent.height - 80 : 40
                width: hintLine.implicitWidth + 2 * Theme.padCard
                height: hintLine.implicitHeight + 2 * Theme.space2
                radius: Theme.radiusMd
                Row {
                    id: hintLine
                    anchors.centerIn: parent
                    spacing: Theme.space4
                    Txt {
                        anchors.verticalCenter: parent.verticalCenter
                        visible: hintCard.lead !== ""
                        text: hintCard.lead
                        color: Theme.text
                        font.pixelSize: Theme.fontSm
                    }
                    KeyHintRow {
                        anchors.verticalCenter: parent.verticalCenter
                        gap: Theme.space3
                        hints: hintCard.hints
                    }
                }
            }

            // Lupe: 17 × 17 Pixel um den Cursor, 8-fach, mit Raster
            Rectangle {
                id: loupe
                readonly property int cells: 17
                readonly property int zoom: 8
                // Pipette: immer am Zielpunkt, auch bevor sich die Maus bewegt
                visible: win.aimHere && (area.containsMouse || root.kbAim || root.pickMode) && (root.mode !== "adjust" || area.pressed || root.pickMode)
                width: cells * zoom + 2
                height: cells * zoom + 2 + (root.pickMode ? 44 : 24)
                radius: Theme.radiusSm
                color: Theme.glassStrong
                border.width: 1
                border.color: Theme.borderStrong
                x: win.mx + 28 + width > win.width ? win.mx - 28 - width : win.mx + 28
                y: win.my + 28 + height > win.height ? win.my - 28 - height : win.my + 28
                clip: true

                ShaderEffectSource {
                    id: zoomed
                    x: 1
                    y: 1
                    width: loupe.cells * loupe.zoom
                    height: width
                    sourceItem: frozen
                    sourceRect: Qt.rect(win.mx - 8, win.my - 8, loupe.cells, loupe.cells)
                    textureSize: Qt.size(loupe.cells, loupe.cells)
                    smooth: false
                    live: loupe.visible
                }
                // Raster
                Repeater {
                    model: loupe.cells + 1
                    Rectangle {
                        required property int index
                        x: 1 + index * loupe.zoom
                        y: 1
                        width: 1
                        height: zoomed.height
                        color: Qt.alpha(Theme.bg, 0.18)
                    }
                }
                Repeater {
                    model: loupe.cells + 1
                    Rectangle {
                        required property int index
                        x: 1
                        y: 1 + index * loupe.zoom
                        width: zoomed.width
                        height: 1
                        color: Qt.alpha(Theme.bg, 0.18)
                    }
                }
                // Pixel unter dem Cursor
                Rectangle {
                    x: 1 + 8 * loupe.zoom - 1
                    y: 1 + 8 * loupe.zoom - 1
                    width: loupe.zoom + 2
                    height: loupe.zoom + 2
                    color: "transparent"
                    border.width: 1
                    border.color: Theme.accent
                }
                // Pipette: Farbe des Pixels (Feld + Hex) über den Koordinaten
                Row {
                    visible: root.pickMode
                    anchors.horizontalCenter: parent.horizontalCenter
                    y: zoomed.y + zoomed.height + 6
                    spacing: 6
                    Item {
                        anchors.verticalCenter: parent.verticalCenter
                        width: 14
                        height: 14
                        // liest den einen Pixel aus dem eingefrorenen Bild (gleiche Stelle wie scripts/snip-color beim Kopieren);
                        // liegt unter dem Farbfeld, muss aber sichtbar sein, sonst malt Canvas nicht
                        Canvas {
                            id: probe
                            width: 1
                            height: 1
                            readonly property string src: root.pickMode && win.aimHere ? "file://" + root.full + "#" + root.shot : ""
                            readonly property int ix: Math.floor((root.ax + 0.5) * root.px)
                            readonly property int iy: Math.floor((root.ay + 0.5) * root.px)
                            property string loaded: ""
                            property string hex: ""
                            onSrcChanged: {
                                hex = "";
                                if (loaded !== "" && loaded !== src)
                                    unloadImage(loaded); // großes Bild nicht im Speicher halten
                                loaded = src;
                                if (src === "")
                                    return;
                                if (isImageLoaded(src))
                                    requestPaint();
                                else
                                    loadImage(src);
                            }
                            onImageLoaded: requestPaint()
                            onIxChanged: requestPaint()
                            onIyChanged: requestPaint()
                            onPaint: {
                                if (src === "" || !isImageLoaded(src))
                                    return;
                                const ctx = getContext("2d");
                                ctx.clearRect(0, 0, 1, 1);
                                ctx.drawImage(src, ix, iy, 1, 1, 0, 0, 1, 1);
                                const d = ctx.getImageData(0, 0, 1, 1).data;
                                hex = "#" + [d[0], d[1], d[2]].map(v => ("0" + v.toString(16)).slice(-2)).join("").toUpperCase();
                            }
                        }
                        Rectangle {
                            anchors.fill: parent
                            radius: 3
                            color: probe.hex !== "" ? probe.hex : Theme.surfaceSunken
                            border.width: 1
                            border.color: Theme.borderStrong
                        }
                    }
                    MonoTxt {
                        anchors.verticalCenter: parent.verticalCenter
                        text: probe.hex !== "" ? probe.hex : "…"
                        color: Theme.text
                        font.pixelSize: Theme.fontSm
                    }
                }
                MonoTxt {
                    anchors.horizontalCenter: parent.horizontalCenter
                    anchors.bottom: parent.bottom
                    anchors.bottomMargin: 5
                    text: win.mx + ", " + win.my
                    color: Theme.textMuted
                    font.pixelSize: Theme.fontXs
                }
            }

            // Fadenkreuz im Fein-Modus und beim Zielen mit Pfeilen (echter Cursor ist dann ausgeblendet)
            Item {
                visible: (area.fine && area.containsMouse) || (root.kbAim && win.aimHere)
                x: win.mx
                y: win.my
                Rectangle { x: -10; y: 0; width: 7; height: 1; color: Theme.accent }
                Rectangle { x: 4; y: 0; width: 7; height: 1; color: Theme.accent }
                Rectangle { x: 0; y: -10; width: 1; height: 7; color: Theme.accent }
                Rectangle { x: 0; y: 4; width: 1; height: 7; color: Theme.accent }
            }

            Item {
                anchors.fill: parent
                focus: root.active
                Keys.onEscapePressed: root.goBack()
                Keys.onPressed: event => {
                    const enter = event.key === Qt.Key_Return || event.key === Qt.Key_Enter;
                    const space = event.key === Qt.Key_Space;
                    if (root.pickMode) {
                        // Pipette: Enter/Leertaste nimmt den Pixel unter dem Zielpunkt
                        if ((enter || space) && root.aimSet) {
                            root.pickAt(root.ax, root.ay);
                            event.accepted = true;
                            return;
                        }
                    } else if (enter || space) {
                        // ohne Maus: 1. Enter = Start, 2. = Ende · danach Enter = kopieren bzw. Aufnahme starten
                        if (root.mode === "idle")
                            root.keyStart();
                        else if (root.mode === "key")
                            root.keyEnd();
                        else if (enter)
                            root.confirm(false);
                        event.accepted = true;
                        return;
                    }
                    // Strg+C = kopieren, Strg+S = speichern unter … (wie überall, nicht im Aufnahme-Modus)
                    if (!root.recordMode && (event.modifiers & Qt.ControlModifier) && (event.key === Qt.Key_C || event.key === Qt.Key_S)) {
                        root.intent = "copy";
                        root.confirm(event.key === Qt.Key_S);
                        event.accepted = true;
                        return;
                    }
                    // einzelne Tasten: T Text lesen · C Pipette · P anpinnen · S speichern unter … (nicht im Aufnahme-Modus)
                    if (!root.recordMode && !(event.modifiers & (Qt.ControlModifier | Qt.AltModifier | Qt.MetaModifier))) {
                        let used = true;
                        if (event.key === Qt.Key_T)
                            root.chooseAction("text");
                        else if (event.key === Qt.Key_P)
                            root.chooseAction("pin");
                        else if (event.key === Qt.Key_C)
                            root.startPick();
                        else if (event.key === Qt.Key_S) {
                            root.intent = "copy";
                            root.confirm(true);
                        } else
                            used = false;
                        if (used) {
                            event.accepted = true;
                            return;
                        }
                    }
                    const d = { [Qt.Key_Left]: [-1, 0], [Qt.Key_Right]: [1, 0], [Qt.Key_Up]: [0, -1], [Qt.Key_Down]: [0, 1] }[event.key];
                    if (!d)
                        return;
                    event.accepted = true;
                    // überall gleich: Shift = 10 px · Strg = ganze Auswahl verschieben (nur wenn sie steht)
                    const step = (event.modifiers & Qt.ShiftModifier) ? 10 : 1;
                    if (root.pressedArea)
                        root.pressedArea.nudgePointer(d[0] * step, d[1] * step); // Maustaste gedrückt: Zeiger pixelweise
                    else if (root.pickMode || root.mode === "idle" || root.mode === "key")
                        root.moveAim(d[0] * step, d[1] * step);
                    else
                        root.nudge(d[0] * step, d[1] * step, (event.modifiers & Qt.ControlModifier) !== 0);
                }
            }

            MouseArea {
                id: area
                anchors.fill: parent
                hoverEnabled: true
                // Griff-Zone im Feinjustier-Modus: l/r/t/b-Kombination, "move" oder ""
                property string zone: ""
                property string grab: ""
                property var start: null
                // Zielpunkt: folgt der Maus, mit Shift nur ¼ so schnell (Fein-Modus)
                property real vx: 0
                property real vy: 0
                property real lastX: 0
                property real lastY: 0
                property bool fine: false
                // Doppelklick bestätigt erst beim Loslassen: verschwindet das Fenster mit gedrückter Taste,
                // bleibt die Taste für Qt "gedrückt" und der nächste Klick (z. B. auf die Bar) geht verloren
                property bool confirmOnRelease: false

                function track(mouse) {
                    const f = (mouse.modifiers & Qt.ShiftModifier) !== 0;
                    if (f && fine) {
                        vx = Math.max(0, Math.min(win.width, vx + (mouse.x - lastX) * 0.25));
                        vy = Math.max(0, Math.min(win.height, vy + (mouse.y - lastY) * 0.25));
                    } else {
                        vx = mouse.x;
                        vy = mouse.y;
                    }
                    fine = f;
                    lastX = mouse.x;
                    lastY = mouse.y;
                    root.kbAim = false;
                    root.setAim(Math.floor(vx) + win.ox, Math.floor(vy) + win.oy);
                }
                // gedrückte Maus ziehen lassen (Ecke, Kante, ganze Auswahl oder neue Auswahl) – für Maus und Pfeile gleich
                function applyDrag() {
                    const gx = Math.round(vx) + win.ox, gy = Math.round(vy) + win.oy;
                    if (grab === "move") {
                        const dx = gx - start.gx, dy = gy - start.gy;
                        root.sx = start.sx + dx; root.ex = start.ex + dx;
                        root.sy = start.sy + dy; root.ey = start.ey + dy;
                    } else if (grab) {
                        if (grab.includes("l")) root.sx = gx;
                        if (grab.includes("r")) root.ex = gx;
                        if (grab.includes("t")) root.sy = gy;
                        if (grab.includes("b")) root.ey = gy;
                    } else if (!root.pickMode) {
                        root.ex = gx;
                        root.ey = gy;
                    }
                }
                // Pfeile bei gedrückter Maustaste: wie eine Mausbewegung um dx/dy, echter Zeiger springt mit
                function nudgePointer(dx, dy) {
                    vx = lastX = Math.max(0, Math.min(win.width - 1, Math.round(vx) + dx));
                    vy = lastY = Math.max(0, Math.min(win.height - 1, Math.round(vy) + dy));
                    fine = false;
                    root.setAim(vx + win.ox, vy + win.oy);
                    applyDrag();
                    root.warps = root.warps.concat([[vx + win.ox, vy + win.oy]]).slice(-20);
                    Hypr.dispatch("movecursor " + Math.round(vx + win.modelData.x) + " " + Math.round(vy + win.modelData.y));
                }
                // Zeiger beim Öffnen schon über diesem Monitor: Zielpunkt dort, bevor sich die Maus bewegt
                onContainsMouseChanged: {
                    if (containsMouse && !root.aimSet) {
                        vx = lastX = mouseX;
                        vy = lastY = mouseY;
                        root.setAim(Math.floor(mouseX) + win.ox, Math.floor(mouseY) + win.oy);
                    }
                }

                function zoneAt(gx, gy) {
                    if (root.mode !== "adjust")
                        return "";
                    const m = 8, x1 = root.selX, y1 = root.selY, x2 = x1 + root.selW, y2 = y1 + root.selH;
                    const inX = gx > x1 - m && gx < x2 + m, inY = gy > y1 - m && gy < y2 + m;
                    let z = "";
                    if (inY && Math.abs(gx - x1) <= m) z += "l";
                    else if (inY && Math.abs(gx - x2) <= m) z += "r";
                    if (inX && Math.abs(gy - y1) <= m) z += "t";
                    else if (inX && Math.abs(gy - y2) <= m) z += "b";
                    if (!z && gx > x1 && gx < x2 && gy > y1 && gy < y2) z = "move";
                    return z;
                }
                cursorShape: {
                    if (fine || root.kbAim)
                        return Qt.BlankCursor;
                    if (root.pickMode)
                        return Qt.CrossCursor;
                    const z = grab || zone;
                    if (z === "move") return Qt.SizeAllCursor;
                    if (z === "lt" || z === "rb") return Qt.SizeFDiagCursor;
                    if (z === "rt" || z === "lb") return Qt.SizeBDiagCursor;
                    if (z === "l" || z === "r") return Qt.SizeHorCursor;
                    if (z === "t" || z === "b") return Qt.SizeVerCursor;
                    return Qt.CrossCursor;
                }

                onPressed: mouse => {
                    track(mouse);
                    root.pressedArea = area;
                    if (root.pickMode)
                        return; // Pixel wird beim Loslassen gewählt
                    const gx = Math.round(vx) + win.ox, gy = Math.round(vy) + win.oy;
                    grab = zoneAt(gx, gy);
                    if (grab) {
                        root.normalize();
                        start = { gx: gx, gy: gy, sx: root.sx, sy: root.sy, ex: root.ex, ey: root.ey };
                        return;
                    }
                    start = { fresh: root.mode === "idle" };
                    root.sx = root.ex = gx;
                    root.sy = root.ey = gy;
                    root.mode = "drag";
                    root.dragging = true;
                }
                onPositionChanged: mouse => {
                    // Echo unseres movecursor (Pfeile): nur Maus-Stand nachziehen, Zielpunkt und Fadenkreuz bleiben
                    if (root.takeWarp(Math.floor(mouse.x) + win.ox, Math.floor(mouse.y) + win.oy)) {
                        vx = lastX = mouse.x;
                        vy = lastY = mouse.y;
                        fine = false;
                        return;
                    }
                    track(mouse);
                    const gx = Math.round(vx) + win.ox, gy = Math.round(vy) + win.oy;
                    if (!pressed) {
                        zone = zoneAt(gx, gy);
                        return;
                    }
                    applyDrag();
                }
                onReleased: {
                    root.pressedArea = null;
                    if (root.pickMode) {
                        root.pickAt(win.mx + win.ox, win.my + win.oy);
                        return;
                    }
                    root.dragging = false;
                    // gezogene Ecke merken, bevor normalize() Start und Ende sortiert (Pfeile schieben sie danach weiter)
                    if (grab !== "move") {
                        const l = grab.includes("l"), t = grab.includes("t");
                        if (!grab || l || grab.includes("r"))
                            root.cornerX = (l ? root.sx < root.ex : root.ex < root.sx) ? "l" : "r";
                        if (!grab || t || grab.includes("b"))
                            root.cornerY = (t ? root.sy < root.ey : root.ey < root.sy) ? "t" : "b";
                    }
                    if (confirmOnRelease) {
                        confirmOnRelease = false;
                        grab = "";
                        root.confirm(false);
                        return;
                    }
                    if (grab) {
                        grab = "";
                        root.normalize();
                        return;
                    }
                    if (root.selW < 4 || root.selH < 4) {
                        if (start && start.fresh)
                            root.finish(win.ox, win.oy, win.width, win.height, false); // Klick = ganzer Monitor
                        else
                            root.mode = "idle";
                        return;
                    }
                    root.normalize();
                    root.mode = "adjust";
                }
                // Doppelklick in die Auswahl = kopieren
                onDoubleClicked: mouse => {
                    if (zoneAt(Math.round(mouse.x) + win.ox, Math.round(mouse.y) + win.oy) === "move")
                        confirmOnRelease = true;
                }
            }
        }
    }
}
