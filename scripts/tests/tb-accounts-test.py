#!/usr/bin/env python3
"""Test für scripts/tb-accounts mit Fake-Profil, Fake-prefs.js und Fake-Entschlüsselung (kein NSS, kein Thunderbird): python3 scripts/tests/tb-accounts-test.py"""
import importlib.machinery
import importlib.util
import json
import os
import shutil
import tempfile


def load(name, file):
    path = os.path.join(os.path.dirname(__file__), "..", file)
    loader = importlib.machinery.SourceFileLoader(name, path)
    spec = importlib.util.spec_from_loader(name, loader)
    mod = importlib.util.module_from_spec(spec)
    loader.exec_module(mod)
    return mod


tb = load("tb_accounts", "tb-accounts")
ms = load("mail_status", "mail-status")

fails = 0


def check(name, got, want):
    global fails
    ok = got == want
    fails += not ok
    print(("ok   " if ok else "FAIL ") + name + ("" if ok else f"  got={got!r} want={want!r}"))


def write(p, data):
    os.makedirs(os.path.dirname(p), exist_ok=True)
    with open(p, "w") as f:
        f.write(data)


tmp = tempfile.mkdtemp(prefix="tb-accounts-test.")
ICLOUD = {"name": "icloud", "user": "Bastian@icloud.com", "password": "thunderbird",
          "mail": {"host": "imap.mail.me.com"}, "caldav": {"url": "https://caldav.icloud.com/"}}

# Schlüsselwort
check("wanted", (tb.wanted(ICLOUD), tb.wanted({"password": " Thunderbird "}), tb.wanted({"password": "abcd-efgh"}),
                 tb.wanted({})), (True, True, False, False))

# Domains aus IMAP- und CalDAV-Host
check("domains icloud", tb.domains(ICLOUD), ["me.com", "icloud.com"])
check("domains caldav port", tb.domains({"mail": {"host": "mail.example.org"},
                                         "caldav": {"url": "https://dav.example.org:8443/x"}}), ["example.org"])
check("host_of", (tb.host_of("imap://imap.mail.me.com"), tb.host_of("https://p39-caldav.icloud.com:443"),
                  tb.host_of("mailbox://u@pop.x.de/inbox")), ("imap.mail.me.com", "p39-caldav.icloud.com", "pop.x.de"))
check("same_user", (tb.same_user("bastian@icloud.com", "Bastian@icloud.com"), tb.same_user("bastian", "bastian@icloud.com"),
                    tb.same_user("other@icloud.com", "bastian@icloud.com"), tb.same_user("", "x")), (True, True, False, False))

# Auswahl: passende Domain + User, neuestes Passwort gewinnt; fremde Domain/fremder User zählen nicht
fake = {"u1": "bastian@icloud.com", "u2": "someone@icloud.com", "p-old": "old", "p-new": "new", "p-x": "evil"}
entries = [
    {"hostname": "imap://imap.mail.me.com", "encryptedUsername": "u1", "encryptedPassword": "p-old", "timePasswordChanged": 100},
    {"hostname": "https://p39-caldav.icloud.com", "encryptedUsername": "u1", "encryptedPassword": "p-new", "timePasswordChanged": 200},
    {"hostname": "https://p39-caldav.icloud.com", "encryptedUsername": "u2", "encryptedPassword": "p-x", "timePasswordChanged": 900},
    {"hostname": "https://icloud.com.evil.net", "encryptedUsername": "u1", "encryptedPassword": "p-x", "timePasswordChanged": 999},
]
check("pick newest", tb.pick(entries, "Bastian@icloud.com", tb.domains(ICLOUD), fake.get), "new")
check("pick none", tb.pick(entries, "nobody@icloud.com", tb.domains(ICLOUD), fake.get), None)

# Profilwahl: Install-Default vor Default=1
root = os.path.join(tmp, "tb")
write(os.path.join(root, "profiles.ini"),
      "[Profile0]\nName=a\nIsRelative=1\nPath=a.default\nDefault=1\n\n[Install4F96]\nDefault=b.default-esr\n")
