#!/usr/bin/env python3
"""theme/palette.json -> zwei entpackte Chromium-Erweiterungen (Helium, Chrome).

  theme/out/chrome-desktop/      "Desktop Theme": reines Theme (nur manifest.json, Chrome erlaubt dort keine Skripte)
  theme/out/chrome-desktop-ext/  "Desktop": neue Tab-Seite + Verbindung zur Shell (Tabs, Termine, Wetter)
                                 + Autofill (iCloud-Passwörter, 2FA, Hide My Email; autofill.js, popup.*)

Die Vorlagen der Funktions-Erweiterung liegen in theme/gen/chrome-ext/ (Farben als {{token}},
werden hier eingesetzt). key.pub = öffentlicher Schlüssel -> feste Erweiterungs-ID (für Native Messaging,
siehe scripts/chrome-ext). Wird NICHT installiert: helium://extensions bzw. chrome://extensions -> Entwicklermodus ->
"Entpackte Erweiterung laden" (beide Ordner). Theme-Schlüssel wie in Chromiums browser_theme_pack.cc.
Aufruf aus dem Repo-Root:
  python3 -I theme/gen/chrome.py [variante]
  python3 -I theme/gen/chrome.py --id      nur die Erweiterungs-ID ausgeben
  python3 -I theme/gen/chrome.py --ohne-wallpaper   Tab-Seite nur mit Verlauf statt Wallpaper
  (deckende Varianten wie hearth nehmen ohnehin den schlichten Grund; --wallpaper erzwingt das Foto)
Der Hintergrund der Tab-Seite ist eine Kopie des aktuellen Mitte-Wallpapers (neues Wallpaper -> neu erzeugen + ↻).
"""
import base64
import hashlib
import json
import pathlib
import re
import shutil
import struct
import subprocess
import sys
import zlib

sys.path.insert(0, str(pathlib.Path(__file__).resolve().parent))
from _pal import OUT, ROOT, load, mix, over, rgba, write  # noqa: E402

TPL = pathlib.Path(__file__).resolve().parent / "chrome-ext"
HOST = "de.bastian.desktop"   # Name des Native-Messaging-Hosts (scripts/chrome-ext)


def ext_id() -> str:
    """Erweiterungs-ID aus dem öffentlichen Schlüssel: SHA-256 der DER-Bytes, erste 16 Byte, 0-f -> a-p."""
    der = base64.b64decode((TPL / "key.pub").read_text().strip())
    return "".join(chr(ord("a") + int(c, 16)) for c in hashlib.sha256(der).hexdigest()[:32])


if "--id" in sys.argv:
    print(ext_id())
    sys.exit(0)

src, variant, t = load()


def rgb(c: str):
    return list(rgba(c)[:3])


def css(c: str) -> str:
    """Palette-Wert unverändert als CSS-Farbe (Hex oder rgba())."""
    return c


# ---------- 1. Theme ----------
solid = not t.get("blur", True)              # hearth & Co.: deckend, mittelbraun (nicht Fast-Schwarz)
frame = t["bg"] if solid else t["bgBottom"]  # Fensterrahmen + Tab-Leiste
frame_off = mix(frame, "#000000", 0.12 if solid else 0.25)   # Fenster ohne Fokus: etwas dunkler
toolbar = t["surface"]                       # aktiver Tab + Toolbar
omnibox = t.get("surfaceSunken", t["bg"])    # Adressleiste: eine Stufe tiefer als die Toolbar
incognito = mix(t["wood"], t["bgBottom"], 0.35 if solid else 0.55)   # Inkognito: Holz statt Lila
incognito_off = mix(incognito, "#000000", 0.25)

