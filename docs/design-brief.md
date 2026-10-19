# Design-Brief: "Desktop" – ein cozy Linux-Desktop

> Für Claude Design. Zusammen mit den Bildern aus `design/inspo/` hochladen.
> Ergebnisse bitte nach `design/claude-design/` (Mockups, Palette, Tokens) und `design/cursors/` (SVGs + Hotspots).

## Ziel
Eigener Desktop-Look für Linux (KDE Plasma 6 + Quickshell/QML-Overlay), Niveau der Top-Posts auf r/unixporn.
Muss im Alltag 8–12 h am Tag funktionieren, ohne zu nerven: ruhig, gut lesbar, auf einen Blick erfassbar.
Wenig Ablenkung, das Wichtigste groß, Fokus-Hilfen. Funktion vor Deko.
Bitte bei jeder Komponente in 1–2 Sätzen begründen, warum sie im Alltag gut funktioniert.

## Stimmung
"Holzhütte am Abend mit Kaminfeuer": cozy, clean, lowkey, warm, holzig, viel Luft.
- Hintergrund: warmes Fast-Schwarz (kein Blau-Grau)
- Akzent: gedämpftes Ember-/Rost-Rot, sparsam (nur für aktiv/wichtig/Fokus)
- Nebentöne: Holzbraun, Creme (Text), warmes Amber für Warnungen
- Glas: halbtransparente Kacheln mit echtem Hintergrund-Blur, feiner heller 1-px-Rand, weiche Ecken, sanfte Schatten
- Schrift: Inter (UI), JetBrains Mono Nerd Font (Zahlen, Stats, Code)
- Icons: Material Symbols Rounded (oder Lucide), weil als Font direkt in QML nutzbar
- Animation: dezent, 150–250 ms, ease-out, Fades/Slides, keine Federn
- NICHT: Gruvbox, Neon, Cyberpunk, Blau/Lila-Verläufe, Türkis, harte Kontraste, verspielte Deko

Bitte 2–3 Stil-Varianten zur Auswahl (z. B. "Ember", "Walnut", "Candlelight").

## Technischer Rahmen (damit es baubar bleibt)
- 3 Monitore: links 1920×1080 (Discord), Mitte 2560×1440 (Hauptmonitor, NUR hier lebt die Shell),
  rechts 1920×1080 (Browser). Gesamt 6400×1440, Seitenmonitore vertikal mittig.
- Kein Dock, kein Rahmen ums Bild, schlanke Top-Bar.
- Blur ist echt: Mockups bitte mit realistischem Inhalt dahinter (VS Code, Browser), nicht nur über dem Wallpaper.
- Umsetzung in QML: Rechtecke, Radien, Verläufe, Blur, Schatten, Bilder, Fonts.
  Illustrationen nur als Bild-Asset, nicht in UI-Elementen.
- Klickflächen ≥ 32 px, alles auch per Tastatur bedienbar.

## Komponenten
1. **Top-Bar** (Mittelmonitor, ca. 36–40 px; schwebend oder randlos, bitte Vorschlag)
   - links: aktives Desktop-Profil (Code · Office · Chill · Gaming · "Code: my-app") + "Jetzt-Aufgabe" (ein Satz)
   - Mitte: Uhr, Datum dezent
   - rechts: Spotify-Mini (Titel – Artist, Play/Pause), Fokus-Timer (nur wenn er läuft),
     CPU-/GPU-Temp (nur auffällig wenn heiß), Tray-Icons
   - Zustand "Fokus-Modus": Bar wird still, nur Uhr + Restzeit + Aufgabe
2. **Dashboard** (Meta+D, Overlay auf dem Mittelmonitor, Glas-Kachel-Grid – _historisch, KWin-Stand; heute: Super antippen, deckende Kacheln_). Klare Hierarchie, nicht alles gleich laut:
   - Uhr/Datum, Wetter jetzt + "Morgen früh" (Motorrad/Rad-Check 7–9 Uhr: Regen, Temp, Wind), Ort aus `secrets.json` (`location`)
   - Spotify groß: Cover, Fortschritt, Hörzeit heute, Top-Song der Woche
   - Fokus: Pomodoro groß, Tagesziel-Ring (Fokus-Minuten/Ziel), Bildschirmzeit heute
   - Dev: Claude-Code-Usage (Tokens/Requests heute, 5-h-Fenster), Code heute (+/− Zeilen, Commits), GitHub-Zähler
   - System: CPU/RAM/GPU-Ringe + Temps, Netz (Ping, ↓/↑), Tailscale-Punkt, freier Speicher (System + Data),
     Uptime, ausstehende Updates, iCloud-Sync (letzter Erfolg ok/Fehler)
   - Steuerung: Key Light (an/aus, Helligkeit, Farbtemperatur), Hue-Szenen (Abend/Hell/Aus), Audio-Ausgang + Lautstärke pro App
   - Benachrichtigungs-Verlauf
   - Office-Hotlinks (Banking, Steuer, Kunden-Seiten …)
   - Profile starten: Code, Office, Chill, Gaming, Projekt …
