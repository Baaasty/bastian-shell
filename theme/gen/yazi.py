#!/usr/bin/env python3
"""theme/palette.json -> yazi-Theme (theme/out/yazi/theme.toml), installiert nach ~/.config/yazi/theme.toml.

Ruhig und warm: Ordner Holz-hell fett, Dateien Creme, die markierte Zeile auf accentFill, Ember nur für
den aktiven Modus, das aktuelle Verzeichnis und Fokus. Rahmen in Holz, kein eigener Hintergrund (Terminalfläche
bleibt). Code-Vorschau nutzt das bat-Theme aus theme/gen/bat.py. Schema: yazi 26.x (Abschnitt [mgr],
Hover in [indicator]); es werden nur Farben überschrieben, Trenner/Symbole bleiben wie im Preset.
yazi.toml und keymap.toml fasst der Generator nicht an.
Aufruf aus dem Repo-Root: python3 -I theme/gen/yazi.py [variante] [--nur-out]
"""
import pathlib
import sys

sys.path.insert(0, str(pathlib.Path(__file__).resolve().parent))
from _pal import HOME, MARK, OUT, install, install_wanted, load, mix, tilde, write  # noqa: E402
import _term  # noqa: E402

src, variant, t = load()
c = _term.colors(src, t)
bg = c["bg"]

border = mix(bg, t["woodLight"], 0.55)      # Rahmenlinien: Holz, leise
faint = mix(bg, t["textFaint"], 0.75)       # Trenner, Nebensachen


def st(fg=None, bg=None, **flags) -> str:
    """Stil als TOML-Inline-Tabelle, z. B. { fg = "#…", bold = true }."""
    parts = []
    if fg:
        parts.append(f'fg = "{fg}"')
    if bg:
        parts.append(f'bg = "{bg}"')
    parts += [f"{k} = {'true' if v else 'false'}" for k, v in flags.items()]
    return "{ " + ", ".join(parts) + " }" if parts else "{}"


def section(name: str, entries: dict) -> str:
    w = max(len(k) for k in entries)
    return f"[{name}]\n" + "\n".join(f"{k.ljust(w)} = {v}" for k, v in entries.items()) + "\n"


def q(s: str) -> str:
    return '"' + s + '"'


sections = {
    "mgr": {
        "cwd": st(t["accentText"], bold=True),
        "find_keyword": st(t["warning"], bold=True, underline=True),
        "find_position": st(t["accentText"], italic=True),
        "symlink_target": st(t["textFaint"], italic=True),
        # Markierungsbalken links: kopiert Moos, ausgeschnitten Glutrot, Auswahl Amber, Visual Holz
        "marker_copied": st(t["success"], t["success"]),
        "marker_cut": st(t["error"], t["error"]),
        "marker_marked": st(t["woodLight"], t["woodLight"]),
        "marker_selected": st(t["warning"], t["warning"]),
        "count_copied": st(t["onAccent"], t["success"], bold=True),
        "count_cut": st(t["onAccent"], t["error"], bold=True),
        "count_selected": st(t["onAccent"], t["warning"], bold=True),
        "border_style": st(border),
        "syntect_theme": q(tilde(HOME / ".config/bat/themes/desktop.tmTheme")),
    },
    # Hover: aktuelle Spalte accentFill, Elternspalte nur eine Stufe angehoben
    "indicator": {
        "parent": st(t["textMuted"], t["surfaceRaised"]),
        "current": st(t["text"], t["accentFill"], bold=True),
        "preview": st(t["text"], t["surface"]),
    },
    "tabs": {
        "active": st(t["onAccent"], t["woodLight"], bold=True),
        "inactive": st(t["textMuted"], t["surface"]),
    },
    # Modus-Pille unten links: normal Ember, Auswahl Amber, Abwählen Glutrot
    "mode": {
        "normal_main": st(t["onAccent"], t["accent"], bold=True),
        "normal_alt": st(t["accentText"], t["surfaceRaised"]),
        "select_main": st(t["onAccent"], t["warning"], bold=True),
        "select_alt": st(t["warning"], t["surfaceRaised"]),
        "unset_main": st(t["onAccent"], t["error"], bold=True),
        "unset_alt": st(t["error"], t["surfaceRaised"]),
    },
    "status": {
        "overall": st(t["textMuted"]),
        "perm_sep": st(faint),
        "perm_type": st(t["woodLight"]),
        "perm_read": st(t["warning"]),
        "perm_write": st(t["error"]),
        "perm_exec": st(t["success"]),
        "progress_label": st(t["text"], bold=True),
        "progress_normal": st(t["accent"], t["surfaceSunken"]),
        "progress_error": st(t["error"], t["surfaceSunken"]),
    },
    "which": {
        "border": st(border),
        "mask": st(bg=t["surfaceSunken"]),
        "cand": st(t["accentText"], bold=True),
        "rest": st(t["textFaint"]),
        "desc": st(t["text"]),
        "separator_style": st(faint),
    },
    "confirm": {
        "border": st(t["accent"]),
        "title": st(t["accentText"], bold=True),
        "body": st(t["text"]),
        "list": st(t["textMuted"]),
        "btn_yes": st(t["onAccent"], t["accent"], bold=True),
        "btn_no": st(t["textMuted"], t["surfaceRaised"]),
    },
    "spot": {
        "border": st(border),
        "title": st(t["accentText"], bold=True),
        "tbl_col": st(t["woodLight"]),
        "tbl_cell": st(t["text"], t["accentFill"]),
    },
    "notify": {
        "title_info": st(t["success"], bold=True),
        "title_warn": st(t["warning"], bold=True),
        "title_error": st(t["error"], bold=True),
    },
    "pick": {
        "border": st(border),
        "active": st(t["text"], t["accentFill"], bold=True),
        "inactive": st(t["textMuted"]),
    },
    "input": {
        "border": st(t["accent"]),
        "title": st(t["accentText"], bold=True),
        "value": st(t["text"]),
        "selected": st(t["text"], t["accentFill"]),
    },
    "cmp": {
        "border": st(border),
        "active": st(t["text"], t["accentFill"], bold=True),
        "inactive": st(t["textMuted"]),
    },
    "tasks": {
        "border": st(border),
        "title": st(t["accentText"], bold=True),
        "hovered": st(t["text"], t["accentFill"], bold=True),
    },
    "help": {
        "border": st(border),
        "chord": st(t["accentText"]),
        "action": st(t["text"]),
        "hovered": st(t["text"], t["accentFill"], bold=True),
    },
}

