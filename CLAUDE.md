# desktop – Bastians Shell (Quickshell auf Hyprland)

Bastians einziges Theme „desktop“ (früher „Hütte“): Quickshell (QML, Layer-Shell) auf Fedora 44 / Hyprland 0.56 (uwsm).
Plasma bleibt installiert (Dolphin, Dateidialog, Qt-Theme, Bluetooth/WLAN), ist aber nicht mehr die Sitzung.
Der alte KWin-Weg ist aus dem Repo entfernt und liegt nur noch im Git-Tag `kwin-final` (`docs/knowledge/hyprland.md`).

## Regeln

- Antworten kurz und auf Deutsch.
- Vor jedem `sudo` fragen.
- Secrets (Hue-Key, Tokens, Passwörter) nur in `secrets.json` (gitignored). Nie loggen, nie committen.
- Nichts an System/Plasma ändern, was sich nicht mit einem Befehl rückgängig machen lässt (`scripts/hypr uninstall`, `scripts/rice off`).
  Plasma-Dateien vorher sichern. Nie `kded6` oder `plasmashell` killen. Farbschemata nur neu anlegen, nie überschreiben.
- Eine Komponente pro Runde → Bastian testet mit `qs -p ~/Workspace/bastian-shell/shell` und schickt Screenshot → erst dann committen.
- `refs/` ist nur Referenz (caelestia, end-4, noctalia …). Code daraus ist GPL-3.0: Herkunfts-Header behalten
  und Zeile in `THIRD_PARTY.md` ergänzen.
- Apps aus der Shell nur über `Launch.qml` starten (`uwsm app --`, sonst `systemd-run --user --scope`), nie direkt
  (sonst sterben sie mit, wenn Quickshell neu startet).
  Discord/Spotify/Thunderbird sind RPMs (früher Flatpak): starten über `Launch.run("discord")` bzw. `scripts/app-run`
  (RPM zuerst, Flatpak-Fallback), Umzug der Daten: `scripts/flatpak-to-native`.
- Keine neue Abhängigkeit (dnf-Paket, COPR, Python-Modul, QML-Plugin) ohne Rückfrage – dann in `system/packages/` + `docs/TECHSTACK.md`.
- Größere Features erst planen (Plan Mode), Plan bestätigen lassen, dann bauen.
- Fertig = läuft, getestet, committet → in der Roadmap abhaken: `- [x] … (JJJJ-MM-TT)`.
- Security: noch kein Audit – bei Gelegenheit Skill `security-audit`, Profil `quick` (Berichte unter `~/security-audit-skill/bastian-shell/run-N`, nie im Repo).

## Stil (verbindlich)

cozy, clean, lowkey, **freundlich**, warm-holzig ("Holzhütte am Abend mit Kaminfeuer"). Alle Flächen **deckend** (kein Glas, kein Blur,
keine Transparenz, kein Glühen/Neon, wenig „dynamisch-glitzernd“): warmes Mittel-Dunkelbraun statt Fast-Schwarz,
sanftes Ember-Terrakotta als sparsamer Akzent, Holzbraun und Creme als Nebentöne. Kein Gruvbox.
Weiche Ecken, ruhige Schatten, viel Luft, klare aktiv/inaktiv-Zustände. Inter + JetBrains Mono Nerd Font. Funktion vor Deko.
Farben nur aus `theme/palette.json` (aktive Variante **hearth**; die alte Glas-Variante **ember** bleibt: `scripts/rice variant ember`), nie hart im QML.
Flächen aus Tokens `surface` / `surfaceRaised` / `surfaceSunken`; `Glass.qml` liefert die Fläche, `Theme.blurEnabled` (Palette `blur`) steuert Blur.

## Hyprland-Fakten (Details: `docs/knowledge/hyprland.md`)

- Hyprland aus COPR `sdegler/hyprland` unter uwsm · Quickshell **0.3.2 aus COPR `errornointernet/quickshell`** (Fedoras 0.2.1 zu alt).
- Fenster/Workspaces über `Quickshell.Hyprland` (`shell/services/Hypr.qml`).
- Kürzel nur in `hypr/binds.conf` → `qs ipc call …`; der Titel `# …` dahinter speist Super+K und `scripts/hotkeys-md`
  (erzeugt `docs/knowledge/hotkeys.md` – nie von Hand ändern).
- Sperre = eigene Shell-Sperre (`shell/modules/lock`, ext-session-lock), Notfall hyprlock.

## Monitore

HDMI-A-2 links 1080p (Discord) · DP-2 Mitte 1440p@360 (volle Shell) · DP-1 rechts 1080p (Browser).

