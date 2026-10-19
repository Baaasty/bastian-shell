# PC-Beleuchtung (AP 23)

Beim Login setzt `scripts/rgb apply --boot` alle RGBs im PC **statisch auf eine Farbe**: `accent` der aktiven
Palette-Variante (`defaultTheme` in `theme/palette.json`, heute **hearth** = `#DB6B4C`). Kein Effekt.

Werkzeug: OpenRGB ohne Server (`--noautoconnect`). Erst ein Scan, dann pro Gerät der erste passende Modus
`Static` → `Fixed` (NZXT) → `Direct` (Rückfall). Autostart-Zeile in `hypr/autostart.conf`, läuft als eigene Unit
im Hintergrund, jeder OpenRGB-Aufruf höchstens 90 s. Fehlt openrgb: eine Zeile im Log, Exit 0.
**Nach Standby** setzt hypridle die Farbe neu (`after_sleep_cmd` in `hypr/hypridle.conf`, hört auf logind
PrepareForSleep): `scripts/rgb apply --boot --delay 3` als eigene uwsm-Unit, 3 s Pause, bis USB wieder da ist.
Eine Sperre verhindert, dass zwei Läufe gleichzeitig an die Geräte gehen. Maus und Tastatur färbt es mit, wenn
OpenRGB sie erkennt.

Hardware: MSI MPG B550 GAMING PLUS (Mystic Light, USB `1462:7c56`), NZXT Smart Device V2 (USB `1e71:200f`),
RAM über SMBus (`/dev/i2c-0…2`, PIIX4), evtl. die Grafikkarte (`/dev/i2c-3…8`).

## Einrichten (einmalig, du, mit sudo)

```bash
sudo dnf install openrgb openrgb-udev-rules
sudo udevadm control --reload-rules && sudo udevadm trigger   # oder neu starten
scripts/rgb status     # Geräte da?
scripts/rgb apply      # Farbe setzen
pkill hypridle; uwsm app -- hypridle &   # einmal, damit hypridle das Standby-Neusetzen lädt
```

Rechte: `openrgb-udev-rules` gibt deinem Login Zugriff (`uaccess`) auf **alle** `/dev/i2c-*` (RAM/Mainboard)
und auf die USB-Geräte (MSI 7C56 und NZXT 200f stehen drin). Keine Gruppe nötig. `i2c-dev` lädt schon
(`i2c-tools.conf`), `i2c_piix4` auch. Heute sind `/dev/i2c-0…2` nur für root – nach den Regeln nicht mehr.
Den System-Dienst `openrgb.service` **nicht** einschalten (das Skript braucht keinen Server).

## Benutzen

| Befehl | Was |
|---|---|
| `scripts/rgb apply` | Palette-Farbe setzen (das macht auch der Login) |
| `scripts/rgb color ff8800` | einmalig andere Farbe, bis zum nächsten `apply`/Login |
| `scripts/rgb off` | alles aus (`Off`-Modus, sonst Schwarz) |
| `scripts/rgb status` | Geräte und Modi auflisten |
| `scripts/rgb plan [hex]` | zeigen, was gesetzt würde, ohne etwas zu ändern |

Gerät auslassen (Standard: keins, alles wird gefärbt): `~/.config/desktop/rgb.json` → `{"skip": ["G502"]}` (Teil des Namens).

## Farbe ändern

Die Farbe kommt immer aus der Palette. Nach `scripts/rice variant <name>` oder einer Änderung an `accent`
einmal `scripts/rgb apply` (sonst erst beim nächsten Login).

## Wenn etwas fehlt

- **Keine Geräte**: udev-Regeln neu laden (oben) oder neu starten; `ls -l /dev/i2c-0` muss ein `+` (ACL) zeigen.
- **Lüfter/Streifen am NZXT bleiben dunkel**: Zonengröße fehlt. Einmal `openrgb` (Fenster) öffnen, beim Gerät
  „Resize zone“ die LED-Zahl setzen, schließen. OpenRGB merkt sich das und lädt es beim nächsten Scan.
- **RAM fehlt**: `scripts/rgb status` zeigt nur USB-Geräte → im OpenRGB-Fenster unter Settings → Supported Devices
  nachsehen, ob der RAM-Typ aktiv ist. Kernel-Parameter erst, wenn das nicht hilft (OpenRGB-Wiki „SMBus Access“).
- **Nach Standby falsche Farbe**: läuft hypridle mit der neuen Config (neu starten, siehe oben)? Log:
  `journalctl --user --since -5min | grep rgb`. Reichen 3 s nicht, in `hypr/hypridle.conf` `--delay 5` setzen.

## Rückweg

- Nur nicht mehr beim Login: Zeile `scripts/rgb apply --boot` in `hypr/autostart.conf` löschen.
- Nicht mehr nach Standby: in `hypr/hypridle.conf` bei `after_sleep_cmd` den Teil ab `; uwsm app -- …rgb…` löschen,
  hypridle neu starten.
- Farbe der Hardware zurück: `scripts/rgb off` oder in OpenRGB/MSI-BIOS einen Effekt wählen.
- Ganz weg: `sudo dnf remove openrgb openrgb-udev-rules` (OpenRGB-Einstellungen in `~/.config/OpenRGB`).
