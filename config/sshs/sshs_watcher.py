# sshs – Kitty-Watcher für „sshs <name> --files“ (läuft im Kitty-Prozess, gestartet über launch --watcher).
# Hängt nur am ersten Terminal-Fenster: wartet, bis die Anmeldung an der Prompt steht (dann liegt der Schlüssel im
# SSH-Agenten und Kitty kennt den Server-Ordner), und schaltet einmal auf Dateien (yazi) um – wie Strg+Leertaste.
# Kommt keine Prompt (Passwort vertippt, Server weg), bleibt das Terminal; nach 3 min gibt der Watcher auf.
import os
import runpy

from kitty.fast_data_types import add_timer, get_boss, remove_timer

_KITTEN = os.path.join(os.path.dirname(os.path.abspath(__file__)), "sshs_kitten.py")
_armed = {}          # Fenster-ID -> Timer-ID
_done = set()


def _arm(window):
    wid = window.id
    if wid in _armed or wid in _done:
        return
    ticks = [0]

    def tick(timer_id):
        ticks[0] += 1
        w = get_boss().window_id_map.get(wid)
        if w is None or ticks[0] > 720:          # 720 × 0,25 s = 3 min
            _stop(wid)
            return
        if not (w.at_prompt and w.screen.last_reported_cwd):
            return
        _stop(wid)
        tab = w.tabref()
        if tab is None:
            return
        try:
            runpy.run_path(_KITTEN)["toggle"](get_boss(), tab)
        except Exception as e:  # nie Kitty mitreißen
            print(f"sshs_watcher: {e}")

    _armed[wid] = add_timer(tick, 0.25, True)


def _stop(wid):
    _done.add(wid)
    t = _armed.pop(wid, None)
    if t is not None:
        remove_timer(t)


def on_resize(boss, window, data):
    _arm(window)


def on_title_change(boss, window, data):
    _arm(window)


def on_close(boss, window, data):
    _stop(window.id)
