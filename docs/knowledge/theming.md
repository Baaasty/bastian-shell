# Theming – alles im desktop-Look

## Grundprinzip

- **Eine Farbquelle:** `theme/palette.json`, aktive Variante `defaultTheme` (heute **hearth**: deckend, kein Blur,
  kein Glühen). Weitere Varianten: ember (alte Glas-Variante, mit Blur, Rückweg), walnut, candlelight, dusk, clay, linen.
- **Generatoren** `theme/gen/*.py` lesen die Palette und schreiben `theme/out/` (liegt im Repo) und installieren nach
  `~/.local`/`~/.config`. Aktiviert wird nichts automatisch. Alles auf einmal: `python3 -I theme/gen/all.py [variante]`;
  Optionen, Zielpfade und Einzelaufrufe: [theme/README.md](../../theme/README.md).
- **Umschalten:** `scripts/rice variant <name>` setzt `defaultTheme`, erzeugt alles neu und wendet an, was schon aktiv ist.
  Die Shell liest `palette.json` live (`Theme.qml`), braucht also keinen Generator.
- **Blur** hängt am Palette-Schalter `blur`: `hypr/look.conf` wird mit `decoration.blur.enabled` daraus erzeugt.
  `BackgroundEffect.blurRegion` steht weiter in vielen Modulen, bleibt in hearth aber wirkungslos.
- **Jede App behält ihren Kontrast:** Editor (`editorSyntax`) ≠ Terminal (`ansi`) ≠ Shell-Flächen. Die Generatoren
  heben Farben bis Kontrast ≥ 4,5 : 1 an oder brechen ab, wenn er nicht erreicht wird.
- **Wiedererkennung vor Einheitslook:** Discord behält Blurple, Spotify bleibt Spotify; Status- und Rollenfarben fremder Apps
  bleiben unangetastet. Nur neue Schemata/Profile anlegen, nie fremde überschreiben; jeder Schalter hat ein `off`.
- **Ein Raster in der Shell:** Schrift-, Abstands-, Radius- und Bedienelement-Größen kommen wie die Farben aus
  `palette.json` (`shell/config/Theme.qml`), Tasten, Knöpfe und Hinweiszeilen nur über die gemeinsamen Bausteine in
  `shell/components/` – sonst lebt die Oberfläche wieder auseinander.

## Welche App wie angebunden ist

| App | Generator → Ziel · Schalter |
| --- | --- |
| Shell (Bar, Dashboard, Launcher, OSD, Popups) | liest `palette.json` live |
| Hyprland-Rahmen, Schatten, Blur | `hypr.py` → `hypr/look.conf` (erzeugt, nie von Hand) |
| Hyprland-Dialoge (App reagiert nicht) | `hyprtoolkit.py` → `~/.config/hypr/hyprtoolkit.conf` (auch per `scripts/hypr install`) |
| Bildschirm-teilen-Auswahl | `share_picker.py` → Stylesheet für hyprland-preview-share-picker |
| Qt/KDE-Apps, KDE-Dateidialog | `kde_colors.py` → Schema „Desktop Hearth“, setzen `plasma-apply-colorscheme DesktopHearth`; Widget-Stil Breeze |
| Qt-Widget-Stil (Menüs mit Radien, ruhiger Hover) | `kvantum.py` → Kvantum „DesktopHearth“, **an** seit 2026-10-20: `scripts/kvantum-theme on\|off\|status` |
| KWrite/Kate-Textfläche (KTextEditor) | `ktexteditor.py` → Theme „Desktop“ (`~/.local/share/org.kde.syntax-highlighting/themes/desktop.theme`), `ktexteditor.py --an\|--aus` |
| GTK3/GTK4/libadwaita, auch Flatpaks | `gtk.py` → `gtk.css` + `settings.ini`, Flatpak-Override (Lesen der gtk-Ordner); zurück `--rueckweg` |
| Ordner- und Ort-Icons (holzbraun) | `icons.py` → Icon-Theme `Desktop-Icons` (an: `/usr/libexec/plasma-changeicons Desktop-Icons`) |
| Cursor „Desktop“ | `design/cursors/build-xcursor.sh` (läuft mit `all.py`) |
| Wallpaper | `wallpaper.py` (nicht in `all.py`) → `scripts/wallpaper set` |
| Kitty (Standard-Terminal) | `kitty.py` → `theme/out/kitty/theme.conf`, `scripts/kitty-theme install\|off` |
| Konsole | `konsole.py` → Profil „Desktop“, `scripts/konsole-ui on` |
| Prompt, zsh, Begrüßung | `starship.py`, `zsh.py`, `fastfetch.py`; `scripts/zsh-setup install\|off` |
| bat, delta, yazi, lazygit | `bat.py`, `delta.py`, `yazi.py`, `lazygit.py` (Farbschema „desktop“) |
| VS Code | `vscode.py` → Theme „Desktop“, `vscode_projects.py` → Projekt-Tönung; `scripts/vscode-colors` |
| Helium (Browser) | `scripts/helium-colors on\|off` (Grundfarbe); neue Tab-Seite + Tabs/Passwörter: `chrome.py` → `scripts/chrome-ext install --browser helium` |
| Vimium C (Helium per Tastatur) | `vimium.py` → `theme/out/vimium/vimium-c-desktop.json`, einmal in Vimium C importieren |
| Thunderbird | `thunderbird.py apply\|remove\|status` → Theme-XPI + `userChrome.css`/`userContent.css`, einmal Theme aktivieren |
| Discord (RPM + Equicord) | `discord.py` → `scripts/discord-theme install\|off\|status`, ggf. einmal in Equicord → Themes einschalten |
| Equibop (alt) | `equibop.py` → `scripts/equibop-theme` (bleibt nur für den alten Client) |
| Login-Bildschirm | `lockscreen_theme.py` → `plasma/loginscreen/DesktopTheme.qml`, `scripts/loginscreen apply` ([setup/loginscreen.md](../setup/loginscreen.md)) |
| Sperre unter Hyprland | liest `Theme` live; Notfall-hyprlock bekommt Palette-Farben aus `scripts/lock` |
| Spotify | bewusst nicht (siehe Stolperfallen) |

