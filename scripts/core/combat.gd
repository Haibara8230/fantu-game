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

## 历练 (docs/COMBAT_PLAN.md, part two, B1): days in the wilds, then a beast from the place's table
## (data/world.json location `hunt`) that the player's realm can face, fought as an encounter (a short
## rest after). Drawn on the world stream, so the same world meets the same beasts.
static func hunt(s) -> String:
	var hunting: Dictionary = s.content.locations[str(s.player.location)].get("hunt", {})
	var open: Array = hunting.get("table", []).filter(func(entry: Dictionary) -> bool: return int(s.content.enemies[entry.enemy].min_realm) <= int(s.player.realm))
	if open.is_empty():
		return "此地没有你应付得来的妖兽。"
	var passed: Dictionary = s.advance_days(int(hunting.days))
	if not s.ended.is_empty() or not s.pending_event.is_empty():
		return s.conclude("", passed)
	var total := 0
	for entry: Dictionary in open:
		total += int(entry.weight)
	var roll: int = s.world_rng.randi_range(1, total)
	var pick: String = open[0].enemy
	for entry: Dictionary in open:
		roll -= int(entry.weight)
		if roll <= 0:
			pick = str(entry.enemy)
			break
	s.record_deed("hunt")
	var text: String = s.log_event("hunt_start", {"days": passed.elapsed, "location": s.player.location, "enemy": pick})
	begin_battle(s, pick, "event")
	return s.conclude(text, passed)

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
	s.battle.opening_percent = int(s.player.hp) * 100 / maxi(1, int(s.player.max_hp))
	s.battle.old_wound = int(s.player.get("wound_until", 0)) > int(s.world.day) or int(s.player.get("injury_until", 0)) > int(s.world.day)
	s.battle.guarded_turns = 0
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

## A round of 潜龙会 against the 炼气 cultivators of the region present, weakest first; the last against
## 萧凌云 while his bout is due (rival.gd).
static func begin_tournament(s, round: int) -> void:
	if round == 3 and s.Rival.qianlong_due(s):
		s.Rival.begin_qianlong(s, round)
		return
	var disciples: Array = s.present_npcs().filter(func(person_id: String) -> bool: return s.is_generated(person_id) and int(s.person(person_id).realm) == 0)
	disciples.sort_custom(func(a: String, b: String) -> bool:
		var ra := int(s.person(a).realm) * 10 + int(s.person(a).stage)
		var rb := int(s.person(b).realm) * 10 + int(s.person(b).stage)
		return ra < rb or (ra == rb and a < b))
	if disciples.is_empty():
		begin_battle(s, "cultivator", "event")
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
# As in Mi Chang Sheng: each turn the player absorbs five qi orbs, drawn by the weight of the spirit
# roots alone (an element without a root never comes, unless a talent, an art or a piece of gear draws
# it in). An art is cast by spending the orbs its cost names — an element, 同 (that many of one
# element, whichever) or 任意 (any) — several arts a turn while orbs last, and 结束回合 hands the turn
# over. At most four orbs (hand_least, and what holds more) stay at the end of a turn: the player
# chooses which to let go. There is no conversion of its own and no 克制: qi is turned into another
# element only by arts that do it (the 印, `absorb`), and each art has its own 连击 (`combo`): when the
# art cast before it was of the element it names, it does more. 聚气 (`gather`) brings more orbs next
# turn. 遁速 decides who moves first and how readily one gets away.
# The opponent shows what it means to do next (intent). Generated cultivators draw orbs of their own
# and cast their whole loadout from them; beasts and the handwritten foes strike once a turn.
# battle: orbs (the player's), last (the element of the art cast last), next_draw, shield,
# player_status, pills; foe_orbs, foe_shield, intent [{"art"?, "kind", "name", "min", "max" | "amount"}].

## Lingering effects either side may carry: 灼烧 (burn: damage each turn), 寒蚀 (weaken: deals less),
## 破甲 (sunder: takes more), 冰封 (slow: draws fewer orbs, or strikes weaker without orbs), 流血 (bleed:
## damage each turn, piling up), 缠绕 (entangle: draws fewer orbs and cannot flee), 禁疗 (wound: heals
## less), 蓄势 (focus: the next blow lands harder, then it is spent), 召唤 (minions: helpers strike each
## turn); each [amount, turns]. docs/COMBAT_PLAN.md, part one, stage one.
const LINGERING := ["burn", "weaken", "sunder", "slow", "bleed", "entangle", "wound", "focus", "minions", "fervor"]
# Lingering effects kept as a share rather than a whole amount.
const SHARES := ["weaken", "sunder", "wound", "focus", "fervor"]
# 流血 piles up to this much at most.
const BLEED_MOST := 12
# Kinds of move a handwritten opponent may make (data/world.json enemies' `moves`).
const MOVE_KINDS := ["attack", "charge", "heal", "guard", "focus", "summon"]
## How much weaker a slowed opponent without orbs strikes.
const SLOW_BLOW := 0.8
## The share of its 遁速 an opponent bound by a whip keeps.
const ENTANGLED_SPEED := 0.7

## A lingering effect as it is kept: a share (weaken, sunder) or a whole amount, and whole turns, the
## same whether it came from the data or from a save.
static func lingering_value(key: String, value: Array) -> Array:
	return [float(value[0]) if key in SHARES else int(value[0]), int(value[1])]

## Puts a lingering effect on one side: 流血 piles up (to BLEED_MOST) and lasts the longer of the two;
## the others are replaced.
static func _inflict(status: Dictionary, key: String, value: Array) -> void:
	var added := lingering_value(key, value)
	if key == "bleed" and status.has("bleed"):
		status.bleed = [mini(BLEED_MOST, int(status.bleed[0]) + int(added[0])), maxi(int(status.bleed[1]), int(added[1]))]
		return
	status[key] = added

## A heal through 禁疗: what is left of `amount`.
static func _healed(status: Dictionary, amount: int) -> int:
	return int(round(float(amount) * (1.0 - float(status.wound[0])))) if status.has("wound") else amount

static func rules(s) -> Dictionary:
	return s.content.rules.duel

static func elements(s) -> Array:
	return s.content.technique_data.elements.keys()

## How many orbs the player keeps at the end of a turn: four, and what talents, arts and equipment
## hold more (orb_cap).
static func hand_cap(s) -> int:
	return int(rules(s).hand_least) + int(s.orb_bonus("orb_cap"))

## Orbs the player draws each turn: the realm's, and what talents, arts and equipment add (orb_draw).
static func draw_count(s) -> int:
	return _by_realm(s, "draw", int(s.player.realm)) + int(s.orb_bonus("orb_draw"))

## With five orbs a turn in every realm, an art's strength grows with the realm instead (realm_power):
## the player's arts and a generated opponent's alike.
static func realm_power(s, realm: int) -> float:
	var power: Array = rules(s).realm_power
	return float(power[clampi(realm, 0, power.size() - 1)])

static func _by_realm(s, key: String, realm: int) -> int:
	var counts: Array = rules(s)[key]
	return int(counts[clampi(realm, 0, counts.size() - 1)])

## Draw weights for the player: the spirit roots' elements alone (other_weight is none), and an element
## favoured by talents, arts or equipment (orb_<element>) heavier, even without its root.
static func player_weights(s) -> Dictionary:
	var weights := {}
	for element: String in elements(s):
		weights[element] = (int(rules(s).root_weight) if element in s.player.get("roots", []) else int(rules(s).other_weight)) + int(s.orb_bonus("orb_" + element))
	return weights

## Draw weights for a generated opponent, whose roots nobody knows: the elements of its arts heavier,
## the others still coming now and then (foe_weights), as they would from mixed roots.
static func _foe_weights(s) -> Dictionary:
	var weights := {}
	var favoured: Array = [foe_element(s)]
	for art_id: Variant in s.battle.get("foe", {}).get("arts", []):
		favoured.append(str(s.content.technique(str(art_id)).get("element", "")))
	for element: String in elements(s):
		weights[element] = int(rules(s).foe_weights[0]) if element in favoured else int(rules(s).foe_weights[1])
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

## The first turn of a duel: the player's first hand, and the opponent's orbs and intent. A quicker
## opponent (遁速, foe_leads) moves first: its opening lands before the player's first hand is drawn.
static func open_hand(s) -> void:
	if wounded(s):
		s.player.hp = mini(int(s.player.hp), int(round(float(s.player.max_hp) * float(rules(s).get("wound_hp", 0.75)))))
	s.battle.orbs = []
	s.battle.last = ""
	s.battle.shield = 0
	s.battle.foe_shield = 0
	s.battle.foe_orbs = []
	s.battle.player_status = {}
	s.battle.pills = 0
	s.battle.cooldowns = {}
	var extra := int(rules(s).first_extra) + int(s.orb_bonus("orb_first"))
	var tide := tide_orbs(s)
	if foe_leads(s):
		s.battle.foe_led = true
		s.battle.next_draw = extra
		if tide > 0:
			s.battle.tide = tide
		_foe_prepare(s)
		s.combat_events.append({"type": "lead", "actor": "enemy", "speed": foe_speed(s), "player_speed": speed(s)})
		# The opening cannot fell the player: whoever starts a duel finds it still open after it.
		s.battle.leading = true
		_enemy_turn(s, false)
		s.battle.erase("leading")
		s.battle.turn = 1
		return
	var drawn := _draw(s, draw_count(s) + extra, player_weights(s))
	for count: int in tide:
		drawn.append("water")
	s.battle.orbs = drawn
	s.combat_events.append({"type": "draw", "actor": "player", "orbs": drawn.duplicate()})
	_foe_prepare(s)

## 听潮 (orb_tide on a piece): on ground that carries water (a 临水 or 临海 field), the duel opens with
## that many more water orbs; elsewhere none.
static func tide_orbs(s) -> int:
	if float(field(s).get("mods", {}).get("water", 0.0)) <= 0.0:
		return 0
	return int(s.orb_bonus("orb_tide"))

## Whether `orbs` cover `cost`.
static func affordable(orbs: Array, cost: Dictionary) -> bool:
	var left := orbs.duplicate()
	for key: String in cost:
		if key in ["any", "same"]:
			continue
		for count: int in int(cost[key]):
			var at := left.find(key)
			if at < 0:
				return false
			left.remove_at(at)
	if cost.has("same"):
		var kind := _same_kind(left, int(cost.same))
		if kind.is_empty():
			return false
		for count: int in int(cost.same):
			left.remove_at(left.find(kind))
	return left.size() >= int(cost.get("any", 0))

## The element 同×`count` is paid in: the most plentiful one that has enough, or "".
static func _same_kind(orbs: Array, count: int) -> String:
	var best := ""
	for element: String in orbs:
		if orbs.count(element) >= count and (best.is_empty() or orbs.count(element) > orbs.count(best)):
			best = element
	return best

