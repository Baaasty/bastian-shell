# Tastenkürzel

_Erzeugt aus `hypr/binds.conf` mit `scripts/hotkeys-md` – nicht von Hand ändern._

**Live ansehen: Super+K** (Keybind-Viewer, liest die Konfiguration bei jedem Öffnen; Suche tippt sofort).

## Schema

| Taste | Zuständig für |
|---|---|
| **Alt** | Workspace-Management (Alt+1…9, Alt+←/→, Alt antippen = Workspace-Modus); dazu Alt+Tab und Alt+F4 wie üblich |
| **Super** | Fenster-Management (Fokus ←/→, ↑ maximieren → Vollbild, ↓ zurück, Shift verschieben, Strg Größe, Super+Shift+V schweben, Monitore, Maus) |
| **Super+Alt** | Menüs und Programme öffnen, Topbar: Super+Alt+<Buchstabe> = Bar-Modus, dann derselbe Buchstabe |
| **Super+Leertaste** | Topbar betreten (Bar-Modus); die häufigsten Topbar-Ziele ohne Alt: Super+F/T/A/E/B/I |
| **Strg+Alt (+Shift)** | Notbremsen (Not-Aus, Power-Menü ohne Shell) |

Sonst nur Screenshots, Medientasten und ein paar Klassiker (Super+Enter/W/K/O/P/V, Super+L, Super+Esc).
Super allein antippen öffnet das Dashboard mit Suche (nur, wenn keine andere Taste dazwischen war).
Alt allein antippen (oder Alt+Esc) öffnet den Workspace-Modus der unteren Leiste.

## Modi (Tasten innerhalb der Shell)

| Modus | Tasten |
|---|---|
| **Bar-Modus** (Super+Leertaste) | Buchstabe an den Chips öffnet das Popout (Direktkürzel in Klammern): F Focus (Super+F) · T Tasks (Super+T) · A Agents (Super+A) · P Sharing (Super+Alt+P) · M Music (Super+Alt+M) · C Chat (Super+Alt+C) · V Dev (Super+Alt+V) · H Servers (Super+Alt+H) · R Resources (Super+Alt+R) · L Light (Super+Alt+L) · G Gear (Super+Alt+G) · S Sound (Super+Alt+S) · N Network (Super+Alt+N) · E Files (Super+E) · D Downloads (Super+Alt+D) · B Browser (Super+B) · I Settings (Super+I) · U Updates (Super+Alt+U) · Y Tray (Super+Alt+Y) · Z Notifications (Super+Alt+Z). Oder ←/→ bzw. Tab wählen, Enter/↓ öffnet. Esc oder nochmal Super+Leertaste = zu; Esc im Popout = zurück zum Chip |
| **In Popouts** | Pfeile/Tab wählen (Glut-Rahmen), Enter/Leertaste löst aus, Regler: Enter, dann ←/→, Esc zu. Per Taste geöffnet: Tastaturfokus, schließt nicht durch Weghovern |
| **Tray** (Super+Alt+Y) | ↑↓ Symbol, → zum Menü-Knopf (⋮) oder Auge, Enter; im Menü ↑↓, Enter/→ öffnet Untermenü, ←/Rücktaste zurück |
| **Benachrichtigungen** (Super+Alt+Z) | ↑↓ Karte, Enter öffnen, 1–3 Knöpfe, S später erinnern (dann 1–4), Entf/X wegklicken, Shift+A alle weg, Esc zu |
| **Workspace-Modus** (Alt antippen) | 1–9, ←/→, Enter, Entf, N, R, T, Q (Quicklinks + Git der Kachel), Esc |

## Windows

| Taste | Aktion |
|---|---|
| `Super + ←↑↓→` | Focus window |
| `Super + Shift + ← / →` | Move window |
| `Super + Shift + ↑`<br>`Alt + Shift + ↑` | Bigger: floating → tiled → maximized → fullscreen |
| `Super + Shift + ↓`<br>`Alt + Shift + ↓` | Smaller: fullscreen → maximized → tiled → floating |
| `Super + Ctrl + →` | Resize window: wider |
| `Super + Ctrl + ←` | Resize window: narrower |
| `Super + Ctrl + ↓` | Resize window: taller |
| `Super + Ctrl + ↑` | Resize window: shorter |
| `Super + Tab`<br>`Alt + Tab` | Next window |
| `Super + Shift + Tab`<br>`Alt + Shift + Tab` | Previous window |
| `Super + ^` | Next window of the same app |
| `Super + Shift + ^` | Previous window of the same app |
| `Super + Shift + V` | Toggle floating |
| `Super + S` | Toggle split |
| `Alt + F4` | Close window (quits Discord/Spotify too) |
| `Super + Q` | Close window (Discord/Spotify: back to the bar) |
| `Super + Ctrl + Esc` | Kill window |
| `Super + Shift + Esc` | Release input capture |

