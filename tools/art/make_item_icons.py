"""Writes the parts the game composes technique and treasure icons from (scripts/ui/art_library.gd):
frames by grade, backs by element, subjects by art kind x element and by treasure base x material,
and one picture (back and subject) for each catalogue item of data/items.json, framed by its 品级.
Square icons with an ornate frame and one subject in the middle, after 觅长生 and 鬼谷八荒, kept to the
project's flat colors and dark outlines. Every part is a 64x64 SVG; the game stacks back, subject, frame.
Usage: make_item_icons.py <project root>"""
import os, sys, math

ROOT = sys.argv[1]
OUT = os.path.join(ROOT, 'assets', 'art', 'icons')
INK = '#26392f'
O = 'stroke="%s" stroke-width="1.2" stroke-linejoin="round" stroke-linecap="round"' % INK
O2 = 'stroke="%s" stroke-width="0.85" stroke-linejoin="round" stroke-linecap="round"' % INK

def write(rel, body):
    path = os.path.join(OUT, rel)
    os.makedirs(os.path.dirname(path), exist_ok=True)
    open(path, 'w', encoding='utf-8', newline='\n').write(
        '<svg xmlns="http://www.w3.org/2000/svg" width="64" height="64" viewBox="0 0 64 64">\n%s\n</svg>\n' % body.strip())

def rot(cx, cy, r, a):
    return cx + r * math.cos(math.radians(a)), cy + r * math.sin(math.radians(a))

# --- Elements --------------------------------------------------------------------------------------
EL = {  # light, main, deep
    'metal': ('#f4e9be', '#c9ae68', '#8e7341'),
    'wood': ('#d3dfac', '#89a86b', '#4c7951'),
    'water': ('#d5e9df', '#8ab9bb', '#4d7c88'),
    'fire': ('#f2d7a5', '#cc8c5d', '#995741'),
    'earth': ('#ead9b1', '#bba16b', '#806841'),
}

# --- Backs: a dark field, the element's glow, a faint pattern of its own ---------------------------
def back(glow, pattern):
    # Quiet colour planes follow the approved item/skill references. The old
    # repeated pattern competes with a 64px subject and is intentionally omitted.
    return ('<rect x="2" y="2" width="60" height="60" rx="3" fill="#303c32"/>'
            '<path d="M2 40 Q32 29 62 37 V62 H2 Z" fill="%s" fill-opacity="0.12"/>' % glow)
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
    rim = '<rect x="1.5" y="1.5" width="61" height="61" rx="3" fill="none" stroke="%s" stroke-width="1.2"/>' % c
    if index >= 2:
        rim += corner_brackets(c, length=6, width=1.2)
    if index >= 4:
        rim += '<path d="M28 2 L32 5 L36 2 M28 62 L32 59 L36 62" stroke="%s" stroke-width="1" fill="none"/>' % GOLD
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
    # Approved 09_skill: one diagonal impact and broad connected rays. This is
    # a subject layer only; backs and grade frames are composed by ArtLibrary.
    return ('<path d="M9 51 L28 31 L54 9 L37 35 Z" fill="%s" %s/>'
            '<path d="M20 18 L30 28 L31 6 L35 27 L52 21 L39 32 L58 40 L37 37 L42 58 L31 40 L16 55 L25 37 L6 32 L25 29 Z" fill="%s" %s/>'
            '<path d="M29 30 L32 15 L35 30 L48 27 L38 35 L45 46 L33 39 L24 49 L28 37 L15 33 Z" fill="%s"/>'
            '<path d="M31 31 L33 25 L35 32 L41 33 L35 36 L33 42 L30 36 L24 34 Z" fill="%s"/>'
            % (deep, O2, main, O2, light, '#fff4d0'))

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

# --- Catalogue items (data/items.json): each its own back and subject; the game adds the 品级 frame ----
RED = '#c0392b'
PAPER = '#f1e6c8'

def glow(cx, cy, r, color, opacity=0.18):
    return ''  # No stacked glow discs behind catalogue subjects.

def shine(x, y, rx, ry, angle=-25, opacity=0.55):
    return '<ellipse cx="%s" cy="%s" rx="%s" ry="%s" fill="#ffffff" fill-opacity="%s" transform="rotate(%d %s %s)"/>' % (x, y, rx, ry, opacity, angle, x, y)

def sparkle(x, y, r, color='#fff4c8'):
    return ('<path d="M{x} {a} Q{x} {y} {b} {y} Q{x} {y} {x} {c} Q{x} {y} {d} {y} Q{x} {y} {x} {a} Z" fill="{col}"/>'
            .format(x=x, y=y, a=y - r, b=x + r, c=y + r, d=x - r, col=color))

def leaf(bx, by, tx, ty, w, fill, vein=None, outline=O2):
    """A leaf from its base to its tip, `w` wide at the middle."""
    mx, my = (bx + tx) / 2.0, (by + ty) / 2.0
    dx, dy = tx - bx, ty - by
    length = math.hypot(dx, dy) or 1.0
    px, py = -dy / length * w, dx / length * w
    out = '<path d="M%.1f %.1f Q%.1f %.1f %.1f %.1f Q%.1f %.1f %.1f %.1f Z" fill="%s" %s/>' % (bx, by, mx + px, my + py, tx, ty, mx - px, my - py, bx, by, fill, outline)
    if vein:
        out += '<path d="M%.1f %.1f L%.1f %.1f" stroke="%s" stroke-width="1" stroke-opacity="0.7"/>' % (bx, by, bx + dx * 0.8, by + dy * 0.8, vein)
    return out

def ground(color='#2a3a33'):
    return '<ellipse cx="32" cy="53" rx="15" ry="3.5" fill="%s" %s/>' % (color, O2)

