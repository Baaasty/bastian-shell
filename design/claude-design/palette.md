# Desktop – Palette & Tokens

Drei Varianten, gleiche Rollen. **Empfehlung: Ember** (dunkelste, klarster Kontrast, Akzent am sparsamsten einsetzbar).
Alle Text-Kontraste gemessen gegen `bg` und gegen eine Glas-Kachel über dem Editor (`glassTint` auf `#141009` komponiert).
Maschinenlesbar: `tokens.json` (gleiche Namen).

## A. Palette – Ember (Standard)

| Rolle | Hex / rgba | Zweck | Kontrast bg / Kachel |
|---|---|---|---|
| bg | `#120D0B` → `#0B0806` | Wallpaper-Basis, Fast-Schwarz (warm, kein Blau) | – |
| surface | `#1A1310` | Opake Flächen ohne Blur (Menüs, Tooltips, Editor-Vorschlag `#141009`) | – |
| glass-tint | `rgba(26,18,14,.62)` | Kacheln, Popups, Launcher – mit Blur 24 px | – |
| glass-strong | `rgba(20,13,10,.80)` | Top-Bar, dringende Popups, Lockscreen-Feld | – |
| border | `rgba(255,232,205,.10)` | 1-px-Hairline auf jedem Glas, plus Innenlicht oben `rgba(255,240,220,.06)` | – |
| border-strong | `rgba(255,232,205,.20)` | Ring-Tracks, Separatoren, Key-Hints | – |
| text (= cream) | `#F2E7D8` | Primärtext, Zahlen, Uhr | 15.8 / 15.3 |
| text-muted | `#BCAB98` | Sekundärtext, Artist, Untertitel | 8.7 / 8.4 |
| text-faint | `#948370` | Labels (12 px, 600, Versalien), Hints, Zeitstempel | 5.1 / 5.0 |
| accent (Ember) | `#D15A32` | NUR aktiv/wichtig/Fokus: Pomodoro-Ring, aktiver Profil-Punkt, Fortschritt, Fokus-Linie, Cursor | 4.8 (Flächen) |
| accent-text | `#E8805A` | Akzent als Text/Icon auf Dunkel (Buttons „pri“, Hyperfokus-Label) | 7.0 / 6.8 |
| accent-soft | `rgba(209,90,50,.16)` | Hintergrund aktiver Chips/Buttons/Launcher-Auswahl | – |
| wood | `#5A3F2E` | Icon-Kacheln, Cover-Fallback, Avatar | – |
| wood-light | `#8A6648` | Sekundäre Ringe/Balken (CPU/RAM/GPU, Tagesziel, Netzgraph) – nie für Text | 3.7 (nur Grafik) |
| success | `#9BA67E` | Moos: Tailscale ok, iCloud ok, +Zeilen, Tests grün | 7.5 / 7.2 |
| warning | `#D9A449` | Amber: heiß, Regen-Verdikt, geänderte Dateien | 8.6 / 8.3 |
| error | `#D4463A` | Fehler (Sync fehlgeschlagen, Platte voll) – als Rand/Icon, Text bleibt cream | 4.4 (nur Rand/Icon) |
| dim | `rgba(10,6,4,.42)` | Abdunkeln hinter Dashboard (.42), Launcher (.30), Power (.55 + Blur 18) | – |

## Walnut

| Rolle | Wert |
|---|---|
| bg / surface | `#14100D` → `#0C0907` / `#1C1511` |
| glass-tint / glass-strong | `rgba(48,34,25,.58)` / `rgba(38,27,20,.78)` |
| border / border-strong | `rgba(255,225,190,.12)` / `.22` |
| text / muted / faint | `#EFE3D1` / `#B9A791` / `#978470` |
| accent (Rost) / accent-text / accent-soft | `#B9502F` / `#DC7A55` / `rgba(185,80,47,.18)` |
| wood / wood-light | `#6A4A35` / `#9A7454` |
| success / warning / error | `#9CA27A` / `#DDB15A` / `#D4463A` |

Charakter: brauner, „materieller“ – Glas wirkt wie dunkles Holz. Trade-off: etwas weniger Kontrast zwischen Kachel und Editor dahinter.

## Candlelight

| Rolle | Wert |
|---|---|
| bg / surface | `#1A130D` → `#100B07` / `#221910` |
| glass-tint / glass-strong | `rgba(64,46,30,.50)` / `rgba(52,37,24,.72)` |
| border / border-strong | `rgba(255,230,190,.14)` / `.26` |
| text / muted / faint | `#F7EEDF` / `#C6B59E` / `#9C8B74` |
| accent (Gold) / accent-text / accent-soft | `#D59A3D` / `#E9B65E` / `rgba(213,154,61,.18)` |
| wood / wood-light | `#6E4F36` / `#A07A55` |
| success / warning / error | `#A3A77E` / `#CF5B35` (Glut = Warnung) / `#D4463A` |

