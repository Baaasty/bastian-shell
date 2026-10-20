#!/usr/bin/env python3
"""theme/palette.json -> Icon-Theme "Desktop" (Ordner in Holzbraun, Rest = Breeze Dark).

Warum: Breeze färbt die bunten Ordner (32/48/64/96 px) mit der Klasse ColorScheme-Accent,
also mit dem Akzent des Farbschemas – bei uns Glutrot. Den Akzent im Farbschema zu ändern,
würde die ganze UI treffen. Darum ein abgeleitetes Theme: Spiegel von Breeze Dark (Symlinks),
in dem nur diese Ordner-SVGs durch Kopien mit fester Holzfarbe ersetzt sind. Kleine Ordner (16/22/24) und
*-symbolic sind in Breeze einfarbig (Textfarbe = Creme) und bleiben, wie sie sind.

Farben (aus der Variante):
  Vorderseite = woodLight, Rückseite/Lasche = Breezes 33-%-Schatten darauf (landet nahe wood)
  Symbol      = Creme (Textfarbe, wie Breeze) · mit --glut-symbol in accentText (kleiner Glut-Akzent)
Bunte Breeze-Varianten (folder-red, folder-blue …) haben feste Farben und bleiben unberührt.

Ort-Bilder ohne Akzent-Klasse (Schreibtisch = Monitor in Türkis/Pink, Papierkorb = Blaugrau) haben feste
Farben. Ihre Hex-Werte werden nach Helligkeit auf Palette-Rampen gelegt: Rot/Pink -> Glut, andere bunte
Töne -> Holz, Grau -> Braun bis Creme. App-Icons und das KDE-Logo (start-here-kde) bleiben, wie sie sind.

Ausgabe: theme/out/icons/Desktop-Icons/ (gitignored, Symlinks + ~200 SVGs) -> ~/.local/share/icons/Desktop-Icons/
Ordnername ≠ "Desktop", weil ~/.local/share/icons/Desktop schon das Cursor-Theme ist.
Aktiviert nichts. Aufruf aus dem Repo-Root:
  python3 -I theme/gen/icons.py [variante] [--nur-out] [--glut-symbol]
Aktivieren: /usr/libexec/plasma-changeicons Desktop-Icons · zurück: … breeze-dark
"""
import colorsys
import configparser
import os
import pathlib
import re
import shutil
import subprocess
import sys

sys.path.insert(0, str(pathlib.Path(__file__).resolve().parent))
from _pal import HOME, MARK, OUT, ROOT, install_wanted, load, mix, rgba  # noqa: E402

BASE = pathlib.Path("/usr/share/icons/breeze-dark")
NAME = "Desktop-Icons"
COLOR_SIZES = {"32", "48", "64", "96"}  # nur dort sind Breeze-Ordner farbig
ILLUSTRATED = {"user-desktop", "user-trash", "user-trash-full"}  # Ort-Bilder mit festen Farben

src, variant, t = load()
front = t["woodLight"]
symbol = t["accentText"] if "--glut-symbol" in sys.argv else None

ELEMENT = re.compile(r"<(?:path|rect|circle|ellipse|polygon|g)\b[^>]*>")


def recolor(svg: str):
    """Akzent-Flächen -> feste Holzfarbe. None, wenn nichts zu tun ist."""
    hit = False

    def fix(m):
        nonlocal hit
        el = m.group(0)
        if 'class="ColorScheme-Accent"' in el and "fill:currentColor" in el:
            hit = True
            el = el.replace("fill:currentColor", f"fill:{front}").replace(' class="ColorScheme-Accent"', "")
        elif symbol and 'class="ColorScheme-Text"' in el and re.search(r"fill:currentColor;fill-opacity:0\.6", el):
            # Symbol auf dem Ordner (Dokument, Note, Bild …); der 20-%-Schatten unten bleibt
            el = re.sub(r"fill:currentColor;fill-opacity:0\.6", f"fill:{symbol};fill-opacity:0.9", el)
            el = el.replace(' class="ColorScheme-Text"', "")
        return el

    out = ELEMENT.sub(fix, svg)
    if not hit:
        return None
    return marked(out)


def marked(svg: str) -> str:
    return svg.replace("<svg ", f"<!-- {MARK} ({variant}) · Basis: Breeze Dark, LGPL-3.0 -->\n<svg ", 1)


# Rampen (Helligkeit 0…1 -> Palette-Ton), dazwischen gemischt
NEUTRAL = [(0.0, t["bgBottom"]), (0.25, t["surface"]), (0.40, t.get("surfaceRaised", t["surface"])),
           (0.60, t["textFaint"]), (0.78, t["textMuted"]), (1.0, t["cream"])]
WOOD = [(0.0, t["bgBottom"]), (0.30, t["wood"]), (0.55, t["woodLight"]), (0.85, t["textMuted"]), (1.0, t["cream"])]
EMBER = [(0.0, t["accentFill"]), (0.40, t["accentPressed"]), (0.55, t["accent"]), (0.80, t["accentText"]),
         (1.0, t["cream"])]


def on_ramp(ramp, v: float) -> str:
    for (p0, c0), (p1, c1) in zip(ramp, ramp[1:]):
        if v <= p1:
            return mix(c0, c1, (v - p0) / (p1 - p0) if p1 > p0 else 0)
    return ramp[-1][1]


