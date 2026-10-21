extends RefCounted
## 秘境 (docs/SIDEQUESTS_DRAFT_20261020.md part four): places that open for a while every so many years
## (data/mijing.json `realms`), each a cave of rooms (caves.gd) at a place of its own that no road reaches.
## Operates on a Session.
## - 限时: a dated event opens it (effect `mijing_open`: the cave afresh, its `open_flag`, its
##   `reset_flags` cleared) and another shuts it (`mijing_close`); whoever is still inside is trapped: a
##   遁地符 gets them out with half of what they gathered, else they crawl out with nothing, badly hurt.
## - 名额: while it is open, a player of its realms (`min`, `max_realm`) who stops at one of its `call_at`
##   places is asked in (its `gate` event); each way in (`ways`: a sect's place, 顶名, a bought place, a
##   fight past the door) is a choice there with effect `mijing_enter` [realm, way]. A way may hand over a
##   share (`tithe`) of what was gathered on the way out, for the sect's merit (`contribution` each).
## - 多方同场: entering a room with things to take, someone else may be after them (`meet`, by the room's
##   `layer`): a disciple of one of its `factions`, or one of the 天骄 of the scroll of the player's realm
##   (tianji.gd). The `meet` event's choices: fight for them (a real duel; won, their gatherings and a
##   word on the 天骄榜; lost, a third of one's own), give one of the `prize` to pass, or leave them the
##   room and agree to see each other out (`ally`).
## - 组队与背叛: a cave's companion (caves.gd party) may turn on a day of their own (`betray`).
## - Events on days inside (`beats`), a room's own event (caves.gd room `event`), and an event on the way
##   out (`exit_event`) carry a realm's story; `outcomes`, the first that holds, close it on the way out.
## - 出口截道: going out, the more one carries the likelier someone waits (`ambush`): fight, hand over half,
##   or, with 神识 enough, slip by; a bribe paid beforehand (`bribe_flag`) or an ally halves it or ends it.
## world.mijing: {"inside" (realm or ""), "from" (where the player came in from), "way", "day" (when they
## went in), "haul" {item: count gathered inside}, "wins", "beats" [fired], "ally", "room", "meet" (the
## foe met, while asked), "opened" {realm: day it last opened}, "offered" {realm: that day, once
## entered or declined}, "out" {"realm", "haul"} (what was carried out, for the ambush)}.
const Events = preload("res://scripts/core/events.gd")
const Population = preload("res://scripts/core/population.gd")

static func data(s) -> Dictionary:
	return s.content.mijing_data

static func realm(s, realm_id: String) -> Dictionary:
	return data(s).realms.get(realm_id, {})

static func state(s) -> Dictionary:
	if not s.world.get("mijing") is Dictionary:
		s.world["mijing"] = {}
	var held: Dictionary = s.world.mijing
	for key: String in ["opened", "offered", "haul"]:
		if not held.get(key) is Dictionary:
			held[key] = {}
	return held

## The realm the player is inside, or "".
static func inside(s) -> String:
	return str(s.world.get("mijing", {}).get("inside", ""))

static func is_open(s, realm_id: String) -> bool:
	return s.has_flag(str(realm(s, realm_id).get("open_flag", "")))

## The realm whose place `location_id` is, or "".
static func at(s, location_id: String) -> String:
	for realm_id: String in data(s).realms:
		if str(data(s).realms[realm_id].location) == location_id:
			return realm_id
	return ""

## The realm whose cave `cave_id` is, or "".
static func of_cave(s, cave_id: String) -> String:
	for realm_id: String in data(s).realms:
		if str(data(s).realms[realm_id].cave) == cave_id:
			return realm_id
	return ""

## Whether the player's realm and stage are among those a realm lets in.
static func fits(s, realm_id: String) -> bool:
	var info := realm(s, realm_id)
	var low: Array = info.min
	return Events.met(s, {"stage_at_least": low}) and int(s.player.realm) <= int(info.max_realm)

## Days left before it shuts (counting today), or 0.
static func days_left(s, realm_id: String) -> int:
	var opened := int(state(s).opened.get(realm_id, -1))
	if not is_open(s, realm_id) or opened < 0:
		return 0
	return maxi(0, opened + int(realm(s, realm_id).days) - int(s.world.day))

