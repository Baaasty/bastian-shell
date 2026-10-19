# Morgen-Übersicht

Beim ersten Mal am Tag, wenn du morgens am Rechner bist, erscheint **eine ruhige Karte** (kein Dialog-Stapel) mit: Begrüßung nach Tageszeit, **Termine heute**, **ungelesene Mails** (Absender – Betreff der neuesten zwei, wie im Dashboard), **Wetter** (jetzt), **offene To-dos** (alle Listen, plus „due today“ aus dem Kalender) und die Zahl der **offenen Zeilen in `~/Notes/inbox.md`** (nur wenn > 0). Bereiche ohne Daten/Konto fehlen einfach.

Schließen: **Klick** (irgendwo), **Esc / Enter / Leertaste** (sobald die Karte den Tastaturfokus hat: nach Überfahren oder Klick) oder von selbst nach **20 s** (Überfahren mit der Maus hält sie offen; ein dünner Streifen zeigt die Restzeit).

## Wann kommt sie?

Alle 15 s prüft die Shell. Sie kommt, sobald alles stimmt:
1. die Uhrzeit liegt im Fenster (Standard **05:00–11:00**),
2. heute war noch keine (`~/.local/state/desktop/morning.json`, `{"day": "2026-10-18"}`),
3. die Shell läuft seit `delaySec` (30 s, damit Dienste da sind),
4. du bist da: nicht gesperrt, nicht im Leerlauf (2 min), kein Spiel/Vollbild, kein Fokus-Block, kein „Nicht stören“,
5. Termine, Mail und Wetter sind geladen (oder 15 s Geduld sind um).

Das deckt erster Login, Aufwachen und Entsperren morgens ab. Liegt der Login außerhalb des Fensters (z. B. 13 Uhr), kommt keine.

## Einstellen (`~/.config/desktop/morning.json`, optional)

```json
{ "enabled": true, "from": "05:00", "to": "11:00", "delaySec": 30, "closeSec": 20 }
```

Fehlt die Datei oder ein Feld, gelten diese Werte. `enabled: false` = nie. Datei wird live gelesen.

## Testen und Kürzel

```
qs ipc --any-display -p ~/Workspace/bastian-shell/shell call morning open     # jetzt zeigen (Zustand bleibt)
… call morning hide | toggle | status                                            # status = Zeitfenster, heute gezeigt?, Dienste geladen? (keine Inhalte)
… call morning reset                                                             # „heute war noch keine“
… call morning inWindowAt 2026-10-19T08:00                                       # Logik für eine Zeit
node scripts/tests/timewin-test.js
```

`morning show` kann `qs ipc` nicht aufrufen (die Kommandozeile hält „show“ für ihren eigenen Befehl), darum heißt die Funktion **`open`**. Für ein Kürzel in `hypr/binds.conf`: `qs ipc --any-display -p ~/Workspace/bastian-shell/shell call morning toggle`.

## Technik

`shell/services/Morning.qml` (Auslöser, Zeitfenster, Zustand, IPC) · `shell/modules/morning/MorningCard.qml` (Karte) + `MorningRow.qml` · Logik in `shell/services/timewin.js` · Daten aus `Agenda`, `Mail`, `Weather`, `Todos`, `Notes`.
