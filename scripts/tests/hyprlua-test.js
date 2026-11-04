// Funktionsprüfung für shell/services/hyprlua.js:  node scripts/tests/hyprlua-test.js
// Mit --print: alle Beispiel-Befehle zeilenweise ausgeben (zum Prüfen gegen ein laufendes Hyprland: hyprctl repl).
const fs = require("fs"), path = require("path");
const src = fs.readFileSync(path.join(__dirname, "../../shell/services/hyprlua.js"), "utf8").replace(/^\.pragma library\s*$/m, "");
const L = new Function(src + "; return { lua, focusWindow, focusMonitor, workspace, moveSilent, resize, move, close, submap, cursor, toggleSpecial, sendShortcut, dpms, exit, config, dsp, evl };")();

const A = "address:0xabc";
const samples = {
    focusWindow: [L.focusWindow(A), 'hl.dsp.focus({ window = "address:0xabc" })'],
    focusMonitor: [L.focusMonitor("DP-2"), 'hl.dsp.focus({ monitor = "DP-2" })'],
    workspace: [L.workspace(103), 'hl.dsp.focus({ workspace = "103" })'],
    moveSilent: [L.moveSilent("special:parked1", A), 'hl.dsp.window.move({ workspace = "special:parked1", follow = false, window = "address:0xabc" })'],
    resize: [L.resize(960.4, 600, A), 'hl.dsp.window.resize({ x = 960, y = 600, window = "address:0xabc" })'],
    move: [L.move(10, 20.6, A), 'hl.dsp.window.move({ x = 10, y = 21, window = "address:0xabc" })'],
    close: [L.close(A), 'hl.dsp.window.close({ window = "address:0xabc" })'],
    closeActive: [L.close(), "hl.dsp.window.close()"],
    submap: [L.submap("modal"), 'hl.dsp.submap("modal")'],
    cursor: [L.cursor(960, 900), "hl.dsp.cursor.move({ x = 960, y = 900 })"],
    toggleSpecial: [L.toggleSpecial("parked1"), 'hl.dsp.workspace.toggle_special("parked1")'],
    sendShortcut: [L.sendShortcut("CTRL", "T", A), 'hl.dsp.send_shortcut({ mods = "CTRL", key = "T", window = "address:0xabc" })'],
    dpms: [L.dpms("off"), 'hl.dsp.dpms({ action = "off" })'],
    exit: [L.exit(), "hl.dsp.exit()"],
    config: [L.config({ cursor: { no_warps: false } }), "hl.config({ cursor = { no_warps = false } })"],
};

if (process.argv.includes("--print")) {
    for (const k in samples)
        console.log(samples[k][0]);
    process.exit(0);
}

let fails = 0;
function eq(name, got, want) {
    const ok = JSON.stringify(got) === JSON.stringify(want);
    if (!ok) fails++;
    console.log((ok ? "ok   " : "FAIL ") + name + (ok ? "" : "  got " + JSON.stringify(got) + " want " + JSON.stringify(want)));
}
for (const k in samples)
    eq(k, samples[k][0], samples[k][1]);
eq("Anführungszeichen escaped", L.lua('a"b'), '"a\\"b"');
eq("undefined fällt weg", L.lua({ a: 1, b: undefined }), "{ a = 1 }");
eq("batch-Einträge", [L.dsp(L.exit()), L.evl(L.config({ misc: { x: true } }))], ["dispatch hl.dsp.exit()", "eval hl.config({ misc = { x = true } })"]);
eq("nie ein Semikolon", Object.values(samples).some(s => s[0].includes(";")), false);

if (fails) {
    console.log(fails + " Fehler");
    process.exit(1);
}
