# Mail- und Kalender-Client: Bewertung (AP 18)

Stand 2026-10-18. Nur Recherche und Konfig-/Doku-Lektüre, nichts installiert, nichts umgestellt, keine Mails und keine Zugangsdaten gelesen.
Frage von Bastian: „Kalender/Mail läuft in Thunderbird. Maybe ein besserer Mailclient, der zum Theme passt.“

## Kurzfassung

**Empfehlung: Thunderbird behalten.** Den Umzug Flatpak-ESR → RPM 157 fertig machen, Look einmal nachprüfen, Thunderbird auf „leise“ trimmen.
Kein anderer Client bringt für dieses Setup (ein iCloud-Konto, IMAP + CalDAV + CardDAV, Mail-Wächter, Theme, Tastatur) mehr, als er kostet.
Plan B, falls Thunderbird doch nervt: **Evolution** (am nächsten dran bei Kalender/Kontakten, GTK-Theme). **Betterbird** nur als 1:1-Austausch, wenn Release-Updates den Look ständig kaputt machen.

## Was in Bastians Setup konkret passiert (aus Konfig und Doku)

- **Ein Konto**: iCloud (`secrets.example.json`: ein Eintrag `icloud` mit `mail`, `codes`, `caldav`), App-spezifisches Passwort. Stalwart ist als späteres zweites Konto vorgesehen.
- **Die Shell hängt NICHT am Client für Daten.** `scripts/mail-status` (IMAP, nur lesen, `EXAMINE` + `BODY.PEEK`) und `scripts/agenda-status` (eigener CalDAV-Leser, ohne Zusatzpakete) füllen `~/.cache/desktop/mail.json` und `agenda.json`. Dashboard-Kacheln (Mail, Termine, Todos) bleiben mit jedem Client gleich.
- **Der Mail-Wächter ist ein eigener IMAP-Client** (`scripts/mail-watch`, IMAP IDLE, eigene Verbindung): Meldung bei neuer Mail, Einmal-Codes in die Zwischenablage, Code-Mail nach 5 min in den Papierkorb, Anmelde-Links. Er braucht keinen Mail-Client im Hintergrund und markiert nie etwas als gelesen. Er funktioniert mit jedem IMAP-Client.
- **Die einzige Bindung an Thunderbird** sind Startzeilen und der Mail-Link:
  - `scripts/mail-watch` `open_mail()` → `app-run thunderbird mid:<Message-ID>` (Klick auf die Meldung öffnet genau diese Mail; `mid:` ist ein Thunderbird-Merkmal)
  - `shell/services/Mail.qml` → `Launch.run("thunderbird", ["-mail" | "-calendar" | "mid:…"])`; `Agenda.qml` → `Mail.openCalendar()`
  - `shell/services/Launch.qml`, `scripts/app-run` (RPM zuerst, sonst Flatpak `org.mozilla.thunderbird_esr`), `scripts/flatpak-to-native`
  - Look: `theme/gen/thunderbird.py` + `theme/gen/thunderbird-css/*`, aufgerufen von `scripts/rice` (an/aus)
  - Pakete: `system/packages/dnf.txt` (`thunderbird`), `system/dotfiles.md`
- **Heutiger Stand**: RPM `thunderbird-157.0-2.fc44` ist installiert, aber `~/.thunderbird` gibt es noch nicht; das aktive Profil liegt im Flatpak (`org.mozilla.thunderbird_esr`, 153.5.0). Der Umzug (`scripts/flatpak-to-native migrate thunderbird`) steht noch aus. `userChrome` wurde gegen 153.5 ESR geprüft, auf 157 ist eine Sichtprüfung offen (steht so in `docs/THEMING.md`).
- **Kalender wird nur selten bearbeitet** (AP 12t „Kalender-Popout“ gestrichen, weil „Kalender/Mail läuft in Thunderbird“). Der Client wird gebraucht zum Lesen langer Mails, Antworten/Schreiben, Termine anlegen/ändern, Kontakte, Suche.

