extends RefCounted
## 洞府探索: a cave of stone rooms (data/caves.json) explored a room at a time, after 觅长生's ruins.
## Operates on a Session. The rooms first explored are open from the start; any room linked to an
## explored one can be entered, which takes days (`step_days`). A room may hold:
## - a trap: seen through and passed when the 神识 reaches its `sense`, else it springs and wounds;
## - things lying about (`loot`), taken on entering;
## - a hidden place (`hidden`), seen only with 神识 enough and opened for some 灵力; it may hold the
##   千年石乳 (fortune "shiru");
## - a guardian, a duel on entering; the rooms beyond it stay shut and its room's things wait until it
##   falls (its enemy's world flag);
## - a seal (`requires_sense`) that only 神识 enough opens;
## - heat (`heat`): a protective thing in the pack (避火珠), or 神识 enough to find a cooler way round;
## - the remnant soul (fortune "remnant"), which offers its blessing before foundation.
## Whether the 千年石乳 and the remnant soul are there is decided once, when the cave is first entered
## (fortune.gd's chance, after the talents for fortune). Which of a room's `loot` choices lies there
## follows from the world seed. Everything else is in world.caves[cave]: explored rooms, rooms whose
## things or hidden place are taken ("room" / "room:hidden"), and the placed fortunes.
const Fortune = preload("res://scripts/core/fortune.gd")
const FORTUNES := ["shiru", "remnant"]

static func definition(s, cave_id: String) -> Dictionary:
	return s.content.cave_data.get(cave_id, {})

static func room(s, cave_id: String, room_id: String) -> Dictionary:
	for candidate: Dictionary in definition(s, cave_id).get("rooms", []):
		if candidate.id == room_id:
			return candidate
	return {}

## The cave that can be explored where the player stands, or "".
static func here(s) -> String:
	for cave_id: String in s.content.cave_data:
		var cave: Dictionary = s.content.cave_data[cave_id]
		if str(cave.location) == str(s.player.location) and s.has_flag(str(cave.requires_flag)):
			return cave_id
	return ""

## A cave's state as saved, or an untouched one.
static func state(s, cave_id: String) -> Dictionary:
	return s.world.get("caves", {}).get(cave_id, {"explored": [], "taken": [], "fortune": {}})

## The state, created on the first visit: the start rooms explored and the fortunes placed.
static func _visit(s, cave_id: String) -> Dictionary:
	if not s.world.has("caves"):
		s.world["caves"] = {}
	if not s.world.caves.has(cave_id):
		var explored: Array = []
		for candidate: Dictionary in definition(s, cave_id).rooms:
			if bool(candidate.get("start", false)):
				explored.append(str(candidate.id))
		var placed := {}
		for id: String in fortunes_in(s, cave_id):
			placed[id] = not Fortune.met(s, id) and s.fortune_roll(id) < Fortune.chance(s, id)
		s.world.caves[cave_id] = {"explored": explored, "taken": [], "fortune": placed}
	return s.world.caves[cave_id]

## The fortunes a cave's rooms may hold (a room's `fortune`, a hidden place's).
static func fortunes_in(s, cave_id: String) -> Array:
	var found: Array = []
	for candidate: Dictionary in definition(s, cave_id).get("rooms", []):
		for id: Variant in [candidate.get("fortune", ""), candidate.get("hidden", {}).get("fortune", "")]:
			if str(id) in FORTUNES and not str(id) in found:
				found.append(str(id))
	return found

## A cave that opens again (沉霞古境) starts afresh: its rooms unexplored, its guardians standing.
static func reset(s, cave_id: String) -> void:
	s.world.get("caves", {}).erase(cave_id)
	for candidate: Dictionary in definition(s, cave_id).get("rooms", []):
		if candidate.has("guardian"):
			s.world.flags.erase(str(s.content.enemies[str(candidate.guardian)].world_flag))

static func explored(s, cave_id: String, room_id: String) -> bool:
	return room_id in state(s, cave_id).explored or bool(room(s, cave_id, room_id).get("start", false))

## Whether a room's guardian still stands.
static func guarded(s, cave_id: String, room_id: String) -> bool:
	var guardian := str(room(s, cave_id, room_id).get("guardian", ""))
	return not guardian.is_empty() and not s.has_flag(str(s.content.enemies[guardian].world_flag))

## Whether a room can be reached: linked to an explored room that no guardian bars.
static func reachable(s, cave_id: String, room_id: String) -> bool:
	for link: Variant in room(s, cave_id, room_id).get("links", []):
		if explored(s, cave_id, str(link)) and not guarded(s, cave_id, str(link)):
			return true
	return false