## Takes `cost` out of `orbs`: the named elements first, then 同 from the most plentiful element that
## has enough, then "any" from the most plentiful. Returns the orbs spent.
static func _pay(orbs: Array, cost: Dictionary) -> Array:
	var spent: Array = []
	for key: String in cost:
		if key in ["any", "same"]:
			continue
		for count: int in int(cost[key]):
			orbs.remove_at(orbs.find(key))
			spent.append(key)
	if cost.has("same"):
		var kind := _same_kind(orbs, int(cost.same))
		for count: int in int(cost.same):
			orbs.remove_at(orbs.find(kind))
			spent.append(kind)
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

## 连击: whether `t`'s combo holds — the art cast before it was of the element its combo names, or a
## 心法 the player runs links the two elements (linked_combo).
static func combo_holds(s, t: Dictionary) -> bool:
	return (t.has("combo") and str(s.battle.get("last", "")) == str(t.combo.after)) or not linked_combo(s, t).is_empty()

## A 心法 that links two elements (《照水分光诀》, its `link`: {"elements", "bonus", "absorb"}): an art of
## one cast right after an art of the other counts as a 连击 even where its own combo names something
## else. The link's terms when it carries `t` now, else {}; never when the art's own combo holds.
static func linked_combo(s, t: Dictionary) -> Dictionary:
	var last := str(s.battle.get("last", ""))
	if last.is_empty() or last == str(t.get("element", "")) or (t.has("combo") and last == str(t.combo.after)):
		return {}
	for method_id: Variant in s.player.get("methods", []):
		var link: Dictionary = s.content.skills.get(str(method_id), {}).get("link", {})
		if not link.is_empty() and str(t.get("element", "")) in link.elements and last in link.elements:
			return link
	return {}

static func use_skill(s, skill_id: String) -> String:
	s.combat_events.clear()
	var t: Dictionary = s.held_technique(skill_id)
	if s.battle.is_empty() or t.is_empty() or t.slot != "art":
		return "当前无法施展神通。"
	if skill_id not in s.active_skills():
		return "此神通未在运转。"
	if not affordable(s.battle.orbs, t.cost):
		return "灵气不足：%s需要%s。" % [t.name, s.Arsenal.cost_text(s.content, t.cost)]
	var spent := _pay(s.battle.orbs, t.cost)
	# 连击: the art before it was of the element its combo names, or a linked one (linked_combo).
	var link := linked_combo(s, t)
	var partner := str(s.battle.get("last", ""))
	var combo := combo_holds(s, t)
	var bonus := float(link.get("bonus", 0.0)) if not link.is_empty() else (float(t.combo.get("bonus", 0.0)) if combo else 0.0)
	var boost := (1.0 + bonus) * realm_power(s, int(s.player.realm))
	var look := {"style": skill_id, "name": t.name, "vfx": t.vfx, "tier": int(t.tier), "element": t.element, "spent": spent, "combo": combo}
	_soul_strike(s)
	# A sect's own art cast by its disciple carries the lineage's signature layer.
	var lineage: String = s.content.legacy_sect(skill_id, str(s.player.get("sect", "wanderer")))
	if not lineage.is_empty():
		look.legacy = lineage
	var text := ""
	match str(t.kind):
		"heal":
			var recovered := mini(_healed(s.battle.get("player_status", {}), int(round(float(t.heal) * boost))), int(s.player.max_hp) - int(s.player.hp))
			s.player.hp += recovered
			s.combat_events.append(_event({"type": "heal", "amount": recovered, "hp_after": int(s.player.hp)}, look))
			text = s.log_event("skill_heal", {"skill": skill_id, "amount": recovered})
		"guard":
			var shield := int(round(float(t.shield) * boost))
			s.battle.shield = int(s.battle.get("shield", 0)) + shield
			s.combat_events.append(_event({"type": "guard", "amount": 0, "shield": int(s.battle.shield)}, look))
			text = s.log_event("skill_shield", {"skill": skill_id, "amount": shield})
		"spirit":
			# 印 and 聚气 deal nothing: they turn qi (absorb, below) or bring more of it next turn.
			if t.has("gather"):
				s.battle.next_draw = int(s.battle.get("next_draw", 0)) + int(t.gather)
			s.combat_events.append(_event({"type": "spirit", "amount": int(t.get("gather", 0))}, look))
			text = s.log_event("skill_spirit", {"skill": skill_id})
		_:
			# The realm's attack bonus counts half for each orb spent, so many small arts gain no more
			# from it than one great one.
			var roll: int = s.combat_rng.randi_range(int(t.damage_min), int(t.damage_max)) + int(round(float(s.attack_bonus()) * spent.size() / 2.0))
			var factor: float = s.element_multiplier(t) * boost * ground(s, str(t.element), false) * _school_force(s, str(t.element))
			if s.battle.get("player_status", {}).has("fervor"):
				factor *= 1.0 + float(s.battle.player_status.fervor[0])
			if s.battle.get("player_status", {}).has("weaken"):
				factor *= 1.0 - float(s.battle.player_status.weaken[0])
			if s.battle.status.has("sunder"):
				factor *= 1.0 + float(s.battle.status.sunder[0])
			# A hammer's blow breaks the opponent's shield before it lands.
			if bool(t.get("shatter", false)):
				s.battle.foe_shield = 0
			var dealt := _strike_foe(s, maxi(1, int(round(float(roll) * factor))), bool(t.get("through", false)))
			if int(t.hits) > 1:
				_sweep(s, int(round(float(roll) * factor * PACK_SPLASH)))
			s.combat_events.append(_event({"type": "attack", "actor": "player", "hits": int(t.hits), "amount": dealt, "hp_after": int(s.battle.hp)}, look))
			text = s.log_event("skill_attack", {"skill": skill_id, "amount": dealt})
			if t.has("lifesteal"):
				var healed := mini(int(round(dealt * float(t.lifesteal))), int(s.player.max_hp) - int(s.player.hp))
				if healed > 0:
					s.player.hp += healed
					s.combat_events.append(_event({"type": "heal", "amount": healed, "hp_after": int(s.player.hp)}, look))
			for status: String in LINGERING:
				if t.has(status):
					_inflict(s.battle.status, status, t[status])
	if combo:
		s.combat_events.append({"type": "combo", "name": t.name, "after": partner if not link.is_empty() else str(t.combo.after), "element": str(t.element)})
	# Each cast is practice toward the art's next layer (layers.gd).
	var reached: Array[String] = s.Layers.after_cast(s, skill_id)
	if not reached.is_empty():
		text = " ".join([text] + reached)
	if t.has("draw"):
		_gain(s, _draw(s, int(t.draw), player_weights(s)))
	if t.has("renew"):
		_gain(s, [str(t.element)])
	# 印: qi of another element drawn in, more of it on a 连击.
	if t.has("absorb"):
		var absorbed: Array = []
		for count: int in int(t.absorb[1]) + (int(t.combo.get("absorb", 0)) if combo and link.is_empty() else 0):
			absorbed.append(str(t.absorb[0]))
		_gain(s, absorbed)
	# A linked 连击 draws in qi of the element it came after, so the two can keep answering each other.
	if int(link.get("absorb", 0)) > 0:
		var drawn: Array = []
		for count: int in int(link.absorb):
			drawn.append(partner)
		_gain(s, drawn)
	s.battle.last = str(t.element)
	if int(s.battle.hp) <= 0:
		return _win(s)
	s.changed.emit()
	return text

## An opponent's art as they hold it: at the cap of their realm (layers.gd); the 心魔 holds the player's
## own layers.
static func foe_art(s, foe: Dictionary, art_id: String) -> Dictionary:
	if str(foe.get("name", "")) == "心魔" and art_id in s.player.get("learned", []):
		return s.held_technique(art_id)
	return s.Layers.at_realm(s.content, art_id, int(foe.get("realm", s.content.realms.size())))

## Orbs come into the player's hand during the turn.
static func _gain(s, orbs: Array) -> void:
	s.battle.orbs.append_array(orbs)
	s.combat_events.append({"type": "draw", "actor": "player", "orbs": orbs.duplicate()})

## Damage to the opponent through its shield (past it, `through`: a spear's thrust); returns what reached it.
static func _strike_foe(s, damage: int, through: bool = false) -> int:
	# Against 天劫, a blow disperses the coming bolt instead.
	if s.battle.get("context", "") == "tribulation":
		s.battle.dispel = int(s.battle.get("dispel", 0)) + damage
		return damage
	var target := int(s.battle.get("target", 0))
	if target > 0 and target <= s.battle.get("pack", []).size():
		return _strike_member(s, target - 1, damage)
	var absorbed := 0 if through else mini(int(s.battle.get("foe_shield", 0)), damage)
	s.battle.foe_shield = int(s.battle.get("foe_shield", 0)) - absorbed
	var dealt := damage - absorbed
	s.battle.hp = maxi(0, int(s.battle.hp) - dealt)
	return dealt

## 流派 in the player's blow (schools.gd): 剑意 grows with each metal art of the turn; 反震 answers a
## heavy blow taken, once.
static func _school_force(s, element: String) -> float:
	var force := 1.0
	match s.Schools.player(s):
		"sword":
			if element == "metal":
				var streak := int(s.battle.get("sword_streak", 0))
				force *= 1.0 + s.Schools.value(s, "sword", "stack") * float(mini(streak, int(s.Schools.value(s, "sword", "most"))))
				s.battle.sword_streak = streak + 1
		"body":
			if bool(s.battle.get("body_ready", false)):
				force *= 1.0 + s.Schools.value(s, "body", "counter_back")
				s.battle.erase("body_ready")
	return force

## 魂修: the turn's first art shakes the opponent: a generated one loses an orb, a beast is weakened.
static func _soul_strike(s) -> void:
	if s.Schools.player(s) != "soul" or int(s.battle.get("soul_turn", 0)) == int(s.battle.turn):
		return
	s.battle.soul_turn = int(s.battle.turn)
	var orbs: Array = s.battle.get("foe_orbs", [])
	if not orbs.is_empty():
		orbs.remove_at(0)
	else:
		_inflict(s.battle.status, "weaken", [s.Schools.value(s, "soul", "weaken"), 1])
	s.log_event("school_soul", {})

## 阵修 布阵: a turn spent laying the formation; from then on an orb and a shield every turn.
static func array_block(s) -> String:
	if s.battle.is_empty():
		return "当前没有对手。"
	if s.Schools.player(s) != "array":
		return "不通阵法。"
	if bool(s.battle.get("array", false)):
		return "阵已布下。"
	return ""

static func lay_array(s) -> String:
	s.combat_events.clear()
	var reason := array_block(s)
	if not reason.is_empty():
		return reason
	s.battle.array = true
	s.combat_events.append({"type": "guard", "amount": 0, "name": "布阵", "sect": str(s.player.get("sect", "wanderer"))})
	s.log_event("school_array", {})
	return end_turn(s)

