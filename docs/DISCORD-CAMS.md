# Equibop: Call-Infos und Kameras in der Shell

Stand 2026-10-18, spät · AP 8b · **Client ist jetzt das normale Discord (RPM) mit eingespieltem eigenen Equicord-Build** – Plugin `desktopBridge` läuft, Shell verbunden; Kamera-Kacheln im echten Call noch nicht erprobt. Equibop fliegt raus (Bastian).
Abschnitte 1–3 sind die Recherche (Befund), ab Abschnitt 4 der Ist-Stand. Was nur ein echter Call klären kann, steht in Abschnitt 6.

## 1. Befund: Equibop und die bisherige Bridge

`scripts/discord-bridge` spricht die **offizielle Discord-RPC** (Socket `discord-ipc-0`, OAuth mit eigener App).
Equibop hat diese Schnittstelle nicht: Es startet **arRPC** (`/opt/Equibop/resources/arrpc/arrpc`, Equibop-Einstellung `arRPC = true`),
und das legt **seinen eigenen** `discord-ipc-0` an. arRPC kennt nur Rich Presence
(`SET_ACTIVITY`, `INVITE_BROWSER`, `DEEP_LINK`, …); alles andere beantwortet es mit `Unknown command` (Code 1000).
Gemessen: Das Bridge-Log von 19:51 zeigt genau das (`AUTHENTICATE abgelehnt (1000)` / `Unknown command: AUTHORIZE`),
und ein Test mit beiden Clients zeigte arRPC auf `$XDG_RUNTIME_DIR/discord-ipc-0`, das Flatpak-Discord nur noch über den socat-Pfad.

| Bridge-Funktion | mit Equibop |
|---|---|
| Fenster holen/wegräumen, Folgen auf allen Workspaces, Starten, Chip, Fensterregeln | **geht** (umgestellt, `Chat.qml`) |
| Chat per Link öffnen (`discord://`) | geht (Equibop ist Handler) |
| Call-Status, Köpfe in der Bar, spricht/Mic/Taub, Kanal, Dauer | **geht nicht** (Zustand „unsupported“ im Popout) |
| Mic/Taub/Verlassen, Lautstärke pro Person, Kanal-Auswahl/Beitreten, Peek | **geht nicht** |

Solange das echte Discord (Flatpak/RPM) parallel läuft, nimmt die Bridge dessen Socket (sie überspringt arRPC-Sockets).
Wer sich nur mit Equibop anmeldet, hat bis zum Plugin (Abschnitt 4) **keine Call-Anzeige in der Bar**.

## 2. Wie kommen Kameras im Renderer vor?

Equibop ist die Web-Version von Discord in Electron; Sprache/Video laufen über WebRTC im Browser-Teil. Deshalb gilt **[prüfen im Call]**:

- Jede Kamera/jeder Stream ist ein `<video>` mit `srcObject = MediaStream`, in einer Kachel, die die User-ID trägt
  (`[data-selenium-video-tile="<userId>"]` – aus Erinnerung an Discords DOM).
- Die Kacheln existieren **nur**, solange die Call-Ansicht gerendert wird (Sprachkanal-Seite oder Popout). Wer im Textkanal ist,
  hat nur das kleine Sprachpanel – dann gibt es kein `<video>` zum Abgreifen. Stärkster Risikopunkt (auch für ein weggeräumtes Fenster).
- Alternative ohne UI-Abhängigkeit: `RTCPeerConnection`-`track`-Ereignisse abfangen und ein verstecktes `<video>` anhängen; die Zuordnung Track → Person ist dort aber Handarbeit.

Gibt es das schon?

- Equicord/Vencord haben **kein** Plugin, das Kameras in ein eigenes Fenster holt oder anpinnt. In `src/plugins` und `src/equicordplugins`
  (Stand heute, per GitHub-API gelistet) finden sich nur Verwandte: `pictureInPicture` (nur Chat-Videos/Anhänge, per Download-Button),
  `biggerStreamPreview`, `disableCameras`, `toggleVideoBind`, `voiceChannelLog`, `screenRecorder.equibop`, `callTimer`.
