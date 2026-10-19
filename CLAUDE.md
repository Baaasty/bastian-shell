# desktop – Bastians Rice (Quickshell über KWin)

Bastians einziges Theme „desktop“ (früher „Hütte“): Quickshell (QML, Layer-Shell) auf Fedora 44 / Plasma 6.7 / KWin Wayland.
Plasma bleibt Fundament (Fenster, Einstellungen, Fallback). Was gebaut wird, steht in [SPEC.md](SPEC.md).

## Regeln

- Antworten kurz und auf Deutsch.
- Vor jedem `sudo` fragen.
- Secrets (Hue-Key, Tokens, Passwörter) nur in `secrets.json` (gitignored). Nie loggen, nie committen.
- Nichts an Plasma ändern, was sich nicht mit einem Befehl rückgängig machen lässt (`scripts/rice off`).
  Plasma-Dateien vorher sichern. Nie `kded6` oder `plasmashell` killen. Farbschemata nur neu anlegen, nie überschreiben.
- Eine Komponente pro Runde → Bastian testet mit `qs -p ~/Workspace/bastian-shell/shell` und schickt Screenshot → erst dann committen.
- `refs/` ist nur Referenz (Hyprland/niri). Hyprland-Spezifisches für KWin anpassen oder weglassen.
  Code aus caelestia/end-4 ist GPL-3.0: Herkunfts-Header beim Übernehmen behalten.
- Apps aus der Shell nur per `kstart --application …` oder `systemd-run --user --scope` starten, nie direkt
  (sonst sterben sie mit, wenn Quickshell neu startet).
  Discord/Spotify/Thunderbird sind RPMs (früher Flatpak): starten über `Launch.run("discord")` bzw. `scripts/app-run`
  (RPM zuerst, Flatpak-Fallback), Umzug der Daten: `scripts/flatpak-to-native`.

## Stil (verbindlich)

cozy, clean, lowkey, **freundlich**, warm-holzig ("Holzhütte am Abend mit Kaminfeuer"). Alle Flächen **deckend** (kein Glas, kein Blur,
keine Transparenz, kein Glühen/Neon, wenig „dynamisch-glitzernd“): warmes Mittel-Dunkelbraun statt Fast-Schwarz,
sanftes Ember-Terrakotta als sparsamer Akzent, Holzbraun und Creme als Nebentöne. Kein Gruvbox.
Weiche Ecken, ruhige Schatten, viel Luft, klare aktiv/inaktiv-Zustände. Inter + JetBrains Mono Nerd Font. Funktion vor Deko.
Farben nur aus `theme/palette.json` (aktive Variante **hearth**; die alte Glas-Variante **ember** bleibt: `scripts/rice variant ember`), nie hart im QML.
Flächen aus Tokens `surface` / `surfaceRaised` / `surfaceSunken`; `Glass.qml` liefert die Fläche, `Theme.blurEnabled` (Palette `blur`) steuert Blur.

## KWin-Fakten (geprüft, Details in SPEC.md §4)

- Quickshell **0.3.2 aus COPR `errornointernet/quickshell`** (Fedoras 0.2.1-Snapshot kann keinen Blur).
- Da: layer-shell, ext_background_effect (Blur), ext_idle_notifier, ext_data_control.
- Fehlt: foreign-toplevel, ext-workspace, ext-session-lock, screencopy, Hyprland-GlobalShortcut/FocusGrab.
- Ersatz:
  - Fenster/Desktops = `import org.kde.taskmanager` + Freigabe in `org.quickshell.desktop`
  - D-Bus = `import org.kde.plasma.workspace.dbus`
  - Kürzel = `.desktop` mit `X-KDE-Shortcuts` → `qs ipc call`
  - Klick außerhalb = `PopupWindow.grabFocus` / Klick-Schutz-Fläche
  - Lockscreen = Plasma-Shell-Paket
- **Nie einen zweiten `kwin_wayland` starten** (auch nicht `--virtual` zum Testen): Beim Beenden markiert er alle KWin-Kürzel als tot (Alt+Tab …). Reparatur: `scripts/rice keys-fix`.
- Erste Anlaufstelle für KWin-Lösungen: `refs/caelestia-kde`. CLI: `qdbus-qt6` oder `busctl --user` (kein `qdbus6`).

## Monitore

HDMI-A-2 links 1080p (Discord) · DP-2 Mitte 1440p@360 (volle Shell) · DP-1 rechts 1080p (Browser).

## Struktur

- `shell/` Quickshell-Config (`shell.qml`, `services/`, `components/`, `modules/`)
- `bridge/` rice-bridge (Python, dbus_next) + `bridge/kwin/` KWin-Script · `plasma/` Plasma-Shell-Paket (ohne Panel)
- `theme/` `palette.json` + Generatoren (KDE, Konsole, Starship, Cursor)
- `design/` Inspos, Claude-Design-Ergebnisse, `preview.html`
- `docs/` Doku: `ROADMAP.md`, `design-brief.md`, `HOTKEYS.md`, `HYPRLAND.md` (`hypr/`, `scripts/hypr`), `LOCKSCREEN.md`, `MIGRATE.md` (Umzug aus den alten Ordnern, `system/migrate`) · `docs/setup/` Logins & Kopplungen
  (Spotify, Discord, Hue, Mail & Kalender; Übersicht in `docs/setup/README.md`). `SPEC.md` + `CLAUDE.md` bleiben im Hauptordner.
- `projects/` Projekt-Einstellungen (`projects.json`: Farbe, Ports, Öffnen, Links – nur über `scripts/project`) · `profiles/` Desktop-Vorlagen · `scripts/` `rice on|off|status` · `systemd/` User-Dienst
- `claude/skills/` Claude-Code-Skill `/desktop-project` (Projekt-Registry, Doku: `docs/PROJECTS.md`), verlinkt per `scripts/claude-skills install`.
  Eigene Projekt-Skills (`/new-project`, `/project`) liegen in einem privaten Skill-Repo mit eigenem Install, nicht hier
- `system/` PC neu aufsetzen: `packages/` (dnf, Repos, Flatpak, VS-Code-Erweiterungen, Sonstiges), `dotfiles.md`,
  `bootstrap` (Standard dry-run, echt mit `--apply`) – Anleitung `system/README.md`

## Befehle

- Testen: `qs -p ~/Workspace/bastian-shell/shell` (nicht `qs -p .`, sonst liest Quickshell `refs/` mit ein).
  Immer derselbe absolute Pfad wie in Kürzeln und systemd, sonst finden die Kürzel die Instanz nicht.
- IPC: `qs ipc --any-display -p ~/Workspace/bastian-shell/shell call <target> <function>`
- An/Aus: `scripts/rice on|off|restart|status` (läuft als User-Unit `desktop-shell`, Log: `journalctl --user -u desktop-shell`)
- Not-Aus: Strg+Alt+Shift+Q = `scripts/rice off` (stellt Vanilla-Plasma wieder her)
- Lockscreen-Paket: `scripts/shellpkg install|test|on|off` · Wallpaper: `scripts/wallpaper set|restore`
- Kürzel-Datei ändern: `rice off && rice on` (kglobalaccel übernimmt Änderungen an bestehenden Dateien nicht live)
