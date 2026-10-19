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
exports._test = { checkMarks, startTerminal, matches, ownPaths, MARKS };
