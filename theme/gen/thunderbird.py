#!/usr/bin/env python3
"""theme/palette.json -> Thunderbird im desktop-Look (natives Fedora-RPM `thunderbird`, Profil ~/.thunderbird;
Fallback: Flatpak org.mozilla.thunderbird_esr, solange es noch nicht umgezogen ist – scripts/flatpak-to-native).

Zwei Teile:
  1. Theme "Desktop" (WebExtension-XPI): Rahmen, Tabs, Toolbar, Suchfeld, Menüs, Seitenleiste.
     Farbschlüssel: chrome/messenger/content/messenger/schemas/theme.json in omni.ja (alle sinnvollen gesetzt).
  2. userChrome.css + userContent.css (Profil/chrome/): alles, was ein Theme nicht erreicht –
     Ordner- und Nachrichtenliste, Lesebereich, Kalender (Tag/Woche/Monat, Heute, Termine), Dialoge,
     Einstellungen, Mailtext (Zitate, Plaintext). Vorlagen ohne Farbwerte in theme/gen/thunderbird-css/,
     der Generator setzt die --desk-*-Tokens aus der Palette davor.
     Braucht toolkit.legacyUserProfileCustomizations.stylesheets = true -> eigener markierter Block in user.js.

Aufruf aus dem Repo-Root:
  python3 -I theme/gen/thunderbird.py [variante] [--nur-out]   erzeugen + XPI ins Profil; chrome/ und user.js
                                                                nur auffrischen, wenn schon angewendet (all.py)
  python3 -I theme/gen/thunderbird.py apply [variante]          zusätzlich chrome/ + user.js-Block anlegen
  python3 -I theme/gen/thunderbird.py remove                    alles Eigene wieder raus (chrome-Dateien,
                                                                user.js-Block, XPI); fremde Dateien bleiben
  python3 -I theme/gen/thunderbird.py status
Wirkt erst nach Thunderbird-Neustart. Thunderbird wird nie beendet; prefs.js wird nie angefasst.
Theme einmalig aktivieren: Add-ons und Themes -> Themes -> "Desktop" (seitengeladen = erst deaktiviert).
"""
import configparser
import json
import pathlib
import re
import shutil
import subprocess
import sys
import zipfile

sys.path.insert(0, str(pathlib.Path(__file__).resolve().parent))
from _pal import HOME, MARK, OUT, ROOT, contrast, install, install_wanted, mix, over, write  # noqa: E402
import _pal  # noqa: E402

ID = "desktop-theme@bastian"
VERSION = "0.3.0"
APP = "org.mozilla.thunderbird_esr"                    # altes Flatpak (Fallback bis zum Umzug)
# Profil-Ordner, erster mit profiles.ini gewinnt: RPM (~/.thunderbird; neuere Thunderbirds ohne den alten
# Ordner nehmen ~/.config/mozilla/thunderbird), sonst das Flatpak
TB_ROOTS = (HOME / ".thunderbird", HOME / ".config/mozilla/thunderbird", HOME / f".var/app/{APP}/.thunderbird")
TB_ROOT = next((r for r in TB_ROOTS if (r / "profiles.ini").is_file()), TB_ROOTS[0])
TEMPLATES = pathlib.Path(__file__).resolve().parent / "thunderbird-css"
CSS_FILES = ("userChrome.css", "userContent.css")
PREF = "toolkit.legacyUserProfileCustomizations.stylesheets"
BLOCK_BEGIN = f"// >>> desktop-theme ({MARK}) – verwaltet von theme/gen/thunderbird.py, nicht von Hand ändern"
BLOCK_END = "// <<< desktop-theme"
BACKUP = "user.js.vor-desktop"

COMMANDS = {"apply", "remove", "status"}
cmd = next((a for a in sys.argv[1:] if a in COMMANDS), None)
if cmd:
    sys.argv.remove(cmd)


# ───────────────────────── Profil ─────────────────────────

