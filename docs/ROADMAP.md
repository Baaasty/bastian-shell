# Roadmap – Desktop

Arbeitsliste in Reihenfolge. Details zu jedem Punkt stehen in [SPEC.md](../SPEC.md).
Jeder Punkt wird erst abgehakt, wenn er läuft und committet ist.

## Erledigt

- [x] Interview, SPEC, Design (Claude Design, Ember, Vorschau)
- [x] R0 Spike: Quickshell 0.3.2, Blur, Fensterliste, IPC, kstart, Schriften
- [x] Wallpaper auf 3 Monitoren + Lockscreen-Bild (`scripts/wallpaper`)
- [x] Desktop-Lockscreen: Passwortfeld auf DP-2, 6er-Code mit Auto-Entsperren, Ember-Uhr, Auffächern beim Entsperren (`scripts/shellpkg`)

## Jetzt: Shell bauen

- [x] R1 Fundament: Theme aus `palette.json`, Bausteine (Glas, Icon, Texte), nur DP-2
- [x] R2 Top-Bar: Uhr, Spotify-Mini, CPU/GPU-Temp, Tray; weicht Fenstern aus, Hover am oberen Rand
- [x] R3 Desktops: Namen, Wechsel, "+" = freier Desktop, Rechtsklick = entfernen (Umbenennen kommt mit R12)
- [x] R4 Kürzel (Meta+Esc, Meta+F, Not-Aus) + `scripts/rice on|off`
- [x] R5 Dashboard-Kern: Uhr, Wetter + Morgen-früh, Spotify groß, System, Status
- [x] R6 Fokus: Pomodoro, Fokus-Modus, Jetzt-Aufgabe (auch auf dem Lockscreen), Pausen, Hyperfokus
- [x] R7 Launcher: Apps, Projekte, Rechner (+ Tasten), Emoji, Zwischenablage – steckt im Dashboard
- [x] R8 Benachrichtigungen (+ Übergabe von Plasma, Portal-Datei) – `scripts/notify-handover hutte|plasma`
- [x] R9 OSD + Power-Menü
- [x] R10 Umstieg: Plasma-Panel weg, Super allein = Dashboard mit Suche
- [x] R11 Steuerung: Key Light, Hue (Szenen sortieren, Farbwähler, Andere aus), GoXLR-Routing
- [x] R12 Vorlagen Code/Office/Fun + Projekt-Desktops (Plus = Leer + Vorlagen, Doppelklick = leer)
- [x] Bar-Extras: Spotify ⏮⏯⏭ + Cover + Popout (Dauer, Springen, Shuffle/Repeat), Desktops per Doppelklick umbenennen
- [x] Zwischenablage à la Clippy (Meta+V): Bilder, Favoriten, Löschen – lokal, ohne Sync
- [x] Ausschneiden (Druck / Meta+S): einfrieren, Bereich ziehen, kopieren + speichern
- [x] Arbeitsplatz-Leiste unten links: Desktops mit Fenstervorschau, umsortieren (ziehen/Menü), + / Vorlagen, offene Apps
- [x] Launcher: offene Fenster (alle Desktops) + Dateien (Präfix /)
- [x] Hintergrund-Apps Spotify/Discord (Rausholen/Wegräumen), Projekt-Desktops, Fensterregeln
- [x] Oben links: To-dos pro Desktop + Allgemein
- [x] Oben links: nächster Termin (heute/morgen, „in 25 min“) · Claude-Sitzungen
- [x] Discord-Popout (Klick): Call, Köpfe in der Bar, Mic/Taub/Verlassen, Lautstärke pro Person, Kanal-Auswahl, Anpinnen
- [x] Spotify-Popout: Warteschlange, Library → Playlist → Songs (auch fremde über Einbett-Seite)
- [x] R13 Stats: Hörzeit + Callzeit heute/Jahr (stats.fm), Bildschirmzeit, Claude aktiv (GitHub/Hotlinks bewusst raus)

- [x] Benachrichtigungen weich rein/raus, max. 4, gleiche zusammengefasst; Klick holt App nach vorn
- [x] Ausschneiden pixelgenau: Lupe, Shift = langsam zielen, Griffe, Strg+C / Strg+S
- [x] Bildschirmkanten über KWin-Script (blockiert keine Klicks), Hot Corner aus
- [x] Eigener Fensterwechsler (Super+Tab), Super+Leertaste = Desktops reihum, Alt+Tab frei _(historisch, KWin – unter Hyprland: Alt+←/→, Workspace-Modus per Alt antippen, Alt+Tab = Wechsler)_
- [x] Nur ein Bar-Popout gleichzeitig

## Erledigt am 2026-10-18 (Kurzfassung)

