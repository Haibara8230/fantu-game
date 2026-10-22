extends RefCounted
## 鬼市夜灯 (docs/SIDEQUESTS_DRAFT5_20261020.md 五·3): the masked night market at 云溪's old pier, open
## the fifteenth night of each month to anyone of foundation and up (data/guishi.json). Operates on a
## Session.
## - 赌宝: a few sealed lots each night, priced by the realm; what is inside is fixed by the world seed
##   and the night. The 神识 sees part of it ("看出几成"): the hint shown tells the truth with that
##   share, else a wrong one.
## - 销赃: things others will know as theirs (items marked `stolen`) no shop will take; here they go at
##   a low price.
## - 接单: one contract a night, cutting down someone who showed their wealth; done, the 凶人榜 marks it.
## - 雇凶: a grudge settled by hired hands, for stones.
## - 黑拍: a black auction (data/auctions.json `black`) on the nights of its months.
## - 财不露白: spend too freely in one night and someone follows the player out of the city.
## - Once 灯婆's war is done (the `guishi_war` story): gone (`gone_flag`), or the player its 二灯
##   (`second_flag`), who sees more, sells higher and is followed by nobody.
## world.guishi: {"night" (the month index of the last night visited), "bought" [lot indices], "spent",
## "contract" (the night it was taken), "black" (the night it was held), "tail" (true when followed)}.
const Calendar = preload("res://scripts/core/calendar.gd")
const Population = preload("res://scripts/core/population.gd")

static func data(s) -> Dictionary:
	return s.content.guishi_data

static func state(s) -> Dictionary:
	if not s.world.get("guishi") is Dictionary:
		s.world["guishi"] = {}
	var held: Dictionary = s.world.guishi
	var night := int(s.world.day) / Calendar.DAYS_PER_MONTH
	# A new night: nothing bought yet, nothing spent.
	if int(held.get("night", -1)) != night and is_night(s):
		held.night = night
		held.bought = []
		held.spent = 0
	return held

static func is_night(s) -> bool:
	return Calendar.day_of_month(int(s.world.day)) == int(data(s).day)

static func second(s) -> bool:
	return s.has_flag(str(data(s).second_flag))

## The base price of a lot for the player's realm.
static func price(s) -> int:
	var table: Array = data(s).price
	return int(table[clampi(int(s.player.realm), 0, table.size() - 1)])

## Why the market cannot be entered now, or "".
static func block(s) -> String:
	var reason: String = s.blocked()
	if not reason.is_empty():
		return reason
	if s.has_flag(str(data(s).gone_flag)):
		return "废码头空了，鬼市散了，再没点过灯。"
	if int(s.player.realm) < int(data(s).realm):
		return "废码头上的人看你一眼，便当你不存在——鬼市不做炼气小辈的买卖。"
	if not is_night(s):
		return "废码头空荡荡的。鬼市每月十五子时开灯，天亮就散。"
	return ""

# --- 赌宝 ------------------------------------------------------------------------------------------

## Tenths of a lot the 神识 sees: by the 神识 against the realm's measure, two more for the 二灯.
static func insight(s) -> int:
	var table: Array = data(s).insight
	var ref := float(table[clampi(int(s.player.realm), 0, table.size() - 1)])
	return clampi(int(round(float(s.sense()) / ref * 10.0)) + (2 if second(s) else 0), 1, 9)

static func _rng(s, key: String) -> RandomNumberGenerator:
	var rng := RandomNumberGenerator.new()
	rng.seed = hash([int(s.world.seed), "guishi", int(s.world.day) / Calendar.DAYS_PER_MONTH, key])
	return rng

## Tonight's lots: [{"kind", "name", "text", "price", "tier", "hint" (the tier the 神识 believes)}].
static func lots(s) -> Array:
	var found: Array = []
	var tiers: Array = data(s).tiers
	var total := 0
	for tier: Dictionary in tiers:
		total += int(tier.weight)
	for index: int in int(data(s).lots):
		var rng := _rng(s, "lot%d" % index)
		var kinds: Array = data(s).kinds
		var kind: Dictionary = kinds[rng.randi_range(0, kinds.size() - 1)]
		var roll := rng.randi_range(1, total)
		var tier := 0
		for at: int in tiers.size():
			roll -= int(tiers[at].weight)
			if roll <= 0:
				tier = at
				break
		var hint := tier
		if rng.randf() * 10.0 >= float(insight(s)):
			hint = (tier + 1 + rng.randi_range(0, tiers.size() - 2)) % tiers.size()
		var cost := int(round(float(price(s)) * (0.8 + rng.randf() * 0.4)))
		found.append({"kind": str(kind.id), "name": str(kind.name), "text": str(kind.text), "price": cost, "tier": tier, "hint": hint})
	return found

