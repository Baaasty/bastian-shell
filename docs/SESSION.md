# Sitzung wiederherstellen (hyprflow)

Stand 18.10.2026 · Spur 1 · Skripte: `scripts/session`, `scripts/session-prepare` · Config: `config/hyprflow/config.toml`

Nach Neustart, Absturz oder Stromausfall öffnen sich Terminal, VS Code, Helium … wieder auf ihren Workspaces.
Backend ist **hyprflow** v0.2.1 (Rust, MIT). Es speichert `hyprctl clients -j` und startet die Apps nacheinander neu.

## Einrichten (einmalig)

1. **cargo** bereitstellen (erledigt: cargo 1.99 aus dnf).
2. `scripts/session install` – verlinkt Config und Autosave-Timer (ohne sudo; ohne hyprflow passiert nichts Schädliches).
3. `scripts/session build` – klont hyprflow, prüft den **festgenagelten, von uns gelesenen Stand** (`efc96e9`),
   baut ihn mit `cargo install --locked --root ~/.local --path ~/.local/src/hyprflow` nach `~/.local/bin/hyprflow`.
4. `scripts/session dry-run` – zeigt, was wiederhergestellt würde (startet nichts).
5. Den ersten echten Test mit wenigen offenen Fenstern machen (`scripts/session restore`, nicht bei vollem Desktop:
   gleiche Klasse auf gleichem Workspace wird übersprungen, alles andere wird zusätzlich geöffnet).

Der Login-Restore (`exec-once` in `hypr/autostart.conf`) ist schon eingetragen und wirkt, sobald hyprflow da ist.

**Stand 18.10.2026: installiert.** hyprflow 0.2.1 (Commit `efc96e9`) in `~/.local/bin/hyprflow`, Config nach `~/.config/hyprflow/config.toml`
verlinkt, Autosave-Timer aktiv (alle 5 min), Login-Restore in `hypr/autostart.conf` eingetragen. Geprüft: Speichern, Positivliste
(nur Kitty, Konsole, VS Code, Helium; Discord (RPM/Flatpak, alt Equibop/Vesktop)/Spotify/Steam draußen), Vorschau, Autosave-Wächter, Not-Aus.
**Noch nicht getestet:** ein echter Restore (öffnet Programme) – siehe „Erster Test“.

## Erster Test (Bastian)

Auf einem freien Workspace, damit nichts doppelt aufgeht:

1. Wechsle auf einen leeren Workspace (z. B. `Super+3` auf dem Hauptmonitor, falls leer) und öffne dort 2–3 Fenster:
   Konsole (in einem Projektordner, z. B. `cd ~/Workspace/bastian-shell`), VS Code, evtl. Helium.
2. `scripts/session save` → meldet „Saved session 'latest' (N windows)“.
3. `scripts/session dry-run` → Liste prüfen: Workspace-Nummer und Programm stimmen? Discord/Spotify dürfen **nicht** auftauchen.
4. Die 2–3 Test-Fenster schließen (nur diese; ungespeicherte Arbeit vorher sichern).
5. `scripts/session restore` → Fenster kommen nacheinander (ca. 1,5 s Pause je App, VS Code/Helium bis ~25 s) wieder
   auf dem Workspace; Konsole mit dem Arbeitsordner. **Währenddessen nichts tippen/öffnen.**
6. Kachel-Anordnung und Größen ansehen – kleine Abweichungen (links/rechts im Split) sind bekannt.

Wenn etwas hakt:
- `scripts/session off` – sofort Autosave und Login-Restore aus (`session on` schaltet wieder an).
- `scripts/session status` und `tail ~/.local/state/desktop/session.log` – was ist passiert?
- Doppelte Fenster: einfach schließen; `restore` bei vollem Desktop vermeiden.
- Hyprland-Config-Fehler: `hyprctl configerrors`. Ganz zurück: `scripts/session uninstall` (siehe unten).
- Beim ersten echten Neustart: Zeile `boot:` im Log zeigt, ob der Login-Restore lief.

## Befehle

| Befehl | Wirkung |
|---|---|
| `session status` | Was ist installiert/aktiv, was würde wiederhergestellt |
| `session save [name]` | Jetzt sichern (Standard „latest“) |
| `session dry-run [name]` | Vorschau, startet nichts |
| `session restore [name] [--max-age 24h]` | Wiederherstellen (öffnet Programme!) |
| `session list` | Gespeicherte Sitzungen |
| `session off` / `session on` | **Not-Aus**: Autosave + Login-Restore aus / an |
| `session uninstall` | Links und Timer entfernen |

## Ablauf

- **Autosave** alle 5 min (`desktop-session-save.timer`, 20 Stände = 100 min Verlauf) nach `~/.local/share/hyprflow/sessions/`.
  Er speichert **nicht**: während des Login-Restores, bei 0 wiederherstellbaren Fenstern, nach plötzlichem Einbruch
  der Fensterzahl (weniger als die Hälfte des letzten Stands, der jünger als 30 min ist). Sonst würde der leere
  Desktop direkt nach einem Absturz den guten Stand überschreiben.
- **Login**: `session boot` wartet auf die Shell (`desktop-shell-hyprland`, max. 90 s) + 8 s, nimmt den neuesten
  brauchbaren Stand (nur wenn jünger als 24 h) und startet die Apps nacheinander (1,5 s Pause). **Während dieser
  Minute nichts tippen/öffnen** – neue Fenster erscheinen zuerst auf dem aktiven Workspace und werden dann verschoben.
