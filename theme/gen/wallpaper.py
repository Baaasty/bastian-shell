#!/usr/bin/env python3
"""theme/palette.json -> ruhige Wallpaper für die drei Monitore.

Ein Panorama 6400x1440 (links 1920 | Mitte 2560 | rechts 1920), daraus die Zuschnitte wie bei
design/claude-design/wallpaper/ (Seitenmonitore vertikal mittig, y 180–1260):
  theme/out/wallpaper/<variante>/<motiv>/desktop-{links,mitte,rechts}-*.jpg + desktop-panorama-6400x1440.jpg
  design/wallpapers/<variante>-<motiv>-{panorama,mitte}.jpg   (kleine Vorschauen für design/wallpapers.html)

Motive (nur Palettenfarben und Mischungen daraus, Akzent nur als Hauch):
  licht   weicher Verlauf, diffuses Abendlicht von oben links, feines Korn
  huegel  sanfte Hügelschichten in Holz-/Taupe-Tönen, Dunst am Horizont, Mitte flach
  holz    sehr dezente Holzmaserung unter Lampenlicht

Aufruf aus dem Repo-Root:
  python3 -I theme/gen/wallpaper.py [variante] [--motif=licht,huegel] [--nur-vorschau]
Ohne Variante: defaultTheme. Ohne --motif: alle Motive. Setzen: scripts/wallpaper set --variant dusk --motif huegel
"""
import json
import math
import pathlib
import random
import sys

sys.path.insert(0, str(pathlib.Path(__file__).resolve().parent))
from _pal import OUT, ROOT, contrast, load, mix, rgba  # noqa: E402

from PIL import Image, ImageDraw, ImageFilter, ImageMath  # noqa: E402

W, H = 6400, 1440
SIDE_Y = 360  # Seitenmonitore unten bündig wie in KDE (kscreen: y=360)
CROPS = {
    "links": ((0, SIDE_Y, 1920, SIDE_Y + 1080), "desktop-links-1920x1080.jpg"),
    "mitte": ((1920, 0, 4480, 1440), "desktop-mitte-2560x1440.jpg"),
    "rechts": ((4480, SIDE_Y, 6400, SIDE_Y + 1080), "desktop-rechts-1920x1080.jpg"),
}
PREVIEW = ROOT / "design/wallpapers"
INFO = {
    "licht": "Weicher Verlauf, diffuses Abendlicht von oben links, feines Korn",
    "huegel": "Sanfte Hügelschichten in Holz-/Taupe-Tönen, Dunst am Horizont, Mitte flach",
    "holz": "Sehr dezente Holzmaserung unter Lampenlicht",
}


# ---------- Werkzeug: drei Float-Kanäle, damit erst ganz am Ende quantisiert wird (kein Banding) ----------

def rgb(c):
    return rgba(c)[:3]


def smooth(t):
    t = max(0.0, min(1.0, t))
    return t * t * (3 - 2 * t)


def lift(t, k):
    """Mischanteil für die Grundtöne; sehr dunkle Paletten (ember) werden etwas angehoben, damit's nicht nach Gaming-Schwarz aussieht."""
    lum = (contrast(t["bg"], "#000000") * 0.05) - 0.05     # relative Luminanz von bg
    return min(0.9, k * max(1.0, min(1.6, 1 + (0.02 - lum) / 0.02 * 0.6)))


def column(stops):
    """Senkrechter Verlauf [(v, farbe), ...] -> 3 F-Kanäle W×H (weich zwischen den Stops)."""
    stops = sorted(stops)
    chans = [[], [], []]
    for y in range(H):
        v = (y + 0.5) / H
        if v <= stops[0][0]:
            c = rgb(stops[0][1])
        elif v >= stops[-1][0]:
            c = rgb(stops[-1][1])
        else:
            for (v0, c0), (v1, c1) in zip(stops, stops[1:]):
                if v0 <= v <= v1:
                    t = smooth((v - v0) / (v1 - v0))
                    a, b = rgb(c0), rgb(c1)
                    c = [a[i] + (b[i] - a[i]) * t for i in range(3)]
                    break
        for i in range(3):
            chans[i].append(float(c[i]))
    out = []
    for ch in chans:
        im = Image.new("F", (1, H))
        im.putdata(ch)
        out.append(im.resize((W, H), Image.NEAREST))
    return out