## What a lot holds: {item: count} and stones, as the tier gives them.
static func contents(s, index: int) -> Dictionary:
	var lot: Dictionary = lots(s)[index]
	var tier: Dictionary = data(s).tiers[int(lot.tier)]
	var rng := _rng(s, "inside%d" % index)
	var items := {}
	if tier.has("manual"):
		items["j:" + s.Arsenal.generate_technique(s.content, rng, clampi(int(s.player.realm) + int(tier.manual), 1, 5))] = 1
	if tier.has("equipment"):
		items[s.Arsenal.generate_equipment(s.content, rng, clampi(int(s.player.realm) + int(tier.equipment), 1, 5))] = 1
	return {"stones": int(round(float(price(s)) * float(tier.stones))), "items": items}

static func gamble_block(s, index: int) -> String:
	var reason := block(s)
	if not reason.is_empty():
		return reason
	if index < 0 or index >= int(data(s).lots):
		return "没有这件货。"
	if index in state(s).bought:
		return "这件已经开过了。"
	if int(s.player.stones) < int(lots(s)[index].price):
		return "灵石不够。"
	return ""

## Buys a sealed lot and opens it.
static func gamble(s, index: int) -> String:
	var reason := gamble_block(s, index)
	if not reason.is_empty():
		return reason
	var lot: Dictionary = lots(s)[index]
	var inside := contents(s, index)
	s.player.stones = int(s.player.stones) - int(lot.price) + int(inside.stones)
	for item_id: String in inside.items:
		s.add_item(item_id, int(inside.items[item_id]))
	state(s).bought.append(index)
	var tier: Dictionary = data(s).tiers[int(lot.tier)]
	var args := {"lot": str(lot.name), "price": int(lot.price), "stones": int(inside.stones), "words": str(tier.opened)}
	var text: String = s.log_event("guishi_gamble_loot" if not inside.items.is_empty() else "guishi_gamble", args.merged({"loot": s.loot_code(inside.items)}))
	return s.finish(_spend(s, int(lot.price), text))

# --- 销赃 ------------------------------------------------------------------------------------------

## What the market pays for one of a stolen thing.
static func fence_price(s, item_id: String) -> int:
	return maxi(1, int(round(float(s.content.item(item_id).get("price", 0)) * float(data(s).fence_second if second(s) else data(s).fence))))

## Stolen things in the 行囊.
static func fenceable(s) -> Array[String]:
	var found: Array[String] = []
	for item_id: String in s.player.get("items", {}):
		if bool(s.content.item(item_id).get("stolen", false)) and s.item_count(item_id) > 0:
			found.append(item_id)
	found.sort()
	return found

static func fence(s, item_id: String) -> String:
	var reason := block(s)
	if not reason.is_empty():
		return reason
	if not item_id in fenceable(s):
		return "鬼市只收明面上卖不出去的东西。"
	var paid := fence_price(s, item_id)
	s.remove_item(item_id, 1)
	s.player.stones = int(s.player.stones) + paid
	return s.finish(s.log_event("guishi_fence", {"item": item_id, "stones": paid}))

# --- 接单 and 雇凶 ------------------------------------------------------------------------------------

## Tonight's contract: {"name", "title", "sect", "gender", "reward"}.
static func contract(s) -> Dictionary:
	var rng := _rng(s, "contract")
	var rules: Dictionary = data(s).contract
	var targets: Array = rules.targets
	var target: Dictionary = targets[rng.randi_range(0, targets.size() - 1)]
	return {"name": Population._name(rng, s.content.population_data), "title": str(target.title), "sect": str(target.sect), "gender": "female" if rng.randf() < 0.35 else "male", "reward": int(round(float(price(s)) * float(rules.reward)))}

static func contract_block(s) -> String:
	var reason := block(s)
	if not reason.is_empty():
		return reason
	if int(state(s).get("contract", -1)) == int(state(s).night):
		return "今夜的单子已经接过了。"
	return ""

## Takes tonight's contract: a duel outside the market with whom it names.
static func take_contract(s) -> String:
	var reason := contract_block(s)
	if not reason.is_empty():
		return reason
	state(s).contract = int(state(s).night)
	var target := contract(s)
	var rules: Dictionary = data(s).contract
	var foe: Dictionary = s.Summit.foe(s, "%s · %s" % [target.title, target.name], str(target.sect), str(target.gender), int(s.player.realm), int(s.player.stage), float(rules.power), int(price(s)))
	s.battle = {"enemy_id": "cultivator", "hp": int(foe.hp), "turn": 1, "cooldowns": {}, "opponent_sect": "qingyun" if str(target.sect) == "wanderer" else str(target.sect), "status": {}, "context": "guishi", "guishi": {"reward": int(target.reward), "foe": "%s%s" % [target.title, target.name]}, "foe": foe, "place": s.Combat._battle_place(s)}
	s.combat_events.clear()
	s.Combat.open_hand(s)
	return s.finish(s.log_event("guishi_contract", {"foe": "%s%s" % [target.title, target.name]}))

