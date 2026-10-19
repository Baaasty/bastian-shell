# Hyperfokus-Wecker (Pausen-Hinweis)

Nach **90 min am Stück** am PC kommt oben mittig unter der Bar (DP-2) eine ruhige Karte:
„Time for a break“ + ein wechselnder Satz (Wasser, Strecken, in die Ferne schauen). Kein Ton, kein Pulsieren,
keine Tastatur-Übernahme.

| Knopf | Wirkung |
|---|---|
| **Taking a break** | Zähler beginnt neu |
| **10 more min** | Karte kommt in 10 min wieder (falls bis dahin keine Pause war) |
| **Not today** | heute still, morgen wieder normal |

**Pause zählt von selbst:** 5 min ohne Maus/Tastatur setzen den Zähler zurück (die Karte geht dann auch weg) –
auch wenn dabei ein Video läuft.
Ebenso: Pause-Block des Fokus-Timers, Ruhezustand oder Shell länger als 5 min aus.

**Schweigt** bei Vollbild, Spiel, Spiele-Modus (`Super+Alt+G`), Feierabend (`Super+Alt+B`), Discord-Call,
laufendem Fokus-Block und Sperrbildschirm. Ist der Hinweis fällig, kommt er, sobald nichts mehr dagegen spricht
(z. B. direkt nach dem Fokus-Block, dann unter dessen Pausen-Banner).

Fortschritt: im Dashboard, Fokus-Kachel, Zeile „Screen time … · break in 34 min“. Keine Fläche in der Bar.

## Einstellungen

`config/breaks.json` (live gelesen). Eigene Werte besser in `~/.config/desktop/breaks.json` – Schlüssel dort ersetzen die aus dem Repo.

| Schlüssel | Standard | Bedeutung |
|---|---|---|
| `enabled` | `true` | ganz an/aus |
| `afterMin` | `90` | Minuten am Stück bis zum Hinweis (5–600) |
| `breakMin` | `5` | so lange ohne Eingabe = Pause (1–60) |
| `snoozeMin` | `10` | „more min“-Knopf |
| `respectInhibitors` | `false` | `false`: auch ein laufendes Video (Idle-Inhibit) ohne Maus/Tastatur zählt als Pause · `true`: Inhibit-Zeit zählt nicht als Pause |
| `silentScenes` | `["game", "evening"]` | Szenen aus `config/scenes.json`, in denen er schweigt |
| `messages` | 5 Sätze | einer wird zufällig gezeigt |

Beispiel `~/.config/desktop/breaks.json`: `{ "afterMin": 75, "snoozeMin": 15 }`

## Befehle

```sh
IPC="qs ipc --any-display -p ~/Workspace/bastian-shell/shell call breaks"
$IPC status        # JSON: activeMin, leftMin, due, shown, silent (warum still), snoozedMin, offToday, idle
$IPC test          # Karte sofort zeigen (ohne Bedingungen) · $IPC hide schließt die Test-Karte
$IPC snooze        # wie „10 more min“ · snoozeFor 30 = eigene Minuten
$IPC reset         # alles zurück: Zähler, Snooze, „Not today“
$IPC off           # wie „Not today“
```

## Aufbau

`shell/services/Breaks.qml` (Zähler, Bedingungen, IPC; Leerlauf über `IdleMonitor`), `shell/modules/breaks/BreakCard.qml`
(Karte, Look wie die Claude-Karten). Zustand: `~/.local/state/desktop/breaks.json` (übersteht Shell-Reloads).
Der frühere, abgeschaltete Hyperfokus-Teil des Fokus-Timers (`Focus.hyperDue`, Karte in `FocusUi.qml`) ist entfernt.
