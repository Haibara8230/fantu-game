extends RefCounted
## 结丹 as a stage played with qi (docs/MCS_SYSTEMS_GAP_20261026.md A1), after 《觅长生》: once the
## attempt's retreat is over, nine rounds of drawing qi by the spirit roots (combat.gd's weights). The
## early rounds only gather and run the 周天 (秘术, data/forming.json `arts`, paid like arts in a duel);
## from `condense_from` on, three qi of one element condense into a 灵珠. The pearls make the 金丹: how
## many sets its grade (one pearl 九品, nine 一品, raised by the steps the attempt earned), their
## elements its kind (纯属性 / 双属性 / 混元), which opens every later duel with more qi.
## 道基 (stability) starts at the attempt's odds: the strain of each round, qi let go and a pearl that
## overcomes the one before wear it down; 调息 and a pearl that the one before generates shore it up.
## At none the attempt fails as before (breakthrough.gd _fail). No pills are taken (金丹 on asks none).
## Operates on a Session; s.forming holds the stage under way, {} otherwise.
const QiRelations = preload("res://scripts/core/qi_relations.gd")
const PEARL := "pearl"
const EFFECTS := ["stability", "absorb", "condense_draw", "draw", "cap", "next"]

static func data(s) -> Dictionary:
	return s.content.forming_data.core

## Whether breaking through to `target` is played as this stage.
static func applies(target: int) -> bool:
	return target == 2

static func valid_data(content) -> bool:
	var d: Variant = content.forming_data.get("core")
	if not d is Dictionary:
		return false
	for key: String in ["rounds", "condense_from", "draw", "cap", "discard"]:
		if not _count(d.get(key)):
			return false
	if int(d.condense_from) < 1 or int(d.condense_from) > int(d.rounds):
		return false
	if not d.get("cap_by_foundation") is Array or d.cap_by_foundation.size() != content.rules.breakthrough.grades.size() or d.cap_by_foundation.any(func(value: Variant) -> bool: return not _signed(value)):
		return false
	if not d.get("strain") is Array or d.strain.size() != int(d.rounds) or d.strain.any(func(value: Variant) -> bool: return not _count(value)):
		return false
	var pearl: Variant = d.get("pearl")
	if not pearl is Dictionary or not _valid_cost(pearl.get("cost")) or not _count(pearl.get("most")) or int(pearl.most) < 1 or int(pearl.most) > content.rules.breakthrough.core.grades.size():
		return false
	var link: Variant = d.get("link")
	if not link is Dictionary or ["generate", "same", "overcome"].any(func(key: String) -> bool: return not _signed(link.get(key))):
		return false
	if not d.get("phases") is Array or d.phases.is_empty() or d.phases.any(func(phase: Variant) -> bool: return not phase is Dictionary or not _count(phase.get("from")) or not phase.get("name") is String or not phase.get("text") is String):
		return false
	var kinds: Variant = d.get("kinds")
	if not kinds is Dictionary or ["pure", "dual", "mixed"].any(func(key: String) -> bool: return not kinds.get(key) is Dictionary or not kinds[key].get("name") is String or not kinds[key].get("text") is String or not _count(kinds[key].get("opening", 0))):
		return false
	if not _count(kinds.pure.get("least")) or not _count(kinds.dual.get("least")) or not _count(kinds.pure.get("weight", 0)):
		return false
	var arts: Variant = d.get("arts")
	if not arts is Dictionary or arts.is_empty() or arts.has(PEARL):
		return false
	for art_id: String in arts:
		var art: Variant = arts[art_id]
		if not art is Dictionary or not art.get("name") is String or not art.get("text") is String or not _valid_cost(art.get("cost")) or not art.get("effect") is Dictionary or art.effect.is_empty():
			return false
		for key: Variant in art.effect:
			if not key in EFFECTS or not _signed(art.effect[key]):
				return false
		if art.has("requires") and not art.requires in content.world_flags:
			return false
		if art.has("on_payment") and not QiRelations.valid(art.on_payment, content.technique_data.elements):
			return false
	for item_id: Variant in d.get("treasures", {}):
		var gift: Variant = d.treasures[item_id]
		if content.item(str(item_id)).is_empty() or int(content.item(str(item_id)).get("breakthrough", {}).get("realm", -1)) != 2 or not gift is Dictionary or not gift.get("text") is String:
			return false
		if not _count(gift.get("draw", 0)) or not gift.get("opening", {}) is Dictionary or gift.get("opening", {}).keys().any(func(element: Variant) -> bool: return not content.technique_data.elements.has(element) or not _count(gift.opening[element])):
			return false
	return true

