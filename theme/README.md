# theme/ – eine Palette für alles

`palette.json` ist die einzige Farbquelle. Die Generatoren in `gen/` schreiben daraus `out/` (liegt im Repo)
und installieren nach `~/.local`. **Aktiviert wird nichts automatisch.**
Jede App behält ihren eigenen Kontrast: Editor (`editorSyntax`) ≠ Shell-Glas (`themes.*`) ≠ Terminal (`ansi`).

## Erzeugen

```sh
cd ~/Workspace/bastian-shell
python3 -I theme/gen/all.py              # alles erzeugen + installieren (inkl. Cursor)
python3 -I theme/gen/all.py --nur-out    # nur theme/out/ schreiben
python3 -I theme/gen/all.py walnut       # andere Variante (Namen bleiben "Desktop")
```

Variante umschalten (setzt `defaultTheme`, erzeugt alles neu, wendet an, was schon aktiv ist; Shell live):
`scripts/rice variant` (Liste) · `scripts/rice variant dusk` · Vergleich ohne Umschalten: `design/variants.html`.

Einzeln: `kde_colors.py`, `konsole.py`, `starship.py`, `vscode.py` (+ `vscode_projects.py`), `chrome.py`, `thunderbird.py`; Cursor: `design/cursors/build-xcursor.sh`.
Wallpaper (nicht in `all.py`): `wallpaper.py [variante] [--motif=licht,huegel,holz]` → `out/wallpaper/<variante>/<motiv>/` (gitignored) + Vorschauen `design/wallpapers/`; Vergleich `design/wallpapers.html`, setzen `scripts/wallpaper set --variant dusk --motif huegel`.
`--alles` erzeugt zusätzlich `design/palette.js`, das Lockscreen-Theme und `Theme.qml` des Fensterwechslers (`bridge/kwin/desktop-switcher/`, installiert per `scripts/rice switcher`).

| Ziel | Datei im Repo | Installiert nach |
|---|---|---|
| KDE-Farbschema | `out/kde/Desktop.colors` | `~/.local/share/color-schemes/Desktop.colors` |
| Konsole | `out/konsole/Desktop.colorscheme`, `Desktop.profile` | `~/.local/share/konsole/` |
| Starship | `out/starship.toml` | – (wird direkt aus dem Repo gelesen) |
| VS Code | `out/vscode-desktop/`, `out/vscode-desktop-projects/` (Projektpunkt) | `~/.vscode/extensions/desktop.desktop-theme-0.1.0/` + `desktop.desktop-projects-0.1.0/` (natives RPM); Flatpak nur, wenn installiert |
| Chrome | `out/chrome-desktop/manifest.json` | – (von Hand laden) |
| Thunderbird | `out/thunderbird-desktop/` (`manifest.json` + `desktop-theme@bastian.xpi`, `chrome/userChrome.css` + `userContent.css`, `user.js`-Block); Vorlagen ohne Farben: `gen/thunderbird-css/` | `~/.thunderbird/<Standardprofil>/` (RPM) → `extensions/desktop-theme@bastian.xpi`, `chrome/`, Block in `user.js`; solange nicht umgezogen: Flatpak-Profil `~/.var/app/org.mozilla.thunderbird_esr/.thunderbird/` |
| Cursor | – (Binärdateien) | `~/.local/share/icons/Desktop/` |

Starship-Binary: `~/.local/bin/starship` (offizielles Release, ohne sudo).

## Aktivieren und zurück

Vorher merken, was gerade aktiv ist: `kreadconfig6 --group General --key ColorScheme` und
`kreadconfig6 --file kcminputrc --group Mouse --key cursorTheme` (Stand 2026-10-18: `CatppuccinMochaRed`, `catppuccin-mocha-red-cursors`).

**KDE-Farben**
```sh
plasma-apply-colorscheme Desktop               # an
plasma-apply-colorscheme CatppuccinMochaRed   # zurück
```

