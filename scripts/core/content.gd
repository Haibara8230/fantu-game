extends RefCounted
## Data definitions are separate from gameplay and presentation.
var locations: Dictionary = {}
var skills: Dictionary = {}
var enemies: Dictionary = {}
var series: Dictionary = {}
var feuds: Dictionary = {}
var rules: Dictionary = {}
var sects: Dictionary = {}
var realms: Array = []
var routes: Array = []
var actions: Dictionary = {}
var world_flags: Array = []
var people: Dictionary = {}
var items: Dictionary = {}
var events: Dictionary = {}
var chronicle: Dictionary = {}
var map: Dictionary = {}
# The regions the map is drawn in (舆图分页); places name theirs, or belong to map.region.
var regions: Dictionary = {}
var technique_data: Dictionary = {}
var equipment_data: Dictionary = {}
var vfx_tiers: Array = []
# Tier layers that start at some tier instead of rising from the first, and each sect's signature layer.
var vfx_unlocks: Array = []
var vfx_legacy: Dictionary = {}
var vfx_styles: Dictionary = {}
var population_data: Dictionary = {}
# Resolves people not in the handwritten table (the generated population), set by the session.
var person_lookup: Callable
var commission_data: Dictionary = {}
# The guided start and the stories of key people (storylines.gd).
var storylines: Dictionary = {}
var talent_data: Dictionary = {}
var sect_data: Dictionary = {}
var bonds_data: Dictionary = {}
# Recipes, furnaces, 丹毒 and the 灵田 (alchemy.gd).
var alchemy_data: Dictionary = {}
# The old cave's rooms (caves.gd).
var cave_data: Dictionary = {}
# Auctions, their lots and how bidders value them (auctions.gd).
var auction_data: Dictionary = {}
# The contests' champions and rewards, 五宗论道 and 天南大比 (summit.gd).
var summit_data: Dictionary = {}
var guest_data: Dictionary = {}
var league_data: Dictionary = {}
var tianji_data: Dictionary = {}
var mijing_data: Dictionary = {}
# 炼器's materials and costs (forge.gd).
var forge_data: Dictionary = {}
# Lore heard in teahouses about the wider world (rumors.gd).
var lore_data: Dictionary = {}
# Born-with talent ids by tier, built on first use (talents.gd).
var talent_pools: Dictionary = {}
var error_message: String = ""
const DANGER_LEVELS := 4
const FAVOR_MAX := 200
const FAVOR_STAGES := [[0, "初识"], [40, "相熟"], [80, "友好"], [140, "信赖"], [200, "亲密"]]
const ATTITUDES := {"friendly": "友善", "neutral": "中立", "hostile": "敌意"}
const BUILT_IN_INTERACTIONS := ["talk", "gift", "help", "consult", "teach", "invite_spar", "invite_help", "companion", "disciple", "instruct", "sworn"]
const PLAIN_ACTIONS := ["cultivate", "rest", "breakthrough", "study", "teach", "sell", "shop", "gather", "inn_rest", "search_ruin", "explore_cave", "forge", "ascend", "inquire", "commissions", "sect", "alchemy", "field", "lease", "hunt", "arena", "series", "join_sect", "guest", "league", "tianji"]
const ITEM_CATEGORIES := {"herb": "灵草", "pill": "丹药", "treasure": "天材地宝", "manual": "玉简", "equipment": "宝物", "material": "材料", "recipe": "丹方", "talisman": "符箓", "tool": "器具", "quest": "信物"}
# Milestones friends send word of, and the deeds the session counts besides victories ("win:<enemy>").
const CONGRATS := ["breakthrough", "core", "nascent", "deity", "serpent", "champion", "summit", "calamity", "promotion"]
const DEEDS := ["retreat_days", "duel", "trade", "gather", "hunt", "commission", "help", "tournament_champion", "summit_champion"]
const STORY_STATES := ["none", "active", "done", "closed"]
const Arsenal = preload("res://scripts/core/arsenal.gd")
const Talents = preload("res://scripts/core/talents.gd")
const Combat = preload("res://scripts/core/combat.gd")

func load_data() -> bool:
	var parsed: Variant = _read_json("res://data/world.json")
	if not parsed is Dictionary:
		error_message = "世界配置格式错误。"
		return false
	for section: String in ["map", "locations", "skills", "enemies", "rules", "sects", "actions"]:
		if not parsed.get(section) is Dictionary or parsed[section].is_empty():
			error_message = "世界配置缺少：" + section
			return false
	for section: String in ["realms", "routes", "world_flags"]:
		if not parsed.get(section) is Array or parsed[section].is_empty():
			error_message = "世界配置缺少：" + section
			return false
	var templates: Variant = _read_json("res://data/chronicle.json")
	if not templates is Dictionary or templates.is_empty():
		error_message = "编年史文本配置错误。"
		return false
	var event_data: Variant = _read_json("res://data/events.json")
	if not event_data is Dictionary:
		error_message = "事件配置格式错误。"
		return false
	events = event_data
	var npc_data: Variant = _read_json("res://data/npcs.json")
	if not npc_data is Dictionary or npc_data.is_empty():
		error_message = "人物配置格式错误。"
		return false
	people = npc_data
	var item_data: Variant = _read_json("res://data/items.json")
	if not item_data is Dictionary or item_data.is_empty():
		error_message = "物品配置格式错误。"
		return false
	items = item_data
	# Each entry knows its own id, as 宝物 and 玉简 do, so presentation can find its picture.
	for item_id: String in items:
		if items[item_id] is Dictionary:
			items[item_id].id = item_id
	for pair: Array in [["techniques", "res://data/techniques.json"], ["equipment", "res://data/equipment.json"], ["vfx_tiers", "res://data/vfx_tiers.json"], ["vfx", "res://data/vfx.json"], ["population", "res://data/population.json"], ["commissions", "res://data/commissions.json"], ["storylines", "res://data/storylines.json"], ["talents", "res://data/talents.json"], ["sect", "res://data/sect.json"], ["bonds", "res://data/bonds.json"], ["alchemy", "res://data/alchemy.json"], ["caves", "res://data/caves.json"], ["auctions", "res://data/auctions.json"], ["summit", "res://data/summit.json"], ["forge", "res://data/forge.json"], ["lore", "res://data/lore.json"], ["guests", "res://data/guests.json"], ["league", "res://data/league.json"], ["tianji", "res://data/tianji.json"], ["mijing", "res://data/mijing.json"]]:
		var loaded: Variant = _read_json(pair[1])
		if not loaded is Dictionary:
			error_message = "配置格式错误：" + pair[1]
			return false
		match pair[0]:
			"techniques":
				technique_data = loaded
			"equipment":
				equipment_data = loaded
			"vfx_tiers":
				vfx_tiers = loaded.get("tiers", [])
				vfx_unlocks = loaded.get("unlocks", [])
				vfx_legacy = loaded.get("legacy", {})
			"vfx":
				vfx_styles = loaded
			"population":
				population_data = loaded
			"commissions":
				commission_data = loaded
			"storylines":
				storylines = loaded
			"talents":
				talent_data = loaded
				talent_pools = {}
			"sect":
				sect_data = loaded
			"bonds":
				bonds_data = loaded
			"alchemy":
				alchemy_data = loaded
			"caves":
				cave_data = loaded
			"auctions":
				auction_data = loaded
			"summit":
				summit_data = loaded
			"forge":
				forge_data = loaded
			"lore":
				lore_data = loaded
			"guests":
				guest_data = loaded
			"league":
				league_data = loaded
			"tianji":
				tianji_data = loaded
			"mijing":
				mijing_data = loaded
	map = parsed.map
	regions = parsed.get("regions", {})
	locations = parsed.locations
	skills = parsed.skills
	enemies = parsed.enemies
	series = parsed.get("series", {})
	feuds = parsed.get("feuds", {})
	rules = parsed.rules
	sects = parsed.sects
	realms = parsed.realms
	routes = parsed.routes
	actions = parsed.actions
	world_flags = parsed.world_flags
	chronicle = templates
	error_message = _validate()
	return error_message.is_empty()

func _read_json(path: String) -> Variant:
	var file := FileAccess.open(path, FileAccess.READ)
	if file == null:
		return null
	return JSON.parse_string(file.get_as_text())

func _validate() -> String:
	# 禁忌秘术 (combat.gd).
	for art_id: String in rules.get("duel", {}).get("secret_arts", {}):
		var art: Variant = rules.duel.secret_arts[art_id]
		if not art_id in ["burn_blood", "shatter", "offer_core"] or not art is Dictionary or not art.get("name") is String or not art.get("text") is String or not _whole(art.get("min_realm")) or (art.has("fervor") and (not art.fervor is Array or art.fervor.size() != 2)) or art.get("items", []).any(func(item_id: Variant) -> bool: return item(str(item_id)).is_empty()):
			return "禁忌秘术配置错误：" + art_id
	# 流派 (schools.gd).
	for school_id: String in technique_data.get("schools", {}):
		var school: Variant = technique_data.schools[school_id]
		if not school is Dictionary or not school.get("name") is String or not school.get("text") is String or not technique_data.archetypes.has(school.get("archetype", "")) or str(technique_data.archetypes[school.archetype].slot) != "method" or not _whole(school.get("min_tier")) or int(school.min_tier) < 1 or int(school.min_tier) > technique_data.tiers.size() or (school.has("element") and not technique_data.elements.has(school.element)):
			return "流派配置错误：" + school_id
	# 恩怨与悬赏 (feuds.gd).
	if not feuds.is_empty():
		if not feuds.get("nicknames") is Array or feuds.nicknames.is_empty() or not feuds.get("avengers") is Array or feuds.avengers.any(func(enemy_id: Variant) -> bool: return not enemies.has(enemy_id)) or not feuds.get("causes") is Dictionary:
			return "恩怨配置错误"
		for key: String in ["ripen_days", "max", "pay", "bounty_wait_days"]:
			if not _whole(feuds.get(key)) or int(feuds[key]) < 1:
				return "恩怨配置错误：" + key
		for key: String in ["grudge_chance", "ambush_chance"]:
			if not (feuds.get(key) is float or feuds.get(key) is int) or float(feuds[key]) < 0.0 or float(feuds[key]) > 1.0:
				return "恩怨配置错误：" + key
		for sworn: Variant in feuds.get("seeded", []):
			if not sworn is Dictionary or not sworn.get("flag") in world_flags or not enemies.has(sworn.get("enemy", "")) or not sworn.get("name") is String or not feuds.causes.has(sworn.get("cause", "")) or not regions.has(sworn.get("region", "")):
				return "恩怨来源配置错误"
		if not _whole(feuds.get("stash_scale")) or not (feuds.get("search_find") is float) or not feuds.get("search_items") is Array or feuds.search_items.any(func(item_id: Variant) -> bool: return item(str(item_id)).is_empty()):
			return "收尾抉择配置错误"
		for event_id: String in ["grudge_ambush", "bounty_found", "bounty_twist", "victory_terms"]:
			if not events.has(event_id):
				return "缺少恩怨事件：" + event_id
	# 成串的战斗 (series.gd): where, how strong, the waves and what they pay.
	for series_id: String in series:
		var entry: Variant = series[series_id]
		if not entry is Dictionary or not entry.get("name") is String or not entry.get("done_text") is String or not locations.has(entry.get("location", "")) or not _whole(entry.get("min_realm", 0)) or not _whole(entry.get("min_stage", 0)) or not entry.get("waves") is Array or entry.waves.is_empty():
			return "连战配置错误：" + series_id
		for wave: Variant in entry.waves:
			if not wave is Dictionary or not wave.get("text") is String or not wave.get("foes") is Array or wave.foes.is_empty() or wave.foes.size() > 4 or wave.foes.any(func(enemy_id: Variant) -> bool: return not enemies.has(enemy_id)):
				return "连战的一波配置错误：" + series_id
		if entry.has("event") and (not events.has(entry.event) or not events[entry.event].has("periodic")):
			return "连战引用的事件须按年开放：" + series_id
		if entry.has("to") and (not locations.has(entry.to) or not _whole(entry.get("days")) or int(entry.days) < 1):
			return "护送的去处或日程错误：" + series_id
		if entry.has("cooldown_days") and (not _whole(entry.cooldown_days) or int(entry.cooldown_days) < 1):
			return "连战冷却错误：" + series_id
		var reward: Variant = entry.get("reward", {})
		if not reward is Dictionary or not _whole(reward.get("stones", 0)) or not _whole(reward.get("contribution", 0)) or not reward.get("items", {}) is Dictionary or reward.get("items", {}).keys().any(func(item_id: Variant) -> bool: return item(str(item_id)).is_empty()):
			return "连战奖励错误：" + series_id
		if reward.has("manual") and (not reward.manual is Dictionary or not _whole(reward.manual.get("tier")) or int(reward.manual.tier) < 1 or int(reward.manual.tier) > technique_data.tiers.size() or not reward.manual.get("slot", "art") in ["art", "method"] or (reward.manual.has("element") and not technique_data.elements.has(reward.manual.element))):
			return "连战奖励的玉简错误：" + series_id
		if not entry.get("per_wave", {}) is Dictionary or not _whole(entry.get("per_wave", {}).get("contribution", 0)) or not entry.get("ranked", false) is bool:
			return "连战逐层奖励错误：" + series_id
		if entry.has("affiliation") and not sects.has(entry.affiliation):
			return "连战限定的宗门未知：" + series_id
		if not entry.location in locations or not locations[entry.location].get("spots", []).any(func(spot: Dictionary) -> bool: return "series" in spot.get("actions", [])):
			return "连战所在地点没有可接下它的去处：" + series_id
	for sect_id: String in sects:
		var definition: Dictionary = sects[sect_id]
		if not definition.get("skills") is Array or definition.skills.size() != 3:
			return "门派神通配置错误：" + sect_id
		for skill_id: Variant in definition.skills:
			if not skill_id is String or not skills.has(skill_id):
				return "门派引用了未知神通：" + sect_id
	for index: int in realms.size():
		var realm: Variant = realms[index]
		if not realm is Dictionary:
			return "境界配置错误：%d" % index
		if not realm.get("name") is String or not _whole(realm.get("lifespan_years")) or int(realm.lifespan_years) < 1:
			return "境界名称或寿元错误：%s" % realm.get("id", index)
		if not realm.get("stages") is Array or realm.stages.is_empty():
			return "境界缺少小阶段：%s" % realm.get("id", index)
		var previous_xp := -1
		for stage: Variant in realm.stages:
			if not stage is Dictionary or not stage.get("name") is String:
				return "小阶段配置错误：%s" % realm.get("id", index)
			for key: String in ["xp", "max_hp", "max_qi", "attack_bonus", "mind", "retreat_days", "sense"]:
				if not _whole(stage.get(key)) or (key in ["max_hp", "max_qi", "retreat_days"] and int(stage[key]) < 1):
					return "小阶段数值错误：%s.%s.%s" % [realm.get("id", index), stage.name, key]
			if int(stage.xp) <= previous_xp:
				return "小阶段修为门槛必须递增：%s" % realm.get("id", index)
			previous_xp = int(stage.xp)
		if int(realm.stages[0].xp) != 0:
			return "第一个小阶段的门槛必须是 0：%s" % realm.get("id", index)
		var breakthrough: Variant = realm.get("breakthrough")
		if breakthrough != null and (not breakthrough is Dictionary or not _whole(breakthrough.get("xp")) or not _whole(breakthrough.get("pills", 0))):
			return "突破条件错误：%s" % realm.get("id", index)
		if breakthrough != null and int(breakthrough.xp) < int(realm.stages.back().xp):
			return "突破所需修为不能低于最后一个小阶段：%s" % realm.get("id", index)
		if realm.has("xp_cap") and (not _whole(realm.xp_cap) or int(realm.xp_cap) <= int(realm.stages.back().xp)):
			return "境界修为上限须高于最后一个小阶段：%s" % realm.get("id", index)
		for key: String in ["retreat_step_days", "fresh_days"]:
			if not _whole(realm.get(key)) or int(realm[key]) < 1:
				return "境界闭关配置错误：%s.%s" % [realm.get("id", index), key]
		var waits: Variant = realm.get("wait_options", [])
		if not waits is Array or waits.any(func(days: Variant) -> bool: return not _whole(days) or int(days) < 1 or int(days) > 3600):
			return "境界停留选项错误：%s" % realm.get("id", index)
	for route: Variant in routes:
		if not route is Dictionary or not route.get("between") is Array or route.between.size() != 2:
			return "路线配置错误。"
		for location_id: Variant in route.between:
			if not locations.has(location_id):
				return "路线引用了未知地点：%s" % location_id
		if route.between[0] == route.between[1]:
			return "路线两端相同：%s" % route.between[0]
		if not _whole(route.get("days")) or int(route.days) < 1:
			return "路线天数错误。"
		if not _whole(route.get("danger")) or int(route.danger) >= DANGER_LEVELS:
			return "路线危险度错误：%s" % "—".join(route.between)
		# A road may be a 传送阵 or the like (`by`), cost stones each way (`fee`) and ask a realm (`realm`).
		if route.has("by") and (not route.by is String or str(route.by).is_empty()):
			return "路线名称无效：%s" % "—".join(route.between)
		if route.has("fee") and (not _whole(route.fee) or int(route.fee) < 1):
			return "路线费用无效：%s" % "—".join(route.between)
		if route.has("realm") and (not _whole(route.realm) or int(route.realm) >= realms.size()):
			return "路线境界要求无效：%s" % "—".join(route.between)
	for action_id: String in actions:
		if not _whole(actions[action_id]):
			return "行为耗时错误：" + action_id
	for enemy_id: String in enemies:
		var enemy: Dictionary = enemies[enemy_id]
		if not _whole(enemy.get("min_realm")) or int(enemy.min_realm) >= realms.size():
			return "敌人境界要求错误：" + enemy_id
		if enemy.has("world_flag") and (not enemy.world_flag in world_flags or not chronicle.has(enemy.get("flag_event", ""))):
			return "敌人引用了未知世界标记：" + enemy_id
		if enemy.has("sect") and not sects.has(enemy.sect):
			return "敌人引用了未知门派：" + enemy_id
		if enemy.has("drops"):
			var drops: Variant = enemy.drops
			if not drops is Dictionary or not (drops.get("chance") is float or drops.get("chance") is int) or not drops.get("tiers") is Array or drops.tiers.size() != 2:
				return "敌人掉落配置错误：" + enemy_id
		if enemy.has("weakened_by"):
			var weakened: Variant = enemy.weakened_by
			if not weakened is Dictionary or not weakened.get("flag") in world_flags or not _whole(weakened.get("hp_percent")) or int(weakened.hp_percent) < 1 or int(weakened.hp_percent) > 100:
				return "敌人的弱点配置错误：" + enemy_id
		if enemy.has("congrats") and not enemy.congrats in CONGRATS:
			return "敌人引用了未知贺信：" + enemy_id
		if enemy.has("contribution") and (not _whole(enemy.contribution) or not enemy.has("world_flag")):
			return "敌人的宗门贡献无效：" + enemy_id
		for part: Variant in enemy.get("parts", []):
			if not part is Dictionary or not items.has(part.get("item", "")) or not (part.get("chance") is float or part.get("chance") is int) or float(part.chance) <= 0.0 or float(part.chance) > 1.0 or not part.get("count") is Array or part.count.size() != 2 or not _whole(part.count[0]) or int(part.count[0]) < 1 or int(part.count[0]) > int(part.count[1]):
				return "敌人掉落的材料配置无效：" + enemy_id
		var moves_problem := _validate_moves(enemy)
		if not moves_problem.is_empty():
			return "敌人招式配置无效：%s（%s）" % [enemy_id, moves_problem]
	var chance: Variant = rules.get("encounter_chance")
	if not chance is Array or chance.size() != DANGER_LEVELS:
		return "遭遇几率需要按危险度给出 %d 档。" % DANGER_LEVELS
	for value: Variant in chance:
		if not (value is int or value is float) or float(value) < 0.0 or float(value) > 1.0:
			return "遭遇几率必须在 0 到 1 之间。"
	var roots: Variant = rules.get("spirit_roots")
	if not roots is Dictionary or not roots.get("elements") is Array or not roots.get("names") is Dictionary or not roots.get("grades") is Array:
		return "灵根配置无效。"
	for element: Variant in roots.elements:
		if not roots.names.has(element):
			return "灵根缺少名称：%s" % element
	for grade: Variant in roots.grades:
		if not grade is Dictionary or not _whole(grade.get("count")) or int(grade.count) < 1 or int(grade.count) > roots.elements.size() or not _whole(grade.get("weight")) or not (grade.get("speed") is float or grade.get("speed") is int) or float(grade.speed) <= 0.0:
			return "灵根等级配置无效。"
	if not _whole(rules.get("rest_full_days")) or int(rules.rest_full_days) < 1:
		return "静养天数无效。"
	var field_rest: Variant = rules.get("field_rest", 0.0)
	if not (field_rest is float or field_rest is int) or float(field_rest) < 0.0 or float(field_rest) > 1.0:
		return "野外调息的恢复比例无效。"
	var retreat: Variant = rules.get("retreat")
	if not retreat is Dictionary or not _whole(retreat.get("fresh_days")) or not _whole(retreat.get("decline_days")) or int(retreat.decline_days) < 1 or not _whole(retreat.get("recovery_per_day")) or int(retreat.recovery_per_day) < 1:
		return "闭关心境配置无效。"
	if not _whole(retreat.get("floor_percent")) or int(retreat.floor_percent) < 1 or int(retreat.floor_percent) > 100:
		return "闭关效率下限必须在 1 到 100 之间。"
	var mind: Variant = rules.get("mind")
	if not mind is Dictionary or not mind.get("gain") is Dictionary:
		return "心境配置无效。"
	for key: String in ["short_percent", "ample_margin", "ample_percent"]:
		if not _whole(mind.get(key)) or (key != "ample_margin" and int(mind[key]) < 1):
			return "心境配置缺少：" + key
	var bottleneck: Variant = rules.get("bottleneck")
	if not bottleneck is Dictionary or not _whole(bottleneck.get("insight_needed")) or int(bottleneck.insight_needed) < 1 or not bottleneck.get("insight") is Dictionary:
		return "瓶颈配置无效。"
	for source: String in ["battle_win", "spar", "commission", "event"]:
		if not _whole(bottleneck.insight.get(source)):
			return "瓶颈历练配置缺少：" + source
	var lineage: Variant = rules.get("lineage")
	if not lineage is Dictionary or not sects.has(lineage.get("home", "")) or not _whole(lineage.get("study_days")):
		return "本门传承配置无效。"
	if not _whole(rules.get("inn_price")):
		return "客栈价格无效。"
	if not rules.get("letters") is Dictionary or not _whole(rules.letters.get("kept")) or int(rules.letters.kept) < 1:
		return "传音配置无效。"
	var requests: Variant = rules.get("requests")
	if not requests is Dictionary or not _whole(requests.get("period_days")) or int(requests.period_days) < 1 or not (requests.get("chance") is float or requests.get("chance") is int) or not requests.get("items") is Array or requests.items.is_empty():
		return "求助配置无效。"
	for item_id: Variant in requests.items:
		if not items.has(item_id):
			return "求助引用了未知物品：%s" % item_id
	if not requests.get("count") is Array or requests.count.size() != 2 or not _whole(requests.count[0]) or int(requests.count[0]) < 1 or int(requests.count[0]) > int(requests.count[1]):
		return "求助数量无效。"
	for key: String in ["favor", "mind"]:
		if not _whole(requests.get(key)):
			return "求助配置缺少：" + key
	if not (requests.get("reward_scale") is float or requests.get("reward_scale") is int):
		return "求助报酬无效。"
	var broken := _validate_breakthrough()
	if broken.is_empty():
		broken = _validate_fortune()
	if not broken.is_empty():
		return broken
	var search: Variant = rules.get("ruin_search")
	if not search is Dictionary or not search.get("stones") is Array or not search.get("herbs") is Array or not (search.get("pill_chance") is float or search.get("pill_chance") is int):
		return "洞府搜寻配置无效。"
	if not rules.get("action_cooldowns") is Dictionary:
		return "行为冷却配置无效。"
	for action_id: String in rules.action_cooldowns:
		if not action_id in PLAIN_ACTIONS or not _whole(rules.action_cooldowns[action_id]):
			return "行为冷却配置无效：" + action_id
	var problem := _validate_map()
	if not problem.is_empty():
		return problem
	for rule: String in ["cultivate_options", "wait_options"]:
		if not rules.get(rule) is Array or rules[rule].is_empty():
			return "规则缺少：" + rule
		for days: Variant in rules[rule]:
			if not _whole(days) or int(days) < 1 or int(days) > 3600:
				return "规则天数错误：" + rule
	for event_id: String in events:
		problem = _validate_event(event_id, events[event_id])
		if not problem.is_empty():
			return "事件 %s：%s" % [event_id, problem]
	problem = _validate_arsenal()
	if not problem.is_empty():
		return problem
	for item_id: String in items:
		problem = _validate_item(items[item_id])
		if not problem.is_empty():
			return "物品 %s：%s" % [item_id, problem]
	for person_id: String in people:
		problem = _validate_person(people[person_id])
		if not problem.is_empty():
			return "人物 %s：%s" % [person_id, problem]
	problem = _validate_talents()
	if problem.is_empty():
		problem = _validate_alchemy()
	if problem.is_empty():
		problem = _validate_sect()
	if problem.is_empty():
		problem = _validate_bonds()
	if problem.is_empty():
		problem = _valid_detours()
	if problem.is_empty():
		problem = _validate_caves()
	if problem.is_empty():
		problem = _validate_auctions()
	if problem.is_empty():
		problem = _validate_summit()
	if problem.is_empty():
		problem = _validate_guests()
	if problem.is_empty():
		problem = _validate_league()
	if problem.is_empty():
		problem = _validate_tianji()
	if problem.is_empty():
		problem = _validate_mijing()
	if problem.is_empty():
		problem = _validate_ascension()
	if problem.is_empty():
		problem = _validate_forge()
	if problem.is_empty():
		problem = _validate_lore()
	if problem.is_empty():
		problem = _validate_mastery()
	if problem.is_empty():
		problem = _validate_layers()
	if problem.is_empty():
		problem = _validate_population()
	if not problem.is_empty():
		return problem
	problem = _validate_storylines()
	if not problem.is_empty():
		return problem
	return _validate_reveals()

