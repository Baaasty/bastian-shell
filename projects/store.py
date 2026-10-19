"""Desktop-Einstellungen der Projekte: projects/projects.json lesen, prüfen und atomar schreiben.

Einziger Schreiber ist dieses Modul – benutzt von scripts/project (CLI) und scripts/vscode-colors
(theme/gen/vscode_projects.py). Nie von Hand und nie aus QML schreiben. Schema: projects/README.md.
Nach jedem Speichern wird theme/projects.json neu erzeugt (Kompatibilität: VS-Code-Erweiterung
„Desktop Projekte“, Claude-Zentrale, Antwort-Karte, /project lesen weiter diese flache Liste).
Projekt-Repos werden nur gelesen (detect: package.json, apps/*/package.json, .env.example, compose) – nie .env.
"""
import contextlib
import fcntl
import json
import os
import pathlib
import re
import subprocess

ROOT = pathlib.Path(__file__).resolve().parents[1]
HOME = pathlib.Path.home()
FILE = ROOT / "projects/projects.json"             # lokal (gitignored), einziges Schreibziel
EXAMPLE = ROOT / "projects/projects.example.json"  # Beispiel im Repo: gilt nur zum Lesen, solange FILE fehlt
COMPAT = ROOT / "theme/projects.json"
PALETTE = ROOT / "theme/palette.json"
VERSION = 1
KINDS = ("kunde", "labs", "intern", "privat")
TERMINALS = ("dev", "shell")
HEX = re.compile(r"^#[0-9a-fA-F]{6}$")
ID_RE = re.compile(r"^[A-Za-z0-9._-]+$")
URL_RE = re.compile(r"^[a-z][a-z0-9+.-]*://\S+$")
HINT = ("Desktop-Einstellungen pro Projekt (Farbe, Tönung, Dev-Ports, was der Projekt-Desktop öffnet, Links). "
        "Nur über scripts/project ändern (Schema: projects/README.md) – erzeugt theme/projects.json mit.")
COMPAT_HINT = ("ERZEUGT aus projects/projects.json (scripts/project) – nicht von Hand ändern. Flache Liste Pfad -> Farbe "
               "für VS-Code-Erweiterung, Claude-Zentrale, Antwort-Karte und /project.")


# ── Pfade ─────────────────────────────────────────────────────────────────
def rel(p) -> str:
    p = pathlib.Path(os.path.expanduser(str(p)))
    try:
        return "~/" + str(p.relative_to(HOME))
    except ValueError:
        return str(p)


def absp(r) -> pathlib.Path:
    return pathlib.Path(os.path.expanduser(str(r)))


def targets(e: dict) -> list:
    """Alles, was VS Code für dieses Projekt öffnen/tönen kann: Arbeitsbereich zuerst, dann die Repos."""
    return ([e["workspace"]] if e.get("workspace") else []) + list(e.get("paths") or [])


def main_path(e: dict):
    """Haupt-Repo (erstes in paths) – für dev, Konsole, Erkennung."""
    return absp(e["paths"][0]) if e.get("paths") else None


def accents() -> dict:
    try:
        return json.loads(PALETTE.read_text()).get("projectAccents", {})
    except (OSError, ValueError):
        return {}


def resolve_color(color):
    if isinstance(color, str) and HEX.match(color):
        return color.upper()
    return accents().get(color)


# ── Laden / Speichern ─────────────────────────────────────────────────────
def empty() -> dict:
    return {"_hinweis": HINT, "version": VERSION, "global": {"links": []}, "ignore": [], "projects": {}}


def norm_org(o) -> dict:
    """global.org (optional): eigene Firma/Org für die Erkennung neuer Projekte (kind, org)."""
    o = o if isinstance(o, dict) else {}
    return {"github": o.get("github") or None, "dir": o.get("dir") or None, "labs": o.get("labs") or None,
            "internal": list(o.get("internal") or [])}


