extends RefCounted
## A light content check of the stories (docs/EXPERIENCE_REVIEW_20261017.md, section 9, item 6): for
## every storyline its ways in, each step's conditions and how it completes, its rewards and the flags
## it leaves, and who reads them; then the problems a reader would otherwise hunt for by hand.
##   错误 — a storyline nobody can start, a step that can never complete, a condition that can never
##          hold (a flag nothing sets, an unknown person, item, story or step, a threshold past the
##          maximum, a list that contradicts itself), an item a story asks for that nothing provides.
##   提醒 — an interaction that hands out rewards again and again, a step and the interaction that
##          advances it both paying out, a flag set that nothing reads.
## Reads data only (Content) and the scripts' text for what code starts or sets; plays nothing.
## tools/story_report.gd writes the readable report; tests/content_smoke.gd fails on 错误.

const Talents = preload("res://scripts/core/talents.gd")
const CONDITION_LISTS := ["conditions", "requires", "done", "close_if", "skip_if", "begin_if", "present_if"]
const REWARDS := ["stones", "xp", "item", "contribution", "manual", "mind", "talent", "recipe", "herbs", "pills", "longevity", "fortune"]
const STATE_WORDS := {"none": "未开始", "active": "进行中", "done": "已完成", "closed": "已作罢"}

var content
var problems: Array[Dictionary] = []    # {"level": "错误" | "提醒", "site": String, "text": String}
var flag_writers := {}                  # flag -> [site]
var flag_readers := {}                  # flag -> [site]
var item_sources := {}                  # item id -> [source text]
var item_needs := {}                    # item id -> [site]
var starters := {}                      # story id -> [site]
var advancers := {}                     # "story/step" -> [{"site", "effects"}]
var code_text := ""
var code_starts := {}                   # story id -> true, for a literal Storylines.start / start_story call

func run(loaded_content) -> void:
	content = loaded_content
	_scan_code()
	_collect_sources()
	for story_id: String in content.storylines:
		_walk_story(story_id)
	for event_id: String in content.events:
		_walk_event(event_id)
	for person_id: String in content.people:
		_walk_person(person_id)
	for item_id: String in content.items:
		var use: Variant = content.items[item_id].get("use")
		if use is Array:
			_effects(use, "物品「%s」使用" % content.items[item_id].name)
	var rumors: Variant = content.lore_data.get("rumors", [])
	if rumors is Array:
		for index: int in rumors.size():
			if rumors[index] is Dictionary:
				_conditions(rumors[index].get("conditions", []), "传闻 %d" % (index + 1))
	for pair: Array in [["地点", content.locations], ["路线", content.routes], ["敌人", content.enemies], ["规则", content.rules], ["恩怨", content.feuds], ["连战", content.series], ["洞府", content.cave_data], ["宗门", content.sect_data], ["拍卖", content.auction_data], ["论道", content.summit_data], ["人情", content.bonds_data], ["炼器", content.forge_data], ["委托", content.commission_data]]:
		_walk_section(pair[0], pair[1])
	_check_stories()
	_check_flags()
	_check_items()
	_check_repeats()

func errors() -> Array[Dictionary]:
	var found: Array[Dictionary] = []
	for problem: Dictionary in problems:
		if problem.level == "错误":
			found.append(problem)
	return found

# --- Collecting ------------------------------------------------------------------------------------

func _scan_code() -> void:
	var parts: Array[String] = []
	_read_scripts("res://scripts", parts)
	code_text = "\n".join(parts)
	var writes := RegEx.create_from_string('flags\\["([a-z0-9_]+)"\\]\\s*=\\s*true')
	for found: RegExMatch in writes.search_all(code_text):
		_add(flag_writers, found.get_string(1), "代码")
	var reads := RegEx.create_from_string('has_flag\\("([a-z0-9_]+)"\\)')
	for found: RegExMatch in reads.search_all(code_text):
		_add(flag_readers, found.get_string(1), "代码")
	var starts := RegEx.create_from_string('(?:Storylines\\.start|start_story)\\([^)]*"([a-z0-9_]+)"')
	for found: RegExMatch in starts.search_all(code_text):
		code_starts[found.get_string(1)] = true

