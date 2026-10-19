# Entscheidungen – bastian-shell

Format: `JJJJ-MM-TT · Entscheidung · Grund · Status` (angenommen | vorläufig | ersetzt durch …).
ID = Datum + Stichwort (keine fortlaufenden Nummern – parallele Chats kollidieren sonst). Nicht ohne neuen Grund neu
aufrollen. Große Entscheidungen mit abgewogenen Optionen: eigene Datei `decisions/JJJJ-MM-TT-<slug>.md`
(Kontext · Optionen · Entscheidung · Folgen · Status). Ab ~300 Zeilen nach Bereich aufteilen.

## Stack

- 2026-10-19 · Projektart `desktop`, Stack Quickshell / QML · Bastians Standard · angenommen
- 2026-10-17 · Quickshell 0.3.2 aus COPR `errornointernet/quickshell` statt Fedoras 0.2.1 · 0.2.1-Snapshot kann keinen Blur (SPEC §4) · angenommen
- 2026-10-17 · Plasma/KWin bleibt Fundament, Quickshell ersetzt nur Panel, Launcher, Tray-Anzeige, OSD, Power-Menü, Benachrichtigungen · Plasma bleibt voll nutzbar und ist der Fallback (SPEC §1, §8) · ersetzt durch 2026-10-18 · Hyprland als Sitzung
- 2026-10-18 · Hyprland (COPR `sdegler/hyprland`, uwsm) als Sitzung, dieselbe Shell · mehr Leistung (360 Hz, NVIDIA) (`docs/HYPRLAND.md`) · angenommen
- 2026-10-19 · Ein Klon `~/Workspace/bastian-shell`, KWin-Variante kommt weg, Autologin in Hyprland; Plasma bleibt installiert, aber unsichtbar · Bluetooth-/WLAN-Dienste, Dolphin, Dateidialog und Qt-Theme hängen an Plasma (`docs/MIGRATE.md`) · angenommen
- 2026-10-18 · Repo wird Repo für den ganzen PC (`system/`: Pakete, Dotfiles, `bootstrap`) · neu aufsetzen mit einem Befehl, danach ist alles wie vorher (SPEC §7) · angenommen; Repo-Name OFFEN (SPEC §7 `~/Workspace/pc`, MIGRATE `bastian-shell`, AP 13 `shell`)
- 2026-10-18 · Discord-Client: normales Discord (RPM) mit eigenem Equicord-Build statt Equibop · OFFEN · angenommen
- 2026-10-18 · Discord, Spotify, Thunderbird als RPM statt Flatpak; Start RPM zuerst, Flatpak-Fallback (`scripts/app-run`) · OFFEN · angenommen (Umzug `scripts/flatpak-to-native` steht in der Roadmap noch offen)
- 2026-10-18 · Mail/Kalender: Thunderbird behalten, Plan B Evolution · Look ist gebaut, Kalender + CardDAV in einem Fenster, `mid:`-Deeplink, kein Umzug (`docs/MAIL.md`) · vorläufig (Bastian entscheidet noch, ROADMAP-HYPRLAND „Von dir“)

## Architektur

