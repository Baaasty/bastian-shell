# Zeit pro Projekt + Tagesrückblick

## Zeit pro Projekt

Die Shell zählt **von selbst**, wie lange ein **Projekt-Workspace** der aktuelle Desktop war. Projekt-Workspace = ein Desktop,
dessen Name einem Projekt aus `projects/projects.json` entspricht (ID oder Anzeigename, wie bei Quicklinks/Git in der Workbar).

Gezählt wird nur, wenn du da bist:
- **nicht im Leerlauf**: nach `idleSec` (Standard 300 s = 5 min) ohne Maus/Tastatur hört es auf, und diese 5 min werden wieder abgezogen.
  Läuft ein Video/Call, das den Leerlauf verhindert (Inhibitor), zählt es weiter.
- **nicht gesperrt** (Lock-Kette), und Lücken über 90 s (Ruhezustand, Shell aus) zählen nie.

**Speicher:** `~/.local/state/desktop/projecttime/YYYY-MM-DD.json`, alle 15 s geschrieben (übersteht Shell-Neustarts):

```json
{ "day": "2026-10-18", "total": { "desktop": 5230 }, "spans": [["desktop", 1792350000, 1792355230]], "current": "desktop", "savedAt": 1792355230000 }
```

`total` = Sekunden je Projekt-ID, `spans` = Zeitspannen (Unix-Sekunden). Von Hand korrigieren geht: `total` ändern (zählt für alle Übersichten; `spans` ist nur der Verlauf).

**Einstellen** (optional, live gelesen) `~/.config/desktop/projecttime.json`:

```json
{ "enabled": true, "idleSec": 300 }
```

### Ansehen

| Was | Wie |
|---|---|
| Wochen-Karte | **Super+Alt+T** oder `… call projecttime toggle` (←/→ = Woche zurück/vor, Esc schließt) |
| Kachel im Dashboard | `shell/modules/dashboard/ProjectTimeTile.qml` (Einhängen siehe unten) |
| Terminal | `scripts/projecttime today` · `week [--offset -1]` · `month [2026-10]` (jeweils `--json`) |

Die Shell schreibt alle 15 s; sofort verbuchen: `… call projecttime flush`.

IPC (`qs ipc --any-display -p ~/Workspace/bastian-shell/shell call projecttime …`): `open | hide | toggle | status | today | week | flush`.

## Tagesrückblick

Eine ruhige Karte „das hast du heute geschafft“ im Look der Morgen-Übersicht:
**Commits heute** (alle Repos, je Projekt mit dem letzten Betreff), **Projektzeit**, **Fokuszeit** (+ Bildschirmzeit),
**abgehakte To-dos**, **fertige Claude-Aufgaben** („Ask Claude…“). Bereiche ohne Inhalt fehlen.

- Kommt **von selbst beim Feierabend**: wenn die Szene `evening` angeht (**Super+Alt+B**, docs/SCENES.md).
- Von Hand: **Super+Alt+R** oder `… call recap toggle`. Schließen: Klick, Esc/Enter/Leertaste oder nach 60 s (Überfahren hält sie offen).
- Einstellen (optional) `~/.config/desktop/recap.json`: `{ "onEvening": true, "closeSec": 60 }`.
- IPC `recap`: `open | hide | toggle | refresh | status` (status = nur Zahlen).

**Commits:** `scripts/recap commits [YYYY-MM-DD] [--json]` – Repos aus `projects.json` + jedes Git-Repo in `~/Workspace`
(Tiefe 4, ohne `node_modules`/`refs`), alle Branches (ohne Stash), nur eigene (Autor = `git config user.email`).
Worktrees und umgeschriebene Commits (gleicher Betreff im selben Projekt) zählen einmal. Nur lesen.

**Abgehakte To-dos:** `Todos` kennt keine Zeit, darum merkt sich der Rückblick jedes Abhaken selbst in
`~/.local/state/desktop/recap.json` (`{ "day", "todos": [{ key, list, text, at }] }`, nur heute). Wieder aufmachen nimmt es raus,
Aufräumen der Liste nicht.

## Technik

- `shell/services/ProjectTime.qml` – Zählen, Leerlauf/Sperre, Tagesdatei, Woche (über `scripts/projecttime`), IPC
- `shell/services/Recap.qml` – Commits, To-do-Log, Claude-Aufgaben, Kopplung an die Szene `evening`, IPC
- `shell/modules/recap/RecapCard.qml` (nutzt `MorningRow` der Morgen-Übersicht) · `ProjectTimeCard.qml` (Karte um die Kachel)
- `shell/modules/dashboard/ProjectTimeTile.qml` – Kachel: Säule je Tag (heute im Akzent, Überfahren zeigt die Projekte des Tages),
  darunter Projekte der Woche (Farbe aus `projects.json`), ‹ › blättert.
  Einhängen ins Dashboard (`Dashboard.qml`, Raster 12 Spalten × 3 Reihen ist voll): z. B. vierte Reihe
  `rows: [250, 380, 420, 300]` + `ProjectTimeTile { x: grid.cx(0); y: grid.ry(3); width: grid.cw(4); height: grid.rows[3] }`
  oder eine bestehende 3er-Kachel ersetzen. Die Kachel passt sich der Höhe an (zeigt so viele Projekte, wie Platz ist).
- `scripts/projecttime`, `scripts/recap` – Python, nur lesen, laufen auch ohne Shell