def default_profile():
    """Profil, das Thunderbird wirklich startet: [Install…] Default, sonst Default=1."""
    ini = TB_ROOT / "profiles.ini"
    if not ini.exists():
        return None
    cp = configparser.ConfigParser(interpolation=None)
    cp.optionxform = str
    cp.read(ini)
    path = next((cp[s]["Default"] for s in cp.sections() if s.startswith("Install") and "Default" in cp[s]), None)
    if path:
        return TB_ROOT / path
    prof = next((cp[s] for s in cp.sections() if s.startswith("Profile") and cp[s].get("Default") == "1"), None)
    if not prof:
        return None
    return TB_ROOT / prof["Path"] if prof.get("IsRelative", "1") == "1" else pathlib.Path(prof["Path"])


def tb_running() -> bool:
    if shutil.which("flatpak"):
        r = subprocess.run(["flatpak", "ps", "--columns=application"], capture_output=True, text=True)
        if APP in r.stdout:
            return True
    return subprocess.run(["pgrep", "-x", "thunderbird"], capture_output=True).returncode == 0


def ours(path: pathlib.Path) -> bool:
    return path.is_file() and MARK in path.read_text(errors="ignore")


def userjs_block() -> str:
    return "\n".join([
        BLOCK_BEGIN,
        "// userChrome.css/userContent.css im Profil/chrome laden (desktop-Look für Listen, Kalender, Mailtext)",
        f'user_pref("{PREF}", true);',
        "// Kalender: Woche beginnt am Montag (Oberfläche bleibt Englisch)",
        'user_pref("calendar.week.start", 1);',
        "// Neue Mail meldet die Shell (scripts/mail-watch) – Thunderbirds eigene Meldung + Ton wären doppelt",
        'user_pref("mail.biff.show_alert", false);',
        'user_pref("mail.biff.play_sound", false);',
        BLOCK_END,
    ]) + "\n"


# Kein weiterer Block-Anfang dazwischen: fehlt bei einem alten Block die Ende-Zeile, darf der Treffer nicht
# vom alten Anfang bis zum Ende des neuen Blocks reichen (sonst würden fremde Prefs dazwischen gelöscht)
_BEGIN = re.escape(BLOCK_BEGIN.split(" (")[0])
BLOCK_RE = re.compile(_BEGIN + r"(?:(?!" + _BEGIN + r").)*?" + re.escape(BLOCK_END) + r"\n?", re.S)


def userjs_state(profile):
    uj = profile / "user.js"
    return uj.is_file() and bool(BLOCK_RE.search(uj.read_text(errors="ignore")))


def userjs_apply(profile):
    uj = profile / "user.js"
    old = uj.read_text() if uj.exists() else ""
    if old and not BLOCK_RE.search(old) and not (profile / BACKUP).exists():
        shutil.copy2(uj, profile / BACKUP)                     # fremde user.js einmal sichern
        print(f"  Sicherung: {profile / BACKUP}")
    rest = BLOCK_RE.sub("", old)
    new = (rest.rstrip("\n") + "\n\n" if rest.strip() else "") + userjs_block()
    if new != old:
        uj.write_text(new)
        print(f"  -> {uj} (Block {PREF})")


def userjs_remove(profile):
    uj = profile / "user.js"
    if not uj.exists():
        return
    old = uj.read_text()
    rest = BLOCK_RE.sub("", old)
    if rest == old:
        return
    if rest.strip():
        uj.write_text(rest.rstrip("\n") + "\n")
        print(f"  {uj}: eigener Block entfernt, Rest bleibt")
    else:
        uj.unlink()
        print(f"  {uj} entfernt (enthielt nur den eigenen Block)")


# ───────────────────────── remove / status (brauchen keine Palette) ─────────────────────────

