# Dotfiles – was wichtig ist und wohin es gehört

Stand 2026-10-18. **Umgesetzt:** `system/dotfiles/` (Links) + `system/copies/` (Kopien, Liste `copies.txt`) +
`system/sync`. **Auf diesem PC ist noch nichts verlinkt** – Umstellen: `system/README.md` → „Auf DIESEM PC umstellen“.

Spalte „Klasse“:

- **a** = wird schon vom Repo erzeugt/gesetzt (nichts tun, `bootstrap` ruft die Generatoren auf)
- **L** = liegt in `system/dotfiles/<pfad ab ~>`, wird **verlinkt**
- **K** = liegt in `system/copies/<pfad ab ~>`, wird **kopiert** + mit `system/sync` abgeglichen
- `<datei>.example` (in `dotfiles/` oder `copies/`) = Vorlage für eine Datei, die nur lokal liegt (gitignored); wird nie verlinkt
- **c** = Secret → nie ins Repo, **kein Backup**: neu anlegen (Checkliste in `system/README.md`)
- **–** = egal / Cache / entsteht von selbst

> Das alte **chezmoi-Repo** (`github.com/<github-user>/dotfiles`) ist hier zusammengeführt (2026-10-18): alle Dateien
> waren auf dem PC gleich oder neuer (`.bashrc` + DOCKER_HOST/Starship, `.gitconfig` + LFS-Filter) → PC-Stand
> übernommen. Sein `run_onchange_install-packages.sh` steckt komplett in `packages/`. Die `symlink_*`-Einträge
> (`default.target.wants/…`) entstehen per `systemctl --user enable`. Archivieren: `gh repo archive <github-user>/dotfiles`.

## Übersicht

