extends RefCounted
## Data definitions are separate from gameplay and presentation.
var locations: Dictionary = {}
var skills: Dictionary = {}
var enemies: Dictionary = {}
var rules: Dictionary = {}
var sects: Dictionary = {}
var error_message: String = ""

func load_data() -> bool:
	var file := FileAccess.open("res://data/world.json", FileAccess.READ)
	if file == null:
		error_message = "无法打开世界配置。"
		return false
	var parsed: Variant = JSON.parse_string(file.get_as_text())
	if not parsed is Dictionary:
		error_message = "世界配置格式错误。"
		return false
	for section: String in ["locations", "skills", "enemies", "rules", "sects"]:
		if not parsed.get(section) is Dictionary or parsed[section].is_empty():
			error_message = "世界配置缺少：" + section
			return false
	locations = parsed.locations
	skills = parsed.skills
	enemies = parsed.enemies
	rules = parsed.rules
	sects = parsed.sects
	for sect_id: String in sects:
		var definition: Dictionary = sects[sect_id]
		if not definition.get("skills") is Array or definition.skills.size() != 3:
			error_message = "门派神通配置错误：" + sect_id
			return false
		for skill_id: Variant in definition.skills:
			if not skill_id is String or not skills.has(skill_id):
				error_message = "门派引用了未知神通：" + sect_id
				return false
	return true
