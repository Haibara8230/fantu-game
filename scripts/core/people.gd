extends RefCounted
## People. Operates on a Session; the population caches live on the Session and are not saved.
## Handwritten people live in content.people. Generated people are lives "g:<seat>:<generation>" computed
## by Population from the world seed; only seats of built regions are tracked here. A person's view (age,
## realm, loadout) is derived for the current day. Residents stay home, wanderers follow a schedule; the
## player only sees who is where they stop, and anyone seen becomes an acquaintance whose whereabouts can
## be looked up. Nothing about people stops a journey.
const Calendar = preload("res://scripts/core/calendar.gd")
const Events = preload("res://scripts/core/events.gd")
const Population = preload("res://scripts/core/population.gd")
const Talents = preload("res://scripts/core/talents.gd")
const Bonds = preload("res://scripts/core/bonds.gd")
const TALK_COOLDOWN_DAYS := 30
# How long someone stays away after leaving, when their data gives no time.
const LONG_ABSENCE_DAYS := 3600
const SHORT_STAY_DAYS := 700

## Resets the population caches for this world; chronicle names of generated people resolve via person().
static func populate(s) -> void:
	s._local_seats = Population.local_seats(s.content, int(s.world.get("seed", 0)))
	s._lives = {}
	s._life_ids = {}
	s._views = {}
	s._loadouts = {}
	s._people_at = {}
	s._index_cache.clear()
	s._writers = -1
	obituaries_changed(s)
	s.content.person_lookup = s.person

static func is_generated(s, person_id: String) -> bool:
	if not person_id.begins_with("g:"):
		return false
	if s._life_ids.has(person_id):
		return true
	var parts := person_id.split(":")
	return parts.size() == 3 and parts[0] == "g" and parts[1].is_valid_int() and parts[2].is_valid_int() and int(parts[1]) >= 0 and int(parts[2]) >= 0 and int(parts[1]) < int(s.content.population_data.world_total)

static func is_person(s, person_id: String) -> bool:
	return s.content.people.has(person_id) or is_generated(s, person_id)

## A seat's lives, extended until one is still alive after `day` or until `generation` exists.
static func seat_lives(s, seat: int, day: int = -1, generation: int = -1) -> Array:
	if not s._lives.has(seat):
		s._lives[seat] = [Population.next_life(s.content, int(s.world.seed), seat, {}, _shaped(s))]
	var lives: Array = s._lives[seat]
	while (day >= 0 and int(lives.back().death) <= day) or (generation >= 0 and lives.size() <= generation):
		lives.append(Population.next_life(s.content, int(s.world.seed), seat, lives.back(), _shaped(s)))
	return lives

## Whether talents shape the generated lives in this world (worlds begun with talents).
static func _shaped(s) -> bool:
	return bool(s.world.get("talent_lives", false))

## Someone's talents and flaws: generated people's from their life, handwritten people's as written
## (one list in the data, split here).
static func talents_of(s, person_id: String) -> Dictionary:
	var someone := person(s, person_id)
	if someone.get("generated", false):
		return {"talents": someone.get("talents", []), "flaws": someone.get("flaws", [])}
	var result := {"talents": [], "flaws": []}
	for id: String in someone.get("talents", []):
		result["flaws" if Talents.is_flaw(s.content, id) else "talents"].append(id)
	return result

## Someone's 资质: generated people's pace stands in for their roots; handwritten people may name theirs
## (`roots`, a count of spirit roots), else three.
static func aptitude_of(s, person_id: String) -> Dictionary:
	var someone := person(s, person_id)
	var owned := talents_of(s, person_id)
	var base := Talents.speed_score(s.content, int(someone.speed)) if someone.get("generated", false) else int(s.content.talent_data.root_scores.get(str(someone.get("roots", 3)), 5))
	return Talents.aptitude(s.content, Talents.score(s.content, base, owned.talents + owned.flaws))

static func life_by_id(s, person_id: String) -> Dictionary:
	if s._life_ids.has(person_id):
		return s._life_ids[person_id]
	if not is_generated(s, person_id):
		return {}
	var parts := person_id.split(":")
	var life: Dictionary = seat_lives(s, int(parts[1]), -1, int(parts[2]))[int(parts[2])]
	s._life_ids[person_id] = life
	return life