# --- Breakthrough static checks -------------------------------------------------------------------

func _validate_breakthrough() -> String:
	var rules_of: Variant = rules.get("breakthrough")
	if not rules_of is Dictionary:
		return "突破配置无效。"
	var r: Dictionary = rules_of
	if not r.get("base") is Array or r.base.size() != talent_data.get("aptitude", []).size() or r.base.any(func(value: Variant) -> bool: return not _whole(value)):
		return "突破底数须按资质等级给出。"
	if not r.get("pill_bonus") is Array or r.pill_bonus.is_empty() or r.pill_bonus.any(func(value: Variant) -> bool: return not _whole(value)):
		return "筑基丹加成无效。"
	for key: String in ["mind_step", "mind_most", "method_root", "least", "most"]:
		if not _whole(r.get(key)) or (key == "mind_step" and int(r[key]) < 1):
			return "突破配置缺少：" + key
	if int(r.least) > int(r.most) or int(r.most) > 100:
		return "突破成功率上下限无效。"
	if not r.get("method_tier") is Dictionary:
		return "心法品阶加成无效。"
	var core: Variant = r.get("core")
	if not core is Dictionary or not _whole(core.get("foundation")) or not core.get("margins") is Array or core.margins.is_empty() or core.margins.any(func(value: Variant) -> bool: return not _whole(value)) or not core.get("grades") is Array or core.grades.size() < 2 or core.grades.any(func(grade: Variant) -> bool: return not grade is Dictionary or not grade.get("name") is String or not _signed(grade.get("stats")) or not _signed(grade.get("speed"))):
		return "金丹品级配置无效。"
	for realm: Dictionary in realms:
		var step: Variant = realm.get("breakthrough")
		# Only 筑基 asks a pill; later realms rest on the cultivator, a 天材地宝 or fortune adding to it.
		if step is Dictionary and ((int(step.get("pills", 0)) > 0 and not items.has(step.get("pill", ""))) or (step.has("pill") and int(step.get("pills", 0)) < 1) or (step.has("odds") and not _signed(step.odds))):
			return "突破所需丹药或难度无效：%s" % realm.get("id", "")
	for item_id: String in items:
		var used: Variant = items[item_id].get("breakthrough")
		if used is Dictionary and used.has("realm") and (not _whole(used.realm) or int(used.realm) < 1 or int(used.realm) >= realms.size()):
			return "天材地宝适用的境界无效：" + item_id
	var guard: Variant = r.get("guard")
	if not guard is Dictionary or not people.has(guard.get("mentor", "")) or not storylines.has(guard.get("mentor_story", "")) or not storylines[guard.mentor_story].steps.any(func(step: Dictionary) -> bool: return step.id == guard.get("mentor_step", "")) or not _whole(guard.get("favor")) or not _whole(guard.get("bonus")) or not _whole(guard.get("mentor_bonus")):
		return "护法配置无效。"
	var eye: Variant = r.get("eye")
	if not eye is Dictionary or not locations.has(eye.get("location", "")) or not eye.get("flag") in world_flags or not _whole(eye.get("bonus")) or (eye.has("dimmed_by") and (not eye.dimmed_by in world_flags or not _whole(eye.get("dimmed_bonus")))):
		return "灵眼配置无效。"
	for lore: Variant in r.get("lore", []):
		if not lore is Dictionary or not lore.get("flag") in world_flags or not lore.get("name") is String or not _whole(lore.get("realm")) or int(lore.realm) < 1 or int(lore.realm) >= realms.size() or not _whole(lore.get("bonus")) or not _whole(lore.get("grade", 0)):
			return "突破所需见识配置无效。"
	if not r.get("boons") is Array:
		return "突破机缘配置无效。"
	for boon: Variant in r.boons:
		if not boon is Dictionary or not boon.get("id") is String or not boon.get("name") is String or not _whole(boon.get("bonus")) or not _whole(boon.get("grade", 0)):
			return "突破机缘配置无效。"
	if not r.get("lesson") is Dictionary or not _whole(r.lesson.get("bonus")) or not _whole(r.lesson.get("most")):
		return "前车之鉴配置无效。"
	var failure: Variant = r.get("failure")
	if not failure is Dictionary:
		return "突破失败配置无效。"
	for key: String in ["xp_percent", "injury_days", "injury_percent", "mind"]:
		if not _whole(failure.get(key)) or (key.ends_with("percent") and int(failure[key]) > 100):
			return "突破失败配置缺少：" + key
	var demon: Variant = r.get("demon")
	if not demon is Dictionary or not (demon.get("chance") is float or demon.get("chance") is int) or not _whole(demon.get("slay_mind")) or not _whole(demon.get("slay_penalty")) or not _whole(demon.get("evade_penalty")):
		return "心魔配置无效。"
	if not events.has("heart_demon") or events.heart_demon.get("trigger") != "manual":
		return "缺少心魔事件。"
	if not r.get("grades") is Array or r.grades.size() < 2:
		return "筑基品质配置无效。"
	for grade: Variant in r.grades:
		if not grade is Dictionary or not grade.get("name") is String or not _signed(grade.get("stats")) or not _signed(grade.get("speed")) or (grade.has("margin") and not _whole(grade.margin)):
			return "筑基品质配置无效。"
	return ""

func _validate_fortune() -> String:
	var fortune: Variant = rules.get("fortune")
	if not fortune is Dictionary:
		return "机缘配置无效。"
	for id: String in ["epiphany", "brink", "shiru", "lingshen", "spirit_eye", "remnant", "humble_spring", "humble_echo", "humble_temper"]:
		var rule: Variant = fortune.get(id)
		if not rule is Dictionary or not (rule.get("chance") is float or rule.get("chance") is int) or float(rule.chance) < 0.0 or float(rule.chance) > 1.0:
			return "机缘配置无效：" + id
		if rule.has("event") and (not events.has(rule.event) or events[rule.event].get("trigger") != "manual"):
			return "机缘引用了未知事件：" + id
		if rule.has("item") and not items.get(rule.item, {}).has("breakthrough"):
			return "机缘的天材地宝无效：" + id
		if rule.has("location") and not locations.has(rule.location):
			return "机缘引用了未知地点：" + id
		for key: String in ["talent", "flaw"]:
			if rule.has(key) and not is_talent(rule[key]):
				return "机缘引用了未知天赋：" + id
	for id: String in ["humble_spring", "humble_echo", "humble_temper"]:
		var rule: Dictionary = fortune[id]
		if not _whole(rule.get("follow_days")) or int(rule.follow_days) < 1:
			return "后天机缘追寻时日无效：" + id
		if not _whole(rule.get("mind")) or not _whole(rule.get("before_realm")) or int(rule.before_realm) < 1 or int(rule.before_realm) >= realms.size() or not _whole(rule.get("max_aptitude")) or int(rule.max_aptitude) >= talent_data.aptitude.size():
			return "后天机缘门槛无效：" + id
		if not (rule.get("chance_cap") is float or rule.get("chance_cap") is int) or float(rule.chance_cap) < float(rule.chance) or float(rule.chance_cap) > 1.0:
			return "后天机缘概率上限无效：" + id
		if rule.has("places") and (not rule.places is Array or rule.places.is_empty() or rule.places.any(func(place: Variant) -> bool: return not locations.has(place))):
			return "后天机缘地点无效：" + id
	var epiphany: Dictionary = fortune.epiphany
	if not epiphany.get("places") is Array or epiphany.places.any(func(place: Variant) -> bool: return not locations.has(place)) or not _whole(epiphany.get("per_days")) or int(epiphany.per_days) < 1 or not _whole(epiphany.get("days")):
		return "顿悟配置无效。"
	if not _whole(rules.get("root_study")) or int(rules.root_study) >= 100:
		return "灵根参悟加成配置无效。"
	var market: Variant = rules.get("market")
	if not market is Dictionary or not market.get("categories") is Array or market.categories.any(func(category: Variant) -> bool: return not ITEM_CATEGORIES.has(category)) or ["spread", "drop", "floor", "recover_per_day"].any(func(key: String) -> bool: return not (market.get(key) is float or market.get(key) is int) or float(market[key]) < 0.0):
		return "坊市行情配置无效。"
	var flight: Variant = rules.get("flight")
	if not flight is Dictionary or not _whole(flight.get("realm")) or int(flight.realm) >= realms.size() or not _whole(flight.get("days_percent")) or int(flight.days_percent) >= 100:
		return "御剑飞行配置无效。"
	if not _whole(fortune.brink.get("hp_percent")) or not fortune.spirit_eye.get("flag") in world_flags or not _whole(fortune.spirit_eye.get("sense_reference")) or int(fortune.spirit_eye.sense_reference) < 1:
		return "生死之间或灵眼配置无效。"
	for key: String in ["before_realm", "mind", "injury_days"]:
		if not _whole(fortune.remnant.get(key)):
			return "残魂配置缺少：" + key
	return ""

# --- Sect static checks ---------------------------------------------------------------------------

func _validate_sect() -> String:
	var data := sect_data
	var rank_ids: Variant = data.get("rank_ids")
	if not rank_ids is Array or rank_ids.is_empty() or rank_ids.any(func(id: Variant) -> bool: return not id is String):
		return "宗门身份编号配置无效。"
	var tiers: Variant = data.get("tiers")
	if not tiers is Dictionary or tiers.is_empty() or tiers.values().any(func(tier: Variant) -> bool: return not tier is Dictionary or not tier.get("name") is String or not _whole(tier.get("order"))):
		return "宗门档次配置无效。"
	if not data.get("sides") is Dictionary or not data.sides.has("righteous") or not data.sides.has("demonic") or not _signed(data.get("betray_favor")):
		return "宗门正魔或叛出配置无效。"
	var stipend: Variant = data.get("stipend")
	if not stipend is Dictionary or not _whole(stipend.get("period_days")) or int(stipend.period_days) < 1 or not _whole(stipend.get("most_periods")):
		return "月俸配置无效。"
	var donation: Variant = data.get("donation")
	if not donation is Dictionary or not (donation.get("rate") is float or donation.get("rate") is int) or not _whole(donation.get("most")) or not _whole(donation.get("period_days")) or int(donation.period_days) < 1 or not donation.get("categories") is Array:
		return "捐献配置无效。"
	for category: Variant in donation.categories:
		if not ITEM_CATEGORIES.has(category):
			return "捐献品类未知：%s" % category
	if not data.get("awards") is Dictionary:
		return "宗门奖赏配置无效。"
	if not data.get("sects") is Dictionary or not data.sects.has(str(rules.lineage.home)):
		return "宗门配置缺少本门。"
	for sect_id: String in data.sects:
		var problem := _validate_one_sect(sect_id, data.sects[sect_id])
		if not problem.is_empty():
			return "宗门 %s：%s" % [sect_id, problem]
	return ""

