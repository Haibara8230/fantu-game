extends RefCounted
## 功法层数 (docs/WORLD_EXPANSION.md 2.1). Every technique has layers by its tier (data/techniques.json
## `tiers[].layers`); the first layer gives `layer_rule.first_share` of the tier's power and the last all
## of it, and affixes unlock at the tier's `affix_layers` (arsenal.gd reads a technique at a layer).
## The realm caps the layers: floor(layers / 2^gap) with gap = the tier's full realm minus the realm,
## at least one; a gap of `blocked_gap` or more cannot be studied at all.
## player.layers holds technique id -> {"layer", "practice"}; practice counts tenths of a day of study
## toward the next layer. Casting an art in a duel and retreating (slotted methods, and slotted arts a
## little) add practice; 参悟 spends days and stones to finish the layer at once. Practice past the
## realm's cap waits, full, until a breakthrough lifts the cap.
## Everyone else (generated people, opponents) holds their techniques at the cap of their realm.

const Arsenal = preload("res://scripts/core/arsenal.gd")

## Tenths of a day, so practice stays whole and a long retreat equals several short ones.
const TENTHS := 10

static func rule(content) -> Dictionary:
	return content.technique_data.layer_rule

static func _tier(content, t: Dictionary) -> Dictionary:
	return content.technique_data.tiers[int(t.tier) - 1]

## The layers a realm allows of a technique; 0 when it cannot be studied yet.
static func cap(content, t: Dictionary, realm: int) -> int:
	var gap := maxi(0, int(t.get("min_realm", 0)) - realm)
	if gap >= int(rule(content).blocked_gap):
		return 0
	return maxi(1, int(t.layers) >> gap)

## The layer the player holds a technique at. One without a record (journeys before layers were kept)
## is held as it always was: at the realm's cap.
static func layer_of(s, technique_id: String) -> int:
	return _layer_in(s.content, s.player.get("layers", {}), technique_id, int(s.player.get("realm", 0)))

static func _layer_in(content, layers: Dictionary, technique_id: String, realm: int) -> int:
	var entry: Variant = layers.get(technique_id)
	if entry is Dictionary:
		return int(entry.layer)
	var full: Dictionary = content.technique(technique_id)
	return maxi(1, cap(content, full, realm)) if not full.is_empty() else 1

## The player's technique as they hold it now.
static func held(s, technique_id: String) -> Dictionary:
	return Arsenal.technique(s.content, technique_id, layer_of(s, technique_id))

## A technique at the layer kept in `layers` (the player's, or a save being checked) at `realm`.
static func held_in(content, layers: Dictionary, technique_id: String, realm: int) -> Dictionary:
	return Arsenal.technique(content, technique_id, _layer_in(content, layers, technique_id, realm))

## Someone else's technique, at the cap of their realm.
static func at_realm(content, technique_id: String, realm: int) -> Dictionary:
	var full: Dictionary = content.technique(technique_id)
	if full.is_empty():
		return full
	return Arsenal.technique(content, technique_id, maxi(1, cap(content, full, realm)))

## Days of study from `layer` to the next, after talents and spirit roots (as learning is).
static func need_days(s, t: Dictionary, layer: int) -> int:
	return s.study_days({"study_days": int(_tier(s.content, t).layer_days) * layer, "element": t.element})

## Stones the next layer asks of 参悟 from `layer`.
static func need_stones(s, t: Dictionary, layer: int) -> int:
	return int(_tier(s.content, t).layer_stones) * layer

## Starts a newly learned technique at the first layer; one already held keeps its layer.
static func begin(s, technique_id: String) -> void:
	if not s.player.has("layers"):
		s.player.layers = {}
	if not s.player.layers.has(technique_id):
		s.player.layers[technique_id] = {"layer": 1, "practice": 0}

## The record for a technique, made at the layer it is held at when it has none yet.
static func _entry(s, technique_id: String) -> Variant:
	if not technique_id in s.player.get("learned", []):
		return null
	if not s.player.has("layers"):
		s.player.layers = {}
	if not s.player.layers.has(technique_id):
		s.player.layers[technique_id] = {"layer": layer_of(s, technique_id), "practice": 0}
	return s.player.layers[technique_id]