def normalize(e: dict) -> dict:
    """Feste Reihenfolge, fehlende Felder mit Standard."""
    dev = e.get("dev") or {}
    op = e.get("open") or {}
    ports = dev.get("ports") or {}
    return {
        "name": e.get("name"),
        "paths": list(e.get("paths") or []),
        "workspace": e.get("workspace"),
        "kind": e.get("kind") or "privat",
        "org": bool(e.get("org", e.get("team", False))),   # Org-Repo (global.org.github); "team" = alter Name
        "color": e.get("color"),
        "tint": bool(e.get("tint", False)),
        "dev": {"command": dev.get("command"), "services": dev.get("services"), "block": dev.get("block"),
                "ports": dict(ports), "infra": dict(dev.get("infra") or {})},
        "open": {
            "code": op.get("code", True),
            "browser": list(op["browser"]) if "browser" in op and op["browser"] is not None else ([next(iter(ports))] if ports else []),
            "terminal": op.get("terminal"),
        },
        "links": list(e.get("links") or []),
    }


def load(example: bool = True) -> dict:
    """FILE lesen; fehlt sie, die Beispiel-Datei (example=False: dann leer – so landen beim ersten
    Speichern keine Beispiel-Projekte in der eigenen Datei)."""
    src = FILE if FILE.exists() else (EXAMPLE if example else None)
    if src is None or not src.exists():
        return empty()
    data = json.loads(src.read_text())
    out = empty()
    g = data.get("global") or {}
    out["global"] = {"links": list(g.get("links") or [])}
    if g.get("org"):
        out["global"]["org"] = norm_org(g["org"])
    out["ignore"] = list(data.get("ignore") or [])
    out["projects"] = {k: normalize(v) for k, v in (data.get("projects") or {}).items()}
    return out


def _check_links(links, where, errs):
    if not isinstance(links, list):
        errs.append(f"{where}: links muss eine Liste sein")
        return
    names = set()
    for l in links:
        if not isinstance(l, dict) or not isinstance(l.get("name"), str) or not l["name"].strip():
            errs.append(f"{where}: Link ohne Namen")
            continue
        if not isinstance(l.get("url"), str) or not URL_RE.match(l["url"]):
            errs.append(f"{where}: Link „{l['name']}“ hat keine gültige URL")
        if "icon" in l and not (isinstance(l["icon"], str) and re.match(r"^[a-z0-9_]+$", l["icon"])):
            errs.append(f"{where}: Link „{l['name']}“: icon = Material-Symbol-Name (z. B. public)")
        if l["name"] in names:
            errs.append(f"{where}: Link „{l['name']}“ doppelt")
        names.add(l["name"])


