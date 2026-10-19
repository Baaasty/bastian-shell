# sshs – Kitty-Kitten für Server-Fenster (läuft im Kitty-Prozess, kein eigenes Fenster).
# Eingebunden über config/sshs/kitty.conf (map … kitten sshs_kitten.py <aktion>), gestartet von scripts/sshs.
#
# Jeder Tab hat zwei Fenster im Stack-Layout (nur eins sichtbar):
#   shell  – sshs _ssh <host> = kitten ssh mit sshs-Shell (Kitty kennt den Server-Ordner per OSC 7)
#   files  – yazi sftp://<host>  (wird beim ersten Umschalten gestartet; meldet seinen Ordner über
#            config/yazi/init.lua in eine Datei, ya emit-to schickt ihn woanders hin)
# Nach su (z. B. root) meldet die Shell den Benutzer als User-Variable sshs_su (config/sshs/remote/bashrc). SFTP kann
# nur den Anmelde-Benutzer, darum läuft yazi dann direkt in der su-Shell auf dem Server (_sshs_y, sshs_yazi=1):
# Umschalten tippt den Start an der Prompt bzw. beendet yazi mit q – die Shell wandert dabei in yazis Ordner.
# Aktionen:
#   toggle   Terminal <-> Dateien, der Ordner wandert jeweils mit
#   new_tab  neuer Tab zum selben Server im aktuellen Ordner (als Anmelde-Benutzer)
#   upload   lokale Dateien auswählen (sshs up, als Overlay) und in den aktuellen Server-Ordner laden;
#            als root über die Zwischenablage in/<kennung>, die su-Shell verschiebt danach (Watcher, _sshs_take)
#   download Dateien im aktuellen Server-Ordner auswählen (sshs down, als Overlay) → ~/Downloads;
#            als root Auswahl in yazi (_sshs_give), der Watcher holt sie ab (sshs fetch)
import os
import secrets
import shlex
import subprocess

from kittens.tui.handler import result_handler
from kitty.launch import launch, parse_launch_args
from kitty.utils import path_from_osc7_url

RUNTIME = os.path.join(os.environ.get("XDG_RUNTIME_DIR", "/tmp"), "sshs")
SSHS = os.path.expanduser("~/.local/bin/sshs")
# Kittens laufen ohne __file__: den Watcher über den sshs-Symlink im Repo finden (scripts/sshs → config/sshs/…)
WATCHER = os.path.join(os.path.dirname(os.path.dirname(os.path.realpath(SSHS))), "config/sshs/sshs_watcher.py")


def main(args):
    pass


def _role(w, role):
    return w.user_vars.get("sshs") == role


def _find(tab, role):
    return next((w for w in tab.windows if _role(w, role)), None)


def su_user(shell) -> str:
    """Benutzer nach su, leer = Anmelde-Benutzer."""
    v = shell.user_vars.get("sshs_su", "")
    return "" if v in ("", "-") else v


def in_yazi(shell) -> bool:
    return shell.user_vars.get("sshs_yazi") == "1"


def at_prompt_then(shell, text: str):
    """text an der Prompt der su-Shell tippen; läuft dort yazi, erst mit q beenden und auf die Prompt warten
    (vorab Getipptes würde yazi beim Beenden noch lesen und verwerfen). Gibt nach 10 s auf."""
    from kitty.fast_data_types import add_timer, get_boss
    if not in_yazi(shell):
        if shell.at_prompt:
            shell.write_to_child(text)
        return
    shell.write_to_child("q")
    wid, ticks = shell.id, [0]

    def tick(timer_id):
        ticks[0] += 1
        w = get_boss().window_id_map.get(wid)
        if w is None or ticks[0] > 100:
            remove(timer_id)
            return
        if w.at_prompt and not in_yazi(w):
            remove(timer_id)
            w.write_to_child(text)

    def remove(timer_id):
        from kitty.fast_data_types import remove_timer
        remove_timer(timer_id)

    add_timer(tick, 0.1, True)


def _client_id(shell) -> int:
    # yazi-Client-IDs müssen über alle yazi-Instanzen eindeutig sein: Kitty-PID + Fenster-ID
    return os.getpid() * 1000 + shell.id


def _cwd_file(shell) -> str:
    return os.path.join(RUNTIME, f"{_client_id(shell)}.cwd")


def _shell_cwd(shell) -> str:
    url = shell.screen.last_reported_cwd
    return path_from_osc7_url(url) if url else ""


def _files_cwd(shell) -> str:
    try:
        with open(_cwd_file(shell)) as f:
            url = f.read().strip()
    except OSError:
        return ""
    if url.startswith("sftp://"):  # sftp://<host>//abs/pfad -> /abs/pfad
        url = "/" + url[len("sftp://"):].partition("/")[2].lstrip("/")
    return url


