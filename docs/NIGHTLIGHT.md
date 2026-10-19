# Abendwärme (Idee c)

Abends wird der Bildschirm wärmer (3400 K), tagsüber neutral. Werkzeug: **hyprsunset** (Hyprland-eigener Farbfilter,
wirkt über `hyprland-ctm-control` auf **alle Monitore gemeinsam**; pro Monitor geht damit nicht).

## Einmalig installieren (sudo, du)

```sh
sudo dnf install hyprsunset      # liegt im COPR sdegler/hyprland (schon aktiv)
```

Ohne das Paket passiert nichts (Daemon beendet sich still, Befehle melden den Installationshinweis).
Danach: Abmelden/Anmelden oder `uwsm app -- ~/Workspace/bastian-shell/scripts/nightlight daemon &`.

## Befehle (`scripts/nightlight`)

| Befehl | Wirkung |
|---|---|
| `status [--json]` | Zustand, aktuelle Kelvin, Zeiten von heute |
| `on` / `off` | jetzt warm / neutral, **bis zum nächsten Zeitplan-Wechsel** |
| `toggle` | warm ⇄ neutral (Kürzel **Super+Alt+N**) |
| `set 4200` | feste Temperatur (1000–6500) bis zum nächsten Wechsel |
| `auto` | zurück zum Zeitplan |
| `check` | Zeitplan von heute und Kurve alle 2 h (ändert nichts) |
| `daemon` | Dauerläufer (Autostart in `hypr/autostart.conf`), prüft alle 15 s |

## Konfiguration von Hand: `config/nightlight.json`

Gilt innerhalb von 15 s, kein Neustart.

| Schlüssel | Bedeutung |
|---|---|
| `evening.at` / `morning.at` | `"sunset"`, `"sunrise"` (aus Ort) oder feste Uhrzeit `"21:30"` |
| `evening.offsetMin` / `morning.offsetMin` | verschiebt den Wechsel (negativ = früher) |
| `latitude` / `longitude` | eigener Ort für Sonnenzeiten (optional; ohne Eintrag gilt `location` aus `secrets.json` wie beim Wetter, sonst Berlin) |
| `dayK` / `warmK` | neutral (6500 = Filter aus) / abends (3400) |
| `transitionMin` | Dauer des weichen Übergangs (30) |
| `pauseInFullscreen` | im echten Vollbild (Spiele, Video) neutral (Standard an) |
| `manualUntilNextChange` | `on/off/set` gelten bis zum nächsten Wechsel (sonst bis `auto`) |
| `enabled` | `false` = nie filtern |

Beispiel „immer 21:00 bis 07:00“: `"evening": {"at": "21:00"}`, `"morning": {"at": "07:00"}`.

## Wie es läuft

Der Daemon startet `hyprsunset` (falls nicht schon da), berechnet pro Tick die Soll-Temperatur
(sanfte Kurve über `transitionMin`) und ruft `hyprctl hyprsunset temperature <K>` bzw. `identity`.
Er setzt nur bei Änderung ab 15 K neu und nach einem hyprsunset-Neustart. Zustand von Hand-Eingriffen:
`~/.local/state/desktop/nightlight.json`. Beendet man den Daemon (SIGTERM), geht ein von ihm gestartetes
hyprsunset mit aus: Farben zurück auf neutral.

## Nicht gebaut / Ideen

- Theme-Variante nach Tageszeit (hearth heller/dunkler): bewusst nicht jetzt.
- Schalter in der Shell: nur CLI + Super+Alt+N (Kürzel steht im Super+K-Viewer).
- Not-Aus: `scripts/nightlight off` oder `pkill -x hyprsunset` (Farben sofort normal).