## One sect's table: its tier, side, place and office, board, way of taking disciples, ranks, duties and
## exchange.
func _validate_one_sect(sect_id: String, table: Variant) -> String:
	var data := sect_data
	if not table is Dictionary or not table.get("name") is String or not data.tiers.has(table.get("tier", "")) or not data.sides.has(table.get("side", "")):
		return "名称、档次或正魔无效"
	if not table.get("element") in technique_data.elements or not locations.has(table.get("place", "")) or not table.get("office") is String or not table.get("joined") is String:
		return "传承、山门或执事处无效"
	var board: Dictionary = commission_data.get("boards", {}).get(table.get("board", ""), {})
	if board.is_empty() or str(board.get("affiliation", "")) != sect_id or str(board.location) != str(table.place):
		return "告示须在山门，且归本宗"
	if not locations[table.place].spots.any(func(spot: Dictionary) -> bool: return "join_sect" in spot.actions and str(spot.get("not_affiliation", "")) == sect_id):
		return "山门缺少收徒之处"
	if not locations[table.place].spots.any(func(spot: Dictionary) -> bool: return "sect" in spot.actions and str(spot.get("requires_affiliation", "")) == sect_id):
		return "山门缺少办事之处"
	var join: Variant = table.get("join")
	if not join is Dictionary or not _whole(join.get("realm_most")) or int(join.realm_most) >= realms.size():
		return "收徒条件无效"
	for key: String in join:
		if not key in ["realm_most", "root", "every_years", "sense", "hp"]:
			return "收徒条件未知：" + key
	if join.has("root") and not join.root in technique_data.elements:
		return "收徒的灵根无效"
	for key: String in ["every_years", "sense", "hp"]:
		if join.has(key) and (not _whole(join[key]) or int(join[key]) < 1):
			return "收徒条件无效：" + key
	if not table.get("people", []) is Array or table.get("people", []).any(func(person: Variant) -> bool: return not people.has(person)):
		return "宗门人物无效"
	if not table.get("ranks") is Array or table.ranks.is_empty() or table.ranks.size() > data.rank_ids.size():
		return "宗门身份配置无效"
	var previous := -1
	for index: int in table.ranks.size():
		var rank: Variant = table.ranks[index]
		if not rank is Dictionary or rank.get("id") != data.rank_ids[index] or not rank.get("name") is String or not _whole(rank.get("merit")) or int(rank.merit) < previous:
			return "宗门身份须按编号次序，贡献递增"
		previous = int(rank.merit)
		if not rank.get("stage") is Array or rank.stage.size() != 2 or not _whole(rank.stage[0]) or int(rank.stage[0]) >= realms.size() or not _whole(rank.stage[1]):
			return "宗门身份的修为要求无效：%s" % rank.id
		for key: String in ["stipend", "retreat"]:
			if not _whole(rank.get(key)):
				return "宗门身份缺少：%s.%s" % [rank.id, key]
		if rank.has("host") and (not people.has(rank.host) or not rank.get("words") is String):
			return "宗门身份的主持人无效：%s" % rank.id
		if rank.has("words") and not rank.words is String or rank.has("days") and not _whole(rank.days) or rank.has("story") and not rank.story is bool:
			return "宗门身份配置无效：%s" % rank.id
	var problem := _validate_duties(table.get("duties"), table.ranks)
	if not problem.is_empty():
		return problem
	var ids := {}
	for good: Variant in table.get("exchange", []):
		if not good is Dictionary or not good.get("id") is String or ids.has(good.id) or str(good.id).contains(":"):
			return "宗门兑换缺少唯一 ID。"
		ids[good.id] = true
		if good.has("item") == good.has("manual"):
			return "宗门兑换须是物品或玉简之一：%s" % good.id
		if good.has("item") and not items.has(good.item):
			return "宗门兑换引用了未知物品：%s" % good.id
		if good.has("manual") and (not _whole(good.manual) or int(good.manual) < 1 or int(good.manual) > technique_data.tiers.size()):
			return "宗门兑换的玉简品阶无效：%s" % good.id
		for key: String in ["price", "limit", "per_days"]:
			if not _whole(good.get(key)) or int(good[key]) < 1:
				return "宗门兑换缺少：%s.%s" % [good.id, key]
		if good.has("rank") and not table.ranks.any(func(rank: Dictionary) -> bool: return rank.id == good.rank):
			return "宗门兑换引用了未知身份：%s" % good.id
	return ""

## A qi-orb cost: {key: count} with known keys and whole counts, at least one orb.
## A handwritten opponent's move table and phases (combat.gd _plan_move): optional; when present each
## move has a unique id, a name, a known kind and the numbers its kind needs; phases fall in order.
func _validate_moves(enemy: Dictionary) -> String:
	if not enemy.has("moves"):
		return "有阶段须先有招式表" if enemy.has("phases") else ""
	var ids := {}
	var groups: Array = [enemy.moves]
	var last := 1.0
	for phase: Variant in enemy.get("phases", []):
		if not phase is Dictionary or not (phase.get("below") is float or phase.get("below") is int) or float(phase.below) <= 0.0 or float(phase.below) >= last or not phase.get("text") is String or not (phase.get("power", 1.0) is float or phase.get("power", 1.0) is int):
			return "阶段须按血量从高到低，并写明说明"
		last = float(phase.below)
		groups.append(phase.get("moves", []))
	if not enemy.moves is Array or enemy.moves.is_empty():
		return "招式表为空"
	for group: Variant in groups:
		if not group is Array:
			return "招式须是列表"
		for move: Variant in group:
			if not move is Dictionary or not move.get("id") is String or ids.has(move.id) or not move.get("name") is String or not move.get("kind", "attack") in Combat.MOVE_KINDS:
				return "招式缺少唯一编号、名称或类别"
			ids[move.id] = true
			for key: String in ["weight", "hits", "every"]:
				if move.has(key) and (not _whole(move[key]) or int(move[key]) < 1):
					return "%s.%s 无效" % [move.id, key]
			for key: String in ["power", "below", "heal", "shield", "drain"]:
				if move.has(key) and (not (move[key] is float or move[key] is int) or float(move[key]) <= 0.0):
					return "%s.%s 无效" % [move.id, key]
			var kind := str(move.get("kind", "attack"))
			for needed: Array in [["heal", "heal"], ["guard", "shield"], ["focus", "focus"], ["summon", "summon"]]:
				if kind == needed[0] and not move.has(needed[1]):
					return "%s 缺少 %s" % [move.id, needed[1]]
			var lingering: Array = []
			for key: String in ["focus", "summon"]:
				if move.has(key):
					lingering.append(move[key])
			for key: Variant in move.get("inflict", {}):
				if not key in Combat.LINGERING:
					return "%s 施加了未知状态 %s" % [move.id, key]
				lingering.append(move.inflict[key])
			for value: Variant in lingering:
				if not value is Array or value.size() != 2 or not (value[0] is float or value[0] is int) or float(value[0]) <= 0.0 or not _whole(value[1]) or int(value[1]) < 1:
					return "%s 的状态须是 [数值, 回合]" % move.id
	return ""

## 连击: {"after": an element (or, for archetypes, "source" — the one that gives rise to theirs — or
## "same"), and "bonus" (a share more of the effect) and/or "absorb" (more orbs drawn in)}.
func _valid_combo(combo: Variant, afters: Array) -> bool:
	if not combo is Dictionary or not combo.get("after") in afters or not (combo.has("bonus") or combo.has("absorb")):
		return false
	return (not combo.has("bonus") or float(combo.bonus) > 0.0) and (not combo.has("absorb") or (_whole(combo.absorb) and int(combo.absorb) >= 1))

## An element's entry ({"name", "color", ...}) among the five, or the neutral 气 of arts that take any
## element's qi; {} when unknown.
func element_info(element: String) -> Dictionary:
	if technique_data.elements.has(element):
		return technique_data.elements[element]
	return technique_data.get("neutral", {}).get(element, {})

func _valid_cost(cost: Variant, keys: Array) -> bool:
	if not cost is Dictionary or cost.is_empty():
		return false
	var total := 0
	for key: Variant in cost:
		if not key in keys or not _whole(cost[key]) or int(cost[key]) < 1:
			return false
		total += int(cost[key])
	return total >= 1

## A sect's duties of the inner court (sect.gd): the rank that may hold one, the days between changes and
## each duty's name, text and known bonuses.
func _validate_duties(duties: Variant, ranks: Array) -> String:
	if not duties is Dictionary or not ranks.any(func(rank: Dictionary) -> bool: return rank.id == duties.get("rank", "")) or not _whole(duties.get("change_days")) or not duties.get("list") is Dictionary or duties.list.is_empty():
		return "宗门职司配置无效。"
	for duty_id: String in duties.list:
		var duty: Variant = duties.list[duty_id]
		if not duty is Dictionary or not duty.get("name") is String or not duty.get("text") is String:
			return "宗门职司配置无效：" + duty_id
		for key: String in duty:
			if not key in ["name", "text", "alchemy", "contribution_percent", "study"] or (not key in ["name", "text"] and not _signed(duty[key])):
				return "宗门职司的加成未知：%s.%s" % [duty_id, key]
	return ""

# --- 炼器 ----------------------------------------------------------------------------------------

## 宝物's tiers name the realm that wields them fully; `mastery` the share and affixes for each realm short.
func _validate_mastery() -> String:
	for tier: Dictionary in equipment_data.tiers:
		if not _whole(tier.get("realm", 0)) or int(tier.get("realm", 0)) >= realms.size():
			return "宝物品阶的驾驭境界无效：" + str(tier.name)
	var table: Variant = equipment_data.get("mastery", [{"share": 1.0, "affixes": 99}])
	if not table is Array or table.is_empty() or float(table[0].get("share", 0.0)) != 1.0:
		return "驾驭度表须从全力驾驭起。"
	for step: Variant in table:
		if not step is Dictionary or not (step.get("share") is float or step.get("share") is int) or float(step.share) <= 0.0 or float(step.share) > 1.0 or not _whole(step.get("affixes")):
			return "驾驭度表无效。"
		# 祭炼 (gear.gd) raises the share up to `refined`, never below the share or above full.
		if step.has("refined") and (not (step.refined is float or step.refined is int) or float(step.refined) < float(step.share) or float(step.refined) > 1.0):
			return "驾驭度表的祭炼上限无效。"
	var refine: Variant = equipment_data.get("refine")
	if not refine is Dictionary or not (refine.get("step") is float or refine.get("step") is int) or float(refine.step) <= 0.0 or not (refine.get("growth") is float or refine.get("growth") is int) or float(refine.growth) < 0.0:
		return "祭炼配置无效。"
	for key: String in ["days", "stones"]:
		if not refine.get(key) is Array or refine[key].size() != equipment_data.tiers.size() or refine[key].any(func(value: Variant) -> bool: return not _whole(value) or int(value) < 1):
			return "祭炼须按品阶给出：" + key
	return ""

## 功法层数 (layers.gd): each tier's layers, the layers that unlock its affixes in order, and the days and
## stones a layer asks; the rule's first-layer share and practice.
func _validate_layers() -> String:
	for tier: Dictionary in technique_data.tiers:
		if not _whole(tier.get("layers")) or int(tier.layers) < 1 or not tier.get("affix_layers") is Array or not _whole(tier.get("layer_days")) or int(tier.layer_days) < 1 or not _whole(tier.get("layer_stones")):
			return "功法层数配置错误：" + str(tier.name)
		var last := 0
		for layer: Variant in tier.affix_layers:
			if not _whole(layer) or int(layer) <= last or int(layer) > int(tier.layers):
				return "功法词条的解封层数无效：" + str(tier.name)
			last = int(layer)
		if tier.affix_layers.size() < int(tier.affixes):
			return "功法词条缺解封层数：" + str(tier.name)
	var rule: Variant = technique_data.get("layer_rule")
	if not rule is Dictionary or not (rule.get("first_share") is float or rule.get("first_share") is int) or float(rule.first_share) <= 0.0 or float(rule.first_share) > 1.0:
		return "功法层数规则无效。"
	for key: String in ["blocked_gap", "cast_practice", "retreat_method", "retreat_art"]:
		if not _whole(rule.get(key)) or int(rule[key]) < 0:
			return "功法层数规则无效：" + key
	return ""

func _validate_forge() -> String:
	var data := forge_data
	var tiers: int = equipment_data.tiers.size()
	if not _whole(data.get("count")) or int(data.count) < 1:
		return "炼器的材料份数无效。"
	for key: String in ["fee", "days"]:
		if not data.get(key) is Array or data[key].size() != tiers or data[key].any(func(value: Variant) -> bool: return not _whole(value)):
			return "炼器须按品阶给出：" + key
	if not data.get("materials") is Dictionary or data.materials.is_empty():
		return "没有炼器材料。"
	if data.has("flux") and (not data.flux is Dictionary or not items.has(data.flux.get("item", "")) or not _whole(data.flux.get("affixes")) or int(data.flux.affixes) < 1):
		return "炼器的助熔之物无效。"
	for material_id: String in data.materials:
		var material: Variant = data.materials[material_id]
		if not items.has(material_id) or str(items[material_id].get("category", "")) != "material" or not material is Dictionary or not equipment_data.materials.has(material.get("family", "")) or not _whole(material.get("tier")) or int(material.tier) < 1 or int(material.tier) > tiers:
			return "炼器材料配置无效：" + material_id
	return ""

## Generated people: the regions with seats, and each kind living in or travelling through places of its
## own region; a region's own small talk covers every personality.
func _validate_population() -> String:
	var shares: Variant = population_data.get("regions")
	if not shares is Dictionary or shares.is_empty():
		return "人口配置缺少 regions。"
	var total := 0.0
	for region_id: String in shares:
		if not regions.has(region_id) or not (shares[region_id] is float or shares[region_id] is int) or float(shares[region_id]) <= 0.0:
			return "人口地区或比例无效：" + region_id
		total += float(shares[region_id])
	if total > 1.0:
		return "人口地区比例之和超过一。"
	var personalities: Array = population_data.personalities.keys()
	for kind_id: String in population_data.kinds:
		var kind: Dictionary = population_data.kinds[kind_id]
		var region := str(kind.get("region", map.get("region", "")))
		if not shares.has(region):
			return "人口类型属于没有席位的地区：" + kind_id
		for place: Variant in kind.get("home", []) + kind.get("schedule", []):
			if place != "away" and (not locations.has(place) or region_of(place) != region):
				return "人口类型去了别区或未知的地点：%s（%s）" % [kind_id, place]
	for region_id: Variant in population_data.get("region_talk", {}):
		var talk: Variant = population_data.region_talk[region_id]
		if not shares.has(region_id) or not talk is Dictionary or personalities.any(func(personality: String) -> bool: return not talk.get(personality) is Array or talk[personality].is_empty()):
			return "地区闲谈须覆盖每种性情：%s" % region_id
	return ""

## Teahouse lore: each a unique id, words to hear and optional conditions (the player's own state).
func _validate_lore() -> String:
	if not lore_data.get("rumors") is Array:
		return "传闻配置缺少 rumors。"
	var seen := {}
	for rumor: Variant in lore_data.rumors:
		if not rumor is Dictionary or not rumor.get("id") is String or str(rumor.id).is_empty() or seen.has(rumor.id):
			return "传闻缺少编号或编号重复。"
		seen[rumor.id] = true
		if not rumor.get("text") is String or str(rumor.text).is_empty():
			return "传闻缺少文字：" + str(rumor.id)
		var problem := _validate_conditions(rumor.get("conditions", []))
		if not problem.is_empty():
			return "传闻条件无效：%s（%s）" % [rumor.id, problem]
	return ""

# --- 飞升 ------------------------------------------------------------------------------------------

func _validate_ascension() -> String:
	var data: Variant = rules.get("ascension")
	if not data is Dictionary or not enemies.has(data.get("tribulation", "")) or not bool(enemies[data.tribulation].get("tribulation", false)) or not _whole(data.get("injury_days")):
		return "飞升配置无效。"
	if not data.get("routes") is Dictionary or data.routes.is_empty():
		return "飞升须有通路。"
	for route_id: String in data.routes:
		var route: Variant = data.routes[route_id]
		if not route is Dictionary or not route.get("flag") in world_flags or not route.get("name") is String or not route.get("ending") is String:
			return "飞升通路配置无效：" + route_id
	if not data.get("truth") is Dictionary or data.truth.keys().any(func(flag: Variant) -> bool: return not flag in world_flags or not data.truth[flag] is String):
		return "飞升结语配置无效。"
	return ""

# --- 天南散修盟 ------------------------------------------------------------------------------------

func _validate_league() -> String:
	var data := league_data
	if not data.get("name") is String or not people.has(data.get("head", "")) or not data.get("branches") is Dictionary or data.branches.is_empty():
		return "散修盟配置无效。"
	if not "league_member" in world_flags:
		return "散修盟标记未登记：league_member"
	for location_id: String in data.branches:
		if not locations.has(location_id) or not data.branches[location_id] is String:
			return "散修盟分舵无效：" + location_id
		if not locations[location_id].spots.any(func(spot: Dictionary) -> bool: return "league" in spot.actions):
			return "散修盟分舵缺少入盟之处：" + location_id
	for board_id: String in commission_data.get("boards", {}):
		var board: Dictionary = commission_data.boards[board_id]
		if board.has("league") and (not data.branches.has(board.location) or board.has("affiliation") or not commission_data.boards.values().any(func(other: Dictionary) -> bool: return other.location == board.location and not other.has("league") and not other.has("affiliation"))):
			return "散修盟的青灯簿须设在有公共告示的分舵：" + board_id
		if board.has("league") and not commission_data.templates.values().any(func(template: Dictionary) -> bool: return board_id in template.boards and _whole(template.get("standing")) and int(template.standing) >= 1):
			return "散修盟的青灯簿须有记声望的差事：" + board_id
	return ""

# --- 秘境 ------------------------------------------------------------------------------------------

## data/mijing.json: each realm a cave at a place of its own that no road reaches, its days open, who it
## lets in and how, who else is inside, its story's events and the way out.
func _validate_mijing() -> String:
	var realms_data: Variant = mijing_data.get("realms")
	if not realms_data is Dictionary or realms_data.is_empty() or not mijing_data.get("layers") is Array or mijing_data.layers.size() != 3:
		return "秘境配置无效。"
	for realm_id: String in realms_data:
		var info: Variant = realms_data[realm_id]
		var where := "秘境 %s" % realm_id
		if not info is Dictionary or not info.get("name") is String or not cave_data.has(info.get("cave", "")) or not locations.has(info.get("location", "")) or not locations.has(info.get("outside", "")):
			return where + " 的名称、洞府或地点无效。"
		if str(cave_data[info.cave].location) != str(info.location) or str(cave_data[info.cave].requires_flag) != str(info.get("open_flag", "")) or not info.open_flag in world_flags:
			return where + " 的洞府须在它自己的地点、随它的开启标记开放。"
		if routes.any(func(route: Dictionary) -> bool: return info.location in route.between):
			return where + " 不应有路可走。"
		if not _whole(info.get("days")) or int(info.days) < 1 or not _whole(info.get("exit_days")) or not _whole(info.get("duel_days")):
			return where + " 的天数无效。"
		if not info.get("min") is Array or info.min.size() != 2 or not _whole(info.min[0]) or not _whole(info.min[1]) or not _whole(info.get("max_realm")) or int(info.max_realm) < int(info.min[0]) or int(info.max_realm) >= realms.size():
			return where + " 的境界范围无效。"
		if not info.get("call_at") is Array or info.call_at.is_empty() or info.call_at.any(func(place: Variant) -> bool: return not locations.has(place)):
			return where + " 的召集地点无效。"
		for key: String in ["gate", "exit_event"]:
			if info.has(key) and (not events.has(info[key]) or events[info[key]].get("trigger") != "manual" or not events[info[key]].has("choices")):
				return where + " 的事件须为有选项的手动事件：" + key
		if not info.has("gate") or not events[info.gate].choices.any(func(choice: Dictionary) -> bool: return choice.get("effects", []).any(func(effect: Dictionary) -> bool: return effect.has("mijing_enter") and str(effect.mijing_enter[0]) == realm_id)):
			return where + " 的召集事件须有进去的选项。"
		if not info.get("ways") is Dictionary or info.ways.is_empty():
			return where + " 没有进去的路数。"
		for way_id: String in info.ways:
			var way: Variant = info.ways[way_id]
			if not way is Dictionary or (way.has("tithe") and (not (way.tithe is float or way.tithe is int) or float(way.tithe) <= 0.0 or float(way.tithe) > 1.0 or not way.get("to") is String)) or (way.has("contribution") and not _whole(way.contribution)):
				return where + " 的路数无效：" + way_id
			if way.has("unless"):
				var problem := _validate_conditions(way.unless)
				if not problem.is_empty():
					return where + " 的路数条件：" + problem
		if not info.get("prize") is Array or info.prize.any(func(item_id: Variant) -> bool: return not items.has(item_id)):
			return where + " 的灵物无效。"
		if info.has("keep") and (not info.keep is Array or info.keep.any(func(item_id: Variant) -> bool: return item(str(item_id)).is_empty())):
			return where + " 的认主之物无效。"
		var meeting: Variant = info.get("meet")
		if not meeting is Dictionary or not events.has(meeting.get("event", "")) or events[meeting.event].get("trigger") != "manual" or not meeting.get("chance") is Array or meeting.chance.size() != 4 or not meeting.get("factions") is Array or meeting.factions.is_empty():
			return where + " 的同场配置无效。"
		if meeting.factions.any(func(faction: Variant) -> bool: return not faction is Dictionary or not sects.has(faction.get("sect", "")) or not faction.get("title") is String):
			return where + " 的势力须写明传承与称呼。"
		for key: String in ["prodigy", "power", "prize_chance", "loss"]:
			if not (meeting.get(key) is float or meeting.get(key) is int) or float(meeting[key]) < 0.0:
				return where + " 的同场数值无效：" + key
		if not meeting.get("stones") is Array or meeting.stones.size() != 2 or not meeting.get("xp") is Array or meeting.xp.is_empty():
			return where + " 的同场奖励无效。"
		for beat: Variant in info.get("beats", []):
			if not beat is Dictionary or not _whole(beat.get("day")) or not events.has(beat.get("event", "")) or events[beat.event].get("trigger") != "manual":
				return where + " 的谷中事件无效。"
		for outcome: Variant in info.get("outcomes", []):
			if not outcome is Dictionary or not outcome.get("text") is String:
				return where + " 的结局无效。"
			var problem := _validate_conditions(outcome.get("if", []))
			if problem.is_empty():
				problem = _validate_effects(outcome.get("effects", []))
			if not problem.is_empty():
				return where + " 的结局：" + problem
		var ambush: Variant = info.get("ambush")
		if not ambush is Dictionary or not events.has(ambush.get("event", "")) or not enemies.has(ambush.get("enemy", "")) or (ambush.has("bribe_flag") and not ambush.bribe_flag in world_flags):
			return where + " 的截道配置无效。"
		for key: String in ["base", "per_value", "max", "ally"]:
			if not (ambush.get(key) is float or ambush.get(key) is int):
				return where + " 的截道数值无效：" + key
		var shut: Variant = info.get("trapped")
		if not shut is Dictionary or not items.has(shut.get("item", "")) or not _whole(shut.get("wound_days")):
			return where + " 的困守配置无效。"
		for flag: Variant in info.get("reset_flags", []):
			if not flag in world_flags:
				return where + " 的重置标记未知：%s" % flag
		for room: Dictionary in cave_data[info.cave].rooms:
			if not room.has("layer"):
				return where + " 的石室须写明层次：" + str(room.id)
		for person_id: String in cave_data[info.cave].get("companions", {}):
			var turn: Variant = cave_data[info.cave].companions[person_id].get("betray")
			if turn != null and (not turn is Dictionary or not _whole(turn.get("day")) or not events.has(turn.get("event", ""))):
				return where + " 的同行者翻脸配置无效：" + person_id
	return ""

