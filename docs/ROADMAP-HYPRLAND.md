# Roadmap Hyprland – Stand 2026-10-18, abends

**Fortschritt: 39 von 46 Punkten fertig** (28 Pakete + 18 Ideen) · Pakete 21/28 · Ideen 18/18
`█████████████████░░░` 85 %

> **Leitlinie (Bastian, 2026-10-19): Tastatur zuerst.** Die Shell (Fenster, Workspaces, Bar, Popouts, Panels) wird per Hotkeys aus dem Muscle Memory bedient. Maus nur im Browser und in Apps. Ein Feature ohne Kürzel und ohne Tastaturbedienung gilt als nicht fertig.

Der Rechner läuft unter **Hyprland 0.56 + Quickshell** (Repo `~/Workspace/bastian-shell`, Branch `main`; Umzug aus den alten Ordnern: `docs/MIGRATE.md`). Verlauf/Details: `docs/FORTSCHRITT.md`.

## Noch offen (7 Punkte)

| # | Paket | Stand | Nächster Schritt |
|---|---|---|---|
| 22 | **Tastatur zuerst** (siehe Paketdetails): jedes Bar-Popout per Taste, in Popouts Pfeile/Enter/Esc, Fenstergröße per Taste, Benachrichtigungen per Taste | 🟡 **gebaut, wartet auf Test**: (a) Bar-Modus Super+B (Buchstaben an den Chips, ←/→/Tab + Enter, Esc im Popout zurück zum Chip) + Direkttasten Super+Alt+S/L/Z (U Server), (b) `KeyNav` in allen Bar-Popouts (Glut-Rahmen, Regler erst nach Enter), Schließ-Regel für alle Popouts (Compositor schließt → sofort wieder auf), (c) Super+Alt+Pfeile, (d) Benachrichtigungs-Modus Super+Alt+Z + Super+Alt+X, (e) Workspace-Modus `Q`, (f) Tray-Liste + Tray-Menü per Taste, (g) `docs/HOTKEYS.md` mit Modi-Tabelle | 🧑 Testpunkte unter „Neu“ |
| 23 | **PC-Beleuchtung beim Start**: alle RGBs fest in der Primärfarbe der Palette | 🟡 vorbereitet, wartet auf OpenRGB-Install: `scripts/rgb apply|off|color|status|plan`, Autostart-Zeile, nach Standby über hypridle `after_sleep_cmd`, `docs/RGB.md` (ohne openrgb mit Fake-Gerätescan getestet) | 🧑 `sudo dnf install openrgb openrgb-udev-rules` + udev neu laden, dann `scripts/rgb status` und `apply` |
| 14 | Terminal-Rätsel (viele Terminals gingen auf) | 🟡 50× Super+Return am 18.10. 20:09 (Taste oder Gerät), Details `docs/FORTSCHRITT.md` | bei Wiederholung `debug:disable_logs = false`, dann Log zeigt das Gerät |
| 13 | Repo-Umbau: `hyprland` → `main`, Repo/Ordner `shell`, `kwin`-Branch bleibt | ⚪ | nur auf Bastians Wort |
| 15 | PC neu aufsetzen: `system/bootstrap` für Fedora + Hyprland | 🟡 vorbereitet (dry-run ok, Hyprland Standard, KWin mit `--kwin`) | nach 13: echter Lauf |
| – | Login-Bildschirm im eigenen Look | 🟡 installiert, **ausgeschaltet** | 🧑 `scripts/loginscreen install` + `on` (sudo) |
| 21 | **Härten (ganz am Ende)**: Konsistenz-Durchgang über alle Module + Härtetest (Shell-Neustart, Monitor ab/an, Standby, viele Fenster/Workspaces, Dienste weg) | 🟡 statischer Teil fertig (Commit „AP 21 Härten“: Rückfall ohne DP-2, JSON-Schutz, Backoff, Dienste-Pfade); Runde 2 (19.10.): `qs log` durchgesehen, Warnungen der Fenster-/PipeWire-Wächter + Emoji-JSON behoben, größere Befunde als Liste in `FORTSCHRITT.md` | 🧑 dynamische Tests nach dem Call: Shell-Neustart, `hyprctl keyword monitor "DP-2,disable"`, Standby, Netz weg |

## Von dir

**Entscheiden:** Dashboard: Coding- und Stats-Kachel dauerhaft weg? · Mail: Thunderbird behalten (Empfehlung) oder Evolution?

