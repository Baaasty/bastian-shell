.pragma library

// Hyprland-Befehle als Lua (Lua-Konfiguration: hyprctl dispatch X = hl.dispatch(X), alte Strings wie
// "movetoworkspacesilent 3,address:…" laufen dort ins Leere, keyword gibt es nicht mehr).
// Eigene Datei, damit die Strings ohne Shell testbar sind: scripts/tests/hyprlua-test.js (node). Genutzt von Hypr.qml.
// Rückgabe = Argument für Hyprland.dispatch(); für hyprctl --batch mit dsp()/evl() einpacken.
// Nie ein ";" erzeugen: hyprctl --batch trennt die Befehle daran.

// JS-Wert → Lua-Literal (Strings mit ", Zahlen, Bool, verschachtelte Tabellen)
function lua(v) {
    if (typeof v === "number")
        return String(v);
    if (typeof v === "boolean")
        return v ? "true" : "false";
    if (v !== null && typeof v === "object")
        return "{ " + Object.keys(v).filter(k => v[k] !== undefined).map(k => k + " = " + lua(v[k])).join(", ") + " }";
    return JSON.stringify(String(v));
}

// Workspaces immer als String: "3", "special:parked1" (Hyprland liest Zahlen-Strings als ID)
function focusWindow(sel) { return "hl.dsp.focus(" + lua({ window: sel }) + ")"; }
function focusMonitor(name) { return "hl.dsp.focus(" + lua({ monitor: name }) + ")"; }
function workspace(ws) { return "hl.dsp.focus(" + lua({ workspace: String(ws) }) + ")"; }
// wie movetoworkspacesilent: Fokus bleibt
function moveSilent(ws, sel) { return "hl.dsp.window.move(" + lua({ workspace: String(ws), follow: false, window: sel }) + ")"; }
// wie resizewindowpixel/movewindowpixel exact
function resize(w, h, sel) { return "hl.dsp.window.resize(" + lua({ x: Math.round(w), y: Math.round(h), window: sel }) + ")"; }
function move(x, y, sel) { return "hl.dsp.window.move(" + lua({ x: Math.round(x), y: Math.round(y), window: sel }) + ")"; }
// ohne sel: aktives Fenster (killactive)
function close(sel) { return "hl.dsp.window.close(" + (sel ? lua({ window: sel }) : "") + ")"; }
function submap(name) { return "hl.dsp.submap(" + lua(name) + ")"; }
function cursor(x, y) { return "hl.dsp.cursor.move(" + lua({ x: Math.round(x), y: Math.round(y) }) + ")"; }
function toggleSpecial(name) { return "hl.dsp.workspace.toggle_special(" + lua(name) + ")"; }
function sendShortcut(mods, key, sel) { return "hl.dsp.send_shortcut(" + lua({ mods: mods, key: key, window: sel }) + ")"; }
function dpms(action) { return "hl.dsp.dpms(" + lua({ action: action }) + ")"; }
function exit() { return "hl.dsp.exit()"; }
// statt keyword: config({ cursor: { no_warps: true } })
function config(opts) { return "hl.config(" + lua(opts) + ")"; }

// Einträge für hyprctl --batch
function dsp(cmd) { return "dispatch " + cmd; }
function evl(cmd) { return "eval " + cmd; }
