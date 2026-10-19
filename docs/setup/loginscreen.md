# Login-Bildschirm (Plasma Login Manager)

Login im Desktop-Look: Lockscreen-Wallpaper, Farbschema + Cursor „Desktop“, Schrift Inter,
Monitor-Anordnung wie in der Sitzung (Login auf DP-2), NumLock an. Tastatur DE kommt schon aus `localectl`.
Dazu das **Layout des Lockscreens** (große Mono-Uhr, Code-Kästchen, runde Symbol-Knöpfe) – siehe unten.

## Befund (2026-10-18) – warum der eigene Look nicht erschien

- Login Manager ist **Plasma Login Manager 6.7.5** (`plasmalogin.service`, `display-manager.service` zeigt darauf), kein SDDM.
  Er startet pro Login einen eigenen kwin (Greeter-Sitzung des Users `plasmalogin` auf tty1); die Hyprland-Sitzung
  läuft danach auf tty2 (`uwsm start -e -D Hyprland hyprland.desktop`). Der Greeter ist von der Sitzung unabhängig,
  Hyprland ändert daran nichts.
- Die Einrichtung (`apply`) **wurde ausgeführt** (08:29 und 17:37): Wallpaper-Block in `/etc/plasmalogin.conf`, Kopien in
  `/var/lib/plasmalogin`, Layout-Theme + Drop-in liegen dort. Der Greeter lädt alles korrekt (Greeter-Journal
  17:37:54: `desktop-login: theme on`, Theme-Bilder in `~/.cache/desktop/loginscreen-shot/` sehen richtig aus).
- **Ursache:** Um 17:42:48 wurde `sudo -u plasmalogin touch /var/lib/plasmalogin/.local/share/desktop-login/off`
  ausgeführt (= `scripts/loginscreen theme off`). Seitdem schreibt der Drop-in bei jedem Start
  `desktop-login: theme off (fingerprint mismatch or off file) - stock greeter` (17:46, 19:42, 19:53) – es erscheint
  der Standard-Greeter. Der Fingerabdruck der Systemdateien stimmt (geprüft, kein Plasma-Update seitdem), es liegt also
  nur an der Datei `off`. Zurück: `scripts/loginscreen on`.
- Ohne root nicht prüfbar (Home von `plasmalogin` ist 0750): Inhalt von `/var/lib/plasmalogin`. `status` zeigt deshalb
  den **tatsächlichen** Zustand aus dem Journal („Letzter Login-Bildschirm: …“).

## Was der Plasma Login Manager erlaubt (ehrlich)

Kein Theme-/Look-and-Feel-Schlüssel (anders als SDDM): Layout (`Main.qml`/`Login.qml`) ist ins Binary einkompiliert.
Möglich ohne Eingriff ins System: Wallpaper (inkl. Wallpaper-Plugin), Farbschema, Cursor, Schriften, Monitor-Anordnung,
NumLock – alles über `/var/lib/plasmalogin` und `/etc/plasmalogin.conf`. Das **Layout** ersetzen wir über die Komponenten
`org.kde.breeze.components` per `QML_IMPORT_PATH` (siehe unten). Grenze: ändern sich diese Komponenten bei einem
Plasma-Update, schaltet der Fingerabdruck-Schutz auf den Standard-Greeter zurück, bis `install` neu läuft.
Nicht möglich: eigene Widgets/Animationen jenseits der Komponenten (Login-Logik bleibt im Binary), Blur (der Greeter
läuft im eigenen kwin ohne Hintergrund-Fenster). Alternative nur wenn das nicht reicht: zurück zu SDDM mit
Theme (volle QML-Freiheit, eigenes Thema in `/usr/share/sddm/themes`) – Vorschlag, nicht umgesetzt.