func _read_scripts(path: String, into: Array[String]) -> void:
	var dir := DirAccess.open(path)
	if dir == null:
		return
	for sub: String in dir.get_directories():
		_read_scripts(path.path_join(sub), into)
	for file: String in dir.get_files():
		if file.ends_with(".gd"):
			into.append(FileAccess.get_file_as_string(path.path_join(file)))

## Where each catalogue item can be had, apart from story and event effects (those are added as found).
func _collect_sources() -> void:
	for location_id: String in content.locations:
		var place: Dictionary = content.locations[location_id]
		for line: Dictionary in place.get("shop", []):
			_add(item_sources, str(line.item), "%s商铺" % place.name)
		for drop: Dictionary in place.get("gather", {}).get("table", []):
			_add(item_sources, str(drop.item), "%s采集" % place.name)
	for enemy_id: String in content.enemies:
		for part: Dictionary in content.enemies[enemy_id].get("parts", []):
			_add(item_sources, str(part.item), "击败%s" % content.enemies[enemy_id].name)
	for good: Dictionary in content.sect_data.get("exchange", []):
		if good.has("item"):
			_add(item_sources, str(good.item), "宗门兑换")
	for recipe_id: String in content.alchemy_data.get("recipes", {}):
		var recipe: Dictionary = content.alchemy_data.recipes[recipe_id]
		_add(item_sources, str(recipe.pill), "炼丹")
		if recipe.has("fine"):
			_add(item_sources, str(recipe.fine), "炼丹（上品）")
	# Lots, caves, the summit, bonds and forging name items in many shapes; a mention counts as a source.
	for item_id: String in content.items:
		for pair: Array in [[content.auction_data, "拍卖"], [content.cave_data, "洞府"], [content.summit_data, "论道"], [content.bonds_data, "人情"], [content.forge_data, "炼器"]]:
			if JSON.stringify(pair[0]).contains('"%s"' % item_id):
				_add(item_sources, item_id, pair[1])

func _walk_story(story_id: String) -> void:
	var story: Dictionary = content.storylines[story_id]
	var name := "剧情「%s」" % story.title
	_conditions(story.get("begin_if", []), name + "开始条件")
	_conditions(story.get("close_if", []), name + "作罢条件")
	for step: Dictionary in story.steps:
		var site := "%s · %s" % [name, step.id]
		for key: String in ["requires", "done", "skip_if", "close_if"]:
			_conditions(step.get(key, []), site)
		_effects(step.get("effects", []), site)
		# A story can open its own manual event; only a choice that actually advances it completes it.
		if step.has("choice_event"):
			var event: Dictionary = content.events.get(str(step.choice_event), {})
			for choice: Dictionary in event.get("choices", []):
				var effects: Array = choice.get("effects", [])
				if effects.any(func(effect: Dictionary) -> bool: return str(effect.get("story_advance", "")) == story_id):
					_add(advancers, "%s/%s" % [story_id, step.id], {"site": "事件「%s」·%s" % [event.title, choice.label], "effects": effects})

func _walk_event(event_id: String) -> void:
	var event: Dictionary = content.events[event_id]
	var site := "事件「%s」" % event.title
	_conditions(event.get("conditions", []), site)
	_effects(event.get("effects", []), site)
	for choice: Dictionary in event.get("choices", []):
		_conditions(choice.get("conditions", []), "%s · %s" % [site, choice.label])
		_effects(choice.get("effects", []), "%s · %s" % [site, choice.label])

