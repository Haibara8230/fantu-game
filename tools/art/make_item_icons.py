"""Writes the parts the game composes technique and treasure icons from (scripts/ui/art_library.gd):
frames by grade, backs by element, subjects by art kind x element and by treasure base x material.
Square icons with an ornate frame and one subject in the middle, after 觅长生 and 鬼谷八荒, kept to the
project's flat colors and dark outlines. Every part is a 64x64 SVG; the game stacks back, subject, frame.
Usage: make_item_icons.py <project root>"""
import os, sys, math

ROOT = sys.argv[1]
OUT = os.path.join(ROOT, 'assets', 'art', 'icons')
INK = '#0b1a1c'
O = 'stroke="%s" stroke-width="2" stroke-linejoin="round" stroke-linecap="round"' % INK
O2 = 'stroke="%s" stroke-width="1.5" stroke-linejoin="round" stroke-linecap="round"' % INK

def write(rel, body):
    path = os.path.join(OUT, rel)
    os.makedirs(os.path.dirname(path), exist_ok=True)
    open(path, 'w', encoding='utf-8', newline='\n').write(
        '<svg xmlns="http://www.w3.org/2000/svg" width="64" height="64" viewBox="0 0 64 64">\n%s\n</svg>\n' % body.strip())

def rot(cx, cy, r, a):
    return cx + r * math.cos(math.radians(a)), cy + r * math.sin(math.radians(a))

# --- Elements --------------------------------------------------------------------------------------
EL = {  # light, main, deep
    'metal': ('#fbf6df', '#e3d9a8', '#9c8f5c'),
    'wood': ('#d9f7c9', '#8fd98f', '#3f8a4c'),
    'water': ('#e2f6ff', '#8fd0ef', '#2f739e'),
    'fire': ('#ffe8b8', '#ffa765', '#b9452a'),
    'earth': ('#f6e4ba', '#d9b373', '#7f5a2c'),
}

# --- Backs: a dark field, the element's glow, a faint pattern of its own ---------------------------
def back(glow, pattern):
    return ('<defs><radialGradient id="g" cx="0.5" cy="0.46" r="0.6"><stop offset="0" stop-color="%s" stop-opacity="0.55"/>'
            '<stop offset="0.55" stop-color="%s" stop-opacity="0.18"/><stop offset="1" stop-color="%s" stop-opacity="0"/></radialGradient></defs>'
            '<rect x="3" y="3" width="58" height="58" rx="7" fill="#11221f"/><rect x="3" y="3" width="58" height="58" rx="7" fill="url(#g)"/>%s'
            % (glow, glow, glow, pattern))
PATTERN = {
    'metal': ''.join('<path d="M%d 4 L%d 60" stroke="#e3d9a8" stroke-opacity="0.08" stroke-width="1.2"/>' % (x, x - 16) for x in range(12, 80, 9)),
    'wood': '<path d="M6 56 C20 44 30 30 34 8 M14 58 C26 50 40 40 56 30 M34 28 C40 24 48 22 58 22" stroke="#8fd98f" stroke-opacity="0.12" stroke-width="1.4" fill="none"/>',
    'water': ''.join('<path d="M4 %d C12 %d 20 %d 28 %d C36 %d 44 %d 52 %d C56 %d 58 %d 60 %d" stroke="#8fd0ef" stroke-opacity="0.12" stroke-width="1.3" fill="none"/>'
                     % (y, y - 4, y - 4, y, y + 4, y + 4, y, y - 2, y - 2, y) for y in range(12, 60, 10)),
    'fire': ''.join('<circle cx="%d" cy="%d" r="%.1f" fill="#ffa765" fill-opacity="0.14"/>' % p for p in [(12, 50, 1.6), (20, 14, 1.2), (50, 18, 1.8), (54, 46, 1.3), (30, 56, 1.0), (44, 8, 1.0), (8, 28, 1.1)]),
    'earth': '<path d="M4 44 L22 40 L36 46 L60 38 M4 52 L18 50 L34 54 L60 48 M4 22 L26 26 L44 20 L60 24" stroke="#d9b373" stroke-opacity="0.12" stroke-width="1.3" fill="none"/>',
    'none': '',
}
for key in list(EL) + ['none']:
    glow = EL[key][1] if key in EL else '#8fb3ad'
    write('backs/%s.svg' % key, back(glow, PATTERN[key]))

