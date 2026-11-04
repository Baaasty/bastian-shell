#!/usr/bin/env python3
"""Liefert dem Keybind-Viewer (Keys.qml) die rohen Daten als ein JSON-Objekt auf stdout:

  layout  Tastaturlayout (input:kb_layout), für code:NN lesbar zu machen
  binds   Ausgabe von `hyprctl binds -j` (was Hyprland wirklich gebunden hat)
  conf    alle bind(…)-Zeilen aus hypr/binds.lua in Dateireihenfolge, mit Abschnitt ("-- ---- Name ----"), Titel
          und den --Kommentaren darüber (conf-Beschreibungen) – nichts davon ist hartcodiert

Format der Zeilen: bind("SUPER + SHIFT + Left", "Titel", Aktion, { release = true, … }) (Helfer in hypr/lib.lua).
Eingerückte hl.bind(…) (Submaps) gehören nicht in den Viewer.
Aufruf: python3 -I keybinds.py
"""
import json
import re
import subprocess
import sys
from pathlib import Path

BINDS = Path(__file__).resolve().parents[3] / "hypr" / "binds.lua"
SECTION = re.compile(r"^--\s*[-=─]{3,}\s*(.+?)\s*[-=─]{3,}\s*$")
BIND = re.compile(r'^bind\(\s*"([^"]+)"\s*,\s*(?:nil|"([^"]*)")\s*,\s*(.*)\)\s*$')
# Bind-Optionen → die alten hyprlang-Flags, mit denen Keybinds.qml rechnet (r = Loslassen, m = Maus …)
FLAGS = {"release": "r", "mouse": "m", "locked": "l", "repeating": "e", "ignore_mods": "i", "transparent": "t"}


def hyprctl(*args):
    try:
        out = subprocess.run(["hyprctl", *args], capture_output=True, text=True, timeout=5).stdout
        return json.loads(out)
    except Exception:
        return None


def main():
    state = {"section": "", "comment": [], "block": 0, "first": False}
    records = []
    try:
        lines = BINDS.read_text(encoding="utf-8", errors="replace").splitlines()
    except OSError:
        lines = []
    for raw in lines:
        line = raw.strip()
        m = BIND.match(raw)
        if not line or (not m and not line.startswith("--")):
            # Leerzeile oder sonstiger Lua-Code: Kommentar darüber gehört nicht zum nächsten Bind
            state["comment"] = []
            state["first"] = False
            continue
        if not m:
            s = SECTION.match(line)
            if s:
                state["section"] = s.group(1)
                state["comment"] = []
                state["first"] = False
                continue
            if state["first"]:
                # neuer Kommentarblock mitten in einer Gruppe
                state["comment"] = []
                state["first"] = False
            state["comment"].append(line[2:].strip())
            continue
        keys, title, rest = m.groups()
        parts = [k.strip() for k in keys.split("+")]
        flags = "".join(f for opt, f in FLAGS.items() if re.search(rf"\b{opt}\s*=\s*true\b", rest))
        if state["comment"] and not state["first"]:
            state["block"] += 1
            state["first"] = True
            first = True
        else:
            first = False
        records.append({
            "flags": flags,
            "mods": " ".join(parts[:-1]),
            "key": parts[-1],
            "dispatcher": "",
            "arg": "",
            "section": state["section"],
            "comment": " ".join(state["comment"]) if state["comment"] else "",
            "block": state["block"] if state["comment"] else 0,
            "first": first,
            "trail": title or "",
        })

    layout = ""
    opt = hyprctl("getoption", "input:kb_layout", "-j")
    if isinstance(opt, dict):
        layout = str(opt.get("str", ""))

    json.dump({"layout": layout, "binds": hyprctl("binds", "-j") or [], "conf": records}, sys.stdout)


main()
