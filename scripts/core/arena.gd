extends RefCounted
## 擂台 (docs/COMBAT_PLAN.md, part two, B3): a place may keep a stage (data/world.json location `arena`)
## where its own people come up one after another. Taking the stage costs a fee; each win pays a purse
## that grows with the streak, and some streaks bring a prize (a slip, a piece of gear, stones). Each
## challenger is a generated person of the stage's kinds, a little stronger than the last, never the same
## one twice in a run; they fight with their whole loadout. A loss ends the run without any penalty, as
## does stepping down or leaving. Operates on a Session.
## player.arena: {"place", "streak", "fought": [person ids]} while a run lasts; player.arena_best:
## {place: best streak}.

## The stage where the player stands, or {}.
static func stage(s) -> Dictionary:
	return s.content.locations.get(str(s.player.location), {}).get("arena", {})

## The run under way here, or {}.
static func run(s) -> Dictionary:
	var current: Dictionary = s.player.get("arena", {})
	return current if str(current.get("place", "")) == str(s.player.location) else {}

static func best(s) -> int:
	return int(s.player.get("arena_best", {}).get(str(s.player.location), 0))

## Why the player cannot take the stage (or face the next challenger) now, or "".
static func block(s) -> String:
	var reason: String = s.blocked()
	if not reason.is_empty():
		return reason
	if stage(s).is_empty() or not s.available_here("arena"):
		return "此地没有擂台。"
	if run(s).is_empty() and int(s.player.stones) < int(stage(s).fee):
		return "灵石不足：登台要 %d 灵石的彩头。" % int(stage(s).fee)
	if _challenger(s).is_empty():
		return "台下已没有人愿意上来了，改日再来。"
	return ""

## Takes the stage (paying the fee) or, during a run, faces the next challenger.
static func fight(s) -> String:
	var reason := block(s)
	if not reason.is_empty():
		return reason
	var text := ""
	if run(s).is_empty():
		s.player.stones = int(s.player.stones) - int(stage(s).fee)
		s.player["arena"] = {"place": str(s.player.location), "streak": 0, "fought": []}
		text = s.log_event("arena_enter", {"location": s.player.location, "stones": int(stage(s).fee)})
	var opponent := _challenger(s)
	s.player.arena.fought.append(opponent)
	s.Combat.begin_spar(s, opponent)
	s.battle.context = "arena"
	return s.finish(text)

## Steps down: the run ends, everything won is kept.
static func leave(s) -> String:
	if run(s).is_empty():
		return "你并不在台上。"
	var streak := int(s.player.arena.streak)
	s.player.erase("arena")
	return s.finish(s.log_event("arena_leave", {"streak": streak}))

## The next challenger: among the stage's kinds alive in the region, those not yet fought this run, the
## weakest still at least as strong as the last one beaten (by realm and stage), drawn among the few
## nearest so runs differ.
static func _challenger(s) -> String:
	var kinds: Array = stage(s).get("kinds", [])
	var fought: Array = run(s).get("fought", [])
	var region: String = s.content.region_of(str(s.player.location))
	var pool: Array = []
	for person_id: String in s.living_people():
		if not s.is_generated(person_id) or person_id in fought:
			continue
		var life: Dictionary = s.life_by_id(person_id)
		if str(life.get("kind", "")) in kinds and str(life.get("region", "")) == region:
			pool.append(person_id)
	if pool.is_empty():
		return ""
	var strength := func(person_id: String) -> int: return int(s.person(person_id).realm) * 10 + int(s.person(person_id).stage)
	pool.sort_custom(func(a: String, b: String) -> bool: return strength.call(a) < strength.call(b) or (strength.call(a) == strength.call(b) and a < b))
	var floor := 0
	if not fought.is_empty() and s.is_person(str(fought.back())):
		floor = strength.call(str(fought.back()))
	var start := 0
	while start < pool.size() - 1 and strength.call(pool[start]) < floor:
		start += 1
	var span := mini(3, pool.size() - start)
	return pool[start + s.world_rng.randi_range(0, span - 1)]

## A bout is over. A win pays the purse for the streak and any prize; a loss ends the run.
static func over(s, won: bool) -> String:
	var npc: String = str(s.battle.get("npc", ""))
	var place := stage(s)
	s.battle.clear()
	s.record_deed("duel")
	s.player.hp = maxi(int(s.player.hp), 1)
	if not won:
		var lost_streak := int(s.player.get("arena", {}).get("streak", 0))
		s.player.erase("arena")
		return s.conclude(s.log_event("arena_lose", {"npc": npc, "streak": lost_streak}), s.advance_days(s.content.action_days("road_recovery")))
	var streak := int(s.player.arena.streak) + 1
	s.player.arena.streak = streak
	if not s.player.has("arena_best"):
		s.player["arena_best"] = {}
	s.player.arena_best[str(s.player.location)] = maxi(best(s), streak)
	var purse := int(place.purse) * streak
	s.player.stones = int(s.player.stones) + purse
	var texts: Array[String] = [s.log_event("arena_win", {"npc": npc, "streak": streak, "stones": purse})]
	for prize: Dictionary in place.get("prizes", []):
		if int(prize.streak) != streak:
			continue
		var found := {}
		if prize.has("stones"):
			s.player.stones = int(s.player.stones) + int(prize.stones)
		if prize.has("manual"):
			found["j:" + s.Arsenal.generate_technique(s.content, s.world_rng, int(prize.manual))] = 1
		if prize.has("equipment"):
			found[s.Arsenal.generate_equipment(s.content, s.world_rng, int(prize.equipment))] = 1
		for item_id: String in found:
			s.add_item(item_id, 1)
		if found.is_empty():
			texts.append(s.log_event("arena_prize_stones", {"streak": streak, "stones": int(prize.get("stones", 0))}, true))
		else:
			texts.append(s.log_event("arena_prize", {"streak": streak, "loot": s.loot_code(found)}, true))
	# Between bouts a breath: some health and qi come back.
	s.player.hp = mini(int(s.player.max_hp), int(s.player.hp) + int(s.player.max_hp) * 3 / 10)
	s.player.qi = mini(int(s.player.max_qi), int(s.player.qi) + int(s.player.max_qi) * 3 / 10)
	texts.append_array(s.gain_insight("spar"))
	return s.conclude(" ".join(texts))
