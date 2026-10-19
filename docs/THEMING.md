# Theming – alles im desktop-Look

Eine Farbquelle: `theme/palette.json` (aktiv: **hearth**). Umschalten: `scripts/rice variant <name>` (hearth · ember · walnut · candlelight · dusk · clay · linen).
Erzeugen: `python3 -I theme/gen/all.py` · An/Aus: `scripts/rice theme on|off`.

## Variante hearth (deckend, freundlich) – Stand 2026-10-18

Bastian: „nicht so glassy, alles freundlich“. **hearth** ist Standard: alle Flächen deckend, kein Blur, kein Glühen, ruhige Schatten.
Die alte Glas-Variante bleibt als **ember** (mit Blur): Rückweg `scripts/rice variant ember` (erzeugt alles neu inkl. App-Themes).
Nur Shell + Hyprland-Rahmen: `python3 -I theme/gen/hypr.py [variante]` (die Shell liest `palette.json` live).

| Token                                                   | Zweck (hearth)                                                                                  |
| ------------------------------------------------------- | ----------------------------------------------------------------------------------------------- |
| `bg` / `bgBottom`                                       | Grund hinter allem (`#2A211B` / `#211A15`), Hyprland-Hintergrund                                |
| `surface`                                               | Kachel/Karte (`#382D26`), deckend                                                               |
| `surfaceRaised`                                         | eine Stufe heller: Bar, Eingabefelder, Hover (`#45372E`)                                        |
| `surfaceSunken`                                         | eine Stufe dunkler: Vertiefungen, Spuren (`#2F2620`)                                            |
| `glassTint` / `glassStrong`                             | Kompatibilität für `Glass.qml`; in hearth = `surface` / `surfaceRaised` (deckend)               |
| `border` / `borderStrong`                               | weiche 1-px-Ränder / Spuren, Trenner                                                            |
| `text` / `textMuted` / `textFaint`                      | Creme, Sekundär, Hinweise (Kontrast ≥ 4,5 : 1 auf `surface`)                                    |
| `accent` / `accentHover` / `accentPressed`              | sanftes Ember-Terrakotta, nur für aktiv/wichtig/Fokus                                           |
| `accentText` / `accentSoft` / `accentFill` / `onAccent` | Akzent als Text · Tönung (aktive Chips, Auswahl) · deckender Ton · Text auf Akzent              |
| `success` / `warning` / `error` (+`warningSoft`)        | Moos · Bernstein · Rost-Rot                                                                     |
| `dim`                                                   | Abdunkeln hinter Overlays (0,82, ohne Blur: Inhalt dahinter bleibt ruhig)                       |
| `shadow`                                                | ruhiger Schlagschatten (`Glass.qml`, Hyprland)                                                  |
| `glow`                                                  | nur noch dünner Akzent-Ring (Fensterwechsler), kein Schein                                      |
| `blur`                                                  | `true` = durchsichtige Glas-Flächen + Compositor-Blur (ember & Co.), `false` = deckend (hearth) |

Maße (global): Radien sm 10 · md 14 · lg 18 · xl 24 · Fenster 16; Bewegung fade 180 / slide 240 / state 220 ms (OutCubic, keine Feder); Standardtext 14 px.
Hyprland (`hypr/look.conf`, erzeugt): Rahmen 2 px (aktiv = Akzent, inaktiv = ruhiges Braun), Blur aus, weicher Schatten.

**Wo Blur noch ausgelöst werden kann:** `BackgroundEffect.blurRegion` steht weiter in 22 Modulen (Bar, Dashboard, Launcher, Power, Keys, Packages, OSD,
Benachrichtigungen, Workbar, Popouts …), bleibt aber wirkungslos, solange `decoration.blur.enabled = false` in `hypr/look.conf` steht
(wird aus `blur` der Variante erzeugt). Wer Blur wieder will: `scripts/rice variant ember`.
Offen (AP 6): KDE-Farbschema, Konsole, VS Code, Helium, Thunderbird usw. sind noch aus der alten Palette (ember) erzeugt.

Legende: ✅ fertig · 🟡 teilweise / Bastian muss einmal klicken · ⬜ offen

## System & Desktop

| Bereich                                                                                 | Stand                 | Wie / was noch                                                                                                                                                                                                                                                                                  |
| --------------------------------------------------------------------------------------- | --------------------- | ----------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------- |
| Shell (Bar, Dashboard, Launcher, Popups, OSD, Power, Workbar)                           | ✅                    | liest `palette.json` live                                                                                                                                                                                                                                                                       |
| KDE-Farbschema „Desktop Hearth“ (Dolphin, Einstellungen, alle Qt-Apps, Dateidialog)     | ✅                    | aktiv seit AP 6a, siehe Abschnitt „Qt/KDE“ · altes „Desktop“ (ember) bleibt als Rückweg                                                                                                                                                                                                         |
| Fensterrahmen (Breeze in Theme-Farben, Knöpfe links: Menü · Pin · Vordergrund)          | ✅                    | `rice theme on`                                                                                                                                                                                                                                                                                 |
| Cursor „Desktop“                                                                        | ✅                    | `design/cursors/build-xcursor.sh`, dann `plasma-apply-cursortheme Desktop`                                                                                                                                                                                                                      |
| Wallpaper (glut-clean auf 3 Monitoren + Lockscreen)                                     | ✅                    | `scripts/wallpaper set --design <set>` · Alternativen: holz/raster/topografie × ember/walnut                                                                                                                                                                                                    |
| Lockscreen (Plasma-Shell-Paket + Hyprland-Sperre der Shell, Uhr mit Sekunden, Englisch) | ✅ hearth             | Farben aus der Palette, siehe „Lockscreen und Login“ unten · `scripts/shellpkg install`                                                                                                                                                                                                         |
| Fensterwechsler (Super+Tab)                                                             | ✅                    | `scripts/rice switcher`                                                                                                                                                                                                                                                                         |
| Login-Bildschirm (Plasma Login Manager)                                                 | 🟡 hearth vorbereitet | 🧑 `scripts/loginscreen install` (sudo), dann `scripts/loginscreen on` – siehe „Lockscreen und Login“                                                                                                                                                                                           |
| Icon-Theme „Desktop“ (Ordner holzbraun)                                                 | 🟡                    | `python3 -I theme/gen/icons.py` → `~/.local/share/icons/Desktop-Icons` (Spiegel von Breeze Dark, nur Ordner 32–96 px in `woodLight`; `--glut-symbol` = Symbol in Glut). An: `/usr/libexec/plasma-changeicons Desktop-Icons` · zurück: `… breeze-dark`. Fehlt: Einbindung in `rice theme on/off` |
| GTK-Apps (GTK3/GTK4/libadwaita, auch Flatpaks)                                          | ✅                    | `theme/gen/gtk.py` (AP 6b), siehe Abschnitt „GTK/libadwaita“                                                                                                                                                                                                                                    |
| Benachrichtigungs-Töne / Systemklänge                                                   | ⬜                    | leise, warme Klänge statt Plasma-Standard (optional)                                                                                                                                                                                                                                            |
| Schriften systemweit (Inter + JetBrains Mono)                                           | 🟡                    | in der Shell ✅; KDE-Systemschrift prüfen/setzen                                                                                                                                                                                                                                                |

## Menüs und Dialoge (Stand 2026-10-18)

Ziel (Bastian): **alle Menüs custom**. Was der Shell gehört, ist eigen gebaut; was Apps/Portale zeigen, lässt sich nur **themen**
(Farbschema/GTK-CSS), nicht ersetzen. Stand: **eigen** = Shell-Komponente im Desktop-Look · **gethemt** = fremder Dialog in Palette-Farben ·
**Standard** = fremder Look · **aus** = erscheint nicht.

