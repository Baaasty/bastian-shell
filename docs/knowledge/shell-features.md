# Shell-Features – was man nicht aus dem Code sieht

Was jedes Feature tut, steht als eine Zeile in [docs/PRD.md](../PRD.md); Kürzel in [hotkeys.md](hotkeys.md); hier nur Konfiguration, Grenzen und Stolperfallen.

Allgemein: IPC-Funktionen heißen `open` statt `show` – `qs ipc` hält „show“ für den eigenen Unterbefehl.

# Bar & Popouts

## Bar-Popouts: auf und zu
Code: `shell/modules/bar/PopoutGuard.qml` (eine Stelle für alle), `shell/services/Popouts.qml` (`claim`, `modal`, `changedAt`)
- Per Maus geöffnet (Hyprland): kein Qt-Popup-Grab, sondern `hyprland_focus_grab` mit Popout **und** Bar → Chips behalten Hand-Zeiger, Hover, Tooltip; Klick auf einen anderen Chip wechselt direkt.
- Zu nur durch: Klick außerhalb, Esc, eigener Chip, anderes Popout, Weghovern (800 ms, nur wenn die Maus drin/auf dem Chip war). Endet der Fang ohne Klick (Fenster/Ebene auf/zu, Arbeitsfläche, Discord/Spotify), bleibt das Fenster stehen und fängt neu – kein Zu→Auf-Flackern.
- Grenze: Ein Klick in ein *nicht fokussiertes* Fenster kommt bei uns nicht an (Hyprland fokussiert vorher um) – erkannt daran, dass in den 1,2 s davor kein Hyprland-Ereignis wie `openwindow`/`openlayer`/`workspace` kam (`Popouts.changedAt`).
- Vorrang: Share-Picker ruft `Popouts.hold(true)` → alle Popouts zu, keins holt sich Fokus/Fang zurück. Nimmt ein anderes Shell-Fenster die Tastatur (Launcher …), geht das Popout zu. Höchstens 4 Neu-Fänge in 10 s, danach offen ohne Fang.
- Per Taste geöffnet (Bar-Modus, Super+Alt+…) und KWin: alter Weg (Qt-Grab, schließt der Compositor, kommt es ohne Fang zurück, die Bar reicht die Tasten weiter).
- Stolperfalle (Qt 6.11 / Quickshell 0.3.2): nie `parent:` per Binding an etwas hängen, das sich mit `QsWindow.window` ändert. Das feuert, während Qt den Baum beim Ein-/Ausblenden eines Fensters (Bar bei Vollbild) durchläuft; das Item zählt das Fenster dann doppelt und zeigt später auf ein gelöschtes → SIGSEGV in `setParentItem`. Deshalb hängt der Guard seine Bar-Fläche verzögert und nur auf ein vorhandenes Fenster um.

## Sound-Mixer
Code: `shell/services/Mixer.qml`, `shell/modules/bar/MixerPopout.qml`, GoXLR-Teil `shell/components/GoxlrPanel.qml` + `GoxlrLevel.qml` · Konfig: `~/.config/desktop/audio.json` (100-%-Wächter, docs/setup/goxlr.md)
- Ausgangs-/Eingangswahl bewusst entfernt (fest: GoXLR System / Chat Mic); der Mixer schreibt nur in App-Streams, nie in einen Ausgang.
- `GoxlrPanel` ist dasselbe Widget für Popout und Dashboard-Kachel (`ControlsTile.qml`): Pegel/Routing nur dort ändern.
- Lautloser Test-Stream: `pw-play -P '{ application.name = "mixertest" }' datei.wav`.

## Netz
Code: `scripts/netinfo` (Test `scripts/tests/netinfo-test.py`), `shell/services/NetInfo.qml`, `Net.qml`, `shell/modules/bar/NetPopout.qml` · Konfig: `~/.config/desktop/net.json` (optional; ≤ 6 Ziele, `count` 1–5, `gateway` = Standardroute)
- „Online“ heißt: ein Ziel außer dem Router antwortet. Hosts nur Buchstaben, Ziffern, `. : - _`.
- Durchsatz-Verlauf liegt nur im Speicher: nach Shell-Neustart leer, erster Punkt nach 1 min.
- Kein VPN-Bereich mehr (Tailscale deinstalliert 2026-10-19).

## Dateimanager, Browser & Downloads
Code: `shell/modules/bar/FilesChip.qml`, `BrowserChip.qml`, `DownloadsPopout.qml`, `shell/services/Downloads.qml` · Konfig: `~/.config/desktop/downloads.json` (optional)
- Downloads-Chip 2026-10-20 raus (zu laut): die Liste hängt jetzt als Rechtsklick am Dateimanager-Chip (Bar-Modus `D`), „neu“ zeigt kein Chip mehr. Beide Chips im Fokus-Modus ausgeblendet.
- Ordner-Ereignisse über `scripts/inotify-watch` (inotify per Python-ctypes, Ersatz für das fehlende `inotifywait`); endet er (Ordner fehlt), Neustart 2 s … 60 s.
- Dateimanager fest Dolphin (wie Super+E): `xdg-mime` für `inode/directory` zeigt auf `kitty-open`. Browser-Chip erkennt Helium an der Fensterklasse; Super+B (alt: Super+W) startet ohne Shell Helium direkt.
- Aufräumen nur per `gio trash`, nie löschen. `gio trash` geht nicht auf tmpfs → Tests mit einem Ordner unter `~` (`downloads testDir`).
- iCloud jetzt synchronisieren (Launcher, Wolken-Knopf, Dolphin): nur über die Unit, damit Sperre und oneshot wie beim Timer greifen. Der Dolphin-Eintrag steht an jedem Ordner – KIO kann Service-Menüs nicht nach Pfad filtern.