- 2026-10-17 · Apps aus der Shell nie direkt starten, sondern `kstart --application` / `systemd-run --user --scope` (Hyprland: `uwsm app --`) · sonst sterben sie mit, wenn Quickshell abstürzt oder neu startet (SPEC §4) · angenommen
- 2026-10-17 · Ein Pfad überall: `~/Workspace/bastian-shell/shell`, byte-gleich in Dev-Start, Kürzeln und systemd · Quickshell 0.3 unterscheidet Instanzen nach Pfad (SPEC §4) · angenommen
- 2026-10-17 · Fenster/Desktops per `org.kde.taskmanager` + Freigabe `org.quickshell.desktop`, Kürzel per `.desktop` mit `X-KDE-Shortcuts` → `qs ipc` · KWin fehlen foreign-toplevel, ext-workspace und GlobalShortcut (SPEC §4) · ersetzt durch 2026-10-18 · `Quickshell.Hyprland` + `hypr/binds.conf`
- 2026-10-17 · rice-bridge (Python, dbus_next) als Kindprozess nur für das, was QML nicht kann (D-Bus-Exporte) · SPEC §4 · vorläufig (nicht gebaut; Hilfsprozesse sind Einzelskripte wie `scripts/discord-bridge`)
- 2026-10-17 · Lockscreen über das Plasma-Shell-Paket `de.bastian.desktop` · KWin hat kein ext-session-lock (CLAUDE.md) · ersetzt durch 2026-10-19 · eigene Sperre `shell/modules/lock` unter Hyprland, Notfall hyprlock (`docs/LOCKSCREEN.md`)
- 2026-10-17 · Volle Shell nur auf DP-2, Seitenmonitore nur Wallpaper · Seitenmonitore gehören Discord/Doku und Browser (SPEC §1, Nicht-Ziele) · angenommen
- 2026-10-18 · Discord-Call und Kameras über eigenes Equicord-Plugin `desktopBridge` statt RPC-Bridge, Kameras gepinnt unter der Bar auf DP-2 (max. 3, 360p) · liefert Call-Status und Kamera-Bilder über einen lokalen Socket, ersetzt die RPC-Bridge vollständig, keine eigene Developer-App (`docs/DISCORD-CAMS.md`) · angenommen

## Stil

- 2026-10-17 · Farben nur aus `theme/palette.json`, alles andere wird erzeugt (`theme/gen/`) · eine Farbquelle; Features dateibasiert und ohne KI pflegbar (SPEC §4, ROADMAP-HYPRLAND „Spielregeln“) · angenommen
- 2026-10-18 · Ganze Shell deckend und freundlich (Variante hearth, kein Glas/Blur), ember bleibt als Rückweg (`scripts/rice variant ember`) · OFFEN · angenommen
- 2026-10-18 · Wirklich alle Fenster im Desktop-Design (Apps, Dialoge, Login), aber jede App behält ihren Kontrast; Discord (Blurple) und Spotify bleiben erkennbar · Überblick behalten, Wiedererkennung (SPEC §8 Schritt 5, `docs/THEMING.md`) · angenommen

## Bedienung

- 2026-10-17 · Nicht einengen: freie Desktops als Basis, Vorlagen nur zusätzlich, jede Automatik abschaltbar · SPEC §0 · angenommen
- 2026-10-18 · Workspaces: nur größere Leiste, kein Overlay · gut sichtbar, klarer aktiver Workspace, bequem wählbar (ROADMAP-HYPRLAND „Entschieden“) · angenommen
- 2026-10-19 · Tastatur zuerst: Shell komplett per Kürzel, Maus nur in Browser und Apps; ohne Kürzel und Tastaturbedienung gilt ein Feature als nicht fertig · Bedienung aus dem Muscle Memory (ROADMAP-HYPRLAND „Leitlinie“) · angenommen

## Betrieb

- 2026-10-17 · Jede Plasma-Änderung mit einem Befehl rückgängig (`scripts/rice off`), Plasma-Dateien vorher sichern, Farbschemata nur neu anlegen · Plasma bleibt Fundament und Fallback (SPEC §5, CLAUDE.md) · angenommen
- 2026-10-17 · Shell als systemd-User-Dienst mit `Restart=on-failure` · bekannte Quickshell-Abstürze bei Suspend/Resume und Monitorwegfall (NVIDIA, SPEC §4) · angenommen
- 2026-10-18 · Features dateibasiert (`projects.json`, `config/*`, `palette.json`), kurz in `docs/` beschrieben, von Hand änderbar · Bastian: Features sollen auch ohne KI nutzbar und pflegbar sein (ROADMAP-HYPRLAND) · angenommen
- 2026-10-19 · Commits als Conventional Commits (bis 2026-10-19 `bastian-shell: …`), vorher `scripts/check` per pre-commit-Hook mit Secrets-Sperre · Bastians Standard (CLAUDE.md „Konventionen“, „Qualität“) · angenommen
