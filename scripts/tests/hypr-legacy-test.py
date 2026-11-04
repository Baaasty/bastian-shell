#!/usr/bin/env python3
"""Wächter: keine alten hyprlang-Befehle mehr im Repo (Hyprland läuft mit Lua-Konfiguration: hyprctl dispatch nimmt nur
noch Lua wie hl.dsp.focus({ … }), keyword gibt es nicht mehr – alte Strings laufen still ins Leere).
python3 -I scripts/tests/hypr-legacy-test.py"""
import re
import subprocess
import sys
from pathlib import Path

ROOT = Path(__file__).resolve().parents[2]
# dispatch/keyword gefolgt von einem Wort statt Lua (hl.…, ' oder ", Platzhalter in Kommentaren mit …)
LEGACY = [
    re.compile(r"""hyprctl\b[^\n]*\bdispatch\s+(?!['"]|hl\.|\$|exec\b|<)[a-z]"""),
    re.compile(r"""["']dispatch\s+(?!hl\.)[a-z]"""),
    re.compile(r"""\bhyprctl\b[^\n]*\bkeyword\b"""),
    re.compile(r"""["']keyword\s+[a-z]"""),
    re.compile(r"""Hypr(land)?\.dispatch\(\s*["'](?!hl\.)[a-z]"""),
]
# Dateien, die das alte Format bewusst erklären oder testen
SKIP = {"scripts/tests/hypr-legacy-test.py", "shell/services/Keybinds.qml"}

files = subprocess.run(["git", "ls-files", "shell", "scripts", "hypr", "systemd", "system", "config"],
                       cwd=ROOT, capture_output=True, text=True).stdout.split()
hits = []
for f in files:
    if f in SKIP:
        continue
    try:
        text = (ROOT / f).read_text(errors="ignore")
    except (OSError, IsADirectoryError):
        continue
    for n, line in enumerate(text.splitlines(), 1):
        if any(p.search(line) for p in LEGACY):
            hits.append(f"{f}:{n}: {line.strip()[:120]}")
for h in hits:
    print("FAIL " + h)
print("ok   keine alten dispatch/keyword-Befehle" if not hits else f"{len(hits)} alte Befehle")
sys.exit(1 if hits else 0)