static func _count(value: Variant) -> bool:
	return (value is int or value is float) and float(value) == floor(float(value)) and float(value) >= 0.0

static func _signed(value: Variant) -> bool:
	return (value is int or value is float) and float(value) == floor(float(value))

static func _valid_cost(cost: Variant) -> bool:
	if not cost is Dictionary or cost.is_empty():
		return false
	for key: Variant in cost:
		if not key in ["metal", "wood", "water", "fire", "earth", "same", "any"] or not _count(cost[key]) or int(cost[key]) < 1:
			return false
	return true

# --- The stage --------------------------------------------------------------------------------------

## Opens the stage once the attempt's retreat is over (breakthrough.gd resolve): the 道基 from its odds,
## the first round's qi drawn. Returns the texts concluded.
static func begin(s, attempt_state: Dictionary, passed: Dictionary, texts: Array) -> String:
	var d := data(s)
	var foundation := clampi(int(s.player.get("foundation_grade", 1)), 0, d.cap_by_foundation.size() - 1)
	s.forming = {
		"round": 1, "orbs": [], "pearls": [], "stability": maxi(1, int(attempt_state.get("odds", 1))), "most": maxi(1, int(attempt_state.get("odds", 1))),
		"certain": bool(attempt_state.get("certain", false)), "steps": int(attempt_state.get("steps", 0)), "xp": int(attempt_state.get("xp", 0)),
		"staked": str(attempt_state.get("staked", "")), "days": int(passed.get("elapsed", 0)), "treasure": str(attempt_state.get("treasure", "")),
		"cap": int(d.cap) + int(d.cap_by_foundation[foundation]), "used": {}, "boost": {"draw": 0, "condense_draw": 0, "next": 0},
	}
	var gift := treasure(s)
	for element: String in gift.get("opening", {}):
		for count: int in int(gift.opening[element]):
			s.forming.orbs.append(element)
	_draw_round(s)
	texts.append(s.log_event("forming_start", {"rounds": int(d.rounds), "stability": int(s.forming.stability)}, true))
	if not gift.is_empty():
		texts.append(str(gift.text))
	return s.conclude(" ".join(texts), passed)

## What the 天材地宝 taken in does in the stage ({"draw", "opening", "text"}), or {}.
static func treasure(s) -> Dictionary:
	return data(s).get("treasures", {}).get(str(s.forming.get("treasure", "")), {})

## The phase of the round under way: {"from", "name", "text"}.
static func phase(s) -> Dictionary:
	var current: Dictionary = data(s).phases[0]
	for entry: Dictionary in data(s).phases:
		if int(s.forming.get("round", 1)) >= int(entry.from):
			current = entry
	return current

static func condensing(s) -> bool:
	return int(s.forming.get("round", 1)) >= int(data(s).condense_from)

## How many qi may be kept at the end of a round.
static func cap(s) -> int:
	return int(s.forming.get("cap", int(data(s).cap)))

static func over_cap(s) -> int:
	return maxi(0, s.forming.get("orbs", []).size() - cap(s))

## How many qi the next round brings.
static func round_draw(s) -> int:
	var boost: Dictionary = s.forming.get("boost", {})
	var count := int(data(s).draw) + int(boost.get("draw", 0)) + int(treasure(s).get("draw", 0)) + int(boost.get("next", 0))
	if int(s.forming.round) >= int(data(s).condense_from):
		count += int(boost.get("condense_draw", 0))
	return count

static func _draw_round(s) -> void:
	var drawn: Array = s.Combat._draw(s, round_draw(s), s.Combat.player_weights(s))
	s.forming.boost.next = 0
	s.forming.orbs.append_array(drawn)
	s.forming["drawn"] = drawn

# --- 秘术 ---------------------------------------------------------------------------------------------

## The 秘术 the player can run here, in the order written: the base ones, and those the 凝丹之法 teaches.
static func known_arts(s) -> Array[String]:
	var known: Array[String] = []
	for art_id: String in data(s).arts:
		var art: Dictionary = data(s).arts[art_id]
		if not art.has("requires") or s.has_flag(str(art.requires)):
			known.append(art_id)
	return known

