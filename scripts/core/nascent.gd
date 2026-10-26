extends RefCounted
## 结婴 as a stage played with qi (docs/MCS_SYSTEMS_GAP_20261026.md A1), after 《觅长生》's 化婴: once the
## attempt's retreat is over, nine rounds of qi drawn by the spirit roots, as in 结丹 (forming.gd).
## First the 金丹 is shattered: 秘术 (data/forming.json `nascent.arts`) crack it until its 丹坚 is gone,
## each round it still stands wearing the 意志; shattered, its pearls pour back as qi of its kind. Then
## 心魔: each round one 念 (`thoughts`) asks something of the round (a 秘术 run, none run, little qi kept,
## many elements kept). Answered, the 魔势 falls; not, the 意志 takes the 魔势 at the round's end. The
## 魔势 gone, the 元婴 is formed at once; the rounds run out with the core shattered, it is formed still,
## 心魔 unsubdued. The share of 意志 kept grades it (rules.breakthrough.nascent.grades), its grade
## adding to the 金丹's. 意志 starts at the attempt's odds; at none the attempt fails as before
## (breakthrough.gd _fail). 经脉, the qi kept between rounds, comes from the 金丹's grade.
## Operates on a Session; s.nascent holds the stage under way, {} otherwise.
const Forming = preload("res://scripts/core/forming.gd")
const QiRelations = preload("res://scripts/core/qi_relations.gd")
const MEASURE := "意志"
const EFFECTS := ["crack", "will", "ward", "later", "subdue", "cap"]
const NEEDS := ["art", "quiet", "most", "elements"]
const PHASES := ["shatter", "infant"]

static func data(s) -> Dictionary:
	return s.content.forming_data.nascent

static func state(s) -> Dictionary:
	return s.nascent

## Whether breaking through to `target` is played as this stage.
static func applies(target: int) -> bool:
	return target == 3

static func valid_data(content) -> bool:
	var d: Variant = content.forming_data.get("nascent")
	if not d is Dictionary:
		return false
	for key: String in ["rounds", "draw", "discard"]:
		if not Forming._count(d.get(key)):
			return false
	if int(d.rounds) < 1:
		return false
	if not d.get("cap_by_core") is Array or d.cap_by_core.size() != content.rules.breakthrough.core.grades.size() or d.cap_by_core.any(func(value: Variant) -> bool: return not Forming._count(value)):
		return false
	var core: Variant = d.get("core")
	if not core is Dictionary or ["base", "per_grade", "strain"].any(func(key: String) -> bool: return not Forming._count(core.get(key))) or int(core.base) < 1:
		return false
	var release: Variant = d.get("release")
	if not release is Dictionary or not Forming._count(release.get("base")) or not Forming._count(release.get("per_grades")) or int(release.per_grades) < 1:
		return false
	var demon: Variant = d.get("demon")
	if not demon is Dictionary or ["base", "per_mind", "least", "most", "answer"].any(func(key: String) -> bool: return not Forming._count(demon.get(key))):
		return false
	if int(demon.per_mind) < 1 or int(demon.answer) < 1 or int(demon.least) < 1 or int(demon.least) > int(demon.base) or int(demon.base) > int(demon.most):
		return false
	var phases: Variant = d.get("phases")
	if not phases is Dictionary or PHASES.any(func(key: String) -> bool: return not phases.get(key) is Dictionary or not phases[key].get("name") is String or not phases[key].get("text") is String):
		return false
	var arts: Variant = d.get("arts")
	if not arts is Dictionary or arts.is_empty():
		return false
	var cracks := false
	for art_id: String in arts:
		var art: Variant = arts[art_id]
		if not art is Dictionary or not art.get("name") is String or not art.get("text") is String or not Forming._valid_cost(art.get("cost")) or not art.get("effect") is Dictionary or art.effect.is_empty():
			return false
		for key: Variant in art.effect:
			if not key in EFFECTS or not Forming._signed(art.effect[key]):
				return false
		if art.has("phase") and not art.phase in PHASES:
			return false
		if art.has("requires") and not art.requires in content.world_flags:
			return false
		if art.has("on_payment") and not QiRelations.valid(art.on_payment, content.technique_data.elements):
			return false
		cracks = cracks or (not art.has("requires") and int(art.effect.get("crack", 0)) > 0)
	# Without a 秘术 anyone knows that cracks the core, the stage could not be passed.
	if not cracks:
		return false
	var thoughts: Variant = d.get("thoughts")
	if not thoughts is Dictionary or thoughts.size() < 2:
		return false
	for thought_id: String in thoughts:
		var thought: Variant = thoughts[thought_id]
		if not thought is Dictionary or not thought.get("name") is String or not thought.get("text") is String or not thought.get("need") is Dictionary or thought.need.is_empty():
			return false
		var need: Dictionary = thought.need
		if need.keys().any(func(key: Variant) -> bool: return not key in NEEDS):
			return false
		if need.has("art") and not arts.has(need.art):
			return false
		if need.has("quiet") and not need.quiet is bool:
			return false
		if (need.has("most") and not Forming._count(need.most)) or (need.has("elements") and (not Forming._count(need.elements) or int(need.elements) > content.technique_data.elements.size())):
			return false
	for item_id: Variant in d.get("treasures", {}):
		var gift: Variant = d.treasures[item_id]
		if content.item(str(item_id)).is_empty() or int(content.item(str(item_id)).get("breakthrough", {}).get("realm", -1)) != 3 or not gift is Dictionary or not gift.get("text") is String:
			return false
		if not Forming._signed(gift.get("demon", 0)) or not Forming._count(gift.get("cap", 0)):
			return false
	return true

