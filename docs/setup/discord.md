# Discord-Call-Info einrichten

> **Chat-Client (Stand 2026-10-18): das normale Discord als RPM** (RPM Fusion, `/usr/bin/discord`, Fensterklasse `discord`, Daten in `~/.config/discord`),
> Start per Skript: `scripts/app-run discord` (RPM zuerst, Flatpak `com.discordapp.Discord` nur, wenn das RPM fehlt). Equibop ist raus (bleibt nur als alter Rückfall erkannt).
> **Zwei Datenwege:** (1) **Eigener Equicord-Build mit Plugin `desktopBridge`, eingespielt ins Discord-RPM**: Call-Anzeige, Steuerung und Kamera-Kacheln ohne eigene Developer-App –
> Bau/Aktivierung/Rückweg in [`docs/DISCORD-CAMS.md`](../DISCORD-CAMS.md). (2) **Offizielle RPC** (`scripts/discord-bridge`, Socket `$XDG_RUNTIME_DIR/discord-ipc-N`;
> diese Anleitung, ab Abschnitt 1): Köpfe, Mic/Deafen/Leave, Lautstärke – aber **keine Kameras** in der Shell. Läuft das Plugin, hat es Vorrang; sonst gilt die Bridge.
> Lauscht am Socket nur ein arRPC (läuft noch ein Equibop), überspringt die Bridge ihn; ist es der einzige, zeigt das Popout „has no call API“. Das Bar-Symbol ist immer das Discord-Logo.
> Look: Theme „Desktop“ (PC-Look, Discord bleibt erkennbar) – `scripts/equibop-theme install|off|status`, Details in [`docs/THEMING.md`](../THEMING.md) (Abschnitt Equibop).

Das Popout am Discord-Symbol in der Bar zeigt deinen Voice-Call (wer drin ist, wer spricht, Mic/Kopfhörer/Cam)
und lässt dich das Nötigste steuern: eigenes Mic, Taub, Kanal verlassen, Lautstärke/Stumm pro Person.
Dafür braucht die Shell eine **eigene Discord-App** – einmalig, dauert ca. 5 Minuten.
Es läuft nur über die offizielle lokale Schnittstelle von Discord (RPC). Nachrichten werden nie gelesen.

## 1. App anlegen

1. <https://discord.com/developers/applications> öffnen und mit deinem Discord-Konto anmelden.
2. **New Application** → Name `Desktop` → Bedingungen bestätigen → **Create**.

## 2. Redirect-URI eintragen

1. Links **OAuth2** öffnen.
2. Bei **Redirects** auf **Add Redirect** klicken und genau `http://localhost` eintragen
   (ohne `/` am Ende, ohne `https`).
3. **Save Changes**.

## 3. Client-ID und Secret kopieren

1. Auf derselben Seite (**OAuth2**) die **Client ID** kopieren.
2. Bei **Client Secret** auf **Reset Secret** klicken (ggf. 2FA-Code eingeben) und das Secret kopieren.
   Es wird nur einmal angezeigt.

## 4. In `secrets.json` eintragen

Datei: `~/Workspace/desktop/secrets.json` (ist gitignored). Gibt es sie schon (z. B. mit `hue`),
nur den Block `discord` dazuschreiben:

```json
{
  "discord": {
    "client_id": "DEINE_CLIENT_ID",
    "client_secret": "DEIN_CLIENT_SECRET"
  }
}
```

Danach die Rechte setzen:

```sh
chmod 600 ~/Workspace/desktop/secrets.json
```

## 5. Koppeln bestätigen

1. Discord muss laufen.
2. Die Shell merkt die geänderte Datei von selbst und startet die Verbindung.
   Das Discord-Fenster kommt nach vorn und fragt: **„Desktop möchte auf dein Konto zugreifen“**.
3. **Autorisieren** klicken. Fertig – das Popout zeigt jetzt die Kanal-Auswahl oder deinen Call.

Die Shell fragt drei Berechtigungen an: `rpc`, `rpc.voice.read` (Call sehen) und `rpc.voice.write` (steuern).

Die Tokens (`access_token`, `refresh_token`) schreibt die Bridge selbst in `secrets.json` und erneuert sie automatisch.

### Schon gekoppelt, aber ohne Steuerung?

Wer vor der Steuerung gekoppelt hat, hat nur Lese-Rechte (`rpc.voice.read`). Dann zeigt das Popout im Call
**Enable Controls** – einmal klicken und in Discord erneut **Autorisieren**. Alternativ:

