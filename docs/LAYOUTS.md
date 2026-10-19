# Drop-down-Terminal und Fenster-Layouts

Stand 18.10.2026 · Skripte: `scripts/dropterm`, `scripts/layout` · Layouts: `config/layouts/<name>.toml`

## Kürzel

| Taste | Wirkung |
|---|---|
| `Super + Shift + Enter` | Drop-down-Terminal ein-/ausblenden |
| `Super + Alt + K` | Layout-Menü der Shell (Layout anwenden, diesen Desktop speichern, löschen) |

(Kollisionen geprüft: Super+Enter = normales Terminal, Super+K = Kürzel-Übersicht; Super+Alt+K war frei. Gesamtliste: `docs/HOTKEYS.md`.)

---

## Drop-down-Terminal (Idee b)

Ein Kitty, der von oben ins Bild kommt, auf **jedem Monitor** (dem fokussierten), und danach im Hintergrund weiterlebt:
dieselbe Shell, dasselbe Scrollback, wenn du ihn wieder einblendest. Erneuter Druck blendet aus.

- Fenster: Klasse **`kitty-drop`** (`kitty --class kitty-drop`), ca. **80 % Breite × 45 % Höhe**, oben mittig (unter der Bar),
  Desktop-Look aus `config/kitty/kitty.conf`.
- Liegt in einem **Spezial-Workspace** `special:dropterm`: stört Kacheln und Workspace-Wechsel nicht.
- Start über `uwsm app -- kitty …` (eigene systemd-Einheit, stirbt nicht mit der Shell).
- **Bewusste Ausnahme** von „nichts schwebt“: nur diese Klasse schwebt (Regel am Ende von `hypr/rules.conf`).
  Normale Kitty-Fenster (Klasse `kitty`) kacheln wie alles andere.
- Größe und Platz setzt `scripts/dropterm` bei jedem Einblenden neu (Bar-Abstand, anderer Monitor).

Befehle (von Hand im Terminal):

```
scripts/dropterm toggle|show|hide   ein-/ausblenden
scripts/dropterm kill               Terminal beenden (nächstes Einblenden startet ein frisches)
scripts/dropterm status             läuft es, wo?
```

Anpassen: Breite/Höhe/Abstand = die Konstanten `WIDTH`, `HEIGHT`, `GAP` oben in `scripts/dropterm` (und die gleichen
Prozente in der Regel in `hypr/rules.conf`, sie gelten nur für das allererste Öffnen). Taste: Zeile `# Drop-down terminal`
in `hypr/binds.conf`.

Wenn es hakt: `scripts/dropterm kill`, dann neu. Das Fenster hat nichts mit Sitzungs-Wiederherstellung (`docs/SESSION.md`)
oder `layout save` zu tun (Klasse steht nicht in der Positivliste).

---

## Fenster-Layouts (Idee k)

Merkt, **welche Fenster auf einem Desktop liegen** (Terminal im Projektordner, VS Code, Helium), und baut sie mit einem
Befehl wieder auf. Gedacht für „Projektwechsel in 1 Sekunde“. Anders als die Sitzungs-Wiederherstellung (`docs/SESSION.md`,
automatisch nach Absturz/Login) ist ein Layout **von dir benannt, von Hand les- und änderbar** und gilt für **einen Desktop**.

„Desktop“ heißt hier wie in der Shell: Workspace *d* auf DP-2 + *100+d* links + *200+d* rechts. Gespeichert und
wiederhergestellt wird der **aktuelle** Desktop des fokussierten Monitors (`--desk N` wählt einen anderen).

### Bedienung

```
scripts/layout save [name]      aktuellen Desktop merken (ohne Namen: Name des Desktops)  [--force überschreibt]
scripts/layout restore [name]   fehlende Fenster starten und auf den Desktop legen          [--dry-run nur zeigen]
scripts/layout list [--json]    gespeicherte Layouts (--json: für das Shell-Menü, mit Desktop + Namensvorschlag)
scripts/layout show <name>      Datei anzeigen
scripts/layout rm <name>        entfernen (Datei wandert nach ~/.local/state/desktop/layouts-trash/)
scripts/layout menu             kdialog-Dialog – nur Rückfall, wenn die Shell nicht läuft
```

**Menü (Super+Alt+K):** eigenes Shell-Panel (`shell/modules/layouts/`, IPC `layouts toggle|open|close|list`) auf dem
fokussierten Monitor, im Look der anderen Menüs. Die Logik bleibt im Skript: das Menü liest `scripts/layout list --json` und
ruft `restore` / `save [--force]` / `rm` auf.

| Taste / Klick | Wirkung |
|---|---|
| `↑` `↓` (Bild↑/↓) | Layout wählen |
| `Enter` / Klick | Layout auf diesem Desktop anwenden (Menü geht zu, Ergebnis kommt als Benachrichtigung) |
| Tippen | filtert (Suchfeld „Search…“ steht ab 7 Layouts immer da, sonst erscheint es beim Tippen) |
| `Entf` / Papierkorb beim Überfahren | Löschen – Rückfrage in der Zeile: `Enter` löscht, `Esc` behält |
| `Strg+S` / „Save desktop N as…“ | Namensfeld (Vorschlag: Name des Desktops); `Enter` speichert. Gibt es den Namen schon: Hinweis, zweites `Enter` überschreibt, `Esc` behält |
| `Esc` | Rückfrage/Suche/Namensfeld zurück, sonst Menü zu (Klick daneben schließt auch) |

