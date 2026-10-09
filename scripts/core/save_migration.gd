extends RefCounted
## Upgrades saved sessions one version at a time. Output still goes through Session validation.
const CURRENT_VERSION := 2
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