| Datei | Klasse | Bemerkung |
|---|---|---|
| `~/.bashrc` | L (Teil) | `DOCKER_HOST` → `~/.bashrc.d/desktop.sh` (Fedora-`.bashrc` lädt `~/.bashrc.d/*`). Starship-Block bleibt in `.bashrc`, den setzt `rice theme on/off`. `.bashrc` selbst = Fedora-Standard |
| `~/.bash_profile` | – | Fedora-Standard |
| `~/.gitconfig` | L | Name, Mail, `defaultBranch=main`, LFS-Filter. Keine Secrets. Eigene Fassung lokal (gitignored), im Repo nur `.gitconfig.example` |
| `~/.ssh/config` | L | Host-Einträge mit Key-Namen; ganz oben `Include config.d/sshs.conf` (Server von `sshs add`, lokal). Eigene Fassung lokal (gitignored), im Repo nur `config.example`. **Keys selbst = c** |
| `~/.config/starship.toml` | a | gibt es nicht – `STARSHIP_CONFIG` zeigt auf `theme/out/starship.toml` |
| `~/.config/Code/User/settings.json` | K | ~4,6 KB, keine Tokens gefunden. Eigene Kopie lokal (gitignored, Firmen-URLs), im Repo `settings.json.example` – bootstrap nimmt die Vorlage nur, wenn beides fehlt. Achtung: Projektfarben schreibt `scripts/vscode-colors` in die **Workspace**-Settings, nicht hierher |
| `~/.config/Code/User/keybindings.json` | K | |
| `~/.config/Code/User/snippets/` | – | nur die leere `cpp.json`-Vorlage – bei echten Snippets in `copies.txt` aufnehmen |
| `~/.config/Code/User/profiles/`, `sync/` | – | Settings Sync ist offenbar an → kommt per Anmeldung zurück |
| VS Code-Theme „Desktop“ + Projekt-Erweiterung | a | `theme/gen/all.py` → `~/.vscode/extensions/desktop.*` |
| `~/.claude/settings.json` | K | nur `model`, `theme`, `env`, Hooks → alle auf `~/Workspace/bastian-shell/scripts/claude-{status,gate}`. Keine Secrets. Gate-Hooks setzt `scripts/claude-gate-hooks on`, die claude-status-Hooks stehen nur hier. Eigene Kopie lokal (gitignored), im Repo `settings.json.example` (Pfade über `$HOME`) |
| `~/.claude/skills/desktop-project` | a | Symlink per `scripts/claude-skills install` |
| `~/.claude/skills/new-project`, `project` | – | Symlinks aus dem privaten Skill-Repo (dessen `./install install`) |
| `~/.claude/skills/security-audit`, `synced/` | – | kommen von Claude selbst |
| `~/.claude.json` | c | Konto/OAuth, Projekt-Verlauf – nicht ins Repo, `claude` neu anmelden |
| `~/.config/kdeglobals` | a | Farbschema per `rice theme on` (`plasma-apply-colorscheme Desktop`) |
| `~/.config/kwinrc` | a + b (Ausschnitt) | Effekte/Plugins/ScreenEdges/TabBox/Deko/ModifierOnly setzt `scripts/rice on`. Rest (`[NightColor]`, `[Desktops]`, `[Xwayland]`, `[Wayland]`) → als `kwriteconfig6`-Liste ins Repo, nicht die Datei (voll mit Tiling-UUIDs) |
| `~/.config/kglobalshortcutsrc` | a | `scripts/rice on` setzt eigene + räumt fremde Kürzel (FOREIGN-Liste) |
| `~/.config/kwinrulesrc` | a | `scripts/winrules on` |
| `~/.config/kwinoutputconfig.json` | K | Monitor-Anordnung (3 Monitore, 360 Hz). KWin erkennt die Monitore per EDID; greift nach Ab-/Anmelden. Nur lokal (gitignored, enthält Monitor-Seriennummern), `system/sync pull` holt sie |
| `~/.config/kcminputrc` | a | Cursor per `rice theme on` |
| `~/.config/plasmarc`, `plasmashellrc`, `plasma-org.kde.plasma.desktop-appletsrc` | a | `rice on` (OSD aus, Panel weg) + `scripts/shellpkg` |
| `~/.config/kscreenlockerrc` | a | Lockscreen-Wallpaper per `scripts/wallpaper set` |
| `~/.config/konsolerc`, `~/.local/share/konsole/` | a | `theme/gen/konsole.py` + `scripts/konsole-ui on` |
| `~/.config/hypr/{hyprland,hypridle}.conf`, `~/.config/uwsm/env-hyprland`, `~/.config/xdg-desktop-portal/hyprland-portals.conf`, `~/.config/desktop/hyprland.env`, `~/.config/systemd/user/desktop-shell-hyprland.service` (+ Drop-in `desktop-shell.service.d/not-on-hyprland.conf`) | a | `scripts/hypr install` (bootstrap 10) – nur Einstieg/Links, alles Echte steht in `hypr/` |
| `~/.config/hypr/xdph.conf`, `~/.config/hyprland-preview-share-picker/` | a | `scripts/share-picker install` (bootstrap 10, erst nach `share-picker build`) |
| `~/.config/hyprflow/config.toml`, `desktop-session-save.{service,timer}` | a | `scripts/session install` (bootstrap 10). Gesicherte Sitzungen `~/.local/share/hyprflow/sessions/` = – (entstehen neu) |
| `~/.config/kitty/{kitty,theme}.conf` | a | Links per `scripts/kitty-theme install` (bootstrap 9) |
| `~/.config/desktop/{audio,goxlr,notes}.json`, `polkit-agent`, `workspaces/` | – / a | kleine Shell-Schalter, entstehen bei Bedarf neu; `workspaces/` macht `scripts/vscode-colors` |
| `~/.config/Equicord/settings/`, `~/.config/discord/app-*/resources/app/` | a + c | `scripts/equicord build` + `inject` (Plugin-Schalter, Einspielen); Discord-Login = c |
| `~/.config/dolphinrc`, `spectaclerc`, `kded6rc`, `baloofilerc` | b? | klein, persönliche Vorlieben – nur, wenn du dort was eingestellt hast |
| `~/.config/mimeapps.list` | K | Standard-Apps. `claude://` zeigt auf `com.anthropic.Claude.desktop`, die es auf dem Host nicht gibt (nur `ubuntu-com.anthropic.Claude.desktop`) |
| `~/.config/user-dirs.dirs` | – | Standard |
| `~/.config/autostart/*.desktop` | K | `claude-desktop.desktop` repariert (2026-10-18): `distrobox-enter -n ubuntu -- claude-desktop --startup`. Claude Desktop schreibt die Datei neu, wenn man dort „Beim Anmelden starten“ umschaltet → dann `system/sync push --apply` |
| `~/.config/systemd/user/goxlr.service`, `icloud-photos.service`, `icloud-sync.{service,timer}` | L | |
| `~/.config/containers/systemd/anisette.container` | L | Quadlet für icp |
| `~/.config/rclone/icloud-filter.txt` | L | |
| `~/.config/rclone/rclone.conf` | **c** | iCloud-Tokens! Neu: `rclone config` (Remotes `icloud`, `icloud-photos`), danach `icloud-login` |
| `~/.local/bin/keylight`, `icloud-sync`, `icloud-login` | L | `keylight` = Link auf `scripts/keylight` (eine CLI für alles, auch den Shutdown-Dienst) |
| `~/.local/share/fonts/huette/` | – | alter Ordnername (bootstrap lädt neu nach `…/fonts/desktop/`), nicht ins Repo (54 MB, fremde Lizenzen) |
| `~/.local/share/goxlr-utility/profiles/`, `mic-profiles/` | K | GoXLR-Profile + Mic-Profile (~130 KB). Rest (Logs, Presets, Icons) entsteht von selbst |
| `~/.config/goxlr-utility/` | – | Daemon-Einstellungen, klein |
| Thunderbird-Profil `~/.thunderbird/` (RPM; früher Flatpak `~/.var/app/org.mozilla.thunderbird_esr/.thunderbird/`, Umzug: `scripts/flatpak-to-native`) | a (Theme) + c (Rest) | Theme-XPI, `chrome/`, `user.js`-Block macht `theme/gen/thunderbird.py`. Konten/Passwörter (`logins.json`, `key4.db`) = c → Konten neu nach `docs/setup/mail-calendar.md` |
| Helium-Profil `~/.config/net.imput.helium/` | c | Theme/Erweiterung „Desktop“ = a (`scripts/chrome-ext install --browser helium`, dann in Helium laden). Altes Chrome-Profil `~/.config/google-chrome/` (Chrome entfernt) liegt nur noch als Archiv |
| `~/.config/Claude/` (13 GB) | c | Claude Desktop – neu anmelden. **13 GB** = vermutlich VM-Image, lohnt Blick |
| `~/.config/gh/hosts.yml` | c | `gh auth login` |
| `~/.ssh/id_*` | c | SSH-Keys |
| `~/.local/share/kwalletd/` | c | KDE-Wallet |
| `~/.gnupg/` | c | (fast leer) |
| `~/Workspace/bastian-shell/secrets.json` | c | Hue, statsfm, Mail-Konten, Stalwart … Vorlage: `secrets.example.json` |
| `.env`, `.env.local` in Projekten | c | aus `.env.example` neu |
| icp-Speicher, Anisette-Volume `anisette-data` | c | `icp` neu anmelden (Apple-ID + 2FA) |

