#!/usr/bin/env python3
"""theme/palette.json -> git-delta (theme/out/delta.gitconfig): schöne git diffs im Desktop-Look.

Syntax-Farben aus dem bat-Schema „desktop“ (theme/gen/bat.py), +/- als leise Moos-/Glut-Flächen,
Zeilennummern in Holz, Datei-Kopf mit Akzent-Linie. n/N springt im Pager von Datei zu Datei.
Eingebunden per include.path in ~/.gitconfig (deine Datei bleibt sonst unverändert):
  scripts/zsh-setup install|off macht das mit (git config --global --add/--unset include.path …).
Aufruf aus dem Repo-Root: python3 -I theme/gen/delta.py [variante]
"""
import pathlib
import sys

sys.path.insert(0, str(pathlib.Path(__file__).resolve().parent))
from _pal import MARK, OUT, load, mix, write  # noqa: E402
import _term  # noqa: E402

src, variant, t = load()
bg = _term.colors(src, t)["bg"]

plus_bg, plus_emph = mix(bg, t["success"], 0.16), mix(bg, t["success"], 0.34)
minus_bg, minus_emph = mix(bg, t["error"], 0.16), mix(bg, t["error"], 0.34)
rule = mix(bg, t["wood"], 0.8)

text = f"""# {MARK} ({variant}) – nicht von Hand ändern. Neu erzeugen: python3 -I theme/gen/delta.py
[core]
	pager = delta
[interactive]
	diffFilter = delta --color-only
[merge]
	conflictStyle = zdiff3
[diff]
	colorMoved = default
[delta]
	navigate = true
	dark = true
	syntax-theme = desktop
	line-numbers = true
	hyperlinks = true
	hyperlinks-file-link-format = "file://{{path}}"
	file-style = "{t['text']}" bold
	file-decoration-style = "{t['accent']}" ul
	file-modified-label = "~"
	file-added-label = "+"
	file-removed-label = "-"
	hunk-header-style = file line-number syntax
	hunk-header-decoration-style = "{rule}" box
	hunk-header-file-style = "{t['textMuted']}"
	hunk-header-line-number-style = "{t['woodLight']}"
	plus-style = syntax "{plus_bg}"
	plus-emph-style = syntax "{plus_emph}"
	minus-style = syntax "{minus_bg}"
	minus-emph-style = syntax "{minus_emph}"
	zero-style = syntax
	line-numbers-zero-style = "{mix(bg, t['woodLight'], 0.5)}"
	line-numbers-plus-style = "{t['success']}"
	line-numbers-minus-style = "{t['error']}"
	line-numbers-left-style = "{rule}"
	line-numbers-right-style = "{rule}"
	blame-palette = "{bg} {mix(bg, t['wood'], 0.2)}"
	merge-conflict-begin-symbol = ▼
	merge-conflict-end-symbol = ▲
	map-styles = bold purple => syntax "{mix(bg, t['warning'], 0.2)}", bold cyan => syntax "{mix(bg, t['woodLight'], 0.2)}"
"""

print(f"delta ({variant}):")
write(OUT / "delta.gitconfig", text)
