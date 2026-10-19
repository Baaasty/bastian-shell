#!/usr/bin/env python3
"""Projektfarben für VS Code: jedes Projekt bekommt eine eigene, warme Akzentfarbe.

Farben: palette.json -> projectAccents · Zuordnung + gewünschte Tönung: projects/projects.json (zentrale
Projekt-Einstellungen, gelesen/geschrieben über projects/store.py; CLI für alles: scripts/project).
theme/projects.json ist nur noch eine daraus erzeugte flache Liste (Pfad -> Farbe) für ältere Leser.
Sichtbar wird sie zweifach:
  1. Punkt + Projektname links in der Statusleiste (Erweiterung desktop.desktop-projects, liest die
     erzeugte theme/projects.json live) – überall, ohne eine einzige Datei im Projekt.
  2. Getönte Titel-/Statusleiste + Akzentlinien (workbench.colorCustomizations, nur für das Theme
     „Desktop“) – nur wo das ohne Spuren im Repo geht:
       - <repo>/.vscode/settings.json, wenn sie NICHT eingecheckt ist; neu angelegte Dateien kommen in
         .git/info/exclude (lokal, wird nie committet) -> `git status` bleibt sauber.
       - *.code-workspace außerhalb von Git: Schlüssel unter "settings".
       - Repo mit EINGECHECKTER .vscode/settings.json (Team-Einstellungen, wird nie angefasst):
         zentraler Arbeitsbereich ~/.config/desktop/workspaces/<name>.code-workspace („Wrapper“) mit dem
         Repo als einzigem Ordner. Die Shell öffnet das Projekt darüber (Index: workspaces/index.json).
         Präzedenz (geprüft im VS-Code-Bundle): in einem Arbeitsbereich liest VS Code aus Ordner-Settings
         nur Datei-/Sprach-Scopes (resource, language-overridable, machine-overridable); window-Scope –
         workbench.colorCustomizations, typescript.tsdk, Erweiterungs-Settings ohne Scope – zählt nur noch
         aus der Arbeitsbereich-Datei. Darum wird die Repo-Datei komplett in den Wrapper gespiegelt
         (eigene colorCustomizations des Repos zusammengeführt) – so geht nichts verloren.
Aufruf: scripts/vscode-colors [status|apply|set|off|refresh|theme|farben] – siehe `hilfe`.
"""
import datetime
import json
import re
import os
import pathlib
import subprocess
import sys

sys.path.insert(0, str(pathlib.Path(__file__).resolve().parent))
import _jsonc as J  # noqa: E402
from _pal import HOME, ROOT, alpha, mix, rgba  # noqa: E402

sys.path.insert(0, str(ROOT / "projects"))
import store as S  # noqa: E402

PALETTE = ROOT / "theme/palette.json"
WORKSPACE = HOME / "Workspace"
USER_SETTINGS = HOME / ".config/Code/User/settings.json"
KEY = "workbench.colorCustomizations"
TAG = "scripts/vscode-colors"
MARK = f"desktop: Projektfarbe ({TAG}) – wird von dort überschrieben"
HEAD = f"// desktop: nur lokal (in .git/info/exclude), erzeugt von {TAG}. Weg damit: {TAG} off\n"
THEME_NAME = "Desktop"
EXCLUDE_LINES = [f"# desktop: Projektfarbe VS Code ({TAG})", "/.vscode/settings.json"]
WRAP_DIR = HOME / ".config/desktop/workspaces"
WRAP_INDEX = WRAP_DIR / "index.json"  # {abs. Repo-Pfad: {"file": Wrapper, "mirrored": [Schlüssel]}} – liest auch die Shell

pal = json.loads(PALETTE.read_text())
ACCENTS = pal["projectAccents"]
t = pal["themes"][pal["defaultTheme"]]
# wie theme/gen/vscode.py: deckende Varianten (hearth) tragen den Rahmen auf surfaceRaised, die alten auf bgBottom
FRAME = t.get("surfaceRaised", t["surface"]) if not t.get("blur", True) else t["bgBottom"]


# ── Projekte finden (wie shell/services/Projects.qml) ─────────────────────
def discover():
    sh = ("find \"$HOME/Workspace\" -maxdepth 2 -name '*.code-workspace' -not -path '*/node_modules/*' 2>/dev/null | sort; "
          "find \"$HOME/Workspace\" -maxdepth 4 -name .git -not -path '*/node_modules/*' -not -path '*/refs/*' "
          "-printf '%h\\n' 2>/dev/null | sort")
    out = subprocess.run(["sh", "-c", sh], capture_output=True, text=True).stdout
    return [pathlib.Path(p) for p in out.split("\n") if p.strip()]


