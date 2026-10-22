"""Checkpoint full-art production. Does not call any image API or launch Godot.

The assistant calls the built-in image tool separately for each raster job.
This helper only writes prompts, validates/copies delivered bytes and records
an honest distinction between generated, reused and still-pending work.
"""
from __future__ import annotations

import argparse
import hashlib
import json
from pathlib import Path
import shutil
import sys
import xml.etree.ElementTree as ET
from PIL import Image
from handoff_support import PACK, ROOT, configure_writes, project_path

QUEUE = PACK / 'ALL_ART_PROGRESS.json'
STYLE = {
 '01_human_actions':['01_hero'], '02_key_portraits':['02_portrait'],
 '03_portrait_pool':['02_portrait'], '04_beast_actions':['03_beast'],
 '05_locations':['04_location'], '06_scenes':['07_interior'],
 '07_battle_backgrounds':['06_battle'], '08_maps':['05_map'],
 '09_events':['13_event'], '11_ui_rites':['10_panel'], '12_vfx':['06_battle'],
}
PEOPLE_STYLE = ('Use exactly the established C drawing language: economical clear thin dark outlines, '
 'lean stylized adult anatomy, small simply drawn manga facial features, grouped solid hair masses, '
 'broad flat muted colours, 3-5 structural clothing folds and one restrained shadow tone. '
 'No realistic face modelling, glossy anime rendering, intricate embroidery, fabric grain, '
 'individual hair strands, airbrushed skin or ornate magical effects. Plain muted grey-green backdrop. '
 'Do not copy the style reference person, beard, abacus or costume.')
IDENTITY = {
 'lu_chengzhou':('陆承舟|陆府|陆家|lu_family|lu_chengzhou|banquet|reunion|friends', 'batches/02_key_portraits/candidates/lu_chengzhou.png'),
 'ye_zhiwei':('叶知微|禁方|ye_zhiwei|banquet|reunion|friends', 'batches/02_key_portraits/candidates/ye_zhiwei.png'),
 'wenren_zhao':('闻人照|wenren|sea_chart|reunion|friends', 'batches/02_key_portraits/candidates/wenren_zhao.png'),
 'liu_hanzhou':('柳寒舟|北岳证人|liu_hanzhou|beiyue_witness|reunion|friends', 'batches/02_key_portraits/candidates/liu_hanzhou_healthy.png'),
 'wen_zhaoheng':('温照衡|auction_elder|testimony|legacy', 'batches/02_key_portraits/candidates/auction_elder.png'),
}


def read(path): return json.loads(path.read_text(encoding='utf-8-sig'))
def sha(path): return hashlib.sha256(path.read_bytes()).hexdigest()
def rel(path): return project_path(path).relative_to(ROOT).as_posix()
def write(path, value):
 path=project_path(path);path.parent.mkdir(parents=True,exist_ok=True)
 path.write_text(json.dumps(value,ensure_ascii=False,indent=2)+'\n',encoding='utf-8',newline='\n')


def statistics(queue):
 from collections import Counter
 return dict(Counter(job['status'] for job in queue['jobs']))


def save(queue):
 queue['counts']=statistics(queue);write(QUEUE,queue)