## Adds practice (tenths of a day) and climbs the layers it pays for, up to the realm's cap. Returns the
## chronicle lines of the layers reached.
static func practise(s, technique_id: String, tenths: int) -> Array[String]:
	var lines: Array[String] = []
	var t: Dictionary = s.content.technique(technique_id)
	if t.is_empty() or (tenths <= 0 and not s.player.get("layers", {}).has(technique_id)):
		return lines
	var entry: Variant = _entry(s, technique_id)
	if not entry is Dictionary:
		return lines
	var top := mini(int(t.layers), cap(s.content, t, int(s.player.realm)))
	entry.practice = int(entry.practice) + maxi(0, tenths)
	while int(entry.layer) < top and int(entry.practice) >= need_days(s, t, int(entry.layer)) * TENTHS:
		entry.practice = int(entry.practice) - need_days(s, t, int(entry.layer)) * TENTHS
		entry.layer = int(entry.layer) + 1
		lines.append(s.log_event("layer_up", {"technique": technique_id, "layer": int(entry.layer)}, int(entry.layer) >= int(t.layers) and int(t.tier) >= 3))
	if int(entry.layer) >= int(t.layers):
		entry.practice = 0
	else:
		entry.practice = mini(int(entry.practice), need_days(s, t, int(entry.layer)) * TENTHS)
	return lines

## Practice from days of retreat: the slotted methods, and the slotted arts a little.
static func after_retreat(s, days: int) -> Array[String]:
	var lines: Array[String] = []
	for technique_id: Variant in s.player.get("methods", []):
		lines.append_array(practise(s, str(technique_id), days * int(rule(s.content).retreat_method)))
	for technique_id: Variant in s.player.get("arts", []):
		lines.append_array(practise(s, str(technique_id), days * int(rule(s.content).retreat_art)))
	return lines

## An art cast in a duel.
static func after_cast(s, technique_id: String) -> Array[String]:
	return practise(s, technique_id, int(rule(s.content).cast_practice))

## A breakthrough lifts the caps: practice that waited climbs now.
static func after_breakthrough(s) -> Array[String]:
	var lines: Array[String] = []
	for technique_id: String in s.player.get("layers", {}).keys():
		lines.append_array(practise(s, technique_id, 0))
	return lines

## What 参悟 of the next layer costs now: {"days", "stones"}; the days are those still missing.
static func comprehend_cost(s, technique_id: String) -> Dictionary:
	var t: Dictionary = s.content.technique(technique_id)
	var layer := layer_of(s, technique_id)
	var practice := int(s.player.get("layers", {}).get(technique_id, {}).get("practice", 0))
	var days := maxi(1, ceili(float(need_days(s, t, layer) * TENTHS - practice) / TENTHS))
	return {"days": days, "stones": need_stones(s, t, layer)}

## Why the player cannot 参悟 the next layer now, or "".
static func comprehend_block(s, technique_id: String) -> String:
	var t: Dictionary = s.content.technique(technique_id)
	if t.is_empty() or not technique_id in s.player.get("learned", []):
		return "尚未习得此法。"
	var layer := layer_of(s, technique_id)
	if layer >= int(t.layers):
		return "此法已修至第 %d 层，圆满。" % layer
	if layer >= cap(s.content, t, int(s.player.realm)):
		return "以眼下境界只能修到第 %d 层；%s可修满。" % [layer, s.content.realm(int(t.min_realm)).name]
	if not s.battle.is_empty():
		return "斗法中无法参悟。"
	var cost := comprehend_cost(s, technique_id)
	if int(s.player.stones) < int(cost.stones):
		return "参悟第 %d 层须耗灵石 %d，灵石不足。" % [layer + 1, int(cost.stones)]
	return s.blocked()

## 参悟: spends the missing days (and the layer's stones) to reach the next layer.
static func comprehend(s, technique_id: String) -> String:
	var reason := comprehend_block(s, technique_id)
	if not reason.is_empty():
		return reason
	var cost := comprehend_cost(s, technique_id)
	s.player.stones = int(s.player.stones) - int(cost.stones)
	var passed: Dictionary = s.advance_days(int(cost.days))
	if not s.ended.is_empty():
		return s.conclude("", passed)
	var t: Dictionary = s.content.technique(technique_id)
	var entry: Dictionary = _entry(s, technique_id)
	entry.layer = int(entry.layer) + 1
	entry.practice = 0
	s.refresh_realm_stats()
	return s.conclude(s.log_event("comprehend", {"technique": technique_id, "layer": int(entry.layer), "days": passed.elapsed}, int(entry.layer) >= int(t.layers) and int(t.tier) >= 3), passed)

## "第 3 / 5 层" with what the next layer still needs, for the 功法 page.
static func progress_text(s, technique_id: String) -> String:
	var t: Dictionary = s.content.technique(technique_id)
	if t.is_empty():
		return ""
	var layer := layer_of(s, technique_id)
	var text := "第 %d / %d 层" % [layer, int(t.layers)]
	if layer >= int(t.layers):
		return text + " · 圆满"
	var top := cap(s.content, t, int(s.player.realm))
	var practice := int(s.player.get("layers", {}).get(technique_id, {}).get("practice", 0))
	var need := need_days(s, t, layer) * TENTHS
	text += " · 熟练 %d%%" % (practice * 100 / maxi(1, need))
	if layer >= top:
		text += " · 境界所限，突破后再进"
	return text
