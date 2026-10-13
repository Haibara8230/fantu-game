extends RefCounted
## People in the interface: the drawer of who is here, the 相识 list, facing a person (their portrait,
## what can be done with them, their details and what has passed between you — 人物志), portraits.
const Calendar = preload("res://scripts/core/calendar.gd")
const ArtLibrary = preload("res://scripts/ui/art_library.gd")
const TalentCards = preload("res://scripts/ui/talent_cards.gd")
const PEOPLE_SHOWN_HERE := 12
# How many of the latest chronicle entries about a person their profile shows.
const RECORD_ENTRIES := 6

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

## People here, in a drawer at the left edge of the scene: handwritten first, then the first few others
## with the rest behind 「更多」. Closed, only its tab shows.
static func render_drawer(ui, layer: Control) -> void:
	var session = ui.session
	var here: Array[String] = session.present_npcs()
	if here.is_empty():
		return
	if not ui.drawer_open:
		var tab: Button = ui.button("此\n地\n人\n物\n%d\n▶" % here.size(), ui.toggle_drawer, "展开此地人物")
		tab.anchor_top = 0.52
		tab.anchor_bottom = 0.52
		tab.offset_left = 0.0
		tab.add_theme_font_size_override("font_size", 15)
		layer.add_child(tab)
		return
	var drawer := PanelContainer.new()
	drawer.add_theme_stylebox_override("panel", ui.style(Color(0.04, 0.09, 0.1, 0.88), Color("#41615e"), 10))
	drawer.anchor_top = 0.52
	drawer.anchor_bottom = 1.0
	drawer.offset_right = 300.0
	# Room below for the latest records.
	drawer.offset_bottom = -130.0
	layer.add_child(drawer)
	var column := VBoxContainer.new()
	column.add_theme_constant_override("separation", 6)
	drawer.add_child(column)
	var header := HBoxContainer.new()
	column.add_child(header)
	var title: Label = ui.label("此地人物 · %d" % here.size(), 16, ui.GOLD)
	title.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	header.add_child(title)
	var fold: Button = ui.button("◀", ui.toggle_drawer, "收起")
	fold.custom_minimum_size = Vector2(36, 30)
	header.add_child(fold)
	var scroll := ScrollContainer.new()
	scroll.horizontal_scroll_mode = ScrollContainer.SCROLL_MODE_DISABLED
	scroll.size_flags_vertical = Control.SIZE_EXPAND_FILL
	column.add_child(scroll)
	var list := VBoxContainer.new()
	list.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	list.add_theme_constant_override("separation", 4)
	scroll.add_child(list)
	var shown := 0
	for person_id: String in here:
		var generated: bool = session.is_generated(person_id)
		if generated and not ui.show_everyone_here and shown >= PEOPLE_SHOWN_HERE:
			continue
		if generated:
			shown += 1
		var person: Dictionary = session.person(person_id)
		var hostile: bool = person.attitude == "hostile"
		var mark := "⚔ " if hostile else ("❗ " if beckons(ui, person_id) else "")
		var chip: Button = ui.button(mark + person.name + " · " + person.title, func() -> void: ui.open_person(person_id), "%s · 好感 %s" % [person.realm_text, session.content.favor_stage(session.favor(person_id))])
		chip.alignment = HORIZONTAL_ALIGNMENT_LEFT
		chip.custom_minimum_size.y = 36
		chip.add_theme_font_size_override("font_size", 14)
		if hostile:
			chip.add_theme_color_override("font_color", Color("#e39a82"))
		chip.disabled = person_id == ui.selected_npc
		list.add_child(chip)
	var hidden: int = here.filter(func(person_id: String) -> bool: return session.is_generated(person_id)).size() - shown
	if hidden > 0:
		list.add_child(ui.button("更多 · %d 人" % hidden, func() -> void:
			ui.show_everyone_here = true
			ui.render(), "显示此地的所有人"))

## Whether the person has something for the player now: a step of a story, the start of one, or a
## request for help (marked ❗ in the drawer).
static func beckons(ui, person_id: String) -> bool:
	for option: Dictionary in ui.session.npc_options(person_id):
		if option.available and is_errand(ui, person_id, str(option.id)):
			return true
	return false

## Whether an option is part of a story or a request rather than everyday dealings.
static func is_errand(ui, person_id: String, option_id: String) -> bool:
	if option_id in ["help", "invite_spar", "invite_help"]:
		return true
	if option_id == "talk":
		# A word with them is what a story's step asks for (a visit, an introduction).
		var session = ui.session
		if int(session.world.people.get(person_id, {}).get("talks", 0)) > 0:
			return false
		for story_id: String in session.content.storylines:
			var step: Dictionary = session.story_step(story_id)
			if not step.is_empty() and session.story_at(story_id, str(step.id)) and step.get("done", []).has({"talked": person_id}):
				return true
		return false
	for interaction: Dictionary in ui.session.person(person_id).get("interactions", []):
		if interaction.id == option_id:
			var keys: Array = []
			for entry: Dictionary in interaction.get("conditions", []) + interaction.get("effects", []):
				keys.append_array(entry.keys())
			return keys.any(func(key: String) -> bool: return key in ["story_at", "start_story", "story_advance"])
	return false