## Every 秘术 with whether it is known: [{"id", "art", "known"}], for the screen to show what is missing.
static func all_arts(s) -> Array[Dictionary]:
	var result: Array[Dictionary] = []
	var known := known_arts(s)
	for art_id: String in data(s).arts:
		result.append({"id": art_id, "art": data(s).arts[art_id], "known": art_id in known})
	return result

## The cost of a 秘术, or of condensing a pearl.
static func cost_of(s, art_id: String) -> Dictionary:
	return data(s).pearl.cost if art_id == PEARL else data(s).arts.get(art_id, {}).get("cost", {})

## Why `art_id` (a 秘术, or "pearl") cannot be run now, "" when it can be paid and is allowed.
static func block(s, art_id: String) -> String:
	if s.forming.is_empty():
		return "眼下并未结丹。"
	if art_id == PEARL:
		if not condensing(s):
			return "第 %d 回合起方能凝液成丹。" % int(data(s).condense_from)
		if s.forming.pearls.size() >= int(data(s).pearl.most):
			return "灵珠已满，金丹之形已定。"
	else:
		var art: Dictionary = data(s).arts.get(art_id, {})
		if art.is_empty():
			return "没有这门秘术。"
		if not art_id in known_arts(s):
			return "须懂凝丹之法，方能运转%s。" % art.name
		var used: Variant = s.forming.get("used", {}).get(art_id)
		if used != null and bool(art.get("once", false)):
			return "%s已经运转过了。" % art.name
		if used != null and bool(art.get("per_round", false)) and int(used) == int(s.forming.round):
			return "%s本回合已经运转过了。" % art.name
	if not s.Combat.affordable(s.forming.orbs, cost_of(s, art_id)):
		return "灵气不够：须%s。" % s.Arsenal.cost_text(s.content, cost_of(s, art_id))
	return ""

## A payment chosen for the player: the remembered one (`current`) while it still fits, else the
## named elements first, then 同 from the most plentiful, then any. `cycle` steps to the next choice.
static func plan(s, art_id: String, cycle: bool = false, current: Array = []) -> Array:
	if s.forming.is_empty():
		return []
	return plan_from(s, s.forming.orbs, cost_of(s, art_id), cycle, current)

## The same for any qi held (`orbs`) and `cost`, shared with 结婴 (nascent.gd).
static func plan_from(s, orbs: Array, cost: Dictionary, cycle: bool, current: Array) -> Array:
	if not s.Combat.affordable(orbs, cost):
		return []
	if not cycle and not current.is_empty() and s.Combat.payment_valid(orbs, cost, current):
		return current.duplicate()
	var plans: Array = []
	for shift: int in maxi(1, orbs.size()):
		var hand: Array = orbs.slice(shift) + orbs.slice(0, shift)
		var choice: Array = s.Combat._pay(hand, cost)
		choice.sort()
		if not choice in plans:
			plans.append(choice)
	var sorted := current.duplicate()
	sorted.sort()
	var at := plans.find(sorted)
	return plans[(at + 1) % plans.size()].duplicate() if cycle else plans[0].duplicate()

## What `payment` for `art_id` would come to, without changing anything: {"stability", "relation"
## (生／同／克 of a pearl with the one before), "element" (the pearl's), "triggers"}.
static func preview(s, art_id: String, payment: Array) -> Dictionary:
	var result := {"stability": 0, "relation": "", "element": "", "triggers": []}
	if s.forming.is_empty() or not s.Combat.payment_valid(s.forming.orbs, cost_of(s, art_id), payment):
		return result
	if art_id == PEARL:
		var element := str(payment[0])
		result.element = element
		result.relation = link_of(s, element)
		if not result.relation.is_empty():
			result.stability = int(data(s).link[result.relation])
		return result
	var art: Dictionary = data(s).arts[art_id]
	var cycle: Dictionary = s.content.rules.duel.generates
	result.stability = int(art.effect.get("stability", 0)) + int(QiRelations.effect(art, payment, cycle).get("heal", 0))
	result.triggers = QiRelations.triggers(art, payment, cycle)
	return result