| Menü / Dialog                                                                    | Stand                                         | Wie / was noch                                                                                                                                                                                                                                                                                                                                                         |
| -------------------------------------------------------------------------------- | --------------------------------------------- | ---------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------- |
| Tray-Rechtsklick (alle Tray-Apps, auch Liste hinter dem Pfeil)                   | eigen (neu)                                   | `shell/modules/bar/TrayMenu.qml` statt nativem Qt-Menü (`QsMenuAnchor`): Einträge aus `QsMenuOpener`, Häkchen/Radio, Icons, Trenner, deaktiviert = gedämpft, Untermenüs klappen im selben Fenster auf (Zeile „‹ Name“, Esc/←/Rücktaste). Look/Zeilenhöhe wie das Workspace-Menü                                                                                        |
| Workspace-Menüs (Bar-Chips, Workbar-Rechtsklick, „+ New“-Vorlagen, Quick links)  | eigen                                         | `DesktopChips.qml`, `WorkBar.qml`, `QuickLinksPopup.qml`                                                                                                                                                                                                                                                                                                               |
| Dashboard-Menüs (Hue-Szenen, Licht aus), Eingabefeld (Umbenennen, Aufgabe …)     | eigen                                         | `HueScenes.qml`/`ControlsTile.qml`, `Prompt`                                                                                                                                                                                                                                                                                                                           |
| Benachrichtigungen, OSD, Fensterwechsler, Power-Menü, Launcher, Kürzel (Super+K) | eigen                                         | Shell                                                                                                                                                                                                                                                                                                                                                                  |
| Absturz-Meldung (statt DrKonqi)                                                  | eigen (neu)                                   | `shell/modules/crash` + `services/Crashes.qml` (liest systemd-coredump aus dem User-Journal): Karte unten rechts „Discord crashed“, Signal/Uhrzeit/„3rd time today“, Restart · Details · Dismiss, gleiche App = eine Karte. DrKonqi-Fenster nur unter Hyprland bei laufender Shell aus (`scripts/hypr drkonqi on\|off`), Plasma unverändert. Doku `docs/CRASHES.md`    |
| Passwort-Abfrage (Polkit)                                                        | eigen                                         | `shell/modules/polkit`; nur ohne Shell der KDE-Agent (gethemt)                                                                                                                                                                                                                                                                                                         |
| Sperrbildschirm                                                                  | eigen                                         | Shell-Sperre; Notfall hyprlock in Palette-Farben (gethemt)                                                                                                                                                                                                                                                                                                             |
| Login                                                                            | 🟡 gethemt, vorbereitet                       | Plasma Login Manager, 🧑 `scripts/loginscreen on`                                                                                                                                                                                                                                                                                                                      |
| Layout-Menü (Super+Alt+K)                                                        | eigen (neu)                                   | `shell/modules/layouts` (IPC `layouts`): Liste, Suche ab 7 Layouts, „Save desktop N as…“ mit Namensfeld, Löschen mit Rückfrage in der Zeile; Logik bleibt in `scripts/layout`. Nur ohne laufende Shell der kdialog-Rückfall (`scripts/layout menu`, gethemt)                                                                                                           |
| Datei/Ordner wählen aus der Shell (Launcher „Choose Folder…“, Snip „Save as“)    | eigen (neu)                                   | `shell/modules/filepicker` + `services/FilePicker.qml` (`pickFolder` / `openFile` / `saveFile`, Callback + Promise): Brotkrumen, Favoriten + Projektordner, Tippen filtert, ⌫ hoch, Strg+H versteckte Dateien, Format-Chips, Überschreiben-Rückfrage. Ansehen: `qs ipc … call filepicker demo folder\|open\|save`                                                      |
| Abmelden ohne Shell (Strg+Alt+Entf → `scripts/hypr power`)                       | gethemt (bewusst)                             | kdialog-Ja/Nein: erscheint nur, wenn die Shell **nicht** läuft – ein Shell-Dialog ginge dann gerade nicht                                                                                                                                                                                                                                                              |
| Datei öffnen/speichern (alle Apps)                                               | gethemt                                       | Portal → xdg-desktop-portal-kde (Breeze + „Desktop Hearth“); GTK-Apps ohne Portal: GTK-Dialog über `gtk.css`                                                                                                                                                                                                                                                           |
| „Öffnen mit“, Drucken, Berechtigungen („App möchte …“, Kamera, USB)              | gethemt                                       | KDE-Portal (Kirigami/Breeze + Farbschema) · „läuft im Hintergrund“ kommt als Benachrichtigung in die Shell                                                                                                                                                                                                                                                             |
| Bildschirm teilen (Auswahl)                                                      | in Arbeit                                     | eigenes Quickshell-Overlay (eigene Spur, `shell/modules/sharepicker/`); bis dahin xdph-Picker (Qt, Farbschema)                                                                                                                                                                                                                                                         |
| Screenshot-, GlobalShortcuts-, InputCapture-Portal                               | kein Dialog                                   | xdg-desktop-portal-hyprland ohne Oberfläche (Kürzel über `bind = …, global, …`)                                                                                                                                                                                                                                                                                        |
| RemoteDesktop-Portal                                                             | –                                             | `portals.conf` zeigt auf hyprland, xdph 1.4.1 bietet das nicht an → keine Fernsteuerung, kein Dialog                                                                                                                                                                                                                                                                   |
| KWallet, pinentry-qt (GPG), gcr (GNOME-Keyring)                                  | gethemt                                       | Qt bzw. GTK                                                                                                                                                                                                                                                                                                                                                            |
| Hyprland „App reagiert nicht“ (ANR)                                              | gethemt (neu, 🧑 einmal installieren)         | hyprtoolkit-Dialog: `python3 -I theme/gen/hyprtoolkit.py` → `~/.config/hypr/hyprtoolkit.conf` (Fenster `surface`, Knöpfe `surfaceRaised`, Terrakotta, Inter, Radien sm/md; auch in `scripts/hypr install`). Bleibt an (`misc:enable_anr_dialog`): Hyprland meldet ANR nicht per IPC, ein Shell-Ersatz ginge nur geraten. Rückweg: `rm ~/.config/hypr/hyprtoolkit.conf` |
| hyprland-dialog (Berechtigungen), Willkommen, hyprland-run                       | aus / gethemt                                 | `ecosystem:enforce_permissions` aus → keine Fragen; Willkommen nur beim ersten Start; statt hyprland-run der Launcher – alle im hyprtoolkit-Look                                                                                                                                                                                                                       |
| Update-News, Spenden-Hinweis, Logo/Splash                                        | aus                                           | `general.conf`: `ecosystem:no_update_news`, `no_donation_nag`, `misc:disable_hyprland_logo`, `disable_splash_rendering`                                                                                                                                                                                                                                                |
| Konfig-Fehlerleiste, `hyprctl notify`                                            | Standard (bewusst)                            | von Hyprland gezeichnet, nicht thembar; nur bei Fehlern (`hyprctl configerrors`), die Shell nutzt `hyprctl notify` nicht                                                                                                                                                                                                                                               |
| hyprpolkitagent                                                                  | –                                             | nicht installiert (Shell-Agent)                                                                                                                                                                                                                                                                                                                                        |
| Qt/KDE-Apps (Dolphin, Okular, Einstellungen)                                     | gethemt (App-intern) · 🧑 Kvantum vorbereitet | Breeze + Farbschema: Menü = Fensterfarbe, Ecken ~5 px, Hover = Terrakotta-Rahmen (Breeze-fest). Echte Radien/`surfaceRaised`/ruhiger Hover nur mit Kvantum: `theme/gen/kvantum.py`, an mit 🧑 `sudo dnf install kvantum` → `scripts/kvantum-theme on` (zurück `off`), siehe „Qt/KDE“                                                                                   |
| GTK-Apps (Popover, Kontextmenüs, Menüleisten)                                    | gethemt (App-intern, neu)                     | `gtk.css`: Menü/Popover = `surfaceRaised`, 1-px-Rand, Radius 10 (GTK3) / 14 (Popover), Hover = eine Stufe heller statt Akzent-Rahmen                                                                                                                                                                                                                                   |
| VS Code                                                                          | gethemt (App-intern)                          | Theme „Desktop“ (`menu.*`)                                                                                                                                                                                                                                                                                                                                             |
| Kitty                                                                            | –                                             | kein Kontextmenü (Rechtsklick = Auswahl erweitern)                                                                                                                                                                                                                                                                                                                     |
| Helium (Kontextmenü, Menü ⋮, Vorschläge, Seitenleiste, Einstellungen)            | gethemt (neu, ab nächstem Start)              | `scripts/helium-colors on`: Grundfarbe `accent`, Variante neutral → ganze Oberfläche warm (Menüs warmes Fast-Schwarz `#1E1B1A`, Ecken/Abstände Chromium). Ohne „Desktop Theme“-Erweiterung (die macht Menüs grau). Siehe „Helium / Chrome“                                                                                                                             |
| Discord (Equicord), Thunderbird                                                  | 🟡 gethemt nach Klick                         | siehe „Discord“/„Thunderbird“                                                                                                                                                                                                                                                                                                                                          |
| Spotify                                                                          | Standard (bewusst)                            | siehe „Spotify“                                                                                                                                                                                                                                                                                                                                                        |

## Apps

| App                                                                                                                                                                                  | Stand                                     | Wie / was noch                                                                                                                                                                                                                                                                                   |
| ------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------ | ----------------------------------------- | ------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------ |
| Kitty (Standard-Terminal, Super+Return; hearth: deckend, Balken-Cursor, Tabs + Splits)                                                                                               | ✅                                        | `scripts/kitty-theme install` (Rückweg `off`), Kürzel siehe „Kitty-Kürzel“ unten                                                                                                                                                                                                                 |
| Fastfetch beim Öffnen von Kitty (kleine Katze; Name, Gruß nach Tageszeit, Abschnitte „system“ und „hardware“ in Palettenfarben) – nur erstes Fenster, nicht in Tabs/Splits/Drop-down | ✅                                        | kommt mit `scripts/kitty-theme install`; Bild `config/fastfetch/cat.txt` (Farbmarke $1), Farben/Module `theme/gen/fastfetch.py`                                                                                                                                                                  |
| zsh (Standard-Shell): Autosuggestions, Syntax-Highlighting, Tab = Fuzzy-Liste mit Vorschau (fzf-tab), eza als ls, bat als cat, zoxide, fzf – Kürzel siehe „zsh“ unten                | ✅                                        | `scripts/zsh-setup install` (Rückweg `off` = wieder bash), Konfiguration `config/zsh/zshrc`, Farben `theme/gen/zsh.py`                                                                                                                                                                           |
| Konsole (Dolphin „Terminal öffnen“; hearth: deckend, schlank, Balken-Cursor)                                                                                                         | ✅                                        | `python3 -I theme/gen/konsole.py` (Profil „Desktop“, Altstand in `~/.local/state/desktop/theme-backup-<datum>/konsole/`), `scripts/konsole-ui on`                                                                                                                                                |
| Starship-Prompt (Git, Dauer, Fehler, Uhr mit Sekunden; hearth-Farben, Kontrast ≥ 4,5 auf dem Terminal)                                                                               | ✅                                        | `theme/out/starship.toml` (`STARSHIP_CONFIG` in `~/.bashrc` zeigt auf den Hauptordner `~/Workspace/bastian-shell`; nach dem Merge gültig)                                                                                                                                                        |
| VS Code (nativ)                                                                                                                                                                      | ✅                                        | Theme „Desktop“ aktiv (`scripts/vscode-colors theme on/off`) · Projektfarben siehe unten · VS-Code-Terminal = Host-Shell                                                                                                                                                                         |
| Helium (RPM `helium-bin`, löst Chrome ab) · Chrome (RPM)                                                                                                                             | 🟡                                        | Farben: Helium `scripts/helium-colors on` (Grundfarbe, auch Menüs), Chrome Erweiterung „Desktop Theme“ · „Desktop“ (neue Tab-Seite, Tabs im Launcher, iCloud-Passwörter) · `scripts/chrome-ext install --browser helium`, dann einmal laden – siehe unten · Lesezeichen: `scripts/helium-import` |
| Thunderbird (RPM `thunderbird`, Profil `~/.thunderbird`; bis zum Umzug Flatpak ESR 153)                                                                                              | 🟡                                        | `python3 -I theme/gen/thunderbird.py apply` (an) · `remove` (weg) · `status` → Thunderbird neu starten → einmal Add-ons → Themes → „Desktop“ aktivieren. Details unten                                                                                                                           |
| Equibop (Discord-Client, RPM `equibop`)                                                                                                                                              | 🟡 gebaut, **noch nicht an**              | Theme „Desktop“ aus der Palette (`theme/gen/equibop.py`), 🧑 Equibop beenden → `scripts/equibop-theme install` · Details „Equibop“ unten. Das alte Discord (RPM/Flatpak) bleibt unthemed (Fallback)                                                                                              |
| Discord (normaler Client, RPM, mit eigenem Equicord)                                                                                                                                 | 🟡 Datei liegt, **per Klick einschalten** | Theme „Desktop (Discord)“ (`theme/gen/discord.py`), `scripts/discord-theme install` · Details „Discord (Equicord)“ unten                                                                                                                                                                         |
| Spotify (Flatpak `com.spotify.Client`, kein RPM)                                                                                                                                     | ⬜ bewusst nicht                          | Spicetify **nicht** empfohlen (siehe „Spotify“ unten) – Spotify bleibt im eigenen Look, die Shell-Kachel trägt den hearth-Look                                                                                                                                                                   |
| Dolphin                                                                                                                                                                              | ✅                                        | über KDE-Farbschema                                                                                                                                                                                                                                                                              |
| OnlyOffice / Betterbird / ArtCraft                                                                                                                                                   | ⬜                                        | erst wenn installiert (Roadmap Apps)                                                                                                                                                                                                                                                             |
| GoXLR Utility (Web-UI)                                                                                                                                                               | ⬜                                        | optional, eigenes CSS nicht vorgesehen                                                                                                                                                                                                                                                           |

