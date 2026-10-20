#!/usr/bin/env python3
"""theme/palette.json -> Kvantum-Theme "DesktopHearth" (theme/out/kvantum/DesktopHearth/), aktiviert nichts.

Warum Kvantum: Breeze nimmt für Menüs immer die Fensterfarbe, kleine Ecken (~5 px) und als Hover die
Auswahlfarbe mit Terrakotta-Rahmen. Echte Theme-Radien, Menü = surfaceRaised und ein ruhiger Hover
(eine Stufe heller statt Akzent-Rahmen) gehen nur mit einem eigenen Qt-Stil – Kvantum zeichnet aus SVG.

Aufbau: Basis ist das Kvantum-Theme KvFlat (dunkel, flach, an Breeze angelehnt; GPL-3.0, Autor Tsu Jan,
liegt nach `sudo dnf install kvantum` unter /usr/share/Kvantum/KvFlat). Alle Grautöne/Blautöne darin werden
auf die Palette umgefärbt (Grau-Rampe bg … text, Blau -> Terrakotta). Menü, Menüeintrag, Menüleisten-Eintrag
und Tooltip werden durch eigene Elemente ersetzt: deckend, Radius sm (10 px), 1-px-Rand, weicher warmer Schatten.
Das erzeugte SVG ist damit ein abgeleitetes Werk von KvFlat (GPL-3.0) – Herkunft steht im Kopf der Dateien.

Aufruf aus dem Repo-Root:
  python3 -I theme/gen/kvantum.py [variante] [--base=DIR]
    --base=DIR   Ordner mit KvFlat.svg/KvFlat.kvconfig (Standard /usr/share/Kvantum/KvFlat)
Einschalten (mit Rückweg): scripts/kvantum-theme on | off | status
"""
import colorsys
import pathlib
import re
import sys

sys.path.insert(0, str(pathlib.Path(__file__).resolve().parent))
from _pal import MARK, OUT, contrast, load, mix, over, rgba, write  # noqa: E402

src, variant, t = load()
NAME = "DesktopHearth" if variant == "hearth" else f"Desktop-{variant}"

base = pathlib.Path("/usr/share/Kvantum/KvFlat")
for _a in sys.argv[1:]:
    if _a.startswith("--base="):
        base = pathlib.Path(_a.split("=", 1)[1])
svg_in, cfg_in = base / "KvFlat.svg", base / "KvFlat.kvconfig"
if not svg_in.is_file() or not cfg_in.is_file():
    sys.exit(f"Abbruch: {svg_in} fehlt – Kvantum ist nicht installiert.\n"
             "  Einmal: sudo dnf install kvantum   (danach diesen Generator erneut starten)")

# ---------------------------------------------------------------- Farben
raised = t.get("surfaceRaised", t["surface"])
border = over(t["borderStrong"], raised)          # Menü-Rand: Creme-Hairline auf der Menüfläche
hover = mix(raised, t["text"], 0.10)              # ruhiger Hover: eine Stufe heller, kein Akzent
pressed = over(t["accentSoft"], raised)           # gedrückt: leichte Terrakotta-Tönung
shadow_rgb = rgba(t["shadow"])[:3]
R = src["radius"]["sm"]                           # 10 px: Menüs, Tooltips
R_ITEM = R - 2                                    # Einträge sitzen innen, etwas kleiner

# Auswahl wie im KDE-Farbschema (kde_colors.py): Terrakotta, abgedunkelt bis Creme >= 5,6 : 1
selection, _s = t["accent"], 0.0
while contrast(t["text"], selection) < 5.6 and _s < 0.9:
    _s += 0.02
    selection = mix(t["accent"], t["bgBottom"], _s)