# --- Frames by grade: plain square to an ornate one -------------------------------------------------
GRADES = ['#c9c2b2', '#86bf7f', '#6fa6db', '#b083d8', '#e59d52', '#e0574e']
GOLD = '#d9b86c'
def corner_brackets(color, length=10, width=2.4):
    d = ''
    for (x, y, sx, sy) in [(5, 5, 1, 1), (59, 5, -1, 1), (5, 59, 1, -1), (59, 59, -1, -1)]:
        d += 'M%d %d L%d %d L%d %d ' % (x, y + sy * length, x, y, x + sx * length, y)
    return '<path d="%s" stroke="%s" stroke-width="%.1f" fill="none" stroke-linecap="round"/>' % (d, color, width)
def cloud_corners(color):
    out = ''
    for (x, y, a) in [(8, 8, 0), (56, 8, 90), (56, 56, 180), (8, 56, 270)]:
        out += ('<g transform="translate(%d %d) rotate(%d)"><path d="M0 9 C0 3 3 0 9 0 M3 9 C3 5 5 3 9 3 C11 3 12 5 11 6.5 C10 8 8 7.5 8 6" stroke="%s" stroke-width="1.8" fill="none" stroke-linecap="round"/></g>'
                % (x - 4, y - 4, a, color))
    return out
def gems(color, r=2.6):
    return ''.join('<path d="M%d %d L%.1f %d L%d %.1f L%.1f %d Z" fill="%s" %s/>' % (x, y - r, x + r, y, x, y + r, x - r, y, color, 'stroke="%s" stroke-width="1"' % INK)
                   for x, y in [(32, 3), (32, 61), (3, 32), (61, 32)])
def frame(index):
    c = GRADES[index]
    rim = '<rect x="3" y="3" width="58" height="58" rx="7" fill="none" stroke="%s" stroke-width="3"/>' % INK
    rim += '<rect x="3.5" y="3.5" width="57" height="57" rx="6.5" fill="none" stroke="%s" stroke-width="%s"/>' % (c, '2' if index < 2 else '2.4')
    if index >= 1:
        rim += '<rect x="7" y="7" width="50" height="50" rx="4" fill="none" stroke="%s" stroke-opacity="0.35" stroke-width="1"/>' % c
    if index >= 2:
        rim += corner_brackets(c)
    if index >= 3:
        rim += cloud_corners(GOLD)
    if index >= 4:
        rim += gems(c)
        rim += '<path d="M24 3 L32 0 L40 3 M24 61 L32 64 L40 61" stroke="%s" stroke-width="1.8" fill="none"/>' % GOLD
    if index >= 5:
        rim += ''.join('<circle cx="%d" cy="%d" r="1.6" fill="%s"/>' % (x, y, '#ffe6a0') for x, y in [(14, 3), (50, 3), (14, 61), (50, 61), (3, 14), (3, 50), (61, 14), (61, 50)])
        rim += '<rect x="1.5" y="1.5" width="61" height="61" rx="8.5" fill="none" stroke="%s" stroke-opacity="0.6" stroke-width="1"/>' % GOLD
    return rim
for index in range(6):
    write('frames/grade_%d.svg' % index, frame(index))