## Struktur

- `shell/` Quickshell-Config (`shell.qml`, `services/`, `components/`, `modules/`)
- `hypr/` Hyprland-Konfig (binds, rules, monitors) · `config/` App- und Shell-Einstellungen (`*.json`)
- `scripts/` Hilfsprogramme für Shell und Kürzel · `systemd/` User-Dienste (`desktop-shell-hyprland` u. a.)
- `tools/` eigene C-Quellen, gebaut nach `~/.local/lib/desktop/` (`v4l2-fastprobe`: schnellerer Kamerastart in Discord, `scripts/fastprobe`)
- `theme/` `palette.json` + Generatoren `theme/gen/` für alle Apps · `design/` Inspos, Design-Brief, `preview.html`
- `projects/` Projekt-Registry (`projects.json`: Farbe, Ports, Öffnen, Links – nur über `scripts/project`) · `profiles/` Desktop-Vorlagen
- `equicord/` Discord-Plugin `desktopBridge` · `plasma/loginscreen/` Theme des Login-Bildschirms (Plasma Login Manager, `scripts/loginscreen`)
- `claude/skills/desktop-project/` nur der Wrapper `project` um `scripts/project` (kein Slash-Befehl; genutzt von
  `/project` und `/new-project` aus dem privaten Skill-Repo), verlinkt per `scripts/claude-skills install`
- `system/` PC neu aufsetzen: `packages/` (dnf, Repos, Flatpak, VS-Code-Erweiterungen, Sonstiges), `dotfiles.md`,
  `bootstrap` (Standard dry-run, echt mit `--apply`) – Anleitung `system/README.md`

## Befehle

- Testen: `qs -p ~/Workspace/bastian-shell/shell` (nicht `qs -p .`, sonst liest Quickshell `refs/` mit ein).
  Immer derselbe absolute Pfad wie in Kürzeln und systemd, sonst finden die Kürzel die Instanz nicht.
- IPC: `qs ipc --any-display -p ~/Workspace/bastian-shell/shell call <target> <function>`
- Einrichten: `scripts/hypr install|uninstall|status|check` · Shell neu starten: `scripts/hypr restart`
  (User-Unit `desktop-shell-hyprland`, Log: `journalctl --user -u desktop-shell-hyprland`)
- Not-Aus: Strg+Alt+Shift+Q = `scripts/hypr panic` (Shell aus, Konsole auf)
- Discord-Kamera schneller: `scripts/fastprobe build|on|off|status|bench` (wirkt beim nächsten Discord-Start)
- Bildschirm teilen: `scripts/share-picker status|remembered|forget [app]` (gemerkte Auswahl je App)
- Klänge: `scripts/sounds play [notify-urgent]|build|on|off|status` (Probehören, neu erzeugen, Sound-Theme für Apps)
- Kürzel geändert: `scripts/hotkeys-md` (Cheat-Sheet neu) · Farben geändert: `python3 -I theme/gen/all.py`
- PC neu aufsetzen: `system/bootstrap` (dry-run, echt mit `--apply`) · Umzug: `docs/setup/migrate.md`
- Checks: `scripts/check` (Tests unter `scripts/tests/`, qmllint wenn installiert) – läuft auch als Git-Hook

## Qualität

Vor jedem Commit muss grün sein (Git-Hook `.githooks/pre-commit`: Secrets-Sperre + `scripts/check`):

- `scripts/check` = `scripts/tests/*-test.js` (node) + `*-test.py` + qmllint (fehlt noch: `qt6-qtdeclarative-devel`, braucht `sudo`)
- danach mit `qs -p ~/Workspace/bastian-shell/shell` testen, Bastian schickt Screenshot (siehe Regeln)
- Fremden Code (GPL, caelestia/end-4) nur mit Herkunfts-Header übernehmen.

## Konventionen

Profil **solo**: Bezeichner, Datei- und Ordnernamen Englisch · Kommentare Deutsch (warum statt was,
nie mischen) · Doku Deutsch, Dateinamen Englisch · Commits: Conventional Commits
(`feat|fix|refactor|docs|test|chore|perf|build(scope): was`, ≤ 72 Zeichen, Text Deutsch, Body = warum).
`TODO:` nur mit Ziel (`→ ROADMAP AP 22`). Volle Regeln: `~/Workspace/WebBude/webbude-skills/skills/_standard/templates/CONVENTIONS.md`.
Abweichungen in diesem Projekt: Commits bis 2026-10-19 im Format `bastian-shell: …` (Englisch) – ab jetzt Conventional Commits,
Scope = Bereich (`bar`, `workbar`, `launcher`, `bridge`, `hypr`, `theme`, `system`, `docs` …).

