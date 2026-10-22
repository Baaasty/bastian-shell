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
- **Befehle** der Shell ans Plugin: Mic/Taub/Kamera/Bildschirm/Verlassen, Beitreten, Zufalls-Call, Lautstärke/Stumm pro Person, Server-/Kanallisten, Peek,
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
- **Zufalls-Call** sucht nur, was Discord im Speicher hat (`VoiceStateStore` aller Server; bei sehr großen Servern kann
  Discord Sprachzustände nachladen – 22.10. einmal allein gelandet). Deshalb prüft das Plugin nach dem Beitritt nach und
  springt allein weiter; die zuletzt besuchten überspringt es, nie zweimal derselbe Server (außer nur dort ist was frei). „Aktiv“ = kein Bot und nicht taub; Mic aus zählt.
  Wahl und Kandidaten stehen im stderr-Log (`[DesktopBridge] random:`). Nur übers Plugin (RPC sieht keine fremden Calls).
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
- **Renderer-Absturz (SIGSEGV) im Call mit Kamera/Go Live:** fast alle Kerne seit 18.10. (Flatpak und RPM, mit und ohne
  Plugin) stehen an derselben Stelle `libnvcuvid.so.615.78.08 + 0x1b021` (Zeiger auf ungemappten Speicher). Geladen über
  `libnvidia-encode` = **NVENC** im Voice-Modul (Log: `nvidia_media_encoding`, Encoder „nvidia: cuda“ wird minütlich neu
  erzeugt/verworfen) – Discord/NVIDIA, nicht Plugin oder fastprobe. VA-API aus hilft nicht.
  **Abhilfe `nvenc-block`** (`tools/nvenc-block/`, LD_PRELOAD über `scripts/app-run`): sperrt das `dlopen` beider
  Bibliotheken, das Voice-Modul kodiert dann in Software. Test 21./22.10.: 25 h ohne Absturz, danach ohne Sperre
  gestartet → zwei Abstürze in 30 min. Greift nur ab dem nächsten Start über `app-run` (Discords Selbst-Neustart
  nach Host-Update hat sie nicht, wie fastprobe). Ob aktiv: `scripts/nvenc-block status`, im stderr-Log steht „gesperrt“.
  Stack: `app-run` schreibt stderr nach `~/.local/state/desktop/discord-stderr.log` (Crashpad aus wegen Equicords
  `ELECTRON_ENABLE_STACK_DUMPING`, Kerne abgeschnitten). 20.10. einmal SIGABRT 0,4 s nach Kamerastart ohne NVIDIA-Bibliothek.
  Ein Absturz des Hauptprozesses kam von KDEs `colorreload-gtk-module` (Ursache: `theme/gen/gtk.py`).
- **Discord nie aus einer Claude-/Terminal-Shell starten** (auch nicht mit `uwsm app --`): Zygote, GPU-, Netz- und
  Audio-Prozess bleiben im Scope des Aufrufers, nur der Hauptprozess zieht in `app-discord-<pid>.scope` um. Endet die
  Session, bekommen sie SIGTERM → „GPU process isn't usable. Goodbye.“ (22.10., 02:18). Neustart über die Shell
  (`Launch.qml`, „Restart Discord“) oder `hyprctl dispatch exec`.
- Discord-Updates können DOM-Selektoren und Store-Namen brechen (das Plugin patcht nichts, ist also weniger fragil).
- Eigener Equicord-Build = Updates nur per `scripts/equicord update`.
- **Testen ohne Call:** `scripts/cam-fake` gibt sich als Plugin aus (nur bei beendetem Discord). `DESKTOP_CAMS_SOCK` und
  `DESKTOP_CAMS_FRAMES` verlegen Socket und Bildordner, damit ein Test-Relay den echten nicht stört.
- **ToS:** Client-Mods verstoßen formal gegen Discords Bedingungen (Grauzone). Das Plugin liest nur Anzeigedaten und sendet
  nur Aktionen, die Bastian selbst in der Shell auslöst.