**Mit sudo/Eingriff (du):**
1. Login: `scripts/loginscreen install` (sudo), dann `scripts/loginscreen on`
2. ~~Share-Picker~~ erledigt: Shell-Picker braucht kein sudo, ist aktiv (GTK-Variante nur noch optional)
3. Discord statt Equibop: in Discord (RPM) anmelden, Call testen; danach Equibop entfernen: `sudo dnf remove equibop` (Daten in `~/.config/equibop` bleiben bis du sie löschst)
4. Abendwärme: `sudo dnf install hyprsunset`; hypridle neu starten: `pkill hypridle; uwsm app -- hypridle &`
5. OCR im Snip: `sudo dnf install tesseract tesseract-langpack-deu tesseract-langpack-eng`
6. Klicken: Helium `helium://extensions` bei beiden ↻ · VS Code „Developer: Reload Window“ · Hue-App: Szene „Game“ anlegen (Spiele-Modus)
7. Thunderbird: Datenumzug Flatpak → RPM (`scripts/flatpak-to-native`), danach `python3 -I theme/gen/thunderbird.py apply`
8. PC-Beleuchtung (AP 23): `sudo dnf install openrgb openrgb-udev-rules`, dann `sudo udevadm control --reload-rules && sudo udevadm trigger` (oder Neustart); danach `scripts/rgb status` + `scripts/rgb apply`; hypridle neu starten (`pkill hypridle; uwsm app -- hypridle &`), dann Standby testen – Farbe kommt nach dem Aufwachen zurück (Details `docs/RGB.md`)

**Testen (fertig gebaut) – zum Abhaken: [docs/TESTLISTE.md](TESTLISTE.md):** Sound-Popout (Lautsprecher-Chip) · Netz-Popout (Netz-Chip) · Privatsphäre-Punkte in der Bar · Super (Dashboard) · Super+K · Super+P · Super+N (Gedanken) · Super+Return (Kitty) · Super+Shift+Return (Dropdown) · Super+Alt+K (Layouts) · Super+Alt+G/B/N (Spiele-Modus, Feierabend, Abendwärme) · Alt antippen / Alt+Esc (Workspace-Modus) · Alt+1…9 · Super+Shift+Pfeile (Fokus folgt) · Launcher-Präfixe (`?`) · Snip (T, C, P) · Ressourcen-Chip · Passwort-Panel (Super+O) · `pkexec true` · Super+L (GoXLR) · Session-Restore (`docs/SESSION.md`) · Quicklinks/Git an den Workspace-Kacheln · Benachrichtigungen (Snooze, Hover-Pause) · Morgen-Übersicht (`morning open`) · Kamin-Idle (`scripts/idle show force`)

## Neu (2026-10-18 spät, gebaut, wartet auf Test nach dem Stream)

- [ ] **AP 22 Bar-Modus**: Super+B → Buchstaben an den Chips; `S` öffnet Sound mit Tastatur, Pfeile/Tab bewegen den Glut-Rahmen, Enter löst aus, Esc → zurück zum Chip, nochmal Esc = Modus zu; ←/→ + Enter wählt Chips ohne Buchstaben
- [ ] **AP 22 Direkttasten**: Super+Alt+S (Sound), Super+Alt+L (Licht), Super+Alt+U (Server) – nochmal = zu; Popout schließt nicht durch Weghovern, Esc schließt
- [ ] **AP 22 Regler**: in Sound/Licht erst Enter auf einem Regler, dann ←/→ (vorher ändern Pfeile nichts)
- [ ] **AP 22 Benachrichtigungen**: Super+Alt+Z (bei offener Karte): ↑↓, Enter öffnet, 1–3 Knöpfe, S + 1–4 später erinnern, Entf weg, Esc zu · Super+Alt+X klickt die neueste weg
- [ ] **AP 22 Tray**: Super+B, T → ↑↓, → auf ⋮ (Menü) / Auge, Enter; im Menü ↑↓, Enter/→ Untermenü, ← zurück
- [ ] **AP 22 Schließ-Regel**: Spotify-Popout offen, Spotify holen (oder ein Fenster geht auf) → Popout bleibt; zu nur durch Weghovern (nachdem die Maus drin war), Esc, Chip-Klick oder anderes Popout
- [ ] **Licht-Chip** in der Bar (Birne neben dem Lautsprecher): Key Light, Hue-Szenen, Kamera – `$Q light open`
- [ ] **Workspace-Modus** jetzt per Alt antippen oder Alt+Esc, Entf löscht, Alt+←/→ markiert im Modus
- [ ] **Server im Dev-Popout** (`docs/SSHS.md`): eigener Server-Chip aufgelöst, Reiter **Server** im Dev-Popout = Web-Konsolen (Dokploy, Hetzner, INWX, Cloudflare aus `config/consoles.json`, Klick öffnet Helium) + sshs-Server mit Upload / Files / Terminal; Suche filtert mit; Dev-Chip immer da (Zahl nur, wenn etwas läuft) – Super+Alt+U, `$Q servers open`. Offen: Dokploy-URL in `~/.config/desktop/consoles.json`