## Gear (PC-Licht, Maus)
Code: `shell/modules/bar/GearChip.qml`, `GearPopout.qml`, `shell/services/Devices.qml`, Backends `scripts/rgb`, `scripts/mouse` (Tests `scripts/tests/rgb-test.py`, `mouse-test.py`) · Konfig: `~/.config/desktop/rgb.json`, Zustand `~/.local/state/desktop/rgb-state.json`
- PC-Licht: jede Änderung ist ein voller OpenRGB-Lauf (~25 s); Balken gehen erst 1,5 s nach der letzten Bewegung raus, was während eines Laufs kommt, läuft danach (nur das Letzte). Farbe = Token in `rgb.json`, Boot/Standby nehmen dieselbe.
- Maus: alles Entwurf bis „Save to mouse“ – das schreibt ins Onboard-Profil (Flash, begrenzte Schreibzyklen), darum nie bei jeder Bewegung. DPI-Balken 100–6400 (Maus kann bis 25600, per `scripts/mouse save`).
- Abfragen nur bei offenem Popout (rgb 5 s, Maus 60 s), sonst Maus alle 10 min für die Akku-Warnung (< 15 %, nicht am Laden). Schläft die Maus, bleiben die letzten Werte grau stehen.
- Einstellungen-Chip (`SettingsChip.qml`): startet `systemsettings.desktop` (Override in `config/applications/` mit `SDL_HIDAPI_LIBUSB=0`, sonst 15–17 s Hänger), Seiten mit derselben Umgebung. KScreen (Display) braucht KWin → keine Display-Seite.

## Spotify
Code: `shell/services/SpotifyApi.qml`, `shell/modules/bar/Spotify*.qml`, Backend `scripts/spotify-api` · Cache: `~/.cache/desktop/spotify/` (`now.json` letzter Stand, `ratelimit.json` Budget/Pause, `blocked-until` Sperre der Shell; löschen = zurücksetzen)
- Vorladen nur bei laufendem Spotify: 10 s nach Shell-Start, dann still bei Songwechsel (1,2 s warten, höchstens alle 20 s, beim Durchskippen nur einmal); Popout zeigt sofort `now.json` und lädt nur nach, wenn älter als 10 s oder anderer Song.
- „Als Nächstes“ ab dem aktuellen Song; Songwechsel schneidet sofort per MPRIS ab. Ohne Shuffle: Warteschlange nur selbst Eingereihtes; mit Shuffle: Gehörtes (Sitzung + recently-played, 5 min Cache) raus.
- Budget im Skript für alle Aufrufe: 20 Anfragen / 60 s; nach 429 Pause = Retry-After, mind. 30 s, verdoppelt bis 15 min, Erfolg setzt zurück. Playlist-Kopf 5 min gecacht.
- Ein `now` kostet meist 2 Anfragen (Warteschlange + Player), Seiten nur bei neuer `snapshot_id`. Spotify-eigene Playlists kommen über die Einbett-Seite (max. ~100 Songs, aktueller Song fehlt dann evtl.).
- Frisch gestartetes Spotify lädt nichts (MPRIS: Stopped, CanPlay=false) – Play geht dann über `spotify-api resume` (Web API, dieses Gerät). Ohne Spielstand bei Spotify startet der letzte gehörte Song von vorn (recently-played kennt keine Position).

## Update-Chip
Code: `shell/services/Updates.qml`, `shell/modules/bar/UpdatesChip.qml`, Backend `scripts/pkg` · Zustand: `~/.local/state/desktop/updates.json` (löschen = beim nächsten Start neu prüfen)
- Installiert nie selbst – nur der Paketmanager (Super+P).

## Privatsphäre-Punkte
Code: `shell/services/Privacy.qml`, `shell/modules/bar/PrivacyDot.qml`, `scripts/privacy-cam` · Konfig: keine
- Bleiben bewusst auch im Fokus-Modus sichtbar.
- Kamera ohne Polling: ein Wächter (`scripts/privacy-cam`, gestartet von `Camera.qml`) bekommt open/close auf `/dev/video*` per inotify (Python-ctypes, kein inotify-tools) und meldet Apps + Facecam-Stream für Punkte und Helligkeit zugleich. Punkt erscheint ~0,4 s nach dem Öffnen; „streamt“ (`urbnum`) wird nur bei offener Kamera sekündlich gemessen. Sicherheitsnetz: alle 60 s nachsehen, stirbt der Wächter → Neustart 2 s … 60 s. Testen: `scripts/privacy-cam once`.
- Discord hält das Mikro nach Call/Mikrotest offen: gemeldet wird es nur im Sprachkanal (`Discord.inVoice`). Andere Apps mit „idle“ gehaltenem Aufnahme-Stream zeigen den Punkt trotzdem.
- Unsichtbar bleiben Kamera-Zugriffe ohne PipeWire und ohne offenes `/dev/video` (z. B. fremde Benutzer).

