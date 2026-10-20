# Mail + Kalender (iCloud, später Stalwart)

Das Dashboard zeigt ungelesene Mails (IMAP, nur lesen) und Termine/Todos (CalDAV).
Alles steht in `secrets.json` (Repo-Root, gitignored) im Abschnitt `"accounts"`.

## 1. App-spezifisches Passwort holen (iCloud)

1. [account.apple.com](https://account.apple.com) → **Anmelden & Sicherheit** → **App-spezifische Passwörter**
2. Neues Passwort, Name z. B. `desktop`
3. Passwort kopieren (Format `xxxx-xxxx-xxxx-xxxx`)

Nie das normale Apple-ID-Passwort nehmen.

## 2. In `secrets.json` eintragen

Nur diese zwei Felder im iCloud-Eintrag ausfüllen:

```json
"accounts": [
  {
    "name": "icloud",
    "label": "iCloud",
    "user": "deine-apple-id@icloud.com",
    "password": "xxxx-xxxx-xxxx-xxxx",
    ...
  }
]
```

- `user` = Apple-ID-Mail
- `password` = app-spezifisches Passwort
- Rest (`mail`, `caldav`) bleibt wie er ist.
- Optional: `caldav.calendars` = Liste von Kalendernamen (leer = alle).
- `mail` oder `caldav` weglassen = dieser Dienst aus.

## 3. Abrufen

```sh
scripts/rice feeds
```

Zeigt pro Dienst den Status (`ok`, `no-user`, `no-password`, `auth` = Login falsch).
Danach läuft es automatisch per Timer.

## Stalwart (später)

Weiteren Eintrag in `"accounts"` anlegen. Vorlage: `_stalwart_example` in `secrets.example.json`
(`name`, `label`, `user`, `password`, `mail.host`, `caldav.url`). Dann wieder `scripts/rice feeds`.

## Thunderbird (Klick auf Mail/Termin öffnet ihn)

```sh
sudo dnf install thunderbird        # Fedora-RPM (Release, nicht ESR), Profil ~/.thunderbird
```

Die Shell und `mail-watch` starten ihn über `scripts/app-run thunderbird` (RPM zuerst, sonst das alte Flatpak
`org.mozilla.thunderbird_esr`). Altes Flatpak-Profil umziehen: `scripts/flatpak-to-native migrate thunderbird`,
danach `python3 -I theme/gen/thunderbird.py apply` und das Theme einmal aktivieren (☰ → Add-ons und Themes → Themes →
„Desktop“). Rückweg: `mv ~/.thunderbird ~/.thunderbird.rpm` (Flatpak-Profil bleibt unangetastet, Sicherung unter
`~/.local/state/desktop/flatpak-backup/`), dann startet `app-run` wieder das Flatpak.

## Neue Mails + Einmal-Codes (wie bei Apple)

Dienst `desktop-mail-watch` (`scripts/mail-watch`, läuft mit `scripts/rice feeds`) hält per IMAP IDLE
eine Verbindung offen:

- **Neue Mail** → Meldung oben (Absender, Betreff). Klick oder **Open** öffnet genau diese Mail in Thunderbird
  und markiert sie gelesen, **Mark read** markiert nur, **Delete** schiebt sie in den Papierkorb (`scripts/mail-action`).
  Thunderbirds eigene Meldung ist dafür aus (user.js-Block von `theme/gen/thunderbird.py`, nach Neustart).
  Nur wirklich neue Mails, nicht das schon Ungelesene beim Start. Mehr als 4 auf einmal → eine Sammelmeldung.
- **Code in der Mail** (Bestätigungs-/Login-/Sicherheitscode, OTP, TAN, 2FA …) → landet in der Zwischenablage,
  Meldung „Code copied“. Erkennung nur mit passendem Schlüsselwort, Datum/Uhrzeit/Beträge/Telefon-/Bestellnummern
  werden ignoriert. Abhol-/Gutscheincodes zählen nicht.
- **Danach löschen**: Code-Mail nach 5 min in den Papierkorb (iCloud: „Deleted Messages“), also wiederherstellbar.
  Mit Fähnchen markierte Mails bleiben.

Einstellungen pro Konto in `secrets.json` (fehlt der Schlüssel, gelten die Standards):

```json
"mail":  { ..., "notify": true },
"codes": { "autoCopy": true, "trashAfterMin": 5 }
```

- `trashAfterMin`: `0` = sofort, `null` = nie löschen. `autoCopy: false` = keine Codes (dann auch kein Löschen).
- Änderungen an `secrets.json` übernimmt der Dienst selbst (Neustart nach ≤ 30 s).
- Prüfen: `scripts/mail-watch --check` (Login, IDLE, Papierkorb – nur lesen), `scripts/mail-watch --selftest`
  (Code- und Link-Erkennung). Log: `journalctl --user -u desktop-mail-watch` (nur Zahlen, nie Inhalte).

## Anmelde-Links (Magic-Links)

Manche Logins (z. B. Claude) schicken keinen Code, sondern nur einen Link. `mail-watch` erkennt solche Mails:

- **Automatisch geöffnet** (Standardbrowser, Meldung „Login link opened“) nur wenn **alles** stimmt:
  - Anmelde-/Bestätigungs-Mail („sign in“, „magic link“, „verify your email“, „Anmelden“, „Anmeldelink“ …),
  - Absender-Domain steht **exakt** in den Paaren, und der Link-Host ist **für genau diesen Absender** erlaubt
    (exakter Host, bei manchen nur bestimmte Pfade). Tracker (`click.`/`links.`), `google.com/url`, `t.co` …
    nur, wenn sie ausdrücklich im Paar stehen (z. B. `click.discord.com`),
  - `https`, keine Weiterleitung auf fremde Ziele (`continue=`/`next=`/`url=` mit anderem Host),
  - keine Mail mit fremdem Inhalt (GitHub-Benachrichtigungen, `notifications@`/`comments@`/`invitations@`,
    Google-Docs-Freigaben, Kalender-Einladungen, Betreff „invited you“/„Einladung“/„Kommentar“ …), genau ein From,
  - Mail jünger als 10 min, Link noch nie geöffnet,
  - der **eigene** Mailserver bestätigt `dkim=pass` (Signatur-Domain = Absender-Domain) oder `dmarc=pass`:
    zählt nur ein `Authentication-Results` mit eigener authserv-id (iCloud: `*.icloud.com`/`me.com`/`apple.com`,
    sonst die Domain des IMAP-Servers oder `authservIds`) **oberhalb** des ersten `Received`. Kein solcher Header,
    fremde authserv-id oder etwas Negatives → nur Meldung.
- **Sonst** Meldung „Login link · Absender“ mit Knopf **Open link**. Im Log steht der Grund
  (`auth-none`, `foreign-link-host`, `redirect`, `user-content`, `legacy-config` …), nie der Link.
- Gewählt wird nur der Anmelde-Knopf (nie Abmelden, Datenschutz, Social, „Das war ich nicht“). Sind es mehrere
  verschiedene oder keiner eindeutig → gar kein Link, normale Mail-Meldung. Sicherheitswarnungen und
  Passwort-Zurücksetzen werden nie geöffnet. Mails mit Code laufen wie bisher (Code hat Vorrang).

Standardpaare (Absender → Link-Hosts):

| Absender | Link |
|---|---|
| anthropic.com, mail.anthropic.com | claude.ai, claude.com |
| github.com | github.com, nur `/users/…/emails/…/confirm_verification/…` |
| google.com, accounts.google.com | accounts.google.com |
| apple.com, id.apple.com | appleid.apple.com, account.apple.com, idmsa.apple.com |
| slack.com | `<workspace>.slack.com`, nur `/z-…` bzw. `/x-…` (Magic-Login) |
| notion.so · vercel.com · figma.com · linear.app | www.notion.so · vercel.com · www.figma.com · linear.app |
| discord.com | discord.com `/verify`, click.discord.com `/ls/click` |

Ändern in `secrets.json` (global oder pro Konto als `accounts[].magicLinks`; `pairs` ersetzt die Standardpaare ganz):

```json
"magicLinks": {
  "autoOpen": true,
  "pairs": {
    "mail.anthropic.com": ["claude.ai", "claude.com"],
    "slack.com": [{ "host": "*.slack.com", "path": "/[xz]-[A-Za-z0-9-]+/?" }]
  },
  "authservIds": ["icloud.com", "me.com", "apple.com"]
}
```

- `path` = Regex für den ganzen Pfad; `*.` am Host = genau ein Label davor (nur zusammen mit `path`).
- `authservIds` nur nötig, wenn der eigene Server nicht iCloud ist und anders heißt als der IMAP-Host.
- Altes Schema `"domains": [...]` (ohne `pairs`) wird noch gelesen, öffnet aber **nichts** mehr automatisch –
  nur Meldung. Umstellen auf `pairs` (oder `magicLinks` weglassen = Standardpaare).
- `autoOpen: false` = nie automatisch, nur Meldung. Links landen nie im Log (nur die Domain).
- `scripts/mail-watch --check` zeigt pro Konto Paare/altes Schema und die authserv-ids.

## Gut zu wissen

- Neue iCloud-**Erinnerungen** gehen per CalDAV nicht. Nur echte Aufgaben-Kalender (VTODO) erscheinen.
- Mails werden nie als gelesen markiert (Ausnahme: Code-Mails beim Verschieben in den Papierkorb).
