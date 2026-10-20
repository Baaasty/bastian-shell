#!/usr/bin/env python3
"""Test für scripts/camera ohne Kamera: Stream-Erkennung über einen falschen `urbnum`-Zähler.
python3 -I scripts/tests/camera-test.py"""
import importlib.machinery
import importlib.util
import os
import sys
import tempfile

path = os.path.join(os.path.dirname(__file__), "..", "camera")
loader = importlib.machinery.SourceFileLoader("camera", path)
spec = importlib.util.spec_from_loader("camera", loader)
cam = importlib.util.module_from_spec(spec)
loader.exec_module(cam)

fails = 0


def check(name, got, want):
    global fails
    ok = got == want
    fails += not ok
    print(("ok   " if ok else "FAIL ") + name + ("" if ok else f"  got={got!r} want={want!r}"))


# Messwerte je 250 ms (2026-10-20): Format-Abfrage 45-75, Stream ab ~150
check("leerlauf", cam.is_stream(0), False)
check("format-abfrage", cam.is_stream(73), False)
check("stream 540p", cam.is_stream(150), True)
check("stream 720p", cam.is_stream(270), True)

# streaming(): Zähler steigt während des sleep um <step>
with tempfile.TemporaryDirectory() as d:
    f = os.path.join(d, "urbnum")

    def run(step):
        with open(f, "w") as fh:
            fh.write("1000")

        def fake_sleep(_):
            with open(f, "w") as fh:
                fh.write(str(1000 + step))
        cam.time.sleep = fake_sleep
        return cam.streaming(d)

    check("streaming abfrage", run(60), False)
    check("streaming stream", run(260), True)
    check("streaming ohne datei", cam.streaming(os.path.join(d, "fehlt")), False)

sys.exit(1 if fails else 0)