## Key Light mit der Kamera
Code: `shell/services/CamLight.qml` (Logik `camlight.js`, Test `scripts/tests/camlight-test.js`) · Konfig: `~/.config/desktop/keylight.json` `{"autoCamera": false}` = aus (fehlt = an) · IPC `camlight status|enable|disable|toggle`
- Quelle ist die Kamera-Erkennung der Privatsphäre-Punkte (`Privacy.camLive`, ohne `privacy simulate`): 1,5 s Kamera an → Licht an, 5 s aus → Licht aus.
- Aus schaltet sie nur, was sie selbst eingeschaltet hat – und nur, wenn Helligkeit/Kelvin noch so sind wie beim Einschalten. War es schon an oder hat Bastian es geschaltet/verstellt (Popout, Elgato-App, Taste), bleibt es.
- Gesperrt oder ≥ 4 min Leerlauf: kein Einschalten. „Gehört der Automatik“ steht in `$XDG_RUNTIME_DIR/desktop-camlight.json` (übersteht `scripts/hypr restart`).
- Licht offline: eine Logzeile `camlight: Key Light not reachable`, sonst nichts (Abfrage max. 2 × 3 s).

# Workspaces & Fenster

## Dropdown-Terminal
Code: `scripts/dropterm` (`WIDTH`/`HEIGHT`/`GAP`), Regel am Ende von `hypr/rules.conf`
- Bewusste Ausnahme von „nichts schwebt“: nur Klasse `kitty-drop` schwebt.
- Die Prozente in `rules.conf` gelten nur fürs allererste Öffnen, danach setzt das Skript Größe/Platz → beide Stellen anpassen.
- Gehört nicht zu Session-Restore oder `layout save` (Klasse nicht in der Positivliste). Hakt es: `scripts/dropterm kill`.

## Fenster-Layouts
Code: `scripts/layout`, `shell/modules/layouts/` · Konfig: `config/layouts/<name>.toml` (von Hand ändern erwünscht, prüfen mit `restore <name> --dry-run`), Positivliste `config/hyprflow/config.toml`
- Abgrenzung: Session-Restore = automatisch, alles; Layout = benannt, ein Desktop; Vorlagen (`profiles/`) legen neue Desktops an, Layouts füllen den aktuellen.
- Kacheln ergeben sich nur aus der Startreihenfolge (dwindle); `box` ist nur Info. Ab 3 Fenstern kann links/rechts vom Original abweichen.
- Restore ~0,6 s je Fenster (VS Code/Helium bis 25 s) – währenddessen nicht tippen. „Kein neues Fenster nach 25 s“ = App nahm ein bestehendes Fenster, kein Fehler.
- `cmd` muss mit dem Programm der Klasse beginnen (kein `sh -c`); schwebende Fenster werden nicht gemerkt. Neue App = `[apps."<Klasse>"]` in der hyprflow-Config (gilt auch für Session-Restore).

## Bildschirm teilen
Code: `scripts/share-pick` (Brücke xdph ↔ Shell), `shell/modules/sharepicker/SharePicker.qml`, `scripts/share-picker` · Konfig: `~/.config/hypr/xdph.conf` (`custom_picker_binary`)
- xdph liest seine Config nur beim Start; der Portal-Neustart bricht laufende Streams/Calls ab. Rückweg: `scripts/share-picker off` + Neustart.
- Protokoll gegen xdph 1.4.1 geprüft (wartet auf stdout **und** stderr, schneidet bei `screen:` ein Zeichen ab) – nach xdph-Updates neu prüfen.
- Log `~/.local/state/desktop/share-pick.log` (xdph verwirft stderr). Equibop überspringt unter Wayland seine eigene Auswahl → unsere Karte kommt.
- Merken (Haken „Remember this choice“ oder Shift+Enter) macht `share-pick` selbst: Discord schickt xdph nie `restore_data`
  (fragt mit `persist_mode` 0/1), Restore-Tokens bringen also nichts. Gemerkt in `~/.local/state/desktop/share-picker.json`
  je App; Fenster über die Klasse, nur wenn eindeutig. Danach teilt es ohne Karte (Benachrichtigung). `scripts/share-picker remembered` · `forget [app]`.
- Welche App fragt: xdph gibt die App-ID nicht weiter → `share-pick` liest die offene Portal-Anfrage per `busctl` (Absender →
  Programmname, Discords Versionsordner egal), sonst Ansage der Shell (`--expect`), sonst aktives Fenster. Früher nur das
  aktive Fenster: Klick in der Bar bei aktivem VS Code → Merkung landete bei `com.microsoft.vscode`.
- `xwaylandvideobridge` (Plasma-Autostart) fragt beim Teilen aus Discord gleich mit – die Karte nennt die fragende App.
- Teilen-Menü am Privatsphäre-Punkt (Klick, Bar-Modus P, Super+Alt+P; Mittelklick = alles stoppen): je Freigabe App + was sie
  sieht (letzte Antwort von share-pick, `$XDG_RUNTIME_DIR/desktop-share-pick/answers.json`) + Stop. Stop für jede App über
  `scripts/share-stop` (zerstört nur den Screencast-Node von xdph in PipeWire; Portal-`Session.Close` geht nicht – nur die App
  darf, und Discord schließt seine Session direkt nach dem Start). Discord mit Plugin stoppt übers Plugin.
