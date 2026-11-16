// ERZEUGT aus theme/palette.json – theme/gen/vscode.py. Farben: palette.json -> projectAccents, Zuordnung: theme/projects.json
"use strict";
const vscode = require("vscode");
const fs = require("fs");
const os = require("os");
const path = require("path");
const ROOT = (() => {
  try {
    const m = /^DESKTOP=(.+)$/m.exec(fs.readFileSync(path.join(os.homedir(), ".config/desktop/hyprland.env"), "utf8"));
    if (m) return m[1].trim();
  } catch (e) {}
  return path.join(os.homedir(), "Workspace/bastian-shell");
})();
const PROJECTS = path.join(ROOT, "theme/projects.json");
const PALETTE = path.join(ROOT, "theme/palette.json");
const abs = (p) => (p.startsWith("~/") ? path.join(os.homedir(), p.slice(2)) : p);

// Kandidaten: Arbeitsbereich-Datei (z. B. ~/Workspace/x.code-workspace), dann erster Ordner –
// so wird auch ein Wrapper (~/.config/desktop/workspaces/<name>.code-workspace, scripts/vscode-colors)
// über seinen Repo-Ordner erkannt.
function candidates() {
  const out = [];
  const ws = vscode.workspace.workspaceFile;
  if (ws && ws.scheme === "file") out.push(ws.fsPath);
  const f = vscode.workspace.workspaceFolders;
  if (f && f.length && f[0].uri.scheme === "file") out.push(f[0].uri.fsPath);
  return out;
}