# Herbs
def grass_tuft():
    return ('<path d="M31 55 C28 40 30 24 33 10" stroke="#5e6e3e" stroke-width="2" fill="none"/>'
            '<g stroke="#33553b" stroke-width="0.85" stroke-linejoin="round">'
            '<path d="M30 48 C20 49 13 44 9 36 C19 35 28 39 30 48 Z" fill="#578353"/>'
            '<path d="M31 44 C32 34 42 28 53 27 C51 38 42 43 31 44 Z" fill="#89a95f"/>'
            '<path d="M30 36 C22 37 14 29 13 22 C24 22 29 27 30 36 Z" fill="#91b067"/>'
            '<path d="M31 29 C31 21 39 15 47 14 C47 23 40 29 31 29 Z" fill="#7caa5c"/>'
            '<path d="M32 21 C25 21 22 15 23 9 C30 11 33 15 32 21 Z" fill="#a1bc68"/>'
            '<path d="M31 52 C35 45 45 42 53 44 C48 50 39 54 31 52 Z" fill="#7aa05a"/>'
            '<path d="M20 22 C18 18 21 17 23 19 C25 15 28 18 25 21 C27 23 24 25 22 23 Z M38 20 C36 17 38 15 41 17 C42 14 45 16 44 19 C46 21 43 23 41 21 Z M32 13 C30 10 32 8 34 10 C35 7 38 9 37 12 C39 14 35 16 34 14 Z" fill="#eee2ba"/>'
            '</g>')

def fire_flower():
    stem = '<path d="M32 54 C31 46 33 40 32 32" stroke="%s" stroke-width="4" fill="none"/><path d="M32 54 C31 46 33 40 32 32" stroke="#5fae6a" stroke-width="2" fill="none"/>' % INK
    leaves = leaf(32, 46, 18, 38, 4, '#5fae6a', '#3f8a4c') + leaf(32, 42, 46, 35, 4, '#5fae6a', '#3f8a4c')
    petals = ''.join('<g transform="translate(32 26) rotate(%d)"><path d="M0 0 C-7 -4 -8 -12 -3 -19 C-1 -15 1 -14 2 -17 C7 -11 6 -4 0 0 Z" fill="%s" %s/></g>'
                     % (a, '#ff7a45' if i % 2 else '#e8483a', O2) for i, a in enumerate(range(0, 360, 60)))
    return glow(32, 26, 20, '#ffa765', 0.22) + ground() + stem + leaves + petals + '<circle cx="32" cy="26" r="4.5" fill="#ffd66b" %s/>' % O2

def dew_grass():
    leaves = ''
    for tx, ty, w, color in [(16, 20, 3, '#5fa89a'), (48, 18, 3, '#5fa89a'), (25, 11, 3.4, '#7fc8b8'), (40, 10, 3.4, '#7fc8b8'), (32, 8, 3.6, '#9fe0cf')]:
        leaves += leaf(32, 52, tx, ty, w, color, '#2f6f68')
    drops = ''.join(('<path d="M{x} {a} C{b} {c} {r} {d} {r} {e} C{r} {f} {l} {f} {l} {e} C{l} {d} {g} {c} {x} {a} Z" fill="#e2f6ff" {o}/>'
                     '<circle cx="{h}" cy="{y}" r="0.9" fill="#ffffff"/>').format(
                        x=x, y=y, a=y - 5, b=x + 1, c=y - 2, d=y - 0.5, e=y + 1.5, f=y + 4, g=x - 1, r=x + 3.5, l=x - 3.5, h=x - 1.2, o=O2)
                    for x, y in [(20, 28), (44, 25), (32, 20)])
    return ground() + leaves + drops

def lingzhi():
    small = ('<g transform="translate(30 27) scale(0.45)"><path d="M12 30 C14 18 30 12 44 16 C54 19 56 28 50 32 C42 36 22 36 12 30 Z" fill="#a04a2a" %s/>'
             '<path d="M30 34 C30 42 30 48 28 54 L36 54 C36 48 36 42 36 34 Z" fill="#7a3a20" %s/></g>' % (O, O))
    cap = ('<path d="M8 30 C10 18 26 12 40 15 C50 18 54 26 48 31 C40 36 18 36 8 30 Z" fill="#b5552f" %s/>'
           '<path d="M14 28 C18 21 28 18 38 19 M20 30 C24 25 31 23 38 24" stroke="#e08a52" stroke-width="1.6" fill="none" stroke-linecap="round"/>'
           '<path d="M10 31 C20 37 40 37 47 32 C40 38 20 39 10 31 Z" fill="#e8d3a0" %s/>' % (O, O2))
    stem = '<path d="M26 35 C27 43 25 49 21 54 L32 54 C32 48 33 42 33 35 Z" fill="#8a3f22" %s/>' % O
    return glow(30, 30, 22, '#ffd59a', 0.12) + ground() + small + stem + cap

def xiaxue():
    return lingzhi().replace('#b5552f', '#d8443a').replace('#e08a52', '#ff9a7a').replace('#a04a2a', '#c23a32').replace('#ffd59a', '#ff9a8a')

def gall(main, deep, light):
    return ('<path d="M33 14 C33 18 30 20 30 22" stroke="%s" stroke-width="4" fill="none" stroke-linecap="round"/><path d="M33 14 C33 18 30 20 30 22" stroke="%s" stroke-width="2" fill="none" stroke-linecap="round"/>'
            '<path d="M30 21 C34 26 46 30 46 41 C46 49 40 54 32 54 C24 54 18 49 18 41 C18 31 26 26 30 21 Z" fill="%s" %s/>'
            '<path d="M22 44 C24 50 30 52 36 51" stroke="%s" stroke-width="1.6" fill="none" stroke-linecap="round"/>'
            '<path d="M27 21 L34 22" stroke="%s" stroke-width="2.4" stroke-linecap="round"/>%s'
            % (INK, deep, main, O, deep, RED, shine(26, 34, 4, 2.4, -50)) + glow(32, 40, 18, light, 0.15))

