# PRD – bastian-shell

Stand: 2026-10-19 · Status: gültig

Code ist die Quelle der Wahrheit. Details je Feature in der verlinkten Doku, Aufbau in [ARCHITECTURE.md](ARCHITECTURE.md).

## 1. Pitch

Eine eigene, warme Desktop-Shell in Quickshell (QML) über Hyprland: Bar, Dashboard, Launcher und alle Dialoge in einem Look
(„Holzhütte am Abend“), komplett per Tastatur bedienbar.

## 2. Problem

- Fertige Desktops (Plasma-Panel, -Launcher, -OSD) sind ein Flickenteppich aus Looks und brauchen die Maus.
- Alltag (Discord, Spotify, GoXLR, Licht, Projekte, Claude Code) ist über viele Apps und Fenster verstreut.
- Ein frischer PC braucht Stunden, bis er wieder so aussieht und sich so bedient wie vorher.

## 3. Lösung in einem Satz

Hyprland liefert Fenster und Workspaces, die Shell legt Bar, Popouts, Panels und Dialoge darüber und bindet alles auf Kürzel,
eine Palette färbt Shell und Apps, und `system/` setzt den ganzen PC neu auf.

## 4. Für wen

- Nur Bastian, sein PC (Fedora 44, NVIDIA, GoXLR, Hue, Key Light), drei Monitore:
  HDMI-A-2 links 1080p (Discord/Doku) · **DP-2 Mitte 1440p@360 (volle Shell)** · DP-1 rechts 1080p (Browser).
- Nicht für: andere Nutzer oder Rechner als fertiges Produkt. Das Repo ist öffentlich „as-is“, Persönliches liegt in
  gitignorierten Dateien mit `.example` daneben.

## 5. So wird es benutzt

- **Tastatur zuerst**: Shell, Fenster, Workspaces, Bar und Popouts aus dem Muscle Memory, Maus nur in Browser und Apps.
- **Super antippen** = Dashboard mit Suche (Launcher) · **Alt antippen** = Workspace-Modus · **Super+Leertaste** = Bar-Modus
  (Buchstabe je Chip öffnet das Popout, darin Pfeile/Enter/Esc).
- Tasten-Schema: Alt = Workspaces, Super = Fenster, Super+Alt = Menüs/Programme und Topbar (Super+Alt+Buchstabe = Bar-Modus-Buchstabe direkt, die häufigsten ohne Alt: Super+F/T/A/E/B/I); dazu Klassiker wie Super+O/P/K, alle live in **Super+K**.
- Läuft als systemd-User-Dienst mit der Hyprland-Sitzung; Not-Aus Strg+Alt+Shift+Q, Plasma bleibt Rückfall-Sitzung.

## 6. Kern-Funktionen

### Bar & Popouts

- **F1** Top-Bar auf DP-2: Desktops, Fokus/To-do/Termin oben links, Uhr, Spotify, Discord-Call, CPU/RAM/GPU, Tray mit eigenem Menü; weicht Vollbild aus.
- **F2** Bar-Modus Super+Leertaste: Buchstabe am Chip öffnet das Popout, alle Popouts mit Pfeilen/Enter/Esc (`KeyNav`).
- **F3** Sound-Popout (Super+Alt+S): GoXLR-Routing und -Kanäle, Lautstärke pro App ([MIXER.md](knowledge/shell-features.md)).
- **F4** Licht-Popout (Super+Alt+L): Key Light, Hue-Szenen mit Farbwähler, Kamera-Belichtung; Key Light geht mit der Kamera an und aus ([shell-features.md](knowledge/shell-features.md)).
- **F5** Netz-Popout: Status, Erreichbarkeit, Durchsatz der letzten Stunde, Speedtest nur auf Knopfdruck ([NET.md](knowledge/shell-features.md)).
- **F6** Ressourcen-Popout: Systemkarte und Prozesstabelle (Reiter, Suche, Sortieren, Beenden).
- **F7** Dateimanager- und Browser-Chip (Super+E / Super+B), letzte Downloads als Popout per Rechtsklick auf den Dateimanager ([shell-features.md](knowledge/shell-features.md)).
- **F8** Update-Chip: zählt dnf/COPR/Flatpak-Updates, öffnet den Paketmanager, installiert nie selbst ([UPDATES.md](knowledge/shell-features.md)).
- **F9** Spotify- und Discord-Popout: Warteschlange/Library bzw. Call, Mic/Taub/Kamera/Bildschirm/Verlassen, Lautstärke pro Person.
- **F10** Privatsphäre-Punkte neben der Uhr: Mikrofon, Kamera, Bildschirm teilen – nur solange aktiv ([PRIVACY.md](knowledge/shell-features.md)); am Teilen-Punkt ein Menü: Stop je Freigabe (jede App), gemerkte Wahl vergessen.

### Workspaces & Fenster