## Qt/KDE (hearth, AP 6a)

Plattformtheme `QT_QPA_PLATFORMTHEME=kde` (plasma-integration, kommt aus der Hyprland-Umgebung), Widget-Stil **Breeze** (kein Kvantum installiert, nicht nötig:
Breeze + Farbschema reicht), Icons „Desktop-Icons“, Cursor „Desktop“, Schriften Inter 10 / JetBrains Mono Nerd Font 10 (`kdeglobals` `[General]`, schon gesetzt).
Alle Qt/KDE-Apps (Dolphin, Systemeinstellungen, Okular, Gwenview, Ark, Spectacle, KDE-Dateidialog über xdg-desktop-portal-kde, Konsole-Oberfläche) lesen nur `kdeglobals`.

- Neues Schema **„Desktop Hearth“** (`~/.local/share/color-schemes/DesktopHearth.colors`), erzeugt von `theme/gen/kde_colors.py` aus `palette.json` (Variante hearth):
  Fenster = `surface` (mittelbraun), Inhalt/Listen/Felder = `bg` (eine Stufe tiefer), Knöpfe/Kopfzeilen/Tooltips = `surfaceRaised`, Auswahl = Terrakotta
  (`accent`, so weit abgedunkelt, dass Creme darauf ≥ 5,6 : 1 hat), Links = `accentText`, Fokus = `accent`, Status = Moos/Bernstein/Rost.
  Kontrast (WCAG): Text/Fenster 11,4 · Text/Inhalt 13,5 · Gedämpft/Fenster 7,7 · Text/Knopf 9,8 · Text/Auswahl 5,7 · Link/Inhalt 7,9 · Fehler/Fenster 4,5.
- Andere Varianten (ember & Co.) erzeugen weiter das alte „Desktop“; das alte „Desktop“ wird von hearth **nicht** mehr überschrieben (`scripts/rice` und `scripts/loginscreen` nutzen es noch).
- Erzeugen + installieren: `python3 -I theme/gen/kde_colors.py` (nur `theme/out/kde/`: `--nur-out`) · setzen: `plasma-apply-colorscheme DesktopHearth` (schreibt `kdeglobals`, ohne kded6/plasmashell anzufassen; laufende Qt-Apps ziehen live nach, sonst neu starten).
- **Rückweg:** `plasma-apply-colorscheme Desktop` (altes Schema) oder Backup einspielen: `cp ~/.local/state/desktop/theme-backup-2026-10-18-qt/kdeglobals ~/.config/kdeglobals` (+ `kdedefaults`, `Trolltech.conf` im selben Ordner).
- Dolphin: Ordner-Icons (holzbraun `woodLight`) passen zum hearth-Ton, keine Anpassung nötig. Kate ist nicht installiert (nur `kate-libs`); Okular/Gwenview/Ark nutzen dasselbe Schema.
- Fensterrahmen: unter Hyprland ohne Titelleiste (`QT_WAYLAND_DISABLE_WINDOWDECORATION=1`), Rahmen/Ecken kommen von Hyprland (`look.conf`); Breeze-Ecken der Widgets bleiben Breeze-Standard.
- **Menüs mit Kvantum (vorbereitet, nicht an):** Breeze malt Menüs immer in der Fensterfarbe, mit ~5-px-Ecken und Terrakotta-Rahmen als Hover – das lässt sich
  per Farbschema nicht ändern. `python3 -I theme/gen/kvantum.py` erzeugt `theme/out/kvantum/DesktopHearth/` (Basis KvFlat aus Kvantum, GPL-3.0, umgefärbt):
  Menü/Tooltip `surfaceRaised`, Rand Creme-Hairline, Radius 10, Einträge innen mit Hover eine Stufe heller (`#574940`, Text 7,4 : 1), Trenner, Zeilen ~34 px wie das Shell-Menü;
  Knöpfe/Felder/Fortschritt mit 6-px-Ecken. Rest (Tabs, Häkchen, Fokusrahmen) bleibt KvFlat-Stil und ist etwas gröber als Breeze.
  An: 🧑 `sudo dnf install kvantum`, dann `scripts/kvantum-theme on` (kopiert nach `~/.config/Kvantum/`, setzt `kdeglobals` `[KDE] widgetStyle=kvantum`), Qt-Apps neu starten.
  **Rückweg:** `scripts/kvantum-theme off` (alter `widgetStyle` + alte `kvantum.kvconfig` aus `~/.local/state/desktop/kvantum-theme.json`).

## Kitty-Kürzel

Kitty-Kürzel nutzen nur **Strg+Shift** (Super = Fenster und Alt = Workspaces gehören Hyprland). Konfiguration: `config/kitty/kitty.conf` (von Hand), Farben `theme/out/kitty/theme.conf` (erzeugt von `theme/gen/kitty.py`, aus `bg`/`bgBottom`/`text`/`accent` der aktiven Variante; 16 ANSI-Farben warm, Kontrast ≥ 4,5:1 auf dem Terminal-Hintergrund, Schwarz nur als sichtbarer Block). Alle Kitty-Standardkürzel sind aus (`clear_all_shortcuts`).

| Kürzel                                  | Aktion                                                                        |
| --------------------------------------- | ----------------------------------------------------------------------------- |
| Strg+Shift+T                            | neuer Tab (gleicher Ordner)                                                   |
| Strg+Tab · Strg+Shift+Tab               | nächster · vorheriger Tab                                                     |
| Strg+Shift+1…9                          | Tab 1…9                                                                       |
| Strg+Shift+W                            | Tab schließen                                                                 |
| Strg+Shift+Enter                        | Split (Kitty wählt die Richtung)                                              |
| Strg+Shift+\ (auch `#`-Taste)           | senkrechter Trennstrich (nebeneinander)                                       |
| Strg+Shift+-                            | waagerechter Trennstrich (untereinander)                                      |
| Strg+Shift+←↑↓→                         | Fokus auf Nachbar-Split                                                       |
| Strg+Shift+Z                            | Zoom (Split vergrößern / zurück)                                              |
| Strg+Shift+Q                            | Split schließen                                                               |
| Strg+Shift+C · Strg+Shift+V             | Kopieren · Einfügen (Auswahl kopiert auch sofort, Shift+Einfg = Maus-Auswahl) |
| Strg+C                                  | kopiert bei Auswahl, sonst normal Abbruch                                     |
| Strg+Shift+F                            | Scrollback in `less` öffnen, dort `/` suchen, `n`/`N` weiter, `q` zurück      |
| Umschalt+Bild↑/↓ · Strg+Shift+Pos1/Ende | seitenweise scrollen · ganz oben/unten                                        |
| Strg+Shift+K                            | Bildschirm leeren                                                             |
| Strg+Plus · Strg+Minus · Strg+0         | Schrift größer · kleiner · zurück                                             |
| Strg+Shift+E                            | Link-Hints (Buchstaben über jedem Link, Buchstaben tippen = öffnen)           |
| Strg+Shift+P                            | aktuellen Ordner des Fensters in die Zwischenablage                           |
| Strg+Linksklick                         | Link unter der Maus öffnen                                                    |

Rückweg: `scripts/kitty-theme off` (entfernt die Symlinks, stellt gesicherten Altstand zurück).

## VS Code: Farbthema (hearth)

`theme/gen/vscode.py`: bei deckenden Varianten (`blur: false`) Ebenen wie in der Shell – Titel/Activity Bar/Statusleiste `surfaceRaised`,
Seitenleiste `surface`, Editor + Panel + Terminal `bg`, Menüs/Suche/Quick Open `surfaceRaised`, Eingaben `surfaceSunken`, Auswahl `accentFill`,
Knöpfe voller Terrakotta mit `onAccent`. Syntax-/ANSI-Farben aus `editorSyntax`/`ansi` werden auf dem helleren Grund automatisch bis zum
Mindestkontrast angehoben (`lift()`). Projekt-Tönung (`vscode_projects.py`) mischt auf demselben Rahmen. Nach Änderung: `python3 -I theme/gen/vscode.py`,
in VS Code „Developer: Reload Window“.

