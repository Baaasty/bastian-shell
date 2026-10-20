#!/usr/bin/env python3
"""App-Kürzel für den Keybind-Viewer (Super+K): liest config/appkeys/*.json und gibt JSON auf stdout aus.

Eine Datei pro Programm, von Hand gepflegt (Format: docs/knowledge/hotkeys.md, Abschnitt „App-Kürzel“):
  { "name": "Discord", "about": "…", "order": 20,
    "match": { "class": ["discord"], "title": "^regex" },        # Hyprland-Klasse (klein), optional Fenstertitel
    "sections": [ { "name": "Navigate", "keys": [ { "keys": "Ctrl+K", "title": "Quick switcher", "note": "…" } ] } ] }
Tasten: "Ctrl+Shift+M" · Alternativen als Liste ["Ctrl+Tab", "Ctrl+PgDn"] · mehrere Tasten nacheinander/zusammen
mit Leerzeichen ("g g", "Alt+↑ ↓") · "Ctrl+Plus" für + · "(tap)" am Ende = Modifier allein antippen.
"group": "shell" hängt die Abschnitte an die Shell-Kürzel an ("area": "topbar" = in die Gruppe „Topbar“ des Viewers);
ein Abschnitt mit "auto" wird hier gefüllt:
  barLetters (aus shell/services/BarKeys.qml), launcherPrefixes (aus shell/modules/launcher/Launcher.qml),
  webShortcuts (aus config/launcher/web.json).
Eine kaputte Datei stoppt nur sich selbst (steht in "errors").
"""
import json
import pathlib
import re
import sys

ROOT = pathlib.Path(__file__).resolve().parents[3]
DIR = ROOT / "config/appkeys"
MODS = {"ctrl": "Ctrl", "strg": "Ctrl", "control": "Ctrl", "alt": "Alt", "shift": "Shift", "umschalt": "Shift",
        "super": "Super", "win": "Super", "meta": "Super", "altgr": "AltGr"}
ORDER = ["Super", "Ctrl", "Alt", "AltGr", "Shift"]
KEYNAMES = {"plus": "+", "minus": "-", "space": "Space", "enter": "Enter", "return": "Enter", "esc": "Esc",
            "escape": "Esc", "del": "Del", "delete": "Del", "pgup": "PgUp", "pgdn": "PgDn", "tab": "Tab",
            "home": "Home", "end": "End", "left": "←", "right": "→", "up": "↑", "down": "↓"}


def chord(text: str) -> dict:
    s = text.strip()
    tag = ""
    m = re.fullmatch(r"(.*?)\s*\(([^()]+)\)", s)
    if m and m.group(1):
        s, tag = m.group(1), m.group(2)
    parts = re.split(r"\+(?=.)", s)            # "Ctrl++" -> Ctrl, +
    *mods, last = parts
    names = []
    for x in mods:
        n = MODS.get(x.strip().lower())
        if not n:
            raise ValueError(f"unknown modifier {x!r} in {text!r}")
        names.append(n)
    names = sorted(set(names), key=ORDER.index)
    keys = [KEYNAMES.get(k.lower(), k) for k in last.split()] or [last]
    if not mods and len(keys) == 1 and keys[0].lower() in MODS:   # "Super (tap)" / "Alt (tap)"
        keys = [MODS[keys[0].lower()]]
    return {"mods": names, "keys": keys, "tag": tag}


def rows(keys: list) -> list:
    out = []
    for k in keys:
        ks = k["keys"] if isinstance(k["keys"], list) else [k["keys"]]
        out.append({"title": str(k["title"]), "sub": str(k.get("note", "")), "chords": [chord(c) for c in ks]})
    return out


# ---------- automatisch gefüllte Abschnitte ----------
def bar_letters() -> list:
    src = (ROOT / "shell/services/BarKeys.qml").read_text()
    # auch Einträge mit Zusatzfeldern (action: true – Dateien, Browser, Settings)
    found = re.findall(r'\{\s*key:\s*"([^"]+)",\s*name:\s*"[^"]*",\s*label:\s*"([^"]+)"[^}]*\}', src)
    return [{"title": label, "sub": "", "chords": [{"mods": [], "keys": [key], "tag": ""}]} for key, label in found]


def launcher_prefixes() -> list:
    src = (ROOT / "shell/modules/launcher/Launcher.qml").read_text()
    found = re.findall(r'\{\s*prefix:\s*"([^"]*)",\s*label:\s*"([^"]+)",\s*hint:\s*"([^"]*)"\s*\}', src)
    out = []
    for prefix, label, hint in found:
        if not prefix.strip():
            continue
        out.append({"title": label, "sub": hint, "chords": [{"mods": [], "keys": [prefix.strip()], "tag": ""}]})
    return out


def web_shortcuts() -> list:
    data = json.loads((ROOT / "config/launcher/web.json").read_text())
    return [{"title": "Search " + v.get("name", k), "sub": "", "chords": [{"mods": [], "keys": [k], "tag": ""}]}
            for k, v in data.items() if isinstance(v, dict)]


AUTO = {"barLetters": bar_letters, "launcherPrefixes": launcher_prefixes, "webShortcuts": web_shortcuts}


def load(path: pathlib.Path) -> dict:
    d = json.loads(path.read_text())
    m = d.get("match") or {}
    cls = m.get("class", [])
    cls = [cls] if isinstance(cls, str) else cls
    title = m.get("title", "")
    if title:
        re.compile(title)
    sections = []
    for s in d.get("sections", []):
        if s.get("auto"):
            fn = AUTO.get(s["auto"])
            if not fn:
                raise ValueError(f"unknown auto section {s['auto']!r}")
            r = fn()
        else:
            r = rows(s.get("keys", []))
        if r:
            sections.append({"name": str(s["name"]), "note": str(s.get("note", "")), "area": str(s.get("area", "")),
                             "rows": r})
    return {"id": path.stem, "name": str(d.get("name", path.stem)), "about": str(d.get("about", "")),
            "group": str(d.get("group", "app")), "order": d.get("order", 100),
            "classes": [c.lower() for c in cls], "title": title, "sections": sections}


def main():
    apps, errors = [], []
    for p in sorted(DIR.glob("*.json")):
        try:
            apps.append(load(p))
        except Exception as e:  # eine kaputte Datei reißt die anderen nicht mit
            errors.append(f"{p.name}: {e}")
    apps.sort(key=lambda a: (a["order"], a["name"].lower()))
    json.dump({"apps": apps, "errors": errors}, sys.stdout, ensure_ascii=False)


if __name__ == "__main__":
    main()