## Days since the player went in.
static func days_inside(s) -> int:
	return int(s.world.day) - int(state(s).get("day", s.world.day))

# --- Opening and shutting -------------------------------------------------------------------------

static func open(s, realm_id: String) -> void:
	var info := realm(s, realm_id)
	s.Caves.reset(s, str(info.cave))
	for flag: Variant in info.get("reset_flags", []):
		s.world.flags.erase(str(flag))
	s.world.flags[str(info.open_flag)] = true
	state(s).opened[realm_id] = int(s.world.day)

static func close(s, realm_id: String) -> String:
	s.world.flags.erase(str(realm(s, realm_id).open_flag))
	return trapped(s) if inside(s) == realm_id else ""

## Shut in: a 遁地符 tears a way out with half of what was gathered; without one, everything is lost
## and the body pays for the long crawl out.
static func trapped(s) -> String:
	var realm_id := inside(s)
	var info := realm(s, realm_id)
	var rules: Dictionary = info.trapped
	var args := {"mijing": str(info.name)}
	var text := ""
	if s.item_count(str(rules.item)) > 0:
		s.remove_item(str(rules.item), 1)
		var torn := _lose(s, 0.5)
		s.player.hp = maxi(1, mini(int(s.player.hp), int(s.player.max_hp) / 2))
		text = _told(s, "mijing_torn", args.merged({"item": str(rules.item)}), torn, true)
	else:
		_lose(s, 1.0)
		s.player.hp = 1
		s.Combat._wound(s, int(rules.wound_days), int(rules.wound_days) / 2)
		text = s.log_event("mijing_trapped", args, true)
	s.pending_event = {}
	var close := _close_story(s, realm_id)
	_out(s, realm_id)
	return text if close.is_empty() else text + " " + close

# --- Going in -------------------------------------------------------------------------------------

## Asks the player in, where they stop while a realm is open, once each opening; inside, the realm's
## events on days of their own. Called with the location events.
static func check(s) -> void:
	if not s.pending_event.is_empty() or not s.battle.is_empty() or not s.ended.is_empty():
		return
	var realm_id := inside(s)
	if not realm_id.is_empty():
		_beats(s, realm_id)
		return
	var held := state(s)
	for candidate: String in data(s).realms:
		var info: Dictionary = data(s).realms[candidate]
		if not is_open(s, candidate) or not str(s.player.location) in info.call_at or not fits(s, candidate):
			continue
		if int(held.offered.get(candidate, -1)) == int(held.opened.get(candidate, -2)):
			continue
		s.pending_event = {"id": str(info.gate), "day": int(s.world.day), "values": {"mijing": str(info.name), "days": days_left(s, candidate)}}
		return

## Goes in by `way` (effect `mijing_enter`).
static func enter(s, realm_id: String, way: String) -> void:
	var info := realm(s, realm_id)
	var held := state(s)
	held.offered[realm_id] = int(held.opened.get(realm_id, -1))
	held.merge({"inside": realm_id, "from": str(s.player.location), "way": way, "day": int(s.world.day), "haul": {}, "wins": 0, "beats": [], "ally": false, "room": "", "meet": {}, "out": {}}, true)
	s.player.location = str(info.location)
	s.player.journey = {}
	s.log_event("mijing_enter", {"mijing": str(info.name), "days": days_left(s, realm_id)}, true)

## Not this time (the gate's last choice).
static func decline(s) -> void:
	for realm_id: String in data(s).realms:
		if str(realm(s, realm_id).gate) == str(s.pending_event.get("id", "")):
			state(s).offered[realm_id] = int(state(s).opened.get(realm_id, -1))

## The realm's events whose day inside has come, and a companion's turn: the first one due becomes
## pending (an event whose own conditions fail is passed over for good).
static func _beats(s, realm_id: String) -> void:
	var held := state(s)
	var due: Array = realm(s, realm_id).get("beats", []).duplicate()
	var along: String = s.Caves.party(s, str(realm(s, realm_id).cave))
	if not along.is_empty():
		var turn: Dictionary = s.Caves.definition(s, str(realm(s, realm_id).cave)).companions[along].get("betray", {})
		if not turn.is_empty():
			due.append(turn)
	for beat: Dictionary in due:
		var event_id := str(beat.event)
		if event_id in held.beats or days_inside(s) < int(beat.day):
			continue
		held.beats.append(event_id)
		if Events.all_met(s, s.content.events[event_id].get("conditions", [])):
			s.pending_event = {"id": event_id, "day": int(s.world.day)}
			return