# --- 天机阁与天骄榜 ------------------------------------------------------------------------------------

func _validate_tianji() -> String:
	var data := tianji_data
	if not data.get("name") is String or not _whole(data.get("revise_years")) or int(data.revise_years) < 1 or not _whole(data.get("reach")) or int(data.reach) < 1 or not _whole(data.get("cooldown_days")):
		return "天机阁配置无效。"
	if not data.get("scrolls") is Dictionary or data.scrolls.is_empty():
		return "天骄榜没有榜卷。"
	var realms_seen := {}
	for scroll_id: String in data.scrolls:
		var scroll: Variant = data.scrolls[scroll_id]
		if not scroll is Dictionary or not scroll.get("name") is String or not _whole(scroll.get("realm")) or int(scroll.realm) >= realms.size() or realms_seen.has(int(scroll.realm)) or not _whole(scroll.get("size")) or int(scroll.size) <= int(data.reach):
			return "天骄榜榜卷无效：" + scroll_id
		realms_seen[int(scroll.realm)] = true
		if not scroll.get("win") is Dictionary or not _whole(scroll.win.get("stones")) or not _whole(scroll.win.get("xp")):
			return "天骄榜胜场酬劳无效：" + scroll_id
		var gift: Variant = scroll.get("gift")
		if not gift is Dictionary or not _whole(gift.get("stones")) or not gift.get("items", {}) is Dictionary or gift.get("items", {}).keys().any(func(item_id: Variant) -> bool: return not items.has(item_id) or not _whole(gift.items[item_id])):
			return "天骄榜年礼无效：" + scroll_id
	for key: String in ["tiers", "defend_years", "discounts"]:
		var steps: Variant = data.get(key)
		if not steps is Array or steps.is_empty():
			return "天骄榜分档无效：" + key
		var last := 0
		for step: Variant in steps:
			if not step is Array or step.size() != (3 if key == "tiers" else 2) or not _whole(step[0]) or int(step[0]) <= last:
				return "天骄榜分档须按名次递增：" + key
			last = int(step[0])
			if key == "tiers" and (not _whole(step[1]) or int(step[1]) > 3 or not (step[2] is float or step[2] is int) or float(step[2]) <= 0.0):
				return "天骄榜分档的境界与强弱无效。"
			if key == "defend_years" and (not _whole(step[1]) or int(step[1]) < 1):
				return "天骄榜受挑战的间隔无效。"
			if key == "discounts" and (not (step[1] is float or step[1] is int) or float(step[1]) <= 0.0 or float(step[1]) > 1.0):
				return "天骄榜折扣无效。"
	for favor: Variant in data.get("favors", []):
		if not favor is Dictionary or not locations.has(favor.get("location", "")) or not favor.get("flag", "") in world_flags or not (favor.get("rate") is float or favor.get("rate") is int) or float(favor.rate) <= 0.0 or float(favor.rate) > 1.0:
			return "天骄榜之外的折扣无效。"
	if not data.get("filler") is Dictionary or not data.filler.get("lineages") is Array or data.filler.lineages.is_empty() or data.filler.lineages.any(func(lineage: Variant) -> bool: return not sects.has(lineage)):
		return "天骄榜无名之辈的传承无效。"
	if not data.get("prodigies") is Dictionary:
		return "天骄榜人物无效。"
	for prodigy_id: String in data.prodigies:
		var prodigy: Variant = data.prodigies[prodigy_id]
		if prodigy_id == "player" or (prodigy_id.begins_with("f") and prodigy_id.substr(1).is_valid_int()):
			return "天骄榜人物的编号与榜上名号冲突：" + prodigy_id
		if not prodigy is Dictionary or not prodigy.get("name") is String or not prodigy.get("title") is String or not sects.has(prodigy.get("sect", "")) or not prodigy.get("gender") in ["male", "female"]:
			return "天骄榜人物无效：" + prodigy_id
		if prodigy.has("person") and not people.has(prodigy.person):
			return "天骄榜人物对应的人物未知：" + prodigy_id
		if prodigy.has("power") and not (prodigy.power is float or prodigy.power is int):
			return "天骄榜人物的强弱无效：" + prodigy_id
		var seated := false
		for scroll_id: String in data.scrolls:
			if not prodigy.has(scroll_id):
				continue
			var span: Variant = prodigy[scroll_id]
			if not span is Array or span.size() != 3 or not _whole(span[0]) or not _whole(span[1]) or int(span[0]) >= int(span[1]) or not _whole(span[2]) or int(span[2]) < 1 or int(span[2]) > int(data.scrolls[scroll_id].size):
				return "天骄榜人物的在榜年份无效：%s.%s" % [prodigy_id, scroll_id]
			seated = true
		if not seated:
			return "天骄榜人物不在任何一卷：" + prodigy_id
		var problem := _validate_conditions(prodigy.get("absent_if", []))
		if not problem.is_empty():
			return "天骄榜人物 %s：%s" % [prodigy_id, problem]
		for key: String in ["intercept", "bout"]:
			if not prodigy.has(key):
				continue
			var part: Variant = prodigy[key]
			if not part is Dictionary or not part.get("story") is Array or part.story.size() != 2 or not storylines.has(str(part.story[0])) or not storylines[str(part.story[0])].steps.any(func(step: Dictionary) -> bool: return step.id == str(part.story[1])):
				return "天骄榜人物的剧情无效：%s.%s" % [prodigy_id, key]
			for event_key: String in ["event", "won_event"]:
				if part.has(event_key) and (not events.has(str(part[event_key])) or events[str(part[event_key])].get("trigger") != "manual"):
					return "天骄榜人物的事件无效：%s.%s" % [prodigy_id, key]
			if key == "intercept" and not part.has("event"):
				return "天骄榜人物的拦路缺少事件：" + prodigy_id
			problem = _validate_conditions(part.get("unless", []))
			if problem.is_empty():
				problem = _validate_effects(part.get("won", []))
			if problem.is_empty():
				problem = _validate_effects(part.get("lost", []))
			if not problem.is_empty():
				return "天骄榜人物 %s：%s" % [prodigy_id, problem]
	if not locations.values().any(func(location: Dictionary) -> bool: return location.spots.any(func(spot: Dictionary) -> bool: return "tianji" in spot.actions)):
		return "天骄榜没有张榜之处。"
	if not events.has("tianji_challenged") or events.tianji_challenged.get("trigger") != "manual":
		return "天骄榜缺少受挑战的事件：tianji_challenged"
	return _validate_rival()

## 萧家麒麟子 (rival.gd): his person, story, prodigy and each bout's numbers.
func _validate_rival() -> String:
	var rival: Variant = tianji_data.get("rival")
	if not rival is Dictionary or not people.has(rival.get("person", "")) or not storylines.has(rival.get("story", "")) or not tianji_data.prodigies.has(rival.get("prodigy", "")) or not sects.has(rival.get("sect", "")):
		return "宿敌配置无效。"
	var steps: Array = storylines[rival.story].steps.map(func(step: Dictionary) -> String: return step.id)
	for bout_id: String in ["qianlong", "dabi"]:
		var bout: Variant = rival.get(bout_id)
		if not bout is Dictionary or not bout_id in steps or not _whole(bout.get("until")) or not bout.get("note") is String:
			return "宿敌交锋无效：" + bout_id
	var first: Dictionary = rival.qianlong
	if not first.get("level") is Array or first.level.size() != 2 or not _whole(first.level[0]) or not _whole(first.level[1]) or not (first.get("power") is float or first.get("power") is int) or not _whole(first.get("xp")):
		return "宿敌交锋无效：qianlong"
	var second: Dictionary = rival.dabi
	if not summit_data.has(second.get("contest", "")) or not tianji_data.scrolls.has(second.get("scroll", "")) or not events.has(second.get("event", "")) or events[second.event].get("trigger") != "manual" or not (second.get("rigged") is float or second.get("rigged") is int) or not _whole(second.get("poison_percent")) or int(second.poison_percent) > 100:
		return "宿敌交锋无效：dabi"
	for flag: String in ["xiao_bout1", "xiao_win1", "xiao_loss1", "xiao_spare1", "xiao_bout2", "xiao_win2", "xiao_loss2", "xiao_spare2", "xiao_bout3", "xiao_win3", "xiao_loss3", "xiao_spare3", "xiao_ambush", "xiao_face", "xiao_poison_found"]:
		if not flag in world_flags:
			return "宿敌标记未登记：" + flag
	for event_id: String in ["xiao_after1", "xiao_after2"]:
		if not events.has(event_id) or events[event_id].get("trigger") != "manual":
			return "宿敌缺少事件：" + event_id
	return ""

# --- 客卿 ------------------------------------------------------------------------------------------

func _validate_guests() -> String:
	var data := guest_data
	if not data.get("sects") is Dictionary or data.sects.is_empty():
		return "客卿缺少宗门配置。"
	for key: String in ["min_realm", "most", "invite_favor", "call_years", "call_days", "missed_most", "served_favor"]:
		if not _whole(data.get(key)) or int(data[key]) < 1 and key != "min_realm":
			return "客卿配置无效：" + key
	if not data.get("stipend") is Array or data.stipend.size() != realms.size() or data.stipend.any(func(value: Variant) -> bool: return not _whole(value)):
		return "客卿月俸须按境界逐一给出。"
	for sect: String in data.sects:
		var terms: Variant = data.sects[sect]
		if not sects.has(sect) or sect == str(rules.lineage.home) or not terms is Dictionary or not locations.has(terms.get("location", "")):
			return "客卿宗门配置无效：" + sect
		if not terms.get("perk") in ["forge_free", "alchemy_free", "discount", "archive"] or not terms.get("perk_text") is String:
			return "客卿专长无效：" + sect
		if terms.has("person") and not people.has(terms.person):
			return "客卿宗门的首徒不存在：" + sect
		if terms.has("flag") and not terms.flag in world_flags:
			return "客卿专长的标记未登记：" + sect
		if terms.get("places", []).any(func(place: Variant) -> bool: return not locations.has(place)):
			return "客卿专长的地点无效：" + sect
		for flag: String in ["guest_" + sect, "guest_invite_" + sect, "guest_ended_" + sect]:
			if not flag in world_flags:
				return "客卿标记未登记：" + flag
		var board: Variant = commission_data.get("boards", {}).get("guest_" + sect)
		if not board is Dictionary or board.get("location") != terms.location:
			return "客卿差遣告示无效：" + sect
		if not commission_data.templates.values().any(func(template: Dictionary) -> bool: return "guest_" + sect in template.boards):
			return "客卿没有差遣：" + sect
	return ""

# --- 五宗论道 --------------------------------------------------------------------------------------

func _validate_summit() -> String:
	if not summit_data.has("wuzong"):
		return "五宗论道缺少配置。"
	if not events.has(str(summit_data.wuzong.get("event", ""))):
		return "五宗论道的报名事件不存在。"
	for contest_id: String in summit_data:
		var data: Variant = summit_data[contest_id]
		if not data is Dictionary or not data.get("name") is String:
			return "擂台大会缺少名字：" + contest_id
		var champions: Variant = data.get("champions")
		if not champions is Array or champions.is_empty():
			return "%s没有对手。" % data.name
		for champion: Variant in champions:
			if not champion is Dictionary or not sects.has(champion.get("sect", "")) or not champion.get("name") is String or not champion.get("title") is String or not champion.get("gender") in ["male", "female"]:
				return "%s的对手配置无效。" % data.name
		for key: String in ["levels", "power"]:
			if not data.get(key) is Array or data[key].size() != champions.size():
				return "%s须按轮次给出：%s" % [data.name, key]
		if data.levels.any(func(level: Variant) -> bool: return not level is Array or level.size() != 2 or not _whole(level[0]) or int(level[0]) >= realms.size() or not _whole(level[1]) or int(level[1]) >= realms[int(level[0])].stages.size()):
			return "%s的对手修为无效。" % data.name
		for realm_key: Variant in data.get("groups", {}):
			var group: Variant = data.groups[realm_key]
			if not str(realm_key).is_valid_int() or int(str(realm_key)) >= realms.size() or not group is Dictionary or not group.get("levels") is Array or group.levels.size() != champions.size() or group.levels.any(func(level: Variant) -> bool: return not level is Array or level.size() != 2 or not _whole(level[0]) or int(level[0]) >= realms.size() or not _whole(level[1]) or int(level[1]) >= realms[int(level[0])].stages.size()):
				return "%s的分组无效。" % data.name
		if data.has("world_flag") and not data.world_flag in world_flags:
			return "%s的魁首标记未登记。" % data.name
		if not _whole(data.get("recover_percent")) or not data.get("round") is Dictionary or not data.get("champion") is Dictionary:
			return "%s的奖赏配置无效。" % data.name
	return ""

# --- Auctions --------------------------------------------------------------------------------------

func _validate_auctions() -> String:
	var data := auction_data
	if not data.get("temper") is Dictionary or data.temper.values().any(func(value: Variant) -> bool: return not (value is float or value is int) or float(value) <= 0.0):
		return "拍卖的性情系数无效。"
	if not data.get("wealth") is Array or data.wealth.size() != realms.size():
		return "拍卖的身家须按境界逐一给出。"
	for index: int in realms.size():
		var row: Variant = data.wealth[index]
		if not row is Array or row.size() != realms[index].stages.size() or row.any(func(value: Variant) -> bool: return not (value is float or value is int) or float(value) <= 0.0):
			return "拍卖的身家须按小阶段逐一给出：%d" % index
	if not data.get("spread") is Array or data.spread.size() != 2 or float(data.spread[0]) <= 0.0 or float(data.spread[0]) > float(data.spread[1]):
		return "拍卖的出价浮动无效。"
	if not data.get("auctions") is Dictionary or data.auctions.is_empty():
		return "没有拍卖。"
	for auction_id: String in data.auctions:
		var auction: Variant = data.auctions[auction_id]
		if not auction is Dictionary or not auction.get("name") is String or not auction.get("pool") is Array or not _whole(auction.get("lots")) or int(auction.lots) < 1 or auction.pool.size() < int(auction.lots) or not _whole(auction.get("bidders")) or int(auction.bidders) < 1:
			return "拍卖配置无效：" + auction_id
		for entry: Variant in auction.pool:
			if not entry is Dictionary or [entry.has("item"), entry.has("manual"), entry.has("equipment")].count(true) != 1:
				return "拍品须是物品、玉简或宝物之一：" + auction_id
			if entry.has("item") and not items.has(entry.item):
				return "拍品引用了未知物品：%s" % entry.item
			for key: String in ["manual", "equipment"]:
				if entry.has(key) and (not _whole(entry[key]) or int(entry[key]) < 1 or int(entry[key]) > technique_data.tiers.size()):
					return "拍品品阶无效：" + auction_id
			for key: String in ["start", "step", "value"]:
				if not _whole(entry.get(key)) or int(entry[key]) < 1:
					return "拍品价格无效：" + auction_id
			if entry.has("count") and (not _whole(entry.count) or int(entry.count) < 1):
				return "拍品数量无效：" + auction_id
	return ""

# --- The old cave's rooms --------------------------------------------------------------------------

