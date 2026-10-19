# Umzug auf ein Theme: `~/Workspace/bastian-shell`

Vorher gab es zwei Ordner: `~/Workspace/desktop` (Branch `kwin`, KWin-Stand) und `~/Workspace/desktop-hyprland` (Branch `hyprland` = `main`).
Danach gibt es nur noch einen Klon von `bastian-shell` in **`~/Workspace/bastian-shell`**. Der PC startet nach dem LUKS-Passwort
per Autologin direkt in Hyprland mit der Shell, ohne Login-Bildschirm und ohne Sitzungsauswahl; gesperrt wird mit dem Sperrbildschirm
der Shell (`docs/LOCKSCREEN.md`, optional nur Leertaste). Die KWin-Variante kommt weg. **Plasma bleibt installiert, aber unsichtbar**
(Bluetooth/WLAN-Dienste, Dolphin, Dateidialog und Qt-Theme hängen teils daran); ganz runter nur mit `--remove-plasma` (dann greetd als
Login-Ersatz, siehe unten). Das Skript dafür ist **`system/migrate`**. Ohne Schalter macht es nur einen Probelauf und ändert nichts.
Andere Inhalte in `~/Workspace` (Projekte, `*.code-workspace`) fasst es nicht an.

## Reihenfolge

Vorher: in der Hyprland-Sitzung sein, nichts per Bildschirm teilen, beide alten Ordner committet. `public` muss den aktuellen Stand
haben (der Klon kommt von GitHub). Claude/VS Code möglichst nicht aus den alten Ordnern heraus laufen lassen.

```sh
~/Workspace/desktop-hyprland/system/migrate                 # 1. Probelauf: alles lesen
~/Workspace/desktop-hyprland/system/migrate --apply --only 1  # 2. klonen
cd ~/Workspace/bastian-shell
system/migrate --apply                                      # 3. Schritte 1–6 (bricht bei Fehlern ab)
system/migrate --only 6                                     # 4. Prüfung: alles „ok“?
system/migrate --apply --only 7                             # 5. alte KWin-Teile weg + Autologin in Hyprland (sudo)
#   Claude/VS Code in den alten Ordnern schließen
system/migrate --apply --only 8 --delete-old                # 6. alte Ordner löschen (vorher Bundle)
system/migrate                                              # 7. Kontrolle, zweiter Lauf schadet nicht
# Neustart: LUKS-Passwort → direkt Hyprland
```

Nur wenn Plasma doch ganz runter soll (nicht nötig): `system/migrate --apply --only 7 --remove-plasma` richtet greetd ein;
nach dem Test im TTY (`sudo systemctl stop plasmalogin && sudo systemctl start greetd`) mit `--remove-plasma --login-switch`
umstellen, neu starten und `--remove-plasma` noch einmal für die Pakete.

Die Rückfragen in 7 und 8 brauchen ein Terminal oder `--confirm "plasma weg"`, `--confirm greetd` bzw. `--confirm löschen`.

## Was passiert