## The life holding a seat on `day`, or {} between lives.
static func life_at(s, seat: int, day: int) -> Dictionary:
	for life: Dictionary in seat_lives(s, seat, day):
		if int(life.appear) <= day and day < int(life.death):
			return life
	return {}

## A person's profile today: handwritten as written, generated as derived for the current day.
static func person(s, person_id: String) -> Dictionary:
	if s.content.people.has(person_id):
		return s.content.people[person_id]
	if not is_generated(s, person_id):
		return {}
	var day := int(s.world.day)
	var cached: Dictionary = s._views.get(person_id, {})
	if int(cached.get("day", -1)) == day:
		return cached.view
	var life := life_by_id(s, person_id)
	var now: Dictionary = Population.standing(s.content, life, day)
	var key := "%s:%d" % [person_id, int(now.realm)]
	if not s._loadouts.has(key):
		s._loadouts[key] = Population.loadout_for(s.content, int(s.world.seed), life, int(now.realm), int(now.stage))
	var view: Dictionary = Population.view(s.content, int(s.world.seed), life, day, s._loadouts[key])
	s._views[person_id] = {"day": day, "view": view}
	return view

## Where a person is on a day (today by default), or "" when absent, dead, away or somewhere undiscovered.
static func npc_location(s, person_id: String, on_day: int = -1) -> String:
	var day := int(s.world.day) if on_day < 0 else on_day
	if int(s.world.people.get(person_id, {}).get("absent_until", -1)) > day:
		return ""
	if is_generated(s, person_id):
		var place := _detoured(s, Population.location_on(life_by_id(s, person_id), day))
		return place if not place.is_empty() and s.location_visible(place) else ""
	var someone: Dictionary = s.content.people[person_id]
	if someone.has("window"):
		var from: Array = someone.window.from
		var to: Array = someone.window.to
		if day < Calendar.to_day(from[0], from[1], from[2]) or day > Calendar.to_day(to[0], to[1], to[2]):
			return ""
	if not Events.all_met(s, someone.get("present_if", [])):
		return ""
	var location: String = s.content.person_base_location(person_id, day)
	return location if s.location_visible(location) else ""

## Where someone goes instead while their place is sealed (落霞谷 during the serpent's rampage): the
## place's `detour`, else the place itself.
static func _detoured(s, place: String) -> String:
	if place.is_empty() or not s.content.location_sealed(place, s.world.flags):
		return place
	return str(s.content.locations[place].get("detour", place))

## Who can be where today; see _people_on.
static func _refresh_people_index(s) -> void:
	s._people_at = _people_on(s, int(s.world.day))

## Who can be where on a day: handwritten people by home and schedule, generated people by the life
## holding each seat. Each index stays valid until a life in the region ends or begins; the two most
## recent are kept.
static func _people_on(s, day: int) -> Dictionary:
	for cached: Dictionary in s._index_cache:
		if day >= int(cached.from) and day < int(cached.until):
			return cached.map
	var built := _build_people_index(s, day)
	s._index_cache.push_front(built)
	if s._index_cache.size() > 2:
		s._index_cache.pop_back()
	return built.map

static func _build_people_index(s, day: int) -> Dictionary:
	var map := {}
	var until := 2147483647
	for person_id: String in s.content.people:
		var someone: Dictionary = s.content.people[person_id]
		for place: String in ([someone.home] if someone.has("home") else someone.schedule.map(func(stop: Dictionary) -> String: return stop.location)):
			_index_add(map, place, person_id)
	for seat: int in s._local_seats:
		var lives := seat_lives(s, seat, day)
		var current := life_at(s, seat, day)
		if current.is_empty():
			until = mini(until, int(lives.back().appear))
			continue
		until = mini(until, int(current.death))
		for place: String in ([current.home] if current.has("home") else current.schedule.map(func(stop: Dictionary) -> String: return stop.location)):
			if place != "away":
				_index_add(map, place, current.id)
				# They may turn aside to the detour while their place is sealed.
				var detour := str(s.content.locations.get(place, {}).get("detour", ""))
				if not detour.is_empty():
					_index_add(map, detour, current.id)
	return {"from": day, "until": until, "map": map}

