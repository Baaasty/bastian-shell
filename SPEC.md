# SPEC – "desktop"

Stand: 2026-10-17 · Status: **bestätigt** (Korrekturen aus KWin-Prüfung + Gegenprüfung eingearbeitet)

**Muss** = gehört zur ersten fertigen Version. **Später** = kommt danach. **Runde** = Bau-Reihenfolge (R0–R13, siehe unten).

## 0. Grundsatz: nicht einengen
- Alles bleibt normal bedienbar wie Plasma: Fenster frei schieben (Maus oder Meta+Pfeile). Kürzel: nur noch eigene (§3), alte KDE-Kürzel sind freigeräumt.
- **Freie Desktops sind die Basis:** "+" legt einen leeren Desktop an, wie in Plasma. **Vorlagen** (Code, Office, Fun) gibt es nur zusätzlich, nie als Pflicht.
- Jede Automatik ist abschaltbar (Fokus-Wecker, Fokus-Modus, Fenster-Platzierung).
- Nach einer Woche Alltag prüfen wir: Was wird nicht genutzt oder nervt? Das fliegt raus.

## 1. Rahmen

| Monitor | Rolle | Shell |
|---|---|---|
| HDMI-A-2 links 1080p | frei (Doku, Browser, Fun-Desktop: Discord) | nichts (nur Wallpaper) |
| DP-2 Mitte 1440p@360 | Hauptarbeit (VS Code, Spiele) | Bar, Dashboard, Launcher, OSD, Notifications, Power-Menü |
| DP-1 rechts 1080p | Browser / Live-Preview | nichts (nur Wallpaper) |

- **Plasma behält:**
  - KWin: Fenster, kglobalaccel, Lockscreen, Nachtfarben, Übersicht
  - plasmashell: Wallpaper + Desktop
  - KRunner, PowerDevil, Polkit-Agent
  - kded6: Tray-Watcher, Lautstärke- und Medientasten, Netzwerk- und Bluetooth-Agent
- **Quickshell ersetzt:** Plasma-Panel, Launcher, Tray-Anzeige, OSD, Power-Menü, Benachrichtigungen (Popups + Verlauf).
- **Geht mit dem Panel verloren:**
  - Klipper → Ersatz durch `cliphist`
  - Dateiübertragungs-Fortschritt (JobViewServer) → wird akzeptiert
  - Plasmas DND-Kürzel → kommt über den Fokus-Modus zurück
  - Desktop-Icons: Das Shell-Paket nutzt einen Desktop ohne Icons, weil Plasmas Icons die Quickshell-Bar ignorieren und darunter lägen
  - Plasmas Mini-OSDs (Mic-Mute, Tastaturlayout …), sobald das Plasma-OSD aus ist → bei Bedarf eigene
- **Kein:** Dock, Rahmen ums Bild, Stream-Modus, GoXLR-Mixer, Info-Dashboard auf den Seitenmonitoren.
- **Animationen:** dezent, 150–250 ms, ease-out, keine Federn.

## 2. Komponenten

### 2.1 Top-Bar (DP-2, oben, schlank)

| Element | Prio | Runde | Datenquelle |
|---|---|---|---|
| Desktops (Name, Klick wechselt; "+" = neuer leerer Desktop, Pfeil daneben = aus Vorlage) | Muss | R3 | `import org.kde.taskmanager` → `VirtualDesktopInfo`; Wechsel/Anlegen per KWin-D-Bus `/VirtualDesktopManager` |
| Jetzt-Aufgabe (ein Satz, Klick = bearbeiten) | Muss | R6 | eigener State `state/focus.json` |
| Uhr + Datum | Muss | R2 | Quickshell `SystemClock` |
| Spotify-Mini (Titel – Artist, Play/Pause) | Muss | R2 | `Quickshell.Services.Mpris`, Player `spotify` |
| Fokus-Timer (nur wenn er läuft) | Muss | R6 | eigener Timer-Service (zeitstempelbasiert, übersteht einen Reload) |
| CPU-/GPU-Temp (leise, auffällig ab Schwelle) | Muss | R2 | CPU: sysfs hwmon `name=k10temp` → `temp1_input` (Tctl). GPU: ein Dauerprozess `nvidia-smi --query-gpu=… --format=csv,noheader,nounits -lms 2000` |
| Tray | Muss | R2 | `Quickshell.Services.SystemTray` (läuft neben kded6) |
| Discord-Call (Kanal · Personen · Dauer), nur sichtbar im Call, keine Steuerung | Muss | R13 | siehe 2.2 Discord-Call |
| Fokus-Modus: Bar wird still (nur Uhr, Restzeit, Aufgabe) | Muss | R6 | Fokus-Service |
| Vollbild (Spiel, Video, F11): Bar verschwindet und kommt nur, wenn die Maus an den oberen Rand fährt | Muss | R2 | `TasksModel` (`IsFullScreen` des aktiven Fensters auf DP-2). 2-px-Hover-Streifen am oberen Rand, Bar dann kurz im Layer `Overlay`, sonst `Top` |

