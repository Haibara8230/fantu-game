extends RefCounted
## Turn-based duel rules. Operates on a Session; only the combat random stream is used here.

static func start_battle(s, enemy_id: String, opponent_sect: String = "") -> String:
	if not s.blocked().is_empty() or not s.content.enemies.has(enemy_id):
		return "当前无法开始斗法。"
	var enemy: Dictionary = s.content.enemies[enemy_id]
	if not s.available_here("battle:" + enemy_id):
		return "此地没有这个对手。"
	if not opponent_sect.is_empty() and not s.content.sects.has(opponent_sect):
		return "未知对手传承。"
	if int(s.player.realm) < int(enemy.min_realm):
		return "%s气息凶险，需达到%s。" % [enemy.name, s.content.realm_title(int(enemy.min_realm), 0)]
	if enemy.has("world_flag") and s.has_flag(enemy.world_flag):
		return "%s已经伏诛，此地重归安宁。" % enemy.name
	return s.finish(begin_battle(s, enemy_id, "", opponent_sect))

## Starts a duel without location checks; used by spots and by event effects (context "event").
static func begin_battle(s, enemy_id: String, context: String = "", opponent_sect: String = "") -> String:
	var enemy: Dictionary = s.content.enemies[enemy_id]
	if opponent_sect.is_empty():
		opponent_sect = str(enemy.get("sect", s.player.get("sect", "wanderer")))
		if opponent_sect == "wanderer":
			opponent_sect = "qingyun"
	var hp := int(enemy.hp)
	# A foe whose weakness the player has prepared (the serpent after 破鳞散) starts the duel hurt.
	var weakened: Dictionary = enemy.get("weakened_by", {})
	if not weakened.is_empty() and s.has_flag(weakened.flag):
		hp = maxi(1, hp * int(weakened.hp_percent) / 100)
	s.battle = {"enemy_id": enemy_id, "hp": hp, "turn": 1, "cooldowns": {}, "opponent_sect": opponent_sect, "status": {}, "place": _battle_place(s)}
	if not context.is_empty():
		s.battle.context = context
	s.combat_events.clear()
	open_hand(s)
	return s.log_event("battle_start", {"enemy": enemy_id})

## A friendly bout with a generated person: their stage's health and their best art, nothing at stake.
static func begin_spar(s, person_id: String) -> void:
	var someone: Dictionary = s.person(person_id)
	var foe: Dictionary = s.Population.foe(s.content, person_id, someone)
	var lineage: String = str(someone.get("sect", "qingyun"))
	s.battle = {"enemy_id": "cultivator", "hp": int(foe.hp), "turn": 1, "cooldowns": {}, "opponent_sect": "qingyun" if lineage == "wanderer" else lineage, "status": {}, "context": "spar", "npc": person_id, "foe": foe, "place": _battle_place(s)}
	s.combat_events.clear()
	open_hand(s)
	s.log_event("spar_start", {"npc": person_id})

## Why the player cannot enter the 外门小比 at the arena now, or "".
static func tournament_block(s) -> String:
	var reason: String = s.blocked()
	if not reason.is_empty():
		return reason
	if not s.available_here("tournament"):
		return "须到青云山演武坪报名。"
	var definition: Dictionary = s.content.events.tournament_entry
	var window: Dictionary = s.Events.window_at(definition, int(s.world.day))
	if window.is_empty():
		return "外门小比于%s开始报名。" % s.Calendar.date_text(int(s.Events.next_window(definition, int(s.world.day)).from))
	if not s.Events.open_for(s, "tournament_entry", window, int(s.world.day)):
		return "这一届外门小比已经报过名或观过战了。"
	return ""

## Enters the 外门小比 at the arena: the first round begins at once.
static func enter_tournament(s) -> String:
	var reason := tournament_block(s)
	if not reason.is_empty():
		return reason
	var definition: Dictionary = s.content.events.tournament_entry
	s.Events.mark_fired(s, "tournament_entry", s.Events.window_at(definition, int(s.world.day)), int(s.world.day))
	var text: String = s.log_event("tournament_enter")
	begin_tournament(s, 1)
	return s.finish(text)

## A tournament round against the sect's outer disciples present, weakest first.
static func begin_tournament(s, round: int) -> void:
	var disciples: Array = s.present_npcs().filter(func(person_id: String) -> bool: return s.is_generated(person_id) and s.person(person_id).kind == "disciple")
	disciples.sort_custom(func(a: String, b: String) -> bool:
		var ra := int(s.person(a).realm) * 10 + int(s.person(a).stage)
		var rb := int(s.person(b).realm) * 10 + int(s.person(b).stage)
		return ra < rb or (ra == rb and a < b))
	if disciples.is_empty():
		begin_battle(s, "disciple", "event")
		s.battle.context = "tournament"
		s.battle.round = round
		return
	var opponent: String = disciples[clampi(round - 1 + disciples.size() / 3 * (round - 1), 0, disciples.size() - 1)]
	begin_spar(s, opponent)
	s.battle.context = "tournament"
	s.battle.round = round