## 地利 (docs/COMBAT_PLAN.md, part one, stage three): where a fight happens may favour some elements
## (a location's or a cave's `field`: {"name", "mods": {element: share}}), and a sect's own ground
## (a location's `home`) lends its people a tenth more force. Both sides alike; applied as blows land.
const HOME_EDGE := 0.1

static func field(s) -> Dictionary:
	var cave := str(s.battle.get("cave", ""))
	if not cave.is_empty():
		return s.content.cave_data.get(cave, {}).get("field", {})
	return s.content.locations.get(str(s.battle.get("place", "")), {}).get("field", {})

## The multiplier the ground gives an element's blows (and a sect's own ground its people's).
static func ground(s, element: String, foe_side: bool) -> float:
	var share := 1.0 + float(field(s).get("mods", {}).get(element, 0.0))
	var home := str(s.content.locations.get(str(s.battle.get("place", "")), {}).get("home", ""))
	if not home.is_empty() and s.battle.get("cave", "") == "":
		if foe_side and _foe_is_person(s) and str(s.battle.get("opponent_sect", "")) == home:
			share += HOME_EDGE
		elif not foe_side and str(s.player.get("sect", "")) == home:
			share += HOME_EDGE
	return share

static func _foe_is_person(s) -> bool:
	return s.battle.has("foe") or bool(s.content.enemies[str(s.battle.enemy_id)].get("human", false))

## "地火：火法 +20%、水法 -20%" and the home ground, or "".
static func ground_text(s) -> String:
	var parts: Array[String] = []
	var spot := field(s)
	var names: Dictionary = s.content.technique_data.elements
	if not spot.is_empty():
		var mods: Array[String] = []
		for element: String in spot.get("mods", {}):
			mods.append("%s法 %+d%%" % [names[element].name, int(round(float(spot.mods[element]) * 100.0))])
		parts.append("%s：%s" % [spot.name, "、".join(mods)])
	var home := str(s.content.locations.get(str(s.battle.get("place", "")), {}).get("home", ""))
	if not home.is_empty() and s.battle.get("cave", "") == "":
		if str(s.player.get("sect", "")) == home:
			parts.append("本门地界：你出手 +%d%%" % int(HOME_EDGE * 100.0))
		elif _foe_is_person(s) and str(s.battle.get("opponent_sect", "")) == home:
			parts.append("%s地界：对手出手 +%d%%" % [s.content.sects[home].name, int(HOME_EDGE * 100.0)])
	return " · ".join(parts)

## 神识探查 (part one, stage three): with 神识 above the opponent's the player sees its whole make-up
## before and during the fight; below it, only its name and rough cultivation.
## {"seen": bool, "lines": [String]}.
static func scout(s) -> Dictionary:
	var enemy: Dictionary = s.content.enemies[str(s.battle.enemy_id)]
	var foe: Dictionary = s.battle.get("foe", {})
	var npc := str(s.battle.get("npc", ""))
	var realm := int(foe.get("realm", enemy.min_realm)) if not foe.is_empty() else int(enemy.min_realm)
	var foe_sense: int = s.person_sense(npc) if not npc.is_empty() and s.is_person(npc) else int(s.content.stage(realm, 1).sense) + (10 if enemy.has("phases") else 0)
	var names: Dictionary = s.content.technique_data.elements
	var element := foe_element(s)
	var lines: Array[String] = []
	if s.sense() < foe_sense:
		lines.append("神识不及对手（%d / %d），只看出是%s修为。" % [s.sense(), foe_sense, s.content.realm(realm).name])
		return {"seen": false, "lines": lines}
	lines.append("神识压过对手（%d / %d）：" % [s.sense(), foe_sense])
	if names.has(element):
		lines.append("五行属%s，遁速 %d（你 %d）。" % [names[element].name, foe_speed(s), speed(s)])
	if not foe.is_empty():
		var arts: Array[String] = []
		for art_id: String in foe.get("arts", []):
			arts.append(str(s.content.technique(art_id).get("name", art_id)))
		lines.append("所修神通：%s。" % ("、".join(arts) if not arts.is_empty() else str(foe.get("art_name", "—"))))
	elif enemy.has("moves"):
		var moves: Array[String] = []
		for move: Dictionary in enemy.moves:
			moves.append(_move_word(move))
		lines.append("招式：%s。" % "、".join(moves))
		for phase: Dictionary in enemy.get("phases", []):
			var added: Array[String] = []
			for move: Dictionary in phase.get("moves", []):
				added.append(_move_word(move))
			lines.append("气血不足%d成时「%s」：出手 ×%.2f%s。" % [int(round(float(phase.below) * 10.0)), phase.name, float(phase.get("power", 1.0)), "，添" + "、".join(added) if not added.is_empty() else ""])
	var parts: Array[String] = []
	for part: Dictionary in enemy.get("parts", []):
		parts.append(str(s.content.item(str(part.item)).name))
	if not parts.is_empty():
		lines.append("身上可取：%s。" % "、".join(parts))
	return {"seen": true, "lines": lines}

static func _move_word(move: Dictionary) -> String:
	var kind := str(move.get("kind", "attack"))
	var notes: Array[String] = []
	match kind:
		"charge":
			notes.append("蓄力 ×%.1f" % float(move.get("power", 1.0)))
		"heal":
			notes.append("回血")
		"guard":
			notes.append("护盾")
		"focus":
			notes.append("蓄势")
		"summon":
			notes.append("召帮手")
	if int(move.get("hits", 1)) > 1:
		notes.append("%d 连击" % int(move.hits))
	for status: String in move.get("inflict", {}):
		notes.append({"bleed": "流血", "burn": "灼烧", "weaken": "削弱", "sunder": "破甲", "slow": "迟缓", "entangle": "缠绕", "wound": "禁疗"}.get(status, status))
	if move.has("drain"):
		notes.append("吸血")
	return str(move.name) + ("（%s）" % "，".join(notes) if not notes.is_empty() else "")

## 伤势 (part one, stage three): a lost fight leaves 外伤 and 内伤, a narrow win 外伤 (player.wound_until).
## While 外伤 lasts the player starts a fight short of health; 内伤 halves retreat gains (as a failed
## breakthrough's). 疗伤丹 or a night at an inn treats 外伤; 内伤 only heals with time.
static func wounded(s) -> bool:
	return int(s.world.day) < int(s.player.get("wound_until", 0))

static func _wound(s, days: int, inner_days: int = 0) -> void:
	s.player["wound_until"] = maxi(int(s.player.get("wound_until", 0)), int(s.world.day) + days)
	if inner_days > 0:
		s.player["injury_until"] = maxi(int(s.player.get("injury_until", 0)), int(s.world.day) + inner_days)

## 禁忌秘术 (docs/COMBAT_PLAN.md, part one, stage five): a burst bought with lifespan, a crippling
## injury or a 妖丹, each once a duel, from 筑基 (rules `secret_arts`). Their costs are written into the
## character at once (player.burned_years, injury_until, the pack), so every save after keeps them and no
## change of gear undoes them. None in a bout among fellows.
static func secret_block(s, art_id: String) -> String:
	if s.battle.is_empty():
		return "当前没有对手。"
	var art: Dictionary = rules(s).get("secret_arts", {}).get(art_id, {})
	if art.is_empty():
		return "没有这门秘术。"
	if int(s.player.realm) < int(art.min_realm):
		return "须%s方能催动禁忌秘术。" % s.content.realm(int(art.min_realm)).name
	if s.battle.get("context", "") in ["spar", "tournament", "summit", "arena", "tianji"]:
		return "比斗点到为止，用不着搏命的秘术。"
	if art_id in s.battle.get("secrets", []):
		return "这一场已用过%s。" % art.name
	if art.has("items") and _secret_item(s, art).is_empty():
		return "行囊里没有妖丹可祭。"
	return ""

static func _secret_item(s, art: Dictionary) -> String:
	for item_id: String in art.get("items", []):
		if s.item_count(item_id) > 0:
			return item_id
	return ""

static func use_secret(s, art_id: String) -> String:
	s.combat_events.clear()
	var reason := secret_block(s, art_id)
	if not reason.is_empty():
		return reason
	var art: Dictionary = rules(s).secret_arts[art_id]
	if not s.battle.has("secrets"):
		s.battle.secrets = []
	s.battle.secrets.append(art_id)
	var look := {"style": "secret", "name": str(art.name), "vfx": "fire_burst", "tier": 4}
	match art_id:
		"burn_blood":
			s.player["burned_years"] = int(s.player.get("burned_years", 0)) + int(art.years)
		"shatter":
			s.player["injury_until"] = maxi(int(s.player.get("injury_until", 0)), int(s.world.day) + int(art.injury_days))
			s.player["wound_until"] = maxi(int(s.player.get("wound_until", 0)), int(s.world.day) + int(art.wound_days))
			var gained := _draw(s, int(art.orbs), player_weights(s))
			_gain(s, gained)
		"offer_core":
			s.remove_item(_secret_item(s, art), 1)
			var healed := mini(int(round(float(s.player.max_hp) * float(art.heal))), int(s.player.max_hp) - int(s.player.hp))
			s.player.hp = int(s.player.hp) + healed
			s.battle.shield = int(s.battle.get("shield", 0)) + int(art.shield)
			s.combat_events.append(_event({"type": "heal", "amount": healed, "hp_after": int(s.player.hp)}, look))
	if art.has("fervor"):
		_inflict(s.battle.player_status, "fervor", art.fervor)
		s.combat_events.append(_event({"type": "guard", "amount": 0, "shield": int(s.battle.get("shield", 0))}, look))
	s.changed.emit()
	return s.log_event("secret_art", {"art_name": str(art.name), "art_text": str(art.text)}, true)

## 心魔斗法 (docs/COMBAT_PLAN.md, part two, B7): the demon takes the player's own shape, arts and school,
## at a share of their health and force. Fought while a breakthrough waits (breakthrough.gd).
static func begin_demon(s) -> void:
	var demon: Dictionary = s.content.rules.breakthrough.demon
	var arts: Array = []
	var best: Dictionary = {}
	for art_id: String in s.active_skills():
		var art: Dictionary = s.held_technique(art_id)
		if art.is_empty():
			continue
		arts.append(art_id)
		if str(art.get("kind", "")) == "attack" and (best.is_empty() or int(art.damage_max) > int(best.damage_max)):
			best = art
	if best.is_empty():
		best = s.held_technique(str(arts[0])) if not arts.is_empty() else {"id": "", "name": "心魔一击", "vfx": "water", "tier": 1, "element": "water", "damage_min": 10, "damage_max": 14}
	var power := float(demon.power)
	var foe := {"name": "心魔", "hp": int(round(float(s.player.max_hp) * float(demon.hp_share))), "damage_min": maxi(1, int(round(float(best.get("damage_min", 10)) * power))), "damage_max": maxi(1, int(round(float(best.get("damage_max", 14)) * power))),
		"art": str(best.get("id", "")), "art_name": str(best.get("name", "")), "vfx": str(best.get("vfx", "water")), "tier": int(best.get("tier", 1)), "xp": 0, "npc": "", "sect": str(s.player.get("sect", "wanderer")),
		"arts": arts, "power": power, "bonus": s.attack_bonus(), "element": str(best.get("element", "water")), "realm": int(s.player.realm), "school": s.Schools.player(s)}
	var lineage := str(s.player.get("sect", "wanderer"))
	s.battle = {"enemy_id": "xin_mo", "hp": int(foe.hp), "turn": 1, "cooldowns": {}, "opponent_sect": "qingyun" if lineage == "wanderer" else lineage, "status": {}, "context": "demon", "foe": foe, "place": str(s.player.location)}
	s.combat_events.clear()
	open_hand(s)