- Discord selbst: Kachel-„Pin/Focus“ (nur innerhalb des Fensters) und **Pop-out** (eigenes Fenster). Das Forum kennt dazu offene Wünsche
  („mehrere Pop-out-Fenster, eines pro Teilnehmer“, „Videochat frei verschiebbar“) – ein Hinweis, dass pro Teilnehmer **nicht** geht. **[prüfen]**
- Chromium-PiP (`video.requestPictureInPicture()`) erlaubt **ein** Fenster gleichzeitig (meines Wissens) und braucht eine Nutzergeste.

## 3. Die drei Wege

| | Idee | Aufwand | Kosten/Risiko | Urteil |
|---|---|---|---|---|
| **2a** Discord-Pop-out + Hyprland-Regel | Pop-out-Knopf auf der Kamera-Kachel; Fensterregel (Titel/Klasse) macht es zum kleinen schwebenden Fenster an festem Platz | ~1 h Test, keine Code-Zeile | Nur was Discord kann (vermutlich 1 Fenster, alle Kameras oder ein Stream). Kein Anpinnen per Kopf in der Bar | **Zuerst testen** |
| **2b** Plugin ruft PiP auf | Klick auf Kopf → Plugin startet PiP für diese Kamera | ~0,5 Tag | **Nur eine** Kamera zugleich, Nutzergeste nötig (aus dem Hauptprozess mit `executeJavaScript(…, true)` machbar) | Zu schwach |
| **1** Plugin schickt Frames lokal an die Shell | Plugin grabbt die gepinnten `<video>`, kodiert JPEG (360p, 10 fps) und liefert sie über einen 0600-Unix-Socket; ein Relay legt sie als Datei in `$XDG_RUNTIME_DIR` (RAM), Quickshell zeigt Kacheln | MVP ~1 Tag Plugin + ~0,5 Tag Shell | Siehe unten | **Empfohlen** |
| **3** Fenster-Capture (PipeWire/Screencopy) | Ausschnitt des Equibop-Fensters abfilmen | 1–2 Tage | Fenster muss sichtbar auf einem Monitor liegen (kein Wegräumen), Ausschnitt/Layout fragil, Portal-Dialog, Kacheln wandern | Verwerfen |

### Weg 1 im Detail

- **Kosten (Schätzung, nicht gemessen):** pro gepinnter Kamera 640×360, JPEG q≈0,6 ≈ 25–40 KB/Bild → ~0,3 MB/s bei 10 fps;
  Renderer ~3–6 % eines Kerns, Quickshell ~1–2 %. Es wird **nur** gegrabbt, was gepinnt ist; ohne Pin läuft nichts.
- **Datenschutz:** Bilder anderer Leute verlassen Equibop nur zu lokalen Prozessen des eigenen Nutzers (Socket-Rechte 0600), liegen nur im RAM
  (`$XDG_RUNTIME_DIR`), werden beim Entpinnen/Beenden gelöscht, nichts geht ins Netz oder auf Platte. Trotzdem: Du holst fremde Videos aus dem Client – nur für Pins, nie dauerhaft.
- **Gleicher Kanal liefert auch den Call-Status:** Das Plugin kann `VoiceStateStore` & Co. direkt lesen und Mic/Taub/Verlassen auslösen.
  Damit ersetzt es die RPC-Bridge **vollständig** (und braucht keine eigene Developer-App mehr). Einzige neue Arbeit in der Shell:
  `discord-bridge` bekommt einen zweiten Datenweg (Socket des Plugins statt RPC), `Discord.qml` bleibt gleich.
- **Anpinnen:** Klick auf einen Avatar-Kopf in der Bar (oder im Popout) → `pin <userId>` an das Plugin → Kachel erscheint
  (Position: Vorschlag oben rechts unter der Bar auf DP-2, mehrere nebeneinander; Entpinnen = Klick auf die Kachel).