## The contract's duel ends: paid and marked on the 凶人榜, or beaten and let go.
static func over(s, won: bool) -> String:
	var bout: Dictionary = s.battle.get("guishi", {})
	s.battle.clear()
	s.record_deed("duel")
	s.player.hp = maxi(int(s.player.hp), 1)
	var args := {"foe": str(bout.get("foe", "")), "stones": int(bout.get("reward", 0))}
	var text := ""
	if won:
		s.player.stones = int(s.player.stones) + int(bout.get("reward", 0))
		s.world.flags[str(data(s).contract.flag)] = true
		s.record_deed("guishi_contract")
		text = s.log_event("guishi_contract_done", args)
	else:
		s.player.hp = maxi(1, int(s.player.max_hp) / 4)
		text = s.log_event("guishi_contract_failed", args)
	return s.conclude(text, s.advance_days(s.content.action_days("road_recovery")))

## What having a grudge settled by hired hands costs.
static func hire_cost(s) -> int:
	return s.Feuds.pay(s) * int(data(s).hire)

static func hire(s, grudge_id: String) -> String:
	var reason := block(s)
	if not reason.is_empty():
		return reason
	var grudge: Dictionary = s.Feuds.find(s, grudge_id)
	if grudge.is_empty():
		return "没有这桩仇。"
	if int(s.player.stones) < hire_cost(s):
		return "灵石不够雇人。"
	s.player.stones = int(s.player.stones) - hire_cost(s)
	s.Feuds.settle(s, grudge_id)
	var text: String = s.log_event("guishi_hire", {"foe": str(grudge.name), "stones": hire_cost(s)})
	return s.finish(_spend(s, hire_cost(s), text))

# --- 黑拍 ------------------------------------------------------------------------------------------

static func black_block(s) -> String:
	var reason := block(s)
	if not reason.is_empty():
		return reason
	var month := Calendar.month(int(s.world.day))
	if not data(s).black.months.any(func(listed: Variant) -> bool: return int(listed) == month):
		return "黑拍每季一场，这个月没有。"
	if int(state(s).get("black", -1)) == int(state(s).night):
		return "今夜的黑拍已经散了。"
	return ""

static func black(s) -> String:
	var reason := black_block(s)
	if not reason.is_empty():
		return reason
	state(s).black = int(state(s).night)
	return s.finish(s.Auctions.open(s, str(data(s).black.auction)))

# --- 财不露白 --------------------------------------------------------------------------------------

## Stones spent tonight; past the night's measure someone takes note of the player.
static func _spend(s, amount: int, text: String) -> String:
	var held := state(s)
	held.spent = int(held.get("spent", 0)) + amount
	if not second(s) and not bool(held.get("tail", false)) and int(held.spent) >= price(s) * int(data(s).tail.spend):
		held.tail = true
		text += " " + s.log_event("guishi_noticed", {})
	return text

## Visiting the market counts (灯婆's war waits for a regular); followed out, the shadow strikes once the
## player is away from the market. Called with the location events.
static func check(s) -> void:
	if not s.pending_event.is_empty() or not s.battle.is_empty() or not s.ended.is_empty():
		return
	var held: Dictionary = s.world.get("guishi", {})
	if bool(held.get("tail", false)) and str(s.player.location) != str(data(s).location):
		held.tail = false
		s.pending_event = {"id": str(data(s).tail.event), "day": int(s.world.day), "values": {"foe": str(s.content.enemies[str(data(s).tail.enemy)].name)}}

## Opening the market's view marks a visit, once a night.
static func visit(s) -> void:
	if not block(s).is_empty():
		return
	var held := state(s)
	if int(held.get("visited", -1)) != int(held.night):
		held.visited = int(held.night)
		s.record_deed("guishi")

## The shadow's ambush answered (effect `guishi`).
static func apply(s, what: String) -> void:
	match what:
		"tail_fight":
			s.begin_battle(str(data(s).tail.enemy), "event")
		"tail_pay":
			var lost := int(s.player.stones) / 5
			s.player.stones = int(s.player.stones) - lost
			s.log_event("guishi_tail_paid", {"stones": lost})
