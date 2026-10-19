# Elgato Facecam (MK.1, 0fd9:0078): Regler unter Linux

Stand 2026-10-18 · Firmware 4.09 · Kernel 7.2 · getestet nur lesend, während Discord gestreamt hat.

## Kurzfassung

- **Helligkeit per Fader geht.** Sie läuft über den normalen UVC-Regler `brightness` (0–255), nicht über eine Elgato-Extension.
  Der Kernel versteckt ihn nur.
- Auto-Belichtung kann dabei an bleiben. Zusätzlich gibt es über die Elgato-XU **Metering** (Mittenbetonung, hilft bei Gegenlicht)
  und **AE-Geschwindigkeit**.
- Eine eigene „Exposure Compensation“ gibt es bei der MK.1 nicht (die gibt's in Camera Hub nur bei der Facecam Pro).
  Für die MK.1 ruft Camera Hub keine solche Funktion auf. Vermutlich steckt hinter dem Regler „Compensation“ `brightness`, das ist aber nicht geprüft.
- Setzen geht **nur, solange die Kamera streamt** (sonst EPIPE/„Broken pipe“).
- Werte sind flüchtig (RAM). Auf den Flash der Kamera speichert nur Camera Hub, und zwar über HID. Das fassen wir nicht an.

## Warum v4l2-ctl die Regler nicht zeigt

Der Kernel-Log meldet: `UVC non compliance: permanently disabling control 980900 (Brightness)`. Das Gleiche gilt für Contrast,
Saturation, WB-Auto und Power-Line. Beim ersten Abfragen (kurz nach dem Login, wahrscheinlich durch PipeWire) hat die Kamera
nicht gestreamt und GET_DEF mit Stall beantwortet. uvcvideo setzt deshalb `V4L2_CTRL_FLAG_DISABLED`.
`v4l2-ctl -l`, cameractrls und Discord blenden die Regler dann aus.

**Aber:** Das Flag wirkt nur beim Auflisten. `VIDIOC_G_CTRL`/`VIDIOC_S_CTRL` mit der ID gehen weiter direkt an die Kamera
(geprüft im Kernel-Quelltext `uvc_ctrl.c`, Lesen live getestet). Der Zugriff braucht also ein eigenes kleines ioctl-Tool, `v4l2-ctl` geht nicht.

## Standard-Regler (Processing Unit 2, live gelesen)

| Regler | V4L2-ID | Bereich | Default | aktuell |
| --- | --- | --- | --- | --- |
| brightness | 0x00980900 | 0–255 | 13 | 35 |
| contrast | 0x00980901 | 0–10 | 5 | 5 |
| saturation | 0x00980902 | 0–63 | 32 | 32 |
| white_balance_automatic | 0x0098090c | 0–1 | 0 | 0 |
| power_line_frequency | 0x00980918 | 0–2 | 0 | war 2 (60 Hz), jetzt 1 (50 Hz) |
| sharpness / WB-Temp / Zoom / AE-Mode / Belichtungszeit | sichtbar wie gehabt | | | |

`gain` und `backlight_compensation` gibt es nicht. Laut Deskriptor fehlen sie, die Abfrage gibt EINVAL.
`auto_exposure` kennt nur 0 = Auto und 2 = Shutter Priority, ein voll manueller Modus fehlt.

## Elgato-Extension-Unit

- Unit **3**, GUID `{a8e5782b-36e6-4fa1-87f8-83e32b323124}`, 9 Controls (Selector 8, 18–21, 25–28)
- Zugriff: `UVCIOC_CTRL_QUERY` (`0xC0107521`) auf `/dev/video0`, kein root nötig
- Namen stammen aus der Disassembly von Camera Hub 1.5.2 (Windows). Dort werden in `CFacecamSupport` die Log-Strings
  `XU_SELECTOR::…` direkt mit der Selector-Konstante verknüpft.

| Sel | Name (Camera Hub) | Länge | Bereich | Default | aktuell | Hinweis |
| --- | --- | --- | --- | --- | --- | --- |
| 8 | EXPOSURE_METERING | 1 B | 0–2 | 1 | 0/1 | Belegung der Werte noch unklar (Mitte/Durchschnitt/…) |
| 18 | NOISE_REDUCTION | 1 B | 0–1 | 0 | 0 | |
| 19 | SERVICE_MODE | 1 B | 0–1 | 0 | 0 | **Nie setzen** |
| 20 | EXPOSURE_TIME | 4 B LE | 1–5000 | 400 | 400 | in 50 µs (400 = 20 ms), entspricht `exposure_time_absolute` |
| 21 | AUTO_EXPOSURE_SPEED | 2 B LE | 0–100 % | 60 | 32 | Wie schnell die Auto-Belichtung nachregelt |
| 25 | AUTO_EXPOSURE_LOCK | 1 B | 0–1 | 0 | 0 | Friert die Auto-Belichtung ein |
| 26 | ? (nur lesen) | 4 B LE | – | – | ~1500–5200, schwankt | vermutlich Live-Messwert (ISO?) |
| 27 | ? (nur lesen) | 4 B LE | – | – | 11796 konstant | unbekannt |
| 28 | ? | 2 B | 0–1 | 0 | 0 | unbekannt, nicht anfassen |

Camera Hub liest ISO, Verschlusszeit und WB über die Selectors 23, 22 und 24. Die Facecam meldet die aber nicht im Deskriptor,
deshalb blockt Linux sie. Eine ISO-/Gain-Steuerung gibt es für die MK.1 nicht (Camera Hub hat für sie kein `SetISO`).

## Setzen per ioctl

Nur während ein Stream läuft (Discord, OBS oder `v4l2-ctl --stream-mmap` im Hintergrund):

```python
# Helligkeit: VIDIOC_S_CTRL = 0xC008561C, struct v4l2_control {u32 id; s32 value}
fcntl.ioctl(fd, 0xC008561C, struct.pack("<Ii", 0x00980900, 80))
# XU, z. B. AE-Speed: struct uvc_xu_control_query {u8 unit, sel, query; u16 size; u8* data}, SET_CUR = 0x01
# unit=3, sel=21, size=2, data=(50).to_bytes(2,"little")
```

## Umsetzung in der Shell

- `scripts/camera` (Python, nur stdlib, per ioctl):
  - `status` → JSON mit `busy` (= streamt), `auto`, `exposure`, `brightness`, `powerLine`
  - `set brightness N` (0–255)
  - `apply N` = Auto-Belichtung an + 50 Hz + Helligkeit N
  - Ohne Stream bricht das Skript mit Exit-Code 2 ab und meldet „camera is off“.
- „Streamt“ wird am Anstieg von `urbnum` des USB-Geräts in 0,25 s erkannt, nicht per GET. Ohne Stream würde jedes GET eine Fehlerzeile ins Kernel-Log schreiben.
- `shell/services/Camera.qml`: Auto-Belichtung ist immer an. Gemerkt wird nur die Wunsch-Helligkeit in `~/.local/state/desktop/camera.json`.
  - Ohne gespeicherten Wert gilt der erste gelesene Kamerawert.
  - Sobald die Kamera einschaltet, wird nach 1,5 s `apply` aufgerufen.
  - Der Fader setzt höchstens alle 150 ms.
  - Ein Shell-Neustart mitten im Call setzt nichts neu.
- Dashboard → Controls → Zeile „Camera“: Balken „Brightness“ in %. Ist die Kamera aus, steht dahinter „applies when camera is on“.

## Risiken

- Nur Selector 8, 18, 20, 21, 25 und Standard-IDs anfassen. **Selector 19 (Service-Mode) nie**, das HID-Interface `hidraw1`
  (Profile, Firmware, Bootloader) auch nie.
- Unbekannte Selectors (26–28) nicht beschreiben.
- Ob `brightness` im Auto-Modus das AE-Ziel verschiebt oder nur das Bild aufhellt, ist ungetestet. Testplan: 35 → 80 → 35, Bild ansehen.
- Nach jedem Abstecken sind die Werte weg. Möglicherweise lädt die Kamera dann ihr Flash-Profil.
- Die Facecam hängt sich laut Foren gelegentlich auf, wenn Streams gestartet und gestoppt werden. Dann hilft nur Abstecken.

## Alternativen, falls brightness nicht reicht

1. **Metering auf Mittenbetonung** (Sel 8). Das ist die eigentliche Gegenlicht-Lösung, weil das Fenster weniger zählt.
2. **AE-Lock** (Sel 25): Belichtung einstellen, wenn das Gesicht gut aussieht, dann einfrieren.
3. **Shutter Priority** (`auto_exposure=2` + `exposure_time_absolute`). Bringt bei Gegenlicht wenig, weil die Kamera dann trotzdem
   per ISO auf den ganzen Frame regelt.
4. **Software-Filter** per v4l2loopback + ffmpeg/GStreamer (`eq=brightness=…`). Braucht ein Kernelmodul (sudo/akmod), kostet CPU und Latenz.
   Nur als letzte Option.

## Quellen

- USB-Deskriptor: `lsusb -v -d 0fd9:0078` (Extension Unit 3, Processing Unit 2)
- Camera Hub 1.5.2 MSI (`edge.elgato.com/egc/windows/echw/1.5.2/…`), Strings + `objdump` von `ExeFile`
- Bereiche von Brightness/Contrast/Saturation stimmen mit [uvcc-Beispiel Facecam](https://github.com/joelpurra/uvcc/tree/main/examples/elgato-facecam/4057-120) überein
- Vorgehen ähnlich wie bei der Facecam 4K: [PrivateGER/ElgatoCam](https://github.com/PrivateGER/ElgatoCam) (andere GUID/Selectors, nicht übertragbar)
- Kernel-Patch „Set V4L2_CTRL_FLAG_DISABLED during queryctrl errors“ (Ricardo Ribalda, 2025)
