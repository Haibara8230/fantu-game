extends RefCounted
## 筑基 as a stage played with qi (docs/MCS_SYSTEMS_GAP_20261026.md A1), after 《觅长生》's 0.9 筑基: once
## the attempt's retreat is over, nine rounds of qi drawn by the spirit roots, as in 结丹 (forming.gd),
## pressed into 灵液 by 秘术 (data/forming.json `foundation.arts`). The 灵液 must reach `goal` by the last
## round and may go past it: how far grades the foundation (`grades`: 下品, 中品, 上品; 无瑕 only by the
## steps of fortune and 天材地宝, as before). 真元 starts at the attempt's odds (the 筑基丹 still count
## there); each round's 灵压 and qi let go wear it, 调息 shores it up. At none, or short of the goal at
## the end, the attempt fails as before (breakthrough.gd _fail).
## Operates on a Session; s.founding holds the stage under way, {} otherwise.
const Forming = preload("res://scripts/core/forming.gd")
const QiRelations = preload("res://scripts/core/qi_relations.gd")
const MEASURE := "真元"
const EFFECTS := ["liquid", "essence", "absorb"]

static func data(s) -> Dictionary:
	return s.content.forming_data.foundation

static func state(s) -> Dictionary:
	return s.founding

## Whether breaking through to `target` is played as this stage.
static func applies(target: int) -> bool:
	return target == 1

static func valid_data(content) -> bool:
	var d: Variant = content.forming_data.get("foundation")
	if not d is Dictionary:
		return false
	for key: String in ["rounds", "draw", "cap", "discard", "goal"]:
		if not Forming._count(d.get(key)):
			return false
	if int(d.rounds) < 1 or int(d.goal) < 1:
		return false
	# One line per grade short of 无瑕, rising from the goal.
	var grades: Variant = d.get("grades")
	if not grades is Array or grades.size() != content.rules.breakthrough.grades.size() - 1 or grades.any(func(value: Variant) -> bool: return not Forming._count(value)) or int(grades[0]) != int(d.goal):
		return false
	for index: int in range(1, grades.size()):
		if int(grades[index]) <= int(grades[index - 1]):
			return false
	if not d.get("strain") is Array or d.strain.size() != int(d.rounds) or d.strain.any(func(value: Variant) -> bool: return not Forming._count(value)):
		return false
	var arts: Variant = d.get("arts")
	if not arts is Dictionary or arts.is_empty():
		return false
	var presses := false
	for art_id: String in arts:
		var art: Variant = arts[art_id]
		if not art is Dictionary or not art.get("name") is String or not art.get("text") is String or not Forming._valid_cost(art.get("cost")) or not art.get("effect") is Dictionary or art.effect.is_empty():
			return false
		for key: Variant in art.effect:
			if not key in EFFECTS or not Forming._signed(art.effect[key]):
				return false
		if art.has("requires") and not art.requires in content.world_flags:
			return false
		var relation: Variant = art.get("relation", {})
		if not relation is Dictionary or relation.keys().any(func(key: Variant) -> bool: return not QiRelations.LABELS.has(key) or not relation[key] is Dictionary or relation[key].keys().any(func(field: Variant) -> bool: return not field in ["liquid", "essence"] or not Forming._count(relation[key][field]))):
			return false
		presses = presses or (not art.has("requires") and int(art.effect.get("liquid", 0)) > 0)
	# Without a 秘术 anyone knows that makes 灵液, the stage could not be passed.
	if not presses:
		return false
	for item_id: Variant in d.get("treasures", {}):
		var gift: Variant = d.treasures[item_id]
		if content.item(str(item_id)).is_empty() or int(content.item(str(item_id)).get("breakthrough", {}).get("realm", -1)) != 1 or not gift is Dictionary or not gift.get("text") is String:
			return false
		if ["liquid", "draw", "cap"].any(func(key: String) -> bool: return not Forming._count(gift.get(key, 0))):
			return false
	return true

