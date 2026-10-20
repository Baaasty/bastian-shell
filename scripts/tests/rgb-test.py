#!/usr/bin/env python3
"""Test für scripts/rgb ohne echtes openrgb (Konfig/Zustand in einem Temp-Ordner): python3 -I scripts/tests/rgb-test.py"""
import contextlib
import importlib.machinery
import importlib.util
import io
import json
import os
import sys
import tempfile
from pathlib import Path

path = os.path.join(os.path.dirname(__file__), "..", "rgb")
loader = importlib.machinery.SourceFileLoader("rgb", path)
spec = importlib.util.spec_from_loader("rgb", loader)
rgb = importlib.util.module_from_spec(spec)
loader.exec_module(rgb)

fails = 0


def check(name, got, want):
    global fails
    ok = got == want
    fails += not ok
    print(("ok   " if ok else "FAIL ") + name + ("" if ok else f"  got={got!r} want={want!r}"))


tmp = Path(tempfile.mkdtemp(prefix="rgb-test-"))
rgb.CONFIG = tmp / "rgb.json"
rgb.STATE = tmp / "rgb-state.json"
rgb.SLOW = tmp / "rgb-slow.json"
rgb.RUN = tmp
rgb.LOCK = tmp / "lock"
rgb.PALETTE = tmp / "palette.json"
rgb.PALETTE.write_text(json.dumps({"defaultTheme": "t", "themes": {"t": {
    "accent": "#DB6B4C", "error": "#E0604F", "warning": "#E0AE55", "woodLight": "#A07C5C", "success": "#A3B083"}}}))
rgb.CONFIG.write_text(json.dumps({"skip": ["G502"]}))

DEVICES = [{"index": 0, "name": "MSI B550", "type": "Motherboard", "modes": ["Off", "Static"]},
           {"index": 1, "name": "NZXT Smart Device V2", "type": "LED Strip", "modes": ["Fixed"]},
           {"index": 2, "name": "Logitech G502 X PLUS", "type": "Mouse", "modes": ["Direct"]}]
calls = []


class Done:
    returncode = 0
    stdout = ""
    stderr = ""


rgb.scan = lambda: DEVICES
rgb.openrgb_bin = lambda: "/usr/bin/openrgb"


def fake_run(args, timeout=rgb.TIMEOUT):
    calls.append(args)
    return Done()


rgb.run_openrgb = fake_run


def run(*argv):
    calls.clear()
    out = io.StringIO()
    with contextlib.redirect_stdout(out):
        rc = rgb.main(list(argv))
    return rc, out.getvalue()


# status --json: ohne Scan, Standard accent
rgb.scan = lambda: (_ for _ in ()).throw(AssertionError("status --json darf nicht scannen"))
rc, out = run("status", "--json")
st = json.loads(out)
check("status json", (rc, st["on"], st["color"], st["led"], st["last"]["running"]), (0, True, "accent", "#FF3700", False))
check("status tokens", [t["name"] for t in st["tokens"]], list(rgb.TOKENS))
rgb.scan = lambda: DEVICES

# set warning: gemerkt (skip bleibt), gesetzt mit der LED-Farbe, Zustand 2 von 2
rc, out = run("set", "warning")
cfg = json.loads(rgb.CONFIG.read_text())
check("set merkt", (rc, cfg["color"], cfg["on"], cfg["skip"]), (0, "warning", True, ["G502"]))
led = rgb.led_color("E0AE55")
check("set Aufruf", calls[0], ["--device", "0", "--mode", "Static", "--color", led, "--device", "1", "--mode", "Fixed", "--color", led])
state = json.loads(rgb.STATE.read_text())
check("set Zustand", (state["ok"], state["total"], state["running"], state["color"]), (2, 2, False, "#" + led))

# apply nimmt die gemerkte Farbe (wie Boot / after_sleep)
rc, out = run("apply", "--boot")
check("apply gemerkte Farbe", calls[0][-1], led)

# tune: Werte gemerkt (Prozent oder 0–1), LED-Farbe folgt
rc, out = run("tune", "50", "0.8")
cfg = json.loads(rgb.CONFIG.read_text())
check("tune merkt", (cfg["saturation"], cfg["brightness"]), (0.5, 0.8))
check("tune setzt", calls[0][-1], rgb.led_color("E0AE55"))
check("tune Farbe weicher", rgb.led_color("E0AE55") != led, True)

# set off: gemerkt, alles aus; apply bleibt danach aus; tune setzt dann nichts
rc, out = run("set", "off")
check("off merkt", json.loads(rgb.CONFIG.read_text())["on"], False)
check("off Aufruf", calls[0][:4], ["--device", "0", "--mode", "Off"])
rc, out = run("apply")
check("apply bleibt aus", calls[0][:4], ["--device", "0", "--mode", "Off"])
rc, out = run("tune", "1", "1")
check("tune bei aus ohne Lauf", (rc, calls), (0, []))
check("status json aus", json.loads(run("status", "--json")[1])["on"], False)

# Fehler
check("set unbekannt", run("set", "pink")[0], 2)
check("tune ohne Werte", run("tune", "1")[0], 2)
check("unbekanntes Token in rgb.json = accent", rgb.wanted_token({"color": "pink"}), "accent")

# hängender Lauf: Zustand nicht ewig „läuft“
rgb.write_state(running=True, pid=999999999)
last = json.loads(run("status", "--json")[1])["last"]
check("toter Lauf gilt nicht", (last["running"], last["aborted"]), (False, True))
check("fertiger Lauf nicht abgebrochen", (run("set", "accent")[0], json.loads(run("status", "--json")[1])["last"]["aborted"]), (0, False))

import shutil
shutil.rmtree(tmp, ignore_errors=True)

sys.exit(1 if fails else 0)