def validate(data: dict) -> list:
    errs = []
    acc = accents()
    seen = {}
    blocks = {}
    for pid, e in data["projects"].items():
        w = f"{pid}"
        if not ID_RE.match(pid):
            errs.append(f"{w}: id nur aus A-Z a-z 0-9 . _ -")
        if not isinstance(e.get("name"), str) or not e["name"].strip():
            errs.append(f"{w}: name fehlt")
        if not isinstance(e["paths"], list) or not all(isinstance(p, str) and p for p in e["paths"]):
            errs.append(f"{w}: paths muss eine Liste von Pfaden sein")
        if e["workspace"] is not None and not (isinstance(e["workspace"], str) and e["workspace"].endswith(".code-workspace")):
            errs.append(f"{w}: workspace muss auf .code-workspace enden oder null sein")
        if not targets(e):
            errs.append(f"{w}: braucht mindestens einen Pfad (paths) oder einen workspace")
        for t in targets(e):
            a = str(absp(t))
            if a in seen and seen[a] != pid:
                errs.append(f"{w}: {t} gehört schon zu {seen[a]}")
            seen[a] = pid
        if e["kind"] not in KINDS:
            errs.append(f"{w}: kind muss eins von {', '.join(KINDS)} sein")
        c = e["color"]
        if c is not None and not (isinstance(c, str) and (HEX.match(c) or c in acc)):
            errs.append(f"{w}: color = #RRGGBB, Palettenname ({', '.join(acc)}) oder null")
        if e["tint"] and c is None:
            errs.append(f"{w}: tint braucht eine Farbe")
        d = e["dev"]
        for k in ("command", "services"):
            if d[k] is not None and not (isinstance(d[k], str) and d[k].strip()):
                errs.append(f"{w}: dev.{k} muss Text oder null sein")
        for key in ("ports", "infra"):
            if not isinstance(d[key], dict):
                errs.append(f"{w}: dev.{key} muss {{name: port}} sein")
                continue
            for k, v in d[key].items():
                if not ID_RE.match(k):
                    errs.append(f"{w}: Port-Name „{k}“ ungültig")
                if not isinstance(v, int) or isinstance(v, bool) or not 1 <= v <= 65535:
                    errs.append(f"{w}: Port {k} muss eine Zahl 1–65535 sein")
        if isinstance(d["ports"], dict) and isinstance(d["infra"], dict) and set(d["ports"]) & set(d["infra"]):
            errs.append(f"{w}: Rolle doppelt in dev.ports und dev.infra: {', '.join(set(d['ports']) & set(d['infra']))}")
        b = d["block"]
        if b is not None and (not isinstance(b, int) or isinstance(b, bool) or not 1 <= b <= MAX_BLOCK):
            errs.append(f"{w}: dev.block = 1–{MAX_BLOCK} oder null")
        elif b is not None and b in blocks:
            errs.append(f"{w}: Port-Block {b} gehört schon zu {blocks[b]}")
        elif b is not None:
            blocks[b] = pid
        o = e["open"]
        if not isinstance(o["code"], bool):
            errs.append(f"{w}: open.code muss true/false sein")
        if not isinstance(o["browser"], list):
            errs.append(f"{w}: open.browser muss eine Liste sein")
        else:
            for b in o["browser"]:
                if not isinstance(b, str) or not (b in d["ports"] or URL_RE.match(b)):
                    errs.append(f"{w}: open.browser „{b}“ ist weder ein Port-Name aus dev.ports noch eine URL")
        if o["terminal"] is not None and o["terminal"] not in TERMINALS:
            errs.append(f"{w}: open.terminal = dev, shell oder null")
        if o["terminal"] == "dev" and not d["command"]:
            errs.append(f"{w}: open.terminal = dev braucht dev.command")
        _check_links(e["links"], w, errs)
    _check_links(data["global"]["links"], "global", errs)
    org = data["global"].get("org")
    if org is not None and (not isinstance(org, dict) or not isinstance(org.get("internal", []), list)):
        errs.append("global.org: Objekt mit github, dir, labs, internal (Liste)")
    if not isinstance(data["ignore"], list):
        errs.append("ignore muss eine Liste sein")
    return errs


def _write_atomic(f: pathlib.Path, text: str):
    f.parent.mkdir(parents=True, exist_ok=True)
    tmp = f.with_name(f".{f.name}.tmp")
    tmp.write_text(text)
    os.replace(tmp, f)


def compat_rows(data: dict) -> list:
    rows = []
    for e in data["projects"].values():
        for t in targets(e):
            rows.append({"path": t, "name": pathlib.Path(t).name.removesuffix(".code-workspace"), "color": e["color"]})
    rows.sort(key=lambda r: (not r["path"].endswith(".code-workspace"), r["path"].lower()))
    return rows