if cmd in ("remove", "status"):
    profile = default_profile()
    if profile is None or not profile.is_dir():
        sys.exit("Thunderbird-Profil nicht gefunden.")
    running = tb_running()
    xpi_dst = profile / "extensions" / f"{ID}.xpi"
    if cmd == "status":
        print(f"Profil:           {profile}")
        print(f"Thunderbird:      {'läuft' if running else 'aus'}")
        print(f"Theme-XPI:        {'da' if xpi_dst.exists() else '–'}")
        for f in CSS_FILES:
            p = profile / "chrome" / f
            print(f"{f + ":":18}{'eigen' if ours(p) else ('fremd!' if p.exists() else '–')}")
        print(f"user.js-Block:    {'da' if userjs_state(profile) else '–'}")
        prefs = (profile / "prefs.js").read_text(errors="ignore") if (profile / "prefs.js").exists() else ""
        active = re.search(r'"extensions\.activeThemeID",\s*"([^"]+)"', prefs)
        print(f"Aktives Theme:    {active.group(1) if active else 'Standard'}"
              f"{'' if active and active.group(1) == ID else '  (Desktop: Add-ons → Themes → aktivieren)'}")
        print(f"Stylesheets:      {'an' if re.search(re.escape(PREF) + r'\", true', prefs) else 'aus (greift nach Neustart)'}")
        sys.exit(0)

    print("Thunderbird: desktop-Look entfernen")
    for f in CSS_FILES:
        p = profile / "chrome" / f
        if ours(p):
            p.unlink()
            print(f"  {p} entfernt")
        elif p.exists():
            print(f"  {p} stammt nicht von hier – bleibt")
    chrome_dir = profile / "chrome"
    if chrome_dir.is_dir() and not any(chrome_dir.iterdir()):
        chrome_dir.rmdir()
    userjs_remove(profile)
    if xpi_dst.exists():
        xpi_dst.unlink()
        print(f"  {xpi_dst} entfernt")
    print(f"  Hinweis: {PREF} bleibt in prefs.js auf true, wirkt ohne chrome/-Dateien aber nicht."
          " Ganz zurück: about:config → Pref → Zurücksetzen.")
    print("  Ebenso mail.biff.show_alert / mail.biff.play_sound (eigene Mail-Meldung + Ton): about:config → Zurücksetzen.")
    print("  Thunderbird neu starten." + (" (läuft gerade – wird nicht beendet)" if running else ""))
    sys.exit(0)


# ───────────────────────── Farben ─────────────────────────

src, variant, t = _pal.load()

solid = not t.get("blur", True)                         # hearth & Co.: deckend, mittelbraun statt Fast-Schwarz
bg, surface = t["bg"], t["surface"]
deep = bg if solid else t["bgBottom"]                   # Rahmen/Fugen um die Kacheln
raised = mix(surface, t["wood"], 0.18)
hover = mix(surface, t["wood"], 0.35)
press = mix(surface, t["wood"], 0.60)
line = over(t["border"], surface)
line_bg = over(t["border"], bg)
line_strong = over(t["borderStrong"], surface)
accent_soft = over(t["accentSoft"], bg)                 # gewählte Zeile in Listen
accent_soft_surface = over(t["accentSoft"], surface)    # gewählt auf Surface (Ordner, Menüs)
accent_muted = mix(t["accent"], surface, 0.35)         # "selected-item": Knöpfe, Fokusrahmen – nie Vollton-Fläche

