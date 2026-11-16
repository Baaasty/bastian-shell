#!/usr/bin/env python3
"""Test für scripts/update-traps: Fallen nur bei echten Abweichungen melden, fehlende Werte überspringen (Messwerte per Umgebung):
python3 -I scripts/tests/update-traps-test.py"""
import os
import subprocess
import sys

path = os.path.join(os.path.dirname(__file__), "..", "update-traps")

fails = 0


def check(name, got, want):
    global fails
    ok = got == want
    fails += not ok
    print(("ok   " if ok else "FAIL ") + name + ("" if ok else f"  got={got!r} want={want!r}"))


SAME = {
    "UPDATE_TRAPS_NVIDIA_LOADED": "620.70.06",
    "UPDATE_TRAPS_NVIDIA_INSTALLED": "620.70.06",
    "UPDATE_TRAPS_KERNEL_RUNNING": "7.3.3-200.fc44.x86_64",
    "UPDATE_TRAPS_KERNEL_LATEST": "7.3.3-200.fc44.x86_64",
    "UPDATE_TRAPS_THEME_STALE": "0",
}


def run(**over):
    env = {**os.environ, **SAME, **over}
    r = subprocess.run([path, "--print"], env=env, capture_output=True, text=True)
    return r.returncode, r.stdout


check("alles gleich", run(), (0, ""))

code, out = run(UPDATE_TRAPS_NVIDIA_LOADED="615.12")
check("treiber exit", code, 0)
check("treiber meldung", out.startswith("Neustart nötig: Treiber aktualisiert (läuft NVIDIA 615.12, installiert NVIDIA 620.70.06)"), True)

code, out = run(UPDATE_TRAPS_KERNEL_LATEST="7.3.4-200.fc44.x86_64")
check("kernel meldung", "Kernel aktualisiert (läuft Kernel 7.3.3-200.fc44.x86_64, installiert Kernel 7.3.4-200.fc44.x86_64)" in out, True)
check("kernel eine zeile", out.count("\n"), 1)

code, out = run(UPDATE_TRAPS_NVIDIA_LOADED="615.12", UPDATE_TRAPS_KERNEL_LATEST="7.3.4-200.fc44.x86_64")
check("beides in einer meldung", out.startswith("Neustart nötig: Treiber/Kernel aktualisiert"), True)
check("beides eine zeile", out.count("\n"), 1)

code, out = run(UPDATE_TRAPS_THEME_STALE="1")
check("theme meldung", out, "Login-Bildschirm: Plasma wurde aktualisiert, eigenes Theme ist aus. "
      "Neu einspielen: scripts/loginscreen apply\n")

check("treiber nicht geladen", run(UPDATE_TRAPS_NVIDIA_LOADED=""), (0, ""))
check("treiber nicht installiert", run(UPDATE_TRAPS_NVIDIA_INSTALLED=""), (0, ""))
check("kernel unbekannt", run(UPDATE_TRAPS_KERNEL_LATEST="", UPDATE_TRAPS_KERNEL_RUNNING="7.2.1"), (0, ""))

sys.exit(1 if fails else 0)