## Where a duel is fought, for its backdrop: "road" while a road encounter is open, otherwise here.
static func _battle_place(s) -> String:
	if not s.pending_event.is_empty() and str(s.content.events[s.pending_event.id].get("trigger", "")) == "route":
		return "road"
	return str(s.player.location)

# --- Qi orbs (灵气) ---------------------------------------------------------------------------------
# After Mi Chang Sheng: each turn the player draws qi orbs of the five elements, weighted toward the
# spirit roots; an art is cast by spending the orbs its cost names (an element, or "any"), several arts
# in a turn while orbs last, and 结束回合 hands the turn over. Two orbs of an element 相生 into one of
# the element it gives rise to (金生水、水生木、木生火、火生土、土生金) at no cost of a turn; an art whose
# element the last art of the turn gave rise to keeps the cycle turning (五行轮转) and brings one more
# orb. An art that overcomes the opponent's element strikes harder, one it is overcome by softer. At the
# end of a turn the orbs held beyond the cap (from the 灵力上限) are let go.
# The opponent shows what it means to do next (intent). Generated cultivators draw orbs of their own
# and cast their whole loadout from them; beasts and the handwritten foes strike once a turn.
# battle: orbs (the player's), chain (the element last cast this turn), shield, player_status, pills;
# foe_orbs, foe_shield, intent [{"art"?, "kind", "name", "min", "max" | "amount"}].

## Lingering effects either side may carry: 灼烧 (burn: damage each turn), 寒蚀 (weaken: deals less),
## 破甲 (sunder: takes more), 冰封 (slow: draws fewer orbs, or strikes weaker without orbs); each
## [amount, turns].
const LINGERING := ["burn", "weaken", "sunder", "slow"]
## How much weaker a slowed opponent without orbs strikes.
const SLOW_BLOW := 0.8

## A lingering effect as it is kept: a share (weaken, sunder) or a whole amount, and whole turns, the
## same whether it came from the data or from a save.
static func lingering_value(key: String, value: Array) -> Array:
	return [float(value[0]) if key in ["weaken", "sunder"] else int(value[0]), int(value[1])]

static func rules(s) -> Dictionary:
	return s.content.rules.duel

static func elements(s) -> Array:
	return s.content.technique_data.elements.keys()

## How many orbs the player keeps at the end of a turn: from the qi cap (灵力上限), and talents, arts
## and equipment that hold more (orb_cap).
static func hand_cap(s) -> int:
	return maxi(int(rules(s).hand_least), int(s.player.max_qi) / int(rules(s).qi_per_orb)) + int(s.orb_bonus("orb_cap"))

## Orbs the player draws each turn: the realm's, and what talents, arts and equipment add (orb_draw).
static func draw_count(s) -> int:
	return _by_realm(s, "draw", int(s.player.realm)) + int(s.orb_bonus("orb_draw"))

static func _by_realm(s, key: String, realm: int) -> int:
	var counts: Array = rules(s)[key]
	return int(counts[clampi(realm, 0, counts.size() - 1)])

## Draw weights for the player: the spirit roots' elements heavier, and an element favoured by talents,
## arts or equipment (orb_<element>) heavier still.
static func player_weights(s) -> Dictionary:
	var weights := {}
	for element: String in elements(s):
		weights[element] = (int(rules(s).root_weight) if element in s.player.get("roots", []) else int(rules(s).other_weight)) + int(s.orb_bonus("orb_" + element))
	return weights

## Draw weights for a generated opponent: the elements of its arts heavier.
static func _foe_weights(s) -> Dictionary:
	var weights := {}
	var favoured: Array = [foe_element(s)]
	for art_id: Variant in s.battle.get("foe", {}).get("arts", []):
		favoured.append(str(s.content.technique(str(art_id)).get("element", "")))
	for element: String in elements(s):
		weights[element] = int(rules(s).root_weight) if element in favoured else int(rules(s).other_weight)
	return weights

static func _draw(s, count: int, weights: Dictionary) -> Array:
	var total := 0
	for element: String in weights:
		total += maxi(0, int(weights[element]))
	var drawn: Array = []
	for index: int in count:
		var roll: int = s.combat_rng.randi_range(1, maxi(1, total))
		for element: String in elements(s):
			roll -= maxi(0, int(weights[element]))
			if roll <= 0:
				drawn.append(element)
				break
	return drawn

## The first turn of a duel: the player's first hand, and the opponent's orbs and intent.
static func open_hand(s) -> void:
	var drawn := _draw(s, draw_count(s) + int(rules(s).first_extra) + int(s.orb_bonus("orb_first")), player_weights(s))
	s.battle.orbs = drawn
	s.battle.chain = ""
	s.battle.shield = 0
	s.battle.foe_shield = 0
	s.battle.foe_orbs = []
	s.battle.player_status = {}
	s.battle.pills = 0
	s.battle.cooldowns = {}
	s.combat_events.append({"type": "draw", "actor": "player", "orbs": drawn.duplicate()})
	_foe_prepare(s)