func _validate_caves() -> String:
	for cave_id: String in cave_data:
		var cave: Variant = cave_data[cave_id]
		if not cave is Dictionary or not cave.get("name") is String or not locations.has(cave.get("location", "")) or not cave.get("requires_flag") in world_flags or not _whole(cave.get("step_days")) or int(cave.step_days) < 1:
			return "洞府配置无效：" + cave_id
		if not locations[cave.location].spots.any(func(spot: Dictionary) -> bool: return "explore_cave" in spot.actions and (not cave.has("spot") or spot.id == cave.spot)):
			return "洞府所在地点没有探索的场景：" + cave_id
		if cave.has("requires_realm") and (not _whole(cave.requires_realm) or int(cave.requires_realm) >= realms.size()):
			return "洞府的境界要求无效：" + cave_id
		if not cave.get("rooms") is Array or cave.rooms.is_empty():
			return "洞府没有石室：" + cave_id
		var ids := {}
		for room: Variant in cave.rooms:
			if not room is Dictionary or not room.get("id") is String or ids.has(room.id) or not room.get("name") is String or not room.get("text") is String:
				return "石室配置无效：%s" % cave_id
			ids[room.id] = room
		if not cave.rooms.any(func(room: Dictionary) -> bool: return bool(room.get("start", false))):
			return "洞府没有入口：" + cave_id
		for room: Dictionary in cave.rooms:
			var where := "%s.%s" % [cave_id, room.id]
			var spot: Variant = room.get("map")
			if not spot is Array or spot.size() != 2 or spot.any(func(value: Variant) -> bool: return not (value is float or value is int) or float(value) < 0.0 or float(value) > 1.0):
				return "石室在图上的位置无效：" + where
			if not room.get("links") is Array or room.links.is_empty() or room.links.any(func(link: Variant) -> bool: return not ids.has(link) or not room.id in ids[link].get("links", [])):
				return "石室的通路须双向且指向已知石室：" + where
			if room.has("trap"):
				var trap: Variant = room.trap
				if not trap is Dictionary or not trap.get("names") is Array or trap.names.is_empty() or trap.names.any(func(name: Variant) -> bool: return not name is String) or not _whole(trap.get("sense")) or not trap.get("damage") is Array or trap.damage.size() != 2 or not _whole(trap.damage[0]) or not _whole(trap.damage[1]) or int(trap.damage[0]) > int(trap.damage[1]):
					return "机关配置无效：" + where
			if room.has("loot") and not _valid_cave_loot(room.loot):
				return "石室宝物配置无效：" + where
			if room.has("hidden"):
				var hidden: Variant = room.hidden
				if not hidden is Dictionary or not hidden.get("name") is String or not _whole(hidden.get("sense")) or not _whole(hidden.get("qi")) or not _valid_cave_loot(hidden.get("loot")) or (hidden.has("fortune") and hidden.fortune != "shiru"):
					return "暗格配置无效：" + where
			if room.has("guardian") and (not enemies.has(room.guardian) or not enemies[room.guardian].get("world_flag", "") in world_flags):
				return "守洞的对手须有世界标记：" + where
			if room.has("fortune") and (room.fortune != "remnant" or not room.has("loot")):
				return "残魂须在有宝物可替的石室：" + where
			if room.has("requires_sense") and not _whole(room.requires_sense):
				return "禁制的神识要求无效：" + where
			if room.has("requires_realm") and (not _whole(room.requires_realm) or int(room.requires_realm) >= realms.size() or not room.get("realm_text") is String):
				return "深处的境界要求须写明境界与说明：" + where
			if room.has("flag") and not room.flag in world_flags:
				return "石室引用了未知标记：" + where
			if room.has("layer") and (not _whole(room.layer) or int(room.layer) < 1 or int(room.layer) > 3):
				return "石室的层次须为 1～3：" + where
			if room.has("requires_flag") and not room.requires_flag in world_flags:
				return "石室等待的标记未知：" + where
			if room.has("gone_if") and not room.gone_if in world_flags:
				return "石室的消失标记未知：" + where
			if room.has("event") and (not events.has(room.event) or events[room.event].get("trigger") != "manual" or not events[room.event].has("choices")):
				return "石室的事件须为有选项的手动事件：" + where
			if room.has("requires_wins") and (not _whole(room.requires_wins) or int(room.requires_wins) < 1 or not room.get("wins_text") is String):
				return "石室须写明要胜几人与说明：" + where
			if room.has("heat"):
				var heat: Variant = room.heat
				if not heat is Dictionary or not items.has(heat.get("item", "")) or not _whole(heat.get("sense")) or not heat.get("text") is String:
					return "热浪须写明避火之物、替代的神识与说明：" + where
	return ""

## A room's `loot`: choices, each a non-empty list of {"stones" | "pills": n}, {"item": [id, n]},
## {"manual" | "equipment": tier}.
func _valid_cave_loot(choices: Variant) -> bool:
	if not choices is Array or choices.is_empty():
		return false
	for choice: Variant in choices:
		if not choice is Array or choice.is_empty():
			return false
		for effect: Variant in choice:
			if not effect is Dictionary or effect.size() != 1:
				return false
			var key: String = effect.keys()[0]
			var value: Variant = effect[key]
			match key:
				"stones", "pills":
					if not _whole(value) or int(value) < 1:
						return false
				"item":
					if not value is Array or value.size() != 2 or item(str(value[0])).is_empty() or not _whole(value[1]) or int(value[1]) < 1:
						return false
				"manual", "equipment":
					if not _whole(value) or int(value) < 1 or int(value) > technique_data.tiers.size():
						return false
				"slip":
					if not value is String or not skills.has(value):
						return false
				_:
					return false
	return true

# --- Alchemy static checks ------------------------------------------------------------------------

func _validate_alchemy() -> String:
	var data := alchemy_data
	var natures: Variant = data.get("natures")
	if not natures is Dictionary or not natures.has("neutral") or not natures.has("cold") or not natures.has("hot"):
		return "药性配置无效。"
	for item_id: String in items:
		var item: Dictionary = items[item_id]
		if item.category == "herb" and not natures.has(item.get("nature", "")):
			return "灵草缺少药性：%s" % item_id
		if item.has("grow") and (item.category != "herb" or not item.grow is Dictionary or not _whole(item.grow.get("days")) or int(item.grow.days) < 1 or not _whole(item.grow.get("yield")) or int(item.grow.yield) < 1):
			return "灵草的生长配置无效：%s" % item_id
		if item.has("fine_of") and (item.category != "pill" or not items.has(item.fine_of) or items[item.fine_of].category != "pill" or items[item.fine_of].has("fine_of")):
			return "上品丹药无效：%s" % item_id
		if item.has("furnace"):
			var furnace: Variant = item.furnace
			if item.category != "tool" or not furnace is Dictionary or not _whole(furnace.get("success")) or not _whole(furnace.get("fine")) or not _whole(furnace.get("yield")):
				return "丹炉配置无效：%s" % item_id
		if item.has("aid") and (item.category != "tool" or not item.aid is Dictionary or not _whole(item.aid.get("success")) or not item.aid.get("safe", false) is bool):
			return "炼丹辅具配置无效：%s" % item_id
		if item.category == "recipe" and not item.get("use", []).any(func(effect: Dictionary) -> bool: return effect.has("recipe")):
			return "丹方须能研读：%s" % item_id
	var recipes: Variant = data.get("recipes")
	if not recipes is Dictionary or recipes.is_empty():
		return "丹方配置无效。"
	for recipe_id: String in recipes:
		var recipe: Variant = recipes[recipe_id]
		if not recipe is Dictionary or not items.get(recipe.get("pill", ""), {}).get("category", "") == "pill" or str(items.get(recipe.get("fine", ""), {}).get("fine_of", "")) != str(recipe.pill):
			return "丹方的丹药无效：%s" % recipe_id
		if not recipe.get("main") is Dictionary or recipe.main.is_empty():
			return "丹方缺少主药：%s" % recipe_id
		for herb_id: Variant in recipe.main:
			if items.get(herb_id, {}).get("category", "") != "herb" or not _whole(recipe.main[herb_id]) or int(recipe.main[herb_id]) < 1:
				return "丹方的主药无效：%s" % recipe_id
		if not _whole(recipe.get("days")) or int(recipe.days) < 1 or not _whole(recipe.get("success")):
			return "丹方的时日或成功率无效：%s" % recipe_id
		if not recipe.get("yield") is Array or recipe.yield.size() != 2 or not _whole(recipe.yield[0]) or int(recipe.yield[0]) < 1 or not _whole(recipe.yield[1]) or int(recipe.yield[1]) < int(recipe.yield[0]):
			return "丹方的成丹数无效：%s" % recipe_id
	var places: Variant = data.get("places")
	if not places is Dictionary:
		return "炼丹地点配置无效。"
	for location_id: String in places:
		var here: Variant = places[location_id]
		if not locations.has(location_id) or not here is Dictionary or not here.get("name") is String or not _whole(here.get("success")) or not _whole(here.get("fee")):
			return "炼丹地点无效：%s" % location_id
		if here.has("needs_met") and not people.has(here.needs_met):
			return "炼丹地点引用了未知人物：%s" % location_id
	var fires: Variant = data.get("fires")
	if not fires is Dictionary or not fires.has("gentle"):
		return "火候配置无效。"
	for fire_id: String in fires:
		var fire: Variant = fires[fire_id]
		if not fire is Dictionary or not fire.get("name") is String or not _signed(fire.get("success")) or not _whole(fire.get("fine")):
			return "火候配置无效：%s" % fire_id
	for key: String in ["fine_base", "fine_most", "burst_hp_percent", "foundation_fine_bonus"]:
		if not _whole(data.get(key)):
			return "炼丹配置缺少：%s" % key
	var bounds: Variant = data.get("success_range")
	if not bounds is Array or bounds.size() != 2 or not _whole(bounds[0]) or not _whole(bounds[1]) or int(bounds[0]) > int(bounds[1]):
		return "炼丹成功率范围无效。"
	var practice: Variant = data.get("practice")
	if not practice is Dictionary or ["success_step", "success_most", "fine_step", "fine_most"].any(func(key: String) -> bool: return not _whole(practice.get(key))):
		return "炼丹熟练配置无效。"
	var toxin: Variant = data.get("toxin")
	if not toxin is Dictionary or ["limit", "decay_per_day", "breakthrough_step"].any(func(key: String) -> bool: return not _whole(toxin.get(key)) or int(toxin[key]) < 1):
		return "丹毒配置无效。"
	var field: Variant = data.get("field")
	if not field is Dictionary or rank_index(str(field.get("rank", ""))) < 0 or not field.get("grades") is Array or field.grades.is_empty():
		return "灵田配置无效。"
	for index: int in field.grades.size():
		var grade: Variant = field.grades[index]
		if not grade is Dictionary or not grade.get("name") is String or not _whole(grade.get("plots")) or int(grade.plots) < 1 or not _whole(grade.get("growth")) or int(grade.growth) < 1 or not _whole(grade.get("bonus")):
			return "灵田品级无效：%d" % index
		if index > 0 and (not grade.get("cost") is Dictionary or not _whole(grade.cost.get("stones")) or not _whole(grade.cost.get("contribution")) or not grade.get("stage") is Array or grade.stage.size() != 2 or not _whole(grade.stage[0]) or int(grade.stage[0]) >= realms.size() or not _whole(grade.stage[1])):
			return "灵田扩建配置无效：%d" % index
	return ""

# --- Bonds static checks --------------------------------------------------------------------------

func _validate_bonds() -> String:
	var data := bonds_data
	for key: String in ["sound_at", "most_letters"]:
		if not _whole(data.get(key)):
			return "人情配置缺少：" + key
	for key: String in ["consult", "teach", "aid"]:
		if not data.get(key) is Dictionary or not _whole(data[key].get("favor")):
			return "人情配置缺少：" + key
	if not _whole(data.consult.get("days")) or not _whole(data.consult.get("cooldown_days")) or not (data.aid.get("power") is float or data.aid.get("power") is int):
		return "请教或求援配置无效。"
	var companion: Variant = data.get("companion")
	if not companion is Dictionary or ["favor", "realm", "speed", "mind"].any(func(key: String) -> bool: return not _whole(companion.get(key))) or int(companion.realm) >= realms.size():
		return "道侣配置无效。"
	var sworn: Variant = data.get("sworn")
	if not sworn is Dictionary or ["favor", "most", "mind"].any(func(key: String) -> bool: return not _whole(sworn.get(key))):
		return "结拜配置无效。"
	var disciple: Variant = data.get("disciple")
	if not disciple is Dictionary or ["favor", "realm", "most"].any(func(key: String) -> bool: return not _whole(disciple.get(key))) or int(disciple.realm) >= realms.size() or not disciple.get("instruct") is Dictionary or not disciple.get("tribute") is Dictionary or not _whole(disciple.tribute.get("every_periods")) or int(disciple.tribute.every_periods) < 1:
		return "收徒配置无效。"
	if not data.get("letters", {}).has("tribute"):
		return "弟子孝敬缺少传音的话。"
	if not rules.bottleneck.insight.has("consult"):
		return "请教缺少历练数值。"
	var visits: Variant = data.get("visits")
	if not visits is Dictionary or not _whole(visits.get("period_days")) or int(visits.period_days) < 1 or not (visits.get("chance") is float or visits.get("chance") is int) or not _whole(visits.get("most_open")) or not visits.get("kinds") is Dictionary:
		return "人物往来配置无效。"
	for kind_id: String in ["spar", "help", "outing", "loan", "gift"]:
		var kind: Variant = visits.kinds.get(kind_id)
		if not kind is Dictionary or not _whole(kind.get("weight")) or int(kind.weight) < 1:
			return "人物往来缺少：" + kind_id
		for item_id: Variant in kind.get("items", []):
			if not items.has(item_id):
				return "人物往来引用了未知物品：%s" % item_id
		for place: Variant in kind.get("places", []):
			if not locations.has(place):
				return "人物往来引用了未知地点：%s" % place
	var personalities: Array = population_data.personalities.keys()
	for kind_id: String in ["spar", "help", "outing", "loan", "gift", "congrats", "repaid"]:
		var letters: Variant = data.get("letters", {}).get(kind_id)
		if not letters is Dictionary or personalities.any(func(personality: String) -> bool: return not letters.get(personality) is String):
			return "人物传音缺少：%s" % kind_id
	return ""

# --- Talent static checks -------------------------------------------------------------------------

func _validate_talents() -> String:
	var data := talent_data
	if not data.get("tiers") is Array or data.tiers.is_empty() or not data.get("talents") is Dictionary or not data.get("flaws") is Dictionary:
		return "天赋配置无效。"
	var tiers := {}
	for tier: Variant in data.tiers + [data.get("flaw")]:
		if not tier is Dictionary or not tier.get("id") is String or not tier.get("name") is String or not tier.get("color") is String or not _signed(tier.get("score")):
			return "天赋等级配置无效。"
		tiers[tier.id] = true
	if not data.get("tables") is Dictionary or not data.tables.has("default") or not data.get("player") is Dictionary or not data.tables.has(data.player.get("table", "")):
		return "天赋出生表配置无效。"
	if not _whole(data.player.get("senses")) or int(data.player.senses) < 1:
		return "感应次数无效。"
	for table_id: String in data.tables:
		var table: Variant = data.tables[table_id]
		if not table is Dictionary or not table.get("counts") is Array or table.counts.is_empty() or not table.get("weights") is Dictionary or table.weights.is_empty() or not (table.get("flaw_chance") is float or table.get("flaw_chance") is int):
			return "天赋出生表无效：%s" % table_id
		for entry: Variant in table.counts:
			if not entry is Array or entry.size() != 2 or not _whole(entry[0]) or not (entry[1] is float or entry[1] is int) or float(entry[1]) <= 0.0:
				return "天赋数量权重无效：%s" % table_id
		for tier_id: Variant in table.weights:
			if not tiers.has(tier_id) or tier_id == "flaw" or not (table.weights[tier_id] is float or table.weights[tier_id] is int) or float(table.weights[tier_id]) <= 0.0:
				return "天赋等级权重无效：%s.%s" % [table_id, tier_id]
	var chances: Variant = population_data.get("life", {}).get("foundation_by_aptitude")
	if not chances is Array or chances.size() != data.get("aptitude", []).size():
		return "人物筑基几率须按资质等级给出。"
	if not data.get("root_scores") is Dictionary or not data.get("speed_scores") is Array or not data.get("aptitude") is Array or data.aptitude.is_empty():
		return "资质配置无效。"
	var previous := -1000
	for grade: Variant in data.aptitude:
		if not grade is Dictionary or not grade.get("name") is String or not grade.get("color") is String or not _signed(grade.get("score")) or int(grade.score) <= previous:
			return "资质等级配置无效。"
		previous = int(grade.score)
	var names := {}
	for table: String in ["talents", "flaws"]:
		for id: String in data[table]:
			var talent: Variant = data[table][id]
			if not talent is Dictionary or not talent.get("name") is String or not talent.get("description") is String or names.has(talent.name):
				return "天赋缺少名称、描述或重名：%s" % id
			names[talent.name] = true
			if table == "talents" and (not tiers.has(talent.get("tier", "")) or talent.tier == "flaw"):
				return "天赋等级未知：%s" % id
			if table == "talents" and data.flaws.has(id):
				return "天赋与缺陷同名：%s" % id
			if not talent.get("mods") is Dictionary:
				return "天赋缺少修正：%s" % id
			for key: Variant in talent.mods:
				if not key in Talents.MODIFIERS or not _signed(talent.mods[key]):
					return "天赋修正无效：%s.%s" % [id, key]
			if talent.has("group") and not talent.group is String:
				return "天赋分组无效：%s" % id
			if talent.has("gained") and not talent.gained is bool:
				return "天赋来源无效：%s" % id
	for tier: Dictionary in data.tiers:
		if not data.talents.values().any(func(talent: Dictionary) -> bool: return talent.tier == tier.id and not bool(talent.get("gained", false))):
			return "天赋等级没有可抽取的天赋：%s" % tier.id
	return ""

## Every kind of fortune a life can meet (player.boons): the breakthrough's own, 残魂灌顶, and those in
## rules.fortune.
func boon_ids() -> Array:
	var ids: Array = ["remnant"]
	for boon: Dictionary in rules.get("breakthrough", {}).get("boons", []):
		ids.append(boon.id)
	for id: String in rules.get("fortune", {}):
		if not id in ids:
			ids.append(id)
	return ids

## A talent or flaw id defined in data/talents.json.
func is_talent(id: Variant) -> bool:
	return id is String and (talent_data.get("talents", {}).has(id) or talent_data.get("flaws", {}).has(id))

func _signed(value: Variant) -> bool:
	return (value is int or value is float) and is_finite(float(value)) and float(value) == floor(float(value))

# --- Storyline static checks ----------------------------------------------------------------------

func _validate_storylines() -> String:
	var guides := 0
	for story_id: String in storylines:
		var story: Variant = storylines[story_id]
		if not story is Dictionary or not story.get("title") is String or not people.has(story.get("giver", "")):
			return "剧情 %s：缺少标题或交代之人" % story_id
		if bool(story.get("guide", false)):
			guides += 1
		for key: String in ["begin_if", "close_if"]:
			var problem := _validate_conditions(story.get(key, []))
			if not problem.is_empty():
				return "剧情 %s：%s" % [story_id, problem]
		if story.has("closed") and not story.closed is String:
			return "剧情 %s：结束语必须是文字" % story_id
		if not story.get("steps") is Array or story.steps.is_empty():
			return "剧情 %s：没有步骤" % story_id
		var ids := {}
		for step: Variant in story.steps:
			if not step is Dictionary or not step.get("id") is String or ids.has(step.id):
				return "剧情 %s：步骤缺少唯一 ID" % story_id
			ids[step.id] = true
			var problem := _validate_step(step)
			if not problem.is_empty():
				return "剧情 %s.%s：%s" % [story_id, step.id, problem]
	return "" if guides <= 1 else "只能有一段入门指引剧情"

func _validate_step(step: Dictionary) -> String:
	for key: String in ["goal", "say", "after", "closed"]:
		if step.has(key) and (not step[key] is String or step[key].is_empty()):
			return "%s 必须是文字" % key
	for key: String in ["letter", "auto", "major"]:
		if step.has(key) and not step[key] is bool:
			return "%s 必须是真假值" % key
	if bool(step.get("letter", false)) and not step.has("say"):
		return "传音的步骤需要 say"
	if step.has("place") and not locations.has(step.place):
		return "未知地点"
	if step.has("goal_variants"):
		if not step.goal_variants is Array:
			return "剧情目标分支须为列表"
		for variant: Variant in step.goal_variants:
			if not variant is Dictionary or not variant.get("goal") is String or (variant.has("place") and not locations.has(variant.place)):
				return "剧情目标分支缺少说明或去处"
			var issue := _validate_conditions(variant.get("conditions", []))
			if not issue.is_empty():
				return issue
	if step.has("choice_event") and (not step.choice_event is String or not events.has(step.choice_event) or not events[step.choice_event].has("choices")):
		return "剧情抉择引用了未知事件"
	if step.has("speaker") and not people.has(step.speaker):
		return "未知人物"
	for key: String in ["wait_days", "retreat_days"]:
		if step.has(key) and (not _whole(step[key]) or int(step[key]) < 1):
			return "%s 无效" % key
	if step.has("wait_days") and (step.has("done") or step.has("deeds")):
		return "等候的步骤不能另有完成条件"
	if step.has("deeds"):
		if not step.deeds is Dictionary or step.deeds.is_empty():
			return "deeds 必须是非空对象"
		for deed: String in step.deeds:
			if not _known_deed(deed) or not _whole(step.deeds[deed]) or int(step.deeds[deed]) < 1:
				return "未知或无效的事迹：%s" % deed
	for key: String in ["done", "requires", "close_if", "skip_if"]:
		var problem := _validate_conditions(step.get(key, []))
		if not problem.is_empty():
			return problem
	return _validate_effects(step.get("effects", []))

