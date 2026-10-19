#!/usr/bin/env python3
"""theme/palette.json -> Farben/Maße für den KWin-Fensterwechsler (Theme.qml im Paket desktop-switcher).

KWin lädt das TabBox-Layout ohne Zugriff aufs Repo, deshalb werden die Werte als QML-Datei
ins Paket geschrieben. Installiert wird nichts (das macht `scripts/rice switcher`). Aufruf aus dem Repo-Root:
  python3 -I theme/gen/switcher.py [variante]
"""
import pathlib
import sys

sys.path.insert(0, str(pathlib.Path(__file__).resolve().parent))
from _pal import MARK, ROOT, load, rgba, write  # noqa: E402

PKG = ROOT / "bridge/kwin/desktop-switcher/contents/ui/Theme.qml"
CARD_ALPHA = 0.94   # KWin blurt hinter TabBox-Fenstern nicht -> fast deckend statt Glas 0.62

src, variant, t = load()


def qcol(value: str, a: float | None = None) -> str:
    r, g, b, alpha = rgba(value)
    a = alpha if a is None else a
    return f"Qt.rgba({r} / 255, {g} / 255, {b} / 255, {a:g})"


radius = src["radius"]
space = src["space"]
scale = src["type"]["scale"]

props = [
    ("string", "variant", f'"{variant}"'),
    ("string", "fontUi", f'"{src["type"]["ui"]["family"]}"'),
    ("color", "card", qcol(t["surface"], CARD_ALPHA)),
    ("color", "innerHighlight", qcol(src["glass"]["innerHighlight"])),
    ("color", "shadow", "Qt.rgba(0, 0, 0, 0.45)"),
]
props += [("color", k, qcol(v)) for k, v in t.items()]
props += [
    ("int", "radiusCard", radius["xl"]),
    ("int", "radiusItem", radius["lg"]),
    ("int", "radiusThumb", radius["md"]),
    ("int", "radiusSmall", radius["sm"]),
    ("int", "padCard", space["6"]),
    ("int", "padItem", space["3"]),
    ("int", "gapItem", space["2"]),
    ("int", "gapRow", space["3"]),
    ("int", "iconSize", src["icon"]["launcher"]),
    ("int", "borderWidth", src["glass"]["borderWidth"]),
    ("int", "fontTitle", scale["body"]["size"]),
    ("int", "fontLabel", scale["label"]["size"]),
    ("real", "labelTracking", scale["label"]["tracking"]),
    # Auswahl gleitet zügig (Wunsch ~120 ms, kürzer als motion.fade wegen 360 Hz)
    ("int", "moveDuration", 120),
    ("int", "fadeDuration", src["motion"]["fade"]),
]

lines = [
    f"// {MARK} ({variant}) – nicht von Hand ändern.",
    "// Neu erzeugen: python3 -I theme/gen/switcher.py",
    "import QtQuick",
    "",
    "QtObject {",
]
lines += [f"    readonly property {typ} {name}: {val}" for typ, name, val in props]
lines.append("}")
write(PKG, "\n".join(lines) + "\n")