## Whether `orbs` cover `cost`.
static func affordable(orbs: Array, cost: Dictionary) -> bool:
	var left := orbs.duplicate()
	for key: String in cost:
		if key == "any":
			continue
		for count: int in int(cost[key]):
			var at := left.find(key)
			if at < 0:
				return false
			left.remove_at(at)
	return left.size() >= int(cost.get("any", 0))

## Takes `cost` out of `orbs`: the named elements first, then "any" from the most plentiful element.
## Returns the orbs spent.
static func _pay(orbs: Array, cost: Dictionary) -> Array:
	var spent: Array = []
	for key: String in cost:
		if key == "any":
			continue
		for count: int in int(cost[key]):
			orbs.remove_at(orbs.find(key))
			spent.append(key)
	for count: int in int(cost.get("any", 0)):
		var most := ""
		for element: String in orbs:
			if most.is_empty() or orbs.count(element) > orbs.count(most):
				most = element
		orbs.remove_at(orbs.find(most))
		spent.append(most)
	return spent

static func _orbs_in(cost: Dictionary) -> int:
	var total := 0
	for key: String in cost:
		total += int(cost[key])
	return total

## The opponent's element.
static func foe_element(s) -> String:
	var foe: Dictionary = s.battle.get("foe", {})
	if foe.has("element"):
		return str(foe.element)
	return str(s.content.enemies[s.battle.enemy_id].get("element", "metal"))

## 克制: an art that overcomes the opponent's element strikes harder, one it is overcome by softer.
static func counter_multiplier(s, element: String) -> float:
	var foe := foe_element(s)
	if str(rules(s).overcomes.get(element, "")) == foe:
		return float(rules(s).counter)
	if str(rules(s).overcomes.get(foe, "")) == element:
		return float(rules(s).countered)
	return 1.0

static func use_skill(s, skill_id: String) -> String:
	s.combat_events.clear()
	var t: Dictionary = s.content.technique(skill_id)
	if s.battle.is_empty() or t.is_empty() or t.slot != "art":
		return "当前无法施展神通。"
	if skill_id not in s.active_skills():
		return "此神通未在运转。"
	if not affordable(s.battle.orbs, t.cost):
		return "灵气不足：%s需要%s。" % [t.name, s.Arsenal.cost_text(s.content, t.cost)]
	var spent := _pay(s.battle.orbs, t.cost)
	var look := {"style": skill_id, "name": t.name, "vfx": t.vfx, "tier": int(t.tier), "element": t.element, "spent": spent}
	# A sect's own art cast by its disciple carries the lineage's signature layer.
	var lineage: String = s.content.legacy_sect(skill_id, str(s.player.get("sect", "wanderer")))
	if not lineage.is_empty():
		look.legacy = lineage
	var text := ""
	match str(t.kind):
		"heal":
			var recovered := mini(int(t.heal), int(s.player.max_hp) - int(s.player.hp))
			s.player.hp += recovered
			s.combat_events.append(_event({"type": "heal", "amount": recovered, "hp_after": int(s.player.hp)}, look))
			text = s.log_event("skill_heal", {"skill": skill_id, "amount": recovered})
		"guard":
			s.battle.shield = int(s.battle.get("shield", 0)) + int(t.shield)
			s.combat_events.append(_event({"type": "guard", "amount": 0, "shield": int(s.battle.shield)}, look))
			text = s.log_event("skill_shield", {"skill": skill_id, "amount": int(t.shield)})
		_:
			# The realm's attack bonus counts half for each orb spent, so many small arts gain no more
			# from it than one great one.
			var roll: int = s.combat_rng.randi_range(int(t.damage_min), int(t.damage_max)) + int(round(float(s.attack_bonus()) * spent.size() / 2.0))
			var counter := counter_multiplier(s, t.element)
			var factor: float = s.element_multiplier(t) * counter
			if s.battle.get("player_status", {}).has("weaken"):
				factor *= 1.0 - float(s.battle.player_status.weaken[0])
			if s.battle.status.has("sunder"):
				factor *= 1.0 + float(s.battle.status.sunder[0])
			var dealt := _strike_foe(s, maxi(1, int(round(float(roll) * factor))))
			s.combat_events.append(_event({"type": "attack", "actor": "player", "hits": int(t.hits), "amount": dealt, "hp_after": int(s.battle.hp), "counter": "克" if counter > 1.0 else ("被克" if counter < 1.0 else "")}, look))
			text = s.log_event("skill_attack", {"skill": skill_id, "amount": dealt})
			if t.has("lifesteal"):
				var healed := mini(int(round(dealt * float(t.lifesteal))), int(s.player.max_hp) - int(s.player.hp))
				if healed > 0:
					s.player.hp += healed
					s.combat_events.append(_event({"type": "heal", "amount": healed, "hp_after": int(s.player.hp)}, look))
			for status: String in LINGERING:
				if t.has(status):
					s.battle.status[status] = lingering_value(status, t[status])
	if t.has("draw"):
		_gain(s, _draw(s, int(t.draw), player_weights(s)))
	if t.has("renew"):
		_gain(s, [str(t.element)])
	# 五行轮转: an art whose element the last one gave rise to brings an orb of the next element.
	var last := str(s.battle.get("chain", ""))
	if not last.is_empty() and str(rules(s).generates[last]) == str(t.element):
		var next := str(rules(s).generates[t.element])
		s.battle.orbs.append(next)
		s.combat_events.append({"type": "chain", "from": last, "to": str(t.element), "orbs": [next]})
	s.battle.chain = str(t.element)
	if int(s.battle.hp) <= 0:
		return _win(s)
	s.changed.emit()
	return text