## 天劫 (B7): rounds of lightning to weather (the foe's health counts the bolts left). The player's
## attack arts disperse a third of what they would deal from the coming bolt (`dispel`), guarding and
## shields take the rest; there is no fleeing.
const DISPEL_PERCENT := 33
static func begin_tribulation(s, trial: String) -> void:
	begin_battle(s, trial, "")
	s.battle.context = "tribulation"
	s.battle.dispel = 0

## 群敌 (docs/COMBAT_PLAN.md, part one, stage five): more foes in the fight than the one in front
## (battle.pack: [{"enemy_id", "hp"}]). The lead (battle.enemy_id and hp) acts by its intent and carries
## the lingering effects; the others join at PACK_HP of their health and each strikes once a turn at
## PACK_BLOW of its force. The player
## picks whom to strike (battle.target: 0 the lead, n the pack's nth); an art of several hits (连击)
## catches every other foe for PACK_SPLASH of the blow. When the lead falls the next steps up
## (battle.felled keeps the fallen for the spoils); the fight is won when none is left.
const PACK_BLOW := 0.4
const PACK_HP := 0.6
const PACK_SPLASH := 1.0 / 3.0

## Joins more foes to the fight under way (an event's `pack`, a wave of a series).
static func add_pack(s, enemy_ids: Array) -> void:
	if not s.battle.has("pack"):
		s.battle.pack = []
	for enemy_id: Variant in enemy_ids:
		s.battle.pack.append({"enemy_id": str(enemy_id), "hp": int(round(float(s.content.enemies[str(enemy_id)].hp) * PACK_HP))})
	s.battle.target = 0
	s.changed.emit()

## Turns the player's arts on another foe of the pack (0 the lead); it takes no turn.
static func set_target(s, index: int) -> String:
	s.combat_events.clear()
	if s.battle.is_empty() or index < 0 or index > s.battle.get("pack", []).size():
		return "没有这个对手。"
	s.battle.target = index
	s.changed.emit()
	var aimed: String = s.battle.enemy_id if index == 0 else str(s.battle.pack[index - 1].enemy_id)
	return "转而对付%s。" % s.content.enemies[aimed].name

static func _strike_member(s, index: int, damage: int) -> int:
	var member: Dictionary = s.battle.pack[index]
	var dealt := mini(damage, int(member.hp))
	member.hp = int(member.hp) - dealt
	if int(member.hp) <= 0:
		s.battle.pack.remove_at(index)
		if not s.battle.has("felled"):
			s.battle.felled = []
		s.battle.felled.append(str(member.enemy_id))
		s.battle.target = 0
		s.combat_events.append({"type": "fell", "enemy_id": str(member.enemy_id)})
		s.log_event("pack_fell", {"enemy": str(member.enemy_id)})
	return dealt

## A 连击 sweeps the rest: every foe but the one aimed at takes a share of the blow.
static func _sweep(s, damage: int) -> void:
	if damage < 1 or s.battle.get("pack", []).is_empty():
		return
	var target := int(s.battle.get("target", 0))
	if target != 0:
		s.battle.hp = maxi(0, int(s.battle.hp) - damage)
	for index: int in range(s.battle.pack.size() - 1, -1, -1):
		if index + 1 != target:
			_strike_member(s, index, damage)

## The lead has fallen with others still standing: the next steps up, fresh, and shows its intent.
static func _next_foe(s) -> String:
	var fallen := str(s.battle.enemy_id)
	if not s.battle.has("felled"):
		s.battle.felled = []
	s.battle.felled.append(fallen)
	var next: Dictionary = s.battle.pack.pop_front()
	s.battle.enemy_id = str(next.enemy_id)
	s.battle.hp = int(next.hp)
	s.battle.status = {}
	s.battle.foe_shield = 0
	s.battle.target = 0
	for key: String in ["phase", "used", "charged"]:
		s.battle.erase(key)
	s.combat_events.append({"type": "fell", "enemy_id": fallen})
	s.combat_events.append({"type": "next_foe", "enemy_id": str(next.enemy_id), "hp_after": int(s.battle.hp)})
	var text: String = s.log_event("pack_fell", {"enemy": fallen}) + " " + s.log_event("pack_next", {"enemy": str(next.enemy_id)})
	_foe_prepare(s)
	s.changed.emit()
	return text

## The others of the pack strike, each once. True when they fell the player.
static func _pack_strikes(s, guarding: bool) -> bool:
	var factor: float = (1.0 - s.defense()) * PACK_BLOW
	for member: Dictionary in s.battle.get("pack", []):
		var enemy: Dictionary = s.content.enemies[str(member.enemy_id)]
		var name: String = str(enemy.moves[0].name) if enemy.has("moves") else "围攻"
		if _hurt_player(s, s.combat_rng.randi_range(int(enemy.damage_min), int(enemy.damage_max)), factor, guarding, {"style": "enemy", "name": "%s · %s" % [enemy.name, name]}):
			return true
	return false

## 散去: the player lets one orb of `element` go, in their own turn (what is over the cap must go before
## the turn can end). It takes no turn.
static func discard_orb(s, element: String) -> String:
	s.combat_events.clear()
	if s.battle.is_empty() or not element in s.battle.get("orbs", []):
		return "手中没有这种灵气。"
	s.battle.orbs.remove_at(s.battle.orbs.find(element))
	s.combat_events.append({"type": "discard", "orbs": [element]})
	s.changed.emit()
	return "散去一颗%s灵气。" % s.content.technique_data.elements[element].name

## How many orbs must go before the turn can end.
static func over_cap(s) -> int:
	return maxi(0, s.battle.get("orbs", []).size() - hand_cap(s))

## 结束回合: with more orbs than the cap, the player first chooses which to let go (discard_orb); when
## `auto_release` (the plain policy, quick duels, tests) the most plentiful go. Then the opponent acts.
static func end_turn(s, guarding: bool = false, auto_release: bool = true) -> String:
	if not guarding:
		s.combat_events.clear()
	if s.battle.is_empty():
		return "当前没有对手。"
	if not auto_release and over_cap(s) > 0:
		return "灵气只能留 %d 颗：先点选要散去的 %d 颗灵气，再结束回合。" % [hand_cap(s), over_cap(s)]
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
	for status: String in ["weaken", "sunder", "slow", "entangle", "wound"]:
		if lingering.has(status):
			_count_down(lingering, status)
	return _enemy_turn(s, guarding)

## 守御: the turn ends at once, the next blows are halved and one more orb comes next turn. Orbs over the
## cap must be let go first, as for any end of turn.
static func defend(s, auto_release: bool = true) -> String:
	s.combat_events.clear()
	if s.battle.is_empty():
		return "当前没有对手。"
	if not auto_release and over_cap(s) > 0:
		return "灵气只能留 %d 颗：先点选要散去的 %d 颗灵气，再守御。" % [hand_cap(s), over_cap(s)]
	s.combat_events.append({"type": "guard", "amount": 0, "sect": str(s.player.get("sect", "wanderer"))})
	s.battle.guarded_turns = int(s.battle.get("guarded_turns", 0)) + 1
	s.log_event("guard_turn", {"amount": int(rules(s).guard_orbs)})
	return end_turn(s, true)

## Why a pill or a talisman cannot be used in the duel now (`duel` in data/items.json), or "". Pills and
## 符箓 are counted apart, each within its own limit a duel.
static func pill_block(s, item_id: String) -> String:
	if s.battle.is_empty():
		return "当前没有对手。"
	var item: Dictionary = s.content.item(item_id)
	if not item.has("duel"):
		return "斗法中用不得此物。"
	if s.item_count(item_id) < 1:
		return "行囊里没有%s。" % item.get("name", item_id)
	if str(item.get("category", "")) == "talisman":
		if int(s.battle.get("talismans", 0)) >= int(rules(s).get("talismans", 3)):
			return "这一场已祭了 %d 张符箓，手上的灵力催不动更多了。" % int(rules(s).get("talismans", 3))
		if bool(item.duel.get("escape", false)) and s.battle.get("context", "") in ["spar", "tournament", "summit", "arena", "tianji", "tribulation"]:
			return "比斗之中遁走，与认输无异；不必用符。"
		return ""
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
	if str(item.get("category", "")) == "talisman":
		return _use_talisman(s, item_id, item)
	s.battle.pills = int(s.battle.get("pills", 0)) + 1
	var effect: Dictionary = item.duel
	if effect.has("orbs"):
		_gain(s, _draw(s, int(effect.orbs), player_weights(s)))
	if bool(effect.get("heal", false)):
		for granted: Dictionary in s.Inventory.pill_effects(s, item):
			if granted.has("hp"):
				var recovered := mini(_healed(s.battle.get("player_status", {}), int(granted.hp)), int(s.player.max_hp) - int(s.player.hp))
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

## 符箓 (docs/COMBAT_PLAN.md, part one, stage two): used without taking a turn. 雷符 strikes, 金光符 shields,
## 定身符 binds the opponent (缠绕), 遁地符 carries the player away whatever holds them.
static func _use_talisman(s, item_id: String, item: Dictionary) -> String:
	s.battle.talismans = int(s.battle.get("talismans", 0)) + 1
	var effect: Dictionary = item.duel
	var look := {"style": "talisman", "name": str(item.name), "vfx": str(effect.get("vfx", "sword")), "tier": 2}
	var text: String = s.log_event("duel_talisman", {"item": item_id})
	if bool(effect.get("escape", false)):
		return _escape(s, text)
	if effect.has("damage"):
		var dealt := _strike_foe(s, int(effect.damage))
		s.combat_events.append(_event({"type": "attack", "actor": "player", "hits": 1, "amount": dealt, "hp_after": int(s.battle.hp)}, look))
		if int(s.battle.hp) <= 0:
			return _win(s)
	if effect.has("shield"):
		s.battle.shield = int(s.battle.get("shield", 0)) + int(effect.shield)
		s.combat_events.append(_event({"type": "guard", "amount": 0, "shield": int(s.battle.shield)}, look))
	if effect.has("bind"):
		_inflict(s.battle.status, "entangle", effect.bind)
	s.changed.emit()
	return text

