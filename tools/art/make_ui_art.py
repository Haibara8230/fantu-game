"""Writes the game's vector UI art: duel status badges, the five qi orbs, grade badges, the seal, the
paper tag, the divider and the map markers. Flat colors, clear dark outlines, one restrained highlight,
to sit with the hand-drawn art. Usage: make_icons.py <project root>"""
import os, sys, math

ROOT = sys.argv[1]
OUT = os.path.join(ROOT, 'assets', 'art', 'ui')
INK = '#26392f'          # restrained ink outline, matching the approved vector samples
BASE = '#293f39'         # quiet badge field
PAPER = '#efe2bf'

def write(rel, body, w=64, h=64):
    path = os.path.join(OUT, rel)
    os.makedirs(os.path.dirname(path), exist_ok=True)
    svg = ('<svg xmlns="http://www.w3.org/2000/svg" width="%d" height="%d" viewBox="0 0 %d %d">\n%s\n</svg>\n'
           % (w, h, w, h, body.strip()))
    open(path, 'w', encoding='utf-8', newline='\n').write(svg)

# --- Duel status badges --------------------------------------------------------------------------
# A round badge: the field, a rim in the kind's color (harm red, help gold, others teal), a faint inner
# ring, then the glyph in flat color outlined in ink.
HARM, HELP, PLAIN = '#d0745b', '#d9b86c', '#86c7c4'

def badge(rim, glyph):
    return ('<circle cx="32" cy="32" r="29" fill="%s" stroke="%s" stroke-width="1.5"/>\n%s'
            % (BASE, rim, glyph))

O = 'stroke="%s" stroke-width="1.2" stroke-linejoin="round" stroke-linecap="round"' % INK

