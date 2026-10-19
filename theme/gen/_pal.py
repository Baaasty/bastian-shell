"""Gemeinsame Helfer für die Generatoren: palette.json laden, Farben umrechnen, installieren.

Wird von den Generatoren per sys.path eingebunden (sie laufen mit `python3 -I`).
"""
import json
import pathlib
import re
import shutil
import sys

ROOT = pathlib.Path(__file__).resolve().parents[2]
OUT = ROOT / "theme/out"
HOME = pathlib.Path.home()
MARK = "ERZEUGT aus theme/palette.json"


def tilde(path) -> str:
    """Pfad unter ~ als "~/…" (erzeugte Dateien ohne festen Home-Pfad), sonst unverändert."""
    p = pathlib.Path(path)
    try:
        return "~/" + str(p.relative_to(HOME))
    except ValueError:
        return str(p)


def load():
    """palette.json + gewählte Variante (erstes Argument ohne --, sonst defaultTheme)."""
    src = json.loads((ROOT / "theme/palette.json").read_text())
    args = [a for a in sys.argv[1:] if not a.startswith("--")]
    variant = args[0] if args else src["defaultTheme"]
    return src, variant, src["themes"][variant]


def install_wanted() -> bool:
    return "--nur-out" not in sys.argv


def rgba(value: str):
    """'#RRGGBB' oder 'rgba(r, g, b, a)' -> (r, g, b, a)."""
    m = re.fullmatch(r"rgba\(\s*(\d+),\s*(\d+),\s*(\d+),\s*([\d.]+)\s*\)", value)
    if m:
        r, g, b, a = m.groups()
        return int(r), int(g), int(b), float(a)
    h = value.lstrip("#")
    return int(h[0:2], 16), int(h[2:4], 16), int(h[4:6], 16), 1.0


def over(value: str, base: str) -> str:
    """Farbe mit Alpha auf opaken Grund legen -> '#RRGGBB'."""
    r, g, b, a = rgba(value)
    br, bg, bb, _ = rgba(base)
    return hexc(r * a + br * (1 - a), g * a + bg * (1 - a), b * a + bb * (1 - a))


def mix(a: str, b: str, t: float) -> str:
    """Lineare Mischung, t=0 -> a, t=1 -> b."""
    ar, ag, ab, _ = rgba(a)
    br, bg, bb, _ = rgba(b)
    return hexc(ar + (br - ar) * t, ag + (bg - ag) * t, ab + (bb - ab) * t)


def hexc(r, g, b) -> str:
    return "#{:02X}{:02X}{:02X}".format(*(max(0, min(255, round(c))) for c in (r, g, b)))


def alpha(value: str, a: float) -> str:
    """Opake Farbe mit Alpha als '#RRGGBBAA' (VS Code)."""
    r, g, b, _ = rgba(value)
    return hexc(r, g, b) + "{:02X}".format(round(a * 255))


def hex8(value: str) -> str:
    """rgba(...) -> '#RRGGBBAA', Hex bleibt Hex."""
    r, g, b, a = rgba(value)
    return hexc(r, g, b) + ("" if a >= 1 else "{:02X}".format(round(a * 255)))


def kde(value: str) -> str:
    """'#RRGGBB' -> 'r,g,b' (KDE/Konsole)."""
    r, g, b, _ = rgba(value)
    return f"{r},{g},{b}"


def contrast(fg: str, bg: str) -> float:
    """WCAG-Kontrast zweier opaker Farben."""
    def lum(c):
        ch = []
        for v in rgba(c)[:3]:
            v /= 255
            ch.append(v / 12.92 if v <= 0.03928 else ((v + 0.055) / 1.055) ** 2.4)
        return 0.2126 * ch[0] + 0.7152 * ch[1] + 0.0722 * ch[2]
    l1, l2 = sorted((lum(fg), lum(bg)), reverse=True)
    return (l1 + 0.05) / (l2 + 0.05)


def write(path: pathlib.Path, text: str):
    path.parent.mkdir(parents=True, exist_ok=True)
    path.write_text(text)
    print(f"  {path.relative_to(ROOT)}")


def install(src: pathlib.Path, dst: pathlib.Path):
    """Datei oder Ordner kopieren. Fremde Dateien (ohne MARK) werden nie überschrieben."""
    if dst.exists():
        probe = dst / "package.json" if dst.is_dir() else dst
        if not probe.exists() or MARK not in probe.read_text(errors="ignore"):
            sys.exit(f"Abbruch: {dst} existiert und stammt nicht von hier.")
        shutil.rmtree(dst) if dst.is_dir() else dst.unlink()
    dst.parent.mkdir(parents=True, exist_ok=True)
    shutil.copytree(src, dst) if src.is_dir() else shutil.copy2(src, dst)
    print(f"  -> {dst}")
