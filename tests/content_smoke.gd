extends SceneTree
## Content checks across the data files (docs/WORLD_EXPANSION.md 2.6–2.7): no key defined twice in one
## object (Godot's JSON parser keeps the last silently, so a copied entry would hide another), every
## item, handwritten skill and generated technique or piece of gear has its own description, and the
## names carry no tier. Art coverage of items is reported, not yet required: item art is still to come.
## The story check (tools/story_check.gd) finds no 错误 in the data and does find faults planted in a copy.
const Content = preload("res://scripts/core/content.gd")
const Arsenal = preload("res://scripts/core/arsenal.gd")
const ArtLibrary = preload("res://scripts/ui/art_library.gd")
const StoryCheck = preload("res://tools/story_check.gd")
const TIER_WORDS := ["凡阶", "黄阶", "玄阶", "地阶", "天阶", "灵阶", "凡兵", "灵器", "灵宝", "玄天之宝"]
var checks := 0
var failures := 0

func check(condition: bool, message: String) -> void:
	checks += 1
	if not condition:
		failures += 1
		printerr("FAIL: " + message)

func _initialize() -> void:
	# A script error aborts this function before quit(); the watchdog turns that hang into a failure.
	create_timer(120.0).timeout.connect(func() -> void: printerr("TIMEOUT: test did not finish (likely a script error)"); quit(1))
	_duplicate_keys()
	var content := Content.new()
	check(content.load_data(), "the data loads (%s)" % content.error_message)
	_descriptions(content)
	_names(content)
	_art_coverage(content)
	_story_check(content)
	print("CONTENT: %d checks, %d failures" % [checks, failures])
	quit(0 if failures == 0 else 1)

func _duplicate_keys() -> void:
	var dir := DirAccess.open("res://data")
	var files := 0
	for file: String in dir.get_files():
		if not file.ends_with(".json"):
			continue
		files += 1
		var repeated := repeated_keys(FileAccess.get_file_as_string("res://data/" + file))
		check(repeated.is_empty(), "no key twice in one object: data/%s %s" % [file, repeated])
	check(files >= 20, "every data file is scanned (%d)" % files)
	check(repeated_keys('{"a": 1, "b": {"a": 2}, "c": [{"a": 3}, {"a": 4}]}').is_empty(), "the same key in different objects is fine")
	check(repeated_keys('{"a": 1, "b": "x", "a": 2}') == ["a"], "a key repeated in one object is found")
	check(repeated_keys('{"a": "}\\"{", "a": 1}') == ["a"], "and strings with braces and escapes do not confuse it")

## Keys that appear twice in the same JSON object, scanning the raw text.
static func repeated_keys(text: String) -> Array[String]:
	var found: Array[String] = []
	var stack: Array = []  # one entry per open bracket: a Dictionary of keys for objects, null for arrays
	var expect_key := false
	var index := 0
	while index < text.length():
		var c := text[index]
		if c == '"':
			var end := index + 1
			while text[end] != '"':
				end += 2 if text[end] == "\\" else 1
			if expect_key and not stack.is_empty() and stack.back() is Dictionary:
				var key := text.substr(index + 1, end - index - 1)
				if stack.back().has(key):
					found.append(key)
				stack.back()[key] = true
				expect_key = false
			index = end + 1
			continue
		match c:
			"{":
				stack.append({})
				expect_key = true
			"[":
				stack.append(null)
			"}", "]":
				stack.pop_back()
			",":
				expect_key = not stack.is_empty() and stack.back() is Dictionary
		index += 1
	return found

func _descriptions(content) -> void:
	var missing: Array[String] = []
	for item_id: String in content.items:
		if str(content.items[item_id].get("description", "")).strip_edges().is_empty():
			missing.append(item_id)
	for skill_id: String in content.skills:
		if str(content.skills[skill_id].get("description", "")).strip_edges().is_empty():
			missing.append(skill_id)
	check(missing.is_empty(), "every item and handwritten skill has a description: %s" % [missing])
	# Every generated kind, at every tier, describes itself.
	var bare: Array[String] = []
	for tier: int in range(1, content.technique_data.tiers.size() + 1):
		for archetype: String in content.technique_data.archetypes:
			var id := Arsenal.technique_id(archetype, "metal", tier, [], 0)
			if str(content.technique(id).get("description", "")).is_empty():
				bare.append(id)
	for tier: int in range(1, content.equipment_data.tiers.size() + 1):
		for base: String in content.equipment_data.bases:
			# A named piece (听潮剑) exists only at its own stages.
			if content.equipment_data.bases[base].has("named") and not content.equipment_data.bases[base].named.has(str(tier)):
				continue
			var id := Arsenal.equipment_id(base, tier, "none", [], 0)
			if str(content.equipment(id).get("description", "")).is_empty():
				bare.append(id)
	check(bare.is_empty(), "every generated technique and piece of gear has a description: %s" % [bare])

