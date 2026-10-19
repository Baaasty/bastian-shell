# Szenen (Spiele-Modus, Fokus-Kopplung, Feierabend)

Eine Szene ist eine Liste von Schritten (Licht, Ruhe, Fenster, Musik …), die auf einer Taste an- und wieder
ausgeht. Alles steht in **`config/scenes.json`**, per Hand änderbar, kein Neustart nötig (die Datei wird live gelesen).
Engine: `shell/services/Scenes.qml`.

## Bedienen

| Was | Wie |
|---|---|
| Spiele-Modus an/aus | `Super+Alt+G` |
| Feierabend an/aus | `Super+Alt+B` |
| Fokus-Szene | automatisch mit dem Fokus-Timer (`Super+Alt+F`, Dashboard, Bar) |
| Terminal | `scripts/scene list` · `scene on\|off\|toggle NAME` · `scene NAME` (= toggle) · `scene status` · `scene check` |
| Trockenlauf | `scripts/scene on game --dry-run` – zeigt mit dem echten Gerätezustand, was passieren würde, ändert nichts |
| IPC | `qs ipc --any-display -p ~/Workspace/desktop-hyprland/shell call scene toggle game` (auch `on`, `off`, `status`) |

## So arbeitet eine Szene

- **An:** Zuerst werden Hue, Key Light und Bildschirmhelligkeit frisch gelesen (bis ~2 s Verzögerung), dann läuft jeder
  Schritt und merkt sich den Zustand davor (nur die Felder, die er ändert). Schon an = nichts passiert.
- **Aus:** Die gemerkten Zustände werden in umgekehrter Reihenfolge zurückgesetzt, danach laufen die `"off"`-Schritte.
- **Tolerant:** Fehlt ein Dienst (Hue nicht gekoppelt, Lampe offline, Spotify aus, Szene nicht vorhanden), wird der
  Schritt übersprungen und im Protokoll vermerkt (`scene status`, `journalctl --user -u … | grep scenes:` bzw. `qs log`).
- **Zustand:** `~/.local/state/desktop/scenes.json` (welche Szenen an sind + Vorher-Werte). Nach einem Shell-Neustart
  werden „Bar weg“ und „Nicht stören“ einer eingeschalteten Szene automatisch wieder gesetzt.
- Mehrere Szenen gleichzeitig sind möglich; am saubersten schaltet man sie in umgekehrter Reihenfolge wieder aus.

## Dateiformat

```json
{
  "settings": { "focusLink": true, "focusScene": "focus" },
  "commands": { "mein-befehl": ["notify-send", "Hallo"] },
  "scenes": {
    "game": {
      "title": "Game mode",
      "on":  [ { "do": "bar", "hidden": true }, { "do": "dnd" } ],
      "off": [ ]
    }
  }
}
```

- `settings.focusLink` – `false` schaltet die Fokus-Kopplung ab; `focusScene` – welche Szene sie schaltet.
- `commands` – **Positivliste** für Schritt `cmd`: nur was hier steht, wird gestartet (Liste aus Wörtern, kein Shell-Text).
- Jede Szene: `title`, `on` (Schritte), `off` (zusätzliche Schritte nach dem Zurücksetzen, optional).
- Jeder Schritt hat `"do": "<Typ>"`, optional `"enabled": false` (überspringen) und `"restore": false`
  (beim Ausschalten nicht zurücksetzen).

## Schritt-Typen

