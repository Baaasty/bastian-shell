# Privatsphäre-Punkt (Idee i)

Kleine runde Symbole direkt links neben der Uhr (Bar-Mitte), **nur solange etwas aktiv ist** – sonst unsichtbar und ohne Platz.
Sie bleiben auch im Fokus-Modus sichtbar.

| Symbol | Farbe | Bedeutung |
|---|---|---|
| Mikrofon | Amber | eine App nimmt über ein echtes Mikrofon auf (PipeWire-Aufnahme-Stream; Aufnahmen von Lautsprecher-Monitoren zählen nicht) |
| Kamera | Rot/Terrakotta | eine App nutzt die Kamera (PipeWire-/Portal-Stream an der Kamera **oder** ein Programm hat `/dev/video*` direkt geöffnet) |
| Bildschirm teilen | Akzent | ein PipeWire-Screencast-Stream läuft (Portal `xdg-desktop-portal-hyprland`: Discord/Equibop, Browser, OBS …) |

Mit der Maus über dem Symbol steht im Tooltip, welche App („Camera in use: Equibop“).

## Wie es erkannt wird (ohne Dauer-Polling)

- Mikrofon/Teilen/Kamera über PipeWire: `shell/services/Privacy.qml` hört auf Änderungen der PipeWire-Verbindungen (Link-Gruppen) – nur bei Ereignissen.
- Kamera direkt über `/dev/video`: `scripts/privacy-cam` (läuft mit der Shell) wartet per `inotifywait` auf open/close der Kamera-Geräte und schaut erst
  dann in `/proc` nach (ein paar ms). Ohne `inotifywait` prüft es alle 3 s. PipeWire/WirePlumber selbst werden ignoriert.
  Von Hand: `scripts/privacy-cam once` → `{"apps":["equibop"]}`.

## Dateien

- `shell/modules/bar/PrivacyDot.qml` (Punkte + Tooltip, eingehängt in `BarWindow.qml`), `shell/services/Privacy.qml`, `scripts/privacy-cam`
- Farben aus dem Theme (`warning`, `error`, `accent`), App-Namen schöner machen: `Privacy.pretty()`

## Testen ohne Kamera/Mikro

```sh
qs ipc --any-display -p ~/Workspace/desktop-hyprland/shell call privacy status          # Text: mic | camera | sharing
qs ipc ... call privacy simulate mic Discord          # zeigt einen Eintrag an (kind: mic | cam | share), aktiviert nichts
qs ipc ... call privacy clear                         # Test-Einträge weg
```

Grenzen: Eine Mikrofon-Aufnahme, die nur „idle“ im Hintergrund offen gehalten wird (manche Apps halten den Stream), zeigt trotzdem den Punkt.
Kamera-Zugriffe ohne PipeWire und ohne offenes `/dev/video` (z. B. Fremdnutzer) sieht die Shell nicht.
