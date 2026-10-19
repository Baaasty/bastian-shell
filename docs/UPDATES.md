# Update-Chip

Kleiner Chip in der Bar (rechts, vor dem Tray): Update-Symbol + Zahl. **Nur sichtbar, wenn Updates da sind** (dnf inkl. COPR + Flatpak).
Installiert wird nie automatisch – das machst du im Paketmanager.

| Maus | Wirkung |
|---|---|
| Links-Klick | Paketmanager (Super+P) öffnet sich auf dem Reiter **Updates** |
| Rechts-Klick | sofort neu prüfen (Symbol dreht auf „sync“, solange es läuft) |

## Wann wird geprüft?

- **3 min nach dem Start** der Shell, danach **alle 4 h** (gerechnet ab der letzten Prüfung – ein Neustart der Shell prüft nicht jedes Mal).
- dnf-Metadaten werden höchstens **1× am Tag** erzwungen neu geladen (`scripts/pkg refresh` = `dnf makecache --refresh`, ohne Root);
  sonst lädt dnf sie nur, wenn sie abgelaufen sind.
- Hat sich die RPM-Datenbank oder Flatpak geändert (du hast installiert/aktualisiert), wird 1 min später neu gezählt
  (alle 5 min ein `stat` auf `rpmdb.sqlite` und die Flatpak-`.changed`-Dateien).
- Alles mit **niedriger Priorität**: `nice -n 19 ionice -c 3`. Backend ist dasselbe wie beim Paketmanager: `scripts/pkg updates system|flatpak`.

Letztes Ergebnis: `~/.local/state/desktop/updates.json` (Zahl steht nach einem Shell-Neustart sofort da). Löschen = beim nächsten Start neu prüfen.

## Dateien

- `shell/services/Updates.qml` – Prüfen, Zeitplan, IPC
- `shell/modules/bar/UpdatesChip.qml` – Chip (in `BarWindow.qml` eingehängt)

## Testen ohne Maus

```sh
S=~/Workspace/bastian-shell/shell
qs ipc --any-display -p $S call updates status    # Zahl, letzte Prüfung, nächste in min, Fehler
qs ipc --any-display -p $S call updates check     # jetzt prüfen (refresh = mit erzwungenem dnf-Refresh)
qs ipc --any-display -p $S call updates fake 5    # Chip mit 5 erfundenen Updates zeigen (nächste Prüfung überschreibt)
qs ipc --any-display -p $S call updates open      # Paketmanager auf „Updates“
```