check("profile install default", tb.profile_dir([os.path.join(tmp, "missing"), root]), os.path.join(root, "b.default-esr"))
write(os.path.join(root, "profiles.ini"), "[Profile0]\nName=a\nIsRelative=1\nPath=a.default\nDefault=1\n")
check("profile default=1", tb.profile_dir([root]), os.path.join(root, "a.default"))

# lookup: kein Profil / Hauptpasswort / gefunden (NSS ersetzt)
tb.PROFILE_ROOTS = [os.path.join(tmp, "missing")]
check("lookup no-profile", tb.lookup(ICLOUD), (None, "no-profile"))
tb.PROFILE_ROOTS = [root]
write(os.path.join(root, "a.default", "logins.json"), json.dumps({"logins": entries}))


class FakeNss:
    locked = False

    def __init__(self, profile):
        pass

    def __enter__(self):
        if FakeNss.locked:
            raise PermissionError("locked")
        return self

    def __exit__(self, *exc):
        return False

    def decrypt(self, b64):
        return fake.get(b64)


tb.Nss = FakeNss
check("lookup ok", tb.lookup(ICLOUD), ("new", "ok"))
FakeNss.locked = True
check("lookup locked", tb.lookup(ICLOUD), (None, "locked"))
FakeNss.locked = False

# mail-status: Status fürs Dashboard
ms.TB = tb
check("status tb ok", ms.password_status(ICLOUD), ("new", None))
check("status tb-missing", ms.password_status(dict(ICLOUD, user="nobody@icloud.com")), (None, "tb-missing"))
FakeNss.locked = True
check("status tb-locked", ms.password_status(ICLOUD), (None, "tb-locked"))
FakeNss.locked = False
check("status direct", ms.password_status({"password": "abcd-efgh"}), ("abcd-efgh", None))
check("status empty", ms.password_status({"password": ""}), (None, "no-password"))

# Konten aus prefs.js: iCloud (IMAP + 2 Kalender, einer aus), Gmail (OAuth), POP, Lokale Ordner, Kalender-Konto für sich
PREFS = r"""// Mozilla User Preferences
user_pref("mail.accountmanager.accounts", "account1,account2,account3,account4");
user_pref("mail.account.account1.server", "server5");
user_pref("mail.server.server5.type", "imap");
user_pref("mail.server.server5.hostname", "imap.mail.me.com");
user_pref("mail.server.server5.port", 993);
user_pref("mail.server.server5.socketType", 3);
user_pref("mail.server.server5.userName", "bastian@icloud.com");
user_pref("mail.server.server5.name", "Privat \"iCloud\"");
user_pref("mail.account.account2.server", "server6");
user_pref("mail.server.server6.type", "none");
user_pref("mail.server.server6.hostname", "Local Folders");
user_pref("mail.server.server6.userName", "nobody");
user_pref("mail.account.account3.server", "server7");
user_pref("mail.server.server7.type", "imap");
user_pref("mail.server.server7.hostname", "imap.gmail.com");
user_pref("mail.server.server7.userName", "b@gmail.com");
user_pref("mail.server.server7.authMethod", 10);
user_pref("mail.account.account4.server", "server8");
user_pref("mail.server.server8.type", "pop3");
user_pref("mail.server.server8.hostname", "pop.example.org");
user_pref("mail.server.server8.userName", "b@example.org");
user_pref("calendar.registry.aaa.type", "caldav");
user_pref("calendar.registry.aaa.uri", "https://p39-caldav.icloud.com/1/calendars/A/");
user_pref("calendar.registry.aaa.username", "bastian@icloud.com");
user_pref("calendar.registry.aaa.name", "Privat");
user_pref("calendar.registry.aaa.color", "#63DA38");
user_pref("calendar.registry.bbb.type", "caldav");
user_pref("calendar.registry.bbb.uri", "https://p39-caldav.icloud.com/1/calendars/B/");
user_pref("calendar.registry.bbb.username", "bastian@icloud.com");
user_pref("calendar.registry.bbb.disabled", true);
user_pref("calendar.registry.ccc.type", "caldav");
user_pref("calendar.registry.ccc.uri", "https://dav.work.de/cal/team/");
user_pref("calendar.registry.ccc.username", "me@work.de");
user_pref("calendar.registry.ccc.name", "Team");
user_pref("calendar.registry.ddd.type", "storage");
user_pref("calendar.registry.ddd.uri", "moz-storage-calendar://");
"""
write(os.path.join(root, "a.default", "prefs.js"), PREFS)
prefs = tb.read_prefs(os.path.join(root, "a.default"))
check("prefs types", (prefs["mail.server.server5.port"], prefs["calendar.registry.bbb.disabled"],
                      prefs["mail.server.server5.name"]), (993, True, 'Privat "iCloud"'))