Testen: `Q="qs ipc --any-display -p ~/Workspace/bastian-shell/shell call"`

- [x] ~~Launcher `?<text>` = FMHY-Suche~~ wieder entfernt (Bastian, 2026-10-19); Snippets bleiben raus
- [ ] Launcher `?<text>` = Websuche (Standard-Kürzel), neu `c <text>` = Claude fragen (`docs/LAUNCHER.md`) – Super, `?wetter`, `c hallo`
- [ ] Sound-Popout: oben Routing, dann Kanäle, unten Apps (`docs/MIXER.md`)
- [ ] Netz schlichter (`docs/NET.md`): Chip nur Symbol; Popout = Status-Zeile, Erreichbarkeit (Internet/Router/GitHub/Discord), Ø-Durchsatz letzte Stunde als Diagramm, Speedtest-Knopf, kein VPN-Bereich mehr; IP/Router unter „Details“ – `$Q net open`
- [ ] Hyperfokus-Wecker nach 90 min (`docs/BREAKS.md`) – `$Q breaks test` / `breaks hide`
- [ ] Projektzeit + Tagesrückblick (`docs/PROJECTTIME.md`) – Super+Alt+T, Super+Alt+R; Platz im Dashboard danach entscheiden
- [ ] Update-Chip (`docs/UPDATES.md`) – `$Q updates fake 5`
- [ ] Downloads-Popout (`docs/DOWNLOADS.md`) – `$Q downloads open`
- [ ] Dev-Dienste-Popout (`docs/DEVSERVICES.md`) – Test-Server starten, Chip erscheint, `$Q devservices toggle`
- [ ] Einheitlichkeits-Check (~35 Stilbrüche angeglichen: Processes-Suche/Reiter, Switcher ohne Glow, Snooze-Chips …)
- [ ] Eigener Share-Picker (`docs/SHARING.md`) – **aktiv seit 18.10. 23:50** (install + Portal-Neustart erledigt): in Discord „Share Screen“ → unsere Karte (Screens · Windows · Region). Rückweg `scripts/share-picker off` + Portal-Neustart
- [ ] Sound-Popout: „Other channels“ startet bei jedem Öffnen zugeklappt
- [ ] Spotify-Popout bleibt offen, solange die Maus drin ist (schloss sich z. B., wenn jemand Discord verlässt); schließt nach Weghovern wie die anderen Popouts
- [ ] Popout-Ecken schärfer: ein harter Schatten statt zwei verschmierter Ringe (`Glass.qml`, gilt für alle Flächen)
- [ ] Share-Picker übersteht Shell-Neuladen (Auswahl erscheint neu statt hängendem Standard-Picker; Instanz-Kennung `sharepicker instance`)
- [ ] Textdateien öffnen in VS Code (eigenes Fenster) statt Wordcraft – Doppelklick auf eine .txt/.md in Dolphin
- [ ] Eigenes Tray-Menü (Rechtsklick auf Tray-Symbole) · „App reagiert nicht“-Dialog im Desktop-Look
- [ ] Eigenes Layout-Menü (Super+Alt+K) und eigener Datei-Wähler (Launcher „Choose Folder…“, Snip S) – `$Q filepicker demo save`
- [ ] Super+Q räumt Discord/Spotify weg (Alt+F4 beendet), ohne Rutsch-Animation, rendern weiter im Versteck
- [ ] Privatsphäre-Punkte links neben der Uhr, Hover zeigt die Apps
- [ ] Helium-Menüs: Vergleich `scripts/helium-theme-compare` (Theme-Erweiterung vs. GTK), dann entscheiden
- [ ] Menüs im Desktop-Look (`docs/THEMING.md` „Menüs und Dialoge“): Helium-Farben aktiv ab nächstem Start (`scripts/helium-colors`; „Desktop Theme“ in Helium nicht laden) · GTK-Menüs neu (Rechtsklick in einer GTK-App) · Qt-Menüs: 🧑 `sudo dnf install kvantum` → `scripts/kvantum-theme on`
- [ ] Ordner öffnen in Kitty statt Dolphin: `xdg-mime default org.kde.dolphin.desktop inode/directory` (Bastian)
- [ ] Absturz-Karte statt DrKonqi (`docs/CRASHES.md`) – `$Q crash test` / `crash testRenderer` / `crash hide`; DrKonqi unter Hyprland aus, Rückweg `scripts/hypr drkonqi on`

## Fertig (39 von 44)

AP 1–5, 7, 8, 8b, 9, 10, 16 (vorbereitet), 17, 18, 19, 20 · AP 6a–6e (alle Fenster im Design) · AP 11 (Aufteilung Chat/Spotify) · **alle 18 Ideen** (a–q, s; r und t gestrichen)

