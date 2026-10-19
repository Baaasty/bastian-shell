#!/usr/bin/env python3
"""theme/palette.json -> Stylesheet für hyprland-preview-share-picker (Bildschirm-teilen-Auswahl, AP 16).

Deckende, freundliche Flächen (kein Glas/Blur: der Picker ist ein GTK-Layer-Shell-Fenster ohne Hintergrund-Effekt),
Inter, weiche Ecken, Auswahl klar im Ember-Akzent, Vorschaubilder mit Rahmen. Die Klassennamen sind die Standardnamen
des Pickers (config.yaml `classes`), die Knotennamen die von GtkNotebook/GtkFlowBox/GtkButton.
Ausgabe: theme/out/share-picker.css (scripts/share-picker install verlinkt sie nach
~/.config/hyprland-preview-share-picker/style.css; der Picker liest sie bei jedem Start neu).
Aufruf aus dem Repo-Root: python3 -I theme/gen/share_picker.py [variante] [--nur-out]
"""
import pathlib
import sys

sys.path.insert(0, str(pathlib.Path(__file__).resolve().parent))
from _pal import MARK, OUT, contrast, load, mix, over, write  # noqa: E402

src, variant, t = load()
R = src.get("radius", {})
ui = src.get("type", {}).get("ui", {})
FAMILY = f'"{ui.get("family", "Inter")}", system-ui, sans-serif'

# Opake Flächen: Fenster = bg, Karten = surface (etwas heller/anders als bg), Rand = Palette-Rand auf surface
bg = t["bg"]
surface = t["surface"]
card = mix(surface, t["text"], 0.04)          # Karte hebt sich leicht vom Fenster ab
card_hover = mix(surface, t["text"], 0.09)
line = over(t["border"], surface)
line_strong = over(t["borderStrong"], surface)
accent = t["accent"]
accent_text = t["accentText"]
accent_fill = over(t["accentSoft"], surface)  # ausgewählte Karte: leicht getönt
text, muted, faint = t["text"], t["textMuted"], t["textFaint"]
# Text auf dem Akzent-Knopf: das, was mehr Kontrast hat (Cremetext oder dunkler Grund)
on_accent = text if contrast(text, accent) >= contrast(bg, accent) else bg
radius_card = R.get("md", 12)
radius_img = R.get("sm", 8)
radius_win = R.get("window", 14)

css = f"""/* {MARK} (theme/gen/share_picker.py, Variante {variant}) – nicht von Hand ändern. */
* {{
  all: unset;
  font-family: {FAMILY};
  font-size: 13px;
  font-weight: 500;
  color: {text};
}}

/* Fenster: deckend, weiche Ecken, feiner Rand */
.window {{
  background-color: {bg};
  border: 1px solid {line_strong};
  border-radius: {radius_win}px;
}}

/* Reiter (Windows / Outputs / Region) als Pillen */
notebook > header {{
  padding: 16px 20px 4px 20px;
}}
tabs {{
  padding: 0;
}}
tabs > tab {{
  padding: 7px 16px;
  margin-right: 8px;
  border-radius: 999px;
  border: 1px solid transparent;
  transition: background-color 120ms ease, border-color 120ms ease;
}}
tabs > tab:hover {{
  background-color: {card};
}}
tabs > tab:checked {{
  background-color: {accent_fill};
  border-color: {accent};
}}
.tab-label {{
  color: {muted};
  font-weight: 600;
}}
tabs > tab:checked > .tab-label {{
  color: {accent_text};
}}
tabs > tab:focus-visible {{
  border-color: {line_strong};
}}

.page {{
  padding: 14px 20px 8px 20px;
}}

/* Fenster-Karten (Windows-Reiter): Vorschaubild im echten Verhältnis (Contain) auf ruhigem Grund + Titel */
flowboxchild > .card {{
  background-color: {card};
  border: 2px solid {line};
  border-radius: {radius_card}px;
  padding: 8px;
  transition: background-color 120ms ease, border-color 120ms ease;
}}
flowboxchild:hover > .card {{
  background-color: {card_hover};
  border-color: {line_strong};
}}
flowboxchild:selected > .card,
flowboxchild:active > .card,
flowboxchild:focus > .card {{
  background-color: {accent_fill};
  border-color: {accent};
}}
flowboxchild .image {{
  border-radius: {radius_img}px;
  border: 1px solid {line_strong};
  background-color: {bg};
}}
flowboxchild .image-label {{
  color: {muted};
  font-size: 12px;
  padding: 8px 4px 2px 4px;
}}
flowboxchild:selected .image-label {{
  color: {text};
}}

/* Monitor-Karten (Outputs-Reiter): Der Picker streckt das Bild auf die ganze Karte (ContentFit::Fill) und gibt der
   Karte genau die Monitorgröße im Verhältnis. Damit nichts verzerrt: KEIN Innenabstand, KEIN Rand, KEIN Titel im
   Kartenkörper (config: show_label: false, spacing: 0). Rahmen nur als Schatten (braucht keinen Platz im Layout). */
button > .card {{
  padding: 0;
  border: none;
  border-radius: {radius_img}px;
  background-color: transparent;
  box-shadow: 0 0 0 0 transparent;
  transition: box-shadow 120ms ease;
}}
button > .card > .image {{
  border: none;
  padding: 0;
  border-radius: {radius_img}px;
  background-color: {card};
}}
button:hover > .card {{
  box-shadow: 0 0 0 3px {line_strong};
}}
button:active > .card,
button:focus > .card {{
  box-shadow: 0 0 0 3px {accent};
}}
.card-loading {{
  opacity: 0.6;
}}

/* Region-Knopf: Akzent, gut lesbar */
.region-button {{
  background-color: {accent};
  color: {on_accent};
  font-weight: 600;
  padding: 10px 22px;
  border-radius: 999px;
  transition: background-color 120ms ease;
}}
.region-button:not(:disabled):hover,
.region-button:not(:disabled):focus {{
  background-color: {mix(accent, text, 0.18)};
}}
.region-button:disabled {{
  background-color: {card};
  color: {faint};
}}

/* Haken „Allow a restore token“ (nur sichtbar, wenn hide_token_restore: false) */
.restore-button {{
  padding: 8px 22px 16px 22px;
  color: {muted};
}}
.restore-button check {{
  min-width: 16px;
  min-height: 16px;
  margin-right: 8px;
  border: 1px solid {line_strong};
  border-radius: {R.get("xs", 6)}px;
  background-color: {card};
}}
.restore-button check:checked {{
  background-color: {accent};
  border-color: {accent};
  color: {on_accent};
  -gtk-icon-source: -gtk-icontheme("object-select-symbolic");
}}

/* Scrollbalken: dünn, nur beim Hovern deutlich */
scrollbar {{
  background: transparent;
}}
scrollbar slider {{
  min-width: 6px;
  min-height: 6px;
  margin: 2px;
  border-radius: 999px;
  background-color: {line_strong};
}}
scrollbar slider:hover {{
  background-color: {faint};
}}
"""
write(OUT / "share-picker.css", css)
