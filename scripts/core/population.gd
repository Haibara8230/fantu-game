extends RefCounted
## The region's generated population. Each person "g:<index>" is a pure function of the world seed and
## the index, so profiles never need saving; only what happens between them and the player is stored
## (world.people). Loadouts come from the same generators as the player's techniques and equipment.
const Arsenal = preload("res://scripts/core/arsenal.gd")
const ATTACK_ARCHETYPES := ["bolt", "barrage", "burst"]

static func generate(content, world_seed: int) -> Dictionary:
	var data: Dictionary = content.population_data
	var people := {}
	var names := {}
	for index: int in int(data.count):
		var person := _person(content, data, world_seed, index, names)
		names[person.name] = true
		people["g:%d" % index] = person
	return people

static func _person(content, data: Dictionary, world_seed: int, index: int, taken: Dictionary) -> Dictionary:
	var rng := RandomNumberGenerator.new()
	rng.seed = hash([world_seed, "person", index])
	var kind_id: String = _weighted(rng, data.kinds)
	var kind: Dictionary = data.kinds[kind_id]
	var personalities: Array = data.personalities.keys()
	personalities.sort()
	var personality: String = personalities[rng.randi_range(0, personalities.size() - 1)]
	var gender: String = "female" if rng.randf() < 0.5 else "male"
	var name := ""
	for attempt: int in range(20):
		name = _name(rng, data)
		if not taken.has(name):
			break
	var level: Dictionary = data.realms[_weighted_index(rng, data.realms)]
	var realm := int(level.realm)
	var stage := int(level.stage)
	var tier_low := int(level.tiers[0])
	var tier_high := int(level.tiers[1])
	var arts: Array = [Arsenal.generate_technique(content, rng, rng.randi_range(tier_low, tier_high), {"archetype": ATTACK_ARCHETYPES[rng.randi_range(0, ATTACK_ARCHETYPES.size() - 1)]})]
	while arts.size() < 4:
		var art := Arsenal.generate_technique(content, rng, rng.randi_range(tier_low, tier_high), {"slot": "art"})
		if not art in arts:
			arts.append(art)
	var methods: Array = []
	while methods.size() < 2:
		var method := Arsenal.generate_technique(content, rng, rng.randi_range(tier_low, tier_high), {"slot": "method"})
		if not method in methods:
			methods.append(method)
	var equipment := {}
	for slot: String in content.equipment_data.slots:
		equipment[slot] = Arsenal.generate_equipment(content, rng, rng.randi_range(tier_low, tier_high), slot) if rng.randf() < 0.75 else ""
	var main_art: Dictionary = content.technique(arts[0])
	var realm_text: String = content.realm_title(realm, stage)
	var sect_id: String = kind.affiliation
	var person := {
		"name": name, "title": kind.title, "attitude": kind.attitude, "realm_text": realm_text,
		"affiliation": content.sects[sect_id].name, "sect": sect_id, "age": rng.randi_range(int(data.age[0]) + realm * 12, int(data.age[1])),
		"personality": personality, "generated": true, "realm": realm, "stage": stage, "gender": gender, "kind": kind_id,
		"description": "一名%s的%s，修为%s，惯用%s。" % [personality, kind.title, realm_text, main_art.name],
		"talk_favor": 2, "gift_favor": 3, "talk": data.personalities[personality].duplicate(),
		"loadout": {"arts": arts, "methods": methods, "equipment": equipment},
		"interactions": [{"id": "spar", "label": "切磋（点到为止）", "effects": [{"spar": true}], "cooldown_days": 30, "chronicle": "你与{npc_name}切磋了一场。"}],
	}
	if kind.has("home"):
		person.home = kind.home[rng.randi_range(0, kind.home.size() - 1)]
	else:
		var places: Array = kind.schedule.duplicate()
		var stops: Array = []
		for stop: int in rng.randi_range(2, mini(3, places.size())):
			stops.append({"location": places.pop_at(rng.randi_range(0, places.size() - 1)), "days": rng.randi_range(5, 20)})
		person.schedule = stops
		person.offset = rng.randi_range(0, 59)
	return person

static func _name(rng: RandomNumberGenerator, data: Dictionary) -> String:
	var surname: String = data.surnames[rng.randi_range(0, data.surnames.size() - 1)]
	var given: String = data.given[rng.randi_range(0, data.given.size() - 1)]
	if rng.randf() < 0.6:
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

static func _weighted_index(rng: RandomNumberGenerator, entries: Array) -> int:
	var total := 0
	for entry: Dictionary in entries:
		total += int(entry.weight)
	var roll := rng.randi_range(1, total)
	for index: int in entries.size():
		roll -= int(entries[index].weight)
		if roll <= 0:
			return index
	return 0

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