## Deeds the session counts (storylines.gd): plain ones, and a victory over a known enemy.
func _known_deed(deed: String) -> bool:
	if deed.begins_with("win:"):
		return enemies.has(deed.trim_prefix("win:"))
	return deed in DEEDS

# --- Map static checks --------------------------------------------------------

func _validate_map() -> String:
	if not locations.has(map.get("start", "")) or locations[map.start].has("hidden_until"):
		return "地图起点无效。"
	if not (map.get("aspect") is float or map.get("aspect") is int) or float(map.aspect) <= 0.0:
		return "地图比例无效。"
	if not regions.has(map.get("region", "")):
		return "地图缺少所属地区。"
	for region_id: String in regions:
		var region: Variant = regions[region_id]
		if not region is Dictionary or not region.get("name") is String or not (region.get("aspect") is float or region.get("aspect") is int) or float(region.aspect) <= 0.0:
			return "地区配置无效：" + region_id
	for location_id: String in locations:
		var location: Dictionary = locations[location_id]
		var point: Variant = location.get("map")
		if not point is Array or point.size() != 2:
			return "地点缺少地图坐标：" + location_id
		for value: Variant in point:
			if not (value is float or value is int) or float(value) < 0.0 or float(value) > 1.0:
				return "地图坐标超出范围：" + location_id
		if not location.get("terrain") is String:
			return "地点缺少地貌：" + location_id
		if location.has("region") and not regions.has(location.region):
			return "地点属于未知地区：" + location_id
		if location.has("hidden_until") and not location.hidden_until in world_flags:
			return "隐藏地点引用了未知标记：" + location_id
		if location.has("sealed_if") and not location.sealed_if in world_flags:
			return "封锁地点引用了未知标记：" + location_id
		if location.has("gather"):
			var gather: Variant = location.gather
			if not gather is Dictionary or not gather.get("picks") is Array or gather.picks.size() != 2 or not _whole(gather.picks[0]) or not _whole(gather.picks[1]) or int(gather.picks[0]) < 1 or int(gather.picks[0]) > int(gather.picks[1]):
				return "采集次数错误：" + location_id
			if not gather.get("table") is Array or gather.table.is_empty():
				return "采集表为空：" + location_id
			for entry: Variant in gather.table:
				if not entry is Dictionary or not items.has(entry.get("item", "")) or not _whole(entry.get("weight")) or int(entry.weight) < 1:
					return "采集表条目错误：" + location_id
		for good: Variant in location.get("shop", []):
			if not good is Dictionary or item(str(good.get("item", ""))).is_empty() or not _whole(good.get("price")) or int(good.price) < 1:
				return "商店货品错误：" + location_id
		for category: Variant in location.get("buys", []):
			if not ITEM_CATEGORIES.has(category):
				return "收购品类未知：" + location_id
		# 跨城需求 (inventory.gd): something this place is short of and pays more for, while it lasts.
		for entry: Variant in location.get("demand", []):
			if not entry is Dictionary or not items.has(entry.get("item", "")) or not items[entry.item].category in location.get("buys", []) or not (entry.get("factor") is float or entry.get("factor") is int) or float(entry.factor) <= 1.0 or not _whole(entry.get("need")) or int(entry.need) < 1 or not _whole(entry.get("days")) or int(entry.days) < 1 or not entry.get("text") is String:
				return "紧缺货品配置错误：" + location_id
		if location.has("stock"):
			var stock: Variant = location.stock
			if not stock is Dictionary or not _whole(stock.get("restock_days")) or int(stock.restock_days) < 1 or not stock.get("lines") is Array:
				return "轮换货品配置错误：" + location_id
			for line: Variant in stock.lines:
				if not line is Dictionary or not line.get("kind") in ["manual", "equipment"] or not _whole(line.get("count")) or not line.get("tiers") is Array or line.tiers.size() != 2 or int(line.tiers[0]) < 1 or int(line.tiers[1]) > technique_data.tiers.size() or int(line.tiers[0]) > int(line.tiers[1]):
					return "轮换货品条目错误：" + location_id
		if not location.get("spots") is Array or location.spots.is_empty():
			return "地点缺少场景：" + location_id
		var ids := {}
		for spot: Variant in location.spots:
			if not spot is Dictionary or not spot.get("id") is String or ids.has(spot.id) or not spot.get("name") is String or not spot.get("actions") is Array:
				return "场景配置错误：" + location_id
			ids[spot.id] = true
			if spot.has("requires_flag") and not spot.requires_flag in world_flags:
				return "场景引用了未知标记：%s.%s" % [location_id, spot.id]
			if spot.has("tag") and (not spot.tag is Array or spot.tag.size() != 2 or spot.tag.any(func(value: Variant) -> bool: return not (value is float or value is int) or float(value) < 0.0 or float(value) > 0.95)):
				return "场景纸条位置无效：%s.%s" % [location_id, spot.id]
			if spot.has("requires_rank") and rank_index(str(spot.requires_rank)) < 0:
				return "场景引用了未知宗门身份：%s.%s" % [location_id, spot.id]
			for taught: Variant in spot.get("teach", []):
				if not taught is String or technique(taught).is_empty():
					return "场景传授了无效的功法：%s" % taught
			if spot.has("lodging"):
				var let: Variant = spot.lodging
				if not "cultivate" in spot.actions or not let is Dictionary or not (let.get("rate") is float or let.get("rate") is int) or float(let.rate) <= 0.0 or not _whole(let.get("rent")) or let.keys().any(func(key: Variant) -> bool: return not key in ["rate", "rent", "league", "realm", "standing"]):
					return "静房配置无效：%s.%s" % [location_id, spot.id]
				if let.has("league") and (not let.league is bool or str(spot.get("requires_flag", "")) != "league_member"):
					return "散修盟的静房须只对盟中人开放：%s.%s" % [location_id, spot.id]
				if (let.has("realm") and (not _whole(let.realm) or int(let.realm) >= realms.size())) or (let.has("standing") and not _whole(let.standing)):
					return "静房的境界或声望门槛无效：%s.%s" % [location_id, spot.id]
			if spot.has("teach") != ("teach" in spot.actions):
				return "传授功法的场景须有 teach 行为与传授列表：%s.%s" % [location_id, spot.id]
			for action: Variant in spot.actions:
				if not action is String:
					return "场景行为错误：%s.%s" % [location_id, spot.id]
				if action.begins_with("battle:"):
					if not enemies.has(action.trim_prefix("battle:")):
						return "场景引用了未知敌人：%s" % action
				elif not action in PLAIN_ACTIONS:
					return "场景引用了未知行为：%s" % action
				if action == "gather" and not location.has("gather"):
					return "可采集的地点缺少采集数量：" + location_id
				if action == "shop" and location.get("shop", []).is_empty():
					return "开店的地点没有货品：" + location_id
				if action == "sell" and location.get("buys", []).is_empty():
					return "收购的地点没有收购品类：" + location_id
				if action == "alchemy" and not alchemy_data.get("places", {}).has(location_id):
					return "可炼丹的地点缺少丹炉配置：" + location_id
				if action == "lease" and not location.has("lease"):
					return "出赁住处的地点缺少租约配置：" + location_id
				if action == "league" and not league_data.get("branches", {}).has(location_id):
					return "散修盟分舵未登记：" + location_id
				if action == "tianji" and not location.has("shop"):
					return "天机榜亭须设在城中：" + location_id
				if action == "hunt" and not location.has("hunt"):
					return "可历练的地点缺少妖兽表：" + location_id
				if action == "arena" and not location.has("arena"):
					return "设擂的地点缺少擂台配置：" + location_id
		if location.has("field") and (not location.field is Dictionary or not location.field.get("name") is String or not location.field.get("mods") is Dictionary or location.field.mods.keys().any(func(element: Variant) -> bool: return not technique_data.elements.has(element))):
			return "地利配置无效：" + location_id
		if location.has("home") and not sects.has(location.home):
			return "地点的本门无效：" + location_id
		if location.has("arena"):
			var stage: Variant = location.arena
			if not stage is Dictionary or not stage.get("name") is String or not stage.get("kinds") is Array or stage.kinds.is_empty() or stage.kinds.any(func(kind: Variant) -> bool: return not population_data.kinds.has(kind)) or not _whole(stage.get("fee")) or not _whole(stage.get("purse")) or int(stage.purse) < 1:
				return "擂台配置无效：" + location_id
			for prize: Variant in stage.get("prizes", []):
				if not prize is Dictionary or not _whole(prize.get("streak")) or int(prize.streak) < 1 or (prize.has("manual") and (not _whole(prize.manual) or int(prize.manual) < 1 or int(prize.manual) > technique_data.tiers.size())) or (prize.has("equipment") and (not _whole(prize.equipment) or int(prize.equipment) < 1 or int(prize.equipment) > equipment_data.tiers.size())) or (prize.has("stones") and not _whole(prize.stones)) or not (prize.has("manual") or prize.has("equipment") or prize.has("stones")):
					return "擂台彩头无效：" + location_id
		if location.has("hunt"):
			var hunting: Variant = location.hunt
			if not hunting is Dictionary or not _whole(hunting.get("days")) or int(hunting.days) < 1 or not hunting.get("table") is Array or hunting.table.is_empty():
				return "历练配置无效：" + location_id
			for entry: Variant in hunting.table:
				if not entry is Dictionary or not enemies.has(entry.get("enemy", "")) or not _whole(entry.get("weight")) or int(entry.weight) < 1 or enemies[entry.enemy].has("world_flag"):
					return "历练的妖兽须是可反复遇到的已知对手：" + location_id
		if location.has("lease"):
			var lease: Variant = location.lease
			if not lease is Dictionary or not lease.get("flag") in world_flags or not lease.get("name") is String or not _whole(lease.get("days")) or int(lease.days) < 1 or not _whole(lease.get("price")) or int(lease.price) < 1:
				return "租约配置无效：" + location_id
			if not location.spots.any(func(spot: Dictionary) -> bool: return spot.get("requires_flag", "") == lease.flag):
				return "租约没有对应的住处场景：" + location_id
		for rule: Variant in location.get("rules", []):
			if not rule is Dictionary or not rule.get("forbid") in ["duel"] or not rule.get("text") is String:
				return "地方规矩配置无效：" + location_id
	# Every location must be reachable once everything is revealed; unhidden ones without any reveal.
	var everything := {}
	var seals := {}
	for location: Dictionary in locations.values():
		if location.has("sealed_if"):
			seals[location.sealed_if] = true
	for flag: String in world_flags:
		if not seals.has(flag):
			everything[flag] = true
	for location_id: String in locations:
		# A 秘境's place has no road: one is taken in while it is open (mijing.gd).
		if mijing_data.get("realms", {}).values().any(func(info: Variant) -> bool: return info is Dictionary and str(info.get("location", "")) == location_id):
			continue
		if find_path(map.start, location_id, everything).is_empty():
			return "地点无法到达：" + location_id
		if not location_visible(location_id, {}):
			continue
		if find_path(map.start, location_id, {}).is_empty():
			return "未解锁隐藏地点前无法到达：" + location_id
	return ""

## Hidden locations and gated spots need something in the content that sets their flag.
func _validate_reveals() -> String:
	var settable := {}
	for enemy: Dictionary in enemies.values():
		if enemy.has("world_flag"):
			settable[enemy.world_flag] = true
	var sources: Array = events.values() + people.values()
	for story: Dictionary in storylines.values():
		sources.append_array(story.steps)
	for definition: Dictionary in sources:
		var effects: Array = definition.get("effects", []).duplicate()
		for choice: Dictionary in definition.get("choices", []) + definition.get("interactions", []):
			effects.append_array(choice.get("effects", []))
		for effect: Dictionary in effects:
			if effect.has("flag"):
				settable[effect.flag] = true
	# A room that is a finding marks its flag when entered (caves.gd).
	for cave: Dictionary in cave_data.values():
		for room: Dictionary in cave.get("rooms", []):
			if room.has("flag"):
				settable[room.flag] = true
	# A dwelling's flag is set by taking its lease (leases.gd).
	for location: Dictionary in locations.values():
		if location.has("lease"):
			settable[location.lease.flag] = true
	# A 客卿's room opens while the bond lasts (guest.gd).
	for sect: String in guest_data.get("sects", {}):
		settable["guest_" + sect] = true
	# 天南散修盟's rooms open to its members (league.gd).
	settable["league_member"] = true
	# A 秘境 opens on its days and closes its story with its outcomes (mijing.gd).
	for info: Variant in mijing_data.get("realms", {}).values():
		if info is Dictionary:
			settable[str(info.get("open_flag", ""))] = true
			for outcome: Variant in info.get("outcomes", []):
				for effect: Variant in outcome.get("effects", []) if outcome is Dictionary else []:
					if effect is Dictionary and effect.has("flag"):
						settable[effect.flag] = true
	for location_id: String in locations:
		var location: Dictionary = locations[location_id]
		if location.has("hidden_until") and not settable.has(location.hidden_until):
			return "隐藏地点永远无法发现：" + location_id
		for spot: Dictionary in location.spots:
			if spot.has("requires_flag") and not settable.has(spot.requires_flag):
				return "场景永远无法开放：%s.%s" % [location_id, spot.id]
	return ""

# --- Map queries ----------------------------------------------------------------

func location_visible(location_id: String, flags: Dictionary) -> bool:
	var location: Dictionary = locations.get(location_id, {})
	return not location.is_empty() and (not location.has("hidden_until") or bool(flags.get(location.hidden_until, false)))

## The region a place is drawn in: its own, or the map's first.
func region_of(location_id: String) -> String:
	return str(locations.get(location_id, {}).get("region", map.get("region", "")))

func route_between(from_id: String, to_id: String) -> Dictionary:
	for route: Dictionary in routes:
		if from_id in route.between and to_id in route.between and from_id != to_id:
			return route
	return {}

## Whether a place is closed to anyone arriving (people already inside may still leave).
## A sealed place's `detour` must be a known place (people go there meanwhile).
func _valid_detours() -> String:
	for location_id: String in locations:
		var detour: Variant = locations[location_id].get("detour")
		if detour != null and (not detour is String or not locations.has(detour) or detour == location_id or not locations[location_id].has("sealed_if")):
			return "绕行地点无效：" + location_id
	return ""

func location_sealed(location_id: String, flags: Dictionary) -> bool:
	var location: Dictionary = locations.get(location_id, {})
	return location.has("sealed_if") and bool(flags.get(location.sealed_if, false))

## Places one road away. With `realm` at 0 or above, roads that ask a higher realm are left out.
func neighbors(location_id: String, flags: Dictionary, realm: int = -1) -> Array[String]:
	var result: Array[String] = []
	for route: Dictionary in routes:
		if realm >= 0 and int(route.get("realm", 0)) > realm:
			continue
		if location_id in route.between:
			var other: String = route.between[1] if route.between[0] == location_id else route.between[0]
			if location_visible(other, flags) and not location_sealed(other, flags):
				result.append(other)
	return result

## Shortest path by days over visible locations, including both ends; empty when unreachable.
## Ties prefer the lower total danger, then the alphabetical order of ids, so paths are stable.
## With `realm` at 0 or above, roads that ask a higher realm (a 传送阵 before foundation) are not taken.
func find_path(from_id: String, to_id: String, flags: Dictionary, realm: int = -1, mode: String = "fast") -> Array[String]:
	var empty: Array[String] = []
	if not location_visible(from_id, flags) or not location_visible(to_id, flags):
		return empty
	var best := {from_id: [0, 0, 0]}
	var previous := {}
	var open: Array[String] = [from_id]
	var done := {}
	while not open.is_empty():
		open.sort_custom(func(a: String, b: String) -> bool:
			return _path_less(best[a], best[b]) or (best[a] == best[b] and a < b))
		var current: String = open.pop_front()
		if done.has(current):
			continue
		done[current] = true
		if current == to_id:
			break
		for other: String in neighbors(current, flags, realm):
			var route := route_between(current, other)
			var edge := [int(route.get("fee", 0)), int(route.days), int(route.danger)] if mode == "cheap" else [int(route.days), int(route.danger), int(route.get("fee", 0))]
			var cost := [int(best[current][0]) + edge[0], int(best[current][1]) + edge[1], int(best[current][2]) + edge[2]]
			if not best.has(other) or _path_less(cost, best[other]):
				best[other] = cost
				previous[other] = current
				open.append(other)
	if not done.has(to_id):
		return empty
	var path: Array[String] = [to_id]
	while path[0] != from_id:
		path.push_front(previous[path[0]])
	return path

static func _path_less(a: Array, b: Array) -> bool:
	for index: int in 3:
		if a[index] != b[index]:
			return a[index] < b[index]
	return false

func path_days(path: Array[String]) -> int:
	var total := 0
	for index: int in range(1, path.size()):
		total += int(route_between(path[index - 1], path[index]).days)
	return total

## Actions offered by the spots at a location; gated spots appear once their flag is set and, for those
## kept for a sect rank, to whoever holds it (`rank`, the index of the player's).
func spot_actions(location_id: String, flags: Dictionary, rank: int = 0, affiliation: String = "") -> Array[String]:
	var result: Array[String] = []
	for spot: Dictionary in locations.get(location_id, {}).get("spots", []):
		if not spot_open(spot, flags, rank, affiliation):
			continue
		for action: String in spot.actions:
			result.append(action)
	return result

## A spot's flag, its sect (`requires_affiliation`: only that sect's own people go in) and the rank in
## it; `not_affiliation` is a spot for outsiders (the sect's recruiting gate).
func spot_open(spot: Dictionary, flags: Dictionary, rank: int, affiliation: String = "") -> bool:
	if spot.has("requires_flag") and not bool(flags.get(spot.requires_flag, false)):
		return false
	if spot.has("requires_affiliation") and affiliation != str(spot.requires_affiliation):
		return false
	if spot.has("not_affiliation") and affiliation == str(spot.not_affiliation):
		return false
	return not spot.has("requires_rank") or rank >= rank_index(str(spot.requires_rank))

## A sect rank's index by id (ids are shared by every sect), or -1.
func rank_index(rank_id: String) -> int:
	return sect_data.get("rank_ids", []).find(rank_id)

# --- Event static checks -----------------------------------------------------