## 遁速 (as in Mi Chang Sheng): the realm's (rules.duel.speed), quickened by talents that shorten the
## road (travel). It decides who moves first and how readily one gets away.
## A 心法 of hiding (《藏息录》) quickens it, except before those whose trade is finding people (`seeker`).
static func speed(s) -> int:
	var hidden := float(s.bonuses().dun_speed)
	if not s.battle.is_empty() and bool(s.content.enemies.get(str(s.battle.get("enemy_id", "")), {}).get("seeker", false)):
		hidden = 0.0
	return maxi(1, int(round(float(_by_realm(s, "speed", int(s.player.realm))) * float(100 - int(s.talent_modifier("travel"))) / 100.0 * (1.0 + hidden))))

## The opponent's 遁速: its own (`speed` in its data), else its realm's.
static func foe_speed(s) -> int:
	if s.battle.is_empty():
		return 1
	var foe: Dictionary = s.battle.get("foe", {})
	var own := 0
	if not foe.is_empty():
		own = _by_realm(s, "speed", int(foe.get("realm", 0)))
	else:
		var enemy: Dictionary = s.content.enemies[s.battle.enemy_id]
		own = int(enemy.get("speed", _by_realm(s, "speed", int(enemy.get("min_realm", 0)))))
	# Bound by a whip (缠绕), it is slower.
	if s.battle.get("status", {}).has("entangle"):
		own = maxi(1, int(round(float(own) * ENTANGLED_SPEED)))
	return own

## Whether the opponent moves first: only when it is the quicker (a tie goes to the player); 天劫 and
## 心魔 do not race.
static func foe_leads(s) -> bool:
	return not s.battle.get("context", "") in ["tribulation", "demon"] and not leads(s) and foe_speed(s) > speed(s)

## Whether the worn weapon always strikes first (a spear's 先手, data/equipment.json bases' `lead`).
static func leads(s) -> bool:
	return bool(weapon_base(s).get("lead", false))

## The base of the weapon worn and wielded (驾驭 enough to use at all), or {}.
static func weapon_base(s) -> Dictionary:
	var weapon := str(s.player.get("equipment", {}).get("weapon", ""))
	if weapon.is_empty():
		return {}
	var gear: Dictionary = s.Gear.item(s, weapon)
	if gear.is_empty() or not bool(s.Arsenal.wielded(s.content, gear, int(s.player.realm)).usable):
		return {}
	return s.content.equipment_data.bases.get(str(gear.get("id", "")).get_slice(":", 1), {})

## How likely the player gets away (遁逃): four in five at an even 遁速, more or less by how much quicker
## either side is (seven tenths of the difference of their 遁速, as a share of the foe's), surely from a lesser
## realm's foe; badly hurt (under three tenths of health) or wounded (重创), harder; never below a fifth.
static func flee_chance(s) -> float:
	var foe: Dictionary = s.battle.get("foe", {})
	var foe_realm := int(foe.get("realm", 0)) if not foe.is_empty() else int(s.content.enemies[s.battle.enemy_id].min_realm)
	var hurt := 0.15 if int(s.player.hp) * 10 < int(s.player.max_hp) * 3 else 0.0
	if s.battle.get("player_status", {}).has("wound"):
		hurt += 0.1
	var quicker := 0.7 * float(speed(s) - foe_speed(s)) / float(maxi(1, foe_speed(s)))
	return clampf(float(rules(s).get("flee", 0.8)) + quicker + (1.0 if foe_realm < int(s.player.realm) else 0.0) - hurt, 0.2, 1.0)

static func flee(s) -> String:
	s.combat_events.clear()
	if s.battle.is_empty():
		return "当前无需撤退。"
	if s.battle.get("player_status", {}).has("entangle"):
		return "被缠住了，脱身不得；先撑过这几回合、打倒对手，或祭一张遁地符。"
	# Stepping off the stage mid-bout is conceding it.
	if s.battle.get("context", "") == "arena":
		s.combat_events.append({"type": "end", "result": "flee"})
		return s.Arena.over(s, false)
	if s.battle.get("context", "") == "tribulation":
		return "天劫临身，无处可逃。"
	# Turning from 心魔 is evading it.
	if s.battle.get("context", "") == "demon":
		s.combat_events.append({"type": "end", "result": "flee"})
		return _trial_over(s, "fled")
	# A bout among fellows can always be conceded; a real fight may not let go (遁逃 by the odds).
	if not s.battle.get("context", "") in ["spar", "tournament", "summit", "tianji"] and s.combat_rng.randf() >= flee_chance(s):
		var failed: String = s.log_event("flee_failed", {"enemy": str(s.battle.enemy_id)})
		return failed + " " + end_turn(s)
	return _escape(s, "")

## Gets away from the duel: the recovery days pass.
static func _escape(s, text: String) -> String:
	if s.battle.get("context", "") == "arena":
		s.combat_events.append({"type": "end", "result": "flee"})
		return s.Arena.over(s, false)
	# Conceding a 天骄榜 duel is losing it.
	if s.battle.get("context", "") == "tianji":
		s.combat_events.append({"type": "end", "result": "flee"})
		return s.Tianji.over(s, false)
	# Getting away from someone met in a 秘境 leaves them the room.
	if s.battle.get("context", "") == "mijing":
		s.combat_events.append({"type": "end", "result": "flee"})
		return s.Mijing.over(s, false, true)
	# Running from a 鬼市 contract is failing it.
	if s.battle.get("context", "") == "guishi":
		s.combat_events.append({"type": "end", "result": "flee"})
		return s.Guishi.over(s, false)
	s.combat_events.append({"type": "end", "result": "flee"})
	var days := _recovery_days(s, "flee")
	s.battle.clear()
	# Outcomes are recorded on the day they happen; the recovery time follows.
	var message: String = s.log_event("flee", {"days": days})
	message = (s.Series.abandon(s) + " " + message).strip_edges()
	return s.conclude((text + " " + message).strip_edges(), s.advance_days(days))

## 祭出 (part one, stage two): the worn 兵刃 thrown into the duel once (twice from 法宝 up), without
## taking a turn: its own move by its base (data/equipment.json bases' `release`), as strong as its
## attack drawn on (驾驭度); not at all two realms short. {} when nothing can be released.
static func release_of(s) -> Dictionary:
	var weapon := str(s.player.get("equipment", {}).get("weapon", ""))
	if weapon.is_empty():
		return {}
	var gear: Dictionary = s.Gear.item(s, weapon)
	var base: Dictionary = s.content.equipment_data.bases.get(str(gear.get("id", "")).get_slice(":", 1), {})
	if gear.is_empty() or not base.has("release"):
		return {}
	var held: Dictionary = s.Arsenal.wielded(s.content, gear, int(s.player.realm))
	var uses := 2 if int(gear.tier) >= 4 else 1
	var damage := int(round((12.0 + 5.0 * float(held.stats.get("attack", 0))) * float(base.release.power)))
	return {"name": "%s · %s" % [gear.name, base.release.name], "move": base.release, "gear": gear, "damage": damage, "left": maxi(0, uses - int(s.battle.get("released", 0))), "usable": bool(held.usable) and float(held.share) >= 0.5}

static func release_block(s) -> String:
	if s.battle.is_empty():
		return "当前没有对手。"
	var release := release_of(s)
	if release.is_empty():
		return "没有佩着可以祭出的兵刃。"
	if not bool(release.usable):
		return "驾驭不足五成，祭不出%s。" % release.gear.name
	if int(release.left) <= 0:
		return "这一场已经祭过了。"
	return ""

static func release(s) -> String:
	s.combat_events.clear()
	var reason := release_block(s)
	if not reason.is_empty():
		return reason
	var release := release_of(s)
	var gear: Dictionary = release.gear
	s.battle.released = int(s.battle.get("released", 0)) + 1
	var element := str(gear.element)
	# 开山一锤 breaks the shield first; 穿云一枪 goes past it.
	if bool(release.move.get("shatter", false)):
		s.battle.foe_shield = 0
	var dealt := _strike_foe(s, maxi(1, int(round(float(release.damage) * ground(s, element, false)))), bool(release.move.get("through", false)))
	var look := {"style": "release", "name": str(release.name), "vfx": str(release.move.get("vfx", "sword")), "tier": int(gear.tier), "element": "metal" if element == "none" else element}
	s.combat_events.append(_event({"type": "attack", "actor": "player", "hits": int(release.move.get("hits", 1)), "amount": dealt, "hp_after": int(s.battle.hp)}, look))
	for lingering: String in LINGERING:
		if release.move.get("inflict", {}).has(lingering):
			_inflict(s.battle.status, lingering, release.move.inflict[lingering])
	var text: String = s.log_event("weapon_release", {"item": str(gear.id), "amount": dealt})
	# 铃音 breaks a blow the opponent has wound up: it lands as nothing.
	if bool(release.move.get("interrupt", false)):
		for index: int in s.battle.get("intent", []).size():
			var planned: Dictionary = s.battle.intent[index]
			if bool(planned.get("landing", false)):
				s.battle.intent[index] = {"kind": "stunned", "move": str(planned.move), "name": "%s被打散" % planned.name}
				text += " " + s.log_event("charge_broken", {"move_name": str(planned.name)})
	if int(s.battle.hp) <= 0:
		return _win(s)
	s.changed.emit()
	return text

## Duels started by events (road encounters, ruins) only cost a short rest afterwards.
static func _recovery_days(s, action: String) -> int:
	return s.content.action_days("road_recovery" if s.battle.get("context", "") == "event" else action)

## What the opponent means to do on its next turn. A generated cultivator draws its orbs now and plans
## up to three arts from them (healing when hurt, else its strongest, a shield when nothing else fits);
## others strike once.
static func _foe_prepare(s) -> void:
	var foe: Dictionary = s.battle.get("foe", {})
	if foe.get("arts", []).is_empty():
		if foe.is_empty() and s.content.enemies[s.battle.enemy_id].has("moves"):
			_plan_move(s)
			return
		var stats: Dictionary = foe if not foe.is_empty() else s.content.enemies[s.battle.enemy_id]
		var name: String = str(foe.get("art_name", "")) if not foe.is_empty() else _counter_name(s)
		# 天劫's bolts are counted: the first, the second... of all it brings.
		if bool(stats.get("tribulation", false)):
			name = "第 %d 道天雷" % (int(stats.hp) - int(s.battle.hp) + 1)
		s.battle.intent = [{"kind": "attack", "name": name, "min": int(stats.damage_min), "max": int(stats.damage_max)}]
		return
	var orbs: Array = s.battle.get("foe_orbs", [])
	var short := int(s.battle.status.slow[0]) if s.battle.get("status", {}).has("slow") else 0
	orbs.append_array(_draw(s, maxi(1, _by_realm(s, "foe_draw", int(foe.get("realm", 0))) - short), _foe_weights(s)))
	# As for the player: what it kept (at most hand_least) and what it just drew.
	while orbs.size() > int(rules(s).hand_least) + _by_realm(s, "foe_draw", int(foe.get("realm", 0))):
		orbs.remove_at(0)
	s.battle.foe_orbs = orbs
	var left := orbs.duplicate()
	var plan: Array = []
	var hurt := int(s.battle.hp) * 5 < int(foe.hp) * 2
	for step: int in 3:
		var pick: Dictionary = {}
		for art_id: Variant in foe.arts:
			var art: Dictionary = foe_art(s, foe, str(art_id))
			if art.is_empty() or art.slot != "art" or art.kind == "spirit" or not affordable(left, art.cost):
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
		var grown := realm_power(s, int(foe.get("realm", 0)))
		match str(chosen.kind):
			"heal":
				entry.amount = int(round(float(chosen.heal) * grown))
			"guard":
				entry.amount = int(round(float(chosen.shield) * grown))
			_:
				# The realm's bonus counts half per orb, as for the player.
				var share := int(round(float(foe.bonus) * _orbs_in(chosen.cost) / 2.0))
				entry.min = maxi(1, int(round(float(chosen.damage_min) * float(foe.power) * grown)) + share)
				entry.max = maxi(1, int(round(float(chosen.damage_max) * float(foe.power) * grown)) + share)
		plan.append(entry)
	if plan.is_empty():
		plan.append({"kind": "gather", "name": "凝神聚气"})
	s.battle.intent = plan