def refs_for(batch,brief,source):
 import re
 refs=[]
 if source: refs.append(source)
 if batch=='02_key_portraits':
  for key,(_,path) in IDENTITY.items():
   if key in brief.get('filename',''):refs=[rel(PACK/path)];break
  if source=='assets/art/portraits/wounded.png':refs.append(rel(PACK/'batches/02_key_portraits/candidates/liu_hanzhou_healthy.png'))
 ids=STYLE.get(batch,[])
 if batch=='06_scenes':
  from production_specs import EXTERIORS
  if brief.get('filename') in EXTERIORS or (source and any(word in Path(source).stem for word in ('gate','wild','ridge','pines','maples','ferry','palisade'))): ids=['04_location']
 if batch=='11_ui_rites':
  name=brief.get('filename','')+' '+(source or '')
  if 'meditat' in name:ids=['01_hero']
  elif any(w in name for w in ('furnace','alchemy','breakthrough_ritual')):ids=['11_furnace']
  elif any(w in name for w in ('garden','spirit_field')):ids=['12_garden']
 samples={x['id']:x for x in read(PACK/'approved_samples/index.json')}
 for sample in ids: refs.append(samples[sample]['packaged_new'])
 if brief and batch not in ('01_human_actions','02_key_portraits','03_portrait_pool','04_beast_actions'):
  # A planned asset's old file is a technical anchor, not a composition target.
  refs=[p for p in refs if p!=source]
 if batch=='09_events':
  text=brief.get('filename','')+' '+brief.get('brief','')
  for key,(pattern,path) in IDENTITY.items():
   if re.search(pattern,text):refs.append(rel(PACK/path))
  yan=PACK/'batches/02_key_portraits/output/yan_wujiu.png'
  if re.search('晏无咎|守川司|shouchuan',text) and yan.exists():refs.append(rel(yan))
  bindings={
   'tiannan_tournament_reunion.png':'tiannan_tournament_venue.png',
   'beiyue_shouchuan_encounter.png':'beiyue_old_archive.png',
   'lu_family_succession.png':'lu_family_courtyard.png',
   'beiyue_witness.png':'beiyue_old_archive.png',
   'yunxi_assembly.png':'yunxi_assembly_street.png',
   'lu_family_night_banquet.png':'lu_family_dining_hall.png',
   'friends_breakthrough_meal.png':'lu_family_dining_hall.png',
   'ye_zhiwei_master_crisis.png':'canglan_medical_hall.png',
   'chenxia_old_city_record.png':'chenxia_record_room.png',
   'chenxia_shouchuan_evidence.png':'chenxia_array_chamber.png',
   'five_sect_forum.png':'five_sect_forum_venue.png',
   'sea_chart_departure.png':'sea_ship_deck.png',
   'wenren_missing_trace.png':'wanghai_chart_shop.png',
  }
  scene=bindings.get(brief.get('filename',''))
  if scene:refs.append(rel(PACK/'batches/06_scenes/output'/scene))
  if any(w in brief.get('filename','') for w in ('old_city','testimony','legacy','mirror','ending')):
   refs.append(rel(PACK/'batches/06_scenes/output/tianhe_ferry_reflection.png'))
 if brief and batch=='07_battle_backgrounds':
  bindings={'tiannan_tournament_arena.png':'tiannan_tournament_venue.png','five_sect_forum_arena.png':'five_sect_forum_venue.png','chenxia_array_arena.png':'chenxia_array_chamber.png','sea_island_arena.png':'island_landing.png','underwater_ruin_arena.png':'underwater_ruin_gate.png'}
  scene=bindings.get(brief.get('filename',''))
  if scene:refs.append(rel(PACK/'batches/06_scenes/output'/scene))
 if brief and batch=='11_ui_rites' and brief.get('filename')=='hero_meditate.png':
  refs=[rel(PACK/'approved_samples/01_hero.png')]
 if brief and batch=='12_vfx':
  refs=[]  # Technical-size VFX glyph must not contaminate the new effect shape.
 if batch=='07_battle_backgrounds' and brief.get('filename')=='public_tournament_stage.png':
  refs.append(rel(PACK/'batches/09_events/candidates/qianlong_arena.png'))
 if brief and batch=='06_scenes':
  name=brief.get('filename','')
  for city in ('yunxi','nanming','beiyue','canglan','wanghai'):
   if city in name or (city=='yunxi' and name.startswith('lu_family')):
    city_path=PACK/'batches/05_locations/output'/(city+'_city.png')
    if not city_path.exists():city_path=PACK/'batches/05_locations/candidates'/(city+'_city.png')
    if city_path.exists():refs.append(rel(city_path))
 refs=list(dict.fromkeys(refs))
 if len(refs)>5:
  # Tool limit: prioritize drawing style plus every named face. Scene continuity
  # remains specified in the composition text; never silently drop an identity.
  refs=[p for p in refs if '/06_scenes/output/' not in p]
 if len(refs)>5:raise RuntimeError('Reference set exceeds tool limit; explicitly resolve '+brief.get('filename',''))
 return refs