## Orbs come into the player's hand during the turn.
static func _gain(s, orbs: Array) -> void:
	s.battle.orbs.append_array(orbs)
	s.combat_events.append({"type": "draw", "actor": "player", "orbs": orbs.duplicate()})

## Damage to the opponent through its shield; returns what reached it.
static func _strike_foe(s, damage: int) -> int:
	var absorbed := mini(int(s.battle.get("foe_shield", 0)), damage)
	s.battle.foe_shield = int(s.battle.get("foe_shield", 0)) - absorbed
	var dealt := damage - absorbed
	s.battle.hp = maxi(0, int(s.battle.hp) - dealt)
	return dealt

## 相生: two orbs of an element become one of the element it gives rise to; it takes no turn.
static func convert_qi(s, element: String) -> String:
	s.combat_events.clear()
	if s.battle.is_empty() or not element in elements(s):
		return "当前无法催生灵气。"
	var need := int(rules(s).convert)
	var names: Dictionary = s.content.technique_data.elements
	if s.battle.orbs.count(element) < need:
		return "%s灵气不足 %d 颗。" % [names[element].name, need]
	for count: int in need:
		s.battle.orbs.remove_at(s.battle.orbs.find(element))
	var made := str(rules(s).generates[element])
	s.battle.orbs.append(made)
	s.combat_events.append({"type": "convert", "from": element, "to": made, "count": need})
	s.changed.emit()
	return "%s生%s。" % [names[element].name, names[made].name]

## 结束回合: the orbs beyond the cap are let go, then the opponent acts.
static func end_turn(s, guarding: bool = false) -> String:
	if not guarding:
		s.combat_events.clear()
	if s.battle.is_empty():
		return "当前没有对手。"
	var cap := hand_cap(s)
	var released: Array = []
	while s.battle.orbs.size() > cap:
		var most := ""
		for element: String in s.battle.orbs:
			if most.is_empty() or s.battle.orbs.count(element) > s.battle.orbs.count(most):
				most = element
		s.battle.orbs.remove_at(s.battle.orbs.find(most))
		released.append(most)
	if not released.is_empty():
		s.combat_events.append({"type": "discard", "orbs": released})
	var lingering: Dictionary = s.battle.get("player_status", {})
	for status: String in ["weaken", "sunder", "slow"]:
		if lingering.has(status):
			_count_down(lingering, status)
	return _enemy_turn(s, guarding)

## 守御: the turn ends at once, the next blows are halved and one more orb comes next turn.
static func defend(s) -> String:
	s.combat_events.clear()
	if s.battle.is_empty():
		return "当前没有对手。"
	s.combat_events.append({"type": "guard", "amount": 0, "sect": str(s.player.get("sect", "wanderer"))})
	s.log_event("guard_turn", {"amount": int(rules(s).guard_orbs)})
	return end_turn(s, true)

## Why a pill cannot be taken in the duel now (`duel` in data/items.json), or "".
static func pill_block(s, item_id: String) -> String:
	if s.battle.is_empty():
		return "当前没有对手。"
	var item: Dictionary = s.content.item(item_id)
	if not item.has("duel"):
		return "斗法中服不得此物。"
	if s.item_count(item_id) < 1:
		return "行囊里没有%s。" % item.get("name", item_id)
	if int(s.battle.get("pills", 0)) >= int(rules(s).pills):
		return "这一场已服了 %d 枚丹药，药力再难化开。" % int(rules(s).pills)
	return ""