## A handwritten opponent's next move from its table (data/world.json enemies' `moves`, plus those of
## the `phases` it has entered): a blow wound up last turn lands now; a move whose `every` comes round
## is made; otherwise one is drawn by weight among those whose conditions hold.
static func _plan_move(s) -> void:
	var enemy: Dictionary = s.content.enemies[s.battle.enemy_id]
	_enter_phase(s, enemy)
	if s.battle.has("charged"):
		var wound_up := _move(enemy, str(s.battle.charged))
		s.battle.erase("charged")
		s.battle.intent = [_intent(s, enemy, wound_up, true)]
		return
	var moves := _moves(s, enemy)
	var pick: Dictionary = {}
	for move: Dictionary in moves:
		if move.has("every") and int(s.battle.turn) % int(move.every) == 0:
			pick = move
			break
	if pick.is_empty():
		var open: Array = moves.filter(func(move: Dictionary) -> bool: return _move_open(s, enemy, move))
		var total := 0
		for move: Dictionary in open:
			total += int(move.get("weight", 1))
		var roll: int = s.combat_rng.randi_range(1, maxi(1, total))
		for move: Dictionary in open:
			roll -= int(move.get("weight", 1))
			if roll <= 0:
				pick = move
				break
	if pick.is_empty():
		pick = moves[0]
	s.battle.intent = [_intent(s, enemy, pick, false)]

## The moves open to the opponent now: its own and those of the phases it has entered.
static func _moves(s, enemy: Dictionary) -> Array:
	var moves: Array = enemy.moves.duplicate()
	for index: int in mini(int(s.battle.get("phase", 0)), enemy.get("phases", []).size()):
		moves.append_array(enemy.phases[index].get("moves", []))
	return moves

static func _move(enemy: Dictionary, move_id: String) -> Dictionary:
	for phase: Dictionary in [{"moves": enemy.moves}] + enemy.get("phases", []):
		for move: Dictionary in phase.get("moves", []):
			if move.id == move_id:
				return move
	return enemy.moves[0]

## Whether a move may be drawn now: not one that only comes round every few turns; one kept for when
## hurt (`below`, a share of health; heals default to half) only then; a `once` move only once; no new
## helpers while the last ones still fight.
static func _move_open(s, enemy: Dictionary, move: Dictionary) -> bool:
	if move.has("every"):
		return false
	var share := float(s.battle.hp) / float(enemy.hp)
	if share >= float(move.get("below", 0.5 if move.get("kind", "") == "heal" else 2.0)):
		return false
	if bool(move.get("once", false)) and str(move.id) in s.battle.get("used", []):
		return false
	return not (move.get("kind", "") == "summon" and s.battle.status.has("minions"))

## The power the opponent's phases add, multiplied.
static func _phase_power(s, enemy: Dictionary) -> float:
	var power := 1.0
	for index: int in mini(int(s.battle.get("phase", 0)), enemy.get("phases", []).size()):
		power *= float(enemy.phases[index].get("power", 1.0))
	return power

## What the intent shows for a move: a blow's range (the wound-up one when `landing`), or a heal's,
## a shield's or the helpers' amount.
static func _intent(s, enemy: Dictionary, move: Dictionary, landing: bool) -> Dictionary:
	var kind := "attack" if landing else str(move.get("kind", "attack"))
	var entry := {"kind": kind, "move": str(move.id), "name": str(move.name)}
	if landing:
		entry.landing = true
	var power := float(move.get("power", 1.0)) * _phase_power(s, enemy)
	match kind:
		"attack", "charge":
			entry.min = maxi(1, int(round(float(enemy.damage_min) * power)))
			entry.max = maxi(1, int(round(float(enemy.damage_max) * power)))
			if int(move.get("hits", 1)) > 1:
				entry.hits = int(move.hits)
		"heal":
			entry.amount = int(round(float(enemy.hp) * float(move.heal)))
		"guard":
			entry.amount = int(round(float(enemy.hp) * float(move.shield)))
		"summon":
			entry.amount = int(move.summon[0])
		"focus":
			entry.amount = int(round(float(move.focus[0]) * 100.0))
	return entry

## Phases (头目分阶段): once health falls below a phase's share, it is entered for good and told.
static func _enter_phase(s, enemy: Dictionary) -> void:
	var phases: Array = enemy.get("phases", [])
	while int(s.battle.get("phase", 0)) < phases.size() and float(s.battle.hp) < float(enemy.hp) * float(phases[int(s.battle.get("phase", 0))].below):
		var phase: Dictionary = phases[int(s.battle.get("phase", 0))]
		s.battle.phase = int(s.battle.get("phase", 0)) + 1
		s.combat_events.append({"type": "phase", "actor": "enemy", "name": str(phase.get("name", ""))})
		s.log_event("enemy_phase", {"phase_text": str(phase.text)})

## Carries out a planned move of a handwritten opponent. True when it fells the player.
static func _do_move(s, planned: Dictionary, factor: float, guarding: bool) -> bool:
	var enemy: Dictionary = s.content.enemies[s.battle.enemy_id]
	var move := _move(enemy, str(planned.move))
	var status: Dictionary = s.battle.status
	var args := {"enemy": str(s.battle.enemy_id), "move_name": str(move.name)}
	if bool(move.get("once", false)):
		if not s.battle.has("used"):
			s.battle.used = []
		s.battle.used.append(str(move.id))
	match str(planned.kind):
		"charge":
			s.battle.charged = str(move.id)
			s.log_event("enemy_charge", args)
		"heal":
			var recovered := mini(_healed(status, int(planned.amount)), int(enemy.hp) - int(s.battle.hp))
			s.battle.hp = int(s.battle.hp) + recovered
			s.combat_events.append({"type": "heal", "actor": "enemy", "style": "enemy", "name": str(move.name), "vfx": "heal", "amount": recovered, "hp_after": int(s.battle.hp)})
			args.amount = recovered
			s.log_event("enemy_heal", args)
		"guard":
			s.battle.foe_shield = int(s.battle.get("foe_shield", 0)) + int(planned.amount)
			s.combat_events.append({"type": "guard", "actor": "enemy", "style": "enemy", "name": str(move.name), "amount": 0, "shield": int(s.battle.foe_shield)})
			args.amount = int(planned.amount)
			s.log_event("enemy_guard", args)
		"focus":
			_inflict(status, "focus", move.focus)
			s.log_event("enemy_focus", args)
		"summon":
			_inflict(status, "minions", move.summon)
			s.log_event("enemy_summon", args)
		"stunned":
			s.log_event("enemy_stunned", args)
		_:
			# Slowed or entangled, a beast strikes weaker; 蓄势 makes the next blow harder, once.
			var strength := factor * (SLOW_BLOW if status.has("slow") or status.has("entangle") else 1.0) * ground(s, str(enemy.element), true)
			if status.has("focus"):
				strength *= 1.0 + float(status.focus[0])
				status.erase("focus")
			var blow := {"style": "enemy" if not bool(enemy.get("human", false)) else _counter_style(s), "name": str(move.name), "wound_up": bool(planned.get("landing", false))}
			for hit: int in int(planned.get("hits", 1)):
				var before := int(s.player.hp)
				if _hurt_player(s, s.combat_rng.randi_range(int(planned.min), int(planned.max)), strength, guarding, blow):
					return true
				if move.has("drain"):
					var drained := mini(_healed(status, int(round(float(before - int(s.player.hp)) * float(move.drain)))), int(enemy.hp) - int(s.battle.hp))
					s.battle.hp = int(s.battle.hp) + drained
			for lingering: String in LINGERING:
				if move.get("inflict", {}).has(lingering):
					_inflict(s.battle.player_status, lingering, move.inflict[lingering])
	return false