## What the stage's screen asks of a stage (stage_panels.gd, shared with nascent.gd): the measure that
## qi let go wears down and what it costs, the choices to pay for, a payment's outcome in words, and
## whether this is the last round.
const MEASURE := "道基"

static func state(s) -> Dictionary:
	return s.forming

static func discard_cost(s) -> int:
	return int(data(s).discard)

## 凝珠 and the 秘术: [{"id", "art" ({"name", "cost", "text"}), "known"}].
static func entries(s) -> Array:
	var d := data(s)
	var result: Array = [{"id": PEARL, "art": {"name": "凝珠", "cost": d.pearl.cost, "text": "三颗同属灵气凝成一颗灵珠。与上一颗相生，道基 +%d；相克，道基 %d。" % [int(d.link.generate), int(d.link.overcome)]}, "known": true}]
	result.append_array(all_arts(s))
	return result

static func preview_words(s, art_id: String, payment: Array) -> String:
	var found := preview(s, art_id, payment)
	var parts: Array[String] = []
	for key: String in found.triggers:
		parts.append("【%s】" % QiRelations.LABELS[key])
	if art_id == PEARL and not str(found.relation).is_empty():
		parts.append("与上一颗%s" % {"generate": "相生", "same": "同属", "overcome": "相克"}[found.relation])
	if int(found.stability) != 0:
		parts.append("道基 %+d" % int(found.stability))
	return " ".join(parts)

static func last_round(s) -> bool:
	return int(s.forming.get("round", 1)) >= int(data(s).rounds)

static func end_words(s) -> Array:
	return ["收功成丹", "九回合已尽：以已凝的灵珠成丹"] if last_round(s) else ["回合结束", "承受本回合灵压，进入下一回合"]

## How a pearl of `element` meets the last pearl: "generate", "same", "overcome", or "" for the first.
static func link_of(s, element: String) -> String:
	var pearls: Array = s.forming.get("pearls", [])
	if pearls.is_empty():
		return ""
	var found := QiRelations.classify([str(pearls.back()), element], s.content.rules.duel.generates)
	return found[0] if not found.is_empty() else ""

## Runs a 秘术 (or condenses a pearl, art_id "pearl") with `payment`, the player's choice of qi; an empty
## payment takes the automatic one.
static func cast(s, art_id: String, payment: Array = []) -> String:
	var reason := block(s, art_id)
	if not reason.is_empty():
		return reason
	var cost := cost_of(s, art_id)
	if payment.is_empty():
		payment = plan(s, art_id)
	if not s.Combat.payment_valid(s.forming.orbs, cost, payment):
		return "配气不符：须%s。" % s.Arsenal.cost_text(s.content, cost)
	for element: Variant in payment:
		s.forming.orbs.remove_at(s.forming.orbs.find(element))
	var told := preview_after_pay(s, art_id, payment)
	var text := ""
	if art_id == PEARL:
		var element := str(payment[0])
		var relation := link_of(s, element)
		s.forming.pearls.append(element)
		_shift(s, int(data(s).link.get(relation, 0)) if not relation.is_empty() else 0)
		text = s.log_event("forming_pearl", {"element": s.content.element_info(element).name, "count": s.forming.pearls.size(), "link": {"generate": "，与上一颗相生，道基更稳", "same": "", "overcome": "，与上一颗相克，道基受冲撞"}.get(relation, ""), "stability": int(s.forming.stability)})
	else:
		var art: Dictionary = data(s).arts[art_id]
		s.forming.used[art_id] = int(s.forming.round)
		for key: String in art.effect:
			var amount := int(art.effect[key])
			match key:
				"stability":
					_shift(s, amount)
				"absorb":
					var drawn: Array = s.Combat._draw(s, amount, s.Combat.player_weights(s))
					s.forming.orbs.append_array(drawn)
				"cap":
					s.forming.cap = int(s.forming.cap) + amount
				_:
					s.forming.boost[key] = int(s.forming.boost.get(key, 0)) + amount
		var paid: Dictionary = QiRelations.effect(art, payment, s.content.rules.duel.generates)
		if paid.has("heal"):
			_shift(s, int(paid.heal))
		if paid.has("gather"):
			s.forming.boost.next = int(s.forming.boost.next) + int(paid.gather)
		if paid.has("absorb"):
			for count: int in int(paid.absorb[1]):
				s.forming.orbs.append(str(paid.absorb[0]))
		text = s.log_event("forming_art", {"art_name": str(art.name), "art_text": str(art.text), "stability": int(s.forming.stability)})
	if not told.is_empty():
		text += " " + told
	return _after(s, text)

