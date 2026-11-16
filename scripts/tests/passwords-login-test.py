#!/usr/bin/env python3
"""Test für scripts/passwords „iCloud-Login nötig“: Login-Fehler erkennen, nur einmal pro Vorfall melden,
Login erkannt, Auftrag wird nach dem Login gespeichert oder nur auf „Discard“ verworfen (ohne iCloud, ohne
notify-send/Terminal – ersetzt): python3 -I scripts/tests/passwords-login-test.py"""
import importlib.machinery
import importlib.util
import os
import sys
import tempfile
import time

tmp = tempfile.mkdtemp()
os.environ["PASSWORDS_LOGIN_NOTIFIED"] = os.path.join(tmp, "notified")
os.environ["PASSWORDS_LOGIN_OK"] = os.path.join(tmp, "ok")

path = os.path.join(os.path.dirname(__file__), "..", "passwords")
loader = importlib.machinery.SourceFileLoader("passwords", path)
spec = importlib.util.spec_from_loader("passwords", loader)
pw = importlib.util.module_from_spec(spec)
loader.exec_module(pw)
pw.STATE_DIR = tmp

fails = 0


def check(name, got, want):
    global fails
    ok = got == want
    fails += not ok
    print(("ok   " if ok else "FAIL ") + name + ("" if ok else f"  got={got!r} want={want!r}"))


EXPIRED = "iCloud credentials expired (unauthorized) - run `icp login` to re-authenticate"

# ---------- Login-Fehler erkennen ----------
check("abgelaufen = Login-Fehler", pw.is_login_error(EXPIRED), True)
check("nicht angemeldet = Login-Fehler", pw.is_login_error("not signed in / joined - run: icp login"), True)
check("anderer Fehler nicht", pw.is_login_error("a login for x / y exists already"), False)
check("leer nicht", pw.is_login_error(None), False)

# ---------- Anisette: lokaler Socket als Vorgabe ----------
check("Anisette-URL gesetzt", os.environ.get("ICP_ANISETTE_URL", "").startswith("http://127.0.0.1:"), True)

# ---------- nur einmal pro Vorfall melden ----------
check("Login nötig -> melden", pw.should_notify_login({"needs_login": True}), True)
check("zweiter Lauf -> nicht nochmal", pw.should_notify_login({"needs_login": True}), False)
check("wieder ok -> nicht melden", pw.should_notify_login({"needs_login": False}), False)
check("Merker nach Erfolg weg", os.path.exists(pw.LOGIN_NOTIFIED), False)
check("neuer Vorfall -> wieder melden", pw.should_notify_login({"needs_login": True}), True)

# ---------- Login erkannt ----------
t0 = time.time() - 1
check("ohne Login nichts", pw.login_done_since(t0, {}), False)
check("Sync danach zählt", pw.login_done_since(t0, {"last_success": t0 + 0.5}), True)
check("alter Sync zählt nicht", pw.login_done_since(t0, {"last_success": t0 - 10}), False)
with open(pw.LOGIN_OK, "w") as fh:
    fh.write("x")
check("Login-Terminal zählt", pw.login_done_since(t0, {}), True)
os.remove(pw.LOGIN_OK)

# ---------- Auftrag festhalten ----------
asked, opened = [], []


def fake_notify(choices):
    def notify(argv):
        asked.append(argv)
        return choices.pop(0) if choices else ""
    return notify


pw.open_login = lambda: opened.append(1)          # Panel (oder Terminal, wenn die Shell fehlt)
pw.time.sleep = lambda s: None
pw.login_done_since = lambda t0, state=None: True     # Login klappt sofort

pw.notify_choice = fake_notify(["discard"])
calls = []
err = pw.hold_for_login("x.example", lambda: calls.append(1), EXPIRED)
check("Discard -> verworfen, kein Speichern", (err, calls, opened), (EXPIRED, [], []))

asked.clear()
pw.notify_choice = fake_notify(["login", ""])
err = pw.hold_for_login("x.example", lambda: None, EXPIRED)
check("Log in & save -> gespeichert", (err, len(opened)), (None, 1))
check("Titel steht in der Meldung", "x.example" in " ".join(asked[0]), True)

opened.clear()
results = [EXPIRED, None]
pw.notify_choice = fake_notify(["login", "login", ""])
err = pw.hold_for_login("x.example", lambda: results.pop(0), EXPIRED)
check("Login nochmal nötig -> neu gefragt, dann gespeichert", (err, len(opened)), (None, 2))

err = pw.hold_for_login("x.example", lambda: None, "network down")
check("fremder Fehler -> unverändert zurück", err, "network down")

print("FAIL" if fails else "alles ok")
sys.exit(1 if fails else 0)