# --- The stage --------------------------------------------------------------------------------------

## The 魔势 the stage would open with: from how far the mind falls short of the 元婴's need (or above
## it), less what the 天材地宝 `treasure_id` keeps away.
static func demon_of(s, treasure_id: String) -> int:
	var demon: Dictionary = data(s).demon
	var gap: int = s.Breakthrough.demon_mind(s) - int(s.player.get("mind", 0))
	var strength := clampi(int(demon.base) + (gap / int(demon.per_mind) if gap >= 0 else -(-gap / int(demon.per_mind))), int(demon.least), int(demon.most))
	return maxi(1, strength + int(data(s).get("treasures", {}).get(treasure_id, {}).get("demon", 0)))

## The 金丹's 丹坚 to crack: more for a finer core.
static func core_strength(s) -> int:
	var core: Dictionary = data(s).core
	return int(core.base) + int(core.per_grade) * clampi(int(s.player.get("core_grade", 0)), 0, data(s).cap_by_core.size() - 1)

## Opens the stage once the attempt's retreat is over (breakthrough.gd resolve): the 意志 from its odds,
## the 丹坚 from the core's grade, the 魔势 from the mind, the first round's qi drawn. Returns the texts
## concluded.
static func begin(s, attempt_state: Dictionary, passed: Dictionary, texts: Array) -> String:
	var d := data(s)
	var grade := clampi(int(s.player.get("core_grade", 0)), 0, d.cap_by_core.size() - 1)
	var treasure_id := str(attempt_state.get("treasure", ""))
	var gift: Dictionary = d.get("treasures", {}).get(treasure_id, {})
	var will := maxi(1, int(attempt_state.get("odds", 1)))
	var demon := demon_of(s, treasure_id)
	s.nascent = {
		"round": 1, "orbs": [], "drawn": [], "will": will, "most": will, "core": core_strength(s), "core_most": core_strength(s),
		"demon": demon, "demon_most": demon, "thought": "", "acts": [], "ward": 0, "extra": 0, "later": 0,
		"cap": int(d.cap_by_core[grade]) + int(gift.get("cap", 0)), "used": {},
		"certain": bool(attempt_state.get("certain", false)), "steps": int(attempt_state.get("steps", 0)), "xp": int(attempt_state.get("xp", 0)),
		"staked": str(attempt_state.get("staked", "")), "days": int(passed.get("elapsed", 0)), "treasure": treasure_id,
	}
	_draw_round(s)
	texts.append(s.log_event("nascent_start", {"rounds": int(d.rounds), "will": will, "core": int(s.nascent.core), "demon": demon}, true))
	if not gift.is_empty():
		texts.append(str(gift.text))
	return s.conclude(" ".join(texts), passed)