STATUS = {
    # 灼烧: a flame with its hot heart.
    'burn': (HARM, '<path d="M32 12 C39 21 46 27 45 38 C44 47 38 52 32 52 C25 52 19 47 19 39 C19 31 25 28 26 20 C29 25 30 29 33 31 C35 26 35 19 32 12 Z" fill="#f59b5a" %s/>'
                   '<path d="M32 30 C36 35 39 38 38 43 C37 47 35 49 32 49 C29 49 26 47 26 43 C26 39 29 37 30 33 C31 35 32 36 33 37 C33 35 33 33 32 30 Z" fill="#ffe0a3"/>' % O),
    # 寒蚀: a blade turned down, rimed with ice.
    'weaken': (HARM, '<path d="M32 50 L26 34 L29 34 L29 15 L35 15 L35 34 L38 34 Z" fill="#b9e6f5" %s/>'
                     '<path d="M24 15 L40 15" %s fill="none"/>'
                     '<path d="M19 22 L22 28 L19 34 L16 28 Z M45 22 L48 28 L45 34 L42 28 Z" fill="#d6f3ff" stroke="%s" stroke-width="1.6" stroke-linejoin="round"/>' % (O, O, INK)),
    # 破甲: a shield split by a crack, a shard falling away.
    'sunder': (HARM, '<path d="M32 13 L47 18 L46 33 C45 42 39 48 32 52 C25 48 19 42 18 33 L17 18 Z" fill="#9fb1b4" %s/>'
                     '<path d="M32 14 L29 25 L35 31 L30 40 L33 51" fill="none" stroke="%s" stroke-width="2.6" stroke-linejoin="round"/>'
                     '<path d="M43 38 L52 44 L46 51 L41 45 Z" fill="#9fb1b4" %s/>' % (O, INK, O)),
    # 冰封: a six-armed frost star.
    'slow': (HARM, ''.join('<g transform="rotate(%d 32 32)"><path d="M32 32 L32 13 M32 19 L27 15 M32 19 L37 15 M32 25 L28 22 M32 25 L36 22" stroke="%s" stroke-width="5" stroke-linecap="round" fill="none"/>'
                           '<path d="M32 32 L32 13 M32 19 L27 15 M32 19 L37 15 M32 25 L28 22 M32 25 L36 22" stroke="#bfeaf9" stroke-width="2.4" stroke-linecap="round" fill="none"/></g>' % (a, INK) for a in range(0, 360, 60))
                   + '<circle cx="32" cy="32" r="4" fill="#e8f8ff" %s/>' % O),
    # 流血: a drop, two drips beside it.
    'bleed': (HARM, '<path d="M30 13 C35 22 42 29 42 37 C42 44 36 49 30 49 C24 49 18 44 18 37 C18 29 25 22 30 13 Z" fill="#d9504c" %s/>'
                    '<path d="M24 36 C24 32 26 29 28 27" stroke="#f6a49b" stroke-width="2.4" fill="none" stroke-linecap="round"/>'
                    '<path d="M44 17 C46 21 48 23 48 26 C48 28.5 46 30 44 30 C42 30 40 28.5 40 26 C40 23 42 21 44 17 Z" fill="#d9504c" %s/>'
                    '<path d="M46 36 C47.5 39 49 40.5 49 42.5 C49 44.5 47.5 45.5 46 45.5 C44.5 45.5 43 44.5 43 42.5 C43 40.5 44.5 39 46 36 Z" fill="#d9504c" %s/>' % (O, O, O)),
    # 缠绕: a vine wound twice about, a leaf at each end.
    'entangle': (HARM, '<path d="M32 12 L32 52" stroke="%s" stroke-width="7" stroke-linecap="round"/><path d="M32 12 L32 52" stroke="#b98a55" stroke-width="3.6" stroke-linecap="round"/>'
                       '<path d="M20 18 C40 20 42 28 32 30 C22 32 22 40 44 42 M20 46 C28 47 34 49 38 52" stroke="%s" stroke-width="6.5" fill="none" stroke-linecap="round"/>'
                       '<path d="M20 18 C40 20 42 28 32 30 C22 32 22 40 44 42 M20 46 C28 47 34 49 38 52" stroke="#8fd68f" stroke-width="3.2" fill="none" stroke-linecap="round"/>'
                       '<path d="M20 18 C15 15 13 12 13 10 C17 10 20 13 20 18 Z M44 42 C49 40 52 41 54 43 C51 46 47 46 44 42 Z" fill="#b8ef9f" %s/>' % (INK, INK, O)),
    # 禁疗: a healing leaf struck through.
    'wound': (HARM, '<path d="M20 44 C18 30 28 18 46 16 C46 32 36 44 20 44 Z" fill="#9adf91" %s/>'
                    '<path d="M21 43 L38 26" stroke="%s" stroke-width="2" fill="none"/>'
                    '<path d="M16 16 L48 48" stroke="%s" stroke-width="7.5" stroke-linecap="round"/>'
                    '<path d="M16 16 L48 48" stroke="#e05a4f" stroke-width="4" stroke-linecap="round"/>' % (O, INK, INK)),
    # 蓄势: three rising chevrons.
    'focus': (HELP, ''.join('<path d="M20 %d L32 %d L44 %d" stroke="%s" stroke-width="7" fill="none" stroke-linecap="round" stroke-linejoin="round"/>'
                            '<path d="M20 %d L32 %d L44 %d" stroke="%s" stroke-width="3.6" fill="none" stroke-linecap="round" stroke-linejoin="round"/>'
                            % (y + 10, y, y + 10, INK, y + 10, y, y + 10, c) for y, c in [(14, '#ffe6a0'), (24, '#ffd27a'), (34, '#e8b45a')])),
    # 帮手: two hooded figures.
    'minions': (PLAIN, '<circle cx="24" cy="24" r="6" fill="#c8d6d2" %s/><path d="M14 46 C14 36 18 32 24 32 C30 32 34 36 34 46 Z" fill="#c8d6d2" %s/>'
                       '<circle cx="41" cy="27" r="5.5" fill="#9fb4ae" %s/><path d="M32 47 C32 38 36 35 41 35 C46 35 50 38 50 47 Z" fill="#9fb4ae" %s/>' % (O, O, O, O)),
    # 秘术: a burning eye.
    'fervor': (HELP, '<path d="M14 36 C20 27 26 24 32 24 C38 24 44 27 50 36 C44 45 38 48 32 48 C26 48 20 45 14 36 Z" fill="#f3d9a6" %s/>'
                     '<circle cx="32" cy="36" r="7.5" fill="#d9504c" %s/><circle cx="32" cy="36" r="3" fill="%s"/>'
                     '<path d="M32 22 C29 18 30 14 33 11 C33 15 37 16 36 21 Z M24 24 C21 21 21 18 23 15 C24 18 27 19 26 23 Z M40 24 C43 21 43 18 41 15 C40 18 37 19 38 23 Z" fill="#f59b5a" %s/>' % (O, O, INK, O)),
    # 护盾: a round guard with a coiled center.
    'shield': (HELP, '<circle cx="32" cy="33" r="17" fill="#d9b86c" %s/><circle cx="32" cy="33" r="11" fill="none" stroke="%s" stroke-width="2"/>'
                     '<path d="M32 26 C36 26 38 29 36 32 C34 35 30 34 30 37 C30 39 32 40 34 40" stroke="%s" stroke-width="2.6" fill="none" stroke-linecap="round"/>'
                     '<path d="M24 22 C27 19.5 30 18.5 32 18.5" stroke="#fff1c7" stroke-width="2.2" fill="none" stroke-linecap="round"/>' % (O, INK, INK)),
}
for key, (rim, glyph) in STATUS.items():
    write('status/%s.svg' % key, badge(rim, glyph))