## Words for the triggers of a payment (【生】 and the like), "" when none.
static func preview_after_pay(s, art_id: String, payment: Array) -> String:
	if art_id == PEARL:
		return ""
	var triggers := QiRelations.triggers(data(s).arts[art_id], payment, s.content.rules.duel.generates)
	return "".join(triggers.map(func(key: String) -> String: return "【%s】" % QiRelations.LABELS[key]))

## Lets one qi go; each costs the 道基 a little.
static func discard(s, element: String) -> String:
	if s.forming.is_empty() or not element in s.forming.get("orbs", []):
		return "丹田里没有这种灵气。"
	s.forming.orbs.remove_at(s.forming.orbs.find(element))
	_shift(s, -int(data(s).discard))
	return _after(s, "散去一颗%s灵气，经脉一震，道基 -%d。" % [s.content.element_info(element).name, int(data(s).discard)])

## Ends the round: qi beyond what may be kept must go first (`auto_release` lets the most plentiful go);
## the round's strain wears the 道基; then the next round's qi, or the core is settled after the last.
static func end_round(s, auto_release: bool = false) -> String:
	if s.forming.is_empty():
		return "眼下并未结丹。"
	if over_cap(s) > 0 and not auto_release:
		return "丹田只能存 %d 颗灵气：先散去 %d 颗，或用秘术耗去。" % [cap(s), over_cap(s)]
	var texts: Array[String] = []
	while over_cap(s) > 0:
		var most := ""
		for element: String in s.forming.orbs:
			if most.is_empty() or s.forming.orbs.count(element) > s.forming.orbs.count(most):
				most = element
		texts.append(discard(s, most))
		if s.forming.is_empty():
			return " ".join(texts)
	var strain := int(data(s).strain[int(s.forming.round) - 1])
	if strain > 0:
		_shift(s, -strain)
		texts.append("灵压冲刷经脉，道基 -%d。" % strain)
	if int(s.forming.stability) <= 0:
		return _broken(s, " ".join(texts))
	s.forming.round = int(s.forming.round) + 1
	if int(s.forming.round) > int(data(s).rounds):
		return _settle(s, " ".join(texts))
	_draw_round(s)
	texts.append("第 %d 回合 · %s：吸入 %d 颗灵气。" % [int(s.forming.round), str(phase(s).name), s.forming.drawn.size()])
	s.changed.emit()
	return " ".join(texts)

## Changes the 道基, never above where it started; a certain attempt (残魂灌顶) cannot fall to none.
static func _shift(s, amount: int) -> void:
	var floor_value := 1 if bool(s.forming.get("certain", false)) else 0
	s.forming.stability = clampi(int(s.forming.stability) + amount, floor_value, int(s.forming.most))

static func _after(s, text: String) -> String:
	if int(s.forming.stability) <= 0:
		return _broken(s, text)
	s.changed.emit()
	return text

## The kind of core the pearls make: {"id": "pure"|"dual"|"mixed", "elements"}; {} for no pearls.
static func kind_of(s, pearls: Array) -> Dictionary:
	if pearls.is_empty():
		return {}
	var kinds: Dictionary = data(s).kinds
	var counts := {}
	for element: Variant in pearls:
		counts[element] = int(counts.get(element, 0)) + 1
	var order: Array = counts.keys()
	order.sort_custom(func(a: String, b: String) -> bool: return int(counts[a]) > int(counts[b]) or (int(counts[a]) == int(counts[b]) and a < b))
	if int(counts[order[0]]) >= int(kinds.pure.least):
		return {"id": "pure", "elements": [order[0]]}
	if order.size() >= 2 and int(counts[order[1]]) >= int(kinds.dual.least):
		return {"id": "dual", "elements": [order[0], order[1]]}
	return {"id": "mixed", "elements": []}