# Pills
def pill(main, deep, light, fine=False, extra=''):
    out = glow(32, 33, 22, light, 0.28 if fine else 0.18)
    out += '<ellipse cx="32" cy="48" rx="17" ry="5" fill="#e9e2cf" %s/><ellipse cx="32" cy="47" rx="11" ry="2.6" fill="#c9bfa4"/>' % O2
    out += '<circle cx="32" cy="34" r="12" fill="%s" %s/>' % (main, O)
    out += '<path d="M20.2 36 A12 12 0 0 0 43.8 36 A14 9 0 0 1 20.2 36 Z" fill="%s" fill-opacity="0.55"/>' % deep
    out += extra
    if fine:
        out += '<path d="M24 33 C26 27 34 26 37 30 C40 34 36 39 31 37 C28 36 29 32 32 32" stroke="%s" stroke-width="1.6" fill="none" stroke-linecap="round"/>' % GOLD
        out += sparkle(13, 18, 3.5) + sparkle(51, 22, 3) + sparkle(48, 44, 2.4)
    return out + shine(27, 29, 4, 2.4)

def pill_crack(deep):
    return '<path d="M27 25 L31 31 L28 35 L33 41" stroke="%s" stroke-width="1.6" fill="none" stroke-linecap="round" stroke-linejoin="round"/>' % deep

def pill_band():
    return '<path d="M20.5 31 C26 34 38 34 43.5 31" stroke="%s" stroke-width="2" fill="none"/>' % GOLD

def peach_pill():
    return (glow(32, 33, 22, '#ffd0c0', 0.2) + '<ellipse cx="32" cy="48" rx="17" ry="5" fill="#e9e2cf" %s/>' % O2
            + '<path d="M32 22 C40 22 45 30 44 37 C43 43 38 46 32 46 C26 46 21 43 20 37 C19 30 24 22 32 22 Z" fill="#ffb59a" %s/>' % O
            + '<path d="M32 22 C29 29 29 39 32 46" stroke="#e0705a" stroke-width="1.4" fill="none"/>'
            + '<path d="M36 26 C42 29 43 36 40 41 C44 36 44 29 36 26 Z" fill="#ff8a7a" fill-opacity="0.6"/>'
            + leaf(32, 22, 22, 16, 3, '#6fbf6a', '#3f8a4c') + leaf(32, 22, 40, 14, 3, '#8fd98f', '#3f8a4c') + shine(26, 30, 3.5, 2))

def powder_packet():
    return (glow(32, 34, 20, '#bfe3c0', 0.2)
            + '<path d="M18 50 C22 44 42 44 46 50 Z" fill="#9fc79a" %s/>' % O2
            + ''.join('<circle cx="%d" cy="%d" r="0.9" fill="#3f6a4c"/>' % p for p in [(26, 48), (31, 47), (37, 48), (34, 49)])
            + '<path d="M32 10 L50 28 L32 46 L14 28 Z" fill="#e9dcb8" %s/>' % O
            + '<path d="M14 28 L32 32 L50 28 M32 32 L32 46" stroke="#b8a77c" stroke-width="1.2" fill="none"/>'
            + '<path d="M23 19 L41 37 M41 19 L23 37" stroke="%s" stroke-width="1.8"/>' % RED
            + '<circle cx="32" cy="28" r="2.6" fill="%s" %s/>' % (RED, O2))

# Quest tokens
def invitation():
    return ('<g transform="rotate(-10 32 32)"><rect x="12" y="16" width="40" height="30" rx="2" fill="#b8322a" %s/>'
            '<rect x="15.5" y="19.5" width="33" height="23" rx="1" fill="none" stroke="%s" stroke-width="1.4"/>'
            '<path d="M22 25 L28 25 M25 25 L25 37 M21 31 L29 31 M34 24 L34 37 M34 24 L41 24 L41 30 L34 30 M36 33 L42 37" stroke="%s" stroke-width="1.8" fill="none" stroke-linecap="round"/>'
            '<circle cx="44" cy="40" r="3" fill="%s" %s/></g>'
            '<path d="M18 46 C16 50 17 54 19 57 M20 46 C21 50 22 53 24 55" stroke="%s" stroke-width="1.8" fill="none" stroke-linecap="round"/>'
            % (O, GOLD, GOLD, GOLD, O2, GOLD))

def bamboo_tag():
    return ('<path d="M32 6 C26 8 26 14 30 16 M32 6 C38 8 38 14 34 16" stroke="%s" stroke-width="1.8" fill="none" stroke-linecap="round"/>' % RED
            + '<g transform="rotate(10 32 34)"><rect x="23" y="14" width="18" height="42" rx="4" fill="#d8bf7a" %s/>' % O
            + '<circle cx="32" cy="19" r="2" fill="#11221f"/>'
            + '<path d="M29 25 L35 25 M32 25 L32 31 M28 31 L36 31 M29 35 L35 35 M32 35 L31 44 M28 40 L36 40 M29 47 L35 48" stroke="#6b4a26" stroke-width="1.7" fill="none" stroke-linecap="round"/>'
            + '<path d="M25 18 L25 52" stroke="#f2e2a8" stroke-width="1.4" stroke-opacity="0.8"/></g>')

def peddler_pack():
    def basket(x):
        return ('<path d="M%d %d L%d %d" stroke="#8a6a3a" stroke-width="1.4"/><path d="M%d %d L%d %d" stroke="#8a6a3a" stroke-width="1.4"/>' % (x + 8, 16, x + 2, 32, x + 8, 16, x + 14, 32)
                + '<ellipse cx="%d" cy="31" rx="7" ry="4" fill="%s" %s/>' % (x + 8, '#6fa6db' if x < 30 else '#b083d8', O2)
                + '<path d="M%d 32 L%d 32 L%d 52 L%d 52 Z" fill="#c99c62" %s/>' % (x, x + 16, x + 14, x + 2, O)
                + '<path d="M%d 38 L%d 38 M%d 44 L%d 44 M%d 32 L%d 52 M%d 32 L%d 52" stroke="#8a6a3a" stroke-width="1.1"/>' % (x + 1, x + 15, x + 1.5, x + 14.5, x + 6, x + 6.5, x + 10, x + 9.5))
    pole = '<path d="M6 16 L58 16" stroke="%s" stroke-width="5" stroke-linecap="round"/><path d="M6 16 L58 16" stroke="#a87a48" stroke-width="2.6" stroke-linecap="round"/>' % INK
    return basket(8) + basket(40) + pole