- **Zeigen in Quickshell:** `Image` mit zwei Puffern (kein Flackern), `cache: false`, Quelle wechselt auf `file://…/cam-<id>.jpg?n`
  per Signal des Relays. Alternative, falls Ruckeln: MJPEG über `127.0.0.1` und Qt-`MediaPlayer` (QtMultimedia ist installiert). **[nicht getestet]**
- **Risiken:** (1) Kachel nur bei sichtbarer Call-Ansicht (siehe Abschnitt 2). (2) Discord-Updates ändern DOM/Stores – das Plugin braucht keine Patches
  (weniger fragil), aber Selektoren können brechen. (3) Mit eigenem Equicord-Ordner holt Equibop **keine** Equicord-Updates mehr (`Cannot repair: using custom Equicord directory`);
  du baust selbst neu (`git pull && pnpm build`). (4) `pnpm` ist nicht installiert (Node 22 ist da).
- **Regeln/ToS:** Equicord-Client-Mods verstoßen formal gegen Discords Nutzungsbedingungen (Grauzone); soweit bekannt trifft die Durchsetzung eher Automatisierung/Spam als reine Anzeige-Plugins, ein Restrisiko bleibt.
  Equicord nimmt solche Plugins nicht in sein Repo (Regeln im CONTRIBUTING) – deshalb **Userplugin**, nicht Upstream.

## 4. Ist-Stand: Plugin `desktopBridge` + Shell

```
equicord/desktopBridge/{index.tsx,native.ts}   Quelle im Repo (Userplugin für Equicord)
scripts/equicord                                build | update | install | off | status
scripts/cam-relay                               Python: Plugin-Socket <-> Quickshell (JSON-Zeilen, Bilder als Dateien im RAM)
scripts/cam-fake                                Test-Gegenstelle (gibt sich als Plugin aus, Fake-Call + bewegte Testbilder)
shell/services/Cams.qml                         Relay-Prozess, Pins, Signal frame
shell/services/Discord.qml                      nimmt Plugin-Daten, wenn verbunden; sonst weiter die RPC-Bridge
shell/modules/cams/{CamWall,CamTile}.qml        bis zu 3 Kacheln unter der Bar rechts auf DP-2
shell/modules/bar/Discord{Chip,Avatar,Popout}.qml   Logo, Kamera-Punkt am Kopf, Pin per Klick
```

**Plugin (Equibop/Electron):** liest `VoiceStateStore`, `MediaEngineStore`, `SelectedChannelStore` usw. (Namen gegen den Equicord-Quellcode und das mitgelieferte Plugin `orbolayBridge` geprüft)
und schickt bei jeder Änderung einen Zustand im selben Format wie `discord-bridge`: Kanal, Leute (Name, Avatar-URL, spricht, Mic/Taub, Kamera, Übertragung, Lautstärke), `self`, `since`.
Befehle von der Shell: `mute 0|1`, `deaf 0|1`, `leave`, `join <id>`, `uvol <id> <0-200>`, `umute <id> 0|1`, `guilds`, `channels <gid>`, `peek <ids>`, `open <id>`, `pin <key>`, `unpin <key>`.
Nur **gepinnte** Kacheln werden abgegriffen: `<video>` in `[data-selenium-video-tile="<userId>"]` (am echten Discord-Web-Client geprüft: das Attribut ist die User-ID,
das `<video>` hängt Discord per `createElement` an) -> OffscreenCanvas -> JPEG (Standard 360 px hoch, 10 fps, Qualität 60; einstellbar unter Equibop -> Plugins -> DesktopBridge).
Schlüssel: `<userId>` = Kamera, `<userId>:stream` = Bildschirmübertragung.