def _url(host, path):
    return f"sftp://{host}//{path.lstrip('/')}" if path else f"sftp://{host}"


def _launch(boss, tab, argv):
    spec = parse_launch_args(argv)
    return launch(boss, spec.opts, spec.args, target_tab=tab)


def toggle(boss, tab):
    shell = _find(tab, "shell")
    if shell is None:
        return
    host = shell.user_vars.get("sshs_host", "")
    vfs = shell.user_vars.get("sshs_vfs", host)   # Name in ~/.config/yazi/vfs.toml (kebab-case)
    files = _find(tab, "files")
    if files is not None and tab.active_window is files:
        # Dateien -> Terminal: in den Ordner wechseln, den yazi gerade zeigt (nur an der Prompt)
        path = _files_cwd(shell)
        if path and path != _shell_cwd(shell) and shell.at_prompt:
            shell.write_to_child(f" cd -- {shlex.quote(path)}\r")
        tab.set_active_window(shell)
        return
    if in_yazi(shell):
        # yazi in der su-Shell -> Terminal: q beendet, die Shell wechselt in yazis letzten Ordner
        shell.write_to_child("q")
        return
    if su_user(shell):
        if shell.at_prompt:
            shell.write_to_child(" _sshs_y\r")
        return
    path = _shell_cwd(shell)
    if files is None:
        os.makedirs(RUNTIME, exist_ok=True)
        _launch(boss, tab, [
            "--type=window", "--var", "sshs=files", "--title", f"{host} · files",
            "--env", f"SSHS_CWD_FILE={_cwd_file(shell)}",
            "yazi", "--client-id", str(_client_id(shell)), _url(vfs, path),
        ])
    else:
        if path and path != _files_cwd(shell):
            subprocess.run(["ya", "emit-to", str(_client_id(shell)), "cd", _url(vfs, path)],
                           check=False, stdout=subprocess.DEVNULL, stderr=subprocess.DEVNULL)
        tab.set_active_window(files)


def new_tab(boss, tab):
    shell = _find(tab, "shell")
    if shell is None:
        return
    host = shell.user_vars.get("sshs_host", "")
    vfs = shell.user_vars.get("sshs_vfs", host)
    path = _files_cwd(shell) if tab.active_window is _find(tab, "files") else _shell_cwd(shell)
    argv = ["--type=tab", "--var", "sshs=shell", "--var", f"sshs_host={host}", "--var", f"sshs_vfs={vfs}",
            "--watcher", WATCHER, SSHS, "_ssh", host]
    _launch(boss, None, argv + ([path] if path else []))


def _transfer(boss, tab, cmd, title, extra=(), tail=()):
    shell = _find(tab, "shell")
    if shell is None:
        return
    host = shell.user_vars.get("sshs_host", "")
    path = _files_cwd(shell) if tab.active_window is _find(tab, "files") else _shell_cwd(shell)
    argv = ["--type=overlay", "--title", f"{host} · {title}", "--cwd", os.path.expanduser("~"),
            "--env", "SSHS_OVERLAY=1", *extra, SSHS, cmd, host]
    if path:
        argv.append(path)
    _launch(boss, tab, argv + list(tail))


def _elevated(tab, shell) -> bool:
    # Dateien-Fenster (SFTP) offen = Anmelde-Benutzer, auch wenn die Shell dahinter gerade root ist
    return bool(su_user(shell)) and tab.active_window is not _find(tab, "files")


def upload(boss, tab):
    shell = _find(tab, "shell")
    if shell is not None and _elevated(tab, shell):
        tok = secrets.token_hex(6)
        # Overlay mit Watcher: beim Schließen sagt die Marke RUNTIME/take-<tok>, ob die su-Shell übernehmen soll
        _transfer(boss, tab, "up", f"hochladen als {su_user(shell)}",
                  ("--var", "sshs=xfer", "--var", f"sshs_take={tok}", "--var", f"sshs_shell={shell.id}",
                   "--watcher", WATCHER), (f"--stage={tok}",))
        return
    _transfer(boss, tab, "up", "hochladen")


def download(boss, tab):
    shell = _find(tab, "shell")
    if shell is not None and _elevated(tab, shell):
        at_prompt_then(shell, " _sshs_give y\r" if in_yazi(shell) else " _sshs_give\r")
        return
    _transfer(boss, tab, "down", "herunterladen")


@result_handler(no_ui=True)
def handle_result(args, answer, target_window_id, boss):
    tab = boss.active_tab
    if tab is None:
        return
    action = args[1] if len(args) > 1 else "toggle"
    {"toggle": toggle, "new_tab": new_tab, "upload": upload, "download": download}.get(action, toggle)(boss, tab)