`all.py --alles` erzeugt zusätzlich `design/palette.js`, Lockscreen- und Fensterwechsler-Theme.
Projektfarben (Farbe + Tönung je Projekt) stehen in `projects/projects.json`, nur über `scripts/project`:
[projects.md](projects.md).

## Menüs und Dialoge

Was der Shell gehört, ist **eigen** gebaut; was Apps und Portale zeigen, lässt sich nur **themen**, nicht ersetzen.

- **Eigen:** Tray-Menü (`TrayMenu.qml` statt nativem Qt-Menü), Workspace-/Dashboard-Menüs, Polkit-Abfrage
  (`modules/polkit`), Datei-/Ordnerwahl aus der Shell (`modules/filepicker`), Absturz-Karte statt DrKonqi, Layout-Menü,
  Sperre, Benachrichtigungen, OSD, Power-Menü, Launcher. Ohne laufende Shell springen gethemte Rückfälle ein (KDE-Polkit-Agent,
  kdialog) – ein Shell-Dialog ginge dann gerade nicht.
- **Gethemt:** Datei öffnen/speichern, „Öffnen mit“, Drucken, Berechtigungen (xdg-desktop-portal-kde + Farbschema),
  KWallet/pinentry (Qt), gcr (GTK), App-interne Menüs (Qt/GTK/VS Code/Helium/Thunderbird/Discord), Hyprlands ANR-Dialog.
- **Aus:** Hyprlands Update-News, Spenden-Hinweis, Logo/Splash, Berechtigungsfragen (`general.conf`).
- **Bewusst Standard:** Hyprlands Konfig-Fehlerleiste (nicht thembar, nur bei Fehlern).

## Stolperfallen

### Qt/KDE

- Breeze malt Menüs immer in der Fensterfarbe mit ~5-px-Ecken und Akzent-Rahmen als Hover – per Farbschema nicht änderbar.
  Darum Kvantum (`kvantum.py`, Basis KvFlat, GPL-3.0): Radien, ruhiger Hover; Häkchen = gefülltes Terrakotta-Kästchen.
  Kvantum liest seine Farben aus der eigenen `.kvconfig` (aus der Palette), nicht aus `kdeglobals`. Laufende Qt-Prozesse
  (auch `dolphin --daemon`, `xdg-desktop-portal-kde` = Dateidialoge) wechseln den Stil erst nach Neustart.
  Variante geht mit: `all.py` (also auch `rice variant`) ruft `kvantum-theme refresh` (nur wenn an).
  `splitter_width=1` wie Breeze: Dolphins kleine Statuszeile zieht 2 + 2·Splitterbreite als Rand ab (sonst „11 …ers“).
  Grenze: KDE-Dateidialog, Detailansicht – Kvantums `CT_ItemViewItem` verwirft die Breite von `KFileItemDelegate`, das
  danach noch 2·PM_FocusFrameHMargin abzieht → schmale Spalten mittig gekürzt („2 …ms“). Per `.kvconfig` nicht lösbar.
