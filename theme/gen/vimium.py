#!/usr/bin/env python3
"""theme/palette.json -> Vimium C (Helium) im Desktop-Look + empfohlene Tasten.

  theme/out/vimium/vimium-c-desktop.json   Import-Datei für Vimium C (Optionen -> "Import settings"):
                                           Theme (Custom CSS), Tasten (keyMappings), Hinweis-Buchstaben
  theme/out/vimium/vimium-c.css            dasselbe CSS zum Einfügen in "Custom CSS for Vimium C UI"
  theme/out/vimium/keymappings.txt         dieselben Tasten zum Einfügen in "Custom key mappings"

Gestylt (Abschnitte wie in Vimium C: /* #ui */ Hinweise + HUD, /* #omni */ Vomnibar, /* #find */ Suchleiste):
Hint-Marker als deckende Holz-Kappen mit Glut-Rand, HUD unten rechts als Kachel, Vomnibar als Desktop-Panel.
Größen der Vomnibar bleiben Vimium-Standard (sonst müsste vomnibarOptions.sizes mitwandern).
Tasten: Vimium-Standard, die üblichen ausdrücklich gemappt (f, F, j/k, H/L, J/K, o/O, /) – nichts Exotisches.
Wird nicht installiert (Vimium C speichert im Browser-Profil): Import per Klick, siehe docs/knowledge/theming.md „Vimium C“.
Aufruf aus dem Repo-Root: python3 -I theme/gen/vimium.py [variante]
"""
import json
import pathlib
import sys

sys.path.insert(0, str(pathlib.Path(__file__).resolve().parent))
from _pal import MARK, OUT, load, mix, over, write  # noqa: E402

src, variant, t = load()
ui = f'"{src["type"]["ui"]["family"]}", {src["type"]["ui"]["fallback"]}'
mono = f'"{src["type"]["mono"]["family"]}", {src["type"]["mono"]["fallback"]}'
surface, raised, sunken = t["surface"], t["surfaceRaised"], t["surfaceSunken"]
line = over(t["border"], surface)            # Hairline, deckend
line_strong = over(t["borderStrong"], surface)
sel = t["accentFill"]
hover = mix(surface, raised, 0.6)
shadow = t["shadow"]

