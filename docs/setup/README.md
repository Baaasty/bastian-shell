# Logins & Kopplungen

Alles, was einmal eingerichtet werden muss. Zugangsdaten und Tokens liegen nur in
`~/Workspace/desktop/secrets.json` (gitignored, Rechte 600). Vorlage: `secrets.example.json`.
Die Shell merkt Änderungen an der Datei von selbst, kein Neustart nötig.

| Dienst | wofür | wie koppeln | wo gespeichert | Anleitung |
|---|---|---|---|---|
| Spotify | Popout: Up Next, Library, Playlists | Client-ID eintragen, dann `scripts/spotify-auth` | `spotify` | [spotify.md](spotify.md) |
| Discord | Call-Info + Steuerung in Bar/Dashboard, Kanal-Auswahl, Chats | eigene App anlegen, Client-ID/Secret eintragen, in Discord **Autorisieren** | `discord` | [discord.md](discord.md) |
| Hue | Licht im Dashboard (Räume, Szenen, Farben) | `scripts/hue-pair` + Taste auf der Bridge | `hue` | [hue.md](hue.md) |
| Mail & Kalender | Ungelesene Mails, Termine, Todos im Dashboard | Konto + app-spezifisches Passwort eintragen, dann `scripts/rice feeds` | `accounts` | [mail-calendar.md](mail-calendar.md) |
| iCloud-Passwörter | Autofill + Popup in Helium (Erweiterung „Desktop“), Passwörter in der Shell | `icp login` (erledigt), Erweiterung laden | icp (`~/Apps/icp`), Website-Zuordnungen `~/.config/desktop/passwords-overrides.json` | [passwords.md](passwords.md) |
| Elgato Key Light | Licht an/aus, Helligkeit, Farbtemperatur | – kein Login, läuft lokal (HTTP im Heimnetz); Adresse: `keylight.host`/`keylight.ip` in `secrets.json` | – | – |
| GoXLR | Audio-Routing im Dashboard, Fader/Routing bei Sperre + Login, PC-Lautstärke fest 100 % | – kein Login, läuft lokal (GoXLR Utility) | `~/.local/state/desktop/goxlr-faders.json`, Schalter `~/.config/desktop/{goxlr,audio}.json` | [goxlr.md](goxlr.md) |

**Entkoppeln** geht überall gleich: den jeweiligen Abschnitt aus `secrets.json` löschen
(bei Spotify/Discord zusätzlich den App-Zugriff im Konto entfernen, steht in der Anleitung).

**Login-Bildschirm** (kein Login, nur Look): [loginscreen.md](loginscreen.md) – `scripts/loginscreen apply|restore|status`.