static func shattered(s) -> bool:
	return int(s.nascent.get("core", 1)) <= 0

## The phase under way: {"id", "name", "text"}.
static func phase(s) -> Dictionary:
	var id := "infant" if shattered(s) else "shatter"
	var entry: Dictionary = data(s).phases[id]
	var amount := int(data(s).demon.answer) if id == "infant" else int(data(s).core.strain)
	return {"id": id, "name": str(entry.name), "text": str(entry.text) % amount}

## The 念 of the round, {} before the core is shattered.
static func thought(s) -> Dictionary:
	return data(s).thoughts.get(str(s.nascent.get("thought", "")), {})

## How many qi may be kept at the end of a round (经脉).
static func cap(s) -> int:
	return int(s.nascent.get("cap", 0))

static func over_cap(s) -> int:
	return maxi(0, s.nascent.get("orbs", []).size() - cap(s))

static func round_draw(s) -> int:
	return int(data(s).draw)

static func _draw_round(s) -> void:
	var drawn: Array = s.Combat._draw(s, round_draw(s), s.Combat.player_weights(s))
	s.nascent.orbs.append_array(drawn)
	s.nascent.drawn = drawn
	s.nascent.acts = []
	if shattered(s):
		_rise(s)

## A new 念 rises, never the one just past.
static func _rise(s) -> void:
	var choices: Array = data(s).thoughts.keys().filter(func(id: String) -> bool: return id != str(s.nascent.get("thought", "")))
	s.nascent.thought = str(choices[s.combat_rng.randi_range(0, choices.size() - 1)])
	s.nascent.acts = []

# --- 秘术 ---------------------------------------------------------------------------------------------

static func known_arts(s) -> Array[String]:
	var known: Array[String] = []
	for art_id: String in data(s).arts:
		var art: Dictionary = data(s).arts[art_id]
		if not art.has("requires") or s.has_flag(str(art.requires)):
			known.append(art_id)
	return known

## The 秘术: [{"id", "art", "known"}], those not yet known too, for the screen to show what is missing.
static func entries(s) -> Array:
	var result: Array = []
	var known := known_arts(s)
	for art_id: String in data(s).arts:
		result.append({"id": art_id, "art": data(s).arts[art_id], "known": art_id in known})
	return result

## What teaches the lore an art requires: the lore's name (凝婴之法), or the flag itself.
static func _lore_name(s, flag: String) -> String:
	for lore: Dictionary in s.content.rules.breakthrough.get("lore", []):
		if str(lore.flag) == flag:
			return str(lore.name)
	return flag

static func cost_of(s, art_id: String) -> Dictionary:
	return data(s).arts.get(art_id, {}).get("cost", {})

static func discard_cost(s) -> int:
	return int(data(s).discard)

## Why `art_id` cannot be run now, "" when it can be paid and is allowed.
static func block(s, art_id: String) -> String:
	if s.nascent.is_empty():
		return "眼下并未结婴。"
	var art: Dictionary = data(s).arts.get(art_id, {})
	if art.is_empty():
		return "没有这门秘术。"
	if not art_id in known_arts(s):
		return "须懂%s，方能运转%s。" % [_lore_name(s, str(art.requires)), art.name]
	if str(art.get("phase", "")) == "shatter" and shattered(s):
		return "金丹已碎，用不上%s了。" % art.name
	if str(art.get("phase", "")) == "infant" and not shattered(s):
		return "金丹碎后方能运转%s。" % art.name
	var used: Variant = s.nascent.get("used", {}).get(art_id)
	if used != null and bool(art.get("once", false)):
		return "%s已经运转过了。" % art.name
	if used != null and bool(art.get("per_round", false)) and int(used) == int(s.nascent.round):
		return "%s本回合已经运转过了。" % art.name
	if not s.Combat.affordable(s.nascent.orbs, cost_of(s, art_id)):
		return "灵气不够：须%s。" % s.Arsenal.cost_text(s.content, cost_of(s, art_id))
	return ""