- Live-Quellwechsel geht unter Wayland nicht (Discord fragt das Portal nicht neu; Neustart-Weg beendete den Stream) – verworfen
  2026-10-20. Andere Quelle = stoppen und in der App neu teilen.
- xdph wartet blockierend auf `share-pick` – hängt es, hängt jedes weitere Teilen (20.10.: Region für Discord → Discord fragte in
  Schleife, Portal-Neustart nötig). Darum: hartes Zeitlimit je Anfrage (60 s + 20 s), eine Anfrage nach der anderen (Sperre),
  Reiter Region nicht für Discord & Co., Region nie gemerkt. `share-stop` liest nur `pw-cli ls` (pw-dump hängt mit xdph).
- Die Karte bricht nur bewusst ab (Esc, Cancel, Klick daneben/auf anderen Monitor); endet ihr Fang ohne Klick, fängt sie neu.
- GTK-Alternative (hyprland-preview-share-picker, Commit `7e11349` geprüft, `PIN` im Skript) braucht sudo-Pakete; Tastatur erst nach Klick.

# Launcher

## Launcher
Code: `shell/modules/launcher/Launcher.qml` (`sources`, `parse()`, `rebuild()`), `shell/services/LauncherSources.qml`, `WebShortcuts.qml` · Konfig: `config/launcher/web.json`, Zähler `~/.local/state/desktop/launcher.json` (nur IDs, nie Suchtexte)
- `web.json`: das erste Kürzel ist die Websuche, die ohne Präfix immer als letzte Zeile steht – darum kein eigener Websuche-Präfix; `url` braucht `http(s)://` + `{q}`; `c` ist reserviert. Kaputte Einträge → „Config problem“ im Web-Modus.
- `c `: `claude://` an Claude Desktop (distrobox „ubuntu“), wenn `xdg-mime query default x-scheme-handler/claude` einen Handler hat, sonst claude.ai in Helium; geprüft einmal pro Shell-Start.
- `@` braucht Helium mit Erweiterung „Desktop“ (`scripts/chrome-ext status`).
- Verworfen (nicht wieder einbauen): Text-Bausteine `s `, FMHY-Suche; seit 2026-10-20 auch Präfixe für Emoji, Zwischenablage, Passwörter, Termine, Mail und `?`: zu viele Modi, die je ein eigenes Panel/Popup schon besser kann (Passwort-Panel, Agenda-/Mail-Kachel, Zwischenablage-/Emoji-Popup).

## Zwischenablage und Emoji
Code: `shell/modules/clip/InlinePopup.qml` (gemeinsame Basis: Position, Ziel-Fenster, Karte), `ClipPopup.qml`, `EmojiPopup.qml`, `shell/services/Clipboard.qml` (`terminalClasses`, `pasteDelay`), `Emoji.qml`, `scripts/clip-paste` · Favoriten `~/.local/state/desktop/clip-pins.json`, zuletzt benutzte Emoji `emoji-recent.json`
- Popup an der Maus, wenn sie im aktiven Fenster steht, sonst im unteren Drittel des Fensters (Schreibmarke fremder Apps ist unter Wayland nicht abfragbar); am Rand eingeklemmt, unten kein Platz → über der Maus.
- Enter = kopieren + einfügen: Ziel-Fenster wird beim Öffnen gemerkt; nach `pasteDelay` (Panel weg) holt `clip-paste` den Fokus nur zurück, wenn er woanders gelandet ist, und schickt dann Strg+V per `hyprctl dispatch sendshortcut` (Klasse in `terminalClasses` → Strg+Shift+V). Shift+Enter = nur kopieren.
- Warum zurückholen: endet der Fokus-Grab des Popups, gibt Hyprland den Fokus an das Fenster unter der Maus. `focuswindow` läuft deshalb im Batch mit erzwungenem `cursor:no_warps` (danach alter Wert) – die Maus bleibt, wo sie ist.
- Warum `sendshortcut` statt `wtype`: wtypes virtuelle Tastatur bringt eine eigene Keymap, Chromium/Electron (Discord, Claude) verschluckt die Taste dann oft. Ohne echten Fokus fügt keine App ein (Zwischenablage gibt es nur mit Tastaturfokus).
- Kein Zielfenster mehr → nur kopieren, still. Bilder gehen genauso.
- Emoji als eigenes Popup statt Launcher-Präfix: es soll dort landen, wo man tippt (wie unter Windows) – der Launcher kennt kein Ziel-Fenster. Einfügen über die Zwischenablage wie oben (darum steht das Emoji danach auch im Verlauf), mit angehängtem VS16 (sonst kommen Symbole wie ☀ schwarz-weiß an). Suche nur über die englischen Unicode-Namen (`shell/data/emoji.json`); jedes Suchwort muss im Namen stecken, lose Buchstabenfolgen passen bei ~1400 Namen sonst fast überall.

# Fokus & Alltag