## Takes a pill in the duel without ending the turn: 回气丹 brings orbs, 疗伤丹 heals.
static func take_pill(s, item_id: String) -> String:
	s.combat_events.clear()
	var reason := pill_block(s, item_id)
	if not reason.is_empty():
		return reason
	var item: Dictionary = s.content.item(item_id)
	s.remove_item(item_id, 1)
	s.battle.pills = int(s.battle.get("pills", 0)) + 1
	var effect: Dictionary = item.duel
	if effect.has("orbs"):
		_gain(s, _draw(s, int(effect.orbs), player_weights(s)))
	if bool(effect.get("heal", false)):
		for granted: Dictionary in s.Inventory.pill_effects(s, item):
			if granted.has("hp"):
				var recovered := mini(int(granted.hp), int(s.player.max_hp) - int(s.player.hp))
				s.player.hp += recovered
				s.combat_events.append({"type": "heal", "style": "pill", "name": str(item.name), "vfx": "heal", "amount": recovered, "hp_after": int(s.player.hp)})
	var text: String = s.log_event("duel_pill", {"item": item_id})
	s.changed.emit()
	return text

## Presentation fields travel with each event, so generated techniques need no lookup tables.
static func _event(fields: Dictionary, look: Dictionary) -> Dictionary:
	var event := look.duplicate()
	event.merge(fields, true)
	return event

## 传音求援: a close friend answers the 传音 and strikes once; once a duel, it takes no turn.
static func call_aid(s, person_id: String) -> String:
	s.combat_events.clear()
	if not person_id in s.Bonds.allies(s):
		return "此刻无人可以求援。"
	s.battle.aid_used = true
	var dealt := _strike_foe(s, int(s.Bonds._strength(s, person_id)))
	s.combat_events.append({"type": "attack", "actor": "player", "style": "aid", "name": s.person(person_id).name, "vfx": "sword_rain", "tier": 3, "hits": 1, "amount": dealt, "hp_after": int(s.battle.hp)})
	var text: String = s.log_event("aid", {"npc": person_id, "amount": dealt})
	if int(s.battle.hp) <= 0:
		return _win(s)
	s.changed.emit()
	return text

static func flee(s) -> String:
	s.combat_events.clear()
	if s.battle.is_empty():
		return "当前无需撤退。"
	s.combat_events.append({"type": "end", "result": "flee"})
	var days := _recovery_days(s, "flee")
	s.battle.clear()
	# Outcomes are recorded on the day they happen; the recovery time follows.
	var message: String = s.log_event("flee", {"days": days})
	return s.conclude(message, s.advance_days(days))

## Duels started by events (road encounters, ruins) only cost a short rest afterwards.
static func _recovery_days(s, action: String) -> int:
	return s.content.action_days("road_recovery" if s.battle.get("context", "") == "event" else action)

## What the opponent means to do on its next turn. A generated cultivator draws its orbs now and plans
## up to three arts from them (healing when hurt, else its strongest, a shield when nothing else fits);
## others strike once.
static func _foe_prepare(s) -> void:
	var foe: Dictionary = s.battle.get("foe", {})
	if foe.get("arts", []).is_empty():
		var stats: Dictionary = foe if not foe.is_empty() else s.content.enemies[s.battle.enemy_id]
		var name: String = str(foe.get("art_name", "")) if not foe.is_empty() else _counter_name(s)
		s.battle.intent = [{"kind": "attack", "name": name, "min": int(stats.damage_min), "max": int(stats.damage_max)}]
		return
	var orbs: Array = s.battle.get("foe_orbs", [])
	var short := int(s.battle.status.slow[0]) if s.battle.get("status", {}).has("slow") else 0
	orbs.append_array(_draw(s, maxi(1, _by_realm(s, "foe_draw", int(foe.get("realm", 0))) - short), _foe_weights(s)))
	while orbs.size() > int(rules(s).hand_least) + 2 * int(foe.get("realm", 0)) + 1:
		orbs.remove_at(0)
	s.battle.foe_orbs = orbs
	var left := orbs.duplicate()
	var plan: Array = []
	var hurt := int(s.battle.hp) * 5 < int(foe.hp) * 2
	for step: int in 3:
		var pick: Dictionary = {}
		for art_id: Variant in foe.arts:
			var art: Dictionary = s.content.technique(str(art_id))
			if art.is_empty() or art.slot != "art" or not affordable(left, art.cost):
				continue
			if plan.any(func(entry: Dictionary) -> bool: return entry.kind in ["heal", "guard"] and entry.kind == art.kind):
				continue
			var worth := 0
			match str(art.kind):
				"heal":
					worth = 1000 if hurt else -1
				"guard":
					worth = 1
				_:
					worth = 100 + int(art.damage_max)
			if worth > int(pick.get("worth", 0)):
				pick = {"worth": worth, "art": art}
		if pick.is_empty():
			break
		var chosen: Dictionary = pick.art
		_pay(left, chosen.cost)
		var entry := {"art": str(chosen.id), "kind": str(chosen.kind), "name": str(chosen.name)}
		match str(chosen.kind):
			"heal":
				entry.amount = int(chosen.heal)
			"guard":
				entry.amount = int(chosen.shield)
			_:
				# The realm's bonus counts half per orb, as for the player.
				var share := int(round(float(foe.bonus) * _orbs_in(chosen.cost) / 2.0))
				entry.min = maxi(1, int(round(float(chosen.damage_min) * float(foe.power))) + share)
				entry.max = maxi(1, int(round(float(chosen.damage_max) * float(foe.power))) + share)
		plan.append(entry)
	if plan.is_empty():
		plan.append({"kind": "gather", "name": "凝神聚气"})
	s.battle.intent = plan

