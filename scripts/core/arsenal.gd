extends RefCounted
## Techniques and equipment. Handwritten sect techniques live in world.json "skills"; generated ones
## are encoded entirely in their id, so saves store ids only and the pools are effectively unlimited:
##   technique  t:<archetype>:<element>:<tier>:<affix+affix>:<variant>
##   equipment  e:<base>:<tier>:<element|none>:<affix+affix>:<variant>
##   manual     j:<technique id>        (a jade slip that teaches the technique)
## Every function here is pure: the same id and data always give the same result.
## A technique is read at a layer (功法层数, layers.gd): 0 means fully cultivated. A lower layer gives a
## share of the tier's power and only the affixes unlocked by then; the cost stays the same.

static func technique_id(archetype: String, element: String, tier: int, affixes: Array, variant: int) -> String:
	var sorted := affixes.duplicate()
	sorted.sort()
	return "t:%s:%s:%d:%s:%d" % [archetype, element, tier, "+".join(sorted), variant]

static func equipment_id(base: String, tier: int, element: String, affixes: Array, variant: int) -> String:
	var sorted := affixes.duplicate()
	sorted.sort()
	return "e:%s:%d:%s:%s:%d" % [base, tier, element, "+".join(sorted), variant]

## Normalized technique at `layer` (0: all of them), or {} when the id is unknown or malformed.
static func technique(content, id: String, layer: int = 0) -> Dictionary:
	if content.skills.has(id):
		return _handwritten(content, id, layer)
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
	for affix_id: String in affix_ids:
		var affix: Variant = data.affixes.get(affix_id)
		if not affix is Dictionary or not parts[1] in affix.applies or affix_ids.count(affix_id) != 1:
			return {}
	# Affixes unlock in the order they are defined in the data, never by their ids' spelling.
	var ordered: Array = data.affixes.keys().filter(func(key: String) -> bool: return key in affix_ids)
	var tier_def: Dictionary = data.tiers[tier - 1]
	var layers := int(tier_def.layers)
	var at := layers if layer <= 0 else clampi(layer, 1, layers)
	var effect := {}
	var affix_names: Array[String] = []
	var affix_texts: Array[String] = []
	var affix_unlocks: Array[int] = []
	for index: int in ordered.size():
		var affix: Dictionary = data.affixes[ordered[index]]
		var unlock := unlock_layer(tier_def, index)
		affix_names.append(affix.name)
		affix_texts.append(affix.text)
		affix_unlocks.append(unlock)
		if unlock <= at:
			for key: String in affix.effect:
				effect[key] = affix.effect[key]
	var power := float(tier_def.power) * layer_share(content, at, layers)
	var words: Array = element.words
	var nouns: Array = archetype.nouns
	var result := {
		"id": id, "generated": true, "archetype": parts[1], "element": parts[2], "tier": tier, "tier_name": tier_def.name,
		"name": str(words[variant % words.size()]) + str(nouns[(variant / words.size()) % nouns.size()]),
		"slot": archetype.slot, "kind": archetype.kind, "affixes": affix_names, "affix_texts": affix_texts,
		"min_realm": int(tier_def.min_realm), "value": int(tier_def.value) + 20 * affix_ids.size(),
		"study_days": int(tier_def.study_days), "layer": at, "layers": layers, "affix_unlocks": affix_unlocks,
	}
	if archetype.slot == "art":
		result.cost = _cost(archetype.cost, parts[2], int(effect.get("thrift", 0)))
		result.vfx = archetype.vfx[parts[2]]
		if archetype.has("damage"):
			var scale := power * float(effect.get("damage_scale", 1.0)) * (1.0 + float(effect.get("pierce", 0.0)))
			result.damage_min = int(round(float(archetype.damage[0]) * scale))
			result.damage_max = int(round(float(archetype.damage[1]) * scale))
			result.hits = int(archetype.get("hits", 1)) + int(effect.get("hits", 0))
		if archetype.has("heal"):
			result.heal = int(round(float(archetype.heal) * power))
		if archetype.has("shield"):
			result.shield = int(round(float(archetype.shield) * power))
		for key: String in ["pierce", "lifesteal", "draw", "renew"]:
			if effect.has(key):
				result[key] = effect[key]
		if archetype.has("combo"):
			result.combo = _combo(content, archetype.combo, parts[2])
		if effect.has("burn"):
			result.burn = [int(round(float(effect.burn[0]) * power)), int(effect.burn[1])]
		for lingering: String in ["weaken", "sunder", "slow"]:
			if effect.has(lingering):
				result[lingering] = effect[lingering].duplicate()
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
	# A 心法 of a school's kind teaches its way of fighting (schools.gd).
	if archetype.slot == "method":
		for school_id: String in content.technique_data.get("schools", {}):
			var school: Dictionary = content.technique_data.schools[school_id]
			if str(school.archetype) == parts[1] and tier >= int(school.min_tier) and (not school.has("element") or str(school.element) == parts[2]):
				result.description += "流派 · %s：%s" % [school.name, school.text]
				break
	return result