### 2.2 Dashboard (Meta+D, Overlay auf DP-2, Glas-Kacheln)

| Kachel | Prio | Runde | Datenquelle |
|---|---|---|---|
| Uhr / Datum | Muss | R5 | `SystemClock` |
| Wetter jetzt + 3 Tage | Muss | R5 | Open-Meteo `api.open-meteo.com/v1/forecast?latitude=<lat>&longitude=<lon>&…&timezone=Europe/Berlin` (Ort aus `secrets.json` → `location`), alle 15 min, Cache in `state/` |
| "Morgen früh"-Check (7–9 Uhr: Regen, Temp, Wind → Motorrad/Rad ok?) | Muss | R5 | Open-Meteo `hourly=precipitation_probability,temperature_2m,wind_speed_10m` |
| Spotify groß (Cover, Fortschritt, Steuerung) | Muss | R5 | Mpris (`trackArtUrl`, 640-px-CDN-Cover) |
| Spotify-Hörzeit heute + Top-Song der Woche | Muss | R13 | eigenes Log: Mpris-Status mitzählen → `state/spotify.jsonl` (kein Spotify-API-Key nötig) |
| CPU/RAM/GPU-Ringe + Temps | Muss | R5 | `/proc/stat`, `/proc/meminfo`, nvidia-smi-Dauerprozess, k10temp |
| Netz ↓/↑ + Ping | Muss | R5 | `/sys/class/net/<iface>/statistics/{rx,tx}_bytes`; `ping -c1 -W1 1.1.1.1` alle 30 s |
| Tailscale-Punkt | Muss | R5 | `tailscale status --json` (`BackendState`, `Self.Online`), alle 60 s |
| Freier Speicher System + Data | Muss | R5 | `df -B1 --output=target,size,avail / ~/Data` (iCloud-FUSE ignorieren) |
| Uptime + ausstehende Updates | Muss | R5 | `/proc/uptime`; `dnf check-update -q` + `flatpak remote-ls --updates`, alle 6 h |
| iCloud-Sync (letzter Erfolg, Fehler rot) | Muss | R5 | `systemctl --user show icloud-sync.service -p Result,ExecMainExitTimestamp` + Marker `~/.local/state/icloud-sync/failed` |
| Pomodoro groß + Tagesziel-Ring (Fokus-Minuten / Ziel) | Muss | R6 | Fokus-Service, `state/focus.json` |
| Bildschirmzeit heute | Muss | R6 | Quickshell `IdleMonitor` (ext_idle_notifier), aktive Minuten → `state/screentime.json` |
| Key Light (an/aus, Helligkeit, Farbtemp) | Muss | R11 | `http://<keylight.host>:9123/elgato/lights` GET/PUT (Fallback `keylight.ip`, beides in `secrets.json`), kein Key |
| Hue-Szenen (Abend/Hell/Aus …) | Muss | R11 | Bridge-Adresse `hue.bridge` (+ `hue.bridgeId`) in `secrets.json`, CLIP v2 `/clip/v2/resource/scene` per `curl` (selbstsigniertes Zertifikat); App-Key einmalig per Bridge-Taste → `secrets.json` |
| Audio-Ausgang + Lautstärke pro App | Muss | R11 | `Quickshell.Services.Pipewire` (Sinks, Stream-Nodes nach `application.name`) |
| Benachrichtigungs-Verlauf | Muss | R8 | Notification-Service (2.4) |
| Discord-Call: wer ist drin, wer spricht, Mic/Cam als Symbol. Nur Info, keine Knöpfe (bewusst, gegen Rumfummeln) | Muss | R13 | Discord-Local-RPC über `$XDG_RUNTIME_DIR/discord-ipc-0` (RPM `discord`; altes Flatpak: `…/app/com.discordapp.Discord/discord-ipc-0`) mit eigener Discord-App (Scopes `rpc`, `rpc.voice.read`; Client-ID/Secret/Token → `secrets.json`), Events `VOICE_STATE_*`, `SPEAKING_*` in der rice-bridge. Fallback ohne RPC: PipeWire erkennt nur "Call läuft + Dauer" |
| Neuer Desktop (groß) + Vorlagen (klein daneben) | Muss | R12 | `profiles/profiles.json` |
| Claude-Code-Usage (Tokens/Requests heute, 5-h-Fenster) | Muss | R13 | lokale Logs `~/.claude/projects/**/*.jsonl` (`message.usage`), Skript → JSON, alle 5 min |
| Code heute (+/− Zeilen, Commits) | Muss | R13 | `git log --since=midnight --numstat` über alle Repos in ~/Workspace (Tiefe 4, ohne `refs/`) |
| GitHub-Zähler (Klick öffnet GitHub) | Muss | R13 | `gh api notifications` (ungelesen), `If-Modified-Since` + `X-Poll-Interval` beachten |
| Office-Hotlinks | Muss | R13 | `profiles/profiles.json` → `hotlinks` |
| Kalender: nächster Termin | Später | – | iCloud CalDAV (App-Passwort → `secrets.json`), erst Mail/Kalender einrichten |
| Tagesziel aus einer eigenen App | Später | – | API einer eigenen App (noch offen) |
| Uptime Kuma eigene Seiten | Später | – | Status-Page-JSON `/api/status-page/heartbeat/<slug>` |
| Backup-Status | Später | – | noch kein Backup eingerichtet (z. B. btrbk/snapper auf btrfs) |
| Steam-Playtime diese Woche | Später | – | Steam lokal (`localconfig.vdf`); Steam ist noch nicht installiert |

