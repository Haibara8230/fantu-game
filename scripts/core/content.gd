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
var people: Dictionary = {}
var items: Dictionary = {}
var events: Dictionary = {}
var chronicle: Dictionary = {}
var error_message: String = ""

func load_data() -> bool:
	var parsed: Variant = _read_json("res://data/world.json")
	if not parsed is Dictionary:
		error_message = "世界配置格式错误。"
		return false
	for section: String in ["locations", "skills", "enemies", "rules", "sects", "actions", "people", "items"]:
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
	var event_data: Variant = _read_json("res://data/events.json")
	if not event_data is Dictionary:
		error_message = "事件配置格式错误。"
		return false
	events = event_data
	locations = parsed.locations
	skills = parsed.skills
	enemies = parsed.enemies
	rules = parsed.rules
	sects = parsed.sects
	realms = parsed.realms
	routes = parsed.routes
	actions = parsed.actions
	world_flags = parsed.world_flags
	people = parsed.people
	items = parsed.items
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
	for rule: String in ["cultivate_options", "wait_options"]:
		if not rules.get(rule) is Array or rules[rule].is_empty():
			return "规则缺少：" + rule
		for days: Variant in rules[rule]:
			if not _whole(days) or int(days) < 1 or int(days) > 3600:
				return "规则天数错误：" + rule
	for event_id: String in events:
		var problem := _validate_event(event_id, events[event_id])
		if not problem.is_empty():
			return "事件 %s：%s" % [event_id, problem]
	return ""

# --- Event static checks -----------------------------------------------------

func _validate_event(event_id: String, definition: Variant) -> String:
	if not definition is Dictionary:
		return "定义必须是对象"
	if not definition.get("title") is String or definition.title.is_empty():
		return "缺少标题"
	var trigger: Variant = definition.get("trigger")
	if trigger == "location":
		if not locations.has(definition.get("location", "")):
			return "未知地点"
	elif trigger == "date":
		if not definition.has("window") and not definition.has("periodic"):
			return "日期事件必须有时间窗口或周期"
		if definition.has("choices") or definition.has("repeat"):
			return "日期事件不能带选项或冷却"
	else:
		return "未知触发方式"
	if definition.has("priority") and not _whole(definition.priority):
		return "优先级必须是非负整数"
	var timing := 0
	for key: String in ["window", "periodic", "repeat"]:
		if definition.has(key):
			timing += 1
	if timing > 1:
		return "时间窗口、周期与冷却只能选一种"
	if definition.has("window"):
		var window: Variant = definition.window
		if not window is Dictionary or not _valid_date(window.get("from")) or not _valid_date(window.get("to")):
			return "时间窗口日期无效"
		if _date_day(window.from) > _date_day(window.to):
			return "时间窗口起止颠倒"
	if definition.has("periodic"):
		var periodic: Variant = definition.periodic
		if not periodic is Dictionary:
			return "周期配置无效"
		for key: String in ["start_year", "every_years", "month", "from_day", "to_day"]:
			if not _whole(periodic.get(key)) or int(periodic[key]) < 1:
				return "周期字段无效：" + key
		if int(periodic.month) > 12 or int(periodic.to_day) > 30 or int(periodic.from_day) > int(periodic.to_day):
			return "周期日期无效"
	if definition.has("repeat"):
		if not definition.repeat is Dictionary or not _whole(definition.repeat.get("cooldown_days")) or int(definition.repeat.cooldown_days) < 1:
			return "冷却天数无效"
	var problem := _validate_conditions(definition.get("conditions", []))
	if problem.is_empty():
		problem = _validate_effects(definition.get("effects", []))
	if not problem.is_empty():
		return problem
	if definition.has("choices"):
		if not definition.get("text") is String or not definition.choices is Array or definition.choices.is_empty():
			return "抉择事件需要正文与选项"
		var ids := {}
		var always_open := false
		for choice: Variant in definition.choices:
			if not choice is Dictionary or not choice.get("id") is String or ids.has(choice.id):
				return "选项缺少唯一 ID"
			ids[choice.id] = true
			if not choice.get("label") is String or not choice.get("chronicle") is String:
				return "选项 %s 缺少文字" % choice.id
			problem = _validate_conditions(choice.get("conditions", []))
			if problem.is_empty():
				problem = _validate_effects(choice.get("effects", []))
			if not problem.is_empty():
				return "选项 %s：%s" % [choice.id, problem]
			if choice.get("conditions", []).is_empty():
				always_open = true
		# Otherwise the player could be stuck in front of an event with no allowed choice.
		if not always_open:
			return "至少需要一个无条件选项"
	elif not definition.get("chronicle") is String:
		return "缺少编年史文字"
	for part: String in ["remind", "expire"]:
		if not definition.has(part):
			continue
		if trigger != "location" or not definition.has("window"):
			return "%s 只用于有固定窗口的地点事件" % part
		if not definition[part] is Dictionary or not definition[part].get("chronicle") is String:
			return "%s 缺少文字" % part
		problem = _validate_conditions(definition[part].get("conditions", []))
		if not problem.is_empty():
			return problem
	# Key events gate important resources and must offer more than one way in.
	if definition.get("key", false) and _alternatives(definition.get("conditions", [])) < 2:
		return "关键事件至少需要两条入场途径"
	return ""

