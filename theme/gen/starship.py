#!/usr/bin/env python3
"""theme/palette.json -> Starship-Prompt (theme/out/starship.toml).

Ruhig, zwei Zeilen (Luft davor per add_newline):
  ~/Workspace/desktop  main !2 ?1  󰔟 4s  ✘ 1                          17:42:08
  ❯
Pfad Creme (Repo-Name fett), Git gedämpft, Dauer/Fehlercode nur wenn nötig, ❯ im Akzent (Amber nach Fehler).
Die Uhrzeit steht per $fill rechts in Zeile 1: right_format kann bash ohne ble.sh nicht.
Aufruf aus dem Repo-Root: python3 -I theme/gen/starship.py [variante]
"""
import pathlib
import sys

sys.path.insert(0, str(pathlib.Path(__file__).resolve().parent))
from _pal import MARK, OUT, contrast, load, write  # noqa: E402
import _term  # noqa: E402

src, variant, t = load()

palette = {
    "accent": t["accent"],
    "text": t["text"],
    "muted": t["textMuted"],
    "faint": t["textFaint"],
    "warning": t["warning"],
    "success": t["success"],
}

# Kontrast zum Terminal-Hintergrund (Kitty/Konsole) prüfen: alle Prompt-Farben >= 4,5:1
term_bg = _term.colors(src, t)["bg"]
for name, col in palette.items():
    if contrast(col, term_bg) < 4.5:
        print(f"  Warnung: {name} {col} hat nur {contrast(col, term_bg):.2f}:1 auf {term_bg}")

text = f'''# {MARK} ({variant}) – nicht von Hand ändern.
# Neu erzeugen: python3 -I theme/gen/starship.py
"$schema" = "https://starship.rs/config-schema.json"

add_newline = true
palette = "desktop"
format = """
$username$hostname$directory$git_branch$git_state$git_status$cmd_duration$status$jobs$fill$time\\
$line_break$character"""
continuation_prompt = "[·](faint) "

[palettes.desktop]
{chr(10).join(f'{k} = "{v}"' for k, v in palette.items())}

# nur per SSH/als root sichtbar
[username]
style_user = "muted"
style_root = "warning"
format = "[$user]($style)[@](faint)"

[hostname]
style = "muted"
format = "[$hostname]($style) "

# ~/W/desktop/theme · im Repo: desktop/theme/gen (Repo-Name fett, Elternordner abgekürzt)
[directory]
style = "text"
truncation_length = 3
truncation_symbol = ""
fish_style_pwd_dir_length = 1
truncate_to_repo = true
before_repo_root_style = "faint"
repo_root_style = "bold text"
repo_root_format = "[$before_root_path]($before_repo_root_style)[$repo_root]($repo_root_style)[$path]($style)[$read_only]($read_only_style) "
read_only = " 󰌾"
read_only_style = "faint"
format = "[$path]($style)[$read_only]($read_only_style) "

[git_branch]
symbol = " "
style = "muted"
format = "[$symbol$branch(:$remote_branch)]($style) "

[git_state]
style = "warning"
format = "[$state( $progress_current/$progress_total)]($style) "

# Status-Zeichen mit Anzahl, gedämpft: !2 ?1 ⇡3
[git_status]
style = "faint"
format = "([$all_status$ahead_behind]($style))"
conflicted = "=${{count}} "
ahead = "⇡${{count}} "
behind = "⇣${{count}} "
diverged = "⇡${{ahead_count}}⇣${{behind_count}} "
untracked = "?${{count}} "
stashed = "*${{count}} "
modified = "!${{count}} "
staged = "+${{count}} "
renamed = "»${{count}} "
deleted = "-${{count}} "

# erst ab 2 s
[cmd_duration]
min_time = 2000
style = "faint"
format = "[󰔟 $duration]($style) "

# Fehlercode nur bei Fehler, Amber (nie Rot)
[status]
disabled = false
style = "warning"
symbol = "✘ "
format = "[$symbol$status]($style) "

[jobs]
style = "faint"
symbol = "✦"
format = "[$symbol$number]($style) "

[fill]
symbol = " "

[time]
disabled = false
time_format = "%H:%M:%S"
style = "faint"
format = "[$time]($style)"

[character]
success_symbol = "[❯](accent)"
error_symbol = "[❯](warning)"
vimcmd_symbol = "[❮](success)"
'''

print(f"Starship ({variant}):")
write(OUT / "starship.toml", text)
