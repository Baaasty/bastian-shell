# Hardware – Facecam, RGB

GoXLR (Lautstärke, Fader, Routing): [setup/goxlr.md](../setup/goxlr.md).

## Facecam (Elgato MK.1, `0fd9:0078`)

Stand 2026-10-18 · Firmware 4.09 · Kernel 7.2. Umsetzung: `scripts/camera` (Python, nur stdlib, ioctl) +
`shell/services/Camera.qml`, Fader „Brightness“ im Dashboard → Controls.

- **Helligkeit** läuft über den normalen UVC-Regler `brightness` (0–255), Auto-Belichtung bleibt an. Eine
  „Exposure Compensation“ gibt es bei der MK.1 nicht (nur Facecam Pro). Gemerkt wird nur die Wunsch-Helligkeit
  (`~/.local/state/desktop/camera.json`); beim Einschalten der Kamera setzt die Shell nach 1,5 s Auto + 50 Hz + Helligkeit.
- **Setzen geht nur, während die Kamera streamt** (sonst EPIPE). „Streamt“ erkennt das Skript am Anstieg von `urbnum`
  des USB-Geräts, nicht per GET – jedes GET ohne Stream schreibt eine Fehlerzeile ins Kernel-Log.
- **Warum `v4l2-ctl` die Regler nicht zeigt:** Beim ersten Abfragen nach dem Login streamt die Kamera nicht und beantwortet
  GET_DEF mit Stall; uvcvideo setzt dann `V4L2_CTRL_FLAG_DISABLED` („UVC non compliance: permanently disabling control“).
  Das Flag wirkt nur beim Auflisten, `VIDIOC_G/S_CTRL` mit der ID geht weiter an die Kamera – daher das eigene ioctl-Tool.
- **Elgato-Extension-Unit** (Unit 3, GUID `{a8e5782b-36e6-4fa1-87f8-83e32b323124}`, `UVCIOC_CTRL_QUERY`, ohne root).
  Namen aus der Disassembly von Camera Hub 1.5.2. Nutzbar: 8 Metering, 18 Rauschfilter, 20 Belichtungszeit (50 µs),
  21 AE-Geschwindigkeit, 25 AE-Lock. **Nie anfassen:** 19 (Service-Mode), 26–28 (unbekannt) und das HID-Interface
  (`hidraw`: Profile, Firmware, Bootloader). `gain`/`backlight_compensation` fehlen, kein voll manueller Belichtungsmodus.
- Werte sind flüchtig (RAM, nach Abstecken weg). Auf den Flash schreibt nur Camera Hub über HID – das fassen wir nicht an.
- Hängt sich die Kamera beim Starten/Stoppen von Streams auf, hilft nur Abstecken.
- **Offen:** ob `brightness` im Auto-Modus das AE-Ziel verschiebt oder nur aufhellt. Reicht es nicht, der Reihe nach:
  Metering auf Mitte (Sel 8, die eigentliche Gegenlicht-Lösung), AE-Lock (Sel 25), zuletzt Software-Filter per
  v4l2loopback (Kernelmodul, CPU, Latenz).

## RGB (OpenRGB)

`scripts/rgb` setzt alle RGBs im PC **statisch** auf `accent` der aktiven Palette-Variante (hearth `#DB6B4C`), kein Effekt.
Hardware: MSI MPG B550 Gaming Plus (Mystic Light, `1462:7c56`), NZXT Smart Device V2 (`1e71:200f`), RAM über SMBus
(`/dev/i2c-0…2`, PIIX4), evtl. GPU; Maus/Tastatur, wenn OpenRGB sie erkennt.

- OpenRGB **ohne Server** (`--noautoconnect`): ein Scan, dann je Gerät der erste passende Modus `Static` → `Fixed` (NZXT)
  → `Direct`. Jeder Aufruf höchstens 90 s, eine Sperre verhindert parallele Läufe; fehlt openrgb: eine Logzeile, Exit 0.
  Den System-Dienst `openrgb.service` nicht einschalten.
- Wann: beim Login (`hypr/autostart.conf`, `--boot`) und nach Standby (`after_sleep_cmd` in `hypr/hypridle.conf`,
  `--delay 3`, bis USB wieder da ist). Nach `scripts/rice variant` einmal `scripts/rgb apply`, sonst erst beim nächsten Login.
- Rechte: `openrgb-udev-rules` (sudo, zusammen mit `openrgb`) gibt dem Login per `uaccess` Zugriff auf alle `/dev/i2c-*`
  und die USB-Geräte; keine Gruppe nötig. Geräte auslassen: `~/.config/desktop/rgb.json` → `{"skip": ["G502"]}`.

Stolperfallen:

- Keine Geräte: udev-Regeln neu laden oder neu starten; `ls -l /dev/i2c-0` muss ein `+` (ACL) zeigen.
- NZXT-Lüfter/Streifen dunkel: Zonengröße fehlt → einmal im OpenRGB-Fenster „Resize zone“ setzen (wird gemerkt).
- RAM fehlt: im OpenRGB-Fenster unter Supported Devices aktivieren; Kernel-Parameter erst danach (Wiki „SMBus Access“).
- Nach Standby falsche Farbe: hypridle mit neuer Config neu starten, sonst `--delay 5`.
  Log: `journalctl --user --since -5min | grep rgb`.
