#!/usr/bin/env bash
# Baut das XCursor-Theme "Desktop" aus den SVGs in diesem Ordner.
# Benötigt: rsvg-convert (librsvg), xcursorgen, python3
set -euo pipefail
HERE="$(cd "$(dirname "$0")" && pwd)"
THEME="${1:-$HOME/.local/share/icons/Desktop}"
SIZES=(24 32 48 64)
BUILD="$(mktemp -d)"
mkdir -p "$THEME/cursors"
export THEME_DIR="$THEME"

python3 - "$HERE" "$BUILD" "${SIZES[@]}" <<'PY'
import json, os, sys, subprocess
here, build, *sizes = sys.argv[1:]
sizes = [int(s) for s in sizes]
hot = json.load(open(os.path.join(here, 'hotspots.json')))
anim = hot['_animation']
names = [n for n in hot if not n.startswith('_')]
# statische Cursor + Animationen (ein .cursor-Config je Zielname)
targets = {}
for n in names:
    e = hot[n]
    if 'frame_of' in e:
        targets.setdefault(e['frame_of'], []).append(n)
    else:
        targets[n] = [n]
for target, frames in targets.items():
    frames.sort()
    lines = []
    for f in frames:
        hx, hy = hot[f]['hotspot']['x'], hot[f]['hotspot']['y']
        for s in sizes:
            png = os.path.join(build, f'{f}-{s}.png')
            subprocess.run(['rsvg-convert', '-w', str(s), '-h', str(s), '-o', png, os.path.join(here, f + '.svg')], check=True)
            delay = anim[target]['delay_ms'] if target in anim else 0
            k = s / 32
            lines.append(f'{s} {round(hx*k)} {round(hy*k)} {png}' + (f' {delay}' if delay else ''))
    cfg = os.path.join(build, target + '.cursor')
    open(cfg, 'w').write('\n'.join(lines) + '\n')
    subprocess.run(['xcursorgen', cfg, os.path.join(os.environ['THEME_DIR'], 'cursors', target)], check=True)
# Aliasse als Symlinks
cd = os.path.join(os.environ['THEME_DIR'], 'cursors')
for n in names:
    for a in hot[n].get('aliases', []):
        p = os.path.join(cd, a)
        if not os.path.exists(p):
            os.symlink(n, p)
# X11 erwartet zusätzlich "left_ptr", "watch", "progress" etc.
for a, n in {'watch': 'wait', 'left_ptr_watch': 'progress', 'pointer': 'pointer', 'hand': 'pointer', 'sb_up_arrow': 'ns-resize', 'sb_down_arrow': 'ns-resize', 'sb_left_arrow': 'ew-resize', 'sb_right_arrow': 'ew-resize', 'pirate': 'not-allowed', 'dnd-move': 'move', 'dnd-ask': 'help', 'copy': 'copy', 'alias': 'alias'}.items():
    p = os.path.join(cd, a)
    if not os.path.exists(p):
        os.symlink(n, p)
PY

cat > "$THEME/index.theme" <<EOF
[Icon Theme]
Name=Desktop
Comment=Desktop – cozy, warm, cream on dark wood
Inherits=breeze_cursors
EOF
cat > "$THEME/cursor.theme" <<EOF
[Icon Theme]
Name=Desktop
Inherits=breeze_cursors
EOF
rm -rf "$BUILD"
echo "Theme gebaut: $THEME"