# --- Subjects: arts (法术, 连击, 重击, 疗愈, 护体) and 心法 (吐纳, 炼体, 凝神, 元气) by element --------
def projectile(e, cx, cy, size, angle):
    """The element's missile, pointing along `angle` (degrees, 0 = right), centered at cx, cy."""
    light, main, deep = EL[e]
    s = size / 20.0
    if e == 'metal':      # a flying sword
        shape = ('<path d="M-18 0 L10 -3 L20 0 L10 3 Z" fill="%s" %s/><path d="M-6 0 L18 0" stroke="%s" stroke-width="1" stroke-opacity="0.6"/>'
                 '<path d="M-14 -6 L-12 0 L-14 6" stroke="%s" stroke-width="3" fill="none" stroke-linecap="round"/><path d="M-14 -6 L-12 0 L-14 6" stroke="#d9b86c" stroke-width="1.6" fill="none" stroke-linecap="round"/>'
                 '<path d="M-22 0 L-15 0" stroke="#a8392e" stroke-width="2.4" stroke-linecap="round"/>' % (light, O2, deep, INK))
    elif e == 'wood':     # a leaf blade
        shape = ('<path d="M-18 0 C-8 -10 8 -9 20 0 C8 9 -8 10 -18 0 Z" fill="%s" %s/><path d="M-16 0 L18 0 M-4 0 L2 -5 M4 0 L10 -4 M-4 0 L2 5 M4 0 L10 4" stroke="%s" stroke-width="1.2" fill="none"/>' % (main, O2, deep))
    elif e == 'water':    # a water lance with a curling tail
        shape = ('<path d="M20 0 C10 -6 -6 -6 -12 -2 C-16 0 -20 -4 -22 -2 C-20 2 -16 4 -12 3 C-6 6 10 6 20 0 Z" fill="%s" %s/><path d="M-6 -1 C0 -3 8 -3 14 -1" stroke="%s" stroke-width="1.6" fill="none" stroke-linecap="round"/>' % (main, O2, light))
    elif e == 'fire':     # a fireball with its trail
        shape = ('<path d="M-22 -5 C-14 -6 -8 -8 0 -9 C-6 -4 -6 4 0 9 C-8 8 -14 6 -22 5 C-16 2 -16 -2 -22 -5 Z" fill="%s" fill-opacity="0.85" %s/>'
                 '<circle cx="6" cy="0" r="10" fill="%s" %s/><circle cx="8" cy="-1" r="5.5" fill="%s"/>' % (main, O2, main, O2, light))
    else:                 # a stone spike
        shape = ('<path d="M20 0 L4 -7 L-14 -5 L-20 0 L-14 5 L4 7 Z" fill="%s" %s/><path d="M4 -7 L0 0 L4 7 M-14 -5 L-8 0 L-14 5" stroke="%s" stroke-width="1.2" fill="none"/>'
                 '<path d="M8 -3 L16 -1" stroke="%s" stroke-width="1.4" stroke-linecap="round"/>' % (main, O2, deep, light))
    return '<g transform="translate(%.1f %.1f) rotate(%d) scale(%.2f)">%s</g>' % (cx, cy, angle, s, shape)

def speed_lines(cx, cy, angle, color):
    out = ''
    for off, length in [(-7, 10), (0, 14), (7, 9)]:
        a = math.radians(angle)
        bx, by = cx - 20 * math.cos(a) + off * -math.sin(a), cy - 20 * math.sin(a) + off * math.cos(a)
        ex, ey = bx - length * math.cos(a), by - length * math.sin(a)
        out += '<path d="M%.1f %.1f L%.1f %.1f" stroke="%s" stroke-width="2" stroke-linecap="round" stroke-opacity="0.7"/>' % (bx, by, ex, ey, color)
    return out

def bolt(e):
    return speed_lines(34, 30, -40, EL[e][0]) + projectile(e, 34, 30, 26, -40)

def barrage(e):
    return ''.join(projectile(e, x, y, 17, -40) for x, y in [(22, 40), (40, 40), (36, 22)]) + speed_lines(24, 44, -40, EL[e][0])

def burst(e):
    light, main, deep = EL[e]
    rays = ''.join('<path d="M%.1f %.1f L%.1f %.1f L%.1f %.1f Z" fill="%s" %s/>' % (
        *rot(32, 32, 9, a - 12), *rot(32, 32, 25 if i % 2 == 0 else 18, a), *rot(32, 32, 9, a + 12), main if i % 2 == 0 else deep, O2)
        for i, a in enumerate(range(0, 360, 30)))
    core = '<circle cx="32" cy="32" r="10" fill="%s" %s/>' % (light, O)
    sign = {'metal': '<path d="M32 25 L34 30 L39 32 L34 34 L32 39 L30 34 L25 32 L30 30 Z" fill="%s"/>' % deep,
            'wood': '<path d="M27 37 C26 30 30 26 37 26 C37 33 33 37 27 37 Z" fill="%s"/>' % deep,
            'water': '<path d="M26 31 C28 29 30 29 32 31 C34 33 36 33 38 31 M26 35 C28 33 30 33 32 35 C34 37 36 37 38 35" stroke="%s" stroke-width="1.8" fill="none" stroke-linecap="round"/>' % deep,
            'fire': '<path d="M32 25 C35 29 37 31 36 34 C35 37 33 38 32 38 C30 38 28 36 28 34 C28 31 31 30 31 27 C32 29 32 30 33 31 Z" fill="%s"/>' % deep,
            'earth': '<path d="M25 37 L30 28 L33 33 L35 29 L39 37 Z" fill="%s"/>' % deep}[e]
    return rays + core + sign

