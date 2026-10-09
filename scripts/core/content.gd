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
var map: Dictionary = {}
var error_message: String = ""
const DANGER_LEVELS := 4
const FAVOR_MAX := 200
const FAVOR_STAGES := [[0, "初识"], [40, "相熟"], [80, "友好"], [140, "信赖"], [200, "亲密"]]
const ATTITUDES := {"friendly": "友善", "neutral": "中立", "hostile": "敌意"}
const BUILT_IN_INTERACTIONS := ["talk", "gift"]
const PLAIN_ACTIONS := ["cultivate", "rest", "breakthrough", "study", "sell", "shop", "gather", "inn_rest", "search_ruin"]
const ITEM_CATEGORIES := {"herb": "灵草", "pill": "丹药", "material": "材料", "quest": "信物"}

func load_data() -> bool:
	var parsed: Variant = _read_json("res://data/world.json")
	if not parsed is Dictionary:
		error_message = "世界配置格式错误。"
		return false
	for section: String in ["map", "locations", "skills", "enemies", "rules", "sects", "actions"]:
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
	var npc_data: Variant = _read_json("res://data/npcs.json")
	if not npc_data is Dictionary or npc_data.is_empty():
		error_message = "人物配置格式错误。"
		return false
	people = npc_data
	var item_data: Variant = _read_json("res://data/items.json")
	if not item_data is Dictionary or item_data.is_empty():
		error_message = "物品配置格式错误。"
		return false
	items = item_data
	map = parsed.map
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
		if not realm.get("name") is String or not _whole(realm.get("lifespan_years")) or int(realm.lifespan_years) < 1:
			return "境界名称或寿元错误：%s" % realm.get("id", index)
		if not realm.get("stages") is Array or realm.stages.is_empty():
			return "境界缺少小阶段：%s" % realm.get("id", index)
		var previous_xp := -1
		for stage: Variant in realm.stages:
			if not stage is Dictionary or not stage.get("name") is String:
				return "小阶段配置错误：%s" % realm.get("id", index)
			for key: String in ["xp", "max_hp", "max_qi", "attack_bonus"]:
				if not _whole(stage.get(key)) or (key in ["max_hp", "max_qi"] and int(stage[key]) < 1):
					return "小阶段数值错误：%s.%s.%s" % [realm.get("id", index), stage.name, key]
			if int(stage.xp) <= previous_xp:
				return "小阶段修为门槛必须递增：%s" % realm.get("id", index)
			previous_xp = int(stage.xp)
		if int(realm.stages[0].xp) != 0:
			return "第一个小阶段的门槛必须是 0：%s" % realm.get("id", index)
		var breakthrough: Variant = realm.get("breakthrough")
		if breakthrough != null and (not breakthrough is Dictionary or not _whole(breakthrough.get("xp")) or not _whole(breakthrough.get("pills"))):
			return "突破条件错误：%s" % realm.get("id", index)
		if breakthrough != null and int(breakthrough.xp) < int(realm.stages.back().xp):
			return "突破所需修为不能低于最后一个小阶段：%s" % realm.get("id", index)
	for route: Variant in routes:
		if not route is Dictionary or not route.get("between") is Array or route.between.size() != 2:
			return "路线配置错误。"
		for location_id: Variant in route.between:
			if not locations.has(location_id):
				return "路线引用了未知地点：%s" % location_id
		if route.between[0] == route.between[1]:
			return "路线两端相同：%s" % route.between[0]
		if not _whole(route.get("days")) or int(route.days) < 1:
			return "路线天数错误。"
		if not _whole(route.get("danger")) or int(route.danger) >= DANGER_LEVELS:
			return "路线危险度错误：%s" % "—".join(route.between)
	for action_id: String in actions:
		if not _whole(actions[action_id]):
			return "行为耗时错误：" + action_id
	for enemy_id: String in enemies:
		var enemy: Dictionary = enemies[enemy_id]
		if not _whole(enemy.get("min_realm")) or int(enemy.min_realm) >= realms.size():
			return "敌人境界要求错误：" + enemy_id
		if enemy.has("world_flag") and (not enemy.world_flag in world_flags or not chronicle.has(enemy.get("flag_event", ""))):
			return "敌人引用了未知世界标记：" + enemy_id
		if enemy.has("sect") and not sects.has(enemy.sect):
			return "敌人引用了未知门派：" + enemy_id
	var chance: Variant = rules.get("encounter_chance")
	if not chance is Array or chance.size() != DANGER_LEVELS:
		return "遭遇几率需要按危险度给出 %d 档。" % DANGER_LEVELS
	for value: Variant in chance:
		if not (value is int or value is float) or float(value) < 0.0 or float(value) > 1.0:
			return "遭遇几率必须在 0 到 1 之间。"
	var roots: Variant = rules.get("spirit_roots")
	if not roots is Dictionary or not roots.get("elements") is Array or not roots.get("names") is Dictionary or not roots.get("grades") is Array:
		return "灵根配置无效。"
	for element: Variant in roots.elements:
		if not roots.names.has(element):
			return "灵根缺少名称：%s" % element
	for grade: Variant in roots.grades:
		if not grade is Dictionary or not _whole(grade.get("count")) or int(grade.count) < 1 or int(grade.count) > roots.elements.size() or not _whole(grade.get("weight")) or not (grade.get("speed") is float or grade.get("speed") is int) or float(grade.speed) <= 0.0:
			return "灵根等级配置无效。"
	if not _whole(rules.get("rest_full_days")) or int(rules.rest_full_days) < 1:
		return "静养天数无效。"
	if not _whole(rules.get("inn_price")):
		return "客栈价格无效。"
	var search: Variant = rules.get("ruin_search")
	if not search is Dictionary or not search.get("stones") is Array or not search.get("herbs") is Array or not (search.get("pill_chance") is float or search.get("pill_chance") is int):
		return "洞府搜寻配置无效。"
	if not rules.get("action_cooldowns") is Dictionary:
		return "行为冷却配置无效。"
	for action_id: String in rules.action_cooldowns:
		if not action_id in PLAIN_ACTIONS or not _whole(rules.action_cooldowns[action_id]):
			return "行为冷却配置无效：" + action_id
	var problem := _validate_map()
	if not problem.is_empty():
		return problem
	for rule: String in ["cultivate_options", "wait_options"]:
		if not rules.get(rule) is Array or rules[rule].is_empty():
			return "规则缺少：" + rule
		for days: Variant in rules[rule]:
			if not _whole(days) or int(days) < 1 or int(days) > 3600:
				return "规则天数错误：" + rule
	for event_id: String in events:
		problem = _validate_event(event_id, events[event_id])
		if not problem.is_empty():
			return "事件 %s：%s" % [event_id, problem]
	for item_id: String in items:
		problem = _validate_item(items[item_id])
		if not problem.is_empty():
			return "物品 %s：%s" % [item_id, problem]
	for person_id: String in people:
		problem = _validate_person(people[person_id])
		if not problem.is_empty():
			return "人物 %s：%s" % [person_id, problem]
	return _validate_reveals()