- **F11** Workspace-Leiste unten: Desktops über alle Monitore mit Vorschau, Vorlagen, offene Apps; Alt+1…9, Alt antippen = Workspace-Modus; Fenster-Symbol auf einen Mini-Monitor einer Kachel ziehen = Fenster auf genau diesen Workspace und Monitor.
- **F12** Fenster-Wechsler Alt+Tab / Super+Tab (Super+^ = gleiche App).
- **F13** Fenster per Taste: Super+Pfeile Fokus, Super+Shift+↑/↓ Stufen schwebend ↔ normal ↔ maximiert ↔ Vollbild, Super+Shift+←/→ verschieben (über Monitore), Super+Strg+Pfeile Größe, Super+Shift+V schweben, Super+1/2/3 Monitor.
- **F14** Hintergrund-Apps Discord/Spotify: Super+Q räumt weg statt zu beenden, Rausholen über Bar/Workspace-Leiste; sichtbar kommen sie auf jeden Desktop mit, auf ihrem Monitor (Liste: `config/follow.json`).
- **F15** Drop-down-Terminal (Super+Shift+Enter) und Fenster-Layouts speichern/anwenden (Super+Alt+K, [LAYOUTS.md](knowledge/shell-features.md)).
- **F16** Sitzung wiederherstellen nach Neustart/Absturz über hyprflow ([SESSION.md](knowledge/hyprland.md)).

### Dashboard & Launcher

- **F17** Dashboard (Super antippen): Uhr & Wetter, Agenda, Mail, Fokus, Spotify, Discord, Licht & Sound, Benachrichtigungen, Stats.
  Mail: öffnen in Thunderbird, nur als gelesen markieren oder in den Papierkorb – auch per Tastatur über den Launcher `m ` (↵ / Ctrl+R / Ctrl+D).
- **F18** Launcher: Apps, Fenster, Projekte ohne Präfix; `#` `=` `:` `;` `/` `@` `pw`, `cal`, `m`, `g`/`yt`/`gh` (mit Leerzeichen), `c` fragt Claude, `?` listet alles ([LAUNCHER.md](knowledge/shell-features.md)).
- **F19** Zwischenablage (Super+V) als Popup an der Eingabe – Enter fügt direkt ein; Zwischenablage (`;`) und Emoji (Super+.) auch als Launcher-Modi.
- **F20** Benachrichtigungen: Popups + Verlauf, Snooze, Ruhezeiten, Hover hält an, leiser, dumpfer Einzelton zum Popup; Super+Alt+Z/X ([NOTIFICATIONS.md](knowledge/shell-features.md)).
- **F21** Kürzel-Übersicht Super+K, erzeugt aus `hypr/binds.conf` plus App-Kürzel.
- **F22** OSD (Lautstärke, Helligkeit per DDC/CI, Medien) und Power-Menü (Super+Esc, Strg+Alt+Entf).
- **F23** Morgen-Übersicht: einmal am Morgen Termine, Mails, Wetter, To-dos, Inbox ([MORNING.md](knowledge/shell-features.md)).
- **F24** Passwörter (Super+O): iCloud-Schlüsselbund lesen und bearbeiten (F2: alles inkl. Websites, 2FA, Löschen nach „Zuletzt gelöscht“, Speichern im Hintergrund), Gruppen-Chips, Kopieren mit Auto-Leeren ([setup/passwords.md](setup/passwords.md)).

### Fokus & Alltag