## Vergleich 1: Funktionen

Quellen für Versionen: Fedora-44-Repos (`dnf repoquery`), Flathub (`flatpak remote-info`), Projekt-Seiten/GitHub/GitLab (Abruf 2026-10-18). „unklar“ = nicht belegt, vor einer Umstellung prüfen.

| | Thunderbird (heute) | Betterbird | Geary | Evolution | KMail / Kontact | Mailspring | aerc (+ khal, vdirsyncer) | Nur Shell + Browser |
|---|---|---|---|---|---|---|---|---|
| iCloud IMAP + App-Passwort | ja | ja (gleiche Basis) | ja | ja | ja | ja | ja | nur Anzeige; Antworten auf icloud.com |
| CalDAV | ja, eingebaut (iCloud-Kalender-URL einmal eintragen) | ja (gleiche Basis) | **nein** | ja, eingebaut, Auto-Erkennung | ja (über Akonadi) | ja, **jung** (1.26.0 hat Kalender-Fixes, Aufgaben/Erinnerungen unklar) | per vdirsyncer + khal (ikhal-Oberfläche) | Shell liest schon; Bearbeiten auf icloud.com |
| CardDAV (Kontakte) | ja, eingebaut | ja | nein (nur lokal/Konten) | ja, eingebaut | ja | teilweise (Fix in Notizen, Umfang unklar) | vdirsyncer + z. B. khard | nein |
| Kalender/Aufgaben integriert | ja (Reiter) | ja | nein | **ja, stark** (Kalender, Aufgaben, Memos) | ja (KOrganizer) | ja, einfach | getrennt (khal), kein Zusammenspiel mit Mail | nein |
| Push (IMAP IDLE) | ja | ja | ja | ja | ja | laut Sync-Engine „fast keine CPU im Leerlauf“, IDLE nicht belegt | ja (IDLE), aber nur solange das Programm läuft | Wächter (eigener Dienst) hat Push schon |
| Wayland | ja (Mozilla-Wayland) | ja; 153.5-bb11 behebt „Phantom-Schatten“, Tray unter Hyprland **nicht offiziell** | ja (GTK) | ja (GTK3) | ja (Qt) | Electron: Flags nötig; Fenster-Startproblem bei 1.17.x berichtet | – (Terminal) | – |
| Theme-Fähigkeit | **fertig**: Theme-XPI + userChrome/userContent aus `palette.json` (Kacheln, Glut, Inter) | gleiche Vorlagen laufen wahrscheinlich 1:1 (gleiche Codebasis, ESR 153.5 = Stand der Prüfung) | libadwaita: nur Farben per `gtk.css`, Layout bleibt GNOME | GTK3: `gtk.css`; Nachrichtenansicht (WebKit) und Kalender-Widgets schlecht zu stylen | Qt-Farbschema + Stil; Farben ja, Kacheln/Luft nein | Electron: eigene CSS-Themes, Layout frei, aber alles neu bauen | höchste Kontrolle: Styleset + Terminal (Kitty) aus der Palette | Shell selbst im Look; Browser-Seite (icloud.com) nicht |
| Tastatur | ordentlich (viele Kürzel, Schnellfilter/Suche per Tastatur) | wie Thunderbird plus kleine Extras | wenig | gut | gut | gut (Gmail-nahe Kürzel), Befehlspalette | **am besten** (vim-Tasten) | – |
| Suche | gut (Gloda-Volltext lokal, Schnellfilter) | wie Thunderbird | einfach | gut | gut (Baloo/Akonadi) | gut (lokaler Index) | Server-Suche (IMAP), begrenzt; mit notmuch stark, aber das ist ein eigenes Projekt | nur iCloud-Suche im Browser |

## Vergleich 2: Betrieb

