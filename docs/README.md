# Doku – bastian-shell

Lesereihenfolge: SPEC → ROADMAP → TECHSTACK → DECISIONS. **Code ist die Quelle der Wahrheit**; die Docs erklären
Kontext und Warum. Leseregel: ohne Tag = gilt · `VORSCHLAG` = braucht OK · `OFFEN` = nicht entschieden ·
`TESTWERT` = Zahl darf sich ändern.

## Planung & Grundlagen

| Datei | Beantwortet |
|---|---|
| [SPEC.md](../SPEC.md) | Was wird gebaut (gilt als PRD)? Rahmen, Komponenten, Kürzel, Architektur, Plasma-Rückweg |
| [CLAUDE.md](../CLAUDE.md) | Regeln, Stil, KWin-Fakten, Struktur und Befehle für die Arbeit am Repo |
| [ROADMAP.md](ROADMAP.md) | Arbeitsliste in Reihenfolge: was ist erledigt, was ist offen, was kommt später? |
| [ROADMAP-HYPRLAND.md](ROADMAP-HYPRLAND.md) | Wo steht der Hyprland-Umbau? Fortschritt, offene Punkte, Entscheidungen, Spielregeln |
| [FORTSCHRITT.md](FORTSCHRITT.md) | Log der fertigen Pakete + was offen für Bastian ist |
| [TESTLISTE.md](TESTLISTE.md) | Was ist gebaut, aber noch nicht per echter Taste/Maus getestet? |
| [BACKLOG.md](BACKLOG.md) | Eingang für Ideen: Ideen, in Ausarbeitung, übernommen, verworfen |
| [TECHSTACK.md](TECHSTACK.md) | Warum dieser Stack? Was bewusst nicht, Qualität |
| [DECISIONS.md](DECISIONS.md) | Welche Entscheidungen gelten (Datum · Entscheidung · Grund · Status)? |
| [design-brief.md](design-brief.md) | Design-Brief für Claude Design: Ziel, Stimmung, technischer Rahmen, Liefergegenstände |

## Shell-Komponenten

| Datei | Beantwortet |
|---|---|
| [HOTKEYS.md](HOTKEYS.md) | Welche Tastenkürzel gibt es? (erzeugt aus `hypr/binds.conf`, live: Super+K) |
| [LAUNCHER.md](LAUNCHER.md) | Die eine Suche: Bedienung, Präfixe, Web-Kürzel, Claude, Passwörter, Kalender, Tabs |
| [NOTIFICATIONS.md](NOTIFICATIONS.md) | Benachrichtigungen: später erinnern (Snooze), Ruhezeiten, Hover hält an |
| [QUICKLINKS.md](QUICKLINKS.md) | Quicklinks (Ports, Links) und Git-/CI-Status an den Projekt-Workspaces |
| [PRIVACY.md](PRIVACY.md) | Privatsphäre-Punkt neben der Uhr: wann sichtbar, wie erkannt? |
| [MIXER.md](MIXER.md) | Audio-Mixer-Popout „Sound“: Routing und Apps |
| [NET.md](NET.md) | Netz-Chip + Popout: Kabel/WLAN/VPN, wann gemessen? |
| [DOWNLOADS.md](DOWNLOADS.md) | Downloads-Chip + Popout: Zustände, Konfiguration |
| [UPDATES.md](UPDATES.md) | Update-Chip: wann geprüft (dnf, COPR, Flatpak)? |
| [NOTES.md](NOTES.md) | Gedanken parken mit Super+N: Bedienung, Dateiformat `~/Notes/inbox.md` |
| [MORNING.md](MORNING.md) | Morgen-Übersicht: wann sie kommt, was drin ist, Einstellungen |
| [BREAKS.md](BREAKS.md) | Hyperfokus-Wecker: Pausen-Hinweis nach 90 min, Knöpfe, Einstellungen |
| [IDLE.md](IDLE.md) | Kamin-Idle nach 3 min Leerlauf (keine Sperre): Ablauf, Befehle |
| [CRASHES.md](CRASHES.md) | Absturz-Karte statt DrKonqi: was sie zeigt, woher die Daten kommen |
| [SCENES.md](SCENES.md) | Szenen (Spiele-Modus, Fokus, Feierabend): Dateiformat, Schritt-Typen |
| [SNIP.md](SNIP.md) | Snip: ausschneiden, Text lesen, Farbe holen, anpinnen |
| [SHARING.md](SHARING.md) | Bildschirm teilen mit eigener Auswahl-Karte statt xdph-Picker |
| [LAYOUTS.md](LAYOUTS.md) | Drop-down-Terminal und Fenster-Layouts: Kürzel, `config/layouts/` |

