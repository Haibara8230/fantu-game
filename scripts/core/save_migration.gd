extends RefCounted
## Upgrades saved sessions one version at a time. Output still goes through Session validation.
const CURRENT_VERSION := 6
const DAYS_PER_MONTH := 30
const DAYS_PER_YEAR := 360
# Version 1 had no ages; every journey began at sixteen on day 0.
const V1_STARTING_AGE := 16
const V1_MAJOR_MARKERS := ["你拜入青云山", "开始研习", "丹田化海", "灵泉重现"]

## Returns a current-version copy, or an empty Dictionary when the data cannot be upgraded.
static func migrate(data: Dictionary) -> Dictionary:
	var version: Variant = data.get("version")
	if not (version is int or version is float) or not is_finite(float(version)) or float(version) != floor(float(version)):
		return {}
	if int(version) < 1 or int(version) > CURRENT_VERSION:
		return {}
	var result: Dictionary = data.duplicate(true)
	if int(version) == 1:
		result = _v1_to_v2(result)
	if not result.is_empty() and int(result.version) == 2:
		result = _v2_to_v3(result)
	if not result.is_empty() and int(result.version) == 3:
		result = _v3_to_v4(result)
	if not result.is_empty() and int(result.version) == 4:
		result = _v4_to_v5(result)
	if not result.is_empty() and int(result.version) == 5:
		result = _v5_to_v6(result)
	return result

static func _v1_to_v2(data: Dictionary) -> Dictionary:
	var player: Variant = data.get("player")
	var battle: Variant = data.get("battle")
	var journal: Variant = data.get("journal")
	var month: Variant = player.get("month") if player is Dictionary else null
	if not player is Dictionary or not battle is Dictionary or not journal is Array:
		return {}
	if not (month is int or month is float) or not is_finite(float(month)) or float(month) < 0 or float(month) != floor(float(month)) or float(month) > 30000000.0:
		return {}
	if not player.get("completed") is bool or not data.get("rng_state") is String:
		return {}
	var day := int(month) * DAYS_PER_MONTH
	var flags := {}
	if player.completed:
		flags["serpent_slain"] = true
	player.erase("month")
	player.erase("completed")
	player.erase("max_hp")
	player.erase("max_qi")
	player["birth_day"] = -V1_STARTING_AGE * DAYS_PER_YEAR
	if not player.has("sect"):
		player["sect"] = "wanderer"
	if not battle.is_empty() and not battle.has("opponent_sect"):
		battle["opponent_sect"] = "qingyun"
	var chronicle: Array = []
	var stamp := RegEx.create_from_string("^【(\\d+)年(\\d+)月】(.*)$")
	for line: Variant in journal:
		if not line is String:
			return {}
		var entry_day := day
		var text: String = line
		var found := stamp.search(line)
		if found:
			var year := int(found.get_string(1))
			var month_of_year := int(found.get_string(2))
			if year >= 1 and month_of_year >= 1 and month_of_year <= 12:
				entry_day = mini(day, (year - 1) * DAYS_PER_YEAR + (month_of_year - 1) * DAYS_PER_MONTH)
			text = found.get_string(3)
		var major := false
		for marker: String in V1_MAJOR_MARKERS:
			if text.contains(marker):
				major = true
		chronicle.append({"day": entry_day, "id": "legacy", "args": {"text": text.left(1000)}, "major": major})
	var combat_state: String = data.rng_state
	return {
		"version": 2,
		"world": {"day": day, "flags": flags},
		"player": player,
		"battle": battle,
		"chronicle": chronicle,
		# The world stream did not exist in version 1; derive it so it differs from combat.
		"rng": {"combat": combat_state, "world": str(hash(combat_state + ":world"))},
	}

## Version 3 adds event progress, people, items, per-day cultivation and the pending/ended states.
static func _v2_to_v3(data: Dictionary) -> Dictionary:
	var world: Variant = data.get("world")
	var player: Variant = data.get("player")
	if not world is Dictionary or not player is Dictionary:
		return {}
	world["events"] = {}
	world["people"] = {}
	player["items"] = {}
	player["cultivation_carry"] = 0
	player["warned_for"] = -1
	data["pending_event"] = {}
	data["ended"] = {}
	data["version"] = 3
	return data

## Version 4 adds multi-leg journeys and per-action cooldowns. Location ids are unchanged.
static func _v3_to_v4(data: Dictionary) -> Dictionary:
	var player: Variant = data.get("player")
	if not player is Dictionary:
		return {}
	player["journey"] = {}
	player["cooldowns"] = {}
	data["version"] = 4
	return data

# Choice pop-ups that became people one can visit (v5). Pending ones are dropped: the person is
# simply where they live or wander, and can be approached there.
const V4_RETIRED_EVENTS := ["shen_request", "teahouse_story", "ruin_occupied", "road_rogue", "road_peddler", "road_wounded"]

## Version 5 turns relations into favor (0–200 scale), adds per-person state and retires forced
## NPC pop-ups in favour of people the player can look up and approach.
static func _v4_to_v5(data: Dictionary) -> Dictionary:
	var world: Variant = data.get("world")
	var pending: Variant = data.get("pending_event")
	if not world is Dictionary or not world.get("people") is Dictionary or not pending is Dictionary:
		return {}
	for person_id: Variant in world.people:
		var person: Variant = world.people[person_id]
		if not person is Dictionary or not (person.get("relation") is int or person.get("relation") is float):
			return {}
		person["relation"] = clampi(int(person.relation) * 20, -200, 200)
		person["last"] = {}
		person["absent_until"] = -1
		person["talks"] = 0
	if pending.get("id", "") in V4_RETIRED_EVENTS:
		data["pending_event"] = {}
	data["version"] = 5
	return data

# Earlier journeys had no spirit roots; their pace matched an ordinary three-element root.
const V5_DEFAULT_ROOTS := ["metal", "wood", "fire"]

## Version 6 adds spirit roots and sub-stages (the stage itself is recomputed from xp on restore).
static func _v5_to_v6(data: Dictionary) -> Dictionary:
	var player: Variant = data.get("player")
	if not player is Dictionary:
		return {}
	player["roots"] = V5_DEFAULT_ROOTS.duplicate()
	player["stage"] = 0
	data["version"] = 6
	return data