## Fokus ohne Zeit
Code: `shell/services/Focus.qml` (`openEnded`), `shell/modules/bar/FocusPopout.qml`, `TimerChip.qml` · IPC: `focus openEnded on|off|toggle` (`focus toggle` bleibt Timer mit Vorgabe)
- Timer und Fokus-Modus sind eins (`mode "focus"`): ohne Zeit ist nur das Ende weg – Benachrichtigungen, stille Bar, später Abdunkeln/Sperre wie im Block.
- Hyperfokus-Wecker kommt trotzdem (`Breaks.silentWhy` schweigt nur im Block mit Ende), sonst würde er gerade beim Endlos-Fokus nie greifen.
- Keine Pause, kein Block-Zähler, kein Pausen-Banner; zählt aber zu den Fokus-Minuten des Tages. Übersteht Shell-Neustarts.
- Per Tastatur (Super+F) steht die Markierung im Popout auf dem Schalter, per Maus hat das Zeitfeld den Fokus.

## Gedanken parken & To-dos
Code: `shell/modules/bar/TodoPopout.qml`, `TodoChip.qml`, `shell/services/Notes.qml` (Text-Logik `inbox.js`, Test `node scripts/tests/inbox-test.js`), `Todos.qml` · Konfig: `~/.config/desktop/notes.json` (`path`, `todoPrefixes`, `todoList`) · Daten: `~/Notes/inbox.md`, `~/.local/state/desktop/todos.json` · IPC: `inbox add|list|count|done|remove`, `todos add|list|remove`
- Ein Popout für beides (Super+T): oben das Feld, darunter Inbox (neueste oben), To-dos des Desktops, General. Das alte Notizfenster (Super+N, IPC `notes`) ist weg.
- Offen = Zeile beginnt mit `- [ ] `. „Abhaken“ schreibt `[x]` (bleibt als Verlauf), „Löschen“ (zweimal drücken) entfernt den Eintrag samt eingerückter Folgezeilen. Einträge werden über Kopfzeile + Vorkommen gefunden – Datei darf von Hand geändert werden.
- `t …`/`! …` geht nur in die To-dos (früher zusätzlich in die Inbox). „Zur Aufgabe“ hakt den Gedanken ab.
- „Ins Backlog“ (Glühbirne) nur bei Repo-Projekt: Projekt des Desktops, sonst das VS-Code-Projekt (`Context`); abgehakt erst nach Erfolg von `scripts/backlog add`.
- Per Super+T ohne Fokus-Griff reicht die Bar die Tasten weiter: Tippen/Rücktaste/Enter landen trotzdem im Feld (`KeyNav.preKey`).

## Mail öffnen, als gelesen markieren, löschen
Code: `shell/services/Mail.qml` (`openMessage`, `markRead`, `trash`), `MailTile.qml` · `scripts/mail-action open|seen|trash [--dry-run]` (Test `python3 scripts/tests/mail-action-test.py`), Abruf `scripts/mail-status` (liefert `uid`), Meldungen `scripts/mail-watch`
- Nur Kachel und Meldung (der Launcher-Modus `m ` ist seit 2026-10-20 weg).
- Nie direkt `thunderbird mid:…`: Thunderbird sucht die ID nur in seinen `.msf`-Indizes – frisch gestartet „Message for message-id … not found“. `mail-action` schickt `mid:` erst, wenn die ID im `.msf` des Ordners steht (Kaltstart ≈ 30 s, Index schreibt er verzögert), sonst bleibt es nach 60 s beim Posteingang.
- Verworfen: `imap://…/fetch>UID>…`-URL (Thunderbird 15x zeigt nur ein leeres Nachrichtenfenster), `.eml`-Kopie (hängt nicht am Ordner).
- Gelesen = IMAP `UID STORE +FLAGS (\Seen)`; Löschen = nur diese UID in den Papierkorb (SPECIAL-USE `\Trash`, sonst Namen wie „Deleted Messages“; MOVE, iCloud kann das nicht → COPY + `\Deleted` + `UID EXPUNGE`, ohne UIDPLUS gar kein EXPUNGE). Beides nur, wenn die UID noch zur Message-ID passt (sonst Exit 3); Mail fliegt sofort aus `mail.json`.
- Thunderbirds eigene Neue-Mail-Meldung + Ton sind aus (`mail.biff.show_alert`/`play_sound` im user.js-Block von `theme/gen/thunderbird.py`, greift nach TB-Neustart), sonst doppelt zu `mail-watch`. Zurück: Block per `thunderbird.py remove`, dann about:config → Zurücksetzen.