def rel(p: pathlib.Path) -> str:
    return "~/" + str(p.relative_to(HOME))


def absp(r: str) -> pathlib.Path:
    return HOME / r[2:] if r.startswith("~/") else pathlib.Path(r)


def name_of(p: pathlib.Path) -> str:
    return p.name.removesuffix(".code-workspace")


def known_paths(data) -> set:
    return {str(S.absp(t)) for e in data["projects"].values() for t in S.targets(e)} | {str(S.absp(x)) for x in data["ignore"]}


def rarest(data) -> str:
    used = [e["color"] for e in data["projects"].values()]
    return min(ACCENTS, key=lambda c: (used.count(c) + (0.5 if c == "glut" else 0), list(ACCENTS).index(c)))


def assign(data, paths):
    """Neue Projekte (nicht in projects.json, nicht in ignore) bekommen die bisher seltenste Farbe."""
    known = known_paths(data)
    added = []
    for p in paths:
        if str(p) in known:
            continue
        color = "glut" if p == ROOT else rarest(data)  # das Rice selbst trägt seinen eigenen Akzent
        pid, e = S.new_entry(data, p, color)
        data["projects"][pid] = e
        known.add(str(p))
        added.append(pid)
    return added


# ── Farben ────────────────────────────────────────────────────────────────
ON = ("an", "wrapper")  # getönt
HEX = re.compile(r"^#[0-9a-fA-F]{6}$")


def resolve(color: str) -> str | None:
    """Farbname aus projectAccents oder eigene Farbe als #RRGGBB (z. B. Logo-Farbe eines Kunden)."""
    if isinstance(color, str) and HEX.match(color):
        return color.upper()
    return ACCENTS.get(color)


def tint(color_name: str) -> dict:
    c = resolve(color_name) or next(iter(ACCENTS.values()))
    return {f"[{THEME_NAME}]": {
        "titleBar.activeBackground": mix(FRAME, c, 0.30),
        "titleBar.activeForeground": t["text"],
        "titleBar.inactiveBackground": mix(FRAME, c, 0.14),
        "titleBar.inactiveForeground": t["textMuted"],
        "titleBar.border": alpha(c, 0.55),
        "statusBar.background": mix(FRAME, c, 0.16),
        "statusBar.foreground": t["textMuted"],
        "statusBar.border": alpha(c, 0.55),
        "activityBar.activeBorder": c,
        "tab.activeBorderTop": c,
        "panelTitle.activeBorder": c,
    }}


def swatch(color_name: str) -> str:
    r, g, b, _ = rgba(resolve(color_name) or "#808080")
    return f"\x1b[48;2;{r};{g};{b}m    \x1b[0m"


# ── Ziel-Datei pro Projekt ────────────────────────────────────────────────
def git(cwd, *args):
    return subprocess.run(["git", "-C", str(cwd), *args], capture_output=True, text=True)


def tracked(path: pathlib.Path) -> bool:
    r = git(path.parent if path.parent.exists() else path.parent.parent, "ls-files", "--error-unmatch", str(path))
    return r.returncode == 0


def target(p: pathlib.Path):
    """-> (datei, schlüsselpfad, art)  art: 'repo' | 'workspace'"""
    if p.suffix == ".code-workspace":
        return p, ["settings", KEY], "workspace"
    return p / ".vscode/settings.json", [KEY], "repo"


def state(p: pathlib.Path) -> str:
    f, path, kind = target(p)
    if kind == "repo" and str(p) in load_index():
        return "wrapper"
    if f.exists() and git(f.parent, "rev-parse").returncode == 0 and tracked(f):
        return "eingecheckt"
    if not f.exists():
        return "aus"
    try:
        text = f.read_text()
        if J.get(text, path) is None:
            return "aus"
        return "an" if TAG in J.comment_before(text, path) else "fremd"
    except (ValueError, KeyError):
        return "kaputt"


def write_atomic(f: pathlib.Path, text: str):
    tmp = f.with_name(f".{f.name}.desktop-tmp")
    tmp.write_text(text)
    if f.exists():
        os.chmod(tmp, f.stat().st_mode & 0o777)
    os.replace(tmp, f)


def exclude_file(repo: pathlib.Path) -> pathlib.Path:
    r = git(repo, "rev-parse", "--git-path", "info/exclude").stdout.strip()
    return (repo / r) if r and not os.path.isabs(r) else pathlib.Path(r)


