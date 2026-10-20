#!/usr/bin/env python3
"""Fenster-Schema mit Super+Pfeilen unter Hyprland – Nachbau des KWin-Scripts desktop-tiling (Git-Tag kwin-final).

  window.py maximize        Super+↑   maximieren, nochmal = zurück
  window.py restore         Super+↓   normale Größe mittig (ist es schon normal: 60 % × 70 % mittig)
  window.py tile left|right Super+←/→ an die Seite, nochmal auf derselben Seite: ½ → ⅓ → ⅔ → ½
  window.py screen -1|1     Super+Shift+←/→ auf den Nachbarmonitor (proportional, Seite/Maximiert bleibt)

Arbeitet mit dem aktiven Fenster (alle Fenster schweben, hypr/rules.conf). Zustand (an die Seite gelegt,
letzte normale Größe) liegt in $XDG_RUNTIME_DIR/desktop-window.json, weil jeder Tastendruck ein neuer
Prozess ist. Spricht Hyprland direkt über dessen Socket an (kein hyprctl-Start je Befehl).
"""
import json
import os
import pathlib
import socket
import subprocess
import sys
import time

GAP = 8                        # Abstand wie in der Shell
STEPS = [1 / 2, 1 / 3, 2 / 3]  # Breiten-Runde an der Seite
DEFAULT_SIZE = (0.6, 0.7)      # Super+↓ auf ein schon normales Fenster
REPEAT_S = 0.8                 # schnelles Nachdrücken zählt, auch wenn die neue Lage noch nicht gemeldet ist

RUN = pathlib.Path(os.environ.get("XDG_RUNTIME_DIR") or f"/run/user/{os.getuid()}")
STATE = RUN / "desktop-window.json"
SHELL_DIR = pathlib.Path(__file__).resolve().parent.parent / "shell"


# ---------- Hyprland-Socket ----------
def sock_path() -> pathlib.Path:
    sig = os.environ.get("HYPRLAND_INSTANCE_SIGNATURE")
    if not sig:
        sys.exit("window.py: läuft nur unter Hyprland")
    return RUN / "hypr" / sig / ".socket.sock"


def request(cmd: str) -> str:
    with socket.socket(socket.AF_UNIX, socket.SOCK_STREAM) as s:
        s.connect(str(sock_path()))
        s.sendall(cmd.encode())
        chunks = []
        while True:
            b = s.recv(65536)
            if not b:
                break
            chunks.append(b)
    return b"".join(chunks).decode(errors="replace")


def query(what: str):
    return json.loads(request("j/" + what) or "null")


def batch(*cmds: str) -> None:
    if cmds:
        request("[[BATCH]]" + " ; ".join("dispatch " + c for c in cmds))


# ---------- Zustand ----------
def load_state() -> dict:
    try:
        return json.loads(STATE.read_text())
    except (OSError, ValueError):
        return {}


def save_state(st: dict) -> None:
    # Einträge geschlossener Fenster wegräumen
    if len(st) > 40:
        alive = {c.get("address") for c in query("clients") or []}
        st = {k: v for k, v in st.items() if k in alive}
    tmp = STATE.with_suffix(".tmp")
    tmp.write_text(json.dumps(st))
    tmp.replace(STATE)


# ---------- Geometrie ----------
def logical(m: dict) -> dict:
    """Monitor in logischen Koordinaten, Arbeitsfläche ohne reservierte Ränder."""
    scale = m.get("scale") or 1
    w, h = m["width"] / scale, m["height"] / scale
    if m.get("transform", 0) % 2 == 1:
        w, h = h, w
    left, top, right, bottom = (m.get("reserved") or [0, 0, 0, 0])[:4]
    return {"name": m["name"], "id": m["id"], "ws": (m.get("activeWorkspace") or {}).get("id"),
            "x": m["x"] + left, "y": m["y"] + top, "w": w - left - right, "h": h - top - bottom}


def side_rect(a: dict, side: str, fraction: float) -> list:
    width = round(a["w"] * fraction)
    x = a["x"] + GAP if side == "left" else a["x"] + a["w"] - width + GAP / 2
    return [round(x), round(a["y"] + GAP), round(width - GAP - GAP / 2), round(a["h"] - 2 * GAP)]


