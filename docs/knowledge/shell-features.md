# Shell-Features – was man nicht aus dem Code sieht

Was jedes Feature tut, steht als eine Zeile in [docs/PRD.md](../PRD.md); Kürzel in [hotkeys.md](hotkeys.md); hier nur Konfiguration, Grenzen und Stolperfallen.

Allgemein: IPC-Funktionen heißen `open` statt `show` – `qs ipc` hält „show“ für den eigenen Unterbefehl.

# Bar & Popouts

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

## Downloads
Code: `shell/services/Downloads.qml`, `shell/modules/bar/DownloadsChip.qml`, `DownloadsPopout.qml` · Konfig: `~/.config/desktop/downloads.json` (optional)
- Eigener Chip, weil kein Popout thematisch passt und „neu“ (15 min) einen Platz in der Bar braucht; im Fokus-Modus ausgeblendet.
- Aufräumen nur per `gio trash`, nie löschen. `gio trash` geht nicht auf tmpfs → Tests mit einem Ordner unter `~` (`downloads testDir`).

## Update-Chip
Code: `shell/services/Updates.qml`, `shell/modules/bar/UpdatesChip.qml`, Backend `scripts/pkg` · Zustand: `~/.local/state/desktop/updates.json` (löschen = beim nächsten Start neu prüfen)
- Installiert nie selbst – nur der Paketmanager (Super+P).

## Privatsphäre-Punkte
Code: `shell/services/Privacy.qml`, `shell/modules/bar/PrivacyDot.qml`, `scripts/privacy-cam` · Konfig: keine
- Bleiben bewusst auch im Fokus-Modus sichtbar.
- Discord hält das Mikro nach Call/Mikrotest offen: gemeldet wird es nur im Sprachkanal (`Discord.inVoice`). Andere Apps mit „idle“ gehaltenem Aufnahme-Stream zeigen den Punkt trotzdem.
- Unsichtbar bleiben Kamera-Zugriffe ohne PipeWire und ohne offenes `/dev/video` (z. B. fremde Benutzer).

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
- „Remember this choice“ geht nur, wenn xdph mit `screencopy:allow_token_by_default = true` läuft.
- GTK-Alternative (hyprland-preview-share-picker, Commit `7e11349` geprüft, `PIN` im Skript) braucht sudo-Pakete; Tastatur erst nach Klick.

# Launcher

## Launcher
Code: `shell/modules/launcher/Launcher.qml` (`sources`, `parse()`, `rebuild()`), `shell/services/LauncherSources.qml`, `WebShortcuts.qml` · Konfig: `config/launcher/web.json`, Zähler `~/.local/state/desktop/launcher.json` (nur IDs, nie Suchtexte)
- `web.json`: das erste Kürzel ist das Standard-Kürzel (`?<text>`, „Search the web“); `url` braucht `http(s)://` + `{q}`; `pw`, `cal`, `c` sind reserviert. Kaputte Einträge → „Config problem“ unter `?`.
- `c `: `claude://` an Claude Desktop (distrobox „ubuntu“), wenn `xdg-mime query default x-scheme-handler/claude` einen Handler hat, sonst claude.ai in Helium; geprüft einmal pro Shell-Start.
- `pw ` lädt Metadaten höchstens alle 5 min (neue Einträge: `scripts/passwords sync`). `@` braucht Helium mit Erweiterung „Desktop“ (`scripts/chrome-ext status`).
- Verworfen (nicht wieder einbauen): Text-Bausteine `s ` und FMHY-Suche.

# Fokus & Alltag

## Gedanken parken
Code: `shell/services/Notes.qml`, `shell/modules/notes/NotesWindow.qml` · Konfig: `~/.config/desktop/notes.json` · Daten: `~/Notes/inbox.md`
- Gezählt werden nur Zeilen, die mit `- [ ] ` beginnen; erledigt = von Hand `[x]` oder Zeile löschen.
- Schlägt das Schreiben fehl, bleibt das Fenster mit Entwurf offen („Could not save“).