# Ores, crystals, jade and silk
def bars(top, left, right):
    def bar(ox, oy):
        return ('<path d="M%d %d L%d %d L%d %d L%d %d Z" fill="%s" %s/>' % (ox, oy, ox + 22, oy - 8, ox + 32, oy - 3, ox + 10, oy + 5, top, O2)
                + '<path d="M%d %d L%d %d L%d %d L%d %d Z" fill="%s" %s/>' % (ox, oy, ox + 10, oy + 5, ox + 10, oy + 13, ox, oy + 8, left, O2)
                + '<path d="M%d %d L%d %d L%d %d L%d %d Z" fill="%s" %s/>' % (ox + 10, oy + 5, ox + 32, oy - 3, ox + 32, oy + 5, ox + 10, oy + 13, right, O2)
                + '<path d="M%d %d L%d %d" stroke="#ffffff" stroke-opacity="0.55" stroke-width="1.6" stroke-linecap="round"/>' % (ox + 4, oy, ox + 22, oy - 6))
    return bar(18, 25) + bar(12, 37)

def crystals(main, deep, light, glow_color):
    out = glow(32, 34, 24, glow_color, 0.3)
    out += '<ellipse cx="32" cy="50" rx="18" ry="5" fill="#3a3530" %s/>' % O2
    for x, h, w, a, color in [(22, 16, 5, -28, deep), (43, 18, 5, 25, deep), (32, 28, 7, 0, main), (25, 12, 4, -10, main), (39, 12, 4, 12, light)]:
        out += ('<g transform="rotate(%d %d 50)"><path d="M%d 50 L%d %d L%d %d L%d %d L%d 50 Z" fill="%s" %s/>'
                '<path d="M%d %d L%d 50" stroke="#ffffff" stroke-opacity="0.45" stroke-width="1.2"/></g>'
                % (a, x, x - w, x - w, 50 - h, x, 50 - h - w * 1.3, x + w, 50 - h, x + w, color, O2, x, 50 - h - w * 1.3, x))
    return out

def jade_stone(skin, main, deep):
    return ('<path d="M12 38 C10 27 19 17 32 17 C45 16 54 26 52 37 C51 47 41 53 30 52 C19 52 13 46 12 38 Z" fill="%s" %s/>' % (skin, O)
            + '<path d="M16 42 C20 47 26 49 32 49 M44 20 C48 23 50 27 50 31" stroke="#ffffff" stroke-opacity="0.18" stroke-width="1.6" fill="none"/>'
            + '<path d="M18 31 L25 22 L39 21 L45 29 L41 39 L27 41 Z" fill="%s" %s/>' % (main, O2)
            + '<path d="M25 22 L29 30 L39 21 M29 30 L27 41 M29 30 L45 29" stroke="%s" stroke-width="1.1" stroke-opacity="0.6" fill="none"/>' % deep
            + shine(26, 27, 3.5, 1.8, -40, 0.6))

def cloth_bolt(main, deep, light, pattern=''):
    return ('<g transform="rotate(-14 32 32)">'
            '<path d="M16 34 C20 44 28 42 34 47 C38 50 44 51 52 48 L50 56 C42 58 35 56 29 53 C22 50 16 46 13 36 Z" fill="%s" %s/>' % (main, O)
            + '<rect x="12" y="18" width="32" height="18" rx="3" fill="%s" %s/>' % (main, O)
            + '<path d="M18 18 L18 36 M26 18 L26 36 M34 18 L34 36" stroke="%s" stroke-width="1.2" stroke-opacity="0.7"/>' % deep + pattern
            + '<ellipse cx="44" cy="27" rx="5" ry="9" fill="%s" %s/>' % (light, O2)
            + '<path d="M44 22 C47 23 47 31 44 32 C42 31 42 25 44 25" stroke="%s" stroke-width="1.2" fill="none"/>' % deep
            + '<path d="M15 21 L40 21" stroke="#ffffff" stroke-opacity="0.4" stroke-width="1.6" stroke-linecap="round"/></g>')

CLOUD_PATTERN = '<path d="M16 30 C16 27 20 27 20 30 C20 27 24 27 24 30 M28 25 C28 22 32 22 32 25 C32 22 36 22 36 25" stroke="%s" stroke-width="1.3" fill="none"/>' % GOLD

# Beast parts
def fang():
    return ('<path d="M34 12 C38 10 42 13 40 16" stroke="%s" stroke-width="1.8" fill="none"/>' % RED
            + '<path d="M18 16 C34 16 46 28 46 46 C45 52 40 53 38 48 C36 34 30 25 17 23 C13 22 13 16 18 16 Z" fill="#efe6cc" %s/>' % O
            + '<path d="M18 16 C22 17 23 22 18 23" fill="#8a7a5a" %s/>' % O2
            + '<path d="M44 44 C45 48 43 51 40 49" stroke="#8fd98f" stroke-width="2.4" fill="none" stroke-linecap="round"/>'
            + '<path d="M22 20 C32 22 40 30 42 42" stroke="#ffffff" stroke-opacity="0.6" stroke-width="1.6" fill="none" stroke-linecap="round"/>'
            + glow(43, 47, 7, '#8fd98f', 0.3))

def pelt():
    return ('<path d="M20 12 L26 17 L32 12 L38 17 L44 12 L46 21 L53 25 L47 32 L52 42 L45 46 L47 55 L38 50 L32 55 L26 50 L17 55 L19 46 L12 42 L17 32 L11 25 L18 21 Z" fill="#8a7055" %s/>' % O
            + '<path d="M24 24 C28 20 36 20 40 24 C44 30 44 40 40 45 C36 49 28 49 24 45 C20 40 20 30 24 24 Z" fill="#c4a582" %s/>' % O2
            + ''.join('<path d="M%d %d l3 4" stroke="#5f4a35" stroke-width="1.2" stroke-linecap="round"/>' % p for p in [(28, 27), (34, 30), (29, 36), (35, 39), (30, 42)]))