# --- Inside ---------------------------------------------------------------------------------------

## Why a room of a realm's cave cannot be entered yet (its `requires_wins`), or "".
static func room_block(s, cave_id: String, room: Dictionary) -> String:
	var need := int(room.get("requires_wins", 0))
	if need > 0 and of_cave(s, cave_id) == inside(s) and int(state(s).get("wins", 0)) < need:
		return "%s（须在%s中胜过 %d 人，你已胜 %d 人）。" % [str(room.get("wins_text", "还进不去")), str(realm(s, inside(s)).name), need, int(state(s).get("wins", 0))]
	return ""

## Whether someone is after a room's things as the player comes in: a room of the layer's chance, with
## things to take. Raises the `meet` event and returns true.
static func meets(s, cave_id: String, room: Dictionary) -> bool:
	var realm_id := of_cave(s, cave_id)
	if realm_id.is_empty() or realm_id != inside(s) or not room.has("loot"):
		return false
	var meeting: Dictionary = realm(s, realm_id).meet
	var chances: Array = meeting.chance
	if s.fortune_roll("mijing_meet") >= float(chances[clampi(int(room.get("layer", 1)), 0, chances.size() - 1)]):
		return false
	var foe := _foe(s, realm_id)
	state(s).room = str(room.id)
	state(s).meet = foe
	s.pending_event = {"id": str(meeting.event), "day": int(s.world.day), "values": {"foe": str(foe.name), "title": str(foe.title)}}
	return true

## Whom the player runs into: one of the 天骄 of their realm's scroll now and then, else a disciple of
## one of the factions.
static func _foe(s, realm_id: String) -> Dictionary:
	var meeting: Dictionary = realm(s, realm_id).meet
	var rng := RandomNumberGenerator.new()
	rng.seed = hash([int(s.world.seed), realm_id, int(s.world.day), state(s).room])
	var scroll_id: String = s.Tianji.own_scroll(s)
	if not scroll_id.is_empty() and rng.randf() < float(meeting.prodigy):
		var rows: Array = s.Tianji.order(s, scroll_id).filter(func(id: String) -> bool: return id != s.Tianji.PLAYER)
		var id: String = rows[rng.randi_range(0, rows.size() - 1)]
		var seat: int = s.Tianji.order(s, scroll_id).find(id) + 1
		var info: Dictionary = s.Tianji.entry(s, scroll_id, id)
		var strength: Array = s.Tianji.tier(s, seat)
		return {"name": str(info.name), "title": "天骄榜第%d %s" % [seat, info.title], "sect": str(info.sect), "gender": str(info.gender), "stage": int(strength[0]), "power": float(strength[1]) + float(info.power), "scroll": scroll_id, "id": id}
	var factions: Array = meeting.factions
	var faction: Dictionary = factions[rng.randi_range(0, factions.size() - 1)]
	return {"name": Population._name(rng, s.content.population_data), "title": str(faction.title), "sect": str(faction.sect), "gender": "female" if rng.randf() < 0.4 else "male", "stage": clampi(int(s.player.stage) + rng.randi_range(-1, 1), 0, 3), "power": float(meeting.power)}

