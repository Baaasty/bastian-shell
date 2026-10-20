#!/usr/bin/env python3
"""Test für scripts/projectstats gegen ein temporäres Git-Repo (eigenes HOME, nichts Echtes wird gelesen oder geschrieben):
python3 scripts/tests/projectstats-test.py"""
import datetime as dt
import json
import os
import subprocess
import sys
import tempfile
from pathlib import Path

SCRIPT = Path(__file__).resolve().parent.parent / "projectstats"
fails = 0


def check(name, got, want):
    global fails
    ok = got == want
    fails += not ok
    print(("ok   " if ok else "FAIL ") + name + ("" if ok else f"  got={got!r} want={want!r}"))


with tempfile.TemporaryDirectory() as tmp:
    home = Path(tmp) / "home"
    repo = Path(tmp) / "repo"
    home.mkdir()
    repo.mkdir()
    env = {"PATH": os.environ.get("PATH", "/usr/bin:/bin"), "HOME": str(home), "LANG": "C.UTF-8",
           "GIT_CONFIG_NOSYSTEM": "1"}

    def git(*args, author="Me <me@example.com>", when=None):
        e = dict(env)
        name, mail = author[:-1].split(" <")
        e.update(GIT_AUTHOR_NAME=name, GIT_AUTHOR_EMAIL=mail, GIT_COMMITTER_NAME=name, GIT_COMMITTER_EMAIL=mail)
        if when:
            e.update(GIT_AUTHOR_DATE=when, GIT_COMMITTER_DATE=when)
        subprocess.run(["git", "-C", str(repo), *args], env=e, check=True, capture_output=True)

    def write(rel, text):
        p = repo / rel
        p.parent.mkdir(parents=True, exist_ok=True)
        p.write_bytes(text if isinstance(text, bytes) else text.encode())

    git("init", "-q", "-b", "main")
    git("config", "user.email", "me@example.com")
    old = (dt.datetime.now() - dt.timedelta(days=10)).strftime("%Y-%m-%dT%H:%M:%S")
    now = dt.datetime.now().strftime("%Y-%m-%dT%H:%M:%S")

    # alter Commit: zählt nur „gesamt“; Vendor, Lockfile, Binäres, Daten zählen nie als Code
    write("README.md", "# x\nzwei\n")
    write("node_modules/lib/index.js", "a\nb\nc\n")
    write("package-lock.json", "{}\n" * 50)
    write("bin.ts", b"\0\1\2\n\n")
    write("data.json", "{\n}\n")
    write("app.min.js", "x\n")
    git("add", "-A")
    git("commit", "-qm", "alt", when=old)

    # heute, eigener Commit: +3 a.py, +2 Skript ohne Endung (Shebang), README 1 Zeile geändert
    write("a.py", "1\n2\n3\n")
    write("tool", "#!/usr/bin/env python3\nprint(1)\n")
    write("README.md", "# x\ndrei\n")
    git("add", "-A")
    git("commit", "-qm", "heute", when=now)

    # heute, fremder Autor: zählt nicht als eigener Commit
    write("b.py", "1\n2\n3\n4\n5\n")
    git("add", "-A")
    git("commit", "-qm", "fremd", author="Other <other@example.com>", when=now)

    # Projektzeit: heute 120 s, früher 60 s, anderes Projekt egal
    pt = home / ".local" / "state" / "desktop" / "projecttime"
    pt.mkdir(parents=True)
    (pt / f"{dt.date.today().isoformat()}.json").write_text(json.dumps({"total": {"p": 120, "q": 999}}))
    (pt / "2020-01-01.json").write_text(json.dumps({"total": {"p": 60}}))

    def run(*args):
        r = subprocess.run([sys.executable, "-I", str(SCRIPT), *args], env=env, capture_output=True, text=True)
        return json.loads(r.stdout)

    s = run(str(repo), "--project", "p")
    check("time", s["time"], {"today": 120, "week": 120, "all": 180})
    check("email", s["email"], "me@example.com")
    check("commits", s["commits"], {"today": 1, "week": 1, "all": 2})
    check("changes today", s["changes"], {"added": 6, "deleted": 1})
    loc = {x["lang"]: x["lines"] for x in s["loc"]}
    check("loc", loc, {"Py": 10, "MD": 2})

    # LOC hängt am Commit: ungespeicherte Änderung ändert nichts, neuer Commit schon
    write("a.py", "1\n" * 30)
    check("loc cached by HEAD", {x["lang"]: x["lines"] for x in run(str(repo))["loc"]}, {"Py": 10, "MD": 2})
    check("cache file", (home / ".local" / "state" / "desktop" / "projectstats.json").exists(), True)
    git("commit", "-qam", "mehr", when=now)
    check("loc after commit", {x["lang"]: x["lines"] for x in run(str(repo))["loc"]}, {"Py": 37, "MD": 2})
    check("no project: no time", run(str(repo))["time"], None)

    # kein Git-Ordner: nur Zeit, Rest leer
    plain = Path(tmp) / "plain"
    plain.mkdir()
    s = run(str(plain), "--project", "p")
    check("no repo", (s["commits"], s["changes"], s["loc"], s["time"]["all"]), (None, None, None, 180))

print("projectstats-test:", "FAIL" if fails else "ok")
sys.exit(1 if fails else 0)
