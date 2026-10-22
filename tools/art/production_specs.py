"""Bind production briefs to existing technical specs and unchanged references."""
from __future__ import annotations

from functools import lru_cache
import hashlib
import json
from math import gcd
import re
import xml.etree.ElementTree as ET

from PIL import Image
from handoff_support import PACK, ROOT, actor_sources, project_path

DEFAULT_SOURCE = {
    '02_key_portraits': 'assets/art/portraits/shen_mo.png',
    '04_beast_actions': 'assets/art/battle/yanjia_xi.png',
    '05_locations': 'assets/art/locations/market_fullscreen.png',
    '06_scenes': 'assets/art/scenes/market_street.png',
    '07_battle_backgrounds': 'assets/art/bamboo_arena_v1.png',
    '08_maps': 'assets/art/map/region_tiannan.png',
    '09_events': 'assets/art/events/yunxi_auction.png',
    '10_item_skill_icons': 'assets/art/story/icons/old_city_record.svg',
    '11_ui_rites': 'assets/art/ui/map/market.svg',
    '12_vfx': 'assets/art/vfx/magic_01.png',
}
SOURCE_OVERRIDES = {
    'qingyun_small_sect.png': 'assets/art/locations/sect_fullscreen.png',
    'nanming_city.png': 'assets/art/locations/nanming_fullscreen.png',
    'qingshi_inn_quiet_room.png': 'assets/art/scenes/sect_chamber.png',
    'city_inn_quiet_room.png': 'assets/art/scenes/sect_chamber.png',
    'sect_gate_normal.png': 'assets/art/scenes/sect_gate.png',
    'rogue_rented_abode.png': 'assets/art/scenes/nanming_abode.png',
    'tianhe_ferry_reflection.png': 'assets/art/scenes/ferry_crossing.png',
    'sea_ship_deck.png': 'assets/art/scenes/ferry_crossing.png',
    'scroll_panel_dark.png': 'assets/art/ui/scroll_panel.png',
    'hero_meditate.png': 'assets/art/actors/hero_meditate.png',
    'breakthrough_ritual_vignette.png': 'assets/art/ui/alchemy_vignette.png',
    'retreat_return_summary.svg': 'assets/art/ui/tag.svg',
}
EXTERIORS = {
    'sect_gate_normal.png', 'yunxi_city_gate.png', 'yunxi_assembly_street.png',
    'lu_family_courtyard.png', 'tianhe_ferry_reflection.png', 'qingyun_sword_trial_cliff.png',
    'luoxia_deep_spirit_spring.png', 'duanjian_gorge_outskirts.png', 'chenxia_branching_path.png',
    'sea_ship_deck.png', 'island_landing.png', 'underwater_ruin_gate.png',
    'sealed_old_city_gate.png', 'sealed_old_city_street.png',
}
INITIAL_ASSETS = {'qingshi_inn_quiet_room.png', 'tianhe_ferry_reflection.png'}
IDENTITIES = {
    'lu_chengzhou': 'batches/02_key_portraits/candidates/lu_chengzhou.png',
    'ye_zhiwei': 'batches/02_key_portraits/candidates/ye_zhiwei.png',
    'wenren_zhao': 'batches/02_key_portraits/candidates/wenren_zhao.png',
    'liu_hanzhou': 'batches/02_key_portraits/candidates/liu_hanzhou_healthy.png',
    'wen_zhaoheng': 'batches/02_key_portraits/candidates/auction_elder.png',
    'azhi': 'batches/02_key_portraits/candidates/azhi.png',
}


def full_scope():
    path = PACK / 'production_scope.json'
    return path.is_file() and json.loads(path.read_text(encoding='utf-8')).get('scope') == 'all_existing_and_planned'


@lru_cache(maxsize=None)
def file_reference(relative):
    path = project_path(relative)
    if not path.is_file():
        raise FileNotFoundError(relative)
    return {'path': relative, 'sha256': hashlib.sha256(path.read_bytes()).hexdigest()}