func _alternatives(conditions: Array) -> int:
	var best := 1 if not conditions.is_empty() else 0
	for condition: Dictionary in conditions:
		if condition.has("any"):
			best = maxi(best, condition.any.size())
	return best

func _validate_conditions(conditions: Variant) -> String:
	if not conditions is Array:
		return "条件必须是数组"
	for condition: Variant in conditions:
		var problem := _validate_condition(condition)
		if not problem.is_empty():
			return problem
	return ""

func _validate_condition(condition: Variant) -> String:
	if not condition is Dictionary or condition.size() != 1:
		return "每个条件只能有一个键"
	var key: String = condition.keys()[0]
	var value: Variant = condition[key]
	match key:
		"all", "any":
			if not value is Array or value.is_empty():
				return "%s 需要非空数组" % key
			return _validate_conditions(value)
		"not":
			return _validate_condition(value)
		"realm_at_least":
			return "" if _whole(value) and int(value) < realms.size() else "境界条件超出已开放境界"
		"flag":
			return "" if value in world_flags else "未知世界标记：%s" % value
		"item_at_least":
			return "" if value is Array and value.size() == 2 and items.has(value[0]) and _whole(value[1]) else "物品条件无效"
		"stones_at_least", "herbs_at_least":
			return "" if _whole(value) else "%s 数值无效" % key
		"met":
			return "" if people.has(value) else "未知人物：%s" % value
		"relation_at_least":
			return "" if value is Array and value.size() == 2 and people.has(value[0]) and (value[1] is int or value[1] is float) else "关系条件无效"
		"event_state":
			if not value is Array or value.size() != 2 or not events.has(value[0]) or not value[1] in ["completed", "expired"]:
				return "事件状态条件无效"
			return ""
	return "未知条件：%s" % key

func _validate_effects(effects: Variant) -> String:
	if not effects is Array:
		return "效果必须是数组"
	for effect: Variant in effects:
		if not effect is Dictionary or effect.size() != 1:
			return "每个效果只能有一个键"
		var key: String = effect.keys()[0]
		var value: Variant = effect[key]
		var ok := false
		match key:
			"stones", "herbs", "pills", "xp":
				ok = (value is int or value is float) and float(value) == floor(float(value))
			"item":
				ok = value is Array and value.size() == 2 and items.has(value[0]) and (value[1] is int or value[1] is float)
			"take_item":
				ok = items.has(value)
			"flag":
				ok = value in world_flags
			"meet":
				ok = people.has(value)
			"relation":
				ok = value is Array and value.size() == 2 and people.has(value[0]) and (value[1] is int or value[1] is float)
		if not ok:
			return "效果无效：%s" % key
	return ""

func _valid_date(value: Variant) -> bool:
	if not value is Array or value.size() != 3:
		return false
	for part: Variant in value:
		if not _whole(part) or int(part) < 1:
			return false
	return int(value[1]) <= 12 and int(value[2]) <= 30

func _date_day(value: Array) -> int:
	return (int(value[0]) - 1) * 360 + (int(value[1]) - 1) * 30 + int(value[2]) - 1

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
