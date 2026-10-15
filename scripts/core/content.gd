extends RefCounted
## Data definitions are separate from gameplay and presentation.
var locations: Dictionary = {}
var skills: Dictionary = {}
var enemies: Dictionary = {}
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
# 五宗论道's champions and rewards (summit.gd).
var summit_data: Dictionary = {}
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
const PLAIN_ACTIONS := ["cultivate", "rest", "breakthrough", "study", "teach", "sell", "shop", "gather", "inn_rest", "search_ruin", "explore_cave", "forge", "ascend", "inquire", "commissions", "sect", "alchemy", "field", "tournament", "lease", "hunt"]
const ITEM_CATEGORIES := {"herb": "灵草", "pill": "丹药", "treasure": "天材地宝", "manual": "玉简", "equipment": "宝物", "material": "材料", "recipe": "丹方", "tool": "器具", "quest": "信物"}
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
	for pair: Array in [["techniques", "res://data/techniques.json"], ["equipment", "res://data/equipment.json"], ["vfx_tiers", "res://data/vfx_tiers.json"], ["vfx", "res://data/vfx.json"], ["population", "res://data/population.json"], ["commissions", "res://data/commissions.json"], ["storylines", "res://data/storylines.json"], ["talents", "res://data/talents.json"], ["sect", "res://data/sect.json"], ["bonds", "res://data/bonds.json"], ["alchemy", "res://data/alchemy.json"], ["caves", "res://data/caves.json"], ["auctions", "res://data/auctions.json"], ["summit", "res://data/summit.json"], ["forge", "res://data/forge.json"], ["lore", "res://data/lore.json"]]:
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
	map = parsed.map
	regions = parsed.get("regions", {})
	locations = parsed.locations
	skills = parsed.skills
	enemies = parsed.enemies
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
		if breakthrough != null and (not breakthrough is Dictionary or not _whole(breakthrough.get("xp")) or not _whole(breakthrough.get("pills"))):
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
		problem = _validate_forge()
	if problem.is_empty():
		problem = _validate_lore()
	if problem.is_empty():
		problem = _validate_mastery()
	if problem.is_empty():
		problem = _validate_population()
	if problem.is_empty():
		problem = _validate_duties()
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
		if step is Dictionary and (not items.has(step.get("pill", "foundation_pill")) or (step.has("odds") and not _signed(step.odds))):
			return "突破所需丹药或难度无效：%s" % realm.get("id", "")
	for item_id: String in items:
		var used: Variant = items[item_id].get("breakthrough")
		if used is Dictionary and used.has("realm") and (not _whole(used.realm) or int(used.realm) < 1 or int(used.realm) >= realms.size()):
			return "天材地宝适用的境界无效：" + item_id
	var guard: Variant = r.get("guard")
	if not guard is Dictionary or not people.has(guard.get("mentor", "")) or not storylines.has(guard.get("mentor_story", "")) or not storylines[guard.mentor_story].steps.any(func(step: Dictionary) -> bool: return step.id == guard.get("mentor_step", "")) or not _whole(guard.get("favor")) or not _whole(guard.get("bonus")) or not _whole(guard.get("mentor_bonus")):
		return "护法配置无效。"
	var eye: Variant = r.get("eye")
	if not eye is Dictionary or not locations.has(eye.get("location", "")) or not eye.get("flag") in world_flags or not _whole(eye.get("bonus")):
		return "灵眼配置无效。"
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
	for id: String in ["epiphany", "brink", "shiru", "lingshen", "spirit_eye", "remnant"]:
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
	if not commission_data.get("boards", {}).has(data.get("board", "")):
		return "宗门告示配置无效。"
	if not data.get("ranks") is Array or data.ranks.is_empty():
		return "宗门身份配置无效。"
	var previous := -1
	for rank: Variant in data.ranks:
		if not rank is Dictionary or not rank.get("id") is String or not rank.get("name") is String or not _whole(rank.get("merit")) or int(rank.merit) < previous:
			return "宗门身份配置无效。"
		previous = int(rank.merit)
		if not rank.get("stage") is Array or rank.stage.size() != 2 or not _whole(rank.stage[0]) or int(rank.stage[0]) >= realms.size() or not _whole(rank.stage[1]):
			return "宗门身份的修为要求无效：%s" % rank.id
		for key: String in ["stipend", "retreat"]:
			if not _whole(rank.get(key)):
				return "宗门身份缺少：%s.%s" % [rank.id, key]
		if rank.has("host") and (not people.has(rank.host) or not rank.get("words") is String):
			return "宗门身份的主持人无效：%s" % rank.id
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
	var ids := {}
	for good: Variant in data.get("exchange", []):
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
		if good.has("rank") and not data.ranks.any(func(rank: Dictionary) -> bool: return rank.id == good.rank):
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

func _valid_cost(cost: Variant, keys: Array) -> bool:
	if not cost is Dictionary or cost.is_empty():
		return false
	var total := 0
	for key: Variant in cost:
		if not key in keys or not _whole(cost[key]) or int(cost[key]) < 1:
			return false
		total += int(cost[key])
	return total >= 1