func _walk_person(person_id: String) -> void:
	var person: Dictionary = content.people[person_id]
	_conditions(person.get("present_if", []), "人物%s出现条件" % person.name)
	for key: String in person:
		if not key in ["interactions", "present_if"]:
			_walk_other(person[key], key, "人物%s闲谈与行程" % person.name)
	for interaction: Dictionary in person.get("interactions", []):
		var site := "人物%s「%s」" % [person.name, interaction.label]
		var conditions: Array = interaction.get("conditions", [])
		_conditions(conditions, site)
		_effects(interaction.get("effects", []), site)
		for effect: Dictionary in interaction.get("effects", []):
			if not effect.has("story_advance"):
				continue
			for condition: Dictionary in conditions:
				if condition.has("story_at") and str(condition.story_at[0]) == str(effect.story_advance):
					_add(advancers, "%s/%s" % condition.story_at, {"site": site, "effects": interaction.get("effects", [])})

## A section of other data, each entry named after itself where it has a name.
func _walk_section(label: String, data: Variant) -> void:
	if not data is Dictionary:
		_walk_other(data, "", label)
		return
	for key: Variant in data:
		var entry: Variant = data[key]
		var site := "%s「%s」" % [label, entry.name] if entry is Dictionary and entry.get("name") is String else "%s %s" % [label, key]
		_walk_other(entry, str(key), site)

## Other data: flags read (requires_flag, sealed_if, a `flag` outside a lease) and set (world_flag, a lease).
func _walk_other(value: Variant, parent: String, site: String) -> void:
	if value is Dictionary:
		for key: Variant in value:
			var inner: Variant = value[key]
			if key in CONDITION_LISTS and inner is Array:
				_conditions(inner, site)
			elif key == "effects" and inner is Array:
				_effects(inner, site)
			elif key in ["requires_flag", "sealed_if"] and inner is String:
				_add(flag_readers, inner, site)
			elif key == "world_flag" and inner is String:
				_add(flag_writers, inner, site)
			elif key == "flag" and inner is String:
				_add(flag_writers if parent == "lease" else flag_readers, inner, site)
			else:
				_walk_other(inner, str(key), site)
	elif value is Array:
		for inner: Variant in value:
			_walk_other(inner, parent, site)

func _conditions(conditions: Array, site: String) -> void:
	for condition: Variant in conditions:
		if condition is Dictionary and not condition.is_empty():
			_condition(condition, site)
	_contradictions(conditions, site)

func _condition(condition: Dictionary, site: String) -> void:
	var key: String = condition.keys()[0]
	var value: Variant = condition[key]
	match key:
		"all", "any":
			for part: Variant in value:
				if part is Dictionary:
					_condition(part, site)
		"not":
			if value is Dictionary:
				_condition(value, site)
		"flag":
			_add(flag_readers, str(value), site)
		"item_at_least":
			_known_item(str(value[0]), site)
			_add(item_needs, str(value[0]), site)
		"met", "talked":
			_known_person(str(value), site)
		"relation_at_least":
			_known_person(str(value[0]), site)
			if int(value[1]) > content.FAVOR_MAX:
				_problem("错误", site, "交情要求 %d 超过上限 %d" % [int(value[1]), content.FAVOR_MAX])
		"realm_at_least":
			if int(value) >= content.realms.size():
				_problem("错误", site, "境界要求 %d 不存在" % int(value))
		"stage_at_least":
			if int(value[0]) >= content.realms.size():
				_problem("错误", site, "境界要求 %d 不存在" % int(value[0]))
		"at_location":
			if not content.locations.has(str(value)):
				_problem("错误", site, "未知地点 %s" % value)
		"story_at":
			_known_step(str(value[0]), str(value[1]), site)
		"story_state":
			_known_story(str(value[0]), site)
			if not STATE_WORDS.has(str(value[1])):
				_problem("错误", site, "剧情状态 %s 不存在" % value[1])
		"event_state", "event_applied":
			var event_id := str(value[0]) if value is Array else str(value)
			if not content.events.has(event_id):
				_problem("错误", site, "未知事件 %s" % event_id)
		"deed_at_least":
			var deed := str(value[0])
			if deed.begins_with("win:") and not content.enemies.has(deed.trim_prefix("win:")):
				_problem("错误", site, "未知敌人 %s" % deed)

