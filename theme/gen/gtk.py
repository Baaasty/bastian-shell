#!/usr/bin/env python3
"""theme/palette.json -> GTK4/libadwaita- und GTK3-Look (theme/out/gtk/gtk-4.0.css, gtk-3.0.css).

Installiert (nach Backup) nach ~/.config/gtk-4.0/gtk.css und ~/.config/gtk-3.0/gtk.css, setzt in GTK3 das
Breeze-Theme (dunkel; nur die KDE-Module raus) und setzt Schrift/Cursor/Icons.
Aufruf aus dem Repo-Root:
  python3 -I theme/gen/gtk.py [variante] [--nur-out]   erzeugen (+ installieren, solange nicht --nur-out)
  python3 -I theme/gen/gtk.py --rueckweg               letztes Backup zurückspielen (Dateien + gsettings)
  python3 -I theme/gen/gtk.py --status                 zeigt, was gesetzt ist
Backup: ~/.local/state/desktop/theme-backup-<datum>/ (mit rueckweg.sh). Nichts wird gelöscht oder deinstalliert.
Von Hand angepasste gtk.css wird nie überschrieben (Abbruch mit Hinweis).
"""
import datetime
import pathlib
import re
import shutil
import subprocess
import sys

sys.path.insert(0, str(pathlib.Path(__file__).resolve().parent))
from _pal import HOME, MARK, OUT, contrast, hexc, install_wanted, load, mix, rgba, write  # noqa: E402

STATE = HOME / ".local/state/desktop"
CFG = HOME / ".config"
FONT = "Inter 10"
SCHEMA = "org.gnome.desktop.interface"


def sh(*cmd, check=False):
    r = subprocess.run(cmd, capture_output=True, text=True)
    if check and r.returncode:
        sys.exit(f"Fehler bei {' '.join(cmd)}: {r.stderr.strip()}")
    return r.stdout.strip()


# ---------------------------------------------------------------- Rückweg
def latest_backup():
    dirs = sorted(d for d in STATE.glob("theme-backup-*") if (d / "gsettings-gtk-theme").exists() and (d / "rueckweg.sh").exists())
    return dirs[-1] if dirs else None


if "--rueckweg" in sys.argv:
    b = latest_backup()
    if not b or not (b / "rueckweg.sh").exists():
        sys.exit("Kein Backup mit rueckweg.sh gefunden.")
    print(f"Rückweg aus {b}")
    sys.exit(subprocess.run(["bash", str(b / "rueckweg.sh")]).returncode)

if "--status" in sys.argv:
    for k in ("color-scheme", "gtk-theme", "icon-theme", "cursor-theme", "font-name"):
        print(f"  gsettings {k}: {sh('gsettings', 'get', SCHEMA, k)}")
    for v in ("gtk-3.0", "gtk-4.0"):
        f = CFG / v / "gtk.css"
        ok = f.exists() and MARK in f.read_text(errors="ignore")
        print(f"  {f}: {'von hier (hearth)' if ok else 'fremd/fehlt'}")
    sys.exit(0)

src, variant, t = load()
ansi = src["ansi"]


def opaque(c):
    """Palette-Wert (evtl. rgba) -> '#RRGGBB'; rgba wird auf die Fläche gelegt."""
    r, g, b, a = rgba(c)
    return hexc(r, g, b)


# ---------------------------------------------------------------- Farben
bg = t["bg"]
window = t["surface"]
raised = t.get("surfaceRaised") or mix(window, t["text"], 0.06)
sunken = t.get("surfaceSunken") or mix(window, t["bgBottom"], 0.5)
text, muted, faint = t["text"], t["textMuted"], t["textFaint"]
accent, accent_text = t["accent"], t["accentText"]
on_accent = t.get("onAccent") or t["bgBottom"]
# Rand: Creme-Hairline auf die Fläche gelegt (GTK-Namen brauchen opake Werte für shade/mix)
from _pal import over  # noqa: E402
border = over(t["border"], window)
border_strong = over(t["borderStrong"], window)

