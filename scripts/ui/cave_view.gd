extends RefCounted
## The old cave's rooms inside the 洞府深处 scroll (caves.gd): a small map of the rooms explored and
## the doorways seen from them, linked by passages; below it the chosen room — its words, what the
## 神识 tells of it, and what can be done there (enter, open a hidden place, take what a fallen
## guardian kept, face the guardian again).
const WARN := Color("#e0b26b")
const DONE := Color("#7f9690")

## Draws the passages between the rooms on the map.
class Passages extends Control:
	var lines: Array = []

	func _draw() -> void:
		for pair: Array in lines:
			draw_line(Vector2(pair[0]) * size, Vector2(pair[1]) * size, Color("#8a7b58", 0.75), 3.0, true)

static func render(ui, center: VBoxContainer) -> void:
	var session = ui.session
	var cave_id: String = session.cave_here()
	if cave_id.is_empty():
		return
	var cave: Dictionary = session.Caves.definition(session, cave_id)
	center.add_child(ui.label("神识 %d  ·  灵力 %d / %d  ·  每探一间 %d 日" % [session.sense(), int(session.player.qi), int(session.player.max_qi), int(cave.step_days)], 15, ui.MUTED))
	var known: Array[String] = []
	for room: Dictionary in cave.rooms:
		if session.Caves.explored(session, cave_id, room.id) or session.Caves.reachable(session, cave_id, room.id):
			known.append(str(room.id))
	# At first the way on: the first doorway not yet entered, else the hall.
	if not str(ui.cave_room) in known:
		var ahead: Array[String] = known.filter(func(room_id: String) -> bool: return not session.Caves.explored(session, cave_id, room_id))
		ui.cave_room = ahead[0] if not ahead.is_empty() else known[0]
	var map := Passages.new()
	map.custom_minimum_size.y = 190
	map.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	center.add_child(map)
	var spots := {}
	for room: Dictionary in cave.rooms:
		if room.id in known:
			spots[room.id] = Vector2(float(room.map[0]), float(room.map[1]))
	for room: Dictionary in cave.rooms:
		for link: Variant in room.links:
			if spots.has(room.id) and spots.has(link) and str(room.id) < str(link):
				map.lines.append([spots[room.id], spots[link]])
	for room: Dictionary in cave.rooms:
		if not room.id in known:
			continue
		var room_id: String = room.id
		var entered: bool = session.Caves.explored(session, cave_id, room_id)
		var chip: Button = ui.button(room.name if entered else room.name + " ？", func() -> void:
			ui.cave_room = room_id
			ui.render(), "已探过" if entered else "尚未探入")
		chip.custom_minimum_size = Vector2(96, 34)
		chip.add_theme_font_size_override("font_size", 14)
		if room_id == ui.cave_room:
			ui.tint(chip, ui.GOLD)
		elif not entered:
			ui.tint(chip, WARN)
		chip.set_anchors_preset(Control.PRESET_TOP_LEFT)
		map.add_child(chip)
		# Centred on its place once the map has its size.
		var at: Vector2 = spots[room_id]
		map.resized.connect(func() -> void: chip.position = at * map.size - chip.size / 2.0)
	_details(ui, center, cave_id, session.Caves.room(session, cave_id, ui.cave_room))

## The chosen room: its words, what the 神识 tells, and its actions.
static func _details(ui, center: VBoxContainer, cave_id: String, room: Dictionary) -> void:
	var session = ui.session
	var caves = session.Caves
	var room_id: String = room.id
	var entered: bool = caves.explored(session, cave_id, room_id)
	center.add_child(ui.label(room.name, 19, ui.GOLD))
	var notes: Array[String] = []
	if entered:
		center.add_child(ui.paragraph(room.text, ui.INK))
	else:
		center.add_child(ui.paragraph("门洞后黑沉沉的，看不清里面。", ui.MUTED))
		if room.has("trap"):
			notes.append("神识察觉门内有机关，进去时可以避开。" if session.sense() >= int(room.trap.sense) else "门内虚实难辨，神识再强些或能看出端倪。")
		if room.has("requires_sense"):
			notes.append("门上有禁制，须神识 %d 方能破开。" % int(room.requires_sense))
		if room.has("guardian"):
			notes.append("里面隐隐有妖气。")
	if room.has("hidden") and entered:
		if room_id + ":hidden" in caves.state(session, cave_id).taken:
			notes.append("%s已经取空。" % room.hidden.name)
		elif caves.hidden_seen(session, cave_id, room_id):
			notes.append("神识看破了%s。" % room.hidden.name)
		else:
			notes.append("神识扫过时似有异样，只是看不真切（须神识 %d）。" % int(room.hidden.sense))
	if entered and caves.guarded(session, cave_id, room_id):
		notes.append("%s还守在这里，往里去的路被它挡住了。" % session.content.enemies[room.guardian].name)
	for note: String in notes:
		center.add_child(ui.paragraph(note, WARN))
	var grid := GridContainer.new()
	grid.columns = 2
	grid.add_theme_constant_override("h_separation", 12)
	grid.add_theme_constant_override("v_separation", 10)
	center.add_child(grid)
	if not entered:
		var reason: String = caves.enter_block(session, cave_id, room_id)
		_act(ui, grid, "探入%s  ·  %d 日" % [room.name, int(caves.definition(session, cave_id).step_days)], func() -> String: return session.enter_room(cave_id, room_id), reason)
		return
	if room.has("hidden") and caves.hidden_seen(session, cave_id, room_id) and not room_id + ":hidden" in caves.state(session, cave_id).taken:
		_act(ui, grid, "破开%s  ·  %d 灵力" % [room.hidden.name, int(room.hidden.qi)], func() -> String: return session.open_hidden(cave_id, room_id), caves.hidden_block(session, cave_id, room_id))
	if caves.guarded(session, cave_id, room_id):
		var enemy: Dictionary = session.content.enemies[room.guardian]
		_act(ui, grid, "再战%s" % enemy.name, func() -> String: return session.challenge_guardian(cave_id, room_id), session.blocked())
	elif caves.loot_waits(session, cave_id, room_id):
		_act(ui, grid, "搜检%s" % room.name, func() -> String: return session.collect_room(cave_id, room_id), session.blocked())

## A button that runs a session action, disabled with the reason as its tooltip when blocked.
static func _act(ui, grid: GridContainer, title: String, callback: Callable, reason: String) -> void:
	var entry: Button = ui.button(title, func() -> void: ui.run(callback), reason)
	entry.disabled = not reason.is_empty()
	entry.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	grid.add_child(entry)
