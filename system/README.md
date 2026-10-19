# system/ – den PC neu aufsetzen

Alles, um ein frisches Fedora 44 zu diesem Rechner zu machen: **Hyprland 0.56 + Quickshell** („desktop“),
Plasma bleibt installiert und ist die Rückfall-Sitzung. Stand 2026-10-18 (AP 15 vorbereitet).

## Was wo ist

| Datei | Inhalt |
|---|---|
| `packages/repos.txt` | Zusatz-Repos: RPM Fusion, COPR Quickshell, COPR Hyprland, COPR Helium, VS Code (+ Befehle) |
| `packages/dnf.txt` | Pakete nach Gruppen: `paket` installieren · `-paket` entfernen · `?paket` optional (`--optional`) · `%paket` nur KWin (`--kwin`) |
| `packages/flatpak.txt` | Flatpaks (System/User), Bundles, Overrides |
| `packages/vscode-extensions.txt` | VS Code-Erweiterungen |
| `packages/other.txt` | Rest: `~/.local/bin`, Fremd-Builds (`~/.local/src`), distrobox (Claude Desktop), Podman, Schriften, systemd-Units, `/etc`-Änderungen |
| `dotfiles/` | **verlinkt** nach `~`: `.gitconfig`, `.bashrc.d/desktop.sh`, `.ssh/config` (ohne Keys), iCloud-/GoXLR-Units, Anisette-Quadlet, rclone-Filter, `~/.local/bin/{keylight,icloud-sync,icloud-login}` |
| `copies/` + `copies.txt` | **kopiert** nach `~` (Apps schreiben die Dateien selbst um): VS Code-Settings/Keybindings, `~/.claude/settings.json`, `mimeapps.list`, Autostart, Monitor-Anordnung (KWin), GoXLR-Profile |
| `sync` | Kopien abgleichen: `pull` PC → Repo, `push` Repo → PC (siehe unten) |
| `dotfiles.md` | welche Configs wichtig sind und warum Link oder Kopie |
| `bootstrap` | das Installationsskript |

## Neu aufsetzen

1. Fedora 44 **KDE** installieren (Workstation geht auch: bootstrap holt dann die KDE-Gruppe und stellt die Anmeldung
   auf Plasma Login um), eigener Benutzer, Netzwerk.
2. Repo holen: `git clone https://github.com/Baaasty/bastian-shell ~/Workspace/bastian-shell`
   (eigener Fork: `gh repo clone <github-user>/bastian-shell ~/Workspace/bastian-shell`)
3. Schauen, was passieren würde: `~/Workspace/bastian-shell/system/bootstrap`
4. Ausführen: `~/Workspace/bastian-shell/system/bootstrap --apply` (fragt einmal nach dem sudo-Passwort)
5. Neustart (NVIDIA + MOK, siehe unten), im Login **„Hyprland (uwsm-managed)“** wählen
6. Nochmal: `system/bootstrap --apply --only 9,10` (Theme an braucht die laufende Sitzung)
7. Die manuellen Schritte unten abarbeiten (auch `system/bootstrap --only 11`)
8. Kontrolle: `system/bootstrap` ohne `--apply` → sollte nur noch `ok` und `..` zeigen

Einzelne Schritte: `system/bootstrap --list`, dann z. B. `--only 4,5`.

### Schritte und Schalter