# --- The five qi orbs ----------------------------------------------------------------------------
# A flat sphere in the element's color, a darker lower crescent, one highlight, the element's sign.
ORBS = {
    'metal': ('#e9e1bd', '#b9ac78', '<path d="M32 15 L36 28 L49 32 L36 36 L32 49 L28 36 L15 32 L28 28 Z" fill="#fffbe9" %s/>' % O),
    'wood': ('#8fd98f', '#4e9a57', '<path d="M20 45 C17 31 26 18 45 17 C46 33 36 45 20 45 Z" fill="#d6f7c4" %s/><path d="M21 44 L38 27" stroke="%s" stroke-width="2"/>' % (O, INK)),
    'water': ('#8fd3f0', '#3f86b3', '<path d="M14 30 C19 25 24 25 29 30 C34 35 39 35 44 30 C46 28 48 27 50 27" stroke="%s" stroke-width="7" fill="none" stroke-linecap="round"/>'
                                  '<path d="M14 30 C19 25 24 25 29 30 C34 35 39 35 44 30 C46 28 48 27 50 27" stroke="#e6f8ff" stroke-width="3.4" fill="none" stroke-linecap="round"/>'
                                  '<path d="M16 40 C21 35 26 35 31 40 C36 45 41 45 46 40" stroke="%s" stroke-width="6" fill="none" stroke-linecap="round"/>'
                                  '<path d="M16 40 C21 35 26 35 31 40 C36 45 41 45 46 40" stroke="#c7ecfa" stroke-width="2.8" fill="none" stroke-linecap="round"/>' % (INK, INK)),
    'fire': ('#ffad6b', '#c4562f', '<path d="M32 14 C38 22 44 28 43 37 C42 45 37 49 32 49 C26 49 21 45 21 38 C21 31 27 28 28 21 C30 25 31 28 33 30 C35 26 34 20 32 14 Z" fill="#ffe7b3" %s/>' % O),
    'earth': ('#dcb87a', '#8f6a35', '<path d="M12 46 L25 24 L32 34 L39 20 L52 46 Z" fill="#f6e2b6" %s/><path d="M36 26 L39 20 L42 26" fill="#fff6dd" stroke="%s" stroke-width="1.5" stroke-linejoin="round"/>' % (O, INK)),
}
for key, (color, deep, sign) in ORBS.items():
    write('orbs/%s.svg' % key,
          '<circle cx="32" cy="32" r="28" fill="%s" stroke="%s" stroke-width="3.5"/>\n'
          '<path d="M8.5 38 A24.5 24.5 0 0 0 55.5 38 A28 22 0 0 1 8.5 38 Z" fill="%s" fill-opacity="0.55"/>\n'
          '<ellipse cx="23" cy="18" rx="9" ry="5" fill="#ffffff" fill-opacity="0.45" transform="rotate(-25 23 18)"/>\n%s'
          % (color, INK, deep, sign))

# --- Grade badges: 白绿蓝紫橙红, each step more ornate -------------------------------------------
GRADES = ['#d6d0c2', '#86bf7f', '#6fa6db', '#b083d8', '#e59d52', '#e0574e']
GOLD = '#d9b86c'
def gem(color, facets):
    body = '<path d="M24 8 L38 24 L24 40 L10 24 Z" fill="%s" %s/>' % (color, O)
    if facets:
        body += '<path d="M24 8 L24 40 M10 24 L38 24" stroke="%s" stroke-opacity="0.45" stroke-width="1.5"/>' % INK
        body += '<path d="M24 13 L33 24 L24 24 Z" fill="#ffffff" fill-opacity="0.35"/>'
    return body