## What the player does about whom they met, about the room's things, and on the way out (effect
## `mijing`).
static func apply(s, what: String) -> void:
	var realm_id := inside(s)
	var info := realm(s, realm_id)
	match what:
		"fight":
			_duel(s, realm_id)
		# One of the prize to pass; the room's things stay the player's.
		"share":
			for item_id: Variant in info.get("prize", []):
				if s.item_count(str(item_id)) > 0:
					s.remove_item(str(item_id), 1)
					_forget(s, {str(item_id): 1})
					break
			state(s).meet = {}
		# The room left to them, and a word to see each other out.
		"ally":
			_forfeit(s, realm_id)
			state(s).ally = true
		"yield":
			_forfeit(s, realm_id)
		# The prize handed over at the door (赤霞谷's 焦长老).
		"surrender":
			var given := {}
			for item_id: Variant in info.get("prize", []):
				var count := mini(s.item_count(str(item_id)), int(state(s).haul.get(str(item_id), 0)))
				if count > 0:
					s.remove_item(str(item_id), count)
					given[str(item_id)] = count
			_forget(s, given)
		# Every part of going out is in the chronicle already.
		"leave":
			leave(s)
		"decline":
			decline(s)
		"rob_fight":
			s.begin_battle(str(_out_realm(s).ambush.enemy), "event")
			s.battle.robbery = str(state(s).out.get("realm", ""))
		"rob_pay":
			_robbed(s, 0.5)

## The room's things left to whoever met the player there.
static func _forfeit(s, realm_id: String) -> void:
	var room_id := str(state(s).get("room", ""))
	var cave_id := str(realm(s, realm_id).cave)
	if not room_id.is_empty() and s.Caves.loot_waits(s, cave_id, room_id):
		s.world.caves[cave_id].taken.append(room_id)
	state(s).meet = {}

## A duel with whom the player met, for the room's things and theirs.
static func _duel(s, realm_id: String) -> void:
	var foe: Dictionary = state(s).meet
	var meeting: Dictionary = realm(s, realm_id).meet
	var built: Dictionary = s.Summit.foe(s, "%s · %s" % [foe.title, foe.name], str(foe.sect), str(foe.gender), int(s.player.realm), int(foe.stage), float(foe.power), int(meeting.xp[mini(int(s.player.realm), meeting.xp.size() - 1)]))
	s.battle = {"enemy_id": "cultivator", "hp": int(built.hp), "turn": 1, "cooldowns": {}, "opponent_sect": "qingyun" if str(foe.sect) == "wanderer" else str(foe.sect), "status": {}, "context": "mijing", "mijing": realm_id, "foe": built, "place": s.Combat._battle_place(s)}
	s.combat_events.clear()
	s.Combat.open_hand(s)

## The duel ends: won, their gatherings and a word on the 天骄榜; lost, a third of the player's; fled,
## the room left to them.
static func over(s, won: bool, fled: bool = false) -> String:
	var realm_id := str(s.battle.get("mijing", inside(s)))
	var info := realm(s, realm_id)
	var meeting: Dictionary = info.meet
	var foe: Dictionary = state(s).get("meet", {})
	var args := {"mijing": str(info.name), "foe": "%s%s" % [foe.get("title", ""), foe.get("name", "")]}
	var xp := int(s.battle.get("foe", {}).get("xp", 0))
	s.battle.clear()
	s.record_deed("duel")
	s.player.hp = maxi(int(s.player.hp), 1)
	var texts: Array[String] = []
	if won:
		state(s).wins = int(state(s).get("wins", 0)) + 1
		var spoils := {}
		var stones: int = s.world_rng.randi_range(int(meeting.stones[0]), int(meeting.stones[1])) * (1 + int(s.player.realm))
		s.player.stones = int(s.player.stones) + stones
		var prize: Array = info.get("prize", [])
		if not prize.is_empty() and s.world_rng.randf() < float(meeting.prize_chance):
			spoils[str(prize[s.world_rng.randi_range(0, prize.size() - 1)])] = 1
		for item_id: String in spoils:
			s.add_item(item_id, int(spoils[item_id]))
		record(s, spoils)
		texts.append(s.log_event("mijing_won_loot" if not spoils.is_empty() else "mijing_won", args.merged({"stones": stones, "loot": s.loot_code(spoils)})))
		# A 天骄 beaten inside: the 天机阁 hears of it.
		if foe.has("scroll"):
			s.Tianji.overtake(s, str(foe.scroll), str(foe.id))
			texts.append(s.Tianji.note(s, "%s中胜%s。" % [info.name, foe.name]))
		texts.append_array(s.gain_xp(xp))
	elif fled:
		_forfeit(s, realm_id)
		texts.append(s.log_event("mijing_fled", args))
	else:
		_forfeit(s, realm_id)
		s.player.hp = maxi(1, int(s.player.max_hp) / 4)
		var taken := _lose(s, float(meeting.loss))
		texts.append(s.log_event("mijing_lost_loot" if not taken.is_empty() else "mijing_lost", args.merged({"loot": s.loot_code(taken)})))
	state(s).meet = {}
	texts.append_array(s.gain_insight("battle_win" if won else "spar"))
	return s.conclude(" ".join(texts.filter(func(text: String) -> bool: return not text.is_empty())), s.advance_days(int(info.duel_days)))