func _effects(effects: Array, site: String) -> void:
	for effect: Variant in effects:
		if not effect is Dictionary or effect.is_empty():
			continue
		var key: String = effect.keys()[0]
		var value: Variant = effect[key]
		match key:
			"flag":
				_add(flag_writers, str(value), site)
			"start_story":
				_known_story(str(value), site)
				_add(starters, str(value), site)
			"story_advance":
				_known_story(str(value), site)
			"item":
				_known_item(str(value[0]), site)
				if int(value[1]) > 0:
					_add(item_sources, str(value[0]), site)
				else:
					_add(item_needs, str(value[0]), site)
			"take_item":
				_known_item(str(value), site)
				_add(item_needs, str(value), site)
			"herbs":
				if int(value) > 0:
					_add(item_sources, "huichun_grass", site)
			"pills":
				_add(item_sources if int(value) > 0 else item_needs, "foundation_pill", site)
			"relation", "meet", "sound":
				_known_person(str(value[0]) if value is Array else str(value), site)
			"battle":
				if not content.enemies.has(str(value)):
					_problem("错误", site, "未知敌人 %s" % value)

## A list that asks for a flag and its absence, or two states of one storyline, can never hold.
func _contradictions(conditions: Array, site: String) -> void:
	var flags := {}
	var states := {}
	var steps := {}
	for condition: Variant in conditions:
		if not condition is Dictionary or condition.is_empty():
			continue
		if condition.has("flag"):
			flags[str(condition.flag)] = int(flags.get(str(condition.flag), 0)) | 1
		elif condition.has("not") and condition.not is Dictionary and condition.not.has("flag"):
			flags[str(condition.not.flag)] = int(flags.get(str(condition.not.flag), 0)) | 2
		elif condition.has("story_state") or condition.has("story_at"):
			var pair: Array = condition.get("story_state", condition.get("story_at"))
			var story_id := str(pair[0])
			var wanted := str(pair[1]) if condition.has("story_state") else "active"
			if condition.has("story_at"):
				if steps.has(story_id) and steps[story_id] != str(pair[1]):
					_problem("错误", site, "同时要求剧情 %s 停在两个步骤" % story_id)
				steps[story_id] = str(pair[1])
			if states.has(story_id) and states[story_id] != wanted:
				_problem("错误", site, "同时要求剧情 %s 处于不同状态" % story_id)
			states[story_id] = wanted
	for flag: String in flags:
		if flags[flag] == 3:
			_problem("错误", site, "同时要求有和没有旗标 %s" % flag)

func _known_person(person_id: String, site: String) -> void:
	if not content.people.has(person_id):
		_problem("错误", site, "未知人物 %s" % person_id)

func _known_item(item_id: String, site: String) -> void:
	if content.item(item_id).is_empty():
		_problem("错误", site, "未知物品 %s" % item_id)

func _known_story(story_id: String, site: String) -> void:
	if not content.storylines.has(story_id):
		_problem("错误", site, "未知剧情 %s" % story_id)

func _known_step(story_id: String, step_id: String, site: String) -> void:
	if not content.storylines.has(story_id):
		_problem("错误", site, "未知剧情 %s" % story_id)
	elif not content.storylines[story_id].steps.any(func(step: Dictionary) -> bool: return str(step.id) == step_id):
		_problem("错误", site, "剧情 %s 没有步骤 %s" % [story_id, step_id])

# --- Checks -----------------------------------------------------------------------------------------

