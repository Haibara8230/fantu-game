extends SceneTree
## Content checks across the data files (docs/WORLD_EXPANSION.md 2.6–2.7): no key defined twice in one
## object (Godot's JSON parser keeps the last silently, so a copied entry would hide another), every
## item, handwritten skill and generated technique or piece of gear has its own description, and the
## names carry no tier. Art coverage of items is reported, not yet required: item art is still to come.
const Content = preload("res://scripts/core/content.gd")
const Arsenal = preload("res://scripts/core/arsenal.gd")
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
	var covered: int = content.items.keys().filter(func(item_id: String) -> bool: return mapped.has(item_id)).size()
	print("ITEM ART: %d / %d items mapped (item art still to come)" % [covered, content.items.size()])
	check(mapped.keys().all(func(item_id: String) -> bool: return content.items.has(item_id)), "item art maps only known items")
