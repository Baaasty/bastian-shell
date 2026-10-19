// Desktop: ein Fenster-Schema mit Super+Pfeilen (ersetzt KWins Quick Tile / Maximieren / Minimieren).
//   Super+↑            maximieren, nochmal = zurück
//   Super+↓            wiederherstellen: normale Größe, mittig auf dem Monitor (nie minimieren)
//   Super+← / →        an die Seite; nochmal auf derselben Seite: ½ → ⅓ → ⅔ → ½
//   Super+Shift+← / →  auf den Nachbarmonitor (proportional, maximiert/gekachelt bleibt es)
//   Super+Shift+↑      Vollbild an/aus
// KWins eigene Kürzel auf diesen Tasten räumt scripts/rice (FOREIGN) frei, bevor das Script lädt.

const GAP = 8;                        // Abstand wie in der Shell
const STEPS = [1 / 2, 1 / 3, 2 / 3];  // Breiten-Runde an der Seite
const DEFAULT_SIZE = [0.6, 0.7];      // Super+↓ auf ein schon normales Fenster
const REPEAT_MS = 800;                // schnelles Nachdrücken zählt, auch wenn die neue Geometrie noch fehlt
const DEBUG = false;

const tiles = {};    // Fenster-ID -> { side, step, output, rect, at } (von uns an die Seite gelegt)
const normals = {};  // Fenster-ID -> [Breite, Höhe] relativ zur Arbeitsfläche (letzte normale Größe)

function log() {
    if (DEBUG)
        console.warn("desktop-tiling:", Array.prototype.join.call(arguments, " "));
}

function idOf(w) { return String(w.internalId); }
function area(output) { return workspace.clientArea(KWin.MaximizeArea, output, workspace.currentDesktop); }
function active() {
    const w = workspace.activeWindow;
    return w && (w.normalWindow || w.dialog) && w.moveable ? w : null;
}

function rounded(r) {
    return { x: Math.round(r.x), y: Math.round(r.y), width: Math.round(r.width), height: Math.round(r.height) };
}

function near(a, b) {
    // Terminals & Co. runden auf Zeichenraster -> Größe großzügig, Lage genau
    return Math.abs(a.x - b.x) <= 4 && Math.abs(a.y - b.y) <= 4
        && Math.abs(a.width - b.width) <= 40 && Math.abs(a.height - b.height) <= 40;
}

// Liegt das Fenster noch so, wie wir es an die Seite gelegt haben?
function ourTile(w) {
    const t = tiles[idOf(w)];
    if (!t || w.fullScreen)
        return null;
    if (Date.now() - t.at < REPEAT_MS)
        return t;
    return w.maximizeMode === 0 && near(w.frameGeometry, t.rect) ? t : null;
}

function isNormal(w) {
    return w.maximizeMode === 0 && !w.fullScreen && !w.tile && !ourTile(w);
}

function rememberNormal(w) {
    if (!isNormal(w))
        return;
    const a = area(w.output), g = w.frameGeometry;
    normals[idOf(w)] = [g.width / a.width, g.height / a.height];
}

// Vollbild, Maximierung und KWin-Kachel lösen
function release(w) {
    if (w.fullScreen)
        w.fullScreen = false;
    if (w.maximizeMode !== 0)
        w.setMaximize(false, false);
    if (w.tile) {
        try { w.tile = null; } catch (e) { log("tile lösen ging nicht:", e); }
    }
}

function sideRect(a, side, fraction) {
    const width = Math.round(a.width * fraction);
    const left = side === "left";
    return {
        x: left ? a.x + GAP : a.x + a.width - width + GAP / 2,
        y: a.y + GAP,
        width: width - GAP - GAP / 2,
        height: a.height - 2 * GAP,
    };
}

function centered(a, width, height) {
    width = Math.min(width, a.width - 2 * GAP);
    height = Math.min(height, a.height - 2 * GAP);
    return rounded({ x: a.x + (a.width - width) / 2, y: a.y + (a.height - height) / 2, width: width, height: height });
}

function toggleMaximize() {
    const w = active();
    if (!w || !w.maximizable)
        return;
    if (w.maximizeMode === 3) {
        w.setMaximize(false, false);
        return;
    }
    rememberNormal(w);
    if (w.fullScreen)
        w.fullScreen = false;
    w.setMaximize(true, true);
}