### 2.3 Launcher (Meta)

| Modus | Prio | Runde | Datenquelle |
|---|---|---|---|
| Apps (fuzzy) | Muss | R7 | Quickshell `DesktopEntries` + fuzzysort.js (MIT, aus end-4) |
| Projekte | Muss | R7 | Git-Repos in ~/Workspace → öffnet Projekt-Profil (ab R12), vorher nur VS Code |
| Neuer Desktop / aus Vorlage | Muss | R12 | `profiles/profiles.json` |
| Rechner | Muss | R7 | eigener Mathe-Parser in JS (kein `eval`) |
| Emoji | Muss | R7 | Emoji-Liste als JSON im Repo, Kopieren per `wl-copy` |
| Zwischenablage | Muss | R7 | `cliphist` (Fedora-Repo, sudo) + `wl-paste --watch` (wl-clipboard kann ext_data_control). Klipper fällt mit dem Panel weg |

### 2.4 Benachrichtigungen

| Teil | Prio | Runde | Datenquelle |
|---|---|---|---|
| Popups oben rechts (normal / dringend) | Muss | R8 | Quickshell `NotificationServer`. Plasmas Server lebt nur im Benachrichtigungs-Applet. In R8 wird dieses Applet im Tray abgeschaltet → `org.freedesktop.Notifications` ist frei, das Panel bleibt |
| Verlauf im Dashboard | Muss | R8 | dito, persistent in `state/` |
| Nicht stören (Fokus-Modus) | Muss | R6 | eigener Schalter im Notification-Service |
| Flatpak-Benachrichtigungen (Portal) | Muss | R8 | **Pflicht** zusammen mit der Übergabe, sonst gehen Spotify/Flatpak-Meldungen verloren: `~/.config/xdg-desktop-portal/kde-portals.conf` mit `[preferred]` + `org.freedesktop.impl.portal.Notification=gtk`, dann `systemctl --user restart xdg-desktop-portal` |

