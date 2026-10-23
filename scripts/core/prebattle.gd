extends RefCounted
## Medicines are consumed before battle. Saves keep only known item IDs, not executable effects.

static func pending(s) -> Array:
	var result: Array = s.player.get("prepared_pills", []).duplicate()
	var legacy := str(s.player.get("prepared_pill", ""))
	if not legacy.is_empty() and not legacy in result:
		result.append(legacy)
	return result

static func group(content, id: String) -> String:
	return str(content.item(id).get("battle_preparation", {}).get("group", "opening_qi"))

static func block(s, id: String) -> String:
	for other: String in pending(s):
		if group(s.content, id) == group(s.content, other):
			return "同类药力已准备，留待下一场斗法使用。"
	return ""

static func prepare(s, id: String) -> void:
	if not s.content.item(id).battle_preparation.has("group"):
		s.player.prepared_pill = id
	else:
		if not s.player.has("prepared_pills"):
			s.player.prepared_pills = []
		s.player.prepared_pills.append(id)

static func consume(s) -> Dictionary:
	var ids := pending(s)
	var result := {"opening_orbs": 0, "opening_shield": 0}
	if ids.is_empty():
		return result
	var legacy := str(s.player.get("prepared_pill", ""))
	if not legacy.is_empty():
		s.battle.prepared_pill = legacy
	s.battle.prepared_pills = ids
	s.player.erase("prepared_pill")
	s.player.erase("prepared_pills")
	for id: String in ids:
		var effect: Dictionary = s.content.item(id).battle_preparation
		for key: String in result:
			result[key] = int(result[key]) + int(effect.get(key, 0))
	return result

static func value(s, key: String, element: String = "") -> int:
	var total := 0
	var ids: Array = s.battle.get("prepared_pills", [])
	if ids.is_empty() and s.battle.has("prepared_pill"):
		ids = [s.battle.prepared_pill]
	for id: String in ids:
		var effect: Dictionary = s.content.item(id).get("battle_preparation", {})
		var item: Variant = effect.get(key, 0)
		if item is Array:
			if str(item[0]) == element:
				total += int(item[1])
		else:
			total += int(item)
	return total

static func burn_immune(s) -> bool:
	return not s.battle.is_empty() and int(s.battle.turn) <= value(s, "burn_immune_turns")

static func describe(s, id: String, active: bool = false) -> String:
	var item: Dictionary = s.content.item(id)
	var effect: Dictionary = item.get("battle_preparation", {})
	var text := str(item.get("description", ""))
	if active and effect.has("burn_immune_turns"):
		text += "（余 %d 回合）" % maxi(0, int(effect.burn_immune_turns) - int(s.battle.turn) + 1)
	elif active and effect.has("first_turn_damage") and int(s.battle.turn) > 1:
		text += "（首回合药力已消退）"
	return "%s · %s" % [str(item.get("name", id)), text]

static func valid_definition(effect: Variant, elements: Dictionary) -> bool:
	if not effect is Dictionary or effect.is_empty():
		return false
	for key: Variant in effect:
		var value: Variant = effect[key]
		if key == "group":
			if not value is String or value.is_empty() or value.length() > 64:
				return false
		elif key in ["damage", "turn_orbs"]:
			if not value is Array or value.size() != 2 or not elements.has(value[0]) or not _count(value[1]):
				return false
		elif not key in ["opening_orbs", "opening_shield", "sense", "first_turn_damage", "burn_immune_turns"] or not _count(value):
			return false
	return effect.keys().any(func(key: Variant) -> bool: return key != "group")

static func _count(value: Variant) -> bool:
	return (value is int or value is float) and is_finite(float(value)) and float(value) == floor(float(value)) and float(value) > 0 and float(value) <= 100

static func valid_ids(content, ids: Variant) -> bool:
	if not ids is Array or ids.size() > 12:
		return false
	var seen: Array = []
	for id: Variant in ids:
		if not id is String or not content.item(id).has("battle_preparation") or group(content, id) in seen:
			return false
		seen.append(group(content, id))
	return true
