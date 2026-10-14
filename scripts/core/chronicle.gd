extends RefCounted
## Structured life record: entries keep an ID, arguments and a date; text is produced on display.
## Major entries are kept for the whole life, everyday entries only for the recent past.
const Calendar = preload("res://scripts/core/calendar.gd")
const RECENT_LIMIT := 100
const MAJOR_LIMIT := 5000
const NAMED_ARGS := {"location": "locations", "enemy": "enemies", "sect": "sects"}
var entries: Array[Dictionary] = []
# How many entries were ever added, trimmed or not; the interface compares it before and after an
# action to find that action's entries (the newest ones). Not saved.
var added := 0

func clear() -> void:
	entries.clear()

func add(day: int, id: String, args: Dictionary = {}, major: bool = false) -> Dictionary:
	var entry := {"day": day, "id": id, "args": args.duplicate(true), "major": major}
	entries.append(entry)
	added += 1
	_trim()
	return entry

func _trim() -> void:
	var minor_count := 0
	var major_count := 0
	for entry: Dictionary in entries:
		if entry.major:
			major_count += 1
		else:
			minor_count += 1
	if minor_count <= RECENT_LIMIT and major_count <= MAJOR_LIMIT:
		return
	var kept: Array[Dictionary] = []
	var minor_drop := maxi(0, minor_count - RECENT_LIMIT)
	var major_drop := maxi(0, major_count - MAJOR_LIMIT)
	for entry: Dictionary in entries:
		if entry.major and major_drop > 0:
			major_drop -= 1
		elif not entry.major and minor_drop > 0:
			minor_drop -= 1
		else:
			kept.append(entry)
	entries = kept

func format(entry: Dictionary, content) -> String:
	var template: String
	match str(entry.id):
		"event":
			template = _event_text(entry.args, content)
		"talk", "npc":
			template = _person_text(entry.id, entry.args, content)
		"story":
			template = story_text(entry.args, content)
		"letter":
			template = "{npc_name}传音：" + letter_text(entry.args, content)
		_:
			template = str(content.chronicle.get(entry.id, "（失传的记载）"))
	# Breakthroughs since grades also tell the foundation's grade.
	if entry.id == "breakthrough" and entry.args.has("grade"):
		template += str(content.chronicle.get("breakthrough_grade", ""))
	var values: Dictionary = entry.args.duplicate()
	for key: String in NAMED_ARGS:
		if values.has(key):
			var table: Dictionary = content.get(NAMED_ARGS[key])
			var definition: Variant = table.get(values[key])
			values[key + "_name"] = definition.name if definition is Dictionary else str(values[key])
	if values.has("realm"):
		values["realm_name"] = content.realm_title(int(values.realm), int(values.get("stage", 0)))
	# Techniques and items may be generated, so their names come from the content resolvers.
	for key: String in ["skill", "technique"]:
		if values.has(key):
			var t: Dictionary = content.technique(str(values[key]))
			values[key + "_name"] = t.name if not t.is_empty() else str(values[key])
	if values.has("npc"):
		var someone: Dictionary = content.person_named(str(values.npc))
		values["npc_name"] = someone.name if not someone.is_empty() else str(values.npc)
	if values.has("board") and content.commission_data.boards.has(values.board):
		values["board_name"] = content.commission_data.boards[values.board].name
	if values.has("item"):
		var named: Dictionary = content.item(str(values.item))
		values["item_name"] = named.name if not named.is_empty() else str(values.item)
	if values.has("auction"):
		values["auction_name"] = str(content.auction_data.get("auctions", {}).get(str(values.auction), {}).get("name", values.auction))
	if values.has("cave") and content.cave_data.has(str(values.cave)):
		var cave: Dictionary = content.cave_data[str(values.cave)]
		values["cave_name"] = cave.name
		for room: Dictionary in cave.rooms:
			if room.id == str(values.get("room", "")):
				values["room_name"] = room.name
	if values.has("loot"):
		values["loot_text"] = loot_text(str(values.loot), content)
	if values.has("grade"):
		var grades: Array = content.rules.get("breakthrough", {}).get("grades", [])
		var grade := int(values.grade)
		values["grade_name"] = str(grades[grade].name) if grade >= 0 and grade < grades.size() else str(values.grade)
	if values.has("rank"):
		var ranks: Array = content.sect_data.get("ranks", [])
		var rank := int(values.rank)
		values["rank_name"] = str(ranks[rank].name) if rank >= 0 and rank < ranks.size() else str(values.rank)
		values["rank_words"] = str(ranks[rank].get("words", "")) if rank >= 0 and rank < ranks.size() else ""
	if values.has("boon"):
		for boon: Dictionary in content.rules.get("breakthrough", {}).get("boons", []):
			if boon.id == values.boon:
				values["boon_name"] = boon.name
	if values.has("talent"):
		values["talent_name"] = str(content.Talents.definition(content, str(values.talent)).get("name", values.talent))
	if values.has("talents"):
		values["talents_text"] = content.Talents.names(content, str(values.talents).split(",", false))
	if values.has("days"):
		values["duration"] = Calendar.duration_text(int(values.days))
	return template.format(values)