## Benachrichtigungen
Code: `shell/services/NotifRules.qml`, `timewin.js` (Test `node scripts/tests/timewin-test.js`), `Notifs.qml`, `shell/modules/notifications/` · Konfig: `config/notifications.json`, eigene Werte `~/.config/desktop/notifications.json` (ersetzt je Hauptschlüssel ganz)
- `days` = Tage, an denen ein Ruhefenster **beginnt** (wichtig über Mitternacht).
- Dringende Meldungen werden nie versteckt, auch nicht per App-Regel `hide`. Claude-Antwort-Karten sind keine Benachrichtigungen → Ruhezeiten greifen dort nie.
- Snooze kommt höchstens zwei auf einmal zurück und wartet Ruhezeit/Fokus/DND ab; „Tomorrow“ zwischen 00 und 05 Uhr = heute 08:00.
- Die Shell spielt keine Töne; App-eigene Töne lassen sich von hier nicht stummschalten.

## Morgen-Übersicht
Code: `shell/services/Morning.qml`, `shell/modules/morning/`, Logik `timewin.js` · Konfig: `~/.config/desktop/morning.json` · Zustand: `~/.local/state/desktop/morning.json`
- Login außerhalb des Zeitfensters (z. B. 13 Uhr) → an dem Tag keine Karte.
- Esc/Enter wirken erst, wenn die Karte Tastaturfokus hat (nach Überfahren oder Klick).

## Hyperfokus-Wecker
Code: `shell/services/Breaks.qml`, `shell/modules/breaks/BreakCard.qml` · Konfig: `config/breaks.json`, eigene Werte `~/.config/desktop/breaks.json` · Zustand: `~/.local/state/desktop/breaks.json`
- Bewusst ohne Ton, Pulsieren, Tastatur-Übernahme und ohne Bar-Fläche (Fortschritt nur in der Fokus-Kachel des Dashboards).
- `respectInhibitors: false` (Standard): auch ein Video ohne Eingabe zählt als Pause.
- Der alte Hyperfokus-Teil des Fokus-Timers (`Focus.hyperDue`) ist entfernt – nicht wiederbeleben.

## Szenen
Code: `shell/services/Scenes.qml`, `scripts/scene` (`check`, `--dry-run`) · Konfig: `config/scenes.json` · Zustand: `~/.local/state/desktop/scenes.json`
- `cmd`-Schritte nur aus der Positivliste `commands` (Wortliste, kein Shell-Text).
- Hue wird pro Raum zurückgesetzt (Einzellampen ohne Szene landen auf einer gemeinsamen Helligkeit); Key-Light-Kelvin auf 50 K genau; Lesen bis ~4 s, wenn ein Gerät schweigt.
- Nach Shell-Neustart werden nur „Bar weg“ und „Nicht stören“ aktiver Szenen neu gesetzt. Hängt eine Szene: `scripts/scene off NAME`, zur Not Zustandsdatei löschen + Shell neu laden.
- Fokus-Kopplung: Timer-„Pause“ ändert nichts, Pausen-Block schaltet aus; `focusLink: false` trennt. Hue-Szene „Game“ fehlt noch in der Bridge (Schritt wird übersprungen).
- Neue Szene mit Kürzel: Zeile in `hypr/binds.conf` mit Titel nach `#`, dann `python3 -I scripts/hotkeys-md`.

## Abendwärme
Code: `scripts/nightlight` (Daemon über `hypr/autostart.conf`) · Konfig: `config/nightlight.json`, Ort sonst aus Secrets-Schlüssel `location` (wie Wetter), sonst Berlin · Zustand: `~/.local/state/desktop/nightlight.json`
- Braucht `hyprsunset` (COPR sdegler/hyprland, sudo); ohne Paket beendet sich der Daemon still.
- hyprsunset wirkt über `hyprland-ctm-control` auf alle Monitore gemeinsam – pro Monitor geht nicht.
- Not-Aus: `scripts/nightlight off` oder `pkill -x hyprsunset`. Bewusst kein Schalter in der Shell (nur CLI + Super+Alt+N).

