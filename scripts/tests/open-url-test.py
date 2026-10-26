#!/usr/bin/env python3
"""Test für scripts/open-url: aktueller Desktop aus den Monitoren, Browserfenster dieses Desktops finden (ohne Hyprland):
python3 -I scripts/tests/open-url-test.py"""
import importlib.machinery
import importlib.util
import os
import sys

path = os.path.join(os.path.dirname(__file__), "..", "open-url")
loader = importlib.machinery.SourceFileLoader("open_url", path)
spec = importlib.util.spec_from_loader("open_url", loader)
ou = importlib.util.module_from_spec(spec)
loader.exec_module(ou)

fails = 0


def check(name, got, want):
    global fails
    ok = got == want
    fails += not ok
    print(("ok   " if ok else "FAIL ") + name + ("" if ok else f"  got={got!r} want={want!r}"))


def mon(name, ws):
    return {"name": name, "activeWorkspace": {"id": ws}}


def win(addr, cls, ws, focus=5):
    return {"address": addr, "class": cls, "workspace": {"id": ws}, "focusHistoryID": focus}


check("Desktop vom Hauptmonitor", ou.current_desk([mon("HDMI-A-2", 102), mon("DP-2", 3), mon("DP-1", 203)]), 3)
check("ohne DP-2: erster Monitor", ou.current_desk([mon("HDMI-A-1", 104)]), 4)
check("keine Monitore", ou.current_desk([]), 0)
check("Spezial-Workspace aktiv", ou.current_desk([mon("DP-2", -98)]), 0)

clients = [
    win("0xa", "helium", 202, focus=1),       # rechts, Desktop 2
    win("0xb", "helium", 201, focus=4),       # rechts, Desktop 1
    win("0xc", "Helium", 1, focus=2),         # Mitte, Desktop 1 (Groß-/Kleinschreibung egal)
    win("0xd", "helium", -97, focus=0),       # minimiert/weggeräumt: zählt nie
    win("0xe", "code", 1, focus=0),
]
check("zuletzt fokussiertes Fenster des Desktops", ou.pick(clients, 1)["address"], "0xc")
check("anderer Desktop", ou.pick(clients, 2)["address"], "0xa")
check("kein Browser auf dem Desktop", ou.pick(clients, 3), None)
check("Desktop unbekannt", ou.pick(clients, 0), None)
check("Chrome zählt auch", ou.pick([win("0xf", "google-chrome", 105)], 5)["address"], "0xf")
check("keine Clients", ou.pick(None, 1), None)

sys.exit(1 if fails else 0)
