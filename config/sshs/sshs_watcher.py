# sshs – Kitty-Watcher für Server-Fenster (läuft im Kitty-Prozess, gestartet über launch --watcher).
# Hängt an jedem Terminal-Fenster (scripts/sshs connect, neuer Tab) und an Upload-Overlays als root:
#   sshs_then  (--files / --su / --run): wartet, bis die Anmeldung an der Prompt steht (dann liegt der Schlüssel im
#              SSH-Agenten und Kitty kennt den Server-Ordner), tippt bei „su“ einmal su (Passwort gibst du selbst ein)
#              und wartet auf die su-Prompt, danach einmal auf Dateien umschalten bzw. sshs_run ausführen.
#              Kommt keine Prompt (Passwort vertippt, Server weg), bleibt das Terminal; nach 3 min gibt er auf.
#   sshs_give  (User-Variable aus _sshs_give in der su-Shell): holt die Auswahl per sshs fetch nach ~/Downloads.
#   sshs_take  (Upload-Overlay als root): nach erfolgreichem Upload verschiebt die su-Shell die Dateien (_sshs_take).
import os
import runpy

from kitty.fast_data_types import add_timer, get_boss, remove_timer
from kitty.launch import launch, parse_launch_args

_DIR = os.path.dirname(os.path.realpath(__file__))
_KITTEN = os.path.join(_DIR, "sshs_kitten.py")
_RUNTIME = os.path.join(os.environ.get("XDG_RUNTIME_DIR", "/tmp"), "sshs")
_SSHS = os.path.expanduser("~/.local/bin/sshs")
_armed = {}          # Fenster-ID -> Timer-ID
_done = set()


def _kitten():
    return runpy.run_path(_KITTEN)


def _later(fn, delay=0.05):
    # nie mitten in der Verarbeitung von Kittys Ausgabe Fenster starten oder tippen
    def run(_timer_id):
        try:
            fn()
        except Exception as e:  # nie Kitty mitreißen
            print(f"sshs_watcher: {e}")
    add_timer(run, delay, False)


def _finish(w, then):
    if "files" in then:
        tab = w.tabref()
        if tab is not None:
            _kitten()["toggle"](get_boss(), tab)
    elif "run" in then:
        cmd = w.user_vars.get("sshs_run", "")
        if cmd:
            w.write_to_child(f" {cmd}\r")


def _arm(window):
    wid = window.id
    if wid in _armed or wid in _done:
        return
    then = [x for x in window.user_vars.get("sshs_then", "").split(",") if x]
    if not then:
        _done.add(wid)
        return
    st = {"ticks": 0, "stage": "login", "left": False}

    def tick(timer_id):
        st["ticks"] += 1
        w = get_boss().window_id_map.get(wid)
        if w is None or st["ticks"] > 720:          # 720 × 0,25 s = 3 min
            _stop(wid)
            return
        try:
            if st["stage"] == "login":
                if not (w.at_prompt and w.screen.last_reported_cwd):
                    return
                if "su" in then:
                    w.write_to_child(" su\r")
                    st["stage"] = "su"
                    return
                _stop(wid)
                _finish(w, then)
                return
            # su: erst weg von der Prompt (Passwortabfrage), dann wieder da – als anderer Benutzer oder vertippt
            if not w.at_prompt:
                st["left"] = True
                return
            if st["left"]:
                _stop(wid)
                if _kitten()["su_user"](w):
                    _finish(w, then)
        except Exception as e:
            _stop(wid)
            print(f"sshs_watcher: {e}")

    _armed[wid] = add_timer(tick, 0.25, True)


def _stop(wid):
    _done.add(wid)
    t = _armed.pop(wid, None)
    if t is not None:
        remove_timer(t)


def _fetch(window, tok):
    tab = window.tabref()
    if tab is None:
        return
    host = window.user_vars.get("sshs_host", "")
    spec = parse_launch_args(["--type=overlay", "--title", f"{host} · herunterladen", "--cwd", os.path.expanduser("~"),
                              "--env", "SSHS_OVERLAY=1", _SSHS, "fetch", host, tok])
    launch(get_boss(), spec.opts, spec.args, target_tab=tab)


def _take(shell_id, tok):
    sh = get_boss().window_id_map.get(shell_id)
    if sh is None:
        return
    k = _kitten()
    if k["in_yazi"](sh):
        k["at_prompt_then"](sh, f" _sshs_take {tok}; _sshs_y\r")
    elif sh.at_prompt:
        sh.write_to_child(f" _sshs_take {tok}\r")
    else:
        print(f"sshs_watcher: Shell beschäftigt – Upload liegt bereit, übernehmen mit: _sshs_take {tok}")


def on_resize(boss, window, data):
    _arm(window)


def on_title_change(boss, window, data):
    _arm(window)


def on_set_user_var(boss, window, data):
    tok = data.get("value") or ""
    if data.get("key") == "sshs_give" and tok and window.user_vars.get("sshs") == "shell":
        _later(lambda: _fetch(window, tok))


def on_close(boss, window, data):
    _stop(window.id)
    tok = window.user_vars.get("sshs_take")
    if not tok:
        return
    mark = os.path.join(_RUNTIME, f"take-{tok}")
    if not os.path.exists(mark):
        return
    os.remove(mark)
    try:
        sid = int(window.user_vars.get("sshs_shell", "0"))
    except ValueError:
        return
    _later(lambda: _take(sid, tok))
