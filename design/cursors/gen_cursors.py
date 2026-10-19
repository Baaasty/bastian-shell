#!/usr/bin/env python3
"""Hütte cursor set – generates 32x32-viewBox SVGs + hotspots.json."""
import json, os, math

OUT = os.path.dirname(os.path.abspath(__file__))
os.makedirs(OUT, exist_ok=True)

CREAM = '#F2E7D8'
DARK = '#3A2619'
EMBER = '#D15A32'
EMBER2 = '#F0A070'
SW = 1.7  # stroke width

HEAD = ('<svg xmlns="http://www.w3.org/2000/svg" viewBox="0 0 32 32" width="32" height="32">'
        '<defs><filter id="s" x="-20%" y="-20%" width="140%" height="150%">'
        '<feDropShadow dx="0" dy="1" stdDeviation="1.0" flood-color="#000000" flood-opacity="0.34"/>'
        '</filter></defs>')
TAIL = '</svg>'

def shape(d, fill=CREAM, stroke=DARK, sw=SW, extra=''):
    return (f'<path d="{d}" fill="{fill}" stroke="{stroke}" stroke-width="{sw}" '
            f'stroke-linejoin="round" stroke-linecap="round" {extra}/>')


def rp(pts, r=1.6, rtip=None, tip_index=0):
    """closed polygon with rounded corners (quadratic bezier at each vertex)"""
    n = len(pts); d = ''
    for i in range(n):
        p0, p1, p2 = pts[i-1], pts[i], pts[(i+1) % n]
        rr = rtip if (rtip is not None and i == tip_index) else r
        for q in (p0, p2):
            L = math.hypot(q[0]-p1[0], q[1]-p1[1]); rr = min(rr, 0.45*L)
        def towards(a, b, t):
            L = math.hypot(b[0]-a[0], b[1]-a[1]); return (a[0]+(b[0]-a[0])*t/L, a[1]+(b[1]-a[1])*t/L)
        a = towards(p1, p0, rr); b = towards(p1, p2, rr)
        d += ('M' if i == 0 else 'L') + f'{a[0]:.2f} {a[1]:.2f} '
        d += f'Q{p1[0]:.2f} {p1[1]:.2f} {b[0]:.2f} {b[1]:.2f} '
    return d + 'Z'

def g(content, rot=0, cx=16, cy=16, shadow=True):
    f = ' filter="url(#s)"' if shadow else ''
    t = f' transform="rotate({rot} {cx} {cy})"' if rot else ''
    return f'<g{f}{t}>{content}</g>'

# ---- primitives --------------------------------------------------------
ARROW = rp([(5,3.5),(5,25),(10.4,20.7),(14,28.2),(18.8,26.1),(15.2,19),(22.6,19)], r=2.3, rtip=1.2)

def arrow(extra=''):
    return g(shape(ARROW) + extra)

def badge_box(x=18, y=18, w=11, h=11, r=3.5):
    return f'<rect x="{x}" y="{y}" width="{w}" height="{h}" rx="{r}" fill="{CREAM}" stroke="{DARK}" stroke-width="{SW}"/>'

def line(d, stroke=DARK, sw=1.8):
    return f'<path d="{d}" fill="none" stroke="{stroke}" stroke-width="{sw}" stroke-linecap="round" stroke-linejoin="round"/>'

def double_arrow(rot=0):
    # vertical double arrow centred at 16,16
    d = rp([(16,3),(21.6,9.3),(18.1,9.3),(18.1,22.7),(21.6,22.7),(16,29),(10.4,22.7),(13.9,22.7),(13.9,9.3),(10.4,9.3)], r=1.5, rtip=1.1)
    return g(shape(d), rot)

def quad_arrow(dots=False):
    d = rp([(16,2.5),(20.4,7.2),(17.7,7.2),(17.7,14.3),(24.8,14.3),(24.8,11.6),(29.5,16),(24.8,20.4),(24.8,17.7),
            (17.7,17.7),(17.7,24.8),(20.4,24.8),(16,29.5),(11.6,24.8),(14.3,24.8),(14.3,17.7),(7.2,17.7),(7.2,20.4),
            (2.5,16),(7.2,11.6),(7.2,14.3),(14.3,14.3),(14.3,7.2),(11.6,7.2)], r=1.3)
    s = shape(d)
    if dots:
        s += f'<circle cx="16" cy="16" r="1.6" fill="{DARK}"/>'
    return g(s)

