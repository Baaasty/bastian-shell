# Discord – Call-Infos und Kameras in der Shell

Stand 2026-10-19 · Client: normales **Discord (RPM, RPM Fusion)** mit eigenem **Equicord-Build** und Plugin `desktopBridge`.
Equibop ist raus (wird nur noch als alter Rückfall erkannt). Einrichten der RPC-Kopplung und Bedienung des Popouts:
[setup/discord.md](../setup/discord.md). Look (Theme „Desktop (Discord)“): [theming.md](theming.md).

## Architektur

```text
Discord-RPM (Renderer)  equicord/desktopBridge/index.tsx   liest Discord-Stores, greift gepinnte Kameras ab
        │ VencordNative.pluginHelpers
Electron-Hauptprozess   equicord/desktopBridge/native.ts   Unix-Socket $XDG_RUNTIME_DIR/desktop/cams.sock (0700/0600)
        │ Zeilen: S <json> Zustand · E <json> Antwort · F <key> <länge> + JPEG
scripts/cam-relay       Python, Socket ↔ Quickshell (JSON-Zeilen), Bilder als cam-<key>.jpg im RAM
        │
shell/services/Cams.qml → Discord.qml → modules/bar/Discord{Chip,Avatar,Popout}.qml, modules/cams/CamWall.qml

Rückfall: scripts/discord-bridge  offizielle Discord-RPC (discord-ipc-N, OAuth mit eigener Developer-App) → Discord.qml
```

- **Zwei Datenwege, ein Format.** Das Plugin schickt denselben Zustand wie `discord-bridge` (Kanal, Leute mit Spricht/Mic/
  Taub/Kamera/Übertragung/Lautstärke, `self`, `since`). Ist es verbunden (`Cams.connected`), hat es Vorrang; fällt es weg,
  gilt wieder die RPC-Bridge mit ihrem letzten Stand. Das Plugin braucht keine Developer-App und kann zusätzlich Kameras.
- **Befehle** der Shell ans Plugin: Mic/Taub/Kamera/Bildschirm/Verlassen, Beitreten, Lautstärke/Stumm pro Person, Server-/Kanallisten, Peek,
  Chat öffnen, `pin`/`unpin <key>` (`<userId>` = Kamera, `<userId>:stream` = Übertragung).
  Kamera/Bildschirm nur übers Plugin (RPC kann das nicht). Bildschirm ruft Discords eigene Picker-Funktion wie das Go-Live-
  Kürzel (`presentNativeScreenSharePicker("window")` + `NATIVE_SCREEN_SHARE_PICKER_PRESENT`; ohne Stil-Argument wirft Host
  1.0.164 „Invalid argument count“ → „Couldn’t start the stream“), dann fragt das Portal (Share-Picker) – deshalb zeigt der
  Knopf erst „Live“, wenn Discord den Stream meldet. Vor jedem Start sagt die Shell dem Share-Picker an, dass Discord fragt
  (`share-pick --expect`).
- Live-Quellwechsel geht unter Wayland nicht (Discords „Change Windows“, `presentDesktopSourcePicker`, fragt das Portal nicht
  neu; Weg über Stop + Neustart beendete den Stream) – verworfen 2026-10-20.
- **Kameras:** abgegriffen wird nur, was gepinnt ist und solange die Shell verbunden ist: `<video>` in
  `[data-selenium-video-tile="<userId>"]` → OffscreenCanvas → JPEG (360 px, 10 fps, Q 60; einstellbar im Plugin).
  Max. 3 Kacheln unter der Bar rechts auf DP-2, die älteste weicht. Im Vollbild/Spiel fordert die Shell keine Bilder an.
  Größe/Auto-Pin von Hand in `~/.config/desktop/cams.json`.
- **Eigene Kamera:** Discords Voice-Modul öffnet `/dev/video0` direkt (V4L2, kein PipeWire) und fragt vor jedem Start
  195 Formate ab – bei der Facecam ~6,5 s. `scripts/app-run` lädt dafür `fastprobe` (Details `hardware.md` → Facecam).
- **Datenschutz:** fremde Bilder verlassen Discord nur zu eigenen lokalen Prozessen, liegen nur im RAM, werden beim
  Entpinnen/Trennen gelöscht; nichts geht ins Netz oder auf die Platte.

Warum so: Ein Plugin, das Frames lokal liefert, war der einzige Weg zu Kameras pro Person. Verworfen: Discord-Pop-out
(nur ein Fenster für alle), Chromium-PiP (eine Kamera, Nutzergeste nötig), Fenster-Capture (Fenster muss sichtbar bleiben,
Ausschnitt fragil). Pop-out + Fensterregel in `hypr/rules.conf` bleibt der Rückfall, falls das Abgreifen nicht trägt.

## Bau und Einspielen

`scripts/equicord build|update|inject|uninject|status` (Details im Kopf des Skripts). Ohne sudo: `pnpm` in `~/.local/bin`,
Equicord-Klon in `~/.local/src/equicord`; `build` kopiert das Plugin nach `src/userplugins/` (Userplugin, nicht Upstream –
Equicord nimmt solche Plugins nicht an). `inject` macht in `~/.config/discord/app-<version>/` dasselbe wie der offizielle
Equicord-Installer (`app.asar` → `_app.asar` + Lader) und schaltet das Plugin in `~/.config/Equicord/settings/` ein.
Discord muss dabei beendet sein. Rückweg: `scripts/equicord uninject`.