def feather():
    return (glow(32, 32, 22, '#ffa765', 0.2)
            + '<path d="M20 48 C14 36 24 18 46 10 C50 26 38 44 20 48 Z" fill="#e8483a" %s/>' % O
            + '<path d="M24 44 C22 34 30 22 42 16 C42 26 36 38 24 44 Z" fill="#ff8a45"/>'
            + '<path d="M12 56 L44 13" stroke="%s" stroke-width="3.4" stroke-linecap="round"/><path d="M12 56 L44 13" stroke="#ffe0a0" stroke-width="1.6" stroke-linecap="round"/>' % INK
            + '<path d="M30 34 L38 36 M26 40 L32 43 M34 27 L42 27" stroke="#ffd66b" stroke-width="1.2" stroke-linecap="round"/>'
            + ''.join('<circle cx="%d" cy="%d" r="%.1f" fill="#ffd66b"/>' % p for p in [(50, 30, 1.6), (46, 40, 1.2), (52, 18, 1.0)]))

def scales():
    def scale(x, y, color):
        return ('<path d="M%d %d C%d %d %d %d %d %d C%d %d %d %d %d %d Z" fill="%s" %s/>' % (x, y - 11, x + 10, y - 11, x + 12, y, x, y + 12, x - 12, y, x - 10, y - 11, x, y - 11, color, O)
                + '<path d="M%d %d L%d %d M%d %d L%d %d" stroke="#5c5448" stroke-width="1.2"/>' % (x, y - 9, x, y + 9, x - 6, y - 3, x + 6, y - 3))
    return scale(23, 26, '#a39a86') + scale(41, 26, '#9a917c') + scale(32, 40, '#b4ab96')

def beast_core(main, deep, light, r):
    return (glow(32, 32, r + 12, light, 0.25) + glow(32, 32, r + 6, main, 0.25)
            + '<circle cx="32" cy="32" r="%d" fill="%s" %s/>' % (r, main, O)
            + '<path d="M%.1f 32 C%.1f %.1f %.1f %.1f 32 32 C%.1f %.1f %.1f %.1f %.1f 32" stroke="%s" stroke-width="1.6" fill="none" stroke-linecap="round"/>'
            % (32 - r * 0.6, 32 - r * 0.6, 32 - r * 0.5, 32 - r * 0.1, 32 - r * 0.5, 32 + r * 0.1, 32 + r * 0.5, 32 + r * 0.6, 32 + r * 0.5, 32 + r * 0.6, deep)
            + shine(32 - r * 0.35, 32 - r * 0.4, r * 0.35, r * 0.2))

# Treasures
def longevity_peach():
    return (glow(32, 34, 22, '#ffd0c0', 0.22)
            + '<path d="M33 14 C42 18 50 26 48 38 C46 48 39 53 32 53 C25 53 18 48 16 38 C14 26 22 18 33 14 Z" fill="#ffc7a8" %s/>' % O
            + '<path d="M38 20 C46 26 48 36 44 46 C40 50 36 50 34 46 C40 40 42 30 38 20 Z" fill="#ff8a7a" fill-opacity="0.7"/>'
            + '<path d="M33 15 C27 26 27 40 32 52" stroke="#e0705a" stroke-width="1.6" fill="none"/>'
            + leaf(33, 15, 20, 10, 4, '#6fbf6a', '#3f8a4c') + leaf(33, 15, 44, 8, 3.4, '#8fd98f', '#3f8a4c') + shine(23, 30, 4, 2.4, -60))

def stone_milk():
    return ('<path d="M6 8 L58 8 L58 14 C50 16 46 14 40 16 L34 34 L30 34 L24 16 C18 14 14 16 6 14 Z" fill="#8a8a7c" %s/>' % O
            + '<path d="M28 18 L32 30" stroke="#c9c9ba" stroke-width="1.4"/>'
            + glow(32, 42, 10, '#ffffff', 0.35)
            + '<path d="M32 36 C34 40 36 42 36 44 C36 47 34 48 32 48 C30 48 28 47 28 44 C28 42 30 40 32 36 Z" fill="#f6f3e8" %s/>' % O2
            + '<path d="M18 52 C18 58 46 58 46 52 Z" fill="#8a8a7c" %s/><ellipse cx="32" cy="52" rx="14" ry="3" fill="#f6f3e8" %s/>' % (O2, O2))

def ginseng():
    return ('<path d="M31 25 L31 12" stroke="%s" stroke-width="3.6" stroke-linecap="round"/><path d="M31 25 L31 12" stroke="#5fae6a" stroke-width="1.8" stroke-linecap="round"/>' % INK
            + ''.join(leaf(31, 13, x, y, 3, '#7fc87a', '#3f8a4c') for x, y in [(18, 10), (22, 3), (40, 3), (44, 10)])
            + ''.join('<circle cx="%d" cy="%d" r="2.2" fill="%s" %s/>' % (x, y, RED, 'stroke="%s" stroke-width="1"' % INK) for x, y in [(29, 9), (33, 8), (31, 5)])
            + '<path d="M26 24 C22 30 23 38 25 43 C22 47 18 50 14 54 C19 53 24 50 27 47 C29 51 31 55 34 58 C34 53 33 49 34 45 C38 40 39 30 36 24 Z" fill="#e3c38f" %s/>' % O
            + '<path d="M25 33 C22 33 18 30 15 31 M36 32 C40 31 44 34 48 33 M34 45 C38 48 40 52 44 52 M27 29 L35 29 M27 37 L34 37" stroke="#9c7a4a" stroke-width="1.2" fill="none" stroke-linecap="round"/>')

DROP = 'M32 10 C38 22 46 30 46 40 C46 48 40 54 32 54 C24 54 18 48 18 40 C18 30 26 22 32 10 Z'