def ibeam(rot=0):
    d = ('M11 4.5 C11 3.6 11.6 3 12.5 3 L14 3 C14.9 3 15.5 3.6 15.5 4.5 L15.5 5 L16.5 5 L16.5 4.5 '
         'C16.5 3.6 17.1 3 18 3 L19.5 3 C20.4 3 21 3.6 21 4.5 C21 5.4 20.4 6 19.5 6 L18.3 6 '
         'L18.3 26 L19.5 26 C20.4 26 21 26.6 21 27.5 C21 28.4 20.4 29 19.5 29 L18 29 '
         'C17.1 29 16.5 28.4 16.5 27.5 L16.5 27 L15.5 27 L15.5 27.5 C15.5 28.4 14.9 29 14 29 '
         'L12.5 29 C11.6 29 11 28.4 11 27.5 C11 26.6 11.6 26 12.5 26 L13.7 26 L13.7 6 L12.5 6 '
         'C11.6 6 11 5.4 11 4.5 Z')
    return g(shape(d), rot)

def crosshair():
    s = ''
    for d in ['M16 2.5 L16 11', 'M16 21 L16 29.5', 'M2.5 16 L11 16', 'M21 16 L29.5 16']:
        s += line(d, CREAM, 3.2) + line(d, DARK, 1.2)
    s += f'<circle cx="16" cy="16" r="2.4" fill="none" stroke="{CREAM}" stroke-width="2.6"/>'
    s += f'<circle cx="16" cy="16" r="2.4" fill="none" stroke="{DARK}" stroke-width="1.2"/>'
    return g(s)

def pointer_hand():
    d = ('M12.2 3.2 C13.5 3.2 14.4 4.1 14.4 5.4 L14.4 14.2 L16 14.2 C16 13.1 16.9 12.4 17.9 12.4 '
         'C18.9 12.4 19.6 13 19.8 13.9 C20.2 13.5 20.8 13.3 21.4 13.3 C22.5 13.3 23.3 14 23.4 15.1 '
         'C23.8 14.9 24.2 14.8 24.6 14.8 C25.8 14.8 26.6 15.7 26.6 16.9 L26.6 22.2 '
         'C26.6 26.2 23.6 29 19.4 29 L16.6 29 C14 29 12.1 27.9 10.7 26 L5.9 19.6 '
         'C5.1 18.5 5.3 17.2 6.3 16.5 C7.3 15.8 8.6 16 9.4 17 L10 17.8 L10 5.4 '
         'C10 4.1 10.9 3.2 12.2 3.2 Z')
    s = shape(d)
    s += line('M17.9 18.6 L17.9 22.6 M20.8 18.6 L20.8 22.6 M23.7 18.6 L23.7 22.6', DARK, 1.2)
    return g(s)

def grab_hand():
    d = ('M9.2 10.6 C9.2 9.5 10.1 8.7 11.1 8.7 C12.1 8.7 12.9 9.5 12.9 10.6 L12.9 14 L13.9 14 '
         'L13.9 7.4 C13.9 6.2 14.8 5.4 15.9 5.4 C17 5.4 17.9 6.2 17.9 7.4 L17.9 14 L18.9 14 '
         'L18.9 8.4 C18.9 7.3 19.8 6.5 20.8 6.5 C21.9 6.5 22.8 7.3 22.8 8.4 L22.8 14.6 L23.8 14.6 '
         'L23.8 11 C23.8 9.9 24.7 9.1 25.7 9.1 C26.7 9.1 27.6 9.9 27.6 11 L27.6 19.4 '
         'C27.6 24.2 24.2 27.8 19.4 27.8 L16.2 27.8 C13.6 27.8 11.7 26.8 10.2 24.8 L5.6 19.2 '
         'C4.8 18.2 5 16.9 6 16.2 C7 15.5 8.3 15.7 9.1 16.7 L9.2 16.8 Z')
    return g(shape(d))

def grabbing_hand():
    d = ('M8.6 14.6 C8.6 13.5 9.5 12.6 10.6 12.6 L11.4 12.6 C11.4 11.3 12.4 10.3 13.7 10.3 '
         'C14.2 10.3 14.7 10.5 15.1 10.8 C15.5 9.9 16.4 9.3 17.4 9.3 C18.6 9.3 19.6 10.1 19.8 11.2 '
         'C20.2 11 20.7 10.9 21.2 10.9 C22.6 10.9 23.7 12 23.7 13.4 L23.7 14 L24.5 14 '
         'C25.9 14 27 15.1 27 16.5 L27 20.2 C27 24.6 23.9 27.8 19.4 27.8 L16 27.8 '
         'C13.4 27.8 11.5 26.8 10.1 24.9 L6.4 20.2 C5.7 19.2 5.9 17.9 6.9 17.2 '
         'C7.5 16.8 8.1 16.7 8.6 16.8 Z')
    s = shape(d)
    s += line('M11.4 12.6 L11.4 15.2 M15.3 10.8 L15.3 14.6 M19.8 11.2 L19.8 14.4 M23.7 14 L23.7 16', DARK, 1.2)
    return g(s)