# --- The stage --------------------------------------------------------------------------------------

## Opens the stage once the attempt's retreat is over (breakthrough.gd resolve): the 真元 from its odds,
## the first round's qi drawn. Returns the texts concluded.
static func begin(s, attempt_state: Dictionary, passed: Dictionary, texts: Array) -> String:
	var d := data(s)
	var treasure_id := str(attempt_state.get("treasure", ""))
	var gift: Dictionary = d.get("treasures", {}).get(treasure_id, {})
	var essence := maxi(1, int(attempt_state.get("odds", 1)))
	s.founding = {
		"round": 1, "orbs": [], "drawn": [], "liquid": int(gift.get("liquid", 0)), "essence": essence, "most": essence,
		"cap": int(d.cap) + int(gift.get("cap", 0)), "used": {},
		"certain": bool(attempt_state.get("certain", false)), "steps": int(attempt_state.get("steps", 0)), "xp": int(attempt_state.get("xp", 0)),
		"staked": str(attempt_state.get("staked", "")), "days": int(passed.get("elapsed", 0)), "treasure": treasure_id,
	}
	_draw_round(s)
	texts.append(s.log_event("founding_start", {"rounds": int(d.rounds), "essence": essence, "goal": int(d.goal)}, true))
	if not gift.is_empty():
		texts.append(str(gift.text))
	return s.conclude(" ".join(texts), passed)

static func cap(s) -> int:
	return int(s.founding.get("cap", 0))

static func over_cap(s) -> int:
	return maxi(0, s.founding.get("orbs", []).size() - cap(s))

static func round_draw(s) -> int:
	var gift: Dictionary = data(s).get("treasures", {}).get(str(s.founding.get("treasure", "")), {})
	return int(data(s).draw) + int(gift.get("draw", 0))

static func _draw_round(s) -> void:
	var drawn: Array = s.Combat._draw(s, round_draw(s), s.Combat.player_weights(s))
	s.founding.orbs.append_array(drawn)
	s.founding.drawn = drawn

# --- 秘术 ---------------------------------------------------------------------------------------------

static func known_arts(s) -> Array[String]:
	var known: Array[String] = []
	for art_id: String in data(s).arts:
		var art: Dictionary = data(s).arts[art_id]
		if not art.has("requires") or s.has_flag(str(art.requires)):
			known.append(art_id)
	return known

## The 秘术: [{"id", "art", "known"}].
static func entries(s) -> Array:
	var result: Array = []
	var known := known_arts(s)
	for art_id: String in data(s).arts:
		result.append({"id": art_id, "art": data(s).arts[art_id], "known": art_id in known})
	return result

static func cost_of(s, art_id: String) -> Dictionary:
	return data(s).arts.get(art_id, {}).get("cost", {})

static func discard_cost(s) -> int:
	return int(data(s).discard)

## Why `art_id` cannot be run now, "" when it can be paid and is allowed.
static func block(s, art_id: String) -> String:
	if s.founding.is_empty():
		return "眼下并未筑基。"
	var art: Dictionary = data(s).arts.get(art_id, {})
	if art.is_empty():
		return "没有这门秘术。"
	if not art_id in known_arts(s):
		return "还不会%s。" % art.name
	var used: Variant = s.founding.get("used", {}).get(art_id)
	if used != null and bool(art.get("once", false)):
		return "%s已经运转过了。" % art.name
	if used != null and bool(art.get("per_round", false)) and int(used) == int(s.founding.round):
		return "%s本回合已经运转过了。" % art.name
	if not s.Combat.affordable(s.founding.orbs, cost_of(s, art_id)):
		return "灵气不够：须%s。" % s.Arsenal.cost_text(s.content, cost_of(s, art_id))
	return ""

