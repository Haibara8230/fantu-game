extends RefCounted
## People in the interface: who is here, the 相识 list, a person's profile card and their portrait.
const Calendar = preload("res://scripts/core/calendar.gd")
const ArtLibrary = preload("res://scripts/ui/art_library.gd")
const PEOPLE_SHOWN_HERE := 12

static func sorted_acquaintances(ui) -> Array[String]:
	var session = ui.session
	var known: Array[String] = session.known_npcs()
	known.sort_custom(func(a: String, b: String) -> bool:
		var core_a: bool = not session.is_generated(a)
		var core_b: bool = not session.is_generated(b)
		if core_a != core_b:
			return core_a
		return session.favor(a) > session.favor(b) or (session.favor(a) == session.favor(b) and a < b))
	return known

## An acquaintance with where they are now; clicking opens their profile.
static func acquaintance_button(ui, person_id: String) -> Button:
	var session = ui.session
	var person: Dictionary = session.person(person_id)
	var where: String = session.npc_location(person_id)
	var place: String = session.content.locations[where].name if not where.is_empty() else "下落不明"
	if person.has("death") and int(session.world.day) >= int(person.death):
		place = "已故"
	var favor: int = session.favor(person_id)
	var entry: Button = ui.button("%s · %s\n%s · %s %d" % [person.name, place, person.title, session.content.favor_stage(favor), favor], func() -> void: ui.open_person(person_id), "查看资料")
	entry.alignment = HORIZONTAL_ALIGNMENT_LEFT
	entry.add_theme_font_size_override("font_size", 14)
	return entry

## 相识: everyone the player has met, with where they are now.
static func render_list(ui) -> void:
	var center: VBoxContainer = ui.center
	var known := sorted_acquaintances(ui)
	center.add_child(ui.label("相 识  ·  %d 人" % known.size(), 26, ui.GOLD))
	var grid := GridContainer.new()
	grid.columns = 3
	grid.add_theme_constant_override("h_separation", 10)
	grid.add_theme_constant_override("v_separation", 8)
	center.add_child(grid)
	for person_id: String in known:
		var entry := acquaintance_button(ui, person_id)
		entry.size_flags_horizontal = Control.SIZE_EXPAND_FILL
		grid.add_child(entry)
	center.add_child(ui.button("返回", func() -> void: ui.set_view("place")))

## People here: handwritten first, then the first few others, with the rest behind 「更多」.
static func render_here(ui) -> void:
	var session = ui.session
	var center: VBoxContainer = ui.center
	var here: Array[String] = session.present_npcs()
	if here.is_empty():
		return
	var flow := HFlowContainer.new()
	flow.add_theme_constant_override("h_separation", 8)
	flow.add_theme_constant_override("v_separation", 6)
	center.add_child(flow)
	flow.add_child(ui.label("此地人物 · %d" % here.size(), 15, ui.GOLD))
	var shown := 0
	for person_id: String in here:
		var generated: bool = session.is_generated(person_id)
		if generated and not ui.show_everyone_here and shown >= PEOPLE_SHOWN_HERE:
			continue
		if generated:
			shown += 1
		var person: Dictionary = session.person(person_id)
		var hostile: bool = person.attitude == "hostile"
		var chip: Button = ui.button(("⚔ " if hostile else "") + person.name + " · " + person.title, func() -> void: ui.open_person(person_id), "查看资料与交互")
		if hostile:
			chip.add_theme_color_override("font_color", Color("#e39a82"))
		chip.disabled = person_id == ui.selected_npc
		flow.add_child(chip)
	var hidden: int = here.filter(func(person_id: String) -> bool: return session.is_generated(person_id)).size() - shown
	if hidden > 0:
		flow.add_child(ui.button("更多 · %d 人" % hidden, func() -> void:
			ui.show_everyone_here = true
			ui.render(), "显示此地的所有人"))

