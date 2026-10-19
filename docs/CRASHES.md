# Absturz-Meldungen (statt DrKonqi)

Stürzt eine App ab, zeigt die Shell unten rechts auf DP-2 eine Karte im Desktop-Look statt des KDE-Fensters
DrKonqi (`drkonqi-coredump-gui`, Breeze).

## Was die Karte zeigt

- **„Discord crashed“**, darüber eine kleine Zeile: Prozessart (z. B. *Renderer*), Signal (`SIGSEGV`), Uhrzeit, „3rd time today“.
- Darunter, ob die App noch läuft: bei einem Kindprozess von Chromium/Electron (`--type=renderer`, `gpu-process` …)
  läuft die App oft weiter („Only a renderer – Discord is still running.“). Solche Karten gehen nach 30 s von selbst
  (nicht, solange die Maus drauf ist oder Details offen sind). Abstürze des Hauptprozesses bleiben bis Dismiss.
- **Nur Apps bekommen eine Karte** (eigene `.desktop`, bekannter Startname oder fester Name wie „Desktop portal“). CLI-Tools aus dem Terminal (pnpm, biome, sleep …) werden nur mitgezählt – `crash list` zeigt sie.
- **Restart** (nur wenn die App nicht mehr läuft): Discord/Spotify/Thunderbird/Equibop über `scripts/app-run`,
  sonst über die .desktop-Datei – immer über `Launch.qml` (eigene Unit, nie als Kind der Shell).
  Nie für Shell, Hyprland, Portale (die startet systemd selbst).
- **Details** klappt Programm, PID und den Anfang des Stack-Traces auf; „Open full report in terminal“ öffnet
  `coredumpctl info <pid>` im Terminal (`xdg-terminal-exec`).
- **Dismiss** schließt die Karte. Mehrere Abstürze derselben App = eine Karte (zeigt den neuesten), höchstens 3 Karten,
  darunter „+ n more crashed · dismiss all“.

## Woher die Daten kommen

`shell/services/Crashes.qml` liest das User-Journal, kein sudo, kein Polling:
- beim Start einmal `journalctl --user -t systemd-coredump --since today` (zählt nur, zeigt nichts),
- danach `journalctl --user -f -n 0 …` – jede neue Zeile ist ein neuer Absturz.

systemd-coredump schreibt jeden Absturz eines User-Prozesses (mit Stack-Trace) auch ins Journal des Users.
Ob die App noch läuft, prüft `pgrep -x <Prozessname>` – nur solange eine Karte steht (alle 5 s).
Ausnahme beim Start: ist die Shell selbst in den letzten 2 min abgestürzt, zeigt sie danach „Desktop shell crashed“.

Testen (ändert nichts am System):

```sh
Q="qs ipc --any-display -p ~/Workspace/bastian-shell/shell call crash"
$Q test           # Discord, Hauptprozess (Restart sichtbar)
$Q testRenderer   # Discord, nur Renderer
$Q details        # alle Karten auf-/zuklappen
$Q list           # Abstürze heute je App (ohne Stack-Traces)
$Q hide
```

Echter Test: `sh -c 'sleep 300 & p=$!; sleep 0.3; kill -SEGV $p'` → Karte „Sleep crashed“, kein DrKonqi.

## DrKonqi aus (nur Hyprland)

`scripts/hypr install` (oder einzeln `scripts/hypr drkonqi off`) legt ein Drop-in an:
`~/.config/systemd/user/drkonqi-coredump-launcher@.service.d/not-on-hyprland.conf`.
Darin eine `ExecCondition`: Läuft die Sitzung unter Hyprland **und** ist `desktop-shell-hyprland` aktiv, startet die
DrKonqi-Instanz nicht (Journal: „Skipped due to 'exec-condition'“). Unter Plasma oder ohne Shell kommt DrKonqi wie
immer. Der Coredump selbst bleibt erhalten (`coredumpctl list`).

- Zustand: `scripts/hypr drkonqi status`
- **Rückweg:** `scripts/hypr drkonqi on` (löscht das Drop-in, `daemon-reload`) – oder von Hand:
  `rm ~/.config/systemd/user/drkonqi-coredump-launcher@.service.d/not-on-hyprland.conf && systemctl --user daemon-reload`
- `scripts/hypr uninstall` entfernt es mit.

Nicht abgedeckt: KDE-Apps, die ohne systemd-coredump direkt DrKonqi starten (KCrash-Rückfall). Unter Fedora melden
KDE-Apps über systemd-coredump, das sollte also selten sein – falls doch ein Breeze-Fenster kommt: melden.
