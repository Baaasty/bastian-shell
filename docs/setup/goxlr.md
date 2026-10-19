# GoXLR (Lautstärke, Fader, Routing)

Bastian regelt alles am GoXLR. Der PC-Ausgang bleibt fest auf 100 %, die Shell hält Fader und Routing ordentlich.
Kein Login nötig (GoXLR Utility läuft lokal, `goxlr.service`, API `http://localhost:14564`).

## Was passiert wann

| Wann | Was |
|---|---|
| Immer | Keine Lautstärke-Tasten (Stumm-, Mikro-, Medien- und Helligkeitstasten bleiben). Wächter in `shell/services/Audio.qml`: ändert sich die Lautstärke des Standard-Ausgangs (GoXLR „System“) von außen, geht sie nach ~0,4 s zurück auf 100 %. Stumm bleibt bedienbar. Kämpft ein Programm dagegen an (>6× in 10 s), pausiert der Wächter 60 s |
| Login | `scripts/goxlr-login` (autostart): wartet auf den Daemon, Routing komplett aus, Standard-Ausgang 100 % + nicht stumm |
| Sperren (Super+L, Leerlauf, Power-Menü) | `scripts/lock` ruft `scripts/goxlr-state lock`: Fader-Stand merken, Routing komplett aus |
| Entsperren | Pfad-Unit `desktop-goxlr-unlock.path` sieht „unlocked“ in `$XDG_RUNTIME_DIR/desktop-lock` → `goxlr-state sync` setzt die Fader exakt zurück (nur abweichende). Routing bleibt aus |
| Herunterfahren/Abmelden | `desktop-keylight-off.service` ExecStop: erst `goxlr-reset-routing`, dann `goxlr-client profiles device save` (Profil ist schon „alles aus“), dann Key Light aus |

Das Dashboard liest den Router alle 5 s (solange offen) und beim Öffnen neu, zeigt also danach „alles aus“.
Routing wieder einschalten: Dashboard-Raster oder GoXLR-App.

## Befehle

```sh
scripts/goxlr-state status            # gemerkter und aktueller Fader-Stand
scripts/goxlr-state save|restore [-n] # von Hand merken / zurücksetzen (-n = nur anzeigen)
scripts/goxlr-state lock|unlock [-n]  # wie beim Sperren/Entsperren
scripts/goxlr-reset-routing -n        # zeigt die geplanten Befehle
scripts/goxlr-reset-routing           # Routing komplett aus (nur echte Änderungen, nacheinander)
```

Fader-Stand: `~/.local/state/desktop/goxlr-faders.json` (Rechte 0600, Rohwerte 0–255; geschrieben wird per HTTP-API,
weil `goxlr-client volume` auf ganze Prozent rundet). Markierung „gesperrt-gemerkt“: `$XDG_RUNTIME_DIR/desktop-goxlr-locked`
(verschwindet beim Abmelden; ein zweites „lock“ überschreibt den gemerkten Stand nicht).

## Schalter (von Hand pflegbar, fehlt die Datei = alles an)

`~/.config/desktop/audio.json`
```json
{ "lockVolume": true, "onlyGoxlr": true }
```
`lockVolume: false` schaltet den Wächter (und das Setzen beim Login) ab. `onlyGoxlr: true` = der Wächter greift nur,
wenn der Standard-Ausgang ein GoXLR ist (nicht z. B. beim HomePod). Wird live gelesen.

`~/.config/desktop/goxlr.json`
```json
{ "restoreFaders": true, "resetRoutingOnLogin": true, "resetRoutingOnLock": true, "resetRoutingOnExit": true }
```

## Einrichtung / Rückbau

Die User-Units liegen im Repo (`systemd/`) und sind nach `~/.config/systemd/user` verlinkt:

```sh
R=~/Workspace/desktop-hyprland/systemd; U=~/.config/systemd/user
ln -sf $R/desktop-keylight-off.service $U/ ; ln -sf $R/desktop-keylight-off.service $U/default.target.wants/
ln -sf $R/desktop-goxlr-unlock.service $U/ ; ln -sf $R/desktop-goxlr-unlock.path $U/
systemctl --user daemon-reload && systemctl --user enable --now desktop-goxlr-unlock.path
```

Zurück: `systemctl --user disable --now desktop-goxlr-unlock.path`, Links wieder auf
`~/Workspace/desktop/systemd/desktop-keylight-off.service` setzen (Sicherung: `desktop-keylight-off.service.vor-goxlr`),
`goxlr-login` in `hypr/autostart.conf` und die Hook-Zeilen `goxlr_lock` in `scripts/lock` entfernen, Lautstärke-Tasten
aus `git log -p hypr/binds.conf` zurückholen. Schneller Weg ohne Code: alle Schalter oben auf `false`.

## Risiken

- Reset beim Sperren/Beenden schaltet auch Mikrofon- und Chat-Routen aus: im Call ist man danach stumm bzw. hört nichts.
  Nach dem Entsperren bleibt es aus (so gewollt) – Routing im Dashboard wieder anschalten.
- Der Fader-Stand wird nur durch Sperren/Entsperren gemerkt, nicht beim Login (das Profil wird beim Herunterfahren gespeichert).
- Wird beim Herunterfahren der Daemon zuerst beendet, bleibt das Profil wie zuletzt (der Reset wird dann übersprungen, ohne Fehler).