static func _enemy_turn(s, guarding: bool) -> String:
	var enemy_id: String = s.battle.enemy_id
	# Lingering effects on the opponent act first: burning can finish a fight.
	var status: Dictionary = s.battle.get("status", {})
	if status.has("burn"):
		var burn: Array = status.burn
		s.battle.hp = maxi(0, int(s.battle.hp) - int(burn[0]))
		s.combat_events.append({"type": "attack", "actor": "player", "style": "burn", "name": "灼烧", "vfx": "flame_bolt", "tier": 1, "hits": 1, "amount": int(burn[0]), "hp_after": int(s.battle.hp)})
		_count_down(status, "burn")
		if int(s.battle.hp) <= 0:
			return _win(s)
	s.battle.foe_shield = 0
	var factor: float = 1.0 - s.defense()
	if status.has("weaken"):
		factor *= 1.0 - float(status.weaken[0])
		_count_down(status, "weaken")
	var foe: Dictionary = s.battle.get("foe", {})
	for planned: Dictionary in s.battle.get("intent", []):
		if not planned.has("art"):
			if str(planned.kind) == "attack":
				var stats: Dictionary = foe if not foe.is_empty() else s.content.enemies[enemy_id]
				var blow := {"style": _counter_style(s)}
				if not foe.is_empty():
					blow = {"style": foe.art, "name": foe.art_name, "vfx": foe.vfx, "tier": int(foe.tier)}
				# Without orbs to be short of, a slowed opponent strikes weaker.
				var strength: float = factor * (SLOW_BLOW if status.has("slow") else 1.0)
				if _hurt_player(s, s.combat_rng.randi_range(int(stats.damage_min), int(stats.damage_max)), strength, guarding, blow):
					return _lose(s)
			continue
		var art: Dictionary = s.content.technique(str(planned.art))
		if art.is_empty() or not affordable(s.battle.foe_orbs, art.cost):
			continue
		var spent := _pay(s.battle.foe_orbs, art.cost)
		var look := {"style": str(art.id), "name": str(art.name), "vfx": str(art.vfx), "tier": int(art.tier), "element": str(art.element), "spent": spent}
		match str(art.kind):
			"heal":
				var recovered := mini(int(art.heal), int(foe.hp) - int(s.battle.hp))
				s.battle.hp = int(s.battle.hp) + recovered
				s.combat_events.append(_event({"type": "heal", "actor": "enemy", "amount": recovered, "hp_after": int(s.battle.hp)}, look))
			"guard":
				s.battle.foe_shield = int(s.battle.get("foe_shield", 0)) + int(art.shield)
				s.combat_events.append(_event({"type": "guard", "actor": "enemy", "amount": 0, "shield": int(s.battle.foe_shield)}, look))
			_:
				for lingering: String in LINGERING:
					if art.has(lingering):
						s.battle.player_status[lingering] = lingering_value(lingering, art[lingering])
				if _hurt_player(s, s.combat_rng.randi_range(int(planned.min), int(planned.max)), factor, guarding, look):
					return _lose(s)
	# The player's turn: the shield has done its work, burning bites, new orbs come and the opponent
	# shows its next intent.
	s.battle.shield = 0
	s.battle.turn += 1
	s.battle.chain = ""
	var burning: Dictionary = s.battle.get("player_status", {})
	if burning.has("burn"):
		var bite := mini(int(burning.burn[0]), int(s.player.hp) - 1)
		s.player.hp = int(s.player.hp) - bite
		s.combat_events.append({"type": "attack", "actor": "enemy", "style": "burn", "name": "灼烧", "vfx": "flame_bolt", "tier": 1, "hits": 1, "amount": bite, "hp_after": int(s.player.hp)})
		_count_down(burning, "burn")
	var short := int(burning.slow[0]) if burning.has("slow") else 0
	_gain(s, _draw(s, maxi(1, draw_count(s) - short + (int(rules(s).guard_orbs) if guarding else 0)), player_weights(s)))
	_foe_prepare(s)
	# The opponent's sunder and slow last through its turns.
	for lingering: String in ["sunder", "slow"]:
		if status.has(lingering):
			_count_down(status, lingering)
	s.changed.emit()
	return "轮到你出招。"