def magnifier(sign):
    s = f'<circle cx="13.5" cy="13.5" r="8.5" fill="{CREAM}" stroke="{DARK}" stroke-width="{SW}"/>'
    s += line('M19.8 19.8 L27.5 27.5', CREAM, 5.2) + line('M19.8 19.8 L27.5 27.5', DARK, 2.4)
    s += line('M9.5 13.5 L17.5 13.5', DARK, 1.8)
    if sign == '+':
        s += line('M13.5 9.5 L13.5 17.5', DARK, 1.8)
    return g(s)

def circle_slash(cx=16, cy=16, r=9.5):
    s = f'<circle cx="{cx}" cy="{cy}" r="{r}" fill="{CREAM}" stroke="{DARK}" stroke-width="{SW}"/>'
    s += f'<circle cx="{cx}" cy="{cy}" r="{r-3.2}" fill="none" stroke="{DARK}" stroke-width="2.2"/>'
    k = (r - 3.2) * 0.7071
    s += line(f'M{cx-k} {cy-k} L{cx+k} {cy+k}', DARK, 2.2)
    return s

def ring_frames(cx, cy, r, sw, n=12):
    """ember loading ring: n frames, glowing arc rotating"""
    frames = []
    for i in range(n):
        a = i * (360 / n)
        track = f'<circle cx="{cx}" cy="{cy}" r="{r}" fill="none" stroke="{CREAM}" stroke-width="{sw+2.2}"/>'
        track += f'<circle cx="{cx}" cy="{cy}" r="{r}" fill="none" stroke="{DARK}" stroke-width="{sw+0.6}" opacity="0.55"/>'
        circ = 2 * math.pi * r
        arc = (f'<circle cx="{cx}" cy="{cy}" r="{r}" fill="none" stroke="{EMBER}" stroke-width="{sw}" '
               f'stroke-linecap="round" stroke-dasharray="{circ*0.38:.2f} {circ:.2f}" '
               f'transform="rotate({a-90:.1f} {cx} {cy})"/>')
        glow = (f'<circle cx="{cx}" cy="{cy}" r="{r}" fill="none" stroke="{EMBER2}" stroke-width="{sw*0.45}" '
                f'stroke-linecap="round" stroke-dasharray="{circ*0.18:.2f} {circ:.2f}" opacity="0.9" '
                f'transform="rotate({a-90+40:.1f} {cx} {cy})"/>')
        frames.append(track + arc + glow)
    return frames

def pencil():
    d = rp([(22.5,3.5),(28.5,9.5),(12,26),(4.5,27.5),(6,20)], r=1.6, rtip=1.2)
    s = shape(d)
    s += line('M19.5 6.5 L25.5 12.5', DARK, 1.4)
    s += line('M6 20 L12 26', DARK, 1.2)
    s += f'<path d="M4.5 26.5 L6 20 L12 26 L5.5 27.5 Z" fill="{DARK}"/>'
    return g(s)

def color_picker():
    d = ('M26.5 5.5 C28 7 28 9 26.5 10.5 L23.5 13.5 L25 15 L22 18 L14 10 L17 7 L18.5 8.5 '
         'L21.5 5.5 C23 4 25 4 26.5 5.5 Z')
    s = shape(d)
    tube = rp([(16.5,11.5),(20.5,15.5),(8.5,27.5),(4.5,27.5),(4.5,23.5)], r=1.2)
    s += shape(tube)
    s += f'<path d="M4.5 27.5 L4.5 23.5 L8.5 27.5 Z" fill="{EMBER}"/>'
    return g(s)

# ---- cursor table -------------------------------------------------------
cursors = {}
def add(name, body, hot, aliases=()):
    cursors[name] = dict(svg=HEAD + body + TAIL, hot=hot, aliases=list(aliases))