# Grau-Rampe: Grauwert der Vorlage (0–255) -> Palette-Ton. Dazwischen wird gemischt.
RAMP = [
    (0x00, "#0C0704"),
    (0x17, t["bgBottom"]),
    (0x28, t["bg"]),
    (0x2E, t.get("surfaceSunken", t["bg"])),
    (0x3D, t["surface"]),
    (0x4B, raised),
    (0x55, mix(raised, t["text"], 0.06)),
    (0x64, border),
    (0x7D, mix(raised, t["text"], 0.30)),
    (0xA0, t["textFaint"]),
    (0xD0, t["textMuted"]),
    (0xFF, t["text"]),
]


def from_ramp(v: float) -> str:
    for (a, ca), (b, cb) in zip(RAMP, RAMP[1:]):
        if v <= b:
            return mix(ca, cb, (v - a) / (b - a) if b > a else 0)
    return RAMP[-1][1]


def recolor(hexval: str) -> str:
    r, g, b, _ = rgba("#" + hexval[-6:] if len(hexval) > 4 else "#" + "".join(c * 2 for c in hexval[1:]))
    h, l, s = colorsys.rgb_to_hls(r / 255, g / 255, b / 255)
    if s > 0.25 and l > 0.08:
        hue = h * 360
        if 170 <= hue <= 250:                     # Breeze-/KvFlat-Blau -> Terrakotta nach Helligkeit
            if l < 0.35:
                return mix(t["accent"], t["bgBottom"], 0.45)
            if l < 0.48:
                return t.get("accentPressed", t["accent"])
            if l < 0.62:
                return t["accent"]
            return t.get("accentText", t["accent"])
        return hexval                              # andere bunte Töne (Fehler-Rot usw.) bleiben
    return from_ramp(0.299 * r + 0.587 * g + 0.114 * b)


HEX = re.compile(r"#[0-9a-fA-F]{6}\b|#[0-9a-fA-F]{3}\b")

# ---------------------------------------------------------------- SVG
svg = svg_in.read_text()
svg = HEX.sub(lambda m: recolor(m.group(0)), svg)
# KvFlat-Menüs sind leicht durchsichtig (opacity .92) – die alten Elemente werden umbenannt (unbenutzt),
# unsere deckenden Elemente kommen unten neu dazu.
OWN = re.compile(r'id="((?:menu-normal|menu-shadow|menuitem-(?:normal|focused|pressed|toggled)|'
                 r'menubaritem-(?:normal|focused|pressed|toggled)|tooltip-normal|tooltip-shadow|'
                 r'button-(?:normal|focused|pressed|toggled)|tbutton-(?:focused|pressed|toggled)|'
                 r'lineedit-(?:normal|focused)|focus-normal|'
                 r'progress-(?:normal|pattern-normal))(?:-(?:top|bottom|left|right|topleft|topright|bottomleft|bottomright))?)"')
svg = OWN.sub(lambda m: f'id="kvflat-{m.group(1)}"', svg)
# Fokus-Rahmen von Ansichten (Dolphin, Listen): ruhiges Holz statt Terrakotta – Akzent bleibt sparsam
# recolor() legt Blau auf genau diese vier Glut-Töne
_glut = {mix(t["accent"], t["bgBottom"], 0.45).upper(), t.get("accentPressed", t["accent"]).upper(),
          t["accent"].upper(), t.get("accentText", t["accent"]).upper()}
svg = re.sub(r'(<g\b[^>]*\bid="common-focused(?:-[a-z]+)?"[^>]*>)(.*?)(</g>)',
             lambda m: m.group(1) + HEX.sub(lambda c: t["woodLight"] if c.group(0).upper() in _glut else c.group(0),
                                            m.group(2)) + m.group(3), svg, flags=re.S)

parts: list[str] = []
defs: list[str] = []
SIDES = ["topleft", "top", "topright", "left", "", "right", "bottomleft", "bottom", "bottomright"]