| | Thunderbird (heute) | Betterbird | Geary | Evolution | KMail / Kontact | Mailspring | aerc (+ khal, vdirsyncer) | Nur Shell + Browser |
|---|---|---|---|---|---|---|---|---|
| Pflege / letzter Stand | sehr aktiv: 157.0 (30.09.2026), Fedora `157.0-2`; ESR 153.5 im Flatpak | aktiv: 153.5.0esr-bb11 (13.10.2026), folgt Thunderbird-ESR mit Verzug (Blog: Thunderbird-Builds scheitern oft) | **eingeschlafen**: letzter Tag 46.0 (Mai 2024), Flathub-Neubau Nov 2025 | sehr aktiv: Tags 3.62.1 (09.10.2026); Flathub 3.62.0; Fedora 3.60.2 | aktiv: Fedora `26.08.1`; Flathub-Kontact veraltet (6.6.3, Apr 2026) | aktiv: 1.26.0 (02.10.2026) | aerc 0.22.0 in Fedora (Upstream 0.21.0 Aug 2025); neomutt 20260616; vdirsyncer letzter Commit 03.09.2026 (Fedora 0.20.0); khal Fedora 0.13.0, Upstream ruhig; himalaya v2.2.1 (02.10.2026, nicht in Fedora) | – |
| Fedora-Paket / Flatpak | RPM `thunderbird` (Release, nicht ESR); Flatpak ESR | **kein RPM**; Flatpak `eu.betterbird.Betterbird` (Sandbox) | RPM `geary` 46.0-9; Flatpak | RPM `evolution`; Flatpak | RPM `kmail`/`kontact` (zieht Akonadi + viel KDE nach; in `system/packages/dnf.txt` steht `-kmail` als bewusst abgewählt); Flatpak | **kein RPM**; Flatpak `com.getmailspring.Mailspring` | RPM `aerc`, `neomutt`, `khal`, `vdirsyncer`; `himalaya` nur per cargo | – |
| Mail-Wächter weiter nutzbar | ja | ja | ja | ja | ja | ja | ja | ja (er ist der Kern) |
| Klick „genau diese Mail öffnen“ | ja (`mid:`) | ja (gleiche Basis; `mid:` ungeprüft) | ungeprüft | ungeprüft (`evolution mailto:` / `-c mail` sicher) | ungeprüft | ungeprüft | per Skript möglich (Terminal-Fenster, Suche nach Message-ID) | Link auf icloud.com (Suche nach Betreff) |
| Ressourcen / Hintergrund | ein Prozess | ein Prozess | klein | Hintergrunddienste (Evolution-Data-Server) | **schwer** (Akonadi, Datenbank, Indexer) | Electron + Sync-Prozess | winzig | keiner |
| Ablenkung | mittel: Tabs, viele Optionen, lässt sich leise stellen | wie Thunderbird, mehr Knöpfe | **niedrig** (aufgeräumt) | mittel | hoch (viele Module) | niedrig, schöne Oberfläche (aber Pro-Werbung/Abo-Features) | sehr niedrig, aber hohe Einstiegshürde | niedrigste |
| Migrationsaufwand (ein Konto) | **null** (RPM-Umzug steht ohnehin an) | klein: gleiche Profilbasis, Konto neu anlegen oder Profil kopieren (nie zwei Programme gleichzeitig auf demselben Profil laufen lassen; Ordnerlage von Betterbird vorher prüfen) | klein, aber Kalender/Kontakte fehlen | mittel (Konten neu, Ordner liegen auf iCloud, Regeln neu) | mittel bis hoch (Akonadi, Resources) | klein (Konto neu), Regeln neu | hoch (Konfig, Filter für HTML/Einladungen, Kalender separat) | klein, aber Funktionsverlust |

Ordner und Mails liegen bei IMAP auf dem iCloud-Server: Migration = Konto im neuen Client anlegen, nichts kopieren. Zu übernehmen sind nur lokale Dinge: Filterregeln, Signaturen, Kalender-Farben, lokale Ordner, Lesezeichen/Tags (Tags sind Server-Keywords, kommen meist mit).

