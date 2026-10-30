extends RefCounted
## 化神 as a stage played with qi (docs/MCS_SYSTEMS_GAP_20261026.md A1), after 《觅长生》's 化神: a 道 of the
## 悟道 (dao.gd) far enough along is chosen to merge with (合道); once the attempt's retreat is over, qi
## drawn by the roots each round, as in the stages before, runs the 法 (data/forming.json
## `deity.arts`). 仙性 must reach `goal` before 凡性 does: 凡性 rises at every round's end (`strain`,
## its last value repeating) and with 淬体 and 塑魂, which make the body and the 神识 of the 化神
## stronger (player.deity: {"dao", "temper", "soul"}). 仙性 starts from the attempt's odds
## (`odds_per` of them to a point), the 道's stage (`dao.bonus`), a 天材地宝 and the steps fortune
## promised. 凡性 at the goal first fails the attempt as before (breakthrough.gd _fail).
## Operates on a Session; s.deifying holds the stage under way, {} otherwise.
const Forming = preload("res://scripts/core/forming.gd")
const QiRelations = preload("res://scripts/core/qi_relations.gd")
const MEASURE := "凡性"
const EFFECTS := ["immortal", "mortal", "temper", "soul"]
const STEP := 5

static func data(s) -> Dictionary:
	return s.content.forming_data.deity

static func state(s) -> Dictionary:
	return s.deifying

## Whether breaking through to `target` is played as this stage.
static func applies(target: int) -> bool:
	return target == 4

static func valid_data(content) -> bool:
	var d: Variant = content.forming_data.get("deity")
	if not d is Dictionary:
		return false
	for key: String in ["draw", "cap", "discard", "goal", "odds_per"]:
		if not Forming._count(d.get(key)):
			return false
	if int(d.goal) < 1 or int(d.odds_per) < 1:
		return false
	var dao: Variant = d.get("dao")
	var stages: int = content.dao_data.stages.size()
	if not dao is Dictionary or not Forming._count(dao.get("least")) or int(dao.least) < 1 or int(dao.least) > stages or not dao.get("bonus") is Array or dao.bonus.size() != stages + 1 or dao.bonus.any(func(value: Variant) -> bool: return not Forming._count(value)):
		return false
	if not d.get("strain") is Array or d.strain.is_empty() or d.strain.any(func(value: Variant) -> bool: return not Forming._count(value)):
		return false
	var rewards: Variant = d.get("rewards")
	if not rewards is Dictionary or not Forming._count(rewards.get("temper_hp")) or not Forming._count(rewards.get("soul_sense")):
		return false
	var arts: Variant = d.get("arts")
	if not arts is Dictionary or arts.is_empty():
		return false
	var rises := false
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
		if not relation is Dictionary or relation.keys().any(func(key: Variant) -> bool: return not QiRelations.LABELS.has(key) or not relation[key] is Dictionary or relation[key].keys().any(func(field: Variant) -> bool: return not field in ["immortal", "mortal"] or not Forming._signed(relation[key][field]))):
			return false
		rises = rises or (not art.has("requires") and int(art.effect.get("immortal", 0)) > 0)
	# Without a 法 anyone knows that raises the 仙性, the stage could not be passed.
	if not rises:
		return false
	for item_id: Variant in d.get("treasures", {}):
		var gift: Variant = d.treasures[item_id]
		if content.item(str(item_id)).is_empty() or int(content.item(str(item_id)).get("breakthrough", {}).get("realm", -1)) != 4 or not gift is Dictionary or not gift.get("text") is String or not Forming._count(gift.get("immortal", 0)):
			return false
	return true

# --- Choosing the 道 --------------------------------------------------------------------------------

## The 道 far enough along to merge with: their ids, the furthest first.
static func paths(s) -> Array[String]:
	var found: Array[String] = []
	for path: String in s.content.dao_data.paths:
		if s.Dao.stage_of(s, path) >= int(data(s).dao.least):
			found.append(path)
	found.sort_custom(func(a: String, b: String) -> bool: return int(s.Dao.state(s).xp.get(a, 0)) > int(s.Dao.state(s).xp.get(b, 0)))
	return found

## "火道 · 道之真境" and the like.
static func path_title(s, path: String) -> String:
	var stage: int = s.Dao.stage_of(s, path)
	return "%s道 · %s" % [s.content.dao_data.paths[path], s.content.dao_data.stages[stage - 1].name if stage > 0 else "未入门"]

## Why `path` cannot be merged with, "" when it can.
static func path_block(s, path: String) -> String:
	if paths(s).is_empty():
		return "化神须合道：至少一条悟道达到%s。" % s.content.dao_data.stages[int(data(s).dao.least) - 1].name
	if not path in paths(s):
		return "这条道还不够深，合不了道。"
	return ""