## Zähler (Claude-Zentrale liest diese Liste: erledigt / gesamt)

Wird bei jedem fertigen Paket abgehakt. Reihenfolge: erst Fertiges, dann Offenes in der Arbeitsreihenfolge.

- [x] AP 1 Design-Basis deckend und freundlich (hearth)
- [x] AP 2 Workspace-Leiste freundlich und gut wählbar
- [x] AP 3 Benachrichtigungen: einheitliche Icons
- [x] AP 4 Ressourcen-Monitor und Bar-Stats
- [x] AP 5 Dashboard entlastet
- [x] AP 7 Passwörter: Favicons und WLAN ausblenden
- [x] AP 8 Equibop-Plugin gebaut (Aktivieren durch Bastian)
- [x] AP 8b Discord-Cams: im echten Call geprüft (19.10.), Kacheln unter der Bar
- [x] AP 9 Session-Restore (hyprflow) installiert
- [x] AP 10 Chrome-Reste aufgeräumt
- [x] AP 16 Share-Picker vorbereitet (Installieren durch Bastian)
- [x] AP 17 Eigener Passwort-Dialog und Paketmanager-Klick
- [x] AP 18 Mail-Client-Bewertung
- [x] AP 19 Lautstärke fix und GoXLR
- [x] AP 20 Workspace-Modus (Alt antippen oder Alt+Esc; Löschen schließt Fenster, letzter Workspace wird zurückgesetzt)
- [ ] Login-Bildschirm einschalten (Bastian: scripts/loginscreen on)
- [x] AP 6a Qt/KDE-Apps im Design
- [x] AP 6b GTK-Apps im Design
- [x] AP 6c Kitty, Konsole, Super+Return
- [x] AP 6d Helium, Thunderbird, VS Code
- [x] AP 6e Equibop (erkennbar als Discord), Spotify, Lockscreen, Login, Starship
- [x] AP 11 Fenster-Feinschliff 62/38
- [ ] AP 14 Terminal-Rätsel
- [ ] AP 13 Repo-Umbau auf shell
- [ ] AP 15 PC neu aufsetzen
- [ ] AP 22 Tastatur zuerst (alle Shell-Teile per Hotkey)
- [ ] AP 23 PC-Beleuchtung beim Start in der Primärfarbe
- [ ] AP 21 Härten: Konsistenz + Härtetest
- [x] Idee a Gedanken parken
- [x] Idee b Dropdown-Terminal
- [x] Idee c Abendwärme
- [x] Idee d Snip-Erweiterungen
- [x] Idee e Spiele-Modus
- [x] Idee f Fokus-Kopplung
- [x] Idee g Audio-Mixer
- [x] Idee h Netz-Popout
- [x] Idee i Privatsphäre-Punkt
- [x] Idee j Universal-Launcher
- [x] Idee k Fenster-Layout pro Projekt
- [x] Idee l Benachrichtigungen: Später erinnern
- [x] Idee m Morgen-Übersicht
- [x] Idee n Quicklinks an Workspaces
- [x] Idee o Git/CI pro Workspace
- [x] Idee p Feierabend-Routine
- [x] Idee q Kamin-Idle
- [x] ~~Idee s Text-Bausteine~~ entfernt (Bastian); die Ersatz-FMHY-Suche (`?`) am 2026-10-19 auch wieder raus

## Entschieden (Bastian, 2026-10-18)

| Thema | Entscheidung |
|---|---|
| Design | **Ganze Shell deckend und freundlich**, nicht glassy. **Wirklich alle Fenster** im Desktop-Design (Shell, Apps, Dialoge, Login). `CLAUDE.md`-Stilregel wird angepasst |
| Workspaces | **Nur größere Leiste** (kein Overlay): gut sichtbar, klarer aktiver Workspace, bequem wählbar |
| Commits | **Ein Commit pro Paket** auf `hyprland`. Kein Push, kein Repo-Umbau, keine Löschung ohne sein Wort |
| Favicons (Passwörter) | **Direkt von der Seite** (`favicon.ico`, `<link rel=icon>`, apple-touch-icon), gecacht, gedrosselt; Rückfall Buchstaben-Kachel |
| Discord-Client | **2026-10-18 spät: normales Discord (RPM) mit eigenem Equicord-Build statt Equibop**, Theme im Desktop-Look, aber klar als Discord erkennbar (Blurple) |
| Equibop (alt) | **Eigenes Equicord-Plugin `desktopBridge`** (Call-Status, Steuerung, Kamera-Kacheln anpinnen); Equicord selbst bauen. Bis es läuft: Calls im Flatpak-Discord. Discord erst entfernen, wenn Equibop funktioniert (sein Wort) |
| Terminal | **Kitty** im Desktop-Look (Super+Return), Konsole bleibt installiert |
| Chrome-Reste | **Aufräumen erlaubt** (GoXLR-Starter → Helium-Starter, alte `chrome-*.desktop` sichern + entfernen) |
| Reihenfolge | **Erst Design-Basis, dann Features** |
| Session-Restore | **hyprflow** (nicht hyprsession), vorbereitet in `scripts/session` |
| Bedienung (2026-10-19) | **Tastatur zuerst**: System komplett per Hotkeys (Muscle Memory), Maus nur in Browser und Apps |
| PC-RGB (2026-10-19) | beim Start alle RGBs **fest in einer Farbe** = Primärfarbe aus `theme/palette.json` (`accent`) |

