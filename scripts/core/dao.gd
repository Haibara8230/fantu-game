extends RefCounted
## Independent understanding, insight and node allocation. No UI, filesystem or random draws.
const LIMIT := 150000
const KINDS := ["element_guard", "combo_damage", "element_draw", "combo_gather", "element_master", "orb_cap", "opening_draw", "attack_heal", "orb_draw", "max_hp", "first_hit_cut", "damage_cut", "sense", "sword_guard", "sword_damage", "sword_shield", "sword_scale", "sword_shatter", "array_drive", "array_gather", "gather_scale", "toxin_cut", "brew_scale", "forge_speed", "sigil_vermilion", "sigil_tiger"]

static func catalogue(content) -> Dictionary:
	if not content.dao_nodes.is_empty():
		return content.dao_nodes
	var nodes: Dictionary = content.dao_data.get("nodes", {}).duplicate(true)
	for path: String in ["metal", "wood", "water", "fire", "earth"]:
		for key: String in content.dao_data.get("element_nodes", {}):
			var node: Dictionary = content.dao_data.element_nodes[key].duplicate(true)
			node.path = path
			if key != "chain":
				node.name += str(content.dao_data.paths[path])
			nodes[path + "_" + key] = node
	content.dao_nodes = nodes
	return nodes

static func paths_for(art: Dictionary) -> Array[String]:
	var paths: Array[String] = []
	var element := str(art.get("element", "none"))
	paths.append(element if element != "none" else "qi")
	var archetype := str(art.get("archetype", ""))
	if is_sword(art):
		paths.append("sword")
	elif archetype == "body":
		paths.append("body")
	elif archetype == "focus":
		paths.append("spirit")
	return paths

static func is_sword(art: Dictionary) -> bool:
	return str(art.get("vfx", "")).begins_with("sword")

static func initial(s) -> Dictionary:
	var xp := {}
	for id: String in s.player.get("learned", []):
		var art: Dictionary = s.content.technique(id)
		var amount := int(art.get("tier", 1)) * int(s.content.dao_data.learning.xp_per_tier)
		for path: String in paths_for(art):
			xp[path] = mini(LIMIT, int(xp.get(path, 0)) + amount)
	return {"xp": xp, "nodes": [], "pending": {}, "debates": {}, "debate_xp": 0}

static func state(s) -> Dictionary:
	return s.player.dao if s.player.has("dao") else initial(s)

static func ensure(s) -> Dictionary:
	if not s.player.has("dao"):
		s.player.dao = initial(s)
	return s.player.dao

static func level(content, xp: int) -> int:
	var count := 0
	for stage: Dictionary in content.dao_data.stages:
		if xp >= int(stage.xp):
			count += 1
	return count

static func stage_of(s, path: String) -> int:
	return level(s.content, int(state(s).xp.get(path, 0)))

static func earned(s) -> int:
	return earned_for(s.content, s.player, state(s))

static func earned_for(content, player: Dictionary, current: Dictionary) -> int:
	# Restore checks dao before validating talent arrays. Never trust their saved types here.
	var talents: Variant = player.get("talents", [])
	var flaws: Variant = player.get("flaws", [])
	var mods := preload("res://scripts/core/talents.gd").sum(content, talents + flaws) if talents is Array and flaws is Array else {}
	var total := 2 + int(mods.get("dao_realm", 0)) * int(player.get("realm", 0))
	for realm: int in mini(int(player.get("realm", 0)), content.realms.size()):
		total += (realm + 1) * content.realms[realm].stages.size()
	total += (int(player.get("realm", 0)) + 1) * int(player.get("stage", 0))
	total += int(current.get("debate_xp", 0)) / int(content.dao_data.debate.point_every)
	for path: String in content.dao_data.paths:
		if level(content, int(current.xp.get(path, 0))) >= 3:
			total += 1
	return total

static func points(s) -> int:
	var total := earned(s)
	var nodes := catalogue(s.content)
	for id: String in state(s).nodes:
		total -= int(nodes[id].cost)
	return total

static func gain(s, path: String, amount: int, pending: bool = false) -> void:
	if not s.content.dao_data.paths.has(path) or amount <= 0:
		return
	var current := ensure(s)
	var target: Dictionary = current.pending if pending else current.xp
	target[path] = mini(LIMIT, int(target.get(path, 0)) + amount)

static func after_learning(s, art: Dictionary, layer: bool = false) -> void:
	# Bootstrap before the new art is appended; old saves then receive their existing understanding once.
	ensure(s)
	var amount := int(s.content.dao_data.learning.layer_xp) if layer else int(art.tier) * int(s.content.dao_data.learning.xp_per_tier)
	for path: String in paths_for(art):
		gain(s, path, amount)

