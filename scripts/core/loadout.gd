extends RefCounted
## Techniques, equipment and lineage, and the bonuses they give. Operates on a Session.
## player.learned lists every technique known; player.arts (up to rules.art_slots) are usable in duels
## and player.methods (up to rules.method_slots) are passive 心法. player.equipment holds one item id
## per slot; equipped items leave the 行囊 and return to it when taken off.
const Talents = preload("res://scripts/core/talents.gd")
const Layers = preload("res://scripts/core/layers.gd")
const Gear = preload("res://scripts/core/gear.gd")

## Totals from 心法, equipment and talents: attack, max_hp, max_qi, defense, cultivation, element_damage
## {element|"*": x}, and the talents' max_hp_percent and max_qi_percent of the stage's caps.
static func bonuses(s, holder: Dictionary = {}) -> Dictionary:
	if holder.is_empty():
		holder = s.player
	var total := {"attack": 0, "max_hp": 0, "max_qi": 0, "defense": 0.0, "cultivation": 0.0, "element_damage": {}, "max_hp_percent": 0, "max_qi_percent": 0}
	for key: String in Talents.ORB_KEYS:
		total[key] = 0
	_add_talents(s, total, holder.get("talents", []) + holder.get("flaws", []))
	var sources: Array[Dictionary] = []
	# 心法 count at the layer held: the player keeps their layers (layers.gd), anyone else holds theirs at
	# their realm's cap.
	var layers: Variant = holder.get("layers")
	for technique_id: Variant in holder.get("methods", []):
		var method: Dictionary = Layers.held_in(s.content, layers, str(technique_id), int(holder.get("realm", 0))) if layers is Dictionary else Layers.at_realm(s.content, str(technique_id), int(holder.get("realm", 0)))
		if not method.is_empty():
			sources.append({"stats": method.passive, "element": method.element})
	for slot: String in holder.get("equipment", {}):
		# The player's pieces may be instances with their 祭炼 (gear.gd).
		var gear: Dictionary = Gear.item_in(s.content, holder.get("gear", {}), str(holder.equipment[slot]))
		if gear.is_empty():
			continue
		# A piece above the holder's realm gives only what they can draw on (驾驭度, arsenal.gd).
		var held: Dictionary = s.Arsenal.wielded(s.content, gear, int(holder.get("realm", 0)))
		if bool(held.usable):
			sources.append({"stats": held.stats, "element": "*" if gear.element == "none" else gear.element})
	for source: Dictionary in sources:
		for key: String in source.stats:
			if key == "element_damage":
				total.element_damage[source.element] = float(total.element_damage.get(source.element, 0.0)) + float(source.stats[key])
			elif key == "orb_weight":
				# An element drawn more often: the 心法's or the 法宝's own element (none for plain gear).
				if total.has("orb_" + str(source.element)):
					total["orb_" + str(source.element)] = int(total["orb_" + str(source.element)]) + int(source.stats[key])
			elif key in ["defense", "cultivation"]:
				total[key] = float(total[key]) + float(source.stats[key])
			else:
				total[key] = int(total[key]) + int(source.stats[key])
	return total

## Talents' share of the totals: percentages become fractions; health and qi stay percentages of the
## stage's caps (refresh_realm_stats).
static func _add_talents(s, total: Dictionary, ids: Array) -> void:
	var mods: Dictionary = Talents.sum(s.content, ids)
	total.attack = int(total.attack) + int(mods.get("attack", 0))
	total.defense = float(total.defense) + float(mods.get("defense", 0)) / 100.0
	total.cultivation = float(total.cultivation) + float(mods.get("cultivation", 0)) / 100.0
	total.max_hp_percent = int(mods.get("max_hp", 0))
	total.max_qi_percent = int(mods.get("max_qi", 0))
	for key: String in Talents.ORB_KEYS:
		total[key] = int(total[key]) + int(mods.get(key, 0))
	for key: String in mods:
		if key.begins_with("damage_"):
			var element := "*" if key == "damage_all" else key.trim_prefix("damage_")
			total.element_damage[element] = float(total.element_damage.get(element, 0.0)) + float(mods[key]) / 100.0

