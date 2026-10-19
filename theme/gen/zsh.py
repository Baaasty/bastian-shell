#!/usr/bin/env python3
"""theme/palette.json -> zsh-Farben (theme/out/zsh/colors.zsh), eingebunden von config/zsh/zshrc.

Setzt: Syntax-Highlighting (Befehle Creme, Fehler Glutrot, Strings Amber, Pfade unterstrichen),
Autosuggestion-Grau, fzf (Ctrl+R/Ctrl+T/Alt+C und fzf-tab), Completion-Menü, bat (Theme desktop aus theme/gen/bat.py).
Aufruf aus dem Repo-Root: python3 -I theme/gen/zsh.py [variante]
"""
import pathlib
import sys

sys.path.insert(0, str(pathlib.Path(__file__).resolve().parent))
from _pal import MARK, OUT, load, mix, write  # noqa: E402
import _term  # noqa: E402

src, variant, t = load()
term_bg = _term.colors(src, t)["bg"]

hl = {
    "default": f"fg={t['text']}",
    "command": f"fg={t['text']},bold",
    "builtin": f"fg={t['text']},bold",
    "alias": f"fg={t['text']},bold",
    "function": f"fg={t['text']},bold",
    "precommand": f"fg={t['accentText']},italic",
    "reserved-word": f"fg={t['accentText']}",
    "unknown-token": f"fg={t['error']}",
    "path": f"fg={t['text']},underline",
    "path_prefix": f"fg={t['textMuted']},underline",
    "globbing": f"fg={t['accentText']}",
    "single-hyphen-option": f"fg={t['woodLight']}",
    "double-hyphen-option": f"fg={t['woodLight']}",
    "single-quoted-argument": f"fg={t['warning']}",
    "double-quoted-argument": f"fg={t['warning']}",
    "dollar-quoted-argument": f"fg={t['warning']}",
    "back-quoted-argument": f"fg={t['accentText']}",
    "dollar-double-quoted-argument": f"fg={t['accentText']}",
    "commandseparator": f"fg={t['textFaint']}",
    "redirection": f"fg={t['textFaint']}",
    "comment": f"fg={t['textFaint']},italic",
    "arg0": f"fg={t['text']}",
}

fzf = {
    "fg": t["textMuted"], "bg": "-1", "hl": t["accentText"],
    "fg+": t["text"], "bg+": t["accentFill"], "hl+": t["accentText"],
    "info": t["textFaint"], "prompt": t["accent"], "pointer": t["accent"], "marker": t["success"],
    "spinner": t["accent"], "header": t["textFaint"], "border": mix(term_bg, t["wood"], 0.7),
    "gutter": "-1", "query": t["text"], "separator": mix(term_bg, t["wood"], 0.5), "scrollbar": t["wood"],
    "label": t["textMuted"],
}
fzf_colors = ",".join(f"{k}:{v}" for k, v in fzf.items())

lines = [
    f"# {MARK} ({variant}) – nicht von Hand ändern. Neu erzeugen: python3 -I theme/gen/zsh.py",
    "",
    "# --- Syntax-Highlighting (vor dem Laden des Plugins gesetzt) ---",
    "typeset -gA ZSH_HIGHLIGHT_STYLES",
]
lines += [f"ZSH_HIGHLIGHT_STYLES[{k}]='{v}'" for k, v in hl.items()]
lines += [
    "",
    "# --- Autosuggestion: leise, aber lesbar ---",
    f"ZSH_AUTOSUGGEST_HIGHLIGHT_STYLE='fg={t['textFaint']}'",
    "",
    "# --- fzf ---",
    f"export DESKTOP_FZF_COLORS='{fzf_colors}'",
    "",
    "# --- Completion-Menü: Auswahl als ruhige Akzentfläche ---",
    f"DESKTOP_MENU_SELECT='{t['accentFill']}'",
    f"DESKTOP_DESC_COLOR='{t['textFaint']}'",
    f"DESKTOP_GROUP_COLOR='{t['accentText']}'",
    "",
    "# --- bat: eigenes Farbschema aus der Palette (theme/gen/bat.py) ---",
    "export BAT_THEME=desktop",
    "",
]

print(f"zsh ({variant}):")
write(OUT / "zsh/colors.zsh", "\n".join(lines))