## A sect's handwritten art: its own numbers at full layers, the inheritance tier's layers.
static func _handwritten(content, id: String, layer: int = 0) -> Dictionary:
	var skill: Dictionary = content.skills[id]
	if str(skill.get("slot", "art")) == "method":
		return _handwritten_method(content, id, layer)
	var tier := int(content.technique_data.inheritance_tier)
	var layers := int(content.technique_data.tiers[tier - 1].layers)
	var at := layers if layer <= 0 else clampi(layer, 1, layers)
	var share := layer_share(content, at, layers)
	var result := {
		"id": id, "generated": false, "element": skill.get("element", "metal"), "tier": tier,
		"tier_name": content.technique_data.tiers[tier - 1].name, "name": skill.name, "slot": "art", "kind": skill.kind,
		"affixes": [], "affix_texts": [], "affix_unlocks": [], "min_realm": 0, "value": int(content.technique_data.tiers[tier - 1].value),
		"study_days": 0, "cost": skill.cost.duplicate(), "vfx": skill.vfx, "layer": at, "layers": layers,
	}
	if skill.has("damage_min"):
		result.damage_min = maxi(1, int(round(float(skill.damage_min) * share)))
		result.damage_max = maxi(1, int(round(float(skill.damage_max) * share)))
		result.hits = int(skill.get("hits", 1))
	if skill.has("heal"):
		result.heal = int(round(float(skill.heal) * share))
	if skill.has("shield"):
		result.shield = int(round(float(skill.shield) * share))
	for lingering: String in ["burn", "weaken", "sunder", "slow", "entangle", "bleed"]:
		if skill.has(lingering):
			result[lingering] = skill[lingering].duplicate()
	# A weapon's own art (破阵枪): through the shield, or breaking it first; cast only with that weapon.
	for key: String in ["through", "shatter", "weapon"]:
		if skill.has(key):
			result[key] = skill[key]
	for key: String in ["combo", "absorb"]:
		if skill.has(key):
			result[key] = skill[key].duplicate()
	if skill.has("gather"):
		result.gather = int(skill.gather)
	if result.has("burn"):
		result.burn = [maxi(1, int(round(float(result.burn[0]) * share))), int(result.burn[1])]
	result.description = str(skill.description) + _layered_numbers(result) + "耗灵气：%s。" % cost_text(content, skill.cost) + combo_text(content, result)
	return result

## A named 心法 written by hand (《藏息录》): its own tier and passive, growing with its layers like any
## other; its words say where it falls short.
static func _handwritten_method(content, id: String, layer: int) -> Dictionary:
	var skill: Dictionary = content.skills[id]
	var tier := int(skill.get("tier", content.technique_data.inheritance_tier))
	var tier_def: Dictionary = content.technique_data.tiers[tier - 1]
	var layers := int(tier_def.layers)
	var at := layers if layer <= 0 else clampi(layer, 1, layers)
	var share := layer_share(content, at, layers)
	var passive := {}
	for key: String in skill.passive:
		passive[key] = _scaled(key, float(skill.passive[key]) * share)
	var result := {
		"id": id, "generated": false, "named": true, "element": skill.get("element", "none"), "tier": tier, "tier_name": tier_def.name,
		"name": skill.name, "slot": "method", "kind": "passive", "affixes": [], "affix_texts": [], "affix_unlocks": [],
		"min_realm": int(tier_def.min_realm), "value": int(tier_def.value), "study_days": int(tier_def.study_days),
		"layer": at, "layers": layers, "passive": passive,
	}
	# 散修专属 (《无相聚气诀》): it works only for one who belongs to no sect (loadout.gd bonuses).
	if bool(skill.get("wanderer", false)):
		result.wanderer = true
	result.description = str(skill.description) + describe_technique(content, result)
	return result