# Menüs (Kontextmenü, Menüleiste, Popover): Fläche surfaceRaised, Hover eine Stufe heller (kein Akzent-Rahmen),
# Rand = Creme-Hairline – gleich wie Qt/Kvantum (theme/gen/kvantum.py) und das Shell-Menü (TrayMenu).
menu_hover = mix(raised, text, 0.10)
menu_border = over(t["borderStrong"], raised)
menu_sep = over(t["border"], raised)
menu_radius = 10  # palette radius.sm

# Knopffläche (Standard): eine Spur heller als das Fenster; Hover/Active etwas weiter.
button = mix(window, text, 0.08)

# Akzent-Knopf: hat Terrakotta genug Kontrast mit onAccent? sonst abdunkeln.
accent_bg = accent
_tries = 0
while contrast(on_accent, accent_bg) < 4.5 and _tries < 20:
    accent_bg = mix(accent_bg, t["bgBottom"], 0.05)
    _tries += 1

# Zustandsfarben: Hintergrund (Knopf/Banner) mit dunklem Text und lesbare Variante als Text auf dem Fenster.
destructive_bg = mix(t["error"], t["bgBottom"], 0.38)  # tiefer Rost, klar vom Akzent unterscheidbar
destructive_fg = text
_tries = 0
while contrast(destructive_fg, destructive_bg) < 4.5 and _tries < 20:
    destructive_bg = mix(destructive_bg, t["bgBottom"], 0.05)
    _tries += 1
destructive_text = mix(t["error"], text, 0.30)
success_bg, warning_bg, error_bg = t["success"], t["warning"], destructive_bg
success_fg = warning_fg = on_accent
error_fg = text

# ---------------------------------------------------------------- libadwaita (GTK4)
adw = {
    "accent_color": accent_text,          # Akzent als Text/Icon auf dem Fenster (>= 4,5)
    "accent_bg_color": accent_bg,         # gefüllte Akzentfläche (Knöpfe, Schalter, Auswahl)
    "accent_fg_color": on_accent,
    "destructive_color": destructive_text,
    "destructive_bg_color": destructive_bg,
    "destructive_fg_color": destructive_fg,
    "success_color": success_bg,
    "success_bg_color": success_bg,
    "success_fg_color": success_fg,
    "warning_color": warning_bg,
    "warning_bg_color": warning_bg,
    "warning_fg_color": warning_fg,
    "error_color": destructive_text,
    "error_bg_color": error_bg,
    "error_fg_color": error_fg,
    "window_bg_color": window,
    "window_fg_color": text,
    "view_bg_color": sunken,
    "view_fg_color": text,
    "headerbar_bg_color": raised,
    "headerbar_fg_color": text,
    "headerbar_border_color": border,
    "headerbar_backdrop_color": window,
    "headerbar_shade_color": "rgba(12, 7, 4, 0.30)",
    "headerbar_darker_shade_color": "rgba(12, 7, 4, 0.36)",
    "sidebar_bg_color": mix(window, bg, 0.5),
    "sidebar_fg_color": text,
    "sidebar_backdrop_color": window,
    "sidebar_shade_color": "rgba(12, 7, 4, 0.25)",
    "sidebar_border_color": border,
    "secondary_sidebar_bg_color": window,
    "secondary_sidebar_fg_color": text,
    "secondary_sidebar_backdrop_color": window,
    "secondary_sidebar_shade_color": "rgba(12, 7, 4, 0.20)",
    "secondary_sidebar_border_color": border,
    "card_bg_color": raised,
    "card_fg_color": text,
    "card_shade_color": "rgba(12, 7, 4, 0.22)",
    "dialog_bg_color": window,
    "dialog_fg_color": text,
    "popover_bg_color": raised,
    "popover_fg_color": text,
    "popover_shade_color": "rgba(12, 7, 4, 0.25)",
    "thumbnail_bg_color": raised,
    "thumbnail_fg_color": text,
    "shade_color": "rgba(12, 7, 4, 0.34)",
    "scrollbar_outline_color": "rgba(12, 7, 4, 0.55)",
}