def field(fn, sw=400, sh=90):
    """Glattes Feld fn(x, y) in Panorama-Pixeln, klein gerechnet und bikubisch hochskaliert (F, ~0..1)."""
    im = Image.new("F", (sw, sh))
    im.putdata([fn((i + 0.5) * W / sw, (j + 0.5) * H / sh) for j in range(sh) for i in range(sw)])
    return im.resize((W, H), Image.BICUBIC)


def blob(cx, cy, rx, ry):
    """Gauß-Lichtfleck (Mitte cx/cy, Radien rx/ry in Panorama-Pixeln)."""
    return field(lambda x, y: math.exp(-((x - cx) / rx) ** 2 - ((y - cy) / ry) ** 2))


def paint(chs, color, mask, op=1.0):
    """Farbe (Hex oder 3 F-Kanäle) mit Maske (F 0..1) und Deckkraft über chs legen."""
    out = []
    for i, ch in enumerate(chs):
        if isinstance(color, str):
            k = float(rgb(color)[i])
            out.append(ImageMath.lambda_eval(lambda a, k=k: a["c"] + (k - a["c"]) * a["m"] * op, c=ch, m=mask))
        else:
            out.append(ImageMath.lambda_eval(lambda a: a["c"] + (a["k"] - a["c"]) * a["m"] * op, c=ch, k=color[i], m=mask))
    return out


def shade(chs, mask, amount):
    """Multiplikativ abdunkeln (Maserung): c * (1 - amount * mask)."""
    return [ImageMath.lambda_eval(lambda a: a["c"] * (1 - a["m"] * amount), c=ch, m=mask) for ch in chs]


def gauss(w, h, seed):
    """Reproduzierbares Normal-Rauschen (F, Mittel 0, Sigma 1)."""
    rnd = random.Random(seed)
    im = Image.new("F", (w, h))
    im.putdata([rnd.gauss(0, 1) for _ in range(w * h)])
    return im


def tiled(tile):
    im = Image.new("F", (W, H))
    for x in range(0, W, tile.width):
        for y in range(0, H, tile.height):
            im.paste(tile, (x, y))
    return im


def finish(chs, grain=1.4, seed=7):
    """Feines Filmkorn (gleich für alle Kanäle) + Dither, dann auf 8 Bit runden."""
    noise = tiled(gauss(509, 487, seed))  # krumme Kachelmaße -> keine sichtbare Wiederholung
    out = []
    for ch in chs:
        out.append(ImageMath.lambda_eval(lambda a: a["c"] + a["n"] * grain + 0.5, c=ch, n=noise).convert("L"))
    return Image.merge("RGB", out)


def noise_grid(gw, gh, seed):
    """Zufallsraster gw×gh (F, 0..1) – hochskaliert ergibt das glattes Rauschen."""
    rnd = random.Random(seed)
    im = Image.new("F", (gw, gh))
    im.putdata([rnd.random() for _ in range(gw * gh)])
    return im


# ---------- Motive ----------

def motif_licht(t):
    chs = column([
        (0.0, mix(t["bg"], t["wood"], lift(t, 0.20))),
        (0.55, mix(t["bg"], t["wood"], lift(t, 0.07))),
        (1.0, mix(t["bgBottom"], t["bg"], 0.6)),
    ])
    light = mix(t["woodLight"], t["cream"], 0.22)
    chs = paint(chs, light, blob(0.18 * W, -0.35 * H, 0.85 * W, 1.25 * H), 0.36)   # Abendlicht oben links, breit
    chs = paint(chs, t["cream"], blob(0.55 * W, 0.00 * H, 0.80 * W, 0.90 * H), 0.05)  # Fülllicht
    chs = paint(chs, t["accent"], blob(0.10 * W, 0.10 * H, 0.22 * W, 0.45 * H), 0.04)  # Hauch Dämmerung
    chs = paint(chs, t["bgBottom"], blob(1.00 * W, 1.30 * H, 0.40 * W, 0.65 * H), 0.25)  # Ecke unten rechts ruhig
    return finish(chs)


def colfn(fn):
    """Senkrechtes Profil fn(y) -> F-Bild W×H."""
    im = Image.new("F", (1, H))
    im.putdata([float(fn(y + 0.5)) for y in range(H)])
    return im.resize((W, H), Image.NEAREST)


