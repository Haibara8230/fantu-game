extends RefCounted
## Techniques and equipment. Handwritten sect techniques live in world.json "skills"; generated ones
## are encoded entirely in their id, so saves store ids only and the pools are effectively unlimited:
##   technique  t:<archetype>:<element>:<tier>:<affix+affix>:<variant>
##   equipment  e:<base>:<tier>:<element|none>:<affix+affix>:<variant>
##   manual     j:<technique id>        (a jade slip that teaches the technique)
## Every function here is pure: the same id and data always give the same result.

static func technique_id(archetype: String, element: String, tier: int, affixes: Array, variant: int) -> String:
	var sorted := affixes.duplicate()
	sorted.sort()
	return "t:%s:%s:%d:%s:%d" % [archetype, element, tier, "+".join(sorted), variant]

static func equipment_id(base: String, tier: int, element: String, affixes: Array, variant: int) -> String:
	var sorted := affixes.duplicate()
	sorted.sort()
	return "e:%s:%d:%s:%s:%d" % [base, tier, element, "+".join(sorted), variant]

## Normalized technique, or {} when the id is unknown or malformed.
static func technique(content, id: String) -> Dictionary:
	if content.skills.has(id):
		return _handwritten(content, id)
	if not id.begins_with("t:"):
		return {}
	var parts := id.split(":")
	if parts.size() != 6:
		return {}
	var data: Dictionary = content.technique_data
	var archetype: Variant = data.archetypes.get(parts[1])
	var element: Variant = data.elements.get(parts[2])
	if not archetype is Dictionary or not element is Dictionary or not parts[3].is_valid_int() or not parts[5].is_valid_int():
		return {}
	var tier := int(parts[3])
	var variant := int(parts[5])
	if tier < 1 or tier > data.tiers.size() or variant < 0:
		return {}
	var affix_ids: Array = Array(parts[4].split("+", false))
	var effect := {}
	var affix_names: Array[String] = []
	var affix_texts: Array[String] = []
	for affix_id: String in affix_ids:
		var affix: Variant = data.affixes.get(affix_id)
		if not affix is Dictionary or not parts[1] in affix.applies or affix_ids.count(affix_id) != 1:
			return {}
		affix_names.append(affix.name)
		affix_texts.append(affix.text)
		for key: String in affix.effect:
			effect[key] = affix.effect[key]
	var tier_def: Dictionary = data.tiers[tier - 1]
	var power := float(tier_def.power)
	var words: Array = element.words
	var nouns: Array = archetype.nouns
	var result := {
		"id": id, "generated": true, "archetype": parts[1], "element": parts[2], "tier": tier, "tier_name": tier_def.name,
		"name": str(words[variant % words.size()]) + str(nouns[(variant / words.size()) % nouns.size()]),
		"slot": archetype.slot, "kind": archetype.kind, "affixes": affix_names, "affix_texts": affix_texts,
		"min_realm": int(tier_def.min_realm), "value": int(tier_def.value) + 20 * affix_ids.size(),
		"study_days": int(tier_def.study_days),
	}
	if archetype.slot == "art":
		result.qi_cost = int(round(float(archetype.qi) * float(effect.get("qi_scale", 1.0))))
		result.cooldown = maxi(0, int(archetype.cooldown) + int(effect.get("cooldown", 0)))
		result.vfx = archetype.vfx[parts[2]]
		if archetype.has("damage"):
			var scale := power * float(effect.get("damage_scale", 1.0)) * (1.0 + float(effect.get("pierce", 0.0)))
			result.damage_min = int(round(float(archetype.damage[0]) * scale))
			result.damage_max = int(round(float(archetype.damage[1]) * scale))
			result.hits = int(archetype.get("hits", 1)) + int(effect.get("hits", 0))
		if archetype.has("heal"):
			result.heal = int(round(float(archetype.heal) * power))
		for key: String in ["pierce", "lifesteal", "qi_gain"]:
			if effect.has(key):
				result[key] = effect[key]
		if effect.has("burn"):
			result.burn = [int(round(float(effect.burn[0]) * power)), int(effect.burn[1])]
		if effect.has("weaken"):
			result.weaken = effect.weaken.duplicate()
	else:
		var passive := {}
		var scale := power * float(effect.get("passive_scale", 1.0))
		for key: String in archetype.passive:
			passive[key] = _scaled(key, float(archetype.passive[key]) * scale)
		for key: String in ["max_hp", "max_qi"]:
			if effect.has(key):
				passive[key] = int(passive.get(key, 0)) + int(effect[key])
		result.passive = passive
	result.description = describe_technique(content, result)
	return result

