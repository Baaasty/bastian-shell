"""Terminal-Farben aus der aktiven Variante (gemeinsam für Kitty und Konsole).

Deckende Varianten (blur=false, z. B. hearth): Hintergrund = bgBottom (eine Stufe tiefer als die Fenster),
die 16 ANSI-Farben bleiben warm und gedämpft, werden aber so weit aufgehellt, dass jede (außer Schwarz)
mindestens 4,5:1 Kontrast zum Hintergrund hat. Glas-Varianten (ember & Co.) behalten ansi.background.
"""
from _pal import contrast, mix, over

NAMES = ["black", "red", "green", "yellow", "blue", "magenta", "cyan", "white"]
MIN = 4.5


def _lift(c: str, bg: str, toward: str, minimum: float = MIN) -> str:
    """Farbe in kleinen Schritten Richtung `toward` ziehen, bis der Kontrast reicht (Farbton bleibt nah)."""
    for i in range(0, 101):
        out = mix(c, toward, i / 100)
        if contrast(out, bg) >= minimum:
            return out
    return toward


def colors(src: dict, t: dict) -> dict:
    ansi = src["ansi"]
    solid = not t.get("blur", src.get("style", {}).get("blur", False))
    bg = t["bgBottom"] if solid else ansi["background"]
    fg = t["text"] if solid else ansi["foreground"]
    out = {"bg": bg, "fg": fg, "solid": solid}
    if not solid:
        out.update({k: ansi[k] for k in ansi if k not in ("background", "foreground")})
        out["cursor"] = ansi["cursor"]
        out["selBg"] = over(ansi["selectionBackground"], bg)
        out["selFg"] = fg
        out["cursorText"] = bg
        return out
    for n in NAMES:
        out[n] = ansi[n]
        out["bright" + n.capitalize()] = ansi["bright" + n.capitalize()]
    # Schwarz: sichtbarer Block auf dem Hintergrund (nicht als Text gedacht)
    out["black"] = mix(bg, t["wood"], 0.55)
    # Hellgrau-Familie aus den Textstufen der Variante
    out["white"] = t["textMuted"]
    out["brightWhite"] = t["text"]
    out["brightBlack"] = t["textFaint"]  # Kommentare, Autosuggestion: lesbar, aber leise
    for k in out:
        if k in ("bg", "fg", "solid", "black"):
            continue
        out[k] = _lift(out[k], bg, t["text"])
    out["cursor"] = t["accent"]
    out["cursorText"] = t["onAccent"]
    out["selBg"] = t["accentFill"]
    out["selFg"] = t["text"]
    return out