function restore() {
    const w = active();
    if (!w)
        return;
    const id = idOf(w), t = ourTile(w);
    const a = area(t ? t.output : w.output);
    const n = normals[id];
    const wasNormal = isNormal(w);
    delete tiles[id];

    if (wasNormal) {
        const g = w.frameGeometry;
        w.frameGeometry = w.resizeable
            ? centered(a, a.width * DEFAULT_SIZE[0], a.height * DEFAULT_SIZE[1])
            : centered(a, g.width, g.height);
        return;
    }
    if (n || t || w.tile) {
        const size = n || DEFAULT_SIZE;
        release(w);
        w.frameGeometry = centered(a, a.width * size[0], a.height * size[1]);
        return;
    }
    // maximiert/Vollbild ohne gemerkte Größe (z. B. per Doppelklick): KWin stellt die alte Größe her,
    // danach einmal mittig setzen. Die Signale kommen in wechselnder Reihenfolge -> warten, bis Zustand
    // und Größe beide normal sind (nur kurz, sonst würde ein späteres Verschieben einrasten).
    const started = Date.now();
    const signals = [w.frameGeometryChanged, w.maximizedChanged, w.fullScreenChanged];
    const once = function () {
        const g = w.frameGeometry, o = w.output.geometry;
        const late = Date.now() - started > 1500;
        if (!late && (w.maximizeMode !== 0 || w.fullScreen || (g.width >= o.width && g.height >= o.height)))
            return;
        for (const s of signals)
            s.disconnect(once);
        if (!late)
            w.frameGeometry = centered(area(w.output), g.width, g.height);
    };
    for (const s of signals)
        s.connect(once);
    release(w);
}

function tile(side) {
    const w = active();
    if (!w)
        return;
    const id = idOf(w), t = ourTile(w);
    const output = t ? t.output : w.output;
    rememberNormal(w);
    const step = t && t.side === side ? (t.step + 1) % STEPS.length : 0;
    const rect = rounded(sideRect(area(output), side, STEPS[step]));
    release(w);
    w.frameGeometry = rect;
    tiles[id] = { side: side, step: step, output: output, rect: rect, at: Date.now() };
    log("tile", side, step, output.name, JSON.stringify(rect));
}

function toScreen(dir) {
    const w = active();
    if (!w)
        return;
    const id = idOf(w), t = ourTile(w);
    const from = t ? t.output : w.output;
    const screens = workspace.screens.slice().sort(function (a, b) { return a.geometry.x - b.geometry.x; });
    let i = -1;
    for (let k = 0; k < screens.length; k++)
        if (screens[k].name === from.name)
            i = k;
    const to = screens[i + dir];
    if (i < 0 || !to)
        return;

    if (t) {
        const rect = rounded(sideRect(area(to), t.side, STEPS[t.step]));
        w.frameGeometry = rect;
        tiles[id] = { side: t.side, step: t.step, output: to, rect: rect, at: Date.now() };
        return;
    }
    if (!isNormal(w)) {
        // maximiert / Vollbild / KWin-Kachel: KWin legt es drüben genauso wieder hin
        workspace.sendClientToScreen(w, to);
        return;
    }
    const a = area(from), b = area(to), g = w.frameGeometry;
    const sx = b.width / a.width, sy = b.height / a.height;
    const width = Math.min(w.resizeable ? g.width * sx : g.width, b.width);
    const height = Math.min(w.resizeable ? g.height * sy : g.height, b.height);
    const x = Math.min(Math.max(b.x + (g.x - a.x) * sx, b.x), b.x + b.width - width);
    const y = Math.min(Math.max(b.y + (g.y - a.y) * sy, b.y), b.y + b.height - height);
    w.frameGeometry = rounded({ x: x, y: y, width: width, height: height });
}

function toggleFullscreen() {
    const w = active();
    if (w && w.fullScreenable)
        w.fullScreen = !w.fullScreen;
}

workspace.windowRemoved.connect(function (w) {
    delete tiles[idOf(w)];
    delete normals[idOf(w)];
});

registerShortcut("Desktop Window Maximize", "Desktop: Maximize / Restore Window", "Meta+Up", toggleMaximize);
registerShortcut("Desktop Window Restore", "Desktop: Restore Window to Center", "Meta+Down", restore);
registerShortcut("Desktop Window Left", "Desktop: Window to Left Side (1/2, 1/3, 2/3)", "Meta+Left", function () { tile("left"); });
registerShortcut("Desktop Window Right", "Desktop: Window to Right Side (1/2, 1/3, 2/3)", "Meta+Right", function () { tile("right"); });
registerShortcut("Desktop Window Screen Left", "Desktop: Window to Left Monitor", "Meta+Shift+Left", function () { toScreen(-1); });
registerShortcut("Desktop Window Screen Right", "Desktop: Window to Right Monitor", "Meta+Shift+Right", function () { toScreen(1); });
registerShortcut("Desktop Window Fullscreen", "Desktop: Toggle Fullscreen", "Meta+Shift+Up", toggleFullscreen);
