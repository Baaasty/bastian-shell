# Benachrichtigungen: Später erinnern, Ruhezeiten, Hover

Alles dateibasiert, ohne KI pflegbar. Meldungen kommen weiter über `shell/services/Notifs.qml` (Popups unten rechts unter der Bar, Verlauf im Dashboard-Panel „Notifications“).

## Später erinnern (Snooze)

- **Popup:** Maus auf die Karte, oben rechts erscheint eine Uhr. Klick → drei Knöpfe **10 min / 1 hour / Tomorrow**. Die Karte verschwindet.
- **Panel:** Maus auf eine Zeile, die Uhr ersetzt die Uhrzeit. Klick → Knöpfe (mit ✕ zum Abbrechen). Oben im Panel steht „N snoozed · next HH:MM“.
- **Zur Zeit** kommt die Meldung als neue Meldung wieder (Popup mit „· reminder“, danach auch im Panel). Sie wartet, solange Ruhezeit, Fokus-Block oder „Nicht stören“ läuft (Dringendes kommt trotzdem), und kommt höchstens zwei auf einmal (kein Sturm).
- **Tomorrow** = 08:00 am nächsten Tag; zwischen 00:00 und 05:00 heute 08:00.
- Gespeichert in `~/.local/state/desktop/notifs-snoozed.json` (übersteht Shell-Neustart und Abmelden). Zurückstellen von Hand: Datei bearbeiten (`due` = Zeit in ms).

## Hover hält alles an

Solange die Maus auf **irgendeinem** Popup liegt (auch auf Uhr/Knöpfen), läuft für **alle** Popups der Auto-Timeout (6 s) nicht weiter, nichts wird zusammengefasst, nichts rutscht aus dem Blick, neue Meldungen reihen sich unten ein (die 4er-Grenze gilt nur ohne Hover). Beim Weggehen läuft die Restzeit weiter, mindestens 1,5 s. Dringende Popups bleiben wie immer bis Klick.

## Ruhezeiten

Standard in `config/notifications.json`, eigene Werte in `~/.config/desktop/notifications.json` (dort ersetzt jeder Schlüssel `quiet`, `through`, `apps`, `snooze` den aus dem Repo; beide Dateien werden live gelesen).

```json
{
  "quiet": {
    "enabled": true,
    "summary": true,
    "windows": [
      { "from": "22:00", "to": "07:00", "days": [] },
      { "from": "12:00", "to": "13:00", "days": ["weekdays"] }
    ]
  },
  "through": {
    "critical": true,
    "rules": [ { "summary": "is calling|incoming call|ringing|anruf" }, { "app": "^claude" } ]
  },
  "apps": [ { "app": "^spotify", "mode": "panel", "when": "always" } ],
  "snooze": { "minutes": [10, 60], "morning": "08:00" }
}
```

- **windows:** `from`/`to` als `HH:MM`; `from` > `to` geht über Mitternacht. `days` = Tage, an denen das Fenster **beginnt** (`mon`…`sun`, `weekdays`, `weekend`, Zahlen 1=Mo…7=So; leer = alle). Mehrere Fenster möglich. `enabled: false` schaltet alles ab.
- **In der Ruhezeit:** kein Popup, die Meldung liegt nur im Panel. Nach dem Ende kommt **einmal** unten mittig „N while you were away · in the panel“ (12 s, Klick schließt; erst wenn du da bist: nicht gesperrt, nicht im Leerlauf). `summary: false` = kein Hinweis.
- **through (kommt durch):** dringende (`critical`) Meldungen und alles, was zu einer Regel passt. Regel = Regex (ohne Groß/Klein) auf `app` (App-Name oder desktop-entry) und/oder `summary` (Titel); `enabled: false` schaltet eine Regel ab. Voreinstellung: Anrufe (Titel mit „is calling“, „incoming call“, „ringing“, „Anruf“) und Claude. Die Claude-Antwort-Karten der Shell (Erlaubnis/Frage) sind keine Benachrichtigungen und werden von Ruhezeiten nie berührt.
- **apps:** eigene Regeln je App. `mode: "panel"` = nie als Popup, nur im Panel; `mode: "hide"` = gar nicht anzeigen (auch nicht im Panel). `when: "quiet"` = nur in den Ruhezeiten, sonst immer. Dringende Meldungen werden nie versteckt.
- **Nicht stören / Fokus-Modus** (`Notifs.dnd`, `Focus.active`) bleiben wie sie waren: dann poppt nur Dringendes auf. Ruhezeiten kommen obendrauf.
- Töne: die Shell spielt keine; Apps mit eigenem Ton bleiben dabei (Ton lässt sich von hier aus nicht stummschalten).

## Prüfen (ohne Tasten)

```
qs ipc --any-display -p ~/Workspace/desktop-hyprland/shell call notifs status
… call notifs quietAt 2026-10-18T23:30      # liegt die Zeit in einer Ruhezeit? (nur Logik)
… call notifs decide Test "Titel" false      # was würde mit so einer Meldung passieren?
… call notifs snooze 0 10                    # Panel-Eintrag 0 um 10 min zurückstellen (0 Minuten = „Tomorrow“)
… call notifs snoozed ; … call notifs wake   # Liste (ohne Inhalte) / sofort fällig machen
… call notifs forget Test                    # Test-Meldungen einer App aus dem Panel entfernen
… call popups fakeHover true|false ; … call popups state   # Hover vortäuschen
node scripts/tests/timewin-test.js           # Zeitfenster-/Snooze-/Regel-Logik
notify-send -a Test "Titel" "Text"           # Test-Meldung (danach `notifs forget Test`)
```

## Technik

`shell/services/NotifRules.qml` (Konfiguration, Entscheidung) · `shell/services/timewin.js` (reine Logik, Test oben) · `shell/services/Notifs.qml` (Verlauf, Snooze, Zähler) · `shell/modules/notifications/{Popups,SnoozeChips,QuietSummary}.qml` · `shell/modules/dashboard/NotifsTile.qml`. Zustand: `~/.local/state/desktop/notifs-snoozed.json`, `notifs-quiet.json` (Zähler „N while you were away“), `notifications.json` (Verlauf).
