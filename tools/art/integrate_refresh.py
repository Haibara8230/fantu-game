"""Install the reviewed refresh deliveries into runtime art. Run with -B from the project root.

Existing assets are replaced in place: downscaled (cover, centred) to the technical source's size when
the delivery is larger, otherwise kept at native size, in the source's mode. Planned assets go to the
runtime paths in PLANNED; data/art.json wiring for them is edited by hand. Originals are kept once under
.tmp/art_integration/backup/, so a rerun never overwrites the first backup."""
from __future__ import annotations
import hashlib
import json
import shutil
from PIL import Image
from handoff_support import PACK, ROOT, configure_writes, project_path

QUEUE = PACK / 'ALL_ART_PROGRESS.json'
BACKUP = ROOT / '.tmp/art_integration/backup'
PORTRAIT = (512, 640)
# Planned delivery label -> (runtime paths, size or None for native).
PLANNED = {
	'lu_chengzhou.png': (['assets/art/portraits/lu_chengzhou.png'], PORTRAIT),
	'ye_zhiwei.png': (['assets/art/portraits/ye_zhiwei.png'], PORTRAIT),
	'wenren_zhao.png': (['assets/art/portraits/wenren_zhao.png'], PORTRAIT),
	'auction_elder.png': (['assets/art/portraits/wen_zhaoheng.png'], PORTRAIT),
	'yan_wujiu.png': (['assets/art/portraits/yan_wujiu.png'], PORTRAIT),
	'nanming_city.png': (['assets/art/locations/nanming_fullscreen.png'], None),
	'yunxi_city.png': (['assets/art/locations/market_fullscreen.png'], None),
	'canglan_city.png': (['assets/art/locations/canglan_fullscreen.png'], None),
	'beiyue_city.png': (['assets/art/locations/beiyue_fullscreen.png'], None),
	'wanghai_city.png': (['assets/art/locations/wanghai_fullscreen.png'], None),
	'sect_gate_normal.png': (['assets/art/scenes/sect_gate_normal.png'], None),
	'city_inn_quiet_room.png': (['assets/art/scenes/city_inn_quiet_room.png'], None),
	'rogue_rented_abode.png': (['assets/art/scenes/rogue_rented_abode.png'], None),
	'canglan_medical_hall.png': (['assets/art/scenes/canglan_medical_hall.png'], None),
	'beiyue_old_archive.png': (['assets/art/scenes/beiyue_old_archive.png'], None),
	'qingyun_sword_trial_cliff.png': (['assets/art/scenes/qingyun_sword_trial_cliff.png'], None),
	'rogue_trial_notice_hall.png': (['assets/art/scenes/rogue_trial_notice_hall.png'], None),
	'luoxia_deep_spirit_spring.png': (['assets/art/scenes/luoxia_deep_spirit_spring.png'], None),
	'duanjian_gorge_outskirts.png': (['assets/art/scenes/duanjian_gorge_outskirts.png'], None),
	'wanghai_chart_shop.png': (['assets/art/scenes/wanghai_chart_shop.png'], None),
	'sea_ship_deck.png': (['assets/art/scenes/sea_ship_deck.png'], None),
	'island_landing.png': (['assets/art/scenes/island_landing.png'], None),
	'underwater_ruin_gate.png': (['assets/art/scenes/underwater_ruin_gate.png'], None),
	'sealed_old_city_gate.png': (['assets/art/scenes/sealed_old_city_gate.png'], None),
	'sealed_old_city_street.png': (['assets/art/scenes/sealed_old_city_street.png'], None),
	'old_city_array_core.png': (['assets/art/scenes/old_city_array_core.png'], None),
	'public_tournament_stage.png': (['assets/art/battle/public_tournament_stage.png'], None),
	'tiannan_tournament_arena.png': (['assets/art/battle/tiannan_tournament_arena.png'], None),
	'five_sect_forum_arena.png': (['assets/art/battle/five_sect_forum_arena.png'], None),
	'sea_island_arena.png': (['assets/art/battle/sea_island_arena.png'], None),
	'chenxia_array_arena.png': (['assets/art/battle/chenxia_array_arena.png'], None),
	'yunxi_assembly.png': (['assets/art/events/yunxi_assembly.png'], None),
	'auction_mirror_anomaly.png': (['assets/art/events/auction_mirror_anomaly.png'], None),
	'lu_family_night_banquet.png': (['assets/art/events/lu_family_night_banquet.png'], None),
	'qianlong_arena.png': (['assets/art/events/qianlong_arena.png'], None),
	'tiannan_tournament_reunion.png': (['assets/art/events/tiannan_tournament_reunion.png'], None),
	'five_sect_forum.png': (['assets/art/events/five_sect_forum.png'], None),
	'beiyue_shouchuan_encounter.png': (['assets/art/events/beiyue_shouchuan_encounter.png'], None),
	'beiyue_witness.png': (['assets/art/events/beiyue_witness.png'], None),
	'lu_family_succession.png': (['assets/art/events/lu_family_succession.png'], None),
	'ye_zhiwei_master_crisis.png': (['assets/art/events/ye_zhiwei_master_crisis.png'], None),
	'sea_chart_departure.png': (['assets/art/events/sea_chart_departure.png'], None),
	'wenren_missing_trace.png': (['assets/art/events/wenren_missing_trace.png'], None),
	'wen_zhaoheng_legacy.png': (['assets/art/events/wen_zhaoheng_legacy.png'], None),
	'chenxia_shouchuan_evidence.png': (['assets/art/events/chenxia_shouchuan_evidence.png'], None),
}
# Runtime crops and sizes that differ from the technical source: the scroll frame is a 9-slice
# (scripts/ui/ui_skin.gd) whose edges draw at texture size, so it is cut to the rollers' caps and installed
# at 55%; the cloud band outside the rails would otherwise take room from the text.
RUNTIME_FIT = {'assets/art/ui/scroll_panel.png': ((22, 72, 1648, 848), (894, 427))}
# Local pool copies that must keep yielding to the curated portrait (data/art.json portrait_placeholders).
PLACEHOLDERS = {'xu_qinghe': 'assets/local/portraits/xu_qinghe.png', 'gu_changgeng': 'assets/local/portraits/gu_changgeng.png'}