# --- Map static checks --------------------------------------------------------

func _validate_map() -> String:
	if not locations.has(map.get("start", "")) or locations[map.start].has("hidden_until"):
		return "地图起点无效。"
	if not (map.get("aspect") is float or map.get("aspect") is int) or float(map.aspect) <= 0.0:
		return "地图比例无效。"
	for location_id: String in locations:
		var location: Dictionary = locations[location_id]
		var point: Variant = location.get("map")
		if not point is Array or point.size() != 2:
			return "地点缺少地图坐标：" + location_id
		for value: Variant in point:
			if not (value is float or value is int) or float(value) < 0.0 or float(value) > 1.0:
				return "地图坐标超出范围：" + location_id
		if not location.get("terrain") is String:
			return "地点缺少地貌：" + location_id
		if location.has("hidden_until") and not location.hidden_until in world_flags:
			return "隐藏地点引用了未知标记：" + location_id
		if location.has("gather"):
			var gather: Variant = location.gather
			if not gather is Dictionary or not gather.get("picks") is Array or gather.picks.size() != 2 or not _whole(gather.picks[0]) or not _whole(gather.picks[1]) or int(gather.picks[0]) < 1 or int(gather.picks[0]) > int(gather.picks[1]):
				return "采集次数错误：" + location_id
			if not gather.get("table") is Array or gather.table.is_empty():
				return "采集表为空：" + location_id
			for entry: Variant in gather.table:
				if not entry is Dictionary or not items.has(entry.get("item", "")) or not _whole(entry.get("weight")) or int(entry.weight) < 1:
					return "采集表条目错误：" + location_id
		for good: Variant in location.get("shop", []):
			if not good is Dictionary or not items.has(good.get("item", "")) or not _whole(good.get("price")) or int(good.price) < 1:
				return "商店货品错误：" + location_id
		for category: Variant in location.get("buys", []):
			if not ITEM_CATEGORIES.has(category):
				return "收购品类未知：" + location_id
		if not location.get("spots") is Array or location.spots.is_empty():
			return "地点缺少场景：" + location_id
		var ids := {}
		for spot: Variant in location.spots:
			if not spot is Dictionary or not spot.get("id") is String or ids.has(spot.id) or not spot.get("name") is String or not spot.get("actions") is Array:
				return "场景配置错误：" + location_id
			ids[spot.id] = true
			if spot.has("requires_flag") and not spot.requires_flag in world_flags:
				return "场景引用了未知标记：%s.%s" % [location_id, spot.id]
			for action: Variant in spot.actions:
				if not action is String:
					return "场景行为错误：%s.%s" % [location_id, spot.id]
				if action.begins_with("battle:"):
					if not enemies.has(action.trim_prefix("battle:")):
						return "场景引用了未知敌人：%s" % action
				elif not action in PLAIN_ACTIONS:
					return "场景引用了未知行为：%s" % action
				if action == "gather" and not location.has("gather"):
					return "可采集的地点缺少采集数量：" + location_id
				if action == "shop" and location.get("shop", []).is_empty():
					return "开店的地点没有货品：" + location_id
				if action == "sell" and location.get("buys", []).is_empty():
					return "收购的地点没有收购品类：" + location_id
	# Every location must be reachable once everything is revealed; unhidden ones without any reveal.
	var everything := {}
	for flag: String in world_flags:
		everything[flag] = true
	for location_id: String in locations:
		if find_path(map.start, location_id, everything).is_empty():
			return "地点无法到达：" + location_id
		if not location_visible(location_id, {}):
			continue
		if find_path(map.start, location_id, {}).is_empty():
			return "未解锁隐藏地点前无法到达：" + location_id
	return ""