def centered(a: dict, w: float, h: float) -> list:
    w = min(w, a["w"] - 2 * GAP)
    h = min(h, a["h"] - 2 * GAP)
    return [round(a["x"] + (a["w"] - w) / 2), round(a["y"] + (a["h"] - h) / 2), round(w), round(h)]


def near(g: list, r: list) -> bool:
    # Terminals & Co. runden auf Zeichenraster -> Größe großzügig, Lage genau
    return abs(g[0] - r[0]) <= 4 and abs(g[1] - r[1]) <= 4 and abs(g[2] - r[2]) <= 40 and abs(g[3] - r[3]) <= 40


def geo(c: dict) -> list:
    return [c["at"][0], c["at"][1], c["size"][0], c["size"][1]]


def sel(c: dict) -> str:
    return "address:" + c["address"]


def place(c: dict, rect: list) -> list:
    """Befehle: Fenster schwebend machen und auf rect legen (erst Größe, dann Lage)."""
    cmds = []
    if not c.get("floating"):
        cmds.append("setfloating " + sel(c))
    cmds.append(f"resizewindowpixel exact {rect[2]} {rect[3]},{sel(c)}")
    cmds.append(f"movewindowpixel exact {rect[0]} {rect[1]},{sel(c)}")
    return cmds


class Ctx:
    def __init__(self):
        self.win = query("activewindow") or {}
        if not self.win.get("address"):
            sys.exit(0)
        self.mons = [logical(m) for m in query("monitors") or [] if not m.get("disabled")]
        self.st = load_state()
        self.addr = self.win["address"]

    def mon(self, mid=None, name=None) -> dict:
        for m in self.mons:
            if (name is not None and m["name"] == name) or (name is None and m["id"] == mid):
                return m
        return self.mons[0]

    @property
    def fullscreen(self) -> int:
        """0 normal, 1 maximiert, 2 Vollbild (Hyprland-Modus des Fensters)."""
        f = self.win.get("fullscreen", 0)
        return int(f) if not isinstance(f, bool) else (2 if f else 0)

    def our_tile(self):
        t = self.st.get(self.addr, {}).get("tile")
        if not t or self.fullscreen:
            return None
        if time.time() - t["at"] < REPEAT_S:
            return t
        return t if near(geo(self.win), t["rect"]) else None

    def is_normal(self) -> bool:
        return self.fullscreen == 0 and not self.our_tile()

    def remember_normal(self) -> None:
        if not self.is_normal():
            return
        a = self.mon(self.win["monitor"])
        g = geo(self.win)
        self.st.setdefault(self.addr, {})["normal"] = [g[2] / a["w"], g[3] / a["h"]]

    def release(self) -> list:
        """Vollbild/Maximierung lösen (wirkt auf das fokussierte = aktive Fenster)."""
        f = self.fullscreen
        if f == 1:
            return ["fullscreen 1 unset"]
        if f >= 2:
            return ["fullscreen 0 unset"]
        return []

    def done(self, cmds: list) -> None:
        batch(*cmds)
        save_state(self.st)
        # Shell neu nachsehen lassen (Bar weicht aus, Workbar-Vorschau) – Hyprland meldet Verschieben nicht
        subprocess.Popen(["qs", "ipc", "--any-display", "-p", str(SHELL_DIR), "call", "hypr", "refresh"],
                         stdout=subprocess.DEVNULL, stderr=subprocess.DEVNULL, start_new_session=True)


# ---------- Befehle ----------
def cmd_maximize(c: Ctx) -> None:
    if c.fullscreen == 1:
        c.done(["fullscreen 1 unset"])
        return
    c.remember_normal()
    c.st.get(c.addr, {}).pop("tile", None)
    cmds = ["fullscreen 0 unset"] if c.fullscreen >= 2 else []
    if not c.win.get("floating"):
        cmds.append("setfloating " + sel(c.win))
    c.done(cmds + ["fullscreen 1 set"])