GRADE_ART = [
    '<circle cx="24" cy="24" r="9" fill="%s" %s/><circle cx="21" cy="21" r="3" fill="#ffffff" fill-opacity="0.5"/>' % (GRADES[0], O),
    gem(GRADES[1], False) + '<path d="M18 20 L24 13" stroke="#ffffff" stroke-opacity="0.5" stroke-width="2.4" stroke-linecap="round"/>',
    gem(GRADES[2], True) + '<circle cx="5" cy="24" r="2.6" fill="%s" %s/><circle cx="43" cy="24" r="2.6" fill="%s" %s/>' % (GRADES[2], O, GRADES[2], O),
    '<path d="M9 30 C3 30 2 22 7 20 C10 19 12 22 10 24 M39 30 C45 30 46 22 41 20 C38 19 36 22 38 24" stroke="%s" stroke-width="2.6" fill="none" stroke-linecap="round"/>' % GOLD + gem(GRADES[3], True),
    ''.join('<path d="M24 24 L%.1f %.1f" stroke="%s" stroke-width="3" stroke-linecap="round"/>' % (24 + 21 * math.cos(math.radians(a)), 24 + 21 * math.sin(math.radians(a)), GOLD) for a in range(0, 360, 45))
        + '<path d="M9 31 C3 31 2 22 7 20 M39 31 C45 31 46 22 41 20" stroke="%s" stroke-width="2.6" fill="none" stroke-linecap="round"/>' % GOLD + gem(GRADES[4], True),
    '<circle cx="24" cy="24" r="21" fill="none" stroke="%s" stroke-width="2.2"/>' % GOLD
        + ''.join('<path d="M%.1f %.1f L%.1f %.1f L%.1f %.1f Z" fill="%s" %s/>' % (
            24 + 19 * math.cos(math.radians(a - 9)), 24 + 19 * math.sin(math.radians(a - 9)),
            24 + 24 * math.cos(math.radians(a)), 24 + 24 * math.sin(math.radians(a)),
            24 + 19 * math.cos(math.radians(a + 9)), 24 + 19 * math.sin(math.radians(a + 9)), '#f59b5a', 'stroke="%s" stroke-width="1.2"' % INK) for a in range(0, 360, 30))
        + gem(GRADES[5], True) + '<circle cx="24" cy="24" r="3.2" fill="#fff1c7" %s/>' % O,
]
for index, art in enumerate(GRADE_ART):
    write('grades/grade_%d.svg' % index, art, 48, 48)

# --- The seal: a vermilion stamp, worn at the edges; the character is set over it ---------------
holes = ''.join('<circle cx="%.1f" cy="%.1f" r="%.1f" fill="#f0e3c0"/>' % p for p in
                [(9, 14, 1.4), (55, 10, 1.1), (57, 49, 1.6), (12, 55, 1.2), (31, 58, 0.9), (6, 34, 1.0), (49, 57, 1.0), (58, 27, 0.8)])
write('seal.svg', '<path d="M7 9 Q8 6 12 6 L52 5 Q58 6 58 11 L59 52 Q58 58 52 58 L12 59 Q6 58 6 53 Z" fill="#b8392c" %s/>'
                  '<path d="M12 11 L52 10.5 L53 53 L11.5 53.5 Z" fill="none" stroke="#f0e3c0" stroke-opacity="0.85" stroke-width="2"/>%s'
                  % ('stroke="#7d2219" stroke-width="1.5"', holes))

# --- The paper tag a spot hangs by: a cord and knot above, a ragged foot -------------------------
# 9-slice: 48 wide; the cord takes the top 22, the foot the bottom 12.
def tag(paper, edge, cord):
    return ('<path d="M24 0 L24 9" stroke="%s" stroke-width="2.2"/>'
            '<circle cx="24" cy="12" r="3.6" fill="%s" stroke="%s" stroke-width="1.4"/>'
            '<path d="M21 14 C18 18 17 20 18 22 M27 14 C30 18 31 20 30 22" stroke="%s" stroke-width="1.8" fill="none" stroke-linecap="round"/>'
            '<path d="M5 19 L43 19 L43 140 L40 143 L36 140 L32 144 L27 140 L22 143 L17 140 L12 144 L8 140 L5 142 Z" fill="%s" stroke="%s" stroke-width="2" stroke-linejoin="round"/>'
            '<path d="M8 23 L40 23" stroke="%s" stroke-opacity="0.5" stroke-width="1.2"/>'
            '<path d="M8 135 L40 135" stroke="%s" stroke-opacity="0.5" stroke-width="1.2"/>'
            % (cord, cord, INK, cord, paper, edge, edge, edge))
write('tag.svg', tag(PAPER, '#6b5536', '#a8392e'), 48, 148)
write('tag_chosen.svg', tag('#f8ebc2', '#c79a45', '#d4473a'), 48, 148)