- **F25** Fokus-Timer und Fokus-Modus (Super+F = Fokus-Popout, Enter = Fokus ohne Zeit bis zum Ausschalten) mit Jetzt-Aufgabe und To-dos pro Desktop.
- **F26** Hyperfokus-Wecker: ruhige Pausen-Karte nach 90 min am Stück ([BREAKS.md](knowledge/shell-features.md)).
- **F27** ~~Szenen (Spiele-Modus, Feierabend)~~ – entfernt 2026-10-20 (DECISIONS).
- **F28** ~~Abendwärme (hyprsunset)~~ – entfernt 2026-10-20 (DECISIONS).
- **F29** Gedanken parken und To-dos in einem: Super+T öffnet das Tasks-Popout oben links, Feld hat den Fokus, Enter parkt den
  Gedanken in `~/Notes/inbox.md`; dort abarbeiten (abhaken, zur Aufgabe, ins Projekt-Backlog, löschen) – kein Fenster in der Mitte mehr
  ([shell-features](knowledge/shell-features.md#gedanken-parken--to-dos)).
- **F30** Leerlauf: alle Monitore langsam abdunkeln, dann aus, danach Sperre ([shell-features](knowledge/shell-features.md#leerlauf-abdunkeln)).
- **F31** Snip: Bereich (Druck), Text per OCR (Super+Shift+T), Farbe (Super+Shift+C), Anpinnen (Super+Shift+P), Aufnahme (Super+R) ([SNIP.md](knowledge/shell-features.md)).
- **F32** Call-Kameras aus Discord als Overlay (Super+C, Ecke mit Super+Alt+Pfeile) über das Plugin `equicord/desktopBridge`.

### Dev & Projekte

- **F33** Projekt-Registry `projects/` (Farbe, Ports, was aufgeht, Links) über `scripts/project` bzw. Skill `/desktop-project`.
- **F34** Projekt-Desktop aus dem Launcher (`#`): benannter Workspace mit VS Code und Helium-Vorschau.
- **F35** Quicklinks und Git-/CI-Status an den Projekt-Workspaces, dazu Projekt-Stats (Zeit, eigene Commits, Codezeilen) ([QUICKLINKS.md](knowledge/shell-features.md)).
- **F36** Dev-Popout: Dev-Server, Container, Ports pro Projekt starten/stoppen; Reiter Server mit Konsolen und sshs (Super+Alt+V bzw. Super+Alt+H, [DEVSERVICES.md](knowledge/shell-features.md), [SSHS.md](knowledge/shell-features.md)).
- **F37** Projektzeit pro Workspace, heute im Kachelkopf der Workspace-Leiste, Woche im Tooltip ([PROJECTTIME.md](knowledge/shell-features.md)); Tagesrückblick entfernt 2026-10-20.
- **F38** Claude Code auf dem Desktop: Zentrale oben links (Sitzungen, Subagents), Rückfragen/Erlaubnisse als Karten beantworten.

### System

- **F39** Sperrbildschirm (Super+L): eigene Sperre per ext-session-lock + PAM, hyprlock als Notfall ([LOCKSCREEN.md](knowledge/hyprland.md)).
- **F40** Eigene Dialoge: Polkit-Agent, Share-Picker ([SHARING.md](knowledge/shell-features.md)), Datei-Wähler, Absturz-Karte statt DrKonqi ([CRASHES.md](knowledge/shell-features.md)).
- **F41** Paketmanager (Super+P): dnf, COPR, Flatpak, AppImage, Updates; Root nur per pkexec.
- **F42** Theming: `theme/palette.json` → Generatoren für Qt/KDE, GTK, Terminals, VS Code, Discord, Browser, Cursor, Wallpaper ([knowledge/theming.md](knowledge/theming.md)).
- **F43** PC-Beleuchtung per OpenRGB statisch in der Akzentfarbe, auch nach Standby ([hardware.md](knowledge/hardware.md)); Drop ALT ausgenommen.
- **F44** PC neu aufsetzen: `system/bootstrap` (dry-run, `--apply`), Paketlisten, Dotfiles; Sitzung per `scripts/hypr install|uninstall`.
- **F45** Gear-Popout (Bar-Modus G): PC-Licht an/aus, Farbe aus der Palette, Sättigung/Helligkeit; Maus G502 X PLUS mit Akku, DPI-Stufen und Farbe ins Onboard-Profil; Akku-Warnung am Chip ([hardware.md](knowledge/hardware.md)).
- **F46** Einstellungen-Chip neben dem Browser (Bar-Modus I): KDE-Systemeinstellungen, Mittelklick Bluetooth ([shell-features.md](knowledge/shell-features.md)).

## 7. Nicht-Ziele

- Kein Dock, kein Rahmen ums Bild, kein Stream-Modus – nicht gebraucht (alte SPEC §1).
- Keine Bar/Panels auf den Seitenmonitoren – die gehören Discord/Doku und dem Browser.
- Keine Pflicht-Vorlagen und keine Automatik ohne Aus-Schalter – nicht einengen; freie Workspaces sind die Basis.
- Kein Glas, Blur, Glühen in der aktiven Palette `hearth` – Stilregel: alle Flächen deckend (`CLAUDE.md`).
- Keine Lautstärketasten und kein Mischpult-Ersatz – Pegel regelt der GoXLR selbst, der PC-Ausgang bleibt auf 100 %.
- Nichts installiert sich von selbst (Updates, Pakete) – Bastian entscheidet im Paketmanager.

## 8. Erfolg

- Jede Shell-Funktion hat ein Kürzel und ist per Tastatur bedienbar – sonst gilt sie als nicht fertig (Leitlinie 2026-10-19).
- Nach einer Woche Alltag fliegt raus, was nicht genutzt wird oder nervt.
- Rückweg in einem Befehl: Not-Aus Strg+Alt+Shift+Q, `scripts/hypr uninstall`, Plasma-Sitzung bleibt nutzbar.
- Die Shell übersteht Neustart, Standby und abgesteckte Monitore ohne Handarbeit (Härtetest AP 21: `OFFEN`).
- Ein frischer Fedora wird mit `system/bootstrap --apply` wieder dieser PC (echter Lauf: `OFFEN`).
- `scripts/check` ist grün vor jedem Commit.