def save(data: dict):
    errs = validate(data)
    if errs:
        raise SystemExit("projects/projects.json NICHT gespeichert:\n  " + "\n  ".join(errs))
    out = {"_hinweis": HINT, "version": VERSION, "global": data["global"], "ignore": sorted(set(data["ignore"])),
           "projects": {k: data["projects"][k] for k in sorted(data["projects"], key=str.lower)}}
    compat = {"_hinweis": COMPAT_HINT, "projects": compat_rows(out)}
    # nur schreiben, was sich geändert hat (die Shell beobachtet beide Dateien)
    for f, obj in ((FILE, out), (COMPAT, compat)):
        text = json.dumps(obj, indent=2, ensure_ascii=False) + "\n"
        if not f.exists() or f.read_text() != text:
            _write_atomic(f, text)


@contextlib.contextmanager
def edit():
    """Lesen → ändern → prüfen → atomar schreiben, gesperrt gegen gleichzeitige Aufrufe. Bei Fehler: nichts."""
    FILE.parent.mkdir(parents=True, exist_ok=True)
    fd = os.open(FILE.parent, os.O_RDONLY)
    try:
        fcntl.flock(fd, fcntl.LOCK_EX)
        data = load(example=False)
        yield data
        save(data)
    finally:
        os.close(fd)


# ── Suchen ────────────────────────────────────────────────────────────────
def find(data: dict, q: str):
    """id, name, Pfad (~/… oder absolut) oder ein Ordner darin (längster Treffer) -> id oder None."""
    if q in data["projects"]:
        return q
    hits = [k for k, e in data["projects"].items() if e["name"] == q]
    if len(hits) == 1:
        return hits[0]
    a = str(absp(q).resolve()) if (q.startswith(("/", "~", ".")) or "/" in q) else None
    if not a:
        return None
    best, blen = None, -1
    for k, e in data["projects"].items():
        for t in targets(e):
            ta = str(absp(t))
            if (a == ta or a.startswith(ta + "/")) and len(ta) > blen:
                best, blen = k, len(ta)
    return best


def new_id(data: dict, p: pathlib.Path) -> str:
    base = p.name.removesuffix(".code-workspace")
    for cand in (base, f"{base}-{p.parent.name}"):
        if cand not in data["projects"]:
            return cand
    i = 2
    while f"{base}-{i}" in data["projects"]:
        i += 1
    return f"{base}-{i}"


# ── Erkennen (nur lesen) ──────────────────────────────────────────────────
def git_remote(p: pathlib.Path):
    r = subprocess.run(["git", "-C", str(p), "remote", "get-url", "origin"], capture_output=True, text=True)
    return r.stdout.strip() if r.returncode == 0 else None


def _under(p: pathlib.Path, base) -> bool:
    if not base:
        return False
    b = str(absp(base)).rstrip("/") + "/"
    return str(absp(p)).startswith(b)


def guess_kind(p: pathlib.Path, data: dict = None) -> str:
    """Aus global.org (Ordner der Firma, Labs-Ordner, interne Repos) – ohne global.org immer privat."""
    org = norm_org(((data or {}).get("global") or {}).get("org"))
    if _under(p, org["labs"]):
        return "labs"
    if org["dir"] and p.name in org["internal"]:
        return "intern"
    if _under(p, org["dir"]):
        return "kunde"
    return "privat"


def guess_org(p: pathlib.Path, data: dict = None) -> bool:
    """Git-Remote gehört der eigenen GitHub-Org (global.org.github)?"""
    gh = norm_org(((data or {}).get("global") or {}).get("org"))["github"]
    return bool(gh) and f"{gh}/" in (git_remote(p) or "")


def _env_example(p: pathlib.Path) -> dict:
    """KEY=VALUE aus .env.example (nur die Vorlage – eine echte .env wird nie geöffnet)."""
    f = p / ".env.example"
    out = {}
    if not f.is_file():
        return out
    for line in f.read_text(errors="ignore").splitlines():
        m = re.match(r"^\s*([A-Z0-9_]+)\s*=\s*(.*?)\s*$", line)
        if m:
            out[m.group(1)] = m.group(2).strip("\"'")
    return out