- KTextEditor (KWrite, Kate) nimmt für die Textfläche nicht das Farbschema, sondern ein KSyntaxHighlighting-Theme;
  ohne Eintrag „Color Theme“ in `kwriterc`/`katerc` (Gruppe „KTextEditor Renderer“) wählt es Breeze Dark (blaugrau).
- Das alte Schema „Desktop“ (ember) bleibt bestehen, hearth überschreibt es nicht: `scripts/rice` und `scripts/loginscreen`
  (Greeter-Farbschema) nutzen es noch.
- Qt-Apps lesen nur `kdeglobals`; `QT_QPA_PLATFORMTHEME=kde` kommt aus der Hyprland-Umgebung. Unter Hyprland ohne Titelleisten
  (`QT_WAYLAND_DISABLE_WINDOWDECORATION=1`), Rahmen kommen aus `look.conf`.
- **Ordner-Icons:** Breeze färbt bunte Ordner über `ColorScheme-Accent` mit dem Akzent – Akzent ändern hieße ganze UI ändern.
  Darum spiegelt `icons.py` Breeze Dark per Symlinks (KIconLoader sucht gekürzte Namen; ein schlankes Theme würde
  `folder-new` & Co. überdecken) und ersetzt nur die Ordner-SVGs. Name `Desktop-Icons`, weil `icons/Desktop` der Cursor ist.
  Ort-Bilder mit festen Farben (Schreibtisch, Papierkorb; Liste `ILLUSTRATED`) legt es nach Helligkeit auf Palette-Rampen;
  App-Icons und KDE-Logo bleiben. Laufende Apps sehen neue Icons erst nach Neustart.

### GTK

- Von Hand geänderte `gtk.css` wird nie überschrieben (Generator bricht ab). Unter Plasma kann kde-gtk-config `gtk.css`/
  `settings.ini` beim Schemawechsel neu schreiben → Generator erneut laufen lassen.
- GTK lädt `gtk.css` nur beim Start; GTK3 braucht alle `*_breeze`-Farbnamen belegt, sonst kommt Breeze-Blau durch.
  `GTK_THEME` wird nicht gesetzt.

### Lockscreen/Login

- QML hält `on…`-Namen für Signal-Handler: `onAccent` heißt im erzeugten Theme `textOnAccent`, sonst laden Lockscreen und
  Login nicht. Bool-Tokens werden als `bool` ausgegeben. Prüfen ohne Sperren:
  `kscreenlocker_greet --testing --shell de.bastian.desktop -platform offscreen`.

### Helium

- Eine Theme-Erweiterung färbt nur Rahmen, Tabs, Toolbar, Adressfeld; Menüs, Vorschläge, Einstellungen bleiben Grau.
  Nur die **Grundfarbe** (`browser.theme.user_color2` in `Default/Preferences`, neutral, dunkel) färbt alles – und nur,
  wenn `extensions.theme.id` = `user_color_theme_id` steht, sonst setzt Helium beim Start wieder Grau. Exakte Palette-Töne in
  Menüs gehen nicht (Material-Töne fest). Darum in Helium **keine** „Desktop Theme“-Erweiterung laden, sie ersetzt die Grundfarbe.
- `scripts/helium-colors` nur bei geschlossenem Helium. Policies liest Helium nur systemweit (`/etc/chromium/policies/`),
  darum bleibt „Load unpacked“ der Erweiterung und der Vimium-Import je ein Handgriff (Vorinstallieren nur mit sudo, dann gesperrt).
- Laufen zwei Browser mit der Erweiterung, gewinnt der zuletzt gestartete Native-Messaging-Host (Tabs-Datei und Socket gibt es
  einmal). Host-Manifest auf altem Checkout → Popup meldet „Desktop host is outdated“ → `scripts/chrome-ext install` neu.
- Vimium C geht nicht auf `helium://`-Seiten, der neuen Tab-Seite und im Web Store. Der Import setzt alle nicht genannten
  Einstellungen auf Standard.

### VS Code