colors = {
    # Rahmen
    "frame": frame,
    "frame_inactive": frame_off,
    "frame_incognito": incognito,
    "frame_incognito_inactive": incognito_off,
    # inaktive Tabs sitzen auf dem Rahmen
    "background_tab": frame,
    "background_tab_inactive": frame_off,
    "background_tab_incognito": incognito,
    "background_tab_incognito_inactive": incognito_off,
    # aktiver Tab + Toolbar
    "toolbar": toolbar,
    "toolbar_text": t["text"],
    "toolbar_button_icon": t["textMuted"],
    "tab_text": t["text"],
    "tab_background_text": t["textMuted"],
    "tab_background_text_inactive": t["textFaint"],
    "tab_background_text_incognito": t["textMuted"],
    "tab_background_text_incognito_inactive": t["textFaint"],
    "bookmark_text": t["textMuted"],
    # Adressleiste etwas tiefer als die Toolbar
    "omnibox_background": omnibox,
    "omnibox_text": t["text"],
    # Chromes eigene neue Tab-Seite (greift nur ohne "Desktop"-Erweiterung)
    "ntp_background": t["bg"],
    "ntp_text": t["text"],
    "ntp_link": t["accentText"],
    "ntp_header": over(t["borderStrong"], t["bg"]),
}

theme_manifest = {
    "manifest_version": 3,
    "name": "Desktop Theme",
    "version": "0.3.0",
    "description": f"Warm brown, wood and cream (from theme/palette.json, {variant}).",
    "theme": {
        # Fensterknöpfe (min/max/zu) ohne eigene Fläche
        "colors": {**{k: rgb(v) for k, v in colors.items()}, "button_background": [0, 0, 0, 0.0]},
        # Icons nicht umfärben (-1 = unverändert), toolbar_button_icon reicht
        "tints": {"buttons": [-1, -1, -1]},
        "properties": {
            "ntp_background_alignment": "bottom",
            "ntp_logo_alternate": 1,   # helles Google-Logo auf dunklem Grund
        },
    },
}

print(f"Chrome ({variant}):")
write(OUT / "chrome-desktop/manifest.json", json.dumps(theme_manifest, indent=2, ensure_ascii=False) + "\n")


# ---------- 2. Funktions-Erweiterung "Desktop" ----------
EXT = OUT / "chrome-desktop-ext"

def current_wallpaper():
    """Wallpaper des Mitte-Monitors (2560 px) laut scripts/wallpaper status, sonst das neueste desktop-mitte-*.jpg."""
    try:
        out = subprocess.run([str(ROOT / "scripts/wallpaper"), "status"], capture_output=True, text=True, timeout=10).stdout
        for line in out.splitlines():
            if line.startswith("Monitor") and "(2560 px)" in line:
                p = pathlib.Path(line.split(": ", 1)[1].strip())
                if p.is_file():
                    return p
    except (OSError, subprocess.SubprocessError):
        pass
    found = sorted((pathlib.Path.home() / ".local/share/wallpapers/desktop").rglob("desktop-mitte-*.jpg"),
                   key=lambda p: p.stat().st_mtime)
    return found[-1] if found else None


# Hintergrund = Desktop-Wallpaper (Mitte), beim Generieren kopiert; ohne Wallpaper bleibt der Verlauf
# Deckende Varianten (blur=false, z. B. hearth): schlichter Grund statt Foto, damit Text ruhig bleibt; --wallpaper erzwingt das Foto
wall = None if ("--ohne-wallpaper" in sys.argv or (solid and "--wallpaper" not in sys.argv)) else current_wallpaper()
br, bgg, bb, _ = rgba(t["bg"])

