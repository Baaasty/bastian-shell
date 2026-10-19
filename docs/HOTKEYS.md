# Tastenkürzel

_Erzeugt aus `hypr/binds.conf` mit `scripts/hotkeys-md` – nicht von Hand ändern._

**Live ansehen: Super+K** (Keybind-Viewer, liest die Konfiguration bei jedem Öffnen; Suche tippt sofort).

## Schema

| Taste | Zuständig für |
|---|---|
| **Super** | Fenster, Monitore, Shell (Dashboard, Apps) |
| **Alt** | Workspaces (Alt+1…9, Alt+←/→); dazu Alt+Tab und Alt+F4 wie üblich |
| **Super+Alt** | Zusatzwerkzeuge der Shell (Zwischenablage, Fokus-Modus) |
| **Strg+Alt (+Shift)** | Notbremsen (Not-Aus, Power-Menü ohne Shell) |

Super allein antippen öffnet das Dashboard mit Suche (nur, wenn keine andere Taste dazwischen war).
Alt allein antippen (oder Alt+Esc) öffnet den Workspace-Modus der unteren Leiste.

## Modi (Tasten innerhalb der Shell)

| Modus | Tasten |
|---|---|
| **Bar-Modus** (Super+B) | Buchstabe an den Chips öffnet das Popout: S Sound · N Netz · L Licht · R Ressourcen · D Downloads · V Dev · M Musik · C Chat · T Tray · U Updates · H Server · A Claude · O To-dos · F Fokus · Z Benachrichtigungen. Oder ←/→ bzw. Tab wählen, Enter/↓ öffnet. Esc oder nochmal Super+B = zu; Esc im Popout = zurück zum Chip |
| **In Popouts** | Pfeile/Tab wählen (Glut-Rahmen), Enter/Leertaste löst aus, Regler: Enter, dann ←/→, Esc zu. Per Taste geöffnet: Tastaturfokus, schließt nicht durch Weghovern |
| **Tray** (Bar-Modus T) | ↑↓ Symbol, → zum Menü-Knopf (⋮) oder Auge, Enter; im Menü ↑↓, Enter/→ öffnet Untermenü, ←/Rücktaste zurück |
| **Benachrichtigungen** (Super+Alt+Z) | ↑↓ Karte, Enter öffnen, 1–3 Knöpfe, S später erinnern (dann 1–4), Entf/X wegklicken, Shift+A alle weg, Esc zu |
| **Workspace-Modus** (Alt antippen) | 1–9, ←/→, Enter, Entf, N, R, T, Q (Quicklinks + Git der Kachel), Esc |

## Shell

| Taste | Aktion |
|---|---|
| `Super + tippen` | Dashboard |
| `Super + Tab`<br>`Alt + Tab` | Next window |
| `Super + Shift + Tab`<br>`Alt + Shift + Tab` | Previous window |
| `Super + ^` | Next window of the same app |
| `Super + Shift + ^` | Previous window of the same app |
| `Super + Alt + V` | Clipboard history |
| `Super + ·` | Emoji picker |
| `Super + Alt + F` | Focus mode |
| `Super + Alt + G` | Game mode (bar off, do not disturb) |
| `Super + Alt + B` | Wind down (evening routine) |
| `Super + Alt + R` | Day recap |
| `Super + Alt + T` | Project time this week |
| `Super + Alt + N` | Night light on/off |
| `Super + K` | Keyboard shortcuts |
| `Super + P` | Package manager |
| `Super + O` | Passwords |
| `Super + N` | Park a thought |
| `Super + B` | Bar mode (letter opens a popout) |
| `Super + Alt + S` | Sound mixer |
| `Super + Alt + L` | Light |
| `Super + Alt + U` | Servers (upload, files, terminal) |
| `Super + Alt + Z` | Notifications (keyboard) |
| `Super + Alt + X` | Dismiss newest notification |
| `Super + C` | Call cameras on/off |
| `Super + Ctrl + ←` | Call cameras: dock left |
| `Super + Ctrl + →` | Call cameras: dock right |
| `Super + Ctrl + ↑` | Call cameras: dock top |
| `Super + Ctrl + ↓` | Call cameras: dock bottom |

## Workspaces

| Taste | Aktion |
|---|---|
| `Alt + →` | Next workspace |
| `Alt + ←` | Previous workspace |
| `Alt + 1…9` | Go to workspace 1…9 |
| `Alt + Shift + 1…9` | Move window to workspace 1…9 |
| `Alt + tippen` | Workspace mode (tap Alt) |
| `Alt + Esc` | Workspace mode |

## Monitors

| Taste | Aktion |
|---|---|
| `Super + 1…3` | Focus monitor 1…3 |
| `Super + Shift + 1…3` | Move window to monitor 1…3 |

## Windows