static func _handwritten(content, id: String) -> Dictionary:
	var skill: Dictionary = content.skills[id]
	var tier := int(content.technique_data.inheritance_tier)
	var result := {
		"id": id, "generated": false, "element": skill.get("element", "metal"), "tier": tier,
		"tier_name": content.technique_data.tiers[tier - 1].name, "name": skill.name, "slot": "art", "kind": skill.kind,
		"affixes": [], "affix_texts": [], "min_realm": 0, "value": int(content.technique_data.tiers[tier - 1].value),
		"study_days": 0, "qi_cost": int(skill.qi_cost), "cooldown": int(skill.cooldown), "vfx": skill.vfx,
		"description": skill.description,
	}
	if skill.has("damage_min"):
		result.damage_min = int(skill.damage_min)
		result.damage_max = int(skill.damage_max)
		result.hits = int(skill.get("hits", 1))
	if skill.has("heal"):
		result.heal = int(skill.heal)
	return result

static func _scaled(key: String, value: float) -> Variant:
	return int(round(value)) if key in ["max_hp", "max_qi", "attack"] else snappedf(value, 0.001)

static func describe_technique(content, t: Dictionary) -> String:
	var lines: Array[String] = []
	var element_name: String = content.technique_data.elements[t.element].name
	if t.slot == "art":
		match str(t.kind):
			"attack":
				lines.append("%s属性，造成 %d–%d 点伤害%s。" % [element_name, t.damage_min, t.damage_max, "，分 %d 段命中" % t.hits if int(t.hits) > 1 else ""])
			"heal":
				lines.append("恢复 %d 点气血。" % t.heal)
			"guard":
				lines.append("恢复 %d 点气血，本回合所受伤害减半。" % t.heal)
		lines.append("消耗 %d 灵力，冷却 %d 回合。" % [t.qi_cost, t.cooldown])
	else:
		var names := {"cultivation": "修炼速度 +%d%%", "max_hp": "气血上限 +%d", "max_qi": "灵力上限 +%d", "element_damage": element_name + "属性伤害 +%d%%"}
		var parts: Array[String] = []
		for key: String in t.passive:
			var value: float = float(t.passive[key])
			parts.append(names[key] % int(round(value * 100.0 if key in ["cultivation", "element_damage"] else value)))
		lines.append("心法，常驻生效：" + "，".join(parts) + "。")
	for text: String in t.get("affix_texts", []):
		lines.append(text + "。")
	return "".join(lines)

## A random technique id of `tier`. Filters: "slot", "element", "archetype".
static func generate_technique(content, rng: RandomNumberGenerator, tier: int, filters: Dictionary = {}) -> String:
	var data: Dictionary = content.technique_data
	var archetypes: Array = data.archetypes.keys().filter(func(key: String) -> bool:
		return (not filters.has("slot") or data.archetypes[key].slot == filters.slot) and (not filters.has("archetype") or key == filters.archetype))
	archetypes.sort()
	var archetype: String = archetypes[rng.randi_range(0, archetypes.size() - 1)]
	var elements: Array = data.elements.keys()
	elements.sort()
	var element: String = filters.get("element", elements[rng.randi_range(0, elements.size() - 1)])
	var candidates: Array = data.affixes.keys().filter(func(key: String) -> bool: return archetype in data.affixes[key].applies)
	candidates.sort()
	var affixes := _pick(rng, candidates, int(data.tiers[tier - 1].affixes))
	return technique_id(archetype, element, tier, affixes, rng.randi_range(0, 24))

static func _pick(rng: RandomNumberGenerator, pool: Array, count: int) -> Array:
	var left := pool.duplicate()
	var chosen := []
	for index: int in mini(count, left.size()):
		chosen.append(left.pop_at(rng.randi_range(0, left.size() - 1)))
	return chosen

# --- Equipment ---------------------------------------------------------------------------