## GTK/libadwaita (hearth, AP 6b)

Generator `python3 -I theme/gen/gtk.py` (`--nur-out` = nur `theme/out/gtk/`, `--status`, `--rueckweg`; Variante als Argument). Eine Palette, zwei Dateien:

| Ziel                                                              | Wie                                                                                             | Was                                                                                                                                                                                                                                                                            |
| ----------------------------------------------------------------- | ----------------------------------------------------------------------------------------------- | ------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------ |
| GTK4 / libadwaita (Nautilus-Stil, zenity, Einstellungen, Dialoge) | `~/.config/gtk-4.0/gtk.css`                                                                     | `@define-color` + `:root`-Variablen nach libadwaita-Doku (`accent_bg_color` = Terrakotta, `window_bg_color` = surface, `view_bg_color` = surfaceSunken, Kopfzeile/Karte/Popover = surfaceRaised, `destructive_*`, `success/warning/error_*`), dazu weiche Ecken, ruhige Ränder |
| GTK3                                                              | `~/.config/gtk-3.0/gtk.css` + Theme **Breeze** (dunkel, wie unter Plasma)                       | alle 100 `*_breeze`-Farbnamen aus der Palette belegt (sonst kommt Breeze-Blau durch); Auswahl/Schalter/Fortschritt/Fokus = Terrakotta                                                                                                                                          |
| Einstellungen                                                     | `settings.ini` (3.0/4.0), gsettings                                                             | `color-scheme=prefer-dark`, `gtk-theme=Breeze` (nur GTK3), Cursor `Desktop`, Icons `Desktop-Icons`, Schrift `Inter 10`; KDE-GTK-Module (`gtk-modules=…`) raus                                                                                                                  |
| Flatpak                                                           | `flatpak override --user --filesystem=xdg-config/gtk-4.0:ro --filesystem=xdg-config/gtk-3.0:ro` | gleiche gtk.css in Flatpak-Apps (nur user-lokal)                                                                                                                                                                                                                               |

Menüs (GTK3 `menu`/Menüleiste, GTK4 `popover.menu`): `surfaceRaised`, Rand `borderStrong`, Radius 10, Hover `#574940` ohne Akzent-Rahmen (wie Qt/Kvantum und das Shell-Menü).

Kontrast (hearth): Text auf Fenster 11,4 · Akzent-Text 6,7 · Text auf Akzentfläche 4,9 · Text auf „Löschen“ 5,6 (alles ≥ 4,5). `GTK_THEME` wird nicht gesetzt. Von Hand angepasste `gtk.css` wird nie überschrieben (Abbruch). Die unbenutzten KDE-Dateien `colors.css`/`window_decorations.css`/`assets/` bleiben liegen.

**Rückweg:** `python3 -I theme/gen/gtk.py --rueckweg` spielt `~/.local/state/desktop/theme-backup-<datum>/rueckweg.sh` ab (gtk.css/settings.ini/Flatpak-Override/gsettings). Unter Plasma kann kde-gtk-config `gtk.css`/`settings.ini` beim Schemawechsel neu schreiben; dann Generator erneut laufen lassen. Laufende Apps nach Änderung neu starten (GTK lädt gtk.css nur beim Start).

## VS Code: Projektfarben

Jedes Projekt hat eine eigene Akzentfarbe: ein Name aus der Palette `projectAccents` (`palette.json`) oder eine
eigene als `#RRGGBB` (z. B. Logo-Farbe eines Kunden), auch „keine“. Gespeichert zentral in **`projects/projects.json`**
(`color` + gewünschte Tönung `tint`, Schema `projects/README.md`), geändert nur über **`scripts/project`**
(`set <projekt> color '#3A7BD5'`, `set <projekt> tint an|aus`) oder `/project` (Desktop); `scripts/vscode-colors`
schreibt dieselbe Datei. `theme/projects.json` wird bei jeder Änderung daraus **erzeugt** (flache Liste Pfad → Farbe)
und ist nur noch für ältere Leser da: Erweiterung „Desktop Projekte“, Claude-Zentrale (`ClaudeHub`), Antwort-Karte
(`ClaudeGate`), `/project` – nicht von Hand ändern.

- **Punkt + Projektname** links in der Statusleiste: Erweiterung „Desktop Projekte“, überall, ohne Datei im Projekt, ändert sich live.
- **Getönte Titel-/Statusleiste + Akzentlinien** (nur beim Theme „Desktop“), bei allen Projekten, ohne Spuren im Repo:
  - Zustand `an`: `.vscode/settings.json` nicht eingecheckt (neu angelegte stehen in `.git/info/exclude`, `git status` bleibt sauber)
    oder `*.code-workspace` außerhalb von Git.
  - Zustand `wrapper`: Repo mit **eingecheckter** `.vscode/settings.json` (z. B. Firmen-Repos) → zentraler Arbeitsbereich
    `~/.config/desktop/workspaces/<name>.code-workspace` mit dem Repo als einzigem Ordner + Tönung; das Repo bleibt unberührt.
    Die Shell öffnet solche Projekte automatisch darüber (`Projects.openTarget()`, Index `workspaces/index.json`):
    Launcher, Projekt-Desktops/Vorlagen, Claude-Zentrale. Von Hand: `code ~/.config/desktop/workspaces/<name>.code-workspace`.
    Fenstertitel dann „… - <name> (Workspace) - Visual Studio Code“ → Kontext/Claude-Zentrale ordnen ihn dem Projekt zu.
  - Präzedenz (geprüft im VS-Code-Bundle): in einem Arbeitsbereich – auch mit nur einem Ordner – liest VS Code aus der
    Ordner-`.vscode/settings.json` nur Datei-/Sprach-Einstellungen (Scopes resource, language-overridable, machine-overridable).
    window-Scope (`workbench.colorCustomizations`, `typescript.tsdk`, Erweiterungs-Settings ohne Scope wie `i18n-ally.*`)
    zählt dann nur aus der Arbeitsbereich-Datei. Deshalb **spiegelt** der Wrapper die Repo-Datei komplett unter `settings`
    (eigene `colorCustomizations` des Repos werden zusammengeführt) – es geht nichts verloren. Ändert sich die Repo-Datei:
    `scripts/vscode-colors refresh`. Eigene Schlüssel im Wrapper (z. B. über Einstellungen → Arbeitsbereich) bleiben erhalten.
  - Die Erweiterung „Desktop Projekte“ (ab 0.1.1) erkennt das Projekt im Wrapper über den Ordnerpfad.

| Befehl <name>                              | Was                                                                                                                      |
| ------------------------------------------ | ------------------------------------------------------------------------------------------------------------------------ |
| `scripts/vscode-colors`                    | Übersicht: Theme, Projekte, Farbe, Zustand                                                                               |
| `scripts/vscode-colors apply`              | neue Projekte erfassen + tönen                                                                                           |
| `scripts/vscode-colors set myproject moos` | Farbe ändern (`… farben` zeigt alle, `'#RRGGBB'` und `none` gehen auch; gleich: `scripts/project set myproject color …`) |
| `scripts/vscode-colors off [projekt]`      | Tönung weg (eigene Dateien + Exclude-Zeilen werden entfernt, Wrapper gelöscht)                                           |
| `scripts/vscode-colors refresh`            | Tönung neu (nach `rice variant`) + Wrapper neu spiegeln                                                                  |
| `scripts/vscode-colors theme off`          | Theme aus (VS-Code-Standard); Sicherungen: `~/.config/Code/User/settings.json.vor-desktop-*`                             |

Ganz weg: `scripts/vscode-colors off && scripts/vscode-colors theme off && code --uninstall-extension desktop.desktop-projects && code --uninstall-extension desktop.desktop-theme`.

## Helium / Chrome

Helium (Chromium-Fork, `/usr/bin/helium`, Profil `~/.config/net.imput.helium`, Fensterklasse `helium`) nimmt dieselben zwei Erweiterungen wie Chrome –
nichts Helium-Spezifisches im Theme nötig (geprüft: Theme + neue Tab-Seite + Native-Messaging-Host laufen). Zwei entpackte Erweiterungen aus `theme/gen/chrome.py` (ein reines Theme darf in Chrome keine Skripte/Seiten haben):

- **Desktop Theme** (`theme/out/chrome-desktop/`): hearth: Rahmen + inaktive Tabs mittelbraun (`bg`), aktiver Tab/Toolbar `surface`,
  Adressleiste `surfaceSunken`, Texte Creme/gedämpft, Inkognito Holz. Alte Glas-Varianten (ember …): Rahmen Fast-Schwarz. Keine Glut im Rahmen.
