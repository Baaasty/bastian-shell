# Hue koppeln (Licht im Dashboard)

Die Hue-Kachel im Dashboard (Controls) steuert Räume, Szenen und Farben direkt über die Hue Bridge im
Heimnetz. Dafür braucht die Shell einmal einen **App-Key** von der Bridge. Dauert eine Minute.

## Koppeln

1. PC und Bridge sind im selben Netz.
2. Im Terminal:

   ```sh
   ~/Workspace/desktop/scripts/hue-pair
   ```

3. Die runde Taste oben auf der Bridge drücken, dann Enter. Das Skript wartet bis zu 30 s auf die Taste.
4. „Gekoppelt.“ – fertig. Die Shell merkt die geänderte Datei von selbst, kein Neustart nötig.

Nur schauen, was passieren würde (sendet und schreibt nichts): `scripts/hue-pair --dry-run`

## Neu koppeln

Steht in der Kachel **Invalid Hue key: scripts/hue-pair --force** (Key wurde in der Hue-App gelöscht o. Ä.):

```sh
~/Workspace/desktop/scripts/hue-pair --force
```

Ohne `--force` lässt das Skript einen vorhandenen Key stehen.

## Wo der Key liegt

In `~/Workspace/desktop/secrets.json` (gitignored, Rechte 600) im Abschnitt `hue`:
`key`, `clientkey`, `bridge`, `bridgeId`. Andere Einträge bleiben erhalten. Das Skript gibt den Key nie aus,
die Shell reicht ihn nur als Umgebungsvariable an `curl` weiter (nie in Befehlszeile oder Log).

Die Bridge-Adresse (`hue.bridge`) liest die Shell aus `secrets.json`. Ohne Eintrag sucht `scripts/hue-pair`
die Bridge über discovery.meethue.com; vorgeben geht mit `scripts/hue-pair --bridge <IP>`. Bekommt die Bridge
eine neue IP: `hue.bridge` in `secrets.json` anpassen (Key bleibt gültig).

## Wenn etwas nicht geht

| Anzeige in der Kachel | Was tun |
|---|---|
| „Pair Hue: scripts/hue-pair“ | Noch nicht gekoppelt – siehe oben. |
| „Invalid Hue key: scripts/hue-pair --force“ | Neu koppeln mit `--force`. |
| „Bridge unreachable“ | Bridge an? Gleiches Netz? IP noch aktuell? |

**Entkoppeln:** den Block `hue` aus `secrets.json` löschen.