css = f"""/* {MARK} ({variant}) – nicht von Hand ändern. Neu erzeugen: python3 -I theme/gen/vimium.py */
/* #ui */
.LH, .D>.LH {{
  background: {raised} !important; color: {t['text']} !important;
  border: 1px solid {t['accent']} !important; border-radius: 6px !important;
  box-shadow: 0 2px 5px {shadow} !important;
  font: 600 12px/1 {mono} !important; padding: 3px 4px 2px !important;
}}
.MC, .MH, .D>.LH .MC {{ color: {t['accentText']} !important; }}
.BH {{ color: {t['warning']} !important; }}
.One {{ border-color: {t['warning']} !important; }}
.IH {{ background: {t['accentSoft']} !important; border: 1px solid {t['accent']} !important; border-radius: 4px; }}
.IHS {{ background: {t['warningSoft']} !important; border-color: {t['warning']} !important; }}
.HUD, .HUD.D {{ color: {t['text']} !important; font: 500 13px/16px {ui} !important; }}
.HUD:after, .HUD.D:after {{
  background: {surface} !important; border: 1px solid {line_strong} !important; border-radius: 8px 8px 0 0 !important;
}}
.Flash {{ box-shadow: 0 0 0 2px {t['accent']} !important; border-radius: 4px; }}
.Sel {{ box-shadow: 0 0 0 2px {t['warning']} !important; }}
.Frame {{ border-color: {t['accent']} !important; }}
/* #find */
.r, .r.D {{
  background: {surface} !important; color: {t['text']} !important;
  box-shadow: inset 0 0 0 1px {line_strong} !important; border-radius: 8px 8px 0 0 !important;
}}
* {{ font-family: {ui} !important; }}
/* #find:selection */
::selection {{ background: {t['accent']} !important; color: {t['onAccent']} !important; }}
/* #omni */
body {{ background: {surface} !important; border-radius: 14px !important; box-shadow: 0 10px 28px {shadow} !important; }}
body::after {{ border: 1px solid {line_strong} !important; border-radius: 14px !important; }}
#bar, .has-dark>#bar {{ background: {raised} !important; border-bottom: 1px solid {line} !important; border-radius: 14px 14px 0 0 !important; }}
#bar.empty {{ border-radius: 14px !important; border: none !important; }}
#input {{
  background: {sunken} !important; color: {t['text']} !important; caret-color: {t['accent']};
  border: 1px solid {t['accent']} !important; border-radius: 10px !important; box-shadow: none !important;
  font-family: {ui} !important;
}}
#input::selection {{ background: {t['accentSoft']}; }}
#list {{ background: {surface} !important; border-radius: 0 0 14px 14px !important; }}
#toolbar {{ color: {t['textFaint']} !important; }}
.button:hover {{ background: {hover} !important; color: {t['text']} !important; border-radius: 6px; }}
.item {{ border-bottom: 1px solid {line} !important; }}
.b {{ border-radius: 0 0 14px 14px !important; }}
.item:hover {{ background-color: {hover} !important; }}
.item.s, .item.s:hover {{ background-color: {sel} !important; }}
.p {{ border-color: {line} !important; }}
.top {{ color: {t['text']} !important; font-family: {ui} !important; }}
match {{ color: {t['accentText']} !important; font-weight: 600; }}
.s .top, .s match {{ color: {t['text']} !important; }}
a {{ color: {t['textMuted']} !important; }}
.mono-url a {{ font-family: {mono} !important; font-size: 13px; }}
.label, .time {{ color: {t['textFaint']} !important; }}
.icon {{ --vc-c: {t['textFaint']}; }}
.s .icon {{ --vc-c: {t['accentText']}; }}
.alt .alt-index::after {{ background: {raised} !important; color: {t['text']} !important; }}
"""

# Vimium-Standard bleibt; die gängigen Tasten stehen trotzdem ausdrücklich da (zum Nachschlagen, Super+K zeigt sie auch).
keys = """# Vimium C – Desktop-Empfehlung (theme/gen/vimium.py). Alles Vimium-Standard, nur ausdrücklich aufgeschrieben.
# Links
map f LinkHints.activate
map F LinkHints.activateOpenInNewTab
map yf LinkHints.activateCopyLinkUrl
# Scrollen
map j scrollDown
map k scrollUp
map d scrollPageDown
map u scrollPageUp
map gg scrollToTop
map G scrollToBottom
# Verlauf und Tabs
map H goBack
map L goForward
map J previousTab
map K nextTab
map x removeTab
map X restoreTab
map t createTab
# Öffnen (Vomnibar)
map o Vomnibar.activate
map O Vomnibar.activateInNewTab
map b Vomnibar.activateBookmarks
map T Vomnibar.activateTabs
# Suchen auf der Seite
map / enterFindMode
map n performFind
map N performBackwardsFind
# Sonstiges
map yy copyCurrentUrl
map gi focusInput
map i enterInsertMode
map r reload
map ? showHelp
"""

settings = {
    "name": "Vimium C",
    "author": "desktop (theme/gen/vimium.py)",
    "description": f"{MARK} ({variant}): Desktop-Look + empfohlene Tasten",
    "keyMappings": keys.splitlines() + [""],
    "userDefinedCss": css.splitlines() + [""],
}

print(f"Vimium C ({variant}):")
d = OUT / "vimium"
write(d / "vimium-c.css", css)
write(d / "keymappings.txt", keys)
write(d / "vimium-c-desktop.json", json.dumps(settings, indent="\t", ensure_ascii=False) + "\n")
