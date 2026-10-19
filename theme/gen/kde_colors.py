#!/usr/bin/env python3
"""theme/palette.json -> KDE-Farbschema (theme/out/kde/*.colors), aktiviert nichts.

Variante hearth (deckend, freundlich) -> "Desktop Hearth" (DesktopHearth.colors): mittelbraune Fenster,
dunklere Inhaltsflächen, Terrakotta-Auswahl mit Creme-Text, Statusfarben aus der Palette.
Alle anderen Varianten (Glas-Look, ember & Co.) -> "Desktop" (Desktop.colors) wie bisher; das alte
"Desktop" bleibt so als Rückweg unangetastet, solange nur hearth erzeugt wird.
Installiert nach ~/.local/share/color-schemes/. Aufbau wie /usr/share/color-schemes/BreezeDark.colors.
Aufruf aus dem Repo-Root:
  python3 -I theme/gen/kde_colors.py [variante] [--nur-out]
Setzen: plasma-apply-colorscheme DesktopHearth (Rückweg: plasma-apply-colorscheme Desktop).
"""
import pathlib
import sys

sys.path.insert(0, str(pathlib.Path(__file__).resolve().parent))
from _pal import HOME, MARK, OUT, contrast, install, install_wanted, kde, load, mix, write  # noqa: E402

src, variant, t = load()
ansi = src["ansi"]

HEARTH = "surfaceRaised" in t  # neue deckende Palette (hearth)
SCHEME = "DesktopHearth" if variant == "hearth" else "Desktop"
SCHEME_NAME = "Desktop Hearth" if variant == "hearth" else "Desktop"

if HEARTH:
    # Fenster = surface (mittelbraun), Inhalt (Listen, Felder, Dolphin-Dateiliste) = bg (eine Stufe tiefer),
    # Knöpfe/Tooltips = surfaceRaised (eine Stufe heller), Kopfzeilen = surface. Kein Blau, kein Glas.
    window = t["surface"]
    view = t["bg"]
    header = t["surfaceRaised"]
    header_inactive = t["surface"]
    button = t["surfaceRaised"]
    tooltip = t["surfaceRaised"]
    complementary = t["bgBottom"]
    window_alt = mix(t["surface"], t["text"], 0.035)
    view_alt = mix(t["bg"], t["text"], 0.04)
    button_alt = t["accentFill"]
    # Auswahl: Terrakotta, so weit Richtung Fläche gedunkelt, dass Creme darauf >= 5,6 hat.
    _sel_t = 0.0
    selection = t["accent"]
    while contrast(t["text"], selection) < 5.6 and _sel_t < 0.9:
        _sel_t += 0.02
        selection = mix(t["accent"], t["bgBottom"], _sel_t)
    selection_alt = mix(selection, t["bgBottom"], 0.25)
    title_active = header
    title_inactive = t["surface"]
else:
    # Glas-Varianten (ember & Co.): dunkler Rahmen, Eigener Kontrast gegenüber Shell-Glas und Terminal.
    window = t["surface"]
    view = t["bg"]
    header = mix(t["bg"], t["bgBottom"], 0.3)
    header_inactive = t["bgBottom"]
    button = mix(t["surface"], t["text"], 0.07)
    tooltip = t["surface"]
    complementary = t["bgBottom"]
    window_alt = mix(t["surface"], t["text"], 0.04)
    view_alt = mix(t["bg"], t["text"], 0.03)
    button_alt = t["wood"]
    # Auswahl: Glut abgedunkelt, damit Creme darauf lesbar bleibt (>= 4.5).
    selection = mix(t["accent"], t["surface"], 0.32)
    _sel_t = 0.32
    while contrast(t["text"], selection) < 4.5 and _sel_t < 0.9:
        _sel_t += 0.04
        selection = mix(t["accent"], t["surface"], _sel_t)
    selection_alt = mix(t["accent"], t["surface"], 0.55)
    title_active = header
    title_inactive = t["bgBottom"]


def group(bg: str, alt: str, fg=None, **extra):
    """Ein [Colors:*]-Block. fg überschreibt einzelne Vordergrund-Rollen."""
    keys = {
        "BackgroundAlternate": alt,
        "BackgroundNormal": bg,
        "DecorationFocus": t["accent"],
        "DecorationHover": t["woodLight"],
        "ForegroundActive": t["accentText"],
        "ForegroundInactive": t["textMuted"],
        "ForegroundLink": t["accentText"],
        "ForegroundNegative": NEG,
        "ForegroundNeutral": t["warning"],
        "ForegroundNormal": t["text"],
        "ForegroundPositive": t["success"],
        "ForegroundVisited": ansi["magenta"],
    }
    keys.update(fg or {})
    keys.update(extra)
    return "\n".join(f"{k}={kde(v)}" for k, v in sorted(keys.items()))


