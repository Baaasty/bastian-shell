# iCloud-Passwörter (Panel Super+O und Browser-Autofill)

Quelle ist der iCloud-Schlüsselbund über icp (`~/Apps/icp`, Branch `live`, eigener Fork mit Schreibweg). Code:
`scripts/passwords` (alles Lesen/Schreiben, Selbsttest `--selftest`), `shell/modules/passwords/`, Browser-Teil
`scripts/chrome-ext` + Erweiterung „Desktop“ (`theme/gen/`). Sync-Takt und Bremse: `systemd/desktop-passwords.timer`,
`~/Apps/icp/icp/ratelimit.py`. Anisette (Gerätekennung für Apple): `scripts/anisette`, `systemd/desktop-anisette.*`.

## Einrichten (einmal)

0. Anisette: Ordner `iCloud` aus dem Store-Paket „iCloud für Windows“ (x64, 15.10.39 getestet) entpacken, dann
   `scripts/anisette setup <Ordner>` und `scripts/anisette install`.
1. `icp login` im Terminal (Apple-ID, 2FA). Läuft der Login später ab, zeigt das Panel „iCloud login needed“ mit
   „Send code“ (auch Launcher „iCloud Login“): das gespeicherte Passwort meldet an, nur der 2FA-Code wird eingetippt.
   Das Terminal braucht es nur noch, wenn das gespeicherte Passwort nicht mehr gilt.
2. `scripts/chrome-ext install --browser helium`, dann `helium://extensions` → Developer mode → „Desktop“ neu laden bzw.
   **Load unpacked** `theme/out/chrome-desktop-ext`.
3. Eine alte Erweiterung „Apple Passwords“ (icp) entfernen – sonst zwei Dropdowns.
4. Heliums eigenen Passwort-Manager aus (`helium://password-manager/settings`: Speichern und Auto-Login aus).
5. Prüfen: `scripts/chrome-ext status`.

## Warum so

- **Kein Dritter:** Logos holt `scripts/favicons` direkt bei der Website (nie Google/DuckDuckGo, nie private Adressen), Kopieren
  geht über `wl-copy --sensitive`, damit Klipper/cliphist nichts speichern.
- **Browser bekommt nur, was zur Seite passt:** Dropdown im geschlossenen Shadow Root, Werte erst nach echtem Klick, nur https
  bzw. localhost, nur passende Einträge (geprüft in Erweiterung und Host).
- **Anisette lokal über Wine, nur bei Bedarf:** Apple nimmt seit Ende Oktober 2026 nur noch Gerätekennungen aus den echten
  Apple-Bibliotheken an (der frühere Container `dadoum/anisette-v3-server` scheitert mit `-80045`). Ein fremder Server
  sähe jede Anmeldung – also Apples Windows-DLLs unter Wine. Der Socket startet den Server beim Zugriff, danach läuft nichts.
- **Im Hintergrund nie Passwort-Login oder 2FA-Push:** wiederholte Logins können die Apple-ID sperren.
- **Bearbeiten speichert im Hintergrund:** holen, schreiben, zurücklesen dauert etliche Sekunden und klappt fast immer – die
  Liste zeigt den neuen Stand sofort, nur ein Fehler meldet sich.
- **Website/Benutzer ändern = neuer Eintrag:** Apple-Geräte gleichen Änderungen nur darüber ab; in-place bliebe auf dem iPhone
  eine Dublette (getestet 2026-10-20). Löschen landet wie in der App unter „Zuletzt gelöscht“.

## Grenzen

- Geteilte Gruppen nur lesen, und nur selbst erstellte (eigene PCS-Verschlüsselung, mit dir geteilte fehlen noch).
- WLAN-Passwörter (Dienst „AirPort“) sind nie zu sehen.

## Fehlerbehebung

| Symptom | Lösung |
|---|---|
| Kein Dropdown | Seite neu laden. http-Seite oder fremdes Iframe → absichtlich aus. Passt der Eintrag? `scripts/passwords match <url>` |
| „Desktop host not reachable“ / „outdated“ | `scripts/chrome-ext install --browser helium`, dann „Desktop“ neu laden |
| „cannot open the icp vault …“ | Schlüsselbund gesperrt oder Login abgelaufen: `icp login` |
| Login scheitert mit `-80045` („This action cannot be completed“) | Apple lehnt die Anisette-Kennung ab, nicht das Passwort. Nicht wiederholt versuchen (Kontosperre); `scripts/anisette status`, icp-Issues prüfen |
| „anisette server not reachable“ | `scripts/anisette status`, Log: `journalctl --user -u desktop-anisette` |
| Eintrag fehlt | `scripts/passwords sync --force` |
| Code wird abgelehnt | Uhrzeit prüfen: `timedatectl` (NTP an?) |
| Speichern gescheitert, Schreiben gesperrt | Grund in `icp write-state`, nach Klärung `icp write-state --clear`; alter Stand: `icp restore` |
