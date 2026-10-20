# Hardware – Facecam, RGB

GoXLR (Lautstärke, Fader, Routing): [setup/goxlr.md](../setup/goxlr.md).

## Facecam (Elgato MK.1, `0fd9:0078`)

Stand 2026-10-18 · Firmware 4.09 · Kernel 7.2. Umsetzung: `scripts/camera` (Python, nur stdlib, ioctl) +
`shell/services/Camera.qml`, Fader „Brightness“ im Dashboard → Controls.

- **Helligkeit** läuft über den normalen UVC-Regler `brightness` (0–255), Auto-Belichtung bleibt an. Eine
  „Exposure Compensation“ gibt es bei der MK.1 nicht (nur Facecam Pro). Gemerkt wird nur die Wunsch-Helligkeit
  (`~/.local/state/desktop/camera.json`); beim Einschalten der Kamera setzt die Shell nach 1,5 s Auto + 50 Hz + Helligkeit.
  „Eingeschaltet“ meldet der Kamera-Wächter `scripts/privacy-cam` (inotify, kein Polling – siehe shell-features „Privatsphäre-Punkte“).
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
- „Streamt“ heißt > 100 URBs je 250 ms (`STREAM_URBS`): die Format-Abfrage vor dem Start erzeugt 45–75, ein Stream ab ~150
  (540p MJPG). `apply` wartet einmal 2 s, falls der Stream noch nicht läuft.
- **Discord-Kamera braucht ~7 s bis zum Bild** (gemessen 2026-10-20, `~/.config/discord/logs/discord-webrtc_0`,
  `CreateCapabilityMap`): Discords natives Voice-Modul öffnet `/dev/video0` direkt (kein PipeWire) und probiert wie WebRTC
  15 Formate × 13 Größen per `VIDIOC_TRY_FMT` – uvcvideo schickt dafür jedes Mal einen USB-Probe, die Facecam antwortet in
  ~32 ms → 195 × 32 ms ≈ 6,3 s, danach ~0,5 s bis zum ersten Bild. USB-Autosuspend kostet nur ~0,15 s (einmal Aufwachen),
  daher bleibt er an.
- **Abhilfe `fastprobe`** (`tools/v4l2-fastprobe/fastprobe.c`, LD_PRELOAD, `scripts/app-run discord` lädt sie): beantwortet
  `VIDIOC_TRY_FMT` nur für die Facecam aus dem Zwischenspeicher – Ziel wie uvcvideo gewählt (fourcc sonst Standardformat,
  nächste Größe), je Ziel einmal echt gefragt (≤ 7 Probes). Alles andere geht unverändert durch. Gemessen 6,27 s → 0,17 s,
  alle 195 Antworten gleich (`scripts/fastprobe bench`). Geht nur, weil das Voice-Modul `ioctl` aus der libc importiert
  (kein Syscall direkt) – nach Discord-Updates prüfen: `nm -D …/discord_voice.node | grep ioctl`.
  Rückweg: `scripts/fastprobe off` (oder `.so` löschen) + Discord neu starten; Env `DESKTOP_FASTPROBE=0`, `…_DEBUG=1`.
  Wirkt erst ab dem nächsten Discord-Start über `scripts/app-run` – ob aktiv: `scripts/fastprobe status` muss
  „geladen in Discord-PID …“ zeigen (`/proc/<pid>/environ` taugt nicht, Chromium überschreibt es).
- Hängt sich die Kamera beim Starten/Stoppen von Streams auf, hilft nur Abstecken.
- **Offen:** ob `brightness` im Auto-Modus das AE-Ziel verschiebt oder nur aufhellt. Reicht es nicht, der Reihe nach:
  Metering auf Mitte (Sel 8, die eigentliche Gegenlicht-Lösung), AE-Lock (Sel 25), zuletzt Software-Filter per
  v4l2loopback (Kernelmodul, CPU, Latenz).

## RGB (OpenRGB)

`scripts/rgb` setzt alle RGBs im PC **statisch** auf ein Palette-Token der aktiven Variante (Standard `accent`, wählbar im
Gear-Popout bzw. `rgb set <token|off>`, gemerkt in `rgb.json` `color`/`on`), für LEDs kräftiger abgeleitet
(gleicher Farbton, volle Sättigung und Helligkeit: hearth `#DB6B4C` → `#FF3700` – LEDs mischen Gedecktes sonst weißlich;
anpassbar in `rgb.json` `saturation`/`brightness`), kein Effekt.
Hardware: MSI MPG B550 Gaming Plus (Mystic Light, `1462:7c56`), NZXT Smart Device V2 (`1e71:200f`), RAM über SMBus
(`/dev/i2c-0…2`, PIIX4), GPU (Gigabyte RTX 3070 Ti, nur `Direct`), Maus G502 X PLUS (Lightspeed-Empfänger `046d:c547`).
Nicht steuerbar: Drop ALT (`04d8:eed3`) – Stock-Firmware ohne Raw-HID, ginge nur mit eigener QMK-Firmware (bewusst gelassen).

- **OpenRGB 1.1 von Codeberg** (RPM `openrgb` + `hidapi-hotplug`, siehe `system/packages/other.txt`), nicht Fedoras
  `1.0~rc2`: rc2 kennt die Funk-G502 nicht und hält den Empfänger `c547` für eine **G915** – deren Protokoll wartet ohne
  Timeout auf Antworten der Maus, der ganze Aufruf hing (> 90 s). Deshalb steht der G915-Detektor in
  `~/.config/OpenRGB/OpenRGB.json` auf `false` (Sicherung daneben `.vor-g915-aus`). 1.1 zeigt Typ/Modi nur mit `-ld`.