# Auf der Auswahl: Statusfarben Richtung Creme ziehen, sonst verschwinden sie im Rot.
on_sel = {
    "ForegroundActive": t["text"],
    "ForegroundInactive": mix(t["text"], selection, 0.1),
    "ForegroundLink": t["text"],
    "ForegroundNegative": mix(t["error"], t["text"], 0.7),
    "ForegroundNeutral": mix(t["warning"], t["text"], 0.55),
    "ForegroundPositive": mix(t["success"], t["text"], 0.55),
    "ForegroundVisited": mix(ansi["magenta"], t["text"], 0.55),
}
# Fehlerrot auf den braunen Flächen: leicht Richtung Creme, damit es >= 4.5 hat (Basis-Gruppe).
_neg = t["error"]
_neg_t = 0.0
while contrast(_neg, window) < 4.5 and _neg_t < 0.6:
    _neg_t += 0.04
    _neg = mix(t["error"], t["text"], _neg_t)
NEG = _neg

sections = {
    "ColorEffects:Disabled": "\n".join([
        f"Color={kde(t['surface'])}",
        "ColorAmount=0",
        "ColorEffect=0",
        "ContrastAmount=0.65",
        "ContrastEffect=1",
        "IntensityAmount=0.1",
        "IntensityEffect=2",
    ]),
    # Inaktive Fenster bleiben wie Breeze unverändert (Enable=false), nur die Farbe passt.
    "ColorEffects:Inactive": "\n".join([
        "ChangeSelectionColor=true",
        f"Color={kde(t['bgBottom'])}",
        "ColorAmount=0.025",
        "ColorEffect=2",
        "ContrastAmount=0.1",
        "ContrastEffect=2",
        "Enable=false",
        "IntensityAmount=0",
        "IntensityEffect=0",
    ]),
    "Colors:Button": group(button, button_alt),
    "Colors:Complementary": group(complementary, t["bg"]),
    "Colors:Header": group(header, window),
    "Colors:Header][Inactive": group(header_inactive, header, {"ForegroundNormal": t["textMuted"]}),
    "Colors:Selection": group(selection, selection_alt, on_sel),
    "Colors:Tooltip": group(tooltip, view),
    "Colors:View": group(view, view_alt),
    "Colors:Window": group(window, window_alt),
    "General": "\n".join([
        f"ColorScheme={SCHEME}",
        f"Name={SCHEME_NAME}",
        "shadeSortColumn=true",
    ]),
    "KDE": "contrast=4",
    # Titelleisten (KWin-Deko): aktiv = Kopfzeilen-Ton, inaktiv dunkler und leiser.
    "WM": "\n".join([
        f"activeBackground={kde(title_active)}",
        f"activeBlend={kde(t['text'])}",
        f"activeForeground={kde(t['text'])}",
        f"inactiveBackground={kde(title_inactive)}",
        f"inactiveBlend={kde(t['textFaint'])}",
        f"inactiveForeground={kde(t['textFaint'])}",
    ]),
}

text = (
    f"# {MARK} ({variant}) – nicht von Hand ändern.\n"
    "# Neu erzeugen: python3 -I theme/gen/kde_colors.py\n\n"
    + "\n\n".join(f"[{name}]\n{body}" for name, body in sections.items())
    + "\n"
)

print(f"KDE-Farbschema ({variant}):")
out = OUT / f"kde/{SCHEME}.colors"
write(out, text)
if install_wanted():
    install(out, HOME / f".local/share/color-schemes/{SCHEME}.colors")

# Kontrast-Nachweis (WCAG, >= 4.5 für Text)
for name, fg, bg in [
    ("Text/Fenster", t["text"], window),
    ("Text/Inhalt", t["text"], view),
    ("Inaktiv/Fenster", t["textMuted"], window),
    ("Text/Auswahl", t["text"], selection),
    ("Text/Knopf", t["text"], button),
    ("Link/Inhalt", t["accentText"], view),
    ("Titel inaktiv", t["textFaint"], title_inactive),
    ("Gedämpft/Inhalt", t["textMuted"], view),
    ("Link/Fenster", t["accentText"], window),
    ("Text/Kopfzeile", t["text"], header),
    ("Text/Tooltip", t["text"], tooltip),
    ("Gedämpft/Auswahl", on_sel["ForegroundInactive"], selection),
    ("Link/Auswahl", on_sel["ForegroundLink"], selection),
    ("Fehler/Fenster", NEG, window),
    ("Erfolg/Fenster", t["success"], window),
]:
    print(f"  Kontrast {name}: {contrast(fg, bg):.1f}")