## The duties of the inner court (sect.gd).
func _validate_duties() -> String:
	var duties: Variant = sect_data.get("duties")
	if not duties is Dictionary or rank_index(str(duties.get("rank", ""))) < 0 or not _whole(duties.get("change_days")) or not duties.get("list") is Dictionary or duties.list.is_empty():
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

# --- 五宗论道 --------------------------------------------------------------------------------------

func _validate_summit() -> String:
	var data := summit_data
	if not events.has(str(data.get("event", ""))):
		return "五宗论道的报名事件不存在。"
	var champions: Variant = data.get("champions")
	if not champions is Array or champions.is_empty():
		return "五宗论道没有对手。"
	for champion: Variant in champions:
		if not champion is Dictionary or not sects.has(champion.get("sect", "")) or not champion.get("name") is String or not champion.get("title") is String or not champion.get("gender") in ["male", "female"]:
			return "五宗论道的对手配置无效。"
	for key: String in ["levels", "power"]:
		if not data.get(key) is Array or data[key].size() != champions.size():
			return "五宗论道须按轮次给出：" + key
	if data.levels.any(func(level: Variant) -> bool: return not level is Array or level.size() != 2 or not _whole(level[0]) or int(level[0]) >= realms.size() or not _whole(level[1]) or int(level[1]) >= realms[int(level[0])].stages.size()):
		return "五宗论道的对手修为无效。"
	if not _whole(data.get("recover_percent")) or not data.get("round") is Dictionary or not data.get("champion") is Dictionary:
		return "五宗论道的奖赏配置无效。"
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
		if not locations[cave.location].spots.any(func(spot: Dictionary) -> bool: return "explore_cave" in spot.actions):
			return "洞府所在地点没有探索的场景：" + cave_id
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
					if not value is Array or value.size() != 2 or not items.has(value[0]) or not _whole(value[1]) or int(value[1]) < 1:
						return false
				"manual", "equipment":
					if not _whole(value) or int(value) < 1 or int(value) > technique_data.tiers.size():
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
			if not good is Dictionary or not items.has(good.get("item", "")) or not _whole(good.get("price")) or int(good.price) < 1:
				return "商店货品错误：" + location_id
		for category: Variant in location.get("buys", []):
			if not ITEM_CATEGORIES.has(category):
				return "收购品类未知：" + location_id
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
				if action == "hunt" and not location.has("hunt"):
					return "可历练的地点缺少妖兽表：" + location_id
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
	# A dwelling's flag is set by taking its lease (leases.gd).
	for location: Dictionary in locations.values():
		if location.has("lease"):
			settable[location.lease.flag] = true
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
func find_path(from_id: String, to_id: String, flags: Dictionary, realm: int = -1) -> Array[String]:
	var empty: Array[String] = []
	if not location_visible(from_id, flags) or not location_visible(to_id, flags):
		return empty
	var best := {from_id: [0, 0]}
	var previous := {}
	var open: Array[String] = [from_id]
	var done := {}
	while not open.is_empty():
		open.sort_custom(func(a: String, b: String) -> bool:
			return best[a][0] < best[b][0] or (best[a][0] == best[b][0] and (best[a][1] < best[b][1] or (best[a][1] == best[b][1] and a < b))))
		var current: String = open.pop_front()
		if done.has(current):
			continue
		done[current] = true
		if current == to_id:
			break
		for other: String in neighbors(current, flags, realm):
			var route := route_between(current, other)
			var cost := [int(best[current][0]) + int(route.days), int(best[current][1]) + int(route.danger)]
			if not best.has(other) or cost[0] < best[other][0] or (cost[0] == best[other][0] and cost[1] < best[other][1]):
				best[other] = cost
				previous[other] = current
				open.append(other)
	if not done.has(to_id):
		return empty
	var path: Array[String] = [to_id]
	while path[0] != from_id:
		path.push_front(previous[path[0]])
	return path

func path_days(path: Array[String]) -> int:
	var total := 0
	for index: int in range(1, path.size()):
		total += int(route_between(path[index - 1], path[index]).days)
	return total

## Actions offered by the spots at a location; gated spots appear once their flag is set and, for those
## kept for a sect rank, to whoever holds it (`rank`, the index of the player's).
func spot_actions(location_id: String, flags: Dictionary, rank: int = 0) -> Array[String]:
	var result: Array[String] = []
	for spot: Dictionary in locations.get(location_id, {}).get("spots", []):
		if not spot_open(spot, flags, rank):
			continue
		for action: String in spot.actions:
			result.append(action)
	return result

func spot_open(spot: Dictionary, flags: Dictionary, rank: int) -> bool:
	if spot.has("requires_flag") and not bool(flags.get(spot.requires_flag, false)):
		return false
	return not spot.has("requires_rank") or rank >= rank_index(str(spot.requires_rank))