static func attack_bonus(s) -> int:
	return int(s.stage_stats().attack_bonus) + int(bonuses(s).attack)

## Share of incoming damage avoided by equipment and talents, capped at half.
static func defense(s) -> float:
	return minf(0.5, float(bonuses(s).defense))

## Damage multiplier for a technique: element bonuses, plus a little extra when it matches a spirit root.
static func element_multiplier(s, t: Dictionary) -> float:
	var damage: Dictionary = bonuses(s).element_damage
	var multiplier := 1.0 + float(damage.get(t.element, 0.0)) + float(damage.get("*", 0.0))
	if t.element in s.player.get("roots", []):
		multiplier += float(s.content.technique_data.root_bonus)
	return multiplier

static func active_skills(s) -> Array[String]:
	var result: Array[String] = []
	for id: Variant in s.player.get("arts", []):
		result.append(str(id))
	return result

## Why the player cannot learn this technique now, or "".
static func learn_block(s, technique_id: String) -> String:
	var t: Dictionary = s.content.technique(technique_id)
	if t.is_empty():
		return "此法无从参悟。"
	if technique_id in s.player.learned:
		return "你已习得此法。"
	# A tier up to two realms beyond can be begun, its layers capped (layers.gd); three is too far.
	if Layers.cap(s.content, t, int(s.player.realm)) < 1:
		return "%s之法，境界相差太远，需达到%s方可参悟。" % [t.tier_name, s.content.realm_title(int(t.min_realm) - int(Layers.rule(s.content).blocked_gap) + 1, 0)]
	return s.blocked()

## Studies a technique for its tier's days; the new technique goes into a free slot if there is one.
static func _study(s, technique_id: String) -> Dictionary:
	var t: Dictionary = s.content.technique(technique_id)
	var passed: Dictionary = s.advance_days(s.study_days(t))
	if not s.ended.is_empty():
		return passed
	s.player.learned.append(technique_id)
	Layers.begin(s, technique_id)
	var slots: Array = s.player.arts if t.slot == "art" else s.player.methods
	if slots.size() < int(s.content.rules.art_slots if t.slot == "art" else s.content.rules.method_slots):
		slots.append(technique_id)
	s.refresh_realm_stats()
	passed.text = s.log_event("learn", {"technique": technique_id, "days": passed.elapsed}, int(t.tier) >= 3)
	return passed

## Studies the technique written in a jade slip from the 行囊.
static func study_manual(s, item_id: String) -> String:
	var manual: Dictionary = s.content.item(item_id)
	if manual.get("category", "") != "manual" or s.item_count(item_id) < 1:
		return "行囊里没有这枚玉简。"
	var reason := learn_block(s, manual.teaches)
	if not reason.is_empty():
		return reason
	s.remove_item(item_id, 1)
	var passed := _study(s, manual.teaches)
	return s.conclude(str(passed.get("text", "")), passed)

## Techniques taught by the scene here (the sect's 传功堂).
static func teachings(s) -> Array[String]:
	var result: Array[String] = []
	if not s.available_here("teach"):
		return result
	for spot: Dictionary in s.content.locations[s.player.location].spots:
		for technique_id: String in spot.get("teach", []):
			result.append(technique_id)
	return result

static func learn_here(s, technique_id: String) -> String:
	if not technique_id in teachings(s):
		return "这里不传授此法。"
	var reason := learn_block(s, technique_id)
	if not reason.is_empty():
		return reason
	var passed := _study(s, technique_id)
	return s.conclude(str(passed.get("text", "")), passed)

## Puts a learned technique into its slots, replacing `replace` when the slots are full.
static func equip_technique(s, technique_id: String, replace: String = "") -> String:
	var t: Dictionary = s.content.technique(technique_id)
	if not technique_id in s.player.learned or t.is_empty():
		return "尚未习得此法。"
	if not s.battle.is_empty():
		return "斗法中无法更换功法。"
	var slots: Array = s.player.arts if t.slot == "art" else s.player.methods
	var limit := int(s.content.rules.art_slots if t.slot == "art" else s.content.rules.method_slots)
	if technique_id in slots:
		return "此法已在运转。"
	if slots.size() >= limit:
		if not replace in slots:
			return "栏位已满，请先选择要替换的功法。"
		slots.erase(replace)
	slots.append(technique_id)
	s.refresh_realm_stats()
	return s.finish("改为运转%s。" % t.name)