## Kamin-Idle
Code: `shell/modules/idle/` (`Idle.qml`, `Fireplace.qml`, `Flame.qml`), `scripts/idle` · Konfig: `hypr/hypridle.conf` (Listener `timeout = 180`, im Fokus-Block 780; löschen = aus)
- Keine Sperre – die Lock-Kette liegt darüber. Inhibit (Video/Spiel) hält hypridle an, dann kommt auch kein Kamin.
- hypridle liest die Datei nur beim Start: `pkill hypridle; uwsm app -- hypridle &`.
- IPC-Ziel heißt `fireplace` (`idle` gehört der Lock-Kette).
- Wegen 360 Hz kein Dauer-Animieren: Flammen springen per Timer (~6 Bilder/s, ~0,5 % eines Kerns).

## Snip
Code: `shell/modules/screenshot/` (`Snip.qml`, `SnipPin.qml`, `SnipToast.qml`), `scripts/snip-ocr`, `scripts/snip-color`
- Bilder nur im RAM (`$XDG_RUNTIME_DIR/desktop-snip/`), OCR-Bild sofort gelöscht, Pins beim Schließen; alles offline.
- OCR braucht `tesseract tesseract-langpack-deu tesseract-langpack-eng` (sudo). Farbe kommt aus dem eingefrorenen Bild, `hyprpicker` ist unnötig.

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
- Chip-Klick öffnet immer den Reiter Services; Server nur per Super+Alt+U / Bar-Modus `H`.

## Server (sshs)
Code: `shell/services/Servers.qml`, Reiter in `DevPopout.qml`, `scripts/sshs`, `config/sshs/sshs_watcher.py`, `config/sshs/remote/` · Konfig: `config/consoles.json`, private Adressen in `~/.config/desktop/consoles.json` (gleiche `id` ersetzt Felder) · Terminal-Seite: [theming.md → sshs](theming.md#sshs)
- Private URLs nie ins öffentliche Repo; ohne Dokploy-URL ist die Zeile ausgegraut. Bewusst keine Konsolen-Links pro Projekt.
- Root-Login per SSH bleibt aus: „root“ = Anmelde-Benutzer + `su` (Passwort tippst du). Upload geht immer als Anmelde-Benutzer nach `~`.
- Upload fragt nie: Schlüssel nicht im Agenten → „Login failed“ → einmal per Terminal verbinden, dann neu. Nur ein Upload gleichzeitig.
- Der Watcher gibt nach 3 min ohne Prompt auf.

## Quicklinks & Git/CI
Code: `shell/modules/workbar/QuickLinksPopup.qml`, `QuickLinksDots.qml`, `QuickLinksTip.qml`, `shell/services/GitInfo.qml` (`projectFor`, `gitEvery`/`ciEvery`), `scripts/gitinfo` · Konfig: `projects/projects.json` (nur über `scripts/project link …`)
- Projekt-Workspace = eigener Workspace-Name gleich Projekt-ID oder Anzeigename; „Workspace 2“ ohne Namen hat kein Projekt.
- Globale Links (`scripts/project link global …`) erscheinen hier nicht.
- CI braucht angemeldetes `gh` und ein github.com-Remote; Fehler bleiben still (kein Punkt).

## Projektzeit & Tagesrückblick
Code: `shell/services/ProjectTime.qml`, `Recap.qml`, `shell/modules/recap/`, `shell/modules/dashboard/ProjectTimeTile.qml`, `scripts/projecttime`, `scripts/recap` · Konfig: `~/.config/desktop/projecttime.json`, `~/.config/desktop/recap.json` · Daten: `~/.local/state/desktop/projecttime/YYYY-MM-DD.json`
- Von Hand korrigieren: `total` ändern (zählt überall); `spans` ist nur Verlauf.
- Ein Inhibitor (Video/Call) lässt trotz Leerlauf weiterzählen.
- `ProjectTimeTile` hängt noch nicht im Dashboard (Raster 12 × 3 voll): vierte Reihe oder eine 3er-Kachel ersetzen.
- Recap zählt nur Commits mit Autor = `git config user.email` des Repos; abgehakte To-dos merkt es sich selbst (Todos kennt keine Zeit).