@lru_cache(maxsize=None)
def old_spec(relative):
    path = project_path(relative)
    if path.suffix == '.svg':
        attributes = ET.parse(path).getroot().attrib
        viewbox = [float(x) for x in attributes.get('viewBox', '0 0 96 96').replace(',', ' ').split()]
        width = int(float(re.findall(r'[\d.]+', attributes.get('width', str(viewbox[2])))[0]))
        height = int(float(re.findall(r'[\d.]+', attributes.get('height', str(viewbox[3])))[0]))
        info = {'format': 'SVG', 'dimensions': [width, height], 'view_box': viewbox,
                'background': 'preserve_source_svg', 'native_vector_required': True}
    else:
        with Image.open(path) as image:
            width, height = image.size
            alpha = 'A' in image.getbands() and image.getchannel('A').getextrema()[0] < 255
            info = {'format': 'PNG', 'dimensions': [width, height], 'mode': image.mode,
                    'background': 'transparent_required' if alpha else 'opaque',
                    'native_vector_required': False}
    divisor = gcd(width, height)
    layouts = actor_sources(json.loads((ROOT / 'data/art.json').read_text(encoding='utf-8'))).get(relative, [])
    return {**file_reference(relative), **info, 'aspect_ratio': [width // divisor, height // divisor],
            'actor_layouts': layouts,
            'actor_layout_note': 'For source_role=preferred, apply preferred_layout overrides, including removal of null frame_regions; do not use fallback-sheet cropping.' if layouts else 'No actor atlas definition on this technical source.'}


def decorate_briefs(rows, batch):
    samples = json.loads((PACK / 'approved_samples/index.json').read_text(encoding='utf-8'))
    default_ids = [sample['id'] for sample in json.loads((PACK / 'batches' / batch / 'references.json').read_text(encoding='utf-8'))]
    for row in rows:
        name = row['filename']
        source = SOURCE_OVERRIDES.get(name, DEFAULT_SOURCE[batch])
        if batch == '10_item_skill_icons' and (ROOT / 'assets/art/story/icons' / name).is_file():
            source = 'assets/art/story/icons/' + name
        row['technical_spec'] = old_spec(source)
        row['spec_policy'] = 'inherit_existing_source; retain measured native output separately; never mislabel dimensions'
        row['reference_bindings'] = [{'id': 'technical:' + source, 'role': 'dimensions_alpha_layout_only'}]
        ids = ['04_location'] if batch == '06_scenes' and name in EXTERIORS else default_ids
        for sample_id in ids:
            row['reference_bindings'].append({'id': 'style:' + sample_id, 'role': 'drawing_style_only'})
            row['reference_bindings'].append({'id': 'original:' + sample_id, 'role': 'original_game_style_only_no_copy'})
        row['identity_policy'] = 'If a registered person appears, use their identity_registry image and hash; unseen characters wait for batch02; never substitute style-reference faces.'
        row['generation_gate'] = 'initial_run' if name in INITIAL_ASSETS else ('review_or_wait' if row['priority'] == 'P0' else 'deferred_by_user')
        if full_scope():
            row['generation_gate'] = 'generate_after_dependencies'
            if row['status'] == 'needs_content_confirmation':
                row['generation_gate'] = 'requires_actual_content_not_invented_enemy'
        if name in INITIAL_ASSETS and (PACK / 'batches' / batch / 'output' / name).is_file():
            row['generation_gate'] = 'review_generated_candidate'
        row['dependencies'] = []
        if batch == '06_scenes':
            row['display_crop_aspect'] = [4, 1]
            row['safe_area'] = 'Complete functional subjects in the central 4:1 banner crop; retain full native original.'
        if name == 'tianhe_ferry_reflection.png':
            row['variants'] = ['tianhe_ferry_day.png', 'tianhe_ferry_reflection.png']
            row['dependencies'] = ['output:tianhe_ferry_day.png', 'motif:old_city_seal_candidate']
        if any(word in name for word in ('mirror', 'old_city', 'zhaochuan', 'record', 'testimony', 'legacy')):
            row['dependencies'].append('motif:old_city_seal_candidate')
        if name == 'auction_mirror_anomaly.png':
            row['dependencies'].append('output:tianhe_ferry_reflection.png')
        if any(word in name for word in ('shouchuan', 'yan_wujiu')) and name != 'yan_wujiu.png':
            row['dependencies'].append('planned:02_key_portraits/yan_wujiu.png')
    return rows


def manifest(all_rows):
    samples = json.loads((PACK / 'approved_samples/index.json').read_text(encoding='utf-8'))
    refs = {}
    for sample in samples:
        refs['style:' + sample['id']] = {**file_reference(sample['packaged_new']), 'state': 'existing_confirmed_style'}
        refs['original:' + sample['id']] = {**file_reference(sample['ref']), 'state': 'third_party_reference_only'}
    for rows in all_rows.values():
        for row in rows:
            source = row['technical_spec']['path']
            refs['technical:' + source] = file_reference(source)
    refs['motif:old_city_seal_candidate'] = {
        **file_reference('assets/art/story/icons/old_city_seal.svg'), 'state': 'candidate_motif_not_final_approval',
        'raster_reference': file_reference('art_sources/refresh_20261019/batches/10_item_skill_icons/review/vector_overview.png'),
        'use': 'Only the old_city_seal/mirror motif cells; do not copy labels, frames or unrelated icons.'}
    out = 'art_sources/refresh_20261019/batches/06_scenes/output/'
    for name in ('tianhe_ferry_day.png', 'tianhe_ferry_reflection.png'):
        refs['output:' + name] = ({**file_reference(out + name), 'state': 'generated_candidate'}
                                   if (ROOT / out / name).is_file() else {'path': out + name, 'state': 'pending_must_wait'})
    yan_path = 'art_sources/refresh_20261019/batches/02_key_portraits/output/yan_wujiu.png'
    yan_ref = ({**file_reference(yan_path), 'state': 'generated_identity_candidate'}
               if (ROOT / yan_path).is_file() else {'path': yan_path, 'state': 'pending_must_wait'})
    refs['planned:02_key_portraits/yan_wujiu.png'] = yan_ref
    identities = {name: {**file_reference('art_sources/refresh_20261019/' + path),
                         'state': 'existing_identity_candidate'} for name, path in IDENTITIES.items()}
    identities['hero'] = {**file_reference('art_sources/refresh_20261019/approved_samples/01_hero.png'), 'state': 'existing_confirmed_identity'}
    identities['shen_mo'] = {**file_reference('art_sources/refresh_20261019/approved_samples/02_portrait.png'), 'state': 'existing_confirmed_identity'}
    identities['yan_wujiu'] = yan_ref
    return {'path_base': 'project_root', 'active_priority': 'ALL' if full_scope() else 'P0', 'initial_assets': sorted(INITIAL_ASSETS),
            'deferred_priorities': [] if full_scope() else ['P1', 'P2', 'P3'],
            'reference_resolution': 'Resolve every reference_bindings.id and dependencies entry here. Verify SHA-256 before generation. Pending entries block dependent generation.',
            'generated_image_storage_report': '.tmp/imagegen_storage/redirection.json',
            'reference_registry': refs,
            'identity_registry': identities,
            'identity_exceptions': {'liu_hanzhou_wounded': file_reference('assets/art/portraits/wounded.png'),
                                    'yan_wujiu': {**yan_ref, 'owned_by': '02_key_portraits'}}}