static func plan(s, art_id: String, cycle: bool = false, current: Array = []) -> Array:
	if s.nascent.is_empty():
		return []
	return Forming.plan_from(s, s.nascent.orbs, cost_of(s, art_id), cycle, current)

## What `payment` for `art_id` would come to, in words, without changing anything.
static func preview_words(s, art_id: String, payment: Array) -> String:
	if s.nascent.is_empty() or not s.Combat.payment_valid(s.nascent.orbs, cost_of(s, art_id), payment):
		return ""
	var art: Dictionary = data(s).arts[art_id]
	var cycle: Dictionary = s.content.rules.duel.generates
	var parts: Array[String] = []
	for key: String in QiRelations.triggers(art, payment, cycle):
		parts.append("【%s】" % QiRelations.LABELS[key])
	var effect: Dictionary = art.effect
	if int(effect.get("crack", 0)) > 0:
		parts.append("丹坚 -%d" % mini(int(effect.crack), int(s.nascent.core)))
	var will := int(effect.get("will", 0)) + int(QiRelations.effect(art, payment, cycle).get("heal", 0))
	if will != 0:
		parts.append("意志 %+d" % will)
	if int(effect.get("ward", 0)) > 0:
		parts.append("心魔伤害 -%d" % int(effect.ward))
	if int(effect.get("subdue", 0)) > 0:
		parts.append("魔势 -%d" % int(effect.subdue))
	if str(thought(s).get("need", {}).get("art", "")) == art_id:
		parts.append("应对%s" % thought(s).name)
	return " ".join(parts)

## Runs a 秘术 with `payment`, the player's choice of qi; an empty payment takes the automatic one.
static func cast(s, art_id: String, payment: Array = []) -> String:
	var reason := block(s, art_id)
	if not reason.is_empty():
		return reason
	var cost := cost_of(s, art_id)
	if payment.is_empty():
		payment = plan(s, art_id)
	if not s.Combat.payment_valid(s.nascent.orbs, cost, payment):
		return "配气不符：须%s。" % s.Arsenal.cost_text(s.content, cost)
	for element: Variant in payment:
		s.nascent.orbs.remove_at(s.nascent.orbs.find(element))
	var art: Dictionary = data(s).arts[art_id]
	var standing := not shattered(s)
	s.nascent.used[art_id] = int(s.nascent.round)
	s.nascent.acts.append(art_id)
	for key: String in art.effect:
		var amount := int(art.effect[key])
		match key:
			"crack":
				s.nascent.core = maxi(0, int(s.nascent.core) - amount)
			"will":
				_shift(s, amount)
			"subdue":
				s.nascent.demon = maxi(0, int(s.nascent.demon) - amount)
			"cap":
				s.nascent.cap = maxi(0, int(s.nascent.cap) + amount)
			_:
				s.nascent[key] = int(s.nascent.get(key, 0)) + amount
	var paid: Dictionary = QiRelations.effect(art, payment, s.content.rules.duel.generates)
	if paid.has("heal"):
		_shift(s, int(paid.heal))
	var text: String = s.log_event("nascent_art", {"art_name": str(art.name), "art_text": str(art.text), "will": int(s.nascent.will)})
	var triggers := QiRelations.triggers(art, payment, s.content.rules.duel.generates)
	if not triggers.is_empty():
		text += " " + "".join(triggers.map(func(key: String) -> String: return "【%s】" % QiRelations.LABELS[key]))
	if standing and shattered(s):
		text += " " + _shatter(s)
	if int(s.nascent.will) > 0 and shattered(s) and int(s.nascent.demon) <= 0:
		return _settle(s, text)
	return _after(s, text)