found = {a["name"]: a for a in tb.accounts()}
check("accounts names", sorted(found), ["example", "gmail", "icloud", "work"])
ic = found["icloud"]
check("icloud mail", (ic["mail"], ic.get("skip"), ic["password"], ic["label"]),
      ({"host": "imap.mail.me.com", "port": 993, "folder": "INBOX"}, None, "thunderbird", 'Privat "iCloud"'))
check("icloud calendars (disabled raus)", (ic["caldav"]["hrefs"], ic["caldav"]["names"], ic["caldav"]["colors"]),
      (["https://p39-caldav.icloud.com/1/calendars/A/"], {"https://p39-caldav.icloud.com/1/calendars/A/": "Privat"},
       {"https://p39-caldav.icloud.com/1/calendars/A/": "#63DA38"}))
check("skip reasons", (found["gmail"].get("skip"), found["example"].get("skip")), ("oauth", "unsupported"))
check("calendar-only account", (found["work"].get("mail"), found["work"]["caldav"]["url"], found["work"]["label"]),
      (None, "https://dav.work.de/cal/team/", "Team"))
check("password_status skip", ms.password_status(found["gmail"]), (None, "tb-oauth"))

# Zusammenführen: eigener Eintrag gewinnt, Name kollidiert nicht
own = [dict(ICLOUD), {"name": "work", "user": "x@other.de", "mail": {"host": "imap.other.de"}}]
merged = tb.merge(own, list(found.values()))
names = [a["name"] for a in merged]
check("merge keeps own icloud", (names.count("icloud"), merged[0] is own[0]), (1, True))
check("merge renames clash", "work-tb" in names and "work" in names, True)
check("fingerprint stable", tb.fingerprint(merged) == tb.fingerprint(list(reversed(merged))), True)

# load_accounts: TB-Konten dazu, mit Abschalter
cfg = os.path.join(tmp, "secrets.json")
write(cfg, json.dumps({"accounts": [ICLOUD]}))
ms.CONFIG = cfg
check("load merged", sorted(a["name"] for a in ms.load_accounts()[1]), ["example", "gmail", "icloud", "work"])
write(cfg, json.dumps({"accounts": [ICLOUD], "thunderbirdAccounts": False}))
check("load off", [a["name"] for a in ms.load_accounts()[1]], ["icloud"])
ms.CONFIG = os.path.join(tmp, "missing.json")
check("load without secrets", ms.load_accounts()[0], "ok")

# Agenda: TB-Kalender per Pfad wiedererkennen (Server nennt evtl. anderen pNN-Host)
ag = load("agenda_status", "agenda-status")
check("cal_key", ag.cal_key("https://p39-caldav.icloud.com/1/Calendars/A/") == ag.cal_key("https://p12-caldav.icloud.com/1/calendars/A"), True)

shutil.rmtree(tmp)
raise SystemExit(1 if fails else 0)
