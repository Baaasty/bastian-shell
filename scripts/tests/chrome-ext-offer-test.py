#!/usr/bin/env python3
"""Test für scripts/chrome-ext „Speichern anbieten“: Entscheidung, Nie-Liste, Ablauf, kein Passwort in Meldung/argv/
Nachrichten an die Seite (ohne Browser, ohne iCloud – scripts/passwords und notify-send sind ersetzt):
python3 -I scripts/tests/chrome-ext-offer-test.py"""
import contextlib
import importlib.machinery
import importlib.util
import io
import json
import os
import pathlib
import shutil
import stat
import sys
import tempfile

path = os.path.join(os.path.dirname(__file__), "..", "chrome-ext")
loader = importlib.machinery.SourceFileLoader("chrome_ext", path)
spec = importlib.util.spec_from_loader("chrome_ext", loader)
ce = importlib.util.module_from_spec(spec)
loader.exec_module(ce)

fails = 0
REAL = sys.stdout   # Prüfzeilen hierhin, damit die abgefangene Ausgabe des Hosts leer bleiben kann
SECRET = "geheim-Pa55wort-xyz"


def check(name, got, want):
    global fails
    ok = got == want
    fails += not ok
    print(("ok   " if ok else "FAIL ") + name + ("" if ok else f"  got={got!r} want={want!r}"), file=REAL)


def entry(i, user, has_pw=True, **kw):
    return {"id": f"{i:016x}", "user": user, "hasPassword": has_pw, "hasTotp": False,
            "urls": ["https://example.com"], "editable": True, **kw}


# ---------- Entscheidung ----------
anna, bob = entry(1, "anna@example.com"), entry(2, "bob")
check("nichts da -> save", ce.decide([], "anna@example.com", None), ("save", None))
check("anderer Benutzer -> add", ce.decide([bob], "anna@example.com", None), ("add", None))
check("gleicher Benutzer, gleiches Passwort -> none", ce.decide([anna], "anna@example.com", True), ("none", None))
check("gleicher Benutzer, anderes Passwort -> update", ce.decide([bob, anna], "Anna@Example.com ", False),
      ("update", anna["id"]))
check("gleicher Benutzer ohne Passwort -> update", ce.decide([entry(3, "anna", has_pw=False)], "anna", None),
      ("update", f"{3:016x}"))
check("geteilte Gruppe (nicht editierbar) -> none", ce.decide([entry(4, "anna", editable=False)], "anna", False),
      ("none", None))
check("Nie-Liste -> none", ce.decide([], "anna", None, never=True), ("none", None))
check("„Nie sichern“-Eintrag ohne alles zählt nicht als anderer Login",
      ce.decide([entry(5, "", has_pw=False)], "anna", None), ("save", None))

blank = entry(6, "", has_pw=False, urls=["https://www.example.com"])
check("Apple-„Nie sichern“ greift für den Host", ce.apple_never([blank], "example.com"), True)
check("Apple-„Nie sichern“ nicht für andere Hosts", ce.apple_never([blank], "login.example.com"), False)
check("Apple-„Nie sichern“ nicht bei echten Logins", ce.apple_never([anna], "example.com"), False)
check("site_host ohne www", ce.site_host("https://WWW.Example.com:8443/login"), "example.com")

# ---------- Nie-Liste (nur Hostnamen, 600) ----------
tmp = pathlib.Path(tempfile.mkdtemp(prefix="chrome-ext-test."))
never = tmp / "passwords-never.json"
ce.NEVER = never
check("Nie-Liste fehlt -> leer", ce.load_never(), set())
ce.add_never("example.com")
ce.add_never("example.com")
ce.add_never("foo.test")
check("Nie-Liste Inhalt", json.loads(never.read_text()), {"sites": ["example.com", "foo.test"]})
check("Nie-Liste 600", stat.S_IMODE(never.stat().st_mode), 0o600)
never.write_text("kaputt")
check("Nie-Liste kaputt -> leer", ce.load_never(), set())
never.unlink()