## The core gives way: its pearls pour back as qi of its kind (a 纯 core's element, a 双 core's two in
## turn, a 混元 one's drawn by the roots), and the first 念 rises.
static func _shatter(s) -> String:
	var release: Dictionary = data(s).release
	var count := int(release.base) + clampi(int(s.player.get("core_grade", 0)), 0, 8) / int(release.per_grades)
	var kind: Dictionary = s.Forming.core_kind(s)
	var elements: Array = kind.get("elements", [])
	var poured: Array = []
	if elements.is_empty():
		poured = s.Combat._draw(s, count, s.Combat.player_weights(s))
	else:
		for index: int in count:
			poured.append(str(elements[index % elements.size()]))
	s.nascent.orbs.append_array(poured)
	_rise(s)
	return s.log_event("nascent_shatter", {"count": poured.size(), "thought": str(thought(s).name)}, true)

## Lets one qi go; each costs the 意志 a little.
static func discard(s, element: String) -> String:
	if s.nascent.is_empty() or not element in s.nascent.get("orbs", []):
		return "丹田里没有这种灵气。"
	s.nascent.orbs.remove_at(s.nascent.orbs.find(element))
	_shift(s, -discard_cost(s))
	return _after(s, "散去一颗%s灵气，心神一晃，意志 -%d。" % [s.content.element_info(element).name, discard_cost(s)])

## Lets the most plentiful qi go until `keep` are left (the 念 that ask little qi kept, the 经脉 full).
static func release_to(s, keep: int) -> String:
	var texts: Array[String] = []
	while not s.nascent.is_empty() and s.nascent.orbs.size() > maxi(0, keep):
		var most := ""
		for element: String in s.nascent.orbs:
			if most.is_empty() or s.nascent.orbs.count(element) > s.nascent.orbs.count(most):
				most = element
		texts.append(discard(s, most))
	return " ".join(texts)

## Whether the round as it stands answers the 念: every need met.
static func answered(s) -> bool:
	var need: Dictionary = thought(s).get("need", {})
	if need.is_empty():
		return false
	var acts: Array = s.nascent.get("acts", [])
	var orbs: Array = s.nascent.get("orbs", [])
	if need.has("art") and not str(need.art) in acts:
		return false
	if bool(need.get("quiet", false)) and not acts.is_empty():
		return false
	if need.has("most") and orbs.size() > int(need.most):
		return false
	if need.has("elements"):
		var kinds := {}
		for element: Variant in orbs:
			kinds[element] = true
		if kinds.size() < int(need.elements):
			return false
	return true

## The 心魔's blow at the round's end if the 念 goes unanswered.
static func blow(s) -> int:
	return maxi(0, int(s.nascent.get("demon", 0)) - int(s.nascent.get("ward", 0)) + int(s.nascent.get("extra", 0)))

static func last_round(s) -> bool:
	return int(s.nascent.get("round", 1)) >= int(data(s).rounds)

static func end_words(s) -> Array:
	if last_round(s):
		return ["收功成婴" if shattered(s) else "收功", "九回合已尽：金丹已碎便就此成婴" if shattered(s) else "九回合已尽，金丹未碎则结婴失败"]
	return ["回合结束", "承受本回合的反冲或心魔，进入下一回合"]

