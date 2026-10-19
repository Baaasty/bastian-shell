# Desktop – Cursor-Set

28 statische Cursor + 2 Animationen (wait, progress: je 12 Frames), alle als SVG mit 32×32 viewBox.
Stil: Creme `#F2E7D8` gefüllt, Rand `#2A1C14` 1,6 px, weicher Schatten (feDropShadow), Glut `#D15A32` nur in der Lade-Animation.
Hotspots in `hotspots.json` (viewBox-Einheiten; beim Rendern mit `größe/32` multiplizieren).

## Dateien

- `<name>.svg` – ein Cursor; `wait-00..11.svg`, `progress-00..11.svg` – Animationsframes (60 ms je Frame)
- `hotspots.json` – Hotspot, Aliasse (X11-Namen), Frame-Zuordnung, Render-Größen 24/32/48/64
- `gen_cursors.py` – Generator (Pfade anpassen → neu ausführen)
- `build-xcursor.sh` – baut ein XCursor-Theme „Desktop“ nach `~/.local/share/icons/Desktop`

Die Richtungs-Cursor n/s/e/w/ne/nw/se/sw-resize sind Aliasse der Doppelpfeile (ns/ew/nwse/nesw) – wie bei Adwaita/Breeze üblich; das Build-Skript legt dafür Symlinks an.

## Build (XCursor für KDE Plasma 6 / Wayland)

Benötigt `rsvg-convert` (librsvg) und `xcursorgen` (xorg-xcursorgen).

```sh
./build-xcursor.sh            # rendert 24/32/48/64 px, schreibt ~/.local/share/icons/Desktop
```

Danach: Systemeinstellungen → Maus & Touchpad → Zeiger → „Desktop“. Für GTK/Flatpak zusätzlich `gsettings set org.gnome.desktop.interface cursor-theme Desktop`.

Hyprcursor (falls später Hyprland): `hyprcursor-util --create` versteht dieselben SVGs + `meta.hl`; Hotspots dort normalisiert (x/32, y/32).