### 2.5 OSD + Power-Menü

| Teil | Prio | Runde | Datenquelle |
|---|---|---|---|
| Lautstärke-OSD | Muss | R9 | Pipewire Default-Sink (GoXLR System). Hardware-Fader laufen nicht über Pipewire → optional GoXLR-Websocket |
| Helligkeits-OSD | Muss | R9 | PowerDevil D-Bus `/org/kde/ScreenBrightness` (Signal `BrightnessChanged`). PowerDevil macht DDC/CI, nie selbst per ddcutil schreiben |
| Plasma-OSD aus (läuft sonst doppelt) | Muss | R10 | `kwriteconfig6 --notify --file plasmarc --group OSD --key Enabled false` (wirkt sofort; schaltet auch Plasmas Mic-/Layout-OSDs ab) |
| Power-Menü (Meta+Esc): Sperren, Abmelden, Standby, Neustart, Aus | Muss | R9 | `loginctl lock-session`, `org.kde.Shutdown` (logout/reboot/shutdown speichert die Sitzung), `systemctl suspend` |

### 2.6 Fokus-Hilfen

| Teil | Prio | Runde |
|---|---|---|
| Pomodoro (Meta+F), Restzeit in der Bar | Muss | R6 |
| Fokus-Modus am Timer: DND an, Bar still | Muss | R6 |
| Jetzt-Aufgabe in der Bar | Muss | R6 |
| Pausen-Erinnerung nach jedem Pomodoro | Muss | R6 |
| Hyperfokus-Wecker nach 90 min aktiver Zeit ("Pause, trinken, aufstehen") | Muss | R6 |

### 2.7 Desktops + Vorlagen

**Discord + Spotify** laufen immer im Hintergrund (Autostart, minimiert). Ihre Fenster gehören auf den Fun-Desktop.
Discord ist bewusst **nicht** auf allen Desktops. Die Call-Info steht in Bar und Dashboard, das Fenster bleibt zu. Weniger Sog, kein ständiges Nachjustieren an der Cam.

**Freier Desktop (Standard):** "+" in der Bar, "Neuer Desktop" im Dashboard oder Launcher. Legt einen leeren Desktop an, es öffnet sich nichts. Umbenennen per Doppelklick.

**Vorlagen** (optional, über den Pfeil neben "+", das Dashboard oder den Launcher). Eine Vorlage legt einen benannten Desktop an und verteilt die Fenster. Welche Vorlagen es gibt, steht in `profiles/profiles.json`:

| Profil | Mitte (DP-2) | Rechts (DP-1) |
|---|---|---|
| Code | VS Code leer (`code --new-window`, ohne natives RPM das Flatpak – `Launch.code`) | Chrome (`google-chrome --new-window`) |
| Projekt "Code: name" | VS Code mit Ordner | Chrome mit Live-Preview-URL aus profiles.json |
| Office | Dolphin `~/Workspace/<firma>` + Buchhaltung (`google-chrome --app=…`) | CRM/Admin (`--app=…`), Hotlinks im Dashboard |
| Fun (Chill + Gaming) | Spotify; Steam auf Knopfdruck | Chrome; links Discord |

- **Desktop schließen:** Rechtsklick auf den Namen in der Bar. Die Fenster wandern auf den Nachbar-Desktop (KWin-Standard).
- **Umsetzung (R12):**
  - Desktop per KWin-D-Bus `createDesktop`.
  - Fenster per `TasksModel.requestVirtualDesktops`.
  - Monitor per kleinem KWin-Script `desktop-placement`. Das fragt bei `windowAdded` die rice-bridge, wohin das Fenster soll.
  - Nur Fenster, die ein Profil gerade gestartet hat, werden platziert. Alles andere bleibt frei.
- **Offen:** URLs für Buchhaltung und CRM trägst du in `profiles.json` ein. Steam muss noch installiert werden.
- **Icons:** Code/Office/Projekt aus `design/claude-design/icons/`, Fun (Lagerfeuer) aus `design/icons/`.

## 3. Tastenkürzel

