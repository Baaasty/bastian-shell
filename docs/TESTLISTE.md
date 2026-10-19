# Testliste (Stand 2026-10-18)

Alles hier ist gebaut, aber von den Agents nur per Befehl/Screenshot geprüft – echte Tasten und Mausklicks fehlen.
Abhaken, was klappt; was nicht klappt, kurz notieren (Taste, was passiert, was erwartet war) und an Claude geben.

## Fenster und Workspaces

- [ ] **Super+Return** öffnet Kitty · **Super+Shift+Return** Dropdown-Kitty oben, nochmal = weg, Inhalt bleibt
  - (auto) `scripts/dropterm status` läuft fehlerfrei („aus“); Öffnen selbst nicht getestet.
- [ ] **Super+Pfeile** Fokus wechseln · **Super+Shift+→** Fenster auf den nächsten Monitor, Fokus und Maus gehen mit
- [ ] **Alt+1…9** Workspace wählen · **Alt+←/→** vor/zurück · Leiste unten zeigt kurz, wo man ist
  - (auto) `workbar reveal` zeigt die Leiste ok; Umschalten nicht getestet. Kleinigkeit: Kacheln zeigen auch `xwaylandvideobridge` und den Absturz-Dialog (drkonqi) als Fenster.
- [ ] **Alt antippen** (oder Alt+Esc) Workspace-Modus: `1–9`, `←/→` (auch Alt+←/→) + `Enter`, `N` neu, `R` umbenennen, `Entf` zweimal = Fenster schließen + Workspace weg (letzter: „reset“), `Esc`
- [ ] Workspace-Leiste: Klick wählt, Fenster-Kachel anklicken holt das Fenster, Fenster-Kachel auf andere Workspace-Kachel ziehen verschiebt es
- [ ] Projekt-Workspace: Link-Knopf an der Kachel (Quicklinks), Tooltip mit Branch/Änderungen/CI
- [ ] **Super+Alt+K** Layout-Menü: Workspace als Layout speichern, später wiederherstellen
  - (auto) `scripts/layout list` ok (noch keine Layouts gespeichert).
- [ ] Spotify-Chip: wegräumen, holen → Spotify rechts 800 px, Chat links

## Shell-Werkzeuge

- [ ] **Super+B** Bar-Modus: Buchstaben an den Chips, Buchstabe öffnet das Popout mit Tastatur; ←/→/Tab + Enter geht auch; Esc im Popout → zurück zum Chip
  - (auto) Ring, Buchstaben, Hinweiszeile, `L` (Licht) und `S` (Sound) per Taste geöffnet, Esc schließt; Chip-Reihenfolge inkl. Server ok
- [ ] **Super+Alt+S / L / U** Sound / Licht / Server direkt (nochmal = zu), Pfeile/Tab/Enter darin, Regler erst nach Enter
  - (auto) `barmode popout mixer` ohne Tastendruck: öffnet ohne Fokus-Griff, Ring auf „System“, Bar reicht Tasten weiter; nochmal = zu
- [ ] **Super+Alt+Z** Benachrichtigungen per Tastatur (↑↓, Enter, 1–3, S + 1–4, Entf, Esc) · **Super+Alt+X** neueste wegklicken
  - (auto) mit `notify-send -u critical -A …`: Karte markiert, Tastenzeile sichtbar, Super+Alt+X klickt weg
- [ ] Tray per Tastatur: Super+B, T → Liste, ⋮ öffnet das Menü, darin ↑↓/Enter/←
- [ ] Popouts bleiben offen, wenn der Compositor sie schließt (Spotify holen, Fenster geht auf); zu nur durch Weghovern, Esc, Chip, anderes Popout
  - (auto) Spotify-Popout über Bar-Modus offen, `parked toggle spotify` hin und zurück → bleibt offen
- [x] **Super** (antippen) Dashboard + Suche · `?` zeigt alle Präfixe · `g test`, `pw <name>`, `cal` (auto, per IPC; die Taste selbst nicht gedrückt)
- [ ] **Super+K** Kürzel-Übersicht · **Super+P** Paketmanager (Klick ins Leere schließt)
  - (auto) Beide öffnen per IPC sauber (62 Kürzel, „Everything is up to date“). „Klick ins Leere“ nicht getestet.
- [ ] **Super+N** Gedanken parken: direkt tippen, Enter speichert, `t …` wird zusätzlich To-do
  - (auto) Fenster öffnet ok; Speichern nicht getestet.