## Facing a person, after Mi Chang Sheng: their portrait large in the middle with their name, what can be
## done with them in two columns either side, what was just said below; 查看 opens who they are, their
## arts and what has passed between you.
static func render_person(ui, person_id: String) -> void:
	var session = ui.session
	var center: VBoxContainer = ui.center
	var person: Dictionary = session.person(person_id)
	var progress: Dictionary = session.world.people.get(person_id, {})
	var favor: int = session.favor(person_id)
	var where: String = session.npc_location(person_id)
	var here: bool = where == session.player.location
	# Some people are met in a scene of their own (the storyteller on his stage, the rogue on the road).
	if here:
		var scene: TextureRect = ui.picture(ArtLibrary.person_art(person_id), 200)
		if scene != null:
			center.add_child(scene)
	var stage := HBoxContainer.new()
	stage.alignment = BoxContainer.ALIGNMENT_CENTER
	stage.add_theme_constant_override("separation", 14)
	center.add_child(stage)
	var left := VBoxContainer.new()
	left.add_theme_constant_override("separation", 8)
	left.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	left.alignment = BoxContainer.ALIGNMENT_CENTER
	stage.add_child(left)
	var middle := VBoxContainer.new()
	middle.add_theme_constant_override("separation", 4)
	stage.add_child(middle)
	var frame := PanelContainer.new()
	frame.add_theme_stylebox_override("panel", ui.style(Color("#152a30"), Color("#e39a82") if person.attitude == "hostile" else ui.GOLD, 4))
	frame.add_child(_portrait(ui, person_id, person, Vector2(176, 220)))
	middle.add_child(frame)
	var name_label: Label = ui.label(person.name, 22, ui.GOLD)
	name_label.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	middle.add_child(name_label)
	var who: Label = ui.label("%s · %s\n%s · %s" % [person.title, person.realm_text, person.personality, session.content.ATTITUDES[person.attitude]], 14, ui.MUTED)
	who.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	middle.add_child(who)
	if bool(progress.get("met", false)):
		var bond: Label = ui.label("好感 · %s  %d" % [session.content.favor_stage(favor), favor], 15)
		bond.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
		middle.add_child(bond)
	else:
		middle.add_child(ui.label("初次相见", 15, ui.MUTED))
	var right := VBoxContainer.new()
	right.add_theme_constant_override("separation", 8)
	right.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	right.alignment = BoxContainer.ALIGNMENT_CENTER
	stage.add_child(right)
	var options: Array[Button] = []
	if here:
		for option: Dictionary in session.npc_options(person_id):
			var option_id: String = option.id
			var choice: Button = ui.button(option.label, func() -> void: ui.run(func() -> String: return session.interact(person_id, option_id)), option.reason)
			choice.disabled = not option.available
			if option_id == "fight":
				choice.add_theme_stylebox_override("normal", ui.style(Color("#5a2b26"), Color("#c9785f"), 10))
			elif option.available and is_errand(ui, person_id, option_id):
				choice.add_theme_stylebox_override("normal", ui.style(Color("#3a3524"), ui.GOLD, 10))
			options.append(choice)
	var half := (options.size() + 1) / 2
	for index: int in options.size():
		(left if index < half else right).add_child(options[index])
	right.add_child(ui.button("收起" if ui.profile_open else "查看", ui.toggle_profile, "此人的来历、功法与往来"))
	if not here and not where.is_empty():
		right.add_child(ui.button("在舆图上查看", func() -> void:
			ui.map_target = where
			ui.selected_npc = ""
			ui.set_view("map")))
	right.add_child(ui.button("离开", ui.close_person))
	if not here:
		var place: String = session.content.locations[where].name if not where.is_empty() else "下落不明"
		center.add_child(ui.paragraph("此人现在 · " + place + "。须到当地才能与其交往。", ui.MUTED))
	if str(ui.dialogue.get("npc", "")) == person_id:
		center.add_child(_dialogue_box(ui, person_id, person))
	if not ui.profile_open:
		return
	center.add_child(HSeparator.new())
	var grid := GridContainer.new()
	grid.columns = 2
	grid.add_theme_constant_override("h_separation", 24)
	center.add_child(grid)
	for pair: Array in [["境界", person.realm_text], ["出身", person.affiliation], ["年岁", "%d" % (int(person.age) + Calendar.year(int(session.world.day)) - 1)], ["性情", person.personality]]:
		grid.add_child(ui.label("%s  %s" % [pair[0], pair[1]], 15))
	center.add_child(ui.paragraph(person.description, ui.INK))
	_talents(ui, person_id)
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
	_record(ui, person_id, person)

## Someone's talents and 资质 once the player can see through them (acquainted, or above them), else a
## word that they cannot.
static func _talents(ui, person_id: String) -> void:
	var session = ui.session
	var born: Dictionary = session.talents_of(person_id)
	if not session.talents_visible(person_id):
		ui.center.add_child(ui.label("天赋 · 看不透（相熟之后，或修为高过此人，方能看出）", 15, ui.MUTED))
		return
	var row := HBoxContainer.new()
	row.add_theme_constant_override("separation", 12)
	ui.center.add_child(row)
	row.add_child(TalentCards.aptitude_label(ui, session.person_aptitude(person_id)))
	ui.center.add_child(TalentCards.row(ui, session.content, born))