- Super allein = Dashboard · Umbenennung Hütte → **desktop** · ganze UI auf Englisch · Uhr mit Sekunden
- Dashboard neu: Uhr, Discord, Spotify, Fokus · System (CPU/RAM/GPU/Internet + Speicher, Updates, Maus, Bildschirmzeit) · Licht & Ton (Raster, Kamera-Helligkeit) · Coding · Wetter · Benachrichtigungen · Termine + Mail (iCloud)
- Mail: Thunderbird ESR, Mail-Wächter (Push, Codes kopieren, Code-Mail in den Papierkorb) · Konten in `secrets.json`
- Theme: Varianten (ember aktiv; walnut, dusk, clay, linen), Wallpaper glut-clean, neue Cursor, Konsole schlank + Starship
- Kürzel aufgeräumt (`docs/HOTKEYS.md`), Super+P/Shift+P anpinnen/oben halten, Key Light + GoXLR-Profil beim Herunterfahren
- VS Code nativ installiert (Shell nimmt es automatisch), Einstellungen + Erweiterungen kopiert
- Doku in `docs/` (setup/ für alle Logins) · Theme-Übersicht: `docs/THEMING.md`

## Offen (Stand 2026-10-18)

1. [x] Fenster-Kürzel als KWin-Script (`desktop-tiling`) + alte KDE-Kürzel raus
2. [ ] Login-Bildschirm: Plasma Login Manager – Skript `scripts/loginscreen` in Vorbereitung (braucht sudo)
3. [x] Ordnerfarbe: **Holzbraun** – eigenes Icon-Theme `Desktop-Icons` (echte Kopie, auch für Flatpaks/Ubuntu-Box)
4. [ ] iCloud-Passwörter einbinden (`~/.local/bin/icp`, wartet auf Apple-Fix -80045)
5. [x] ~~Notizen-Kachel~~ gestrichen (To-dos oben links reichen)
6. [x] ~~Desktops-Kachel~~ gestrichen · Hotlinks kommen in die Stats-Kachel (R13)
7. [x] Topbar am oberen Rand: kommt wieder (KWin-Script wurde nicht neu geladen); Fenster lassen sich durch leere Bar-Stellen packen
8. [x] Super+R: Video mit pixelgenauer Auswahl (wie Ausschneiden, Shift = genau zielen)
9. [ ] Agenda-Kachel: heute + nächste Tage zusammen, Monatskalender mit KWs; Klick öffnet Thunderbird-Kalender bzw. -Mail – in Arbeit
10. [x] Thunderbird ganz im Desktop-Look (Listen, Kalender, Adressbuch, Dialoge), Woche ab Montag
11. [x] VS Code: Theme in Rice-Farben + eigene Akzentfarbe pro Projekt

### Geplant: Claude-Zentrale oben links (2026-10-18 mit Bastian abgestimmt)

Ziel: Ordnung oben links, sauber an mehreren Projekten gleichzeitig arbeiten, Claude meldet sich selbst.

- [x] **Sammel-Chip** statt Einzel-Chips: „✦ 3 projects · 1 needs you“ (Ember, wenn etwas wartet). Klick = Popout.
- [x] (Claude-Tasks per `CLAUDE_CODE_ENABLE_TODO_TOOLS=1`) **Popout pro Projekt:** Name · Branch · Änderungen · Claude-Status je Sitzung; Klick = richtiges VS-Code-Fenster nach vorn.
  - Claudes Aufgabenliste live („3/7 · Bar umbauen“, aus Hooks)
  - **Projekt-Roadmap**: Fortschritt aus `docs/ROADMAP.md` des Projekts (erledigt/offen, nächster Punkt) – „wie weit ist Claude“
  - Eigene Aufgaben + Brainstorming pro Projekt (To-dos an das Projekt gekoppelt, schnelles Notieren)
- [x] **Claude braucht dich → Karte unter der Bar** (Frage, Erlaubnis), Bar kommt dafür auch über maximierten Fenstern.
  Direkt auf der Karte beantworten (Erlaubnis erlauben/ablehnen, Frage-Optionen wählen), VS-Code-Chat geht parallel weiter.
  Machbarkeit geprüft: geht über Hooks (PermissionRequest erlaubt/lehnt ab, PreToolUse beantwortet AskUserQuestion) – wird gebaut.

### Projekt-Ersteller (2026-10-18)

- [ ] (gebaut, wartet auf Test) Skill `/new-project`: CLAUDE.md, PRD, Roadmap, Git + Hook, Checks je Stack, Projektfarbe, optional privates GitHub-Repo (`docs/PROJECTS.md`)
- [ ] (gebaut, wartet auf Test) Launcher „New Project“: Projekt-Desktop + `~/Workspace/<name>` + VS Code mit Claude-Tab „/new-project <name>“ (`scripts/new-project`)

### Idee: Orchestrator in der Claude-Zentrale (2026-10-18, Bastian)

Claude Code (VS Code und CLI) legt alles gleich ab: `~/.claude/projects/<ordner>/<sitzung>.jsonl`, Subagents in
`<sitzung>/subagents/agent-*.jsonl`. Darauf aufbauend:
- [ ] (gebaut, wartet auf Test) **Agents pro Projekt anzeigen**: laufende/fertige Subagents je Sitzung (Beschreibung, seit wann, fertig?) –
  ohne Hooks direkt aus `~/.claude/projects/…/subagents/*.meta.json` (`scripts/claude-agents`)
