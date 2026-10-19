#!/usr/bin/env python3
"""theme/palette.json -> Kitty (theme/out/kitty/theme.conf) + Konfiguration (config/kitty/kitty.conf ist von Hand).

theme.conf: Hintergrund, Vordergrund, Cursor, Auswahl, 16 ANSI-Farben (warm, Kontrast >= 4,5:1),
Tab-Leiste, aktiver/inaktiver Tab, Fensterrahmen, Marks, URL-Farbe.
Installieren/zurücknehmen: scripts/kitty-theme install|off|status (dieses Skript schreibt nur theme/out/).
Aufruf aus dem Repo-Root: python3 -I theme/gen/kitty.py [variante]
"""
import pathlib
import sys

sys.path.insert(0, str(pathlib.Path(__file__).resolve().parent))
from _pal import MARK, OUT, load, mix, over, write  # noqa: E402
import _term  # noqa: E402

src, variant, t = load()
c = _term.colors(src, t)
bg = c["bg"]

# Tab-Leiste: eine Stufe tiefer als das Terminal, aktiver Tab = Terminalfläche (wächst aus dem Inhalt),
# inaktive Tabs verschmelzen mit der Leiste. Akzent nur als dünner Strich (Rahmen/Cursor), nie als Fläche.
tabbar = mix(bg, "#000000", 0.28)
border_inactive = over(t["border"], bg)

lines = [
    f"# {MARK} ({variant}) – nicht von Hand ändern.",
    "# Neu erzeugen: python3 -I theme/gen/kitty.py  ·  einbinden: scripts/kitty-theme install",
    "",
    "# --- Basis ---",
    f"foreground {c['fg']}",
    f"background {bg}",
    f"selection_foreground {c['selFg']}",
    f"selection_background {c['selBg']}",
    f"cursor {c['cursor']}",
    f"cursor_text_color {c['cursorText']}",
    f"url_color {t['accentText']}",
    "",
    "# --- Fensterrahmen (nur sichtbar bei Splits) ---",
    f"active_border_color {t['accent']}",
    f"inactive_border_color {border_inactive}",
    f"bell_border_color {t['warning']}",
    "",
    "# --- Tab-Leiste ---",
    f"tab_bar_background {tabbar}",
    f"tab_bar_margin_color {tabbar}",
    f"active_tab_foreground {t['text']}",
    f"active_tab_background {bg}",
    f"inactive_tab_foreground {t['textMuted']}",
    f"inactive_tab_background {tabbar}",
    "",
    "# --- Markierungen (Strg+Shift+F-Treffer, Link-Hints) ---",
    f"mark1_foreground {t['onAccent']}",
    f"mark1_background {t['accentText']}",
    f"mark2_foreground {t['onAccent']}",
    f"mark2_background {t['warning']}",
    f"mark3_foreground {t['onAccent']}",
    f"mark3_background {t['success']}",
    "",
    "# --- ANSI (0-7 normal, 8-15 hell) ---",
]
names = _term.NAMES
for i, n in enumerate(names):
    lines.append(f"color{i} {c[n]}")
for i, n in enumerate(names):
    lines.append(f"color{i + 8} {c['bright' + n.capitalize()]}")
lines.append("")

print(f"Kitty ({variant}):")
write(OUT / "kitty/theme.conf", "\n".join(lines))
