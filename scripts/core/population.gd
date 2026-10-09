extends RefCounted
## The world's generated population. The world has a fixed number of seats; each seat holds a sequence
## of lives, one after another: a person appears as a young cultivator, cultivates at their own pace,
## may break through, and dies of age or misfortune; some time later a newcomer takes the seat.
## A life is "g:<seat>:<generation>". Everything is a pure function of the world seed, the seat and the
## generation, so nothing about these people is saved except what happens between them and the player.
## Only seats belonging to a built region (currently 青云山周边) ever place people on the map.
const Arsenal = preload("res://scripts/core/arsenal.gd")
const ATTACK_ARCHETYPES := ["bolt", "barrage", "burst"]
const DAYS_PER_YEAR := 360

static func region_of(content, world_seed: int, seat: int) -> String:
	var rng := RandomNumberGenerator.new()
	rng.seed = hash([world_seed, "seat", seat])
	var roll := rng.randf()
	for region: String in content.population_data.regions:
		roll -= float(content.population_data.regions[region])
		if roll < 0.0:
			return region
	return "elsewhere"

## The seats whose people live in or pass through built regions.
static func local_seats(content, world_seed: int) -> Array[int]:
	var seats: Array[int] = []
	for seat: int in int(content.population_data.world_total):
		if region_of(content, world_seed, seat) != "elsewhere":
			seats.append(seat)
	return seats

## The life after `previous` in a seat (or the first one when `previous` is empty).
static func next_life(content, world_seed: int, seat: int, previous: Dictionary) -> Dictionary:
	var data: Dictionary = content.population_data
	var life_rules: Dictionary = data.life
	var generation := 0 if previous.is_empty() else int(previous.generation) + 1
	var rng := RandomNumberGenerator.new()
	rng.seed = hash([world_seed, "life", seat, generation])
	var kind_id: String = _weighted(rng, data.kinds)
	var kind: Dictionary = data.kinds[kind_id]
	var personalities: Array = data.personalities.keys()
	personalities.sort()
	var speed := rng.randi_range(int(life_rules.speed[0]), int(life_rules.speed[1]))
	var breakthrough_xp := int(content.realm(0).breakthrough.xp)
	var foundation_age := -1
	if content.realms.size() > 1 and rng.randf() < float(life_rules.foundation_chance):
		foundation_age = int(life_rules.start_age[0]) + int(ceil(float(breakthrough_xp) / float(speed)))
	var max_realm := 1 if foundation_age > 0 else 0
	var lifespan := int(content.realm(max_realm).lifespan_years)
	var death_age := int(round(float(lifespan) * rng.randf_range(float(life_rules.lifespan_share[0]), float(life_rules.lifespan_share[1]))))
	if rng.randf() < float(life_rules.accident_chance):
		death_age = rng.randi_range(int(life_rules.start_age[1]) + 2, death_age)
	if foundation_age > 0 and death_age <= foundation_age:
		foundation_age = -1
	var start_age := rng.randi_range(int(life_rules.start_age[0]), int(life_rules.start_age[1]))
	var appear := 0
	var birth := 0
	if previous.is_empty():
		var age_now := rng.randi_range(start_age, death_age - 1)
		birth = -age_now * DAYS_PER_YEAR - rng.randi_range(0, DAYS_PER_YEAR - 1)
		appear = birth + start_age * DAYS_PER_YEAR
	else:
		appear = int(previous.death) + rng.randi_range(int(life_rules.successor_gap_days[0]), int(life_rules.successor_gap_days[1]))
		birth = appear - start_age * DAYS_PER_YEAR - rng.randi_range(0, DAYS_PER_YEAR - 1)
	var life := {
		"id": "g:%d:%d" % [seat, generation], "seat": seat, "generation": generation, "region": region_of(content, world_seed, seat),
		"kind": kind_id, "gender": "female" if rng.randf() < 0.5 else "male", "name": _name(rng, data),
		"personality": personalities[rng.randi_range(0, personalities.size() - 1)],
		"speed": speed, "foundation_age": foundation_age, "birth": birth, "appear": appear,
		"death": birth + death_age * DAYS_PER_YEAR + rng.randi_range(0, DAYS_PER_YEAR - 1),
	}
	if kind.has("home"):
		life.home = kind.home[rng.randi_range(0, kind.home.size() - 1)]
	else:
		var places: Array = kind.schedule.duplicate()
		var stops: Array = []
		for stop: int in rng.randi_range(2, mini(3, places.size())):
			stops.append({"location": places.pop_at(rng.randi_range(0, places.size() - 1)), "days": rng.randi_range(5, 20)})
		life.schedule = stops
		life.offset = rng.randi_range(0, 59)
		life.cycle = stops.reduce(func(total: int, stop: Dictionary) -> int: return total + int(stop.days), 0)
	return life

