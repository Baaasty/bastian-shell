#!/usr/bin/env python3
"""theme/palette.json -> bat-Farbschema „Desktop Hearth“ (theme/out/bat/desktop.tmTheme).

Warm und ruhig: Code Creme, Schlüsselwörter Ember, Strings Moos, Zahlen Amber, Typen Holz,
Funktionen Akzent-Text, Kommentare leise kursiv. Rahmen/Zeilennummern in Holz, kein eigener Hintergrund
(Terminalfläche bleibt). Installiert nach ~/.config/bat/themes/ und baut den bat-Cache neu.
Stil (Rahmen, Nummern, Dateiname) setzt config/zsh/zshrc über BAT_STYLE.
Aufruf aus dem Repo-Root: python3 -I theme/gen/bat.py [variante] [--nur-out]
"""
import pathlib
import shutil
import subprocess
import sys
from xml.sax.saxutils import escape

sys.path.insert(0, str(pathlib.Path(__file__).resolve().parent))
from _pal import HOME, MARK, OUT, install, install_wanted, load, mix, write  # noqa: E402
import _term  # noqa: E402

src, variant, t = load()
c = _term.colors(src, t)
bg = c["bg"]

general = {
    "background": bg,
    "foreground": t["text"],
    "caret": t["accent"],
    "selection": t["accentFill"],
    "lineHighlight": mix(bg, t["wood"], 0.25),
    "gutterForeground": mix(bg, t["woodLight"], 0.6),   # Zeilennummern
    "guide": mix(bg, t["wood"], 0.7),                   # Rahmenlinien (grid)
    "findHighlight": t["warning"],
}

# (Name, Scopes, Farbe, Schrift)
rules = [
    ("Kommentar", "comment, punctuation.definition.comment", t["textFaint"], "italic"),
    ("String", "string, punctuation.definition.string", c["green"], ""),
    ("Escape", "constant.character.escape, string.regexp", c["cyan"], ""),
    ("Zahl", "constant.numeric", t["warning"], ""),
    ("Konstante", "constant.language, constant.other, support.constant", t["warning"], ""),
    ("Schlüsselwort", "keyword, storage.type, storage.modifier", t["accent"], ""),
    ("Operator", "keyword.operator, punctuation.separator, punctuation.terminator", t["textMuted"], ""),
    ("Funktion", "entity.name.function, support.function, meta.function-call variable.function", t["accentText"], ""),
    ("Typ/Klasse", "entity.name.type, entity.name.class, support.type, support.class, entity.other.inherited-class",
     t["woodLight"], ""),
    ("Tag", "entity.name.tag", t["accent"], ""),
    ("Attribut", "entity.other.attribute-name", t["woodLight"], "italic"),
    ("Variable", "variable, variable.other", t["text"], ""),
    ("Parameter", "variable.parameter", c["magenta"], "italic"),
    ("Sprachvariable", "variable.language", c["magenta"], "italic"),
    ("Schlüssel (JSON/YAML/TOML)", "meta.mapping.key string, support.type.property-name, entity.name.tag.yaml, "
     "meta.object-literal.key", t["accentText"], ""),
    ("Klammern", "punctuation, meta.brace", t["textMuted"], ""),
    ("Überschrift", "markup.heading, entity.name.section", t["accent"], "bold"),
    ("Fett", "markup.bold", t["text"], "bold"),
    ("Kursiv", "markup.italic", t["text"], "italic"),
    ("Code", "markup.raw, markup.inline.raw", c["green"], ""),
    ("Link", "markup.underline.link, string.other.link", c["blue"], "underline"),
    ("Liste", "markup.list punctuation.definition.list", t["accent"], ""),
    ("Zitat", "markup.quote", t["textMuted"], "italic"),
    ("Diff +", "markup.inserted", t["success"], ""),
    ("Diff -", "markup.deleted", t["error"], ""),
    ("Diff ~", "markup.changed", t["warning"], ""),
    ("Diff Kopf", "meta.diff.header, meta.diff.range", c["blue"], ""),
    ("Fehler", "invalid", t["error"], "underline"),
]


def d(entries: dict) -> str:
    return "<dict>" + "".join(f"<key>{k}</key><string>{escape(v)}</string>" for k, v in entries.items()) + "</dict>"


items = [f"<dict><key>settings</key>{d(general)}</dict>"]
for name, scope, fg, style in rules:
    s = {"foreground": fg}
    if style:
        s["fontStyle"] = style
    items.append(f"<dict><key>name</key><string>{escape(name)}</string><key>scope</key><string>{escape(scope)}</string>"
                 f"<key>settings</key>{d(s)}</dict>")

xml = f"""<?xml version="1.0" encoding="UTF-8"?>
<!-- {MARK} ({variant}) – nicht von Hand ändern. Neu erzeugen: python3 -I theme/gen/bat.py -->
<!DOCTYPE plist PUBLIC "-//Apple//DTD PLIST 1.0//EN" "http://www.apple.com/DTDs/PropertyList-1.0.dtd">
<plist version="1.0"><dict>
<key>name</key><string>Desktop Hearth</string>
<key>settings</key><array>
{chr(10).join(items)}
</array></dict></plist>
"""

print(f"bat ({variant}):")
out = OUT / "bat/desktop.tmTheme"
write(out, xml)
if install_wanted():
    install(out, HOME / ".config/bat/themes/desktop.tmTheme")
    if shutil.which("bat"):
        subprocess.run(["bat", "cache", "--build"], check=False, stdout=subprocess.DEVNULL)
        print("  bat-Cache neu gebaut")
