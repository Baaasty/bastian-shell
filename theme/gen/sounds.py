#!/usr/bin/env python3
"""Kurze, warme Systemklänge (ein dumpfes „Tupf“) -> design/sounds/*.wav (nur stdlib, keine Downloads, keine Lizenzfragen).

Neutral und gedämpft statt hell: ein einzelner tief-mittiger Ton, fast nur Grundton (Obertöne ×2/×3 kaum hörbar),
kurzer weicher Einsatz (5 ms), schnelles Abklingen, doppelter Tiefpass (~1,8 kHz) – klingt wie durch Stoff.
Spitze -1 dBFS, weil tiefe Töne leiser wirken; wie laut es wirklich wird, regelt die Wiedergabe
(config/notifications.json „sound.volume“, Standard 0.7 – am GoXLR-Kanal „System“ hörbar, ohne aufzufallen).
Ausgabe (16 bit, mono, 48 kHz, deterministisch – erneutes Erzeugen ändert die Dateien nicht):
  notify.wav         ein Ton F#4 (370 Hz), 150 ms (normale Meldung)
  notify-urgent.wav  ein Ton A4 (440 Hz), minimal heller und kräftiger, 180 ms (dringende Meldung)
Abspielen: scripts/sounds play [notify|notify-urgent]. Wer sie nutzt: shell/services/Sounds.qml, Sound-Theme „desktop“.
Aufruf aus dem Repo-Root: python3 -I theme/gen/sounds.py
"""
import math
import pathlib
import struct
import wave

ROOT = pathlib.Path(__file__).resolve().parents[2]
OUT = ROOT / "design" / "sounds"
RATE = 48000
PEAK = 0.89  # -1 dBFS

FS4, A4 = 369.99, 440.0


def tone(f0, length, amp=1.0, decay=0.110, bright=1.0):
    """Ein weicher Ton mit Grundton f0 (Hz) als Liste von Samples (float)."""
    n = int(RATE * length)
    # (Frequenz-Faktor, Stärke, Abklingzeit s): Grundton trägt, Obertöne nur als Hauch (bright skaliert sie)
    partials = [
        (1.0, 1.0, decay),
        (2.0, 0.18 * bright, 0.060),
        (3.0, 0.06 * bright, 0.035),
        (4.0, 0.035 * bright, 0.015),
    ]
    out = []
    for i in range(n):
        t = i / RATE
        s = 0.0
        for k, a, tau in partials:
            s += a * math.exp(-t / tau) * math.sin(2 * math.pi * f0 * k * t)
        # weicher Einsatz (Sinus-Rampe 5 ms): kein Klick, kein harter Anschlag
        if t < 0.005:
            s *= math.sin(0.5 * math.pi * t / 0.005)
        out.append(amp * s)
    return out


def finish(samples, cutoff=1800, release=0.03):
    # zweifacher Tiefpass (12 dB/Oktave) bei cutoff, dann weich auf null ausklingen (kein Knacken am Ende)
    lp1 = lp2 = 0.0
    a = 1 - math.exp(-2 * math.pi * cutoff / RATE)
    out = []
    for v in samples:
        lp1 += a * (v - lp1)
        lp2 += a * (lp1 - lp2)
        out.append(lp2)
    r = int(RATE * release)
    for i in range(r):
        out[len(out) - r + i] *= 0.5 * (1 + math.cos(math.pi * i / r))
    return out


def write(name, samples):
    peak = max(abs(v) for v in samples) or 1.0
    data = b"".join(struct.pack("<h", int(round(v / peak * PEAK * 32767))) for v in samples)
    OUT.mkdir(parents=True, exist_ok=True)
    with wave.open(str(OUT / name), "wb") as w:
        w.setnchannels(1)
        w.setsampwidth(2)
        w.setframerate(RATE)
        w.writeframes(data)
    print(f"{OUT.relative_to(ROOT) / name}  {len(samples) / RATE * 1000:.0f} ms")


# normal: F#4, kaum Obertöne, Grundton klingt in ~55 ms ab
write("notify.wav", finish(tone(FS4, 0.15, decay=0.055, bright=0.3), cutoff=1800))
# dringend: gleicher Charakter, minimal heller (A4, etwas mehr Obertöne, Tiefpass 2,2 kHz) und etwas länger – ein Ton
write("notify-urgent.wav", finish(tone(A4, 0.18, decay=0.070, bright=0.6), cutoff=2200))