tokens = {
    "bg": bg,
    "bg-deep": deep,
    "surface": surface,
    "raised": raised,
    "hover": hover,
    "press": press,
    "hover-bg": mix(bg, t["wood"], 0.16),
    "hover-surface": mix(surface, t["wood"], 0.22),
    "hover-deep": mix(deep, t["wood"], 0.22),
    "select-unfocused": mix(bg, t["wood"], 0.30),
    "select-unfocused-surface": mix(surface, t["wood"], 0.30),
    "select-day": mix(bg, t["wood"], 0.12),             # gewählter Kalendertag: neutral, nicht rot
    "line": line,
    "line-bg": line_bg,
    "line-strong": line_strong,
    "text": t["text"],
    "text-muted": t["textMuted"],
    "text-faint": t["textFaint"],
    "g15": mix(t["text"], t["textMuted"], 0.5),
    "g20": mix(t["text"], t["textMuted"], 0.7),
    "g50": mix(t["textFaint"], t["wood"], 0.35),
    "accent": t["accent"],
    "accent-text": t["accentText"],
    "accent-soft": accent_soft,
    "accent-soft-surface": accent_soft_surface,
    "accent-muted": accent_muted,
    "wood": t["wood"],
    "wood-light": t["woodLight"],
    "success": t["success"],
    "warning": t["warning"],
    "warning-soft": over(t["warningSoft"], surface),
    "error": t["error"],
    "warning-line": mix(surface, t["warning"], 0.35),
    "error-soft": mix(surface, t["error"], 0.14),
    "error-line": mix(surface, t["error"], 0.35),
    "success-soft": mix(surface, t["success"], 0.12),
    "success-line": mix(surface, t["success"], 0.30),
    "dim": t["dim"],
    # Kalender
    "today-bg": mix(bg, t["accent"], 0.035),            # Heute-Spalte: nur ein Hauch Glut
    "today-off-bg": mix(mix(bg, deep, 0.6), t["accent"], 0.035),
    "weekend-bg": mix(bg, t["wood"], 0.08),
    "other-month-bg": mix(bg, deep, 0.7),
    "offtime-bg": mix(bg, deep, 0.6),
    # Mailtext
    "selection": over(src["ansi"]["selectionBackground"], bg),
    "quote-1": t["woodLight"],
    "quote-2": t["textFaint"],
    "quote-3": t["success"],
    "quote-4": t["warning"],
}
radius = src["radius"]
lengths = {f"radius-{k}": f"{radius[k]}px" for k in ("xs", "sm", "md", "lg")}
ui, mono = src["type"]["ui"], src["type"]["mono"]
fonts = {
    "font-ui": f'"{ui["family"]}", {ui["fallback"]}',
    "font-mono": f'"{mono["family"]}", {mono["fallback"]}',
}

# Kontrolle: Creme auf den Auswahlflächen muss lesbar bleiben
for name in ("accent-soft", "accent-soft-surface", "accent-muted", "select-unfocused", "hover"):
    c = contrast(t["text"], tokens[name])
    if c < 4.5:
        print(f"  Warnung: Kontrast text/{name} = {c:.1f} (< 4.5)")

BASE_SLOT = "/* @@BASE@@ */"
HEX = re.compile(r"#[0-9a-fA-F]{3,8}\b|\brgba?\(|\bhsla?\(")


def css(template: str) -> str:
    body = (TEMPLATES / template).read_text()
    if BASE_SLOT in body:                                   # gemeinsame Basis einsetzen
        body = body.replace(BASE_SLOT, (TEMPLATES / "base.css").read_text())
    stripped = re.sub(r"/\*.*?\*/", "", body, flags=re.S)
    if HEX.search(stripped):
        sys.exit(f"Abbruch: {template} enthält einen festen Farbwert – nur var(--desk-*) erlaubt.")
    used = set(re.findall(r"var\(--desk-([a-z0-9-]+)", stripped))
    known = {**tokens, **lengths, **fonts}
    if used - known.keys():
        sys.exit(f"Abbruch: {template} nutzt unbekannte Tokens: {', '.join(sorted(used - known.keys()))}")
    decl = "\n".join(f"  --desk-{k}: {v};" for k, v in known.items())
    head = (f"/* {MARK} ({variant}) – nicht von Hand ändern.\n"
            f" * Vorlagen: theme/gen/thunderbird-css/ · neu erzeugen: python3 -I theme/gen/thunderbird.py */\n\n")
    return head + f":root {{\n{decl}\n}}\n\n" + body


# ───────────────────────── Theme (XPI) ─────────────────────────

frame = deep                          # Kopfzeile, Tab-Leiste und Toolbar: ein ruhiger Rahmen
bar = deep
tab = surface                         # aktiver Tab hebt sich als Kachel ab
tree = surface                        # Seitenleisten (Ordner, Kalender, Adressbuch)
field = surface