## 人物志: when and where you met, what has passed between you, the person's life as far as it is
## known, and the latest chronicle entries about them.
static func _record(ui, person_id: String, person: Dictionary) -> void:
	var session = ui.session
	var progress: Dictionary = session.world.people.get(person_id, {})
	if not bool(progress.get("met", false)):
		return
	var center: VBoxContainer = ui.center
	center.add_child(HSeparator.new())
	center.add_child(ui.label("往 来", 16, ui.GOLD))
	var lines: Array[String] = []
	var met_day := int(progress.get("met_day", -1))
	var met_place: String = str(progress.get("met_place", ""))
	if met_day >= 0:
		var place: String = session.content.locations[met_place].name if session.content.locations.has(met_place) else ""
		lines.append("初识 · %s%s" % [Calendar.date_text(met_day), " · " + place if not place.is_empty() else ""])
	else:
		lines.append("初识 · 早年相识，未有记载")
	var dealings: Array[String] = []
	if int(progress.get("talks", 0)) > 0:
		dealings.append("交谈 %d 次" % int(progress.talks))
	var last: Dictionary = progress.get("last", {})
	for option_id: String in last:
		dealings.append("上回%s · %s" % [_option_name(person, option_id), Calendar.short_text(int(last[option_id]))])
	if not dealings.is_empty():
		lines.append("交往 · " + "；".join(dealings))
	if session.is_generated(person_id):
		lines.append("生平 · " + "；".join(_life(session, person_id)))
	center.add_child(ui.paragraph("\n".join(lines), ui.INK))
	# Entries the dialogue box above already shows (those since its action) are not repeated.
	var entries: Array[Dictionary] = session.chronicle.entries
	var before := entries.size()
	if str(ui.dialogue.get("npc", "")) == person_id:
		before -= clampi(int(session.chronicle.added) - int(ui.dialogue.get("mark", session.chronicle.added)), 0, entries.size())
	var mentions: Array = entries.slice(0, before).filter(func(entry: Dictionary) -> bool: return str(entry.args.get("npc", "")) == person_id)
	if mentions.is_empty():
		return
	center.add_child(ui.label("近 来", 15, ui.GOLD))
	var recent: Array = mentions.slice(-RECORD_ENTRIES)
	recent.reverse()
	for entry: Dictionary in recent:
		center.add_child(ui.paragraph("【%s】%s" % [Calendar.short_text(int(entry.day)), session.chronicle.format(entry, session.content)]))

static func _option_name(person: Dictionary, option_id: String) -> String:
	match option_id:
		"talk":
			return "交谈"
		"gift":
			return "赠礼"
		"help", "invite_help":
			return "相助"
		"consult":
			return "请教"
		"teach":
			return "求传功法"
		"invite_spar":
			return "赴约切磋"
	for interaction: Dictionary in person.get("interactions", []):
		if interaction.id == option_id:
			return str(interaction.label)
	return option_id

## A generated person's life up to today: birth, foundation, death.
static func _life(session, person_id: String) -> Array[String]:
	var life: Dictionary = session.life_by_id(person_id)
	var today := int(session.world.day)
	var birth := int(life.birth)
	var result: Array[String] = ["生于" + _year_text(birth)]
	if int(life.foundation_age) > 0:
		var foundation := birth + int(life.foundation_age) * Calendar.DAYS_PER_YEAR
		if foundation <= today:
			result.append(_year_text(foundation) + "筑基")
	if int(life.death) <= today:
		result.append("%s故去，享年 %d 岁" % [_year_text(int(life.death)), Calendar.age_years(birth, int(life.death))])
	return result

## A year in the era, or before it (generated people can be born before 历元 1 年).
static func _year_text(day: int) -> String:
	if day >= 0:
		return "%s %d 年" % [Calendar.ERA, Calendar.year(day)]
	return "%s前 %d 年" % [Calendar.ERA, 1 + (-day - 1) / Calendar.DAYS_PER_YEAR]

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
	var delay := 0.0
	for index: int in range(ui.dialogue.lines.size()):
		var line: Label = ui.paragraph(str(ui.dialogue.lines[index]).trim_prefix(speaker), ui.INK)
		words.add_child(line)
		delay = ui.type_out(line, "dialogue|%d|%d" % [int(ui.dialogue.get("mark", 0)), index], delay)
	return box

static func _portrait(ui, person_id: String, person: Dictionary, size: Vector2 = Vector2(120, 150)) -> Control:
	var local_path := _local_portrait(ui, person_id)
	var texture: Texture2D = ArtLibrary.local_texture(local_path)
	var preferred := ArtLibrary.preferred_portrait_path(person_id)
	if not preferred.is_empty() and (texture == null or ArtLibrary.placeholder_portrait(person_id, local_path)):
		var painted := ArtLibrary.texture(preferred)
		if painted != null:
			texture = painted
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
