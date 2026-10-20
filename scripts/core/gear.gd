extends RefCounted
## 宝物实例与祭炼 (docs/WORLD_EXPANSION.md 2.3, 2.5). Operates on a Session.
## A plain piece is its generated type id ("e:…", arsenal.gd) and stacks in the 行囊 like any item. A
## piece that grows on its own becomes an instance the first time it is refined: player.gear holds
## instance id ("q:<n>") -> {"type", "refine"}, and player.gear_serial numbers the next one. Instances
## never stack; one is in the 行囊 unless a slot of player.equipment holds its id.
## 祭炼 belongs to the piece and its owner: each step adds `refine.step` to the share drawn on, up to the
## `refined` limit of the realms still short (data/equipment.json `mastery`); a breakthrough recounts the
## base share and keeps the steps, never above full. Selling an instance takes it away with its steps;
## a new owner would begin again.

const PREFIX := "q:"

static func is_instance(item_id: String) -> bool:
	return item_id.begins_with(PREFIX)

## The type id behind an instance id; any other id is its own type.
static func type_of(s, item_id: String) -> String:
	if not is_instance(item_id):
		return item_id
	return str(s.player.get("gear", {}).get(item_id, {}).get("type", ""))

## A piece as the player holds it: its type's definition, with "instance" and "refine" for an instance.
## {} when unknown.
static func item(s, item_id: String) -> Dictionary:
	return item_in(s.content, s.player.get("gear", {}), item_id)

## The same from a holder's own instances (the player's, or a save being checked).
static func item_in(content, gear: Dictionary, item_id: String) -> Dictionary:
	if not is_instance(item_id):
		return content.equipment(item_id)
	var held: Variant = gear.get(item_id)
	if not held is Dictionary:
		return {}
	var piece: Dictionary = content.equipment(str(held.type)).duplicate()
	if piece.is_empty():
		return piece
	piece.instance = item_id
	piece.refine = int(held.refine)
	return piece

static func worn(s, item_id: String) -> bool:
	return s.player.get("equipment", {}).values().has(item_id)

## Instances in the 行囊 (not worn), oldest first.
static func carried(s) -> Array[String]:
	var ids: Array[String] = []
	for item_id: String in s.player.get("gear", {}):
		if not worn(s, item_id):
			ids.append(item_id)
	ids.sort_custom(func(a: String, b: String) -> bool: return int(a.trim_prefix(PREFIX)) < int(b.trim_prefix(PREFIX)))
	return ids

static func _create(s, type_id: String) -> String:
	if not s.player.has("gear"):
		s.player.gear = {}
	s.player.gear_serial = int(s.player.get("gear_serial", 0)) + 1
	var item_id := PREFIX + str(s.player.gear_serial)
	s.player.gear[item_id] = {"type": type_id, "refine": 0}
	return item_id

## What the next step of 祭炼 costs: {"days", "stones"}, growing with the steps already taken.
static func refine_cost(s, piece: Dictionary) -> Dictionary:
	var rule: Dictionary = s.content.equipment_data.refine
	var factor := 1.0 + float(rule.growth) * int(piece.get("refine", 0))
	return {"days": int(round(float(rule.days[int(piece.tier) - 1]) * factor)), "stones": int(round(float(rule.stones[int(piece.tier) - 1]) * factor))}

## Why this piece cannot be refined now, or "". `slot` names the slot it is worn in, else it is carried.
static func refine_block(s, item_id: String, slot: String = "") -> String:
	var piece := item(s, item_id)
	if piece.is_empty() or (slot.is_empty() and s.item_count(item_id) < 1) or (not slot.is_empty() and str(s.player.equipment.get(slot, "")) != item_id):
		return "没有这件宝物。"
	if not s.battle.is_empty():
		return "斗法中无法祭炼。"
	var held: Dictionary = s.Arsenal.wielded(s.content, piece, int(s.player.realm))
	if int(held.short) == 0:
		return "你已能全力驾驭此宝，无须祭炼。"
	if not bool(held.usable):
		return "境界相差太远，祭炼不动此宝。"
	if float(held.share) >= float(held.limit) - 0.0001:
		return "以眼下境界，祭炼已到尽头（驾驭 %d%%），突破后方能再进。" % int(round(float(held.share) * 100.0))
	if not s.available_here("cultivate"):
		return "祭炼须在静室或洞府中静心施为。"
	var cost := refine_cost(s, piece)
	if int(s.player.stones) < int(cost.stones):
		return "祭炼须耗灵石 %d，灵石不足。" % int(cost.stones)
	return s.blocked()

## 祭炼: days and stones for one more step of the share drawn on. A plain piece becomes an instance.
static func refine(s, item_id: String, slot: String = "") -> String:
	var reason := refine_block(s, item_id, slot)
	if not reason.is_empty():
		return reason
	var piece := item(s, item_id)
	var cost := refine_cost(s, piece)
	s.player.stones = int(s.player.stones) - int(cost.stones)
	var passed: Dictionary = s.advance_days(int(cost.days))
	if not s.ended.is_empty():
		return s.conclude("", passed)
	var refined := item_id
	if not is_instance(item_id):
		refined = _create(s, item_id)
		if slot.is_empty():
			s.remove_item(item_id, 1)
		else:
			s.player.equipment[slot] = refined
	s.player.gear[refined].refine = int(s.player.gear[refined].refine) + 1
	s.refresh_realm_stats()
	var share := int(round(float(s.Arsenal.wielded(s.content, item(s, refined), int(s.player.realm)).share) * 100.0))
	return s.conclude(s.log_event("refine", {"item": str(piece.id), "days": passed.elapsed, "share": share}), passed)

## The 祭炼 line for a piece's details, or "" for a plain one.
static func refine_text(piece: Dictionary) -> String:
	if int(piece.get("refine", 0)) <= 0:
		return ""
	return "已祭炼 %d 次（契合随主人，转手即失）。" % int(piece.refine)

## Whether the player holds a piece of `type_id` anywhere: carried, worn, or as an instance.
static func holds(s, type_id: String) -> bool:
	if s.item_count(type_id) > 0 or s.player.get("equipment", {}).values().has(type_id):
		return true
	for held: Variant in s.player.get("gear", {}).values():
		if held is Dictionary and str(held.get("type", "")) == type_id:
			return true
	return false

## Mends a piece into the next stage of itself (听潮剑): the one held of `from_type` becomes `to_type`
## where it lies — an instance keeps its id and its 祭炼, a worn piece stays worn. False when none is held.
static func reforge(s, from_type: String, to_type: String) -> bool:
	for item_id: String in s.player.get("gear", {}):
		if str(s.player.gear[item_id].type) == from_type:
			s.player.gear[item_id].type = to_type
			s.refresh_realm_stats()
			return true
	for slot: String in s.player.get("equipment", {}):
		if str(s.player.equipment[slot]) == from_type:
			s.player.equipment[slot] = to_type
			s.refresh_realm_stats()
			return true
	if s.item_count(from_type) > 0:
		s.remove_item(from_type, 1)
		s.add_item(to_type, 1)
		return true
	return false