## The 仙性 the stage would open with: the odds, the 道's stage, a 天材地宝, fortune's steps.
static func opening(s, odds: int, path: String, treasure_id: String, steps: int) -> int:
	var d := data(s)
	var stage: int = clampi(s.Dao.stage_of(s, path), 0, d.dao.bonus.size() - 1)
	return int(s.talent_modifier("immortal_start")) + odds / int(d.odds_per) + int(d.dao.bonus[stage]) + int(d.get("treasures", {}).get(treasure_id, {}).get("immortal", 0)) + steps * STEP

# --- The stage --------------------------------------------------------------------------------------

## Opens the stage once the attempt's retreat is over (breakthrough.gd resolve). Returns the texts
## concluded.
static func begin(s, attempt_state: Dictionary, passed: Dictionary, texts: Array) -> String:
	var d := data(s)
	var treasure_id := str(attempt_state.get("treasure", ""))
	var path := str(attempt_state.get("dao", ""))
	if not s.content.dao_data.paths.has(path):
		path = paths(s)[0] if not paths(s).is_empty() else "qi"
	var immortal := mini(int(d.goal) - 1, opening(s, int(attempt_state.get("odds", 0)), path, treasure_id, int(attempt_state.get("steps", 0))))
	s.deifying = {
		"round": 1, "orbs": [], "drawn": [], "immortal": immortal, "mortal": 0, "temper": 0, "soul": 0, "dao": path,
		"cap": int(d.cap), "used": {},
		"certain": bool(attempt_state.get("certain", false)), "xp": int(attempt_state.get("xp", 0)),
		"staked": str(attempt_state.get("staked", "")), "days": int(passed.get("elapsed", 0)), "treasure": treasure_id,
	}
	_draw_round(s)
	texts.append(s.log_event("deifying_start", {"dao_title": path_title(s, path), "immortal": immortal, "goal": int(d.goal)}, true))
	var gift: Dictionary = d.get("treasures", {}).get(treasure_id, {})
	if not gift.is_empty():
		texts.append(str(gift.text))
	return s.conclude(" ".join(texts), passed)

static func cap(s) -> int:
	return int(s.deifying.get("cap", 0))

static func over_cap(s) -> int:
	return maxi(0, s.deifying.get("orbs", []).size() - cap(s))

static func round_draw(s) -> int:
	return int(data(s).draw)

static func _draw_round(s) -> void:
	var drawn: Array = s.Combat._draw(s, round_draw(s), s.Combat.player_weights(s))
	s.deifying.orbs.append_array(drawn)
	s.deifying.drawn = drawn

## The 凡性 the end of the round under way adds.
static func strain(s) -> int:
	var rises: Array = data(s).strain
	return int(rises[clampi(int(s.deifying.get("round", 1)) - 1, 0, rises.size() - 1)])

# --- 法 -----------------------------------------------------------------------------------------------

static func known_arts(s) -> Array[String]:
	var known: Array[String] = []
	for art_id: String in data(s).arts:
		var art: Dictionary = data(s).arts[art_id]
		if not art.has("requires") or s.has_flag(str(art.requires)):
			known.append(art_id)
	return known

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

static func block(s, art_id: String) -> String:
	if s.deifying.is_empty():
		return "眼下并未化神。"
	var art: Dictionary = data(s).arts.get(art_id, {})
	if art.is_empty():
		return "没有这门法。"
	if not art_id in known_arts(s):
		return "还不会%s。" % art.name
	var used: Variant = s.deifying.get("used", {}).get(art_id)
	if used != null and bool(art.get("once", false)):
		return "%s已经运转过了。" % art.name
	if used != null and bool(art.get("per_round", false)) and int(used) == int(s.deifying.round):
		return "%s本回合已经运转过了。" % art.name
	if not s.Combat.affordable(s.deifying.orbs, cost_of(s, art_id)):
		return "灵气不够：须%s。" % s.Arsenal.cost_text(s.content, cost_of(s, art_id))
	return ""

static func plan(s, art_id: String, cycle: bool = false, current: Array = []) -> Array:
	if s.deifying.is_empty():
		return []
	return Forming.plan_from(s, s.deifying.orbs, cost_of(s, art_id), cycle, current)

## What a payment's 生／同／克 adds and which relations count: [{"immortal", "mortal"}, [keys]].
static func _relation(s, art: Dictionary, payment: Array) -> Array:
	var extra := {}
	var met: Array[String] = []
	for key: String in QiRelations.classify(payment, s.content.rules.duel.generates):
		if art.get("relation", {}).has(key):
			met.append(key)
			for field: String in art.relation[key]:
				extra[field] = int(extra.get(field, 0)) + int(art.relation[key][field])
	return [extra, met]