- OpenRGB **ohne Server** (`--noautoconnect`): ein Scan, dann je Gerät der erste passende Modus `Static` → `Fixed` (NZXT)
  → `Direct`. Jeder Aufruf höchstens 90 s, eine Sperre verhindert parallele Läufe; fehlt openrgb: eine Logzeile, Exit 0.
  Den System-Dienst `openrgb.service` nicht einschalten.
- Wann: beim Login (`hypr/autostart.conf`, `--boot`) und nach Standby (`after_sleep_cmd` in `hypr/hypridle.conf`,
  `--delay 3`, bis USB wieder da ist). Nach `scripts/rice variant` einmal `scripts/rgb apply`, sonst erst beim nächsten Login.
  Beide nehmen die gemerkte Farbe; steht `on` auf `false`, schalten sie aus (Licht bleibt nach Neustart so, wie zuletzt gewählt).
- Shell (Gear-Popout): `rgb status --json` scannt nicht, es liest nur `rgb.json` und den letzten Lauf aus
  `~/.local/state/desktop/rgb-state.json` (`ok`/`total`/`at`, „läuft“ nur, solange die PID lebt).
- Rechte: die udev-Regel aus dem OpenRGB-RPM (`60-openrgb.rules`) gibt dem Login per `uaccess` Zugriff auf alle `/dev/i2c-*`
  und die USB-Geräte; keine Gruppe nötig. Geräte auslassen: `~/.config/desktop/rgb.json` → `{"skip": ["G502"]}`.
- Ein gemeinsamer OpenRGB-Aufruf für alle Geräte; hängt er (> 90 s, z. B. ein falsch erkanntes Gerät), setzt `apply` jedes Gerät
  einzeln (je 45 s). Hängende Geräte merkt `~/.local/state/desktop/rgb-slow.json` und setzt sie künftig einzeln zuletzt.

Stolperfallen:

- Keine Geräte: udev-Regeln neu laden oder neu starten; `ls -l /dev/i2c-0` muss ein `+` (ACL) zeigen.
- NZXT-Lüfter/Streifen dunkel: Zonengröße fehlt → einmal im OpenRGB-Fenster „Resize zone“ setzen (wird gemerkt).
- RAM fehlt: im OpenRGB-Fenster unter Supported Devices aktivieren; Kernel-Parameter erst danach (Wiki „SMBus Access“).
- Maus G502 X PLUS: Farbe steht **fest im Onboard-Profil 1** (Solaar, 2026-10-20), deshalb `rgb.json` → `{"skip": ["G502"]}`
  – OpenRGB würde sonst wieder „live“ übersteuern, und nach Aufwachen/Neuverbinden käme die Profilfarbe zurück.
  Vorher waren die Onboard-Profile aus, darum zeigte die Maus nach dem Aufwachen ihr altes Rot.
  Ändern: `solaar profiles "G502 X PLUS" > a.yaml`, im aktiven Profil unter `lighting` den Eintrag `ID: 1, color: 0x…`
  anpassen, `solaar profiles "G502 X PLUS" a.yaml`. Dazu `onboard_profiles = Profile 1`, `rgb_control = false`.
  Rückweg: Sicherung `~/.local/state/desktop/g502-profiles-backup-2026-10-20.yaml` genauso laden. DPI kommt im
  Profil-Modus aus `resolutions` (1200/1600/2000).

## Maus G502 X PLUS (Solaar)

`scripts/mouse` (Python, ruft die Solaar-CLI) + Gear-Popout: Akku, aktives Profil, DPI-Stufen (`resolutions`, Standardstufe
`resolution_default_index`) und Logo-Farbe (`lighting[1]`, Static).

- **Schreiben nur ins Onboard-Profil** (Flash, `mouse save`): frischer Dump, nur die Textzeilen der geänderten Felder ersetzt,
  danach Prüfung, dass sich sonst nichts ändert; Solaar schreibt nur Sektoren, die sich unterscheiden. Vor dem ersten
  Schreiben einmalig Sicherung `~/.local/state/desktop/g502-profiles.bak.yaml`; zurück mit `scripts/mouse restore`.
- **Regenbogen statt Profilfarbe:** Byte 252 im Profil-Sektor = `custom_animation_index` (libratbag-Quirk `G502X_PLUS`);
  ≠ 0 spielt die Firmware ihre Animation statt `lighting[1]`. Solaar kennt es nicht und schreibt 0xff → `mouse save`/`restore`
  setzen es danach auf 0, von Hand `scripts/mouse fix-light` (2026-10-20).
- `rgb_control` bleibt `false`, `rgb.json` `skip: ["G502"]` bleibt – sonst übersteuern Solaar/OpenRGB das Profil „live“.
- `scripts/mouse` und `scripts/rgb` teilen die Sperre `$XDG_RUNTIME_DIR/desktop-rgb.lock`: nie OpenRGB und Solaar gleichzeitig
  am Lightspeed-Empfänger. Ist sie belegt, meldet `mouse status` nur `busy` (die Shell behält die alten Werte).
- Zustände: Solaar fehlt · Maus nicht verbunden · Maus schläft (`solaar profiles` geht dann nicht, Werte grau) · läuft.
- **Solaar-Autostart aus:** `~/.config/autostart/solaar.desktop` mit `Hidden=true` (überdeckt `/etc/xdg/autostart/solaar.desktop`,
  2026-10-20) – das Solaar-Fenster im Hintergrund würde sonst parallel am Empfänger hängen. Rückweg: die Datei löschen.
- Nach Standby falsche Farbe: hypridle mit neuer Config neu starten, sonst `--delay 5`.
  Log: `journalctl --user --since -5min | grep rgb`.