## Workflow

- Größere Features: Plan Mode → Plan bestätigen lassen → umsetzen → Checks zeigen → Roadmap abhaken.
- Roadmap: nur `docs/ROADMAP.md` (alte `ROADMAP-HYPRLAND.md` seit 2026-10-20 nur noch in Git).
  Nur `- [ ]` / `- [x]` (kein `[~]` → `- [ ] … (teilweise: was fehlt)`), erster offener Punkt = nächster Schritt.
- Ideen „nicht jetzt“: eine Zeile in `docs/BACKLOG.md` statt umsetzen; ganzes Konzept → `docs/BACKLOG-<THEMA>.md`.
- Beim Kompaktieren erhalten: geänderte Dateien, offene TODOs, aktueller Roadmap-Punkt.

## Doku-Pflege

Doku im selben Commit wie der Code. **Code ist die Quelle der Wahrheit:** Docs behaupten nie Umgesetztes, das nicht im
Code steht, und wiederholen nicht, was der Code schon zeigt (Versionen, Feldlisten, IPC-Funktionen) – sie verweisen auf die
Stelle und erklären das Warum. Widerspricht die Doku dem Code: Doku sofort korrigieren. Ausnahme Planung
(ROADMAP, BACKLOG) – dort steht Geplantes, klar als geplant markiert. Nur erklären, was man aus dem Code nicht sieht.
**Nie in Docs:** Tastenkürzel (dafür gibt es `scripts/hotkeys-md`), Befehls-/Flag-Listen, UI-Abläufe Schritt für Schritt,
Defaults, Grenzwerte, Pfade. Vor dem Schreiben im Code nachsehen, wie es umgesetzt ist – auch in Aufträgen an Agents sagen.

| Auslöser | Doc |
| --- | --- |
| Punkt läuft, getestet, committet | Roadmap abhaken: `- [x] … (JJJJ-MM-TT)` |
| Neue Aufgabe beim Bauen | Roadmap `- [ ]` an die richtige Stelle (Reihenfolge = Priorität) |
| Idee „nicht jetzt“ | `docs/BACKLOG.md` (eine Zeile) |
| Neues Paket, Werkzeugwechsel | `docs/TECHSTACK.md` (warum) + `docs/DECISIONS.md` + `system/packages/` – nach OK |
| Grundsatzentscheidung | `docs/DECISIONS.md`: `JJJJ-MM-TT · Entscheidung · Grund · Status` |
| Scope ändert sich (Ziel, Nicht-Ziel) | `docs/PRD.md` (gilt als PRD) + DECISIONS – nur nach OK |
| Neues Feature | eine Zeile in `docs/PRD.md` (Kern-Funktionen) |
| Grenze oder Stolperfalle eines Features, die der Code nicht zeigt | `docs/knowledge/shell-features.md` (≤ 6 Zeilen je Feature) |
| Neues Kürzel | `hypr/binds.conf` mit Titel, dann `scripts/hotkeys-md` |
| Neuer Befehl, Ordner, Skript | CLAUDE.md „Befehle“ / „Struktur“ |
| Setup-/Login-Schritt gelernt | `docs/setup/<thema>.md` |
| Fehler passiert zum zweiten Mal | Regel unter „Regeln“ |

## Doku

| Datei | Wofür |
| --- | --- |
| `README.md` | öffentlich (Englisch): was es ist, Installation |
| `THIRD_PARTY.md` | übernommener fremder Code + Lizenzen (Pflicht, Repo ist GPL und öffentlich) |
| `docs/PRD.md` | was die Shell kann und warum, Nicht-Ziele |
| `docs/ARCHITECTURE.md` | wie sie gebaut ist (Ordner, Datenfluss, IPC, Start) |
| `docs/ROADMAP.md` | was dran ist |
| `docs/BACKLOG.md` · `docs/TECHSTACK.md` · `docs/DECISIONS.md` | Ideen · womit und warum · Entscheidungs-Log |
| `docs/knowledge/` | `shell-features` (Konfig/Grenzen je Feature) · `hyprland` (Sitzung, Sperre, hyprflow, alter KWin-Weg) · `theming` · `hotkeys` (erzeugt) · `projects` (Registry) · `discord` (Plugin, Kameras) · `hardware` (Facecam, RGB) |
| `docs/setup/` | einmal einrichten: discord, goxlr, hue, spotify, mail-calendar, passwords, loginscreen, migrate |