- [ ] **Super+O** Passwörter: Logos („Icons“), keine WLAN-Einträge, „Show“ blendet sie ein
- [ ] Ressourcen-Chip (CPU/RAM/GPU): Popout, Sortierung nach Memory, Zeile aufklappen (Pfeil vorne), Icons in jeder Zeile
- [x] Lautsprecher-Chip: Apps nach Kanal (System, Music, Chat zuletzt), GoXLR-Pegel wie im Dashboard (auto, per `mixer open`)
- [ ] Netz-Chip: Verbindung, Ping, Tailscale-Schalter (nur bewusst benutzen)
  - (auto) Popout zeigt Ethernet, Ping und Tailscale „Connected“ ok; Schalter nicht benutzt. `net status` meldet aber „tailscale: not installed“, solange das Popout nicht offen war.
- [ ] `pkexec true` im Terminal → eigener Passwort-Dialog, Esc bricht ab
  - (auto) `polkit status` = registered.

## Screenshot und Benachrichtigungen

- [ ] **Druck** / **Super+Shift+S**: Bereich → `Enter` kopiert, `S` speichert, `C` Farbe, `P` anpinnen (Pin ziehen, Mausrad, Rechtsklick schließt), `T` Text (braucht tesseract)
  - (auto) tesseract ist **nicht installiert** → `T` geht noch nicht. Log: `SnipPin.qml:19:12: Duplicate signal name` (`signal dismissed`).
- [ ] **Super+Shift+C** Farbpipette direkt · **Strg+Druck** alle Monitore
- [ ] `notify-send -a Test Hallo Text`: Maus drauf → bleibt stehen (auch die darunter), Uhr → „10 min“ → kommt wieder
  - (auto) Abends gerade Ruhezeit: Benachrichtigung landet nur im Panel („1 while you were away“). Tagsüber testen.
- [x] Morgen-Übersicht: `qs ipc --any-display -p ~/Workspace/desktop-hyprland/shell call morning open` (auto)

## Szenen, Licht, Ton

- [ ] **Super+Alt+G** Spiele-Modus an/aus (Bar weg, keine Popups) · **Super+Alt+B** Feierabend an/aus
  - (auto) `scene … --dry-run`: Feierabend ok. Spiele-Modus: „skip hue: scene 'Game' not in room Büro“ – Hue-Szene „Game“ fehlt (anlegen oder `config/scenes.json` anpassen).
- [ ] Fokus-Block (**Super+Alt+F**) → Büro-Licht warm/gedimmt, danach wie vorher
  - (auto) `scene on focus --dry-run` ok (Nicht stören an, Hue Büro 400 mirek/40 %).
- [ ] **Super+Alt+N** Abendwärme (braucht hyprsunset) · Kamin-Idle: `scripts/idle show force`, Maus bewegen beendet
  - (auto) hyprsunset ist **nicht installiert** (`sudo dnf install hyprsunset`); Zeitplan (`nightlight check`) ok. `idle status` = hidden.
- [ ] Licht-Chip (Birne neben dem Lautsprecher): Popout wie im Dashboard – Key Light an/aus + Regler, Szene wählen, Farbpunkt → Farbwähler, Rechtsklick auf Szene/„Off“ = Menü, Kamera-Regler; Weghovern schließt
  - (auto) `light open` + `light picker` per IPC, Screenshot ok; Klicks/Ziehen nicht getestet.
- [ ] **Super+L** sperren, Fader verstellen, entsperren → Fader wie vorher, Dashboard-Routing alles aus
- [x] Lautstärke-Tasten tun nichts; System bleibt 100 % (auto: kein Bind, Ausgang 1.00, Sperre an)

## Apps im Look

- [ ] Dolphin, Systemeinstellungen, Datei-Dialog: Schema „Desktop Hearth“
  - (auto) `kdeglobals` steht auf DesktopHearth; Ansehen fehlt.
- [ ] GTK-Dialog: `zenity --question --text=Test` warmbraun, kein Blau
  - (auto) `theme/gen/gtk.py --status`: gtk.css 3.0/4.0 = hearth; Ansehen fehlt.
- [ ] VS Code nach „Reload Window“, Helium nach ↻ bei beiden Erweiterungen
- [ ] GoXLR im Launcher öffnet die GoXLR-Oberfläche in Helium
  - (auto) `goxlr.desktop` da (helium --app=localhost:14564), Daemon antwortet (HTTP 200).

## Wiederherstellen

- [ ] Session-Restore: Erster Test laut `docs/SESSION.md` (2–3 Fenster, `scripts/session save`, schließen, `scripts/session restore`)
  - (auto) `session status` / `session dry-run` ok (Autosave läuft, würde VS Code auf ws 3 holen).