# Zusatz-Regeln: weiche Ecken, ruhige Ränder, Terrakotta nur als Auswahl/Fokus, kein Glas.
EXTRA_4 = f"""
/* Ränder und Ecken: ruhig, deckend */
window.background, window.dialog, window.csd {{ background-color: @window_bg_color; }}
.card, .boxed-list, list.boxed-list {{ border: 1px solid {border}; border-radius: 14px; box-shadow: none; }}
popover > contents, popover.menu > contents {{ border: 1px solid {border_strong}; border-radius: 14px; }}
entry, spinbutton, .view text {{ border-radius: 10px; }}
entry:focus-within, spinbutton:focus-within {{ outline-color: alpha({accent}, 0.55); }}
button {{ border-radius: 10px; }}
button.suggested-action {{ background-color: {accent_bg}; color: {on_accent}; }}
button.suggested-action:hover {{ background-color: {t.get("accentHover", accent)}; }}
button.suggested-action:active {{ background-color: {t.get("accentPressed", accent)}; }}
button.destructive-action {{ background-color: {destructive_bg}; color: {destructive_fg}; }}
row:selected, listview > row:selected, columnview row:selected {{ background-color: alpha({accent}, 0.30); color: @window_fg_color; }}
selection, text selection {{ background-color: alpha({accent}, 0.45); color: {text}; }}
scale highlight, progressbar progress, levelbar block.filled {{ background-color: {accent_bg}; }}
tooltip, tooltip.background {{ background-color: {raised}; color: {text}; border: 1px solid {border_strong}; border-radius: 10px; }}
link, a {{ color: {accent_text}; }}
/* Menüs: ruhiger Hover statt Akzent, Einträge mit eigenen weichen Ecken */
popover.menu modelbutton {{ border-radius: 8px; min-height: 30px; }}
popover.menu modelbutton:hover, popover.menu modelbutton:selected {{ background-color: {menu_hover}; color: {text}; }}
popover.menu separator {{ background-color: {menu_sep}; }}
"""