static func _enemy_turn(s, guarding: bool) -> String:
	var arrived := false
	var soul_done := false
	var foe_swords := 0
	var enemy_id: String = s.battle.enemy_id
	# Lingering effects on the opponent act first: burning and bleeding can finish a fight.
	var status: Dictionary = s.battle.get("status", {})
	for wound: Array in [["burn", "灼烧", "flame_bolt"], ["bleed", "流血", "sword"]]:
		if not status.has(wound[0]):
			continue
		var bite := int(status[wound[0]][0])
		s.battle.hp = maxi(0, int(s.battle.hp) - bite)
		s.combat_events.append({"type": "attack", "actor": "player", "style": wound[0], "name": wound[1], "vfx": wound[2], "tier": 1, "hits": 1, "amount": bite, "hp_after": int(s.battle.hp)})
		_count_down(status, wound[0])
		if int(s.battle.hp) <= 0:
			if s.battle.get("pack", []).is_empty():
				return _win(s)
			# The next of the pack steps up; it has not yet had its turn.
			_next_foe(s)
			arrived = true
			status = s.battle.status
			break
	s.battle.foe_shield = 0
	var factor: float = 1.0 - s.defense()
	if status.has("weaken"):
		factor *= 1.0 - float(status.weaken[0])
		_count_down(status, "weaken")
	var foe: Dictionary = s.battle.get("foe", {})
	# Helpers it called (召唤) strike before it does.
	if status.has("minions"):
		if _hurt_player(s, int(status.minions[0]), factor, guarding, {"style": "enemy", "name": "%s的帮手" % s.content.enemies[enemy_id].name}):
			return _lose(s)
		_count_down(status, "minions")
	for planned: Dictionary in (s.battle.get("intent", []) if not arrived else []):
		if planned.has("move"):
			if _do_move(s, planned, factor, guarding):
				return _lose(s)
			continue
		if not planned.has("art"):
			if str(planned.kind) == "attack":
				var stats: Dictionary = foe if not foe.is_empty() else s.content.enemies[enemy_id]
				var blow := {"style": _counter_style(s)}
				if not foe.is_empty():
					blow = {"style": foe.art, "name": foe.art_name, "vfx": foe.vfx, "tier": int(foe.tier)}
				# Without orbs to be short of, a slowed opponent strikes weaker.
				var strength: float = factor * (SLOW_BLOW if status.has("slow") else 1.0) * ground(s, foe_element(s), true)
				var roll: int = s.combat_rng.randi_range(int(stats.damage_min), int(stats.damage_max))
				if s.battle.get("context", "") == "tribulation":
					roll = maxi(1, roll - int(s.battle.get("dispel", 0)) * DISPEL_PERCENT / 100)
					s.battle.dispel = 0
					blow = {"style": "enemy", "name": str(stats.name), "vfx": "sword_rain", "tier": 3}
				if _hurt_player(s, roll, strength, guarding, blow):
					return _lose(s)
				if s.battle.get("context", "") == "tribulation":
					s.battle.hp = int(s.battle.hp) - 1
					if int(s.battle.hp) <= 0:
						return _win(s)
			continue
		var art: Dictionary = foe_art(s, foe, str(planned.art))
		if art.is_empty() or not affordable(s.battle.foe_orbs, art.cost):
			continue
		var spent := _pay(s.battle.foe_orbs, art.cost)
		var look := {"style": str(art.id), "name": str(art.name), "vfx": str(art.vfx), "tier": int(art.tier), "element": str(art.element), "spent": spent}
		# Their 流派 too: 剑意 across their metal arts, 魂修 shaking the player's next draw.
		var foe_school: String = s.Schools.foe(s)
		if foe_school == "soul" and not soul_done:
			soul_done = true
			_inflict(s.battle.player_status, "slow", [1, 1])
		var school_force := 1.0
		if foe_school == "sword" and str(art.element) == "metal":
			school_force += s.Schools.value(s, "sword", "stack") * float(mini(foe_swords, int(s.Schools.value(s, "sword", "most"))))
			foe_swords += 1
		match str(art.kind):
			"heal":
				var recovered := mini(_healed(status, int(planned.get("amount", art.heal))), int(foe.hp) - int(s.battle.hp))
				s.battle.hp = int(s.battle.hp) + recovered
				s.combat_events.append(_event({"type": "heal", "actor": "enemy", "amount": recovered, "hp_after": int(s.battle.hp)}, look))
			"guard":
				s.battle.foe_shield = int(s.battle.get("foe_shield", 0)) + int(planned.get("amount", art.shield))
				s.combat_events.append(_event({"type": "guard", "actor": "enemy", "amount": 0, "shield": int(s.battle.foe_shield)}, look))
			_:
				for lingering: String in LINGERING:
					if art.has(lingering):
						_inflict(s.battle.player_status, lingering, art[lingering])
				if _hurt_player(s, s.combat_rng.randi_range(int(planned.min), int(planned.max)), factor * ground(s, str(art.element), true) * school_force, guarding, look):
					return _lose(s)
	if _pack_strikes(s, guarding):
		return _lose(s)
	# The player's turn: the shield has done its work, burning bites, new orbs come and the opponent
	# shows its next intent.
	s.battle.shield = 0
	s.battle.turn += 1
	s.battle.erase("sword_streak")
	var formation := 0
	if bool(s.battle.get("array", false)):
		formation = int(s.Schools.value(s, "array", "orbs"))
		s.battle.shield = int(s.Schools.value(s, "array", "shield"))
	var burning: Dictionary = s.battle.get("player_status", {})
	for wound: Array in [["burn", "灼烧", "flame_bolt"], ["bleed", "流血", "sword"]]:
		if not burning.has(wound[0]):
			continue
		# Lingering harm leaves the player a sliver; it is the blows that fell them.
		var bite := mini(int(burning[wound[0]][0]), int(s.player.hp) - 1)
		s.player.hp = int(s.player.hp) - bite
		s.combat_events.append({"type": "attack", "actor": "enemy", "style": wound[0], "name": wound[1], "vfx": wound[2], "tier": 1, "hits": 1, "amount": bite, "hp_after": int(s.player.hp)})
		_count_down(burning, wound[0])
	if burning.has("fervor"):
		_count_down(burning, "fervor")
	var short := (int(burning.slow[0]) if burning.has("slow") else 0) + (int(burning.entangle[0]) if burning.has("entangle") else 0)
	var gathered := int(s.battle.get("next_draw", 0))
	s.battle.erase("next_draw")
	var hand := _draw(s, maxi(1, draw_count(s) - short + formation + gathered + (int(rules(s).guard_orbs) if guarding else 0)), player_weights(s))
	# The tide's orbs held back when the opponent moved first (open_hand).
	for count: int in int(s.battle.get("tide", 0)):
		hand.append("water")
	s.battle.erase("tide")
	_gain(s, hand)
	_foe_prepare(s)
	# The opponent's sunder, slow, entangle, wound and focus last through its turns.
	for lingering: String in ["sunder", "slow", "entangle", "wound", "focus"]:
		if status.has(lingering):
			_count_down(status, lingering)
	s.changed.emit()
	return "轮到你出招。"

## One blow at the player through defense, a weakening, a guard and the shield. True when it fells them.
static func _hurt_player(s, roll: int, factor: float, guarding: bool, look: Dictionary) -> bool:
	var sundered: Dictionary = s.battle.get("player_status", {})
	if sundered.has("sunder"):
		factor *= 1.0 + float(sundered.sunder[0])
	# A 体修's body takes every blow a little lighter.
	if s.Schools.player(s) == "body":
		factor *= s.Schools.value(s, "body", "countered")
	var damage := maxi(1, int(round(float(roll) * factor)))
	if guarding:
		damage = maxi(1, damage / 2)
	damage = _gear_traits(s, damage, look)
	var absorbed := mini(int(s.battle.get("shield", 0)), damage)
	s.battle.shield = int(s.battle.get("shield", 0)) - absorbed
	damage -= absorbed
	if bool(s.battle.get("leading", false)):
		damage = mini(damage, int(s.player.hp) - 1)
	s.player.hp = maxi(0, int(s.player.hp) - damage)
	if s.Schools.player(s) == "body" and float(damage) >= float(s.player.max_hp) * s.Schools.value(s, "body", "heavy"):
		s.battle.body_ready = true
	s.combat_events.append(_event({"type": "attack", "actor": "enemy", "amount": damage, "absorbed": absorbed, "hp_after": int(s.player.hp)}, look))
	s.log_event("enemy_attack", {"enemy": s.battle.enemy_id, "amount": damage})
	return int(s.player.hp) <= 0

## The worn pieces' own effects (data/equipment.json bases' `trait`), each once a duel, on a blow about
## to land: 护心 halves a heavy one; 反照 turns half of an art's or a wound-up blow back on the foe
## (never felling it). Pieces two realms short do nothing. Returns what is left of the blow.
static func _gear_traits(s, damage: int, look: Dictionary) -> int:
	for perk: Dictionary in worn_traits(s):
		if str(perk.kind) in s.battle.get("traits_used", []):
			continue
		var kept := damage
		match str(perk.kind):
			"heart_guard":
				if float(damage) >= float(s.player.max_hp) * float(perk.heavy):
					kept = int(round(float(damage) * (1.0 - float(perk.cut))))
			"mirror":
				if look.has("spent") or bool(look.get("wound_up", false)):
					var turned := int(round(float(damage) * float(perk.reflect)))
					kept = damage - turned
					var back := mini(turned, int(s.battle.hp) - 1)
					s.battle.hp = int(s.battle.hp) - back
					s.combat_events.append({"type": "attack", "actor": "player", "style": "mirror", "name": str(perk.name), "vfx": "water", "tier": 2, "hits": 1, "amount": back, "hp_after": int(s.battle.hp)})
		if kept == damage:
			continue
		if not s.battle.has("traits_used"):
			s.battle.traits_used = []
		s.battle.traits_used.append(str(perk.kind))
		s.log_event("gear_trait", {"trait_name": str(perk.name), "amount": damage - kept})
		damage = kept
	return damage

## The effects of the pieces the player wears that they can draw on (not two realms short).
static func worn_traits(s) -> Array[Dictionary]:
	var traits: Array[Dictionary] = []
	for slot: String in s.player.get("equipment", {}):
		var item_id := str(s.player.equipment[slot])
		if item_id.is_empty():
			continue
		var gear: Dictionary = s.Gear.item(s, item_id)
		var base: Dictionary = s.content.equipment_data.bases.get(str(gear.get("id", "")).get_slice(":", 1), {})
		if base.has("trait") and not gear.is_empty() and bool(s.Arsenal.wielded(s.content, gear, int(s.player.realm)).usable):
			traits.append(base["trait"])
	return traits

## The end of a 心魔 or 天劫 duel: the breakthrough it stood in goes on (breakthrough.gd).
static func _trial_over(s, outcome: String) -> String:
	var context := str(s.battle.context)
	# The 飞升天劫 (ascension.gd) ends a life or wounds it, apart from any breakthrough.
	var ascension := str(s.battle.get("ascension", ""))
	s.battle.clear()
	if not ascension.is_empty():
		s.player.hp = maxi(int(s.player.hp), 1)
		return s.Ascension.over(s, ascension, outcome == "won")
	s.player.hp = maxi(int(s.player.hp), 1)
	if context == "demon":
		return s.Breakthrough.demon_over(s, outcome)
	return s.Breakthrough.tribulation_over(s, outcome == "won")