static func _index_add(map: Dictionary, place: String, person_id: String) -> void:
	if not map.has(place):
		map[place] = []
	if not person_id in map[place]:
		map[place].append(person_id)

static func present_npcs(s) -> Array[String]:
	_refresh_people_index(s)
	var result: Array[String] = []
	for person_id: String in s._people_at.get(s.player.location, []):
		if npc_location(s, person_id) == s.player.location:
			result.append(person_id)
	return result

## Everyone alive in the built regions today (handwritten and generated).
static func living_people(s) -> Array[String]:
	var result: Array[String] = []
	for person_id: String in s.content.people:
		result.append(person_id)
	for seat: int in s._local_seats:
		var life := life_at(s, seat, int(s.world.day))
		if not life.is_empty():
			result.append(life.id)
	return result

## Staying somewhere for a span means meeting everyone who passes through during it, so one long stay
## meets the same people as many short ones.
static func meet_during(s, first_day: int, last_day: int) -> void:
	var here: String = s.player.location
	for person_id: String in s.content.people:
		var someone: Dictionary = s.content.people[person_id]
		var places: Array = [someone.home] if someone.has("home") else someone.schedule.map(func(stop: Dictionary) -> String: return stop.location)
		if not here in places or bool(s.world.people.get(person_id, {}).get("met", false)):
			continue
		for day: int in range(first_day, last_day + 1):
			if npc_location(s, person_id, day) == here:
				mark_met(s, person_id, day)
				break
	# Lives last at least two years, so a short stay only needs the people indexed at its start and end;
	# a long stay checks every seat.
	var lives: Array = []
	if last_day - first_day < SHORT_STAY_DAYS:
		var ids := {}
		var start_map := _people_on(s, first_day)
		var end_map := _people_on(s, last_day)
		for map: Dictionary in ([start_map] if start_map == end_map else [start_map, end_map]):
			for person_id: String in map.get(here, []):
				if is_generated(s, person_id) and not bool(s.world.people.get(person_id, {}).get("met", false)):
					ids[person_id] = true
		for person_id: String in ids:
			if not bool(s.world.people.get(person_id, {}).get("met", false)):
				lives.append(life_by_id(s, person_id))
	else:
		for seat: int in s._local_seats:
			lives.append_array(seat_lives(s, seat, last_day))
	for life: Dictionary in lives:
		if int(life.death) <= first_day or int(life.appear) > last_day or bool(s.world.people.get(life.id, {}).get("met", false)):
			continue
		var met := Population.first_present(life, here, first_day, last_day)
		if met >= 0:
			mark_met(s, life.id, met)
	s._met_through = {"location": here, "day": last_day}

static func known_npcs(s) -> Array[String]:
	var result: Array[String] = []
	for person_id: String in s.world.people:
		if is_person(s, person_id) and bool(s.world.people[person_id].get("met", false)):
			result.append(person_id)
	return result

static func meet_present(s) -> void:
	# Right after a stay, everyone generated who was here through today is already met: only the
	# handwritten people are left to look for (much cheaper than everyone's whereabouts).
	var covered: bool = s._met_through.get("location", "") == s.player.location and int(s._met_through.get("day", -1)) == int(s.world.day)
	if covered:
		for person_id: String in s.content.people:
			if npc_location(s, person_id) == s.player.location:
				mark_met(s, person_id)
		return
	for person_id: String in present_npcs(s):
		mark_met(s, person_id)

## Marks someone as met, here on `day` (today by default; a long stay passes the day within it).
## Meeting a generated person who has already died (heard of during a long stay) records them without
## an obituary; meeting a living one may schedule one later.
static func mark_met(s, person_id: String, day: int = -1) -> void:
	var progress := Events.person(s, person_id)
	if bool(progress.met):
		return
	progress.met = true
	progress.met_day = int(s.world.day) if day < 0 else mini(day, int(s.world.day))
	progress.met_place = str(s.player.location)
	if is_generated(s, person_id) and int(life_by_id(s, person_id).death) <= int(s.world.day):
		progress.mourned = true
	obituaries_changed(s)