# ---------------------------------------------------------------- GTK3 (Breeze-Theme, Farben über Namen)
# Das Breeze-GTK3-Theme (wie unter Plasma, passend zu den Qt-Apps) färbt alles über @define-color <name>_breeze;
# hier werden alle 100 Namen aus /usr/share/themes/Breeze-Dark/gtk-3.0/gtk.css aus der Palette belegt,
# damit nirgends Breeze-Blau (#3daee9) durchkommt. (libadwaita-Namen gelten für GTK3 nicht.)
dim = lambda c: mix(c, window, 0.62)  # "insensitive": 62 % Richtung Fläche
sel = accent_bg
sel_fg = on_accent
head = raised
head_back = window
b = {
    "theme_fg_color": text, "theme_text_color": text,
    "theme_bg_color": window, "theme_base_color": sunken, "content_view_bg": sunken,
    "theme_view_hover_decoration_color": accent, "theme_view_active_decoration_color": accent,
    "theme_hovering_selected_bg_color": t.get("accentHover", accent),
    "theme_selected_bg_color": sel, "theme_selected_fg_color": sel_fg,
    "theme_unfocused_fg_color": text, "theme_unfocused_text_color": text, "theme_unfocused_bg_color": window,
    "theme_unfocused_base_color": sunken,
    "theme_unfocused_selected_bg_color": mix(sel, window, 0.45), "theme_unfocused_selected_bg_color_alt": mix(sel, window, 0.45),
    "theme_unfocused_selected_fg_color": text,
    "theme_unfocused_view_text_color": faint, "theme_unfocused_view_bg_color": sunken,
    "insensitive_bg_color": dim(window), "insensitive_fg_color": faint, "insensitive_base_color": dim(sunken),
    "insensitive_base_fg_color": faint,
    "insensitive_selected_bg_color": dim(sel), "insensitive_selected_fg_color": faint,
    "insensitive_unfocused_fg_color": faint, "insensitive_unfocused_bg_color": dim(window),
    "insensitive_unfocused_selected_bg_color": dim(sel), "insensitive_unfocused_selected_fg_color": faint,
    "borders": border_strong, "unfocused_borders": border, "insensitive_borders": border,
    "unfocused_insensitive_borders": border,
    "theme_button_background_normal": button, "theme_button_background_backdrop": button,
    "theme_button_background_insensitive": dim(button), "theme_button_background_backdrop_insensitive": dim(button),
    "theme_button_decoration_hover": accent, "theme_button_decoration_hover_backdrop": accent,
    "theme_button_decoration_focus": accent, "theme_button_decoration_focus_backdrop": accent,
    "theme_button_decoration_hover_insensitive": dim(accent),
    "theme_button_decoration_hover_backdrop_insensitive": dim(accent),
    "theme_button_decoration_focus_insensitive": dim(accent),
    "theme_button_decoration_focus_backdrop_insensitive": dim(accent),
    "theme_button_foreground_normal": text, "theme_button_foreground_active": text,
    "theme_button_foreground_backdrop": text, "theme_button_foreground_active_backdrop": text,
    "theme_button_foreground_insensitive": faint, "theme_button_foreground_active_insensitive": faint,
    "theme_button_foreground_backdrop_insensitive": faint, "theme_button_foreground_active_backdrop_insensitive": faint,
    "warning_color": warning_bg, "warning_color_backdrop": warning_bg,
    "warning_color_insensitive": dim(warning_bg), "warning_color_insensitive_backdrop": dim(warning_bg),
    "error_color": destructive_text, "error_color_backdrop": destructive_text,
    "error_color_insensitive": dim(destructive_text), "error_color_insensitive_backdrop": dim(destructive_text),
    "success_color": success_bg, "success_color_backdrop": success_bg,
    "success_color_insensitive": dim(success_bg), "success_color_insensitive_backdrop": dim(success_bg),
    "link_color": accent_text, "link_visited_color": ansi.get("magenta", accent_text),
    "theme_titlebar_background": head, "theme_titlebar_foreground": text,
    "theme_titlebar_background_light": head, "theme_titlebar_foreground_backdrop": muted,
    "theme_titlebar_background_backdrop": head_back,
    "theme_titlebar_foreground_insensitive": faint, "theme_titlebar_foreground_insensitive_backdrop": faint,
    "theme_header_background": head, "theme_header_foreground": text, "theme_header_background_light": head,
    "theme_header_foreground_backdrop": muted, "theme_header_background_backdrop": head_back,
    "theme_header_foreground_insensitive": faint, "theme_header_foreground_insensitive_backdrop": faint,
    "tooltip_text": text, "tooltip_background": raised, "tooltip_border": border_strong,
    "print_paper_backdrop": text,
}
gtk3 = {f"{k}_breeze" if k != "content_view_bg" else "content_view_bg_breeze": v for k, v in b.items()}

EXTRA_3 = f"""
/* Feinschliff: deckend, weiche Ecken, Terrakotta nur als Auswahl/Fokus */
button.destructive-action, button.destructive-action:hover {{ background-image: none; background-color: {destructive_bg}; color: {destructive_fg}; border-color: {destructive_bg}; }}
button.suggested-action, button.suggested-action:hover {{ background-image: none; background-color: {accent_bg}; color: {on_accent}; border-color: {accent_bg}; }}
button.suggested-action:hover {{ background-color: {t.get("accentHover", accent)}; }}
/* Menüs (Kontextmenü, Menüleiste, auch Helium im GTK-Modus): deckend surfaceRaised, Radius sm, ruhiger Hover */
.csd.popup decoration {{ border-radius: {menu_radius}px; box-shadow: 0 8px 22px rgba(12, 7, 4, 0.34); }}
menu, .menu, .context-menu {{ background-color: {raised}; color: {text}; border: 1px solid {menu_border}; border-radius: {menu_radius}px; padding: 6px; }}
menu menuitem, .menu menuitem, .context-menu menuitem {{ padding: 6px 10px; min-height: 20px; border-radius: 8px; border: none; box-shadow: none; background-image: none; }}
menu menuitem:hover, .menu menuitem:hover, .context-menu menuitem:hover {{ background-color: {menu_hover}; color: {text}; border: none; box-shadow: none; }}
menu menuitem:disabled, menu menuitem:disabled label {{ color: {faint}; }}
menu separator, .menu separator, .context-menu separator {{ background-color: {menu_sep}; min-height: 1px; margin: 4px 8px; }}
menubar > menuitem {{ border-radius: 8px; padding: 4px 8px; }}
menubar > menuitem:hover {{ background-color: {menu_hover}; color: {text}; border: none; box-shadow: none; }}
"""