- Start jeder App über `uwsm app --` (eigene systemd-Einheit, stirbt nicht mit Quickshell/Hyprland-Skripten).

## Was wiederhergestellt wird – und was nicht

Wiederhergestellt wird **nur, was in `config/hyprflow/config.toml` als `[apps."<Klasse>"]` steht** (Positivliste):

| App | Verhalten |
|---|---|
| Konsole / Kitty | je ein Fenster, **Arbeitsordner** kommt zurück (letzter Befehl nicht) |
| VS Code (`com.microsoft.VSCode`) | **ein** Start, VS Code öffnet seine Ordner selbst |
| Helium | **ein** Start; Tabs nur, wenn Helium „Beim Start: zuletzt geöffnete Seiten“ nutzt |

Nie neu gestartet: Discord, Spotify (die Shell holt sie selbst), Steam und Spiele, Dialoge, Picker, Polkit,
alles was nicht in der Liste steht. Dolphin/Thunderbird: als Beispiel auskommentiert in der Config.
Weitere App aufnehmen: Klasse mit `hyprctl clients -j | grep '"class"'` ablesen, Block nach dem Muster ergänzen.
Nicht gemerkt: Fensterinhalte, ungespeicherte Arbeit, Vollbild, schwebende Fenster (alles kachelt), Brave-Profile (aus).

## Kacheln und drei Monitore

hyprflow positioniert per Pixelkoordinaten. Bei gekachelten Fenstern (dwindle) wirkt `movewindowpixel` nicht;
`resizewindowpixel` verschiebt höchstens die Teilungsverhältnisse. **Maßgeblich sind also Workspace und Startreihenfolge**
(zuerst die kleinen Workspace-Nummern, in jedem oben→unten, links→rechts). Das passt zum Schema: Die Workspace-Nummer
(`1…`, `101…`, `201…`) legt den Monitor fest, ein eigener Monitor-Schritt ist nicht nötig. Layout-Feinheiten (wer links,
wer rechts im Split) können nach dem Restore abweichen – das ist unvermeidbar und beim ersten Test zu prüfen.
Fehlt ein Monitor, landen die Fenster auf den Workspaces des vorhandenen (Hyprland ordnet sie neu zu).

## Sicherheit (Prüfung der Quellen, Details im Chat-Bericht)

- hyprflow startet Programme als **Argumentliste ohne Shell**, liest nur `/proc/<pid>/cwd|children|cmdline`, hat kein
  Netzwerk, keine Telemetrie, kein `build.rs`, 9 gängige Abhängigkeiten (alle crates.io, `Cargo.lock` mit `--locked`).
- Trotzdem liest hyprflow nie die Originale: `session-prepare` baut daraus beim Restore eine **bereinigte Kopie** in
  `$XDG_RUNTIME_DIR` (Positivliste, Namen nur `[A-Za-z0-9._-]`, Ordner nur absolut und existierend, Vollbild/Schweben aus,
  weil hyprflow `fullscreen` auf das *fokussierte* Fenster anwendet).
- Sitzungsdateien enthalten Fenstertitel; Ordner `0700`, Dateien `0600` (hyprflow selbst schreibt `0644`, das Skript korrigiert).
- Die Datei-Schreibung von hyprflow ist nicht atomar; bei Stromausfall mitten im Schreiben ist nur dieser eine Stand kaputt,
  `session-prepare` überspringt unlesbare Dateien und nimmt den vorherigen.

## Not-Aus und Rückbau

- `scripts/session off` (sofort wirksam, hält auch den noch wartenden Login-Restore an) · `session on`.
- Ganz weg: `scripts/session uninstall`, dann Zeile `# Session restore` aus `hypr/autostart.conf` löschen, `~/.local/bin/hyprflow` löschen.
- Log: `~/.local/state/desktop/session.log`.
- Hinweis: `session off` stoppt den Timer nur (kein `systemctl disable`, das würde den verlinkten Unit-Link löschen).

## Alternative geprüft: hyprsession (nicht gewählt)

github.com/joshurtree/hyprsession (GPL-3.0, v0.2.1, letzter Commit Jan 2026; Autor stellt auf Plugin um, keine neuen Features).
Gründe dagegen (aus dem Quellcode): `load` **beendet erst alle offenen Fenster** (`kill <pid>` auf jedes Client, Endlosschleife
bis keins mehr da ist); Befehle gehen als **Shell-String** über `hyprctl dispatch exec` (Argumente aus `/proc/cmdline` ohne
Quoting, Fenstertitel als letzter Fallback); keine Ignore-/Positivliste (Discord, Steam-Spiele, Picker würden mitgespeichert
und neu gestartet); eine einzige „default“-Sitzung wird alle 60 s überschrieben (kein Verlauf, nicht atomar, nach einem
Absturz mit halbem Login-Zustand weg); Fenster werden nur per **identischem Titel** zugeordnet; `MoveWorkspaceToMonitor`
kann das Workspace-Schema (1/101/201) durcheinanderbringen; Start über Hyprlands `exec`, nicht `uwsm app`
(Wrapper-Skripte in `~/.local/bin` können installierte Programme nicht ersetzen); `hyprland`-Crate 0.4.0-beta.3 gegen
Hyprland 0.56 ungetestet (`.expect()` = Absturz bei Schemaänderung). Plus: ein dauerhaft laufender Daemon.
Stärken: Fenster werden per Workspace-Regel direkt beim Start platziert, doppelte PIDs (VS Code, Electron) werden
automatisch einmal gestartet, `--adjust-clients-only` verschiebt nur vorhandene Fenster.