def motif_huegel(t):
    haze = mix(t["bg"], t["woodLight"], lift(t, 0.34))
    chs = column([
        (0.0, mix(t["bg"], t["wood"], lift(t, 0.18))),
        (0.35, mix(t["bg"], t["woodLight"], lift(t, 0.20))),
        (0.60, haze),
        (1.0, haze),
    ])
    chs = paint(chs, t["cream"], blob(0.50 * W, 0.58 * H, 0.60 * W, 0.30 * H), 0.07)   # heller Dunst
    chs = paint(chs, mix(t["accent"], t["cream"], 0.35), blob(0.50 * W, 0.62 * H, 0.30 * W, 0.12 * H), 0.06)  # Nachglühen, kaum

    near = mix(t["wood"], t["bgBottom"], 0.74)
    far = mix(haze, near, 0.22)
    rnd = random.Random(23)
    layers = 5
    for i in range(layers):
        f = i / (layers - 1)
        top = mix(far, near, f ** 0.9)
        base = 0.66 + 0.07 * i                      # Grundlinie (v), Mitte bleibt flach und tief
        # breite Kuppen, abwechselnd eher links/rechts, nie in der Mitte
        humps = []
        for k in range(3):
            side = (k + i) % 2
            c = rnd.uniform(0.02, 0.30) if side == 0 else rnd.uniform(0.70, 0.98)
            humps.append((c, rnd.uniform(0.10, 0.22), rnd.uniform(0.07, 0.13) + 0.025 * i))
        ph = rnd.uniform(0, 6.3)
        pts, vmin = [], 1.0
        for x in range(0, W + 9, 8):
            u = x / W
            v = base - sum(h * math.exp(-((u - c) / w) ** 2) for c, w, h in humps)
            v -= 0.010 * math.sin(2 * math.pi * 3.1 * u + ph)
            vmin = min(vmin, v)
            pts.append((x, v * H))
        mask = Image.new("L", (W, H), 0)
        ImageDraw.Draw(mask).polygon(pts + [(W + 8, H + 40), (-8, H + 40)], fill=255)
        mask = mask.filter(ImageFilter.GaussianBlur(10 - 1.8 * i)).convert("F")
        mask = ImageMath.lambda_eval(lambda a: a["m"] / 255, m=mask)
        if i < layers - 1:   # unten heller in den Dunst -> nächste Schicht hebt sich weich ab
            col = column([(vmin, top), (min(1.0, vmin + 0.30), mix(top, haze, 0.45))])
        else:                # vorderste Schicht: Boden, nach unten dunkler
            col = column([(vmin, top), (1.0, mix(top, t["bgBottom"], 0.40))])
        chs = paint(chs, col, mask)
    return finish(chs, grain=1.3)