## Secrets

Nie ins Repo, nie loggen, **kein Backup** (Entscheidung 2026-10-18): alles wird nach dem Neuaufsetzen neu
angelegt bzw. neu angemeldet – Checkliste „Nach dem Neuaufsetzen neu anlegen“ in `system/README.md`.
`system/sync pull` weigert sich, Textdateien mit Token/Passwort/Key-artigem Inhalt ins Repo zu holen.

## Struktur (umgesetzt)

```
system/dotfiles/                   # → Symlinks nach ~
  .gitconfig                       # lokal; Vorlage .gitconfig.example
  .bashrc.d/desktop.sh             # DOCKER_HOST (Starship-Block bleibt bei rice theme)
  .ssh/config
  .config/containers/systemd/anisette.container
  .config/rclone/icloud-filter.txt
  .config/systemd/user/{goxlr.service,icloud-photos.service,icloud-sync.service,icloud-sync.timer}
  .local/bin/{keylight,icloud-sync,icloud-login}
system/copies.txt                  # Liste der Kopien (Datei oder "Ordner/ Muster")
system/copies/                     # → Kopien nach ~
  .claude/settings.json            # lokal; Vorlage settings.json.example
  .config/Code/User/{settings.json,keybindings.json}
  .config/mimeapps.list
  .config/autostart/claude-desktop.desktop
  .config/kwinoutputconfig.json    # nur lokal (Monitor-Seriennummern)
  .local/share/goxlr-utility/{profiles/*.goxlr,mic-profiles/*.goxlrMicProfile}
system/sync                        # status | pull [-n] | push [--apply]
```

Noch nicht drin (Idee): `system/kde/kwinrc.extra` – `kwriteconfig6`-Zeilen für `[NightColor]`, `[Desktops]` usw.

### Warum Link oder Kopie

| Weg | Gut | Schlecht | Für |
|---|---|---|---|
| **Symlink** `~/x → system/dotfiles/x` | Änderung sofort im Repo, kein Abgleich | Apps, die Dateien atomar neu schreiben, **ersetzen den Link durch eine Datei** → Repo hängt still hinterher | alles in `system/dotfiles/` |
| **Kopie** (bootstrap kopiert, `system/sync` gleicht ab) | robust gegen atomares Schreiben | man muss ans `sync pull` denken | alles in `copies.txt` |

`system/bootstrap` Schritt 8 macht beides: Links (Original vorher als `<datei>.vor-desktop`; bei `~/.local/bin` und
`~/.bashrc.d` nach `~/.local/state/desktop/dotfiles-backup/`) und Kopien (alte PC-Datei als `.vor-desktop`).
Eine Kopie, deren PC-Fassung **neuer** ist als das Repo, lässt bootstrap stehen (Hinweis `system/sync pull` / `push --apply`).
Links in einen anderen bekannten Checkout (`CHECKOUTS` oben in `bootstrap`) gelten als ok.
