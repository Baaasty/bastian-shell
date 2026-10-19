# Hyprland (zweite Sitzung neben Plasma)

Stand 19.10.2026 · Repo `~/Workspace/bastian-shell` (Branch `main`) · Hyprland 0.56.2 aus COPR `sdegler/hyprland`.

Dieselbe Shell (Quickshell 0.3.2) läuft statt auf KWin auf Hyprland – mehr Leistung (360 Hz, NVIDIA).
**Plasma bleibt installiert und unverändert**: Beim Login wählt man die Sitzung, Plasma ist der Fallback.

## Einrichten

1. Pakete (sudo, einmalig):
   ```sh
   sudo dnf copr enable -y sdegler/hyprland
   sudo dnf install -y hyprland hyprland-guiutils xdg-desktop-portal-hyprland uwsm hypridle hyprlock \
       grim wf-recorder xdg-terminal-exec
   ```
2. Konfiguration (ohne sudo): `~/Workspace/bastian-shell/scripts/hypr install`, dann `scripts/hypr check`
   (prüft mit `Hyprland --verify-config`, startet nichts).
3. Abmelden → im Login **„Hyprland (uwsm-managed)“** wählen.

`scripts/hypr status` zeigt, was installiert ist und welche Pakete fehlen.

## Zurück zu Plasma

- Normal: abmelden (Super+Esc → Log out, oder Strg+Alt+Entf) → im Login **„Plasma (Wayland)“** wählen.
- Shell hängt: Strg+Alt+Shift+Q (`scripts/hypr panic`: Shell aus, Konsole auf), dann `uwsm stop` = abmelden.
- Gar nichts geht: Strg+Alt+F3 → einloggen → `loginctl terminate-user $USER` (alle Apps zu, zurück zum Login).
- Ganz entfernen: `scripts/hypr uninstall`, dann
  `sudo dnf remove hyprland hyprland-guiutils xdg-desktop-portal-hyprland uwsm hypridle hyprlock && sudo dnf copr disable sdegler/hyprland`.

## Was `scripts/hypr install` anlegt

| Datei | Inhalt |
|---|---|
| `~/.config/hypr/hyprland.conf` | `$DESKTOP = <Repo>` + `source = $DESKTOP/hypr/hyprland.conf` |
| `~/.config/hypr/hypridle.conf` | dasselbe für `hypr/hypridle.conf` |
| `~/.config/uwsm/env-hyprland` | Umgebung aus `hypr/env.conf` (NVIDIA, Qt/KDE-Look, Cursor) für Apps als systemd-Units |
| `~/.config/xdg-desktop-portal/hyprland-portals.conf` | Link → `hypr/portals.conf` (Dateidialog KDE, Bildschirm teilen Hyprland) |
| `~/.config/systemd/user/desktop-shell-hyprland.service` | Link → `systemd/…` (Shell, Neustart bei Absturz) |
| `~/.config/systemd/user/desktop-shell.service.d/not-on-hyprland.conf` | hält die Plasma-Shell in der Hyprland-Sitzung an (unter Plasma ohne Wirkung) |
| `~/.config/systemd/user/drkonqi-coredump-launcher@.service.d/not-on-hyprland.conf` | kein DrKonqi-Fenster in der Hyprland-Sitzung bei laufender Shell (eigene Absturz-Karte, `docs/CRASHES.md`); einzeln zurück: `scripts/hypr drkonqi on` |
| `~/.config/desktop/hyprland.env` | `DESKTOP=<Repo>` für den Shell-Dienst |

Alle Dateien gelten nur in der Hyprland-Sitzung. Vorhandene fremde Dateien sichert install nach
`~/.local/state/desktop/hypr-backup/`, uninstall holt sie zurück.

## Aufbau `hypr/`