| # | Schritt | sudo |
|---|---|---|
| 1 | Paketquellen: RPM Fusion, COPR `errornointernet/quickshell`, `sdegler/hyprland`, `imput/helium`, VS Code | **ja** |
| 2 | dnf-Pakete aus `dnf.txt` (ein `dnf install`), ffmpeg-Swap, KDE-Gruppe (nur Workstation), KDE-Apps entfernen, GoXLR-RPM, Spotify per `lpf` | **ja** |
| 3 | System: Gruppe kvm, vhost_vsock, nodocker, Anmeldung Plasma Login, Firewall rdp (nur mit krdp), podman.socket | **ja** |
| 4 | Flatpaks + Overrides (System-Flatpaks fragen per polkit) | polkit |
| 5 | VS Code-Erweiterungen | – |
| 6 | User-Tools: Bun, Claude CLI, Starship, Godot, pnpm, Schriften, icp · Hyprland: `scripts/session build` (hyprflow), `scripts/share-picker build`, Equicord klonen + `scripts/equicord build` | – |
| 7 | distrobox `ubuntu` + Claude Desktop (sudo nur **im** Container) | – |
| 8 | Dotfiles: `system/dotfiles` verlinken, `system/copies` kopieren | – |
| 9 | Gemeinsam für beide Sitzungen: `theme/gen/all.py`, `rice theme on`, `scripts/kitty-theme install`, Wallpaper-Bilder, `scripts/claude-skills install`, Helium-Host (`scripts/chrome-ext install --browser helium`), User-Dienste (Key Light/GoXLR, `rice feeds` wenn `secrets.json` da) | – |
| 10 | Sitzung: `scripts/hypr install` (Konfig + Shell-Dienst `desktop-shell-hyprland`), `scripts/session install` (Session-Restore), `scripts/share-picker install` · mit `--kwin` zusätzlich Shell-Paket, `rice on`, `wallpaper set` | – |
| 11 | Hinweise: was von Hand bleibt | – |

Befehle mit sudo stehen in der Ausgabe mit **`[sudo]`**; die Schlusszeile zählt sie. Ohne `--apply` wird nichts ausgeführt.

- **Standard = Hyprland.** Plasma bleibt installiert und unverändert (Rückfall-Sitzung im Login), der KWin-Rice
  (Shell-Paket, `rice on`, KWin-Kürzel/-Skripte, `%`-Pakete wie krdp) kommt nur mit **`--kwin`** dazu.
- `--no-hyprland` lässt die Hyprland-Builds (6) und die Hyprland-Sitzung (10) weg – z. B. `--kwin --no-hyprland` für den alten KWin-Stand.
- `--optional` installiert auch die `?`-Pakete (sonst nur ein Hinweis).
- **Nie überschrieben:** Kopien, deren PC-Fassung neuer ist als das Repo (Hinweis: `system/sync pull` oder `push --apply`),
  fremde Dateien (werden vorher als `.vor-desktop` bzw. nach `~/.local/state/desktop/` gesichert).
- Equibop wird nicht mehr installiert (Chat = Discord-RPM + eigener Equicord-Build, Roadmap 18.10.).

### Pfade

Das Repo liegt in **`~/Workspace/bastian-shell`** (Branch `main`). Alle Repo-Pfade stehen oben in `bootstrap` im Block
**„Pfade“**: `WORKSPACE`, `REPO_NAME`, `REPO_BRANCH`, `CHECKOUTS`. Skripte und Shell ermitteln den Ort selbst
(Skriptverzeichnis, `Quickshell.shellDir`); für systemd-Units und Hyprland steht er an **einer** Stelle:
`DESKTOP=` in `~/.config/desktop/hyprland.env` (schreibt `scripts/hypr install`, Rückfall `~/Workspace/bastian-shell`).
Links, die schon in einen der `CHECKOUTS` zeigen, gelten als `ok` und werden nicht umgebogen. Umbiegen = den jeweiligen
Installer aus dem gewünschten Checkout aufrufen (`scripts/hypr install`, `scripts/session install`, `scripts/claude-skills install` …).
Umzug aus den alten Ordnern (`desktop` + `desktop-hyprland` in `~/Workspace`): **`system/migrate`** ([docs/MIGRATE.md](../docs/MIGRATE.md)).

## Dotfiles: Links, Kopien, Sync

Zwei Wege, je nachdem, wer die Datei schreibt:

- **Link** (`system/dotfiles/<pfad>` → `~/<pfad>`): Dateien, die nur du bearbeitest. Änderung = sofort im Repo.
- **Kopie** (`system/copies/<pfad>`, Liste `copies.txt`): Dateien, die Apps selbst neu schreiben (VS Code, Claude,
  KDE, GoXLR). Ein Link würde dabei durch eine Datei ersetzt – darum Kopie + `system/sync`.

```sh
system/sync               # Übersicht: welche Kopien weichen ab, welche Links fehlen noch
system/sync pull -n       # zeigen, was vom PC ins Repo käme (Diff)
system/sync pull          # PC → Repo holen + Diff (rückgängig: git checkout -- system/copies)
system/sync push          # zeigen, was Repo → PC schreiben würde
system/sync push --apply  # schreiben, alte PC-Datei vorher als <datei>.vor-desktop
system/sync pull Code     # nur Pfade mit „Code“
```

`pull` übernimmt keine Textdatei, in der etwas wie Token/Passwort/Key steht (zeigt nur die Zeilennummer).
Faustregel: nach Änderungen in VS Code/Claude/GoXLR/Monitoren ab und zu `system/sync pull` + committen.

### Auf DIESEM PC umstellen (noch nicht gemacht – du entscheidest, wann)

Heute sind alle Dateien noch normale Dateien (Stand = Repo, `system/sync` zeigt es). Umstellen auf Links:

1. `system/sync` → alles `ok` / „gleich“? Sonst erst `system/sync pull` bzw. Unterschied prüfen.
2. `system/bootstrap --only 8` (zeigt nur) → `system/bootstrap --apply --only 8`
   (Links, die schon in `~/Workspace/bastian-shell` zeigen, bleiben, siehe „Pfade“)
   - ersetzt `~/.gitconfig`, `~/.ssh/config`, Units, Skripte … durch Links; Original als `<datei>.vor-desktop`
     (Skripte aus `~/.local/bin` nach `~/.local/state/desktop/dotfiles-backup/`, damit sie nicht im PATH liegen)
   - legt `~/.bashrc.d/desktop.sh` an und nimmt die `DOCKER_HOST`-Zeile aus `~/.bashrc` (Backup `~/.bashrc.vor-desktop`).
     Den Starship-Block in `~/.bashrc` verwaltet weiter `scripts/rice theme on|off`.
3. Prüfen: neues Terminal (`echo $DOCKER_HOST`), `git config user.name`, `ssh -T git@github.com`,
   `systemctl --user status goxlr icloud-sync.timer`, `/usr/libexec/podman/quadlet -dryrun -user | grep anisette`
4. chezmoi stilllegen: `rm -rf ~/.local/share/chezmoi ~/.config/chezmoi` (sonst überschreibt ein `chezmoi apply`
   die Links) und das alte Repo archivieren: `gh repo archive <github-user>/dotfiles`
5. Zurück: Link löschen, `<datei>.vor-desktop` zurückbenennen.

## Nach dem Neuaufsetzen neu anlegen (Checkliste)

Secrets werden **nicht** gesichert – alles hier wird neu erzeugt bzw. neu angemeldet.
Steht gekürzt auch am Ende von `bootstrap` (Schritt 11).

- [ ] **Secure Boot + NVIDIA:** `sudo kmodgenca -a && sudo mokutil --import /etc/pki/akmods/certs/public_key.der` → Neustart, „Enroll MOK“
- [ ] **~/Data:** verschlüsselte zweite Platte in `/etc/crypttab` + `/etc/fstab`
- [ ] **SSH-Keys** (die Namen erwartet `~/.ssh/config`; die eigene Fassung `system/dotfiles/.ssh/config` ist lokal,
      Vorlage `config.example`): z. B. `ssh-keygen -t ed25519 -f ~/.ssh/id_ed25519_personal` (privat, GitHub) und
      `ssh-keygen -t ed25519 -f ~/.ssh/id_ed25519_work` (Firma) → die `.pub` bei GitHub
      (github.com/settings/keys) bzw. auf den eigenen Servern eintragen (`ssh-copy-id -i …`)
