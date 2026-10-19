#!/usr/bin/env python3
"""theme/palette.json -> lazygit-Config (theme/out/lazygit/config.yml), installiert nach ~/.config/lazygit/config.yml.

Ruhig und warm: aktiver Rahmen Ember fett, inaktive Rahmen Holz, ausgewählte Zeile auf accentFill,
Suche Amber, ungestagte Änderungen Glutrot, Text Creme. Runde Rahmen, Nerd-Font-Icons (v3).
Diffs laufen durch delta (`delta --dark --paging=never`); delta selbst wird über git config eingestellt,
nicht hier. Schema: lazygit 0.47 (docs/Config.md).
Aufruf aus dem Repo-Root: python3 -I theme/gen/lazygit.py [variante] [--nur-out]
"""
import json
import pathlib
import sys

sys.path.insert(0, str(pathlib.Path(__file__).resolve().parent))
from _pal import HOME, MARK, OUT, install, install_wanted, load, mix, write  # noqa: E402
import _term  # noqa: E402

src, variant, t = load()
c = _term.colors(src, t)
bg = c["bg"]

# Farbattribute: Liste aus höchstens einer Farbe ('#rrggbb') plus Modifikatoren (bold, underline …)
theme = {
    "activeBorderColor": [t["accent"], "bold"],
    "inactiveBorderColor": [mix(bg, t["woodLight"], 0.55)],
    "searchingActiveBorderColor": [t["warning"], "bold"],
    "optionsTextColor": [t["accentText"]],
    "selectedLineBgColor": [t["accentFill"]],
    "inactiveViewSelectedLineBgColor": [t["surfaceRaised"]],
    "cherryPickedCommitFgColor": [t["onAccent"]],
    "cherryPickedCommitBgColor": [t["woodLight"]],
    "markedBaseCommitFgColor": [t["onAccent"]],
    "markedBaseCommitBgColor": [t["warning"]],
    "unstagedChangesColor": [t["error"]],
    "defaultFgColor": [t["text"]],
}

config = {
    "gui": {
        "theme": theme,
        "nerdFontsVersion": "3",   # ersetzt das veraltete showIcons
        "showFileIcons": True,
        "border": "rounded",
    },
    "git": {
        "paging": {
            "colorArg": "always",
            "pager": "delta --dark --paging=never",
        },
    },
}


def y(v) -> str:
    """Skalar als YAML (JSON-Strings sind gültiges YAML, '#' bleibt so sicher in Anführungszeichen)."""
    return json.dumps(v, ensure_ascii=False)


def dump(d: dict, indent: int = 0) -> str:
    pad = "  " * indent
    lines = []
    for k, v in d.items():
        if isinstance(v, dict):
            lines.append(f"{pad}{k}:")
            lines.append(dump(v, indent + 1))
        elif isinstance(v, list):
            lines.append(f"{pad}{k}:")
            lines += [f"{pad}  - {y(i)}" for i in v]
        else:
            lines.append(f"{pad}{k}: {y(v)}")
    return "\n".join(lines)


yml = (f"# {MARK} ({variant}) – nicht von Hand ändern. Neu erzeugen: python3 -I theme/gen/lazygit.py\n"
       "# yaml-language-server: $schema=https://raw.githubusercontent.com/jesseduffield/lazygit/v0.47.2/schema/config.json\n"
       + dump(config) + "\n")

print(f"lazygit ({variant}):")
out = OUT / "lazygit/config.yml"
write(out, yml)
if install_wanted():
    install(out, HOME / ".config/lazygit/config.yml")