def spirit_marrow():
    inner = lambda s, color: '<path d="%s" fill="%s" transform="translate(32 52) scale(%.2f) translate(-32 -52)"/>' % (DROP, color, s)
    return (glow(32, 38, 24, '#ffb3a0', 0.3)
            + '<path d="%s" fill="#b07ad8" %s/>' % (DROP, O)
            + inner(0.72, '#ff9a7a') + inner(0.42, '#ffd98a')
            + shine(26, 36, 3, 5, 20) + sparkle(14, 20, 3.4) + sparkle(50, 18, 2.8))

def fire_lotus():
    petals = ''
    for a, color in [(-64, '#b9452a'), (64, '#b9452a'), (-34, '#e8483a'), (34, '#e8483a'), (0, '#ff7a45')]:
        petals += '<g transform="translate(32 46) rotate(%d)"><path d="M0 0 C-8 -8 -7 -21 0 -28 C7 -21 8 -8 0 0 Z" fill="%s" %s/><path d="M0 -4 L0 -22" stroke="#ffd66b" stroke-width="1" stroke-opacity="0.7"/></g>' % (a, color, O2)
    flames = ''.join('<path d="M%d %d C%d %d %d %d %d %d C%d %d %d %d %d %d Z" fill="#ffd66b" fill-opacity="0.9"/>' % (x, y, x + 3, y + 4, x + 3, y + 8, x, y + 9, x - 3, y + 8, x - 3, y + 4, x, y)
                     for x, y in [(32, 12), (16, 22), (48, 22)])
    embers = '<path d="M14 54 C20 48 44 48 50 54 Z" fill="#7f2a1c" %s/>' % O2 + ''.join('<circle cx="%d" cy="%d" r="1.3" fill="#ffa765"/>' % p for p in [(22, 52), (30, 51), (40, 52)])
    return glow(32, 36, 24, '#ffa765', 0.3) + embers + petals + flames + '<ellipse cx="32" cy="44" rx="6" ry="3" fill="#ffd66b" %s/>' % O2

def soul_wood():
    return (glow(32, 30, 22, '#a8d8ff', 0.22)
            + '<path d="M10 40 L40 26 L46 38 L16 52 Z" fill="#6a4a5a" %s/>' % O
            + '<path d="M16 42 L38 32 M20 47 L42 36" stroke="#4a3040" stroke-width="1.2"/>'
            + '<ellipse cx="43" cy="32" rx="4.5" ry="7" transform="rotate(-25 43 32)" fill="#c9a48a" %s/>' % O2
            + '<ellipse cx="43" cy="32" rx="2" ry="3.4" transform="rotate(-25 43 32)" fill="none" stroke="#8a6050" stroke-width="1"/>'
            + '<path d="M26 34 C22 26 30 22 26 14 C34 18 34 26 30 30" stroke="#d9f0ff" stroke-width="2.2" fill="none" stroke-linecap="round"/>'
            + '<path d="M26 14 C24 10 28 8 30 10 C30 12 28 13 26 14 Z" fill="#d9f0ff"/>')

def vermilion_fruit():
    twig = '<path d="M12 12 C22 14 28 18 32 24" stroke="%s" stroke-width="4" fill="none" stroke-linecap="round"/><path d="M12 12 C22 14 28 18 32 24" stroke="#7a5a3a" stroke-width="2" fill="none" stroke-linecap="round"/>' % INK
    leaves = leaf(22, 14, 34, 6, 4, '#6fbf6a', '#3f8a4c') + leaf(26, 17, 12, 24, 3.6, '#8fd98f', '#3f8a4c')
    fruits = ''
    for x, y, r in [(26, 38, 9), (42, 34, 8), (36, 48, 7)]:
        fruits += '<path d="M32 24 L%d %d" stroke="#7a5a3a" stroke-width="1.4"/>' % (x, y - r)
    for x, y, r in [(26, 38, 9), (42, 34, 8), (36, 48, 7)]:
        fruits += '<circle cx="%d" cy="%d" r="%d" fill="#e0402e" %s/>' % (x, y, r, O) + shine(x - r * 0.35, y - r * 0.35, r * 0.35, r * 0.2)
    return glow(34, 40, 20, '#ff8a6a', 0.22) + twig + leaves + fruits

def lotus_seed():
    holes = ''.join('<ellipse cx="%d" cy="%d" rx="2" ry="1.2" fill="#2f5a3a"/>' % p for p in [(26, 24), (32, 23), (38, 24), (29, 27), (35, 27)])
    return ('<path d="M32 46 C31 50 30 54 28 58" stroke="%s" stroke-width="4" fill="none"/><path d="M32 46 C31 50 30 54 28 58" stroke="#5fae6a" stroke-width="2" fill="none"/>' % INK
            + '<path d="M17 25 L24 44 C27 48 37 48 40 44 L47 25 Z" fill="#7fb87a" %s/>' % O
            + '<ellipse cx="32" cy="25" rx="15" ry="5" fill="#a6d39a" %s/>' % O2 + holes
            + glow(46, 44, 11, '#e2f6ff', 0.5)
            + '<ellipse cx="46" cy="44" rx="5" ry="6.5" fill="#f4f1dc" %s/>' % O2 + shine(44.5, 41.5, 1.6, 2.4, 0, 0.8)
            + sparkle(54, 34, 2.6) + sparkle(38, 54, 2.2))

# Recipes, tools, talismans
def recipe(pill_color):
    return ('<rect x="12" y="18" width="40" height="30" fill="%s" %s/>' % (PAPER, O)
            + ''.join('<path d="M%d 23 L%d %d" stroke="#5c5448" stroke-width="1.6" stroke-linecap="round"/>' % (x, x, 43 - (x * 7) % 9) for x in range(18, 36, 4))
            + '<circle cx="43" cy="28" r="4.6" fill="%s" %s/>' % (pill_color, O2) + shine(41.5, 26.5, 1.4, 0.9)
            + '<rect x="40" y="37" width="6" height="6" fill="%s"/>' % RED
            + ''.join('<rect x="%d" y="14" width="5" height="38" rx="2" fill="#7a4a2a" %s/>' % (x, O2) for x in (8, 51)))

