# Kamin-Idle (Idee q)

Nach 3 min Leerlauf zeigt der **Hauptmonitor (DP-2)** einen ruhigen, flachen Kamin mit kleiner Uhr (Creme,
wandert einmal pro Minute ein paar Pixel gegen Einbrennen). Die **anderen Monitore** werden dunkel.
**Taste oder Mausbewegung beendet ihn sofort.** Er ist **keine Sperre**.

## Ablauf (`hypr/hypridle.conf`)

| Zeit | Aktion |
|---|---|
| 3:00 | Kamin-Idle an (`scripts/idle show`) |
| 5:00 | dimmen (unverändert; legt sich über den Kamin) |
| 5:05 | **sperren** (unverändert, `scripts/lock idle`; die Sperre liegt über dem Kamin) |
| 6:05 | Monitore aus (unverändert) |

Fokus-Block läuft: Kamin erst nach 13 min (`show force`), Dimmen/Sperren wie bisher nach 15 min.
Videos/Spiele/Inhibit halten hypridle an, dann kommt auch der Kamin nicht. Zum Abschalten: den
`listener` mit `timeout = 180` (und 780) in `hypr/hypridle.conf` löschen, hypridle neu starten.

hypridle liest die Datei nur beim Start: `pkill hypridle; uwsm app -- hypridle &` (oder neu anmelden).

## Befehle

```sh
scripts/idle show [force] | hide | toggle | status
qs ipc --any-display -p ~/Workspace/desktop-hyprland/shell call fireplace on true|false   # on(force)
qs ipc ... call fireplace off | toggle | status
```

IPC-Ziel heißt `fireplace` (nicht `idle`: das gehört der Lock-Kette), die Funktion `on` statt `show`
(„show“ kollidiert mit dem Unterbefehl `qs ipc show`).

## Aufbau

`shell/modules/idle/`: `Idle.qml` (Fenster je Monitor, Layer Overlay, IPC, Maus beendet), `Fireplace.qml`
(Szene), `Flame.qml` (flache Flamme). Fenster existieren nur, solange der Kamin sichtbar ist.
Farben aus Theme-Tokens (`accent`, `warning`, `accentText`, `wood`, `woodLight`, `bgBottom`).

**Sparsam:** kein Dauer-Animieren (360-Hz-Monitor). Die Flammen springen per Timer in Schritten
(160 ms = ca. 6 Bilder/s), Glut ebenso, Uhr alle 60 s. Gemessen: ~0,5 % CPU eines Kerns.

## Sicherheit

Der Kamin sperrt nichts. Entsperrt wird weiter nur per Passwort; die Sperre (ext-session-lock) liegt über
dem Kamin. Fällt hypridle aus, beendet jede Mausbewegung ihn nach 1,5 s selbst.
Anpassen: Bild in `Fireplace.qml` (Größen in „Einheiten“ ~ 1/1000 Bildschirmhöhe), Start nach Leerlauf in `hypridle.conf`.