## The handwritten text names the art's full numbers; below full layers a line says what it does now.
static func _layered_numbers(t: Dictionary) -> String:
	if int(t.layer) >= int(t.layers):
		return ""
	if t.has("damage_min"):
		return "眼下第 %d 层，伤害 %d–%d。" % [t.layer, t.damage_min, t.damage_max]
	if t.has("heal"):
		return "眼下第 %d 层，恢复 %d 点气血。" % [t.layer, t.heal]
	if t.has("shield"):
		return "眼下第 %d 层，护盾 %d 点。" % [t.layer, t.shield]
	return ""

## The share of the tier's power at a layer: `layer_rule.first_share` at the first, all of it at the last,
## evenly between.
static func layer_share(content, layer: int, layers: int) -> float:
	if layers <= 1:
		return 1.0
	var first := float(content.technique_data.layer_rule.first_share)
	return first + (1.0 - first) * float(clampi(layer, 1, layers) - 1) / float(layers - 1)

## The layer that unlocks the `index`-th affix: the tier's `affix_layers`, else the last layer.
static func unlock_layer(tier_def: Dictionary, index: int) -> int:
	var unlocks: Array = tier_def.get("affix_layers", [])
	return int(unlocks[index]) if index < unlocks.size() else int(tier_def.layers)

## An archetype's cost for an element: "element" becomes the element; 省灵 drops an "any" orb first,
## else one of the element, never below one orb.
static func _cost(template: Dictionary, element: String, thrift: int) -> Dictionary:
	var cost := {}
	for key: String in template:
		cost[element if key == "element" else key] = int(template[key])
	for step: int in thrift:
		var total := 0
		for key: String in cost:
			total += int(cost[key])
		if total <= 1:
			break
		var dropped := "any" if cost.has("any") else ("same" if cost.has("same") else element)
		cost[dropped] = int(cost[dropped]) - 1
		if int(cost[dropped]) <= 0:
			cost.erase(dropped)
	return cost

## "金×2、同×2、任意×1": 同 is that many orbs of one element, whichever; 任意 any orbs at all.
static func cost_text(content, cost: Dictionary) -> String:
	var parts: Array[String] = []
	for key: String in content.technique_data.elements:
		if cost.has(key):
			parts.append("%s×%d" % [content.technique_data.elements[key].name, int(cost[key])])
	if cost.has("same"):
		parts.append("同×%d" % int(cost.same))
	if cost.has("any"):
		parts.append("任意×%d" % int(cost.any))
	return "、".join(parts)

## The same, short enough for a duel button: "金1·同2·任1".
static func cost_short(content, cost: Dictionary) -> String:
	var parts: Array[String] = []
	for key: String in content.technique_data.elements:
		if cost.has(key):
			parts.append("%s%d" % [content.technique_data.elements[key].name, int(cost[key])])
	if cost.has("same"):
		parts.append("同%d" % int(cost.same))
	if cost.has("any"):
		parts.append("任%d" % int(cost.any))
	return "·".join(parts)

## An archetype's 连击 for an element: "source" becomes the element that gives rise to it (土生金: a
## metal art follows an earth one), "same" the element itself.
static func _combo(content, template: Dictionary, element: String) -> Dictionary:
	var combo := template.duplicate()
	if str(template.after) == "same":
		combo.after = element
	elif str(template.after) == "source":
		for source: String in content.rules.duel.generates:
			if str(content.rules.duel.generates[source]) == element:
				combo.after = source
	return combo

## "连击：上一道神通为土系时，伤害 +30%。"
static func combo_text(content, t: Dictionary) -> String:
	if not t.has("combo"):
		return ""
	var combo: Dictionary = t.combo
	var effects: Array[String] = []
	if combo.has("bonus"):
		var word: String = {"heal": "回复", "guard": "护盾", "spirit": "效果"}.get(str(t.get("kind", "attack")), "伤害")
		effects.append("%s +%d%%" % [word, int(round(float(combo.bonus) * 100.0))])
	if combo.has("absorb"):
		effects.append("多吸收 %d 颗灵气" % int(combo.absorb))
	return "连击：上一道神通为%s系时，%s。" % [content.element_info(str(combo.after)).get("name", ""), "，".join(effects)]

static func _scaled(key: String, value: float) -> Variant:
	return int(round(value)) if key in ["max_hp", "max_qi", "attack", "orb_weight"] else snappedf(value, 0.001)

## The attribute line shown beside a technique's name, never inside it: "黄阶 · 金 · 神通".
static func technique_tag(content, t: Dictionary) -> String:
	return "%s · %s · %s" % [t.tier_name, content.element_info(str(t.element)).get("name", ""), "心法" if t.slot == "method" else "神通"]