## "纯火金丹" and the like.
static func kind_name(s, kind: Dictionary) -> String:
	if kind.is_empty():
		return ""
	var names: Array = kind.get("elements", []).map(func(element: String) -> String: return str(s.content.element_info(element).name))
	match str(kind.id):
		"pure":
			return "纯%s金丹" % names[0]
		"dual":
			return "%s%s双属性金丹" % names
	return str(data(s).kinds.mixed.name)

## The grade the pearls held now would make (index into the core grades), before the talents' chance.
static func grade_now(s) -> int:
	var grades: int = s.content.rules.breakthrough.core.grades.size()
	return clampi(s.forming.get("pearls", []).size() - 1 + int(s.forming.get("steps", 0)), 0, grades - 1)

## The last round is over: with a pearl or more the core is formed (its 天劫 still to come), else the
## attempt fails.
static func _settle(s, told: String) -> String:
	var state: Dictionary = s.forming
	s.forming = {}
	var texts: Array = [told] if not told.is_empty() else []
	var pearls: Array = state.pearls
	if pearls.is_empty() and not bool(state.certain):
		texts.append(s.log_event("forming_empty", {}, true))
		return s.Breakthrough._fail(s, int(state.xp), texts, {"elapsed": int(state.days)}, 1, str(state.staked))
	var grades: int = s.content.rules.breakthrough.core.grades.size()
	var grade := clampi(pearls.size() - 1 + int(state.steps) + s.Breakthrough.talent_steps(s), 0, grades - 1)
	var kind := kind_of(s, pearls)
	if kind.is_empty():
		kind = {"id": "mixed", "elements": []}
	s.player["core_kind"] = kind
	texts.append(s.log_event("forming_done", {"pearls": pearls.size(), "kind": kind_name(s, kind)}, true))
	return s.Breakthrough.core_formed(s, grade, int(state.days), int(state.xp), str(state.staked), texts)

## The 道基 gave way: the qi scatters and the attempt fails.
static func _broken(s, told: String) -> String:
	var state: Dictionary = s.forming
	s.forming = {}
	var texts: Array = [told] if not told.is_empty() else []
	texts.append(s.log_event("forming_broken", {"pearls": state.pearls.size()}, true))
	return s.Breakthrough._fail(s, int(state.xp), texts, {"elapsed": int(state.days)}, 1, str(state.staked))

# --- The plain policy (速成, the playtest, tests) -------------------------------------------------------

## One decision of the plain policy; false when only ending the round is left. Builds the 周天 early
## (the lasting ones first), shores the 道基 with 调息 when it runs low, condenses the pearl that best
## follows the last one, and lets nothing overflow that a 秘术 could use.
static func plain_step(s) -> bool:
	if s.forming.is_empty():
		return false
	var low := int(s.forming.stability) * 100 / maxi(1, int(s.forming.most)) < 45
	if condensing(s):
		if low and block(s, "tiaoxi").is_empty() and s.forming.orbs.size() - 2 >= 3:
			cast(s, "tiaoxi")
			return true
		var best := ""
		var best_score := -1000
		for element: String in ["metal", "wood", "water", "fire", "earth"]:
			if s.forming.orbs.count(element) < 3 or not block(s, PEARL).is_empty():
				continue
			var relation := link_of(s, element)
			var score := int(data(s).link.get(relation, 0)) if not relation.is_empty() else 0
			# Toward a 纯 core: the element most held is worth a little more.
			score += s.forming.pearls.count(element)
			if score > best_score:
				best = element
				best_score = score
		if not best.is_empty() and (best_score > int(data(s).link.overcome) or int(s.forming.stability) > -int(data(s).link.overcome) * 2):
			cast(s, PEARL, [best, best, best])
			return true
		for art_id: String in ["nixing", "xiao_zhoutian"]:
			if block(s, art_id).is_empty() and (art_id != "nixing" or int(s.forming.stability) > 20):
				cast(s, art_id)
				return true
	else:
		for art_id: String in ["da_zhoutian", "baoyuan", "xiao_zhoutian"]:
			if block(s, art_id).is_empty():
				cast(s, art_id)
				return true
	if (low or over_cap(s) >= 2) and block(s, "tiaoxi").is_empty():
		cast(s, "tiaoxi")
		return true
	return false

## Plays the rest of the stage by the plain policy. Returns the texts.
static func auto(s) -> String:
	var texts: Array[String] = []
	var guard := 0
	while not s.forming.is_empty() and guard < 200:
		guard += 1
		if plain_step(s):
			continue
		texts.append(end_round(s, true))
	return " ".join(texts.filter(func(text: String) -> bool: return not text.is_empty()))

