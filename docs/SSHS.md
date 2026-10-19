# Server-Chip (sshs in der Bar)

Server aus `scripts/sshs` direkt aus der Bar: hochladen, Dateien ansehen, Terminal. Das Terminal-Werkzeug selbst
(Server anlegen, Strg+Leertaste, Strg+Shift+U/D …) steht in [THEMING.md → sshs](THEMING.md#sshs).

**Öffnen:** Server-Chip (Symbol `dns`, rechts neben Downloads) oder **Super+Alt+U** – dann mit Tastatur:
↑↓←→/Tab wählen, Enter löst aus, Esc schließt.

| Knopf | Wirkung |
|---|---|
| **Upload** | Datei-Wähler der Shell, mehrere Dateien/Ordner: **Tab** oder Klick markiert (auch über mehrere Ordner), Strg+A alle Dateien im Ordner, Enter lädt hoch. Ziel: Home-Ordner `~` auf dem Server. Fortschritt + Ergebnis als Benachrichtigung, solange es läuft, zeigt der Chip `cloud_upload` im Glut-Ton |
| **Files** | sshs-Kitty-Fenster, das nach der Anmeldung von selbst auf Dateien (yazi per SFTP) umschaltet |
| **Terminal** | sshs-Kitty-Fenster mit der Shell auf dem Server |
| New server | `sshs add` in einem Kitty-Fenster |

- Der zuletzt benutzte Server steht oben (Upload-Knopf im Glut-Ton). sshs merkt sich das selbst in
  `~/.local/state/sshs/recent.json` – auch Verbindungen aus dem Terminal zählen.
- Upload fragt nie nach: Liegt der Schlüssel nicht im SSH-Agenten (und hat eine Passphrase), meldet die Benachrichtigung
  „Login failed“ → einmal per **Terminal** verbinden (legt den Schlüssel in den Agenten), dann nochmal.
- Upload läuft in einer eigenen systemd-Scope (übersteht Shell-Neustarts). Nur ein Upload gleichzeitig.

## Neu in scripts/sshs (für die Shell, Verhalten im Terminal unverändert)

| Befehl | Wirkung |
|---|---|
| `sshs list --json` | Server als JSON (`name, host, user, port, last`), zuletzt benutzte zuerst; liest nur `ssh -G`, verbindet nicht |
| `sshs put <name> <ziel> <dateien…> [--notify]` | nicht-interaktiv hochladen (`scp -r -p`, `BatchMode=yes`); `--notify` = Benachrichtigung „Uploading …“ → „Uploaded …“ / Fehler |
| `sshs <name> --files` | verbinden, nach der Anmeldung auf Dateien umschalten (Kitty-Watcher `config/sshs/sshs_watcher.py`) |

## Dateien

- `shell/services/Servers.qml` – Liste, Aktionen, laufender Upload
- `shell/modules/bar/ServerChip.qml`, `ServerPopout.qml` – Chip + Popout (KeyNav)
- `shell/services/FilePicker.qml` – neu `openFiles(start, filters, cb, { title, action })` (Mehrfachauswahl, Callback bekommt eine Liste)
- `config/sshs/sshs_watcher.py` – schaltet bei `--files` nach der ersten Prompt einmal um (gibt nach 3 min auf)

## Testen

```sh
Q="qs ipc --any-display -p ~/Workspace/desktop-hyprland/shell call"
$Q servers open      # ohne Klick-Fang, zu mit: $Q servers close
$Q servers status
$Q filepicker demo multi   # Mehrfachauswahl ansehen (Ergebnis nur als Benachrichtigung)
sshs list --json
```