def mend(e):
    light, main, deep = EL[e]
    petals = ''
    for a, length, color in [(-90, 20, main), (-130, 17, main), (-50, 17, main), (-165, 13, deep), (-15, 13, deep)]:
        tip = rot(32, 40, length, a)
        l = rot(32, 40, 7, a - 35)
        r = rot(32, 40, 7, a + 35)
        petals += '<path d="M32 40 Q%.1f %.1f %.1f %.1f Q%.1f %.1f 32 40 Z" fill="%s" %s/>' % (l[0], l[1], tip[0], tip[1], r[0], r[1], color, O2)
    glow = '<circle cx="32" cy="34" r="20" fill="%s" fill-opacity="0.18"/>' % light
    stem = '<path d="M20 47 C26 44 38 44 44 47" stroke="%s" stroke-width="5" fill="none" stroke-linecap="round"/><path d="M20 47 C26 44 38 44 44 47" stroke="%s" stroke-width="2.6" fill="none" stroke-linecap="round"/>' % (INK, '#8fd98f')
    sparks = ''.join('<path d="M%d %d L%d %d M%d %d L%d %d" stroke="%s" stroke-width="1.8" stroke-linecap="round"/>' % (x - 3, y, x + 3, y, x, y - 3, x, y + 3, light) for x, y in [(14, 18), (50, 16), (52, 32)])
    return glow + stem + petals + sparks

def ward(e):
    light, main, deep = EL[e]
    hexagon = ' '.join('%.1f,%.1f' % rot(32, 33, 20, a) for a in range(-90, 270, 60))
    inner = ' '.join('%.1f,%.1f' % rot(32, 33, 13, a) for a in range(-90, 270, 60))
    return ('<polygon points="%s" fill="%s" fill-opacity="0.85" %s/><polygon points="%s" fill="none" stroke="%s" stroke-width="1.6"/>'
            '<path d="M32 13 L32 53 M14.7 23 L49.3 43 M14.7 43 L49.3 23" stroke="%s" stroke-opacity="0.35" stroke-width="1.2"/>'
            '<circle cx="32" cy="33" r="5" fill="%s" %s/><path d="M20 22 C24 17 29 15 33 15" stroke="%s" stroke-width="2" fill="none" stroke-linecap="round"/>'
            % (hexagon, main, O, inner, deep, deep, light, O2, light))

def breath(e):
    light, main, deep = EL[e]
    swirl = ('<path d="M32 10 C46 12 52 24 46 32 C42 38 34 36 34 30" stroke="%s" stroke-width="3" fill="none" stroke-linecap="round"/>'
             '<path d="M32 10 C18 12 12 24 18 32" stroke="%s" stroke-width="2.4" stroke-opacity="0.7" fill="none" stroke-linecap="round"/>' % (main, light))
    figure = ('<circle cx="32" cy="24" r="5.5" fill="#e9dcb8" %s/><path d="M24 40 C24 32 27 30 32 30 C37 30 40 32 40 40 Z" fill="#5f8f86" %s/>'
              '<path d="M14 48 C18 40 26 40 32 43 C38 40 46 40 50 48 C42 51 22 51 14 48 Z" fill="#5f8f86" %s/><circle cx="32" cy="43" r="2.6" fill="%s"/>' % (O2, O2, O2, light))
    return swirl + figure