func entries(story_id: String) -> Array[String]:
	var ways: Array[String] = []
	var story: Dictionary = content.storylines[story_id]
	if story.has("begin_if"):
		ways.append("条件满足时自行开始：" + conditions_text(story.begin_if))
	for site: String in starters.get(story_id, []):
		ways.append("由%s开启" % site)
	if code_starts.has(story_id):
		ways.append("由代码开启")
	return ways

## How a step completes: its own conditions and deeds, a wait, at once, or an interaction.
func completion(story_id: String, step: Dictionary) -> Array[String]:
	var ways: Array[String] = []
	if step.has("wait_days"):
		ways.append("等 %d 日" % int(step.wait_days))
	elif step.has("done") or step.has("deeds"):
		var parts: Array[String] = []
		if step.has("done"):
			parts.append(conditions_text(step.done))
		for deed: String in step.get("deeds", {}):
			parts.append(deed_text(deed, int(step.deeds[deed])))
		ways.append("；".join(parts))
	elif bool(step.get("auto", false)):
		ways.append("开始即完成")
	for advancer: Dictionary in advancers.get("%s/%s" % [story_id, step.id], []):
		ways.append("在%s推进" % advancer.site)
	return ways

func _check_stories() -> void:
	for story_id: String in content.storylines:
		var story: Dictionary = content.storylines[story_id]
		if entries(story_id).is_empty():
			_problem("错误", "剧情「%s」" % story.title, "没有入口：无开始条件，也没有任何效果或代码开启它")
		for step: Dictionary in story.steps:
			var site := "剧情「%s」 · %s" % [story.title, step.id]
			if completion(story_id, step).is_empty():
				_problem("错误", site, "这一步无法完成：没有完成条件、等待或推进它的交互")
			for advancer: Dictionary in advancers.get("%s/%s" % [story_id, step.id], []):
				if _pays(step.get("effects", [])) and _pays(advancer.effects):
					_problem("提醒", site, "步骤奖励与推进它的%s各发一份：%s ／ %s" % [advancer.site, effects_text(step.effects), effects_text(advancer.effects)])

func _check_flags() -> void:
	for flag: String in flag_readers:
		if not flag_writers.has(flag):
			_problem("错误", "旗标 %s" % flag, "没有任何地方设置，读取它的条件永远不成立：%s" % "、".join(_unique(flag_readers[flag])))
	for flag: String in flag_writers:
		if not flag_readers.has(flag) and not code_text.contains('"%s"' % flag):
			_problem("提醒", "旗标 %s" % flag, "设置了但没有条件读取：%s" % "、".join(_unique(flag_writers[flag])))

func _check_items() -> void:
	for item_id: String in item_needs:
		if content.items.has(item_id) and not item_sources.has(item_id):
			_problem("错误", "物品「%s」" % content.items[item_id].name, "被要求或交出，却没有任何来源：%s" % "、".join(_unique(item_needs[item_id])))

## An interaction that pays out with nothing to stop it being chosen again.
func _check_repeats() -> void:
	for person_id: String in content.people:
		var person: Dictionary = content.people[person_id]
		for interaction: Dictionary in person.get("interactions", []):
			var effects: Array = interaction.get("effects", [])
			if not _pays(effects) or bool(interaction.get("once", false)) or interaction.has("cooldown_days") or interaction.has("monthly_stock"):
				continue
			if _costs(effects) or _self_limiting(interaction.get("conditions", []), effects):
				continue
			_problem("提醒", "人物%s「%s」" % [person.name, interaction.label], "可以反复领取：%s" % effects_text(effects))

func _pays(effects: Array) -> bool:
	for effect: Dictionary in effects:
		var key: String = effect.keys()[0]
		if key in ["manual", "talent", "recipe", "longevity", "fortune"]:
			return true
		if key == "item" and int(effect.item[1]) > 0:
			return true
		if key in ["stones", "xp", "contribution", "mind", "herbs", "pills"] and int(effect[key]) > 0:
			return true
	return false