def _pkg(f: pathlib.Path) -> dict:
    try:
        return json.loads(f.read_text())
    except (OSError, ValueError):
        return {}


def _runner(p: pathlib.Path, pkg: dict) -> str:
    pm = str(pkg.get("packageManager") or "")
    if pm.startswith("bun") or (p / "bun.lock").exists() or (p / "bun.lockb").exists():
        return "bun run"
    if pm.startswith("pnpm") or (p / "pnpm-lock.yaml").exists():
        return "pnpm"
    if pm.startswith("yarn") or (p / "yarn.lock").exists():
        return "yarn"
    return "npm run"


def _port_from_env(env: dict, name: str):
    for key in (f"{name.upper()}_PUBLIC_URL", f"{name.upper()}_URL", f"{name.upper()}_INTERNAL_URL"):
        m = re.match(r"^(?:https?|wss?)://(?:localhost|127\.0\.0\.1)(?::(\d+))?", env.get(key, ""))
        if m and m.group(1):
            return int(m.group(1))
    return None


def _port_of(script: str, env: dict, name: str, single: bool):
    m = re.search(r"(?:\s-p|--port)[\s=](\d{2,5})", script or "")
    if m:
        return int(m.group(1))
    if single and env.get("PORT", "").isdigit():
        return int(env["PORT"])
    hit = _port_from_env(env, name)
    if hit:
        return hit
    if re.search(r"\bnext dev\b", script or ""):
        return 3000  # Next.js-Standard
    if re.search(r"\bvite\b", script or ""):
        return 5173
    return None


COMPOSE_FILES = ("docker-compose.yml", "docker-compose.yaml", "compose.yml", "compose.yaml",
                 "infra/docker-compose.yml", "infra/docker-compose.yaml", "infra/compose.yml", "infra/compose.yaml")


def compose_ports(p: pathlib.Path) -> dict:
    """Host-Ports der Container aus compose-Dateien (einfaches Zeilenlesen, kein YAML-Modul nötig).
    "${DB_PORT:-5432}:5432" -> 5432. Rolle = Dienstname; mehrere Ports: <dienst>-console (9001) bzw. <dienst>-<containerport>."""
    out = {}
    for name in COMPOSE_FILES:
        f = p / name
        if not f.is_file():
            continue
        service, in_services, in_ports, n = None, False, False, 0
        for line in f.read_text(errors="ignore").splitlines():
            if not line.strip() or line.lstrip().startswith("#"):
                continue
            ind = len(line) - len(line.lstrip())
            if ind == 0:
                in_services = line.startswith("services:")
                service = None
                continue
            if not in_services:
                continue
            m = re.match(r"^  ([A-Za-z0-9._-]+):\s*$", line)
            if m:
                service, in_ports, n = m.group(1), False, 0
                continue
            if service and re.match(r"^\s{4}ports:\s*$", line):
                in_ports = True
                continue
            if in_ports and ind <= 4 and not line.lstrip().startswith("-"):
                in_ports = False
            if in_ports:
                m = re.match(r"""^\s*-\s*["']?(?:[\d.]+:)?(?:\$\{[A-Z0-9_]+:-(\d+)\}|(\d+)):(\d+)""", line)
                if m:
                    host, cont = int(m.group(1) or m.group(2)), int(m.group(3))
                    role = service if n == 0 else (f"{service}-console" if cont == 9001 else f"{service}-{cont}")
                    out.setdefault(role, host)
                    n += 1
    return out