| # | Schritt | Details |
|---|---|---|
| 1 | Klonen | `git clone git@github.com:Baaasty/bastian-shell.git`. Gibt es den Ordner schon: Herkunft prüfen, dann `pull --ff-only`, wenn er sauber ist. Vergleicht den Stand mit dem lokalen `main`. |
| 2 | Lokale Dateien | Alles, was laut `.gitignore` von `main` lokal ist: `secrets.json`, `projects/projects.json`, `theme/projects.json`, `profiles/profiles.json`, `system/dotfiles/{.gitconfig,.ssh/config}`, `system/copies/**/settings.json`, `design/inspo/*`, Wallpaper-Vorschauen, `theme/out/wallpaper/`. Zeigt ein Link im Home auf eine Fassung, wird die genommen (z. B. `~/.ssh/config` → Ordner `desktop`). Weichende Zweitfassungen landen in `~/.local/state/desktop/migrate/aus-<ordner>/`. Im Ziel wird nichts überschrieben. |
| 2 | Nicht mitgenommen | `refs/` (Referenz-Klone, neu klonbar; `--with-refs` nimmt sie mit), `__pycache__`, Logs, `.claude/`-Lock, Browser-Cache, `theme/out/icons/` (erzeugt `icons.py` neu), `.vscode/settings.json` (`scripts/vscode-colors refresh`), `kwinoutputconfig.json` (nur KWin, kommt in die Sicherung) |
| 3 | Pfade | a) alle Symlinks im Home, die in die alten Ordner zeigen, auf denselben Pfad im neuen Repo (systemd-Units + `.wants`, kitty, yazi, fastfetch, hyprflow, Portale, zsh, Dotfiles, `~/.local/bin`, Claude-Skill). b) Installer aus dem neuen Repo: `hypr install`, `session install`, `share-picker install`, `kitty-theme install`, `sshs install`, `chrome-ext install --browser helium`, `theme/gen/vscode.py`. c) Textdateien mit festem Pfad (`~/.bashrc` Starship, `~/.claude/settings.json` Hooks, Claude-Desktop-Config, `QtProject.conf`, `discord.desktop`, Chrome-Host …), vorher Sicherung `<datei>.vor-migrate`. d) Nur ein Hinweis: Die Helium-Erweiterung neu laden (entpackt aus `theme/out/chrome-desktop-ext`), VS Code „Zuletzt geöffnet“. |
| 4 | Repo-Prüfung | keine festen Pfade auf die alten Ordner. Ein Ort für Units und Hyprland: `DESKTOP=` in `~/.config/desktop/hyprland.env` |
| 5 | Claude Code | `memory/` aus `~/.claude/projects/-home-<user>-Workspace-desktop*` nach `…-bastian-shell` (nichts überschreiben, `MEMORY.md` zusammenführen), `scripts/claude-skills install` |
| 6 | Dienste | `daemon-reload`, Shell-Dienst neu starten (vom neuen Pfad), Mail-Wächter und Portale neu starten, `hyprctl reload`. **Prüfung**: Klon, `hyprland.env`, keine Links und Texte mehr auf die alten Ordner, Shell läuft von `~/Workspace/bastian-shell/shell`, IPC antwortet, `hyprctl configerrors` leer. Ist sie rot, sind 7 und 8 gesperrt. |
| 7a | Alte Teile | KWin-Shell-Dienst, Kürzel-Wächter, KWin-Scripts, Wechsler, Plasma-Shell-Paket, Kürzel-.desktop, Screencast-Helfer, Fensterregeln, KWin-Schlüssel, Rückweg-Dateien von `rice off`, Catppuccin-Reste, alte Sicherungen `*.vor-desktop`, `*.vor-goxlr`, `*.vor-gate-*` … Vorher wird alles nach `~/Backups/desktop-reste-<zeit>.tar.gz` gesichert. **Bleibt:** DesktopHearth-Farben, Cursor, Desktop-Icons, Konsole-Profil, `kscreenlockerrc` (Wallpaper-Pfad). |
| 7b | Anmeldung | greetd + tuigreet statt plasmalogin (plasmalogin braucht kwin). Hyprland unter uwsm ist vorausgewählt, KWallet wird beim Login entsperrt. Umgestellt wird erst mit `--login-switch`, nach dem Test im TTY. |
| 7c | Pakete | erst, wenn die Anmeldung nicht mehr plasmalogin ist: Keep-Pakete als „user“ markieren, das Plasma-Menü nach `~/.config/menus` kopieren, dann `dnf remove` (61 Pakete direkt, insgesamt ~146 Pakete / 664 MiB). Bricht ab, wenn dnf ein Keep-Paket mitnehmen würde. |
| 8 | Löschen | nur mit `--delete-old` und grüner Prüfung, aus dem neuen Ordner gestartet. Erst `~/Backups/desktop-<datum>.bundle` (`--all`: kwin, hyprland, main, Stash), dazu ein tar der lokalen Reste und eine Liste der refs-URLs. Dann `git worktree remove`, `rm -rf ~/Workspace/desktop`. |