static func describe_technique(content, t: Dictionary) -> String:
	var lines: Array[String] = []
	var element_name: String = content.element_info(str(t.element)).get("name", "")
	if t.slot == "art":
		match str(t.kind):
			"attack":
				lines.append("%s属性，造成 %d–%d 点伤害%s。" % [element_name, t.damage_min, t.damage_max, "，分 %d 段命中" % t.hits if int(t.hits) > 1 else ""])
			"heal":
				lines.append("恢复 %d 点气血。" % t.heal)
			"guard":
				lines.append("结成 %d 点护盾，先替你挡下伤害，至对手下一回合结束。" % t.shield)
		lines.append("耗灵气：%s。" % cost_text(content, t.cost))
		lines.append(combo_text(content, t))
	else:
		var names := {"cultivation": "修炼速度 +%d%%", "max_hp": "气血上限 +%d", "max_qi": "灵力上限 +%d", "element_damage": element_name + "属性伤害 +%d%%", "orb_weight": "斗法中" + element_name + "灵气更易抽到 +%d", "dun_speed": "遁速 +%d%%", "encounter": "野外遇险 %d%%", "humble_rate": "客栈、租屋与散修盟静室闭关收益 +%d%%", "room_rate": "闭关收益 +%d%%", "poison_ward": "所受流血与禁疗 -%d%%"}
		var parts: Array[String] = []
		for key: String in t.passive:
			var value: float = float(t.passive[key])
			parts.append(names[key] % int(round(value * 100.0 if key in ["cultivation", "element_damage", "dun_speed", "encounter", "humble_rate", "room_rate", "poison_ward"] else value)))
		lines.append("心法，常驻生效：" + "，".join(parts) + "。")
	var unlocks: Array = t.get("affix_unlocks", [])
	var texts: Array = t.get("affix_texts", [])
	for index: int in texts.size():
		var unlock: int = int(unlocks[index]) if index < unlocks.size() else 0
		if unlock > int(t.get("layer", 0)):
			lines.append("（第 %d 层解封）%s。" % [unlock, texts[index]])
		else:
			lines.append(str(texts[index]) + "。")
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
	# A named piece (听潮剑) exists only at the stages it is mended to, by its own name.
	if base.has("named") and not base.named.has(str(tier)):
		return {}
	var tier_def: Dictionary = data.tiers[tier - 1]
	var power := float(tier_def.power)
	var base_stats := {}
	for key: String in base.stats:
		base_stats[key] = float(base.stats[key]) * power
	var affix_ids: Array = Array(parts[4].split("+", false))
	var affix_names: Array[String] = []
	# Each affix's own share, kept apart so a piece wielded below its realm can count only some of them.
	var affix_stats: Array[Dictionary] = []
	for affix_id: String in affix_ids:
		var affix: Variant = data.affixes.get(affix_id)
		if not affix is Dictionary or affix_ids.count(affix_id) != 1:
			return {}
		affix_names.append(affix.name)
		var own := {}
		for key: String in affix.stats:
			# Orb affixes count whole orbs and do not grow with the tier.
			own[key] = float(affix.stats[key]) * (1.0 if key.begins_with("orb_") else power)
		affix_stats.append(own)
	var stats := _sum_stats(base_stats, affix_stats, 1.0, affix_stats.size())
	var nouns: Array = base.nouns
	var material: String = data.materials[base.material][tier - 1]
	var prefix := ""
	if element != "none":
		var words: Array = content.technique_data.elements[element].words
		prefix = str(words[variant % words.size()])
	var piece_name: String = str(base.named[str(tier)]) if base.has("named") else prefix + material + str(nouns[variant % nouns.size()])
	var result := {
		"id": id, "category": "equipment", "slot": base.slot, "tier": tier, "tier_name": tier_def.name, "element": element,
		"name": piece_name, "stats": stats, "affixes": affix_names,
		"price": int(tier_def.value) + 10 * affix_ids.size(),
		"realm": int(tier_def.get("realm", 0)), "base_stats": base_stats, "affix_stats": affix_stats,
	}
	result.description = describe_equipment(content, result)
	return result

