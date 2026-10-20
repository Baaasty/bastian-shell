#!/usr/bin/env python3
"""Test für scripts/share-stop: Freigaben aus pw-dump-Daten erkennen, nur xdph-Screencasts sind stoppbar (ohne PipeWire):
python3 -I scripts/tests/share-stop-test.py"""
import importlib.machinery
import importlib.util
import os
import sys

path = os.path.join(os.path.dirname(__file__), "..", "share-stop")
loader = importlib.machinery.SourceFileLoader("share_stop", path)
spec = importlib.util.spec_from_loader("share_stop", loader)
ss = importlib.util.module_from_spec(spec)
loader.exec_module(ss)

fails = 0


def check(name, got, want):
    global fails
    ok = got == want
    fails += not ok
    print(("ok   " if ok else "FAIL ") + name + ("" if ok else f"  got={got!r} want={want!r}"))


def node(i, **p):
    return {"id": i, "type": "PipeWire:Interface:Node", "info": {"props": p}}


def link(a, b):
    return {"id": 900 + a + b, "type": "PipeWire:Interface:Link", "info": {"output-node-id": a, "input-node-id": b}}


cam = node(170, **{"node.name": "v4l2_input.x", "media.class": "Video/Source", "media.role": "Camera"})
xdph1 = node(224, **{"node.name": "xdg-desktop-portal-hyprland", "media.class": "Video/Source", "media.name": "xdph-streaming-1"})
discord = node(210, **{"node.name": "Discord", "media.class": "Stream/Input/Video", "media.name": "discord", "node.target": 224})
xdph2 = node(230, **{"node.name": "xdg-desktop-portal-hyprland", "media.class": "Video/Source"})
chrome = node(231, **{"node.name": "chromium", "application.name": "Chromium", "media.class": "Stream/Input/Video"})
obs = node(240, **{"node.name": "obs-cam", "media.class": "Stream/Input/Video"})
mic = node(50, **{"node.name": "alsa_input.x", "media.class": "Audio/Source"})

data = [cam, xdph1, discord, xdph2, chrome, obs, mic, link(230, 231), link(170, 240)]
check("zwei Freigaben", ss.shares(data), [{"node": 224, "apps": ["Discord"]}, {"node": 230, "apps": ["Chromium"]}])
check("xdph stoppbar", ss.stoppable(data, 224), True)
check("Kamera nie", ss.stoppable(data, 170), False)
check("Mikro nie", ss.stoppable(data, 50), False)
check("App-Stream nie", ss.stoppable(data, 210), False)
check("unbekannt nie", ss.stoppable(data, 999), False)
check("leer", ss.shares([]), [])
check("kaputt", ss.shares([None, 3, {"type": "PipeWire:Interface:Link", "info": None}]), [])

sys.exit(1 if fails else 0)
