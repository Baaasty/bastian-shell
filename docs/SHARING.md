# Bildschirm teilen – eigene Auswahl (AP 16)

Beim Teilen (Discord/Equibop, Helium/Chrome, OBS) fragt `xdg-desktop-portal-hyprland` (xdph) nach Monitor, Fenster oder Bereich.
Statt des Standard-Dialogs `hyprland-share-picker` zeigt die **Shell** eine eigene Karte im Desktop-Look:
Reiter **Screens · Windows · Region**, echte Live-Vorschauen, Suche, Haken „Remember this choice“.

Einbindung: `~/.config/hypr/xdph.conf` → `screencopy { custom_picker_binary = <Repo>/scripts/share-pick }`.
Das Portal startet das Programm pro Teilen-Anfrage und liest die Antwort (`[SELECTION]…`) von stdout.

## Aktivieren (einmalig, nur wenn kein Stream/Call läuft)

```bash
cd ~/Workspace/bastian-shell
scripts/share-picker status        # läuft die Shell? Standard-Picker als Rückfall da?
scripts/share-picker test          # Karte mit echten Fenstern zeigen – nichts wird geteilt, Esc schließt
scripts/share-picker install       # xdph.conf-Block eintragen (Backup nach ~/.local/state/desktop/)
systemctl --user restart xdg-desktop-portal-hyprland xdg-desktop-portal   # bricht laufende Streams ab!
```

Das Portal liest `xdph.conf` nur beim Start. Bis zum Neustart bleibt alles beim Alten. Kein sudo, nichts zu bauen.

**Zurück zum Standard:** `scripts/share-picker off` (auch `uninstall`/`restore`) + derselbe Portal-Neustart.

## Bedienung

| Taste / Maus | Wirkung |
| --- | --- |
| ← → (↑ ↓ bei Fenstern) | Monitor/Fenster wählen |
| Tab / Shift+Tab | Reiter wechseln |
| Tippen | Fenster suchen (springt in „Windows“) |
| Enter · Doppelklick · „Share“ | teilen |
| Esc · „Cancel“ · Klick daneben | abbrechen (bei Text im Suchfeld: erst Suche leeren) |
| Region → „Select region“ | Karte verschwindet, Rechteck mit der Maus ziehen (slurp in Palette-Farben); Esc = zurück zur Karte |

- Monitore heißen nach ihrer Lage: **Left screen** (HDMI-A-2), **Center screen** (DP-2, vorausgewählt), **Right screen** (DP-1) –
  von links nach rechts sortiert, bei 2 Monitoren Left/Right.
- Fenster: zuletzt benutzte zuerst. Vorschau live nur beim gewählten Fenster, die anderen zeigen ein Standbild (spart Leistung);
  ohne Vorschau (z. B. minimiert) kommt das App-Icon.
- „Remember this choice“ = Restore-Token: die App darf dieselbe Quelle beim nächsten Mal ohne Frage nehmen (OBS, Browser).
  Standard aus; an, wenn xdph mit `screencopy:allow_token_by_default = true` läuft.
- Die Karte erscheint auf dem Monitor mit dem Fokus, liegt als Overlay über allem (auch über angepinntem Discord),
  hält Tastatur exklusiv und schließt bei Klick auf einen anderen Monitor (Fokus-Grab).

## Ablauf

```text
xdph ──startet──▶ scripts/share-pick ──qs ipc call sharepicker open '<json>'──▶ Shell (SharePicker.qml)
     ◀─stdout──── [SELECTION]r/screen:DP-2   ◀── $XDG_RUNTIME_DIR/desktop-share-pick/<token>.result ──┘
```

- `share-pick` gibt der Shell Token, Fensterliste und `allowToken`, wartet auf die Ergebnisdatei (`ok <flags>/<auswahl>` oder `cancel`),
  prüft sie (nur `screen:`/`window:`/`region:` mit sauberem Format, Fenster-ID muss aus der xdph-Liste stammen) und gibt genau eine Zeile aus.
- **Zeitlimit 60 s** (`SHARE_PICK_TIMEOUT`), danach schließt die Karte und das Teilen wird abgebrochen.
- **Rückfall:** Läuft die Shell nicht, antwortet nicht (4 s) oder startet sie während der Auswahl neu (Prüfung alle 3 s),
  startet `share-pick` den Standard-Picker `hyprland-share-picker` mit denselben Argumenten – Teilen geht also immer.
- Abbruch = keine `[SELECTION]`-Zeile, Exit 1 → xdph bricht ab.

## Protokoll (geprüft 18.10.2026 an xdph 1.4.1 – installiert: `xdg-desktop-portal-hyprland-1.4.1-1.fc44`)

Quelle: `src/shared/ScreencopyShared.cpp` (Tag v1.4.1, `promptForScreencopySelection`, `buildWindowList`) und
`hyprland-share-picker/main.cpp`; die Strings stimmen mit `/usr/libexec/xdg-desktop-portal-hyprland` überein.