def render(colors: dict, extra: str, kind: str, css_vars: bool) -> str:
    head = (
        f"/* {MARK} ({variant}) – nicht von Hand ändern.\n"
        f" * Neu erzeugen: python3 -I theme/gen/gtk.py\n"
        f" * Rückweg: python3 -I theme/gen/gtk.py --rueckweg  (Backup unter ~/.local/state/desktop/theme-backup-*)\n"
        f" * {kind} */\n"
    )
    body = "\n".join(f"@define-color {k} {v};" for k, v in colors.items()) + "\n"
    if css_vars:  # libadwaita >= 1.7 liest zusätzlich :root-Variablen (CSS-Variablen ersetzen die alten Namen)
        body += "\n:root {\n" + "\n".join(f"  --{k.replace('_', '-')}: {v};" for k, v in colors.items()) + "\n}\n"
    return head + body + extra


css4 = render(adw, EXTRA_4, "GTK4 / libadwaita", True)
css3 = render(gtk3, EXTRA_3, "GTK3 (Breeze-Theme mit Palette-Farben)", False)

print(f"GTK ({variant}):")
write(OUT / "gtk/gtk-4.0.css", css4)
write(OUT / "gtk/gtk-3.0.css", css3)

# ---------------------------------------------------------------- Kontrast-Nachweis
checks = [
    ("Text/Fenster", text, window),
    ("Text/Inhalt", text, sunken),
    ("Text/Kopfzeile", text, raised),
    ("Text/Karte+Popover", text, raised),
    ("Leise/Fenster", muted, window),
    ("Leise/Kopfzeile", muted, raised),
    ("Akzent-Text/Fenster", accent_text, window),
    ("Akzent-Text/Inhalt", accent_text, sunken),
    ("Text auf Akzentfläche", on_accent, accent_bg),
    ("Text auf Zerstörerisch", destructive_fg, destructive_bg),
    ("Fehler-Text/Fenster", destructive_text, window),
    ("Text auf Erfolg", success_fg, success_bg),
    ("Text auf Warnung", warning_fg, warning_bg),
    ("Text/Knopf", text, button),
    ("Text/Seitenleiste", text, adw["sidebar_bg_color"]),
]
bad = []
for name, fg, bgc in checks:
    c = contrast(fg, bgc)
    print(f"  Kontrast {name}: {c:.1f}")
    if c < 4.5:
        bad.append(name)
if bad:
    print("  WARNUNG < 4,5: " + ", ".join(bad))

if not install_wanted():
    sys.exit(0)

# ---------------------------------------------------------------- Backup
today = datetime.date.today().isoformat()
BK = STATE / f"theme-backup-{today}"
BK.mkdir(parents=True, exist_ok=True)
FILES = {}  # Backup-Name -> Zielpfad (für rueckweg.sh)


def backup_file(path: pathlib.Path, tag: str):
    """Original einmal sichern (spätere Läufe überschreiben das Backup nicht)."""
    dst = BK / tag
    FILES[tag] = path
    if dst.exists() or (BK / (tag + ".fehlte")).exists():
        return
    if path.exists():
        shutil.copy2(path, dst)
    else:
        (BK / (tag + ".fehlte")).write_text("")


def install_css(ver: str, text_: str):
    dst = CFG / ver / "gtk.css"
    if dst.exists():
        old = dst.read_text(errors="ignore")
        generated_by_kde = old.strip() in ("@import 'colors.css';", '@import "colors.css";', "")
        if MARK not in old and not generated_by_kde:
            sys.exit(f"Abbruch: {dst} ist von Hand angepasst. Bitte zusammenführen "
                     f"(theme/out/gtk/{ver}.css einbinden) und erneut starten.")
    backup_file(dst, f"{ver}-gtk.css")
    dst.parent.mkdir(parents=True, exist_ok=True)
    dst.write_text(text_)
    print(f"  -> {dst}")