3. **Launcher** (Meta): Suchfeld + Ergebnisliste, Modi: Apps, Projekte, Rechner, Emoji, Zwischenablage. Tastatur zuerst.
4. **Benachrichtigungs-Popup** (oben rechts), normal + dringend
5. **OSD** Lautstärke: klein, kurz sichtbar
6. **Power-Menü**: Sperren, Abmelden, Standby, Neustart, Ausschalten
7. **Fokus-Hinweise**: Pausen-Erinnerung, Hyperfokus-Wecker nach 90 min ("Pause, trinken, aufstehen"): freundlich, nicht alarmierend
8. **Lockscreen**: Wallpaper + große Uhr
9. **Terminal** (transparent mit Blur) + Prompt: Look-Vorschlag

## Liefergegenstände
- **A. Palette**: 12–16 Farben mit Name, Hex, Zweck (bg, surface, glass-tint, border, text, text-muted, accent,
  accent-soft, wood, cream, success, warning, error) + 16 ANSI-Terminalfarben. Text-Kontrast ≥ 4.5:1.
- **B. Design-Tokens**: Radien, Abstände (8er-Raster), Glas-Opazität, Blur-Stärke, Schatten, Schriftgrößen/-gewichte, Animationsdauern.
- **C. Mockups** 2560×1440 als PNG: Bar über VS Code · Dashboard offen · Launcher · Notification · OSD · Power-Menü · Fokus-Modus.
- **D. Wallpaper**: Motiv-Vorschlag (Desktop in der Dämmerung, Kaminglut, dunkles Holz, viel ruhige dunkle Fläche)
  in 2560×1440 + 2× 1920×1080 passend, oder als 6400×1440-Panorama. Dunkel genug für lesbare Glas-Kacheln.
- **E. Mauszeiger-Set**, komplett eigenes Design:
  - je Cursor ein SVG, 32×32-Viewbox (wird in 24/32/48/64 px gerendert) + Hotspot-Koordinate je Cursor
  - Stil: weich gerundet, Creme-Füllung mit dunkelbraunem Rand (oder umgekehrt), dezenter Schatten,
    Akzent nur in der Lade-Animation (z. B. glimmende Glut, 8–12 Frames)
  - Cursors: default, pointer, text, vertical-text, crosshair, help, progress (animiert), wait (animiert),
    not-allowed, no-drop, grab, grabbing, move, all-scroll, copy, alias, context-menu, cell,
    col-resize, row-resize, n/s/e/w/ne/nw/se/sw-resize, ew/ns/nesw/nwse-resize, zoom-in, zoom-out,
    optional: pencil, color-picker
- **F. Icons**: Ordnerfarbe(n) als Hex für ein Icon-Theme (z. B. Papirus) + Profil-Icons (Code/Office/Chill/Gaming)
- **G. Optional**: Wetter-Icons im selben Stil, sanfter Benachrichtigungston (weicher Holz-Klick), Avatar

## Inspirationen (Bilder in `design/inspo/`)
- **Bild 1–3** – Glas-Dashboards im Quickshell-Stil: halbtransparente Kacheln mit starkem Blur, große Outline-Uhr,
  CPU/RAM/GPU-Ringe mit Netzgraph, Media-Kachel mit Cover + Visualizer, Kalender/Wetter-Kachel.
  Übernehmen: Glas, Ringe, Kachel-Grid, viel Luft. Nicht übernehmen: Türkis/Mint, Rahmen ums Bild, vertikale Leiste.
- **Bild 4** – dunkles Setup mit Orange-Akzent: dünne Text-Topbar, transparentes Terminal, fastfetch.
  Übernehmen: warmes Schwarz + ein Akzent, ruhige Textbar, Terminal-Look. Akzent bei uns gedämpfter (Rost/Ember statt Signalorange).
