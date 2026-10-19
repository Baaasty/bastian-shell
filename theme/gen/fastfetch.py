#!/usr/bin/env python3
"""theme/palette.json -> Fastfetch (theme/out/fastfetch/config.jsonc).

Links eine kleine Katze (config/fastfetch/cat.txt, Farbmarke $1), rechts ein ruhiger Block:
  user @ host
  good evening

  system ─────────────────────
    󰣛  os      Fedora Linux 44
    …
  hardware ───────────────────
    …
    ● ● ● ● ● ● ● ●
Icons im Akzent-Text, Schlüssel gedämpft, Werte Creme. Läuft beim Öffnen von Kitty (config/fastfetch/greet.sh).
Einbinden/zurücknehmen: scripts/kitty-theme install|off (dieses Skript schreibt nur theme/out/).
Aufruf aus dem Repo-Root: python3 -I theme/gen/fastfetch.py [variante]
"""
import json
import pathlib
import sys

sys.path.insert(0, str(pathlib.Path(__file__).resolve().parent))
from _pal import MARK, OUT, ROOT, load, mix, write  # noqa: E402

src, variant, t = load()

icon, key, value, faint = t["accentText"], t["textMuted"], t["text"], t["textFaint"]

logo_colors = {"1": t["textMuted"]}  # Katze: eine leise Farbe
rule = mix(t["bgBottom"], t["wood"], 0.8)


def k(glyph: str, label: str) -> str:
    """Schlüssel: eingerückt, Icon im Akzent-Text, Name gedämpft, auf feste Breite.
    Nur Icons aus dem BMP (U+E000–F8FF): die 󰀀-Reihe (U+F0000+) ist in Kitty 2 Zellen breit und verschiebt die Spalte."""
    return f"  {{#{icon}}}{glyph}  {{#{key}}}{label:<6}"


def section(name: str) -> dict:
    """Abschnittskopf: Name leise, dann eine Holzlinie."""
    return {"type": "custom", "format": f"{{#{faint}}}{name} {{#{rule}}}" + "─" * (30 - len(name))}


# Gruß nach Tageszeit (läuft bei jedem Start, kein Netz)
greet = (
    'h=$(date +%-H); '
    'if [ "$h" -lt 5 ]; then echo "still up?"; '
    'elif [ "$h" -lt 11 ]; then echo "good morning"; '
    'elif [ "$h" -lt 17 ]; then echo "good afternoon"; '
    'elif [ "$h" -lt 22 ]; then echo "good evening"; '
    'else echo "cozy night"; fi'
)

cfg = {
    "$schema": "https://github.com/fastfetch-cli/fastfetch/raw/dev/doc/json_schema.json",
    "_": f"{MARK} ({variant}) – nicht von Hand ändern. Neu erzeugen: python3 -I theme/gen/fastfetch.py",
    "logo": {
        # Katze direkt in der Datei (type data) statt Pfad aufs Repo: die Ausgabe hängt nicht am Checkout-Ort
        "type": "data",
        "source": (ROOT / "config/fastfetch/cat.txt").read_text().rstrip("\n"),
        "color": logo_colors,
        "padding": {"top": 0, "left": 2, "right": 3},  # top: unten, Katze mittig zum Textblock
    },
    "display": {
        "separator": "  ",
        "color": {"keys": key, "title": icon, "output": value, "separator": faint},
        "brightColor": False,
        "size": {"binaryPrefix": "jedec", "ndigits": 1},
        "percent": {"type": 0},
    },
    "modules": [
        "break",
        {"type": "title", "format": f"{{#1;{icon}}}{{user-name}}{{#0}}{{#{faint}}} @ {{#{value}}}{{host-name}}"},
        {"type": "command", "key": " ", "keyWidth": 0, "separator": "", "text": greet, "outputColor": faint},
        "break",
        section("system"),
        {"type": "os", "key": k("", "os"), "format": "{name} {version-id}"},
        {"type": "wm", "key": k("", "wm"), "format": "{pretty-name} {version}"},
        {"type": "shell", "key": k("", "shell"), "format": "{pretty-name} {version}"},
        {"type": "packages", "key": k("", "pkgs"),
         "format": "{rpm} rpm {#" + faint + "}·{#" + value + "} {flatpak-all} flatpak"},
        {"type": "uptime", "key": k("", "up"),
         "format": "{?days}{days}d {?}{hours}h {minutes}m"},
        "break",
        section("hardware"),
        {"type": "cpu", "key": k("", "cpu"), "format": "{name} {#" + faint + "}· {cores-logical} threads"},
        {"type": "gpu", "key": k("", "gpu"), "format": "{name}"},
        {"type": "memory", "key": k("", "ram"), "format": "{used} {#" + faint + "}/ {total}"},
        {"type": "disk", "key": k("", "disk"), "folders": "/", "format": "{size-used} {#" + faint + "}/ {size-total}"},
        "break",
        {"type": "colors", "symbol": "circle", "paddingLeft": 2},
    ],
}

# Katze senkrecht mittig zum Textblock (eine Zeile pro Modul)
logo_h = len((ROOT / "config/fastfetch/cat.txt").read_text().splitlines())
cfg["logo"]["padding"]["top"] = max(0, (len(cfg["modules"]) - logo_h + 1) // 2)

print(f"Fastfetch ({variant}):")
write(OUT / "fastfetch/config.jsonc", json.dumps(cfg, indent=2, ensure_ascii=False) + "\n")