static func plan(s, art_id: String, cycle: bool = false, current: Array = []) -> Array:
	if s.founding.is_empty():
		return []
	return Forming.plan_from(s, s.founding.orbs, cost_of(s, art_id), cycle, current)

## What a payment's 生／同／克 adds ({"liquid", "essence"}) and which relations count.
static func _relation(s, art: Dictionary, payment: Array) -> Array:
	var found := QiRelations.classify(payment, s.content.rules.duel.generates)
	var extra := {}
	var met: Array[String] = []
	for key: String in found:
		if art.get("relation", {}).has(key):
			met.append(key)
			for field: String in art.relation[key]:
				extra[field] = int(extra.get(field, 0)) + int(art.relation[key][field])
	return [extra, met]

## What `payment` for `art_id` would come to, in words, without changing anything.
static func preview_words(s, art_id: String, payment: Array) -> String:
	if s.founding.is_empty() or not s.Combat.payment_valid(s.founding.orbs, cost_of(s, art_id), payment):
		return ""
	var art: Dictionary = data(s).arts[art_id]
	var relation := _relation(s, art, payment)
	var parts: Array[String] = []
	for key: String in relation[1]:
		parts.append("【%s】" % QiRelations.LABELS[key])
	var liquid := int(art.effect.get("liquid", 0)) + int(relation[0].get("liquid", 0))
	if liquid != 0:
		parts.append("灵液 %+d" % liquid)
	var essence := int(art.effect.get("essence", 0)) + int(relation[0].get("essence", 0))
	if essence != 0:
		parts.append("真元 %+d" % essence)
	if int(art.effect.get("absorb", 0)) > 0:
		parts.append("多吸 %d 颗" % int(art.effect.absorb))
	return " ".join(parts)

## Runs a 秘术 with `payment`, the player's choice of qi; an empty payment takes the automatic one.
static func cast(s, art_id: String, payment: Array = []) -> String:
	var reason := block(s, art_id)
	if not reason.is_empty():
		return reason
	var cost := cost_of(s, art_id)
	if payment.is_empty():
		payment = plan(s, art_id)
	if not s.Combat.payment_valid(s.founding.orbs, cost, payment):
		return "配气不符：须%s。" % s.Arsenal.cost_text(s.content, cost)
	for element: Variant in payment:
		s.founding.orbs.remove_at(s.founding.orbs.find(element))
	var art: Dictionary = data(s).arts[art_id]
	var relation := _relation(s, art, payment)
	s.founding.used[art_id] = int(s.founding.round)
	var liquid := int(art.effect.get("liquid", 0)) + int(relation[0].get("liquid", 0))
	s.founding.liquid = maxi(0, int(s.founding.liquid) + liquid)
	_shift(s, int(art.effect.get("essence", 0)) + int(relation[0].get("essence", 0)))
	if int(art.effect.get("absorb", 0)) > 0:
		s.founding.orbs.append_array(s.Combat._draw(s, int(art.effect.absorb), s.Combat.player_weights(s)))
	var text: String = s.log_event("founding_art", {"art_name": str(art.name), "art_text": str(art.text), "liquid": int(s.founding.liquid), "essence": int(s.founding.essence)})
	if not relation[1].is_empty():
		text += " " + "".join(relation[1].map(func(key: String) -> String: return "【%s】" % QiRelations.LABELS[key]))
	return _after(s, text)

## Lets one qi go; each costs the 真元 a little.
static func discard(s, element: String) -> String:
	if s.founding.is_empty() or not element in s.founding.get("orbs", []):
		return "丹田里没有这种灵气。"
	s.founding.orbs.remove_at(s.founding.orbs.find(element))
	_shift(s, -discard_cost(s))
	return _after(s, "散去一颗%s灵气，真元 -%d。" % [s.content.element_info(element).name, discard_cost(s)])

static func last_round(s) -> bool:
	return int(s.founding.get("round", 1)) >= int(data(s).rounds)

