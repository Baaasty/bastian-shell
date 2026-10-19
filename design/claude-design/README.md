# Desktop – Design-Lieferung

Mockups liegen im Claude-Design-Canvas „Desktop – cozy Linux-Desktop“ (jedes Board hat unter *Tweaks* den Stil-Schalter ember/walnut/candlelight; das Desktop-Board zusätzlich Bar schwebend/randlos). PNG-Export 2560×1440: im Canvas Board auswählen → Share › Export → PNG (Fonts werden eingebettet).

## Dateien

| Pfad | Inhalt |
|---|---|
| `palette.md` | A. Palette (3 Varianten, Kontrastwerte) + 16 ANSI-Farben, B. Tokens in Prosa |
| `tokens.json` | A+B maschinenlesbar: Themes, ANSI, Editor-Syntax, Radien, Abstände, Glas, Schatten, Typo, Icons, Motion, Fokus-Logik |
| `Theme.qml` | Singleton für Quickshell, Werte 1:1 aus tokens.json, `variant` umschaltbar |
| `wallpaper/` | D. `desktop-panorama-6400x1440.jpg` + Zuschnitte `links/mitte/rechts` (Seitenmonitore vertikal mittig, y 180–1260) |
| `icons/` | F. Profil-Icons (Kachel + Glyph) und Ordner-Vorschau, Farben in `icons/icons.md` |
| `../cursors/` | E. Cursor-Set: 28 SVGs + 24 Animationsframes, `hotspots.json`, `README.md` (XCursor-Build) |

## Empfehlung

**Ember.** Dunkelste Variante, Akzent nur an vier Stellen (Profil-Punkt, Fokus-Ring, Fortschritt, Auswahl) – bei 8–12 h am Tag bleibt der Akzent so ein Signal und wird kein Dauerton. Walnut ist die „holzigere“ Alternative mit etwas weniger Kachel-Kontrast; Candlelight die hellste, wenn Ember auf Dauer zu düster wirkt.

**Top-Bar schwebend** (10 px Lücke = Fenster-Lücke): Bar, Fenster und Kacheln liegen damit auf einem Raster, wirkt ruhiger als eine Kante, die am Bildrand klebt. Randlos ist ein Tweak, falls der Platz wichtiger ist.

## Warum die Komponenten im Alltag funktionieren

- **Top-Bar (38 px):** Links steht, *was* du gerade tust (Profil + Jetzt-Aufgabe), rechts nur Dinge, die du steuerst (Spotify, Tray); Temps sind Text in text-faint und werden erst in Amber laut, wenn es wirklich heiß ist. Nichts blinkt, nichts animiert dauerhaft.
- **Fokus-Modus:** Die Bar verliert alles außer Aufgabe, Uhr, Restzeit – der einzige bewegte Teil ist die 2-px-Fortschrittslinie. Weniger Ablenkung, aber die Information „wie lange noch“ bleibt auf einen Blick lesbar.
- **Dashboard:** Hierarchie statt Gleichlaut: Outline-Uhr und Fokus-Ring sind groß, Dev/System mittel, Steuerung/Hotlinks klein. Es ist ein Overlay (Meta+D), kein Dauer-Widget – also null Reiz, solange du arbeitest. Bike-Check steht als fertiges Urteil da („Eher Auto“), nicht als Rohdaten.
- **Launcher:** Ein Feld, Tastatur zuerst, Modi per Tab, erster Treffer ist vorausgewählt (Enter reicht). Treffer zeigen die Konsequenz („Code-Profil starten · Editor, Terminal, Docs“), nicht nur einen Namen.
- **Benachrichtigungen:** Normal = 6 s, dann Verlauf; dringend = Glut-Rand, bleibt bis Klick, kommt auch im Fokus-Modus durch. Zwei Stufen reichen; eine dritte würde die Unterscheidung aufweichen.
- **OSD:** Eine Pille, 1,2 s, unten mittig – weit weg von Bar und Popups, damit es nichts überdeckt.
- **Power-Menü:** Fünf Kacheln mit Tastenbuchstaben, Fokus auf „Sperren“ (die häufigste Aktion), Hinweis auf laufenden Fokus-Block – verhindert versehentliches Ausschalten mitten im Block.
- **Fokus-Hinweise:** Pausen-Erinnerung als schmales Banner unter der Bar (verdeckt nichts), Hyperfokus-Wecker als eine mittige Karte mit drei konkreten Handlungen und zwei Buttons – freundlich, ohne Ton, ohne Rot.
- **Lockscreen:** Nur Uhr, Datum, ein Satz „Wenn du zurück bist: …“ – der Wiedereinstieg kostet keine Sekunde Überlegen.
- **Terminal:** Glas 78 % + Blur 30, zweizeiliger Prompt mit Pfad in Akzent-Text, Branch in muted, Uhrzeit rechts; Fehlerfarben nur Amber/Moos. Fastfetch bekommt dieselbe Palette (Logo in Glut, Text in Creme).

## Wallpaper – Motiv-Vorschlag

Geliefert ist die abstrakte Version (Dämmerung, Baumlinie, Kaminglut unten links der Mitte, Korn). Für ein gemaltes Motiv, z. B. per Bildgenerator, Prompt:

> Dunkle Holzhütte in der Abenddämmerung, weit hinten links im Bild, ein warm erleuchtetes Fenster und Kaminglut; Nadelwald als Silhouette, sehr viel ruhige, fast schwarze Fläche oben und rechts; warme Brauntöne, kein Blau; feines Filmkorn; Panorama 40:9 (6400×1440); kein Text, keine Personen.

Prüfkriterium: Über jedem Bildbereich, auf dem Glas-Kacheln liegen, muss die Luminanz unter ~12 % bleiben – sonst leidet die Lesbarkeit der Kacheln.