# --- A divider under headings: a line that fades out from a cloud coil ---------------------------
write('divider.svg', '<defs><linearGradient id="l" x1="0" x2="1"><stop offset="0" stop-color="%s" stop-opacity="0"/><stop offset="0.5" stop-color="%s"/><stop offset="1" stop-color="%s" stop-opacity="0"/></linearGradient></defs>'
                     '<path d="M4 12 L196 12" stroke="url(#l)" stroke-width="1.6"/>'
                     '<path d="M86 12 C86 6 93 5 95 9 C97 13 93 15 91 13 M114 12 C114 6 107 5 105 9 C103 13 107 15 109 13" stroke="%s" stroke-width="1.8" fill="none" stroke-linecap="round"/>'
                     '<path d="M96 12 L100 8 L104 12 L100 16 Z" fill="%s"/>' % (GOLD, GOLD, GOLD, GOLD, GOLD), 200, 24)

# --- Map markers by terrain: a round token holding the place's sign ------------------------------
TOKEN = '<circle cx="32" cy="32" r="27" fill="#13292c" stroke="%s" stroke-width="3"/><circle cx="32" cy="32" r="22.5" fill="none" stroke="%s" stroke-opacity="0.3" stroke-width="1.4"/>' % (GOLD, GOLD)
MARK = {
    # 宗门: a hall on its peak.
    'mountain': '<path d="M11 47 L24 26 L32 36 L40 24 L53 47 Z" fill="#7fa79a" %s/><path d="M22 26 L32 19 L42 26 Z" fill="#c9785f" %s/><path d="M25 26 L25 33 L39 33 L39 26" fill="#e9dcb8" %s/>' % (O, O, O),
    # 城镇: two roofs.
    'town': '<path d="M12 33 L22 25 L32 33 Z M30 30 L41 21 L52 30 Z" fill="#c9785f" %s/><path d="M14 33 L14 45 L30 45 L30 33 M33 30 L33 45 L50 45 L50 30" fill="#e9dcb8" %s/><path d="M20 38 L24 38 L24 45 L20 45 Z M39 36 L44 36 L44 41 L39 41 Z" fill="#6b5536"/>' % (O, O),
    # 渡口: a boat on the water.
    'ferry': '<path d="M14 36 L50 36 L44 44 L20 44 Z" fill="#b98a55" %s/><path d="M30 36 L30 16 L44 32 Z" fill="#e9dcb8" %s/><path d="M12 50 C17 47 22 47 27 50 C32 53 37 53 42 50 C46 48 49 48 52 49" stroke="#8fd3f0" stroke-width="2.6" fill="none" stroke-linecap="round"/>' % (O, O),
    # 坊市: a stall's roof and its lanterns.
    'market': '<path d="M10 25 L32 15 L54 25 Z" fill="#c9785f" %s/><path d="M15 25 L15 47 M49 25 L49 47 M13 47 L51 47" stroke="%s" stroke-width="3" stroke-linecap="round"/>'
              '<path d="M24 25 L24 29" stroke="%s" stroke-width="1.8"/><ellipse cx="24" cy="35" rx="5" ry="6.5" fill="#f59b5a" %s/><path d="M20 35 L28 35" stroke="%s" stroke-opacity="0.5" stroke-width="1.2"/>'
              '<path d="M35 28 L45 28 L45 43 L40 40 L35 43 Z" fill="#e9dcb8" %s/><path d="M38 32 L42 32 M38 36 L42 36" stroke="#a8392e" stroke-width="1.8" stroke-linecap="round"/>' % (O, INK, INK, O, INK, O),
    # 山岭: pines.
    'ridge': '<path d="M23 14 L33 30 L28 30 L36 42 L10 42 L18 30 L13 30 Z" fill="#6fae7c" %s/><path d="M42 20 L50 33 L46 33 L53 44 L31 44 L38 33 L34 33 Z" fill="#8cc792" %s/><path d="M23 42 L23 48 M42 44 L42 49" stroke="%s" stroke-width="3"/>' % (O, O, INK),
    # 山谷: twin peaks over a spring.
    'valley': '<path d="M10 42 L22 20 L32 34 L42 20 L54 42 Z" fill="#9b8a6c" %s/><path d="M20 44 C26 40 38 40 44 44 C38 48 26 48 20 44 Z" fill="#8fd3f0" %s/><circle cx="32" cy="30" r="2.6" fill="#f2a7b8" %s/>' % (O, O, O),
    # 洞府: a cave mouth in the rock.
    'ruin': '<path d="M10 47 L14 26 C18 16 46 16 50 26 L54 47 Z" fill="#8c8a80" %s/><path d="M22 47 L22 36 C22 27 42 27 42 36 L42 47 Z" fill="%s" %s/><path d="M18 26 L22 22 M44 24 L47 28" stroke="%s" stroke-width="2"/>' % (O, '#13292c', O, INK),
}
for key, sign in MARK.items():
    write('map/%s.svg' % key, TOKEN + sign)
print('written')
