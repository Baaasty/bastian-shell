#!/usr/bin/env python3
"""theme/palette.json -> Hyprland-Look (hypr/look.conf).

Fenster-Rahmen: aktiv = Akzent (klar sichtbar, 2 px), inaktiv = ruhiges Holzbraun. Rundung wie die Fenster (radius.window),
Schatten aus shadow (ruhig, kein Leuchten), Animationen kurz aus motion.
Blur nur, wenn die Variante blur=true hat (palette.json; hearth = aus, ember & Co. = an). Der Compositor-Blur ist damit
zentral abgeschaltet: BackgroundEffect.blurRegion in den Shell-Modulen bleibt harmlos (ohne Blur wird nichts gezeichnet). Bewusst sparsam (360 Hz, NVIDIA): 2 Blur-Pässe, keine Dauer-Animationen
(borderangle aus), Layer-Animationen aus (die Shell animiert selbst).
Hyprland lädt die Datei bei Änderung selbst neu -> rice variant wirkt sofort.
Aufruf aus dem Repo-Root: python3 -I theme/gen/hypr.py [variante]
"""
import pathlib
import re
import sys

sys.path.insert(0, str(pathlib.Path(__file__).resolve().parent))
from _pal import MARK, ROOT, load, over, rgba, write  # noqa: E402

src, variant, t = load()
radius = src.get("radius", {})
layout = src.get("layout", {})
glass = src.get("glass", {})
motion = src.get("motion", {})


def hl(value: str, a: float | None = None) -> str:
    """Palette-Farbe -> Hyprland rgba(RRGGBBAA). a überschreibt den Alpha-Wert."""
    r, g, b, alpha = rgba(value)
    alpha = alpha if a is None else a
    return "rgba({:02X}{:02X}{:02X}{:02X})".format(r, g, b, round(alpha * 255))


def shadow(css: str):
    """'0 16px 48px rgba(0, 0, 0, 0.45)' -> (Versatz y, Reichweite, Alpha). Hyprland streut weiter als CSS -> halbieren."""
    m = re.match(r"\s*(-?\d+)(?:px)?\s+(-?\d+)(?:px)?\s+(\d+)(?:px)?\s+(rgba\([^)]*\))", css)
    if not m:
        return 8, 24, 0.45
    _, y, blur, col = m.groups()
    return int(y) // 2, int(blur) // 2, rgba(col)[3]


def speed(ms: int) -> str:
    """Millisekunden -> Hyprland-Geschwindigkeit (Einheit 100 ms)."""
    return f"{ms / 100:g}"


gap = int(layout.get("windowGap", 10))
blur_on = bool(t.get("blur", src.get("style", {}).get("blur", False)))
# deckender Look: Rahmen 2 px, klar aktiv/inaktiv; Glas-Look: Haarlinie
border = 2 if not blur_on else int(glass.get("borderWidth", 1))
rounding = int(radius.get("window", radius.get("lg", 14)))
tile = glass.get("tile", {})
# CSS-Blur 24 px ~ Hyprland size × 2^passes -> 2 Pässe, size 6 (mehr Pässe kosten pro Frame)
passes = 2
blur_size = max(2, round(float(tile.get("blur", 24)) / 2 ** passes))
vibrancy = round(max(0.0, float(tile.get("saturate", 1.15)) - 1), 3)
sh_y, sh_range, sh_alpha = shadow(src.get("shadow", {}).get("tile", ""))
fade = int(motion.get("fade", 150))
slide = int(motion.get("slide", 200))
state = int(motion.get("state", 200))

INACTIVE = t["border"] if blur_on else over(t["borderStrong"], t.get("surfaceRaised", t["surface"]))

text = f"""# {MARK} ({variant}) – nicht von Hand ändern.
# Neu erzeugen: python3 -I theme/gen/hypr.py [variante]   (läuft auch in theme/gen/all.py und scripts/rice variant)

general {{
    border_size = {border}
    gaps_in = {gap // 2}
    gaps_out = {gap}
    # aktiv: Akzent, inaktiv: ruhiger Ton aus der Fläche (Glas-Varianten: Akzent gedämpft + Haarlinie)
    col.active_border = {hl(t["accent"], 0.9 if not blur_on else 0.55)}
    col.inactive_border = {hl(INACTIVE)}
    col.nogroup_border = {hl(INACTIVE)}
    col.nogroup_border_active = {hl(t["accent"], 0.9 if not blur_on else 0.55)}
}}

decoration {{
    rounding = {rounding}
    rounding_power = 2
    active_opacity = 1.0
    inactive_opacity = 1.0
    dim_inactive = false

    # dezent und nur so weit wie nötig (Schatten kosten pro Fenster)
    shadow {{
        enabled = true
        range = {sh_range}
        render_power = 3
        offset = 0 {sh_y}
        color = {hl(t.get("shadow", t["bgBottom"]), sh_alpha)}
        color_inactive = {hl(t.get("shadow", t["bgBottom"]), round(sh_alpha * 0.6, 3))}
    }}

    # Blur nur bei Varianten mit blur=true (hearth: aus, alles deckend). Wenige Pässe, kein Rauschen-Schnickschnack.
    blur {{
        enabled = {'true' if blur_on else 'false'}
        size = {blur_size}
        passes = {passes}
        new_optimizations = true
        xray = false
        noise = 0.01
        contrast = 1.0
        brightness = 1.0
        vibrancy = {vibrancy}
        vibrancy_darkness = 0.0
        special = false
        popups = false
        input_methods = false
    }}
}}

misc {{
    background_color = {hl(t["bg"], 1.0)}
}}

# Kurz und ruhig: OutCubic wie motion.easing, keine Feder, kein Nachschwingen, nichts läuft dauerhaft
animations {{
    enabled = true
}}
bezier = desktopOut, 0.33, 1, 0.68, 1
animation = global, 1, {speed(state)}, desktopOut
animation = windowsIn, 1, {speed(slide)}, desktopOut, popin 96%
animation = windowsOut, 1, {speed(fade)}, desktopOut, popin 96%
animation = windowsMove, 1, {speed(slide)}, desktopOut
animation = fade, 1, {speed(fade)}, desktopOut
animation = border, 1, {speed(state)}, desktopOut
animation = borderangle, 0
animation = workspaces, 1, {speed(slide)}, desktopOut, fade
animation = specialWorkspace, 1, {speed(slide)}, desktopOut, fade
# Layer-Flächen (Bar, Dashboard, OSD …) animiert die Shell selbst – sonst doppelt
animation = layers, 0
animation = fadeLayers, 0
"""

write(ROOT / "hypr/look.conf", text)