## One blow at the player through defense, a weakening, a guard and the shield. True when it fells them.
static func _hurt_player(s, roll: int, factor: float, guarding: bool, look: Dictionary) -> bool:
	var sundered: Dictionary = s.battle.get("player_status", {})
	if sundered.has("sunder"):
		factor *= 1.0 + float(sundered.sunder[0])
	var damage := maxi(1, int(round(float(roll) * factor)))
	if guarding:
		damage = maxi(1, damage / 2)
	var absorbed := mini(int(s.battle.get("shield", 0)), damage)
	s.battle.shield = int(s.battle.get("shield", 0)) - absorbed
	damage -= absorbed
	s.player.hp = maxi(0, int(s.player.hp) - damage)
	s.combat_events.append(_event({"type": "attack", "actor": "enemy", "amount": damage, "absorbed": absorbed, "hp_after": int(s.player.hp)}, look))
	s.log_event("enemy_attack", {"enemy": s.battle.enemy_id, "amount": damage})
	return int(s.player.hp) <= 0

static func _lose(s) -> String:
	s.combat_events.append({"type": "end", "result": "lose"})
	if s.battle.get("context", "") == "spar":
		return _spar_over(s, false)
	if s.battle.get("context", "") == "tournament":
		return _tournament_over(s, false)
	s.battle.clear()
	s.record_deed("duel")
	var lost := mini(int(s.player.stones), 10)
	s.player.stones -= lost
	s.player.location = "sect"
	s.player.journey = {}
	var message: String = s.log_event("battle_defeat", {"lost": lost})
	var passed: Dictionary = s.advance_days(s.content.action_days("battle_defeat"))
	s.player.hp = maxi(1, int(s.player.max_hp) / 2)
	s.player.qi = s.player.max_qi
	return s.conclude(message, passed)

## A plain full turn (simulations, tests): heal when low, otherwise cast the strongest affordable arts
## while orbs last, 相生 when three orbs of an element sit idle, then end the turn.
static func plain_turn(s) -> String:
	var text := ""
	for step: int in 8:
		if s.battle.is_empty():
			return text
		var best := ""
		var best_worth := -1
		for art_id: String in s.active_skills():
			var t: Dictionary = s.content.technique(art_id)
			if t.is_empty() or not affordable(s.battle.orbs, t.cost):
				continue
			var worth := int(t.get("damage_max", 0))
			if t.kind == "heal":
				worth = 500 if int(s.player.hp) * 5 < int(s.player.max_hp) * 2 else -1
			elif t.kind == "guard":
				worth = 0
			if worth > best_worth:
				best_worth = worth
				best = art_id
		if best.is_empty():
			var idle: Array = elements(s).filter(func(element: String) -> bool: return s.battle.orbs.count(element) >= 3)
			if idle.is_empty():
				break
			convert_qi(s, str(idle[0]))
			continue
		text = use_skill(s, best)
	if s.battle.is_empty():
		return text
	return end_turn(s)

## The simplest full turn: casts the art if the orbs allow, then ends the turn (simulations, tests).
static func duel_turn(s, skill_id: String) -> String:
	var t: Dictionary = s.content.technique(skill_id)
	var text := ""
	if not s.battle.is_empty() and not t.is_empty() and affordable(s.battle.orbs, t.cost):
		text = use_skill(s, skill_id)
	if s.battle.is_empty():
		return text
	return end_turn(s)

## A spar ends without loss: the loser keeps a sliver of health, both sides gain a little.
static func _spar_over(s, won: bool) -> String:
	var npc: String = s.battle.npc
	var xp: int = int(s.battle.foe.xp) if won else int(s.battle.foe.xp) / 2
	var invite: String = str(s.battle.get("invite", ""))
	s.battle.clear()
	s.record_deed("duel")
	s.player.hp = maxi(int(s.player.hp), 1)
	s.Events.apply(s, [{"relation": [npc, 5 if won else 2]}])
	var message: String = s.log_event("spar_win" if won else "spar_lose", {"npc": npc, "xp": xp})
	message = _with_milestones(message, s.gain_insight("spar"))
	message = _with_milestones(message, s.gain_xp(xp))
	if won:
		message = _with_milestones(message, s.Fortune.after_win(s, int(s.person(npc).get("realm", 0))))
	if not invite.is_empty():
		message = _with_milestones(message, s.Bonds.spar_kept(s, invite, npc, won))
	return s.conclude(message, s.advance_days(s.content.action_days("road_recovery")))

static func _with_milestones(message: String, milestones: Array[String]) -> String:
	return message if milestones.is_empty() else message + " " + " ".join(milestones)