## Base stats at `share` plus the first `affixes` affixes (in the piece's own order), at `share` too;
## whole orbs are not scaled. Rounded as the piece's own stats are.
static func _sum_stats(base_stats: Dictionary, affix_stats: Array, share: float, affixes: int) -> Dictionary:
	var stats := {}
	for key: String in base_stats:
		stats[key] = float(base_stats[key]) * share
	for index: int in mini(affixes, affix_stats.size()):
		for key: String in affix_stats[index]:
			stats[key] = float(stats.get(key, 0.0)) + float(affix_stats[index][key]) * (1.0 if key.begins_with("orb_") else share)
	for key: String in stats.keys():
		stats[key] = int(stats[key]) if key.begins_with("orb_") else _scaled(key, stats[key])
	return stats

## 驾驭度 (docs/WORLD_EXPANSION.md 2.3): a piece above its wielder's realm gives only a share of its
## stats and some of its affixes (data/equipment.json `mastery`, by how many realms short); three or more
## realms short it cannot be used at all. 祭炼 (gear.gd) adds `refine.step` per step taken on the piece
## (its "refine"), up to the row's `refined` limit. {"usable", "share", "limit", "affixes", "stats", "short"}.
static func wielded(content, item: Dictionary, realm: int) -> Dictionary:
	var short := maxi(0, int(item.get("realm", 0)) - realm)
	var table: Array = content.equipment_data.get("mastery", [{"share": 1.0, "affixes": 99}])
	if short >= table.size():
		return {"usable": false, "share": 0.0, "limit": 0.0, "affixes": 0, "stats": {}, "short": short}
	var step: Dictionary = table[short]
	var limit := float(step.get("refined", step.share))
	var share := minf(limit, float(step.share) + float(content.equipment_data.get("refine", {}).get("step", 0.0)) * int(item.get("refine", 0)))
	var affixes: int = mini(int(step.affixes), item.get("affix_stats", []).size())
	return {"usable": true, "share": share, "limit": limit, "affixes": affixes, "stats": _sum_stats(item.get("base_stats", item.stats), item.get("affix_stats", []), share, affixes), "short": short}

## A word on how much of a piece its wielder can draw on, or "" when all of it.
static func mastery_text(content, item: Dictionary, realm: int) -> String:
	var held := wielded(content, item, realm)
	var needed: String = content.realm(int(item.get("realm", 0))).name
	if not bool(held.usable):
		return "须%s方能催动，眼下境界差得太远。" % needed
	if float(held.share) >= 1.0:
		return ""
	var affixes := "词条只生效 %d 条" % int(held.affixes) if int(held.affixes) > 0 else "词条不生效"
	var further := "，祭炼可至 %d%%" % int(round(float(held.limit) * 100.0)) if float(held.share) < float(held.limit) - 0.0001 else ""
	return "须%s方能全力驾驭：眼下驾驭 %d%%%s，%s。" % [needed, int(round(float(held.share) * 100.0)), further, affixes]

static func describe_equipment(content, item: Dictionary) -> String:
	var names := {"attack": "攻击 +%d", "max_hp": "气血上限 +%d", "max_qi": "灵力上限 +%d", "defense": "受伤 -%d%%", "element_damage": "属性伤害 +%d%%", "cultivation": "修炼速度 +%d%%", "orb_first": "斗法开局多抽 %d 颗灵气", "orb_cap": "灵气上限 +%d", "orb_tide": "在临水、临海之地斗法，开局多吸 %d 颗水灵气"}
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
	var text := "%s · %s。%s%s" % [item.tier_name, slot_name, "，".join(parts), "。词条：" + "、".join(item.affixes) if not item.affixes.is_empty() else "。"]
	# What the piece does in a duel of its own (combat.gd): 祭出 for 兵刃, a 特性 for some others.
	var base: Dictionary = content.equipment_data.bases.get(str(item.get("id", "")).get_slice(":", 1), {})
	if base.has("release"):
		text += "可祭出「%s」（斗法中每场%s，不占回合）。" % [base.release.name, "两次" if int(item.tier) >= 4 else "一次"]
	if base.has("art") and content.skills.has(str(base.art)):
		text += "持之可施展「%s」。" % content.skills[str(base.art)].name
	if bool(base.get("lead", false)):
		text += "持之斗法总是先出手。"
	if base.has("trait"):
		text += "特性「%s」：%s" % [base["trait"].name, base["trait"].text]
	if base.has("lore"):
		text += str(base.lore)
	return text

static func generate_equipment(content, rng: RandomNumberGenerator, tier: int, slot: String = "") -> String:
	var data: Dictionary = content.equipment_data
	var bases: Array = data.bases.keys().filter(func(key: String) -> bool: return (slot.is_empty() or data.bases[key].slot == slot) and not data.bases[key].has("named"))
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
