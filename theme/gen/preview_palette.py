#!/usr/bin/env python3
"""theme/palette.json -> design/palette.js (für design/preview.html).

Aufruf aus dem Repo-Root: python3 theme/gen/preview_palette.py
"""
import json
import pathlib

ROOT = pathlib.Path(__file__).resolve().parents[2]
src = json.loads((ROOT / "theme/palette.json").read_text())

data = {
    "default": src["defaultTheme"],
    "themes": src["themes"],
    "info": src.get("themeInfo", {}),
    "ansi": src["ansi"],
    "editor": src["editorSyntax"],
    "layout": src["layout"],
    "radius": src["radius"],
    "glass": src["glass"],
    "motion": src["motion"],
    "focus": src["focus"],
}
out = ROOT / "design/palette.js"
out.write_text(
    "// ERZEUGT aus theme/palette.json – nicht von Hand ändern.\n"
    "// Neu erzeugen: python3 theme/gen/preview_palette.py\n"
    "window.DESKTOP = " + json.dumps(data, indent=2, ensure_ascii=False) + ";\n"
)
print(f"{out.relative_to(ROOT)} geschrieben ({', '.join(src['themes'])})")
