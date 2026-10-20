# bastian-shell

A cozy, warm desktop shell for **Hyprland**, built with [Quickshell](https://quickshell.org) (QML).
Think "wooden cabin in the evening": opaque warm-brown surfaces, a sparing ember accent, soft corners, no glass and no glow.

This is my personal daily driver on Fedora, published as-is. It is opinionated and wired to my setup
(three monitors, GoXLR, Hue lights, Elgato Key Light, Discord, Spotify). Everything personal (keys, accounts,
location, projects) lives in local, git-ignored files with an `.example` next to them. Take what you like.

## What's in it

- **Top bar** – media (Spotify), Discord call with camera tiles, CPU/RAM/GPU, light, sound mixer (GoXLR channels), network, downloads, updates, dev services, privacy dots, tray with its own menu.
  **Bar mode** (Super+Space) puts a letter on every chip; the letter opens that popout, and every popout works with arrows, Enter and Esc
- **Popouts** – sound, network, light (Hue, Key Light), resources, downloads, dev services, music, chat, tray, updates
- **Workspace bar** – workspaces across all monitors with live window previews, quick links, git status and today's project time per workspace; keyboard mode (tap Alt)
- **Dashboard** (tap Super) – clock & weather, agenda, mail, focus, Spotify, Discord, light & sound, notifications
- **Launcher** – apps, windows and projects without prefix; prefixes for projects (`#`), calculator (`=`), emoji (`:`),
  clipboard (`;`), files (`/`), browser tabs (`@`), passwords (`pw `), calendar (`cal `) and web searches (`g `, `yt `, `gh ` …, `?` lists them all)
- **Cheat sheet** – Super+K shows every keybinding, generated from the Hyprland config
- **Lock screen** – the shell locks itself (ext-session-lock, PAM), hyprlock as fallback; a matching Plasma lock screen package lives in `plasma/`
- **Own dialogs** – polkit agent, screen-share picker, file picker, crash card, "app not responding"
- **Focus & breaks** – focus mode, break reminder, project time
- **Theming** – one palette (`theme/palette.json`) feeds generators in `theme/gen/` for Qt/KDE, Kvantum, GTK, Kitty, Konsole,
  Starship, VS Code, Discord, the browser, Thunderbird, yazi, lazygit, the cursor and the wallpaper
- **Projects** – per-project color, ports and workspace layout (`projects/`, see `docs/knowledge/projects.md`)

## Requirements

- Fedora (tested on 44) with Hyprland 0.56 (COPR `sdegler/hyprland`) and uwsm
- Quickshell 0.3.x (COPR `errornointernet/quickshell`)
- Fonts: Inter, JetBrains Mono Nerd Font
- Optional integrations need their own setup, see `docs/setup/`

## Install

```sh
git clone https://github.com/Baaasty/bastian-shell ~/Workspace/bastian-shell
cd ~/Workspace/bastian-shell
cp secrets.example.json secrets.json      # fill in what you use; never committed
scripts/hypr install                       # links config into ~/.config, nothing system-wide
scripts/hypr check
```

Then pick the Hyprland (uwsm) session at login. `scripts/hypr uninstall` reverts everything.
Package lists for a fresh machine live in `system/` (`system/bootstrap` is a dry run by default, `--apply` runs it).
Colors and app themes: edit `theme/palette.json`, then `python3 -I theme/gen/all.py` (see `theme/README.md`).

The older KDE Plasma / KWin variant (`scripts/rice on|off`, `bridge/`, `plasma/`) is still in the tree but no longer the focus.

Keybindings: press **Super+K** in the session, or read [docs/knowledge/hotkeys.md](docs/knowledge/hotkeys.md).

## Layout

| Folder | Content |
|---|---|
| `shell/` | Quickshell config (`shell.qml`, `services/`, `components/`, `modules/`) |
| `hypr/` | Hyprland config (binds, rules, monitors) |
| `config/` | app configs and shell settings (launcher, breaks, Kitty, zsh, yazi) |
| `theme/` | palette and generators for all apps |
| `scripts/` | helpers called by the shell and keybindings |
| `docs/` | feature docs (mostly German) |
| `system/` | package lists and bootstrap for a fresh install |

Docs and code comments are mostly in German; the UI is English.

## License

[GPL-3.0-or-later](LICENSE). Parts are adapted from other projects, see [THIRD_PARTY.md](THIRD_PARTY.md).
