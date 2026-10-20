#!/usr/bin/env python3
"""theme/palette.json -> KTextEditor-Farbschema "Desktop" (KWrite, Kate, eingebettete Editoren).

Warum eigenes Theme: Die Textfläche von KTextEditor liest nicht das KDE-Farbschema, sondern ein
KSyntaxHighlighting-Theme (JSON). Ohne Eintrag wählt sie zum dunklen Farbschema "Breeze Dark" (blaugrau).
Ebenen wie VS Code (vscode.py, deckende Varianten): Textfläche = bg, Auswahl = accentFill,
Syntaxfarben aus editorSyntax, Richtung Creme angehoben bis Kontrast >= 4,5 : 1 (sonst Abbruch).

Ausgabe: theme/out/ktexteditor/desktop.theme -> ~/.local/share/org.kde.syntax-highlighting/themes/desktop.theme
Aufruf aus dem Repo-Root:
  python3 -I theme/gen/ktexteditor.py [variante] [--nur-out]   erzeugen + installieren, schaltet nichts um
  python3 -I theme/gen/ktexteditor.py --an                     kwriterc + katerc: "Color Theme" = Desktop
  python3 -I theme/gen/ktexteditor.py --aus                    alten Wert zurück (vorher keiner = Automatik)
Laufende KWrite/Kate-Fenster übernehmen es erst nach Neustart.
"""
import json
import pathlib
import subprocess
import sys

sys.path.insert(0, str(pathlib.Path(__file__).resolve().parent))
from _pal import HOME, MARK, OUT, contrast, install, install_wanted, load, mix, over, write  # noqa: E402

THEME = "Desktop"
RCS = ("kwriterc", "katerc")
GROUP, KEY = "KTextEditor Renderer", "Color Theme"
STATE = HOME / ".local/state/desktop"
MEMO = STATE / "ktexteditor-theme.json"


def kread(rc: str) -> str:
    r = subprocess.run(["kreadconfig6", "--file", rc, "--group", GROUP, "--key", KEY], capture_output=True, text=True)
    return r.stdout.strip()


def kwrite(rc: str, value: str | None):
    tail = [value] if value else ["--delete"]
    subprocess.run(["kwriteconfig6", "--file", rc, "--group", GROUP, "--key", KEY, *tail], check=True)


if "--an" in sys.argv or "--aus" in sys.argv:
    if "--an" in sys.argv:
        if not MEMO.exists():  # nur beim ersten Einschalten merken, sonst ginge der echte Ursprung verloren
            STATE.mkdir(parents=True, exist_ok=True)
            MEMO.write_text(json.dumps({rc: kread(rc) for rc in RCS}, indent=1))
        for rc in RCS:
            kwrite(rc, THEME)
        print(f"KTextEditor: {', '.join(RCS)} -> {KEY}={THEME} (greift beim nächsten Start)")
    else:
        memo = json.loads(MEMO.read_text()) if MEMO.exists() else {}
        for rc in RCS:
            kwrite(rc, memo.get(rc) or None)
        MEMO.unlink(missing_ok=True)
        print(f"KTextEditor: {KEY} zurück ({memo or 'Automatik'})")
    sys.exit(0)

src, variant, t = load()
ed = src["editorSyntax"]
solid = not t.get("blur", True)
bg = t["bg"] if solid else ed["background"]   # Glas-Varianten: dunkler Editor-Grund wie in VS Code


def lift(c: str, minc: float) -> str:
    """Richtung Creme schieben, bis Kontrast >= minc auf der Textfläche."""
    for i in range(21):
        v = mix(c, t["text"], i / 20)
        if contrast(v, bg) >= minc:
            return v
    return t["text"]


ed = {**ed, "text": lift(ed["text"], 9), "keyword": lift(ed["keyword"], 6), "type": lift(ed["type"], 7),
      "string": lift(ed["string"], 6), "number": lift(ed["number"], 6), "comment": lift(ed["comment"], 4.5),
      "punctuation": lift(ed["punctuation"], 5), "lineNumber": lift(ed["lineNumber"], 3.2),
      "error": lift(ed["error"], 4.5)}
regex = lift(src["ansi"]["cyan"], 4.5)
fn = t["text"]                       # Funktionen Creme wie in VS Code
var = lift(t["accentText"], 4.5)     # $VAR, @attr: sparsamer Glut-Akzent
selection = t.get("accentFill", over(t["accentSoft"], bg))