static func unequip_technique(s, technique_id: String) -> String:
	if not s.battle.is_empty():
		return "斗法中无法更换功法。"
	var t: Dictionary = s.content.technique(technique_id)
	var slots: Array = s.player.arts if t.get("slot", "art") == "art" else s.player.methods
	if not technique_id in slots:
		return "此法并未运转。"
	if t.get("slot", "art") == "art" and slots.size() <= 1:
		return "至少保留一门神通。"
	slots.erase(technique_id)
	s.refresh_realm_stats()
	return s.finish("停下了%s。" % t.name)

## Wears a piece from the 行囊: a plain one leaves its stack, an instance stays in player.gear and is
## only marked worn; what was worn goes back the same way.
static func equip_item(s, item_id: String) -> String:
	var gear: Dictionary = Gear.item(s, item_id)
	if gear.is_empty() or s.item_count(item_id) < 1:
		return "行囊里没有这件宝物。"
	if not s.battle.is_empty():
		return "斗法中无法更换宝物。"
	if not bool(s.Arsenal.wielded(s.content, gear, int(s.player.realm)).usable):
		return s.Arsenal.mastery_text(s.content, gear, int(s.player.realm))
	var worn := str(s.player.equipment.get(gear.slot, ""))
	if not Gear.is_instance(item_id):
		s.remove_item(item_id, 1)
	s.player.equipment[gear.slot] = item_id
	if not worn.is_empty():
		s.add_item(worn, 1)
	s.refresh_realm_stats()
	return s.finish("换上了%s。" % gear.name)

static func unequip_slot(s, slot: String) -> String:
	var worn := str(s.player.equipment.get(slot, ""))
	if worn.is_empty():
		return "此处没有佩戴宝物。"
	if not s.battle.is_empty():
		return "斗法中无法更换宝物。"
	var name := str(Gear.item(s, worn).get("name", ""))
	s.player.equipment[slot] = ""
	s.add_item(worn, 1)
	s.refresh_realm_stats()
	return s.finish("取下了%s。" % name)

static func choose_sect(s, sect_id: String) -> String:
	if s.player.is_empty() or not s.content.sects.has(sect_id):
		return "未知门派。"
	if not s.battle.is_empty():
		return "斗法中无法更换传承。"
	var blocked: String = s.blocked()
	if not blocked.is_empty():
		return blocked
	if not s.available_here("study"):
		return "请回青云山传功堂研习门派传承。"
	if s.player.get("sect", "wanderer") == sect_id:
		return "你已在研习此传承。"
	if sect_id != home_lineage(s):
		return "传功堂只传本门传承；他派神通须得其玉简，或请人传授。"
	# Studying the lineage takes its days, like any technique.
	var passed: Dictionary = s.advance_days(int(s.content.rules.lineage.study_days))
	if not s.ended.is_empty():
		return s.conclude("", passed)
	take_lineage(s, sect_id)
	return s.conclude(s.log_event("study_lineage", {"sect": sect_id, "days": passed.elapsed}, true), passed)

## The lineage the sect's 传功堂 teaches.
static func home_lineage(s) -> String:
	return str(s.content.rules.lineage.home)

## Takes up a lineage at once: teaches its three arts and puts them in the art slots. The 传功堂 goes
## through choose_sect; the sect preview and tests use this directly.
static func take_lineage(s, sect_id: String) -> void:
	s.player.sect = sect_id
	s.player.arts = []
	for skill_id: String in s.content.sects[sect_id].skills:
		if not skill_id in s.player.learned:
			s.player.learned.append(skill_id)
		Layers.begin(s, skill_id)
		s.player.arts.append(skill_id)