Leer (noch kein Layout): Hinweis „No layouts yet“, die Speichern-Zeile ist gleich ausgewählt.
Ohne laufende Shell (`qs ipc` scheitert) öffnet das Kürzel den alten kdialog-Dialog (`scripts/layout menu`).

**Typischer Ablauf:** Projekt-Desktop einrichten (Terminal, VS Code, Helium ordnen) → `Super+Alt+K` → *Save* → Name = Projektname.
Später auf einem leeren Desktop: `Super+Alt+K` → Layout wählen.

### Was `restore` tut (und lässt)

1. Liest `config/layouts/<name>.toml`. Ohne Namen: Name des aktuellen Desktops.
2. Zählt, was auf dem Ziel-Workspace **schon läuft** (gleiche Klasse). Davon wird **nichts doppelt gestartet**
   (zwei gemerkte Kitty, einer läuft → es kommt einer dazu).
3. Startet jedes fehlende Fenster der Reihe nach über `uwsm app --` und legt es per Hyprland-Regel gleich auf den
   Workspace seines Monitors. Auf einem sichtbaren Workspace wird jedes neue Fenster fokussiert, damit das nächste es teilt
   (dwindle: Fenster 2 rechts von 1, Fenster 3 unter/neben 2 …); am Ende kommt der Fokus dorthin zurück, wo du warst.
4. **Kacheln ergeben sich aus der Startreihenfolge** – Größen/Teilungsverhältnisse werden *nicht* nachgezogen
   (`box` in der Datei ist nur ein lesbarer Richtwert). Wer links/rechts landet, kann bei mehr als zwei Fenstern vom
   Original abweichen; mit `Super+Shift+Pfeil` oder `Super+S` zurechtrücken.
5. **Nur die Positivliste** aus `config/hyprflow/config.toml` (Kitty, Konsole, VS Code, Helium). Chat (Discord),
   Spotify, Steam und alles andere werden nie gespeichert noch gestartet. Ein `cmd` in der Datei muss mit dem Programm der
   Klasse beginnen (keine Shell, kein `sh -c`); sonst wird die Zeile übersprungen und gemeldet.

Die Zeit: ca. 0,6 s pro Fenster (VS Code/Helium bis ~25 s Wartezeit auf das Fenster). **Währenddessen nichts tippen.**

### Projekt-Verknüpfung

Ist der Layout-Name eine **Projekt-ID aus `projects/projects.json`** (z. B. `habit-tracker`, `dotfiles`), schreibt `save`
für VS Code `code --new-window <Projektordner oder Wrapper-Arbeitsbereich>` und für Helium die Dev-URL des Projekts
(`open.browser` / erster Port) in die Datei – wie beim Projekt-Desktop (`shell/services/Templates.qml: openProject`).
Bei anderen Namen steht dort nur `code` bzw. `helium` (die Programme stellen ihr Fenster selbst wieder her). Kitty/Konsole
bekommen den **Arbeitsordner der Shell** (`--directory` bzw. `--workdir`), nicht den letzten Befehl.

**Verhältnis zu den Desktop-Vorlagen** (`profiles/profiles.json`: *Code*, *Office* – in der Shell Workspace-Modus/Launcher):
Vorlagen legen einen **neuen** Desktop an und starten feste Programme. Layouts bauen den **aktuellen** Desktop nach einem
gemerkten Stand auf. Beides ergänzt sich: Vorlage/Projekt-Desktop öffnen, dann das Layout drüberlegen. Die Vorlagen selbst
sind unverändert (QML nicht angefasst).

### Dateiformat (`config/layouts/<name>.toml`)

```toml
version = 1
name = "habit-tracker"
saved = "2026-10-18T21:20:00"

[[window]]                     # Reihenfolge = Startreihenfolge = Kachelreihenfolge
class = "com.microsoft.VSCode" # Fensterklasse (hyprctl clients -j | grep class); muss in config/hyprflow/config.toml stehen
monitor = "DP-2"               # Monitor wie in hypr/monitors.conf -> Workspace d / 100+d / 200+d
cmd = ["code", "--new-window", "/home/me/Workspace/labs/habit-tracker"]
box = [0.005, 0.009, 0.493, 0.983]   # optional: x y Breite Höhe als Bruchteil des Monitors (nur Info)

[[window]]
class = "kitty"
monitor = "DP-2"
cmd = ["kitty", "--directory", "/home/me/Workspace/labs/habit-tracker"]
```

Von Hand ändern ist erwünscht: Fenster löschen/ergänzen, Reihenfolge tauschen, `monitor` ändern, anderen Ordner eintragen.
Nach dem Ändern `scripts/layout restore <name> --dry-run` zeigt, was passieren würde.

### Wenn etwas hakt

- „Auf Desktop N gibt es kein Fenster aus der Positivliste“ → es liegt nichts Speicherbares dort (Chat/Spotify zählen nicht).
- Neues Fenster wird nicht erkannt („kein neues Fenster nach 25 s“) → die App öffnete in einem bestehenden Fenster
  (VS Code mit schon offenem Projekt); kein Fehler.
- Schwebende Fenster werden nicht gemerkt (alles kachelt).
- Neue App aufnehmen: Block `[apps."<Klasse>"]` in `config/hyprflow/config.toml` (gilt dann auch für die Sitzungs-Wiederherstellung).
- Menü öffnet nicht: läuft die Shell? (`scripts/hypr status`). Ohne Shell kommt der kdialog-Rückfall; dessen Hyprland-Regeln
  kommen per `exec`-Regel direkt beim Start (`[float on; center on; …]`), nichts in `rules.conf`.
- Speichern meldet „Nothing to save here“: auf dem Desktop liegt kein Fenster aus der Positivliste.
