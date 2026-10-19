# Launcher: die eine Suche für alles

Super antippen (Dashboard) oder per Kürzel öffnen und lostippen. Esc schließt. `?` zeigt alle Präfixe, `?` + Text sucht im Web, `c ` + Text fragt Claude.
Alles Eigene steht in Dateien unter `config/launcher/` – per Hand änderbar, Änderungen gelten sofort (Datei wird beobachtet, kein Neustart).

## Bedienung

- Tippen = Suche über Apps, offene Fenster, Projekte, Aktionen, Tabs. Unten steht immer „Search the web …“ als letzter Ausweg.
- ↑/↓ wählen, Enter führt aus, Tab wechselt den Modus, Esc schließt. Die Chips unter dem Feld zeigen den aktiven Modus (klickbar).
- Präfix am Anfang tippen, dann den Suchtext. Einzelzeichen direkt davor (`=2+2`), Wortpräfixe mit Leerzeichen (`g wetter`).

## Präfixe

| Eingabe | Was | Enter |
|---|---|---|
| (nichts) | Apps, Fenster, Projekte, Aktionen, passende Tabs | startet / springt hin |
| `#` | Projekte, neues Projekt | öffnet den Projekt-Desktop |
| `=` | Rechner (mit Tasten rechts) | kopiert das Ergebnis |
| `:` | Emoji | kopiert |
| `;` | Zwischenablage-Verlauf + Favoriten | kopiert (Strg+P pinnt, Entf löscht) |
| `/` | Dateien nach Namen | öffnet |
| `@` | offene Helium-Tabs | springt zum Tab |
| `pw ` | Passwörter: Titel, Website, Benutzername | kopiert das Passwort (30 s) |
| `cal ` | kommende Termine | öffnet den Kalender (Thunderbird) |
| `c ` (z. B. `c erklär mir rsync`) | Claude fragen | neuer Chat mit dem Text (Claude Desktop, sonst claude.ai in Helium) |
| `g `, `ddg `, `yt `, `gh `, `w `, `maps `, `npm `, `tr ` | Web-Kürzel aus `web.json` | öffnet die Suche in Helium |
| `?` (allein) | Hilfe: alle Präfixe (Web-Kürzel und Config-Probleme inklusive) | öffnet den Launcher mit dem Präfix |
| `?<text>` (z. B. `?wetter berlin`) | Websuche mit dem Standard-Kürzel (erstes in `web.json`, also Google) | öffnet die Suche in Helium |

## Web-Kürzel – `config/launcher/web.json`

```json
{
  "g":  { "name": "Google",  "url": "https://www.google.com/search?q={q}" },
  "yt": { "name": "YouTube", "url": "https://www.youtube.com/results?search_query={q}" }
}
```

- Schlüssel = das Kürzel (klein, Buchstaben/Ziffern/`-_.`). **Neues Kürzel = neue Zeile**, Komma nicht vergessen.
- `url` muss mit `http(s)://` beginnen und `{q}` enthalten (wird URL-kodiert ersetzt). Ohne Suchtext (`g ` + Enter) geht die Startseite auf.
- Das **erste** Kürzel der Datei ist das Standard-Kürzel (Chip „Web“, „Search the web for …“ ganz unten und `?<text>`).
- Reserviert, nicht belegbar: `pw`, `cal`, `c`. Fehlerhafte Einträge werden übersprungen; `?` zeigt eine Zeile „Config problem“.
- Tipp zum Finden der URL: auf der Seite einmal nach `TEST` suchen, Adresse kopieren, `TEST` durch `{q}` ersetzen.
- Geöffnet wird mit `helium <url>` über `Launch.cmd` (uwsm, überlebt Shell-Neustart).

## Claude fragen – `c `

- `c <text>` + Enter startet einen neuen Claude-Chat mit dem Text als Prompt. Nur „c“ mit Leerzeichen; „code“, „chrome“ usw. bleiben normale Suche.
- Weg: Ist ein Handler für `claude://` registriert (`xdg-mime query default x-scheme-handler/claude` → Claude Desktop aus der distrobox „ubuntu“),
  geht `claude://claude.ai/new?q=<text>` an Claude Desktop (gleiches Schema wie dessen „New Chat“-Aktion). Sonst `https://claude.ai/new?q=<text>` in Helium.
- Geprüft wird beim ersten `c ` nach dem Shell-Start; die Zeile zeigt, welcher Weg genommen wird. `c ` ohne Text öffnet einen leeren Chat.

## Passwörter – `pw `

- Quelle: derselbe Dienst wie das Passwort-Panel (`scripts/passwords list`, iCloud-Schlüsselbund). Die Liste zeigt **nur Titel, Website und Benutzername**, nie ein Passwort.
- Enter kopiert das Passwort wie das Panel: `scripts/passwords copy <id> password` (`wl-copy --sensitive`, nach 30 s geleert, kein Verlauf).
  Gibt es nur einen 2FA-Code, kopiert Enter den Code.
- Letzte Zeile „Open Passwords panel“ öffnet das Panel (Super+O) mit dem Suchtext (Details, 2FA, Websites).
- WLAN-Einträge und von Hand Ausgeblendete bleiben auch hier weg (Einstellung `~/.config/desktop/passwords.json`, siehe `docs/setup/passwords.md`).
- Die Metadaten werden beim ersten `pw ` geladen und höchstens alle 5 Minuten aufgefrischt; neue Einträge: `scripts/passwords sync`.

## Kalender – `cal `

Termine aus dem Agenda-Dienst (`~/.cache/desktop/agenda.json`, siehe `docs/setup/mail-calendar.md`): laufende und kommende, nach Beginn sortiert.
Tippen filtert nach Titel/Ort/Kalender. Enter öffnet den Thunderbird-Kalender (läuft er schon, kommt er nach vorn).

## Tabs – `@`

Offene Helium-Tabs über die Erweiterung „Desktop“ (`scripts/chrome-ext status` zeigt „Tabs: N“). Ohne Präfix erscheinen nur klare Treffer.
Zeigt `status` „Host aus“, ist Helium zu oder die Erweiterung nicht geladen (`docs/setup/passwords.md`, Einrichten).

## Wo steckt was (zum Selbermachen)

| Datei | Inhalt |
|---|---|
| `config/launcher/web.json` | deine Web-Kürzel |
| `shell/modules/launcher/Launcher.qml` | Präfix-Liste `sources`, `parse()`, `rebuild()` (ein Block pro Modus) |
| `shell/services/WebShortcuts.qml` | liest `web.json`, öffnet die Suche |
| `shell/services/LauncherSources.qml` | Wortpräfixe zerlegen, Passwort-Metadaten, Kalender-Zeilen, Claude fragen |

Neues Präfix: Eintrag in `sources` (Chip + Hilfe), Zweig in `parse()`/`LauncherSources.parse()` und ein Block in `rebuild()`.
Zähler für „häufig benutzt zuerst“: `~/.local/state/desktop/launcher.json` (nur IDs, nie Suchtexte).