## Bewertung je Kandidat (ehrlich)

- **Thunderbird behalten.** Pro: Look ist gebaut (Kacheln, Glut-Akzent, Inter, auch Kalender/Adressbuch/Dialoge), Kalender + CardDAV in einem Fenster, `mid:`-Deeplink läuft, kein Migrationsaufwand. Contra: Fensterfülle (Tabs, Menüs), und **jedes Release kann die userChrome-Selektoren brechen** (Release-Kanal 157 statt ESR 153; Erfahrung steht in `docs/THEMING.md`). Dagegen hilft: nach jedem größeren Update `thunderbird.py status` + Screenshot-Prüfung, oder bewusst bei Flatpak-ESR bleiben (ESR ändert nur Fehlerbehebungen, nicht die UI-Selektoren).
- **Betterbird.** Gleiche Codebasis, gleiche Vorlagen, ESR-Basis (153.5 = Stand der Prüfung, also stabiler für den Look) plus kleine Verbesserungen (Tray, Ordner-Fixes). Contra: **kein Fedora-Paket**, nur Flatpak-Sandbox; Tray unter Hyprland offiziell nicht unterstützt; hängt an Thunderbirds Build-Problemen; gewonnen ist für dein Ziel (ruhiger, besser im Theme) fast nichts. Nur sinnvoll als Notlösung, wenn Release-Updates den Look nicht mehr tragbar machen.
- **Geary.** Schönstes ruhiges Fenster, aber kein Kalender, keine Kontakte-Sync, Projekt faktisch eingeschlafen (Tag 46.0 vom Mai 2024). Fällt raus.
- **Evolution.** Funktional der ehrlichste Ersatz (Mail + Kalender + Aufgaben + Kontakte, CalDAV/CardDAV, aktiv, RPM). Contra: GTK3, Look wirkt „Büro“; Theme nur über `gtk.css` (AP 6b), Nachrichtenfenster und Kalender nicht so kachelig zu bekommen wie bei Thunderbird; Hintergrunddienste. Als Plan B einplanen, nicht als Verbesserung.
- **KMail/Kontact.** Qt-Farbschema passt über AP 6a, aber Akonadi + Indexer = schwer, viele Module, viel Ablenkung; steht in `dnf.txt` bewusst als abgewählt (`-kmail`). Nein.
- **Mailspring.** Hübsch und ruhig, CSS-Themes möglich, Flatpak aktuell. Contra: Electron (Wayland-Flags, Startprobleme berichtet), Kalender/Kontakte jung und nicht belegt für iCloud-Alltag, kein RPM, Teile hinter Abo (Pro), Theme müsste komplett neu gebaut werden, `mid:` ungeprüft. Der Gewinn („schöner“) steht in keinem Verhältnis zum Aufwand.
- **Terminal (aerc, neomutt, himalaya + khal/vdirsyncer).** Beste Tastatur, kleinstes Ablenkungsbild, perfekt zur Palette, aber: kein gutes HTML (Newsletter, Einladungen), Kalender wäre eine zweite, separate Welt (vdirsyncer-Sync + khal), keine Kontakte-Oberfläche. Für Bastians Alltag (Antworten, Termine anlegen, Anhänge) mehr Reibung als heute. himalaya ist ein CLI-Werkzeug, kein Client. Höchstens später als Ergänzung (Skript-Zugriff), nicht als Ersatz.
- **Mail/Kalender in der Shell, Antworten im Browser.** Die Shell zeigt das schon (MailTile, AgendaTile, Meldungen, Codes). Fehlt: Lesen von Mail-Text, Antworten, Schreiben, Anhänge, Termine anlegen; selbst bauen heißt SMTP, HTML-Anzeige, Entwürfe, Suche, Threads = ein eigenes Mailprogramm. iCloud-Weboberfläche ist nicht im Look und schwach auf Tastatur. Als **Ergänzung** gut (Schnellaktionen in der Shell: „Öffnen“, später evtl. „Als gelesen“/„Archivieren“ per eigenem IMAP-Aufruf), als Ersatz nein.