def furnace(main, deep, light, rune=''):
    legs = ''.join('<path d="M%d %d L%d %d" stroke="%s" stroke-width="5" stroke-linecap="round"/><path d="M%d %d L%d %d" stroke="%s" stroke-width="2.6" stroke-linecap="round"/>'
                   % (x0, 46, x1, 56, INK, x0, 46, x1, 56, deep) for x0, x1 in [(22, 18), (42, 46), (32, 32)])
    ears = ''.join('<path d="M%d 27 L%d 17 L%d 17 L%d 27" fill="none" stroke="%s" stroke-width="4.4"/><path d="M%d 27 L%d 17 L%d 17 L%d 27" fill="none" stroke="%s" stroke-width="2"/>'
                   % (x, x - d, x - d + 5 * (1 if d > 0 else -1), x + 4 * (1 if d > 0 else -1), INK, x, x - d, x - d + 5 * (1 if d > 0 else -1), x + 4 * (1 if d > 0 else -1), main)
                   for x, d in [(17, 2), (47, -2)])
    return (glow(32, 50, 14, '#ffa765', 0.3) + legs + ears
            + '<path d="M15 30 C15 44 22 50 32 50 C42 50 49 44 49 30 Z" fill="%s" %s/>' % (main, O)
            + '<path d="M18 36 C24 39 40 39 46 36" stroke="%s" stroke-width="1.4" fill="none"/>' % deep + rune
            + '<path d="M19 28 C19 19 45 19 45 28 Z" fill="%s" %s/>' % (main, O)
            + '<rect x="13" y="27" width="38" height="5" rx="2" fill="%s" %s/>' % (deep, O2)
            + '<circle cx="32" cy="18" r="3" fill="%s" %s/>' % (light, O2)
            + '<path d="M20 34 C21 40 24 45 28 47" stroke="#ffffff" stroke-opacity="0.35" stroke-width="1.6" fill="none" stroke-linecap="round"/>')

FURNACE_RUNE = ('<path d="M26 42 C28 39 31 41 32 43 C33 41 36 39 38 42" stroke="#ff7a45" stroke-width="1.6" fill="none" stroke-linecap="round"/>'
                '<circle cx="32" cy="44" r="1.4" fill="#ffd66b"/>')

TALISMAN_GLYPHS = {
    'thunder': '<path d="M35 19 L28 31 L35 31 L28 44" stroke="%s" stroke-width="2.4" fill="none" stroke-linecap="round" stroke-linejoin="round"/>' % RED,
    'gold': ('<circle cx="32" cy="30" r="5" fill="none" stroke="%s" stroke-width="2"/>' % RED
             + ''.join('<path d="M%.1f %.1f L%.1f %.1f" stroke="%s" stroke-width="1.6" stroke-linecap="round"/>' % (*rot(32, 30, 7.5, a), *rot(32, 30, 10, a), RED) for a in range(0, 360, 45))
             + '<path d="M28 42 L36 42" stroke="%s" stroke-width="1.8" stroke-linecap="round"/>' % RED),
    'bind': ('<path d="M27 21 L37 21 M32 18 L32 21 M26 26 L38 26 M32 26 L32 43 M28 33 L36 33 M26 43 L38 43" stroke="%s" stroke-width="1.9" fill="none" stroke-linecap="round"/>' % RED
             + '<circle cx="32" cy="33" r="7.5" fill="none" stroke="%s" stroke-width="1.2" stroke-dasharray="2 2"/>' % RED),
    'earth': ('<path d="M25 32 L32 21 L39 32 Z" fill="none" stroke="%s" stroke-width="2" stroke-linejoin="round"/>' % RED
              + '<path d="M32 35 L32 45 M28.5 41.5 L32 45 L35.5 41.5" stroke="%s" stroke-width="1.9" fill="none" stroke-linecap="round" stroke-linejoin="round"/>' % RED),
    'fire': ('<path d="M32 19 C36 24 38 28 37 32 C36 36 34 38 32 38 C30 38 27 36 27 32 C27 28 31 27 31 22 Z" fill="none" stroke="%s" stroke-width="2" stroke-linejoin="round"/>' % RED
             + '<path d="M27 42 C29 40 31 44 33 42 C35 40 37 44 38 42" stroke="%s" stroke-width="1.6" fill="none" stroke-linecap="round"/>' % RED),
}

def talisman(glyph, paper='#f2d27a'):
    return ('<g transform="rotate(-8 32 32)"><rect x="21" y="8" width="22" height="48" rx="1.5" fill="%s" %s/>' % (paper, O)
            + '<rect x="23.5" y="10.5" width="17" height="43" fill="none" stroke="%s" stroke-width="1.1"/>' % RED
            + '<path d="M29 14 L32 12 L35 14" stroke="%s" stroke-width="1.6" fill="none" stroke-linecap="round"/>' % RED
            + TALISMAN_GLYPHS[glyph]
            + '<path d="M27 49 C29 47 33 51 37 48" stroke="%s" stroke-width="1.5" fill="none" stroke-linecap="round"/></g>' % RED)

def fire_pearl():
    flames = ''.join('<g transform="translate(%d %d) rotate(%d)"><path d="M0 0 C3 -4 3 -8 0 -12 C-3 -8 -3 -4 0 0 Z" fill="#ffa765" %s/></g>' % (x, y, a, O2)
                     for x, y, a in [(17, 51, -40), (47, 51, 40), (15, 25, -70), (49, 25, 70)])
    return (flames + glow(32, 34, 20, '#bfe9ff', 0.35)
            + '<circle cx="32" cy="34" r="17" fill="none" stroke="#bfe9ff" stroke-width="1.4" stroke-dasharray="3 3"/>'
            + '<circle cx="32" cy="34" r="11" fill="#8fd0ef" %s/>' % O
            + '<path d="M21.6 37 A11 11 0 0 0 42.4 37 A12 8 0 0 1 21.6 37 Z" fill="#2f739e" fill-opacity="0.45"/>'
            + shine(28, 30, 3.6, 2.2))