func _validate_event(event_id: String, definition: Variant) -> String:
	if not definition is Dictionary:
		return "定义必须是对象"
	if not definition.get("title") is String or definition.title.is_empty():
		return "缺少标题"
	# Retired events never fire; they stay only so old chronicle entries keep their text.
	if definition.get("retired", false):
		return ""
	var trigger: Variant = definition.get("trigger")
	if trigger == "location":
		if not locations.has(definition.get("location", "")):
			return "未知地点"
		var venues: Variant = definition.get("periodic", {}).get("venues", [])
		if not venues is Array or venues.any(func(place: Variant) -> bool: return not locations.has(place)):
			return "轮办地点无效"
	elif trigger == "date":
		if not definition.has("window") and not definition.has("periodic"):
			return "日期事件必须有时间窗口或周期"
		if definition.has("choices") or definition.has("repeat"):
			return "日期事件不能带选项或冷却"
	elif trigger == "manual":
		# Raised by the rules themselves (心魔 at a breakthrough, fortune), never by place or date.
		if definition.has("location") or definition.has("window") or definition.has("periodic") or definition.has("repeat"):
			return "规则触发的事件不带地点或时间"
	elif trigger == "route":
		if not definition.get("routes") is Array or definition.routes.is_empty():
			return "途中事件需要路线"
		for pair: Variant in definition.routes:
			if not pair is Array or pair.size() != 2 or route_between(str(pair[0]), str(pair[1])).is_empty():
				return "途中事件引用了不存在的路线"
		if not _whole(definition.get("min_danger")) or int(definition.min_danger) >= DANGER_LEVELS:
			return "途中事件危险度无效"
		if not _whole(definition.get("weight")) or int(definition.weight) < 1:
			return "途中事件权重无效"
		if definition.has("window") or definition.has("periodic"):
			return "途中事件不使用时间窗口或周期"
		# People are met where the player stops, never forced on the road; road encounters are beasts and the like.
		if not definition.has("choices"):
			return "途中遭遇需要选项"
	else:
		return "未知触发方式"
	if definition.has("priority") and not _whole(definition.priority):
		return "优先级必须是非负整数"
	var timing := 0
	for key: String in ["window", "periodic", "repeat"]:
		if definition.has(key):
			timing += 1
	if timing > 1:
		return "时间窗口、周期与冷却只能选一种"
	if definition.has("window"):
		var window: Variant = definition.window
		if not window is Dictionary or not _valid_date(window.get("from")) or not _valid_date(window.get("to")):
			return "时间窗口日期无效"
		if _date_day(window.from) > _date_day(window.to):
			return "时间窗口起止颠倒"
	if definition.has("periodic"):
		var periodic: Variant = definition.periodic
		if not periodic is Dictionary:
			return "周期配置无效"
		for key: String in ["start_year", "every_years", "month", "from_day", "to_day"]:
			if not _whole(periodic.get(key)) or int(periodic[key]) < 1:
				return "周期字段无效：" + key
		if int(periodic.month) > 12 or int(periodic.to_day) > 30 or int(periodic.from_day) > int(periodic.to_day):
			return "周期日期无效"
	if definition.has("repeat"):
		if not definition.repeat is Dictionary or not _whole(definition.repeat.get("cooldown_days")) or int(definition.repeat.cooldown_days) < 1:
			return "冷却天数无效"
	var problem := _validate_conditions(definition.get("conditions", []))
	if problem.is_empty():
		problem = _validate_effects(definition.get("effects", []))
	if not problem.is_empty():
		return problem
	if definition.has("choices"):
		if not definition.get("text") is String or not definition.choices is Array or definition.choices.is_empty():
			return "抉择事件需要正文与选项"
		var ids := {}
		var always_open := false
		for choice: Variant in definition.choices:
			if not choice is Dictionary or not choice.get("id") is String or ids.has(choice.id):
				return "选项缺少唯一 ID"
			ids[choice.id] = true
			if not choice.get("label") is String or not choice.get("chronicle") is String:
				return "选项 %s 缺少文字" % choice.id
			# A choice that ends the life says so (`final`), and only such a choice ends it.
			var ends: bool = choice.get("effects", []).any(func(effect: Variant) -> bool: return effect is Dictionary and effect.has("end_life"))
			if ends != bool(choice.get("final", false)) or not choice.get("final", false) is bool:
				return "选项 %s：结束一生的选项须标明 final，标明 final 的须有 end_life" % choice.id
			problem = _validate_conditions(choice.get("conditions", []))
			if problem.is_empty():
				problem = _validate_effects(choice.get("effects", []))
			if not problem.is_empty():
				return "选项 %s：%s" % [choice.id, problem]
			if choice.get("conditions", []).is_empty():
				always_open = true
		# Otherwise the player could be stuck in front of an event with no allowed choice.
		if not always_open:
			return "至少需要一个无条件选项"
	elif not definition.get("chronicle") is String:
		return "缺少编年史文字"
	for part: String in ["remind", "expire"]:
		if not definition.has(part):
			continue
		if trigger != "location" or not definition.has("window"):
			return "%s 只用于有固定窗口的地点事件" % part
		if not definition[part] is Dictionary or not definition[part].get("chronicle") is String:
			return "%s 缺少文字" % part
		problem = _validate_conditions(definition[part].get("conditions", []))
		if not problem.is_empty():
			return problem
	# Key events gate important resources and must offer more than one way in.
	if definition.get("key", false) and _alternatives(definition.get("conditions", [])) < 2:
		return "关键事件至少需要两条入场途径"
	return ""

func _alternatives(conditions: Array) -> int:
	var best := 1 if not conditions.is_empty() else 0
	for condition: Dictionary in conditions:
		if condition.has("any"):
			best = maxi(best, condition.any.size())
	return best

func _validate_conditions(conditions: Variant) -> String:
	if not conditions is Array:
		return "条件必须是数组"
	for condition: Variant in conditions:
		var problem := _validate_condition(condition)
		if not problem.is_empty():
			return problem
	return ""

func _validate_condition(condition: Variant) -> String:
	if not condition is Dictionary or condition.size() != 1:
		return "每个条件只能有一个键"
	var key: String = condition.keys()[0]
	var value: Variant = condition[key]
	match key:
		"all", "any":
			if not value is Array or value.is_empty():
				return "%s 需要非空数组" % key
			return _validate_conditions(value)
		"not":
			return _validate_condition(value)
		"realm_at_least":
			return "" if _whole(value) and int(value) < realms.size() else "境界条件超出已开放境界"
		"grudge", "grudge_pay":
			return "" if value is bool else "%s 须为真假" % key
		"flag":
			return "" if value in world_flags else "未知世界标记：%s" % value
		"item_at_least":
			return "" if value is Array and value.size() == 2 and items.has(value[0]) and _whole(value[1]) else "物品条件无效"
		"stones_at_least", "herbs_at_least", "mind_at_least", "sense_at_least", "year_at_least":
			return "" if _whole(value) else "%s 数值无效" % key
		"trial_at_least":
			return "" if value is Array and value.size() == 3 and value[0] in ["jianya", "lilian", "tiannan", "wuzong"] and _whole(value[1]) and _whole(value[2]) and int(value[2]) >= 1 else "试炼条件无效"
		"met":
			return "" if people.has(value) else "未知人物：%s" % value
		"relation_at_least":
			return "" if value is Array and value.size() == 2 and people.has(value[0]) and (value[1] is int or value[1] is float) else "关系条件无效"
		"event_applied":
			return "" if value is String and events.has(value) else "事件发生条件无效"
		"event_state":
			if not value is Array or value.size() != 2 or not events.has(value[0]) or not value[1] in ["completed", "expired"]:
				return "事件状态条件无效"
			return ""
		"stage_at_least":
			if not value is Array or value.size() != 2 or not _whole(value[0]) or int(value[0]) >= realms.size() or not _whole(value[1]) or int(value[1]) >= realm(int(value[0])).stages.size():
				return "小阶段条件无效"
			return ""
		"sect":
			return "" if sects.has(value) else "未知门派：%s" % value
		"talked":
			return "" if people.has(value) else "未知人物：%s" % value
		"at_location":
			return "" if locations.has(value) else "未知地点：%s" % value
		"deed_at_least":
			return "" if value is Array and value.size() == 2 and value[0] is String and _known_deed(value[0]) and _whole(value[1]) else "事迹条件无效"
		"story_at":
			if not value is Array or value.size() != 2 or not storylines.has(value[0]) or not storylines[value[0]].steps.any(func(step: Dictionary) -> bool: return step.id == value[1]):
				return "剧情步骤条件无效"
			return ""
		"story_state":
			return "" if value is Array and value.size() == 2 and storylines.has(value[0]) and value[1] in STORY_STATES else "剧情状态条件无效"
		"talent":
			return "" if is_talent(value) else "未知天赋：%s" % value
		"rank_at_least":
			return "" if value in sect_data.get("rank_ids", []) else "未知宗门身份：%s" % value
		"recipe":
			return "" if alchemy_data.get("recipes", {}).has(value) else "未知丹方：%s" % value
		"month_day":
			return "" if value is Array and value.size() == 2 and _whole(value[0]) and _whole(value[1]) and int(value[0]) >= 1 and int(value[0]) <= int(value[1]) and int(value[1]) <= 30 else "月中日期条件无效"
		"affiliation":
			return "" if value is String and (value.is_empty() or sect_data.get("sects", {}).has(value)) else "未知宗门：%s" % value
		"holds_gear":
			return "" if value is String and not equipment(value).is_empty() else "宝物条件无效"
		"work_at_least":
			return "" if _whole(value) and int(value) >= 1 and int(value) <= technique_data.tiers.size() else "作品品阶条件无效"
		"guest":
			return "" if value is String and (value.is_empty() or guest_data.get("sects", {}).has(value)) else "客卿条件无效"
		"league":
			return "" if value in ["member", "deputy", "banned"] else "散修盟条件无效"
		"tianji":
			return "" if value is Array and value.size() == 2 and tianji_data.get("scrolls", {}).has(value[0]) and _whole(value[1]) and int(value[1]) >= 1 else "天骄榜条件无效"
		"rival":
			return "" if value in ["friend", "beaten", "elder_known"] else "宿敌条件无效"
		"present":
			return "" if people.has(value) else "未知人物：%s" % value
		"party":
			return "" if value is Array and value.size() == 2 and cave_data.get(str(value[0]), {}).get("companions", {}).has(str(value[1])) else "同行条件无效"
	return "未知条件：%s" % key

func _validate_effects(effects: Variant) -> String:
	if not effects is Array:
		return "效果必须是数组"
	for effect: Variant in effects:
		if not effect is Dictionary or effect.size() != 1:
			return "每个效果只能有一个键"
		var key: String = effect.keys()[0]
		var value: Variant = effect[key]
		var ok := false
		match key:
			"stones", "herbs", "pills", "xp", "mind", "contribution":
				ok = (value is int or value is float) and float(value) == floor(float(value))
			"item":
				ok = value is Array and value.size() == 2 and items.has(value[0]) and (value[1] is int or value[1] is float)
			"take_item":
				ok = items.has(value)
			"give_gear":
				ok = value is String and not equipment(value).is_empty()
			"flag":
				ok = value in world_flags
			"meet":
				ok = people.has(value)
			"relation":
				ok = value is Array and value.size() == 2 and people.has(value[0]) and (value[1] is int or value[1] is float)
			"battle":
				ok = enemies.has(value)
			"pack":
				ok = value is Array and not value.is_empty() and value.all(func(enemy_id: Variant) -> bool: return enemies.has(enemy_id))
			"series":
				ok = series.has(value)
			"grudge_fight", "grudge_pay", "grudge_evade", "bounty_fight", "bounty_wait", "bounty_drop", "mend_wound", "terms_search", "terms_press", "deadly":
				ok = value is bool and value
			"hp", "qi":
				ok = (value is int or value is float) and float(value) == floor(float(value))
			"leave":
				ok = value is bool and value
			"clear_flag":
				ok = value in world_flags
			"spar", "tournament", "breach":
				ok = value is bool and value
			"start_story", "story_advance":
				ok = storylines.has(value)
			"sound":
				ok = people.has(value)
			"manual":
				ok = _whole(value) and int(value) >= 1 and int(value) <= technique_data.tiers.size()
			"slip":
				ok = value is String and skills.has(value)
			"talent":
				ok = is_talent(value)
			"demon":
				ok = value in ["slay", "evade", "duel"]
			"fortune":
				ok = value in ["epiphany", "remnant", "humble_spring", "humble_echo", "humble_temper"]
			"recipe":
				ok = alchemy_data.get("recipes", {}).has(value)
			"auction":
				ok = auction_data.get("auctions", {}).has(value)
			"summit":
				ok = value is bool and value
			"contest":
				ok = value is String and summit_data.has(value) and value != "wuzong"
			"reset_cave":
				ok = cave_data.has(value)
			"mijing_open", "mijing_close":
				ok = mijing_data.get("realms", {}).has(value)
			"mijing_enter":
				ok = value is Array and value.size() == 2 and mijing_data.get("realms", {}).get(str(value[0]), {}).get("ways", {}).has(str(value[1]))
			"mijing":
				ok = value in ["fight", "share", "ally", "yield", "surrender", "leave", "decline", "rob_fight", "rob_pay"]
			"reforge":
				ok = value is Array and value.size() == 2 and not equipment(str(value[0])).is_empty() and not equipment(str(value[1])).is_empty()
			"guest_invite":
				ok = guest_data.get("sects", {}).has(value)
			"end_life":
				ok = value is String and not value.is_empty()
			"sect_rank":
				ok = value in sect_data.get("rank_ids", [])
			"league":
				ok = value in ["deputy", "ban"]
			"league_standing":
				ok = _whole(value) and int(value) >= 1
			"tianji":
				ok = value is Array and value.size() == 3 and tianji_data.get("scrolls", {}).has(value[0]) and _whole(value[1]) and int(value[1]) >= 1 and value[2] is String and not value[2].is_empty()
			"tianji_duel":
				ok = tianji_data.get("prodigies", {}).has(value)
			"tianji_defend":
				ok = value in ["fight", "refuse"]
			"rival":
				ok = value in ["enter", "poisoned", "face"]
			"close_sect":
				ok = value is Array and value.size() == 2 and sect_data.get("sects", {}).has(value[0]) and str(value[0]) != str(rules.lineage.home) and (str(value[1]).is_empty() or sect_data.sects.has(value[1])) and value[0] != value[1] and ("sect_closed_" + str(value[0])) in world_flags
			# "" sends whoever went along away (a companion who turned).
			"party":
				ok = value is Array and value.size() == 2 and cave_data.has(str(value[0])) and (str(value[1]).is_empty() or cave_data[value[0]].get("companions", {}).has(str(value[1])))
			"longevity":
				ok = value is Array and value.size() == 2 and value[0] is String and _whole(value[1]) and int(value[1]) >= 1
		if not ok:
			return "效果无效：%s" % key
	return ""

func _valid_date(value: Variant) -> bool:
	if not value is Array or value.size() != 3:
		return false
	for part: Variant in value:
		if not _whole(part) or int(part) < 1:
			return false
	return int(value[1]) <= 12 and int(value[2]) <= 30

func _date_day(value: Array) -> int:
	return (int(value[0]) - 1) * 360 + (int(value[1]) - 1) * 30 + int(value[2]) - 1

func _whole(value: Variant) -> bool:
	return (value is int or value is float) and is_finite(float(value)) and float(value) >= 0.0 and float(value) == floor(float(value))

func realm(index: int) -> Dictionary:
	return realms[clampi(index, 0, realms.size() - 1)]

func action_days(action_id: String) -> int:
	return int(actions.get(action_id, 0))

## A handwritten person, or one the session can resolve (the generated population); {} otherwise.
func person_named(person_id: String) -> Dictionary:
	if people.has(person_id):
		return people[person_id]
	if person_lookup.is_valid():
		return person_lookup.call(person_id)
	return {}

## Event ids by descending priority, then id. Cached; rebuilt if the event set changes size.
var _by_priority: Array[String] = []
var _by_priority_source := -1

func events_by_priority() -> Array[String]:
	if _by_priority_source != events.size():
		_by_priority_source = events.size()
		_by_priority.clear()
		for id: String in events:
			if not events[id].get("retired", false):
				_by_priority.append(id)
		_by_priority.sort_custom(func(a: String, b: String) -> bool:
			var pa := int(events[a].get("priority", 0))
			var pb := int(events[b].get("priority", 0))
			return pa > pb or (pa == pb and a < b))
	return _by_priority

# --- People ------------------------------------------------------------------------

# What a phase of someone's life (年表, people.gd) may change.
const PHASE_KEYS := ["standing", "realm_text", "title", "description", "home", "spot", "schedule", "talk", "affiliation", "present_if"]

func _valid_standing(standing: Variant) -> bool:
	return standing is Array and standing.size() == 2 and _whole(standing[0]) and int(standing[0]) < realms.size() and _whole(standing[1])

## Every place a handwritten person may live or pass through, over all their phases.
## Every place a handwritten person may be found, over all their phases (kept once worked out).
var _places_cache := {}

func person_places(person_id: String) -> Array:
	if _places_cache.has(person_id):
		return _places_cache[person_id]
	var person: Dictionary = people[person_id]
	var places := []
	for shape: Dictionary in [person] + person.get("phases", []):
		if shape.has("home"):
			places.append(shape.home)
		for stop: Dictionary in shape.get("schedule", []):
			places.append(stop.location)
	_places_cache[person_id] = places
	return places

func _validate_person(person: Variant) -> String:
	if not person is Dictionary:
		return "定义必须是对象"
	for key: String in ["name", "title", "realm_text", "affiliation", "personality", "description"]:
		if not person.get(key) is String or person[key].is_empty():
			return "缺少资料：" + key
	if not _whole(person.get("age")) or not ATTITUDES.has(person.get("attitude", "")):
		return "年龄或态度无效"
	if person.has("gender") and not person.gender in ["male", "female"]:
		return "性别无效"
	if person.has("home") == person.has("schedule"):
		return "必须二选一：常驻某地（home）或按行程走动（schedule）"
	if person.has("home"):
		if not locations.has(person.home):
			return "常驻地点未知"
		if person.has("spot") and not locations[person.home].spots.any(func(spot: Dictionary) -> bool: return spot.id == person.spot):
			return "常驻场景未知"
	else:
		if not person.schedule is Array or person.schedule.is_empty():
			return "行程不能为空"
		for stop: Variant in person.schedule:
			# "away" means outside the built regions (travellers who come and go).
			if not stop is Dictionary or not (locations.has(stop.get("location", "")) or stop.get("location", "") == "away") or not _whole(stop.get("days")) or int(stop.days) < 1:
				return "行程中有无效的一站"
		if person.has("offset") and not _whole(person.offset):
			return "行程偏移无效"
	if person.has("window"):
		var window: Variant = person.window
		if not window is Dictionary or not _valid_date(window.get("from")) or not _valid_date(window.get("to")) or _date_day(window.from) > _date_day(window.to):
			return "出现时段无效"
	var problem := _validate_conditions(person.get("present_if", []))
	if not problem.is_empty():
		return problem
	for key: String in ["talk_favor", "gift_favor", "leave_days", "sound_at"]:
		if person.has(key) and not _whole(person[key]):
			return "数值无效：" + key
	if person.has("congrats"):
		if not person.congrats is Dictionary:
			return "贺信必须是对象"
		for kind: Variant in person.congrats:
			if not kind in CONGRATS or not person.congrats[kind] is String:
				return "贺信无效：%s" % kind
	if person.has("standing") and not _valid_standing(person.standing):
		return "修为无效"
	# 年表: later lives of the same person, each from a year on (people.gd view).
	var last_year := 0
	for phase: Variant in person.get("phases", []):
		if not phase is Dictionary or not _whole(phase.get("year")) or int(phase.year) < maxi(1, last_year):
			return "年表须按年份排列"
		last_year = int(phase.year)
		for key: Variant in phase:
			if not key in PHASE_KEYS and not key in ["year", "if"]:
				return "年表中有未知的项：%s" % key
		if phase.has("home") and phase.has("schedule"):
			return "年表不能同时给出常驻与行程"
		var shown: Dictionary = person.duplicate()
		shown.merge(phase, true)
		if phase.has("home"):
			shown.erase("schedule")
		elif phase.has("schedule"):
			shown.erase("home")
		if shown.has("home"):
			if not locations.has(shown.home):
				return "年表中的常驻地点未知"
			if shown.has("spot") and not locations[shown.home].spots.any(func(spot: Dictionary) -> bool: return spot.id == shown.spot):
				return "年表中的常驻场景未知"
		if phase.has("standing") and not _valid_standing(phase.standing):
			return "年表中的修为无效"
		for key: String in ["realm_text", "title", "description", "affiliation"]:
			if phase.has(key) and (not phase[key] is String or phase[key].is_empty()):
				return "年表中的%s无效" % key
		if phase.has("talk") and (not phase.talk is Array or phase.talk.any(func(line: Variant) -> bool: return not line is String)):
			return "年表中的对话必须是文字列表"
		problem = _validate_conditions(phase.get("if", []))
		if problem.is_empty():
			problem = _validate_conditions(phase.get("present_if", []))
		if not problem.is_empty():
			return "年表：" + problem
	if person.has("talents") and (not person.talents is Array or person.talents.any(func(id: Variant) -> bool: return not is_talent(id))):
		return "天赋无效"
	if person.has("talk") and (not person.talk is Array or person.talk.any(func(line: Variant) -> bool: return not line is String)):
		return "对话必须是文字列表"
	if person.has("talk_variants"):
		if not person.talk_variants is Array:
			return "情境对话必须是数组"
		for variant: Variant in person.talk_variants:
			if not variant is Dictionary or not variant.get("lines") is Array or variant.lines.is_empty() or variant.lines.any(func(line: Variant) -> bool: return not line is String):
				return "情境对话缺少文字"
			problem = _validate_conditions(variant.get("conditions", []))
			if not problem.is_empty():
				return problem
	var ids := {}
	for interaction: Variant in person.get("interactions", []):
		if not interaction is Dictionary or not interaction.get("id") is String or ids.has(interaction.id) or interaction.id in BUILT_IN_INTERACTIONS:
			return "交互缺少唯一 ID"
		ids[interaction.id] = true
		if not interaction.get("label") is String or not interaction.get("chronicle") is String:
			return "交互 %s 缺少文字" % interaction.id
		if interaction.has("monthly_stock") and (not interaction.monthly_stock is String or str(interaction.monthly_stock).strip_edges().is_empty()):
			return "交互 %s 月度货品组无效" % interaction.id
		if interaction.has("cooldown_days") and not _whole(interaction.cooldown_days):
			return "交互 %s 冷却无效" % interaction.id
		problem = _validate_conditions(interaction.get("conditions", []))
		if problem.is_empty():
			problem = _validate_effects(interaction.get("effects", []))
		if not problem.is_empty():
			return "交互 %s：%s" % [interaction.id, problem]
	return ""