## Realm, stage and age of a life on `day`.
static func standing(content, life: Dictionary, day: int) -> Dictionary:
	var age := (day - int(life.birth)) / DAYS_PER_YEAR
	var years := maxi(0, age - int(content.population_data.life.start_age[0]))
	var realm := 0
	var xp := mini(years * int(life.speed), int(content.realm(0).breakthrough.xp) - 1)
	if int(life.foundation_age) > 0 and age >= int(life.foundation_age):
		realm = 1
		xp = (age - int(life.foundation_age)) * int(life.speed)
	return {"age": age, "realm": realm, "stage": content.stage_index(realm, xp)}

## The full profile of a life as seen on `day`, in the same shape as handwritten people.
static func view(content, world_seed: int, life: Dictionary, day: int, loadout: Dictionary = {}) -> Dictionary:
	var data: Dictionary = content.population_data
	var kind: Dictionary = data.kinds[life.kind]
	var now := standing(content, life, day)
	var realm_text: String = content.realm_title(int(now.realm), int(now.stage))
	if loadout.is_empty():
		loadout = loadout_for(content, world_seed, life, int(now.realm), int(now.stage))
	var person := {
		"name": life.name, "title": kind.title, "attitude": kind.attitude, "realm_text": realm_text,
		"affiliation": content.sects[kind.affiliation].name, "sect": kind.affiliation, "age": int(now.age),
		"personality": life.personality, "generated": true, "realm": int(now.realm), "stage": int(now.stage),
		"gender": life.gender, "kind": life.kind, "birth": life.birth, "appear": life.appear, "death": life.death,
		"description": "一名%s的%s，修为%s，惯用%s。" % [life.personality, kind.title, realm_text, content.technique(loadout.arts[0]).name],
		"talk_favor": 2, "gift_favor": 3, "talk": data.personalities[life.personality].duplicate(), "loadout": loadout,
		"interactions": [{"id": "spar", "label": "切磋（点到为止）", "effects": [{"spar": true}], "cooldown_days": 30, "chronicle": "你与{npc_name}切磋了一场。"}],
	}
	for key: String in ["home", "schedule", "offset"]:
		if life.has(key):
			person[key] = life[key]
	return person

## Techniques and equipment for a life at a given realm: renewed when they break through.
static func loadout_for(content, world_seed: int, life: Dictionary, realm: int, stage: int) -> Dictionary:
	var tiers: Array = content.population_data.loadout_tiers[mini(realm * 4 + stage, content.population_data.loadout_tiers.size() - 1)]
	var low := int(tiers[0])
	var high := int(tiers[1])
	var rng := RandomNumberGenerator.new()
	rng.seed = hash([world_seed, life.id, "loadout", realm])
	var arts: Array = [Arsenal.generate_technique(content, rng, rng.randi_range(low, high), {"archetype": ATTACK_ARCHETYPES[rng.randi_range(0, ATTACK_ARCHETYPES.size() - 1)]})]
	while arts.size() < 4:
		var art := Arsenal.generate_technique(content, rng, rng.randi_range(low, high), {"slot": "art"})
		if not art in arts:
			arts.append(art)
	var methods: Array = []
	while methods.size() < 2:
		var method := Arsenal.generate_technique(content, rng, rng.randi_range(low, high), {"slot": "method"})
		if not method in methods:
			methods.append(method)
	var equipment := {}
	for slot: String in content.equipment_data.slots:
		equipment[slot] = Arsenal.generate_equipment(content, rng, rng.randi_range(low, high), slot) if rng.randf() < 0.75 else ""
	return {"arts": arts, "methods": methods, "equipment": equipment}