def style(color, **flags):
    s = {"text-color": color}
    s.update({k: True for k, on in flags.items() if on})
    return s


styles = {
    "Normal": {**style(ed["text"]), "selected-text-color": t["text"]},
    "Keyword": style(ed["keyword"]),
    "Function": style(fn),
    "Variable": style(var),
    "ControlFlow": style(ed["keyword"]),
    "Operator": style(ed["punctuation"]),
    "BuiltIn": style(fn),
    "Extension": style(ed["type"]),
    "Preprocessor": style(ed["keyword"]),
    "Attribute": style(ed["type"], italic=True),
    "Char": style(ed["string"]),
    "SpecialChar": style(ed["number"]),
    "String": style(ed["string"]),
    "VerbatimString": style(ed["string"]),
    "SpecialString": style(regex),
    "Import": style(ed["keyword"]),
    "DataType": style(ed["type"]),
    "DecVal": style(ed["number"]),
    "BaseN": style(ed["number"]),
    "Float": style(ed["number"]),
    "Constant": style(ed["number"]),
    "Comment": style(ed["comment"], italic=True),
    "Documentation": style(ed["comment"], italic=True),
    "Annotation": style(ed["type"], italic=True),
    "CommentVar": style(var, italic=True),
    "RegionMarker": {**style(lift(t["woodLight"], 4.5)), "background-color": t["surface"]},
    "Information": style(lift(t["success"], 4.5)),
    "Warning": style(lift(t["warning"], 4.5)),
    "Alert": {**style(lift(t["error"], 4.5), bold=True), "background-color": selection},
    "Error": style(ed["error"], underline=True),
    "Others": style(lift(t["success"], 4.5)),
}

# Wie die Generatoren für Kitty/VS Code: lieber abbrechen als unleserlich ausliefern
weak = [f"{k} {s['text-color']} ({contrast(s['text-color'], bg):.2f})" for k, s in styles.items()
        if contrast(s["text-color"], bg) < 4.5]
if weak:
    sys.exit("Abbruch, Kontrast < 4,5 : 1 auf " + bg + ": " + ", ".join(weak))

guide = mix(bg, t["text"], 0.12)
editor = {
    "BackgroundColor": bg,
    "CodeFolding": mix(bg, t["woodLight"], 0.25),
    "BracketMatching": mix(bg, t["woodLight"], 0.35),
    "CurrentLine": mix(bg, t["text"], 0.04),
    "IconBorder": bg,
    "IndentationLine": guide,
    "LineNumbers": ed["lineNumber"],
    "CurrentLineNumber": t["text"],
    "MarkBookmark": t["woodLight"],
    "MarkBreakpointActive": t["error"],
    "MarkBreakpointReached": t["warning"],
    "MarkBreakpointDisabled": t["textFaint"],
    "MarkExecution": t["textMuted"],
    "MarkWarning": t["warning"],
    "MarkError": t["error"],
    "ModifiedLines": t["warning"],
    "ReplaceHighlight": mix(bg, t["success"], 0.30),
    "SavedLines": t["success"],
    "SearchHighlight": over(t.get("warningSoft", t["accentSoft"]), bg),
    "TextSelection": selection,
    "Separator": t.get("surfaceRaised", t["surface"]),
    "SpellChecking": t["error"],
    "TabMarker": guide,
    "TemplateBackground": t["surface"],
    "TemplatePlaceholder": mix(bg, t["woodLight"], 0.30),
    "TemplateFocusedPlaceholder": mix(bg, t["accent"], 0.35),
    "TemplateReadOnlyPlaceholder": mix(bg, t["textFaint"], 0.20),
    "WordWrapMarker": guide,
}

theme = {
    "metadata": {
        "name": THEME,
        "revision": 1,
        "license": "GPL-3.0",
        "author": "desktop (bastian-shell)",
        "read-only": True,
        "generator": f"{MARK} ({variant}) – theme/gen/ktexteditor.py, nicht von Hand ändern",
    },
    "text-styles": styles,
    "editor-colors": editor,
    "custom-styles": {},
}

print(f"KTextEditor ({variant}):")
out = OUT / "ktexteditor/desktop.theme"
write(out, json.dumps(theme, indent=2, ensure_ascii=False) + "\n")
if install_wanted():
    install(out, HOME / ".local/share/org.kde.syntax-highlighting/themes/desktop.theme")