static func obituaries_changed(s) -> void:
	s._obituary_cache = {"dirty": true}

## The next death among generated acquaintances not yet mourned: {"day", "id"}, or {}. Cached until
## someone is newly met or mourned.
static func next_obituary(s, from_day: int) -> Dictionary:
	if not bool(s._obituary_cache.get("dirty", true)):
		var cached: Dictionary = s._obituary_cache.result
		return {} if cached.is_empty() else {"day": maxi(from_day, int(cached.day)), "id": cached.id}
	var best := {}
	for person_id: String in s.world.people:
		var progress: Dictionary = s.world.people[person_id]
		if not is_generated(s, person_id) or not bool(progress.get("met", false)) or bool(progress.get("mourned", false)):
			continue
		var due := int(life_by_id(s, person_id).death)
		if best.is_empty() or due < int(best.day) or (due == int(best.day) and person_id < str(best.id)):
			best = {"day": due, "id": person_id}
	s._obituary_cache = {"dirty": false, "result": best}
	return {} if best.is_empty() else {"day": maxi(from_day, int(best.day)), "id": best.id}

static func favor(s, person_id: String) -> int:
	return int(s.world.people.get(person_id, {}).get("relation", 0))

## The person goes away for their leave time (paid off, defeated, healed and moving on).
static func npc_depart(s, person_id: String) -> void:
	if person_id.is_empty():
		return
	var days := int(person(s, person_id).get("leave_days", LONG_ABSENCE_DAYS))
	Events.person(s, person_id).absent_until = int(s.world.day) + days

## What an ordinary acquaintance needs this period, or {}: {"item", "count", "stones", "period"}. Now
## and then (rules.requests) someone the player knows is short of an herb or a pill; helping out earns
## favor, a little silver and some mind. Drawn from the world seed, the person and the period, so
## nothing needs saving but the day it was answered.
static func request_of(s, person_id: String) -> Dictionary:
	if not is_generated(s, person_id) or not bool(s.world.people.get(person_id, {}).get("met", false)):
		return {}
	if str(person(s, person_id).get("attitude", "")) == "hostile":
		return {}
	var rules: Dictionary = s.content.rules.requests
	var period := int(s.world.day) / int(rules.period_days)
	var rng := RandomNumberGenerator.new()
	rng.seed = hash([int(s.world.get("seed", 0)), "request", person_id, period])
	if rng.randf() >= float(rules.chance):
		return {}
	var item_id: String = rules.items[rng.randi_range(0, rules.items.size() - 1)]
	var count := rng.randi_range(int(rules.count[0]), int(rules.count[1]))
	var stones := int(round(float(s.content.item(item_id).price) * count * float(rules.reward_scale)))
	return {"item": item_id, "count": count, "stones": stones, "period": period}

## Whether an acquaintance's request is waiting for an answer.
static func request_open(s, person_id: String) -> bool:
	var request := request_of(s, person_id)
	if request.is_empty():
		return false
	var answered := int(s.world.people.get(person_id, {}).get("last", {}).get("help", -1))
	return answered < 0 or answered / int(s.content.rules.requests.period_days) != int(request.period)

