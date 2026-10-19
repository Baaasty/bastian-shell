# Icons – Profil-Icons & Ordnerfarben

## Profil-Icons

Je Profil zwei Dateien, 32×32 viewBox, Stroke 2 px, runde Enden:

| Profil | Kachel (Holz-Fläche, Creme-Glyph) | Glyph (currentColor, für QML/Bar) |
|---|---|---|
| Code | `profile-code.svg` | `profile-code-glyph.svg` |
| Office | `profile-office.svg` | `profile-office-glyph.svg` |
| Chill (Becher mit Dampf) | `profile-chill.svg` | `profile-chill-glyph.svg` |
| Gaming | `profile-gaming.svg` | `profile-gaming-glyph.svg` |
| Projekt… | `profile-projekt.svg` | `profile-projekt-glyph.svg` |

Kachel: Fläche `#5A3F2E` (wood), Radius 9/32, Hairline `rgba(242,231,216,.12)`. Aktives Profil in der Bar: Glyph in `text` + Glut-Punkt, nicht die Kachel einfärben.

## Ordnerfarben (Papirus)

Papirus hat keine Holz-Variante; eigene Farbe über `papirus-folders` mit angepasstem Farbset (Front/Back/Glyph) oder per `papirus-folders -C` nach Hinzufügen einer Farbe in `~/.local/share/icons/Papirus/…/places/`.

| Set | Zweck | Front | Back | Glyph/Symbol |
|---|---|---|---|---|
| Holz (Standard) | alle Ordner | `#8A6648` | `#6B4D37` | `#F2E7D8` (Creme, 85 %) |
| Glut | Projekt-Ordner (`~/dev`, aktives Projekt) | `#D15A32` | `#A8452A` | `#F2E7D8` |
| Amber (optional) | Downloads/temporär | `#D9A449` | `#A97E34` | `#1A1310` |

Vorschau: `folder-wood.svg`, `folder-ember.svg`. Papirus-Workflow: `places/48/folder-*.svg` duplizieren → Fill-Farben ersetzen (Papirus verwendet zwei Töne pro Ordner) → `papirus-folders -C desktop --theme Papirus-Dark`.