## Mouse

| Taste | Aktion |
|---|---|
| `Super + Mouse left` | Move window (drag) |
| `Super + Mouse right` | Resize window (drag) |

## Monitors

| Taste | Aktion |
|---|---|
| `Super + 1…3` | Focus monitor 1…3 |
| `Super + Shift + 1…3` | Move window to monitor 1…3 |

## Workspaces

| Taste | Aktion |
|---|---|
| `Alt + →` | Next workspace |
| `Alt + ←` | Previous workspace |
| `Alt + 1…9` | Go to workspace 1…9 |
| `Alt + Shift + 1…9` | Move window to workspace 1…9 |
| `Alt + tippen` | Workspace mode (tap Alt) |
| `Alt + Esc` | Workspace mode |

## Topbar

| Taste | Aktion |
|---|---|
| `Super + Space` | Bar mode (letter opens a popout) |
| `Super + F` | Focus |
| `Super + T` | Tasks |
| `Super + A` | Agents (Claude) |
| `Super + E` | Files |
| `Super + B` | Browser here: new tab, else new window |
| `Super + W` | Browser |
| `Super + I` | Settings |
| `Super + Alt + P` | Screen sharing: stop, forget |
| `Super + Alt + M` | Music (Spotify) |
| `Super + Alt + C` | Chat (Discord) |
| `Super + Alt + V` | Dev services |
| `Super + Alt + H` | Servers (consoles, upload, files, terminal) |
| `Super + Alt + R` | Resources |
| `Super + Alt + L` | Light |
| `Super + Alt + G` | Gear (devices) |
| `Super + Alt + S` | Sound mixer |
| `Super + Alt + N` | Network |
| `Super + Alt + D` | Downloads |
| `Super + Alt + U` | Updates (package manager) |
| `Super + Alt + Y` | Tray |
| `Super + Alt + Z` | Notifications (keyboard) |
| `Super + Alt + X` | Dismiss newest notification |

## Apps & menus

| Taste | Aktion |
|---|---|
| `Super + tippen` | Dashboard |
| `Super + Enter` | Terminal |
| `Super + Shift + Enter` | Drop-down terminal |
| `Super + V` | Clipboard history at the cursor (Enter pastes) |
| `Super + ·` | Emoji picker |
| `Super + K` | Keyboard shortcuts |
| `Super + P` | Package manager |
| `Super + O` | Passwords |
| `Super + Alt + K` | Layout menu |
| `Super + C` | Call cameras on/off |
| `Super + Alt + ←` | Call cameras: dock left |
| `Super + Alt + →` | Call cameras: dock right |
| `Super + Alt + ↑` | Call cameras: dock top |
| `Super + Alt + ↓` | Call cameras: dock bottom |

## Screenshots

| Taste | Aktion |
|---|---|
| `Print`<br>`Super + Shift + S` | Screenshot region |
| `Ctrl + Print` | Screenshot all monitors |
| `Super + R` | Screen recording |
| `Super + Shift + T` | Snip text (OCR) |
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
zeigt beides), dann die Topbar (Super+Leertaste, Direktkürzel, Popouts, Benachrichtigungen, Tray), dann die übrige Shell
(live aus `hypr/binds.conf` + Anleitungen zu Workspace-Modus und Launcher), darunter
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
- `shell.json` (`"group": "shell"`) hängt Anleitungen an die Shell-Kürzel; `"area": "topbar"` stellt einen Abschnitt in die
  Gruppe „Topbar“ (zusammen mit dem binds.conf-Abschnitt `Topbar`). Abschnitte mit `"auto"` füllt
  `shell/modules/keys/appkeys.py` selbst: `barLetters` (`shell/services/BarKeys.qml`), `launcherPrefixes`
  (`shell/modules/launcher/Launcher.qml`), `webShortcuts` (`config/launcher/web.json`).
- Kaputte Datei: nur sie fehlt, der Grund steht im Log (`qs log -p … | grep appkeys`).
- Testen ohne Fokuswechsel: `qs ipc --any-display -p <shell> call keys app discord ""` (tut so, als wäre Discord fokussiert).