## "id:count,id:count" as "回春草×2、赤炎花"; unknown ids keep their id so old records still read.
## Generated ids contain colons themselves ("j:t:…", "e:…"), so the count is after the last colon.
static func loot_text(code: String, content) -> String:
	var parts: Array[String] = []
	for piece: String in code.split(",", false):
		var pair := piece.rsplit(":", true, 1)
		var item: Dictionary = content.item(pair[0])
		var name: String = item.name if not item.is_empty() else pair[0]
		var count := int(pair[1]) if pair.size() > 1 else 1
		parts.append(name if count == 1 else "%s×%d" % [name, count])
	return "、".join(parts) if not parts.is_empty() else "一无所获"

## Talks and interactions point into data/npcs.json.
static func _person_text(kind: String, args: Dictionary, content) -> String:
	var person: Variant = content.person_named(str(args.get("npc", "")))
	if person.is_empty():
		return "（失传的记载）"
	if kind == "talk":
		var lines: Array = person.get("talk", [])
		var index := int(args.get("line", 0))
		return "{npc_name}：" + str(lines[index]) if index >= 0 and index < lines.size() else "（失传的记载）"
	for interaction: Dictionary in person.get("interactions", []):
		if interaction.id == args.get("interaction", ""):
			return interaction.chronicle
	return "（失传的记载）"

## Storyline records point into data/storylines.json: a step's opening or closing words, or the words
## when the storyline was overtaken ("closed", the step's own or the storyline's).
static func story_text(args: Dictionary, content) -> String:
	var story: Variant = content.storylines.get(args.get("story", ""))
	if not story is Dictionary:
		return "（失传的记载）"
	var part := str(args.get("part", "say"))
	for step: Dictionary in story.steps:
		if step.id == args.get("step", ""):
			if step.has(part):
				return str(step[part])
			break
	if part == "closed" and story.has("closed"):
		return str(story.closed)
	return "（失传的记载）"

## A 传音: a storyline step's words, or a friend's word on a milestone.
static func letter_text(args: Dictionary, content) -> String:
	if args.has("story"):
		return story_text({"story": args.story, "step": args.get("step", ""), "part": "say"}, content)
	var person: Dictionary = content.person_named(str(args.get("npc", "")))
	var kind := str(args.get("kind", ""))
	# Letters friends write on their own, in the words of their temper (data/bonds.json).
	if kind.begins_with("bond:"):
		var words: Variant = content.bonds_data.get("letters", {}).get(kind.trim_prefix("bond:"), {}).get(str(person.get("personality", "")))
		if not words is String:
			return "（失传的记载）"
		var values: Dictionary = args.duplicate()
		if values.has("item"):
			values["item_name"] = str(content.item(str(values.item)).get("name", values.item))
		if values.has("place"):
			values["place_name"] = str(content.locations.get(str(values.place), {}).get("name", values.place))
		return words.format(values)
	return str(person.get("congrats", {}).get(kind, "（失传的记载）"))

## Event records point into data/events.json: the event's own text, a choice, a reminder or an expiry.
static func _event_text(args: Dictionary, content) -> String:
	var definition: Variant = content.events.get(args.get("event", ""))
	if not definition is Dictionary:
		return "（失传的记载）"
	match str(args.get("part", "chronicle")):
		"choice":
			for choice: Dictionary in definition.get("choices", []):
				if choice.id == args.get("choice", ""):
					return choice.chronicle
		"remind":
			return definition.get("remind", {}).get("chronicle", "（失传的记载）")
		"expire":
			return definition.get("expire", {}).get("chronicle", "（失传的记载）")
		"chronicle":
			return definition.get("chronicle", "（失传的记载）")
	return "（失传的记载）"

func lines(content, limit: int = RECENT_LIMIT) -> Array[String]:
	var result: Array[String] = []
	for index: int in range(maxi(0, entries.size() - limit), entries.size()):
		var entry: Dictionary = entries[index]
		result.append("【%s】%s" % [Calendar.short_text(int(entry.day)), format(entry, content)])
	return result

func to_save() -> Array:
	return entries.duplicate(true)

## Returns a validated copy of saved entries, or null when the data is malformed.
static func parse(data: Variant, current_day: int) -> Variant:
	if not data is Array or data.size() > RECENT_LIMIT + MAJOR_LIMIT:
		return null
	var result: Array[Dictionary] = []
	for item: Variant in data:
		if not item is Dictionary or not item.get("id") is String or not item.get("args") is Dictionary or not item.get("major") is bool:
			return null
		var day: Variant = item.get("day")
		if not (day is int or day is float) or not is_finite(float(day)) or float(day) != floor(float(day)) or float(day) < 0 or int(day) > current_day:
			return null
		if item.id.length() > 64 or item.args.size() > 16:
			return null
		var args: Dictionary = {}
		for key: Variant in item.args:
			var value: Variant = item.args[key]
			if not key is String:
				return null
			if value is float:
				if not is_finite(value) or value != floor(value) or absf(value) > 1000000000.0:
					return null
				value = int(value)
			elif value is String:
				value = value.left(1000)
			elif not (value is int or value is bool):
				return null
			args[key] = value
		result.append({"day": int(day), "id": item.id, "args": args, "major": item.major})
	return result