static func learning_block(s, art: Dictionary) -> String:
	var required := int(s.content.dao_data.learning.required_stage_by_tier[clampi(int(art.tier) - 1, 0, 4)])
	for path: String in paths_for(art):
		if stage_of(s, path) < required:
			return "需要%s道达到%s。" % [s.content.dao_data.paths[path], s.content.dao_data.stages[required - 1].name]
	return ""

static func pick_block(s, id: String) -> String:
	var nodes := catalogue(s.content)
	if not nodes.has(id):
		return "没有这项悟道。"
	if not s.blocked().is_empty():
		return s.blocked()
	if id in state(s).nodes:
		return "已领悟此项。"
	var node: Dictionary = nodes[id]
	if stage_of(s, str(node.path)) < int(node.stage):
		return "道境未达%s。" % s.content.dao_data.stages[int(node.stage) - 1].name
	if not prerequisite(nodes, state(s).nodes, node):
		return "需先领悟同一道的前层节点。"
	if points(s) < int(node.cost):
		return "悟道点不足。"
	return ""

static func pick(s, id: String) -> String:
	var reason := pick_block(s, id)
	if not reason.is_empty():
		return reason
	ensure(s).nodes.append(id)
	s.refresh_realm_stats()
	return s.finish(s.log_event("dao_pick", {"dao_name": catalogue(s.content)[id].name}))

static func forget(s, id: String) -> String:
	var nodes := catalogue(s.content)
	if not s.blocked().is_empty():
		return s.blocked()
	if not id in state(s).nodes or not nodes.has(id):
		return "尚未领悟。"
	if not bool(nodes[id].get("forget", true)):
		return "此项领悟不可遗忘。"
	var rest: Array = state(s).nodes.duplicate()
	rest.erase(id)
	for other: String in rest:
		if not prerequisite(nodes, rest, nodes[other]):
			return "先遗忘依赖它的后层节点。"
	ensure(s).nodes = rest
	s.refresh_realm_stats()
	return s.finish(s.log_event("dao_forget", {"dao_name": nodes[id].name}))

static func value(s, kind: String, path: String = "") -> float:
	return value_for(s.content, state(s), kind, path)

## Sparse paths may skip empty columns, but never an existing preceding stage.
static func prerequisite(nodes: Dictionary, picked: Array, node: Dictionary) -> bool:
	var previous := 0
	for other: Dictionary in nodes.values():
		if other.path == node.path and int(other.stage) < int(node.stage):
			previous = maxi(previous, int(other.stage))
	return previous == 0 or picked.any(func(id: Variant) -> bool: return nodes.has(id) and nodes[id].path == node.path and int(nodes[id].stage) == previous)

static func value_for(content, current: Dictionary, kind: String, path: String = "") -> float:
	var total := 0.0
	var nodes := catalogue(content)
	for id: String in current.get("nodes", []):
		var node: Dictionary = nodes[id]
		if node.kind == kind and (path.is_empty() or node.path == path):
			total += float(node.value)
	return total

static func reflect(s, path: String, days: int = 30) -> String:
	if not s.content.dao_data.paths.has(path) or days < 1 or days > 360:
		return "感悟选择无效。"
	if not s.blocked().is_empty():
		return s.blocked()
	var reason: String = s.Layers.seclusion_block(s, days)
	if not reason.is_empty():
		return reason
	var amount := mini(int(state(s).pending.get(path, 0)), days * int(s.content.dao_data.reflection.xp_per_day))
	amount = mini(amount, LIMIT - int(state(s).xp.get(path, 0)))
	if amount <= 0 or stage_of(s, path) >= 5:
		return "此道暂无可吸收的感悟。"
	var passed: Dictionary = s.advance_days(days)
	s.Cultivation.pay_rent(s, int(passed.elapsed))
	if not s.ended.is_empty():
		return s.conclude("", passed)
	amount = mini(amount, int(passed.elapsed) * int(s.content.dao_data.reflection.xp_per_day))
	ensure(s).pending[path] = int(state(s).pending.get(path, 0)) - amount
	gain(s, path, amount)
	return s.conclude(s.log_event("dao_reflect", {"dao_name": s.content.dao_data.paths[path], "amount": amount}), passed)

static func debate_block(s, person_id: String) -> String:
	if not s.is_person(person_id) or s.npc_location(person_id) != str(s.player.location):
		return "道友不在此地。"
	if not s.blocked().is_empty():
		return s.blocked()
	if s.favor(person_id) < int(s.content.dao_data.debate.favor):
		return "尚不熟悉，难以坐而论道。"
	var last := int(state(s).debates.get(person_id, -100000))
	if int(s.world.day) - last < int(s.content.dao_data.debate.cooldown):
		return "近期已与这位道友论过道。"
	return ""