## Spielregeln für die Umsetzung (Abwesenheit)

- Kein `sudo`, kein Push, kein Repo-Umbau, kein Löschen von Apps/Daten (Discord/Chrome-Pakete), keine Passwörter/Tokens loggen.
- **Eine Spur = ein Agent = eigene Dateien.** Gemeinsame Dateien (`shell/shell.qml`, `hypr/binds.conf`, `hypr/rules.conf`, `hypr/autostart.conf`, `Theme.qml`, `Glass.qml`) nur kleine Edits nach frischem Lesen; Design-Basis (AP 1) läuft allein auf `Theme.qml`/`Glass.qml`/`palette.json`.
- Jedes Paket: bauen → Shell lädt ohne Fehler (`qs log`) → Screenshot geprüft → `hyprctl configerrors` leer → **ein Commit** `AP n: Titel` mit Co-Authored-By-Zeile → Eintrag in `docs/FORTSCHRITT.md`.
- Schlägt ein Paket fehl: nicht committen, Befund in `FORTSCHRITT.md`, weiter mit dem nächsten.
- **Wartbar ohne KI** (Bastian): Features sind dateibasiert (`projects.json`, `config/*`, `theme/palette.json`), kurz dokumentiert in `docs/` und per Hand oder kleinem Dialog änderbar. Agenten sind zum Bauen da, nicht zum Betreiben.
- Neue Kürzel nur mit Titel `# …` in `binds.conf` (Super+K zeigt sie), danach `scripts/hotkeys-md`.
- **Jedes Shell-Feature mit Kürzel und voller Tastaturbedienung** (Pfeile, Enter, Esc, sichtbarer Fokus). Klick-/Hover-only = nicht fertig. Lieber wenige, logische Kürzel als viele Einzeltasten.
- Hauptsitzung koordiniert, prüft jeden Bericht und fasst am Ende alles auf einer Seite zusammen.

## Anhang: Erledigtes (Verlauf)

- ✅ Blur-Fehler · Kacheln als Standard · Kürzel (Super = Fenster/Monitore, Alt = Workspaces, `docs/HOTKEYS.md`, Super+K)
- ✅ Workspace-Leiste größer („Workspaces“, Namen nach Platz) · Bar reserviert Platz, im echten Vollbild ganz weg
- ✅ Discord/Spotify gekachelt und folgen allen Workspaces · Equibop-Grundumstellung (`Chat.qml`, Bridge erkennt „unsupported“)
- ✅ Medien-OSD · Keybind-Viewer (Super+K) · Paketmanager (Super+P) · Helium (Lesezeichen, Theme, Standardbrowser)
- ✅ Vorbereitet: Session-Restore (`scripts/session`), Login-Look (`scripts/loginscreen`), Kamera-Recherche (`docs/DISCORD-CAMS.md`)

## Anhang: Paketdetails (inkl. Erledigtes)

### Phase 1 – Basis (parallel, getrennte Dateien)

| AP | Paket | Fertig, wenn … | Dateien |
|---|---|---|---|
| 1 | **Design-Basis deckend + freundlich** (alleine auf den Kern-Dateien) | neue Palette (wärmere, hellere, freundlichere Töne, klare aktiv/inaktiv-Zustände), `Glass.qml` liefert deckende Flächen, Blur über ein Theme-Flag aus, alle Module laden ohne Fehler; Vorher/Nachher-Screenshots von Bar, Dashboard, Launcher, OSD; `CLAUDE.md` Stilregel + `docs/THEMING.md` angepasst | `theme/palette.json`, `theme/gen/*`, `shell/config/Theme.qml`, `shell/components/Glass.qml` |
| 10 | **Chrome-Reste aufräumen** | GoXLR-Helium-Starter mit Icon (`helium --app=http://localhost:14564`), alte `chrome-*.desktop` gesichert unter `~/.local/state/desktop/` und entfernt, keine Fehler-Benachrichtigung mehr | `~/.local/share/applications/chrome-*`, `docs/THEMING.md` |
| 9 | **Session-Restore** (braucht `cargo`) | `scripts/session install/build/dry-run` laufen, Autosave-Timer aktiv, ein Test-Restore mit 2–3 Fenstern (nach Absprache auf einem freien Workspace) | `scripts/session*`, `config/hyprflow/*`, `systemd/desktop-session-*` |