def detect(p: pathlib.Path) -> dict:
    """Vorschlag für dev (command, services, ports) und links eines Repos – liest nur."""
    dev = {"command": None, "services": None, "ports": {}, "infra": {}}
    links = []
    if not p or not p.is_dir():
        return {"dev": dev, "links": links}
    pkg = _pkg(p / "package.json")
    scripts = pkg.get("scripts") or {}
    env = _env_example(p)
    if pkg:
        run = _runner(p, pkg)
        if "dev" in scripts:
            dev["command"] = f"{run} dev"
        if "services:up" in scripts:
            dev["services"] = f"{run} services:up"
        elif any((p / f).exists() for f in ("docker-compose.yml", "compose.yml", "compose.yaml", "docker-compose.yaml")):
            dev["services"] = "docker compose up -d"
        apps = sorted((p / "apps").glob("*/package.json")) if (p / "apps").is_dir() else []
        found = {}
        if apps:
            for f in apps:
                name = f.parent.name
                port = _port_of((_pkg(f).get("scripts") or {}).get("dev", ""), env, name, False)
                if port:
                    found[name] = port
        elif "dev" in scripts:
            port = _port_of(scripts["dev"], env, "web", True)
            if port:
                found["web"] = port
        dev["ports"] = dict(sorted(found.items(), key=lambda kv: (kv[0] != "web", kv[1])))
    dev["infra"] = compose_ports(p)
    url = git_remote(p)
    if url:
        m = re.match(r"^(?:git@github\.com:|https://github\.com/)([^/]+/[^/]+?)(?:\.git)?$", url)
        if m:
            links.append({"name": "Repo", "url": f"https://github.com/{m.group(1)}", "icon": "code"})
    for key in ("SITE_URL", "NEXT_PUBLIC_SITE_URL", "WEB_URL"):
        v = env.get(key, "")
        if v.startswith("https://") and "localhost" not in v:
            links.insert(0, {"name": "Prod", "url": v.rstrip("/"), "icon": "public"})
            break
    return {"dev": dev, "links": links}


def new_entry(data: dict, path, color=None):
    """Neuer Eintrag für einen Repo-Ordner oder eine *.code-workspace-Datei -> (id, eintrag)."""
    p = absp(path)
    pid = new_id(data, p)
    ws = p.suffix == ".code-workspace"
    repo = None if ws else p
    found = detect(repo) if repo else {"dev": {}, "links": []}
    e = normalize({
        "name": pid,
        "paths": [] if ws else [rel(p)],
        "workspace": rel(p) if ws else None,
        "kind": guess_kind(p, data) if repo else "privat",
        "org": guess_org(repo, data) if repo else False,
        "color": color,
        "tint": False,
        "dev": found["dev"],
        "links": found["links"],
    })
    return pid, e


# ── Port-Blöcke ───────────────────────────────────────────────────────────
# Block n (1–69) gehört genau einem Projekt. Apps: 3000 + 100·n + Versatz (web 00, api 01, admin 02, relay 03 …,
# weitere ab 10, höchstens 49). Infra-Container: Standardport + 100·n (Postgres 5432 -> 5532 bei Block 1);
# unbekannte Dienste im Block ab Versatz 50. Block 0 = alte Standardports (3000, 5432 …) ohne Block.
MAX_BLOCK = 69
APP_OFFSETS = {"web": 0, "api": 1, "admin": 2, "relay": 3, "mobile": 4, "docs": 5, "storybook": 6, "worker": 7}
INFRA_DEFAULTS = {"postgres": 5432, "db": 5432, "redis": 6379, "valkey": 6379, "minio": 9000, "minio-console": 9001,
                  "mailpit": 8025, "mailpit-smtp": 1025, "mongo": 27017, "rabbitmq": 5672, "meilisearch": 7700,
                  "elasticsearch": 9200, "mysql": 3306, "mariadb": 3306}


def app_port(n: int, role: str, taken: set) -> int:
    base = 3000 + 100 * n
    if role in APP_OFFSETS and base + APP_OFFSETS[role] not in taken:
        return base + APP_OFFSETS[role]
    for off in range(10, 50):
        if base + off not in taken:
            return base + off
    raise SystemExit(f"Block {n}: keine freien App-Ports mehr")