## Benachrichtigungen
Code: `shell/services/NotifRules.qml`, `timewin.js` (Test `node scripts/tests/timewin-test.js`), `Notifs.qml`, `shell/modules/notifications/` · Konfig: `config/notifications.json`, eigene Werte `~/.config/desktop/notifications.json` (ersetzt je Hauptschlüssel ganz)
- `days` = Tage, an denen ein Ruhefenster **beginnt** (wichtig über Mitternacht).
- Dringende Meldungen werden nie versteckt, auch nicht per App-Regel `hide`. Claude-Antwort-Karten sind keine Benachrichtigungen → Ruhezeiten greifen dort nie.
- Flüchtig (App-Regel `transient` oder Hint `transient`): nur Popup, nie im Verlauf; ohne erlaubtes Popup (Ruhezeit, Fokus) fällt sie ganz weg und zählt nicht als verpasst. Gedacht für Rückmeldungen und Mail (steht in der Mail-Kachel).
- `mail-watch` meldet als App „Mail“ mit Thunderbirds desktop-entry und Symbol – im Verlauf sah das wie Thunderbird aus. Regeln matchen App-Name + desktop-entry: Thunderbird-Regeln deshalb mit `^` verankern (Test prüft die mitgelieferten Regeln).
- Ton: ein leiser, dumpfer Einzelton (`Sounds.qml`, Regeln `notifsound.js`, Test `node scripts/tests/notifsound-test.js`, Konfig-Schlüssel `sound`) nur zum sichtbaren Popup – nie in Ruhezeit/Fokus/`panel`/`hide`, nicht bei niedriger Dringlichkeit, Hint `suppress-sound` oder `skip`-Apps (Discord, Spotify klingen selbst – auch dringend), höchstens einer je 1,5 s. App-eigene Töne lassen sich von hier nicht stummschalten.
- Probehören `scripts/sounds play [notify-urgent]`. Stream heißt `desktop-sounds` (Standard-Sink = GoXLR „System“); nie `--media-role Notification` – die Rolle merkt WirePlumber hier stumm. Sound-Theme „desktop“ für canberra-Apps: `scripts/sounds on|off` (setzt gsettings, kdeglobals `[Sounds]`, GTK-settings.ini; alte Werte in `~/.local/state/desktop/sounds-theme.prev`).

## Morgen-Übersicht
Code: `shell/services/Morning.qml`, `shell/modules/morning/`, Logik `timewin.js` · Konfig: `~/.config/desktop/morning.json` · Zustand: `~/.local/state/desktop/morning.json`
- Login außerhalb des Zeitfensters (z. B. 13 Uhr) → an dem Tag keine Karte.
- Esc/Enter wirken erst, wenn die Karte Tastaturfokus hat (nach Überfahren oder Klick).

## Hyperfokus-Wecker
Code: `shell/services/Breaks.qml`, `shell/modules/breaks/BreakCard.qml` · Konfig: `config/breaks.json`, eigene Werte `~/.config/desktop/breaks.json` · Zustand: `~/.local/state/desktop/breaks.json`
- Bewusst ohne Ton, Pulsieren, Tastatur-Übernahme und ohne Bar-Fläche (Fortschritt nur in der Fokus-Kachel des Dashboards).
- `respectInhibitors: false` (Standard): auch ein Video ohne Eingabe zählt als Pause.
- Der alte Hyperfokus-Teil des Fokus-Timers (`Focus.hyperDue`) ist entfernt – nicht wiederbeleben.

## Leerlauf-Abdunkeln
Code: `shell/modules/idle/Idle.qml` (IPC `dim`), `scripts/idle` · Konfig: `hypr/hypridle.conf` (Zeiten; Ablauf dort im Kopf)
- Keine Sperre – die Lock-Kette (`scripts/lock`) liegt darüber. Inhibit (Video/Spiel/Call) hält hypridle an.
- Monitore gehen **vor** der Sperre aus: die helle Sperre würde das Dunkel sonst kurz aufreißen.
- Overlay ist klickdurchlässig (leere Maske); weg geht es über hypridle-Resume, Rückfall: eigener `IdleMonitor`.
- `OpacityAnimator` statt Timer-Schritten (Render-Thread, ruckelfrei auf 360 Hz); schreibt die Deckkraft erst am Ende zurück.
- Ausprobieren: `scripts/idle dim-test 10`, `scripts/idle black-test 3`. hypridle liest die Datei nur beim Start: `pkill hypridle; uwsm app -- hypridle &`.

## Snip
Code: `shell/modules/screenshot/` (`Snip.qml`, `SnipPin.qml`, `SnipToast.qml`), `scripts/snip-ocr`, `scripts/snip-color`
- Bilder nur im RAM (`$XDG_RUNTIME_DIR/desktop-snip/`), OCR-Bild sofort gelöscht, Pins beim Schließen; alles offline.
- OCR braucht `tesseract tesseract-langpack-deu tesseract-langpack-eng` (sudo). Farbe kommt aus dem eingefrorenen Bild, `hyprpicker` ist unnötig.
- Maus und Pfeile teilen sich einen Zielpunkt: der echte Zeiger springt per `movecursor` mit, das Bewegungs-Echo wird über `warps` verworfen. Alt+Pfeile sind in Hyprland belegt, darum Strg für „ganze Auswahl“.
- Pipette nur im Snip, kein eigenes Kürzel (ein Weg statt zwei). Der Hex in der Lupe liest ein Canvas aus demselben eingefrorenen Bild wie `snip-color` beim Kopieren.
- Aufnahme-Quellwahl = SharePicker im Modus „record“ (ohne Portal, nichts gemerkt). wf-recorder kann nur Bildschirmbereiche: ein Fenster wird als seine Fläche aufgenommen (was darüber liegt, ist mit drin; Verschieben wird nicht verfolgt), darum listet die Wahl nur sichtbare Fenster.