# --- What was gathered ----------------------------------------------------------------------------

## Counts things found inside (a room's, a hidden place's, a duel's) as gathered there.
static func record(s, found: Dictionary) -> void:
	if inside(s).is_empty():
		return
	var haul: Dictionary = state(s).haul
	for item_id: String in found:
		haul[item_id] = int(haul.get(item_id, 0)) + int(found[item_id])

static func _forget(s, gone: Dictionary) -> void:
	var haul: Dictionary = state(s).haul
	for item_id: String in gone:
		var left := int(haul.get(item_id, 0)) - int(gone[item_id])
		if left > 0:
			haul[item_id] = left
		else:
			haul.erase(item_id)

## What the player still carries of what they gathered: {item: count}.
static func carried(s, haul: Dictionary) -> Dictionary:
	var kept := {}
	for item_id: String in haul:
		var count := mini(int(haul[item_id]), s.item_count(item_id))
		if count > 0:
			kept[item_id] = count
	return kept

## The stones it would fetch, by its list prices.
static func value(s, haul: Dictionary) -> int:
	var total := 0
	var kept := carried(s, haul)
	for item_id: String in kept:
		total += int(s.content.item(item_id).get("price", 0)) * int(kept[item_id])
	return total

## Takes `share` of each thing gathered (rounded, so half of one is the one), never the realm's `keep`
## (a sword that chose its owner); returns what was taken.
static func _lose(s, share: float, haul: Dictionary = {}, realm_id: String = "") -> Dictionary:
	if haul.is_empty():
		haul = state(s).haul
	if realm_id.is_empty():
		realm_id = inside(s)
	var keep: Array = realm(s, realm_id).get("keep", [])
	var taken := {}
	var kept := carried(s, haul)
	for item_id: String in kept:
		if item_id in keep:
			continue
		var count := mini(int(kept[item_id]), roundi(float(kept[item_id]) * share))
		if count > 0:
			s.remove_item(item_id, count)
			taken[item_id] = count
	for item_id: String in taken:
		var left := int(haul.get(item_id, 0)) - int(taken[item_id])
		if left > 0:
			haul[item_id] = left
		else:
			haul.erase(item_id)
	return taken

# --- Going out ------------------------------------------------------------------------------------

## Why the player cannot go out now, or "".
static func leave_block(s) -> String:
	var reason: String = s.blocked()
	if not reason.is_empty():
		return reason
	return "此刻不在秘境之中。" if inside(s).is_empty() else ""

## 出谷: the realm's word at the door first if it has one, then out (the share handed over, the story's
## close, perhaps someone waiting).
static func exit(s) -> String:
	var reason := leave_block(s)
	if not reason.is_empty():
		return reason
	var info := realm(s, inside(s))
	var at_door := str(info.get("exit_event", ""))
	if not at_door.is_empty() and Events.all_met(s, s.content.events[at_door].get("conditions", [])):
		s.pending_event = {"id": at_door, "day": int(s.world.day)}
		return s.finish("")
	return s.conclude(leave(s))