def cmd_restore(c: Ctx) -> None:
    t = c.our_tile()
    a = c.mon(name=t["monitor"]) if t else c.mon(c.win["monitor"])
    n = c.st.get(c.addr, {}).get("normal")
    was_normal = c.is_normal()
    c.st.get(c.addr, {}).pop("tile", None)

    if was_normal:
        c.done(place(c.win, centered(a, a["w"] * DEFAULT_SIZE[0], a["h"] * DEFAULT_SIZE[1])))
        return
    if n or t:
        size = n or DEFAULT_SIZE
        c.done(c.release() + place(c.win, centered(a, a["w"] * size[0], a["h"] * size[1])))
        return
    # maximiert/Vollbild ohne gemerkte Größe: Hyprland stellt die alte Größe her, danach einmal mittig setzen
    batch(*c.release())
    for _ in range(15):
        time.sleep(0.05)
        w = query("activewindow") or {}
        if w.get("address") == c.addr and not w.get("fullscreen"):
            g = geo(w)
            c.win = w
            c.done(place(w, centered(c.mon(w["monitor"]), g[2], g[3])))
            return
    save_state(c.st)


def cmd_tile(c: Ctx, side: str) -> None:
    if side not in ("left", "right"):
        sys.exit("tile left|right")
    t = c.our_tile()
    a = c.mon(name=t["monitor"]) if t else c.mon(c.win["monitor"])
    c.remember_normal()
    step = (t["step"] + 1) % len(STEPS) if t and t["side"] == side else 0
    rect = side_rect(a, side, STEPS[step])
    c.st.setdefault(c.addr, {})["tile"] = {"side": side, "step": step, "monitor": a["name"], "rect": rect,
                                           "at": time.time()}
    c.done(c.release() + place(c.win, rect))


def cmd_screen(c: Ctx, direction: int) -> None:
    t = c.our_tile()
    src = c.mon(name=t["monitor"]) if t else c.mon(c.win["monitor"])
    screens = sorted(c.mons, key=lambda m: m["x"])
    i = next((k for k, m in enumerate(screens) if m["name"] == src["name"]), -1)
    if i < 0 or not 0 <= i + direction < len(screens):
        return
    dst = screens[i + direction]
    # erst auf den sichtbaren Workspace des Zielmonitors (Desktop-Schema der Shell: gleicher Desktop, anderer Platz)
    move = [f"movetoworkspacesilent {dst['ws']},{sel(c.win)}"] if dst.get("ws") else []
    focus = [f"focuswindow {sel(c.win)}"]

    if t:
        rect = side_rect(dst, t["side"], STEPS[t["step"]])
        c.st[c.addr]["tile"] = dict(t, monitor=dst["name"], rect=rect, at=time.time())
        c.done(move + focus + place(c.win, rect))
        return
    f = c.fullscreen
    if f:
        # maximiert/Vollbild: drüben genauso wieder hinlegen
        mode = "1" if f == 1 else "0"
        c.done(c.release() + move + focus + [f"fullscreen {mode} set"])
        return
    g = geo(c.win)
    sx, sy = dst["w"] / src["w"], dst["h"] / src["h"]
    w, h = min(g[2] * sx, dst["w"]), min(g[3] * sy, dst["h"])
    x = min(max(dst["x"] + (g[0] - src["x"]) * sx, dst["x"]), dst["x"] + dst["w"] - w)
    y = min(max(dst["y"] + (g[1] - src["y"]) * sy, dst["y"]), dst["y"] + dst["h"] - h)
    c.done(move + focus + place(c.win, [round(x), round(y), round(w), round(h)]))


def main() -> None:
    args = sys.argv[1:]
    if not args or args[0] not in ("maximize", "restore", "tile", "screen"):
        sys.exit(__doc__)
    c = Ctx()
    if args[0] == "maximize":
        cmd_maximize(c)
    elif args[0] == "restore":
        cmd_restore(c)
    elif args[0] == "tile":
        cmd_tile(c, args[1] if len(args) > 1 else "")
    else:
        cmd_screen(c, -1 if (args[1] if len(args) > 1 else "1").startswith("-") else 1)


if __name__ == "__main__":
    main()
