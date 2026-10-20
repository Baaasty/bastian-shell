#!/usr/bin/env python3
"""Test für scripts/spotify-api last/resume gegen einen Fake-Server (kein Netz, kein echtes Token):
python3 scripts/tests/spotify-api-test.py"""
import http.server
import importlib.machinery
import importlib.util
import json
import os
import shutil
import sys
import tempfile
import threading
import time
import urllib.parse

tmp = tempfile.mkdtemp(prefix="spotify-api-test.")

# Fake-Spotify: Antworten je "METHODE pfad" aus routes, jede Anfrage landet in seen
routes: dict = {}
seen: list = []


class Fake(http.server.BaseHTTPRequestHandler):
    def log_message(self, *a):
        pass

    def handle_any(self):
        u = urllib.parse.urlparse(self.path)
        n = int(self.headers.get("Content-Length") or 0)
        body = self.rfile.read(n) if n else b""
        seen.append((self.command, u.path, dict(urllib.parse.parse_qsl(u.query)),
                     json.loads(body) if body.strip() else None))
        r = routes.get(f"{self.command} {u.path}", (404, {"error": {"status": 404, "message": "not found"}}))
        if callable(r):
            r = r()
        code, data = r
        raw = b"" if data is None else json.dumps(data).encode()
        self.send_response(code)
        self.send_header("Content-Length", str(len(raw)))
        self.end_headers()
        self.wfile.write(raw)

    do_GET = do_PUT = do_POST = handle_any


srv = http.server.HTTPServer(("127.0.0.1", 0), Fake)
threading.Thread(target=srv.serve_forever, daemon=True).start()
base = f"http://127.0.0.1:{srv.server_port}"

secrets = os.path.join(tmp, "secrets.json")
with open(secrets, "w") as f:
    json.dump({"spotify": {"client_id": "x", "refresh_token": "r", "access_token": "a",
                           "expires_at": int(time.time()) + 3600}}, f)
os.environ.update(SPOTIFY_SECRETS=secrets, SPOTIFY_API_BASE=base, SPOTIFY_TOKEN_URL=base + "/token",
                  SPOTIFY_CACHE=os.path.join(tmp, "cache"), XDG_RUNTIME_DIR=tmp)

path = os.path.join(os.path.dirname(__file__), "..", "spotify-api")
loader = importlib.machinery.SourceFileLoader("spotify_api", path)
spec = importlib.util.spec_from_loader("spotify_api", loader)
sa = importlib.util.module_from_spec(spec)
loader.exec_module(sa)
sa.DEVICE_PAUSE = 0
sa.socket.gethostname = lambda: "mypc.fritz.box"

fails = 0


def check(name, got, want):
    global fails
    ok = got == want
    fails += not ok
    print(("ok   " if ok else "FAIL ") + name + ("" if ok else f"  got={got!r} want={want!r}"))


def reset(**r):
    routes.clear()
    routes.update(r)
    seen.clear()
    shutil.rmtree(os.path.join(tmp, "cache"), ignore_errors=True)  # last-Cache + Rate-Topf frisch


def plays():
    return [(q, b) for m, p, q, b in seen if m == "PUT" and p == "/me/player/play"]


DEVICES = (200, {"devices": [
    {"id": "dot", "name": "Echo Dot", "type": "Speaker", "is_active": True},
    {"id": "lap", "name": "laptop", "type": "Computer", "is_active": False},
    {"id": "pc", "name": "MyPC.fritz.box", "type": "Computer", "is_active": False},
]})
SONG = {"uri": "spotify:track:s1", "name": "Song", "duration_ms": 1000, "artists": [{"name": "Band"}],
        "album": {"images": [{"url": "http://img/64", "width": 64}]}}
# Kontext wie echt mit Anhang (?sessionId=…) – muss ohne an /me/player/play gehen
RECENT = (200, {"items": [{"track": SONG, "context": {"uri": "spotify:playlist:p1?sessionId=1&mode=enhanced"}}]})

