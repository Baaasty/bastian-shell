# Hyprland – Sitzung, Sperre, Sitzung wiederherstellen

Stand 19.10.2026 · Hyprland 0.56.2 aus COPR `sdegler/hyprland` · Quickshell 0.3.2.

Dieselbe Shell läuft auf Hyprland statt auf KWin – mehr Leistung (360 Hz, NVIDIA). **Plasma bleibt installiert und
unverändert** (Bluetooth-/WLAN-Dienste, Dolphin, Dateidialog und Qt-Theme hängen daran) und ist der Fallback.
Umzug und Autologin: [setup/migrate.md](../setup/migrate.md).

## Einrichten und zurück

- Pakete (sudo) stehen in `system/packages/dnf.txt` (Abschnitt Hyprland-Sitzung). Danach ohne sudo `scripts/hypr install`,
  prüfen mit `scripts/hypr check` (`Hyprland --verify-config`, startet nichts), `scripts/hypr status` zeigt Fehlendes.
  Im Login **„Hyprland (uwsm-managed)“** wählen.
- `install` legt nur Includes und Links an, die allein in der Hyprland-Sitzung wirken: `~/.config/hypr/*.conf` → `hypr/`,
  uwsm-Umgebung aus `hypr/env.conf`, Portal-Zuordnung, User-Unit `desktop-shell-hyprland`, und ein Drop-in, das hier
  DrKonqi anhält (eigene Absturz-Karte, [shell-features.md](shell-features.md); einzeln zurück:
  `scripts/hypr drkonqi on`). Fremde Dateien sichert es nach `~/.local/state/desktop/hypr-backup/`, `uninstall` holt sie zurück.
- **Zurück zu Plasma:** abmelden → „Plasma (Wayland)“. Shell hängt: Strg+Alt+Shift+Q (`scripts/hypr panic`: Shell aus,
  Konsole auf), dann `uwsm stop`. Nichts geht: Strg+Alt+F3 → `loginctl terminate-user $USER`.
  Ganz weg: `scripts/hypr uninstall`, Pakete entfernen, COPR abschalten.

## Aufbau

- `hypr/hyprland.conf` ist der Einstieg (`$DESKTOP` = Repo, `$IPC`, `$APP` = `uwsm app --`); daneben `env.conf`,
  `monitors.conf`, `general.conf`, `rules.conf`, `binds.conf` (Kürzel: [hotkeys.md](hotkeys.md)), `autostart.conf`,
  `hypridle.conf`, `portals.conf`. `look.conf` wird aus `theme/palette.json` **erzeugt** (`theme/gen/hypr.py`), nie von Hand.
  `window.py` (altes Fensterschema) ist nicht mehr gebunden.
- Workspaces gehören fest zu Monitoren: Desktop d = Workspace d (DP-2) / 100+d (HDMI-A-2) / 200+d (DP-1).
- Kacheln ist Standard; schweben nur Dialoge, Picker, Bild im Bild, Steam.
- Shell-Seite: `shell/services/Hypr.qml` (`Quickshell.Hyprland`), `modules/background` (Wallpaper, unter Plasma aus),
  `modules/lock`, `modules/switcher` (Super+Tab). Ausschneiden per `grim`, Video per `wf-recorder`.
- Apps starten immer über `uwsm app --` (eigene systemd-Unit, stirbt nicht mit der Shell).

## Steam und Spiele

Steam ist ein Flatpak (`--user`) auf XWayland. Hauptfenster mittig auf DP-2, alle anderen Steam-Fenster schweben.
Spiele (`steam_app_<id>`) öffnen auf DP-2 mit `content game`; Vollbild schalten sie selbst (EA/Ubisoft-Launcher haben dieselbe Klasse).

- **Tearing** (`immediate`) geht nur im echten Vollbild **ohne Overlay-Fläche** auf dem Monitor (`CMonitor::isSolitaryBlocked`).
  Darum nimmt die Shell bei einem Vollbild-Spiel Bar, Arbeitsplatz-Leiste und Randstreifen ganz weg (`Windows.game`);
  Dashboard, Launcher und Benachrichtigungen gehen weiter. Ob der NVIDIA-Treiber Tearing kann, zeigt erst der Test.