def ensure_excluded(repo: pathlib.Path):
    if git(repo, "check-ignore", "-q", ".vscode/settings.json").returncode == 0:
        return
    ex = exclude_file(repo)
    ex.parent.mkdir(parents=True, exist_ok=True)
    old = ex.read_text() if ex.exists() else ""
    ex.write_text(old + ("" if not old or old.endswith("\n") else "\n") + "\n".join(EXCLUDE_LINES) + "\n")


def drop_excluded(repo: pathlib.Path):
    ex = exclude_file(repo)
    if not ex.exists():
        return
    lines = ex.read_text().split("\n")
    for i in range(len(lines) - 1):
        if lines[i] == EXCLUDE_LINES[0] and lines[i + 1] == EXCLUDE_LINES[1]:
            del lines[i:i + 2]
            ex.write_text("\n".join(lines))
            return


# ── Wrapper-Arbeitsbereich für Repos mit eingecheckter .vscode/settings.json ─
def load_index() -> dict:
    try:
        return json.loads(WRAP_INDEX.read_text())
    except (OSError, ValueError):
        return {}


def save_index(idx: dict):
    WRAP_DIR.mkdir(parents=True, exist_ok=True)
    write_atomic(WRAP_INDEX, json.dumps(dict(sorted(idx.items())), indent=2, ensure_ascii=False) + "\n")


def wrapper_file(p: pathlib.Path, idx: dict) -> pathlib.Path:
    """<name>.code-workspace (VS-Code-Titel „… - <name> (Workspace) - …“); bei Namensgleichheit -<Elternordner>."""
    if str(p) in idx:
        return pathlib.Path(idx[str(p)]["file"])
    taken = {e["file"] for e in idx.values()}
    for stem in (p.name, f"{p.name}-{p.parent.name}"):
        f = WRAP_DIR / f"{stem}.code-workspace"
        if str(f) not in taken and not f.exists():
            return f
    sys.exit(f"Kein freier Wrapper-Name für {p}")


def wrapper_header(p: pathlib.Path) -> str:
    return (f"// desktop: Arbeitsbereich für {rel(p)}, erzeugt von {TAG} – das Repo bleibt unberührt.\n"
            f"// Öffnen: Launcher/Workbar/Claude-Zentrale oder `code {{datei}}`. Neu spiegeln/tönen: {TAG} refresh · Weg: {TAG} off {p.name}\n"
            "// \"settings\": Spiegel der eingecheckten .vscode/settings.json (in einem Arbeitsbereich zählen aus der\n"
            "// Ordner-Datei nur Datei-/Sprach-Einstellungen) + Projektfarbe. Eigene Schlüssel hier bleiben erhalten.\n")


def apply_wrapper(p: pathlib.Path, color: str) -> str:
    idx = load_index()
    wf = wrapper_file(p, idx)
    repo_settings = {}
    src = p / ".vscode/settings.json"
    if src.exists():
        try:
            repo_settings = J.loads(src.read_text())
        except ValueError:
            return f"übersprungen: {src} nicht lesbar"
    old, prev = {}, set(idx.get(str(p), {}).get("mirrored", []))
    if wf.exists():
        try:
            old = J.loads(wf.read_text())
        except ValueError:
            return f"übersprungen: {wf} nicht lesbar"
    # eigene (nicht gespiegelte) Schlüssel behalten, Spiegel neu, Farbe zuletzt
    settings = {k: v for k, v in (old.get("settings") or {}).items() if k not in prev and k != KEY}
    settings.update(repo_settings)
    cc = dict(repo_settings.get(KEY) or {})
    ours = tint(color)[f"[{THEME_NAME}]"]
    cc[f"[{THEME_NAME}]"] = {**(cc.get(f"[{THEME_NAME}]") or {}), **ours}
    settings[KEY] = cc
    folders = old.get("folders") or []
    if not folders or pathlib.Path(folders[0].get("path", "")) != p:
        folders = [{"path": str(p)}]
    data = {k: v for k, v in old.items() if k not in ("folders", "settings")}
    data = {"folders": folders, "settings": settings, **data}
    text = wrapper_header(p).replace("{datei}", str(wf)) + json.dumps(data, indent=2, ensure_ascii=False) + "\n"
    entry = {"file": str(wf), "mirrored": sorted(k for k in repo_settings if k != KEY)}
    changed = not wf.exists() or wf.read_text() != text
    if changed:
        WRAP_DIR.mkdir(parents=True, exist_ok=True)
        write_atomic(wf, text)
    if idx.get(str(p)) != entry:
        idx[str(p)] = entry
        save_index(idx)
    return f"wrapper{' (neu geschrieben)' if changed else ''} → {'~/' + str(wf.relative_to(HOME))}"