# Dateitypen: erste passende Regel gewinnt. Die Liste ersetzt das Preset komplett,
# darum stehen Sonderfälle (verwaist, Dummy, VFS) wieder mit drin.
archive = "zip,rar,7z*,tar,gzip,xz,zstd,bzip*,lzma,compress,archive,cpio,arj,xar,ms-cab*"
rules = [
    ('mime = "**/image/*"', st(c["magenta"])),
    ('mime = "**/{audio,video}/*"', st(c["blue"])),
    (f'mime = "**/application/{{{archive}}}"', st(t["accentText"])),
    ('mime = "**/application/{pdf,doc,rtf,epub*,vnd.oasis.opendocument.*,'
     'vnd.openxmlformats-officedocument.*}"', st(c["cyan"])),
    ('mime = "vfs/{absent,stale}"', st(t["textFaint"])),
    ('url = "*", is = "orphan"', st(t["error"], crossed=True)),
    ('url = "*", is = "link"', st(t["textMuted"], italic=True)),
    ('url = "*", is = "exec"', st(t["success"])),
    ('url = "*", is = "dummy"', st(t["error"], italic=True)),
    ('url = "*/", is = "dummy"', st(t["error"], italic=True)),
    ('url = "*/"', st(t["woodLight"], bold=True)),
    ('url = "*"', st(t["text"])),
]
filetype = "[filetype]\nrules = [\n" + "".join(
    f"\t{{ {sel}, {style[2:-2]} }},\n" for sel, style in rules) + "]\n"

# Icons: Preset-Glyphen behalten, nur die bunten Ordner-/Fallback-Farben auf Holz/Creme ziehen.
# Datei-/Endungs-Icons (Sprachfarben) bleiben wie im Preset.
dir_names = {
    ".config": "", ".git": "", ".github": "", ".npm": "",
    "Desktop": "", "Development": "", "Documents": "", "Downloads": "",
    "Library": "", "Movies": "", "Music": "", "Pictures": "",
    "Public": "", "Videos": "",
}
conds = [
    ("orphan", "", t["error"]),
    ("link", "", t["textFaint"]),
    ("block", "", t["warning"]),
    ("char", "", t["warning"]),
    ("fifo", "", t["warning"]),
    ("sock", "", t["warning"]),
    ("sticky", "", t["warning"]),
    ("dummy", "", t["error"]),
    ("dir & hovered", "", t["woodLight"]),
    ("dir", "", t["woodLight"]),
    ("exec", "", t["success"]),
    ("!dir", "", t["textMuted"]),
]
icon = ("[icon]\nprepend_dirs = [\n"
        + "".join(f'\t{{ name = "{n}", text = "{g}", fg = "{t["woodLight"]}" }},\n' for n, g in dir_names.items())
        + "]\nprepend_conds = [\n"
        + "".join(f'\t{{ if = "{i}", text = "{g}", fg = "{fg}" }},\n' for i, g, fg in conds)
        + "]\n")

toml = (f"# {MARK} ({variant}) – nicht von Hand ändern. Neu erzeugen: python3 -I theme/gen/yazi.py\n"
        "#:schema https://yazi-rs.github.io/schemas/theme.json\n\n"
        + "\n".join(section(k, v) for k, v in sections.items())
        + "\n" + filetype + "\n" + icon)

print(f"yazi ({variant}):")
out = OUT / "yazi/theme.toml"
write(out, toml)
if install_wanted():
    install(out, HOME / ".config/yazi/theme.toml")