static func _lose(s) -> String:
	s.combat_events.append({"type": "end", "result": "lose"})
	if s.battle.get("context", "") in ["demon", "tribulation"]:
		return _trial_over(s, "lost")
	if s.battle.get("context", "") == "arena":
		return s.Arena.over(s, false)
	if s.battle.get("context", "") == "spar":
		return _spar_over(s, false)
	if s.battle.get("context", "") == "tournament":
		return _tournament_over(s, false)
	if s.battle.get("context", "") == "summit":
		return s.Summit.over(s, false)
	if s.battle.get("context", "") == "tianji":
		return s.Tianji.over(s, false)
	if s.battle.get("context", "") == "mijing":
		return s.Mijing.over(s, false)
	if s.battle.get("context", "") == "guishi":
		return s.Guishi.over(s, false)
	var grudge_id := str(s.battle.get("grudge", ""))
	var robbery := str(s.battle.get("robbery", ""))
	var deadly := bool(s.battle.get("deadly", false))
	var killer := str(s.battle.get("title", s.content.enemies[str(s.battle.enemy_id)].name))
	var review := {"enemy":str(s.battle.enemy_id), "turns":int(s.battle.turn), "guards":int(s.battle.get("guarded_turns", 0)), "opening_percent":int(s.battle.get("opening_percent", 100)), "old_wound":bool(s.battle.get("old_wound", false))}
	s.battle.clear()
	s.record_deed("duel")
	# 死斗 (part one, stage five): marked before it began, lost, it ends the life.
	if deadly:
		# The ending marks the fall; health stays a sliver, as saves keep it.
		s.player.hp = 1
		s.ended = {"kind": "fallen", "day": int(s.world.day)}
		var fall: String = s.log_event("fallen", {"foe": killer, "age": s.age()}, true)
		s.changed.emit()
		return fall
	if not grudge_id.is_empty():
		s.Feuds.fight_over(s, grudge_id, false)
	# Beaten in a 秘境, or by those waiting at its door (mijing.gd): out, and half of what was gathered gone.
	var behind := ""
	if not robbery.is_empty():
		behind = s.Mijing.robbed_in_battle(s)
	elif not s.Mijing.inside(s).is_empty():
		behind = s.Mijing.carried_out(s)
	# A disciple is carried back to their sect's gate; a wanderer to the nearest inn
	# (rules.opening.location when the place has none) — or, one of 天南散修盟 far from any inn, by its
	# people to the branch they joined at, who take nothing from the purse.
	var member: bool = s.Sect.member(s)
	var sheltered: bool = not member and not s.available_here("inn_rest") and s.League.member(s)
	var lost := 0 if sheltered else mini(int(s.player.stones), 10)
	s.player.stones -= lost
	if member:
		s.player.location = str(s.Sect.own(s).place)
	elif sheltered:
		s.player.location = s.League.home(s)
	elif not s.available_here("inn_rest"):
		s.player.location = str(s.content.rules.opening.location)
	s.player.journey = {}
	var defeat := "battle_defeat" if member else ("battle_defeat_league" if sheltered else "battle_defeat_wanderer")
	var message: String = (s.Series.abandon(s) + " " + behind + " " + s.log_event(defeat, {"lost": lost, "location": s.player.location})).strip_edges()
	var passed: Dictionary = s.advance_days(s.content.action_days("battle_defeat"))
	# The wounds outlast the days spent being carried home.
	_wound(s, int(rules(s).get("defeat_wound_days", 12)), int(rules(s).get("defeat_injury_days", 10)))
	s.player.hp = maxi(1, int(s.player.max_hp) / 2)
	s.player.qi = s.player.max_qi
	message += " " + s.log_event("battle_review", review)
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
			var t: Dictionary = s.held_technique(art_id)
			if t.is_empty() or not affordable(s.battle.orbs, t.cost):
				continue
			var worth := int(t.get("damage_max", 0)) * (2 if combo_holds(s, t) else 1)
			if t.kind == "heal":
				worth = 500 if int(s.player.hp) * 5 < int(s.player.max_hp) * 2 else -1
			elif t.kind in ["guard", "spirit"]:
				worth = 0
			if worth > best_worth:
				best_worth = worth
				best = art_id
		if best.is_empty():
			break
		text = use_skill(s, best)
	if s.battle.is_empty():
		return text
	return end_turn(s)

## 速战: the plain turn again and again until the duel ends (at most `most` turns); returns the last
## turn's text. The turn's events are those of the last turn, ending with the outcome.
static func quick(s, most: int = 60) -> String:
	var text := ""
	for turn: int in most:
		if s.battle.is_empty():
			break
		text = plain_turn(s)
	return text

## The simplest full turn: casts the art if the orbs allow, then ends the turn (simulations, tests).
static func duel_turn(s, skill_id: String) -> String:
	var t: Dictionary = s.held_technique(skill_id)
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
	var against_rival := bool(s.battle.get("rival", false))
	s.battle.clear()
	s.record_deed("duel")
	# 萧凌云's bout (rival.gd) is decided with the round that ends it.
	var rival: String = s.Rival.tournament_over(s, won, against_rival)
	if not won:
		s.player.hp = maxi(int(s.player.hp), 1)
		var out: String = s.log_event("tournament_out", {"round": round, "npc": npc})
		if not rival.is_empty():
			out += " " + rival
		return s.conclude(_with_milestones(out, s.gain_insight("spar")), s.advance_days(s.content.action_days("road_recovery")))
	var message: String = _with_milestones(s.log_event("tournament_round", {"round": round, "npc": npc}), s.gain_insight("spar"))
	message += " " + s.Sect.gain(s, int(s.content.sect_data.awards.get("tournament_round", 0)), "潜龙会胜了一轮")
	if round < 3:
		s.player.hp = mini(int(s.player.max_hp), int(s.player.hp) + int(s.player.max_hp) * 3 / 10)
		s.player.qi = mini(int(s.player.max_qi), int(s.player.qi) + int(s.player.max_qi) * 3 / 10)
		s.begin_tournament(round + 1)
		s.changed.emit()
		return message + " 下一轮开始。"
	# 潜龙会's prize prepares a foundation: a slip, stones and a 筑基丹 (docs/GAME_OUTLINE.md 4.5).
	var prize: String = "j:" + s.Arsenal.generate_technique(s.content, s.world_rng, 2, {"slot": "art"})
	s.add_item(prize, 1)
	s.add_item("foundation_pill", 1)
	s.player.stones += 100
	message += " " + s.log_event("tournament_champion", {"stones": 100, "xp": 150, "item": prize}, true)
	s.record_deed("tournament_champion")
	message += " " + s.Sect.gain(s, int(s.content.sect_data.awards.get("tournament_champion", 0)), "潜龙会夺魁")
	message = _with_milestones(message, s.gain_xp(150))
	message = _with_milestones(message, s.congratulate("champion"))
	if not rival.is_empty():
		message += " " + rival
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
	if not s.battle.get("pack", []).is_empty():
		return _next_foe(s)
	s.combat_events.append({"type": "end", "result": "win"})
	if s.battle.get("context", "") in ["demon", "tribulation"]:
		return _trial_over(s, "won")
	if s.battle.get("context", "") == "arena":
		return s.Arena.over(s, true)
	if s.battle.get("context", "") == "spar":
		return _spar_over(s, true)
	if s.battle.get("context", "") == "tournament":
		return _tournament_over(s, true)
	if s.battle.get("context", "") == "summit":
		return s.Summit.over(s, true)
	if s.battle.get("context", "") == "tianji":
		return s.Tianji.over(s, true)
	if s.battle.get("context", "") == "mijing":
		return s.Mijing.over(s, true)
	if s.battle.get("context", "") == "guishi":
		return s.Guishi.over(s, true)
	var enemy_id: String = s.battle.enemy_id
	var enemy: Dictionary = s.content.enemies[enemy_id]
	var days := _recovery_days(s, "battle_victory")
	var npc: String = s.battle.get("npc", "")
	var series_id := str(s.battle.get("series", ""))
	var felled: Array = s.battle.get("felled", []).duplicate()
	# 惨胜: won with under a tenth of health left, the body pays for it.
	if int(s.player.hp) * 10 < int(s.player.max_hp):
		_wound(s, int(rules(s).get("narrow_wound_days", 6)))
	var grudge_id := str(s.battle.get("grudge", ""))
	var wanted_key := str(s.battle.get("wanted", ""))
	s.record_kill(enemy_id)
	s.record_deed("duel")
	s.record_deed("win:" + enemy_id)
	s.player.stones += int(enemy.reward_stones)
	s.add_item("huichun_grass", int(enemy.reward_herbs))
	s.battle.clear()
	var message: String = s.log_event("battle_victory", {"enemy": enemy_id, "stones": int(enemy.reward_stones), "xp": int(enemy.reward_xp), "herbs": int(enemy.reward_herbs)})
	# 恩怨与悬赏 (feuds.gd): a grudge settled, an outlaw taken, or a comrade left to remember.
	if not grudge_id.is_empty():
		message += " " + s.Feuds.fight_over(s, grudge_id, true)
	elif not wanted_key.is_empty():
		message += " " + s.Feuds.caught(s, wanted_key)
	elif series_id.is_empty() and npc.is_empty():
		# A named person's fate belongs to their story; a nameless road outlaw's to the player.
		message = _with_milestones(message, [s.Feuds.offer_terms(s, enemy_id)])
	# A defeated regional threat changes the world; the journey itself continues.
	var flag: String = enemy.get("world_flag", "")
	if not flag.is_empty() and not s.has_flag(flag):
		s.world.flags[flag] = true
		message += " " + s.log_event(enemy.flag_event, {}, true)
		if enemy.has("congrats"):
			message = _with_milestones(message, s.congratulate(str(enemy.congrats)))
		if enemy.has("contribution"):
			message += " " + s.Sect.gain(s, int(enemy.contribution), "为宗门除去%s" % enemy.name)
	# Beast parts (妖兽材料): each by its own chance, from the world stream.
	var parts := {}
	for part: Dictionary in enemy.get("parts", []):
		if s.world_rng.randf() < float(part.chance):
			var count: int = s.world_rng.randi_range(int(part.count[0]), int(part.count[1]))
			s.add_item(str(part.item), count)
			parts[str(part.item)] = int(parts.get(str(part.item), 0)) + count
	# The rest of a pack (群敌) yields its stones, cultivation and parts too.
	var pack_xp := 0
	for fallen: String in felled:
		var other: Dictionary = s.content.enemies[fallen]
		s.record_kill(fallen)
		s.player.stones += int(other.reward_stones)
		pack_xp += int(other.reward_xp)
		for part: Dictionary in other.get("parts", []):
			if s.world_rng.randf() < float(part.chance):
				var count: int = s.world_rng.randi_range(int(part.count[0]), int(part.count[1]))
				s.add_item(str(part.item), count)
				parts[str(part.item)] = int(parts.get(str(part.item), 0)) + count
	if not felled.is_empty():
		message += " " + s.log_event("pack_spoils", {"count": felled.size()})
	if not parts.is_empty():
		message += " " + s.log_event("loot", {"loot": s.loot_code(parts)})
	if enemy.has("drops") and s.world_rng.randf() < float(enemy.drops.chance):
		var tier: int = s.world_rng.randi_range(int(enemy.drops.tiers[0]), int(enemy.drops.tiers[1]))
		var loot: String = "j:" + s.Arsenal.generate_technique(s.content, s.world_rng, tier) if s.world_rng.randf() < 0.5 else s.Arsenal.generate_equipment(s.content, s.world_rng, tier)
		s.add_item(loot, 1)
		message += " " + s.log_event("loot", {"loot": loot + ":1"})
	message = _with_milestones(message, s.gain_insight("battle_win"))
	message = _with_milestones(message, s.gain_xp(int(enemy.reward_xp) + pack_xp))
	# Won with almost nothing left against a foe of one's own realm or above: perhaps 生死之间.
	message = _with_milestones(message, s.Fortune.after_win(s, int(enemy.min_realm)))
	s.npc_depart(npc)
	if not series_id.is_empty() and s.player.has("series"):
		return s.Series.wave_won(s, message)
	return s.conclude(message, s.advance_days(days))