tokens = {
    "wallpaper": 'url("wallpaper.jpg")' if wall else "none",
    "glowDisplay": "none" if (wall or solid) else "block",
    "scrim": f"rgba({br}, {bgg}, {bb}, 0.5)" if wall else "transparent",   # Abdunkeln um Uhr/Suche (bg mit Alpha)
    "bg": css(t["bg"]),
    "bgBottom": css(t["bgBottom"]),
    "surface": css(t["surface"]),
    "surfaceRaised": css(t.get("surfaceRaised", t["surface"])),
    "surfaceSunken": css(t.get("surfaceSunken", t["bg"])),
    "accentFill": css(t.get("accentFill", t["accentSoft"])),
    "onAccent": css(t.get("onAccent", t["text"])),
    "chipBg": css(t["surface"] if solid else t["glassTint"]),
    "menuBg": css(t.get("surfaceRaised", t["surface"]) if solid else t["surface"]),
    "menuBgEnd": css(t.get("surfaceRaised", t["surface"]) if solid else t["bg"]),
    "activeBg": css(t["accentFill"] if solid and "accentFill" in t else t["accentSoft"]),
    "blurFilter": "none" if solid else "blur(24px) saturate(1.15)",
    "highlight": "0 0 0 transparent" if solid else "inset 0 1px 0 " + src["glass"]["innerHighlight"],
    "glassTint": css(t["glassTint"]),
    "glassStrong": css(t["glassStrong"]),
    "border": css(t["border"]),
    "borderStrong": css(t["borderStrong"]),
    "text": css(t["text"]),
    "textMuted": css(t["textMuted"]),
    "textFaint": css(t["textFaint"]),
    "accent": css(t["accent"]),
    "accentText": css(t["accentText"]),
    "accentSoft": css(t["accentSoft"]),
    "wood": css(t["wood"]),
    "woodLight": css(t["woodLight"]),
    "glow": css(t["glow"]),
    "innerHighlight": css(src["glass"]["innerHighlight"]),
    "shadowTile": src["shadow"]["tile"],
    "fontUi": f'"{src["type"]["ui"]["family"]}", {src["type"]["ui"]["fallback"]}',
    "fontMono": f'"{src["type"]["mono"]["family"]}", {src["type"]["mono"]["fallback"]}',
    "radiusMd": f'{src["radius"]["md"]}px',
    "radiusLg": f'{src["radius"]["lg"]}px',
    "radiusXl": f'{src["radius"]["xl"]}px',
}


def fill(text: str) -> str:
    def sub(m):
        key = m.group(1)
        if key not in tokens:
            sys.exit(f"Abbruch: unbekanntes Token {{{{{key}}}}} in chrome-ext/")
        return tokens[key]
    return re.sub(r"\{\{(\w+)\}\}", sub, text)


# Sprüche + Nudges unter der Suche, eingebettet (Seite lädt nichts aus dem Netz). Frisches Futter
# (Wikipedia, KI-Nudges) kommt zusätzlich über den Host aus scripts/newtab-feed.
def lines(name):
    return [x.strip() for x in (TPL / name).read_text().splitlines() if x.strip() and not x.startswith("#")]


quotes = lines("quotes.txt")
nudges = [dict(zip(("tag", "title", "text"), (p.strip() for p in x.split("|", 2)))) for x in lines("nudges.txt")]
config = {"quotes": quotes, "nudges": nudges, "variant": variant}


def png(size: int) -> bytes:
    """Kleines Erweiterungs-Icon ohne Bibliotheken: Holzkachel mit Glutpunkt, weiche Kanten."""
    wood, ember = rgba(t["wood"])[:3], rgba(t["accent"])[:3]
    r_tile, r_dot = size * 0.22, size * 0.17
    rows = []
    for y in range(size):
        row = bytearray([0])
        for x in range(size):
            px, py = x + 0.5, y + 0.5
            # abgerundetes Quadrat (Abstand zur Kante), 1 px Kantenglättung
            qx = max(abs(px - size / 2) - (size / 2 - r_tile), 0)
            qy = max(abs(py - size / 2) - (size / 2 - r_tile), 0)
            a_tile = max(0.0, min(1.0, r_tile - (qx * qx + qy * qy) ** 0.5 + 0.5))
            d = ((px - size / 2) ** 2 + (py - size / 2) ** 2) ** 0.5
            a_dot = max(0.0, min(1.0, r_dot - d + 0.5))
            c = [w + (e - w) * a_dot for w, e in zip(wood, ember)]
            row += bytes([round(c[0]), round(c[1]), round(c[2]), round(255 * a_tile)])
        rows.append(bytes(row))

    def chunk(kind, data):
        return struct.pack(">I", len(data)) + kind + data + struct.pack(">I", zlib.crc32(kind + data) & 0xFFFFFFFF)
    return (b"\x89PNG\r\n\x1a\n" + chunk(b"IHDR", struct.pack(">IIBBBBB", size, size, 8, 6, 0, 0, 0))
            + chunk(b"IDAT", zlib.compress(b"".join(rows), 9)) + chunk(b"IEND", b""))