- [ ] (gebaut, wartet auf Test) **Neue Aufgabe aus der Bar**: Notizfeld im Projekt, Tab → „✦ Ask Claude…“, Enter startet
  `claude -p` im Projektordner als eigene systemd-Unit (`scripts/claude-task`, übersteht Shell-Neustart); Zeile „background · running/done“
  in der Karte, fertig = Ergebnis per Klick + „Continue in VS Code“ (öffnet die Sitzung über den URI-Handler der Extension) /
  „Copy resume“; Meldung „Claude task done“; Abbrechen-Knopf. Erlaubnisse über die Antwort-Karte (Hooks greifen auch bei `-p`)
- [ ] (gebaut, wartet auf Test) **Status abfragen**: „Wie weit bist du?“ an eine Sitzung – Knopf „status“ beim Drüberfahren
  (auch an laufenden Hintergrund-Aufgaben), währenddessen „asking…“; `scripts/claude-ask` fragt einen Abzweig
  (`--resume … --fork-session --no-session-persistence --safe-mode --tools ""`, ohne Hooks/Werkzeuge, nicht gespeichert) –
  die laufende VS-Code-Sitzung bleibt byte-gleich; Antwort als Karte unter der Sitzung (4 Zeilen, Klick = ganz, Copy), 10 min
- Voraussetzung: Antwort-Karte getestet (sonst bleiben Hintergrund-Agents an Erlaubnissen hängen)

### Bugs (gemerkt)

- [ ] **Claude-Chats-Bubble** (eine Bubble für Claude Desktop/claude.ai-Antworten) – gebaut, aber ausgehängt (2026-10-18):
  Claude Desktop 2.42304 (offizielles Anthropic-Paket in der Ubuntu-Box) schickt unter Linux **keine** Benachrichtigungen
  (weder Chat noch Cowork, obwohl „Abgeschlossene Antworten“ an ist); claude.ai in Chrome geht, aber verzögert.
  Code liegt bereit: `shell/services/ClaudeChats.qml` + `shell/modules/bar/ClaudeChatsChip.qml` → wieder einhängen, sobald die App meldet.

- [ ] Während einer Bildschirmaufnahme ließ sich die Topbar (einmal) nicht mehr bedienen (2026-10-18) – **gefixt, wartet auf Test**: Aufnahme-Pille lag im Bar-Streifen (Bereich knapp unter der Bar oder ganzer Seitenmonitor → Pille oben rechts auf DP-2) und schluckte die Klicks; jetzt immer unter der Bar. Dazu Snip gehärtet (Maske leer wenn zu, Doppelklick bestätigt erst beim Loslassen, Druck/Super+S bricht hängende Auswahl ab, Spectacle-Timeout).

### Braucht Bastian / testen

- [ ] Login-Bildschirm: `scripts/loginscreen apply` (sudo, Backup + `restore`), Vorschau mit `scripts/loginscreen preview`
- [x] VS Code: Flatpak entfernt, natives läuft (Claude-Hooks kommen an)
- [x] Thunderbird: iCloud-Mail + Kalender eingerichtet
- [ ] Discord, Spotify, Thunderbird, Steam als RPM statt Flatpak (mpv statt Haruna): Apps schließen → `scripts/flatpak-to-native migrate all` → testen → `remove-flatpaks` (Shell startet bis dahin RPM zuerst, sonst Flatpak: `scripts/app-run`)
- [ ] Kamera-Helligkeit im Call testen · GoXLR-Fader nach Neustart prüfen · Workbar-Vorschau beim Fensterwechsel
- [ ] Zwischenablage: Enter = sofort einfügen (braucht `sudo dnf install ydotool` + Dienst)
- [ ] Buchhaltungs-/CRM-Adressen für `profiles/profiles.json`

## Danach: alles im Desktop-Look (Schritt 5)

- [x] KDE-Farbschema (Dolphin & Co.) – `rice theme on|off`
- [x] Konsole (transparent + Blur) + Starship
- [x] VS Code-Theme, Chrome-Theme (erzeugt; in VS Code bzw. Chrome einmal auswählen)
- [x] Cursor-Theme aus `design/cursors` (Ordnerfarbe offen)

## Abschluss

- [x] Autostart als systemd-User-Dienst + Not-Aus (Schritt 6) – `systemd/desktop-shell.service`
- [ ] PC-Repo: Umbenennen auf `~/Workspace/pc`, `packages/`, `dotfiles/`, Skripte, `bootstrap`
  - [x] Bestandsaufnahme + Bootstrap-Entwurf in `system/` (Paketlisten, `dotfiles.md`, `system/bootstrap` mit dry-run) – siehe `system/README.md`
  - [ ] Entscheiden: welche Dotfiles ins Repo, altes chezmoi-Repo zusammenführen oder behalten
  - [ ] `system/dotfiles/` befüllen + verlinken · Umbenennen des Repos
- [ ] Eine Woche Alltag, dann aufräumen: Was nervt oder wird nicht genutzt, fliegt raus

## Später

iCloud-Kalender, Tagesziel aus einer eigenen App, Uptime Kuma, Backup-Status, Steam-Playtime, Screenshot hinter dem Lockscreen