func _costs(effects: Array) -> bool:
	for effect: Dictionary in effects:
		var key: String = effect.keys()[0]
		if key == "take_item" or (key == "item" and int(effect.item[1]) < 0) or (key in ["stones", "herbs", "pills"] and int(effect[key]) < 0):
			return true
	return false

## Tied to a story step, a story not yet begun that it starts, or a flag it sets and asks to be absent.
func _self_limiting(conditions: Array, effects: Array) -> bool:
	for condition: Dictionary in conditions:
		if condition.has("story_at"):
			return true
		if condition.has("story_state") and str(condition.story_state[1]) == "none" and effects.any(func(e: Dictionary) -> bool: return e.has("start_story") and str(e.start_story) == str(condition.story_state[0])):
			return true
		if condition.has("not") and condition.not is Dictionary and condition.not.has("flag") and effects.any(func(e: Dictionary) -> bool: return e.has("flag") and str(e.flag) == str(condition.not.flag)):
			return true
	return false

# --- Text -------------------------------------------------------------------------------------------

func conditions_text(conditions: Array) -> String:
	var parts: Array[String] = []
	for condition: Variant in conditions:
		if condition is Dictionary and not condition.is_empty():
			parts.append(condition_text(condition))
	return "、".join(parts) if not parts.is_empty() else "无"

func condition_text(condition: Dictionary) -> String:
	var key: String = condition.keys()[0]
	var value: Variant = condition[key]
	match key:
		"all":
			return "（%s）" % conditions_text(value)
		"any":
			var parts: Array[String] = []
			for part: Dictionary in value:
				parts.append(condition_text(part))
			return "（%s）" % " 或 ".join(parts)
		"not":
			return "非" + condition_text(value)
		"flag":
			return "旗标 %s" % value
		"realm_at_least":
			return "境界≥%s" % _realm(int(value))
		"stage_at_least":
			return "境界≥%s第%d阶" % [_realm(int(value[0])), int(value[1]) + 1]
		"item_at_least":
			return "持有%s×%d" % [_item(str(value[0])), int(value[1])]
		"stones_at_least":
			return "灵石≥%d" % int(value)
		"herbs_at_least":
			return "灵草≥%d" % int(value)
		"met":
			return "结识%s" % _person(str(value))
		"talked":
			return "与%s交谈过" % _person(str(value))
		"relation_at_least":
			return "%s交情≥%d" % [_person(str(value[0])), int(value[1])]
		"mind_at_least":
			return "心境≥%d" % int(value)
		"sense_at_least":
			return "神识≥%d" % int(value)
		"at_location":
			return "在%s" % content.locations.get(str(value), {}).get("name", str(value))
		"deed_at_least":
			return deed_text(str(value[0]), int(value[1]))
		"talent":
			return "天赋「%s」" % Talents.definition(content, str(value)).get("name", str(value))
		"rank_at_least":
			for rank: Dictionary in content.sect_data.get("ranks", []):
				if str(rank.id) == str(value):
					return "宗门身份≥%s" % rank.name
			return "宗门身份≥%s" % value
		"sect":
			return "修习%s传承" % content.sects.get(str(value), {}).get("name", str(value))
		"recipe":
			return "掌握%s丹方" % content.alchemy_data.get("recipes", {}).get(str(value), {}).get("name", str(value))
		"grudge":
			return "尚有恩怨" if bool(value) else "没有恩怨"
		"story_at":
			return "「%s」到 %s" % [_story(str(value[0])), value[1]]
		"story_state":
			return "「%s」%s" % [_story(str(value[0])), STATE_WORDS.get(str(value[1]), str(value[1]))]
		"event_state":
			return "事件「%s」%s" % [content.events.get(str(value[0]), {}).get("title", str(value[0])), value[1]]
		"event_applied":
			return "事件「%s」已发生" % content.events.get(str(value), {}).get("title", str(value))
	return JSON.stringify(condition)