## Tournament rounds: a win leads straight into the next round with some health back; the third
## win takes the prize. A loss ends the run without any penalty. Every round counts as a spar's insight.
static func _tournament_over(s, won: bool) -> String:
	var round: int = int(s.battle.get("round", 1))
	var npc: String = s.battle.get("npc", "")
	s.battle.clear()
	s.record_deed("duel")
	if not won:
		s.player.hp = maxi(int(s.player.hp), 1)
		var out: String = s.log_event("tournament_out", {"round": round, "npc": npc})
		return s.conclude(_with_milestones(out, s.gain_insight("spar")), s.advance_days(s.content.action_days("road_recovery")))
	var message: String = _with_milestones(s.log_event("tournament_round", {"round": round, "npc": npc}), s.gain_insight("spar"))
	message += " " + s.Sect.gain(s, int(s.content.sect_data.awards.get("tournament_round", 0)), "小比胜了一轮")
	if round < 3:
		s.player.hp = mini(int(s.player.max_hp), int(s.player.hp) + int(s.player.max_hp) * 3 / 10)
		s.player.qi = mini(int(s.player.max_qi), int(s.player.qi) + int(s.player.max_qi) * 3 / 10)
		s.begin_tournament(round + 1)
		s.changed.emit()
		return message + " 下一轮开始。"
	var prize: String = "j:" + s.Arsenal.generate_technique(s.content, s.world_rng, 2, {"slot": "art"})
	s.add_item(prize, 1)
	s.player.stones += 100
	message += " " + s.log_event("tournament_champion", {"stones": 100, "xp": 150, "item": prize}, true)
	s.record_deed("tournament_champion")
	message += " " + s.Sect.gain(s, int(s.content.sect_data.awards.get("tournament_champion", 0)), "外门小比夺魁")
	message = _with_milestones(message, s.gain_xp(150))
	message = _with_milestones(message, s.congratulate("champion"))
	return s.conclude(message, s.advance_days(s.content.action_days("road_recovery")))

static func _count_down(status: Dictionary, key: String) -> void:
	status[key][1] = int(status[key][1]) - 1
	if int(status[key][1]) <= 0:
		status.erase(key)

## The name a handwritten opponent's blow goes by: a person's lineage art, else the beast's own.
static func _counter_name(s) -> String:
	var enemy: Dictionary = s.content.enemies[s.battle.enemy_id]
	if not bool(enemy.get("human", false)):
		return "%s扑击" % enemy.name
	return str(s.content.technique(_counter_style(s)).get("name", enemy.name))

static func _counter_style(s) -> String:
	if not bool(s.content.enemies[s.battle.enemy_id].get("human", false)):
		return "enemy"
	var sect_id: String = s.battle.get("opponent_sect", "qingyun")
	return str(s.content.sects[sect_id].skills[0])

static func _win(s) -> String:
	s.combat_events.append({"type": "end", "result": "win"})
	if s.battle.get("context", "") == "spar":
		return _spar_over(s, true)
	if s.battle.get("context", "") == "tournament":
		return _tournament_over(s, true)
	var enemy_id: String = s.battle.enemy_id
	var enemy: Dictionary = s.content.enemies[enemy_id]
	var days := _recovery_days(s, "battle_victory")
	var npc: String = s.battle.get("npc", "")
	s.record_kill(enemy_id)
	s.record_deed("duel")
	s.record_deed("win:" + enemy_id)
	s.player.stones += int(enemy.reward_stones)
	s.add_item("huichun_grass", int(enemy.reward_herbs))
	s.battle.clear()
	var message: String = s.log_event("battle_victory", {"enemy": enemy_id, "stones": int(enemy.reward_stones), "xp": int(enemy.reward_xp), "herbs": int(enemy.reward_herbs)})
	# A defeated regional threat changes the world; the journey itself continues.
	var flag: String = enemy.get("world_flag", "")
	if not flag.is_empty() and not s.has_flag(flag):
		s.world.flags[flag] = true
		message += " " + s.log_event(enemy.flag_event, {}, true)
		if enemy.has("congrats"):
			message = _with_milestones(message, s.congratulate(str(enemy.congrats)))
		if enemy.has("contribution"):
			message += " " + s.Sect.gain(s, int(enemy.contribution), "为宗门除去%s" % enemy.name)
	if enemy.has("drops") and s.world_rng.randf() < float(enemy.drops.chance):
		var tier: int = s.world_rng.randi_range(int(enemy.drops.tiers[0]), int(enemy.drops.tiers[1]))
		var loot: String = "j:" + s.Arsenal.generate_technique(s.content, s.world_rng, tier) if s.world_rng.randf() < 0.5 else s.Arsenal.generate_equipment(s.content, s.world_rng, tier)
		s.add_item(loot, 1)
		message += " " + s.log_event("loot", {"loot": loot + ":1"})
	message = _with_milestones(message, s.gain_insight("battle_win"))
	message = _with_milestones(message, s.gain_xp(int(enemy.reward_xp)))
	# Won with almost nothing left against a foe of one's own realm or above: perhaps 生死之间.
	message = _with_milestones(message, s.Fortune.after_win(s, int(enemy.min_realm)))
	s.npc_depart(npc)
	return s.conclude(message, s.advance_days(days))