# ---------- Ablauf mit Ersatz für scripts/passwords, notify-send, Native Messaging ----------
calls, sent, argvs = [], [], []
db = {"entries": []}
notify_answer = {"value": ("save", False, 3.0)}


def fake_pw_run(*args, stdin=None):
    calls.append((args, stdin))
    if args[0] == "match":
        return json.dumps(db["entries"])
    if args[0] == "get":
        return db["password"]
    return json.dumps({"ok": True, "pending": True})


def fake_notify(argv):
    argvs.append(argv)
    return notify_answer["value"]


ce.pw_run = fake_pw_run
ce.run_notify = fake_notify
ce.send = sent.append
ce.spawn = lambda fn, *a: fn(*a)                      # synchron statt Thread
ce.notify_error = lambda site, err: argvs.append(["notify-error", site, err])


def offer(user="anna@example.com", tab=7, url="https://www.example.com/login?next=/x"):
    return ce.pw_offer({"url": url, "user": user, "password": SECRET, "signup": False, "tab": tab})


out, err = io.StringIO(), io.StringIO()
with contextlib.redirect_stdout(out), contextlib.redirect_stderr(err):
    # 1. neu, Benachrichtigung -> Save
    r = offer()
    check("neu -> save angeboten", r["action"], "save")
    creates = [c for c in calls if c[0][0] == "create"]
    check("create --detach aufgerufen", [c[0] for c in creates], [("create", "--detach")])
    check("create bekommt Passwort nur über stdin",
          json.loads(creates[0][1]), {"urls": ["https://www.example.com"], "user": "anna@example.com",
                                      "password": SECRET})
    check("Angebot danach vergessen", ce.offers, {})

    # 2. gleicher Benutzer, gleiches Passwort -> nichts, keine Meldung
    db["entries"], db["password"] = [entry(1, "anna@example.com")], SECRET
    n = len(argvs)
    check("gleiches Passwort -> none", offer()["action"], "none")
    check("gleiches Passwort -> keine Meldung", len(argvs), n)

    # 3. anderes Passwort -> update per edit --detach
    db["password"] = "altes-passwort"
    calls.clear()
    notify_answer["value"] = ("update", False, 2.0)
    check("anderes Passwort -> update", offer()["action"], "update")
    edits = [c for c in calls if c[0][0] == "edit"]
    check("edit <id> --detach", [c[0] for c in edits], [("edit", f"{1:016x}", "--detach")])
    check("edit bekommt nur das Passwort über stdin", json.loads(edits[0][1]), {"password": SECRET})

    # 4. Popup abgelaufen (leer nach > 1 s) -> nichts speichern, keine Leiste
    db["entries"] = []
    calls.clear()
    sent.clear()
    notify_answer["value"] = ("", False, 6.5)
    offer()
    check("abgelaufen -> kein create", [c for c in calls if c[0][0] == "create"], [])
    check("abgelaufen -> keine Leiste", sent, [])
    check("abgelaufen -> vergessen", ce.offers, {})

    # 5. unterdrückt (sofort leer) -> Leiste in der Seite, ohne Passwort; Antwort aus der Leiste
    notify_answer["value"] = ("", False, 0.05)
    r = offer()
    bar = sent[-1] if sent else {}
    check("unterdrückt -> offer-bar", (bar.get("type"), bar.get("tab"), bar.get("kind"), bar.get("site")),
          ("offer-bar", 7, "save", "example.com"))
    check("offer-bar trägt die Angebots-ID", bar.get("offer"), r["offer"])
    check("gleiches Formular nochmal -> kein zweites Angebot", offer()["action"], "none")
    try:
        ce.pw_offer_answer({"offer": r["offer"], "answer": "save", "tab": 8})
        check("Antwort aus fremdem Tab abgelehnt", "angenommen", "abgelehnt")
    except ce.PwError:
        check("Antwort aus fremdem Tab abgelehnt", True, True)
    ce.pw_offer_answer({"offer": r["offer"], "answer": "save", "tab": 7})
    check("Leiste -> create", [c[0] for c in calls if c[0][0] == "create"], [("create", "--detach")])
    try:
        ce.pw_offer_answer({"offer": r["offer"], "answer": "save", "tab": 7})
        check("zweite Antwort abgelehnt", "angenommen", "abgelehnt")
    except ce.PwError:
        check("zweite Antwort abgelehnt", True, True)

    # 6. Nie für diese Website (über die Leiste) -> Nie-Liste, danach kein Angebot mehr
    r = offer()
    ce.pw_offer_answer({"offer": r["offer"], "answer": "never", "tab": 7})
    check("never -> Nie-Liste", ce.load_never(), {"example.com"})
    check("Nie-Liste -> kein Angebot", offer()["action"], "none")
    never.unlink()

    # 7. Fehler beim Anlegen -> Benachrichtigung mit Meldung (ohne Passwort)
    def failing(*args, stdin=None):
        if args[0] == "create":
            raise ce.PwError("a login for example.com / anna exists already – edit it instead")
        return fake_pw_run(*args, stdin=stdin)
    ce.pw_run = failing
    notify_answer["value"] = ("save", False, 2.0)
    offer()
    check("Fehler -> Meldung", argvs[-1][0], "notify-error")
    ce.pw_run = fake_pw_run

    # 8. localhost mit Port: Website ohne Port (icp nimmt keine Ports)
    calls.clear()
    offer(user="dev", url="http://localhost:8765/login")
    check("localhost:8765 -> Website http://localhost",
          [json.loads(c[1])["urls"] for c in calls if c[0][0] == "create"], [["http://localhost"]])

    # 9. ohne Benutzer kein Angebot (iCloud braucht einen)
    check("ohne Benutzer -> none", offer(user="  ")["action"], "none")

    # 10. Ablauf: Angebot (samt Passwort) nach OFFER_TTL weg
    notify_answer["value"] = ("", False, 0.05)
    r = offer()
    check("Angebot gehalten", r["offer"] in ce.offers, True)
    ce.purge(now=ce.offers[r["offer"]]["created"] + ce.OFFER_TTL - 1)
    check("vor Ablauf noch da", r["offer"] in ce.offers, True)
    ce.purge(now=ce.offers[r["offer"]]["created"] + ce.OFFER_TTL + 1)
    check("nach Ablauf weg", r["offer"] in ce.offers, False)
    try:
        ce.pw_offer_answer({"offer": r["offer"], "answer": "save", "tab": 7})
        check("Antwort nach Ablauf abgelehnt", "angenommen", "abgelehnt")
    except ce.PwError:
        check("Antwort nach Ablauf abgelehnt", True, True)

    # 11. Unsinn abweisen
    for bad in ({"url": "http://example.com/", "user": "a", "password": "x", "tab": 1},
                {"url": "https://example.com/", "user": "a", "password": "", "tab": 1},
                {"url": "https://example.com/", "user": "a", "password": "x"}):
        try:
            ce.pw_offer(bad)
            check(f"abgewiesen: {sorted(bad)}", "angenommen", "abgelehnt")
        except ce.PwError:
            check(f"abgewiesen: {sorted(bad)}", True, True)

# ---------- nirgends das Passwort: Meldungen, argv, Nachrichten, Ausgabe ----------
check("Passwort nie in notify-send-argv", any(SECRET in " ".join(a) for a in argvs), False)
check("Passwort nie in Nachrichten an die Erweiterung", any(SECRET in json.dumps(m) for m in sent), False)
check("Passwort nie als Argument an scripts/passwords", any(SECRET in " ".join(c[0]) for c in calls), False)
check("keine Ausgabe auf stdout/stderr", (out.getvalue(), err.getvalue()), ("", ""))
argv = ce.offer_argv("update", "example.com", "anna")
check("Meldung: transient, wartet, zwei Aktionen", ("-e" in argv, "-w" in argv, argv.count("-A")), (True, True, 2))
check("Meldung: Titel + Benutzer", argv[-2:], ["Update password for example.com?", "anna · iCloud Passwords"])

shutil.rmtree(tmp, ignore_errors=True)
print("alles ok" if not fails else f"{fails} Fehler", file=sys.stderr if fails else sys.stdout)
sys.exit(1 if fails else 0)