def set_ini(path: pathlib.Path, tag: str, set_keys: dict, drop_keys=()):
    """Einzelne Schlüssel in settings.ini setzen/entfernen, Rest bleibt. Rechte bleiben."""
    if not path.exists():
        return
    backup_file(path, tag)
    lines = path.read_text().splitlines()
    out, seen = [], set()
    for ln in lines:
        k = ln.split("=", 1)[0].strip()
        if k in drop_keys:
            continue
        if k in set_keys:
            out.append(f"{k}={set_keys[k]}")
            seen.add(k)
        else:
            out.append(ln)
    for k, v in set_keys.items():
        if k not in seen:
            out.append(f"{k}={v}")
    path.write_text("\n".join(out) + "\n")
    print(f"  -> {path}")


# gsettings-Stand vorher sichern
keys = ["color-scheme", "gtk-theme", "icon-theme", "cursor-theme", "font-name"]
for k in keys:
    old = sh("gsettings", "get", SCHEMA, k)
    f = BK / f"gsettings-{k}"
    if not f.exists():
        f.write_text(old)
gl = pathlib.Path.home() / ".local/share/flatpak/overrides/global"
backup_file(gl, "flatpak-overrides-global")

install_css("gtk-4.0", css4)
install_css("gtk-3.0", css3)

# GTK3: Breeze-Theme (dunkel) bleibt, nur die Farben kommen aus gtk.css; die KDE-Module (alte Titelknopf-SVGs
# in Ember-Farben, colors.css-Reload) raus.
set_ini(CFG / "gtk-3.0/settings.ini", "gtk-3.0-settings.ini",
        {"gtk-theme-name": "Breeze", "gtk-application-prefer-dark-theme": "true"}, drop_keys=("gtk-modules",))
set_ini(CFG / "gtk-4.0/settings.ini", "gtk-4.0-settings.ini", {"gtk-application-prefer-dark-theme": "true"})

# gsettings: GTK3 (Wayland) liest hier zuerst; libadwaita nutzt color-scheme
sh("gsettings", "set", SCHEMA, "gtk-theme", "Breeze")
sh("gsettings", "set", SCHEMA, "color-scheme", "prefer-dark")
for k, want in (("icon-theme", "Desktop-Icons"), ("cursor-theme", "Desktop")):
    if (HOME / ".local/share/icons" / want).is_dir():
        sh("gsettings", "set", SCHEMA, k, want)
sh("gsettings", "set", SCHEMA, "font-name", FONT)
print("  gsettings: gtk-theme=Breeze, color-scheme=prefer-dark, Icons/Cursor/Schrift gesetzt")

# Flatpak (nur user-lokal): GTK-Konfiguration lesend durchreichen
r = subprocess.run(["flatpak", "override", "--user", "--filesystem=xdg-config/gtk-4.0:ro",
                    "--filesystem=xdg-config/gtk-3.0:ro"], capture_output=True, text=True)
print("  flatpak override --user: " + ("ok" if r.returncode == 0 else f"übersprungen ({r.stderr.strip()[:80]})"))

lines = ["#!/usr/bin/env bash", f"# Rückweg GTK-Theme (erzeugt von theme/gen/gtk.py, Backup vom {today})", "set -u"]
for tag, path in FILES.items():
    if (BK / tag).exists():
        lines.append(f"cp -p '{BK / tag}' '{path}'")
    else:
        lines.append(f"rm -f '{path}'")
for k in keys:
    lines.append(f"gsettings set {SCHEMA} {k} \"$(cat '{BK / ('gsettings-' + k)}')\"")
lines.append("echo 'GTK-Theme zurückgesetzt (laufende Apps neu starten).'")
undo = BK / "rueckweg.sh"
undo.write_text("\n".join(lines) + "\n")
undo.chmod(0o755)
print(f"  Backup: {BK}  (Rückweg: python3 -I theme/gen/gtk.py --rueckweg)")
