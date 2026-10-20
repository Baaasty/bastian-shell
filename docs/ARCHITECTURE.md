# Architektur – bastian-shell

Stand: 2026-10-19 · Code ist die Quelle der Wahrheit; hier nur, wo was liegt und wie es zusammenhängt.
Was gebaut wird: [PRD.md](PRD.md) · warum dieser Stack: [TECHSTACK.md](TECHSTACK.md).

## Ordner

| Ordner | Rolle |
|---|---|
| `shell/` | Quickshell-Config. `shell.qml` = `ShellRoot`, lädt jedes Modul einmal |
| `shell/services/` | Singletons: Daten und Zustand (`Hypr.qml`, `Desktops`, `Notifs`, `Focus`, `Discord` …), keine Oberfläche |
| `shell/modules/` | Oberflächen, ein Ordner pro Funktion (`bar/`, `dashboard/`, `launcher/`, `workbar/`, `lock/` …) |
| `shell/components/` | Bausteine (`Glass.qml` = Fläche, `KeyNav.qml` = Tastatur in Popouts, `Chip`, `Slider`, `Txt` …) |
| `shell/config/` | `Config.qml` (Monitor, feste Einstellungen), `Theme.qml` (liest `theme/palette.json` live) |
| `shell/assets/`, `shell/data/` | PAM-Datei der Sperre (`pam.d/desktop-lock`), Emoji-Liste |
| `scripts/` | Hilfsprozesse (Python `-I`, Bash) für alles, was QML nicht kann; Tests in `scripts/tests/`, Gesamtcheck `scripts/check` |
| `hypr/` | Hyprland-Konfig (`hyprland.conf` + Teile), `binds.conf` → `qs ipc`, `hypridle.conf`, `autostart.conf` |
| `config/` | Konfig im Repo (`breaks.json`, `consoles.json`, `notifications.json`, `launcher/web.json`, App-Konfigs) |
| `theme/` | `palette.json` → `theme/gen/*.py` → `theme/out/` (+ Installation nach `~/.local`), siehe `theme/README.md` |
| `systemd/` | User-Units: Shell (`desktop-shell-hyprland.service`), Mail, Agenda, Session-Save, GoXLR, Key Light |
| `system/` | PC neu aufsetzen: Paketlisten, Dotfiles, `bootstrap` (dry-run, `--apply`), siehe `system/README.md` |
| `projects/` | Projekt-Registry (`projects.json` lokal, `projects.example.json` im Repo, `store.py`, nur über `scripts/project`) |
| `profiles/` | Desktop-Vorlagen (`profiles.json` lokal, `.example` im Repo; `services/Templates.qml`) |
| `equicord/desktopBridge/` | Discord-Plugin (Equicord): Call-Status und Kamerabilder über einen lokalen Socket an `services/Cams.qml`/`Discord.qml` |
| `plasma/`, `bridge/kwin/`, `scripts/rice` | alter KWin/Plasma-Weg (Shell-Paket, KWin-Skripte, Login-Theme); bleibt im Baum, nicht mehr im Fokus |

## Datenfluss

- **Hyprland → Shell**: `services/Hypr.qml` ist die einzige Hyprland-Anbindung (`Quickshell.Hyprland`). Es hört auf
  `rawEvent`, holt Fenster/Workspaces neu (kein Polling) und zählt `version` hoch; `Windows`, `Desktops`, `Parked`
  und die Module binden darauf. Desktop d = Workspace d auf DP-2, 100+d / 200+d auf den Nebenmonitoren (Kopf von `Hypr.qml`).
- **Shell → Hyprland**: Befehle über `Hypr.qml` (`hyprctl`-Dispatch/Batch); Apps nur über `services/Launch.qml` (`uwsm app --`).
- **Kürzel → Shell**: `hypr/binds.conf` ruft `$IPC <ziel> <funktion>` (`$IPC = qs ipc --any-display -p $DESKTOP/shell call`,
  `hypr/hyprland.conf`). Ziele = `IpcHandler { target: … }` in den Modulen/Services (z. B. `dashboard`, `launcher`,
  `barmode`, `workbar`, `snip`, `lock`); Liste: `grep -rh 'target:' shell`. Kommentare `# …` hinter den
  Binds speisen Super+K (`modules/keys/keybinds.py`) und `docs/knowledge/hotkeys.md` (`scripts/hotkeys-md`).
- **Hilfsprozesse**: QML startet `scripts/*` als `Process`; Antwort als JSON auf stdout (einmalig oder als
  JSON-Zeilen im Dauerlauf, `SplitParser`), Befehle bei Bedarf über stdin (z. B. `scripts/procs watch`,
  `scripts/discord-bridge`). Schreibende/lange Aktionen laufen als eigene systemd-Unit.
- **Popouts**: immer nur eins offen (`services/Popouts.qml`); Tastatur über `services/BarKeys.qml` + `components/KeyNav.qml`.
  Offene Panels mit Tastatur sperren die übrigen Kürzel über die Submap `modal` (`Hypr.setModal`, Ende `binds.conf`).
- **Farben**: nur aus `theme/palette.json` über `config/Theme.qml` (live neu geladen), nie hart im QML.

## Zustand und Konfiguration

| Wo | Was |
|---|---|
| `~/.local/state/desktop/` | Laufzeit-Zustand der Shell (Desktops, To-dos, Fokus, Stats, Snooze, Projektzeit, Morgen …) |
| `~/.config/desktop/*.json` | lokale Einstellungen/Overrides (`lock.json`, `audio.json`, `consoles.json`, `notifications.json` …) |
| `~/.config/desktop/hyprland.env` | `DESKTOP=<Repo-Pfad>`, angelegt von `scripts/hypr install`, gelesen von Hyprland und systemd |

## Start

- `scripts/hypr install` verlinkt `hypr/`, Portale, uwsm-Umgebung und die Unit nach `~/.config` (nichts systemweit),
  `uninstall` nimmt alles zurück.
- `systemd/desktop-shell-hyprland.service` startet `qs -p ${DESKTOP}/shell` mit der Hyprland-Sitzung, `Restart=on-failure`;
  unter Plasma hält `ExecCondition` sie an. Plasma-Gegenstück: `desktop-shell.service` (`scripts/rice on|off`).
- Ein Pfad überall (`~/Workspace/bastian-shell/shell`): Quickshell unterscheidet Instanzen nach Pfad, sonst findet
  `qs ipc` sie nicht. Testen: `qs -p ~/Workspace/bastian-shell/shell`.
- Weitere Hintergrund-Starts (hypridle, Polkit-Agent, Session-Restore, RGB): `hypr/autostart.conf`.

## Secrets

- Nur in `secrets.json` (gitignored), Vorlage `secrets.example.json` (Hue, Key Light, stats.fm, Ort, Konten).
  Gelesen von den Services, die sie brauchen (`Hue`, `KeyLight`, `Weather`, `Mail`, `Discord`, `SpotifyApi`, `Stats`).
- Lokale Daten ebenso mit `.example` daneben: `projects/`, `profiles/`, `system/dotfiles/`, `system/copies/`.
- Pre-commit-Hook `.githooks/pre-commit` (über `scripts/check`) sperrt Secrets im Commit. Nie loggen.