static func end_words(s) -> Array:
	if last_round(s):
		return ["收功筑基", "九回合已尽：灵液满 %d 便筑基成功" % int(data(s).goal)]
	return ["回合结束", "承受本回合灵压，进入下一回合"]

## The 灵压 at the end of the round under way.
static func strain(s) -> int:
	return int(data(s).strain[clampi(int(s.founding.get("round", 1)) - 1, 0, data(s).strain.size() - 1)])

## Ends the round: qi beyond what may be kept must go first (`auto_release` lets the most plentiful go);
## the round's 灵压 wears the 真元; then the next round's qi, or the foundation is settled after the last.
static func end_round(s, auto_release: bool = false) -> String:
	if s.founding.is_empty():
		return "眼下并未筑基。"
	if over_cap(s) > 0 and not auto_release:
		return "丹田只能存 %d 颗灵气：先散去 %d 颗，或用秘术耗去。" % [cap(s), over_cap(s)]
	var texts: Array[String] = []
	while over_cap(s) > 0:
		var most := ""
		for element: String in s.founding.orbs:
			if most.is_empty() or s.founding.orbs.count(element) > s.founding.orbs.count(most):
				most = element
		texts.append(discard(s, most))
		if s.founding.is_empty():
			return " ".join(texts)
	if strain(s) > 0:
		_shift(s, -strain(s))
		texts.append("灵压冲刷经脉，真元 -%d。" % strain(s))
	if int(s.founding.essence) <= 0:
		return _broken(s, " ".join(texts))
	s.founding.round = int(s.founding.round) + 1
	if int(s.founding.round) > int(data(s).rounds):
		return _settle(s, " ".join(texts))
	_draw_round(s)
	texts.append("第 %d 回合：吸入 %d 颗灵气（灵液 %d / %d）。" % [int(s.founding.round), s.founding.drawn.size(), int(s.founding.liquid), int(data(s).goal)])
	s.changed.emit()
	return " ".join(texts)

## Changes the 真元, never above where it started; a certain attempt (残魂灌顶) cannot fall to none.
static func _shift(s, amount: int) -> void:
	var floor_value := 1 if bool(s.founding.get("certain", false)) else 0
	s.founding.essence = clampi(int(s.founding.essence) + amount, floor_value, int(s.founding.most))

static func _after(s, text: String) -> String:
	if int(s.founding.essence) <= 0:
		return _broken(s, text)
	s.changed.emit()
	return text

## The grade the 灵液 makes now (index into rules.breakthrough.grades), before fortune and talents; -1
## short of the goal.
static func grade_now(s, stage: Dictionary = {}) -> int:
	if stage.is_empty():
		stage = s.founding
	var grade := -1
	var lines: Array = data(s).grades
	for index: int in lines.size():
		if int(stage.get("liquid", 0)) >= int(lines[index]):
			grade = index
	return grade

## The last round is over: the 灵液 at the goal or past it lays the foundation; short of it, the attempt
## fails, unless it was certain (残魂灌顶), which lays a middling one.
static func _settle(s, told: String) -> String:
	var stage: Dictionary = s.founding
	s.founding = {}
	var texts: Array = [told] if not told.is_empty() else []
	var grade := grade_now(s, stage)
	if grade < 0 and not bool(stage.certain):
		texts.append(s.log_event("founding_short", {"liquid": int(stage.liquid), "goal": int(data(s).goal)}, true))
		return s.Breakthrough._fail(s, int(stage.xp), texts, {"elapsed": int(stage.days)}, 1, str(stage.staked))
	if bool(stage.certain):
		grade = maxi(1, grade)
	var grades: Array = s.content.rules.breakthrough.grades
	grade = clampi(grade + int(stage.steps) + s.Breakthrough.talent_steps(s), 0, grades.size() - 1)
	texts.append(s.log_event("founding_done", {"liquid": int(stage.liquid)}, true))
	return s.Breakthrough.core_formed(s, grade, int(stage.days), int(stage.xp), str(stage.staked), texts)