## Absturz-Karten
Code: `shell/services/Crashes.qml`, `shell/modules/crash/` · DrKonqi: `scripts/hypr drkonqi off|on|status`
- Nur Apps bekommen eine Karte; CLI-Abstürze werden nur gezählt (`crash list`). Kein Restart für Shell, Hyprland, Portale (die startet systemd).
- DrKonqi ist nur aus, wenn Hyprland **und** `desktop-shell-hyprland` laufen (ExecCondition im Drop-in `drkonqi-coredump-launcher@.service.d/not-on-hyprland.conf`); Coredumps bleiben (`coredumpctl list`).
- Lücke: KDE-Apps mit KCrash-Rückfall öffnen DrKonqi direkt (unter Fedora selten) – Breeze-Fenster = melden.
- Echter Test: `sh -c 'sleep 300 & p=$!; sleep 0.3; kill -SEGV $p'` → Karte „Sleep crashed“.

# Dev & Projekte

## Dev-Dienste
Code: `scripts/devservices` (`show` = Test ohne Shell), `shell/services/DevServices.qml`, `shell/modules/bar/DevChip.qml`, `DevPopout.qml` · Konfig: `projects/projects.json` (nur lesen, ändern über `scripts/project`)
- Geteilte Altports (3000, 5432 …) ordnen nichts zu – dafür Port-Blöcke (`projects/README.md`).
- Start als Unit `devserver-<projekt>` (überlebt Shell-Neustart); startet nicht, wenn der erste App-Port schon belegt ist.
- Von systemd/Quadlet verwaltete Container ohne Projekt (z. B. `systemd-anisette`) zählen nicht im Chip; Stoppen kann systemd rückgängig machen.
- Chip-Klick öffnet immer den Reiter Services; Server nur per Super+Alt+H / Bar-Modus `H`.