```sh
qs ipc --any-display -p ~/Workspace/desktop/shell call discord reauth
```

## 6. Bedienung

- **Klick** auf das Discord-Symbol öffnet das Popout (Klick daneben schließt). Das Pfeil-Symbol oben rechts holt das
  Discord-Fenster nach vorn (nochmal = wegräumen).
- **Person anklicken** (im Popout): Lautstärke 0–200 % und Stumm-Knopf (gilt nur für dich).
- **Mic / Deafen / Leave** unten im Popout. Leave braucht zwei Klicks (**Sure?**).
- **Ohne Call** zeigt das Popout eine Kanal-Auswahl – **Klick auf einen Kanal = beitreten**:
  - **Favorites** oben: Stern an einem Kanal setzt/entfernt ihn.
  - **Recent**: die letzten 3 Kanäle, in denen du warst (automatisch).
  - **Servers**: aufklappen zeigt die Sprachkanäle; kleine Köpfe = wer gerade drin ist.
    Geladen wird erst beim Aufklappen und kurz gemerkt (Server 5 min, Kanäle 45 s, Köpfe 30 s).
  - Bist du schon in einem anderen Call, fragt das Popout erst nach (**Switch** / **Cancel**).
  - Favorites und Recent werden in `~/.local/state/desktop/discord.json` gemerkt.
- Das Popout scrollt mit dem Mausrad, wenn es länger wird.

**Grenzen (von Discord vorgegeben):**
- Was du über die Bar einstellst (Lautstärke/Stumm pro Person, Mic, Taub), gilt nur, solange die Verbindung
  steht. Endet sie (Shell- oder Discord-Neustart), setzt Discord diese Einstellungen zurück.
  Dauerhafte Lautstärken stellst du in Discord selbst ein.
- Kamera und Bildschirm teilen lassen sich über die offizielle Schnittstelle nicht schalten. Angezeigt werden sie nur,
  wenn Discord den Zustand mitschickt – sonst fehlt das Kamera-Symbol (statt fälschlich „aus“).
- Freunde und DMs listet Discord über die Schnittstelle nicht – deshalb die feste Chat-Liste (Abschnitt 7).
  Einen DM-Anruf kann man darüber nicht klingeln lassen (man würde nur still in den DM-Call gehen),
  darum gibt es bei den Chats keinen Anrufen-Knopf.

## 7. Chats (optional)

Discord gibt über die offizielle Schnittstelle **keine Liste deiner DMs oder Freunde** heraus.
Deshalb trägst du deine wichtigsten Chats einmal selbst ein:

1. In Discord: **Einstellungen → Erweitert → Entwicklermodus** einschalten.
2. Links in der DM-Liste Rechtsklick auf den Chat → **Kanal-ID kopieren**
   (oder im Browser die Zahl am Ende von `discord.com/channels/@me/<zahl>`).
3. In `secrets.json` unter `discord` ergänzen:

```json
"chats": [
  { "name": "Alex", "id": "123456789012345678" },
  { "name": "Team", "id": "234567890123456789" }
]
```

Klick auf einen Chat im Popout (Abschnitt **Chats**) öffnet ihn im Discord-Fenster und holt das Fenster nach vorn.

## Wenn etwas nicht geht

| Anzeige im Popout | Was tun |
|---|---|
| „Call info isn’t set up yet …“ | Noch kein `discord`-Block in `secrets.json` – Schritte 1–4. |
| „Discord isn’t running.“ | Discord starten. Die Bridge verbindet sich von selbst. |
| „Not linked: invalid client_id“ | Client-ID in `secrets.json` prüfen. |
| „Not linked: Token exchange: …“ | Secret prüfen (ggf. neu erzeugen) und ob `http://localhost` als Redirect eingetragen ist. |
| „Not linked: …“ (Dialog abgelehnt) | Im Popout **Link Again** klicken. |
| „Controls aren’t authorized – re-link below.“ | **Enable Controls** klicken (siehe oben). |

Test im Terminal (zeigt nur Zustände, nie Tokens):

```sh
qs ipc --any-display -p ~/Workspace/desktop/shell call discord status
```

**Entkoppeln:** Discord → Einstellungen → **Autorisierte Apps** → Desktop entfernen, dann `discord`-Block
in `secrets.json` löschen.