# --- What the core does in a duel (combat.gd) ---------------------------------------------------------

## The player's core kind once formed, {} before.
static func core_kind(s) -> Dictionary:
	if int(s.player.get("realm", 0)) < 2:
		return {}
	return s.player.get("core_kind", {})

## The qi a duel opens with for the core: two of a 纯 core's element, one of each of a 双 core's, or two
## drawn by the roots for a 混元 one.
static func opening_orbs(s) -> Array:
	var kind := core_kind(s)
	if kind.is_empty():
		return []
	var entry: Dictionary = data(s).kinds.get(str(kind.id), {})
	var count := int(entry.get("opening", 0))
	if str(kind.id) == "mixed":
		return s.Combat._draw(s, count, s.Combat.player_weights(s))
	var result: Array = []
	for element: Variant in kind.get("elements", []):
		for index: int in count:
			result.append(str(element))
	return result

## The draw weight a 纯 core adds to its element.
static func weight(s, element: String) -> int:
	var kind := core_kind(s)
	if kind.is_empty() or str(kind.id) != "pure" or not element in kind.get("elements", []):
		return 0
	return int(data(s).kinds.pure.get("weight", 0))

## A saved core kind is well formed: {"id", "elements"} of the right count.
static func valid_kind(content, kind: Variant) -> bool:
	if not kind is Dictionary:
		return false
	if kind.is_empty():
		return true
	if not kind.get("id") in ["pure", "dual", "mixed"] or not kind.get("elements") is Array:
		return false
	var wanted: int = {"pure": 1, "dual": 2, "mixed": 0}[kind.id]
	if kind.elements.size() != wanted:
		return false
	for element: Variant in kind.elements:
		if not content.technique_data.elements.has(element) or kind.elements.count(element) != 1:
			return false
	return true

## A saved stage is well formed (save_restore.gd): its round, qi, pearls, 道基 and boosts; null when
## malformed, else the normalized copy.
static func valid_state(content, saved: Variant) -> Variant:
	if not saved is Dictionary:
		return null
	if saved.is_empty():
		return {}
	var d: Dictionary = content.forming_data.get("core", {})
	for key: String in ["round", "stability", "most", "steps", "xp", "days", "cap"]:
		if not _count(saved.get(key)):
			return null
	if int(saved.round) < 1 or int(saved.round) > int(d.rounds) or int(saved.most) < 1 or int(saved.stability) < 1 or int(saved.stability) > int(saved.most) or int(saved.cap) > 1000:
		return null
	if not saved.get("certain") is bool or not saved.get("staked") is String or not saved.get("treasure") is String:
		return null
	if not saved.treasure.is_empty() and not d.get("treasures", {}).has(saved.treasure) and content.item(saved.treasure).is_empty():
		return null
	for key: String in ["orbs", "pearls"]:
		if not saved.get(key) is Array or saved[key].size() > 1000 or saved[key].any(func(element: Variant) -> bool: return not content.technique_data.elements.has(element)):
			return null
	if saved.pearls.size() > int(d.pearl.most):
		return null
	var used: Variant = saved.get("used")
	if not used is Dictionary or used.keys().any(func(art_id: Variant) -> bool: return not d.arts.has(art_id) or not _count(used[art_id]) or int(used[art_id]) > int(saved.round)):
		return null
	var boost: Variant = saved.get("boost")
	if not boost is Dictionary or boost.keys().any(func(key: Variant) -> bool: return not key in ["draw", "condense_draw", "next"] or not _count(boost[key]) or int(boost[key]) > 1000):
		return null
	var result: Dictionary = saved.duplicate(true)
	for key: String in ["round", "stability", "most", "steps", "xp", "days", "cap"]:
		result[key] = int(saved[key])
	for art_id: String in result.used:
		result.used[art_id] = int(result.used[art_id])
	for key: String in ["draw", "condense_draw", "next"]:
		result.boost[key] = int(boost.get(key, 0))
	var drawn: Variant = saved.get("drawn", [])
	result.drawn = drawn if drawn is Array and drawn.all(func(element: Variant) -> bool: return content.technique_data.elements.has(element)) else []
	return result