## A sect rank's index by id, or -1.
func rank_index(rank_id: String) -> int:
	var ranks: Array = sect_data.get("ranks", [])
	for index: int in ranks.size():
		if ranks[index].id == rank_id:
			return index
	return -1

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
		"flag":
			return "" if value in world_flags else "未知世界标记：%s" % value
		"item_at_least":
			return "" if value is Array and value.size() == 2 and items.has(value[0]) and _whole(value[1]) else "物品条件无效"
		"stones_at_least", "herbs_at_least", "mind_at_least", "sense_at_least":
			return "" if _whole(value) else "%s 数值无效" % key
		"met":
			return "" if people.has(value) else "未知人物：%s" % value
		"relation_at_least":
			return "" if value is Array and value.size() == 2 and people.has(value[0]) and (value[1] is int or value[1] is float) else "关系条件无效"
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
			return "" if sect_data.get("ranks", []).any(func(rank: Dictionary) -> bool: return rank.id == value) else "未知宗门身份：%s" % value
		"recipe":
			return "" if alchemy_data.get("recipes", {}).has(value) else "未知丹方：%s" % value
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
			"flag":
				ok = value in world_flags
			"meet":
				ok = people.has(value)
			"relation":
				ok = value is Array and value.size() == 2 and people.has(value[0]) and (value[1] is int or value[1] is float)
			"battle":
				ok = enemies.has(value)
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
			"talent":
				ok = is_talent(value)
			"demon":
				ok = value in ["slay", "evade"]
			"fortune":
				ok = value in ["epiphany", "remnant"]
			"recipe":
				ok = alchemy_data.get("recipes", {}).has(value)
			"auction":
				ok = auction_data.get("auctions", {}).has(value)
			"summit":
				ok = value is bool and value
			"reset_cave":
				ok = cave_data.has(value)
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
	if person.has("standing") and (not person.standing is Array or person.standing.size() != 2 or not _whole(person.standing[0]) or int(person.standing[0]) >= realms.size() or not _whole(person.standing[1])):
		return "修为无效"
	if person.has("talents") and (not person.talents is Array or person.talents.any(func(id: Variant) -> bool: return not is_talent(id))):
		return "天赋无效"
	if person.has("talk") and (not person.talk is Array or person.talk.any(func(line: Variant) -> bool: return not line is String)):
		return "对话必须是文字列表"
	var ids := {}
	for interaction: Variant in person.get("interactions", []):
		if not interaction is Dictionary or not interaction.get("id") is String or ids.has(interaction.id) or interaction.id in BUILT_IN_INTERACTIONS:
			return "交互缺少唯一 ID"
		ids[interaction.id] = true
		if not interaction.get("label") is String or not interaction.get("chronicle") is String:
			return "交互 %s 缺少文字" % interaction.id
		if interaction.has("cooldown_days") and not _whole(interaction.cooldown_days):
			return "交互 %s 冷却无效" % interaction.id
		problem = _validate_conditions(interaction.get("conditions", []))
		if problem.is_empty():
			problem = _validate_effects(interaction.get("effects", []))
		if not problem.is_empty():
			return "交互 %s：%s" % [interaction.id, problem]
	return ""

## Where a person would be on `day` by home or schedule, before presence conditions are applied.
func person_base_location(person_id: String, day: int) -> String:
	var person: Dictionary = people[person_id]
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
	if item.has("duel") and (not item.duel is Dictionary or item.duel.is_empty() or (item.duel.has("orbs") and (not _whole(item.duel.orbs) or int(item.duel.orbs) < 1)) or (item.duel.has("heal") and not item.duel.heal is bool)):
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
			if not archetype.get("kind") in ["attack", "heal", "guard"] or not _valid_cost(archetype.get("cost"), ["element", "any"]):
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
		if not data.elements.has(skills[skill_id].get("element", "")):
			return "传承神通缺少属性：" + skill_id
		if not _valid_cost(skills[skill_id].get("cost"), data.elements.keys() + ["any"]):
			return "传承神通的灵气消耗无效：" + skill_id
	var duel: Variant = rules.get("duel")
	if not duel is Dictionary or ["first_extra", "root_weight", "other_weight", "qi_per_orb", "hand_least", "convert", "pills", "guard_orbs"].any(func(key: String) -> bool: return not _whole(duel.get(key))):
		return "斗法规则配置无效。"
	for key: String in ["draw", "foe_draw"]:
		if not duel.get(key) is Array or duel[key].size() != realms.size() or duel[key].any(func(value: Variant) -> bool: return not _whole(value) or int(value) < 1):
			return "斗法抽灵气数须按境界逐一给出：" + key
	for key: String in ["generates", "overcomes"]:
		var cycle: Variant = duel.get(key)
		if not cycle is Dictionary or cycle.size() != data.elements.size() or cycle.keys().any(func(element: Variant) -> bool: return not data.elements.has(element) or not data.elements.has(cycle[element]) or cycle[element] == element):
			return "五行%s配置无效。" % ("相生" if key == "generates" else "相克")
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
			if events[event_id].trigger == "location" and events[event_id].location == location_id:
				ids.append(event_id)
		_by_location[location_id] = ids
	return _by_location[location_id]
