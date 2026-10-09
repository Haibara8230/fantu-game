extends RefCounted
## Structured life record: entries keep an ID, arguments and a date; text is produced on display.
## Major entries are kept for the whole life, everyday entries only for the recent past.
const Calendar = preload("res://scripts/core/calendar.gd")
const RECENT_LIMIT := 100
const MAJOR_LIMIT := 5000
const NAMED_ARGS := {"location": "locations", "enemy": "enemies", "sect": "sects"}
var entries: Array[Dictionary] = []

func clear() -> void:
	entries.clear()

func add(day: int, id: String, args: Dictionary = {}, major: bool = false) -> Dictionary:
	var entry := {"day": day, "id": id, "args": args.duplicate(true), "major": major}
	entries.append(entry)
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
		_:
			template = str(content.chronicle.get(entry.id, "（失传的记载）"))
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
	if values.has("loot"):
		values["loot_text"] = loot_text(str(values.loot), content)
	if values.has("days"):
		values["duration"] = Calendar.duration_text(int(values.days))
	return template.format(values)

## "id:count,id:count" as "回春草×2、赤炎花"; unknown ids keep their id so old records still read.
static func loot_text(code: String, content) -> String:
	var parts: Array[String] = []
	for piece: String in code.split(",", false):
		var pair := piece.split(":")
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