## Projekte & Dev

| Datei | Beantwortet |
|---|---|
| [PROJECTS.md](PROJECTS.md) | Projekt-Registry der Shell: Skill `/desktop-project`, Projekt öffnen, Einstiege |
| [PROJECTTIME.md](PROJECTTIME.md) | Wie lange lief welcher Projekt-Workspace? Tagesrückblick |
| [DEVSERVICES.md](DEVSERVICES.md) | Dev-Popout: was läuft lokal (Dev-Server, Container, Ports), starten/stoppen |
| [SSHS.md](SSHS.md) | Server-Reiter im Dev-Popout: Hosting-Konsolen und SSH aus `scripts/sshs` |

## System & Umzug

| Datei | Beantwortet |
|---|---|
| [HYPRLAND.md](HYPRLAND.md) | Hyprland-Sitzung: einrichten, zurück zu Plasma, Aufbau `hypr/`, Lücken zu KWin |
| [MIGRATE.md](MIGRATE.md) | Umzug von zwei Ordnern auf einen Klon `~/Workspace/bastian-shell`: Reihenfolge, Rückweg, Notfall |
| [LOCKSCREEN.md](LOCKSCREEN.md) | Sperrbildschirm unter Hyprland: Ablauf, Absturz, Notfall aus dem TTY |
| [THEMING.md](THEMING.md) | Alles im desktop-Look: Palette-Varianten, System, Menüs, Apps, Qt/KDE, VS Code |
| [SESSION.md](SESSION.md) | Sitzung wiederherstellen (hyprflow): einrichten, was zurückkommt und was nicht |
| [NIGHTLIGHT.md](NIGHTLIGHT.md) | Abendwärme mit hyprsunset: Befehle, `config/nightlight.json` |
| [RGB.md](RGB.md) | PC-Beleuchtung statisch auf Akzentfarbe: einrichten, Farbe ändern, Rückweg |

## Recherche & Bewertungen

| Datei | Beantwortet |
|---|---|
| [MAIL.md](MAIL.md) | Welcher Mail-/Kalender-Client passt? Vergleich, Bewertung, Empfehlung |
| [DISCORD-CAMS.md](DISCORD-CAMS.md) | Call-Infos und Kameras aus Discord in der Shell: Befund, Plugin `desktopBridge`, offene Prüfungen |
| [facecam.md](facecam.md) | Elgato-Facecam-Regler unter Linux: Standard-Regler, Extension-Unit, Setzen per ioctl |

## Setup & Logins

| Datei | Beantwortet |
|---|---|
| [setup/README.md](setup/README.md) | Übersicht: was einmal eingerichtet werden muss, wo Zugangsdaten liegen (`secrets.json`) |
| [setup/discord.md](setup/discord.md) | Discord-Call-Info einrichten: App, Redirect-URI, Secret, koppeln |
| [setup/spotify.md](setup/spotify.md) | Spotify koppeln für Up Next und Playlists im Popout |
| [setup/hue.md](setup/hue.md) | Hue Bridge koppeln (App-Key) für die Licht-Kachel |
| [setup/mail-calendar.md](setup/mail-calendar.md) | Mail (IMAP) + Kalender (CalDAV) einrichten: iCloud, später Stalwart, Thunderbird |
| [setup/passwords.md](setup/passwords.md) | iCloud-Passwörter im Browser (Helium) über die Erweiterung „Desktop“ |
| [setup/goxlr.md](setup/goxlr.md) | GoXLR: was die Shell an Fadern und Routing hält, Befehle, Rückbau |
| [setup/loginscreen.md](setup/loginscreen.md) | Login-Bildschirm (Plasma Login Manager) im Desktop-Look: was geht, Fehlersuche |