| Datei | Inhalt |
|---|---|
| `hyprland.conf` | Einstieg, Variablen `$DESKTOP`, `$IPC`, `$APP` (= `uwsm app --`), `$WIN` |
| `env.conf` | Umgebungsvariablen (NVIDIA nach Hyprland-Wiki, Qt/KDE, Cursor) |
| `monitors.conf` | 3 Monitore wie unter KWin, Workspaces je Monitor (Desktop d = Workspace d / 100+d / 200+d) |
| `general.conf` | Eingabe (de nodeadkeys), Klick-Fokus, kein Mausspringen, Einrasten |
| `look.conf` | **erzeugt** aus `theme/palette.json` (`python3 -I theme/gen/hypr.py`), nie von Hand |
| `rules.conf` | Kacheln als Standard; Schweben nur für Dialoge, Picker, Bild im Bild, Steam; Startplätze wie `scripts/winrules` |
| `binds.conf` | Kürzel wie `docs/HOTKEYS.md` |
| `autostart.conf` | hypridle, Polkit-Wächter (eigener Dialog, KDE-Agent als Rückfall), KWallet, Cursor |
| `hypridle.conf` | dimmen 5 min, sperren 5:05, Monitore aus +1 min (Fokus-Block: 15 min) |
| `window.py` | altes Fensterschema (½ → ⅓ → ⅔, mittig, Nachbarmonitor); **nicht mehr gebunden**, liegt nur noch da |
| `portals.conf` | Portal-Zuordnung |

Shell-Seite: `shell/services/Hypr.qml` (Fenster, Monitore, Desktops über `Quickshell.Hyprland`),
`shell/modules/background` (Wallpaper, unter Plasma aus), `shell/modules/lock` (Sperre, siehe `docs/LOCKSCREEN.md`),
`shell/modules/switcher` (Super+Tab). Ausschneiden per `grim`, Video per `wf-recorder` (`scripts/screenrec`).

## Steam und Spiele

Steam = Flatpak (`--user`, `system/packages/flatpak.txt`), läuft über XWayland, startet aus dem Launcher wie jede App.
- **Steam-Hauptfenster** (Klasse `steam`, Titel „Steam“) öffnet mittig auf DP-2, 1600×1000. Freunde-Liste,
  Dialoge, Menüs: alle Steam-Fenster schweben (Regel `float on`).
- **Spiele** (`steam_app_<id>`, alles über Proton/Steam-Laufzeit) öffnen auf DP-2 und werden als Spiel markiert
  (`content game`). Vollbild schalten die Spiele selbst um (nicht erzwungen: Launcher von EA/Ubisoft haben dieselbe Klasse).