## Empfehlung

1. **Thunderbird behalten** (RPM 157), jetzt sauber fertig machen (Plan unten). Aufwand klein, Risiko klein, Look steht.
2. **Leise stellen** statt Client wechseln: eigene Benachrichtigungen aus (die Shell/der Wächter meldet schon; sonst doppelt), Tab-Leiste minimal, Vereinheitlichter Posteingang oder nur Posteingang, Schnellfilter statt vieler Ordner.
3. **Plan B Evolution**, wenn nach 2–3 Wochen Nutzung des 157er-Looks klar ist, dass Thunderbird zu unruhig bleibt. Vorher nichts umstellen.
4. **Betterbird nur bei Look-Bruch**, nicht aus Prinzip.
5. **Kein Eigenbau** eines Mailprogramms in der Shell; nur kleine Zusatzknöpfe, wenn Bastian sie vermisst.

## Plan A: Thunderbird behalten (konkrete Schritte, jeweils auf Bastians Wort)

1. `scripts/flatpak-to-native migrate --dry-run thunderbird` ansehen, dann echt (Thunderbird vorher schließen). Das Konto kommt mit (Passwort steht in `logins.json`/`key4.db`); sonst Konto neu nach `docs/setup/mail-calendar.md` (App-Passwort, ein neues, nie das Apple-ID-Passwort).
2. `python3 -I theme/gen/thunderbird.py apply`, Thunderbird starten, einmal Add-ons → Themes → „Desktop“ aktivieren, **alle Ansichten durchsehen** (Mail, Kalender, Adressbuch, Einstellungen, Dialoge) auf 157, Abweichungen in `thunderbird-css/*` nachziehen.
3. Prüfen: `scripts/app-run --which thunderbird` meldet RPM; Klick auf Mail-Meldung öffnet die Mail (`mid:`); Shell-Klick auf Termin öffnet den Kalender-Reiter; Wayland-Fenster sauber unter Hyprland (Fensterregel/Workspace nach Bastian).
4. Leise-Einstellungen in Thunderbird (Benachrichtigungen aus, Tray nach Wunsch, Ansicht); Hotkeys in `docs/HOTKEYS.md` ergänzen (z. B. Super+M = Mail, Super+Alt+M = Kalender, falls gewünscht – beide frei, Super+K ist die Kürzel-Übersicht; vorher in `hypr/binds.conf` prüfen).
5. Altes Flatpak erst nach Bastians „läuft“ entfernen (`flatpak uninstall`, Daten bleiben unter `~/.var/app/…` als Rückfall).

## Migrationsplan, falls doch gewechselt wird (am Beispiel Evolution; Betterbird sinngemäß)

1. **Nichts löschen**: Thunderbird-Profil und Flatpak bleiben als Rückfall. `scripts/rice off` bleibt der Not-Aus für die Shell.
2. Evolution installieren (`sudo dnf install evolution`: Bastian fragen, sudo) bzw. Betterbird als Flatpak.
3. Neues, **eigenes** App-Passwort für den neuen Client erzeugen (account.apple.com → App-spezifische Passwörter), Konto per IMAP/SMTP + CalDAV + CardDAV anlegen. Nicht `secrets.json` anfassen.
4. Regeln/Filter, Signaturen, Kalenderfarben von Hand übertragen (ein Konto, wenig).
5. Look: Evolution über `gtk.css` aus `palette.json` (neuer Generator wie `thunderbird.py`, in `scripts/rice` an/aus), Betterbird: vorhandene `thunderbird.py` mit dem Betterbird-Profilordner.
6. Kopplung umstellen, klein und an einer Stelle halten: ein Eintrag in `scripts/app-run` (z. B. `mailclient`) statt „thunderbird“ fest in `mail-watch`, `Mail.qml`, `Launch.qml`; Deeplink für „genau diese Mail“ erst prüfen (`mid:` bei Evolution ungeprüft, sonst Posteingang öffnen, wie der Rückfall im Code).
7. Parallelbetrieb eine Woche (Mail-Wächter läuft unabhängig weiter), dann erst Thunderbird entfernen (`sudo dnf remove` = Bastian).
8. Doku nachziehen: `docs/setup/mail-calendar.md`, `docs/THEMING.md`, `system/packages/dnf.txt`, `system/dotfiles.md`, `system/bootstrap`.

