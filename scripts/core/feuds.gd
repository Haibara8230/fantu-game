extends RefCounted
## 恩怨与悬赏 (docs/COMBAT_PLAN.md, part two, B5 and B6). Operates on a Session; rules in data/world.json
## `feuds`, outlaws on the boards in data/commissions.json (the `wanted` kind, commissions.gd).
##
## 恩怨找上门: beating one of the road's human foes (`avengers`) may leave a comrade who remembers; some
## deeds name an avenger outright (`seeded`, by a world flag: exposing 袁赤锋 sets 赤霄门 against the
## player). world.grudges: [{"id", "name", "enemy", "cause", "since", "region"}], at most `max`. Teahouses
## hear of it first (lore condition `grudge`); once `ripen_days` have passed and the player can face the
## avenger, a road leg in its region may bring the ambush (`grudge_ambush` in data/events.json), never in
## flight, on a paid passage or in retreat. The player fights, pays, or slips away to be found later.
##
## 悬赏猎杀: an accepted outlaw commission names someone hiding at a place; stopping there finds them
## (`bounty_found`, or `bounty_twist` when the poster lied). Taking them in counts the commission done.

static func rules(s) -> Dictionary:
	return s.content.feuds

## A name for an outlaw or an avenger: a nickname and a person's name, from the world stream.
static func outlaw_name(s, rng: RandomNumberGenerator) -> String:
	var nicknames: Array = rules(s).nicknames
	var data: Dictionary = s.content.population_data
	var given: String = data.given[rng.randi_range(0, data.given.size() - 1)]
	return "「%s」%s%s" % [nicknames[rng.randi_range(0, nicknames.size() - 1)], data.surnames[rng.randi_range(0, data.surnames.size() - 1)], given]

# --- 恩怨 ---------------------------------------------------------------------------------------------

## After a won fight: a comrade of a beaten road foe may swear revenge.
static func after_win(s, enemy_id: String) -> void:
	if not enemy_id in rules(s).avengers or s.world.get("grudges", []).size() >= int(rules(s).max):
		return
	if s.world_rng.randf() >= float(rules(s).grudge_chance):
		return
	_add(s, {"name": outlaw_name(s, s.world_rng), "enemy": enemy_id, "cause": "comrade", "region": s.content.region_of(str(s.player.location))})

## Deeds that name an avenger (`seeded`): each once, when its flag is first seen.
static func update(s) -> void:
	for sworn: Dictionary in rules(s).get("seeded", []):
		var key := "grudge_seeded:" + str(sworn.flag)
		if s.has_flag(str(sworn.flag)) and not s.world.get("grudge_seeds", {}).has(key):
			if not s.world.has("grudge_seeds"):
				s.world["grudge_seeds"] = {}
			s.world.grudge_seeds[key] = int(s.world.day)
			_add(s, {"name": str(sworn.name), "enemy": str(sworn.enemy), "cause": str(sworn.cause), "region": str(sworn.region)})

static func _add(s, grudge: Dictionary) -> void:
	if not s.world.has("grudges"):
		s.world["grudges"] = []
	s.world["grudge_serial"] = int(s.world.get("grudge_serial", 0)) + 1
	grudge.id = "g%d" % int(s.world.grudge_serial)
	grudge.since = int(s.world.day)
	s.world.grudges.append(grudge)
	s.log_event("grudge_sworn", {"foe": str(grudge.name), "enemy": str(grudge.enemy)})

static func find(s, grudge_id: String) -> Dictionary:
	for grudge: Dictionary in s.world.get("grudges", []):
		if str(grudge.id) == grudge_id:
			return grudge
	return {}

## Whether someone bears the player a grudge (the teahouse's whisper).
static func any(s) -> bool:
	return not s.world.get("grudges", []).is_empty()

## On a road leg: a ripe grudge of the region may waylay the player. True when the ambush is pending.
static func ambush(s, route: Dictionary) -> bool:
	var ripe: Array = s.world.get("grudges", []).filter(func(grudge: Dictionary) -> bool:
		return int(s.world.day) >= int(grudge.since) + int(rules(s).ripen_days) \
			and int(s.player.realm) >= int(s.content.enemies[str(grudge.enemy)].min_realm) \
			and route.between.any(func(place: String) -> bool: return s.content.region_of(place) == str(grudge.region)))
	if ripe.is_empty() or s.world_rng.randf() >= float(rules(s).ambush_chance):
		return false
	var grudge: Dictionary = ripe[0]
	s.pending_event = {"id": "grudge_ambush", "day": int(s.world.day), "values": {"grudge": str(grudge.id), "foe": str(grudge.name), "words": str(rules(s).causes[str(grudge.cause)]), "pay": str(pay(s))}}
	return true

