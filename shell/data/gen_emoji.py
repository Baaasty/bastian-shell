#!/usr/bin/env python3
"""Erzeugt emoji.json (Zeichen + englischer Name) aus Pythons Unicode-Datenbank.
Aufruf: python3 -I shell/data/gen_emoji.py"""
import json
import pathlib
import unicodedata

RANGES = [(0x1F300, 0x1F5FF), (0x1F600, 0x1F64F), (0x1F680, 0x1F6FF), (0x1F900, 0x1F9FF),
          (0x1FA70, 0x1FAFF), (0x2600, 0x26FF), (0x2700, 0x27BF), (0x1F1E6, 0x1F1FF)]
out = []
for lo, hi in RANGES:
    for cp in range(lo, hi + 1):
        ch = chr(cp)
        name = unicodedata.name(ch, "")
        if not name or unicodedata.category(ch) != "So" or "SKIN TONE" in name or "REGIONAL INDICATOR" in name:
            continue
        out.append([ch, name.lower()])
pathlib.Path(__file__).with_name("emoji.json").write_text(json.dumps(out, ensure_ascii=False))
print(len(out), "Emoji, Unicode", unicodedata.unidata_version)