static func preview_words(s, art_id: String, payment: Array) -> String:
	if s.deifying.is_empty() or not s.Combat.payment_valid(s.deifying.orbs, cost_of(s, art_id), payment):
		return ""
	var art: Dictionary = data(s).arts[art_id]
	var relation := _relation(s, art, payment)
	var parts: Array[String] = []
	for key: String in relation[1]:
		parts.append("【%s】" % QiRelations.LABELS[key])
	for field: Array in [["immortal", "仙性"], ["mortal", "凡性"], ["temper", "淬体"], ["soul", "塑魂"]]:
		var amount := int(art.effect.get(field[0], 0)) + int(relation[0].get(field[0], 0))
		if amount != 0:
			parts.append("%s %+d" % [field[1], amount])
	return " ".join(parts)

## Runs a 法 with `payment`, the player's choice of qi; an empty payment takes the automatic one.
static func cast(s, art_id: String, payment: Array = []) -> String:
	var reason := block(s, art_id)
	if not reason.is_empty():
		return reason
	var cost := cost_of(s, art_id)
	if payment.is_empty():
		payment = plan(s, art_id)
	if not s.Combat.payment_valid(s.deifying.orbs, cost, payment):
		return "配气不符：须%s。" % s.Arsenal.cost_text(s.content, cost)
	for element: Variant in payment:
		s.deifying.orbs.remove_at(s.deifying.orbs.find(element))
	var art: Dictionary = data(s).arts[art_id]
	var relation := _relation(s, art, payment)
	s.deifying.used[art_id] = int(s.deifying.round)
	for key: String in EFFECTS:
		var amount := int(art.effect.get(key, 0)) + int(relation[0].get(key, 0))
		if amount != 0:
			s.deifying[key] = maxi(0, int(s.deifying[key]) + amount)
	var text: String = s.log_event("deifying_art", {"art_name": str(art.name), "art_text": str(art.text), "immortal": int(s.deifying.immortal), "mortal": int(s.deifying.mortal)})
	if not relation[1].is_empty():
		text += " " + "".join(relation[1].map(func(key: String) -> String: return "【%s】" % QiRelations.LABELS[key]))
	return _after(s, text)

## Lets one qi go; each stirs the 凡性 a little.
static func discard(s, element: String) -> String:
	if s.deifying.is_empty() or not element in s.deifying.get("orbs", []):
		return "丹田里没有这种灵气。"
	s.deifying.orbs.remove_at(s.deifying.orbs.find(element))
	s.deifying.mortal = int(s.deifying.mortal) + discard_cost(s)
	return _after(s, "散去一颗%s灵气，凡心一动，凡性 +%d。" % [s.content.element_info(element).name, discard_cost(s)])

## The stage has no last round: it runs until 仙性 or 凡性 reaches the goal.
static func last_round(_s) -> bool:
	return false

static func end_words(s) -> Array:
	return ["回合结束", "本回合末凡性 +%d，进入下一回合" % strain(s)]

## Ends the round: qi beyond what may be kept must go first (`auto_release` lets the most plentiful go);
## the 凡性 rises; then the next round's qi.
static func end_round(s, auto_release: bool = false) -> String:
	if s.deifying.is_empty():
		return "眼下并未化神。"
	if over_cap(s) > 0 and not auto_release:
		return "丹田只能存 %d 颗灵气：先散去 %d 颗，或用法耗去。" % [cap(s), over_cap(s)]
	var texts: Array[String] = []
	while over_cap(s) > 0:
		var most := ""
		for element: String in s.deifying.orbs:
			if most.is_empty() or s.deifying.orbs.count(element) > s.deifying.orbs.count(most):
				most = element
		texts.append(discard(s, most))
		if s.deifying.is_empty():
			return " ".join(texts)
	var rise := strain(s)
	s.deifying.mortal = int(s.deifying.mortal) + rise
	texts.append("尘缘牵扯，凡性 +%d（%d / %d）。" % [rise, int(s.deifying.mortal), int(data(s).goal)])
	if int(s.deifying.mortal) >= int(data(s).goal):
		return _after(s, " ".join(texts))
	s.deifying.round = int(s.deifying.round) + 1
	_draw_round(s)
	texts.append("第 %d 回合：吸入 %d 颗灵气。" % [int(s.deifying.round), s.deifying.drawn.size()])
	s.changed.emit()
	return " ".join(texts)

## After any change: 仙性 at the goal forms the 化神; 凡性 there fails it, unless the attempt was certain
## (残魂灌顶), which holds the 凡性 just short.
static func _after(s, text: String) -> String:
	var goal := int(data(s).goal)
	if int(s.deifying.immortal) >= goal:
		return _settle(s, text)
	if int(s.deifying.mortal) >= goal:
		if bool(s.deifying.get("certain", false)):
			s.deifying.mortal = goal - 1
		else:
			return _broken(s, text)
	s.changed.emit()
	return text