## Hidden locations and gated spots need something in the content that sets their flag.
func _validate_reveals() -> String:
	var settable := {}
	for enemy: Dictionary in enemies.values():
		if enemy.has("world_flag"):
			settable[enemy.world_flag] = true
	var sources: Array = events.values() + people.values()
	for definition: Dictionary in sources:
		var effects: Array = definition.get("effects", []).duplicate()
		for choice: Dictionary in definition.get("choices", []) + definition.get("interactions", []):
			effects.append_array(choice.get("effects", []))
		for effect: Dictionary in effects:
			if effect.has("flag"):
				settable[effect.flag] = true
	for location_id: String in locations:
		var location: Dictionary = locations[location_id]
		if location.has("hidden_until") and not settable.has(location.hidden_until):
			return "隐藏地点永远无法发现：" + location_id
		for spot: Dictionary in location.spots:
			if spot.has("requires_flag") and not settable.has(spot.requires_flag):
				return "场景永远无法开放：%s.%s" % [location_id, spot.id]
	return ""

# --- Map queries ----------------------------------------------------------------

func location_visible(location_id: String, flags: Dictionary) -> bool:
	var location: Dictionary = locations.get(location_id, {})
	return not location.is_empty() and (not location.has("hidden_until") or bool(flags.get(location.hidden_until, false)))

func route_between(from_id: String, to_id: String) -> Dictionary:
	for route: Dictionary in routes:
		if from_id in route.between and to_id in route.between and from_id != to_id:
			return route
	return {}

func neighbors(location_id: String, flags: Dictionary) -> Array[String]:
	var result: Array[String] = []
	for route: Dictionary in routes:
		if location_id in route.between:
			var other: String = route.between[1] if route.between[0] == location_id else route.between[0]
			if location_visible(other, flags):
				result.append(other)
	return result

## Shortest path by days over visible locations, including both ends; empty when unreachable.
## Ties prefer the lower total danger, then the alphabetical order of ids, so paths are stable.
func find_path(from_id: String, to_id: String, flags: Dictionary) -> Array[String]:
	var empty: Array[String] = []
	if not location_visible(from_id, flags) or not location_visible(to_id, flags):
		return empty
	var best := {from_id: [0, 0]}
	var previous := {}
	var open: Array[String] = [from_id]
	var done := {}
	while not open.is_empty():
		open.sort_custom(func(a: String, b: String) -> bool:
			return best[a][0] < best[b][0] or (best[a][0] == best[b][0] and (best[a][1] < best[b][1] or (best[a][1] == best[b][1] and a < b))))
		var current: String = open.pop_front()
		if done.has(current):
			continue
		done[current] = true
		if current == to_id:
			break
		for other: String in neighbors(current, flags):
			var route := route_between(current, other)
			var cost := [int(best[current][0]) + int(route.days), int(best[current][1]) + int(route.danger)]
			if not best.has(other) or cost[0] < best[other][0] or (cost[0] == best[other][0] and cost[1] < best[other][1]):
				best[other] = cost
				previous[other] = current
				open.append(other)
	if not done.has(to_id):
		return empty
	var path: Array[String] = [to_id]
	while path[0] != from_id:
		path.push_front(previous[path[0]])
	return path