## Risiken

- **Look bricht bei Thunderbird-Updates** (Release statt ESR): wichtigstes Risiko bei „behalten“. Gegenmittel: nach Updates prüfen, Selektoren an einer Stelle (`thunderbird-css/`), notfalls Flatpak-ESR oder Betterbird.
- **Verbindungsgrenzen bei iCloud**: Client + Wächter (IDLE) + `mail-status`-Timer = mehrere IMAP-Verbindungen. Heute offenbar unauffällig; Clients mit vielen Verbindungen pro Ordner (Evolution/KMail) vorsichtig testen. Nicht belegt, nur beobachten.
- **Zwei Programme räumen auf**: Der Wächter verschiebt Code-Mails nach 5 min in „Deleted Messages“; ein Client, der gerade geöffnet hat, zeigt kurz eine verschwindende Mail. Mit jedem IMAP-Client gleich, kein Datenverlust (wiederherstellbar).
- **iCloud-Eigenheiten bleiben**: neue Erinnerungen gehen nicht per CalDAV, egal welcher Client (`docs/setup/mail-calendar.md`).
- **Doppelte Meldungen**, wenn der Client eigene Mail-Benachrichtigungen an hat: abschalten.
- **Tray/Hyprland**: Thunderbird 154+ und Betterbird haben Tray-Modus; unter Hyprland nicht überall zuverlässig, Fenster notfalls normal offen lassen.
- **Aussagen ohne eigene Prüfung** (vor Entscheidung testen): `mid:` bei anderen Clients, iCloud-Alltag mit Mailspring-Kalender, IDLE in Mailspring, Wayland-Verhalten von Betterbird/Thunderbird 157 in genau dieser Hyprland-Sitzung.

## Quellen (Abruf 2026-10-18)

- Betterbird Blog (Releases bis 153.5.0esr-bb11, Tray/Hyprland-Hinweis): https://blog.betterbird.eu/
- Thunderbird 154 / 157 (Tray-Modus, Fehlerbehebungen CalDAV/CardDAV): https://www.linuxjournal.com/node/1341455 · https://umatechnology.org/thunderbird-157-0-whats-new-and-fixed/
- Geary Tags (letzter 46.0, 2024-05-20): https://gitlab.gnome.org/GNOME/geary/-/tags
- Evolution Tags (3.62.1, 2026-10-09): https://gitlab.gnome.org/GNOME/evolution/-/tags
- Mailspring 1.26.0 (2026-10-02): https://github.com/Foundry376/Mailspring/releases
- vdirsyncer, khal, himalaya, neomutt, aerc: https://github.com/pimutils/vdirsyncer · https://github.com/pimutils/khal · https://github.com/pimalaya/himalaya · https://github.com/neomutt/neomutt · https://git.sr.ht/~rjarry/aerc
- Fedora-44-Pakete und Flathub-Einträge: lokal per `dnf repoquery` und `flatpak remote-info` abgefragt (nur lesen).
- iCloud + Thunderbird (App-Passwort, CalDAV-URL): https://frightanic.com/apple-mac/thunderbird-icloud-calendar-sync/