```sh
scripts/loginscreen status            # ohne root
scripts/loginscreen apply --dry-run   # zeigt alles, was geschrieben würde (ohne root)
scripts/loginscreen apply             # sudo: erst Backup, dann setzen
scripts/loginscreen preview           # „Benutzer wechseln“: echter Login-Bildschirm, Sitzung läuft weiter
scripts/loginscreen restore           # sudo: exakt zurück
scripts/loginscreen shot              # ohne root: Layout als Bilder (~/.cache/desktop/loginscreen-shot/)
scripts/loginscreen test [sek]        # ohne root: Layout live auf allen Monitoren, Testmodus, endet von selbst
scripts/loginscreen theme off|on      # sudo: nur das Layout aus/an, Farben/Wallpaper bleiben (Kurzform: `on` / `off`)
scripts/loginscreen install           # = apply (Alias)
```

**Einrichtung in einem Schritt:** `scripts/loginscreen apply --dry-run` (prüft mit dem echten Greeter, ohne root),
dann `scripts/loginscreen apply` (fragt einmal sudo, sichert zuerst). Ist das Theme schon installiert, aber ausgeschaltet:
nur `scripts/loginscreen on`. Prüfen ohne Neustart: `scripts/loginscreen preview` (Benutzer wechseln) oder
`scripts/loginscreen shot` (Bilder). **Rückbau:** `off` (nur Layout) oder `restore` (alles wie vor `apply`).

Backup: `~/.local/state/desktop/loginscreen-backup/` (`plasmalogin.conf` + Tar von
`/var/lib/plasmalogin/{.config,.cache,.local,wallpapers}` mit Rechten/SELinux). Ein zweites `apply`
überschreibt das Backup nicht.

## Was `apply` schreibt

| Datei | Inhalt |
|---|---|
| `/etc/plasmalogin.conf` | markierter Block am Ende: `[Greeter] WallpaperPluginId` + `Image=` |
| `/var/lib/plasmalogin/wallpapers/desktop-login.jpg` | Kopie des Lockscreen-Bilds |
| `/var/lib/plasmalogin/.config/` | `kdeglobals` (Farben, Inter), `kcminputrc` (Cursor, NumLock), `kwinoutputconfig.json`, `plasmarc`, `plasma-localerc` |
| `/var/lib/plasmalogin/.local/share/` | `icons/Desktop/`, `color-schemes/Desktop.colors` |
| `/var/lib/plasmalogin/.cache` | gelöscht (Plasma-Theme-Cache, wie die KCM) |
| `/var/lib/plasmalogin/.local/share/desktop-login/` | Layout-Theme (`qml/org/kde/breeze/components/`, `fingerprint.sha256`) |
| `/var/lib/plasmalogin/.config/systemd/user/plasma-login.service.d/desktop-login.conf` | Drop-in, das das Theme einhängt |
| `/var/lib/plasmalogin/.local/share/fonts/desktop/` | JetBrains Mono NF + Material Symbols (liegen sonst nur in `~/.local`) |

Alles in `/var/lib/plasmalogin` wird als User `plasmalogin` geschrieben (wie der KCM-Helper).

## Layout-Theme (Lockscreen-Look)

Quelle: `plasma/loginscreen/` (`components/` = unsere QML, `systemd/desktop-login.conf` = Drop-in,
`preview/ShotHook.qml` = nur für `shot`). Farben kommen aus `DesktopTheme.qml` des Lockscreens
(erzeugt aus `theme/palette.json`), Hauptmonitor und Code-Länge (`desktopAutoSubmitLength`, Standard 6)
liest `apply` aus den Lockscreen-Einstellungen.

**Warum so:** Plasma Login 6.7.5 hat keinen Theme-/Look-and-Feel-Schlüssel. `Main.qml`/`Login.qml` sind
fest im Binary (`qrc:/qt/qml/org/kde/plasma/login/`). Sie importieren aber `org.kde.breeze.components`
(Uhr, Formular-Rahmen, Nutzerliste, Aktions-Knöpfe). Eine eigene Fassung davon wird über
`QML_IMPORT_PATH` eingehängt – nur für `plasma-login.service`, per User-Drop-in im Home von `plasmalogin`.
Ersetzt: `Clock`, `SessionManagementScreen` (Farben, Code-Kästchen, Pillen-Felder, runder Knopf),
`UserList`/`UserDelegate` (ein Nutzer = nur Name), `ActionButton` (Material-Symbole, englisch).
Unverändert vom System: alles andere (Login-Logik, PAM, Sitzungswahl, Fußleiste).