## Ends the round: qi beyond what may be kept must go first (`auto_release` lets the most plentiful go);
## a core still standing jars the 意志; the 念 answered lowers the 魔势, else it strikes. Then the next
## round's qi, or the 元婴 is settled after the last.
static func end_round(s, auto_release: bool = false) -> String:
	if s.nascent.is_empty():
		return "眼下并未结婴。"
	if over_cap(s) > 0 and not auto_release:
		return "经脉只容 %d 颗灵气：先散去 %d 颗，或用秘术耗去。" % [cap(s), over_cap(s)]
	var texts: Array[String] = []
	if over_cap(s) > 0:
		texts.append(release_to(s, cap(s)))
		if s.nascent.is_empty():
			return " ".join(texts)
	if not shattered(s):
		var strain := int(data(s).core.strain)
		_shift(s, -strain)
		texts.append("金丹未碎，丹元反冲，意志 -%d。" % strain)
	elif answered(s):
		s.nascent.demon = maxi(0, int(s.nascent.demon) - int(data(s).demon.answer))
		texts.append(s.log_event("nascent_answer", {"thought": str(thought(s).name), "demon": int(s.nascent.demon)}))
		if int(s.nascent.demon) <= 0:
			return _settle(s, " ".join(texts))
	else:
		var damage := blow(s)
		if damage > 0:
			_shift(s, -damage)
			texts.append(s.log_event("nascent_hurt", {"thought": str(thought(s).name), "damage": damage, "will": int(s.nascent.will)}))
	if int(s.nascent.will) <= 0:
		return _broken(s, " ".join(texts))
	s.nascent.round = int(s.nascent.round) + 1
	s.nascent.ward = 0
	s.nascent.extra = int(s.nascent.get("later", 0))
	s.nascent.later = 0
	if int(s.nascent.round) > int(data(s).rounds):
		if shattered(s):
			return _settle(s, " ".join(texts))
		return _broken(s, " ".join(texts), "nascent_unbroken")
	_draw_round(s)
	var told := "第 %d 回合 · %s：吸入 %d 颗灵气。" % [int(s.nascent.round), str(phase(s).name), s.nascent.drawn.size()]
	if shattered(s):
		told += "心魔起%s：%s" % [str(thought(s).name), str(thought(s).text)]
	texts.append(told)
	s.changed.emit()
	return " ".join(texts)

## Changes the 意志, never above where it started; a certain attempt (残魂灌顶) cannot fall to none.
static func _shift(s, amount: int) -> void:
	var floor_value := 1 if bool(s.nascent.get("certain", false)) else 0
	s.nascent.will = clampi(int(s.nascent.will) + amount, floor_value, int(s.nascent.most))

static func _after(s, text: String) -> String:
	if int(s.nascent.will) <= 0:
		return _broken(s, text)
	s.changed.emit()
	return text

## The 元婴's grade the stage as it stands would make (index into rules.breakthrough.nascent.grades),
## before fortune and talents: by the share of 意志 kept; with 心魔 unsubdued, no better than the second.
static func grade_now(s, stage: Dictionary = {}) -> int:
	if stage.is_empty():
		stage = s.nascent
	var grades: Array = s.content.rules.breakthrough.nascent.grades
	var share := int(stage.get("will", 0)) * 100 / maxi(1, int(stage.get("most", 1)))
	var grade := 0
	for index: int in grades.size():
		if share >= int(grades[index].share):
			grade = index
	if int(stage.get("demon", 0)) > 0:
		grade = mini(grade, 1)
	return grade

## The 元婴 is formed (心魔 subdued, or the rounds over with the core shattered): its 天劫 next.
static func _settle(s, told: String) -> String:
	var stage: Dictionary = s.nascent
	s.nascent = {}
	var texts: Array = [told] if not told.is_empty() else []
	var grades: Array = s.content.rules.breakthrough.nascent.grades
	var grade := clampi(grade_now(s, stage) + int(stage.steps) + s.Breakthrough.talent_steps(s), 0, grades.size() - 1)
	texts.append(s.log_event("nascent_done", {"grade_name": str(grades[grade].name), "subdued": "心魔尽散" if int(stage.demon) <= 0 else "心魔未尽"}, true))
	return s.Breakthrough.core_formed(s, grade, int(stage.days), int(stage.xp), str(stage.staked), texts)

## The 意志 gave way (or the core would not break): the attempt fails.
static func _broken(s, told: String, entry: String = "nascent_broken") -> String:
	var stage: Dictionary = s.nascent
	s.nascent = {}
	var texts: Array = [told] if not told.is_empty() else []
	texts.append(s.log_event(entry, {}, true))
	return s.Breakthrough._fail(s, int(stage.xp), texts, {"elapsed": int(stage.days)}, 1, str(stage.staked))

