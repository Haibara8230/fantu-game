"""Editable story/legacy icons for the new outline; art only, no item rules.

Usage: python -B tools/art/make_story_icons.py
The shared old-city motif is three arches over two water lines, within a broken
ring. Its repetition is intentional evidence, not an unrelated generic sigil.
"""
from pathlib import Path

ROOT = Path(__file__).resolve().parents[2]
OUT = ROOT / "assets/art/story/icons"
INK = '#293d35'
PAPER = '#e5d6b1'
GOLD = '#b39a5d'
LINE = f'stroke="{INK}" stroke-width="1.1" stroke-linejoin="round" stroke-linecap="round"'


def crest(color=GOLD):
    return (f'<g fill="none" stroke="{color}" stroke-width="2" stroke-linecap="round" stroke-linejoin="round">'
            '<path d="M43 14 A23 23 0 1 0 54 32 M49 20 L53 24"/>'
            '<path d="M17 38 V25 H47 V38 M22 38 V32 A3 3 0 0 1 28 32 V38 M29 38 V28 A3 3 0 0 1 35 28 V38 M36 38 V32 A3 3 0 0 1 42 32 V38"/>'
            '<path d="M18 43 Q25 40 32 43 T46 43 M20 48 Q26 45 32 48 T44 48"/>'
            '</g>')


def back():
    return '<rect x="1.5" y="1.5" width="61" height="61" rx="3" fill="#303c32" stroke="#a99a70" stroke-width="1"/>'


def book(fill, symbol):
    return (f'<path d="M13 10 L47 8 L51 52 L17 56 Z" fill="{fill}" {LINE}/>'
            f'<path d="M17 53 L49 49 L51 52 L17 56 Z" fill="{PAPER}" {LINE}/>'
            '<path d="M20 11 L24 52 M15 19 L23 18 M16 29 L24 28 M17 39 L25 38" fill="none" stroke="#c7ba90" stroke-width="1"/>'
            + symbol)


def sword(broken):
    blade = ('M23 39 L35 23 L37 26 L38 19 L44 18 L40 29 L37 28 L29 44 Z' if broken else
             'M23 39 L49 9 L47 23 L29 44 Z')
    return (f'<path d="{blade}" fill="#d1e0da" {LINE}/>'
            '<path d="M27 39 L45 16" stroke="#75a3aa" stroke-width="1.2"/>'
            f'<path d="M18 38 L32 48 L35 44 L21 34 Z" fill="{GOLD}" {LINE}/>'
            f'<path d="M22 41 L12 53 L17 57 L27 45 Z" fill="#42696b" {LINE}/>'
            '<path d="M14 55 Q10 58 10 62 M18 56 Q17 59 16 62" stroke="#7b9491" stroke-width="1.4" fill="none"/>'
            '<path d="M32 51 Q38 47 44 50 T56 50 M36 56 Q42 53 48 56" fill="none" stroke="#89b7b6" stroke-width="1.5"/>')


icons = {
    'old_city_seal': crest(),
    'mirror_back_fragment': (f'<path d="M13 18 L40 9 L50 24 L42 32 L47 48 L22 55 L10 38 L17 29 Z" fill="#877957" {LINE}/>'
                             '<g transform="translate(8 8) scale(.72)">' + crest('#c6b579') + '</g>'
                             '<path d="M40 10 L32 23 L39 31 L31 45" stroke="#4a5142" stroke-width="1.3" fill="none"/>'),
    'remnant_mirror': (f'<path d="M31 6 A25 25 0 1 0 54 22 L42 23 L46 12 Z" fill="#88988b" stroke="{GOLD}" stroke-width="3"/>'
                       '<path d="M12 39 L20 31 L24 38 L32 20 L35 28 L42 24" stroke="#c3d5c9" stroke-width="2" fill="none"/>'
                       '<g transform="translate(15 13) scale(.5)">' + crest('#536e63') + '</g>'
                       '<path d="M33 7 L27 20 L34 29 L25 43 L29 55" fill="none" stroke="#445a51" stroke-width="1.5"/>'),
    'old_city_record': (f'<path d="M15 9 L49 9 L49 52 L43 49 L38 54 L32 50 L25 54 L15 51 Z" fill="{PAPER}" {LINE}/>'
                        '<g transform="translate(13 11) scale(.6)">' + crest('#6f7e64') + '</g>'
                        '<path d="M21 44 H42 M21 47 H35" stroke="#9c926e" stroke-width="1"/>'),
    'zhaoshui_fenguang': book('#526f79', '<path d="M29 39 L44 15 L41 30 Z M31 40 L48 30 L42 39 Z" fill="#dbe7dd" stroke="#263e40" stroke-width=".8"/><path d="M28 45 Q34 42 40 45 T48 45" fill="none" stroke="#99c4bb" stroke-width="1.6"/>'),
    'cangxi_lu': book('#716e55', '<path d="M29 39 C27 29 32 20 38 18 C45 24 47 32 44 39 Z" fill="#344b43"/><path d="M32 36 C32 29 35 24 38 23 C41 27 43 32 41 36 Z" fill="#bac4a1"/><path d="M28 42 Q34 39 39 42 T48 42 M30 47 Q37 44 43 47" fill="none" stroke="#acb99c" stroke-width="1.5"/>'),
    'tingchao_broken': sword(True),
    'tingchao_repaired': sword(False),
    'wenren_sea_chart': (f'<path d="M9 14 Q17 10 23 14 L48 10 Q52 15 52 23 L55 51 L25 55 Q17 49 12 53 Z" fill="{PAPER}" {LINE}/>'
                         '<path d="M25 15 Q22 33 26 52 M31 22 Q38 18 45 21 M30 29 Q37 25 47 28 M30 36 Q37 32 47 35 M32 43 Q39 39 48 43" fill="none" stroke="#82a39b" stroke-width="1.3"/>'
                         '<path d="M35 22 L39 17 L42 22 L39 25 Z M42 37 L46 32 L49 37 L46 40 Z" fill="#869369"/>'),
}

OUT.mkdir(parents=True, exist_ok=True)
for name, body in icons.items():
    (OUT / (name + '.svg')).write_text('<svg xmlns="http://www.w3.org/2000/svg" width="64" height="64" viewBox="0 0 64 64">\n' + back() + body + '\n</svg>\n', encoding='utf-8')
print('STORY_ICONS', len(icons))