Bleibt installiert: Hyprland, uwsm, Quickshell, Portale (hyprland, gtk, kde für den Dateidialog), plasma-integration (Qt-Theming),
Breeze-Stil, Breeze-Icons und Breeze-Cursor, kirigami, kconfig (`kwriteconfig6`), `qdbus-qt6`, KWallet, polkit-kde (Rückfall), kdialog, ksshaskpass,
Dolphin, Konsole, KWrite, Ark, Okular, Gwenview, KCalc, Filelight, Partitionmanager, KDE Connect, NetworkManager, PipeWire.
Weg sind danach: Bluetooth-Oberfläche (nur noch `bluetoothctl`), Netzwerk-Applet (`nmcli`), Discover (Updates-Knopf im Dashboard tut nichts),
`rice theme`/`rice variant` (brauchen `plasma-apply-*`), `scripts/wallpaper` (braucht plasmashell).

## Zurück

- **Vor Schritt 8:** Die alten Ordner sind noch da. Jede geänderte Textdatei hat ein `<datei>.vor-migrate` daneben (zurückbenennen).
  Links zurück: `~/Workspace/desktop-hyprland/scripts/hypr install` und die anderen Installer aus dem alten Ordner, dann `systemctl --user daemon-reload`.
- **Alte Teile (7a):** `tar -C ~ -xzf ~/Backups/desktop-reste-<zeit>.tar.gz`
- **Pakete (7c):** Die Liste vorher steht in `~/.local/state/desktop/migrate/rpm-vorher-<datum>.txt`. Plasma zurück: `sudo dnf install plasma-desktop plasma-workspace kwin plasma-login-manager`.
- **Nach Schritt 8:** `git clone ~/Backups/desktop-<datum>.bundle ~/Workspace/desktop-alt` (alle Branches), lokale Dateien aus `~/Backups/desktop-<datum>-lokal.tar.gz`.

## Notfall aus dem TTY (Strg+Alt+F3)

- **Kein grafischer Login:** `sudo systemctl enable --force plasmalogin.service && sudo reboot` (solange Plasma noch installiert ist).
  Danach: `sudo systemctl enable --force greetd.service && sudo reboot`. Ohne Greeter: anmelden, dann `uwsm start -e -D Hyprland hyprland.desktop`.
- **greetd hängt:** `sudo systemctl restart greetd`. Konfiguration in `/etc/greetd/config.toml` (Sicherung `.vor-migrate`), Log: `journalctl -b -u greetd`.
- **Shell kaputt nach dem Umzug:** `systemctl --user status desktop-shell-hyprland`, `cat ~/.config/desktop/hyprland.env` (muss auf `~/Workspace/bastian-shell` zeigen),
  `~/Workspace/bastian-shell/scripts/hypr install && systemctl --user restart desktop-shell-hyprland`.
- **Hyprland startet nicht:** `cat ~/.config/hypr/hyprland.conf` (`$DESKTOP = …/bastian-shell`), `Hyprland --verify-config` über `scripts/hypr check`.

## Danach offen

- `system/packages/dnf.txt` und `system/bootstrap` holen Plasma (plasma-workspace, plasma-login-manager) noch als Grundlage. Ein frischer Bootstrap installiert es also wieder.
  Das muss in einer eigenen Runde auf greetd und die Keep-Liste umgestellt werden.
- Login-Bildschirm im Desktop-Look: greetd mit einem Quickshell-Greeter in einem kleinen Hyprland. Die Farben kommen aus `palette.json` (Generator `theme/gen/login.py`). Das ist nur geplant, noch nicht gebaut.
  `scripts/loginscreen` und `plasma/loginscreen/` sind nach dem Umzug veraltet.
- KWin-Code im Repo (`scripts/rice` außer `theme`/`feeds`, `scripts/shellpkg`, `scripts/winrules`, `bridge/kwin/`, `plasma/`) kann raus. Das gehört in eine eigene Runde.