def off_wrapper(p: pathlib.Path) -> str:
    idx = load_index()
    e = idx.pop(str(p), None)
    if not e:
        return "nichts zu tun"
    pathlib.Path(e["file"]).unlink(missing_ok=True)
    save_index(idx)
    return "aus (Wrapper entfernt)"


def apply_one(p: pathlib.Path, color: str) -> str:
    f, path, kind = target(p)
    st = state(p)
    if st == "wrapper" or (st == "eingecheckt" and kind == "repo"):
        return apply_wrapper(p, color)
    if st == "eingecheckt":
        return "eingecheckt → nur Statusleisten-Punkt"
    if st == "fremd":
        return f"übersprungen: {KEY} dort schon von Hand gesetzt"
    if st == "kaputt":
        return f"übersprungen: {f} nicht lesbar"
    value = tint(color)
    if kind == "workspace":
        if git(p.parent, "rev-parse").returncode == 0 and tracked(f):
            return "eingecheckt → nur Statusleisten-Punkt"
        text = f.read_text()
        if J.get(text, ["settings"]) is None:
            text = J.set_key(text, ["settings"], {})
        new = J.set_key(text, path, value, comment=MARK)
    else:
        if f.exists():
            new = J.set_key(f.read_text(), path, value, comment=MARK)
        else:
            f.parent.mkdir(exist_ok=True)
            new = HEAD + J.set_key("{}\n", path, value, comment=MARK)
        ensure_excluded(p)
    if not f.exists() or f.read_text() != new:
        write_atomic(f, new)
        return "an (neu geschrieben)"
    return "an"


def off_one(p: pathlib.Path) -> str:
    f, path, kind = target(p)
    if state(p) == "wrapper":
        return off_wrapper(p)
    if state(p) != "an":
        return "nichts zu tun"
    text = J.del_key(f.read_text(), path, marker=TAG)
    if kind == "repo" and text.startswith(HEAD) and J.loads(text) == {}:
        f.unlink()
        try:
            f.parent.rmdir()
        except OSError:
            pass
        drop_excluded(p)
        return "aus (Datei entfernt)"
    write_atomic(f, text)
    return "aus"


# ── Theme in den User-Settings ────────────────────────────────────────────
def user_settings_edit(fn):
    text = USER_SETTINGS.read_text()
    new = fn(text)
    if new == text:
        return False
    stamp = datetime.datetime.now().strftime("%Y%m%d-%H%M%S")
    backup = USER_SETTINGS.with_name(f"settings.json.vor-desktop-{stamp}")
    backup.write_text(text)
    write_atomic(USER_SETTINGS, new)
    print(f"  Sicherung: {backup}")
    return True


def theme(cmd):
    if cmd == "on":
        changed = user_settings_edit(lambda s: J.set_key(s, ["workbench.colorTheme"], THEME_NAME,
                                                          before="workbench.editorAssociations"))
        print(f"  workbench.colorTheme = {THEME_NAME}" + ("" if changed else " (war schon)"))
    elif cmd == "off":
        changed = user_settings_edit(lambda s: J.del_key(s, ["workbench.colorTheme"]))
        print("  workbench.colorTheme entfernt -> VS-Code-Standard" if changed else "  war nicht gesetzt")
    else:
        print(f"  workbench.colorTheme = {J.get(USER_SETTINGS.read_text(), ['workbench.colorTheme'], '(Standard)')}")


# ── Befehle (auch von scripts/project benutzt) ─────────────────────────────
def pick(data, names):
    if not names:
        return list(data["projects"])
    out = []
    for n in names:
        pid = S.find(data, n)
        if not pid:
            sys.exit(f"Unbekanntes Projekt: {n} (Liste: scripts/project list)")
        out.append(pid)
    return out


def states(e) -> list:
    return [state(S.absp(t)) for t in S.targets(e)]


def tint_on(e) -> list:
    """Alle Ziele (Arbeitsbereich + Repos) tönen -> Meldungen."""
    return [f"{S.rel(S.absp(t))}: {apply_one(S.absp(t), e['color'])}" for t in S.targets(e)]


def tint_off(e) -> list:
    return [f"{S.rel(S.absp(t))}: {off_one(S.absp(t))}" for t in S.targets(e)]


def set_tint(e, on: bool) -> list:
    if on and not e["color"]:
        sys.exit("Ohne Farbe gibt es keine Tönung – erst eine Farbe setzen.")
    msgs = tint_on(e) if on else tint_off(e)
    e["tint"] = on
    return msgs


