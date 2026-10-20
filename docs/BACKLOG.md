# Backlog – bastian-shell

Eingang für Ideen, damit nichts im Chat verloren geht. Eine Zeile pro Idee: **Titel** – worum es geht (Datum, Quelle).
**Keine Checkboxen** (Ideen sind keine Zusagen, werden nicht gezählt). Wird es ein ganzes Konzept: eigene Datei `BACKLOG-<THEMA>.md`
(Status Idee → VORSCHLAG → beschlossen → umgesetzt | verworfen) oder direkt als Punkt in [ROADMAP.md](ROADMAP.md).

## Ideen

- **Theme-Variante nach Tageszeit** – hearth abends heller/dunkler; „bewusst nicht jetzt“ (Quelle: docs/knowledge/shell-features.md)
- **Stalwart als zweites Mail-Konto** – weiterer Eintrag in `accounts` nach Vorlage `_stalwart_example` (Quelle: docs/setup/mail-calendar.md)
- **Backup-Status** – letzter Lauf im Dashboard; braucht erst ein Backup (z. B. btrbk/snapper auf btrfs) (Quelle: docs/ROADMAP.md „Später“, alte SPEC §2.2)
- **Mit mir geteilte Passwort-Gruppen** – Gruppen fremder Besitzer (Shared-DB + Teilnehmer-Schlüssel) in icp lesen; eigene Gruppen gehen schon (`~/Apps/icp/icp/sharing`) (2026-10-19, Quelle: Chat)
- **Claude-Chats-Bubble** – eine Bubble für Claude-Desktop/claude.ai-Antworten; Code liegt bereit (`shell/services/ClaudeChats.qml`, `shell/modules/bar/ClaudeChatsChip.qml`), **blockiert**: Claude Desktop schickt unter Linux keine Benachrichtigungen (2026-10-18, aus der Roadmap 2026-10-20)
- **Härtetest der Shell** – Shell-Neustart, DP-2 aus/an, Standby, Netz weg: fängt sich die Shell ohne Neustart? (aus der Roadmap 2026-10-20, AP 21)

## In Ausarbeitung

## Übernommen

- **KWin-Code aus dem Repo** – `scripts/rice` (außer `theme`/`feeds`), `scripts/shellpkg`, `scripts/winrules`, `bridge/kwin/`, `plasma/` entfernen; „eigene Runde“ (Quelle: docs/setup/migrate.md) → umgesetzt 2026-10-20
- **Mail-Schnellaktionen in der Shell** – „Als gelesen“/„Archivieren“ per eigenem IMAP-Aufruf neben „Öffnen“; „später evtl.“ (Quelle: docs/DECISIONS.md) → umgesetzt 2026-10-20
- **Leise, warme Systemklänge** – eigener sanfter Benachrichtigungston („weicher Holz-Klick“) statt Standard; optional (Quelle: docs/knowledge/theming.md, design/brief.md) → umgesetzt 2026-10-20
- **Kamera-Status ereignisgesteuert** – `Camera.qml` fragt `scripts/camera status` alle 5 s ab; könnte über `scripts/privacy-cam` (inotify auf `/dev/video`) laufen (Quelle: docs/ROADMAP-HYPRLAND.md) → umgesetzt 2026-10-20
- **Tasten-Hinweise in Popout-Fußzeilen als Kappen** – Fokus, Tasks, Dateiauswahl und Kürzel-Menü zeigen ihre Tasten noch als Fließtext; auf die gemeinsamen Kappen (`KeyCap`/`KeyTip`) umstellen (2026-10-20, Quelle: einheitliche Hotkey-Einblendungen) → umgesetzt 2026-10-20

## Verworfen

<!-- mit Grund, damit sie nicht wiederkommt -->

- **Quelle beim Teilen live wechseln** – „Share something else…“ im Teilen-Menü, ohne den Stream zu beenden — verworfen 2026-10-20: unter Wayland fragt Discord das Portal nicht neu (`presentDesktopSourcePicker` ist ein No-Op), der Weg über Stop + Neustart beendete den Stream; das Portal tauscht keine Quelle einer laufenden Freigabe. Einzige Möglichkeit: virtueller Bildschirm/Headless-Output, der einen Monitor spiegelt und den man intern umschaltet
- **Login als Quickshell-Greeter** – greetd mit einem Quickshell-Greeter in einem kleinen Hyprland, Farben aus `palette.json` (`theme/gen/login.py`); nur geplant, nicht gebaut (Quelle: docs/setup/migrate.md) — verworfen 2026-10-20: Autologin, Login-Bildschirm wird nie gesehen
- **Bootstrap ohne Plasma** – `system/packages/dnf.txt` und `system/bootstrap` auf greetd + Keep-Liste umstellen, statt Plasma neu zu holen; „eigene Runde“ (Quelle: docs/setup/migrate.md) — verworfen 2026-10-20: Plasma bleibt eh (Dolphin, Dateidialog, Bluetooth/WLAN)
- **Tagesziel aus einer eigenen App** – Dashboard zeigt ein Tagesziel über die API einer eigenen App (welche, ist offen) (Quelle: docs/ROADMAP.md „Später“, alte SPEC §2.2) — verworfen 2026-10-20: keine App dafür, To-dos oben links reichen
- **Uptime Kuma** – eigene Status-Seiten im Dashboard über `/api/status-page/heartbeat/<slug>` (Quelle: docs/ROADMAP.md „Später“, alte SPEC §2.2) — verworfen 2026-10-20: Server-Reiter im Dev-Popout reicht
- **Steam-Playtime** – Spielzeit dieser Woche aus Steam lokal (`localconfig.vdf`) (Quelle: docs/ROADMAP.md „Später“, alte SPEC §2.2) — verworfen 2026-10-20: kein Bedarf (Spiele-Modus auch gestrichen)
- **Screenshot hinter dem Lockscreen** – nur als Stichwort notiert (Quelle: docs/ROADMAP.md „Später“) — verworfen 2026-10-20: Sinn unklar
- **Kürzel über GlobalShortcut** – Super antippen und Super+Tab über Quickshell-`GlobalShortcut` statt `qs ipc`, falls der Prozessstart je Taste träge wirkt (Quelle: docs/knowledge/hyprland.md) — verworfen 2026-10-20: Tasten wirken nicht träge
- **Super+Return entprellen** – kleines Skript mit ≥ 0,5 s Sperre gegen Terminal-Fluten (AP 14); Vorschlag (Quelle: docs/ROADMAP-HYPRLAND.md) — verworfen 2026-10-20: nur einmal passiert (AP 14 geschlossen)