## Grenzen

- Kamera-Kacheln gibt es nur, solange Discord die **Call-Ansicht** rendert; in der Textkanal-Ansicht gibt es kein `<video>`.
- **Im echten Call noch nicht geprüft:** ob Bilder kommen (`srcObject`), ob das Abgreifen bei weggeräumtem Fenster
  weiterläuft (Hyprland/Chromium drosseln evtl.), ob „größere Kachel = Übertragung“ stimmt.
- Über die RPC-Bridge (Rückfall): keine Kameras, keine DM-/Freundesliste, Einstellungen pro Person nur bis zum Verbindungsende.

## Stolperfallen

- **Go Live schwarz:** Unter Wayland überträgt Discords Voice-Modul nur mit Quelle `prepicked:screen` (fragt das Portal,
  PipeWire). `getDesktopSources` liefert dort nur XWayland-Fenster `window:N` → „No screencast portal config available“
  in `~/.config/discord/logs/discord-webrtc_0`, Zuschauer sehen Schwarz. Die Aufnahme selbst hängt nicht am Fenster
  (läuft nativ: Voice-Modul ↔ PipeWire); `render_unfocused` in `hypr/rules.conf` hält weggeräumt zusätzlich das Fenster wach.
- **Discord-Update** bringt einen neuen `app-*`-Ordner ohne Equicord. `app-run` spielt vor dem Start ein, Discords Updater
  installiert Host-Updates aber erst danach (Splash) und startet sich selbst neu – ohne Plugin, Flags und `fastprobe`.
  `equicord status --json` erkennt das (Shell prüft alle 20 s), dann Meldung + Popout-Knopf „Restart Discord“ (`equicord restart`,
  im Call zweimal drücken). Abschalten geht nicht: `SKIP_HOST_UPDATE` liest nur der alte Updater, Host-Updates sind Pflicht.
  Vorbeugend startet `app-run` die Unit `desktop-discord-update-watch` (`equicord watch-update`, 2 min): neuer app-Ordner
  ohne Equicord und kein Call → einmal automatisch `restart`; im Call oder Call-Stand unbekannt → nur Meldung/Knopf.
- **arRPC** (Equibop) legt einen eigenen `discord-ipc-0` an, der nur Rich Presence kann (`Unknown command`, Code 1000).
  Die Bridge überspringt solche Sockets; ist es der einzige, zeigt das Popout „has no call API“.
- **Renderer-Absturz (SIGSEGV) im Call mit Kamera/Go Live:** 10 von 11 Kernen seit 18.10. (Flatpak und RPM, mit und ohne
  Plugin) stehen an derselben Stelle `libnvcuvid.so.615.78.08 + 0x1b021` (Zeiger auf ungemappten Speicher). Geladen über
  `libnvidia-encode` = **NVENC** im Voice-Modul (Log: `nvidia_media_encoding`, Encoder „nvidia: cuda“ wird minütlich neu
  erzeugt/verworfen). VA-API aus (`app-run`) hilft nicht. Abhilfe (ungetestet): Voice & Video → Video-Codec → Hardware-Beschleunigung aus.
  Prüfen: `coredumpctl info <pid>` + NT_FILE-Mappings (`eu-readelf -n`) des Kerns.
  20.10. (Host 1.0.164) neu: **SIGABRT** im Renderer 0,4 s nach dem ersten Kamerastart, ohne NVIDIA-Bibliothek, zweiter Start ging.
  Stack fehlt (Kern abgeschnitten, Crashpad aus wegen Equicords `ELECTRON_ENABLE_STACK_DUMPING`) → `app-run` schreibt
  stderr nach `~/.local/state/desktop/discord-stderr.log`, dort steht der Stack beim nächsten Absturz.
  Abends 3 weitere Renderer-Abstürze, wieder `libnvcuvid + 0x1b021` (Kamera H.264 und Go Live H.265 über NVENC) – Discord/NVIDIA,
  nicht Plugin oder fastprobe. Ein Absturz des Hauptprozesses kam von KDEs `colorreload-gtk-module` (Ursache: `theme/gen/gtk.py`).
- Discord-Updates können DOM-Selektoren und Store-Namen brechen (das Plugin patcht nichts, ist also weniger fragil).
- Eigener Equicord-Build = Updates nur per `scripts/equicord update`.
- **Testen ohne Call:** `scripts/cam-fake` gibt sich als Plugin aus (nur bei beendetem Discord). `DESKTOP_CAMS_SOCK` und
  `DESKTOP_CAMS_FRAMES` verlegen Socket und Bildordner, damit ein Test-Relay den echten nicht stört.
- **ToS:** Client-Mods verstoßen formal gegen Discords Bedingungen (Grauzone). Das Plugin liest nur Anzeigedaten und sendet
  nur Aktionen, die Bastian selbst in der Shell auslöst.
