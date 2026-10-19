#!/usr/bin/env python3
"""theme/palette.json -> hyprtoolkit.conf (Look der Hyprland-eigenen Dialoge).

hyprtoolkit zeichnet hyprland-guiutils: „App reagiert nicht“ (ANR, misc:enable_anr_dialog), hyprland-dialog
(z. B. Berechtigungsfragen, falls ecosystem:enforce_permissions mal an ist), Update-/Spenden-/Willkommens-Bildschirm,
hyprland-run. Ohne Datei: Standard-Look (Grau/Türkis). Mit Datei: deckend wie die Shell –
Fenster = surface, Knöpfe/Felder = surfaceRaised, Wechsel-Ton = surfaceSunken, Akzent = Terrakotta, Inter, weiche Ecken.
Schlüssel geprüft an libhyprtoolkit 0.6 (strings): background, base, text, alternate_base, bright_text, link_text,
accent, accent_secondary, rounding_large/small, h1–h3_size, font_size, small_font_size, icon_theme, font_family(_monospace).
Hyprtoolkit liest die Datei bei jedem Start eines Dialogs neu (laufende Dialoge bleiben, wie sie sind).

Ausgabe: theme/out/hyprtoolkit.conf; ohne --nur-out zusätzlich Symlink ~/.config/hypr/hyprtoolkit.conf -> Ausgabe
(eine fremde Datei dort wird nie überschrieben). Rückweg: rm ~/.config/hypr/hyprtoolkit.conf
Aufruf aus dem Repo-Root: python3 -I theme/gen/hyprtoolkit.py [variante] [--nur-out]
"""
import os
import pathlib
import sys

sys.path.insert(0, str(pathlib.Path(__file__).resolve().parent))
from _pal import HOME, MARK, OUT, install_wanted, load, over, rgba, write  # noqa: E402

src, variant, t = load()
R = src.get("radius", {})
ui = src.get("type", {}).get("ui", {})
mono = src.get("type", {}).get("mono", {})


def hl(value: str, base: str | None = None) -> str:
    """Palette-Farbe -> hyprlang rgba(RRGGBBAA), deckend (Alpha auf base gerechnet)."""
    if base is not None:
        value = over(value, base)
    r, g, b, _ = rgba(value)
    return "rgba({:02X}{:02X}{:02X}FF)".format(r, g, b)


surface = over(t["surface"], t["bg"])
raised = over(t.get("surfaceRaised", t["surface"]), t["bg"])
sunken = over(t.get("surfaceSunken", t["bg"]), t["bg"])

text = f"""# {MARK} ({variant}) – nicht von Hand ändern.
# Neu erzeugen: python3 -I theme/gen/hyprtoolkit.py [variante]   ·   Rückweg: rm ~/.config/hypr/hyprtoolkit.conf
# Look der Hyprland-Dialoge (hyprland-guiutils: „App reagiert nicht“, hyprland-dialog, Update-/Willkommens-Bildschirm)

background = {hl(surface)}
base = {hl(raised)}
alternate_base = {hl(sunken)}
text = {hl(t["text"])}
bright_text = {hl(t["text"])}
link_text = {hl(t["accentText"])}
accent = {hl(t["accent"])}
accent_secondary = {hl(t.get("woodLight", t["accentText"]))}

rounding_large = {int(R.get("md", 14))}
rounding_small = {int(R.get("sm", 10))}

font_family = {ui.get("family", "Inter")}
font_family_monospace = {mono.get("family", "JetBrainsMono Nerd Font")}
h1_size = 19
h2_size = 15
h3_size = 13
font_size = 11
small_font_size = 10
icon_theme = Desktop-Icons
"""

out = OUT / "hyprtoolkit.conf"
write(out, text)

if install_wanted():
    conf = pathlib.Path(os.environ.get("XDG_CONFIG_HOME") or HOME / ".config")
    dst = conf / "hypr/hyprtoolkit.conf"
    if dst.is_symlink():
        if dst.resolve() != out.resolve():
            sys.exit(f"Abbruch: {dst} zeigt woanders hin ({os.readlink(dst)}).")
    elif dst.exists():
        if MARK not in dst.read_text(errors="ignore"):
            sys.exit(f"Abbruch: {dst} existiert und stammt nicht von hier.")
        dst.unlink()
    if not dst.is_symlink():
        dst.parent.mkdir(parents=True, exist_ok=True)
        dst.symlink_to(out)
    print(f"  -> {dst}")