- **Desktop** (`theme/out/chrome-desktop-ext/`, Vorlagen ohne Farbwerte in `theme/gen/chrome-ext/`):
  - neue Tab-Seite: bei hearth (deckend) schlichter brauner Grund, Suche/Karten/Chips deckend ohne Blur/Glühen; bei Glas-Varianten
    auf dem Desktop-Wallpaper (Kopie des Mitte-Bilds, beim Generieren; `--wallpaper` erzwingt es auch bei hearth):
    große Uhr mit Sekunden, Datum, Suchfeld (Google; URL → direkt hin; `/` fokussiert),
    darunter pro Tab eins von: Wikipedia-Häppchen (Artikel des Tages, „Schon gewusst?“, „Was geschah am …“, mit Link),
    Tipp (KI-Nudge des Tages oder eingebettet: `theme/gen/chrome-ext/nudges.txt`) oder Spruch (`quotes.txt`). Klick = nächstes.
    Unten nächster Termin (heute/morgen, ≤ 60 min in Glut) + Wetter – beides nur, wenn die Shell Daten liefert.
  - Verbindung zur Shell über Native Messaging (`scripts/chrome-ext`, startet Chrome selbst): Tabs → `~/.cache/desktop/chrome-tabs.json`,
    Launcher findet Tabs (ohne Präfix bei klaren Treffern, mit `@` alle) und springt hin. Termine aus `agenda.json`,
    Wetter aus `chrome-shell.json` (schreibt `shell/services/ChromeTabs.qml`).
  - Futter: `scripts/newtab-feed` → `~/.cache/desktop/newtab-feed.json` (Wikipedia de, REST ohne Key; 8 Tipps per `claude -p`
    mit Sonnet, Hooks aus, keine Tools, keine Session). Der Host startet ihn bei offenem Chrome höchstens alle 3 h als
    User-Unit `desktop-newtab-feed`; neu geholt wird nur, was nicht von heute ist (KI-Versuch höchstens alle 6 h). Kein Timer nötig.
    Log: `journalctl --user -u desktop-newtab-feed` · sofort neu: `scripts/newtab-feed --force` · ohne KI: `--no-ai`.
  - **Passwörter (iCloud)**: Dropdown an Login-, 2FA- und E-Mail-Feldern (Registrierung → Hide My Email) + Popup über das
    Toolbar-Symbol (Logins der Seite: Benutzer/Passwort/Code kopieren, Ausfüllen). Quelle `scripts/passwords` (icp) über
    denselben Host. Vorlagen `chrome-ext/autofill.js|.css`, `popup.*`. Bedienung, Sicherheit, Fehler: [setup/passwords.md](setup/passwords.md).
  - feste Erweiterungs-ID über `key` im Manifest (`theme/gen/chrome-ext/key.pub`, nur öffentlicher Teil): `foiochcpalmokidmfefhmailobgpgbnb`.

Einrichten (einmal), Helium:

1. `scripts/chrome-ext install --browser helium` – baut beide Ordner, legt `~/.config/net.imput.helium/NativeMessagingHosts/de.bastian.desktop.json` an
   (`--browser chrome` für Chrome, `both` oder ohne Angabe = alle installierten; `status` / `remove` nehmen dasselbe `--browser`).
2. `helium://extensions` → rechts oben **Developer mode** an → **Load unpacked** → Ordner `<Repo>/theme/out/chrome-desktop-ext`
   (in Helium **ohne** `chrome-desktop` = „Desktop Theme“: Farben kommen aus `scripts/helium-colors`, siehe unten; Chrome nimmt beide) (`<Repo>` = der Ordner, aus dem `chrome-ext install` lief; er steht in der Ausgabe).
3. Helium fragt ggf. einmal „Diese Seite wurde von einer Erweiterung geändert“ → **Keep**. Neuer Tab = Desktop-Seite.
4. Bei „Desktop“ einmal ↻ (damit der Host startet). Prüfen: `scripts/chrome-ext status` (Tabs-Zahl, Host läuft, „Host: dieses Repo“).
5. Puzzle-Symbol → „Desktop“ anheften (Passwort-Popup). Schon offene Tabs einmal neu laden (Autofill steckt erst in neu geladenen Seiten).
   Ohne Klicks zum Ausprobieren: `helium --load-extension=<Repo>/theme/out/chrome-desktop,<Repo>/theme/out/chrome-desktop-ext` (nur für diesen Start).
   Chrome: gleicher Ablauf mit `--browser chrome` und `chrome://extensions`.
   Laufen beide Browser mit der Erweiterung, gewinnt der zuletzt gestartete Host (Tabs-Datei + Socket gibt es nur einmal).
   Zeigt ein Host-Manifest auf einen alten Checkout, meldet das Popup „Desktop host is outdated“ (Tabs/Tab-Seite laufen weiter).
   Umstellen: `scripts/chrome-ext install --browser chrome|helium` aus diesem Repo (macht auch `system/migrate`).

### Helium: Farben überall (`scripts/helium-colors`, Stand 2026-10-19)

Geprüft mit Wegwerf-Profilen (Helium 0.19.4.1 = Chromium 155): Eine **Theme-Erweiterung** färbt nur Rahmen, Tabs, Toolbar und Adressfeld – Menüs (⋮, Rechtsklick),
Vorschläge, Seitenleiste, Einstellungen und Knöpfe bleiben Heliums Grau (`#1A1C1C`) mit lila Knöpfen. **GTK-Modus** färbt Rahmen und Menüs aus `gtk.css`,
Vorschläge/Einstellungen bleiben grau. **Grundfarbe** (wie „Customize Helium“ → Farbe) färbt alles aus einem Farbsystem – das ist die Empfehlung:
`scripts/helium-colors on` (nur bei geschlossenem Helium) setzt in `Default/Preferences` `browser.theme.user_color2` = `accent`, `color_variant2` = 2 (neutral),
`color_scheme2` = 2 (dunkel), löscht `is_grayscale2`, `extensions.theme.id` = `user_color_theme_id` (ohne diese ID setzt Helium beim Start wieder Grau).
Ergebnis: Rahmen `#291D19` (≈ `bg`), Toolbar/aktiver Tab `#41332F` (≈ `surfaceRaised`), Vorschläge warmbraun, Menüs warmes Fast-Schwarz `#1E1B1A` mit Hover `#353231`,
Akzent Terrakotta. Exakte Palette-Töne in Menüs gehen in Chromium nicht (Material-Töne sind fest). Eine „Desktop Theme“-Erweiterung würde die Grundfarbe ersetzen → in Helium entfernen.
Sicherung: `Default/Preferences.vor-desktop-colors` + `~/.local/state/desktop/helium-colors.json`. **Rückweg:** `scripts/helium-colors off`. Per Klick ohne Skript:
⋮ → Customize Helium → Dark → Stift-Kachel → `#DB6B4C`. Vergleich zum Ausprobieren: `scripts/helium-theme-compare` (Erweiterung vs. GTK).

**Helium-Pfade (geprüft im Binary, helium-bin 0.19.4.1):** Profil + Native-Messaging-Hosts pro Benutzer `~/.config/net.imput.helium/`
(`NativeMessagingHosts/`), systemweit `/etc/chromium/native-messaging-hosts`. Policies liest Helium **nur systemweit** aus
`/etc/chromium/policies/managed|recommended` (wie Chromium, gilt also auch für ein installiertes Chromium) – kein Pfad unter `~/.config`.
Darum bleibt „Load unpacked“ ein Handgriff (Policies können nur gepackte CRX mit Update-URL zwangsinstallieren).
Optional, nur mit sudo und Rückfrage – Heliums eigenen Passwort-Manager abschalten (sonst zwei Dropdowns):
`sudo mkdir -p /etc/chromium/policies/managed && echo '{"PasswordManagerEnabled": false}' | sudo tee /etc/chromium/policies/managed/desktop.json`
(zurück: `sudo rm` der Datei; prüfen: `helium://policy`). Ohne sudo geht dasselbe per Klick, siehe setup/passwords.md.
Die Shell findet Helium-Fenster/Tabs wie Chrome-Fenster (Launcher `@`, Claude-Chats); Fensterregel (`hypr/rules.conf`): Helium startet rechts (DP-1).

### Vimium C: Helium per Tastatur (Stand 2026-10-19)

Vimium C legt Buchstaben auf jeden Link (`f`), scrollt mit `j`/`k`, wechselt Tabs mit `J`/`K`, `o` öffnet URL/Lesezeichen/Verlauf.
Alle Tasten: Super+K in Helium (Abschnitt „Vimium C“) oder `?` auf einer Webseite. Geht nicht auf `helium://`-Seiten, der neuen Tab-Seite
und im Web Store (Chromium sperrt Erweiterungen dort) – dort helfen Heliums eigene Kürzel (Strg+L, Strg+T …).

Erzeugt von `theme/gen/vimium.py` (läuft mit `theme/gen/all.py`), Ausgabe `theme/out/vimium/`:
`vimium-c-desktop.json` (Import: Theme + Tasten), `vimium-c.css` und `keymappings.txt` (dasselbe zum Einfügen per Hand).
Theme: Hinweis-Kappen deckend in `surfaceRaised` mit Glut-Rand, HUD und Suchleiste als Kachel, Vomnibar als Desktop-Panel. Tasten:
Vimium-Standard, die gängigen ausdrücklich gemappt (f/F, j/k, d/u, gg/G, H/L, J/K, o/O, b, T, /, n/N, x/X, yy, gi, i, ?).

Einrichten (einmal, Klicks macht Bastian):

1. Store-Seite in Helium öffnen: https://chromewebstore.google.com/detail/vimium-c-all-by-keyboard/hfjbmagddngcpeloejdejnfgbamkjaeg
   (ID `hfjbmagddngcpeloejdejnfgbamkjaeg`, geprüft im README von gdh1995/vimium-c) → **Add to Chrome** / Hinzufügen → bestätigen.
2. Puzzle-Symbol → Vimium C → ⋮ → **Options** (oder `helium://extensions` → Vimium C → Details → Extension options).
3. Ganz unten **Import settings** (Auswahl „Exported file“) → `<Repo>/theme/out/vimium/vimium-c-desktop.json` → Rückfrage bestätigen.
   Achtung: Der Import setzt alle _nicht_ in der Datei genannten Einstellungen auf Standard – auf einer frischen Installation egal.
4. Webseite neu laden, `f` drücken: Glut-umrandete Buchstaben = fertig. Neues Theme nach Palettenwechsel: Generator laufen lassen, Schritt 3 wiederholen.