## Where a person would be on `day` by home or schedule, before presence conditions are applied.
## `person` is their profile as of that day (a phase may move them, people.gd); the data's by default.
func person_base_location(person_id: String, day: int, person: Dictionary = {}) -> String:
	if person.is_empty():
		person = people[person_id]
	if person.has("home"):
		return person.home
	if not person.has("_cycle"):
		var cycle := 0
		for stop: Dictionary in person.schedule:
			cycle += int(stop.days)
		person["_cycle"] = cycle
	var total := int(person._cycle)
	var position := (day + int(person.get("offset", 0))) % total
	for stop: Dictionary in person.schedule:
		position -= int(stop.days)
		if position < 0:
			return stop.location
	return person.schedule[0].location

func favor_stage(favor: int) -> String:
	var name: String = FAVOR_STAGES[0][1]
	for stage: Array in FAVOR_STAGES:
		if favor >= int(stage[0]):
			name = stage[1]
	return name

# --- Realms and stages ----------------------------------------------------------------

## The sub-stage reached with `xp` inside a realm (stages unlock by cumulative xp in that realm).
func stage_index(realm_index: int, xp: int) -> int:
	var stages: Array = realm(realm_index).stages
	var reached := 0
	for index: int in stages.size():
		if xp >= int(stages[index].xp):
			reached = index
	return reached

func stage(realm_index: int, stage_number: int) -> Dictionary:
	var stages: Array = realm(realm_index).stages
	return stages[clampi(stage_number, 0, stages.size() - 1)]

## e.g. "炼气初期".
func realm_title(realm_index: int, stage_number: int) -> String:
	return str(realm(realm_index).name) + str(stage(realm_index, stage_number).name)

## Spirit-root grade for a set of elements, e.g. {"name": "双灵根", "speed": 1.4}.
func root_grade(elements: Array) -> Dictionary:
	for grade: Dictionary in rules.spirit_roots.grades:
		if int(grade.count) == elements.size():
			return grade
	return {"name": "灵根", "speed": 1.0}

func root_title(elements: Array) -> String:
	var names := ""
	for element: String in rules.spirit_roots.elements:
		if element in elements:
			names += str(rules.spirit_roots.names[element])
	return names + str(root_grade(elements).name)

# --- Items ---------------------------------------------------------------------------

func _validate_item(item: Variant) -> String:
	if not item is Dictionary or not item.get("name") is String or not item.get("description") is String:
		return "缺少名称或描述"
	if not ITEM_CATEGORIES.has(item.get("category", "")):
		return "品类未知"
	if not _whole(item.get("price")):
		return "价格无效"
	if item.has("duel") and (not item.duel is Dictionary or item.duel.is_empty() or (item.duel.has("orbs") and (not _whole(item.duel.orbs) or int(item.duel.orbs) < 1)) or (item.duel.has("heal") and not item.duel.heal is bool) or ["damage", "shield"].any(func(key: String) -> bool: return item.duel.has(key) and (not _whole(item.duel[key]) or int(item.duel[key]) < 1)) or (item.duel.has("bind") and (not item.duel.bind is Array or item.duel.bind.size() != 2)) or (item.duel.has("escape") and not item.duel.escape is bool)):
		return "斗法中服用的配置无效"
	if item.has("rarity") and (not _whole(item.rarity) or int(item.rarity) >= talent_data.tiers.size()):
		return "品级无效"
	if item.has("toxin") and (not _whole(item.toxin) or int(item.toxin) < 1):
		return "丹毒无效"
	if item.has("breakthrough") and (not item.breakthrough is Dictionary or not _whole(item.breakthrough.get("bonus")) or not _whole(item.breakthrough.get("grade", 0))):
		return "突破之用无效"
	return _validate_effects(item.get("use", []))

## 品级, 0–5 for 白、绿、蓝、紫、橙、红 (the talents' colors): catalogue items name theirs (`rarity`);
## techniques, manuals and equipment follow their tier (凡阶 / 凡兵 white up to 天阶 / 灵宝 orange).
func rarity_of(entry: Dictionary) -> int:
	var top: int = talent_data.tiers.size() - 1
	if entry.has("rarity"):
		return clampi(int(entry.rarity), 0, top)
	if entry.has("tier"):
		return clampi(int(entry.tier) - 1, 0, top)
	return 0

func rarity_color(rarity: int) -> Color:
	return Color(str(talent_data.tiers[clampi(rarity, 0, talent_data.tiers.size() - 1)].color))

## The fine (上品) pill made beside a pill, or "".
func fine_pill(pill_id: String) -> String:
	if pill_id.is_empty():
		return ""
	for item_id: String in items:
		if str(items[item_id].get("fine_of", "")) == pill_id:
			return item_id
	return ""

## Herb ids from cheapest to dearest (then by id), the order generic herb costs are paid in.
func herbs_by_value() -> Array[String]:
	var ids: Array[String] = []
	for item_id: String in items:
		if items[item_id].category == "herb":
			ids.append(item_id)
	ids.sort_custom(func(a: String, b: String) -> bool:
		return int(items[a].price) < int(items[b].price) or (int(items[a].price) == int(items[b].price) and a < b))
	return ids

# --- Techniques, equipment, manuals ----------------------------------------------------

func technique(id: String) -> Dictionary:
	return Arsenal.technique(self, id)

func equipment(id: String) -> Dictionary:
	return Arsenal.equipment(self, id)

## Any item by id: catalogue items, generated equipment ("e:") and manuals ("j:"). {} when unknown.
func item(id: String) -> Dictionary:
	if items.has(id):
		return items[id]
	if id.begins_with("e:"):
		return equipment(id)
	if id.begins_with("j:"):
		return Arsenal.manual(self, id)
	return {}

func tier_layers(tier: int) -> Dictionary:
	return vfx_tiers[clampi(tier - 1, 0, vfx_tiers.size() - 1)]

## The sect whose signature layer an art shows when `sect_id`'s disciple casts it: one of that sect's
## own arts, or "" (wanderers have no lineage).
func legacy_sect(skill_id: String, sect_id: String) -> String:
	if sect_id == "wanderer" or not sects.has(sect_id) or not vfx_legacy.has(sect_id):
		return ""
	return sect_id if skill_id in sects[sect_id].skills else ""

func _validate_arsenal() -> String:
	var data := technique_data
	for key: String in ["tiers", "elements", "archetypes", "affixes"]:
		if not data.has(key):
			return "功法配置缺少：" + key
	if not data.tiers is Array or data.tiers.is_empty():
		return "功法品阶为空。"
	var previous_power := 0.0
	for tier: Variant in data.tiers:
		if not tier is Dictionary or not tier.get("name") is String or float(tier.get("power", 0)) <= previous_power or not _whole(tier.get("affixes")) or not _whole(tier.get("value")) or not _whole(tier.get("study_days")):
			return "功法品阶配置错误。"
		previous_power = float(tier.power)
	if not _whole(data.get("inheritance_tier")) or int(data.inheritance_tier) < 1 or int(data.inheritance_tier) > data.tiers.size():
		return "传承功法品阶无效。"
	for element: Variant in rules.spirit_roots.elements:
		if not data.elements.has(element) or data.elements[element].get("words", []).is_empty():
			return "功法缺少属性：%s" % element
	for archetype_id: String in data.archetypes:
		var archetype: Dictionary = data.archetypes[archetype_id]
		if not archetype.get("slot") in ["art", "method"] or archetype.get("nouns", []).is_empty():
			return "功法原型配置错误：" + archetype_id
		if archetype.slot == "art":
			if not archetype.get("kind") in ["attack", "heal", "guard"] or not _valid_cost(archetype.get("cost"), ["element", "same", "any"]) or (archetype.has("combo") and not _valid_combo(archetype.combo, ["source", "same"])):
				return "神通原型配置错误：" + archetype_id
			for element: String in data.elements:
				if not vfx_styles.has(archetype.get("vfx", {}).get(element, "")):
					return "神通原型缺少特效：%s.%s" % [archetype_id, element]
		elif not archetype.get("passive") is Dictionary or archetype.passive.is_empty():
			return "心法原型缺少效果：" + archetype_id
	for affix_id: String in data.affixes:
		var affix: Dictionary = data.affixes[affix_id]
		if not affix.get("name") is String or not affix.get("text") is String or not affix.get("applies") is Array or not affix.get("effect") is Dictionary:
			return "功法词条配置错误：" + affix_id
		for archetype_id: Variant in affix.applies:
			if not data.archetypes.has(archetype_id):
				return "功法词条引用了未知原型：" + affix_id
	for skill_id: String in skills:
		var skill: Dictionary = skills[skill_id]
		if not data.elements.has(skill.get("element", "")) and not data.get("neutral", {}).has(skill.get("element", "")):
			return "传承神通缺少属性：" + skill_id
		# A named 心法 (《藏息录》): its tier and its passive, nothing to cast.
		if str(skill.get("slot", "art")) == "method":
			if not _whole(skill.get("tier")) or int(skill.tier) < 1 or int(skill.tier) > data.tiers.size() or not skill.get("name") is String or not skill.get("description") is String:
				return "手写心法的品阶或文字无效：" + skill_id
			if not skill.get("passive") is Dictionary or skill.passive.is_empty() or skill.passive.keys().any(func(key: Variant) -> bool: return not key in ["cultivation", "max_hp", "max_qi", "dun_speed", "encounter", "element_damage", "orb_weight"]) or skill.passive.values().any(func(value: Variant) -> bool: return not (value is float or value is int)):
				return "手写心法的常驻效果无效：" + skill_id
			# 《照水分光诀》: two elements that answer each other as a 连击 (combat.gd linked_combo).
			var link: Variant = skill.get("link", {})
			if not link is Dictionary or (not link.is_empty() and (not link.get("elements") is Array or link.elements.size() != 2 or link.elements.any(func(element: Variant) -> bool: return not data.elements.has(element)) or not (link.get("bonus") is float or link.get("bonus") is int) or not _whole(link.get("absorb", 0)))):
				return "手写心法的连击相合无效：" + skill_id
			continue
		if not _valid_cost(skill.get("cost"), data.elements.keys() + ["same", "any"]):
			return "传承神通的灵气消耗无效：" + skill_id
		if not skill.get("kind") in ["attack", "heal", "guard", "spirit"]:
			return "传承神通的种类无效：" + skill_id
		if skill.has("combo") and not _valid_combo(skill.combo, data.elements.keys()):
			return "传承神通的连击无效：" + skill_id
		if skill.has("absorb") and (not skill.absorb is Array or skill.absorb.size() != 2 or not data.elements.has(skill.absorb[0]) or not _whole(skill.absorb[1]) or int(skill.absorb[1]) < 1):
			return "传承神通的吸收灵气无效：" + skill_id
		if skill.has("gather") and (not _whole(skill.gather) or int(skill.gather) < 1):
			return "传承神通的聚气无效：" + skill_id
		if ["through", "shatter"].any(func(key: String) -> bool: return skill.has(key) and not skill[key] is bool):
			return "传承神通的破盾配置无效：" + skill_id
		if skill.has("weapon") and str(equipment_data.get("bases", {}).get(str(skill.weapon), {}).get("art", "")) != skill_id:
			return "兵刃神通须由那种兵刃带出：" + skill_id
	var duel: Variant = rules.get("duel")
	if not duel is Dictionary or ["first_extra", "root_weight", "other_weight", "hand_least", "pills", "guard_orbs"].any(func(key: String) -> bool: return not _whole(duel.get(key))):
		return "斗法规则配置无效。"
	for key: String in ["draw", "foe_draw", "speed"]:
		if not duel.get(key) is Array or duel[key].size() != realms.size() or duel[key].any(func(value: Variant) -> bool: return not _whole(value) or int(value) < 1):
			return "斗法抽灵气数须按境界逐一给出：" + key
	var foe_weights: Variant = duel.get("foe_weights")
	if not foe_weights is Array or foe_weights.size() != 2 or foe_weights.any(func(value: Variant) -> bool: return not _whole(value)):
		return "对手抽灵气的权重无效。"
	var power: Variant = duel.get("realm_power")
	if not power is Array or power.size() != realms.size() or power.any(func(value: Variant) -> bool: return not (value is float or value is int) or float(value) <= 0.0):
		return "斗法境界威力须按境界逐一给出。"
	var cycle: Variant = duel.get("generates")
	if not cycle is Dictionary or cycle.size() != data.elements.size() or cycle.keys().any(func(element: Variant) -> bool: return not data.elements.has(element) or not data.elements.has(cycle[element]) or cycle[element] == element):
		return "五行相生配置无效。"
	var starter: Variant = duel.get("starter")
	if not starter is Dictionary or data.elements.keys().any(func(element: String) -> bool: return not starter.get(element) is Array or starter[element].any(func(id: Variant) -> bool: return not skills.has(id))):
		return "散修本命神通须按五行逐一给出。"
	for enemy_id: String in enemies:
		if not data.elements.has(enemies[enemy_id].get("element", "")):
			return "对手缺少五行属性：" + enemy_id
	var gear := equipment_data
	if not gear.get("tiers") is Array or gear.tiers.size() != data.tiers.size():
		return "装备品阶须与功法品阶一一对应。"
	for base_id: String in gear.get("bases", {}):
		var base: Dictionary = gear.bases[base_id]
		if not gear.slots.has(base.get("slot", "")) or not gear.materials.has(base.get("material", "")) or gear.materials[base.material].size() < gear.tiers.size() or base.get("nouns", []).is_empty():
			return "装备底材配置错误：" + base_id
		if base.has("release") and (not base.release is Dictionary or not base.release.get("name") is String or not (base.release.get("power") is float or base.release.get("power") is int) or float(base.release.power) <= 0.0 or base.get("slot") != "weapon"):
			return "兵刃祭出配置错误：" + base_id
		if base.has("named") and (not base.named is Dictionary or base.named.is_empty() or base.named.keys().any(func(key: Variant) -> bool: return not str(key).is_valid_int() or int(str(key)) < 1 or int(str(key)) > gear.tiers.size() or not base.named[key] is String)):
			return "有名宝物的阶段配置错误：" + base_id
		# A weapon's own art (枪、锤、鞭) names it back, and its 祭出 may go past or break a shield.
		if base.has("art") and (base.get("slot") != "weapon" or not skills.has(str(base.art)) or str(skills[str(base.art)].get("weapon", "")) != base_id):
			return "兵刃的本门神通须是只认这种兵刃的神通：" + base_id
		if base.has("lead") and (not base.lead is bool or base.get("slot") != "weapon"):
			return "兵刃先手配置错误：" + base_id
		if base.has("release") and (["through", "shatter", "interrupt"].any(func(key: String) -> bool: return base.release.has(key) and not base.release[key] is bool) or (base.release.has("hits") and (not _whole(base.release.hits) or int(base.release.hits) < 1))):
			return "兵刃祭出配置错误：" + base_id
		if base.has("trait") and (not base["trait"] is Dictionary or not base["trait"].get("kind") in ["heart_guard", "mirror"] or not base["trait"].get("name") is String or not base["trait"].get("text") is String):
			return "宝物特性配置错误：" + base_id
	# Tier effects must escalate on every measure, so a stronger art never looks weaker. Layers that
	# unlock at a tier (the charge, the rune circle, the zoom...) may stay level but never fall back.
	if vfx_tiers.size() != data.tiers.size():
		return "特效品阶须与功法品阶一一对应。"
	for index: int in range(1, vfx_tiers.size()):
		for key: String in vfx_tiers[0]:
			var now := float(vfx_tiers[index].get(key, 0))
			var before := float(vfx_tiers[index - 1].get(key, 0))
			if key in vfx_unlocks and now < before:
				return "特效第 %d 阶的 %s 低于上一阶。" % [index + 1, key]
			if not key in vfx_unlocks and now <= before:
				return "特效第 %d 阶的 %s 没有高于上一阶。" % [index + 1, key]
	for key: Variant in vfx_unlocks:
		if not vfx_tiers[0].has(key) or float(vfx_tiers.back().get(key, 0)) <= 0.0:
			return "特效层 %s 在任何品阶都不出现。" % str(key)
	for sect_id: String in sects:
		if sect_id != "wanderer" and not vfx_legacy.get(sect_id) is String:
			return "门派缺少传承特效：" + sect_id
	return ""

## Location-triggered events of one place, in priority order (cached with the priority list).
var _by_location := {}

func location_events(location_id: String) -> Array[String]:
	var ordered := events_by_priority()
	if _by_location.get("_size", -1) != ordered.size():
		_by_location = {"_size": ordered.size()}
	if not _by_location.has(location_id):
		var ids: Array[String] = []
		for event_id: String in ordered:
			if events[event_id].trigger == "location" and (events[event_id].location == location_id or location_id in events[event_id].get("periodic", {}).get("venues", [])):
				ids.append(event_id)
		_by_location[location_id] = ids
	return _by_location[location_id]

## Only dated events and fixed windows enter the time scheduler. Manual and location
## events are indexed separately so longer worlds do not rescan them every month.
var _scheduled_events: Array[String] = []
var _scheduled_source := -1

func scheduled_events() -> Array[String]:
	if _scheduled_source != events.size():
		_scheduled_source = events.size()
		_scheduled_events.clear()
		for event_id: String in events_by_priority():
			var event: Dictionary = events[event_id]
			if event.trigger == "date" or event.has("window"):
				_scheduled_events.append(event_id)
	return _scheduled_events
