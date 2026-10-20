#!/usr/bin/env python3
"""Test für scripts/mail-action mit Fake-Profil und Fake-Cache (kein Netz, kein Thunderbird): python3 scripts/tests/mail-action-test.py"""
import importlib.machinery
import importlib.util
import json
import os
import shutil
import sys
import tempfile

path = os.path.join(os.path.dirname(__file__), "..", "mail-action")
loader = importlib.machinery.SourceFileLoader("mail_action", path)
spec = importlib.util.spec_from_loader("mail_action", loader)
ma = importlib.util.module_from_spec(spec)
loader.exec_module(ma)

fails = 0


def check(name, got, want):
    global fails
    ok = got == want
    fails += not ok
    print(("ok   " if ok else "FAIL ") + name + ("" if ok else f"  got={got!r} want={want!r}"))


def write(p, data, mode="w"):
    os.makedirs(os.path.dirname(p), exist_ok=True)
    with open(p, mode) as f:
        f.write(data)


tmp = tempfile.mkdtemp(prefix="mail-action-test.")

# Message-ID prüfen
check("mid ok", ma.valid_mid("abc.123@host"), "abc.123@host")
check("mid rejects space/quote", (ma.valid_mid("a b@x"), ma.valid_mid("a\"@x"), ma.valid_mid("")), ("", "", ""))

# Mork-Escapes: ) \ $ stehen im .msf mit Backslash
check("mork forms", ma.mork_forms("a$b)c@x"), {b"a$b)c@x", b"a\\$b\\)c@x"})

# Profil finden: Install-Default gewinnt, relative Pfade
root = os.path.join(tmp, "tb")
write(os.path.join(root, "profiles.ini"),
      "[Profile1]\nName=old\nIsRelative=1\nPath=old.default\nDefault=1\n\n"
      "[Profile0]\nName=esr\nIsRelative=1\nPath=new.default-esr\n\n"
      "[InstallABC]\nDefault=new.default-esr\nLocked=1\n")
ma.PROFILE_ROOTS = [os.path.join(tmp, "missing"), root]
prof = ma.profile_dir()
check("profile install default", prof, os.path.join(root, "new.default-esr"))

# Server-Ordner aus prefs.js (Host + Benutzer müssen passen)
write(os.path.join(prof, "prefs.js"),
      'user_pref("mail.server.server1.hostname", "imap.other.com");\n'
      'user_pref("mail.server.server1.directory-rel", "[ProfD]ImapMail/imap.other.com");\n'
      'user_pref("mail.server.server5.hostname", "imap.mail.me.com");\n'
      'user_pref("mail.server.server5.type", "imap");\n'
      'user_pref("mail.server.server5.userName", "me@example.org");\n'
      'user_pref("mail.server.server5.directory-rel", "[ProfD]ImapMail/imap.mail.me.com");\n')
sdir = ma.server_dir(prof, "imap.mail.me.com", "me@example.org")
check("server dir", sdir, os.path.join(prof, "ImapMail/imap.mail.me.com"))
check("server dir wrong user", ma.server_dir(prof, "imap.mail.me.com", "other@example.org"), None)

# Index-Datei: INBOX.msf, Unterordner A.sbd/B.msf, sonst alle
write(os.path.join(sdir, "INBOX.msf"), "(A1=<old@x>)")
write(os.path.join(sdir, "Sent Messages.msf"), "(B1=new@x)")
write(os.path.join(sdir, "Haushalt.sbd", "Strom.msf"), "")
check("msf inbox", ma.msf_paths(sdir, "INBOX"), [os.path.join(sdir, "INBOX.msf")])
check("msf subfolder", ma.msf_paths(sdir, "Haushalt/Strom"), [os.path.join(sdir, "Haushalt.sbd", "Strom.msf")])
check("msf fallback all", len(ma.msf_paths(sdir, "Gibt/Es nicht")), 3)
check("known in inbox", ma.known_locally(ma.msf_paths(sdir, "INBOX"), "old@x"), True)
check("same id only in Sent not counted", ma.known_locally(ma.msf_paths(sdir, "INBOX"), "new@x"), False)

# Öffnen: bekannt -> sofort mid:, unbekannt -> Posteingang + warten, ohne ID -> Posteingang
spawned = []
ma.spawn_client = lambda args: spawned.append(args)
ma.WAIT_SECS = 0.3
ma.POLL_SECS = 0.05
acc = {"name": "icloud", "user": "me@example.org", "mail": {"host": "imap.mail.me.com", "folder": "INBOX"}}
ma.open_client(acc, "old@x", False)
check("open known -> mid", spawned, [["mid:old@x"]])
spawned.clear()
ma.open_client(acc, "fresh@x", False)
check("open unknown -> inbox only after timeout", spawned, [["-mail"]])
spawned.clear()
ma.open_client(acc, "", False)
check("open without id -> inbox", spawned, [["-mail"]])
spawned.clear()
ma.open_client(acc, "old@x", True)
check("dry-run spawns nothing", spawned, [])

# Cache: Mail fällt raus, Zähler sinkt, andere Konten bleiben
cache = os.path.join(tmp, "mail.json")
write(cache, json.dumps({"total": 3, "accounts": [
    {"name": "icloud", "unread": 2, "messages": [{"uid": 7, "mid": "a@x"}, {"uid": 8, "mid": "b@x"}]},
    {"name": "work", "unread": 1, "messages": [{"uid": 7, "mid": "c@x"}]}]}))
check("drop from cache", ma.drop_from_cache(cache, "icloud", 7), True)
with open(cache) as f:
    d = json.load(f)
check("cache after drop", (d["total"], d["accounts"][0]["unread"], [m["uid"] for m in d["accounts"][0]["messages"]],
                           len(d["accounts"][1]["messages"])), (2, 1, [8], 1))
check("drop unknown uid", ma.drop_from_cache(cache, "icloud", 99), False)

# Papierkorb: nur diese UID; MOVE wenn möglich, sonst COPY + \\Deleted (+ UID EXPUNGE nur mit UIDPLUS)
class FakeImap:
    def __init__(self, caps):
        self.capabilities = caps
        self.calls = []

    def uid(self, cmd, *args):
        self.calls.append((cmd,) + args)
        return "OK", [None]


f = FakeImap(("IMAP4REV1", "MOVE", "UIDPLUS"))
check("trash via MOVE", (ma.to_trash(f, 42, "Deleted Messages"), [c[0] for c in f.calls], f.calls[-1][2]),
      (True, ["STORE", "MOVE"], '"Deleted Messages"'))
f = FakeImap(("IMAP4REV1", "UIDPLUS"))
ma.to_trash(f, 42, "Trash")
check("trash via COPY + UID EXPUNGE", [c[0] for c in f.calls], ["STORE", "COPY", "STORE", "EXPUNGE"])
f = FakeImap(("IMAP4REV1",))
ma.to_trash(f, 42, "Trash")
check("no folder-wide EXPUNGE without UIDPLUS", [c[0] for c in f.calls], ["STORE", "COPY", "STORE"])
check("trash needs account", ma.main(["trash", "--uid", "5"]), 2)

# Aufruf ohne Konto/UID markiert nichts
check("seen needs account", ma.main(["seen", "--uid", "5"]), 2)

shutil.rmtree(tmp, ignore_errors=True)
sys.exit(1 if fails else 0)
