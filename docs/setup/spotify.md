# Spotify koppeln (Warteschlange + Bibliothek im Popout)

Das Spotify-Popout zeigt **Up Next** und deine Playlists über die offizielle Spotify Web API.
Das brauchst du **einmal**, ungefähr 5 Minuten.

**Voraussetzung:** Spotify Premium. Die App läuft im Development Mode, und der funktioniert seit
Februar 2026 nur, wenn der App-Besitzer (du) Premium hat. Abspielen per API geht ohnehin nur mit Premium.

## 1. App anlegen

1. <https://developer.spotify.com/dashboard> öffnen, mit deinem Spotify-Konto anmelden.
2. **Create app**:
   - Name: `Desktop`, Beschreibung: beliebig
   - Redirect URI: `http://127.0.0.1:8888/callback` (genau so, mit `127.0.0.1` und nicht `localhost`)
   - Unter „Which API/SDKs are you planning to use?“ **Web API** anhaken
   - Bedingungen bestätigen, **Save**
3. In der App auf **Settings**: die **Client ID** kopieren. Ein Client Secret brauchst du nicht (PKCE).
4. Nur falls du ein anderes Spotify-Konto benutzt als das Entwickler-Konto: unter **User Management**
   Name und E-Mail dieses Kontos eintragen. Sonst bekommst du später „Zugriff verweigert“ (403).

## 2. Client ID eintragen

In `~/Workspace/desktop/secrets.json` (gitignored; andere Einträge wie `hue` bleiben stehen):

```json
{
  "spotify": { "client_id": "HIER-DIE-CLIENT-ID" }
}
```

## 3. Koppeln

```sh
~/Workspace/desktop/scripts/spotify-auth
```

Der Browser öffnet sich. Bei Spotify zustimmen, dann zeigt der Tab „Gekoppelt“. Die Tokens landen in
`secrets.json` (Rechte 600). Die Shell merkt das von selbst und muss nicht neu starten.

## Bedienung

Popout: oben der laufende Song, darunter **Up Next**. **Library** → Playlist anklicken → Songliste
(lädt beim Scrollen nach). Song anklicken spielt ihn in der Playlist. **Play** startet bei Song 1
(Zufallswiedergabe aus), **Shuffle** startet gemischt. Zurück-Pfeil oder **Esc** geht eine Ebene hoch.

## Gut zu wissen

- **Nach 6 Monaten neu koppeln.** Spotify lässt das Refresh-Token seit Juli 2026 nach 6 Monaten
  ablaufen. Dann steht im Popout „Reconnect Spotify: scripts/spotify-auth“, und du startest einfach `scripts/spotify-auth` noch einmal.
- **Fremde Playlists:** Im Development Mode liefert die API Songs nur für eigene Playlists. Für fremde
  und Spotify-Playlists (Daily Mix …) holt die Shell die Songliste deshalb aus der öffentlichen
  Einbett-Seite von Spotify, ohne Cover pro Song. Nur private fremde Playlists bleiben leer.
- **Künstler als Kontext:** Bei Künstlern zeigt das Popout keine Songliste, weil Spotify die „Top-Tracks“
  im Development Mode gestrichen hat.
- **„Spotify isn’t running“:** Wenn gerade nichts aktiv ist, nimmt das Skript diesen PC als Ziel. Dafür muss die
  Spotify-App (RPM `spotify-client`, bis zum Umzug das Flatpak) offen sein.
- Test ohne Shell: `scripts/spotify-api queue` und `scripts/spotify-api playlists` geben JSON aus.
- Entkoppeln: den Block `spotify` aus `secrets.json` löschen. Den Zugriff entziehst du unter
  <https://www.spotify.com/account/apps/>.