## Profile card: who they are, how they feel about you, and what you can do with them here.
static func render_person(ui, person_id: String) -> void:
	var session = ui.session
	var center: VBoxContainer = ui.center
	var person: Dictionary = session.person(person_id)
	var progress: Dictionary = session.world.people.get(person_id, {})
	var favor: int = session.favor(person_id)
	var where: String = session.npc_location(person_id)
	# Some people are met in a scene of their own (the storyteller on his stage, the rogue on the road).
	if where == session.player.location:
		var scene: TextureRect = ui.picture(ArtLibrary.person_art(person_id), 260)
		if scene != null:
			center.add_child(scene)
	var card := HBoxContainer.new()
	card.add_theme_constant_override("separation", 18)
	center.add_child(card)
	card.add_child(_portrait(ui, person_id, person))
	var info := VBoxContainer.new()
	info.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	card.add_child(info)
	info.add_child(ui.label("%s  ·  %s" % [person.name, person.title], 24, ui.GOLD))
	var attitude_color: Color = Color("#e39a82") if person.attitude == "hostile" else ui.INK
	info.add_child(ui.label("态度  %s" % session.content.ATTITUDES[person.attitude], 15, attitude_color))
	var grid := GridContainer.new()
	grid.columns = 2
	grid.add_theme_constant_override("h_separation", 24)
	info.add_child(grid)
	for pair: Array in [["境界", person.realm_text], ["出身", person.affiliation], ["年岁", "%d" % (int(person.age) + Calendar.year(int(session.world.day)) - 1)], ["性情", person.personality]]:
		grid.add_child(ui.label("%s  %s" % [pair[0], pair[1]], 15))
	if bool(progress.get("met", false)):
		ui.meter(info, "好感 · " + session.content.favor_stage(favor), maxi(favor, 0), session.content.FAVOR_MAX, ui.GOLD)
	else:
		info.add_child(ui.label("初次相见", 15, ui.MUTED))
	center.add_child(ui.paragraph(person.description, ui.INK))
	if str(ui.dialogue.get("npc", "")) == person_id:
		center.add_child(_dialogue_box(ui, person_id, person))
	if person.has("loadout"):
		var arts: Array[String] = []
		for art_id: String in person.loadout.arts:
			var art: Dictionary = session.content.technique(art_id)
			arts.append("%s（%s）" % [art.name, art.tier_name])
		var methods: Array[String] = []
		for method_id: String in person.loadout.methods:
			methods.append(session.content.technique(method_id).name)
		var gear: Array[String] = []
		for slot: String in person.loadout.equipment:
			if not str(person.loadout.equipment[slot]).is_empty():
				gear.append(session.content.equipment(person.loadout.equipment[slot]).name)
		center.add_child(ui.paragraph("神通 · %s\n心法 · %s%s" % ["、".join(arts), "、".join(methods), "\n法宝 · " + "、".join(gear) if not gear.is_empty() else ""]))
	if where != session.player.location:
		var place: String = session.content.locations[where].name if not where.is_empty() else "下落不明"
		center.add_child(ui.paragraph("此人现在 · " + place + "。须到当地才能与其交往。", ui.MUTED))
	var options := GridContainer.new()
	options.columns = 2
	options.add_theme_constant_override("h_separation", 12)
	options.add_theme_constant_override("v_separation", 10)
	center.add_child(options)
	if where == session.player.location:
		for option: Dictionary in session.npc_options(person_id):
			var option_id: String = option.id
			var choice: Button = ui.button(option.label, func() -> void: ui.run(func() -> String: return session.interact(person_id, option_id)), option.reason)
			choice.disabled = not option.available
			choice.size_flags_horizontal = Control.SIZE_EXPAND_FILL
			options.add_child(choice)
	elif not where.is_empty():
		var locate: Button = ui.button("在舆图上查看", func() -> void:
			ui.map_target = where
			ui.selected_npc = ""
			ui.set_view("map"))
		options.add_child(locate)
	options.add_child(ui.button("返回", ui.close_person))

## What was just said: the person's face and name beside their words.
static func _dialogue_box(ui, person_id: String, person: Dictionary) -> Control:
	var box := PanelContainer.new()
	box.add_theme_stylebox_override("panel", ui.style(Color("#18302f"), ui.GOLD, 12))
	var row := HBoxContainer.new()
	row.add_theme_constant_override("separation", 14)
	box.add_child(row)
	row.add_child(_portrait(ui, person_id, person, Vector2(64, 80)))
	var words := VBoxContainer.new()
	words.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	row.add_child(words)
	words.add_child(ui.label(person.name, 17, ui.GOLD))
	var speaker: String = person.name + "："
	for line: String in ui.dialogue.lines:
		words.add_child(ui.paragraph(line.trim_prefix(speaker), ui.INK))
	return box

static func _portrait(ui, person_id: String, person: Dictionary, size: Vector2 = Vector2(120, 150)) -> Control:
	var texture: Texture2D = ArtLibrary.local_texture(_local_portrait(ui, person_id))
	if texture == null:
		texture = ArtLibrary.texture(ArtLibrary.portrait_path(person_id))
	if texture != null:
		var image := TextureRect.new()
		image.texture = texture
		image.custom_minimum_size = size
		image.expand_mode = TextureRect.EXPAND_IGNORE_SIZE
		image.stretch_mode = TextureRect.STRETCH_KEEP_ASPECT_COVERED
		return image
	# Placeholder: an ink seal with the person's first character until portrait art exists.
	var seal := PanelContainer.new()
	seal.custom_minimum_size = size
	seal.add_theme_stylebox_override("panel", ui.style(Color("#1b3236"), Color("#e39a82") if person.attitude == "hostile" else ui.GOLD, 0))
	var initial: Label = ui.label(str(person.name).left(1), int(round(size.y * 56.0 / 150.0)), ui.GOLD)
	initial.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	initial.vertical_alignment = VERTICAL_ALIGNMENT_CENTER
	seal.add_child(initial)
	return seal

## A person's image from the local pack: their own file first, then their assigned pool image.
static func _local_portrait(ui, person_id: String) -> String:
	var session = ui.session
	var root: String = ui.portrait_root
	var own := ArtLibrary.find_image(root.path_join(person_id.replace(":", "_")))
	if not own.is_empty() or not person_id.begins_with("g:"):
		return own
	var index := ArtLibrary.pool_index(root)
	var key := "%d:%s" % [int(session.world.get("seed", 0)), str(index.hash())]
	if key != ui._pool_key:
		ui._pool_key = key
		ui._pool_assignments = {}
	if not ui._pool_assignments.has(person_id):
		ui._pool_assignments[person_id] = ArtLibrary.pick_portrait(person_id, session.person(person_id), int(session.world.get("seed", 0)), index)
	return str(ui._pool_assignments[person_id])