static func debate(s, person_id: String) -> String:
	var reason := debate_block(s, person_id)
	if not reason.is_empty():
		return reason
	var someone: Dictionary = s.person(person_id)
	var element := str(s.content.sects.get(str(someone.get("sect", "qingyun")), {}).get("element", "qi"))
	if not s.content.dao_data.paths.has(element):
		element = "qi"
	var passed: Dictionary = s.advance_days(int(s.content.dao_data.debate.days))
	if not s.ended.is_empty():
		return s.conclude("", passed)
	var current := ensure(s)
	current.debates[person_id] = int(s.world.day)
	var amount := int(s.content.dao_data.debate.xp) * (int(someone.get("realm", 0)) + 1)
	current.debate_xp = mini(1000000, int(current.debate_xp) + amount)
	gain(s, element, amount, true)
	gain(s, "qi", amount / 2, true)
	return s.conclude(s.log_event("dao_debate", {"npc": person_id, "dao_name": s.content.dao_data.paths[element], "amount": amount}), passed)

static func valid_data(content) -> bool:
	var data: Dictionary = content.dao_data
	if not data.get("stages") is Array or data.stages.size() != 5 or not data.get("paths") is Dictionary or data.paths.size() != 12 or not data.get("nodes") is Dictionary or not data.get("element_nodes") is Dictionary:
		return false
	var previous := 0
	for stage: Variant in data.stages:
		if not stage is Dictionary or not stage.get("name") is String or not _whole(stage.get("xp"), LIMIT) or int(stage.xp) <= previous:
			return false
		previous = int(stage.xp)
	for key: String in ["learning", "reflection", "debate"]:
		if not data.get(key) is Dictionary:
			return false
	for key: String in ["xp_per_day"]:
		if not data.reflection.has(key):
			return false
	for key: String in ["days", "xp", "point_every", "favor", "cooldown"]:
		if not data.debate.has(key):
			return false
	for key: String in ["xp_per_tier", "layer_xp"]:
		if not _whole(data.learning.get(key), LIMIT) or int(data.learning[key]) <= 0:
			return false
	var requirements: Variant = data.learning.get("required_stage_by_tier")
	if not requirements is Array or requirements.size() != 5 or requirements.any(func(x: Variant) -> bool: return not _whole(x, 5)):
		return false
	for group: Dictionary in [data.reflection, data.debate]:
		if group.values().any(func(x: Variant) -> bool: return not _whole(x, LIMIT) or int(x) <= 0):
			return false
	content.dao_nodes.clear()
	for rule: Variant in data.nodes.values():
		if not rule is Dictionary or not data.paths.has(rule.get("path", "")):
			return false
	for rule: Variant in data.nodes.values() + data.element_nodes.values():
		if not rule is Dictionary or not rule.get("name") is String or not rule.get("text") is String or not rule.get("kind") in KINDS or not _whole(rule.get("stage"), 5) or int(rule.stage) < 1 or not _whole(rule.get("cost"), 20) or int(rule.cost) < 1 or not rule.get("forget", true) is bool:
			return false
		var value: Variant = rule.get("value")
		if not (value is int or value is float) or not is_finite(float(value)) or float(value) <= 0 or float(value) > 10000:
			return false
		if rule.has("path") and not data.paths.has(rule.path):
			return false
	return true

static func _whole(value: Variant, cap: int) -> bool:
	return (value is int or value is float) and is_finite(float(value)) and float(value) == floor(float(value)) and float(value) >= 0 and float(value) <= cap

static func valid_state(content, player: Dictionary, day: int) -> bool:
	if not player.has("dao"):
		return true
	var current: Variant = player.dao
	if not current is Dictionary or current.keys().any(func(key: Variant) -> bool: return not key in ["xp", "nodes", "pending", "debates", "debate_xp"]) or not _whole(current.get("debate_xp"), 1000000):
		return false
	for key: String in ["xp", "pending"]:
		var values: Variant = current.get(key)
		if not values is Dictionary or values.keys().any(func(path: Variant) -> bool: return not content.dao_data.paths.has(path) or not _whole(values[path], LIMIT)):
			return false
	var debates: Variant = current.get("debates")
	if not debates is Dictionary or debates.size() > 2000 or debates.keys().any(func(id: Variant) -> bool: return not id is String or not _whole(debates[id], day)):
		return false
	var nodes := catalogue(content)
	var picked: Variant = current.get("nodes")
	if not picked is Array or picked.size() > nodes.size():
		return false
	var spent := 0
	for id: Variant in picked:
		if not id is String or not nodes.has(id) or picked.count(id) != 1:
			return false
		var node: Dictionary = nodes[id]
		if level(content, int(current.xp.get(node.path, 0))) < int(node.stage):
			return false
		if not prerequisite(nodes, picked, node):
			return false
		spent += int(node.cost)
	return spent <= earned_for(content, player, current)