- [ ] **GitHub CLI:** `gh auth login` → `gh config set git_protocol ssh` · Test: `ssh -T git@github.com`
- [ ] **Claude:** `claude` (Login) · Claude Desktop starten (Login). Autostart kommt aus `system/copies` –
      in Claude Desktop „Beim Anmelden starten“ **nicht** umschalten (schreibt sonst den Container-Pfad zurück)
- [ ] **secrets.json:** `cp secrets.example.json secrets.json && chmod 600 secrets.json`, Felder:
  - `hue`: `key`, `clientkey`, `bridge`, `bridgeId` → `scripts/hue-pair` ([hue.md](../docs/setup/hue.md))
  - `keylight`: `host` (mDNS-Name), `ip` (Fallback) – Elgato Key Light
  - `spotify`: `client_id` → `scripts/spotify-auth` ([spotify.md](../docs/setup/spotify.md))
  - `discord`: `client_id`, `client_secret` → in Discord autorisieren ([discord.md](../docs/setup/discord.md))
  - `statsfm`: `user`
  - `accounts[]`: `name`, `label`, `user`, `password` (App-Passwort), `mail.{host,port,folder,notify}`,
    `codes.{autoCopy,trashAfterMin}`, `caldav.{url,calendars[]}` ([mail-calendar.md](../docs/setup/mail-calendar.md))
  - `magicLinks.autoOpen`
  - danach `scripts/rice feeds`
- [ ] **Thunderbird-Konten:** [mail-calendar.md](../docs/setup/mail-calendar.md)
- [ ] **iCloud:** `rclone config` (Remotes `icloud` + `icloud-photos`, Typ iclouddrive) → `icloud-login`
      → `systemctl --user enable --now icloud-photos.service icloud-sync.timer`
- [ ] **icp:** Login mit Apple-ID (Anisette läuft auf 127.0.0.1:6969), Browser-Erweiterung (Helium) aus `~/Apps/icp/extension`
- [ ] Wake-on-LAN: `nmcli connection modify "<Kabel>" 802-3-ethernet.wake-on-lan magic`
- [ ] **Helium:** Erweiterung + Theme „Desktop“ laden (`helium://extensions`, Entwicklermodus, Ordner aus `theme/out/`)
- [ ] **VS Code:** Theme „Desktop“ wählen, Settings Sync anmelden
- [ ] **Discord:** einmal starten, anmelden, beenden → `scripts/equicord inject` (eigener Equicord-Build, Plugin desktopBridge, [DISCORD-CAMS.md](../docs/DISCORD-CAMS.md))
- [ ] **Spotify/Steam:** in spotify-client anmelden · Steam-Bibliothek `~/Data/Games/SteamLibrary` hinzufügen
- [ ] **Login-Bildschirm:** `scripts/loginscreen install && scripts/loginscreen on` (sudo, mit Backup)
- [ ] **Share-Picker aktiv:** `systemctl --user restart xdg-desktop-portal-hyprland xdg-desktop-portal` (nur ohne laufenden Stream)
- [ ] **…craft-Flatpaks:** aus den `.flatpak`-Dateien
- [ ] **Projekte:** eigene Repos nach `~/Workspace` per `gh` klonen (Liste: `projects/projects.json`, lokal), `.env` aus `.env.example` · danach `scripts/vscode-colors refresh`

Übersicht aller Logins: [docs/setup/README.md](../docs/setup/README.md).

## Hinweise

- Das alte chezmoi-Repo (`<github-user>/dotfiles`) ist hier zusammengeführt und auf GitHub archiviert (2026-10-18).
- `keylight` gibt es nur einmal: `scripts/keylight` (an/aus/toggle/hell/warm/status, feste IP zuerst – läuft auch
  beim Herunterfahren). `system/dotfiles/.local/bin/keylight` ist ein Link darauf.