- Aufruf: `custom_picker_binary` (sonst `hyprland-share-picker`), Argument `--allow-token`, wenn `screencopy:allow_token_by_default` an ist.
- Umgebung: geerbt von xdph + `WAYLAND_DISPLAY`, `QT_QPA_PLATFORM=wayland`, `XCURSOR_SIZE`, `HYPRLAND_INSTANCE_SIGNATURE`,
  `XDPH_WINDOW_SHARING_LIST` = `<id>[HC>]<Klasse>[HT>]<Titel>[HE>]<Fensteradresse dezimal>[HA>]` je Fenster
  (id = untere 32 Bit des Toplevel-Handles; Adresse 0, wenn xdph keine Zuordnung hat; Anführungszeichen, `$`, Backtick und `>]` werden durch Leerzeichen ersetzt).
- Antwort auf stdout: `[SELECTION]<flags>/<auswahl>`
  - `screen:<Monitor>` · `window:<id>` · `region:<Monitor>@<x>,<y>,<w>,<h>` (x/y relativ zum Monitor, logische Pixel)
  - Flag `r` = Restore-Token erlaubt; andere Flags ignoriert xdph.
  - **Zeilenende nötig:** bei `screen:` schneidet xdph das letzte Zeichen ab (`pop_back`).
- xdph wartet synchron, bis stdout **und** stderr zu sind (`CProcess::runSync`, Hyprutils). Darum hält `share-pick` keine Kindprozesse
  mit geerbtem stdout offen und schließt stderr nicht vorzeitig.

## Dateien

- `scripts/share-pick` – Brücke xdph ↔ Shell (python3, nur Standardbibliothek). Lädt die Shell während der Auswahl neu, zeigt sie dieselbe Anfrage wieder (ein „cancel“ der alten Instanz zählt nicht, erkannt über `sharepicker instance`). Selbsttests ohne Oberfläche:
  `share-pick --format 'ok r/screen:DP-2'` (Ausgabeformat), `share-pick --parse '<Liste>'` (Fensterliste), `share-pick --demo` (mit Karte).
- `shell/modules/sharepicker/SharePicker.qml` – Karte, IPC-Ziel `sharepicker` (`open`, `close`, `alive`, `status`).
  Nur sichtbar, solange eine Anfrage offen ist (`LazyLoader`); Farben, Radien, Abstände aus `theme/palette.json`.
  Vorschauen: `ScreencopyView` (Monitore über wlr-screencopy, Fenster über `HyprlandToplevel.wayland` / hyprland-toplevel-export).
- `scripts/share-picker` – `install [shell|gtk]`, `off`, `status`, `test`, `build`, `css`.

## Test nach dem Aktivieren

1. `scripts/share-picker test` – Karte erscheint, Vorschauen laufen, Pfeile/Tab/Enter/Esc gehen. Ausgabe zeigt, was geteilt *würde*.
2. Equibop: Bildschirm teilen → auf Wayland überspringt Equibop seine eigene Auswahl (`isWayland → skipPicker: true`), es kommt **unsere** Karte.
   Genauso Helium/Chrome (Teilen → Bildschirm) und OBS (Quelle „Bildschirmaufnahme (PipeWire)“).
3. Je einmal Monitor, Fenster und Region teilen; einmal Esc (App meldet „abgebrochen“).
4. Fehler: `~/.local/state/desktop/share-pick.log` (Rückfälle, Zeitlimit, ungültige Antworten – xdph selbst verwirft stderr des Pickers),
   `qs log -p ~/Workspace/bastian-shell/shell`, `journalctl --user -u xdg-desktop-portal-hyprland` (Zeile `[sc] Selection: …`).

## Alternative: GTK-Picker (hyprland-preview-share-picker)

Vorgänger-Lösung, bleibt als Option: `scripts/share-picker build` + `scripts/share-picker install gtk`.
Braucht `sudo dnf install -y gtk4-devel gtk4-layer-shell gtk4-layer-shell-devel`. Config `config/share-picker/config.yaml`,
Stylesheet aus der Palette (`theme/gen/share_picker.py` → `theme/out/share-picker.css`), `test --gtk [--shot x.png]`.
`install gtk` schreibt den Eintrag nur, wenn der Picker gebaut ist und seine Bibliotheken findet; `install` (Shell) entfernt seine Links wieder.

Quellcode-Prüfung (18.10.2026, Commit `7e11349`, Tag v0.3.0, MIT): ~1350 Zeilen Rust, 279 Abhängigkeiten alle von crates.io,
kein Netz, ein Prozessstart (Region-Befehl `slurp`), Wayland nur lesend (`hyprland_toplevel_export_v1`, `wlr-screencopy`), stable-Rust ≥ 1.88 reicht.
Festgenagelt auf den geprüften Commit (`PIN` in `scripts/share-picker`). Grenzen: Monitorkarten im echten Größenverhältnis (nicht gleich groß),
Tastatur erst nach einem Klick (OnDemand), Vorschauen nur SHM `Xrgb8888`.