## Where a life stands on `day` by home or schedule ("away" means outside the region), or "" when dead
## or not yet arrived.
static func location_on(life: Dictionary, day: int) -> String:
	if day < int(life.appear) or day >= int(life.death):
		return ""
	if life.has("home"):
		return life.home
	var cycle := int(life.cycle)
	var position := posmod(day + int(life.offset), cycle)
	for stop: Dictionary in life.schedule:
		position -= int(stop.days)
		if position < 0:
			return "" if stop.location == "away" else str(stop.location)
	return ""

## Whether a life is at `location` on any day from `first` to `last`, worked out stop by stop rather
## than day by day.
static func present_during(life: Dictionary, location: String, first: int, last: int) -> bool:
	first = maxi(first, int(life.appear))
	last = mini(last, int(life.death) - 1)
	if first > last:
		return false
	if life.has("home"):
		return life.home == location
	var cycle := int(life.cycle)
	if last - first + 1 >= cycle:
		return life.schedule.any(func(stop: Dictionary) -> bool: return stop.location == location)
	# Walk the schedule from the stop that contains `first` until past `last`.
	var position := posmod(first + int(life.offset), cycle)
	var index := 0
	var into := position
	while into >= int(life.schedule[index].days):
		into -= int(life.schedule[index].days)
		index += 1
	var day := first
	while day <= last:
		var stop: Dictionary = life.schedule[index]
		if stop.location == location:
			return true
		day += int(stop.days) - into
		into = 0
		index = (index + 1) % life.schedule.size()
	return false

static func _name(rng: RandomNumberGenerator, data: Dictionary) -> String:
	var surname: String = data.surnames[rng.randi_range(0, data.surnames.size() - 1)]
	var given: String = data.given[rng.randi_range(0, data.given.size() - 1)]
	if rng.randf() < 0.7:
		given += str(data.given[rng.randi_range(0, data.given.size() - 1)])
	return surname + given

static func _weighted(rng: RandomNumberGenerator, table: Dictionary) -> String:
	var keys: Array = table.keys()
	keys.sort()
	var total := 0
	for key: String in keys:
		total += int(table[key].weight)
	var roll := rng.randi_range(1, total)
	for key: String in keys:
		roll -= int(table[key].weight)
		if roll <= 0:
			return key
	return keys[0]

## Duel stats for sparring with a person: their stage's health and their strongest attack.
static func foe(content, person_id: String, person: Dictionary) -> Dictionary:
	var caps: Dictionary = content.stage(int(person.realm), int(person.stage))
	var best: Dictionary = {}
	for art_id: String in person.loadout.arts:
		var art: Dictionary = content.technique(art_id)
		if art.get("kind", "") == "attack" and (best.is_empty() or int(art.damage_max) > int(best.damage_max)):
			best = art
	var bonus := int(caps.attack_bonus)
	return {
		"name": person.name, "hp": int(caps.max_hp), "damage_min": int(round(float(best.damage_min) * 0.8)) + bonus,
		"damage_max": int(round(float(best.damage_max) * 0.8)) + bonus, "art": best.id, "art_name": best.name,
		"vfx": best.vfx, "tier": int(best.tier), "xp": 10 * (int(person.stage) + 1) + 30 * int(person.realm), "npc": person_id,
	}