**Schutz, damit Login immer geht:**
- `apply` startet vorher den echten Greeter im Testmodus offscreen (ohne root) und bricht ab, wenn das
  Theme Meldungen erzeugt, die der Original-Greeter nicht hat.
- Der Drop-in prüft bei jedem Start `fingerprint.sha256` (Greeter-Binary + Breeze-Komponenten des Systems +
  unsere Dateien). Passt etwas nicht (Plasma-Update, kaputte Kopie) oder liegt `…/desktop-login/off`,
  startet der **normale Greeter**. Nach einem Plasma-Update also `scripts/loginscreen apply` erneut
  (`status` zeigt es an). Log: `journalctl _UID=$(id -u plasmalogin) | grep desktop-login`.
- Einzeln abschaltbar: `scripts/loginscreen theme off`.

**Testen ohne root:** `scripts/loginscreen shot` (Bilder: Ruhe, aktiv, Tippen, Fehler, „Other user“) oder
`scripts/loginscreen test 45` (echter Greeter mit Mock-Login über der Sitzung; startet keinen kwin).
Raus vor Ablauf: „Other user“ → beliebiger Name + `mypassword`. Escape schaltet im Testmodus die Monitore aus.

## Warum kein Drop-in in `/etc/plasmalogin.conf.d/`

Der Greeter lädt (später gewinnt): `/etc/plasmalogin.conf.d/*` → `/usr/lib/plasmalogin/defaults.conf`
→ `/usr/lib/plasmalogin/plasmalogin.conf.d/*` → `/etc/plasmalogin.conf`. Fedoras `defaults.conf`
setzt `Image=` aufs Fedora-Bild und würde ein Drop-in überstimmen. Die KCM schreibt deshalb auch
direkt `/etc/plasmalogin.conf` (komplett neu). Benutzt du später die KCM, ersetzt sie unseren Block –
`restore` stellt trotzdem den Stand vor `apply` her.

## Offizieller Weg (Klick)

`kcmshell6 kcm_plasmalogin` → Bild wählen + „Plasma-Einstellungen übernehmen“. Läuft über den
KAuth-Helper `kcmplasmalogin_authhelper` (polkit `org.kde.kcontrol.kcmplasmalogin.save|sync|reset`).
Nachteil: kopiert `kdeglobals` komplett (inkl. Catppuccin-Look-and-Feel, das der Greeter nicht lesen kann),
keine Inter-Schrift, Cursor/Farbschema aus `~/.local` fehlen dem Greeter.

## Fehlersuche

- Standard-Look obwohl installiert: `scripts/loginscreen status` → „Letzter Login-Bildschirm“. „Theme aus“ = Datei `off`
  (`scripts/loginscreen on`) oder Fingerabdruck (nach Plasma-Update: `scripts/loginscreen install`).
- Wallpaper falsch: unter Hyprland kommt die Quelle aus `kscreenlockerrc` (Lockscreen-Bild); `install` kopiert sie neu.
- `test` unter Hyprland: Greeter im Testmodus als Layer-Shell über der Sitzung, Tastatur gehört ihm, endet nach N s.

## Wenn der Login-Bildschirm kaputt aussieht

Anmelden geht trotzdem (PAM/Daemon werden nicht angefasst). Rückweg: Hyprland-Sitzung liegt auf tty2
(Strg+Alt+F2), Login-Bildschirm auf tty1 (Strg+Alt+F1), freie Konsole Strg+Alt+F3. Notfalls Strg+Alt+F3 → auf der Konsole
einloggen → `~/Workspace/desktop-hyprland/scripts/loginscreen theme off` (nur Layout) oder `… restore` (alles) →
`sudo systemctl restart plasmalogin` (nur, wenn du grafisch nicht angemeldet bist) bzw. Strg+Alt+F1/F2
zurück zum Login-Bildschirm.