def body(e):
    light, main, deep = EL[e]
    skin = {'metal': '#d8cfa6', 'wood': '#b9d9a4', 'water': '#b6d6e3', 'fire': '#e8b48a', 'earth': '#c99c62'}[e]
    fist = ('<path d="M20 30 C20 24 24 22 28 23 L42 23 C46 23 48 26 48 30 L48 40 C48 46 44 50 38 50 L28 50 C22 50 20 46 20 40 Z" fill="%s" %s/>'
            '<path d="M28 23 L28 32 M35 23 L35 32 M42 23 L42 32" stroke="%s" stroke-width="1.6"/><path d="M20 34 C24 32 30 33 32 36 C30 40 26 41 21 40" fill="%s" %s/>'
            '<path d="M24 50 L24 56 L44 56 L44 50" fill="%s" %s/>' % (skin, O, INK, skin, O2, deep, O2))
    aura = ''.join('<path d="M%.1f %.1f L%.1f %.1f" stroke="%s" stroke-width="2.4" stroke-linecap="round"/>' % (*rot(34, 36, 22, a), *rot(34, 36, 28, a), main) for a in range(-150, 30, 30))
    return aura + fist

def focus(e):
    light, main, deep = EL[e]
    rays = ''.join('<path d="M%.1f %.1f L%.1f %.1f" stroke="%s" stroke-width="2" stroke-linecap="round" stroke-opacity="0.8"/>' % (*rot(32, 32, 19, a), *rot(32, 32, 26, a), light) for a in range(0, 360, 30))
    eye = ('<path d="M32 12 C40 20 44 26 44 32 C44 38 40 44 32 52 C24 44 20 38 20 32 C20 26 24 20 32 12 Z" fill="#f3e6c4" %s/>'
           '<circle cx="32" cy="32" r="8" fill="%s" %s/><circle cx="32" cy="32" r="3.4" fill="%s"/><circle cx="34" cy="29.5" r="1.6" fill="#ffffff"/>' % (O, main, O2, INK))
    return rays + eye

def affinity(e):
    light, main, deep = EL[e]
    ring = '<circle cx="32" cy="32" r="22" fill="none" stroke="%s" stroke-width="1.6" stroke-dasharray="3 3"/>' % main
    runes = ''.join('<circle cx="%.1f" cy="%.1f" r="2.4" fill="%s" %s/>' % (*rot(32, 32, 22, a), light, 'stroke="%s" stroke-width="1"' % INK) for a in range(-90, 270, 72))
    orb = ('<circle cx="32" cy="32" r="14" fill="%s" %s/><path d="M19.5 36 A12.5 12.5 0 0 0 44.5 36 A14 11 0 0 1 19.5 36 Z" fill="%s" fill-opacity="0.6"/>'
           '<ellipse cx="27" cy="26" rx="4.5" ry="2.6" fill="#ffffff" fill-opacity="0.5" transform="rotate(-25 27 26)"/>' % (main, O, deep))
    return ring + runes + orb

ARTS = {'bolt': bolt, 'barrage': barrage, 'burst': burst, 'mend': mend, 'ward': ward, 'breath': breath, 'body': body, 'focus': focus, 'affinity': affinity}
for name, draw in ARTS.items():
    for e in EL:
        write('arts/%s_%s.svg' % (name, e), draw(e))

# --- Subjects: treasures by base and material (the five materials of each family, by tier) ---------
MATERIAL = {
    'metal': [('#a3a9aa', '#6d7476'), ('#8ec4bf', '#4f8a86'), ('#5f6b78', '#323a45'), ('#d6eef7', '#86b5c8'), ('#a996e0', '#5e4ca0')],
    'cloth': [('#ad9068', '#76603f'), ('#69b0a5', '#3d756d'), ('#6a5a8a', '#3d3256'), ('#ecdcaa', '#b49a5c'), ('#f6f3ff', '#b3aee0')],
    'jade':  [('#a29d91', '#6c685f'), ('#86cba6', '#4d8a69'), ('#4a5853', '#27302d'), ('#d9f2f3', '#8ebec2'), ('#86a3e6', '#4a64ad')],
}
TRIM = ['#b98a55', '#c9a35a', '#d9b86c', '#e6c77a', '#f2d68b']   # guards and fittings, richer by tier

def sword(m, t):
    main, deep = m
    return ('<path d="M47 11 L53 11 L53 17 L24 46 L18 40 Z" fill="%s" %s/><path d="M50 14 L22 42" stroke="%s" stroke-width="1.2"/>'
            '<path d="M14 36 L28 50" stroke="%s" stroke-width="7" stroke-linecap="round"/><path d="M14 36 L28 50" stroke="%s" stroke-width="4" stroke-linecap="round"/>'
            '<path d="M18 46 L11 53" stroke="%s" stroke-width="6" stroke-linecap="round"/><path d="M18 46 L11 53" stroke="#5a3a25" stroke-width="3" stroke-linecap="round"/>'
            '<circle cx="10" cy="54" r="3" fill="%s" %s/><path d="M9 56 C7 60 8 62 10 63 M11 56 C12 60 14 61 15 62" stroke="#a8392e" stroke-width="1.8" fill="none" stroke-linecap="round"/>'
            % (main, O, deep, INK, TRIM[t], INK, TRIM[t], O2))