| Taste | Aktion |
|---|---|
| Meta (allein) | Dashboard mit Suchleiste (lostippen = suchen) |
| Meta+Tab / Meta+Shift+Tab | Fenster wechseln (aktueller Desktop); Alt+Tab ist frei |
| Meta+` / Meta+~ | Fenster derselben App wechseln |
| Meta+Leertaste / Meta+Shift+Leertaste | nächster / vorheriger Desktop (reihum), Workbar zeigt kurz wo |
| Meta+V | Zwischenablage |
| Druck, Meta+S | Ausschneiden (Strg+C kopieren, Strg+S speichern) |
| Meta+Esc | Power-Menü |
| Meta+F | Fokus-Timer starten/stoppen |
| Meta+↑ | Fenster maximieren, nochmal = zurück |
| Meta+↓ | wiederherstellen: normale Größe, mittig auf dem Monitor (nie minimieren; schon normal = 60 % × 70 %) |
| Meta+← / Meta+→ | an die linke/rechte Seite, nochmal: ½ → ⅓ → ⅔ → ½ (8 px Abstand) |
| Meta+Shift+← / → | auf den Nachbarmonitor, proportional; maximiert/gekachelt bleibt es |
| Meta+Shift+↑ | Vollbild an/aus |
| Meta+P / Meta+Shift+P | Fenster auf allen Desktops / immer im Vordergrund |
| Meta+T | Terminal (Konsole) |
| Meta+L · Meta+R | sperren · Bereich als Video (Spectacle) |
| Strg+Alt+Shift+Q | Not-Aus: `scripts/rice off` |

- **Kürzel mit Taste:** `~/.local/share/applications/desktop-shortcuts.desktop` mit `X-KDE-Shortcuts` (+ `[Desktop Action …]`) → `qs ipc --any-display -p ~/Workspace/desktop/shell call <target> <fn>`.
  - kglobalaccel übernimmt neue Dateien automatisch (`kbuildsycoca6`). Löschen der Datei = Kürzel weg.
  - **Änderungen an der Datei greifen nicht live.** Zum Ändern: Datei löschen → `kbuildsycoca6` → neu anlegen → `kbuildsycoca6`.
  - In `Exec` relativ `qs` schreiben, nie `/usr/bin/qs`: Sonst kollidiert die Datei mit der Fensterlisten-Freigabe (§4).
- **Meta+D freimachen:** `setForeignShortcutKeys` auf KWins "Show Desktop" (Rückweg setzt Meta+D zurück).
- **Nur eigene Kürzel:** Alle anderen KDE-Kürzel mit Taste räumt die `FOREIGN`-Liste in `scripts/rice` per `setForeignShortcutKeys` frei (alter Stand in `~/.local/state/desktop/shortcut-backup.txt`, `rice off` stellt ihn her). Bleiben: Hardware-Tasten, Meta+L, Strg+Alt+Entf, Meta+R, Alt+F4, Meta+Strg+Esc, Meta+Shift+Esc. Liste: `docs/HOTKEYS.md`.
- **Fenster-Kürzel:** KWin-Script `bridge/kwin/desktop-tiling` (`registerShortcut`, Komponente `kwin`, Aktionen `Desktop Window …`). `rice on`: erst FOREIGN frei, dann Script laden, Tasten noch einmal fest setzen. `rice off`: Script aus, Aktionen per `unregister` abmelden (sonst halten sie die Tasten), dann FOREIGN zurück.
- **Meta allein:** `kwinrc [ModifierOnlyShortcuts] Meta=org.kde.kglobalaccel,/component/desktop_shortcuts_desktop,org.kde.kglobalaccel.Component,invokeShortcut,_launch` (= Dashboard). Rückweg: Eintrag löschen (`rice off`).

## 4. Architektur

```
shell/                       Quickshell-Config (Test: qs -p ~/Workspace/desktop/shell)
  shell.qml                  ShellRoot; volle Shell nur auf Screen "DP-2"
  config/                    Theme.qml (aus theme/palette.json), Anim.qml, Settings
  services/                  je Datenquelle ein Singleton (System, Gpu, Weather, Spotify, Focus, Desktops, KeyLight, Hue, …)
  components/                GlassTile, Ring, Graph, Icon, Text-Stile, ClickShield
  modules/                   bar/ dashboard/ launcher/ notifications/ osd/ power/ focus/
