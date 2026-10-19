# Backlog – bastian-shell

Eingang für Ideen, damit nichts im Chat verloren geht. Eine Zeile pro Idee: **Titel** – worum es geht (Datum, Quelle).
**Keine Checkboxen** (Ideen sind keine Zusagen, werden nicht gezählt). Wird es ein ganzes Konzept: eigene Datei `BACKLOG-<THEMA>.md`
(Status Idee → VORSCHLAG → beschlossen → umgesetzt | verworfen) oder direkt als Punkt in [ROADMAP.md](ROADMAP.md).

## Ideen

- **Theme-Variante nach Tageszeit** – hearth abends heller/dunkler, passend zur Abendwärme; „bewusst nicht jetzt“ (Quelle: docs/knowledge/shell-features.md)
- **Login als Quickshell-Greeter** – greetd mit einem Quickshell-Greeter in einem kleinen Hyprland, Farben aus `palette.json` (`theme/gen/login.py`); nur geplant, nicht gebaut (Quelle: docs/setup/migrate.md)
- **Bootstrap ohne Plasma** – `system/packages/dnf.txt` und `system/bootstrap` auf greetd + Keep-Liste umstellen, statt Plasma neu zu holen; „eigene Runde“ (Quelle: docs/setup/migrate.md)
- **KWin-Code aus dem Repo** – `scripts/rice` (außer `theme`/`feeds`), `scripts/shellpkg`, `scripts/winrules`, `bridge/kwin/`, `plasma/` entfernen; „eigene Runde“ (Quelle: docs/setup/migrate.md)
- **Stalwart als zweites Mail-Konto** – weiterer Eintrag in `accounts` nach Vorlage `_stalwart_example` (Quelle: docs/setup/mail-calendar.md)
- **Mail-Schnellaktionen in der Shell** – „Als gelesen“/„Archivieren“ per eigenem IMAP-Aufruf neben „Öffnen“; „später evtl.“ (Quelle: docs/DECISIONS.md)
- **Tagesziel aus einer eigenen App** – Dashboard zeigt ein Tagesziel über die API einer eigenen App (welche, ist offen) (Quelle: docs/ROADMAP.md „Später“, alte SPEC §2.2)
- **Uptime Kuma** – eigene Status-Seiten im Dashboard über `/api/status-page/heartbeat/<slug>` (Quelle: docs/ROADMAP.md „Später“, alte SPEC §2.2)
- **Backup-Status** – letzter Lauf im Dashboard; braucht erst ein Backup (z. B. btrbk/snapper auf btrfs) (Quelle: docs/ROADMAP.md „Später“, alte SPEC §2.2)
- **Steam-Playtime** – Spielzeit dieser Woche aus Steam lokal (`localconfig.vdf`) (Quelle: docs/ROADMAP.md „Später“, alte SPEC §2.2)
- **Screenshot hinter dem Lockscreen** – nur als Stichwort notiert (Quelle: docs/ROADMAP.md „Später“)
- **Leise, warme Systemklänge** – eigener sanfter Benachrichtigungston („weicher Holz-Klick“) statt Standard; optional (Quelle: docs/knowledge/theming.md, design/brief.md)
- **Kürzel über GlobalShortcut** – Super antippen und Super+Tab über Quickshell-`GlobalShortcut` statt `qs ipc`, falls der Prozessstart je Taste träge wirkt (Quelle: docs/knowledge/hyprland.md)
- **Super+Return entprellen** – kleines Skript mit ≥ 0,5 s Sperre gegen Terminal-Fluten (AP 14); Vorschlag (Quelle: docs/ROADMAP-HYPRLAND.md)
- **Kamera-Status ereignisgesteuert** – `Camera.qml` fragt `scripts/camera status` alle 5 s ab; könnte über `scripts/privacy-cam` (inotify auf `/dev/video`) laufen (Quelle: docs/ROADMAP-HYPRLAND.md)
- **Abendwärme-Schalter in der Shell** – Anzeige/Schalter für die Abendwärme (z. B. im Licht-Popout) statt nur `scripts/nightlight` + Super+Alt+N; bisher bewusst nicht gebaut (2026-10-18, Quelle: docs/knowledge/shell-features.md)

## In Ausarbeitung

## Übernommen

## Verworfen
<!-- mit Grund, damit sie nicht wiederkommt -->