def make_prompt(job):
 batch=job['batch'];spec=job.get('spec',{});size=spec.get('dimensions')
 rows=['Use case: style-transfer / identity-preserve / production game art.',
       'Asset: '+job['label'], 'Content request: '+job['brief'],
       'This is one independent production asset for an original Chinese cultivation RPG.']
 for i,path in enumerate(job['tool_refs'],1):
  role=('existing identity/content/layout target; preserve recognizable subject' if path==job.get('source') else 'approved drawing-style reference ONLY; do not copy its subject, architecture, layout or camera')
  if '/02_key_portraits/' in path:role='same named character identity anchor; preserve face, hair, costume cues and props'
  if '/05_locations/' in path:role='city continuity anchor: retain this city palette, roof materials and architectural scale; create the requested new viewpoint and functional space, do not duplicate the overview'
  if '/06_scenes/output/' in path:role='spatial and prop continuity reference; preserve recognizable place or story motif, redraw in this category drawing style and requested camera'
  if path.endswith('/qianlong_arena.png'):role='opening Qianlong tournament venue continuity; use this same stone stage, lake and spectator terrace in an empty side-view battle camera; do not include people or spells'
  rows.append(f'Input image {i}: {path}. Role: {role}.')
 if batch in ('01_human_actions','02_key_portraits','03_portrait_pool'):rows.append(PEOPLE_STYLE)
 else:rows.append('Preserve the existing category-specific approved hand-drawn style: clear outlines, broad grouped colour areas, restrained shadows and low texture density. Do not impose character C anatomy rules on environments, maps, items or UI. No photorealism, cinematic bloom, dense surface scratches or depth-of-field blur.')
 if batch in ('02_key_portraits','03_portrait_pool'):
  rows.append('ONE individual waist-up portrait. Preserve the target sex, apparent age, face shape, skin tone, hairstyle, clothing identity and occupational props. Full head, hair, both hands and important props inside frame. No scene, text, border, label or watermark. Do not make different people share the same face.')
  rows.append('Simplify into the APPROVED C sample line and fill density. Remove paper texture, ink speckling, intricate embroidery and isolated hair strands. Reduce costume ornaments to their identifying big shapes. Do not change a stubbled or old face into a generic handsome youth. Do not add a beard to a clean-shaven target. Preserve the target view, expression and left/right placement of held objects.')
 if batch=='01_human_actions':rows.append('A complete transparent 3-column by 2-row atlas: idle, prepare, attack, cast, hit, guard in that order. Six genuinely different usable action poses of ONE consistent character. Preserve original facing and custom frame registrations. Full head, hair, weapons and boots inside each cell, safe margins, no crossing cells, no contact shadows or background.')
 if batch=='04_beast_actions':rows.append('Retain this beast species and silhouette. Preserve all original pose mappings, frame_regions, facing and true alpha; independent preferred sheets usually have idle/attack/hit/guard. Never copy a one-pose style sample into a multi-pose sheet.')
 if batch in ('05_locations','06_scenes','07_battle_backgrounds'):
  rows.append('Empty environment: no characters, animals, UI, baked text, signs, labels, names or watermark. Preserve clear functional spaces and complete landmarks. Scene banners need a central 4:1 safe crop. Battle fields keep clear left/right standing ground. Qingyun is a small sect; do not copy monumental palace scale from a style sample.')
 if batch=='08_maps':rows.append('Top-down stylized geographic base map only. Preserve layout anchors for existing maps; planned maps are provisional spatial concepts. No baked place names, routes, node symbols, fog, UI or watermark. Grouped small mountains, forest clusters, pale terrain blocks and readable rivers; no cinematic giant peak view.')
 if batch=='09_events':rows.append('Story illustration in the approved graphic event style: symbolic focal point, layered mountain/cloud shapes and broad flat colours. Any depicted named person must match its supplied identity anchor in C style. No lettering, UI, labels, frames or watermark. Do not reveal late truth in early scenes; use only the requested event state. No obligatory victory/death/evil outcome unless requested.')
 if batch=='11_ui_rites':rows.append('Retain the existing UI/rite illustration drawing language and readability. UI text, slots, dates and numerical values are not baked into the image. Any transparent reference must remain genuinely transparent. Do not replace editable SVG assets with this bitmap.')
 if batch=='12_vfx':rows.append('Standalone readable skill VFX on genuinely transparent alpha. Preserve the old source footprint and frame structure where specified. No character, scenery, text, interface or permanent background. No new gameplay mechanics.')
 if size:rows.append(f'Old technical target: {size[0]}x{size[1]} pixels. Request the same proportions and retain usable safe margins; actual native output size will be measured, never mislabelled. Background: {spec.get("background","inherit source")}.')
 if spec.get('actor_layouts'):rows.append('Original actor definitions to preserve: '+json.dumps(spec['actor_layouts'],ensure_ascii=False))
 if job['kind']=='planned' and batch in ('05_locations','06_scenes','07_battle_backgrounds','08_maps','09_events'):
  rows.append('IMPORTANT NEW CONTENT: this is NOT a repaint of the old technical-source scene. Completely replace its subject and composition according to the requested new asset. The old size anchor does not authorize copying its city, terrain, camera or buildings. Retain ONLY the approved drawing language from the style reference.')
 city={
  'nanming_city.png':'NEW ELEVATED THREE-QUARTER CITY OVERVIEW: a broad inhabited inland city across a low volcanic basin, red tiled workshop districts and rectangular streets, two squat foundries with restrained smoke, ore yard, waterwheel and merchants warehouse court, a modest central guild hall. Sparse red maples, dark low rocky hills, one small inland canal. NOT a colossal mountain temple, cliff palace, portal or gold clock tower.',
  'beiyue_city.png':'NEW ELEVATED THREE-QUARTER CITY OVERVIEW: a dry northern foothill town, grey stone wall and modest gate near the lower right, winding ochre streets linking a rectangular old archive courtyard, covered antique stalls and a small array-scholar hall. Low angular slate hills behind, a few dark pines, muted cool roofs and warm stone. No river, waterfall, boat harbour, tall palace or monumental white towers. Strong horizontal city footprint.',
  'canglan_city.png':'NEW ELEVATED THREE-QUARTER CITY OVERVIEW: a low lakeside medical city organized around water gardens, short bridges, a modest pharmacy courtyard, orderly herb drying yards and a small medicinal market, green-grey roofs with ivory walls, rounded wooded hills far behind. Buildings low and human-scale, open areas for each function. Not a mountain sect, not a giant cliff temple; no sheer peaks or numerous waterfalls.',
  'wanghai_city.png':'NEW ELEVATED THREE-QUARTER SEAPORT OVERVIEW: broad blue sea fills the RIGHT half; a curved working harbour with two wooden ocean-going junks, visible shipbuilding slipway and warehouses, low clustered town districts and chart-shop street on the LEFT. A squat stone harbour beacon and modest wall gate, distant small islands and a low green headland. Maritime trade, no inland river canyon, no cliff palace, no waterfalls or giant towers.',
 }
 if job['label'] in city:rows.append(city[job['label']])
 scenes={
  'city_inn_quiet_room.png':'ONE modest private city-inn guest room. Front view across one room: narrow single bed at far LEFT, one wooden chest, one simple desk below a small rear window, one round straw meditation cushion at centre RIGHT and a kettle on a low stand. A closed door at far right. Plaster walls and simple brown beams. One occupant capacity. NO rows of desks, lecture platform, dining hall, staircase, cave, shrine or lavish private estate. New composition, do not copy the sample inn public room.',
  'lu_family_dining_hall.png':'Private Lu merchant-family evening banquet room, viewed diagonally from its corner. ONE long oval banquet table with eight chairs at centre-left, prepared bowls, modest dishes and one wine pot. A plain wooden screen across the back, small sideboard at right, warm hanging lanterns, dark night visible through two narrow windows. Human-scale wealthy household, no restaurant rows, public counter, stairway, palace throne or copied inn layout.',
  'beiyue_old_archive.png':'Dry northern Beiyue old archive interior in cool grey stone and dark brown wood. Deep narrow room viewed along two asymmetrical floor-to-ceiling shelves of tied document bundles. One reading desk with an incomplete open paper folder and a plain closed courier case, no readable writing. Small high window shows only dry slate hillside and grey stone roofs. A locked side cabinet provides investigation interest. No lush rivers, white jade palace, broad inn windows, dining tables or stairway.',
  'qingyun_sword_trial_cliff.png':'Small Qingyun sect sword-testing cliff: modest uneven stone practice ledge with sparse sword cuts in a rock face on left, grouped pines, narrow safe hillside path and open mist valley right. A tiny shelter only; human-scale practice place, no huge palace. Calm daylight.',
  'rogue_trial_notice_hall.png':'Small independent cultivators guild trial-registration room. One plain reception counter on left, empty wooden notice-board panels on back wall, one bench and modest shelving on right, open central walking space. Every notice surface blank for runtime UI text. No temple, lecture hall or palace.',
  'tiannan_tournament_venue.png':'Tiannan tournament venue: single broad low square stone competition platform at centre, restrained tiered spectator benches on far left and right, modest judge canopy behind, clear entry paths at the near corners. No people. Open daylight, local arena rather than imperial palace.',
  'five_sect_forum_venue.png':'Five-sect discussion venue: five equal low wooden seats arranged in an open semicircle around a simple central demonstration mat, side benches for younger disciples, modest bamboo pavilion in rear and courtyard pines. No hierarchy throne or six seats. Blank restrained banners. Empty day scene.',
  'ancient_abode_inner_chamber.png':'Ancient cultivator abode deep chamber: coherent traversable stone room, main entrance behind viewer, broad central walkway, one side passage to left and a low central study dais with closed relic box. Faded geometric stone inlays, grouped rock walls, sparse ivy near light shaft. Not a generic glowing fantasy throne room.',
  'luoxia_deep_spirit_spring.png':'Deep Luoxia Valley spirit spring: one small clear jade spring pooled in rounded rock basin, a subtle unusual double ripple, herb-gathering footpath entering from left, grouped quiet red-gold foliage and low rocks. Investigation place with no explicit final-truth symbol or villain imagery.',
  'duanjian_gorge_outskirts.png':'Outer Broken Sword Gorge: dry rocky ravine, narrow but safe caravan trail in foreground, two wheel ruts and an abandoned plain rope-tied supply crate, broken upright rock formations resembling sword silhouettes far behind. Restricted deeper path curls away right. No corpses or invented enemies.',
  'wanghai_chart_shop.png':'Wanghai seaport chart shop interior: one large angled worktable with blank parchment sea charts weighted by shells, plain brass divider compass, shallow chart drawers and rolled maps on left wall. Small right window sees blue sea and ship masts; salt-worn dark wood and pale walls. No legible map text or symbols revealing final geography.',
  'chenxia_branching_path.png':'Chenxia ancient ruin fork: clear Y-shaped stone path in broad ruined courtyard, one branch through a shallow stone arch left, the other descending behind broken wall right. Low foundations, sparse grass, muted old jade and ochre stone. Distinct traversable branches rather than giant palace.',
  'chenxia_array_chamber.png':'Chenxia array research chamber: low circular stone mechanism floor surrounded by three reachable broken instrument plinths, side alcove with a plain tool bench, safe entry threshold foreground. Restrained faint jade inlays, dry stone and grouped cloudlike wear. Intact enough for careful study or disassembly. No explosive beam or hostile creature.',
  'chenxia_record_room.png':'Chenxia old record room: low ancient archive recess containing two stone shelves, sealed paper bundles and simple geometric carved tablets with NO readable lettering. One horizontal table with an open incomplete folio, clear entry path and cool shaft of daylight. No spectacular palace or magical prophecy.',
  'sea_ship_deck.png':'Deck of a practical Chinese ocean-going wooden junk at sea, wide low viewpoint across deck. Single mast and folded sail enter from upper left, simple railing and tied coils of rope, modest deckhouse right, broad quiet ocean horizon and low distant island. Complete navigable deck, no people, no modern equipment.',
  'island_landing.png':'Remote island landing cove: one sandy-pebble beach with small timber landing step left, broad low jagged rocks and grouped sea pines, a clear footpath leads inland right. Blue sea across left rear and rounded distant islands. No imposing temple or unexplained grand ruins.',
  'underwater_ruin_gate.png':'Underwater ancient ruin entrance: low broad broken stone arch beneath clear blue-green water, short submerged stairway and readable navigable floor, soft sea-grass groups framing edges, faint light shafts and simple rock layers. Maritime chart investigation motif only, no giant monster or final revelation.',
  'sealed_old_city_gate.png':'Sealed ancient-city outer gate: broad weathered grey-green masonry gateway, closed paired stone doors, restrained dormant circular geometric lock in the centre, low eroded walls and dry empty approach street. Provisional neutral city layout with no final secret baked in. Not an imperial celestial palace.',
  'sealed_old_city_street.png':'Lived-in ancient city remains: eye-level old street with modest ruined household courtyards on both sides, one broken well, ordinary pottery and worn thresholds, clear walking lane and faint dormant geometric floor seam. Empty quiet city, not only monumental palaces; no corpses or invented inscriptions.',
  'old_city_array_core.png':'Ancient city array nexus: one dormant low round stone hub in a broad practical chamber, four shallow channels lead to reachable side mechanisms, neutral inactive jade stone, clear entrance and side access. Reusable for restore, dismantle or preserve decisions: no single forced ending, no destructive explosion, no god figure or villain throne.',
 }
 if job['label'] in scenes:rows.append('MANDATORY SCENE COMPOSITION: '+scenes[job['label']])
 if batch=='07_battle_backgrounds':rows.append('Mandatory battle camera: very wide SIDE VIEW with a completely flat open standing strip across the entire lower 40 percent. Two unobstructed standing areas at x=25 and x=75 percent, same ground height. Venue stairs, doors, apparatus, rocks and spectator seats ONLY behind the strip or at far edges. No central obstacle, sloping footpath, characters or spells.')
 if job['label']=='chenxia_array_arena.png':rows.append('MANDATORY: enclosed INDOOR Chenxia ancient array chamber, no outdoor sky, mountains, bamboo or valley. Wide stone room with low wooden rafters and grey masonry, the three damaged brass instrument plinths and dormant jade floor ring from the supplied chamber reference situated behind the clear front combat strip. Preserve the indoor architecture. Battle sample supplies drawing style only.')
 if batch=='11_ui_rites' and job['label']=='hero_meditate.png':rows.append(PEOPLE_STYLE+' ONE full-body seated cross-legged young male protagonist, calm closed eyes, both hands resting naturally on knees, same face, hair, ivory outer robe and muted jade-green trim and belt as the supplied hero. No sect emblem. Complete legs and hands, isolated transparent alpha with no floor, halo or scenic background. Transparent requirement overrides the portrait-backdrop style sentence.')
 if job['label']=='breakthrough_ritual_vignette.png':rows.append('One isolated compact planning vignette: round plain jade meditation mat, three small closed medicine bottles on a modest wooden tray, one rolled paper and a simple incense vessel beside it. Clear graphic outlines and flat muted jade/ochre colours from the approved furnace style, simple broad shading. No actual furnace needed. No slots, characters, text, numerical conditions, success flash or prediction. True transparent alpha.')
 if batch=='12_vfx':
  motifs={'zhaoshui_water_metal_chain.png':'Two simple interwoven water arcs and three short pale-gold blade-like streaks moving left-to-right, one small water seal spark converting into a gold highlight. Readable compact chain-combo expression, no counterattack shield or stored-charge orb.', 'cangxi_concealment.png':'A few pale desaturated jade-grey mist ribbons peeling diagonally backward, suggesting brief retreat and reduced presence, soft but clearly separated flowing shapes. No human silhouette, invisibility bubble, solid shield or permanent magical dome.', 'tingchao_water_qi.png':'Three narrow pale-cyan water-qi streams curling gently into ONE small central resting point; restrained ripple arcs and minimal light flecks. This effect overlays the existing Tingchao sword at runtime, so do not invent or redraw a different sword. No waves engulfing a character, no giant burst.'}
  rows.append('VFX content: '+motifs.get(job['label'],job['brief'])+' Single static expression candidate, not a falsely claimed animation atlas. True empty transparent pixels around effect, no checkerboard artwork or dark square baked into image.')
 if batch=='09_events' and job['kind']=='planned':
  from event_compositions import EVENTS
  if job['label'] in EVENTS:rows.append('MANDATORY EVENT COMPOSITION: '+EVENTS[job['label']])
 corrections={
  'beiyue_shouchuan_encounter.png':'Every open paper surface is completely BLANK pale parchment. Missing-page clue uses only one clean torn-out rectangle and an empty sheet. NO letters, brush strokes, dots in rows, writing-like squiggles, manuscript texture or faux calligraphy anywhere. Retain Yan identity and northern archive.',
  'beiyue_witness.png':'Every paper and book surface is completely BLANK pale parchment. Liu compares blank torn edges and empty sheets. NO letters, handwriting, writing-like lines or faux calligraphy anywhere. Retain his face, sword tassel and implied witness hand.',
  'auction_mirror_anomaly.png':'STRICT FLAT DRAWING: draw the bronze mirror as one solid muted teal oval with one ochre rim and only TWO plain chips, one single dark cel shadow. No patina texture, material grain, realistic reflections, microcracks, speckles, gold scratches or camera blur. The city inside is a tiny simplified THREE-ARCH gate silhouette with two water curves. Plain block-colour auction background. Match approved graphic event drawing density.',
  'auction_elder_old_painting.png':'In the HISTORICAL PAINTING ONLY he is a clean-shaven thirty-year-old man: absolutely NO moustache, goatee, beard, facial wrinkles or pale facial hairs. Same eyebrows, eyes, nose and jaw, dark tied hair. The living elder on the RIGHT retains his white moustache, long white beard and white hair. Clear age difference of the SAME person.',
 }
 if job.get('rejected_attempts') and job['label'] in corrections:rows.append('REQUIRED CORRECTION: '+corrections[job['label']])
 if job.get('rejected_attempts') and batch in ('02_key_portraits','03_portrait_pool'):
  rows.append('REQUIRED REPAIR: '+job['rejected_attempts'][-1]['reason'])
  rows.append('Reframe the portrait farther away: entire topmost hair strand, tied bun, crown, ribbons and held props are safely inside canvas. Leave at least eight percent of canvas height as plain background ABOVE the highest hair/crown point. Do NOT retain clipping present in the old original. Preserve the same face and view, move the composition inward rather than changing identity.')
 return '\n'.join(rows)