## What buying the grudge off costs: grows with the player's realm.
static func pay(s) -> int:
	return int(rules(s).pay) * (int(s.player.realm) + 1)

## The pending event's grudge, or {}.
static func pending(s) -> Dictionary:
	return find(s, str(s.pending_event.get("values", {}).get("grudge", "")))

static func fight(s) -> void:
	var grudge := pending(s)
	if grudge.is_empty():
		return
	s.Combat.begin_battle(s, str(grudge.enemy), "event")
	s.battle.grudge = str(grudge.id)
	s.battle.title = str(grudge.name)

## Paid off, or beaten in a fight, the grudge is laid to rest.
static func settle(s, grudge_id: String) -> void:
	s.world.grudges = s.world.get("grudges", []).filter(func(grudge: Dictionary) -> bool: return str(grudge.id) != grudge_id)

static func pay_off(s) -> void:
	var grudge := pending(s)
	if grudge.is_empty():
		return
	s.player.stones = maxi(0, int(s.player.stones) - pay(s))
	settle(s, str(grudge.id))

## Slipped away: the avenger will look again later.
static func evade(s) -> void:
	var grudge := pending(s)
	if not grudge.is_empty():
		grudge.since = int(s.world.day)

## A grudge fight is over (combat.gd): won or lost, the account is settled.
static func fight_over(s, grudge_id: String, won: bool) -> String:
	var grudge := find(s, grudge_id)
	if grudge.is_empty():
		return ""
	settle(s, grudge_id)
	return s.log_event("grudge_won" if won else "grudge_lost", {"foe": str(grudge.name)})

# --- 悬赏 ---------------------------------------------------------------------------------------------

## Stopping where an accepted outlaw hides finds them (once in a while if the player held back).
static func check_bounties(s) -> void:
	if not s.pending_event.is_empty() or not s.battle.is_empty():
		return
	for quest: Dictionary in s.player.get("quests", []):
		if not quest.has("wanted") or int(quest.progress) >= 1:
			continue
		var wanted: Dictionary = quest.wanted
		if str(wanted.place) != str(s.player.location) or int(s.world.day) < int(wanted.get("wait_until", 0)):
			continue
		var event_id := "bounty_twist" if bool(wanted.twist) else "bounty_found"
		s.pending_event = {"id": event_id, "day": int(s.world.day), "values": {"quest": str(quest.key), "foe": str(wanted.name), "board_name": str(s.content.commission_data.boards[quest.board].name)}}
		return

static func _pending_quest(s) -> Dictionary:
	var key := str(s.pending_event.get("values", {}).get("quest", ""))
	for quest: Dictionary in s.player.get("quests", []):
		if str(quest.key) == key:
			return quest
	return {}

static func bounty_fight(s) -> void:
	var quest := _pending_quest(s)
	if quest.is_empty():
		return
	s.Combat.begin_battle(s, str(quest.wanted.enemy), "event")
	s.battle.wanted = str(quest.key)
	s.battle.title = str(quest.wanted.name)

## Held back: the outlaw is still there in a while.
static func bounty_wait(s) -> void:
	var quest := _pending_quest(s)
	if not quest.is_empty():
		quest.wanted["wait_until"] = int(s.world.day) + int(rules(s).bounty_wait_days)

## Let go (the framed one): the commission is dropped.
static func bounty_drop(s) -> void:
	var quest := _pending_quest(s)
	if not quest.is_empty():
		s.player.quests.erase(quest)

## The outlaw is beaten (combat.gd): the commission waits to be handed in.
static func caught(s, quest_key: String) -> String:
	for quest: Dictionary in s.player.get("quests", []):
		if str(quest.key) == quest_key:
			quest.progress = 1
			return s.log_event("bounty_caught", {"foe": str(quest.wanted.name), "board_name": str(s.content.commission_data.boards[quest.board].name)})
	return ""