def nine(prefix: str, x0: float, y0: float, f: float, r: float, fill: str, stroke: str | None, sw: float = 1.0):
    """9-Teile-Rahmen (Kvantum): Ecken f×f mit Viertelkreis Radius r (= f), Kanten, Mitte."""
    c = 20.0  # Kantenlänge/Mitte (wird gestreckt)
    cells = {}
    for i, side in enumerate(SIDES):
        cx = x0 + [0, f, f + c][i % 3]
        cy = y0 + [0, f, f + c][i // 3]
        w = [f, c, f][i % 3]
        h = [f, c, f][i // 3]
        cells[side] = (cx, cy, w, h)
    h_ = sw / 2
    paint = "fill:#000;fill-opacity:0;stroke:none" if fill == "transparent" else f"fill:{fill};stroke:none"
    out = []
    for side, (x, y, w, h) in cells.items():
        eid = f"{prefix}-{side}" if side else prefix
        g = [f'<g id="{eid}">']
        if side in ("topleft", "topright", "bottomleft", "bottomright"):
            # Viertelkreis an der äußeren Ecke, Fläche zur Mitte hin
            if side == "topleft":
                d = f"M {x},{y+h} A {f},{f} 0 0 1 {x+w},{y} L {x+w},{y+h} Z"
                a = f"M {x+h_},{y+h} A {f-h_},{f-h_} 0 0 1 {x+w},{y+h_}"
            elif side == "topright":
                d = f"M {x},{y} A {f},{f} 0 0 1 {x+w},{y+h} L {x},{y+h} Z"
                a = f"M {x},{y+h_} A {f-h_},{f-h_} 0 0 1 {x+w-h_},{y+h}"
            elif side == "bottomleft":
                d = f"M {x},{y} A {f},{f} 0 0 0 {x+w},{y+h} L {x+w},{y} Z"
                a = f"M {x+h_},{y} A {f-h_},{f-h_} 0 0 0 {x+w},{y+h-h_}"
            else:
                d = f"M {x+w},{y} A {f},{f} 0 0 1 {x},{y+h} L {x},{y} Z"
                a = f"M {x+w-h_},{y} A {f-h_},{f-h_} 0 0 1 {x},{y+h-h_}"
            g.append(f'<path d="{d}" style="{paint}"/>')
            if stroke:
                g.append(f'<path d="{a}" style="fill:none;stroke:{stroke};stroke-width:{sw}"/>')
        else:
            g.append(f'<rect x="{x}" y="{y}" width="{w}" height="{h}" style="{paint}"/>')
            if stroke and side:
                lx, ly, lw, lh = {"top": (x, y, w, sw), "bottom": (x, y + h - sw, w, sw),
                                  "left": (x, y, sw, h), "right": (x + w - sw, y, sw, h)}[side]
                g.append(f'<rect x="{lx}" y="{ly}" width="{lw}" height="{lh}" style="fill:{stroke};stroke:none"/>')
        g.append("</g>")
        out.append("".join(g))
    parts.extend(out)


def shadow(prefix: str, x0: float, y0: float, d: float, alpha: float):
    """Weicher Schatten um den Rahmen: Ecken radial, Kanten linear, innen alpha -> außen 0."""
    c = 20.0
    r, g, b = shadow_rgb
    col = f"rgb({r},{g},{b})"
    for i, side in enumerate(SIDES):
        if not side:
            continue
        x = x0 + [0, d, d + c][i % 3]
        y = y0 + [0, d, d + c][i // 3]
        w = [d, c, d][i % 3]
        h = [d, c, d][i // 3]
        gid = f"{prefix}-grad-{side}"
        if side in ("topleft", "topright", "bottomleft", "bottomright"):
            cx = x + (w if "left" in side else 0)
            cy = y + (h if "top" in side else 0)
            defs.append(f'<radialGradient id="{gid}" gradientUnits="userSpaceOnUse" cx="{cx}" cy="{cy}" r="{d}" fx="{cx}" fy="{cy}">'
                        f'<stop offset="0" style="stop-color:{col};stop-opacity:{alpha}"/>'
                        f'<stop offset="1" style="stop-color:{col};stop-opacity:0"/></radialGradient>')
        else:
            x1, y1, x2, y2 = {"top": (x, y + h, x, y), "bottom": (x, y, x, y + h),
                              "left": (x + w, y, x, y), "right": (x, y, x + w, y)}[side]
            defs.append(f'<linearGradient id="{gid}" gradientUnits="userSpaceOnUse" x1="{x1}" y1="{y1}" x2="{x2}" y2="{y2}">'
                        f'<stop offset="0" style="stop-color:{col};stop-opacity:{alpha}"/>'
                        f'<stop offset="1" style="stop-color:{col};stop-opacity:0"/></linearGradient>')
        parts.append(f'<rect id="{prefix}-{side}" x="{x}" y="{y}" width="{w}" height="{h}" style="fill:url(#{gid});stroke:none"/>')


def hints(prefix: str, x0: float, y0: float, top: float, right: float, bottom: float, left: float):
    """Schattenbreite je Seite (Kvantum liest Höhe der *-hint-*-Rechtecke)."""
    parts.append(f'<rect id="{prefix}-hint-top" x="{x0}" y="{y0}" width="2.5" height="{top}" style="fill:#000;fill-opacity:0"/>')
    parts.append(f'<rect id="{prefix}-hint-bottom" x="{x0 + 4}" y="{y0}" width="2.5" height="{bottom}" style="fill:#000;fill-opacity:0"/>')
    parts.append(f'<rect id="{prefix}-hint-left" x="{-(y0 + 2.5)}" y="{x0 + 8}" width="2.5" height="{left}" transform="rotate(-90)" style="fill:#000;fill-opacity:0"/>')
    parts.append(f'<rect id="{prefix}-hint-right" x="{-(y0 + 2.5)}" y="{x0 + 12}" width="2.5" height="{right}" transform="rotate(-90)" style="fill:#000;fill-opacity:0"/>')


# Platz rechts neben der Vorlage (KvFlat ist 450 breit)
X = 1000.0
nine("menu-normal", X, 10, R, R, raised, border)

# Bedienelemente (sonst KvFlat-eckig): weiche Ecken xs (6 px), Flächen wie im KDE-Farbschema
RX = src["radius"].get("xs", 6)
btn = raised
btn_hover = mix(raised, t["text"], 0.08)
btn_border = over(t["border"], raised)
field = t["bg"]
for i, (st, f_, b_) in enumerate((("normal", btn, btn_border), ("focused", btn_hover, over(t["borderStrong"], btn_hover)),
                                   ("pressed", pressed, over(t["borderStrong"], pressed)),
                                   ("toggled", t["accentFill"], over(t["borderStrong"], t["accentFill"])))):
    nine(f"button-{st}", X + 600, 10 + 50 * i, RX, RX, f_, b_)
    if st != "normal":                          # Werkzeugknöpfe: flach, nur Hover/gedrückt/an
        nine(f"tbutton-{st}", X + 650, 10 + 50 * i, RX, RX, f_, None)
nine("lineedit-normal", X + 700, 10, RX, RX, field, btn_border)
nine("lineedit-focused", X + 700, 60, RX, RX, field, t["accent"])
nine("focus-normal", X + 800, 10, RX, RX, "transparent", t["accent"], 1.5)
nine("progress-normal", X + 850, 10, RX, RX, t.get("surfaceSunken", t["bg"]), btn_border)
nine("progress-pattern-normal", X + 850, 60, RX, RX, t["accent"], None)
nine("tooltip-normal", X, 80, R, R, raised, border)
for st, col in (("normal", None), ("focused", hover), ("toggled", hover), ("pressed", pressed)):
    if col:
        nine(f"menuitem-{st}", X + 100, 10 + 70 * ["focused", "toggled", "pressed"].index(st), R_ITEM, R_ITEM, col, None)
        nine(f"menubaritem-{st}", X + 200, 10 + 70 * ["focused", "toggled", "pressed"].index(st), R_ITEM, R_ITEM, col, None)
# Trenner: 1-px-Linie in der Mitte einer 9 px hohen, sonst leeren Fläche (Kvantum streckt das Element)
for sep in ("menuitem-separator", "separator-normal"):
    parts.append(f'<g id="{sep}"><rect x="{X + 500}" y="10" width="40" height="9" style="fill:#000;fill-opacity:0"/>'
                 f'<rect x="{X + 500}" y="14" width="40" height="1" style="fill:{over(t["border"], raised)}"/></g>')
SH = 8
shadow("menu-shadow", X + 300, 10, SH, 0.30)
shadow("tooltip-shadow", X + 300, 80, SH, 0.24)
hints("menu-shadow", X + 400, 10, 4, 6, 8, 6)

head = (f"<!-- {MARK} ({variant}) – nicht von Hand ändern. Neu erzeugen: python3 -I theme/gen/kvantum.py\n"
        "     Abgeleitet von KvFlat (Kvantum, GPL-3.0, Tsu Jan): umgefärbt, Menü/Tooltip-Elemente ersetzt. -->\n")
svg = re.sub(r'(<svg\b[^>]*?)\bwidth="[^"]*"', r'\1width="1450"', svg, count=1)
svg = svg.replace("</svg>", "<defs>" + "".join(defs) + "</defs>\n" + "\n".join(parts) + "\n</svg>")
svg = re.sub(r"^(<\?xml[^>]*>\s*)?", lambda m: (m.group(0) or "") + head, svg, count=1)

# ---------------------------------------------------------------- kvconfig
cfg = cfg_in.read_text()
cfg = HEX.sub(lambda m: recolor(m.group(0)), cfg)
cfg = re.sub(r"=white\b", "=" + t["text"], cfg)
cfg = re.sub(r"=black\b", "=" + t["bgBottom"], cfg)


def set_key(text: str, section: str, key: str, value) -> str:
    """Schlüssel in [section] setzen (oder anhängen)."""
    pat = re.compile(rf"(^\[{re.escape(section)}\]\n)(.*?)(?=^\[|\Z)", re.S | re.M)
    m = pat.search(text)
    if not m:
        return text.rstrip("\n") + f"\n\n[{section}]\n{key}={value}\n"
    body = m.group(2)
    if re.search(rf"^{re.escape(key)}=", body, re.M):
        body = re.sub(rf"^{re.escape(key)}=.*$", f"{key}={value}", body, flags=re.M)
    else:
        body = body.rstrip("\n") + f"\n{key}={value}\n\n"
    return text[:m.start(2)] + body + text[m.end(2):]


gen = {
    "comment": f"Desktop {variant} (aus theme/palette.json, Basis KvFlat von Tsu Jan, GPL-3.0)",
    "composite": "true",                 # runde Ecken + Schatten an Menüs (deckende Fläche, nur der Rand ist frei)
    "translucent_windows": "false",      # Fenster deckend
    "reduce_window_opacity": 0,
    "reduce_menu_opacity": 0,            # Menüs deckend
    "menu_blur_radius": 0,
    "tooltip_blur_radius": 0,
    "popup_blurring": "false",
    "blurring": "false",
    "menu_shadow_depth": SH,
    "tooltip_shadow_depth": SH,
    "spread_menuitems": "false",          # Einträge innen (Abstand = Menürahmen), Hover mit eigenen Ecken
    "menu_separator_height": 9,
    "submenu_overlap": 0,
    # Dolphins kleine Statuszeile rechnet ihre Breite mit 2 + 2·PM_SplitterWidth als Rand ab (KvFlat: 7 -> 16 px,
    # Text wird zu „11 …ers“ gekürzt). 1 px wie Breeze; die Trennlinie zeichnet ohnehin niemand.
    "splitter_width": 1,
}
for k, v in gen.items():
    cfg = set_key(cfg, "%General", k, v)

colors = {
    "window.color": t["surface"],
    "base.color": t["bg"],
    "alt.base.color": mix(t["bg"], t["text"], 0.04),
    "button.color": raised,
    "light.color": mix(raised, t["text"], 0.12),
    "mid.light.color": mix(raised, t["text"], 0.06),
    "dark.color": t["bgBottom"],
    "mid.color": t.get("surfaceSunken", t["bg"]),
    "highlight.color": selection,
    "inactive.highlight.color": mix(selection, t["surface"], 0.35),
    "tooltip.base.color": raised,
    "text.color": t["text"],
    "window.text.color": t["text"],
    "button.text.color": t["text"],
    "disabled.text.color": t["textFaint"],
    "tooltip.text.color": t["text"],
    "highlight.text.color": t["text"],
    "link.color": t["accentText"],
    "link.visited.color": src["ansi"].get("magenta", t["accentText"]),
    "progress.indicator.text.color": t["text"],
}
for k, v in colors.items():
    cfg = set_key(cfg, "GeneralColors", k, v)

for sec in ("PanelButtonCommand", "LineEdit", "Focus", "Progressbar", "ProgressbarContents"):
    for k in ("frame.top", "frame.bottom", "frame.left", "frame.right"):
        cfg = set_key(cfg, sec, k, RX)
cfg = set_key(cfg, "PanelButtonCommand", "text.focus.color", t["text"])
cfg = set_key(cfg, "Focus", "frame", "true")
cfg = set_key(cfg, "Focus", "frame.element", "focus")
cfg = set_key(cfg, "Focus", "interior", "false")
for k, v in {"text.margin.top": 2, "text.margin.bottom": 2, "text.margin.left": 6, "text.margin.right": 6}.items():
    cfg = set_key(cfg, "PanelButtonCommand", k, v)

# Menüs: Rahmen = Radius (Ecken passen), Einträge mit Luft wie im Shell-Menü (Zeilen ~32 px)
for k, v in {"frame.top": R, "frame.bottom": R, "frame.left": R, "frame.right": R,
             "frame.element": "menu", "interior.element": "menu"}.items():
    cfg = set_key(cfg, "Menu", k, v)
for k, v in {"frame.top": R_ITEM, "frame.bottom": R_ITEM, "frame.left": R_ITEM, "frame.right": R_ITEM,
             "text.margin.top": 0, "text.margin.bottom": 0, "text.margin.left": 4, "text.margin.right": 4,
             "text.normal.color": t["text"], "text.focus.color": t["text"], "text.press.color": t["text"],
             "text.toggle.color": t["text"], "frame": "true"}.items():
    cfg = set_key(cfg, "MenuItem", k, v)
for k, v in {"frame.top": R_ITEM // 2, "frame.bottom": R_ITEM // 2, "frame.left": R_ITEM // 2, "frame.right": R_ITEM // 2,
             "interior.element": "menubaritem", "frame.element": "menubaritem", "frame": "true", "interior": "true",
             "text.normal.color": t["text"], "text.focus.color": t["text"], "text.press.color": t["text"],
             "text.toggle.color": t["text"]}.items():
    cfg = set_key(cfg, "MenuBarItem", k, v)
for k, v in {"frame.top": R, "frame.bottom": R, "frame.left": R, "frame.right": R,
             "frame.element": "tooltip", "interior.element": "tooltip", "text.normal.color": t["text"]}.items():
    cfg = set_key(cfg, "ToolTip", k, v)

cfg = (f"# {MARK} ({variant}) – nicht von Hand ändern. Neu erzeugen: python3 -I theme/gen/kvantum.py\n"
       "# Abgeleitet von KvFlat.kvconfig (Kvantum, GPL-3.0, Tsu Jan).\n" + cfg)

print(f"Kvantum ({variant}, Basis {base}):")
write(OUT / f"kvantum/{NAME}/{NAME}.svg", svg)
write(OUT / f"kvantum/{NAME}/{NAME}.kvconfig", cfg)
print(f"  Menü {raised} · Rand {border} · Hover {hover} · Gedrückt {pressed} · Auswahl {selection} · Radius {R}")
print(f"  Kontrast Text/Menü {contrast(t['text'], raised):.1f} · Text/Hover {contrast(t['text'], hover):.1f}"
      f" · Gedämpft/Menü {contrast(t['textFaint'], raised):.1f}")
print("  Einschalten: scripts/kvantum-theme on   (zurück: scripts/kvantum-theme off)")
