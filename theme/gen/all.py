#!/usr/bin/env python3
"""Alle Schritt-5-Generatoren nacheinander (KDE, Konsole, Starship, Equibop, Discord, VS Code, Chrome, Vimium C, Thunderbird, Hyprland + Hyprland-Dialoge, Cursor).

Erzeugt theme/out/ und installiert nach ~/.local – aktiviert nichts.
Aufruf aus dem Repo-Root:
  python3 -I theme/gen/all.py [variante] [--nur-out] [--ohne-cursor] [--alles]
--nur-out      nur theme/out/ schreiben, nichts installieren (Cursor entfällt dann auch)
--ohne-cursor  Cursor-Theme nicht neu bauen (dauert ein paar Sekunden)
--alles        zusätzlich design/palette.js, Lockscreen-Theme und Fensterwechsler-Theme (liegen außerhalb von theme/)
"""
import pathlib
import subprocess
import sys

HERE = pathlib.Path(__file__).resolve().parent
ROOT = HERE.parents[1]
args = sys.argv[1:]
variant = [a for a in args if not a.startswith("--")]
passthru = variant + (["--nur-out"] if "--nur-out" in args else [])

steps = ["kde_colors.py", "konsole.py", "starship.py", "kitty.py", "fastfetch.py", "zsh.py", "bat.py", "delta.py", "yazi.py", "lazygit.py", "gtk.py", "equibop.py", "discord.py", "vscode.py", "chrome.py", "vimium.py", "thunderbird.py", "hypr.py", "hyprtoolkit.py", "share_picker.py"]
if "--alles" in args:
    steps += ["preview_palette.py", "lockscreen_theme.py", "switcher.py"]

failed = []
for s in steps:
    # Ältere Generatoren kennen --nur-out nicht
    extra = {"preview_palette.py": [], "lockscreen_theme.py": variant, "switcher.py": variant}.get(s, passthru)
    r = subprocess.run([sys.executable, "-I", str(HERE / s), *extra], cwd=ROOT)
    if r.returncode:
        failed.append(s)

if "--nur-out" not in args and "--ohne-cursor" not in args:
    print("Cursor-Theme:", flush=True)
    r = subprocess.run(["bash", str(ROOT / "design/cursors/build-xcursor.sh")], cwd=ROOT)
    if r.returncode:
        failed.append("build-xcursor.sh")

if failed:
    sys.exit("Fehlgeschlagen: " + ", ".join(failed))
print("Fertig. Aktivieren: siehe theme/README.md")