- Angepinnte Fenster (Discord, Spotify) liegen unter Hyprland **über** Vollbild-Spielen und blockieren Tearing – vorher wegräumen.
- Vollbild hält hypridle an. Spiele erscheinen nicht einzeln im Launcher (das Flatpak darf keine .desktop-Dateien schreiben).

## Grenzen gegenüber KWin

- Keine Titelleisten: verschieben mit Super+links ziehen, Größe am Rand oder Super+rechts ziehen.
- „Immer oben“ gibt es nicht; Anpinnen nur per Regel (Discord/Spotify, `hypr/rules.conf`) und pro Monitor.
- Mausverschiebungen meldet Hyprland nicht: die Bar merkt sie erst beim nächsten Fenster-Ereignis
  (Super+Pfeile melden sich selbst über `qs ipc call hypr refresh`).
- Super antippen und Super+Tab gehen über `qs ipc` (ein Prozessstart je Taste); wirkt das träge → Quickshell-`GlobalShortcut`.
- Bildschirm teilen: Discord nutzt keine Portal-Restore-Tokens (Log von xdph: nie `restore_data`) – die Auswahl merkt
  darum unser Picker selbst je App ([shell-features.md](shell-features.md#bildschirm-teilen), `scripts/share-picker forget`).
- Monitore nur über `monitors.conf`. Plasma-only bleibt `scripts/wallpaper set`
  (in Plasma ausführen; die Hyprland-Shell übernimmt neue Wallpaper über `kscreenlockerrc`).
- **hyprlang (.conf) ist seit 0.55 veraltet** und fällt bald weg → vor einem Update auf 0.57+ Release-Notes lesen,
  ggf. auf Lua umstellen oder das Update zurückhalten.

## Offen aus dem ersten Test (18.10.2026, abgebrochen)

- Ganzer Bildschirm hakt periodisch (`aquamarine drm: Cannot commit when a page-flip is awaiting`; 360/144/144 Hz, VRR nur
  auf DP-1). Zuerst VRR überall aus + `misc:vfr` prüfen.
- Spotify/Discord 20–23 % CPU im Leerlauf als native Wayland-Clients ohne GPU → Ozone-Hint weg bzw. XWayland testen.
- Angepinntes Spotify lässt sich nicht verschieben; Discord-Stream: Share-Picker blieb offen, nichts geteilt.
- Login-Theme: Uhr bleibt nach dem Login stehen, Escape lässt alles flackern.

## Workspace-Leiste

Unten links (`shell/modules/workbar/WorkBar.qml`), eine Kachel je Workspace. **Alt antippen** = Workspace-Modus mit
Tastatur (Tasten: [hotkeys.md](hotkeys.md)). Entfernen schließt die Fenster sanft (`closewindow`, Apps dürfen nachfragen)
und erst nach Bestätigung; bleiben Fenster offen, bleibt der Workspace. Nie geschlossen: Discord, Spotify, geparkte Fenster.
Der letzte Workspace wird nicht entfernt, sondern auf einen leeren Standard zurückgesetzt.

## Sperrbildschirm

Die Shell sperrt selbst (`shell/modules/lock`, ext-session-lock); in der Rückfall-Sitzung Plasma sperrt der normale
kscreenlocker. Einstieg für alles: `scripts/lock`.

- Super+L, Power-Menü, `loginctl lock-session` und hypridle rufen `scripts/lock now` → IPC `lock lock`. Antwortet die Shell
  nicht, übernimmt sofort **hyprlock** (Farben aus der Palette).
- Entsperren nur per Passwort über PAM (`shell/assets/pam.d/desktop-lock`: 2 s Wartezeit, kein leeres Passwort).
  Bewusst kein IPC-„unlock“. Ausnahme: `~/.config/desktop/lock.json` mit `{ "requirePassword": false }` → Leertaste
  entsperrt; nur sinnvoll mit verschlüsselter Platte und Autologin. hyprlock fragt immer nach dem Passwort.
- Leerlauf (`hypr/hypridle.conf`): 4:00 langsam abdunkeln, 5:00 Monitore aus, 5:05 sperren; im Fokus-Block 10 min später.
- Zustand in `$XDG_RUNTIME_DIR/desktop-lock` (`locked`/`unlocked`) – daran hängen u. a. GoXLR-Fader beim Entsperren.
- **Absturz:** Hyprland bleibt gesperrt (`misc:allow_session_lock_restore`). Der Wächter `scripts/lock guard` startet
  hyprlock, wenn die Shell die Sperre ~12 s nicht hält; die neu gestartete Shell sperrt dank Zustandsdatei selbst wieder.
- **Notfall aus dem TTY:** Strg+Alt+F3, einloggen,
  `hyprctl --instance 0 dispatch exec ~/Workspace/bastian-shell/scripts/lock rescue`, zurück mit Strg+Alt+F2.

## Sitzung wiederherstellen (hyprflow)

Nach Neustart oder Absturz öffnen sich Terminal, VS Code, Helium wieder auf ihren Workspaces. Backend **hyprflow** v0.2.1
(Rust, MIT), gebaut aus dem gelesenen, festgenagelten Commit `efc96e9` nach `~/.local/bin/hyprflow` (`scripts/session build`).
Skripte `scripts/session` + `scripts/session-prepare`, Config `config/hyprflow/config.toml`, Log `~/.local/state/desktop/session.log`.
Stand: installiert, Autosave läuft; **ein echter Restore ist noch nicht getestet** (erst mit wenigen Fenstern auf einem leeren Workspace).

- **Positivliste:** nur Apps mit `[apps."<Klasse>"]` in der Config – Konsole/Kitty (mit Arbeitsordner), VS Code und Helium
  je ein Start (öffnen ihre Fenster selbst). Nie: Discord, Spotify (holt die Shell), Steam/Spiele, Dialoge, Picker.
  Nicht gemerkt: Inhalte, Vollbild, schwebende Fenster.
- **Autosave** alle 5 min (`desktop-session-save.timer`, 20 Stände). Er speichert nicht während des Login-Restores, bei
  0 Fenstern oder nach einem Einbruch der Fensterzahl – sonst überschreibt der leere Desktop nach einem Absturz den guten Stand.
- **Login** (`exec-once` in `hypr/autostart.conf`): `session boot` wartet auf die Shell, nimmt den neuesten Stand (< 24 h)
  und startet die Apps nacheinander per `uwsm app --`. In dieser Minute nichts öffnen.
- **Kacheln:** Pixelpositionen wirken in dwindle nicht; maßgeblich sind Workspace-Nummer (legt den Monitor fest) und
  Startreihenfolge. Wer links/rechts im Split landet, kann abweichen.
- **Sicherheit:** hyprflow startet Argumentlisten ohne Shell, kein Netz. Trotzdem liest es nie die Originale:
  `session-prepare` baut eine bereinigte Kopie in `$XDG_RUNTIME_DIR` (Positivliste, Namen/Ordner geprüft, Vollbild/Schweben
  aus, weil hyprflow `fullscreen` aufs fokussierte Fenster anwendet). Sitzungsdateien enthalten Fenstertitel → `0700`/`0600`.
- **Not-Aus:** `scripts/session off` (hält auch einen wartenden Login-Restore an; stoppt den Timer nur, kein `disable`,
  das würde den Unit-Link löschen). Ganz weg: `session uninstall`, Zeile in `autostart.conf`, Binary löschen.
- **hyprsession verworfen:** `load` beendet erst alle offenen Fenster, startet Befehle als ungequoteten Shell-String,
  keine Positivliste, eine einzige Sitzung alle 60 s nicht atomar überschrieben, Zuordnung nur per Fenstertitel, Daemon.

## Alter KWin-Weg

Bis 2026-10-18 lief die Shell über KWin (Plasma 6); seit 2026-10-20 ist der Code aus dem Repo entfernt und liegt nur noch im
Git-Tag `kwin-final` (`plasma/shells/`, `bridge/kwin/`, `scripts/rice on`, `shellpkg`, `winrules`, KWin-Bildschirmaufnahme) –
Grund: [DECISIONS.md](../DECISIONS.md). Übrig ist nur das Login-Theme `plasma/loginscreen/` (Plasma Login Manager, `scripts/loginscreen`).