def motif_holz(t):
    chs = column([
        (0.0, mix(t["bg"], t["wood"], lift(t, 0.32))),
        (0.6, mix(t["bg"], t["wood"], lift(t, 0.20))),
        (1.0, mix(t["bgBottom"], t["wood"], lift(t, 0.12))),
    ])
    chs = paint(chs, mix(t["woodLight"], t["cream"], 0.15), blob(0.20 * W, -0.30 * H, 0.85 * W, 1.20 * H), 0.28)
    chs = paint(chs, t["bgBottom"], blob(1.00 * W, 1.25 * H, 0.45 * W, 0.65 * H), 0.25)

    # Breite waagerechte Bretter (4 auf der Mitte), Maserung klein gerechnet (1/4) und hochskaliert
    board = H // 4
    rnd = random.Random(17)
    nb = H // board + 1
    offs = [rnd.uniform(0, 40) for _ in range(nb)]
    tone = [rnd.uniform(-1, 1) for _ in range(nb)]
    sw, sh = W // 4, H // 4
    warp = noise_grid(6, 10, 3).resize((sw, sh), Image.BICUBIC).load()      # lange, flache Wellen
    fine = noise_grid(14, 40, 5).resize((sw, sh), Image.BICUBIC).load()
    fade = noise_grid(10, 60, 8).resize((sw, sh), Image.BICUBIC).load()    # manche Linien verblassen
    lines = 15  # Linien pro Brett
    vals = []
    for j in range(sh):
        y = (j + 0.5) * 4
        b = int(y // board)
        v = (y - b * board) / board
        for i in range(sw):
            ph = v * lines + offs[b] + 3.0 * warp[i, j] + 0.6 * fine[i, j]
            ring = (0.5 + 0.5 * math.cos(2 * math.pi * ph)) ** 8
            vals.append(ring * (0.35 + 0.65 * fade[i, j]) + 0.25 * fine[i, j])
    g = Image.new("F", (sw, sh))
    g.putdata(vals)
    grain = g.resize((W, H), Image.BICUBIC)
    fib = gauss(W // 48, H, 9).resize((W, H), Image.BICUBIC)               # Fasern, waagerecht gestreckt

    def seam(y):  # weiche Fuge zwischen den Brettern (oben keine)
        d = min(abs(y - k * board) for k in range(1, nb))
        return math.exp(-(d / 3.0) ** 2)
    calm = colfn(lambda y: 0.45 + 0.55 * smooth(y / (0.10 * H)))           # hinter der Bar ruhiger
    grain = ImageMath.lambda_eval(lambda a: a["g"] * a["k"], g=grain, k=calm)
    chs = shade(chs, grain, 0.085)
    chs = shade(chs, fib, 0.006)
    chs = shade(chs, colfn(lambda y: tone[int(y // board)]), 0.025)        # Bretter leicht verschieden
    chs = shade(chs, colfn(seam), 0.16)
    chs = paint(chs, t["cream"], colfn(lambda y: seam(y - 4)), 0.025)     # Lichtkante unter der Fuge
    return finish(chs, grain=1.2)


MOTIFS = {"licht": motif_licht, "huegel": motif_huegel, "holz": motif_holz}


# ---------- Ausgabe ----------

def save_previews(pano: Image.Image, name: str):
    PREVIEW.mkdir(parents=True, exist_ok=True)
    pano.resize((1600, 360), Image.LANCZOS).save(PREVIEW / f"{name}-panorama.jpg", quality=86)
    pano.crop(CROPS["mitte"][0]).resize((1280, 720), Image.LANCZOS).save(PREVIEW / f"{name}-mitte.jpg", quality=88)


def write_list():
    """design/wallpapers/list.js: welche Vorschauen es gibt (für die statische Vergleichsseite)."""
    items = []
    for p in sorted(PREVIEW.glob("*-mitte.jpg")):
        stem = p.name[: -len("-mitte.jpg")]
        if stem == "bisher":
            continue
        variant, _, motif = stem.partition("-")
        items.append({"variant": variant, "motif": motif, "info": INFO.get(motif, "")})
    order = list(MOTIFS)
    items.sort(key=lambda d: (order.index(d["motif"]) if d["motif"] in order else 99, d["variant"]))
    (PREVIEW / "list.js").write_text(
        "// ERZEUGT von theme/gen/wallpaper.py – nicht von Hand ändern.\n"
        "window.WALLPAPERS = " + json.dumps(items, indent=2, ensure_ascii=False) + ";\n")
    print(f"  {(PREVIEW / 'list.js').relative_to(ROOT)}")


def main():
    try:
        _, variant, t = load()
    except KeyError as e:
        sys.exit(f"Unbekannte Variante: {e}")
    wanted = list(MOTIFS)
    for a in sys.argv[1:]:
        if a.startswith("--motif="):
            wanted = [m for m in a.split("=", 1)[1].split(",") if m]
    bad = [m for m in wanted if m not in MOTIFS]
    if bad:
        sys.exit(f"Unbekanntes Motiv: {', '.join(bad)} (da: {', '.join(MOTIFS)})")
    only_preview = "--nur-vorschau" in sys.argv

    # Vergleich: bisheriges Wallpaper (Claude Design) einmalig als Vorschau
    old = ROOT / "design/claude-design/wallpaper/desktop-panorama-6400x1440.jpg"
    if old.exists() and not (PREVIEW / "bisher-mitte.jpg").exists():
        save_previews(Image.open(old).convert("RGB"), "bisher")

    for m in wanted:
        print(f"{variant}/{m} …")
        pano = MOTIFS[m](t)
        save_previews(pano, f"{variant}-{m}")
        if not only_preview:
            out = OUT / "wallpaper" / variant / m
            out.mkdir(parents=True, exist_ok=True)
            pano.save(out / "desktop-panorama-6400x1440.jpg", quality=93, subsampling=0)
            for box, fname in CROPS.values():
                pano.crop(box).save(out / fname, quality=94, subsampling=0)
            print(f"  {out.relative_to(ROOT)}/")
    write_list()


if __name__ == "__main__":
    main()