# Autofill (iCloud-Passwörter über den Host): nur https + http://localhost, alle Frames (autofill.js lässt
# fremde Iframes selbst aus, background.js prüft die Origin noch einmal)
AUTOFILL_MATCHES = ["https://*/*", "http://localhost/*", "http://127.0.0.1/*", "http://*.localhost/*"]

ext_manifest = {
    "manifest_version": 3,
    "name": "Desktop",
    "version": "0.3.0",
    "description": "New tab page, bridge to Bastian's desktop shell (tabs, agenda, weather) and iCloud password autofill.",
    # öffentlicher Schlüssel -> feste ID (privater Teil wird für entpackte Erweiterungen nicht gebraucht)
    "key": (TPL / "key.pub").read_text().strip(),
    "icons": {"16": "icon16.png", "48": "icon48.png", "128": "icon128.png"},
    "chrome_url_overrides": {"newtab": "newtab.html"},
    "background": {"service_worker": "background.js"},
    "permissions": ["tabs", "nativeMessaging", "storage"],
    "action": {"default_popup": "popup.html", "default_title": "Passwords",
               "default_icon": {"16": "icon16.png", "48": "icon48.png"}},
    "content_scripts": [{
        "matches": AUTOFILL_MATCHES,
        "js": ["autofill-css.js", "autofill.js"],
        "run_at": "document_idle",
        "all_frames": True,
    }],
    "content_security_policy": {"extension_pages": "script-src 'self'; object-src 'self'"},
}

write(EXT / "manifest.json", json.dumps(ext_manifest, indent=2, ensure_ascii=False) + "\n")
write(EXT / "config.js", "// ERZEUGT von theme/gen/chrome.py – nicht von Hand ändern\n"
      f"globalThis.DESKTOP = {json.dumps(config, indent=2, ensure_ascii=False)};\n")
for name in ("newtab.html", "newtab.css", "newtab.js", "background.js", "popup.html", "popup.css", "popup.js",
             "autofill.js"):
    body = (TPL / name).read_text()
    write(EXT / name, fill(body) if name.endswith((".css", ".html")) else body.replace("{{host}}", HOST))
# Stil des Autofill-Menüs als String fürs Content-Script (adoptedStyleSheets im Shadow Root)
write(EXT / "autofill-css.js", "// ERZEUGT von theme/gen/chrome.py aus chrome-ext/autofill.css – nicht von Hand ändern\n"
      f"globalThis.DESKTOP_AUTOFILL_CSS = {json.dumps(fill((TPL / 'autofill.css').read_text()), ensure_ascii=False)};\n")
if wall:
    shutil.copyfile(wall, EXT / "wallpaper.jpg")
    print(f"  {(EXT / 'wallpaper.jpg').relative_to(ROOT)}  <- {wall}")
elif (EXT / "wallpaper.jpg").exists():
    (EXT / "wallpaper.jpg").unlink()
for s in (16, 48, 128):
    p = EXT / f"icon{s}.png"
    p.write_bytes(png(s))
    print(f"  {p.relative_to(ROOT)}")
print(f"  ID: {ext_id()}")