| `do` | Felder | Wirkung (und was beim Ausschalten zurückkommt) |
|---|---|---|
| `hue` | `room` (Standard: PC-Raum „Büro“), dazu entweder `scene` (Name in diesem Raum) · `off: true` · `mirek` (153–500, kleiner = kühler) und/oder `bri` (1–100) | Hue-Raum schalten. Zurück: vorherige aktive Szene bzw. Farbtemperatur/Farbe + Helligkeit, oder aus |
| `keylight` | `on`, `brightness` (3–100), `kelvin` (2900–7000), `only_if_on: true` (nur wenn die Lampe schon an ist) | Elgato Key Light. Zurück: die geänderten Felder |
| `brightness` | `percent` (absolut) oder `scale` (Faktor, z. B. 0.7 = 30 % dunkler), `display` (Anschluss, leer = alle) | Bildschirmhelligkeit per DDC/CI. Zurück: vorherige Werte |
| `dnd` | `value` (Standard `true`) | „Nicht stören“: nur Dringendes poppt auf, der Verlauf füllt sich weiter. Zurück: vorheriger Wert |
| `bar` | `hidden` (Standard `true`) | Bar und Arbeitsplatz-Leiste ganz weg (wie im Vollbild/Spiel). Zurück: vorheriger Wert |
| `park` | `app`: `chat` oder `spotify` | Fenster wegräumen (nur Sichtbarkeit, keine Discord-API). Zurück: wieder holen, wenn es draußen war |
| `music` | `action`: `play` · `pause` · `toggle`, `player`: `spotify` (Standard) oder `any` | Wiedergabe, nur wenn der Player läuft. Zurück: vorheriger Zustand |
| `focus` | `action`: `stop` (Standard) · `start` | Fokus-Timer. Beendet die Fokus-Szene gleich mit. Kein Zurück |
| `cmd` | `name` aus `commands` | Befehl über `systemd-run --user --scope`. Kein Zurück (bei Bedarf einen zweiten Befehl in `"off"`) |

## Mitgelieferte Szenen

- **game** (`Super+Alt+G`): Bar/Leiste weg, „Nicht stören“ an, Hue-Szene „Game“ (**gibt es im Raum Büro noch nicht** –
  in der Hue-App anlegen, dann greift der Schritt; bis dahin wird er übersprungen). Chat bleibt wie er ist.
- **focus** (automatisch): „Nicht stören“ an, Hue-Büro warm und gedimmt (400 Mirek, 40 %). Chat wegräumen ist vorbereitet,
  aber aus: bei `park` `"enabled": false` entfernen. Start des Fokus-Blocks = an; Ende, Stopp oder Pausen-Block (Break) = aus;
  „Pause“ des Timers (`paused`) ändert nichts.
- **evening** (`Super+Alt+B`): Fokus beenden, „Nicht stören“ aus, Hue-Büro warm (400 Mirek, 45 %), Key Light auf 3000 K
  (nur wenn an), Bildschirme auf 70 %, Spotify „play“ (nur wenn Spotify läuft; beim Ausschalten wird die Musik nicht angefasst).
  Nochmal drücken = alles zurück.

## Beispiel zum Ergänzen: Szene „movie“

In `config/scenes.json` unter `"scenes"` ergänzen, danach `scripts/scene check`:

```json
"movie": {
  "title": "Movie night",
  "on": [
    { "do": "dnd" },
    { "do": "hue", "scene": "Tokio" },
    { "do": "keylight", "on": false },
    { "do": "brightness", "percent": 50 },
    { "do": "park", "app": "chat" },
    { "do": "cmd", "name": "mein-befehl" }
  ]
}
```

Kürzel dafür: in `hypr/binds.conf` eine Zeile `bind = SUPER ALT, M, exec, $IPC scene toggle movie # Movie night`
(Titel nach `#` nicht vergessen), danach `python3 -I scripts/hotkeys-md`.

## Wenn etwas nicht geht

- `scripts/scene on NAME --dry-run` zeigt, welche Schritte laufen würden und warum einer übersprungen wird.
- `scripts/scene check` findet Tippfehler in Typen und fehlende Befehle.
- Szene „hängt“ auf an (z. B. Bar weg nach Absturz): `scripts/scene off NAME`; zur Not die Datei
  `~/.local/state/desktop/scenes.json` löschen und die Shell neu laden.
- Fokus-Kopplung stört: `"focusLink": false` in `settings`.
- Helligkeit/Hue lesen dauert bis ~4 s, wenn ein Gerät nicht antwortet; dann wird mit den letzten bekannten Werten gearbeitet.
- Grenzen: Hue wird pro Raum zurückgesetzt (einzelne Lampen mit Handwerten ohne Szene werden auf eine gemeinsame
  Helligkeit gesetzt); Key-Light-Farbtemperatur ist auf 50 K genau.