## Why the room cannot be entered now, or "".
static func enter_block(s, cave_id: String, room_id: String) -> String:
	var reason: String = s.blocked()
	if not reason.is_empty():
		return reason
	if here(s) != cave_id:
		return "此地无法如此行事。"
	var target := room(s, cave_id, room_id)
	if target.is_empty():
		return "没有这间石室。"
	if explored(s, cave_id, room_id):
		return "这间石室已经探过。"
	if not reachable(s, cave_id, room_id):
		return "还找不到通往这里的路。"
	if s.sense() < int(target.get("requires_sense", 0)):
		return "门上的禁制须神识 %d 方能破开（你的神识 %d）。" % [int(target.requires_sense), s.sense()]
	# Heat (地火之心): a 避火珠 in the pack, or 神识 enough to find a cooler way round.
	var heat: Dictionary = target.get("heat", {})
	if not heat.is_empty() and s.item_count(str(heat.item)) < 1 and s.sense() < int(heat.sense):
		return "%s：须带%s，或神识 %d 寻出一条凉些的岔道（你的神识 %d）。" % [heat.text, s.content.item(str(heat.item)).name, int(heat.sense), s.sense()]
	return ""

## Enters a room: the days pass, then its trap, things, guardian or remnant soul.
static func enter(s, cave_id: String, room_id: String) -> String:
	var reason := enter_block(s, cave_id, room_id)
	if not reason.is_empty():
		return reason
	var cave := definition(s, cave_id)
	var target := room(s, cave_id, room_id)
	var visit := _visit(s, cave_id)
	var passed: Dictionary = s.advance_days(int(cave.step_days))
	if not s.ended.is_empty():
		return s.conclude("", passed)
	visit.explored.append(room_id)
	var args := {"cave": cave_id, "room": room_id}
	var texts: Array[String] = [s.log_event("cave_enter", args.merged({"days": passed.elapsed}))]
	if target.has("trap"):
		var trap: Dictionary = target.trap
		var name := str(_pick(s, cave_id, room_id + ":trap", trap.names))
		if s.sense() >= int(trap.sense):
			texts.append(s.log_event("cave_trap_seen", args.merged({"trap": name})))
		else:
			var hurt: int = s.world_rng.randi_range(int(trap.damage[0]), int(trap.damage[1]))
			hurt = mini(hurt, int(s.player.hp) - 1)
			s.player.hp = int(s.player.hp) - hurt
			# One already hanging by a thread is spared the telling of a wound of nothing.
			texts.append(s.log_event("cave_trap_sprung" if hurt > 0 else "cave_trap_grazed", args.merged({"trap": name, "amount": hurt})))
	if guarded(s, cave_id, room_id):
		texts.append(s.begin_battle(str(target.guardian), "event"))
		s.battle.cave = cave_id
	elif str(target.get("fortune", "")) == "remnant" and _remnant_waits(s, cave_id):
		visit.fortune.remnant = false
		visit.taken.append(room_id)
		s.pending_event = {"id": str(Fortune.rules(s).remnant.event), "day": int(s.world.day)}
	elif target.has("loot"):
		texts.append(_take(s, cave_id, room_id, room_id, target.loot))
	return s.conclude(" ".join(texts.filter(func(text: String) -> bool: return not text.is_empty())), passed)

## The remnant soul is there and the player has not founded yet.
static func _remnant_waits(s, cave_id: String) -> bool:
	return bool(state(s, cave_id).fortune.get("remnant", false)) and not Fortune.met(s, "remnant") and int(s.player.realm) < int(Fortune.rules(s).remnant.before_realm)

## Faces a guardian that still stands in an explored room again (after a lost or fled duel). Takes no
## days beyond the duel's own.
static func challenge(s, cave_id: String, room_id: String) -> String:
	var reason: String = s.blocked()
	if not reason.is_empty():
		return reason
	if here(s) != cave_id or not explored(s, cave_id, room_id) or not guarded(s, cave_id, room_id):
		return "这里没有对手。"
	var text: String = s.begin_battle(str(room(s, cave_id, room_id).guardian), "event")
	s.battle.cave = cave_id
	return s.finish(text)

## Whether a room's things still wait (left behind a guardian that has fallen since).
static func loot_waits(s, cave_id: String, room_id: String) -> bool:
	var target := room(s, cave_id, room_id)
	return target.has("loot") and explored(s, cave_id, room_id) and not guarded(s, cave_id, room_id) and not room_id in state(s, cave_id).taken

