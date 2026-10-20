# Techstack – bastian-shell

Stand: 2026-10-19 · Leitlinie: Eigene Shell über einem fertigen Fundament – Fenster, Einstellungen und Fallback liefert der Compositor bzw. Plasma, und alles bleibt mit einem Befehl rückgängig.

Hier steht **warum** – nicht die Versionsliste. Versionen und genaue Pakete zeigt der Code (`package.json`,
`bun.lock`, `pyproject.toml`); nichts davon hier abschreiben.

| Bereich | Wahl | Warum |
| --- | --- | --- |
| Shell | Quickshell 0.3.2 (QML, Layer-Shell) aus COPR `errornointernet/quickshell` | läuft über dem Compositor, nicht statt Plasma; 0.3.2, weil Fedoras 0.2.1-Snapshot keinen Blur kann (alte SPEC §4) |
| Sitzung (aktuell) | Hyprland 0.56 aus COPR `sdegler/hyprland` unter uwsm, Konfiguration in `hypr/` | mehr Leistung (360 Hz, NVIDIA) bei derselben Shell (`docs/knowledge/hyprland.md`) |
| Fundament | Plasma bleibt installiert (Rückfall-Sitzung, ohne Shell); der KWin-Weg ist entfernt (Git-Tag `kwin-final`) | Bluetooth-/WLAN-Dienste, Dolphin, Dateidialog und Qt-Theme hängen an Plasma (`docs/setup/migrate.md`) |
| Fenster / Workspaces | `Quickshell.Hyprland` (`shell/services/Hypr.qml`) | Hyprland liefert Fenster und Workspaces direkt an Quickshell; KWin fehlen foreign-toplevel und ext-workspace (alte SPEC §4) |
| Kürzel | `hypr/binds.conf` → `qs ipc … call` | ein Kürzel = ein Aufruf an die laufende Instanz; Titel `# …` in `binds.conf` speisen Super+K und `docs/knowledge/hotkeys.md`. KWin kennt kein Hyprland-GlobalShortcut |
| D-Bus | Kommandozeile aus QML und Skripten (`qdbus-qt6`, `gdbus`, `busctl --user`) | reicht für Aufrufe; `qdbus6` gibt es auf Fedora nicht (CLAUDE.md). Die in alte SPEC §4 geplante rice-bridge (Python, dbus_next) für D-Bus-Exporte ist nicht gebaut |
| Hilfsprozesse | Python 3 (fast nur Standardbibliothek, Start mit `python3 -I`) und Bash in `scripts/`, als Kindprozess mit JSON-Zeilen über stdin/stdout (z. B. `scripts/discord-bridge`, `scripts/procs`) | nur für das, was QML nicht kann (Sockets, `/proc`, Discord-IPC) |
| Theme | `theme/palette.json` + Generatoren `theme/gen/*.py` | eine Farbquelle für Shell, KDE/Qt, GTK, Terminals, Hyprland (`look.conf`), Apps; jede App behält ihren eigenen Kontrast (`theme/README.md`) |
| Qt-Stil | Kvantum (`kvantum`, `kvantum-qt5`), Theme „DesktopHearth“ aus `theme/gen/kvantum.py` (Basis KvFlat, GPL-3.0) | Breeze malt Menüs per Farbschema nicht änderbar (kleine Ecken, Akzent-Rahmen als Hover); Kvantum zeichnet aus SVG, also Palette-Radien und ruhiger Hover ohne eigenen Qt-Stil. Rückweg `scripts/kvantum-theme off` |
| Lockscreen | eigene Sperre `shell/modules/lock` (ext-session-lock, PAM), Notfall hyprlock; Login-Bildschirm: Theme `plasma/loginscreen/` für den Plasma Login Manager | KWin hat kein ext-session-lock (CLAUDE.md); unter Hyprland übernimmt hyprlock, wenn die Shell nicht antwortet (`docs/knowledge/hyprland.md`) |
| Dienst | systemd-User-Unit `desktop-shell-hyprland.service`, `Restart=on-failure` | bekannte Quickshell-Abstürze bei Suspend/Resume und wenn ein Monitor wegfällt (NVIDIA, alte SPEC §4) |
| Apps starten | `uwsm app --`, sonst `systemd-run --user --scope` (`shell/services/Launch.qml`); RPM zuerst, Flatpak-Fallback über `scripts/app-run` | gestartete Apps leben in eigener Unit und sterben nicht mit, wenn Quickshell neu startet |
| Qualität | `scripts/check` (Tests unter `scripts/tests/` + qmllint) als pre-commit-Hook mit Secrets-Sperre (`.githooks/pre-commit`) | ein Befehl vor jedem Commit; Secrets nie committen |

## Bewusst nicht

- **Fedoras Quickshell 0.2.1** – kann keinen Blur.
- **Glas, Blur, Transparenz, Glühen in hearth** – Stilregel: alle Flächen deckend (CLAUDE.md); Blur nur noch in der alten Variante ember (`scripts/rice variant ember`).
- **Gruvbox** – passt nicht zum Stil (CLAUDE.md „Stil“).
- **Apps direkt aus der Shell starten** – sie sterben sonst mit, wenn Quickshell abstürzt oder neu startet.
- **Helligkeit selbst per `ddcutil` schreiben** – PowerDevil macht DDC/CI (alte SPEC §2.5).
- **Spicetify für Spotify** – Aufwand und Bruchrisiko (Flatpak-Pfad, Updates) gegen ein bisschen Farbe; Bedienung läuft über die Shell (`docs/knowledge/theming.md`).
- **KMail/Kontact** – Akonadi + Indexer schwer, viel Ablenkung; in `system/packages/dnf.txt` abgewählt (`docs/DECISIONS.md`).
- **Equibop** – ersetzt durch normales Discord (RPM) mit eigenem Equicord-Build (`docs/DECISIONS.md`).

## Qualität

Ein Befehl für alles – steht in CLAUDE.md „Qualität“. Hier nur, warum genau diese Checks.

- **Tests (`node` / `python3 -I`)** prüfen die reine Logik ohne laufende Shell (z. B. Zeitfenster/Snooze in `timewin.js`, Sortierung im Ressourcen-Popout, `netinfo`).
- **qmllint** findet QML-Fehler, ohne die Shell zu starten; wird übersprungen, solange `qt6-qtdeclarative-devel` fehlt (braucht `sudo`).
- **Secrets-Sperre im Hook**, weil Secrets nur in `secrets.json` stehen dürfen und nie ins Repo.
- Aussehen und Bedienung prüft kein Check: dafür `qs -p ~/Workspace/bastian-shell/shell` + Screenshot von Bastian.
