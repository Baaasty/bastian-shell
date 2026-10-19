# iCloud-Passwörter im Browser (Helium)

Autofill aus dem iCloud-Schlüsselbund – in der Erweiterung **„Desktop“** (dieselbe wie die neue Tab-Seite).
Die icp-eigene Erweiterung („Apple Passwords“) wird nicht mehr gebraucht.

Weg der Daten: Erweiterung → Native Host `de.bastian.desktop` (`scripts/chrome-ext`) → `scripts/passwords` → icp (`~/Apps/icp`, nur lesend).
Login bei icp: `icp login`. Neue Einträge vom iPhone/Mac holen: `scripts/passwords sync`.

## Einrichten (einmal, in dieser Reihenfolge)

1. Terminal: `scripts/chrome-ext install --browser helium` (baut die Erweiterung, Host-Manifest zeigt auf dieses Repo).
2. `helium://extensions` → rechts oben **Developer mode** an.
   - „Desktop“ schon geladen → bei „Desktop“ auf **↻** (Neu laden).
   - noch nicht → **Load unpacked** → Ordner `~/Workspace/desktop-hyprland/theme/out/chrome-desktop-ext`
     (für die Farben dasselbe mit `…/theme/out/chrome-desktop`).
3. Falls „Apple Passwords“ (icp) dort steht: **Remove** – sonst erscheinen zwei Dropdowns.
4. Puzzle-Symbol in der Toolbar → bei „Desktop“ die Nadel → Symbol (Holzkachel mit Glutpunkt) = Passwort-Popup.
5. Heliums eigenen Passwort-Manager aus (sonst bietet er zusätzlich Speichern/Ausfüllen an):
   `helium://password-manager/settings` → **Offer to save passwords** aus, **Sign in automatically** aus.
6. Schon offene Tabs einmal neu laden.
7. Prüfen: `scripts/chrome-ext status` → Helium „Host: dieses Repo (mit Passwörtern)“; Popup auf einer Seite mit Login öffnen → „N saved“.

## Bedienung

- **Login-Feld** (Benutzer, E-Mail oder Passwort) anklicken → Dropdown „iCloud Passwords“ mit den Logins der Seite.
  Klick oder ↓/↑ + Enter füllt Benutzer + Passwort. Tippen im Benutzerfeld filtert. Esc schließt.
- **E-Mail zuerst** (Google, Microsoft …): im ersten Schritt füllt der Klick nur die E-Mail; im Passwort-Schritt steht
  derselbe Eintrag oben.
- **2FA-Feld** (auch 6 Einzelkästchen) → Dropdown „Verification code“; der Code wird erst beim Klick frisch geholt.
  Ist das 2FA-Feld schon im Login-Formular, wird es beim Ausfüllen gleich mitgefüllt.
- **Registrierung** (E-Mail-Feld + „Passwort wiederholen“/neues Passwort, oder Sign-up/Register/Konto erstellen in Formular/URL)
  → „Hide My Email“ mit den aktiven Adressen (passende Website zuerst). Neue Adressen anlegen geht hier nicht (nur in iCloud).
- **Popup**: Logins der aktuellen Seite – Benutzer, Passwort, 2FA-Code kopieren, **Fill**. Kopiert wird über
  `passwords copy` (wl-copy `--sensitive`, Klipper/cliphist speichern es nicht), nach 30 s ist die Zwischenablage leer.
- Seite nicht erkannt (anderer Domainname als im Schlüsselbund)? Website zuordnen: in der Shell (Passwörter, `shell/modules/passwords`) oder
  `scripts/passwords match <url>` (zeigt, was passt) und `scripts/passwords add-url <id> <url>`.

## Sicherheit (so gebaut)

- Ohne Klick bekommt eine Seite nichts: das Dropdown zeigt nur Titel/Benutzer und liegt in einem geschlossenen
  Shadow Root (Seiten-Skripte können es nicht lesen). Synthetische Klicks/Tasten der Seite lösen nichts aus.
- Passwort/Code gehen nur nach Klick und nur an den anfragenden Frame – nur bei https oder http://localhost, nur im
  obersten Frame bzw. in Iframes derselben Origin, nur für Einträge, die laut `scripts/passwords match` zur Seite passen
  (geprüft im Hintergrund **und** im Host). Fremde Iframes und http-Seiten bekommen kein Dropdown; im Popup ist dort nur Kopieren möglich.
- Nichts wird geloggt oder in `chrome.storage` gespeichert. Der Shell-Socket des Hosts gibt keine Passwörter heraus.

## Favicons

Im Passwort-Panel (Super+O) steht links an jedem Login das Logo der Website, sonst der Buchstabe.

- **Laden:** im Panel oben **Icons** (Fortschritt „n/N“, nochmal klicken = stoppen). Holt nur fehlende Icons.
  Unten im Panel: **Auto-load on/off** (holt beim Öffnen nach, höchstens einmal pro Stunde; Standard: aus) und **Refresh all** (alle neu holen).
  Ohne Shell: `scripts/favicons run <domain…>` · `scripts/favicons config auto on|off` (Datei `~/.config/desktop/favicons.json`).