**Transport:** Unix-Socket `$XDG_RUNTIME_DIR/desktop/cams.sock` (Ordner 0700, Socket 0600; Electron-Hauptprozess in `native.ts`, das Plugin spricht per `VencordNative.pluginHelpers.DesktopBridge`).
Zeilen `S <json>` (Zustand), `E <json>` (Antworten), `F <key> <länge>` + JPEG-Bytes. Ohne Shell-Verbindung wird nichts abgegriffen. `cam-relay` legt Bilder als `cam-<key>.jpg` im RAM ab
(atomar ersetzt, bei Entpinnen/Trennung/Beenden gelöscht). Nichts geht ins Netz oder auf die Platte.

**Shell:** Ist das Plugin verbunden (`Cams.connected`), kommen Köpfe/Status/Steuerung daraus; fällt es weg (oder läuft nur das Flatpak-Discord), gilt wieder die RPC-Bridge (letzter Stand wird neu angewendet).
Läuft beides, hat das Plugin Vorrang. Anpinnen: Klick auf einen Kopf mit Kamera-Punkt in der Bar oder auf das Kamera-/Übertragungs-Symbol im Discord-Popout; Entpinnen: nochmal klicken oder X auf der Kachel;
mehr als 3 -> die älteste weicht; wer den Call verlässt, verliert die Kachel. Das Bar-Symbol ist immer das Discord-Logo (`shell/assets/discord.png`, einfarbig in Theme-Farbe), egal welcher Client läuft.
`qs ipc … call cams status|pin <key>|unpin <key>` zum Prüfen.

## 5. Bau, Einspielen, Rückweg

Bau (user-lokal, ohne sudo): `pnpm` 12.8.1 liegt in `~/.local/bin` (`npm i -g pnpm@12.8.1 --prefix ~/.local`), Equicord-Klon in `~/.local/src/equicord`
(`git clone https://github.com/Equicord/Equicord`). `scripts/equicord build` kopiert das Plugin nach `src/userplugins/desktopBridge/` und baut;
Userplugins stecken damit fest im Build (kein extra Werkzeug nötig). Neue Equicord-Version: `scripts/equicord update`.

**Discord (RPM von RPM Fusion, ohne sudo):** Das RPM installiert nur einen Starter; die App selbst legt Discord beim ersten Start unter
`~/.config/discord/app-<version>/` ab (gehört dem Nutzer). `scripts/equicord inject` macht dort dasselbe wie der offizielle Equicord-Installer:
`resources/app.asar` → `resources/_app.asar`, daneben `resources/app/index.js` (lädt `<Klon>/dist/desktop/patcher.js`) + `package.json`,
und schaltet das Plugin in `~/.config/Equicord/settings/settings.json` ein (Sicherung unter `~/.local/state/desktop/equibop-backup/`).
Discord muss dafür beendet sein. Prüfen: `scripts/equicord status` (Zeilen „Discord … eingespielt“ und „Socket … Plugin läuft“).

- **Discord-Update:** bringt einen neuen `app-*`-Ordner ohne Equicord. `scripts/app-run discord` ruft vor jedem Start `scripts/equicord inject --if-needed` auf.
  Startet Discord sich nach einem Update selbst neu, läuft dieser eine Start ohne Equicord – Discord einmal beenden und neu starten.
- **Rückweg:** Discord beenden, `scripts/equicord uninject` (stellt `app.asar` wieder her). Equicord-Einstellungen/Themes unter `~/.config/Equicord/` bleiben.
- **Equibop (alt):** `scripts/equicord install|off` gibt es noch für Equibop; Equibop wird deinstalliert (`sudo dnf remove equibop`, Bastian).

**Kacheln einstellen (von Hand):** `~/.config/desktop/cams.json` – `{ "size": "S"|"M"|"L", "autoPin": false }`.
Mausrad auf den Kacheln = Größe S/M/L; `autoPin` pinnt Kameras anderer automatisch, sobald sie angehen (von Hand gelöste bleiben gelöst).
Im Vollbild/Spiel (keine Bar) fordert die Shell keine Bilder an (`Cams.paused`).

