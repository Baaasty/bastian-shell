# Netz-Popout (Idee h)

Netz-Chip in der Bar (rechts neben dem Lautsprecher): nur ein Symbol (Kabel / WLAN / VPN), offline = Wolke in Warnfarbe.
Klick öffnet das Popout, Klick daneben oder Esc schließt es. Tastatur: Bar-Modus (Super+B), Pfeile/Tab, Enter (`KeyNav.qml`).

## Was drin ist (bewusst schlicht)

| Bereich | Inhalt |
|---|---|
| Kopf | Eine Zeile: **Online** / **No internet** / **Offline** + Ping ins Internet. Online = ein Ziel außer dem Router antwortet. Rechts „Details“ |
| Details (zugeklappt) | Name, Link-Geschwindigkeit, IP, Router, WLAN-Signal, Durchsatz gerade jetzt |
| Reachability | Ping zu Internet (1.1.1.1), Router, GitHub, Discord – Punkt grün (gut) / gelb (ab 150 ms oder Paketverlust) / rot (keine Antwort) |
| Last hour | Ø-Durchsatz ↓/↑ in Mbit/s + kleines Diagramm (Minutenmittel, bis 60 Punkte; ↓ Fläche, ↑ Linie), Spitze |
| Speed test | Knopf „Run“: lädt 25 MB von `speed.cloudflare.com` (curl), Ergebnis in Mbit/s. **Nur auf Knopfdruck**, nie automatisch |

Kein VPN-Bereich mehr (Tailscale deinstalliert, 2026-10-19).

## Konfiguration (optional)

`~/.config/desktop/net.json` – fehlt die Datei, gilt dies:
```json
{ "targets": [ { "name": "Internet", "host": "1.1.1.1" }, { "name": "Router", "host": "gateway" },
               { "name": "GitHub", "host": "github.com" }, { "name": "Discord", "host": "discord.com" } ], "count": 2 }
```
`gateway` = dein Router (Standardroute). Bis zu 6 Ziele. `count` = Pakete pro Messung (1–5). Hosts dürfen nur Buchstaben, Ziffern und `. : - _` enthalten.
Wird beim nächsten Messen (alle 3 s bei offenem Popout) gelesen.

## Wann wird gemessen?

- Chip-Anzeige: nur bei Netz-Ereignissen (`ip monitor link address route`, entprellt 1,2 s) – kein Dauer-Polling.
- Ping, Verbindung: **nur solange das Popout offen ist** (Ping alle 3 s, Verbindung alle ~15 s).
- Durchsatz („Last hour“): läuft dauerhaft, aber sparsam – alle 5 s zwei Byte-Zähler aus `/sys/class/net/<iface>/statistics` lesen,
  pro Minute mitteln, 60 Werte im Speicher (nach Shell-Neustart leer, erster Punkt nach einer Minute).
- Speedtest: nur auf Knopfdruck (ca. 25 MB Download).

## Dateien

- `scripts/netinfo link|ping|config` – alles als JSON, von Hand aufrufbar
- `scripts/tests/netinfo-test.py` – Test mit gespielten Ausgaben (WLAN, Ping)
- `shell/services/NetInfo.qml` – Verbindung/Ping, `shell/services/Net.qml` – Durchsatz-Verlauf + Speedtest
- `shell/modules/bar/NetChip.qml` (+ IPC), `NetPopout.qml` (Diagramm: `components/Graph.qml`)

## Testen ohne Maus

```sh
qs ipc --any-display -p ~/Workspace/desktop-hyprland/shell call net open      # ohne Klick-Fang: mit `net close` schließen
qs ipc ... call net status                                                    # Text: Verbindung, Pings
```