Vorinstallieren ohne Klick? **Nein, nicht ohne sudo.** Helium liest Policies (`ExtensionInstallForcelist`) und „externe Erweiterungen“
(`<id>.json` mit `external_update_url`) nur systemweit aus `/etc/chromium/policies/managed/` bzw. `/usr/share/chromium/extensions/`
(Pfade aus dem Binary). Ein Versuch mit Wegwerf-Profil (headless, `--user-data-dir`) und `<Profil>/External Extensions/<id>.json`
installierte nichts (headless nicht ganz aussagekräftig, aber Chromium kennt den Benutzer-Pfad offiziell nur auf macOS). Mit sudo ginge (nicht ausgeführt): `sudo mkdir -p /etc/chromium/policies/managed && echo '{"ExtensionInstallForcelist":
["hfjbmagddngcpeloejdejnfgbamkjaeg"]}' | sudo tee /etc/chromium/policies/managed/vimium.json` – dann ist sie aber gesperrt (nicht entfernbar)
und gilt auch für ein installiertes Chromium; die Einstellungen (Import) bleiben trotzdem ein Klick. Empfehlung: einmal per Store-Seite installieren.

### Lesezeichen aus Chrome nach Helium

`scripts/helium-import` (Helium vorher schließen; `--dry-run` zeigt nur, `--html FILE` schreibt einen HTML-Export zum Importieren
über `helium://bookmarks` → ⋮ → Import). Liest Chromes `Default/Bookmarks` und `AccountBookmarks` (bei angemeldetem Konto liegen die Leisten-Lesezeichen dort), nur lesend.
Fügt in Heliums `Default/Bookmarks` ein: ohne Duplikate (Ordnerpfad + URL), Ordner werden zusammengeführt, Backup `Bookmarks.bak-<Datum>`,
`checksum`/`sync_metadata` weggelassen (Chromium rechnet neu), blendet die Lesezeichenleiste ein (`--no-bar` lässt sie). Mehrfach aufrufbar.
Passwörter/Verlauf/Cookies übernimmt das Skript nicht (Helium: `helium://settings/importData` → Chrome, Chrome vorher schließen).

### Chrome ablösen – erledigt (2026-10-18)

Erledigt: `google-chrome-stable` ist deinstalliert, Helium ist der Browser. Chrome-Reste (Web-App-Starter, Menü, Icons) aufgeräumt, Sicherung unter
`~/.local/state/desktop/chrome-reste-backup/`. Der GoXLR-Starter heißt jetzt `goxlr.desktop` (`helium --app=http://localhost:14564`, Fensterklasse
`chrome-localhost__-Default`). Das alte Profil `~/.config/google-chrome` (ca. 600 MB) bleibt als Archiv liegen, bis Bastian es löscht. Standardbrowser: `helium.desktop` (steht schon; sonst `xdg-settings set default-web-browser helium.desktop`). Projekt-Desktops und Vorlagen
(`shell/services/Templates.qml`, `profiles/profiles.json`) starten `helium` (Chromium-Flags `--new-window`, `--app=URL` gelten unverändert).

Footer unten auf der Tab-Seite („Desktop“ + „Customize Chrome“, nur Chrome – in Helium nicht vorhanden) weg – ohne sudo: `chrome://flags/#ntp-footer` → **Disabled** → Neustart.
Falls das Flag mal verschwindet: Policy (nur der Erweiterungs-Hinweis; Chrome zeigt dann „Von deiner Organisation verwaltet“):
`sudo mkdir -p /etc/opt/chrome/policies/managed && echo '{"NTPFooterExtensionAttributionEnabled": false}' | sudo tee /etc/opt/chrome/policies/managed/desktop-ntp.json` (zurück: `sudo rm` der Datei), prüfen in `chrome://policy`.

Nach Palette- oder Wallpaper-Wechsel: `python3 -I theme/gen/chrome.py` (läuft auch in `all.py`), dann in `helium://extensions` bzw. `chrome://extensions` bei beiden ↻.
Sprüche geändert: genauso. Weg: beide Erweiterungen entfernen + `scripts/chrome-ext remove --browser helium|chrome`; Theme allein: `chrome://settings/appearance` → „Zurücksetzen“.

## Equibop (Discord im PC-Look, erkennbar als Discord)

Ziel (Bastian): lowkey im Look vom PC, aber man findet sich sofort zurecht. Darum überschreibt das Theme **nur Farb-Variablen und die Schrift**:
Layout, Server-Leiste, Icons, Emojis, Rollenfarben, Avatare und die Statusfarben (grün/gelb/rot) bleiben Discord.

- Erzeugt: `python3 -I theme/gen/equibop.py [variante]` → `theme/out/equibop/desktop.theme.css` (auch ohne Installation; bricht mit Fehler ab, wenn ein Kontrast < 4,5 : 1 wäre).
- Flächen aus hearth: Server-Leiste `bgBottom`, Kanalliste `bg`, Seitenfelder `surfaceSunken`, Chat `surface`, Eingabefeld/Karten/Popouts `surfaceRaised`.
  Text Creme (`text`), Zweittext `textMuted`, Hinweise `textFaint`; Hover/Auswahl = Creme mit wenig Alpha; Ränder = Palette-`border`.