## Server (sshs)
Code: `shell/services/Servers.qml`, Reiter in `DevPopout.qml`, `scripts/sshs`, `config/sshs/sshs_watcher.py` · Konfig: `config/consoles.json`, private Adressen in `~/.config/desktop/consoles.json` (gleiche `id` ersetzt Felder) · Terminal-Seite: [theming.md → sshs](theming.md#sshs)
- Private URLs nie ins öffentliche Repo; ohne Dokploy-URL ist die Zeile ausgegraut. Bewusst keine Konsolen-Links pro Projekt.
- Alles läuft als Anmelde-Benutzer (Root-Login per SSH ist auf den Servern aus); root nur im Terminal per `sudo -i`/`su -`.
  Dateien, Up- und Downloads sehen dann weiter nur, was der Anmelde-Benutzer darf. Upload aus der Bar geht nach `~`.
- Upload fragt nie: Schlüssel nicht im Agenten → „Login failed“ → einmal per Terminal verbinden, dann neu. Nur ein Upload gleichzeitig.
- „Files“ wartet auf die erste Prompt, gibt nach 3 min auf (dann bleibt das Terminal).

## Workspace-Leiste: Fenster ziehen
Code: `shell/modules/workbar/WorkBar.qml` (`wdMon`, `monAt`), `shell/services/Hypr.qml` (`moveToSlot`)
- Symbol auf einen Mini-Monitor = Workspace dieses Desktops auf diesem Monitor (`slot*100+desk`), auch in derselben Kachel; Kopf/Rand der Kachel = wie früher (gleicher Monitor-Platz). Lücken zwischen den Mini-Monitoren zählen als Rand.
- `movetoworkspacesilent`: Fokus bleibt, wo er war. Schwebende Fenster behalten ihre Lage relativ zum Monitor und schrumpfen auf den Zielmonitor (ohne reservierte Ränder) – Hyprland allein schiebt nur die rechte Kante hinein, ein 1440p-Fenster ragte dann auf den Nachbarn.
- Tastatur (aktives Fenster): erst Monitor mit Super+Shift+←/→ oder Super+Shift+1…3 (`scripts/winmove`, Fokus folgt), dann Alt antippen + Shift+Ziffer (Workspace, Monitor bleibt).
- Mitkommende Apps (Discord/Spotify, siehe nächster Abschnitt): auf einen anderen Desktop ziehen hält nicht, ein anderer Monitor schon.

## Mitkommende Apps (Discord, Spotify)
Code: `shell/services/Hypr.qml` (`follows`, `followCmds`, `switchCmds`), `shell/services/Parked.qml` (`_follow`) · Konfig: `config/follow.json` (`apps`, Teil der Fensterklasse; `"discord"` = ganzer Chat-Client), eigene Liste in `~/.config/desktop/follow.json` (ersetzt, live gelesen)
- Kein Hyprland-`pin`: gepinnte Fenster lehnen `movetoworkspace` ab (Wegräumen/Holen ginge nicht) und `pin` gibt es nur schwebend. Stattdessen `movetoworkspacesilent` auf `slot*100+desk` ihres Monitors.
- Shell-Wechsel (Alt+1…9, Alt+←/→, Leiste, Klick auf Fenster, neuer Workspace) schieben vorher mit (kein Flackern); jeder andere Wechsel (Hyprland direkt) zieht nach dem Event nach.
- Monitor, Kacheln/Schweben, Lage und Fokus bleiben. Weggeräumte (`special:parked…`), minimierte, angepinnte und Vollbild-Fenster kommen nicht mit.
- Prüfen: `qs ipc … call hypr status` → `follow` zeigt die aktive Liste.

## Quicklinks & Git/CI
Code: `shell/modules/workbar/QuickLinksPopup.qml`, `QuickLinksDots.qml`, `QuickLinksTip.qml`, `QuickLinksStats.qml`, `shell/services/GitInfo.qml` (`projectFor`, `gitEvery`/`ciEvery`), `scripts/gitinfo` · Konfig: `projects/projects.json` (nur über `scripts/project link …`)
- Projekt-Workspace = eigener Workspace-Name gleich Projekt-ID oder Anzeigename; „Workspace 2“ ohne Namen hat kein Projekt.
- Globale Links (`scripts/project link global …`) erscheinen hier nicht.
- CI braucht angemeldetes `gh` und ein github.com-Remote; Fehler bleiben still (kein Punkt).
- Tastatur: Popup hat eigenen Handler (`keyTrap`), denn Hyprland gibt ihm die Tastatur bei Grab (Klick) und sobald die Maus darüber steht; im Workspace-Modus (Q) reicht sonst die Leiste die Tasten weiter.
- Stats (`QuickLinksStats.qml`, `scripts/projectstats`): nur Hauptprojekt, nur beim Öffnen; Commits = Autor `user.email` des Repos auf lokalen Branches, +/− nur eigene Commits seit Mitternacht (Uncommittetes = „N changes“ der Git-Zeile); LOC ohne Lockfiles/Vendor/JSON/YAML, Cache nach HEAD in `~/.local/state/desktop/projectstats.json`.

## Projektzeit
Code: `shell/services/ProjectTime.qml`, Anzeige im Kachelkopf `shell/modules/workbar/WorkBar.qml`, `scripts/projecttime` · Konfig: `~/.config/desktop/projecttime.json` · Daten: `~/.local/state/desktop/projecttime/YYYY-MM-DD.json`
- Kachel zeigt **heute** (ab 1 min, nicht auf Kacheln schmaler als 150 px); Woche nur im Tooltip – heute ist die Zahl, nach der man handelt, die Woche ändert sich kaum.
- Wochenwert rechnet `scripts/projecttime week` beim Öffnen des Tooltips; ältere Wochen/Monate nur per CLI.
- Von Hand korrigieren: `total` ändern (zählt überall); `spans` ist nur Verlauf.
- Ein Inhibitor (Video/Call) lässt trotz Leerlauf weiterzählen.

## Passwörter: Speichern anbieten (Browser)
- Erkannt wird nur im obersten Frame: submit, Klick auf einen Absende-Knopf (oder Knopf mit Login-Wörtern), Enter in einem Feld. Ohne erkannten Benutzer kein Angebot (iCloud braucht einen); E-Mail-zuerst-Logins merken den Benutzer aus Schritt 1.
- Gefragt wird erst, wenn der Login wohl geklappt hat: Seite navigiert und zeigt kein Login-Formular mehr, bzw. (SPA) kein Passwortfeld binnen 10 s. Falsches Passwort → nichts.
- Unterdrückt die Shell die Meldung (Fokus-Modus, Ruhezeit), kommt `notify-send` sofort leer zurück → Leiste oben in der Seite. Popup abgelaufen = nein. Wegklicken in der ersten Sekunde zählt als unterdrückt.
- iCloud kennt Website + Benutzer nur einmal → gleicher Benutzer = „Update“, nie Dublette. Gespeichert wird der Host ohne Port (icp nimmt keine Ports).
- „Never“ landet in `passwords-never.json` (nur Hostnamen) neben den Overrides; Apples „Nie sichern“-Einträge gelten auch. Zurück: Zeile dort löschen.
- E-Mail-Felder: „Your email“ = nur Absender der in Thunderbird verknüpften Konten (bewusst nichts aus Logins geraten;
  neues Konto in Thunderbird → erscheint von selbst). Apples „Nie sichern“ ist ein Login mit Benutzer
  „Passwords not saved“ – wird nie vorgeschlagen. „Create new Hide My Email“ legt bei Apple echt eine Adresse an (Label = Host).

## Externe Dienste: Drosselung
Regel: nie im Sekunden-/Minutentakt gegen fremde APIs; bei Fehlern wachsender Abstand, `Retry-After` gilt.
- Passwörter neu anlegen (`icp add`): nur eine Website (weitere danach per Bearbeiten); Website + Benutzer, die es schon gibt,
  lehnt iCloud ab (ein Eintrag je Paar) → Hinweis, stattdessen bearbeiten. Titel/Notiz/2FA brauchen ein vorhandenes
  Metadaten-Objekt als Vorlage, sonst nur Login + Warnung.
- Passwörter (icp): Timer 15 min + beim Öffnen ab 5 min alt; icp selbst ≥ 5 min Abstand, Backoff 5 min → 6 h, `~/.config/icp/state.json`.
- Wetter (`Weather.qml`): 15 min; Fehler → 1, 2, 4 … 15 min. Mail 2 min / Kalender 5 min (eigene Timer), stats.fm ≥ 30 min, nach 429 30 min Pause.
- GitHub-CI (`scripts/gitinfo`) je Projekt ≥ 5 min; Hue ist lokal (Bridge, 15 s nur bei offenem Popout); Favicons nur auf Abruf, Cache 30/7 Tage.
- Spotify: siehe Abschnitt Spotify.