func path_days(path: Array[String]) -> int:
	var total := 0
	for index: int in range(1, path.size()):
		total += int(route_between(path[index - 1], path[index]).days)
	return total

## Actions offered by the spots at a location; gated spots appear once their flag is set.
func spot_actions(location_id: String, flags: Dictionary) -> Array[String]:
	var result: Array[String] = []
	for spot: Dictionary in locations.get(location_id, {}).get("spots", []):
		if spot.has("requires_flag") and not bool(flags.get(spot.requires_flag, false)):
			continue
		for action: String in spot.actions:
			result.append(action)
	return result

# --- Event static checks -----------------------------------------------------

func _validate_event(event_id: String, definition: Variant) -> String:
	if not definition is Dictionary:
		return "定义必须是对象"
	if not definition.get("title") is String or definition.title.is_empty():
		return "缺少标题"
	# Retired events never fire; they stay only so old chronicle entries keep their text.
	if definition.get("retired", false):
		return ""
	var trigger: Variant = definition.get("trigger")
	if trigger == "location":
		if not locations.has(definition.get("location", "")):
			return "未知地点"
	elif trigger == "date":
		if not definition.has("window") and not definition.has("periodic"):
			return "日期事件必须有时间窗口或周期"
		if definition.has("choices") or definition.has("repeat"):
			return "日期事件不能带选项或冷却"
	elif trigger == "route":
		if not definition.get("routes") is Array or definition.routes.is_empty():
			return "途中事件需要路线"
		for pair: Variant in definition.routes:
			if not pair is Array or pair.size() != 2 or route_between(str(pair[0]), str(pair[1])).is_empty():
				return "途中事件引用了不存在的路线"
		if not _whole(definition.get("min_danger")) or int(definition.min_danger) >= DANGER_LEVELS:
			return "途中事件危险度无效"
		if not _whole(definition.get("weight")) or int(definition.weight) < 1:
			return "途中事件权重无效"
		if definition.has("window") or definition.has("periodic"):
			return "途中事件不使用时间窗口或周期"
		# People are met where the player stops, never forced on the road; road encounters are beasts and the like.
		if not definition.has("choices"):
			return "途中遭遇需要选项"
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
			"battle":
				ok = enemies.has(value)
			"hp", "qi":
				ok = (value is int or value is float) and float(value) == floor(float(value))
			"leave":
				ok = value == true
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

## Event ids by descending priority, then id. Cached; rebuilt if the event set changes size.
var _by_priority: Array[String] = []
var _by_priority_source := -1

func events_by_priority() -> Array[String]:
	if _by_priority_source != events.size():
		_by_priority_source = events.size()
		_by_priority.clear()
		for id: String in events:
			if not events[id].get("retired", false):
				_by_priority.append(id)
		_by_priority.sort_custom(func(a: String, b: String) -> bool:
			var pa := int(events[a].get("priority", 0))
			var pb := int(events[b].get("priority", 0))
			return pa > pb or (pa == pb and a < b))
	return _by_priority

# --- People ------------------------------------------------------------------------