def saber(m, t):
    main, deep = m
    return ('<path d="M20 44 C28 30 40 18 54 10 C52 20 44 32 26 48 Z" fill="%s" %s/><path d="M24 45 C32 33 42 22 52 13" stroke="%s" stroke-width="1.2" fill="none"/>'
            '<ellipse cx="22" cy="46" rx="6" ry="3" fill="%s" %s transform="rotate(-45 22 46)"/>'
            '<path d="M19 49 L12 56" stroke="%s" stroke-width="6" stroke-linecap="round"/><path d="M19 49 L12 56" stroke="#5a3a25" stroke-width="3" stroke-linecap="round"/>'
            '<circle cx="10" cy="58" r="3.4" fill="none" stroke="%s" stroke-width="2.4"/>' % (main, O, deep, TRIM[t], O2, INK, TRIM[t]))
def fan(m, t):
    main, deep = m
    cx, cy, r = 32, 48, 28
    ribs = ''.join('<path d="M%d %d L%.1f %.1f" stroke="%s" stroke-width="1.2"/>' % (cx, cy, *rot(cx, cy, r, a), deep) for a in range(-155, -20, 15))
    return ('<path d="M%d %d L%.1f %.1f A%d %d 0 0 1 %.1f %.1f Z" fill="%s" %s/>%s'
            '<path d="M%.1f %.1f A%d %d 0 0 1 %.1f %.1f" stroke="%s" stroke-width="1.2" fill="none" stroke-opacity="0.6"/>'
            '<circle cx="%d" cy="%d" r="3.4" fill="%s" %s/><path d="M%d %d C%d %d %d %d %d %d" stroke="#a8392e" stroke-width="1.8" fill="none" stroke-linecap="round"/>'
            % (cx, cy, *rot(cx, cy, r, -160), r, r, *rot(cx, cy, r, -20), main, O, ribs, *rot(cx, cy, 19, -155), 19, 19, *rot(cx, cy, 19, -25), INK,
               cx, cy, TRIM[t], O2, cx, cy + 3, cx - 1, cy + 7, cx + 2, cy + 9, cx, cy + 12))
def bell(m, t):
    main, deep = m
    return ('<path d="M32 8 L32 14" stroke="#a8392e" stroke-width="2.6" stroke-linecap="round"/><path d="M28 14 C28 11 36 11 36 14" fill="none" stroke="%s" stroke-width="2.4"/>'
            '<path d="M32 14 C22 14 19 24 19 34 C19 40 16 43 13 46 L51 46 C48 43 45 40 45 34 C45 24 42 14 32 14 Z" fill="%s" %s/>'
            '<path d="M21 36 L43 36" stroke="%s" stroke-width="1.4"/><path d="M24 22 C26 18 29 17 32 17" stroke="#ffffff" stroke-opacity="0.45" stroke-width="2" fill="none" stroke-linecap="round"/>'
            '<circle cx="32" cy="50" r="4" fill="%s" %s/><path d="M14 46 L50 46" stroke="%s" stroke-width="2.6" stroke-linecap="round"/>' % (TRIM[t], main, O, deep, TRIM[t], O2, TRIM[t]))
def robe(m, t):
    main, deep = m
    return ('<path d="M24 10 L32 14 L40 10 L52 18 L48 28 L44 26 L45 54 L19 54 L20 26 L16 28 L12 18 Z" fill="%s" %s/>'
            '<path d="M24 10 L32 26 L40 10" fill="none" stroke="%s" stroke-width="2"/><path d="M32 26 L36 54" stroke="%s" stroke-width="1.4"/>'
            '<path d="M20 34 L44 34" stroke="%s" stroke-width="3"/><path d="M20 34 L44 34" stroke="%s" stroke-width="1.6"/>' % (main, O, INK, deep, INK, TRIM[t]))