# Spotify hat noch einen Spielstand -> auf diesem PC fortsetzen (Hostname gewinnt vor aktivem Gerät)
reset(**{"GET /me/player/devices": DEVICES, "GET /me/player": (200, {"item": SONG}),
         "PUT /me/player/play": (204, None)})
code_res = sa.run(["resume"])
check("resume ok", (code_res[1], code_res[0].get("via")), (0, "resume"))
check("resume on this pc, no body", plays(), [({"device_id": "pc"}, None)])

# Nach Neustart leer (204) -> letzter Song im Kontext
reset(**{"GET /me/player/devices": DEVICES, "GET /me/player": (204, None),
         "GET /me/player/recently-played": RECENT, "PUT /me/player/play": (204, None)})
res, code = sa.run(["resume"])
check("recent ok", (code, res.get("via"), res["track"]["name"], res["track"]["artists"]), (0, "recent", "Song", "Band"))
check("recent plays context at song", plays(),
      [({"device_id": "pc"}, {"context_uri": "spotify:playlist:p1", "offset": {"uri": "spotify:track:s1"}})])

# Kontext weg (404) -> nur der Song
calls = {"n": 0}


def play_once_404():
    calls["n"] += 1
    return (404, {"error": {"status": 404, "message": "Not found"}}) if calls["n"] == 1 else (204, None)


reset(**{"GET /me/player/devices": DEVICES, "GET /me/player": (204, None),
         "GET /me/player/recently-played": RECENT, "PUT /me/player/play": play_once_404})
res, code = sa.run(["resume"])
check("context gone -> track only", (code, [b for _, b in plays()][-1]), (0, {"uris": ["spotify:track:s1"]}))

# Kein PC unter den Geräten -> no_device nach DEVICE_TRIES Versuchen, nichts gespielt
reset(**{"GET /me/player/devices": (200, {"devices": [{"id": "dot", "name": "Echo", "type": "Speaker", "is_active": True}]})})
res, code = sa.run(["resume"])
check("no device", (code, res.get("error")), (1, "no_device"))
check("no device retries", sum(1 for m, p, _, _ in seen if p == "/me/player/devices"), sa.DEVICE_TRIES)
check("no device no play", plays(), [])

# Einziger Computer ohne passenden Namen zählt als dieser PC
reset(**{"GET /me/player/devices": (200, {"devices": [{"id": "only", "name": "other", "type": "Computer"}]}),
         "GET /me/player": (200, {"item": SONG}), "PUT /me/player/play": (204, None)})
sa.run(["resume"])
check("single computer", plays(), [({"device_id": "only"}, None)])

# Kein Verlauf -> nothing
reset(**{"GET /me/player/devices": DEVICES, "GET /me/player": (204, None),
         "GET /me/player/recently-played": (200, {"items": []})})
res, code = sa.run(["resume"])
check("nothing to resume", (code, res.get("error")), (1, "nothing"))

# Premium fehlt -> premium
reset(**{"GET /me/player/devices": DEVICES, "GET /me/player": (200, {"item": SONG}),
         "PUT /me/player/play": (403, {"error": {"status": 403, "message": "Premium required", "reason": "PREMIUM_REQUIRED"}})})
res, code = sa.run(["resume"])
check("premium", (code, res.get("error")), (1, "premium"))

# last: Song + Kontext, danach aus dem Cache (keine zweite Anfrage)
reset(**{"GET /me/player/recently-played": RECENT})
res, code = sa.run(["last"])
check("last", (code, res["track"]["uri"], res["track"]["image"], res["context"]),
      (0, "spotify:track:s1", "http://img/64", "spotify:playlist:p1"))
sa.run(["last"])
check("last cached", sum(1 for m, p, _, _ in seen if p == "/me/player/recently-played"), 1)

# last ohne Scope (403) -> leer statt Fehler
reset(**{"GET /me/player/recently-played": (403, {"error": {"status": 403, "message": "Insufficient client scope"}})})
res, code = sa.run(["last"])
check("last without scope", (code, res), (0, {"track": None, "context": ""}))

srv.shutdown()
shutil.rmtree(tmp, ignore_errors=True)
sys.exit(1 if fails else 0)
