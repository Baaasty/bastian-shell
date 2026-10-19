# Audio-Mixer (Idee g)

Lautsprecher-Symbol in der Bar (rechts neben CPU/RAM/GPU). Klick öffnet das Popout „Sound“, Klick daneben oder Esc schließt es.
Es ist immer nur ein Bar-Popout offen.

## Was drin ist (oben Routing, darunter die Apps)

| Abschnitt | Inhalt |
|---|---|
| Routing | Zwei gleich gebaute Chip-Zeilen: „Speakers“ (System/Music/Chat → Lautsprecher) und „Discord hears“ (System/Music → Chat-Mic). Darunter einmal „System volume is locked at 100 % (GoXLR)“. Ohne GoXLR Utility: „GoXLR Utility isn’t running“ |
| Channels | GoXLR-Pegel System, Music, Chat, Mic als Zeilen (nur ansehen). „Other channels“ eingeklappt darunter: nur Game, Sample, Headphones mit Pegel > 0. Ohne Utility ausgeblendet |
| Apps | alle App-Streams (Spotify, Discord, übrige; Reihenfolge aus `AudioOut.priority`) mit Symbol, Regler, %, Stumm und darunter klein der Kanal, auf dem die App landet (Music/Chat/System). Leer: „No app is playing sound“ |

Alle Zeilen fluchten: Name links, Chips/Pegel-Balken/Regler ab derselben Spalte (`colX` im Popout), Prozente rechtsbündig untereinander.
App-Namen kommen aus den Streams (`AudioOut.appName`), nichts ist hart umbenannt.

Keine Ausgangs-/Eingangs-Auswahl (Ausgang = GoXLR System, Eingang = Chat Mic, fest). Kanal einer App (Spotify → Music, Discord → Chat, Rest → System): `Mixer.group()` in `shell/services/Mixer.qml`.
Das Dashboard (Kachel „Light & Sound“) zeigt dieselben Pegel als Raster (System, Music, Game, Sample, Headphones, Chat, Mic) und dasselbe Routing.

Die System-Lautstärke bleibt fest auf 100 % (Wächter in `shell/services/Audio.qml`, Schalter `~/.config/desktop/audio.json`,
siehe `docs/setup/goxlr.md`). Der Mixer schreibt nie in einen Ausgang, nur in App-Streams.

## Dateien

- `shell/modules/bar/AudioChip.qml` – Chip + IPC
- `shell/modules/bar/MixerPopout.qml` – Popout
- `shell/services/Mixer.qml` – App-Symbole, Stumm/Lautstärke pro App
- `shell/components/GoxlrPanel.qml` + `GoxlrLevel.qml` – **gemeinsames GoXLR-Widget** (Dashboard: `ControlsTile.qml`, Pegel-Raster + Routing; Popout: `GoxlrPanel` nur fürs Routing mit `outlined: true` = inaktive Chips nur umrandet, Pegel als Zeilen über `GoxlrLevel { nameW: … }`).
  Änderungen an Pegeln/Routing-Zeilen nur dort machen, dann stimmen beide Orte.
- `shell/services/GoXLR.qml` – Daten (Router + Pegel `levels`, Abfrage alle 5 s **nur solange ein Panel sichtbar ist**, `watch()` zählt Zuschauer)
- Apps: `shell/services/AudioOut.qml` (Reihenfolge der wichtigen Apps dort in `priority`)

## Testen ohne Maus

```sh
qs ipc --any-display -p ~/Workspace/bastian-shell/shell call mixer status      # Text: Ausgang, Eingang, Apps, GoXLR
qs ipc ... call mixer open | close | toggle                                       # open per IPC ohne Klick-Fang: mit `close` schließen
qs ipc ... call mixer setApp <App> <0-100>                                        # nur App-Lautstärke
qs ipc ... call mixer muteApp <App> <true|false>
```
Eigener Test-Stream (lautlos): `pw-play -P '{ application.name = "mixertest" }' datei.wav`.
