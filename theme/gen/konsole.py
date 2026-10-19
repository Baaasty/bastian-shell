#!/usr/bin/env python3
"""theme/palette.json -> Konsole-Farbschema + Profil "Desktop" (theme/out/konsole/).

Installiert nach ~/.local/share/konsole/, stellt das Standardprofil aber NICHT um.
Schlüssel wie in Konsoles eingebauten Schemata (ColorScheme.cpp/Profile.cpp). Aufruf aus dem Repo-Root:
  python3 -I theme/gen/konsole.py [variante] [--nur-out]
"""
import pathlib
import sys

sys.path.insert(0, str(pathlib.Path(__file__).resolve().parent))
from _pal import HOME, MARK, OUT, install, install_wanted, kde, load, mix, write  # noqa: E402
import _term  # noqa: E402

src, variant, t = load()
ansi = src["ansi"]
glass = src["glass"]["terminal"]
mono = src["type"]["mono"]["family"]
tc = _term.colors(src, t)  # deckende Varianten (hearth): warme ANSI-Farben mit Kontrast >= 4,5:1, sonst ansi.* aus der Palette
solid = tc["solid"]
bg = tc["bg"]

names = ["black", "red", "green", "yellow", "blue", "magenta", "cyan", "white"]


def faint(c: str) -> str:
    """Faint = Richtung Hintergrund gedimmt."""
    return mix(c, bg, 0.35)


blocks = {
    "Background": bg,
    "BackgroundFaint": bg,
    "BackgroundIntense": tc["black"],
    "Foreground": tc["fg"],
    "ForegroundFaint": faint(tc["fg"]),
    "ForegroundIntense": tc["brightWhite"],
}
for i, n in enumerate(names):
    blocks[f"Color{i}"] = tc[n]
    blocks[f"Color{i}Faint"] = faint(tc[n])
    blocks[f"Color{i}Intense"] = tc["bright" + n.capitalize()]

head = f"# {MARK} ({variant}) – nicht von Hand ändern.\n# Neu erzeugen: python3 -I theme/gen/konsole.py\n\n"

scheme = head + "\n\n".join(f"[{k}]\nColor={kde(v)}" for k, v in sorted(blocks.items()))
# Glas 78 % + Blur nur in Glas-Varianten (Stärke stellt KWin, nicht Konsole); hearth = deckend
scheme += "\n\n" + "\n".join([
    "[General]",
    "Anchor=0.5,0.5",
    f"Blur={'true' if glass['blur'] and not solid else 'false'}",
    "ColorRandomization=false",
    "Description=Desktop",
    "FillStyle=Tile",
    f"Opacity={1 if solid else ansi['backgroundOpacity']}",
    "Wallpaper=",
    "WallpaperFlipType=NoFlip",
    "WallpaperOpacity=1",
]) + "\n"

# Ruhig und luftig: Balken-Cursor, keine Scrollbar, Rand aus space["6"], Tab-Titel = Ordnername.
# Werkzeugleisten/Tab-Leiste stehen nicht im Profil, sondern in konsolerc/konsolestaterc (scripts/konsole-ui).
profile = head + "\n".join([
    "[Appearance]",
    "ColorScheme=Desktop",
    f"Font={mono},12",
    "LineSpacing=2",
    "UseFontLineChararacters=false",
    "",
    "[Cursor Options]",
    "CursorShape=1",  # 0 Block, 1 Balken (I-Beam), 2 Unterstrich
    f"CustomCursorColor={kde(tc['cursor'])}",
    f"CustomCursorTextColor={kde(tc['cursorText'])}",
    "UseCustomCursorColor=true",
    "",
    "[General]",
    "LocalTabTitleFormat=%d",
    "Name=Desktop",
    "Parent=FALLBACK/",
    "ShowTerminalSizeHint=false",
    "TerminalCenter=false",
    f"TerminalMargin={src['space']['6']}",
    "",
    "[Scrolling]",
    "HistorySize=10000",
    "ScrollBarPosition=2",  # 0 links, 1 rechts, 2 aus (Mausrad/Umschalt+Bild scrollt weiter)
    "",
    "[Terminal Features]",
    "BlinkingCursorEnabled=false",
]) + "\n"

print(f"Konsole ({variant}):")
for name, text in [("Desktop.colorscheme", scheme), ("Desktop.profile", profile)]:
    out = OUT / "konsole" / name
    write(out, text)
    if install_wanted():
        install(out, HOME / ".local/share/konsole" / name)