- Projekt-Tönung ohne Spuren im Repo: neue `.vscode/settings.json` landen in `.git/info/exclude`. Repos mit **eingecheckter**
  `.vscode/settings.json` bekommen einen Wrapper `~/.config/desktop/workspaces/<name>.code-workspace`, den die Shell automatisch
  öffnet. In einem Arbeitsbereich zählen window-Scope-Einstellungen (`workbench.colorCustomizations`, `typescript.tsdk`,
  Erweiterungs-Settings ohne Scope) nur aus der Arbeitsbereich-Datei – darum spiegelt der Wrapper die Repo-Datei komplett.
  Ändert sie sich: `scripts/vscode-colors refresh` (auch nach `rice variant`).
- `theme/projects.json` wird aus `projects/projects.json` erzeugt (für ältere Leser), nie von Hand ändern.

### Discord / Thunderbird / Spotify

- Discord benennt CSS-Variablen um → eine Fläche wird wieder grau-blau: Variable in der Entwicklerkonsole suchen, im Generator
  ergänzen. Zwei Regeln hängen an Klassennamen (Server-Strich, Erwähnungs-Rand). Läuft Discord, kopiert `discord-theme install`
  nur die Datei – einschalten dann per Klick. Equibop überschreibt seine Einstellungen beim Beenden: nur bei beendetem Equibop ändern.
- Thunderbird ist gegen die Selektoren in `omni.ja` von 153.5 ESR geprüft; Release-Updates (RPM 157+) können den Look brechen →
  nach Updates `status` + Sichtprüfung. Adressbuch, Einstellungen, Add-ons laufen in Inhalts-Browsern und brauchen dieselbe Basis
  in `userContent.css`. `remove` lässt die Pref `toolkit.legacyUserProfileCustomizations.stylesheets` auf `true` (wirkungslos).
- Spotify (Flatpak): Spicetify müsste `xpui.spa` unter `/var/lib/flatpak/…/<Commit>/` patchen (root, Pfad ändert sich bei jedem
  Update, bricht regelmäßig) – nicht eingerichtet. Bedienung läuft ohnehin über die Shell-Kachel.

## sshs

Server aus dem Terminal (`scripts/sshs`, Befehle: `sshs --help`; Reiter in der Bar: [shell-features.md](shell-features.md)).

- Ein Server = ein Kitty-Fenster (Klasse `sshs`, `config/sshs/kitty.conf`); pro Tab `kitten ssh` und yazi über
  `sftp://<server>` übereinander, Strg+Leertaste schaltet um, der Ordner wandert mit (`config/sshs/sshs_kitten.py`,
  `config/yazi/init.lua`).
- Auf dem Server nur normales `kitten ssh` (Terminalbeschreibung + Kittys Shell-Integration für den Ordner), sonst nichts.
  TERM ist `xterm-256color`: `xterm-kitty` kennt dort nur der Anmelde-Benutzer, nach `sudo -i`/`su` gab es sonst Fehler.
- Server in `~/.ssh/config.d/sshs.conf` (lokal, nicht im Repo). Anmeldung über den SSH-Agenten; Passwörter speichert sshs nie.

## Sonstiges

- Kitty- und zsh-Kürzel stehen in `config/kitty/kitty.conf` und `config/zsh/zshrc`, Übersicht per Super+K ([hotkeys.md](hotkeys.md)).
  Kitty nutzt nur Strg+Shift (Super gehört Hyprland, Alt den Workspaces), alle Kitty-Standardkürzel sind aus.
- Textdateien öffnen in einem schlichten VS-Code-Fenster (`config/applications/code-simple.desktop`, per `xdg-mime default`).
- Klänge: ein einzelner neutraler, dumpfer Ton („Tupf“) statt Piepton, aus Rechnung erzeugt (`theme/gen/sounds.py` → `design/sounds/*.wav`, keine Fremd-Samples):
  fast nur Grundton (×2/×3 kaum), 5-ms-Einsatz, doppelter Tiefpass ~1,8 kHz. Normal F#4 (370 Hz), 150 ms; dringend A4, minimal heller, 180 ms.
  Bewusst keine Tonfolge und nichts Helles (Zwei-Ton-„pling“ und G5/C6 waren Bastian zu viel/zu hoch). Tief = wirkt leiser → `volume` 0.7.
  Zu dumpfe, tiefe Klicks (520 Hz, 50 ms Abklingen) gingen auf dem GoXLR-Kanal „System“ unter – ein Ton braucht Mitten um 0,7–1 kHz und ~100 ms Nachklang.
  Hängt nicht an der Palette (läuft nur mit `all.py --alles`). Shell spielt direkt per `pw-play`; Apps nur mit `scripts/sounds on`.
- Offen: KDE-Systemschrift prüfen, Icon-Theme in `rice theme on/off` einbinden, Login-Look einschalten.
