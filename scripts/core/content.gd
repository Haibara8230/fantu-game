extends RefCounted
## Data definitions are separate from gameplay and presentation.
var locations: Dictionary = {}
var skills: Dictionary = {}
var enemies: Dictionary = {}
var rules: Dictionary = {}
var sects: Dictionary = {}
var realms: Array = []
var routes: Array = []
var actions: Dictionary = {}
var world_flags: Array = []
var chronicle: Dictionary = {}
var error_message: String = ""

func load_data() -> bool:
	var parsed: Variant = _read_json("res://data/world.json")
	if not parsed is Dictionary:
		error_message = "世界配置格式错误。"
		return false
	for section: String in ["locations", "skills", "enemies", "rules", "sects", "actions"]:
		if not parsed.get(section) is Dictionary or parsed[section].is_empty():
			error_message = "世界配置缺少：" + section
			return false
	for section: String in ["realms", "routes", "world_flags"]:
		if not parsed.get(section) is Array or parsed[section].is_empty():
			error_message = "世界配置缺少：" + section
			return false
	var templates: Variant = _read_json("res://data/chronicle.json")
	if not templates is Dictionary or templates.is_empty():
		error_message = "编年史文本配置错误。"
		return false
	locations = parsed.locations
	skills = parsed.skills
	enemies = parsed.enemies
	rules = parsed.rules
	sects = parsed.sects
	realms = parsed.realms
	routes = parsed.routes
	actions = parsed.actions
	world_flags = parsed.world_flags
	chronicle = templates
	error_message = _validate()
	return error_message.is_empty()

func _read_json(path: String) -> Variant:
	var file := FileAccess.open(path, FileAccess.READ)
	if file == null:
		return null
	return JSON.parse_string(file.get_as_text())

func _validate() -> String:
	for sect_id: String in sects:
		var definition: Dictionary = sects[sect_id]
		if not definition.get("skills") is Array or definition.skills.size() != 3:
			return "门派神通配置错误：" + sect_id
		for skill_id: Variant in definition.skills:
			if not skill_id is String or not skills.has(skill_id):
				return "门派引用了未知神通：" + sect_id
	for index: int in realms.size():
		var realm: Variant = realms[index]
		if not realm is Dictionary:
			return "境界配置错误：%d" % index
		for key: String in ["max_hp", "max_qi", "attack_bonus", "lifespan_years"]:
			if not _whole(realm.get(key)) or int(realm[key]) < (1 if key != "attack_bonus" else 0):
				return "境界数值错误：%s.%s" % [realm.get("id", index), key]
		var breakthrough: Variant = realm.get("breakthrough")
		if breakthrough != null and (not breakthrough is Dictionary or not _whole(breakthrough.get("xp")) or not _whole(breakthrough.get("pills"))):
			return "突破条件错误：%s" % realm.get("id", index)
	for route: Variant in routes:
		if not route is Dictionary or not route.get("between") is Array or route.between.size() != 2:
			return "路线配置错误。"
		for location_id: Variant in route.between:
			if not locations.has(location_id):
				return "路线引用了未知地点：%s" % location_id
		if not _whole(route.get("days")) or int(route.days) < 1:
			return "路线天数错误。"
	for action_id: String in actions:
		if not _whole(actions[action_id]):
			return "行为耗时错误：" + action_id
	for enemy_id: String in enemies:
		var enemy: Dictionary = enemies[enemy_id]
		if not enemy.get("locations") is Array or enemy.locations.is_empty():
			return "敌人缺少出没地点：" + enemy_id
		for location_id: Variant in enemy.locations:
			if not locations.has(location_id):
				return "敌人引用了未知地点：" + enemy_id
		if not _whole(enemy.get("min_realm")) or int(enemy.min_realm) >= realms.size():
			return "敌人境界要求错误：" + enemy_id
		if enemy.has("world_flag") and (not enemy.world_flag in world_flags or not chronicle.has(enemy.get("flag_event", ""))):
			return "敌人引用了未知世界标记：" + enemy_id
	return ""

func _whole(value: Variant) -> bool:
	return (value is int or value is float) and is_finite(float(value)) and float(value) >= 0.0 and float(value) == floor(float(value))

func realm(index: int) -> Dictionary:
	return realms[clampi(index, 0, realms.size() - 1)]

func action_days(action_id: String) -> int:
	return int(actions.get(action_id, 0))

## Direct route length in days, or -1 when the two places are not connected.
func route_days(from_id: String, to_id: String) -> int:
	for route: Dictionary in routes:
		if from_id in route.between and to_id in route.between and from_id != to_id:
			return int(route.days)
	return -1
