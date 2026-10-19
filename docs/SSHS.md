# Server (Reiter im Dev-Popout)

Web-Konsolen der Hosting-Dienste und die Server aus `scripts/sshs` direkt aus der Bar: Konsole im Browser öffnen,
hochladen, Dateien ansehen, Terminal. Das Terminal-Werkzeug selbst (Server anlegen, Strg+Leertaste, Strg+Shift+U/D …)
steht in [THEMING.md → sshs](THEMING.md#sshs).

**Öffnen:** Dev-Chip (Symbol `dns`) → Reiter **Server**, oder **Super+Alt+U** bzw. Bar-Modus `H` (öffnet gleich den
Reiter). Früher ein eigener Server-Chip; Dev-Dienste und Server sind jetzt ein Popout ([DEVSERVICES.md](DEVSERVICES.md)).
Tastatur: ↑↓←→/Tab wählen, Enter löst aus, Esc schließt. Die Suche oben filtert auch diesen Reiter.

## Consoles

Feste Liste in `config/consoles.json` (einzige Stelle, live gelesen): **Dokploy** (admin), **Hetzner**, **INWX**,
**Cloudflare**. Klick öffnet die Adresse in Helium (wie die Ports im Dev-Popout). Bewusst keine Links pro Projekt.
Private Adressen gehören nicht ins (öffentliche) Repo, sondern nach `~/.config/desktop/consoles.json` – Einträge dort
ersetzen Felder mit gleicher `id`:

```json
{ "consoles": [ { "id": "dokploy", "url": "https://…" } ] }
```

Solange die Dokploy-URL fehlt, ist die Zeile ausgegraut („no URL yet“).

## SSH

| Knopf | Wirkung |
|---|---|
| Benutzer-Pille (`admin` ↔ `root`) | Klick schaltet um, gemerkt in `~/.local/state/desktop/sshs-root.json`. Als root hängen Files/Terminal `--su` an: sshs meldet sich als Anmelde-Benutzer an und tippt `su`, das Passwort gibst du ein (Root-Login per SSH bleibt aus). Files zeigt danach yazi direkt in der su-Shell. Upload aus der Bar geht weiter als Anmelde-Benutzer nach `~` |
| **Upload** | Datei-Wähler der Shell, mehrere Dateien/Ordner: **Tab** oder Klick markiert (auch über mehrere Ordner), Strg+A alle Dateien im Ordner, Enter lädt hoch. Ziel: Home-Ordner `~` auf dem Server. Fortschritt + Ergebnis als Benachrichtigung, solange es läuft, zeigt der Dev-Chip `cloud_upload` im Glut-Ton |
| **Files** | sshs-Kitty-Fenster, das nach der Anmeldung von selbst auf Dateien (yazi per SFTP) umschaltet |
| **Terminal** | sshs-Kitty-Fenster mit der Shell auf dem Server |
| Container (`deployed_code`) | klappt darunter die Container des Servers auf: `sshs ps <name> --json`, nach Projekt gruppiert (compose-/Stack-Projekt bzw. Name bis zum ersten `-`, z. B. shop, blog, dokploy …), Punkt = läuft, Image · Status, Ports (`:8080→80` nach außen, gerahmt = nur im Container; Swarm-Dienste mit den Ports des Dienstes). Neu laden mit ↻. Darf der Anmelde-Benutzer nicht an docker (und `sudo -n` geht nicht), steht das dort, dazu „As root in terminal“ (`--su --run docker ps …`) |
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
| `sshs <name> --su [--files \| --run <befehl>]` | dazu nach der Anmeldung `su` tippen, nach der su-Prompt Dateien bzw. Befehl; vertipptes Passwort = bleibt Terminal |
| `sshs ps <name> [--json]` | Container (docker/podman als Anmelde-Benutzer, docker notfalls `sudo -n`), gruppiert, mit Ports |
| `sshs fetch <name> <kennung>` · `_setup <name>` | intern: Download als root abholen · yazi im Hintergrund auf den Server kopieren |

## Dateien

- `config/consoles.json` – Web-Konsolen (Name, Adresse, Angabe rechts, Symbol)
- `shell/services/Servers.qml` – Konsolen, sshs-Liste, Aktionen, laufender Upload
- `shell/modules/bar/DevPopout.qml` – Reiter Server (KeyNav) · `DevChip.qml` – Chip + IPC `servers`
- `shell/services/BarKeys.qml` – `aliases`: `servers` öffnet das Dev-Popout auf dem Reiter Server
- `shell/services/FilePicker.qml` – neu `openFiles(start, filters, cb, { title, action })` (Mehrfachauswahl, Callback bekommt eine Liste)
- `config/sshs/sshs_watcher.py` – an jedem Terminal: `--files`/`--su`/`--run` nach der ersten Prompt (gibt nach 3 min auf), holt Downloads als root ab, lässt Uploads als root übernehmen
- `config/sshs/remote/bashrc` – su-Wrapper, User-Variablen `sshs_su`/`sshs_yazi`/`sshs_give`, `_sshs_y`/`_sshs_take`/`_sshs_give` · `config/sshs/remote/yazi/init.lua` – yazi in der su-Shell meldet seinen Ordner per OSC 7

## Testen

```sh
Q="qs ipc --any-display -p ~/Workspace/desktop-hyprland/shell call"
$Q servers open      # Dev-Popout, Reiter Server, ohne Klick-Fang; zu mit: $Q servers close
$Q servers status
$Q filepicker demo multi   # Mehrfachauswahl ansehen (Ergebnis nur als Benachrichtigung)
sshs list --json
```
