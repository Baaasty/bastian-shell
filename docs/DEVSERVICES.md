# Dev-Dienste (Bar-Popout)

Zeigt pro Projekt, was gerade lokal läuft: **Dev-Server** (lauschende Ports eigener Prozesse), **Container**
(podman, echtes docker falls vorhanden) und belegte Ports. Starten, stoppen, im Browser öffnen.

## Bedienung

- **Chip** in der Bar (rechts, Symbol `dns`) – immer da (auch der Reiter Server lebt hier), die **Zahl nur, wenn etwas
  läuft**. Zahl = Dev-Prozesse (einer je PID) + laufende Container (ohne Hintergrund-Container, s. u.). Läuft ein
  sshs-Upload, steht `cloud_upload` im Glut-Ton. Klick öffnet das Popout, immer auf **Services** (merkt sich den
  letzten Reiter nicht; nur Super+Alt+U, Bar-Modus `H` und `servers open` gehen direkt auf **Server**).
- **Services**: eine Karte pro Projekt (Farbpunkt aus `projects.json`), darin Dev-Server und Container des Projekts.
  Unbekanntes unter **Other**. Darunter **Not running**: Projekte mit `dev.command`, in denen nichts läuft → **Start**.
- **Containers**: alle Container (außer Distrobox/Toolbox), mit Start / Restart / Stop.
- **Ports**: alle eigenen lauschenden Ports, auch Apps (Discord, VS Code …) und Container-Weiterleitungen. `LAN` = nicht nur auf localhost.
- **Server** (früher eigener Server-Chip): Web-Konsolen (Dokploy, Hetzner, INWX, Cloudflare) und die sshs-Server mit
  Upload / Files / Terminal – Details in [SSHS.md](SSHS.md). Direkt: **Super+Alt+U** bzw. Bar-Modus `H`.
- Zeile anklicken / `open_in_new` = `http://localhost:<port>` in Helium. **Stop** fragt immer erst in der Zeile nach.
- Suche (oben rechts) filtert nach Projekt, Port, Prozess, Befehl, Container, Image; im Reiter Server nach Konsole, Adresse, Server, Host.
  Esc: Rückfrage weg → Suche leeren → schließen.
- IPC: `qs ipc -p ~/Workspace/desktop-hyprland/shell call devservices toggle|open|close|refresh|status`,
  Reiter Server: `… call servers open|close|toggle|refresh|status`

## Zuordnung zum Projekt

1. Arbeitsordner des Prozesses (`/proc/<pid>/cwd`) bzw. compose-Ordner des Containers liegt in `paths` eines Projekts (längster Treffer).
2. Sonst ein Port, der **genau einem** Projekt gehört (`dev.ports`/`dev.infra`). Geteilte Altports (3000, 5432 …) zählen nicht – dafür gibt es Port-Blöcke (`projects/README.md`).
3. Sonst **Other** – aber nur, wenn es nach Dev-Server aussieht (node, bun, python, vite, next-server … oder Ordner unter `~/Workspace`).
   Bekannte Apps (VS Code, Discord, Spotify, Helium …) stehen nur unter **Ports**.

Hintergrund-Container = von systemd/Quadlet verwaltet, ohne compose und ohne Projekt (z. B. `systemd-anisette`):
nur im Reiter Containers, zählen nicht im Chip.

## Starten und Stoppen

- **Start** führt `dev.services && dev.command` im Haupt-Repo (`paths[0]`) als eigene User-Unit aus:
  `devserver-<projekt>.service` (über `systemd-run --user`, überlebt Shell-Neustarts, `bash -lc`).
  Log: Knopf **Logs** bzw. `journalctl --user -fu devserver-<projekt>`. Ist der erste App-Port schon belegt, startet nichts.
- **Stop** (SIGTERM):
  - eigene Unit `devserver-*` → `systemctl --user stop` (ganzer Baum, auch `services`),
  - sonst die **Prozessgruppe** (z. B. `bun run dev` im VS-Code-Terminal: bun + next + Kinder), wenn sicher:
    nicht die Sitzung/Shell selbst, alle Prozesse eigene, Gruppenführer keine Shell/VS Code/Hyprland, ≤ 64 Prozesse,
  - sonst nur der Prozess. Die Rückfrage zeigt, was genau passiert. PID + Startzeit werden geprüft (keine PID-Wiederverwendung).
- **Container**: `podman|docker start|stop|restart <id>`. Bei systemd-verwalteten Containern warnt die Rückfrage (systemd startet sie evtl. neu).

## Prüfintervall

Alle **5 s**, solange das Popout offen ist, sonst alle **30 s** (nur für die Zahl im Chip); im Vollbild/Spiel gar nicht.
Eine Messung (`ss -ltnpH` + `podman ps -a`) dauert ~0,1 s.

## Technik

`scripts/devservices` (Python, nur Standardbibliothek; `scan` | `show` | `stop <pid>:<st>` | `start <projekt>` |
`container <engine> start|stop|restart <id>`) · `shell/services/DevServices.qml` (Daten, Aktionen) ·
`shell/modules/bar/DevChip.qml` (Chip + IPC) · `shell/modules/bar/DevPopout.qml` (Popout) · Einbau in `BarWindow.qml` ·
Reiter Server: `shell/services/Servers.qml` + `config/consoles.json`.
Liest `projects/projects.json` nur (Ändern: `scripts/project set <projekt> dev.command …` bzw. `dev.ports …`).
Zum Ausprobieren ohne Shell: `scripts/devservices show`.