**Cursor**
```sh
plasma-apply-cursortheme Desktop                         # an
plasma-apply-cursortheme catppuccin-mocha-red-cursors   # zurück
```

**Konsole** – erst testen, dann als Standard:
```sh
konsole --profile Desktop.profile              # nur dieses Fenster
kwriteconfig6 --file konsolerc --group "Desktop Entry" --key DefaultProfile Desktop.profile   # Standard
kwriteconfig6 --file konsolerc --group "Desktop Entry" --key DefaultProfile --delete         # zurück
```
Oder in Konsole: Einstellungen → Profile verwalten → „Desktop“ → Als Standard.
Blur kommt vom KWin-Effekt „Unschärfe“; die Stärke (Design: 30) stellt man dort global ein, nicht pro App.
Schlank (keine Werkzeugleisten, Tab-Leiste nur bei mehreren Tabs): `scripts/konsole-ui on|off|status`, läuft mit `rice theme on|off`.
Menü dann per Rechtsklick oder Strg+Shift+M.

**Starship** – zwei Zeilen ans Ende von `~/.bashrc`:
```sh
export STARSHIP_CONFIG="$HOME/Workspace/bastian-shell/theme/out/starship.toml"
eval "$(starship init bash)"
```
Zurück: beide Zeilen löschen, `exec bash`. (Nach dem Umbenennen des Repos nach `~/Workspace/pc` den Pfad anpassen.)

**VS Code**
`scripts/vscode-colors theme on` (setzt nur `workbench.colorTheme`, sichert vorher nach `settings.json.vor-desktop-<zeit>`).
Zurück: `scripts/vscode-colors theme off` (vorher war keins gesetzt = Standard „Dark 2026“).
Projektfarben: `scripts/vscode-colors` (Übersicht/Hilfe), Logik in `gen/vscode_projects.py`, Zuordnung `../projects/projects.json` (über `scripts/project`; `projects.json` hier ist daraus erzeugt), Farben `projectAccents`.
Nach `rice variant` tönt `vscode.py` die Projekte automatisch neu (`vscode-colors refresh`).
Ganz entfernen: `scripts/vscode-colors off`, `… theme off`, dann `code --uninstall-extension desktop.desktop-theme` und `… desktop.desktop-projects`.

**Chrome**
`chrome://extensions` → Entwicklermodus an → „Entpackte Erweiterung laden“ → `~/Workspace/bastian-shell/theme/out/chrome-desktop`.
Zurück: `chrome://settings/appearance` → Design „Zurücksetzen“ (entfernt das Theme).

**Thunderbird** (Theme + userChrome/userContent, Details `docs/knowledge/theming.md`)
```sh
python3 -I theme/gen/thunderbird.py apply    # an: XPI + chrome/ + user.js-Block, greift nach Neustart
python3 -I theme/gen/thunderbird.py status   # was liegt im Profil, welches Theme ist aktiv
python3 -I theme/gen/thunderbird.py remove   # alles Eigene raus (fremde Dateien bleiben)
```
Einmalig: ☰ → Add-ons und Themes → Themes → „Desktop“ → Aktivieren (seitengeladen = erst deaktiviert, `extensions.autoDisableScopes` = 15).
`all.py`/`rice variant` frischen chrome/ + user.js nur auf, wenn schon angewendet. Thunderbird wird nie beendet, prefs.js nie angefasst.

## Alles wieder weg

```sh
rm ~/.local/share/color-schemes/Desktop.colors
rm ~/.local/share/konsole/Desktop.colorscheme ~/.local/share/konsole/Desktop.profile
rm -r ~/.local/share/icons/Desktop
python3 -I theme/gen/thunderbird.py remove   # Thunderbird danach neu starten
scripts/vscode-colors off; scripts/vscode-colors theme off
code --uninstall-extension desktop.desktop-theme; code --uninstall-extension desktop.desktop-projects
rm ~/.local/bin/starship
```
Vorher die Einstellungen oben zurückstellen, sonst fällt Plasma auf Breeze zurück.