- **Marken-Akzent bleibt Discord-Blurple, gedämpft** (Sättigung 34 %, etwas dunkler als #5865F2) für Buttons, Links, Erwähnungen, Auswahl, Fokus – kein Terrakotta, damit es nach Discord aussieht.
- Schrift: Inter für den Fließtext (`--font-primary`, gg sans bleibt Rückfall; Überschriften/Code unverändert). Nicht gewollt: `python3 -I theme/gen/equibop.py --ohne-schrift`.
- Variablen geprüft gegen Discords aktuelle Web-App (Block `.theme-dark`, Stand 2026-10-18). Selektor `.theme-dark.theme-dark, .theme-darker…, .theme-midnight…` (doppelt = gewinnt immer). Das helle Discord-Theme bleibt unberührt (Einstellungen → Aussehen: Dunkel).
  Discord benennt Variablen manchmal um – dann sieht eine Fläche wieder grau-blau aus: Variable in der Entwicklerkonsole (Strg+Umschalt+I) suchen und im Generator ergänzen.
- Installation: `scripts/equibop-theme install|off|status` (kopiert nach `~/.config/equibop/themes/desktop.theme.css`, trägt `desktop.theme.css` in `enabledThemes` ein, Sicherung nach `~/.local/state/desktop/theme-backup-<Datum>/equibop/`).
  Fasst nichts an, solange Equibop läuft (es überschreibt seine Einstellungen beim Beenden). Rückweg: `scripts/equibop-theme off`; per Klick: Einstellungen → Equicord → Themes.
- Nach Palette-Wechsel: `python3 -I theme/gen/equibop.py && scripts/equibop-theme install` (Equibop beendet) – Equicord lädt Theme-Dateien beim Ändern neu.
- Geprüft ohne laufendes Equibop: Attrappe mit denselben Variablen (Kontraste, Blurple, Inter); am echten Client noch nicht gesehen – bitte nach dem ersten Start einmal durchklicken (DMs, Server, Einstellungen, Sprachkanal, Emoji-Auswahl).

## Discord (Equicord)

Bastian nutzt jetzt den normalen Discord-Client (RPM) mit eigenem Equicord-Build statt Equibop. Equicord legt dort alles unter `~/.config/Equicord/` ab.
Ziel: Farben wie die Shell, aber zwischen den anderen Fenstern sofort als Discord erkennbar.

- Erzeugt: `python3 -I theme/gen/discord.py [variante]` → `theme/out/discord/desktop-discord.theme.css` (bricht ab, wenn ein Kontrast < 4,5 : 1 wäre oder Klammern nicht aufgehen). Läuft mit `theme/gen/all.py`; liegt das Theme schon in `~/.config/Equicord/themes/`, wird die Datei dort gleich mit erneuert (auch bei `scripts/rice variant`).
- **Flächen und Text = Shell-Palette** (hearth): Server-Leiste `bgBottom`, Kanalliste `bg`, Seitenfelder `surfaceSunken`, Chat `surface`, Eingabe/Karten/Popouts `surfaceRaised`, Text Creme/`textMuted`/`textFaint`. Ecken aus der Palette (`radius` xs–lg), Schrift Inter, Code JetBrains Mono Nerd Font.
- **Erkennungszeichen = Discord-Blurple, gut sichtbar** (`#545ED4`, nur leicht ruhiger als `#5865F2`): Home-Knopf, aktiver Server-Strich, ausgewählter Kanal/DM, Buttons, Schalter, Links, @-Erwähnungen.
- **Ember nur sparsam:** Nachrichten, in denen Bastian erwähnt wird (Tönung + Randstrich), Zähler ungelesener Erwähnungen, Ungelesen-Punkt in der Server-Leiste.
- Überschreibt die neuen Variablen (`--background-base-*`, `--background-surface-*`, `--text-*`, `--icon-*`, `--interactive-*`, `--control-*` …) und Discords Grund-Töne (`--opacity-N-hsl`, `--opacity-blurple-N-hsl`, `--blurple-N-hsl`), damit nichts blaugrau bleibt. Geprüft gegen den Block `.theme-dark` aus Discord 1.0.162 (2026-10-18). Status grün/gelb/rot, Rollenfarben, Layout bleiben Discord.
- Installation: `scripts/discord-theme install|off|status`. Läuft Discord (`pgrep -x Discord`), wird nur die Datei kopiert und die Einstellung nicht angefasst – dann 🧑 **Discord → Einstellungen → Equicord → Themes → „Desktop (Discord)“ einschalten** (Aussehen: Dunkel). Ist Discord zu, trägt `install` den Namen in `enabledThemes` ein (fehlt `settings.json`, wird eine minimale angelegt); Sicherung vorher nach `~/.local/state/desktop/theme-backup-<Datum>/equicord/`.
- Zwei Regeln hängen an Discord-Klassennamen (Server-Strich, Erwähnungs-Rand). Benennt Discord sie um, fällt nur dieser Teil auf Discords Weiß/Gelb zurück. Am echten Client noch nicht gesehen – bitte einmal durchklicken (Server, DMs, Einstellungen, Sprachkanal, Emoji-Auswahl).

## Spotify (Bewertung, nichts installiert)

Stand: Spotify läuft als **Flatpak** (`com.spotify.Client` 1.2.95, system-weit), kein RPM, Spicetify nicht installiert.

- **Spicetify** patcht `xpui.spa` im App-Ordner. Der liegt beim Flatpak unter `/var/lib/flatpak/app/com.spotify.Client/…/<Commit>/files/extra/…` (root, **Pfad ändert sich bei jedem Flatpak-Update**),
  also bräuchte es `sudo`/Schreibrechte und nach jedem Spotify- oder Flatpak-Update ein erneutes `spicetify backup apply`. Spotify-Updates brechen Spicetify regelmäßig (Theme-Selektoren, Patches).
- **Empfehlung: nicht einrichten.** Aufwand und Bruchrisiko stehen gegen ein bisschen Farbe; Spotify bleibt Spotify (grüner Akzent = Wiedererkennung, wie Discord-Blurple).
  Die Bedienung läuft ohnehin über die Shell (Kachel/Chip mit hearth-Look, Steuerung per MPRIS), das Spotify-Fenster wird kaum angesehen.
- Falls später doch: erst Spotify als RPM (`lpf-spotify-client`, schreibbarer Pfad `/usr/share/spotify`), dann Spicetify mit eigenem, aus der Palette erzeugtem `color.ini` (`theme/gen/spotify.py`) – nur nach Bastians Wort.
- Zwischenweg ohne Eingriff in die App: Spotify im Web-Player (Helium) mit Stylus-artigem CSS – nicht umgesetzt.

## Lockscreen und Login (hearth)

Eine Farbquelle: `theme/gen/lockscreen_theme.py` erzeugt `plasma/shells/de.bastian.desktop/contents/lockscreen/DesktopTheme.qml` aus der Palette (jetzt **hearth**: deckende Felder `glassStrong` = `surfaceRaised`, Creme-Uhr, Terrakotta nur für Fokus/aktiv).
Dieselbe Datei nutzt der Login-Bildschirm (`scripts/loginscreen` kopiert sie in sein Layout-Theme). Die Hyprland-Sperre der Shell (`shell/modules/lock`) liest `Theme` live und ist schon hearth. Hintergrund bleibt das Wallpaper.

- Generator-Fix: `onAccent` (QML hält „on…“ für einen Signal-Handler → Lockscreen und Login hätten nicht geladen) heißt dort `textOnAccent`; Bool-Tokens (`blur`) werden als `bool` ausgegeben.
- Paket: `scripts/shellpkg install` (erzeugt neu, kopiert nach `~/.local/share/plasma/shells`, schaltet nichts um). Offscreen geprüft: `kscreenlocker_greet --testing --shell de.bastian.desktop -platform offscreen` lädt ohne QML-Fehler.
- Login: Bilder ohne root mit `scripts/loginscreen shot` (→ `~/.cache/desktop/loginscreen-shot/`, echter Greeter offscreen). Installation (sudo): `scripts/loginscreen install` (sichert zuerst, Selbsttest), danach `scripts/loginscreen on`
  (der Login-Look ist derzeit **ausgeschaltet**: Datei `off`, siehe `docs/setup/loginscreen.md`). Das Farbschema „Desktop“ für den Greeter kopiert `install` aus `~/.local/share/color-schemes/Desktop.colors` (neu erzeugen: `python3 -I theme/gen/kde_colors.py`).

## Thunderbird

Zwei Teile, beide aus `palette.json` (`theme/gen/thunderbird.py`, Vorlagen ohne Farbwerte in `theme/gen/thunderbird-css/`):

- **Theme „Desktop“ (XPI)**: Rahmen, Tab-Leiste, Toolbar, Suchfeld, Menüs, Seitenleiste – alle Farbschlüssel aus Thunderbirds `theme.json`.
  hearth: Rahmen/Fugen = `bg` (mittelbraun) statt Fast-Schwarz.
- **userChrome.css / userContent.css** im Profil `chrome/` (Pref `toolkit.legacyUserProfileCustomizations.stylesheets` per markiertem Block in `user.js`):
  - Mail: Ordnerliste, Nachrichtenliste und Lesebereich als Kacheln mit 8-px-Fuge auf dunklem Rahmen, runde Ecken.
    Gelesen = gedämpft, ungelesen = Creme + fett + Glutpunkt, Auswahl = leiser Glutgrund + Glutlinie links. Ordner-Icons holzbraun.
  - Tabs: aktiver Tab als Surface-Kachel mit Glutlinie, inaktive leise.
  - Kalender: Seitenleiste + Ansicht als Kacheln; Heute = Glut-Pille (Monat), Glut-Kopf (Tag/Woche), Jetzt-Linie in Glut;
    Termine gedämpft auf Dunkel mit Kalenderfarbe als Kante links; Wochenende/fremder Monat leicht abgesetzt; Minimonat mit Glutring für Heute.
  - Adressbuch: Bücher · Kontakte · Details als Kacheln wie Mail, Auswahl Glut statt Blau.
  - Dialoge, Einstellungen, Add-ons, Menüs, Tooltips, Warnleisten (Amber statt Neon-Gelb), XUL-Tabellen: über Thunderbirds
    eigene Variablen (Graustufen → warme Rampe, Standard-Blau/Cyan → Glut, Ink-Grau → Holz).
  - Wichtig: Adressbuch, Einstellungen, Add-ons, Kontoeinstellungen laufen in Inhalts-Browsern → dafür steckt dieselbe
    Basis (`thunderbird-css/base.css`) auch in `userContent.css` (nur für diese about:-/chrome:-Seiten).
  - Schrift Inter (UI), JetBrains Mono (Code, reine Textmails). Mailtext: Zitate Holz/Creme/Moos/Amber, Links Glut, Signatur leiser.
    HTML-Mails behalten ihr Layout (Thunderbirds Dunkel-Lesemodus dunkelt ab).

Geprüft gegen die Selektoren/Variablen in `omni.ja` von 153.5 ESR. Nach Thunderbird-Updates ggf. `status` + Sichtprüfung
(nach dem Umstieg aufs RPM, Release 157+, einmal komplett durchsehen).
Profil: der Generator nimmt den ersten Ordner mit `profiles.ini` – `~/.thunderbird` (RPM), `~/.config/mozilla/thunderbird`,
sonst das alte Flatpak-Profil `~/.var/app/org.mozilla.thunderbird_esr/.thunderbird`. Umzug: `scripts/flatpak-to-native migrate thunderbird`.
`remove` lässt die Pref in `prefs.js` auf `true` (wirkungslos ohne `chrome/`-Dateien; ganz zurück: about:config → Zurücksetzen).

## Bedienung & Verhalten (eingestellt)

| Was                                                                                                                                          | Stand                                                                                                                                                                                                                                                   |
| -------------------------------------------------------------------------------------------------------------------------------------------- | ------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------- |
| Kürzel (nur eigene + Not-Aus, Sperren, Hardware, Super+R)                                                                                    | ✅ `docs/HOTKEYS.md`                                                                                                                                                                                                                                    |
| Fenster: Super+↑/↓/←/→, Shift = Monitor/Vollbild                                                                                             | ✅ KWin-Script `desktop-tiling`                                                                                                                                                                                                                         |
| Bar/Workbar an der Kante hervorholen (auch Vollbild)                                                                                         | ✅ KWin-Script `desktop-edges` (Mausposition) – bitte testen                                                                                                                                                                                            |
| Key Light aus + GoXLR-Profil speichern beim Herunterfahren                                                                                   | ✅ `desktop-keylight-off.service`                                                                                                                                                                                                                       |
| Mail-Push + Codes kopieren                                                                                                                   | ✅ `desktop-mail-watch`                                                                                                                                                                                                                                 |
| Kamera: Auto-Belichtung, Helligkeit per Fader, 50 Hz                                                                                         | ✅ Licht & Ton                                                                                                                                                                                                                                          |
| Textdateien (txt, md, json, yaml, Skripte, Logs …) öffnen in **VS Code, eigenes schlichtes Fenster** (`--new-window`) statt Wordcraft/KWrite | ✅ `config/applications/code-simple.desktop` → `~/.local/share/applications/`, Standard per `xdg-mime default code-simple.desktop <typ>`; Backup `~/.local/state/desktop/mimeapps.list.bak-*` (Rückweg: Backup nach `~/.config/mimeapps.list` kopieren) |

### Ordnerfarbe – warum eigenes Icon-Theme

Breeze färbt die bunten Ordner (32/48/64/96 px) über die SVG-Klasse `ColorScheme-Accent` mit dem Akzent des Farbschemas –
bei uns Glutrot. Akzent ändern hieße: ganze UI ändern. Darum `theme/gen/icons.py`: spiegelt Breeze Dark per Symlinks
(nötig, weil KIconLoader pro Theme auch gekürzte Namen sucht – ein schlankes Theme mit nur `folder` würde `folder-new`,
`folder-red` … überdecken) und ersetzt nur die Ordner-SVGs durch Kopien mit fester Farbe: Vorderseite `woodLight`,
Rückseite = Breezes 33-%-Schatten (≈ `wood`), Symbol Creme. Kleine Ordner (16/22 px, Seitenleiste) und `*-symbolic`
sind in Breeze einfarbig Creme und bleiben. Ordnername `Desktop-Icons`, weil `icons/Desktop` das Cursor-Theme ist.
Ausgabe `theme/out/icons/` ist gitignored. Neue Variante: Generator neu laufen lassen (Plasma merkt es sofort).

## Nächste Schritte (Vorschlag, Reihenfolge)

1. Login-Bildschirm (5 min, Bastian klickt)
2. Thunderbird-Theme aktivieren (1 Klick) · Chrome: beide Erweiterungen laden (siehe Chrome)
3. Ordnerfarbe: in Dolphin anschauen, dann in `rice theme on/off` einbinden
4. GTK-Apps prüfen (welche gibt es überhaupt?)
5. Optional: Discord/Spotify-Theming – nur wenn gewünscht

## zsh

Konfiguration `config/zsh/zshrc` (Symlink `~/.zshrc`), Farben `theme/out/zsh/colors.zsh` (erzeugt von `theme/gen/zsh.py`). Prompt bleibt Starship. Rückweg: `scripts/zsh-setup off`.

| Eingabe                                  | Wirkung                                                                                                                                                                                                                     |
| ---------------------------------------- | --------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------- |
| Tab                                      | Fuzzy-Liste mit Vorschau (Ordner als Baum, Dateien mit Farben); `<` `>` wechselt die Gruppe                                                                                                                                 |
| → oder Strg+Leertaste                    | grauen Vorschlag übernehmen                                                                                                                                                                                                 |
| ↑ / ↓                                    | Verlauf, passend zum schon Getippten                                                                                                                                                                                        |
| Strg+R                                   | Verlauf fuzzy durchsuchen                                                                                                                                                                                                   |
| Strg+T                                   | Datei suchen und einfügen                                                                                                                                                                                                   |
| Alt+C                                    | in Ordner springen (Suche)                                                                                                                                                                                                  |
| Esc Esc                                  | `sudo` vor die Zeile (leer: vor den letzten Befehl)                                                                                                                                                                         |
| Strg+Z (leere Zeile)                     | angehaltenes Programm wieder nach vorn                                                                                                                                                                                      |
| Strg+X Strg+E                            | Zeile im Editor bearbeiten                                                                                                                                                                                                  |
| `z teil` / `zi`                          | in einen oft genutzten Ordner springen / auswählen                                                                                                                                                                          |
| Ordnername tippen                        | `cd` dorthin; `cd -`+Tab = letzte Ordner                                                                                                                                                                                    |
| `ls` `ll` `la` `lt`                      | eza: Icons, Git-Status, relative Zeit, Baum                                                                                                                                                                                 |
| `cat` · `catp`                           | bat: Rahmen, Zeilennummern, Dateiname + Größe, Git-Änderungen am Rand, Farbschema „desktop“ (`theme/gen/bat.py`) · `catp` ohne Rahmen · `man` ebenfalls farbig                                                              |
| `mkcd ordner` · `x datei.zip` · `please` | anlegen + rein · beliebiges Archiv entpacken · letzten Befehl mit sudo                                                                                                                                                      |
| `cpwd`                                   | aktuellen Ordner kopieren (in Kitty auch Strg+Shift+P)                                                                                                                                                                      |
| `y`                                      | yazi: Dateimanager mit Vorschau, beim Schließen landest du im Ordner (Farben `theme/gen/yazi.py`)                                                                                                                           |
| `lg`                                     | lazygit: Git zum Durchklicken – stagen, committen, Branches, Diffs mit delta (Farben `theme/gen/lazygit.py`)                                                                                                                |
| `git diff` / `git log -p` / `git show`   | delta: Syntax-Farben, Zeilennummern, n/N = nächste/vorige Datei (`theme/gen/delta.py`, per `include.path` in `~/.gitconfig`)                                                                                                |
| `tldr befehl`                            | kurze Beispiele statt man-Seite                                                                                                                                                                                             |
| `dust` · `duf`                           | was frisst Platz · wie voll sind die Platten                                                                                                                                                                                |
| _von selbst_                             | **Fertig-Ping**: Befehl läuft > 30 s und Kitty ist nicht vorn → Benachrichtigung (fertig / fehlgeschlagen + Dauer; nicht bei Editoren, ssh, yazi, lazygit …) · **Paket-Tipp**: unbekannter Befehl → bietet das dnf-Paket an |

## sshs

Server aus dem Terminal, ruhig im Termius-Stil: `scripts/sshs` (Symlink `~/.local/bin/sshs`), eingerichtet mit `sshs install` (Rückweg `sshs off`).

| Eingabe                                                                      | Wirkung                                                                                                                                                                                                                                                                                                                                  |
| ---------------------------------------------------------------------------- | ---------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------- |
| `sshs`                                                                       | Liste aller Server · Enter verbindet · Strg+N neuer Server · Strg+E Liste bearbeiten                                                                                                                                                                                                                                                     |
| `sshs name` · `sshs add` · `sshs edit [name]` · `sshs rm name` · `sshs list` | direkt verbinden · anlegen (Name, Adresse, Benutzer, Port, Schlüssel wählen oder neu erzeugen, optional `ssh-copy-id`) · bearbeiten (Formular, Enter behält den Wert; danach prüft sshs, ob der Server den Schlüssel annimmt, und bietet `ssh-copy-id` an; in der Liste Strg+D löschen, Strg+O Datei öffnen) · entfernen · auflisten     |
| `sshs name --su [--files \| --run befehl]`                                   | verbinden, nach der Anmeldung tippt sshs `su` (Passwort gibst du ein), danach Dateien bzw. der Befehl                                                                                                                                                                                                                                    |
| `sshs ps name`                                                               | Container auf dem Server (docker/podman, als Anmelde-Benutzer), nach Projekt gruppiert, mit Ports; `--json` für die Bar                                                                                                                                                                                                                  |
| Strg+Leertaste (im Server-Fenster)                                           | Terminal ↔ Dateien (yazi per SFTP); der Ordner wandert in beide Richtungen mit. Nach `su` (z. B. root): yazi läuft direkt in der su-Shell auf dem Server, Strg+Leertaste startet bzw. beendet es, der Ordner wandert genauso                                                                                                             |
| Strg+Shift+T (im Server-Fenster)                                             | neuer Tab zum selben Server, im aktuellen Ordner                                                                                                                                                                                                                                                                                         |
| Strg+Shift+U (im Server-Fenster) · `sshs up [name] [ordner]`                 | hochladen: lokale Dateien/Ordner per fzf wählen (Tab = mehrere, Vorschau), `scp -r` in den gerade offenen Server-Ordner (Terminal oder Dateien); ohne Fenster Ziel-Server per fzf, Standard-Ordner `~`                                                                                                                                   |
| Strg+Shift+D (im Server-Fenster) · `sshs down [name] [ordner]`               | herunterladen: Dateien/Ordner im gerade offenen Server-Ordner per fzf wählen (bis 4 Ebenen tief, Tab = mehrere, Vorschau), `scp -r` nach `~/Downloads`; eine geteilte Verbindung für Liste, Vorschau und Kopieren                                                                                                                        |
| Strg+Shift+U / D nach `su`                                                   | als root: Upload landet erst in `~/.local/share/sshs/in` des Anmelde-Benutzers, die su-Shell verschiebt es danach in den offenen Ordner (gehört dann root, nichts wird überschrieben). Download: Auswahl in yazi (Leertaste markiert, Enter übernimmt), die su-Shell kopiert nach `…/out`, sshs holt es nach `~/Downloads` und räumt auf |

- Ein Server = ein Kitty-Fenster (Klasse `sshs`, `config/sshs/kitty.conf`: Tabs immer sichtbar, Stack-Layout). Pro Tab zwei Fenster übereinander: `kitten ssh` (Shell-Integration, Kitty kennt den Server-Ordner) und yazi (`sftp://<server>`, erst beim ersten Umschalten). Logik: `config/sshs/sshs_kitten.py`; yazi meldet seinen Ordner über `config/yazi/init.lua`.
- Auf dem Server: Jede Verbindung (`sshs _ssh`, auch neue Tabs) kopiert `config/sshs/remote` und ein statisches eza (`~/.cache/sshs/eza`, lädt `sshs` beim ersten Mal von GitHub) nach `~/.local/share/sshs` und startet die Bash darüber (`login_shell`): normale Startdateien, dann Kittys Shell-Integration, dann `ls`/`ll`/`la`/`lt` mit eza. Sonst bleibt der Server unverändert; läuft eza dort nicht, bleibt das normale `ls`.
- `su` auf dem Server: Die sshs-Bash ersetzt das schlichte `su [-] [benutzer]` durch eins, das die neue Shell wieder über `~/.local/share/sshs/bashrc` startet – Kitty kennt dann weiter Ordner und Prompt. Die Shell meldet den Benutzer als Kitty-User-Variable (`sshs_su`), so weiß Strg+Leertaste, dass SFTP (nur Anmelde-Benutzer) nicht reicht. `su` mit eigenen Optionen (`-c`, `-s` …) bleibt das normale. Root-Login per SSH braucht es dafür nicht.
- yazi auf dem Server: Nach jedem Verbinden prüft `sshs _setup` im Hintergrund (BatchMode, wartet bis der Schlüssel im Agenten liegt) und kopiert einmalig ein statisches yazi (`~/.cache/sshs/yazi-<version>`, von GitHub, ~24 MB) nach `~/.local/share/sshs/bin`. Fehlt es noch, sagt die su-Shell das beim Umschalten.
- Server stehen in `~/.ssh/config.d/sshs.conf` (lokal, nicht im Repo; `Include` ganz oben in `~/.ssh/config`). Host-Einträge direkt in `~/.ssh/config` erscheinen auch (ohne Muster und Git-Dienste). yazi-Einträge (`~/.config/yazi/vfs.toml`) schreibt `sshs` bei jedem Start neu.
- Anmeldung der Dateiansicht über den SSH-Agenten (`ssh-agent.socket`, `SSH_AUTH_SOCK` in der zshrc; `AddKeysToAgent yes`): Die Terminal-Verbindung legt den Schlüssel dort ab. Passwörter speichert sshs nie.