PILLS = {  # main, deep, light
    'foundation': ('#f2c75c', '#a87a2a', '#ffe6a0'),
    'huiqi': ('#8fd0ef', '#2f739e', '#e2f6ff'),
    'liaoshang': ('#ef7a6a', '#a8392e', '#ffd0c0'),
    'ningqi': ('#a996e0', '#5e4ca0', '#e4dcff'),
    'pozhang': ('#ffa765', '#b9452a', '#ffe8b8'),
    'jiedu': ('#7fcf8a', '#3f8a4c', '#d8f5d0'),
    'xueyuan': ('#c8303c', '#7a1420', '#f4a8a8'),
}

def p(kind, fine=False, extra=''):
    main, deep, light = PILLS[kind]
    if kind == 'pozhang':
        extra += pill_crack(deep)
    if kind == 'foundation':
        extra += pill_band()
    return pill(main, deep, light, fine, extra)

GOODS = {  # item id: (back, subject)
    'huichun_grass': ('wood', grass_tuft()),
    'chiyan_flower': ('fire', fire_flower()),
    'ninglu_grass': ('water', dew_grass()),
    'lingzhi': ('earth', lingzhi()),
    'snake_gall': ('water', gall('#3f7a52', '#1f4a32', '#8fd98f')),
    'foundation_pill': ('earth', p('foundation')),
    'huiqi_pill': ('water', p('huiqi')),
    'liaoshang_pill': ('fire', p('liaoshang')),
    'ningqi_pill': ('none', p('ningqi')),
    'pozhang_pill': ('fire', p('pozhang')),
    'liaoshang_pill_fine': ('fire', p('liaoshang', True)),
    'huiqi_pill_fine': ('water', p('huiqi', True)),
    'ningqi_pill_fine': ('none', p('ningqi', True)),
    'pozhang_pill_fine': ('fire', p('pozhang', True)),
    'foundation_pill_fine': ('earth', p('foundation', True)),
    'polin_powder': ('wood', powder_packet()),
    'yanshou_dan': ('wood', peach_pill()),
    'jiedu_dan': ('wood', p('jiedu')),
    'xiaxue_zhi': ('fire', xiaxue()),
    'xueyuan_dan': ('fire', p('xueyuan')),
    'auction_invitation': ('none', invitation()),
    'azhi_token': ('none', bamboo_tag()),
    'peddler_pack': ('none', peddler_pack()),
    'ore_qinggang': ('metal', bars('#9fc4bf', '#5f8a86', '#77a39e')),
    'ore_xuantie': ('metal', bars('#6b7480', '#323a45', '#4a5360')),
    'ore_hantie': ('water', crystals('#d6eef7', '#86b5c8', '#ffffff', '#bfe9ff')),
    'dihuo_jing': ('fire', crystals('#ff7a45', '#b9452a', '#ffd66b', '#ffa765')),
    'jade_qing': ('wood', jade_stone('#a39a86', '#86cba6', '#4d8a69')),
    'jade_mo': ('none', jade_stone('#8a8070', '#3f5a4f', '#1f2f29')),
    'jade_han': ('water', jade_stone('#b4b0a8', '#d9f2f3', '#8ebec2')),
    'silk_qing': ('wood', cloth_bolt('#69b0a5', '#3d756d', '#bfe3dc')),
    'silk_xuancan': ('none', cloth_bolt('#4a4060', '#2a2238', '#8a7aa8')),
    'silk_yunjin': ('metal', cloth_bolt('#ecdcaa', '#b49a5c', '#fff6dc', CLOUD_PATTERN)),
    'wolf_fang': ('none', fang()),
    'shanxiao_pelt': ('earth', pelt()),
    'huoya_feather': ('fire', feather()),
    'yanjia_scale': ('earth', scales()),
    'xiong_dan': ('none', gall('#2f3a35', '#11181a', '#86cba6')),
    'yaodan_small': ('earth', beast_core('#f2c75c', '#a87a2a', '#ffe6a0', 8)),
    'yaodan': ('fire', beast_core('#ef7a4a', '#9a3a22', '#ffd0a0', 13)),
    'shouyuan_guo': ('wood', longevity_peach()),
    'qiannian_shiru': ('metal', stone_milk()),
    'jiuqu_lingshen': ('earth', ginseng()),
    'xiaguang_lingsui': ('fire', spirit_marrow()),
    'dixin_huolian': ('fire', fire_lotus()),
    'yanghun_mu': ('water', soul_wood()),
    'qiannian_zhuguo': ('fire', vermilion_fruit()),
    'tianxin_lianzi': ('water', lotus_seed()),
    'recipe_liaoshang': ('none', recipe(PILLS['liaoshang'][0])),
    'recipe_huiqi': ('none', recipe(PILLS['huiqi'][0])),
    'recipe_ningqi': ('none', recipe(PILLS['ningqi'][0])),
    'recipe_pozhang': ('none', recipe(PILLS['pozhang'][0])),
    'recipe_foundation': ('earth', recipe(PILLS['foundation'][0])),
    'furnace_bronze': ('fire', furnace('#c99a5c', '#8a6232', '#f2d68b')),
    'furnace_purple': ('fire', furnace('#b8644a', '#7a3a2a', '#f2b08b')),
    'furnace_xuantie': ('fire', furnace('#4a5360', '#262c35', '#9fb0c0', FURNACE_RUNE)),
    'kongho_fu': ('fire', talisman('fire')),
    'bihuo_zhu': ('water', fire_pearl()),
    'lei_fu': ('metal', talisman('thunder')),
    'jinguang_fu': ('metal', talisman('gold')),
    'dingshen_fu': ('earth', talisman('bind')),
    'dundi_fu': ('earth', talisman('earth')),
}
for item_id, (key, subject) in GOODS.items():
    write('items/%s.svg' % item_id, back(EL[key][1] if key in EL else '#8fb3ad', PATTERN[key]) + subject)
import json
catalogue = json.load(open(os.path.join(ROOT, 'data', 'items.json'), encoding='utf-8'))
for item_id in catalogue:
    if item_id not in GOODS:
        print('no icon drawn for', item_id)
print('written')