- **Tearing** (`immediate`, `general:allow_tearing = true`): nur im echten Vollbild und nur ohne Overlay-Flächen
  auf dem Monitor (Hyprland `CMonitor::isSolitaryBlocked`). Darum nimmt die Shell bei einem Spiel im Vollbild
  Bar, Arbeitsplatz-Leiste und ihre 2-px-Randstreifen ganz weg (`Windows.game`, Status: `qs ipc … call shell status`).
  Dashboard (Super antippen), Launcher und Benachrichtigungen gehen weiter. Ob der NVIDIA-Treiber Tearing kann,
  zeigt erst der Test (sonst Hinweis „monitor doesn't support it“ im Hyprland-Log, Spiel läuft trotzdem normal).
- **Vollbild** hält hypridle an (dimmen/sperren/Monitore aus).
- **Angepinnte Fenster** (Discord, Spotify) zeigt Hyprland **über** Vollbild-Spielen, wenn sie auf DP-2 offen sind
  (unter KWin liegen sie dahinter) – und sie blockieren dort Tearing. Vor dem Spielen wegräumen oder auf einen
  Nebenmonitor schieben.
- Spiele erscheinen **nicht** einzeln im Launcher: das Flatpak darf keine .desktop-Verknüpfungen nach
  `~/.local/share/applications` schreiben. Start über Steam.
- gamemode: optional, braucht sudo (`system/packages/dnf.txt`, Kommentar unten).

## Unterschiede zu KWin / offene Lücken

- **Ungetestet:** Alles ist nur offline geprüft (QML-Syntax, Konfig-Schlüssel gegen den Hyprland-0.56.2-Quelltext,
  `bash -n`, `py_compile`). Erster echter Test = erste Hyprland-Sitzung.
- **Keine Titelleisten:** Fenster mit Super+links ziehen verschieben, Größe am Rand oder Super+rechts ziehen.
- **Super+Shift+P** („immer oben“) ist entfallen (Hyprland kennt kein dauerhaftes „oben halten“); Anpinnen nur per Regel.
- **Anpinnen** (alle Desktops) gibt es nur per Regel für Discord/Spotify (`hypr/rules.conf`, kein Kürzel wie unter
  KWin) und gilt pro Monitor (Workspaces sind pro Monitor).
- **Fenster mit der Maus verschieben** meldet Hyprland nicht: die Bar merkt ein hochgeschobenes Fenster erst
  beim nächsten Fenster-Ereignis (Super+Pfeile melden sich selbst über `qs ipc call hypr refresh`).
- **Super antippen** (Dashboard) und Super+Tab gehen über `qs ipc` (ein kurzer Prozessstart je Taste). Falls das
  träge wirkt: auf Quickshell-`GlobalShortcut` (Hyprland-Protokoll) umstellen.
- **Monitore** nur über `monitors.conf` (kein KScreen-Dialog).
- **Plasma-only bleiben:** `scripts/rice on|off`, `winrules`, `shellpkg`, `wallpaper set` (liest die Monitore über
  plasmashell – in Plasma ausführen; die Hyprland-Shell übernimmt das neue Set automatisch über `kscreenlockerrc`).
- **hyprlang (.conf) ist seit 0.55 veraltet**, 0.56 zeigt beim Start einen Hinweis. Laut Hyprland fällt es
  1–2 Versionen nach 0.55 weg → **vor einem Update auf 0.57+ die Release-Notes prüfen**; ggf. auf Lua umstellen
  (Vorlage: `refs/dots-hyprland/dots/.config/hypr/*.lua`) oder das Update zurückhalten.
- Nachtlicht: unter Plasma aus, daher hier nichts (bei Bedarf `hyprsunset` aus derselben COPR).

## Erster Test (2026-10-18, ~17:35) – abgebrochen, zurück zu Plasma

Bastian: „alles kaputt“. Gefunden:
- **Ganzer Bildschirm hakt periodisch** („alles gleichzeitig“). Log: `aquamarine drm: Cannot commit when a page-flip is awaiting` (6×),
  3 Monitore mit 360/144/144 Hz, VRR nur auf DP-1. Ursache offen – zuerst VRR überall aus + `misc:vfr` prüfen, dann Monitor-Commits.
- **Spotify/Discord 20–23 % CPU im Leerlauf**: laufen als native Wayland-Clients (ELECTRON_OZONE_PLATFORM_HINT=auto) ohne GPU
  (nicht in nvidia-smi). Unter Plasma lief Spotify anders. Test: Hint weg bzw. Spotify per XWayland.
- **Spotify lässt sich nicht verschieben** (angepinnt per Regel `pin on`; Super+Ziehen ging nicht).
- **Discord-Stream geht nicht**: hyprland-share-picker blieb offen, nichts wurde geteilt.
- systemd-hostnamed wird ~minütlich neu aktiviert (wer fragt? harmlos, aber prüfen).
- Login-Theme (Haupt-Repo, plasma/loginscreen): Uhr bleibt nach dem Login stehen; Escape lässt alles flackern (schaltet Monitore aus).

## Workspace-Leiste und Workspace-Modus (AP 2 / AP 20)

Die Leiste unten links (`shell/modules/workbar/WorkBar.qml`, App-Leiste `shell/modules/bar/AppStrip.qml`) zeigt jeden Workspace als Kachel (Nummer = Alt+n, Name, Vorschau mit Fenstern).
**Alt antippen** (oder Alt+Esc) = Workspace-Modus: die Leiste erscheint (auch bei Vollbild) und bekommt die Tastatur, solange der Modus läuft.
Tasten: `1–9` wechseln · `←/→` (H/L) markieren · `Enter` wechseln · `Shift+1–9` Fenster dorthin · `Shift+←/→` Kachel verschieben ·
`Entf` (oder `X`) Workspace schließen & entfernen · `N` neu · `T` Vorlagen · `R`/`F2` umbenennen · `Esc` oder Klick daneben beendet. IPC: `qs ipc … call workbar mode|modeOpen|modeClose`.

**Entfernen** (Modus X/Entf, Mittelklick auf die Kachel, Rechtsklick → „Close N windows & remove“): leerer Workspace sofort weg; sonst zeigt die Kachel
kurz (3 s) „Close N windows? · Enter“ in der Warnfarbe – zweites X/Entf oder Enter bestätigt, jede andere Taste bricht ab. Die Fenster werden sanft geschlossen
(`closewindow`, Apps dürfen nachfragen); bleiben welche offen, bleibt der Workspace und die Leiste meldet „N windows still open“. Nie geschlossen:
Chat-Client (Discord-RPM, Rückfall Flatpak bzw. alt Equibop/Vesktop), Spotify, geparkte/weggeräumte Fenster.
Es gibt immer mindestens einen Workspace: beim **letzten** (Kachel/Tooltip/Menü sagen dann „reset“) werden die Fenster geschlossen und er wird auf einen leeren Standard-Workspace zurückgesetzt (Standardname), nicht entfernt.