## Takes the things a fallen guardian kept. Takes no time.
static func collect(s, cave_id: String, room_id: String) -> String:
	if here(s) != cave_id or not loot_waits(s, cave_id, room_id) or not s.blocked().is_empty():
		return "这里没有可取的东西。"
	_visit(s, cave_id)
	return s.finish(_take(s, cave_id, room_id, room_id, room(s, cave_id, room_id).loot))

## Whether the 神识 sees a room's hidden place.
static func hidden_seen(s, cave_id: String, room_id: String) -> bool:
	var target := room(s, cave_id, room_id)
	return target.has("hidden") and explored(s, cave_id, room_id) and s.sense() >= int(target.hidden.sense)

## Why a room's hidden place cannot be opened now, or "".
static func hidden_block(s, cave_id: String, room_id: String) -> String:
	var reason: String = s.blocked()
	if not reason.is_empty():
		return reason
	var target := room(s, cave_id, room_id)
	if here(s) != cave_id or not target.has("hidden") or not explored(s, cave_id, room_id):
		return "此地无法如此行事。"
	if room_id + ":hidden" in state(s, cave_id).taken:
		return "暗处已经取空。"
	if not hidden_seen(s, cave_id, room_id):
		return "神识不足以看清（须 %d，你的神识 %d）。" % [int(target.hidden.sense), s.sense()]
	if int(s.player.qi) < int(target.hidden.qi):
		return "灵力不足：破开禁制需要 %d 灵力。" % int(target.hidden.qi)
	return ""

## Opens a hidden place for its 灵力: the 千年石乳 if it was placed there, else its things.
static func open_hidden(s, cave_id: String, room_id: String) -> String:
	var reason := hidden_block(s, cave_id, room_id)
	if not reason.is_empty():
		return reason
	var hidden: Dictionary = room(s, cave_id, room_id).hidden
	var visit := _visit(s, cave_id)
	s.player.qi = int(s.player.qi) - int(hidden.qi)
	var texts: Array[String] = [s.log_event("cave_hidden", {"cave": cave_id, "room": room_id, "hidden": str(hidden.name), "qi": int(hidden.qi)})]
	if str(hidden.get("fortune", "")) == "shiru" and bool(visit.fortune.get("shiru", false)) and not Fortune.met(s, "shiru"):
		visit.fortune.shiru = false
		visit.taken.append(room_id + ":hidden")
		texts.append(Fortune.grant_treasure(s, "shiru"))
	else:
		texts.append(_take(s, cave_id, room_id, room_id + ":hidden", hidden.loot))
	return s.finish(" ".join(texts))

## One of `options` for this world, from its seed; the same every time it is asked.
static func _pick(s, cave_id: String, key: String, options: Array) -> Variant:
	return options[mini(options.size() - 1, int(s.seeded_roll(["cave", cave_id, key]) * options.size()))]

## The things lying in a room for this world (one of its `loot` choices).
static func loot_of(s, cave_id: String, key: String, choices: Array) -> Array:
	return _pick(s, cave_id, key, choices)

## Takes this world's choice of `choices`, marks `key` taken, and tells what was found.
static func _take(s, cave_id: String, room_id: String, key: String, choices: Array) -> String:
	s.world.caves[cave_id].taken.append(key)
	var found := {}
	var stones := 0
	for effect: Dictionary in loot_of(s, cave_id, key, choices):
		var kind: String = effect.keys()[0]
		var value: Variant = effect[kind]
		match kind:
			"stones":
				stones += int(value)
			"item":
				found[str(value[0])] = int(found.get(str(value[0]), 0)) + int(value[1])
			"pills":
				found["foundation_pill"] = int(found.get("foundation_pill", 0)) + int(value)
			"manual":
				found["j:" + s.Arsenal.generate_technique(s.content, s.world_rng, int(value))] = 1
			"equipment":
				found[s.Arsenal.generate_equipment(s.content, s.world_rng, int(value))] = 1
	var texts: Array[String] = []
	for item_id: String in found:
		s.add_item(item_id, int(found[item_id]))
	if not found.is_empty():
		texts.append(s.log_event("cave_loot", {"cave": cave_id, "room": room_id, "loot": s.loot_code(found)}))
	if stones > 0:
		s.player.stones = int(s.player.stones) + stones
		texts.append(s.log_event("cave_stones", {"cave": cave_id, "room": room_id, "stones": stones}))
	return " ".join(texts)