## Titles carry only the name (docs/WORLD_EXPANSION.md 2.7): no tier word inside a name.
func _names(content) -> void:
	var tiered: Array[String] = []
	for item_id: String in content.items:
		var name := str(content.items[item_id].name)
		if TIER_WORDS.any(func(word: String) -> bool: return name.contains(word)):
			tiered.append(name)
	for tier: int in range(1, content.technique_data.tiers.size() + 1):
		for archetype: String in content.technique_data.archetypes:
			for element: String in content.technique_data.elements:
				for variant: int in 25:
					var name := str(content.technique(Arsenal.technique_id(archetype, element, tier, [], variant)).name)
					if TIER_WORDS.any(func(word: String) -> bool: return name.contains(word)):
						tiered.append(name)
	check(tiered.is_empty(), "no name carries a tier: %s" % [tiered])

func _art_coverage(content) -> void:
	var art: Variant = JSON.parse_string(FileAccess.get_file_as_string("res://data/art.json"))
	var mapped: Dictionary = art.get("item_art", {}) if art is Dictionary else {}
	var covered: int = content.items.keys().filter(func(item_id: String) -> bool: return not ArtLibrary.item_icon_path(content.item(item_id)).is_empty()).size()
	print("ITEM ART: %d / %d items mapped (item art still to come)" % [covered, content.items.size()])
	check(mapped.keys().all(func(item_id: String) -> bool: return content.items.has(item_id)), "item art maps only known items")

func _story_check(content) -> void:
	var real := StoryCheck.new()
	real.run(content)
	var errors := real.errors()
	print("STORY CHECK: %d errors, %d notes (report: tools/story_report.gd)" % [errors.size(), real.problems.size() - errors.size()])
	check(errors.is_empty(), "no story has a broken path, an impossible condition or a missing source: %s" % [errors.slice(0, 3)])
	check(real.completion("south_settlement", content.storylines.south_settlement.steps[2]).size()==2, "both manual route choices count as real story completion paths")
	for flag: String in ["chenxia_puppet_down", "chenxia_remnant_down", "ruin_den_cleared"]:
		check(real.flag_readers.get(flag, []).any(func(site: Variant) -> bool: return str(site).contains("Caves.guarded")), "actual cave guardian flags have dynamic readers: " + flag)
	# A copy with one fault of each kind: every one is found.
	var planted := Content.new()
	planted.load_data()
	planted.items["planted_relic"] = {"id": "planted_relic", "name": "无源遗物", "category": "quest", "price": 0, "description": "测试"}
	planted.storylines["planted"] = {"title": "测试剧情", "giver": "xu_qinghe", "steps": [
		{"id": "stuck", "goal": "没有完成方式"},
		{"id": "odd", "requires": [{"flag": "never_set_anywhere"}, {"flag": "rushi_done"}, {"not": {"flag": "rushi_done"}}],
			"done": [{"relation_at_least": ["shen_mo", Content.FAVOR_MAX + 1]}, {"item_at_least": ["planted_relic", 1]}, {"story_at": ["rushi", "no_such_step"]}, {"met": "nobody_here"}]}]}
	planted.people.xu_qinghe.interactions.append({"id": "planted_gift", "label": "白送灵石", "conditions": [], "effects": [{"stones": 50}], "chronicle": "测试"})
	for choice: Dictionary in planted.events.south_return_routes.choices:
		choice.effects = []
	# Removing a real guardian reference makes that enemy's flag unused again.
	for room: Dictionary in planted.cave_data.ruin.rooms:
		if str(room.get("guardian", "")) == "den_wolf":
			room.erase("guardian")
	var found := StoryCheck.new()
	found.run(planted)
	var said := func(level: String, fragment: String) -> bool: return found.problems.any(func(p: Dictionary) -> bool: return p.level == level and (p.site + p.text).contains(fragment))
	check(said.call("错误", "没有入口"), "a storyline nobody starts is found")
	check(said.call("错误", "这一步无法完成"), "a step with no way to complete is found")
	check(said.call("错误", "never_set_anywhere"), "a condition on a flag nothing sets is found")
	check(said.call("错误", "同时要求有和没有旗标 rushi_done"), "a list asking for a flag and its absence is found")
	check(said.call("错误", "超过上限"), "a favor beyond the maximum is found")
	check(said.call("错误", "无源遗物"), "an item a story needs with no source is found")
	check(said.call("错误", "没有步骤 no_such_step"), "a step that does not exist is found")
	check(said.call("错误", "未知人物 nobody_here"), "an unknown person is found")
	check(said.call("提醒", "可以反复领取"), "an interaction paying out again and again is noted")
	check(said.call("错误", "南明落脚"), "a choice event without any advancing effect remains a broken story path")
	check(said.call("提醒", "ruin_den_cleared"), "an enemy flag without an actual cave reference is still reported")
	check(not said.call("错误", "初入山门"), "the real storylines stay clean beside the planted one")