### Phase 2 – Sichtbares (nach AP 1, parallel)

| AP | Paket | Fertig, wenn … | Dateien |
|---|---|---|---|
| 2 | **Workspace-Leiste freundlich + gut wählbar** | aktiver Workspace sofort erkennbar (Farbe/Rahmen/Größe), große Vorschauen, Klick wählt, Tasten (Alt+1…9) zeigen kurz an, kein Glas | `WorkBar.qml`, `AppStrip.qml` |
| 3 | **Benachrichtigungen + OSD: Icons** | einheitliche Material-Symbole je Art (Snip, Fehler, Mail, Medien …), kein leeres Quadrat, App-Icon nur wenn vorhanden | `shell/modules/notifications/*`, `shell/modules/osd/*`, `NotifsTile.qml`, `Notifs.qml` |
| 4 | **Ressourcen-Monitor + Bar-Stats** | Bar neben dem Chat-Bereich: CPU/RAM/GPU/Netz-Chips; Klick öffnet Popout wie das Referenzbild (Reiter All/User/System, Suche, Kopf mit Rechner/Uptime + Ringe, Tabelle Name · CPU · Memory · PID sortierbar, Details aufklappbar, Beenden mit Rückfrage) | neue `shell/modules/bar/Resources*.qml`, `shell/services/Procs.qml` |
| 5 | **Dashboard entlasten** (nach 4) | Stats-/System-Kacheln raus oder klein; Dashboard = Uhr, Termine, Mail, Medien, Fokus, Licht | `shell/modules/dashboard/*` |
| 7 | **Passwörter: Favicons** | Logos statt Buchstaben (direkt von der Seite, Cache `~/.cache/desktop/favicons`, gedrosselt, Rückfall Buchstabe), Panel im neuen Design | `shell/modules/passwords/*`, `shell/services/Favicons.qml` |

| 17 | **Eigener Passwort-Dialog + Paketmanager-Klick** | (a) Wenn Root-/Admin-Passwort nötig ist (pkexec, Systemeinstellungen, Paketmanager), erscheint ein **Dialog im Shell-Design** statt des KDE-Fensters: Quickshell hat dafür ein Polkit-Modul (`Quickshell.Services.Polkit`, 0.3.2 vorhanden), eigener Agent ersetzt `polkit-kde-authentication-agent-1` (Autostart-Zeile in `hypr/autostart.conf`); mit Rückfall: läuft die Shell nicht, startet der KDE-Agent weiter (kein Aussperren), Fehlversuche/Abbrechen/Fingerabdruck sauber; (b) Klick ins Leere hinter dem Paketmanager schließt ihn zuverlässig (nur nicht während einer laufenden Aktion; prüfen: `HyprlandFocusGrab` + Backdrop in `Packages.qml`), Esc ebenso | neue `shell/modules/polkit/*`, `hypr/autostart.conf` (eine Zeile), `shell/modules/packages/Packages.qml` (nur Schließlogik) | nach AP 1 (Design); Test: harmloser `pkexec true` |

### Phase 3 – Breite und Große