def remap(svg: str) -> str:
    """Feste Hex-Farben eines Ort-Bildes auf Palette-Rampen legen (Helligkeit bleibt, Farbton wird warm)."""
    def fix(m):
        r, g, b, _ = rgba(m.group(0))
        h, li, s = colorsys.rgb_to_hls(r / 255, g / 255, b / 255)
        if s < 0.30 or li < 0.08 or li > 0.95:
            return on_ramp(NEUTRAL, li)
        return on_ramp(EMBER if h < 0.06 or h > 0.75 else WOOD, li)
    return re.sub(r"#[0-9a-fA-F]{6}\b", fix, svg)


# 1) Ziel-Dateien: echte SVGs in places/<farbige Größe> mit Akzent-Fläche, dazu die Ort-Bilder
targets = {}
for d in sorted(COLOR_SIZES):
    for f in sorted((BASE / "places" / d).iterdir()):
        if f.is_symlink() or f.suffix != ".svg":
            continue
        text = f.read_text()
        illustrated = f.stem in ILLUSTRATED
        if illustrated:
            text = remap(text)  # vor recolor, sonst würde das Holz der Akzent-Fläche mit umgelegt
        new = recolor(text) or (marked(text) if illustrated else None)
        if new:
            targets[f.resolve()] = new

# 2) Breeze Dark komplett spiegeln. Nötig, weil KIconLoader pro Theme erst den vollen Namen und dann
#    gekürzte Namen sucht ("folder-new" -> "folder"), bevor er ins Eltern-Theme geht: Ein schlankes
#    Theme mit nur "folder" würde folder-new, folder-red, folder-symbolic … überdecken.
#    Echte Kopien statt Symlinks (~40 MB): Flatpak-Apps (Thunderbird …) und die Ubuntu-Box sehen
#    /usr/share/icons des Systems nicht – absolute Links zeigten dort ins Leere, Fensterknöpfe und
#    Icons fehlten. Relative Verzeichnis-Links (16@2x -> 16) bleiben relativ.
def copy_deref(src: pathlib.Path, dst: pathlib.Path) -> None:
    """Verzeichnis kopieren, Symlinks aufgelöst (shutil.copytree prüft relative Links gegen das
    Arbeitsverzeichnis und überspringt sie mit ignore_dangling_symlinks fälschlich)."""
    dst.mkdir(parents=True, exist_ok=True)
    for e in src.iterdir():
        real = e.resolve()
        if real.is_dir():
            copy_deref(real, dst / e.name)
        elif real.is_file():
            shutil.copy2(real, dst / e.name)


ini = configparser.ConfigParser(interpolation=None, strict=False)
ini.optionxform = str
ini.read(BASE / "index.theme")
head = ini["Icon Theme"]
all_dirs = [d for key in ("Directories", "ScaledDirectories") for d in head.get(key, "").split(",") if d]

outdir = OUT / "icons" / NAME
if outdir.exists():
    shutil.rmtree(outdir)
outdir.mkdir(parents=True)
copies = 0
for d in all_dirs:
    src_dir, dst_dir = BASE / d, outdir / d
    if not src_dir.exists() or dst_dir.exists() or dst_dir.is_symlink():
        continue
    dst_dir.parent.mkdir(parents=True, exist_ok=True)
    if src_dir.is_symlink() and not os.path.isabs(os.readlink(src_dir)):
        dst_dir.symlink_to(os.readlink(src_dir))  # zeigt aufs eigene Geschwister
        continue
    entries = sorted(src_dir.iterdir())
    if not any(e.resolve() in targets for e in entries):
        copy_deref(src_dir.resolve(), dst_dir)
        continue
    dst_dir.mkdir()
    for e in entries:
        real = e.resolve()
        if real in targets:
            (dst_dir / e.name).write_text(targets[real])
            copies += 1
        elif real.exists():
            shutil.copy2(real, dst_dir / e.name)

# 3) index.theme = Breeze Dark 1:1, nur Kopf (Name, Comment, Inherits) ersetzt
lines, in_head = [f"# {MARK} ({variant}) – theme/gen/icons.py, nicht von Hand ändern"], False
for line in (BASE / "index.theme").read_text().splitlines():
    if line.startswith("["):
        in_head = line.strip() == "[Icon Theme]"
        lines.append(line)
        if in_head:
            lines += ["Name=Desktop", "Comment=Desktop – Breeze Dark mit holzbraunen Ordnern",
                      "Inherits=breeze-dark,breeze,hicolor"]
        continue
    if in_head and re.match(r"(Name|Comment|Inherits)(\[|=)", line):
        continue
    lines.append(line)
(outdir / "index.theme").write_text("\n".join(lines) + "\n")

gi = OUT / "icons" / ".gitignore"
if not gi.exists():
    gi.write_text("# Erzeugt von theme/gen/icons.py (Kopie von Breeze Dark + Ordner-SVGs), nicht im Repo\n*\n!.gitignore\n")

print(f"  {outdir.relative_to(ROOT)}  ({len(targets)} Ordner-/Ort-SVGs, {copies} Kopien, "
      f"Holz {front}" + (f", Symbol {symbol})" if symbol else ")"))

if install_wanted():
    dst = HOME / ".local/share/icons" / NAME
    if dst.exists():
        probe = dst / "index.theme"
        if not probe.exists() or MARK not in probe.read_text(errors="ignore"):
            sys.exit(f"Abbruch: {dst} existiert und stammt nicht von hier.")
        shutil.rmtree(dst)
    shutil.copytree(outdir, dst, symlinks=True)
    # GTK-Cache (sonst durchsucht GTK alle Ordner); frische mtime -> KIconLoader verwirft seinen Cache
    gtk = shutil.which("gtk-update-icon-cache")
    if gtk:
        subprocess.run([gtk, "--force", "--quiet", str(dst)], check=False)
    os.utime(dst)
    print(f"  -> {dst}")
