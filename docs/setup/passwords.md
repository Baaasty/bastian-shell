# iCloud-Passwörter (Panel Super+O und Browser-Autofill)

Quelle ist der iCloud-Schlüsselbund über icp (`~/Apps/icp`, Branch `live`, eigener Fork mit Schreibweg). Code:
`scripts/passwords` (alles Lesen/Schreiben, Selbsttest `--selftest`), `shell/modules/passwords/`, Browser-Teil
`scripts/chrome-ext` + Erweiterung „Desktop“ (`theme/gen/`). Sync-Takt und Bremse: `systemd/desktop-passwords.timer`,
`~/Apps/icp/icp/ratelimit.py`.

## Einrichten (einmal)

1. `icp login` im Terminal (Apple-ID, 2FA). Läuft der Login später ab, steht im Panel „iCloud login needed“ – dann wieder das.
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
| Eintrag fehlt | `scripts/passwords sync --force` |
| Code wird abgelehnt | Uhrzeit prüfen: `timedatectl` (NTP an?) |
| Speichern gescheitert, Schreiben gesperrt | Grund in `icp write-state`, nach Klärung `icp write-state --clear`; alter Stand: `icp restore` |