def vest(m, t):
    main, deep = m
    plates = ''.join('<path d="M%d %d L%d %d" stroke="%s" stroke-width="1.2"/>' % (21, y, 43, y, deep) for y in range(30, 52, 5))
    return ('<path d="M22 10 L28 10 C29 16 35 16 36 10 L42 10 L48 18 L46 52 L18 52 L16 18 Z" fill="%s" %s/>%s'
            '<circle cx="32" cy="26" r="6" fill="%s" %s/><circle cx="32" cy="26" r="2.4" fill="%s"/>' % (main, O, plates, TRIM[t], O2, deep))
def pendant(m, t):
    main, deep = m
    return ('<path d="M32 4 L32 12" stroke="#a8392e" stroke-width="2.4" stroke-linecap="round"/><circle cx="32" cy="14" r="2.4" fill="%s" %s/>'
            '<circle cx="32" cy="32" r="15" fill="%s" %s/><circle cx="32" cy="32" r="5" fill="#11221f" %s/>'
            '<path d="M22 26 C24 22 27 20 31 19" stroke="#ffffff" stroke-opacity="0.45" stroke-width="2" fill="none" stroke-linecap="round"/>'
            '<path d="M24 38 C27 42 37 42 40 38" stroke="%s" stroke-width="1.4" fill="none"/>'
            '<path d="M32 47 L32 52 M29 52 C28 56 29 59 30 61 M35 52 C36 56 35 59 34 61 M32 52 L32 61" stroke="#a8392e" stroke-width="1.8" fill="none" stroke-linecap="round"/>' % (TRIM[t], O2, main, O, O2, deep))
def ring(m, t):
    main, deep = m
    return ('<ellipse cx="32" cy="38" rx="17" ry="13" fill="none" stroke="%s" stroke-width="8"/><ellipse cx="32" cy="38" rx="17" ry="13" fill="none" stroke="%s" stroke-width="5"/>'
            '<path d="M20 34 C24 29 30 27 34 27" stroke="#ffffff" stroke-opacity="0.4" stroke-width="1.6" fill="none" stroke-linecap="round"/>'
            '<path d="M32 12 L40 20 L32 28 L24 20 Z" fill="%s" %s/><path d="M32 12 L32 28 M24 20 L40 20" stroke="%s" stroke-width="1" stroke-opacity="0.5"/>' % (INK, TRIM[t], main, O, INK))
def mirror(m, t):
    main, deep = m
    return ('<circle cx="32" cy="30" r="19" fill="%s" %s/><circle cx="32" cy="30" r="14" fill="%s" stroke="%s" stroke-width="1.4"/>'
            '<path d="M24 22 L30 18 M22 30 L34 18" stroke="#ffffff" stroke-opacity="0.6" stroke-width="2" stroke-linecap="round"/>'
            '<path d="M28 49 L36 49 L38 56 L26 56 Z" fill="%s" %s/><path d="M22 58 L42 58" stroke="%s" stroke-width="3" stroke-linecap="round"/>' % (TRIM[t], O, main, deep, TRIM[t], O2, INK))

BASES = {'sword': ('metal', sword), 'saber': ('metal', saber), 'fan': ('jade', fan), 'bell': ('metal', bell), 'robe': ('cloth', robe),
         'vest': ('metal', vest), 'pendant': ('jade', pendant), 'ring': ('jade', ring), 'mirror': ('jade', mirror)}
for base, (family, draw) in BASES.items():
    for tier in range(5):
        write('gear/%s_%d.svg' % (base, tier + 1), draw(MATERIAL[family][tier], tier))

# --- A jade slip laid over a technique's icon for its 玉简 ----------------------------------------
write('slip.svg', '<g transform="translate(36 36)"><rect x="0" y="0" width="24" height="24" rx="4" fill="#11221f" stroke="%s" stroke-width="1.6"/>'
                  '<path d="M5 5 L5 19 M10 5 L10 19 M15 5 L15 19 M20 5 L20 19" stroke="#86cba6" stroke-width="3.4" stroke-linecap="round"/>'
                  '<path d="M3 9 L22 9 M3 15 L22 15" stroke="#a8392e" stroke-width="1.6"/></g>' % GOLD)
print('written')