colors = {
    "frame": frame,
    "frame_inactive": mix(frame, "#000000", 0.25),
    "tab_background_text": t["textFaint"],
    "tab_background_separator": "transparent",
    "tab_selected": tab,
    "tab_text": t["text"],
    "tab_line": t["accent"],
    "tab_loading": t["accent"],
    "toolbar": bar,
    "toolbar_text": t["text"],
    "bookmark_text": t["text"],
    "toolbar_top_separator": over(t["border"], frame),
    "toolbar_bottom_separator": over(t["border"], frame),
    "toolbar_vertical_separator": over(t["border"], frame),
    "toolbar_field": field,
    "toolbar_field_text": t["text"],
    "toolbar_field_border": line,
    "toolbar_field_separator": line,
    "toolbar_field_focus": field,
    "toolbar_field_text_focus": t["text"],
    "toolbar_field_border_focus": accent_muted,
    "toolbar_field_highlight": accent_muted,
    "toolbar_field_highlight_text": t["text"],
    "button_background_hover": mix(frame, t["wood"], 0.30),
    "button_background_active": mix(frame, t["wood"], 0.50),
    "icons": t["textMuted"],
    "icons_attention": t["accentText"],
    "sidebar": tree,
    "sidebar_text": t["text"],
    "sidebar_border": line,
    "sidebar_highlight": accent_soft_surface,
    "sidebar_highlight_text": t["text"],
    "sidebar_highlight_border": line_strong,
    "popup": surface,
    "popup_text": t["text"],
    "popup_border": line_strong,
    "popup_highlight": accent_soft_surface,
    "popup_highlight_text": t["text"],
    "ntp_background": bg,
    "ntp_text": t["text"],
}

manifest = {
    "manifest_version": 2,
    "name": "Desktop",
    "version": VERSION,
    "description": f"Warmes Braun, Creme und Terrakotta-Akzent. {MARK} ({variant}).",
    "browser_specific_settings": {"gecko": {"id": ID, "strict_min_version": "128.0"}},
    "theme": {
        "colors": colors,
        "properties": {"color_scheme": "dark", "content_color_scheme": "dark"},
    },
}
text = json.dumps(manifest, indent=2, ensure_ascii=False) + "\n"

print(f"Thunderbird ({variant}):")
out = OUT / "thunderbird-desktop"
write(out / "manifest.json", text)

# XPI = Zip mit manifest.json im Wurzelverzeichnis. Unkomprimiert, damit _pal.install() den MARK
# in der installierten Datei findet; feste Zeit, damit die Datei nur bei Farbänderung neu ist.
xpi = out / f"{ID}.xpi"
info = zipfile.ZipInfo("manifest.json", date_time=(2026, 1, 1, 0, 0, 0))
info.compress_type = zipfile.ZIP_STORED
with zipfile.ZipFile(xpi, "w") as z:
    z.writestr(info, text)
print(f"  {xpi.relative_to(ROOT)}")

for f in CSS_FILES:
    write(out / "chrome" / f, css(f))
write(out / "user.js", userjs_block())

if not install_wanted():
    sys.exit(0)

profile = default_profile()
if profile is None or not profile.is_dir():
    print("  Thunderbird-Profil nicht gefunden – nur theme/out/ geschrieben.")
    sys.exit(0)

xpi_dst = profile / "extensions" / f"{ID}.xpi"
if xpi_dst.exists() and xpi_dst.read_bytes() == xpi.read_bytes():
    print(f"  = {xpi_dst} (unverändert)")
else:
    install(xpi, xpi_dst)

applied = all(ours(profile / "chrome" / f) for f in CSS_FILES) or userjs_state(profile)
if cmd == "apply" or applied:
    for f in CSS_FILES:
        dst = profile / "chrome" / f
        if dst.exists() and not ours(dst):
            sys.exit(f"Abbruch: {dst} existiert und stammt nicht von hier.")
        install(out / "chrome" / f, dst)
    userjs_apply(profile)
    print("  Greift nach Thunderbird-Neustart." + (" (Thunderbird läuft gerade – nicht beendet.)" if tb_running() else ""))
    prefs = (profile / "prefs.js").read_text(errors="ignore") if (profile / "prefs.js").exists() else ""
    if f'"extensions.activeThemeID", "{ID}"' not in prefs:
        print("  Theme einmalig aktivieren: ☰ → Add-ons und Themes → Themes → \"Desktop\".")
else:
    print("  Listen/Kalender/Mailtext: python3 -I theme/gen/thunderbird.py apply")
