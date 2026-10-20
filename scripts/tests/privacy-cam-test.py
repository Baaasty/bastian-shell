#!/usr/bin/env python3
"""Test für scripts/privacy-cam + scripts/inotify-watch ohne Kamera: inotify-Puffer zerlegen, URB-Rate umrechnen, App-Filter.
python3 -I scripts/tests/privacy-cam-test.py"""
import importlib.machinery
import importlib.util
import os
import sys

path = os.path.join(os.path.dirname(__file__), "..", "privacy-cam")
loader = importlib.machinery.SourceFileLoader("privacy_cam", path)
spec = importlib.util.spec_from_loader("privacy_cam", loader)
pc = importlib.util.module_from_spec(spec)
loader.exec_module(pc)

fails = 0


def check(name, got, want):
    global fails
    ok = got == want
    fails += not ok
    print(("ok   " if ok else "FAIL ") + name + ("" if ok else f"  got={got!r} want={want!r}"))


def ev(wd, mask, name=""):
    raw = name.encode()
    if raw:
        raw += b"\0" * (16 - len(raw) % 16)    # der Kernel füllt Namen mit Nullen auf
    return iw.EVENT.pack(wd, mask, 0, len(raw)) + raw


iw, M = pc.ino_mod, pc.M
buf = ev(1, M["CREATE"], "video2") + ev(3, M["OPEN"]) + ev(3, M["CLOSE_NOWRITE"])
check("events", iw.parse_events(buf), [(1, M["CREATE"], "video2"), (3, M["OPEN"], ""), (3, M["CLOSE_NOWRITE"], "")])
check("events halb", iw.parse_events(buf[:5]), [])
check("namen wie inotifywait", iw.mask_names(M["CLOSE_WRITE"]), "CLOSE_WRITE,CLOSE")
check("maske", iw.parse_mask("create,moved_to,close"), M["CREATE"] | M["MOVED_TO"] | iw.IN_CLOSE)

# Rate über ~1 s auf das 250-ms-Fenster von scripts/camera: Format-Abfrage ~60, Stream ab ~150 je 250 ms
check("rate stream", pc.cam.is_stream(pc.urbs_per_window(600, 1.0)), True)
check("rate abfrage", pc.cam.is_stream(pc.urbs_per_window(240, 1.0)), False)
check("rate dt 0", pc.urbs_per_window(500, 0), 0)

check("app chrome", pc.is_app("chrome"), True)
check("pipewire still", pc.is_app("pipewire"), False)
check("eigenes camera still", pc.is_app("camera"), False)
check("leer", pc.is_app(""), False)
check("andere camera-app", pc.is_app("cameractrls"), True)

sys.exit(1 if fails else 0)