def initialize():
 if QUEUE.exists():print(json.dumps({'existing_queue':True,'counts':statistics(read(QUEUE))},ensure_ascii=False));return
 from production_specs import old_spec
 queue={'authorization':'Continue and complete all art, preserving category styles; candidate delivery only',
        'scope':'645 existing resources plus 98 plans, with aliases/reuse explicitly recorded', 'jobs':[]}
 aliases={
  'assets/art/cultivator_atlas_v2.png':'batches/01_human_actions/candidates/hero_atlas_alpha.png',
  'assets/art/portraits/azhi_unique.png':'batches/02_key_portraits/candidates/azhi.png',
  'assets/art/portraits/shen_mo.png':'approved_samples/02_portrait.png',
  'assets/art/locations/sect_fullscreen.png':'batches/05_locations/candidates/sect_small.png',
  'assets/art/ui/scroll_panel.png':'batches/11_ui_rites/candidates/scroll_panel_dark.png',
 }
 for p in sorted((PACK/'batches').glob('*/inputs.json')):
  batch=p.parent.name
  for item in read(p):
   source=item['path'];out=rel(p.parent/'output/existing'/Path(source).relative_to('assets'))
   job={'id':hashlib.sha256(('existing:'+source).encode()).hexdigest()[:16], 'batch':batch,'kind':'existing',
        'label':source,'source':source,'output':out,'brief':'Redraw the existing asset while preserving its actual identity, purpose and technical registration. Inspect the supplied original; filenames are not an excuse to invent its content.',
        'spec':old_spec(source),'status':'pending'}
   if source.endswith('.svg'):job['status']='reuse_vector'
   elif source.startswith('assets/art/vfx/'):job['status']='reuse_licensed_vfx'
   elif source in aliases:job.update(status='reuse_prior_candidate',reuse_source=rel(PACK/aliases[source]))
   job['tool_refs']=refs_for(batch,{},source)
   queue['jobs'].append(job)
 for p in sorted((PACK/'batches').glob('*/new_asset_briefs.json')):
  batch=p.parent.name
  for item in read(p):
   name=item['filename'];out=item['output_path']
   job={'id':hashlib.sha256(('planned:'+batch+'/'+name).encode()).hexdigest()[:16], 'batch':batch,'kind':'planned',
        'label':name,'source':item['technical_spec']['path'],'output':out,'brief':item['brief'],
        'spec':item['technical_spec'],'status':'pending','priority':item['priority'],'dependencies':item.get('dependencies',[])}
   if project_path(out).is_file():job.update(status='reuse_prior_candidate',reuse_source=out)
   elif name.endswith('.svg'):
    exact=ROOT/'assets/art/story/icons'/name
    if exact.exists():job.update(status='reuse_vector',source=rel(exact))
    else:job['status']='vector_pending'
   else:
    alias={'qingyun_small_sect.png':'sect_small.png'}
    candidate=p.parent/'candidates'/alias.get(name,name)
    if candidate.exists():job.update(status='reuse_prior_candidate',reuse_source=rel(candidate))
   if item['status']=='needs_content_confirmation':job.update(status='excluded_unconfirmed_enemy',reason='Optional concept without confirmed gameplay consumer; do not invent a new enemy.')
   job['tool_refs']=refs_for(batch,item,job['source'])
   if name=='yan_wujiu.png':
    job['source']=None;job['tool_refs']=[]
    job['brief']+=' Original identity design: composed mature male array custodian, angular broad jaw, dark hair tied with a plain grey cord, a little grey at temples, muted deep jade outer robe and ivory collar, plain dark belt, closed document case in one hand. No faction emblem, no evil aura, no beard/abacus copied from Shen Mo.'
   queue['jobs'].append(job)
 for job in queue['jobs']:
  job['prompt_path']=rel(PACK/'batches'/job['batch']/'output/prompts'/(job['id']+'.txt'))
  path=project_path(job['prompt_path']);path.parent.mkdir(parents=True,exist_ok=True)
  path.write_text(make_prompt(job)+'\n',encoding='utf-8')
 save(queue);print(json.dumps({'jobs':len(queue['jobs']),'counts':statistics(queue)},ensure_ascii=False))