| AP | Paket | Fertig, wenn … | Dateien |
|---|---|---|---|
| 6 | **Alle Fenster im Desktop-Design** (Unter-Agenten je App-Familie) | (a) Qt/KDE (Dolphin, Kate, Systemeinstellungen …): Farbschema/Stil; (b) GTK/libadwaita (inkl. Flatpak): `gtk.css`/Theme; (c) **Kitty** (`theme/gen/kitty.py`, Kürzel, Super+Return); (d) Electron: **Equibop als finaler Discord-Client**: Equicord-Theme/CSS dezent im PC-Look (Flächen, Schrift, Farben aus der Palette), aber **als Discord erkennbar** (Layout, Icons, Server-/Kanal-Struktur, ein gedämpfter Discord-Akzent bleiben, damit man sich zurechtfindet und nichts zu stark vertauscht ist), Spotify (Spicetify, falls machbar), VS Code, Claude Desktop; (e) Steam, Thunderbird (da), Helium (da); (f) Dialoge/Portale, Cursor, Schriften, Icons; (g) Login-Look an Palette angeglichen. Liste „noch nicht im Look“ am Ende in `docs/THEMING.md` | `theme/gen/*`, `docs/THEMING.md`, App-Konfigurationen |
| 8 | **Equibop-Plugin `desktopBridge`** | pnpm user-lokal, Equicord geklont + gebaut, Plugin liefert Call-Status/Mic/Taub/Köpfe + Kamera-Frames (gepinnte, 360p, 10 fps) über 0600-Socket an die Shell; Bar zeigt Köpfe, Klick pinnt Kamera (max. 3 unter der Bar auf DP-2); Equibop auf eigenen `dist`-Ordner umgestellt; Rückweg dokumentiert | `docs/DISCORD-CAMS.md`, `scripts/discord-bridge`, `shell/modules/bar/Discord*.qml`, neue Cam-Kacheln |
| 11 | **Fenster-Feinschliff** | Chat-Fenster (Equibop) + Spotify nach „Holen“ wieder 62/38, Chips getestet | `WorkBar.qml`/`Parked.qml` (nur Aufteilung) |
| 18 | **Mail-/Kalender-Client im Theme** | Bewertung (nur Recherche, keine Umstellung): Thunderbird (heute, schon im Look), Betterbird, Geary, Evolution, KMail, Mailspring, Terminal-Clients. Kriterien: iCloud-Konten (IMAP/CalDAV/CardDAV), Kalender, Push, Mail-Wächter (Codes kopieren) weiter nutzbar, Theme-Fähigkeit (Palette/CSS), Pflege, Wayland. Ergebnis: Tabelle + Empfehlung in `docs/MAIL.md`; Bastian entscheidet, dann Umzug als eigenes Paket | `docs/MAIL.md` (neu) | nur Recherche (Phase 3) |
| 16 | **Bildschirm-teilen-Auswahl im Desktop-Design** (Discord/Equibop, Browser, OBS) | Statt des schlichten Standard-Pickers erscheint beim Teilen eine eigene Auswahl mit Vorschauen von Monitoren und Fenstern, im Look der Shell. Basis: [hyprland-preview-share-picker](https://github.com/WhySoBad/hyprland-preview-share-picker) (Rust, GTK4 + layer-shell, MIT, 102 Sterne, noch kein Release; Einbindung über `xdph.conf` → `screencopy { custom_picker_binary = … }`; Styling über eigene CSS-Dateien in `config.yaml`). Schritte: Quellcode prüfen (Fremdcode), mit Rust bauen (README nennt nightly; mit `cargo` aus Fedora oder `RUSTC_BOOTSTRAP` prüfen, sonst Alternative: eigener Picker als Quickshell-Overlay), CSS aus der Palette erzeugen (`theme/gen/share_picker.py`), `~/.config/hypr/xdph.conf` + Config im Repo, Fensterregel für den neuen Picker in `rules.conf` (bisher `hyprland-share-picker`), Test mit Equibop/Helium/OBS (Vesktop-Familie bringt evtl. eine eigene Auswahl mit – prüfen) | `theme/gen/share_picker.py` (neu), `config/xdph/*`, `config/share-picker/*`, eine Regel in `hypr/rules.conf`, `docs/SHARING.md` | **Planung** (nach AP 1, braucht `cargo`) |
| 14 | **Terminal-Rätsel** | Ursache gefunden, falls es wieder passiert (Journal + `hyprctl clients` sofort prüfen) | — |

### Phase 4 – Ideen (von Claude vorgeschlagen, Bastian streicht, was er nicht will)

| AP | Idee | Nutzen |
|---|---|---|
| 12a | **Gedanken parken** (Super+N): Eingabefeld, Notiz geht in eine Inbox-Datei und optional als To-do | Idee loswerden, ohne den Fokus zu verlieren |
| 12b | **Dropdown-Terminal** (Kitty auf einer Taste, Hyprland-Spezial-Workspace) | schneller Befehl ohne Fenster-Chaos |
| 12c | **Abendwärme** (hyprsunset): Bildschirm wird abends automatisch wärmer, passt zum Kaminfeuer; optional Theme-Variante nach Tageszeit | Augen, Stimmung |
| 12d | **Snip-Erweiterungen**: Text aus Bild (OCR), Farbpipette, Screenshot an den Bildschirm anpinnen | Alltag |
| 12e | **Spiele-Modus** auf einer Taste: Bar weg, Benachrichtigungen aus, Hue-Szene, Chat leiser | mehr als nur Vollbild-Erkennung |
| 12f | **Fokus-Kopplung**: Fokus-Timer schaltet Licht-Szene, „Nicht stören“ und Chat-Status mit | Fokus ohne Handarbeit |
| 12g | **Audio-Mixer-Popout**: Lautstärke pro App, Ausgang wechseln (GoXLR-Routing dabei) | ein Ort für Ton |
| 12h | **Netz-Popout**: LAN/WLAN, Tailscale/WARP an/aus, Ping | passt zu den Vendor-Repos |
| 12i | **Privatsphäre-Punkt** in der Bar, wenn Kamera, Mikro oder Bildschirmfreigabe aktiv ist | Sicherheit auf einen Blick |
| 12j | **Universal-Launcher**: Passwörter, Web-Kürzel (g, yt, gh), Kalender, Helium-Tabs | eine Suche für alles |
| 12k | **Fenster-Layout merken** pro Projekt (VS Code + Helium + Kitty auf eine Taste) | Projektwechsel in 1 Sekunde |
| 12l | **Benachrichtigungen**: „Später erinnern“ (Snooze) + Ruhezeiten | weniger Ablenkung |
| 12m | **Morgen-Übersicht** beim ersten Login des Tages: Termine, Mails, Wetter, offene To-dos | guter Start |
| 12n | **Quicklinks an den Workspaces** (statt Dev-Server-Übersicht): pro Projekt-Workspace ein paar Links/Ports (localhost:3000, Repo, Board), Klick öffnet Helium. Daten stehen in `projects/projects.json`, **von Hand pflegbar** (Datei oder kleiner Editor-Dialog), keine Agenten nötig | Bastian: Features sollen auch ohne KI nutzbar und pflegbar sein |
| 12o | **Git-/CI-Status pro Projekt-Workspace** in der Workspace-Leiste (Branch, ungespeicherte Änderungen, letzter CI-Lauf) | Projektstand auf einen Blick |
| 12p | **Feierabend-Routine** auf einer Taste: Fokus aus, warmes Licht, Bildschirm dimmen, Musik an | sauberer Schnitt zwischen Arbeit und Abend |
| 12q | **Kamin-Idle**: nach Leerlauf ein ruhiger Kamin-/Glut-Bildschirm (sparsam, kein Dauer-Rendern) statt schwarzem Schirm. **UI freundlich und ruhig, nicht glowy/glassy/dynamisch** | Thema „Holzhütte am Abend“ (Bastian: ja) |
| 12s | **Text-Bausteine** im Launcher: Floskeln, Adresse, Befehle einfügen | schnelles Tippen, wenig Merken |
| ~~12t~~ | ~~Kalender-Popout + Wallpaper-Galerie~~ | **gestrichen** (Bastian: Kalender/Mail läuft in Thunderbird) → siehe AP 18 |
| ~~12r~~ | ~~Fokus-Dimm~~ | **gestrichen** (Bastian: nein) |

### Phase 4b – Tastatur und Hardware (2026-10-19)

| AP | Paket | Fertig, wenn … | Dateien |
|---|---|---|---|
| 22 | **Tastatur zuerst** | (a) jedes Bar-Popout per Taste erreichbar (Schema wählt Bastian), (b) in allen Popouts/Panels Pfeile/Tab, Enter, Esc und sichtbarer Fokus, (c) Fenstergröße per Taste (z. B. Super+Alt+Pfeile), (d) Benachrichtigungen: neueste öffnen/Aktion/Wegklicken/Snooze per Taste, (e) Workspace-Modus: Quicklinks und Git der Kachel per Taste, (f) Tray-Menü per Taste, (g) Super+K zeigt alles, `docs/HOTKEYS.md` neu | `hypr/binds.conf`, `shell/modules/bar/*Popout.qml`, `shell/modules/notifications/*`, `shell/modules/workbar/*` |
| 23 | **PC-Beleuchtung beim Start** | OpenRGB (headless, `--noautoconnect`) setzt beim Login alle Zonen (Mainboard, NZXT, RAM) statisch auf `accent` aus `theme/palette.json`; `scripts/rgb apply|off`, Autostart-Zeile, Doku `docs/RGB.md` | `scripts/rgb`, `hypr/autostart.conf` (eine Zeile), `docs/RGB.md` |

### Phase 5 – Abschluss (nur auf Bastians Wort)

| AP | Paket | Hinweis |
|---|---|---|
| 13 | **Repo-Umbau** `hyprland` → `main`, KWin-Stand als Branch `kwin`, Ordner/Repo `shell`, Pfade (systemd, Hyprland, Starship, bootstrap), `CLAUDE.md` + `SPEC.md` für Hyprland | allein, alle anderen pausieren; Backup vorher |
| 15 | **PC neu aufsetzen**: `system/bootstrap` für Fedora + Hyprland (Pakete, Dotfiles, Session-Restore, Helium, Equibop, Kitty) | nach 13 |
| – | **Discord entfernen** (Flatpak/RPM), wenn Equibop-Plugin funktioniert | nur auf Bastians „funktioniert“; RPM-Entfernen = sudo durch Bastian |

## Abschlussprüfung (nach Phase 4)

- Ein Prüf-Agent geht alle Module durch (Screenshot je Modul auf DP-2, zusätzlich HDMI-A-2/DP-1, wo sinnvoll), meldet Stilbrüche und Fehler im `qs log`.
- `docs/HOTKEYS.md` neu erzeugt, `docs/FORTSCHRITT.md` vollständig, offene Punkte als Liste.