## The 仙性 has reached the goal: the 道 merged with, the 淬体 and 塑魂 kept; the 天劫 next.
static func _settle(s, told: String) -> String:
	var stage: Dictionary = s.deifying
	s.deifying = {}
	var texts: Array = [told] if not told.is_empty() else []
	s.player["deity"] = {"dao": str(stage.dao), "temper": int(stage.temper), "soul": int(stage.soul)}
	texts.append(s.log_event("deifying_done", {"dao_name": str(s.content.dao_data.paths[str(stage.dao)]), "temper": int(stage.temper), "soul": int(stage.soul)}, true))
	return s.Breakthrough.core_formed(s, 0, int(stage.days), int(stage.xp), str(stage.staked), texts)

## The 凡性 won: the attempt fails.
static func _broken(s, told: String) -> String:
	var stage: Dictionary = s.deifying
	s.deifying = {}
	var texts: Array = [told] if not told.is_empty() else []
	texts.append(s.log_event("deifying_broken", {"immortal": int(stage.immortal)}, true))
	return s.Breakthrough._fail(s, int(stage.xp), texts, {"elapsed": int(stage.days)}, 1, str(stage.staked))

# --- What the 化神 keeps ----------------------------------------------------------------------------

## The 化神's 淬体 and 塑魂 as stats: {"max_hp", "sense"} to add; none before 化神.
static func gains(content, holder: Dictionary) -> Dictionary:
	var deity: Variant = holder.get("deity", {})
	if int(holder.get("realm", 0)) < 4 or not deity is Dictionary:
		return {"max_hp": 0, "sense": 0}
	var rewards: Dictionary = content.forming_data.deity.rewards
	return {"max_hp": int(deity.get("temper", 0)) * int(rewards.temper_hp), "sense": int(deity.get("soul", 0)) * int(rewards.soul_sense)}

## A saved 化神 record is well formed.
static func valid_deity(content, deity: Variant) -> bool:
	if not deity is Dictionary:
		return false
	if deity.is_empty():
		return true
	return content.dao_data.paths.has(deity.get("dao")) and Forming._count(deity.get("temper")) and Forming._count(deity.get("soul")) and int(deity.temper) <= 1000 and int(deity.soul) <= 1000

# --- The plain policy (速成, the playtest, tests) -------------------------------------------------------

## One decision of the plain policy; false when only ending the round is left. Well ahead in the race,
## it tempers the body first; otherwise it raises the 仙性, keeps the 凡性 down with 守心诀, and spends
## what is left on 淬体 and 塑魂 while the race is safe.
static func plain_step(s) -> bool:
	if s.deifying.is_empty():
		return false
	var lead := int(s.deifying.immortal) - int(s.deifying.mortal)
	if lead > 30 and block(s, "cuiti").is_empty():
		cast(s, "cuiti")
		return true
	if block(s, "tianren").is_empty():
		cast(s, "tianren")
		return true
	if block(s, "ganying").is_empty():
		cast(s, "ganying")
		return true
	if block(s, "shouxin").is_empty():
		cast(s, "shouxin")
		return true
	if lead > 15 and block(s, "cuiti").is_empty():
		cast(s, "cuiti")
		return true
	if lead > 15 and block(s, "suhun").is_empty() and s.deifying.orbs.size() > cap(s):
		cast(s, "suhun")
		return true
	return false

static func auto(s) -> String:
	var texts: Array[String] = []
	var guard := 0
	while not s.deifying.is_empty() and guard < 300:
		guard += 1
		if plain_step(s):
			continue
		texts.append(end_round(s, true))
	return " ".join(texts.filter(func(text: String) -> bool: return not text.is_empty()))

# --- Saves ------------------------------------------------------------------------------------------

static func valid_state(content, saved: Variant) -> Variant:
	if not saved is Dictionary:
		return null
	if saved.is_empty():
		return {}
	var d: Dictionary = content.forming_data.get("deity", {})
	var counts := ["round", "immortal", "mortal", "temper", "soul", "cap", "xp", "days"]
	for key: String in counts:
		if not Forming._count(saved.get(key)) or float(saved[key]) > 1000000000.0:
			return null
	if int(saved.round) < 1 or int(saved.round) > 1000 or int(saved.immortal) >= int(d.goal) or int(saved.mortal) >= int(d.goal) or int(saved.cap) > 1000:
		return null
	if not content.dao_data.paths.has(saved.get("dao")) or not saved.get("certain") is bool or not saved.get("staked") is String or not saved.get("treasure") is String:
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
