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
- **Befehle** der Shell ans Plugin: Mic/Taub/Verlassen, Beitreten, Lautstärke/Stumm pro Person, Server-/Kanallisten, Peek,
  Chat öffnen, `pin`/`unpin <key>` (`<userId>` = Kamera, `<userId>:stream` = Übertragung).
- **Kameras:** abgegriffen wird nur, was gepinnt ist und solange die Shell verbunden ist: `<video>` in
  `[data-selenium-video-tile="<userId>"]` → OffscreenCanvas → JPEG (360 px, 10 fps, Q 60; einstellbar im Plugin).
  Max. 3 Kacheln unter der Bar rechts auf DP-2, die älteste weicht. Im Vollbild/Spiel fordert die Shell keine Bilder an.
  Größe/Auto-Pin von Hand in `~/.config/desktop/cams.json`.
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

- **Discord-Update** bringt einen neuen `app-*`-Ordner ohne Equicord. `scripts/app-run discord` spielt vor jedem Start
  neu ein (`inject --if-needed`); startet Discord sich nach dem Update selbst neu, läuft dieser eine Start ohne Plugin →
  Discord einmal beenden und neu starten.
- **arRPC** (Equibop) legt einen eigenen `discord-ipc-0` an, der nur Rich Presence kann (`Unknown command`, Code 1000).
  Die Bridge überspringt solche Sockets; ist es der einzige, zeigt das Popout „has no call API“.
- Discord-Updates können DOM-Selektoren und Store-Namen brechen (das Plugin patcht nichts, ist also weniger fragil).
- Eigener Equicord-Build = Updates nur per `scripts/equicord update`.
- **Testen ohne Call:** `scripts/cam-fake` gibt sich als Plugin aus (nur bei beendetem Discord). `DESKTOP_CAMS_SOCK` und
  `DESKTOP_CAMS_FRAMES` verlegen Socket und Bildordner, damit ein Test-Relay den echten nicht stört.
- **ToS:** Client-Mods verstoßen formal gegen Discords Bedingungen (Grauzone). Das Plugin liest nur Anzeigedaten und sendet
  nur Aktionen, die Bastian selbst in der Shell auslöst.