## The 真元 gave way: the 灵液 scatters and the attempt fails.
static func _broken(s, told: String) -> String:
	var stage: Dictionary = s.founding
	s.founding = {}
	var texts: Array = [told] if not told.is_empty() else []
	texts.append(s.log_event("founding_broken", {"liquid": int(stage.liquid)}, true))
	return s.Breakthrough._fail(s, int(stage.xp), texts, {"elapsed": int(stage.days)}, 1, str(stage.staked))

# --- The plain policy (速成, the playtest, tests) -------------------------------------------------------

## One decision of the plain policy; false when only ending the round is left. Presses four of a kind,
## then pairs, then three that generate each other; draws more while the 真元 is ample, shores it up when
## it runs low, and lets nothing overflow that a 秘术 could use.
static func plain_step(s) -> bool:
	if s.founding.is_empty():
		return false
	var share := int(s.founding.essence) * 100 / maxi(1, int(s.founding.most))
	if share < 40 and block(s, "tiaoxi").is_empty():
		cast(s, "tiaoxi")
		return true
	if share > 50 and block(s, "yasuo").is_empty():
		cast(s, "yasuo")
		return true
	if block(s, "ningye").is_empty():
		cast(s, "ningye")
		return true
	if share > 60 and block(s, "yinqi").is_empty() and int(s.founding.round) < int(data(s).rounds):
		cast(s, "yinqi")
		return true
	if s.founding.orbs.size() > cap(s) and block(s, "huaqi").is_empty():
		cast(s, "huaqi")
		return true
	# The last round keeps nothing: what is held might as well become 灵液.
	if last_round(s) and block(s, "huaqi").is_empty():
		cast(s, "huaqi")
		return true
	return false

## Plays the rest of the stage by the plain policy. Returns the texts.
static func auto(s) -> String:
	var texts: Array[String] = []
	var guard := 0
	while not s.founding.is_empty() and guard < 200:
		guard += 1
		if plain_step(s):
			continue
		texts.append(end_round(s, true))
	return " ".join(texts.filter(func(text: String) -> bool: return not text.is_empty()))

# --- Saves ------------------------------------------------------------------------------------------

## A saved stage is well formed (save_restore.gd); null when malformed, else the normalized copy.
static func valid_state(content, saved: Variant) -> Variant:
	if not saved is Dictionary:
		return null
	if saved.is_empty():
		return {}
	var d: Dictionary = content.forming_data.get("foundation", {})
	var counts := ["round", "liquid", "essence", "most", "cap", "steps", "xp", "days"]
	for key: String in counts:
		if not Forming._count(saved.get(key)) or float(saved[key]) > 1000000000.0:
			return null
	if int(saved.round) < 1 or int(saved.round) > int(d.rounds) or int(saved.most) < 1 or int(saved.essence) < 1 or int(saved.essence) > int(saved.most) or int(saved.cap) > 1000:
		return null
	if not saved.get("certain") is bool or not saved.get("staked") is String or not saved.get("treasure") is String:
		return null
	if not saved.treasure.is_empty() and content.item(saved.treasure).is_empty():
		return null
	for key: String in ["orbs", "drawn"]:
		if not saved.get(key) is Array or saved[key].size() > 1000 or saved[key].any(func(element: Variant) -> bool: return not content.technique_data.elements.has(element)):
			return null
	var used: Variant = saved.get("used")
	if not used is Dictionary or used.keys().any(func(art_id: Variant) -> bool: return not d.arts.has(art_id) or not Forming._count(used[art_id]) or int(used[art_id]) > int(saved.round)):
		return null
	var result: Dictionary = saved.duplicate(true)
	for key: String in counts:
		result[key] = int(saved[key])
	for art_id: String in result.used:
		result.used[art_id] = int(result.used[art_id])
	return result