def set_color(e, color) -> list:
    """color: Palettenname, #RRGGBB oder None (keine Farbe -> Tönung aus)."""
    if color is not None and not resolve(color):
        sys.exit(f"Farbe: #RRGGBB, Palettenname ({', '.join(ACCENTS)}) oder none")
    if color and HEX.match(color):
        color = color.upper()
    msgs = []
    if color is None and e["tint"]:
        msgs = set_tint(e, False)
    e["color"] = color
    if color and e["tint"]:
        msgs = tint_on(e)
    return msgs or ["Punkt aktualisiert"]


def status(data):
    theme("status")
    w = max([len(k) for k in data["projects"]] + [8])
    for pid, e in data["projects"].items():
        st = "+".join(dict.fromkeys(states(e)))
        print(f"  {swatch(e['color'] or '#808080')} {pid:<{w}}  {str(e['color']):<9} {st:<12} {' · '.join(S.targets(e))}")
    print("  Zustand: an = Titel/Statusleiste getönt · wrapper = getönt über ~/.config/desktop/workspaces/<name>.code-workspace\n"
          "           (Repo hat eingecheckte .vscode/settings.json, bleibt unberührt) · eingecheckt/aus = nur Punkt in der Statusleiste\n"
          "  Alle Projekt-Einstellungen: scripts/project list")


HELP = f"""{TAG} – Projektfarben + Theme für VS Code
  {TAG}                      Übersicht (Theme, Projekte, Farben, Zustand)
  {TAG} apply [projekt…]     neue Projekte erfassen, Farben vergeben, Titel/Statusleiste tönen
  {TAG} set <projekt> <farbe>  Farbe ändern (#RRGGBB, Name aus {TAG} farben, none)
  {TAG} off [projekt…]       Tönung entfernen (Zuordnung bleibt, Punkt bleibt; Wrapper wird gelöscht)
  {TAG} refresh              Tönung neu berechnen (nach rice variant) + Wrapper neu spiegeln, nur wo schon an
  {TAG} theme on|off|status  Theme „Desktop“ in den User-Settings an/aus
  {TAG} farben               alle Akzentfarben zeigen
  Gespeichert in projects/projects.json – alle Projekt-Einstellungen (Ports, Links, …): scripts/project"""


def main(argv):
    cmd, args = (argv[0], argv[1:]) if argv else ("status", [])
    if cmd in ("hilfe", "help", "-h", "--help"):
        print(HELP)
    elif cmd == "farben":
        for n, c in ACCENTS.items():
            print(f"  {swatch(n)} {n:<9} {c}")
    elif cmd == "theme":
        theme(args[0] if args else "status")
    elif cmd == "status":
        with S.edit() as data:
            added = assign(data, discover())
        if added:
            print("  neu: " + ", ".join(added))
        status(S.load())
    elif cmd == "apply":
        with S.edit() as data:
            added = assign(data, discover())
            if added:
                print("  neu: " + ", ".join(added))
            # ohne Namen: alle mit gewünschter Tönung + neu erfasste; mit Namen: genau diese (Tönung an)
            ids = pick(data, args) if args else [k for k, e in data["projects"].items() if e["tint"] or k in added]
            for pid in ids:
                e = data["projects"][pid]
                if not e["color"]:
                    print(f"  {pid:<28} keine Farbe → nichts zu tönen")
                    continue
                for msg in set_tint(e, True):
                    print(f"  {swatch(e['color'])} {pid:<28} {msg}")
    elif cmd == "set":
        if len(args) != 2:
            sys.exit(f"Aufruf: {TAG} set <projekt> <farbe|#RRGGBB|none>  (Farben: {', '.join(ACCENTS)} – oder jede eigene als #RRGGBB)")
        with S.edit() as data:
            assign(data, discover())
            for pid in pick(data, args[:1]):
                e = data["projects"][pid]
                for msg in set_color(e, None if args[1].lower() in ("none", "null", "keine") else args[1]):
                    print(f"  {swatch(e['color'] or '#808080')} {pid:<28} {msg}")
    elif cmd == "off":
        with S.edit() as data:
            for pid in pick(data, args):
                for msg in set_tint(data["projects"][pid], False):
                    print(f"  {pid:<28} {msg}")
    elif cmd == "refresh":
        data = S.load()
        for e in data["projects"].values():
            if e["tint"] and e["color"]:
                for t in S.targets(e):
                    if state(S.absp(t)) in ON:
                        apply_one(S.absp(t), e["color"])
        print(f"  Projektfarben neu getönt ({pal['defaultTheme']})")
    else:
        sys.exit(HELP)


if __name__ == "__main__":
    main(sys.argv[1:])