function lookup(p) {
  try {
    const list = JSON.parse(fs.readFileSync(PROJECTS, "utf8")).projects || [];
    const accents = JSON.parse(fs.readFileSync(PALETTE, "utf8")).projectAccents || {};
    let hit = null;
    for (const e of list) {
      const a = abs(e.path);
      if ((p === a || p.startsWith(a + path.sep)) && (!hit || a.length > abs(hit.path).length)) hit = e;
    }
    // Farbname aus projectAccents oder eigene Farbe als #RRGGBB
    return hit ? { name: hit.name, color: hit.color, hex: /^#[0-9a-f]{6}$/i.test(hit.color) ? hit.color : accents[hit.color] } : null;
  } catch (e) {
    return null;
  }
}

function activate(ctx) {
  const item = vscode.window.createStatusBarItem("desktop.project", vscode.StatusBarAlignment.Left, 100000);
  item.name = "Desktop: Projekt";
  ctx.subscriptions.push(item);
  const update = () => {
    const ps = candidates();
    if (!ps.length) return item.hide();
    let e = null;
    for (const p of ps) if ((e = lookup(p))) break;
    item.text = "$(circle-large-filled) " + (e ? e.name : path.basename(ps[0]).replace(/\.code-workspace$/, ""));
    item.color = e && e.hex ? e.hex : undefined;
    item.tooltip = e ? "Projektfarbe: " + e.color + " (scripts/vscode-colors)" : "Noch keine Projektfarbe: scripts/vscode-colors apply";
    item.show();
  };
  update();
  ctx.subscriptions.push(vscode.workspace.onDidChangeWorkspaceFolders(update));
  for (const dir of [path.dirname(PROJECTS)]) {
    try {
      const w = fs.watch(dir, (_ev, f) => { if (!f || f === "projects.json" || f === "palette.json") update(); });
      ctx.subscriptions.push({ dispose: () => w.close() });
    } catch (e) { /* ohne Watch: beim nächsten Fenster */ }
  }
  openTerminals(ctx);
  keepSideBars(ctx);
}

// Feste Leisten: Wird das Fenster schmal (Kacheln, anderer Monitor), quetscht VS Code irgendwann Explorer und
// Claude-Leiste; wird es wieder breit, bekommt nur der Editor den Platz zurück. Eine API für die Breite gibt es
// nicht: Leiste fokussieren, mit „Decrease View Size“ auf die Mindestbreite, dann in Schritten hoch (beide Werte
// aus dem VS-Code-Bundle). Die Fenstergröße kommt von Hyprland – alle Fenster gehören zum VS-Code-Hauptprozess
// (= Eltern des Extension-Hosts), welches unseres ist, verrät nur der Titel.
const BAR_MIN = 170;
const BAR_STEP = 60;
const EDITOR_ROOM = 500; // schmaler darf der Editor neben beiden Leisten nicht werden, sonst gelten sie als gequetscht
const sleep = (ms) => new Promise((r) => setTimeout(r, ms));

function barConfig() {
  const c = vscode.workspace.getConfiguration("desktop.sideBars");
  return { keep: c.get("keep", true), primary: c.get("primaryWidth", 380), secondary: c.get("secondaryWidth", 530) };
}

let resizing = false;

async function setBar(focus, width) {
  await vscode.commands.executeCommand(focus);
  await sleep(80); // Webviews (Claude) nehmen den Fokus verzögert, vorher träfe das Schrumpfen den Editor
  for (let i = 0; i < 20; i++) await vscode.commands.executeCommand("workbench.action.decreaseViewSize");
  const steps = Math.max(0, Math.round((width - BAR_MIN) / BAR_STEP));
  for (let i = 0; i < steps; i++) await vscode.commands.executeCommand("workbench.action.increaseViewSize");
}

async function resetSideBars() {
  if (resizing) return;
  resizing = true;
  try {
    const c = barConfig();
    await setBar("workbench.action.focusSideBar", c.primary);
    await setBar("workbench.action.focusAuxiliaryBar", c.secondary);
    await vscode.commands.executeCommand("workbench.action.focusActiveEditorGroup");
  } finally {
    resizing = false;
  }
}

// Breite des eigenen Fensters oder null (Hyprland fehlt, Titel passt auf kein oder mehrere Fenster)
function ownWidth() {
  const name = vscode.workspace.name;
  if (!name) return Promise.resolve(null);
  return new Promise((done) => {
    require("child_process").execFile("hyprctl", ["clients", "-j"], { timeout: 2000 }, (err, out) => {
      try {
        const mine = JSON.parse(out).filter((w) => w.pid === process.ppid && (w.title.startsWith(name + " - ") || w.title.includes(" - " + name + " - ")));
        done(!err && mine.length === 1 ? mine[0].size[0] : null);
      } catch (e) {
        done(null);
      }
    });
  });
}

function keepSideBars(ctx) {
  ctx.subscriptions.push(vscode.commands.registerCommand("desktop.resetSideBars", resetSideBars));
  let squeezed = true; // Fenster neu: Zustand der Leisten unbekannt, einmal setzen
  let timer = null;
  const check = async () => {
    const c = barConfig();
    if (!c.keep || resizing) return;
    const w = await ownWidth();
    if (!w) return;
    if (w < c.primary + c.secondary + EDITOR_ROOM) squeezed = true;
    else if (squeezed) {
      squeezed = false;
      await resetSideBars().catch((e) => console.error("desktop-projects: Leisten", e));
    }
  };
  const soon = () => { clearTimeout(timer); timer = setTimeout(check, 300); };
  const poll = setInterval(soon, 5000); // Rückfall: nicht jede Größenänderung (Teilungsverhältnis) meldet Hyprland
  ctx.subscriptions.push({ dispose: () => { clearTimeout(timer); clearInterval(poll); } });
  ctx.subscriptions.push(vscode.window.onDidChangeWindowState(soon));
  ctx.subscriptions.push(vscode.workspace.onDidChangeConfiguration((e) => {
    if (e.affectsConfiguration("desktop.sideBars")) { squeezed = true; soon(); }
  }));
  // Hyprland-Ereignisse (Fenster auf/zu, verschoben, Vollbild …) sofort; Titelwechsel beim Tippen ignorieren
  const sig = process.env.HYPRLAND_INSTANCE_SIGNATURE;
  const run = process.env.XDG_RUNTIME_DIR;
  if (sig && run) {
    let sock = null;
    let closed = false;
    const connect = () => {
      sock = require("net").createConnection(path.join(run, "hypr", sig, ".socket2.sock"));
      sock.on("data", (d) => { if (/^(?!windowtitle|activelayout)\w+>>/m.test(d.toString())) soon(); });
      sock.on("error", () => {});
      sock.on("close", () => { if (!closed) setTimeout(connect, 10000); });
    };
    connect();
    ctx.subscriptions.push({ dispose: () => { closed = true; sock && sock.destroy(); } });
  }
  soon();
}

// Dev-Terminal beim Projekt-Öffnen (shell/services/Templates.qml -> openProject): Einmal-Marke
// ~/.cache/desktop/open-terminal/<id>.json = { dir, target, command|null, name: "dev"|"shell", created }.
// Das Fenster, dessen Ordner (oder Arbeitsbereich-Datei) passt, öffnet unten im Panel ein Terminal in dir,
// schickt command und löscht die Marke. Marken älter als 2 min zählen nicht mehr (nach 10 min weg).
const MARKS = path.join(os.homedir(), ".cache/desktop/open-terminal");
const MAX_AGE = 2 * 60 * 1000;
const DROP_AGE = 10 * 60 * 1000;

function norm(p) {
  if (!p) return null;
  const a = path.resolve(abs(String(p)));
  try { return fs.realpathSync(a); } catch (e) { return a; }
}

// Eigene Pfade: alle Ordner + Arbeitsbereich-Datei (Wrapper ~/.config/desktop/workspaces/<name>.code-workspace
// hat das Repo als Ordner, *.code-workspace mit mehreren Repos hat dir als einen davon)
function ownPaths() {
  const out = new Set();
  const ws = vscode.workspace.workspaceFile;
  if (ws && ws.scheme === "file") out.add(norm(ws.fsPath));
  for (const f of vscode.workspace.workspaceFolders || []) if (f.uri.scheme === "file") out.add(norm(f.uri.fsPath));
  return out;
}

function matches(m, own) {
  return !!m && typeof m.dir === "string" && (own.has(norm(m.dir)) || (!!m.target && own.has(norm(m.target))));
}

function cwdOf(t) {
  const c = t.creationOptions && t.creationOptions.cwd;
  return c ? norm(typeof c === "string" ? c : c.fsPath) : null;
}

function startTerminal(m) {
  const name = m.name === "shell" ? "shell" : "dev";
  const dir = norm(m.dir);
  // Läuft das Terminal hier schon (Projekt erneut geöffnet): nur zeigen, nicht den Dev-Server doppelt starten
  const old = vscode.window.terminals.find((t) => t.name === name && t.exitStatus === undefined && (cwdOf(t) === null || cwdOf(t) === dir));
  if (old) return old.show(true);
  const opts = { name, cwd: dir };
  if (vscode.TerminalLocation) opts.location = vscode.TerminalLocation.Panel;
  if (vscode.ThemeIcon) opts.iconPath = new vscode.ThemeIcon(m.command ? "server-process" : "terminal");
  const t = vscode.window.createTerminal(opts);
  if (typeof m.command === "string" && m.command) t.sendText(m.command, true);
  t.show(true);
}

// Marke nehmen: erst lesen + prüfen, dann atomar umbenennen (nur ein Fenster gewinnt), dann löschen
function claim(file, own, now) {
  let st, m;
  try { st = fs.statSync(file); } catch (e) { return null; }
  try { m = JSON.parse(fs.readFileSync(file, "utf8")); } catch (e) { m = null; }
  const age = now - (m && typeof m.created === "number" ? m.created : st.mtimeMs);
  if (!m || age > DROP_AGE) {
    if (now - st.mtimeMs > DROP_AGE) try { fs.unlinkSync(file); } catch (e) { /* schon weg */ }
    return null;
  }
  if (!matches(m, own)) return null;
  const taken = file + ".taken-" + process.pid;
  try { fs.renameSync(file, taken); } catch (e) { return null; }
  try { fs.unlinkSync(taken); } catch (e) { /* egal */ }
  return age <= MAX_AGE && age >= -MAX_AGE ? m : null;
}

function checkMarks() {
  const own = ownPaths();
  if (!own.size) return;
  let names;
  try { names = fs.readdirSync(MARKS); } catch (e) { return; }
  const now = Date.now();
  for (const n of names) {
    if (n.startsWith(".") || !n.endsWith(".json")) continue;
    const m = claim(path.join(MARKS, n), own, now);
    if (m) {
      try { startTerminal(m); } catch (e) { console.error("desktop-projects: Terminal", e); }
    }
  }
}

function openTerminals(ctx) {
  let timer = null;
  const soon = () => { clearTimeout(timer); timer = setTimeout(checkMarks, 150); };
  ctx.subscriptions.push({ dispose: () => clearTimeout(timer) });
  try { fs.mkdirSync(MARKS, { recursive: true, mode: 0o700 }); } catch (e) { /* ohne Ordner: kein Watch */ }
  try {
    const w = fs.watch(MARKS, (_ev, f) => { if (!f || (f.endsWith(".json") && !f.startsWith("."))) soon(); });
    ctx.subscriptions.push({ dispose: () => w.close() });
  } catch (e) { /* ohne Watch: beim Fokus */ }
  ctx.subscriptions.push(vscode.window.onDidChangeWindowState((s) => { if (s.focused) soon(); }));
  ctx.subscriptions.push(vscode.workspace.onDidChangeWorkspaceFolders(soon));
  checkMarks();
}

exports.activate = activate;
exports.deactivate = () => {};
exports._test = { checkMarks, startTerminal, matches, ownPaths, MARKS, resetSideBars };