def audit_reuse():
 queue=read(QUEUE);done=0
 for job in queue['jobs']:
  if job['status'] not in ('reuse_vector','reuse_licensed_vfx','reuse_prior_candidate'):continue
  source=project_path(job.get('reuse_source',job['source']));target=project_path(job['output'])
  target.parent.mkdir(parents=True,exist_ok=True)
  if source.suffix=='.svg':ET.parse(source)
  else:
   with Image.open(source) as image:image.verify()
  if source!=target:
   if target.exists() and sha(target)!=sha(source):raise RuntimeError('Refusing to overwrite '+str(target))
   shutil.copy2(source,target)
  job.update(status='delivered_reuse',delivery_kind=job['status'],sha256=sha(target),newly_generated=False)
  done+=1
 save(queue);print(json.dumps({'reused_deliveries':done,'counts':statistics(queue)},ensure_ascii=False))


def record(job_id,source,reject_reason=None):
 queue=read(QUEUE);job=next(x for x in queue['jobs'] if x['id']==job_id)
 origin=Path(source).resolve();origin.relative_to(project_path('.tmp/imagegen_storage/generated_images'))
 target=project_path(job['output']);target.parent.mkdir(parents=True,exist_ok=True)
 if reject_reason:
  target=project_path(target.parent/'originals'/(target.stem+'_rejected_'+sha(origin)[:8]+'.png'))
  target.parent.mkdir(parents=True,exist_ok=True);shutil.copy2(origin,target)
  prompt_copy=target.with_suffix('.prompt.txt')
  shutil.copy2(project_path(job['prompt_path']),prompt_copy)
  job.setdefault('rejected_attempts',[]).append({'path':rel(target),'sha256':sha(target),'reason':reject_reason,'tool_physical_path':str(origin),'prompt_path':rel(prompt_copy)})
  save(queue);print(json.dumps({'rejected_saved':rel(target),'id':job_id},ensure_ascii=False));return
 if target.exists() and sha(target)!=sha(origin):raise RuntimeError('Refusing to overwrite candidate '+str(target))
 shutil.copy2(origin,target)
 with Image.open(target) as image:
  image.load();native=list(image.size);mode=image.mode
  alpha=list(image.getchannel('A').getextrema()) if 'A' in image.getbands() else None
 job.update(status='generated_pending_review',newly_generated=True,sha256=sha(target),native_dimensions=native,
            native_mode=mode,alpha_extrema=alpha,tool_logical_path=source,tool_physical_path=str(origin),
            input_hashes=[{'path':p,'sha256':sha(ROOT/p)} for p in job['tool_refs']])
 if job['spec'].get('background')=='transparent_required' and (alpha is None or alpha[0]!=0):
  job['status']='needs_alpha_fix'
 save(queue);print(json.dumps({'id':job_id,'output':job['output'],'status':job['status'],'native':native,'counts':statistics(queue)},ensure_ascii=False))