bridge/
  rice-bridge                Python (dbus_next, schon installiert), Kindprozess von qs, JSON-Zeilen über stdin/stdout.
                             Bietet D-Bus de.bastian.Desktop nur für das, was QML nicht kann:
                             Antworten an das KWin-Script, Meta-Taste
  kwin/                      KWin-Script-Paket "desktop-placement"
plasma/                      Plasma/Shell-Paket "de.bastian.desktop" (Layout ohne Panel; später Lockscreen)
theme/palette.json           einzige Farbquelle → gen/ erzeugt KDE-Farbschema, Konsole, starship.toml, Cursor-Theme
profiles/profiles.json       Profile + Hotlinks
scripts/rice                 on | off | status (bündelt alle Plasma-Änderungen + Rückweg)
systemd/                     desktop-shell.service (Schritt 6)
secrets.json                 gitignored; secrets.example.json als Vorlage
```

**Wichtige technische Regeln:**
- **Quickshell 0.3.2** aus dem COPR `errornointernet/quickshell`. Fedoras 0.2.1-Snapshot kann keinen Blur.
  Bei Qt-Updates auf den COPR-Rebuild warten (eventuell `dnf versionlock`).
- **Ein Pfad überall:** `~/Workspace/desktop/shell` (ausgeschrieben als absoluter Pfad), byte-gleich in Dev-Start, Kürzeln und systemd. Quickshell 0.3 unterscheidet Instanzen nach Pfad.
- **Apps starten** immer über `kstart --application <id>.desktop` oder `systemd-run --user --scope`, nie direkt (ab R2).
  Sonst sterben alle gestarteten Apps mit, wenn Quickshell abstürzt oder neu startet.
- **Fensterliste/Desktops:**
  - `~/.local/share/applications/org.quickshell.desktop` mit `Exec=/usr/bin/quickshell` und `X-KDE-Wayland-Interfaces=org_kde_plasma_window_management,zkde_screencast_unstable_v1`
  - in QML `import org.kde.taskmanager` (TasksModel, VirtualDesktopInfo)
  - Die Freigabe prüft `/proc/<pid>/exe`. `/usr/bin/qs` ist ein Symlink, also gehen `qs` und `quickshell`.
  - Keine andere `.desktop`-Datei darf `Exec=/usr/bin/qs` oder `/usr/bin/quickshell` haben.
  - Nach dem Anlegen: `kbuildsycoca6` und Quickshell neu starten.
  - caelestia-kde nutzt dafür eine eigene C++-Brücke. Der TasksModel-Weg ist bisher nur in einem verschachtelten KWin getestet → R0.
- **D-Bus aus QML:** `import org.kde.plasma.workspace.dbus` (Aufrufe + Signale). Für Exporte die rice-bridge.
- **Layer-Namespaces:**
  - Bar: `dock`, damit "Desktop zeigen" sie nicht versteckt
  - Popups: `notification`
  - OSD: `on-screen-display`
- **Klick außerhalb schließt:** Menüs per `PopupWindow.grabFocus`. Große Panels per Klick-Schutz-Fläche (Mask).
- **Tastaturfokus:** Bar `None`, offene Panels `OnDemand`. Ein Panel schließt, wenn es den Fokus verliert (Muster: caelestia-kde `kdeFocusGrab`, 100-ms-Timer).
- **Vollbild:** Echte Vollbild-Fenster liegen über der Bar. Popups und OSD auf den Layer `Top` legen und bei Vollbild unterdrücken, damit Spiele nicht gestört werden.
- **Stabilität (NVIDIA):**
  - Bekannte Quickshell-Abstürze bei Suspend/Resume und wenn ein Monitor wegfällt → systemd `Restart=on-failure`
  - wenig Vollbild-Flächen, Blur-Regionen eng halten
  - Ein Monitor läuft mit 360 Hz, also kurze Animationen.

## 5. Plasma-Änderungen und Rückweg

Alles läuft mit `scripts/rice off` zurück zu Vanilla-Plasma. Einmalig vorher: `tar -C ~/.config -czf ~/plasma-pre-desktop.tgz plasma-org.kde.plasma.desktop-appletsrc plasmashellrc plasmarc kscreenlockerrc kglobalshortcutsrc kwinrc`

| Änderung | Runde | Rückweg |
|---|---|---|
| Desktop-Wallpaper auf 3 Monitoren + Lockscreen (`scripts/wallpaper set`) | ✅ 3 | `scripts/wallpaper restore` (Backup in `~/.local/state/desktop/`) |
| Quickshell 0.3.2 aus COPR (sudo) | R0 | `sudo dnf remove quickshell && sudo dnf copr remove errornointernet/quickshell` |
| Freigabe `org.quickshell.desktop` | R3 | Datei löschen + `kbuildsycoca6` |
| Panel weg über eigenes Shell-Paket `de.bastian.desktop` (Desktop ohne Icons, Original-appletsrc bleibt unberührt) | R10 | `kwriteconfig6 --file plasmashellrc --group Shell --key ShellPackage --delete` + plasmashell neu starten |
| Fallback, falls das Shell-Paket nicht klappt: Panel per `evaluateScript` entfernen | R10 | plasmashell stoppen → Backup-tar zurück → starten |
| Kürzel-Datei `desktop-shortcuts.desktop` + Meta+D frei | R4 | Datei löschen, `kbuildsycoca6`, Meta+D zurücksetzen |
| Meta allein → Dashboard | R10 | kwinrc-Eintrag löschen |
| Plasma-OSD aus | R10 | `kwriteconfig6 --notify --file plasmarc --group OSD --key Enabled --delete` |
| Hot Corner oben links (Übersicht) aus | rice on | `kwriteconfig6 --file kwinrc --group Effect-overview --key BorderActivate --delete` + KWin reconfigure |
| Benachrichtigungs-Applet im Tray abschalten | ✅ R8 | `scripts/notify-handover plasma` (oder `scripts/shellpkg off`) |
| Portal-Datei `kde-portals.conf` | ✅ R8 | Datei löschen + `systemctl --user restart xdg-desktop-portal` |
| KWin-Script desktop-placement | R12 | `kpackagetool6 -t KWin/Script -r desktop-placement` |
| KWin-Script desktop-tiling (Super+Pfeile) + KDE-Kürzel freigeräumt | rice on | `rice off` (Script aus + abgemeldet, alte Tasten aus dem Backup zurück) |
| Fensterwechsler `desktop-switcher` (Super+Tab, `kwinrc [TabBox] LayoutName`, alter Wert in `~/.local/state/desktop/switcher-layout.txt`) | rice on | `rice off` (Wert zurück bzw. gelöscht = KDE-Raster, Paket entfernt); einzeln: `kwriteconfig6 --file kwinrc --group TabBox --key LayoutName --delete` + KWin reconfigure |
| KDE-Farbschema, Konsole-Profil, Cursor-Theme (nur neu angelegt) | Schritt 5 | altes Schema/Profil/Cursor wieder wählen (`rice theme off`) |
| Lockscreen im Shell-Paket `de.bastian.desktop` (Passwortfeld auf DP-2, Desktop-Uhr) | jetzt | `scripts/shellpkg off` (Original-Layout bleibt unberührt). Test vorher: `scripts/shellpkg test` |
| Login-Bildschirm (Plasma Login Manager): Hintergrundbild | jetzt | in `kcmshell6 kcm_plasmalogin` zurückstellen |
| systemd-User-Dienst | Schritt 6 | `systemctl --user disable --now desktop-shell` |

## 6. Offene Prüfpunkte

**Geklärt in R0 (2026-10-18):**
- ✅ Quickshell 0.3.2 (COPR) läuft. Blur über `BackgroundEffect.blurRegion` funktioniert auf DP-2 (Sichttest mit An/Aus im Wechsel).
- ✅ Fensterliste per `TasksModel` mit der `.desktop`-Freigabe, in der echten 3-Monitor-Sitzung, auch beim Start über `qs`.
- ✅ `VirtualDesktopInfo` liefert Desktop-Namen außerhalb von plasmashell.
- ✅ IPC per `qs ipc --any-display -p …` funktioniert.
- ✅ Apps per `kstart --application` landen in einer eigenen `app-…`-Gruppe und überleben einen Quickshell-Neustart.
- ✅ Schriften: Inter (dnf), JetBrains Mono Nerd Font + Material Symbols Rounded (`~/.local/share/fonts/desktop`).

**Noch offen (wird in der jeweiligen Runde geprüft):**
1. R8: Übernimmt Quickshells `NotificationServer` den Namen, sobald das Applet im Tray aus ist? Gehen Flatpak-Meldungen mit der Portal-Datei?
2. R10: Shell-Paket ohne Panel auf Plasma 6.7.5. Fallback ist `evaluateScript`.
3. R10: Lässt sich Meta allein auf eine D-Bus-Methode der rice-bridge legen?
4. R13: Discord-RPC mit eigener App: Liefert es den Voice-Status (`rpc.voice.read`) für dich als App-Besitzer ohne Freigabe durch Discord? Fallback ist PipeWire.
5. KWin hat keine Fenster-Lücken für maximierte Fenster: Die Bar schwebt mit 10 px, maximierte Fenster liegen aber direkt an den Rändern.

## 7. PC-Repo (beschlossen 2026-10-18)

Das Repo wird zum Repo für den **ganzen PC**: neu aufsetzen mit einem Befehl, danach ist alles wie vorher.
- Neuer Name: `~/Workspace/pc` (Umbenennen bei der nächsten Pause; dann Pfade in CLAUDE.md/SPEC und Kürzeln anpassen).
- Der Desktop-Rice bleibt wie er ist (`shell/`, `theme/`, `design/`, `plasma/`, `bridge/`, `scripts/`).
- Neu dazu:
  - `packages/`: dnf, Flatpak, COPR, Schriften
  - `dotfiles/`: Konsole, Starship, Git, VS Code, ausgewählte KDE-Einstellungen
  - deine Skripte: keylight, icloud-sync, icloud-login
  - `bootstrap`: idempotentes Installationsskript
- Nie ins Repo: Secrets, Tokens, rclone-Konfiguration, SSH-Keys, Browser-Profile.

## 8. Reihenfolge

| Schritt | Inhalt |
|---|---|
| 2 SPEC | ✅ bestätigt |
| 3 Design | 3a: Claude Design (`docs/design-brief.md`) → `design/claude-design/` ← **läuft gerade**. 3b: `theme/palette.json` + `design/preview.html`, iterieren bis "passt" |
| 4 Bauen | ✅ R0 Spike (COPR, Fonts, Blur, Freigabe) · R1 Theme + Komponenten · R2 Bar · R3 Desktops · R4 Kürzel + `rice on/off` · R5 Dashboard-Kern · R6 Fokus · R7 Launcher · R8 Notifications (+ Übergabe von Plasma, Portal-Datei) · R9 OSD + Power · **R10 Umstieg** (Panel-Tausch, Plasma-OSD aus, Meta allein) · R11 Key Light/Hue/Audio · R12 Profile + freier Desktop + Discord · R13 Stats + Hotlinks |
| 5 Einheitlich | KDE-Farbschema (Dolphin & Co.), Konsole (transparent + Blur), Starship, **VS Code-Theme** (aus `editorSyntax`), **Chrome-Theme**, Cursor-Theme, Ordnerfarbe. Regel: alles passt zusammen, aber jede App behält ihren eigenen Kontrast (Editor ≠ Shell-Glas ≠ Terminal), damit man den Überblick behält |
| 6 Autostart | `desktop-shell.service` (`ExecStart=/usr/bin/quickshell -p …/shell`, `Restart=on-failure`) + Not-Aus-Kürzel + Discord/Spotify minimiert |

Bis R10 läuft das Plasma-Panel weiter mit. Plasma bleibt also voll nutzbar, während die Ersatzteile entstehen.

Jede Runde: `qs -p ~/Workspace/desktop/shell` → du testest + Screenshot → Commit.

**Referenzen in `refs/`:**
- caelestia-shell: Look und Drawer
- **caelestia-kde: gepflegter KWin-Port, erste Anlaufstelle für KWin-Lösungen**
- dots-hyprland: Services, Launcher, OSD
- noctalia-shell: C++, nur noch als KDE-Rezeptbuch