static func equipment(content, id: String) -> Dictionary:
	if not id.begins_with("e:"):
		return {}
	var parts := id.split(":")
	if parts.size() != 6 or not parts[2].is_valid_int() or not parts[5].is_valid_int():
		return {}
	var data: Dictionary = content.equipment_data
	var base: Variant = data.bases.get(parts[1])
	var tier := int(parts[2])
	var variant := int(parts[5])
	var element := parts[3]
	if not base is Dictionary or tier < 1 or tier > data.tiers.size() or variant < 0:
		return {}
	if element != "none" and not content.technique_data.elements.has(element):
		return {}
	var tier_def: Dictionary = data.tiers[tier - 1]
	var power := float(tier_def.power)
	var stats := {}
	for key: String in base.stats:
		stats[key] = float(base.stats[key]) * power
	var affix_ids: Array = Array(parts[4].split("+", false))
	var affix_names: Array[String] = []
	for affix_id: String in affix_ids:
		var affix: Variant = data.affixes.get(affix_id)
		if not affix is Dictionary or affix_ids.count(affix_id) != 1:
			return {}
		affix_names.append(affix.name)
		for key: String in affix.stats:
			stats[key] = float(stats.get(key, 0.0)) + float(affix.stats[key]) * power
	for key: String in stats.keys():
		stats[key] = _scaled(key, stats[key])
	var nouns: Array = base.nouns
	var material: String = data.materials[base.material][tier - 1]
	var prefix := ""
	if element != "none":
		var words: Array = content.technique_data.elements[element].words
		prefix = str(words[variant % words.size()])
	var result := {
		"id": id, "category": "equipment", "slot": base.slot, "tier": tier, "tier_name": tier_def.name, "element": element,
		"name": prefix + material + str(nouns[variant % nouns.size()]), "stats": stats, "affixes": affix_names,
		"price": int(tier_def.value) + 10 * affix_ids.size(),
	}
	result.description = describe_equipment(content, result)
	return result

static func describe_equipment(content, item: Dictionary) -> String:
	var names := {"attack": "攻击 +%d", "max_hp": "气血上限 +%d", "max_qi": "灵力上限 +%d", "defense": "受伤 -%d%%", "element_damage": "属性伤害 +%d%%", "cultivation": "修炼速度 +%d%%"}
	var parts: Array[String] = []
	var keys: Array = item.stats.keys()
	keys.sort()
	for key: String in keys:
		var value: float = float(item.stats[key])
		var shown := int(round(value * 100.0)) if key in ["defense", "element_damage", "cultivation"] else int(value)
		var text: String = names[key] % shown
		if key == "element_damage" and item.element != "none":
			text = content.technique_data.elements[item.element].name + text
		parts.append(text)
	var slot_name: String = content.equipment_data.slots[item.slot]
	return "%s · %s。%s%s" % [item.tier_name, slot_name, "，".join(parts), "。词条：" + "、".join(item.affixes) if not item.affixes.is_empty() else "。"]

static func generate_equipment(content, rng: RandomNumberGenerator, tier: int, slot: String = "") -> String:
	var data: Dictionary = content.equipment_data
	var bases: Array = data.bases.keys().filter(func(key: String) -> bool: return slot.is_empty() or data.bases[key].slot == slot)
	bases.sort()
	var base: String = bases[rng.randi_range(0, bases.size() - 1)]
	var elements: Array = content.technique_data.elements.keys()
	elements.sort()
	var element := "none" if rng.randf() < 0.5 else str(elements[rng.randi_range(0, elements.size() - 1)])
	var affixes: Array = data.affixes.keys()
	affixes.sort()
	return equipment_id(base, tier, element, _pick(rng, affixes, int(data.tiers[tier - 1].affixes)), rng.randi_range(0, 9))

# --- Manuals -------------------------------------------------------------------------------

static func manual(content, id: String) -> Dictionary:
	if not id.begins_with("j:"):
		return {}
	var taught := technique(content, id.substr(2))
	if taught.is_empty():
		return {}
	return {
		"id": id, "category": "manual", "teaches": taught.id, "tier": taught.tier,
		"name": "《%s》玉简" % taught.name, "price": int(taught.value) / 2,
		"description": "%s · %s。参悟 %d 日可习得。%s" % [taught.tier_name, "心法" if taught.slot == "method" else "神通", taught.study_days, taught.description],
	}