add('default', arrow(), (4, 3), aliases=['arrow', 'left_ptr'])
add('pointer', pointer_hand(), (12, 3), aliases=['hand2', 'hand1'])
add('text', ibeam(), (16, 16), aliases=['xterm', 'ibeam'])
add('vertical-text', ibeam(90), (16, 16))
add('crosshair', crosshair(), (16, 16), aliases=['cross', 'tcross'])
add('help', arrow(badge_box() + line('M21.2 21.6 C21.5 20.6 22.4 20 23.5 20 C24.9 20 25.8 20.9 25.8 22 C25.8 23.4 23.6 23.6 23.6 25.2', DARK, 1.5) + f'<circle cx="23.6" cy="27.1" r="0.9" fill="{DARK}"/>'), (4, 3), aliases=['question_arrow', 'whats_this'])
add('not-allowed', g(circle_slash()), (16, 16), aliases=['crossed_circle', 'forbidden'])
add('no-drop', arrow(circle_slash(23, 23, 7)), (4, 3), aliases=['dnd-no-drop'])
add('grab', grab_hand(), (16, 16), aliases=['openhand'])
add('grabbing', grabbing_hand(), (16, 16), aliases=['closedhand', 'dnd-none'])
add('move', quad_arrow(), (16, 16), aliases=['fleur', 'size_all'])
add('all-scroll', quad_arrow(dots=True), (16, 16))
add('copy', arrow(badge_box() + line('M23.5 20.5 L23.5 26.5 M20.5 23.5 L26.5 23.5', DARK, 1.8)), (4, 3), aliases=['dnd-copy'])
add('alias', arrow(badge_box() + line('M20.5 26.5 C20.5 22.5 23 21 26 21 M23.5 18.8 L26.3 21 L23.5 23.3', DARK, 1.5)), (4, 3), aliases=['dnd-link', 'link'])
add('context-menu', arrow(badge_box() + line('M20.6 21.2 L26.4 21.2 M20.6 23.6 L26.4 23.6 M20.6 26 L24.6 26', DARK, 1.5)), (4, 3))
add('cell', g(shape(rp([(13.6,4),(18.4,4),(18.4,13.6),(28,13.6),(28,18.4),(18.4,18.4),(18.4,28),(13.6,28),(13.6,18.4),(4,18.4),(4,13.6),(13.6,13.6)], r=1.8))), (16, 16), aliases=['plus'])
add('col-resize', g(shape(rp([(16,3),(21.6,9.3),(18.1,9.3),(18.1,22.7),(21.6,22.7),(16,29),(10.4,22.7),(13.9,22.7),(13.9,9.3),(10.4,9.3)], r=1.5, rtip=1.1)) + line('M4 16 L28 16', CREAM, 3.4) + line('M4 16 L28 16', DARK, 1.4), 90), (16, 16), aliases=['sb_h_double_arrow', 'split_h'])
add('row-resize', g(shape(rp([(16,3),(21.6,9.3),(18.1,9.3),(18.1,22.7),(21.6,22.7),(16,29),(10.4,22.7),(13.9,22.7),(13.9,9.3),(10.4,9.3)], r=1.5, rtip=1.1)) + line('M4 16 L28 16', CREAM, 3.4) + line('M4 16 L28 16', DARK, 1.4)), (16, 16), aliases=['sb_v_double_arrow', 'split_v'])
add('ns-resize', double_arrow(0), (16, 16), aliases=['n-resize', 's-resize', 'size_ver', 'top_side', 'bottom_side', 'v_double_arrow'])
add('ew-resize', double_arrow(90), (16, 16), aliases=['e-resize', 'w-resize', 'size_hor', 'left_side', 'right_side', 'h_double_arrow'])
add('nwse-resize', double_arrow(-45), (16, 16), aliases=['nw-resize', 'se-resize', 'size_fdiag', 'top_left_corner', 'bottom_right_corner'])
add('nesw-resize', double_arrow(45), (16, 16), aliases=['ne-resize', 'sw-resize', 'size_bdiag', 'top_right_corner', 'bottom_left_corner'])
add('zoom-in', magnifier('+'), (13, 13))
add('zoom-out', magnifier('-'), (13, 13))
add('pencil', pencil(), (4, 28), aliases=['draft'])
add('color-picker', color_picker(), (4, 28))

# animated
wait_frames = ring_frames(16, 16, 9.5, 3.4)
for i, f in enumerate(wait_frames):
    cursors[f'wait-{i:02d}'] = dict(svg=HEAD + g(f) + TAIL, hot=(16, 16), aliases=[], frame_of='wait')
prog_frames = ring_frames(23.5, 23.5, 5.2, 2.4)
for i, f in enumerate(prog_frames):
    cursors[f'progress-{i:02d}'] = dict(svg=HEAD + arrow(f) + TAIL, hot=(4, 3), aliases=[], frame_of='progress')

hot = {}
for name, c in cursors.items():
    with open(f'{OUT}/{name}.svg', 'w') as fh:
        fh.write(c['svg'])
    entry = {'hotspot': {'x': c['hot'][0], 'y': c['hot'][1]}, 'aliases': c['aliases']}
    if c.get('frame_of'):
        entry['frame_of'] = c['frame_of']
    hot[name] = entry
hot['_animation'] = {'wait': {'frames': 12, 'delay_ms': 60}, 'progress': {'frames': 12, 'delay_ms': 60}}
hot['_viewBox'] = 32
hot['_render_sizes'] = [24, 32, 48, 64]
with open(f'{OUT}/hotspots.json', 'w') as fh:
    json.dump(hot, fh, indent=2, ensure_ascii=False)
print(len(cursors), 'svgs written')