func deed_text(deed: String, count: int) -> String:
	if deed.begins_with("win:"):
		return "击败%s %d 次" % [content.enemies.get(deed.trim_prefix("win:"), {}).get("name", deed), count]
	if deed == "retreat_days":
		return "闭关 %d 日" % count
	return "%s %d 次" % [{"duel": "斗法", "trade": "交易", "gather": "采集", "hunt": "狩猎", "commission": "交付委托", "help": "帮忙"}.get(deed, deed), count]

func effects_text(effects: Array) -> String:
	var parts: Array[String] = []
	for effect: Variant in effects:
		if not effect is Dictionary or effect.is_empty():
			continue
		var key: String = effect.keys()[0]
		var value: Variant = effect[key]
		match key:
			"stones":
				parts.append("灵石%+d" % int(value))
			"xp":
				parts.append("修为%+d" % int(value))
			"mind":
				parts.append("心境%+d" % int(value))
			"contribution":
				parts.append("贡献%+d" % int(value))
			"item":
				parts.append("%s%+d" % [_item(str(value[0])), int(value[1])])
			"take_item":
				parts.append("交出%s" % _item(str(value)))
			"herbs":
				parts.append("灵草%+d" % int(value))
			"pills":
				parts.append("筑基丹%+d" % int(value))
			"manual":
				parts.append("%d阶玉简" % int(value))
			"relation":
				parts.append("%s交情%+d" % [_person(str(value[0])), int(value[1])])
			"meet":
				parts.append("结识%s" % _person(str(value)))
			"sound":
				parts.append("与%s互留传音符" % _person(str(value)))
			"flag":
				parts.append("旗标 %s" % value)
			"clear_flag":
				parts.append("清除旗标 %s" % value)
			"start_story":
				parts.append("开启「%s」" % _story(str(value)))
			"story_advance":
				parts.append("推进「%s」" % _story(str(value)))
			"battle":
				parts.append("斗法：%s" % content.enemies.get(str(value), {}).get("name", str(value)))
			_:
				parts.append(key if value is bool else "%s %s" % [key, JSON.stringify(value)])
	return "、".join(parts) if not parts.is_empty() else "—"

func _realm(index: int) -> String:
	return str(content.realms[index].name) if index >= 0 and index < content.realms.size() else str(index)

func _item(item_id: String) -> String:
	var item: Dictionary = content.item(item_id)
	return str(item.name) if not item.is_empty() else item_id

func _person(person_id: String) -> String:
	return str(content.people.get(person_id, {}).get("name", person_id))

func _story(story_id: String) -> String:
	return str(content.storylines.get(story_id, {}).get("title", story_id))

# --- Report -----------------------------------------------------------------------------------------