**Tests:** `scripts/cam-fake` (Fake-Plugin) nur ohne laufendes Plugin. `DESKTOP_CAMS_SOCK` verlegt den Socket (Plugin, Relay, Fake),
`DESKTOP_CAMS_FRAMES` den Bildordner des Relays – so stört ein zweiter Test-Relay den echten nicht.

ToS: Client-Mods verstoßen formal gegen Discords Nutzungsbedingungen (Grauzone); das Plugin liest nur Anzeigedaten und sendet nichts an Discord außer den Aktionen, die du selbst in der Shell auslöst (Mic, Taub, Verlassen, Beitreten, Lautstärke).

## 6. Noch nicht im echten Call geprüft

- Dass im Discord-Call das `<video>` im Tile wirklich `srcObject` hat und Bilder kommen (nur bei sichtbarer Call-Ansicht; in der Textkanal-Ansicht gibt es keine Kacheln: Kachel zeigt „Open the call view in Equibop“ (Text ggf. auf Discord ändern)).
- Läuft das Abgreifen weiter, wenn das Equibop-Fenster weggeräumt ist (Hyprland stoppt dann evtl. Frame-Callbacks, Chromium drosselt Timer)? Wenn nicht: Fenster in einem Workspace lassen oder PiP/Pop-out (Weg 2a).
- Kamera + Übertragung derselben Person: Zuordnung „größere Kachel = Übertragung“ ist eine Annahme.
- `uvol` (Lautstärke) nutzt `VoiceActions.setLocalVolume` mit Rückfall auf den Flux-Befehl `AUDIO_SET_LOCAL_VOLUME`; `open` (Chat öffnen) navigiert per Router zu `/channels/@me/<id>`.
- ~~Kompatibilität mit Equibop~~ – erledigt: Build läuft im Discord-RPM (app-1.0.162), Plugin startet, Shell verbunden (2026-10-18).
- Test ohne Call: `scripts/cam-fake` starten (Plugin darf nicht laufen, also Discord beenden); die Shell zeigt dann einen Fake-Call mit 3 Kamera-/Übertragungs-Kacheln. Bei laufendem echten Call überschreibt das kurz die Anzeige – nur testen, wenn kein Call läuft.

## 7. Empfehlung / offene Entscheidungen

Entschieden (Bastian): eigener Equicord-Build, Plugin `desktopBridge`, Kameras gepinnt unter der Bar auf DP-2 (max. 3, 360p), bis dahin Flatpak-Discord für Calls; Equibop soll Discord später ersetzen.
Fallback, falls das Abgreifen nicht trägt: Weg 2a (Pop-out + Fensterregel in `hypr/rules.conf`).

## Quellen

- Equibop 3.3.1 lokal gelesen: `/opt/Equibop/resources/app.asar` (Einstellung `equicordDir`, Prüfung `equibop/main.js`), `/opt/Equibop/resources/arrpc/arrpc` (Befehlsliste).
- Equicord: <https://github.com/Equicord/Equicord> (README: Bau; `scripts/build/build.mjs`: Ordner `plugins`, `equicordplugins`, `userplugins`, Ausgabe `dist/equibop/*`; `CONTRIBUTING.md`: Plugin-Regeln), Doku <https://docs.equicord.org>.
- Vencord: <https://docs.vencord.dev/installing/custom-plugins/> (`src/userplugins`, nach dem Hinzufügen neu bauen).
- Discord-Forum (Wünsche zu Pop-out/PiP pro Teilnehmer): <https://support.discord.com/hc/de/community/posts/360072285692--Feature-Suggestion-Multiple-Pop-Out-windows-for-each-video-screen-share-participant>, <https://support.discord.com/hc/nl/community/posts/360029455072-Enable-pop-out-video-chat-and-allow-dragging-the-box-anywhere>.
