#!/usr/bin/env python3
"""theme/palette.json -> Lockscreen-Farben (DesktopTheme.qml im Shell-Paket).

Der Lockscreen (kscreenlocker) kann palette.json nicht selbst lesen, deshalb wird
ein QML-Singleton erzeugt. Aufruf aus dem Repo-Root:
  python3 theme/gen/lockscreen_theme.py [variante]
"""
import json
import pathlib
import re
import sys

ROOT = pathlib.Path(__file__).resolve().parents[2]
OUT = ROOT / "plasma/shells/de.bastian.desktop/contents/lockscreen/DesktopTheme.qml"

src = json.loads((ROOT / "theme/palette.json").read_text())
variant = sys.argv[1] if len(sys.argv) > 1 else src["defaultTheme"]
theme = src["themes"][variant]


def qml_color(value: str) -> str:
    m = re.fullmatch(r"rgba\(\s*(\d+),\s*(\d+),\s*(\d+),\s*([\d.]+)\s*\)", value)
    if m:
        r, g, b, a = m.groups()
        return f"Qt.rgba({int(r)} / 255, {int(g)} / 255, {int(b)} / 255, {float(a)})"
    return json.dumps(value)


lines = [
    "// ERZEUGT aus theme/palette.json – nicht von Hand ändern.",
    "// Neu erzeugen: python3 theme/gen/lockscreen_theme.py",
    "pragma Singleton",
    "import QtQuick",
    "",
    "QtObject {",
    f'    readonly property string variant: "{variant}"',
    f'    readonly property string fontUi: "{src["type"]["ui"]["family"]}"',
    f'    readonly property string fontMono: "{src["type"]["mono"]["family"]}"',
]
# „onAccent“ ginge in QML als Signal-Handler durch (Präfix „on“) – darum umbenannt
RENAME = {"onAccent": "textOnAccent"}
for key, value in theme.items():
    key = RENAME.get(key, key)
    if isinstance(value, bool):  # z. B. blur (hearth: deckend, kein Blur)
        lines.append(f"    readonly property bool {key}: {'true' if value else 'false'}")
    else:
        lines.append(f"    readonly property color {key}: {qml_color(value)}")
lines.append("}")
OUT.write_text("\n".join(lines) + "\n")
print(f"{OUT.relative_to(ROOT)} geschrieben ({variant})")
