# Projekte auf dem Desktop (Shell-Feature)

Jedes Projekt kann in der **Projekt-Registry** der Shell stehen (`projects/projects.json`, Schema und Port-Schema:
[`projects/README.md`](../projects/README.md)): Farbe, VS-Code-Tönung, Dev-Befehl, Ports/Port-Block, was der
Projekt-Desktop öffnet, Links. Das Projekt-Repo selbst bleibt dabei unverändert. Geschrieben wird **nur** über
`scripts/project` (`scripts/project hilfe`) – nie von Hand, nie aus QML.

## Skill `/desktop-project` (Claude Code)

`claude/skills/desktop-project/` – universeller Skill, der die Registry bedient: Projekt aufnehmen, Farbe (`#RRGGBB`)
und Tönung, Dev-Befehl, Ports/Port-Block, Öffnen (VS Code, Browser, Terminal), Links. Liest im Projekt nur
(`.env` nie), schreibt nur über `scripts/project`, prüft danach, dass `git status` im Projekt gleich geblieben ist.
Antwortet in der Sprache des Nutzers.

- `SKILL.md` = Ablauf · `project` = Wrapper um `scripts/project`. Fester Befehl für Skills aus anderen Repos:
  `~/.claude/skills/desktop-project/project <befehl> …` (gleiche Argumente; findet das Repo über den Symlink).
- Installiert als Symlink: `scripts/claude-skills install` → `~/.claude/skills/desktop-project` (nur Ordner mit
  `SKILL.md`; Änderungen gelten sofort; räumt tote eigene Links mit weg, fremde Ordner bleiben unangetastet).
  `scripts/claude-skills status` · `scripts/claude-skills uninstall`.
- Eigene Projekt-Skills (Gerüst, Projekt-Standard, Umbau) gehören nicht in dieses Repo: sie bringen ihr eigenes
  Install mit und rufen für den Desktop-Teil nur den Befehl oben auf.

## Projekt öffnen: Terminal und Dev-Server

`open.terminal` in `projects/projects.json` (`scripts/project set <id> open.terminal dev|shell|none`): `dev` startet
`dev.services && dev.command`, `shell` ein leeres Terminal – immer im **integrierten Terminal unten in VS Code**,
nie in einem eigenen Konsole-Fenster. Gilt für jeden Projekt-Start (Launcher `#`, Workbar, `/desktop-project` → Öffnen).
Technik: `Templates.openProject()` schreibt vor dem VS-Code-Start eine Einmal-Marke
`~/.cache/desktop/open-terminal/<id>.json` (`{ dir, target, command, name, created }`, Ordner 700, Datei 600).
Die Erweiterung „Desktop Projekte“ (`theme/gen/vscode.py`, ab 0.2.0) prüft beim Start, bei neuen Marken und beim
Fokus, ob Ordner bzw. Arbeitsbereich-Datei des Fensters passen, öffnet dann das Terminal „dev“/„shell“ in `dir`
(Fokus bleibt im Editor) und löscht die Marke. Marken älter als 2 min zählen nicht. Läuft „dev“ im Fenster schon,
wird es nur gezeigt (kein zweiter Dev-Server). Ohne Erweiterung startet nichts – nur eine leise Meldung.
`open.code aus` + Terminal geht nicht (Warnung im Shell-Log).

## Zwei Einstiege für neue Projekte

1. **Desktop:** Super → `#` + Name → „New Project “…”“ (ohne Namen fragt das Eingabefeld unter der Bar).
   Dann: neuer Projekt-Desktop, Ordner `~/Workspace/<name>`, VS Code öffnet sich dort mit einem Claude-Tab,
   in dem schon `/new-project <name>` steht → **Enter drücken**. Der Skill `/new-project` (Gerüst) kommt nicht aus
   diesem Repo, sondern aus einem eigenen Skill-Repo; fehlt er, bleibt der Tab mit dem Text einfach offen.
   Technik: `Templates.newProject()` → `scripts/new-project <name>` → `code --new-window` +
   `code --open-url vscode://anthropic.claude-code/open?prompt=…`. Probelauf: `scripts/new-project <name> --dry-run`.
2. **Claude Code:** in einem beliebigen Chat `/new-project <name>` bzw. ein bestehendes Projekt mit `/desktop-project` aufnehmen.

## Claude-Zentrale (Roadmap-Zählung)

`scripts/project-info` zählt `docs/ROADMAP.md` **plus** alle Unter-Roadmaps (`docs/roadmaps/*.md`, älteres Muster
`docs/ROADMAP_*.md`). „Nächster Schritt“ kommt aus der Unter-Roadmap mit `Status: Aktuell` im Kopf (oder der, auf die
die Haupt-Roadmap in einer `Aktuell:`-Zeile verlinkt), sonst aus der Haupt-Roadmap. Neue Felder: `nextFile`,
`partial` (Anzahl `[~]`), `parts` (je Datei). `file`, `done`, `total`, `next` wie bisher.