Charakter: heller, wärmer, luftiger. Trade-off: Warnung und Fehler liegen beide im Rot – Warnung deshalb immer mit Thermometer-/Regen-Icon, nie nur Farbe.

## 16 ANSI-Terminalfarben (alle Varianten)

| # | Name | Hex | # | Name | Hex |
|---|---|---|---|---|---|
| 0 | black | `#1A1310` | 8 | bright black | `#5E5146` |
| 1 | red (Ember) | `#C9532E` | 9 | bright red | `#E8805A` |
| 2 | green (Moos) | `#8FA37B` | 10 | bright green | `#A9BC8E` |
| 3 | yellow (Amber) | `#D9A449` | 11 | bright yellow | `#E6BE6A` |
| 4 | blue (gedämpft) | `#7E8FA8` | 12 | bright blue | `#9FB0C7` |
| 5 | magenta (Rosenholz) | `#B8788A` | 13 | bright magenta | `#CC94A4` |
| 6 | cyan (Salbei, kein Türkis) | `#7FA394` | 14 | bright cyan | `#96BBAC` |
| 7 | white | `#D9CDBB` | 15 | bright white | `#F2E7D8` |

Vordergrund `#F2E7D8`, Hintergrund `#100B09` bei 78 % + Blur 30 px, Cursor `#D15A32`, Selektion `rgba(209,90,50,.28)`.
Blau bleibt absichtlich im Set (ls, Pfade, Links), aber stark entsättigt; Cyan ist Salbei statt Türkis.

## B. Design-Tokens

**Radien:** xs 6 · sm 8 (Chips) · md 12 (Bar, Buttons) · lg 16 (Kacheln, Popups) · xl 20 (Launcher, Hyperfokus-Karte, Power-Kacheln 22) · Fenster 14 · Pille 999.

**Abstände (8er-Raster):** 4 · 8 · 12 · 16 · 20 (Kachel-Gap) · 24 · 32 · 48 · 80 (Dashboard-Rand).
Ausnahmen: Fenster-Lücke 10 px (= Bar-Margin), Bar-Höhe 38 px, Dashboard-Oberkante 110 px.

**Glas:** Kachel 62 % Tint + Blur 24 px + Sättigung 1.15 · Bar 80 % + Blur 24 · Terminal 78 % + Blur 30 · Rand 1 px `border` + Innenlicht oben 1 px `rgba(255,240,220,.06)`.
Abdunkeln dahinter: Dashboard .42, Launcher .30, Power .55 + Blur 18.

**Schatten:** Kachel/Popup `0 16 48 rgba(0,0,0,.45)` · Terminal `0 24 64 rgba(0,0,0,.50)` · Slider-Knopf `0 2 6 rgba(0,0,0,.40)` · Tastaturfokus `0 0 0 2px accent`.

**Schrift:** Inter 400/500/600/700 (UI) · JetBrains Mono Nerd Font 400/500/600 (Zahlen, Stats, Code, Uhr), tabellarische Ziffern.
Label 12/600 Versalien, Tracking .08em · Caption 12 · UI 13 · Bar 14/600 · Body 14 (LH 1.45) · Launcher-Treffer 16 · Sub 18 · Titel 24/600 · Headline 32/600 · Stat 30/600 mono · Ring 48/600 mono · Dashboard-Uhr 210/700 mono als Outline (2 px) · Lock-Uhr 260/600 mono.

**Icons:** 14 inline im Text · 18 in Buttons · 22 Launcher · 34 Power-Kacheln · 44 Wetter. Stroke 2 px, runde Enden.
In QML: Material Symbols Rounded als Font (`FILL 0, wght 400, opsz 24`); die Mockups nutzen Lucide-Strokes, Metrik identisch.

**Animation:** alles ease-out (OutCubic), keine Federn. Fade 150 · Slide 200 · Zustandswechsel 200 · Ring 250 · Dashboard auf 180 · Launcher auf 150 · OSD 1,2 s sichtbar · Benachrichtigung 6 s (dringend: bis Klick).

**Klickflächen:** min. 32 px (Tray-Buttons 32, Chips 30 hoch in 38er-Bar, Launcher-Zeilen 60, Profil-Buttons 68, Power-Kacheln 168).

**Fokus-Logik (Tokens):** Block 25 min · Pause 5 min · Hyperfokus-Wecker nach 90 min · Tagesziel 180 min · Fokus-Modus blendet aus: Spotify, Temps, Tray, Datum, nicht-dringende Popups.