def sha(path):
	return hashlib.sha256(path.read_bytes()).hexdigest()


def fitted(img, size, alpha):
	img = img.convert('RGBA' if alpha else 'RGB')
	if size is None or tuple(size) == img.size or size[0] > img.width or size[1] > img.height:
		return img
	if abs(size[0] / size[1] - img.width / img.height) < 0.002:
		return img.resize(tuple(size), Image.LANCZOS)
	scale = max(size[0] / img.width, size[1] / img.height)
	scaled = img.resize((max(size[0], round(img.width * scale)), max(size[1], round(img.height * scale))), Image.LANCZOS)
	left, top = (scaled.width - size[0]) // 2, (scaled.height - size[1]) // 2
	return scaled.crop((left, top, left + size[0], top + size[1]))


def install(job, targets, size, alpha, crop=None):
	with Image.open(project_path(job['output'])) as img:
		img.load()
		out = fitted(img.crop(crop) if crop else img, size, alpha)
	records = []
	for target in targets:
		path = project_path(target)
		if path.exists():
			backup = BACKUP / target
			if not backup.exists():
				backup.parent.mkdir(parents=True, exist_ok=True)
				shutil.copy2(path, backup)
		path.parent.mkdir(parents=True, exist_ok=True)
		out.save(path, optimize=True)
		records.append({'path': target, 'dimensions': list(out.size), 'mode': out.mode, 'sha256': sha(path)})
	return records


def main():
	configure_writes()
	queue = json.loads(QUEUE.read_text(encoding='utf-8'))
	installed = {}
	for job in queue['jobs']:
		alpha = job['spec'].get('background') == 'transparent_required'
		if job['kind'] == 'existing' and (job['status'] == 'delivered_generated' or job.get('delivery_kind') == 'reuse_prior_candidate'):
			crop, size = RUNTIME_FIT.get(job['source'], (None, job['spec']['dimensions']))
			installed[job['id']] = install(job, [job['source']], size, alpha, crop)
		elif job['kind'] == 'planned' and job['label'] in PLANNED and job['status'].startswith('delivered_'):
			targets, size = PLANNED[job['label']]
			installed[job['id']] = install(job, targets, size, alpha)
	missing = sorted(set(PLANNED) - {j['label'] for j in queue['jobs'] if j['id'] in installed})
	if missing:
		raise SystemExit('Planned deliveries not found: ' + ', '.join(missing))
	art_path = ROOT / 'data/art.json'
	art = json.loads(art_path.read_text(encoding='utf-8'))
	for person, local in PLACEHOLDERS.items():
		art['portrait_placeholders'][person] = sha(project_path(local))
	text = art_path.read_text(encoding='utf-8')
	for person in PLACEHOLDERS:
		start = text.index('"%s": "' % person, text.index('"portrait_placeholders"'))
		end = text.index('"', start + len(person) + 5)
		text = text[:start] + '"%s": "%s' % (person, art['portrait_placeholders'][person]) + text[end:]
	art_path.write_text(text, encoding='utf-8', newline='\n')
	(PACK / 'INTEGRATION.json').write_text(json.dumps({'scope': 'runtime art installed from reviewed deliveries', 'installed': installed}, ensure_ascii=False, indent=1) + '\n', encoding='utf-8', newline='\n')
	print(json.dumps({'jobs': len(installed), 'files': sum(len(v) for v in installed.values())}))


if __name__ == '__main__':
	main()