func _validate_person(person: Variant) -> String:
	if not person is Dictionary:
		return "定义必须是对象"
	for key: String in ["name", "title", "realm_text", "affiliation", "personality", "description"]:
		if not person.get(key) is String or person[key].is_empty():
			return "缺少资料：" + key
	if not _whole(person.get("age")) or not ATTITUDES.has(person.get("attitude", "")):
		return "年龄或态度无效"
	if person.has("home") == person.has("schedule"):
		return "必须二选一：常驻某地（home）或按行程走动（schedule）"
	if person.has("home"):
		if not locations.has(person.home):
			return "常驻地点未知"
		if person.has("spot") and not locations[person.home].spots.any(func(spot: Dictionary) -> bool: return spot.id == person.spot):
			return "常驻场景未知"
	else:
		if not person.schedule is Array or person.schedule.is_empty():
			return "行程不能为空"
		for stop: Variant in person.schedule:
			if not stop is Dictionary or not locations.has(stop.get("location", "")) or not _whole(stop.get("days")) or int(stop.days) < 1:
				return "行程中有无效的一站"
		if person.has("offset") and not _whole(person.offset):
			return "行程偏移无效"
	if person.has("window"):
		var window: Variant = person.window
		if not window is Dictionary or not _valid_date(window.get("from")) or not _valid_date(window.get("to")) or _date_day(window.from) > _date_day(window.to):
			return "出现时段无效"
	var problem := _validate_conditions(person.get("present_if", []))
	if not problem.is_empty():
		return problem
	for key: String in ["talk_favor", "gift_favor", "leave_days"]:
		if person.has(key) and not _whole(person[key]):
			return "数值无效：" + key
	if person.has("talk") and (not person.talk is Array or person.talk.any(func(line: Variant) -> bool: return not line is String)):
		return "对话必须是文字列表"
	var ids := {}
	for interaction: Variant in person.get("interactions", []):
		if not interaction is Dictionary or not interaction.get("id") is String or ids.has(interaction.id) or interaction.id in BUILT_IN_INTERACTIONS:
			return "交互缺少唯一 ID"
		ids[interaction.id] = true
		if not interaction.get("label") is String or not interaction.get("chronicle") is String:
			return "交互 %s 缺少文字" % interaction.id
		if interaction.has("cooldown_days") and not _whole(interaction.cooldown_days):
			return "交互 %s 冷却无效" % interaction.id
		problem = _validate_conditions(interaction.get("conditions", []))
		if problem.is_empty():
			problem = _validate_effects(interaction.get("effects", []))
		if not problem.is_empty():
			return "交互 %s：%s" % [interaction.id, problem]
	return ""

## Where a person would be on `day` by home or schedule, before presence conditions are applied.
func person_base_location(person_id: String, day: int) -> String:
	var person: Dictionary = people[person_id]
	if person.has("home"):
		return person.home
	var total := 0
	for stop: Dictionary in person.schedule:
		total += int(stop.days)
	var position := (day + int(person.get("offset", 0))) % total
	for stop: Dictionary in person.schedule:
		position -= int(stop.days)
		if position < 0:
			return stop.location
	return person.schedule[0].location

func favor_stage(favor: int) -> String:
	var name: String = FAVOR_STAGES[0][1]
	for stage: Array in FAVOR_STAGES:
		if favor >= int(stage[0]):
			name = stage[1]
	return name

# --- Realms and stages ----------------------------------------------------------------

## The sub-stage reached with `xp` inside a realm (stages unlock by cumulative xp in that realm).
func stage_index(realm_index: int, xp: int) -> int:
	var stages: Array = realm(realm_index).stages
	var reached := 0
	for index: int in stages.size():
		if xp >= int(stages[index].xp):
			reached = index
	return reached

func stage(realm_index: int, stage_number: int) -> Dictionary:
	var stages: Array = realm(realm_index).stages
	return stages[clampi(stage_number, 0, stages.size() - 1)]

## e.g. "炼气初期".
func realm_title(realm_index: int, stage_number: int) -> String:
	return str(realm(realm_index).name) + str(stage(realm_index, stage_number).name)

## Spirit-root grade for a set of elements, e.g. {"name": "双灵根", "speed": 1.4}.
func root_grade(elements: Array) -> Dictionary:
	for grade: Dictionary in rules.spirit_roots.grades:
		if int(grade.count) == elements.size():
			return grade
	return {"name": "灵根", "speed": 1.0}

func root_title(elements: Array) -> String:
	var names := ""
	for element: String in rules.spirit_roots.elements:
		if element in elements:
			names += str(rules.spirit_roots.names[element])
	return names + str(root_grade(elements).name)

# --- Items ---------------------------------------------------------------------------

func _validate_item(item: Variant) -> String:
	if not item is Dictionary or not item.get("name") is String or not item.get("description") is String:
		return "缺少名称或描述"
	if not ITEM_CATEGORIES.has(item.get("category", "")):
		return "品类未知"
	if not _whole(item.get("price")):
		return "价格无效"
	if item.has("use_cooldown_days") and not _whole(item.use_cooldown_days):
		return "服用间隔无效"
	return _validate_effects(item.get("use", []))

## Herb ids from cheapest to dearest (then by id), the order generic herb costs are paid in.
func herbs_by_value() -> Array[String]:
	var ids: Array[String] = []
	for item_id: String in items:
		if items[item_id].category == "herb":
			ids.append(item_id)
	ids.sort_custom(func(a: String, b: String) -> bool:
		return int(items[a].price) < int(items[b].price) or (int(items[a].price) == int(items[b].price) and a < b))
	return ids