def main():
 configure_writes()
 parser=argparse.ArgumentParser(description=__doc__);parser.add_argument('action',choices=['init','reuse','next','record','record-many','prepare','review','summary'])
 parser.add_argument('--id');parser.add_argument('--source');parser.add_argument('--batch');parser.add_argument('--limit',type=int,default=3);parser.add_argument('--records-file')
 args=parser.parse_args()
 if args.action=='init':initialize()
 elif args.action=='reuse':audit_reuse()
 elif args.action=='record':record(args.id,args.source)
 elif args.action=='record-many':
  for result in read(project_path(args.records_file)):
   record(result['id'],result['source'],result.get('reject_reason'))
   if result.get('reviewed'):
    queue=read(QUEUE);job=next(x for x in queue['jobs'] if x['id']==result['id'])
    if job['status']!='generated_pending_review':raise RuntimeError('Cannot approve '+job['status'])
    job.update(status='delivered_generated',review='Visually checked identity/content, category style and complete composition; integration separate.');save(queue)
 elif args.action=='prepare':
  queue=read(QUEUE)
  for job in queue['jobs']:
   if (args.id and job['id'] in args.id.split(',')) or (not args.id and args.batch==job['batch']):
    brief={'filename':job['label'],'brief':job['brief']} if job['kind']=='planned' else {}
    job['tool_refs']=refs_for(job['batch'],brief,job['source'])
    if job['label']=='yan_wujiu.png' and not job['source']:job['tool_refs']=[]
    project_path(job['prompt_path']).write_text(make_prompt(job)+'\n',encoding='utf-8')
  save(queue);print('PROMPTS_PREPARED')
 elif args.action=='summary':print(json.dumps({'counts':statistics(read(QUEUE))},ensure_ascii=False))
 elif args.action=='review':
  queue=read(QUEUE)
  for job in queue['jobs']:
   if job['id'] in args.id.split(','):
    if job['status']!='generated_pending_review':raise RuntimeError('Cannot approve '+job['status'])
    job['status']='delivered_generated';job['review']='Visually checked against category style, supplied identity/content and safe layout; integration still separate.'
  save(queue);print(json.dumps({'counts':statistics(queue)},ensure_ascii=False))
 else:
  jobs=[x for x in read(QUEUE)['jobs'] if x['status']=='pending' and (not args.batch or x['batch']==args.batch)]
  jobs.sort(key=lambda x:(x['kind']!='planned',x.get('priority','P9'),x['label']!='yan_wujiu.png',x['label']))
  print(json.dumps(jobs[:args.limit],ensure_ascii=False))


if __name__=='__main__':main()