func markdown() -> String:
	var out: Array[String] = []
	var errs := errors()
	out.append("# 剧情检查报告")
	out.append("")
	out.append("由 `tools/story_report.gd` 生成，只读数据与脚本文本，不进行游玩。剧情 %d 条、步骤 %d 个、事件 %d 个、人物交互 %d 个；错误 %d 项、提醒 %d 项。" % [
		content.storylines.size(), content.storylines.values().reduce(func(n: int, s: Dictionary) -> int: return n + s.steps.size(), 0), content.events.size(),
		content.people.values().reduce(func(n: int, p: Dictionary) -> int: return n + p.get("interactions", []).size(), 0), errs.size(), problems.size() - errs.size()])
	out.append("")
	out.append("## 问题")
	out.append("")
	if problems.is_empty():
		out.append("没有发现问题。")
	for level: String in ["错误", "提醒"]:
		for problem: Dictionary in problems:
			if problem.level == level:
				out.append("- **%s** %s：%s" % [level, problem.site, problem.text])
	out.append("")
	out.append("## 剧情")
	for story_id: String in content.storylines:
		var story: Dictionary = content.storylines[story_id]
		out.append("")
		out.append("### %s（`%s`）" % [story.title, story_id])
		out.append("")
		out.append("- 交付人：%s%s" % [_person(str(story.giver)), "；入门引导" if bool(story.get("guide", false)) else ""])
		var ways := entries(story_id)
		out.append("- 入口：" + ("；".join(ways) if not ways.is_empty() else "**无**"))
		if story.has("close_if"):
			out.append("- 作罢：" + conditions_text(story.close_if))
		out.append("")
		out.append("| 步骤 | 地点 | 开始条件 | 完成方式 | 效果与奖励 |")
		out.append("|---|---|---|---|---|")
		for step: Dictionary in story.steps:
			var start := conditions_text(step.get("requires", []))
			if step.has("skip_if"):
				start += "；跳过：" + conditions_text(step.skip_if)
			if step.has("close_if"):
				start += "；作罢：" + conditions_text(step.close_if)
			var done := completion(story_id, step)
			var paid := effects_text(step.get("effects", []))
			for advancer: Dictionary in advancers.get("%s/%s" % [story_id, step.id], []):
				paid += "<br>%s：%s" % [advancer.site, effects_text(advancer.effects)]
			out.append("| %s | %s | %s | %s | %s |" % [step.id, content.locations.get(str(step.get("place", "")), {}).get("name", "—"), start, "<br>".join(done) if not done.is_empty() else "**无法完成**", paid])
		var exits: Array[String] = []
		for step: Dictionary in story.steps:
			for effect: Dictionary in step.get("effects", []):
				if effect.has("flag"):
					var readers: Array[String] = _unique(flag_readers.get(str(effect.flag), []))
					exits.append("旗标 %s → %s" % [effect.flag, "、".join(readers) if not readers.is_empty() else "无人读取"])
				elif effect.has("start_story"):
					exits.append("开启「%s」" % _story(str(effect.start_story)))
		var followers: Array[String] = []
		for other_id: String in content.storylines:
			if other_id != story_id and JSON.stringify(content.storylines[other_id].get("begin_if", [])).contains('"%s"' % story_id):
				followers.append("「%s」" % content.storylines[other_id].title)
		if not followers.is_empty():
			exits.append("以它为开始条件：" + "、".join(followers))
		out.append("")
		out.append("- 出口：" + ("；".join(exits) if not exits.is_empty() else "无旗标或后续剧情"))
	out.append("")
	out.append("## 剧情要用的物品与来源")
	out.append("")
	out.append("| 物品 | 被要求或交出于 | 来源 |")
	out.append("|---|---|---|")
	for item_id: String in item_needs:
		out.append("| %s | %s | %s |" % [_item(item_id), "、".join(_unique(item_needs[item_id])), "、".join(_unique(item_sources.get(item_id, []))) if item_sources.has(item_id) else "**无**"])
	out.append("")
	out.append("## 旗标")
	out.append("")
	out.append("| 旗标 | 设置于 | 读取于 |")
	out.append("|---|---|---|")
	var flags: Array[String] = _unique(flag_writers.keys() + flag_readers.keys())
	flags.sort()
	for flag: String in flags:
		out.append("| %s | %s | %s |" % [flag, "、".join(_unique(flag_writers.get(flag, []))) if flag_writers.has(flag) else "**无**", "、".join(_unique(flag_readers.get(flag, []))) if flag_readers.has(flag) else "—"])
	return "\n".join(out) + "\n"

# --- Helpers ----------------------------------------------------------------------------------------

func _add(table: Dictionary, key: String, entry: Variant) -> void:
	if not table.has(key):
		table[key] = []
	table[key].append(entry)

func _unique(values: Array) -> Array[String]:
	var seen := {}
	var result: Array[String] = []
	for value: Variant in values:
		if not seen.has(str(value)):
			seen[str(value)] = true
			result.append(str(value))
	return result

func _problem(level: String, site: String, text: String) -> void:
	for existing: Dictionary in problems:
		if existing.site == site and existing.text == text:
			return
	problems.append({"level": level, "site": site, "text": text})
