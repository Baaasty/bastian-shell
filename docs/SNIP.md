# Snip – Ausschneiden, Text lesen, Farbe holen, Anpinnen

Alles in `shell/modules/screenshot/` (`Snip.qml`, `SnipToast.qml`, `SnipPin.qml`), Hilfsskripte in `scripts/snip-*`.
Der Bildschirm wird mit `grim` eingefroren (ein Bild aller Monitore in `$XDG_RUNTIME_DIR/desktop-snip/full.png`, also im RAM), darauf wird gewählt.

## Bedienung

| Kürzel | Was |
|---|---|
| `Druck` / `Super+Shift+S` | Bereich ziehen → Enter kopiert + speichert (Bilder/Screenshots) |
| `Super+Shift+T` | Snip text: Bereich ziehen → Text daraus lesen (OCR) → Zwischenablage |
| `Super+Shift+C` | Pick color: Pixel anklicken → `#RRGGBB` in die Zwischenablage |
| `Super+Shift+P` | Snip pin: Bereich ziehen → als kleines Bild an den Schirm pinnen |
| `Strg+Druck` | alle Monitore speichern · `Super+R` Bildschirmaufnahme |

**Im Snip-Modus** (nach dem Ziehen, einzeilige Hilfe oben): `Enter` kopieren · `S` speichern unter … · `T` Text lesen · `C` Farbpipette · `P` anpinnen · Pfeile feinjustieren (Shift = Größe, Strg = 10 px) · `Esc` abbrechen.
Dazu wie bisher: Lupe, Shift = langsam zielen, Griffe, `Strg+C` / `Strg+S`, Klick ohne Ziehen = ganzer Monitor.
Vor dem Ziehen setzt `T` / `P` das Ziel (Enter führt es dann aus), `C` schaltet gleich auf die Pipette (Esc = zurück zur Auswahl).
Die Knopfreihe unter der Auswahl hat dieselben Aktionen für die Maus.

- **Text (OCR):** Ergebnis landet in der Zwischenablage, unten erscheint kurz „Text copied · 142 chars“ (keine Benachrichtigung). Das Bild liegt nur kurz in `$XDG_RUNTIME_DIR` und wird sofort gelöscht. Alles offline.
- **Farbe:** liest das Pixel aus dem eingefrorenen Bild (Lupe zeigt es), unten Farbfleck + Hex. `hyprpicker` wird nicht gebraucht.
- **Anpinnen:** kleines Fenster mit Rahmen, immer oben. **Ziehen** = verschieben · **Mausrad** = Größe · **Mittelklick** = Originalgröße · **Rechtsklick**, `Esc` (nach Klick) oder × = schließen. Max. 4, beim fünften geht das älteste zu. Bild nur in `$XDG_RUNTIME_DIR/desktop-snip/pin_*.png`, beim Schließen gelöscht (bei Abmeldung ohnehin weg). Alle schließen: `qs ipc … call snip closePins`.

## Abhängigkeiten

- Schon da: `grim`, `wl-copy`, ImageMagick (`magick`).
- **Nur für Text:** `sudo dnf install tesseract tesseract-langpack-deu tesseract-langpack-eng`
  Fehlt es, zeigt Snip „Install tesseract“ und legt diesen Befehl in die Zwischenablage. Sprachen: `deu` + `eng`, soweit installiert.
  Prüfen: `tesseract --list-langs`.

## Wartung / Fehlersuche

- `scripts/snip-ocr BILD.png` – Text lesen + kopieren (Ausgabe `OK n` / `EMPTY` / `NOTOOL` / `NOLANG`). Vorverarbeitung (Graustufen, 2×, dunkler Grund wird umgedreht) steht oben im Skript.
- `scripts/snip-color BILD.png X Y` – Hex eines Pixels (Bildkoordinaten) + kopieren.
- IPC (`qs ipc --any-display -p ~/Workspace/desktop-hyprland/shell call snip …`): `region` · `text` · `pick` · `pin` · `closePins` · zum Testen ohne Maus: `ocrArea x y w h` · `pinArea x y w h` · `pickAt x y` (globale Koordinaten) · `crop x y w h`.
- Kürzel stehen in `hypr/binds.conf` (Abschnitt Screenshots), Übersicht `docs/HOTKEYS.md`.