| Taste | Aktion |
|---|---|
| `Super + ←↑↓→` | Focus window |
| `Super + Shift + ←↑↓→` | Move window |
| `Super + F` | Maximize |
| `Super + Shift + F` | Fullscreen |
| `Super + V` | Toggle floating |
| `Super + S` | Toggle split |
| `Alt + F4` | Close window (quits Discord/Spotify too) |
| `Super + Q` | Close window (Discord/Spotify: back to the bar) |
| `Super + Ctrl + Esc` | Kill window |
| `Super + Shift + Esc` | Release input capture |
| `Super + Mouse left` | Move window (drag) |
| `Super + Mouse right` | Resize window (drag) |
| `Super + Alt + →` | Resize window: wider |
| `Super + Alt + ←` | Resize window: narrower |
| `Super + Alt + ↓` | Resize window: taller |
| `Super + Alt + ↑` | Resize window: shorter |

## Apps

| Taste | Aktion |
|---|---|
| `Super + Enter` | Terminal |
| `Super + E` | File manager |
| `Super + Shift + Enter` | Drop-down terminal |
| `Super + Alt + K` | Layout menu |

## Screenshots

| Taste | Aktion |
|---|---|
| `Print`<br>`Super + Shift + S` | Screenshot region |
| `Ctrl + Print` | Screenshot all monitors |
| `Super + R` | Screen recording |
| `Super + Shift + T` | Snip text (OCR) |
| `Super + Shift + C` | Pick color |
| `Super + Shift + P` | Pin screenshot |

## System

| Taste | Aktion |
|---|---|
| `Super + Esc` | Power menu |
| `Super + L` | Lock screen |
| `Super + Shift + M` | Log out |
| `Ctrl + Alt + Shift + Q` | Panic: shell off |
| `Ctrl + Alt + Del` | Power menu (works without the shell) |

## Media keys

| Taste | Aktion |
|---|---|
| `AudioMute` | Mute |
| `AudioMicMute`<br>`Super + AudioMute` | Mute microphone |
| `AudioPlay / AudioPause` | Play / pause |
| `AudioNext` | Next track |
| `AudioPrev` | Previous track |
| `AudioStop` | Stop |
| `MonBrightnessUp` | Brightness up |
| `MonBrightnessDown` | Brightness down |
| `Shift + MonBrightnessUp` | Brightness up (fine) |
| `Shift + MonBrightnessDown` | Brightness down (fine) |
| `PowerOff` | Power menu |

## App-Kürzel und Cheat-Sheet (Super+K)

Super+K ist ein Nachschlagewerk für alles: oben die App, die beim Öffnen fokussiert war (*focused app*; Kitty mit yazi/lazygit
zeigt beides), dann die Shell (live aus `hypr/binds.conf` + Anleitungen zu Bar, Popouts, Workspace-Modus, Launcher), darunter
alle Programme. Sofort tippen = Suche über App-Name, Tasten und Beschreibung (`upload`, `discord mute`, `ctrl+shift+u`).
↑/↓ und Bild↑/↓ scrollen, Tab/Shift+Tab springt zur nächsten/vorigen App, Esc schließt.

Drin: Helium (+ Vimium C), Discord, VS Code, Dolphin, Kitty, sshs, yazi, lazygit, Thunderbird, Spotify.
Eine Datei pro Programm in `config/appkeys/<app>.json`, von Hand pflegbar (nach dem Speichern reicht erneut Super+K):

```json
{ "name": "Discord", "about": "kurzer Hinweis", "order": 20,
  "match": { "class": ["discord"], "title": "^optional-regex" },
  "sections": [ { "name": "Navigate", "keys": [
      { "keys": "Ctrl+K", "title": "Quick switcher", "note": "optional" } ] } ] }
```

- `match.class`: Hyprland-Klasse, klein geschrieben (`hyprctl clients -j` → `class`). `match.title`: Regex auf den Fenstertitel
  (yazi/lazygit laufen in Kitty). Mehrere Treffer: Titel-Treffer zuerst, dann die App, deren Klassenliste die Klasse weiter vorn hat.
- Tasten: `Ctrl+Shift+M` · Alternativen als Liste `["Ctrl+Tab", "Ctrl+PgDn"]` · Leerzeichen = mehrere Tasten (`g g`, `Alt+↑ ↓`) ·
  `Ctrl+Plus` für + · `Alt (tap)` = Modifier allein antippen.
- `shell.json` (`"group": "shell"`) hängt Anleitungen an die Shell-Kürzel. Abschnitte mit `"auto"` füllt
  `shell/modules/keys/appkeys.py` selbst: `barLetters` (`shell/services/BarKeys.qml`), `launcherPrefixes`
  (`shell/modules/launcher/Launcher.qml`), `webShortcuts` (`config/launcher/web.json`).
- Kaputte Datei: nur sie fehlt, der Grund steht im Log (`qs log -p … | grep appkeys`).
- Testen ohne Fokuswechsel: `qs ipc --any-display -p <shell> call keys app discord ""` (tut so, als wäre Discord fokussiert).