# --- The plain policy (速成, the playtest, tests) -------------------------------------------------------

## One decision of the plain policy; false when only ending the round is left. Cracks the core with the
## strongest 秘术 it can pay; then answers the 念 when it can, shores the 意志 with 清心咒, and spends
## what the 念 asks it to let go.
static func plain_step(s) -> bool:
	if s.nascent.is_empty():
		return false
	if not shattered(s):
		for art_id: String in ["liedan", "suidan", "xieling"]:
			if block(s, art_id).is_empty() and (art_id != "liedan" or int(s.nascent.will) > 20):
				cast(s, art_id)
				return true
		if block(s, "qingxin").is_empty() and int(s.nascent.will) * 100 / maxi(1, int(s.nascent.most)) < 60:
			cast(s, "qingxin")
			return true
		return false
	var need: Dictionary = thought(s).get("need", {})
	if need.has("art") and not str(need.art) in s.nascent.acts and block(s, str(need.art)).is_empty():
		cast(s, str(need.art))
		return true
	if bool(need.get("quiet", false)):
		if s.nascent.orbs.size() > int(need.get("most", s.nascent.orbs.size())):
			release_to(s, int(need.most))
			return not s.nascent.is_empty()
		return false
	if block(s, "nizhoutian").is_empty() and int(s.nascent.will) > 30:
		cast(s, "nizhoutian")
		return true
	if need.has("elements"):
		return false
	if block(s, "qingxin").is_empty():
		cast(s, "qingxin")
		return true
	if need.has("most") and s.nascent.orbs.size() > int(need.most):
		release_to(s, int(need.most))
		return not s.nascent.is_empty()
	return false

## Plays the rest of the stage by the plain policy. Returns the texts.
static func auto(s) -> String:
	var texts: Array[String] = []
	var guard := 0
	while not s.nascent.is_empty() and guard < 200:
		guard += 1
		if plain_step(s):
			continue
		texts.append(end_round(s, true))
	return " ".join(texts.filter(func(text: String) -> bool: return not text.is_empty()))

# --- Saves ------------------------------------------------------------------------------------------

## A saved 元婴 grade is well formed.
static func valid_grade(content, grade: Variant) -> bool:
	return Forming._count(grade) and int(grade) < content.rules.breakthrough.nascent.grades.size()

## A saved stage is well formed (save_restore.gd); null when malformed, else the normalized copy.
static func valid_state(content, saved: Variant) -> Variant:
	if not saved is Dictionary:
		return null
	if saved.is_empty():
		return {}
	var d: Dictionary = content.forming_data.get("nascent", {})
	var counts := ["round", "will", "most", "core", "core_most", "demon", "demon_most", "ward", "extra", "later", "cap", "steps", "xp", "days"]
	for key: String in counts:
		if not Forming._count(saved.get(key)) or float(saved[key]) > 1000000000.0:
			return null
	if int(saved.round) < 1 or int(saved.round) > int(d.rounds) or int(saved.most) < 1 or int(saved.will) < 1 or int(saved.will) > int(saved.most) or int(saved.core) > int(saved.core_most) or int(saved.demon) > int(saved.demon_most) or int(saved.cap) > 1000:
		return null
	if not saved.get("certain") is bool or not saved.get("staked") is String or not saved.get("treasure") is String:
		return null
	if not saved.treasure.is_empty() and content.item(saved.treasure).is_empty():
		return null
	var thought_id: Variant = saved.get("thought")
	if not thought_id is String or (not thought_id.is_empty() and not d.thoughts.has(thought_id)) or (thought_id.is_empty() != (int(saved.core) > 0)):
		return null
	for key: String in ["orbs", "drawn"]:
		if not saved.get(key) is Array or saved[key].size() > 1000 or saved[key].any(func(element: Variant) -> bool: return not content.technique_data.elements.has(element)):
			return null
	if not saved.get("acts") is Array or saved.acts.any(func(art_id: Variant) -> bool: return not d.arts.has(art_id)):
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