## Out of the door: the way's share handed over, the story closed, back where the player came from;
## whoever waits outside, by how much is carried.
static func leave(s) -> String:
	var realm_id := inside(s)
	var info := realm(s, realm_id)
	var held := state(s)
	var texts: Array[String] = []
	var way: Dictionary = info.ways.get(str(held.way), {})
	# A way's share is not asked once its `unless` holds (赤霄 asks nothing after 焦长老 falls).
	var tithe := float(way.get("tithe", 0.0))
	if tithe > 0.0 and (not way.has("unless") or not Events.all_met(s, way.unless)):
		var handed := {}
		for item_id: Variant in info.get("prize", []):
			var count := mini(s.item_count(str(item_id)), int(held.haul.get(str(item_id), 0)))
			var given := int(floor(float(count) * tithe))
			if given > 0:
				s.remove_item(str(item_id), given)
				handed[str(item_id)] = given
		_forget(s, handed)
		if not handed.is_empty():
			var merit := 0
			for item_id: String in handed:
				merit += int(handed[item_id]) * int(way.get("contribution", 0))
			texts.append(s.log_event("mijing_tithe", {"mijing": str(info.name), "loot": s.loot_code(handed), "to": str(way.to)}))
			if merit > 0:
				texts.append(s.Sect.gain(s, merit, "交上%s所采" % info.name))
	texts.append(_close_story(s, realm_id))
	var haul: Dictionary = carried(s, held.haul)
	texts.append(_told(s, "mijing_out", {"mijing": str(info.name)}, haul))
	var ally := bool(held.get("ally", false))
	_out(s, realm_id)
	held.out = {"realm": realm_id, "haul": haul}
	var passed: Dictionary = s.advance_days(int(info.exit_days))
	texts.append_array(passed.messages)
	if s.ended.is_empty() and s.pending_event.is_empty() and s.fortune_roll("mijing_ambush") < ambush_chance(s, realm_id, haul, ally):
		s.pending_event = {"id": str(info.ambush.event), "day": int(s.world.day), "values": {"foe": str(s.content.enemies[str(info.ambush.enemy)].name)}}
	return " ".join(texts.filter(func(text: String) -> bool: return not text.is_empty()))

## The first of the realm's `outcomes` that holds, however the player comes out; returns its words.
static func _close_story(s, realm_id: String) -> String:
	for outcome: Dictionary in realm(s, realm_id).get("outcomes", []):
		if Events.all_met(s, outcome.get("if", [])):
			Events.apply(s, outcome.get("effects", []))
			return s.log_event("mijing_outcome", {"text": str(outcome.text)}, true)
	return ""

## How likely someone waits outside for what is carried out: by its worth, halved for an ally, none for
## one who paid them off beforehand.
static func ambush_chance(s, realm_id: String, haul: Dictionary, ally: bool) -> float:
	var rules: Dictionary = realm(s, realm_id).ambush
	if haul.is_empty() or (rules.has("bribe_flag") and s.has_flag(str(rules.bribe_flag))):
		return 0.0
	var chance := minf(float(rules.max), float(rules.base) + float(rules.per_value) * float(value(s, haul)))
	return chance * (float(rules.ally) if ally else 1.0)

## Back out where the player came in from.
static func _out(s, realm_id: String) -> void:
	var held := state(s)
	var back := str(held.get("from", ""))
	if not s.content.locations.has(back):
		back = str(realm(s, realm_id).outside)
	s.player.location = back
	s.player.journey = {}
	held.inside = ""
	held.meet = {}
	held.room = ""

## Carried out beaten (a guardian, someone at the door): half of what was gathered is lost on the way.
## Returns the words for it.
static func carried_out(s) -> String:
	var realm_id := inside(s)
	var info := realm(s, realm_id)
	var lost := _lose(s, 0.5)
	var text := _told(s, "mijing_carried", {"mijing": str(info.name)}, lost)
	var close := _close_story(s, realm_id)
	_out(s, realm_id)
	return text if close.is_empty() else text + " " + close

## Tells of things found or lost: the entry with them, or its "_none" when there were none.
static func _told(s, id: String, args: Dictionary, things: Dictionary, major: bool = false) -> String:
	if things.is_empty():
		return s.log_event(id + "_none", args, major)
	return s.log_event(id, args.merged({"loot": s.loot_code(things)}), major)

static func _out_realm(s) -> Dictionary:
	return realm(s, str(state(s).get("out", {}).get("realm", "")))

## Robbed of `share` of what was carried out; returns the words for it.
static func _robbed(s, share: float) -> String:
	var out: Dictionary = state(s).get("out", {})
	var taken := _lose(s, share, out.get("haul", {}), str(out.get("realm", "")))
	return _told(s, "mijing_robbed", {"mijing": str(_out_realm(s).get("name", ""))}, taken)

## The robbers at the door beat the player: half of what was carried out goes with them.
static func robbed_in_battle(s) -> String:
	return _robbed(s, 0.5)