## Everything the player could do with a person here: {"id", "label", "available", "reason"}.
static func npc_options(s, person_id: String) -> Array[Dictionary]:
	var options: Array[Dictionary] = []
	var someone: Dictionary = person(s, person_id)
	if someone.attitude != "hostile" and not someone.get("talk", []).is_empty():
		options.append({"id": "talk", "label": "交谈", "cooldown_days": TALK_COOLDOWN_DAYS})
	if someone.attitude != "hostile" and int(someone.get("gift_favor", 0)) > 0:
		options.append({"id": "gift", "label": "赠一株灵草（好感 +%d）" % int(someone.gift_favor), "conditions": [{"herbs_at_least": 1}], "cooldown_days": TALK_COOLDOWN_DAYS})
	if request_open(s, person_id):
		var request := request_of(s, person_id)
		options.append({"id": "help", "label": "相助：送上%s×%d（好感 +%d，酬谢 %d 灵石）" % [s.content.item(request.item).name, int(request.count), int(s.content.rules.requests.favor), int(request.stones)], "conditions": [{"item_at_least": [request.item, int(request.count)]}]})
	options.append_array(Bonds.options(s, person_id))
	for interaction: Dictionary in someone.get("interactions", []):
		options.append(interaction)
	var result: Array[Dictionary] = []
	var here: bool = npc_location(s, person_id) == str(s.player.get("location", ""))
	var last: Dictionary = s.world.people.get(person_id, {}).get("last", {})
	var blocked: String = s.blocked()
	for option: Dictionary in options:
		# Interactions repeat unless marked "once"; "cooldown_days" spaces repeats out.
		var reason := ""
		if not blocked.is_empty():
			reason = blocked
		elif not here:
			reason = "此人不在这里。"
		elif bool(option.get("once", false)) and last.has(option.id):
			reason = "此事已了。"
		elif last.has(option.id) and int(s.world.day) < int(last[option.id]) + int(option.get("cooldown_days", 0)):
			reason = "%s后再来。" % Calendar.duration_text(int(last[option.id]) + int(option.cooldown_days) - int(s.world.day))
		elif not Events.all_met(s, option.get("conditions", [])):
			reason = "条件不足。"
		elif _duels(option) and not forbidden(s, "duel").is_empty():
			reason = forbidden(s, "duel")
		else:
			reason = Bonds.option_block(s, person_id, str(option.id))
		result.append({"id": option.id, "label": option.label, "available": reason.is_empty(), "reason": reason})
	return result

## Whether an option comes to blows (a spar, a duel).
static func _duels(option: Dictionary) -> bool:
	return str(option.id) == "invite_spar" or option.get("effects", []).any(func(effect: Dictionary) -> bool: return effect.has("spar") or effect.has("battle"))

## The local rule against `what` where the player stands (data/world.json location `rules`), or "".
static func forbidden(s, what: String) -> String:
	for rule: Dictionary in s.content.locations.get(str(s.player.location), {}).get("rules", []):
		if rule.forbid == what:
			return str(rule.text)
	return ""

static func interact(s, person_id: String, option_id: String) -> String:
	if not is_person(s, person_id) or person(s, person_id).is_empty():
		return "未知人物。"
	var chosen: Dictionary = {}
	for option: Dictionary in npc_options(s, person_id):
		if option.id == option_id:
			chosen = option
	if chosen.is_empty():
		return "没有这个选项。"
	if not chosen.available:
		return chosen.reason
	var someone: Dictionary = person(s, person_id)
	mark_met(s, person_id)
	var progress := Events.person(s, person_id)
	progress.last[option_id] = int(s.world.day)
	if option_id in ["consult", "teach", "invite_spar", "invite_help", "companion", "disciple", "instruct", "sworn"]:
		return Bonds.interact(s, person_id, option_id)
	var text := ""
	match option_id:
		"talk":
			var lines: Array = someone.talk
			text = s.log_event("talk", {"npc": person_id, "line": int(progress.talks) % lines.size()})
			progress.talks = int(progress.talks) + 1
			Events.apply(s, [{"relation": [person_id, int(someone.get("talk_favor", 0))]}])
		"gift":
			Events.apply(s, [{"herbs": -1}, {"relation": [person_id, int(someone.gift_favor)]}])
			text = s.log_event("gift", {"npc": person_id, "favor": int(someone.gift_favor)})
		"help":
			var request := request_of(s, person_id)
			var rules: Dictionary = s.content.rules.requests
			s.Inventory.remove_family(s, request.item, int(request.count))
			s.player.stones += int(request.stones)
			Events.apply(s, [{"relation": [person_id, int(rules.favor)]}, {"mind": int(rules.mind)}])
			s.record_deed("help")
			text = s.log_event("help", {"npc": person_id, "loot": "%s:%d" % [request.item, int(request.count)], "favor": int(rules.favor), "stones": int(request.stones)})
		_:
			for interaction: Dictionary in someone.interactions:
				if interaction.id == option_id:
					s.acting_npc = person_id
					Events.apply(s, interaction.get("effects", []))
					s.acting_npc = ""
					if not s.battle.is_empty():
						s.battle.npc = person_id
			text = s.log_event("npc", {"npc": person_id, "interaction": option_id})
	return s.conclude(text)