- **Datenschutz:** Der Abruf geht direkt bei den Websites aus deiner Liste (nur die Domain, erste Website des Eintrags), kein
  Dritter (kein Google/DuckDuckGo), keine Cookies, kein Referer. Einträge ohne Website werden nicht abgefragt.
- **Ablauf je Domain:** Startseite (https, 5 s, max. 512 KB, max. 3 Weiterleitungen) → `<link rel="icon|apple-touch-icon…">`, bestes Icon →
  sonst `/favicon.ico` → sonst Buchstabe. Bilder werden geprüft (PNG/ICO/SVG/JPEG/WebP, max. 200 KB, nie HTML/Skript) und auf 64×64 gebracht.
- **Schutz:** nur http(s) auf Port 80/443; der Name wird vorher aufgelöst und nur öffentliche Adressen werden angesprochen
  (kein localhost/privates Netz/Router). Höchstens 2 Abrufe gleichzeitig, kleine Pause dazwischen.
- **Cache:** `~/.cache/desktop/favicons/<domain>.png`; „kein Icon gefunden“ merkt sich `<domain>.none` 7 Tage (Netzfehler nicht – die
  werden beim nächsten Lauf wieder versucht). Neu holen: Datei löschen oder **Refresh all**. Alles weg: Ordner löschen.
- Funktioniert ein Logo nicht/falsch: andere Website beim Eintrag eintragen (Detail → Websites), dann **Icons**.

## Ausblenden (WLAN & Co.)

Im Passwort-Panel (Super+O) sind gespeicherte **WLAN-/Hotspot-Passwörter** standardmäßig ausgeblendet. Der iCloud-Schlüsselbund legt sie
mit dem Dienst „AirPort“ ab – daran werden sie erkannt (nicht geraten über Titel = Benutzer). Dazu Platzhalter-Einträge ohne
Buchstaben/Ziffern (z. B. „.“) ohne Website. Einträge mit Website (Router-/Pi-hole-Logins mit IP als Titel) bleiben sichtbar.
Ausgeblendet heißt nur: nicht angezeigt – nichts wird gelöscht, geändert oder synchronisiert.

- **Kopf:** „N + M hidden“ = sichtbare Anzahl + ausgeblendete.
- **Fuß:** „M Wi-Fi hidden · Show · Wi-Fi filter on“. **Show** zeigt sie gedimmt (mit durchgestrichenem Auge) wieder an, **Hide again** blendet sie aus,
  **Wi-Fi filter on/off** schaltet die automatische Erkennung ein/aus. Die Suche findet Ausgeblendete nur bei „Show“.
- **Von Hand:** Maus über die Zeile → Augen-Symbol, oder **Ctrl+H** beim gewählten Eintrag (blendet aus bzw. wieder ein;
  ein fälschlich erkanntes WLAN-Login so wieder sichtbar machen: „Show“ → Ctrl+H).
- **Favicons:** der Icon-Lauf überspringt Ausgeblendete.
- **Von Hand pflegen:** `~/.config/desktop/passwords.json` `{ "hideWifi": true, "hidden": ["<id>"], "shown": ["<id>"] }`
  (`hidden` = zusätzlich ausblenden, `shown` = trotz Filter zeigen; ids aus `scripts/passwords list`).
  Per Befehl: `scripts/passwords config [hideWifi on|off]` · `scripts/passwords hide|unhide <id>`.

## Fehlerbehebung

| Symptom | Lösung |
|---|---|
| Kein Dropdown | Seite neu laden (nach Installieren/↻ nötig). http-Seite oder fremdes Iframe → absichtlich aus. Passt der Eintrag? `scripts/passwords match <url>` |
| Popup: „Desktop host not reachable“ | `scripts/chrome-ext install --browser helium`, dann bei „Desktop“ ↻ |
| Popup: „Desktop host is outdated“ | Host-Manifest zeigt auf ein altes Repo (`scripts/chrome-ext status` → „Host: …“) → install aus diesem Repo, ↻ |
| „cannot open the icp vault …“ | Schlüsselbund gesperrt oder Login abgelaufen: `icp login` |
| Eintrag fehlt | `scripts/passwords sync`, danach Seite neu laden |
| Code wird abgelehnt | Uhrzeit prüfen: `timedatectl` (NTP an?) |
| „extension reloaded – reload this page“ | Erweiterung wurde neu geladen → Seite neu laden |
| Fehler ansehen | `helium://extensions` → Desktop → „service worker“ → Console (nur Fehlertexte, nie Werte) |

Ganz weg: in `helium://extensions` „Desktop“ entfernen (dann auch ohne Tab-Seite) oder nur die Passwörter: `scripts/chrome-ext remove --browser helium`
(Tab-Seite läuft weiter, Tabs im Launcher und Passwörter nicht mehr).