def infra_port(n: int, role: str, taken: set) -> int:
    known = INFRA_DEFAULTS.get(role)
    if known and known + 100 * n not in taken:
        return known + 100 * n
    base = 3000 + 100 * n
    for off in range(50, 100):
        if base + off not in taken:
            return base + off
    raise SystemExit(f"Block {n}: keine freien Infra-Ports mehr")


def block_ports(n: int, apps, infra) -> dict:
    """Ports, die Block n für diese Rollen vergibt -> {"ports": {...}, "infra": {...}}."""
    taken, ports, inf = set(), {}, {}
    for r in apps:
        ports[r] = app_port(n, r, taken)
        taken.add(ports[r])
    for r in infra:
        inf[r] = infra_port(n, r, taken)
        taken.add(inf[r])
    return {"ports": ports, "infra": inf}


def usage(data: dict, skip=None) -> dict:
    """Port -> [„projekt:rolle“] aller erfassten Projekte (ohne skip)."""
    out = {}
    for pid, e in data["projects"].items():
        if pid == skip:
            continue
        for kind in ("ports", "infra"):
            for r, port in e["dev"][kind].items():
                out.setdefault(port, []).append(f"{pid}:{r}")
    return out


def listeners() -> dict:
    """Ports, auf denen gerade etwas lauscht (ss -ltnH) -> Prozessname (falls sichtbar)."""
    try:
        r = subprocess.run(["ss", "-ltnpH"], capture_output=True, text=True, timeout=5)
    except (OSError, subprocess.SubprocessError):
        return {}
    out = {}
    for line in r.stdout.splitlines():
        cols = line.split()
        if len(cols) < 4:
            continue
        m = re.search(r":(\d+)$", cols[3])
        if m:
            proc = re.search(r'users:\(\("([^"]+)"', line)
            out.setdefault(int(m.group(1)), proc.group(1) if proc else "?")
    return out


def allocate(data: dict, pid: str, apps=None, infra=None, block=None, live=None) -> dict:
    """Port-Block für ein Projekt vergeben (oder seinen behalten) und dev.ports/dev.infra damit füllen.
    apps/infra: Rollen (ohne Angabe: die schon erfassten, sonst web bzw. keine). Nimmt nur Blöcke, deren Ports weder
    ein anderes Projekt noch ein laufender Listener belegt. -> {"block", "ports", "infra", "moved": {rolle: (alt, neu)}}"""
    e = data["projects"][pid]
    d = e["dev"]
    apps = list(apps) if apps is not None else (list(d["ports"]) or ["web"])
    infra = list(infra) if infra is not None else list(d["infra"])
    used = usage(data, skip=pid)
    blocks = {x["dev"]["block"] for k, x in data["projects"].items() if k != pid and x["dev"]["block"]}
    live = listeners() if live is None else live
    own = set(d["ports"].values()) | set(d["infra"].values())

    def free(n):
        if n in blocks:
            return None
        want = block_ports(n, apps, infra)
        ports = list(want["ports"].values()) + list(want["infra"].values())
        if any(p in used or (p in live and p not in own) for p in ports):
            return None
        return want

    order = [block] if block else ([d["block"]] if d["block"] else []) + list(range(1, MAX_BLOCK + 1))
    for n in order:
        want = free(n)
        if want:
            break
    else:
        raise SystemExit(f"Kein freier Port-Block{f' ({block})' if block else ''} – belegt durch Projekte oder laufende Dienste")
    moved = {}
    for kind in ("ports", "infra"):
        for r, port in want[kind].items():
            old = d[kind].get(r)
            if old != port:
                moved[r] = (old, port)
    d["block"] = n
    d["ports"] = want["ports"]
    d["infra"] = want["infra"]
    e["open"]["browser"] = [b for b in e["open"]["browser"] if "://" in b or b in d["ports"]] or (
        [next(iter(d["ports"]))] if d["ports"] else [])
    return {"block": n, "ports": d["ports"], "infra": d["infra"], "moved": moved}
