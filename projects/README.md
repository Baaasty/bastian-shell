# projects/ – Desktop-Einstellungen der Projekte

`projects.json` = alles, was **nur auf dem eigenen Rechner** Sinn ergibt: Farbe, VS-Code-Tönung, Dev-Ports,
was der Projekt-Desktop öffnet, Links. Das Projekt-Repo bleibt unverändert (auch bei Org-Repos).
Keine Secrets hinein (Tokens bleiben in `secrets.json`).

- **Nur lokal:** `projects.json` ist gitignored (eigene Kunden, Pfade, Ports). Im Repo liegt
  `projects.example.json`; alle Leser (Shell, `scripts/*`) nehmen sie, solange `projects.json` fehlt.
  Das erste `scripts/project add …` legt die eigene `projects.json` an (ohne die Beispiel-Projekte).

- **Schreiben nur über `scripts/project`** (oder `scripts/vscode-colors` für Farbe/Tönung) – beide über
  `store.py`: prüft das Schema, sperrt gegen gleichzeitige Aufrufe, schreibt atomar, bei Fehlern **nichts**.
  Nie von Hand, nie aus QML. Bequem: Skill `/project` (Bereich Desktop).
- Nach jedem Schreiben wird `theme/projects.json` neu **erzeugt** (flache Liste `path`/`name`/`color` je Pfad)
  für ältere Leser: VS-Code-Erweiterung „Desktop Projekte“, Claude-Zentrale (`ClaudeHub`), Antwort-Karte
  (`ClaudeGate`), `/project`.

## Schema (version 1)

```jsonc
{
  "version": 1,
  "global": {
    "links": [ { "name": "Buchhaltung", "url": "https://example.com/accounting", "icon": "receipt_long" } ],
    // optional: eigene Firma/Org – nur für die Erkennung neuer Projekte (kind, org)
    "org": { "github": "example-org", "dir": "~/Workspace/clients", "labs": "~/Workspace/labs", "internal": ["website"] }
  },
  "ignore": ["~/Workspace/alt"],          // Ordner, die der Scan (vscode-colors) nicht neu aufnehmen soll (rm)
  "projects": {
    "habit-tracker": {                    // id = Ordnername (wie Launcher/Context ihn kennen)
      "name": "habit-tracker",            // Anzeige
      "paths": ["~/Workspace/labs/habit-tracker"],   // 1..n Repos, erstes = Haupt-Repo (dev, Konsole)
      "workspace": null,                  // optional *.code-workspace (mehrere Repos in einem Fenster)
      "kind": "labs",                     // kunde | labs | intern | privat (Vorschlag aus global.org: labs/dir/internal)
      "org": true,                        // Org-Repo (Git-Remote global.org.github); altes "team" wird gelesen
      "color": "rose",                    // #RRGGBB, Palettenname (palette.json projectAccents) oder null
      "tint": true,                       // gewünschte VS-Code-Tönung (braucht color)
      "dev": {
        "command": "bun run dev",         // Dev-Server (läuft nie von selbst, nur mit open.terminal = dev)
        "services": "bun run services:up",// optional davor (Docker/Podman)
        "block": null,                    // Port-Block 1–69 (siehe Ports) oder null = alte Standardports
        "ports": { "web": 3000, "api": 3001, "admin": 3002 },  // App-Ports, Rolle -> Port; erster = Browser (Helium)
        "infra": { "postgres": 5432, "minio": 9000, "minio-console": 9001 }  // Container-Ports (compose)
      },
      "open": {                           // Projekt-Desktop (Launcher `#`, Templates.openProject)
        "code": true,                     // VS Code (über den Wrapper, falls es einen gibt)
        "browser": ["web"],               // Port-Namen aus dev.ports und/oder URLs; [] = kein Browser
        "terminal": null                  // null | "shell" (Konsole im Haupt-Repo) | "dev" (services && command)
      },
      "links": [ { "name": "Repo", "url": "https://github.com/example-org/habit-tracker", "icon": "code" } ]
    }
  }
}
```

## Ports (Block-Schema)

Damit parallel laufende Projekte sich nicht in die Quere kommen, bekommt jedes Projekt einen **Port-Block n**
(1–69, jeder Block gehört genau einem Projekt):

| Was | Regel | Block 1 | Block 2 |
|---|---|---|---|
| Apps | `3000 + 100·n + Versatz` – web `00`, api `01`, admin `02`, relay `03`, mobile `04`, docs `05`, storybook `06`, worker `07`, weitere ab `10` (bis `49`) | web 3100 · api 3101 · admin 3102 | web 3200 · api 3201 |
| Infra (Container) | `Standardport + 100·n` – postgres 5432, redis 6379, minio 9000, minio-console 9001, mailpit 8025/1025, mongo 27017, rabbitmq 5672, meilisearch 7700, elasticsearch 9200, mysql 3306 | postgres 5532 · redis 6479 · minio 9100/9101 | postgres 5632 · minio 9200/9201 |
| unbekannter Dienst | im App-Block ab Versatz `50` | 3150 | 3250 |

Block 0 heißt: noch kein Block, alte Standardports (3000, 5432 …) – so stehen die bestehenden Projekte drin
(`migrate` erfasst nur, ändert nichts). `ports allocate` nimmt den nächsten Block, dessen Ports weder ein anderes
Projekt (dev.ports/dev.infra) noch ein gerade lauschender Dienst (`ss -ltn`) belegt; hat das Projekt schon einen
Block, bleibt er. `projects.json` ändert sich dabei – **die Repo-Konfiguration** (`.env.example`, compose,
`next dev -p …`) zieht `/project` (Standard angleichen) bzw. `/new-project` im Repo nach (z. B. `PORT=3100`, `DB_PORT=5532`).

Regeln, die `store.py` prüft: eindeutige Pfade über alle Projekte · `color` gültig · `tint` nur mit Farbe ·
Ports 1–65535, Rolle nicht doppelt in `ports` und `infra` · Block 1–69 und eindeutig · `open.browser` nur bekannte Port-Namen oder URLs · `terminal: "dev"` nur mit `dev.command` ·
Links mit Name + URL (`icon` = Material-Symbol-Name, optional).

## Leser

| Wer | Felder |
|---|---|
| `shell/services/Projects.qml` (`settingsFor`, `browserUrls`, `globalLinks`) | alle |
| `shell/services/Templates.qml` (`openProject`) | `open`, `dev.ports`, `dev.command`/`services`, `paths` |
| `theme/gen/vscode_projects.py` (`scripts/vscode-colors`) | `color`, `tint`, `paths`, `workspace`, `ignore` |
| erzeugte `theme/projects.json` → VS-Code-Erweiterung, ClaudeHub, ClaudeGate, /project | `color` je Pfad |

## Befehle

`scripts/project hilfe` – `list`, `show <projekt|pfad>`, `detect`, `set <projekt> <feld> <wert>`,
`link <projekt|global> add|rm`, `ports list|show|allocate|set`, `add <pfad>`, `rm <projekt>`, `migrate` (einmalig aus `theme/projects.json`,
Wrapper-Zustand und `profiles.json`-Hotlinks; erneut aufrufen ist harmlos).
