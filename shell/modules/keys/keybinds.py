#!/usr/bin/env python3
"""Liefert dem Keybind-Viewer (Keys.qml) die rohen Daten als ein JSON-Objekt auf stdout:

  layout  Tastaturlayout (input:kb_layout), für code:NN lesbar zu machen
  binds   Ausgabe von `hyprctl binds -j` (was Hyprland wirklich gebunden hat)
  conf    alle bind*-Zeilen der Konfiguration in Dateireihenfolge, mit Abschnitt ("# ---- Name ----")
          und den #-Kommentaren darüber (conf-Beschreibungen) – nichts davon ist hartcodiert

Die Konfiguration wird zur Laufzeit gefunden: $HYPRLAND_CONFIG, sonst $XDG_CONFIG_HOME/hypr/hyprland.conf,
und von dort allen "source = …"-Zeilen gefolgt ($VAR aus der Konfiguration oder der Umgebung, ~, Globs).
Aufruf: python3 -I keybinds.py
"""
import glob
import json
import os
import re
import subprocess
import sys

SECTION = re.compile(r"^#\s*[-=─]{3,}\s*(.+?)\s*[-=─]{3,}\s*$")
VAR_DEF = re.compile(r"^\$(\w+)\s*=\s*(.*)$")
BIND = re.compile(r"^(bind[a-z]*)\s*=\s*(.*)$")
SOURCE = re.compile(r"^source\s*=\s*(.+)$")
INLINE = re.compile(r"\s#\s+(\S.*)$")


def hyprctl(*args):
    try:
        out = subprocess.run(["hyprctl", *args], capture_output=True, text=True, timeout=5).stdout
        return json.loads(out)
    except Exception:
        return None


def main():
    variables = {}

    def expand(s):
        # längere Namen zuerst, damit $IPC2 nicht als $IPC + "2" ersetzt wird
        for name in sorted(variables, key=len, reverse=True):
            s = s.replace("$" + name, variables[name])
        return re.sub(r"\$(\w+)", lambda m: os.environ.get(m.group(1), m.group(0)), s)

    state = {"section": "", "comment": [], "block": 0, "first": False}
    records = []
    seen = set()

    def read(path):
        path = os.path.realpath(os.path.expanduser(path))
        if path in seen or not os.path.isfile(path):
            return
        seen.add(path)
        base = os.path.dirname(path)
        try:
            lines = open(path, encoding="utf-8", errors="replace").read().splitlines()
        except OSError:
            return
        for raw in lines:
            line = raw.strip()
            if not line:
                state["comment"] = []
                state["first"] = False
                continue
            if line.startswith("#"):
                m = SECTION.match(line)
                if m:
                    state["section"] = m.group(1)
                    state["comment"] = []
                    state["first"] = False
                    continue
                if state["first"]:
                    # neuer Kommentarblock mitten in einer Gruppe
                    state["comment"] = []
                    state["first"] = False
                state["comment"].append(line.lstrip("#").strip())
                continue
            m = VAR_DEF.match(line)
            if m:
                variables[m.group(1)] = expand(m.group(2).strip())
                continue
            m = SOURCE.match(line)
            if m:
                target = expand(m.group(1).strip())
                if not os.path.isabs(target) and not target.startswith("~"):
                    target = os.path.join(base, target)
                for f in sorted(glob.glob(os.path.expanduser(target))):
                    read(f)
                continue
            m = BIND.match(line)
            if m:
                body = expand(m.group(2))
                trail = ""
                t = INLINE.search(body)
                if t:
                    trail = t.group(1).strip()
                    body = body[: t.start()]
                parts = [p.strip() for p in body.split(",", 3)]
                if len(parts) < 3:
                    continue
                while len(parts) < 4:
                    parts.append("")
                if state["comment"] and not state["first"]:
                    state["block"] += 1
                    state["first"] = True
                    first = True
                else:
                    first = False
                records.append({
                    "flags": m.group(1)[4:],
                    "mods": parts[0],
                    "key": parts[1],
                    "dispatcher": parts[2],
                    "arg": parts[3],
                    "section": state["section"],
                    "comment": " ".join(state["comment"]) if state["comment"] else "",
                    "block": state["block"] if state["comment"] else 0,
                    "first": first,
                    "trail": trail,
                })

    xdg = os.environ.get("XDG_CONFIG_HOME") or os.path.expanduser("~/.config")
    root = os.environ.get("HYPRLAND_CONFIG") or os.path.join(xdg, "hypr", "hyprland.conf")
    read(root)

    layout = ""
    opt = hyprctl("getoption", "input:kb_layout", "-j")
    if isinstance(opt, dict):
        layout = str(opt.get("str", ""))

    json.dump({"layout": layout, "binds": hyprctl("binds", "-j") or [], "conf": records}, sys.stdout)


main()
