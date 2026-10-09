extends Control
const Session = preload("res://scripts/core/session.gd")
const SaveStore = preload("res://scripts/core/save_store.gd")
const Landscape = preload("res://scripts/ui/landscape.gd")
const BattleStage = preload("res://scripts/presentation/battle_stage.gd")
const Calendar = preload("res://scripts/core/calendar.gd")
const WorldMap = preload("res://scripts/ui/world_map.gd")
const AudioDirector = preload("res://scripts/presentation/audio_director.gd")
const ArtLibrary = preload("res://scripts/ui/art_library.gd")
const GOLD := Color("#d5b777")
const INK := Color("#e3e8dc")
const MUTED := Color("#97aaa4")
var session = Session.new()
var manual_store = SaveStore.new("user://saves/manual")
var auto_store = SaveStore.new("user://saves/auto")
var started := false
var autosave_error := ""
var stats: VBoxContainer
var center: VBoxContainer
var view := "place"
var selected_spot := ""
# The person whose profile is open in the centre panel ("" when none).
var selected_npc := ""
var shown_location := ""
var welcome_roots: Array = []
# Local, never-committed portrait pack (see ArtLibrary); tests point this elsewhere.
var portrait_root := ArtLibrary.LOCAL_PORTRAITS
var _pool_assignments := {}
var _pool_key := ""
var roots_label: Label
var map_target := ""
var world_map
var audio
var settings_dialog: AcceptDialog
var view_buttons: Dictionary = {}
var journey_button: Button
var journal_text: RichTextLabel
var status_label: Label
var clock_label: Label
var load_button: Button
var welcome_layer: ColorRect
var name_input: LineEdit
var new_game_dialog: ConfirmationDialog
var battle_stage
var presenting := false
var locked_buttons: Array[Dictionary] = []
var preview_mode := false
var preview_opponent := "qingyun"

func _ready() -> void:
	get_window().min_size = Vector2i(1000, 640)
	_build_theme()
	audio = AudioDirector.new()
	add_child(audio)
	_build_layout()
	if not session.content.error_message.is_empty():
		notice(session.content.error_message)
		return
	session.new_game()
	session.changed.connect(_on_changed)
	_render()
	preview_mode = "--art-preview" in OS.get_cmdline_user_args() or "--sect-preview" in OS.get_cmdline_user_args()
	if preview_mode:
		manual_store = SaveStore.new("user://art_preview/manual")
		auto_store = SaveStore.new("user://art_preview/auto")
		started = true
		_reset_preview()
	else:
		_show_welcome()

func _build_theme() -> void:
	var game_theme := Theme.new()
	var font := SystemFont.new()
	font.font_names = PackedStringArray(["Microsoft YaHei", "Noto Sans CJK SC", "SimHei"])
	game_theme.default_font = font
	game_theme.default_font_size = 17
	game_theme.set_color("font_color", "Label", INK)
	game_theme.set_color("default_color", "RichTextLabel", INK)
	game_theme.set_color("font_color", "Button", INK)
	game_theme.set_color("font_hover_color", "Button", Color("#ffffff"))
	game_theme.set_color("font_disabled_color", "Button", Color("#6d807b"))
	game_theme.set_stylebox("normal", "Button", _style(Color("#213b3f"), Color("#41615e"), 10))
	game_theme.set_stylebox("hover", "Button", _style(Color("#305451"), GOLD, 10))
	game_theme.set_stylebox("pressed", "Button", _style(Color("#152b2f"), GOLD, 10))
	game_theme.set_stylebox("disabled", "Button", _style(Color("#182b30"), Color("#2b4445"), 10))
	game_theme.set_stylebox("focus", "Button", _style(Color(0, 0, 0, 0), GOLD, 10))
	game_theme.set_color("font_color", "LineEdit", INK)
	game_theme.set_stylebox("normal", "LineEdit", _style(Color("#14282c"), Color("#41615e"), 10))
	game_theme.set_stylebox("focus", "LineEdit", _style(Color("#14282c"), GOLD, 10))
	game_theme.set_stylebox("panel", "PopupMenu", _style(Color("#152a30"), GOLD, 10))
	theme = game_theme

func _style(fill: Color, border: Color, padding: float) -> StyleBoxFlat:
	var box := StyleBoxFlat.new()
	box.bg_color = fill
	box.border_color = border
	box.set_border_width_all(1)
	box.set_corner_radius_all(5)
	box.content_margin_left = padding
	box.content_margin_right = padding
	box.content_margin_top = padding
	box.content_margin_bottom = padding
	return box

func _label(text_value: String, font_size: int = 17, color: Color = INK) -> Label:
	var label := Label.new()
	label.text = text_value
	label.add_theme_font_size_override("font_size", font_size)
	label.add_theme_color_override("font_color", color)
	return label

func _paragraph(text_value: String, color: Color = MUTED) -> Label:
	var label := _label(text_value, 16, color)
	label.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	return label

func _button(text_value: String, callback: Callable, tooltip: String = "") -> Button:
	var button := Button.new()
	button.text = text_value
	button.tooltip_text = tooltip
	button.custom_minimum_size.y = 42
	button.mouse_default_cursor_shape = Control.CURSOR_POINTING_HAND
	button.pressed.connect(func() -> void: audio.cue("click"))
	button.pressed.connect(callback)
	return button

func _panel() -> PanelContainer:
	var panel := PanelContainer.new()
	panel.add_theme_stylebox_override("panel", _style(Color("#112329"), Color("#304749"), 18))
	return panel

func _build_layout() -> void:
	var margin := MarginContainer.new()
	margin.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	margin.add_theme_constant_override("margin_left", 24)
	margin.add_theme_constant_override("margin_right", 24)
	margin.add_theme_constant_override("margin_top", 20)
	margin.add_theme_constant_override("margin_bottom", 16)
	add_child(margin)
	var page := VBoxContainer.new()
	page.add_theme_constant_override("separation", 14)
	margin.add_child(page)
	var header := HBoxContainer.new()
	header.add_theme_constant_override("separation", 12)
	page.add_child(header)
	header.add_child(_label("凡 途", 32, GOLD))
	header.add_child(_label("修仙纪事", 16, MUTED))
	var spacer := Control.new()
	spacer.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	header.add_child(spacer)
	clock_label = _label("", 16, GOLD)
	header.add_child(clock_label)
	view_buttons.place = _button("此地", func() -> void: _set_view("place"))
	header.add_child(view_buttons.place)
	view_buttons.map = _button("舆图", func() -> void: _set_view("map"))
	header.add_child(view_buttons.map)
	view_buttons.bag = _button("行囊", func() -> void: _set_view("bag"))
	header.add_child(view_buttons.bag)
	view_buttons.arts = _button("功法", func() -> void: _set_view("arts"))
	header.add_child(view_buttons.arts)
	header.add_child(_button("保存 F5", _save_manual))
	load_button = _button("读取 F9", _load_manual)
	header.add_child(load_button)
	header.add_child(_button("新旅程", _ask_new_game))
	header.add_child(_button("设置", _open_settings))
	var body := HBoxContainer.new()
	body.size_flags_vertical = Control.SIZE_EXPAND_FILL
	body.add_theme_constant_override("separation", 16)
	page.add_child(body)
	var sidebar := _panel()
	sidebar.custom_minimum_size.x = 258
	body.add_child(sidebar)
	stats = VBoxContainer.new()
	stats.add_theme_constant_override("separation", 8)
	var sidebar_scroll := ScrollContainer.new()
	sidebar_scroll.horizontal_scroll_mode = ScrollContainer.SCROLL_MODE_DISABLED
	sidebar.add_child(sidebar_scroll)
	stats.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	sidebar_scroll.add_child(stats)
	var main_panel := _panel()
	main_panel.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	body.add_child(main_panel)
	var scroll := ScrollContainer.new()
	scroll.horizontal_scroll_mode = ScrollContainer.SCROLL_MODE_DISABLED
	main_panel.add_child(scroll)
	center = VBoxContainer.new()
	center.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	center.add_theme_constant_override("separation", 10)
	scroll.add_child(center)
	var log_panel := _panel()
	log_panel.custom_minimum_size.y = 140
	page.add_child(log_panel)
	var log_box := VBoxContainer.new()
	log_panel.add_child(log_box)
	log_box.add_child(_label("修 行 手 记", 16, GOLD))
	journal_text = RichTextLabel.new()
	journal_text.bbcode_enabled = false
	journal_text.scroll_following = true
	journal_text.size_flags_vertical = Control.SIZE_EXPAND_FILL
	journal_text.add_theme_font_size_override("normal_font_size", 15)
	log_box.add_child(journal_text)
	status_label = _label("鼠标选择行动 · F5 保存 · F9 读取 · 斗法中按 1 / 2 / 3 施法，空格守御", 14, MUTED)
	status_label.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	page.add_child(status_label)
	new_game_dialog = ConfirmationDialog.new()
	new_game_dialog.title = "开启新旅程"
	new_game_dialog.dialog_text = "新旅程会替换自动存档。手动存档将保留，直到你再次手动保存。"
	new_game_dialog.ok_button_text = "开启新旅程"
	new_game_dialog.cancel_button_text = "返回"
	new_game_dialog.confirmed.connect(_show_welcome)
	add_child(new_game_dialog)
	_build_settings()

func _clear(container: Node) -> void:
	for child: Node in container.get_children():
		container.remove_child(child)
		child.queue_free()

func _meter(parent: VBoxContainer, title: String, value: float, maximum: float, color: Color) -> void:
	parent.add_child(_label("%s    %d / %d" % [title, value, maximum], 15, MUTED))
	var bar := ProgressBar.new()
	bar.show_percentage = false
	bar.max_value = maximum
	bar.value = value
	bar.custom_minimum_size.y = 8
	bar.add_theme_stylebox_override("background", _style(Color("#1d3539"), Color("#1d3539"), 0))
	bar.add_theme_stylebox_override("fill", _style(color, color, 0))
	parent.add_child(bar)

func _render() -> void:
	if session.player.is_empty():
		return
	var p: Dictionary = session.player
	clock_label.text = session.time_name()
	if p.location != shown_location:
		shown_location = p.location
		selected_npc = ""
	_clear(stats)
	stats.add_child(_label(p.name, 25))
	stats.add_child(_label(session.realm_name(), 18, GOLD))
	stats.add_child(_label(session.content.sects[session.player.get("sect", "wanderer")].name, 16, MUTED))
	_meter(stats, "气血", p.hp, p.max_hp, Color("#a96f66"))
	_meter(stats, "灵力", p.qi, p.max_qi, Color("#5f999b"))
	stats.add_child(_label("年岁 %d  ·  寿元 %d" % [session.age(), session.lifespan()], 15, MUTED))
	stats.add_child(_label("灵根 · %s · 修炼 ×%.2f" % [session.root_title(), session.cultivation_speed()], 14, MUTED))
	_meter(stats, "修为", p.xp, maxi(1, maxi(int(p.xp), _xp_goal())), GOLD)
	stats.add_child(_label("灵石  %d    灵草  %d    筑基丹  %d" % [p.stones, session.herb_count(), session.item_count("foundation_pill")], 15))
	_render_quests()
	_render_acquaintances()
	_render_upcoming()
	stats.add_child(HSeparator.new())
	stats.add_child(_label("山 川 行 旅", 16, GOLD))
	stats.add_child(_label("身在 · " + session.content.locations[p.location].name, 15))
	journey_button = null
	if not p.journey.is_empty():
		var destination: String = session.content.locations[p.journey.to].name
		var remaining: int = session.content.path_days(session.path_to(p.journey.to))
		stats.add_child(_paragraph("行程未竟 · 前往%s，尚余约 %d 日" % [destination, remaining], INK))
		journey_button = _button("继续赶路", func() -> void: _run(session.continue_journey), "沿原定路线继续前进")
		journey_button.disabled = not _settled()
		stats.add_child(journey_button)
	var open_map := _button("展开舆图", func() -> void: _set_view("map"), "选择目的地，查看路程与危险")
	open_map.disabled = not _settled()
	stats.add_child(open_map)
	load_button.disabled = not manual_store.has_save()
	view_buttons.place.disabled = view == "place"
	view_buttons.map.disabled = view == "map" or not _settled()
	view_buttons.bag.disabled = view == "bag"
	view_buttons.arts.disabled = view == "arts"
	_clear(center)
	if not session.ended.is_empty():
		_render_ending()
	elif not session.pending_event.is_empty():
		_render_event()
	elif not session.battle.is_empty():
		_render_battle()
	elif view == "map":
		_render_map()
	elif view == "bag":
		_render_bag()
	elif view == "arts":
		_render_arts()
	else:
		_render_location()
	_update_audio()
	journal_text.text = "\n".join(session.journal_lines())

func _objective() -> String:
	if session.has_flag("serpent_slain"):
		return "落霞谷灵泉已复。世事仍在流转，你可以继续修炼与游历。"
	var need: Dictionary = session.next_breakthrough()
	if need.is_empty():
		return "当前目标 · 休整后前往落霞谷，平定赤鳞妖蟒。"
	return "当前目标 · 修至%s，积攒 %d 修为与 %d 枚筑基丹，在青云山突破。" % [session.content.realm_title(int(session.player.realm), session.content.realm(int(session.player.realm)).stages.size() - 1), int(need.xp), int(need.pills)]

## The next xp milestone: the next sub-stage, or the breakthrough once at the last stage.
func _xp_goal() -> int:
	var stages: Array = session.content.realm(int(session.player.realm)).stages
	if int(session.player.stage) + 1 < stages.size():
		return int(stages[int(session.player.stage) + 1].xp)
	return int(session.next_breakthrough().get("xp", 0))

func _duration(action: String) -> String:
	return Calendar.duration_text(session.content.action_days(action))

func _breakthrough_tooltip() -> String:
	var need: Dictionary = session.next_breakthrough()
	if need.is_empty():
		return "后续境界尚未开放"
	return "需修至%s，并有 %d 修为与 %d 枚筑基丹" % [session.content.realm_title(int(session.player.realm), session.content.realm(int(session.player.realm)).stages.size() - 1), int(need.xp), int(need.pills)]

func _realm_bonus_text() -> String:
	var bonus: int = session.attack_bonus()
	return " 境界加成：攻击伤害 +%d。" % bonus if bonus > 0 else ""

func _render_location() -> void:
	if preview_mode:
		_sect_choices(center, true)
	var location_id: String = session.player.location
	var location: Dictionary = session.content.locations[location_id]
	var title_row := HBoxContainer.new()
	title_row.add_theme_constant_override("separation", 20)
	center.add_child(title_row)
	title_row.add_child(_label(location.name, 30, GOLD))
	title_row.add_child(_label(location.subtitle, 16, MUTED))
	center.add_child(_paragraph(location.description))
	center.add_child(_paragraph(_objective(), GOLD))
	_render_people_here()
	if not selected_npc.is_empty():
		_render_person(selected_npc)
		return
	# Second-level scenes: each spot has its own banner, text and actions; moving between them is free.
	var spots := _open_spots(location_id)
	if not spots.any(func(spot: Dictionary) -> bool: return spot.id == selected_spot):
		selected_spot = spots[0].id
	var tabs := HBoxContainer.new()
	tabs.add_theme_constant_override("separation", 8)
	center.add_child(tabs)
	var spot: Dictionary = {}
	for candidate: Dictionary in spots:
		var spot_id: String = candidate.id
		var tab := _button(candidate.name, func() -> void: _select_spot(spot_id))
		tab.disabled = spot_id == selected_spot
		tabs.add_child(tab)
		if spot_id == selected_spot:
			spot = candidate
	var landscape = Landscape.new()
	landscape.location_id = location_id
	landscape.terrain = location.terrain
	landscape.spot_id = spot.id
	landscape.custom_minimum_size.y = 190
	center.add_child(landscape)
	center.add_child(_paragraph(spot.description, INK))
	var grid := GridContainer.new()
	grid.columns = 2
	grid.add_theme_constant_override("h_separation", 12)
	grid.add_theme_constant_override("v_separation", 10)
	center.add_child(grid)
	for action: String in spot.actions:
		_spot_action(grid, action)
	for days: Variant in session.content.rules.wait_options:
		var span := int(days)
		_timed(grid, "停留  ·  " + Calendar.duration_text(span), func() -> String: return session.wait(span), "原地停留，等候时机；约定临近时会提醒")
	if "study" in spot.actions and not preview_mode:
		_sect_choices(center, false)
	var names: Array[String] = []
	for id: String in session.active_skills():
		names.append(session.content.skills[id].name)
	center.add_child(_paragraph("已习神通 · " + " / ".join(names) + "。悬停神通按钮可查看效果。"))

# --- People ------------------------------------------------------------------------

## Acquaintances with where they are now; clicking opens their profile.
func _render_acquaintances() -> void:
	var known: Array[String] = session.known_npcs()
	if known.is_empty():
		return
	stats.add_child(_label("相 识", 15, GOLD))
	for person_id: String in known:
		var person: Dictionary = session.content.people[person_id]
		var where: String = session.npc_location(person_id)
		var place: String = session.content.locations[where].name if not where.is_empty() else "下落不明"
		var favor: int = session.favor(person_id)
		var entry := _button("%s · %s\n%s · %s %d" % [person.name, place, person.title, session.content.favor_stage(favor), favor], func() -> void: _open_person(person_id), "查看资料")
		entry.alignment = HORIZONTAL_ALIGNMENT_LEFT
		entry.add_theme_font_size_override("font_size", 14)
		stats.add_child(entry)

func _render_quests() -> void:
	if session.player.get("quests", []).is_empty():
		return
	stats.add_child(_label("委 托", 15, GOLD))
	for quest: Dictionary in session.player.quests:
		var progress := ""
		if quest.has("enemy"):
			progress = " %d/%d" % [int(quest.progress), int(quest.count)]
		elif quest.has("item"):
			progress = " %d/%d" % [mini(session.item_count(quest.item), int(quest.count)), int(quest.count)]
		var label := _label("%s%s
限 %s · %s" % [session.commission_text(quest).title, progress, Calendar.short_text(int(quest.deadline)), session.content.commission_data.boards[quest.board].name], 14)
		label.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
		stats.add_child(label)

func _render_people_here() -> void:
	var here: Array[String] = session.present_npcs()
	if here.is_empty():
		return
	var row := HBoxContainer.new()
	row.add_theme_constant_override("separation", 8)
	center.add_child(row)
	row.add_child(_label("此地人物", 15, GOLD))
	for person_id: String in here:
		var person: Dictionary = session.content.people[person_id]
		var hostile: bool = person.attitude == "hostile"
		var chip := _button(("⚔ " if hostile else "") + person.name + " · " + person.title, func() -> void: _open_person(person_id), "查看资料与交互")
		if hostile:
			chip.add_theme_color_override("font_color", Color("#e39a82"))
		chip.disabled = person_id == selected_npc
		row.add_child(chip)

func _open_person(person_id: String) -> void:
	if presenting:
		return
	selected_npc = person_id
	view = "place"
	audio.cue("page")
	_render()

func _close_person() -> void:
	selected_npc = ""
	_render()

## Profile card: who they are, how they feel about you, and what you can do with them here.
func _render_person(person_id: String) -> void:
	var person: Dictionary = session.content.people[person_id]
	var progress: Dictionary = session.world.people.get(person_id, {})
	var favor: int = session.favor(person_id)
	var card := HBoxContainer.new()
	card.add_theme_constant_override("separation", 18)
	center.add_child(card)
	card.add_child(_portrait(person_id, person))
	var info := VBoxContainer.new()
	info.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	card.add_child(info)
	info.add_child(_label("%s  ·  %s" % [person.name, person.title], 24, GOLD))
	var attitude_color := Color("#e39a82") if person.attitude == "hostile" else INK
	info.add_child(_label("态度  %s" % session.content.ATTITUDES[person.attitude], 15, attitude_color))
	var grid := GridContainer.new()
	grid.columns = 2
	grid.add_theme_constant_override("h_separation", 24)
	info.add_child(grid)
	for pair: Array in [["境界", person.realm_text], ["出身", person.affiliation], ["年岁", "%d" % (int(person.age) + Calendar.year(int(session.world.day)) - 1)], ["性情", person.personality]]:
		grid.add_child(_label("%s  %s" % [pair[0], pair[1]], 15))
	if bool(progress.get("met", false)):
		_meter(info, "好感 · " + session.content.favor_stage(favor), maxi(favor, 0), session.content.FAVOR_MAX, GOLD)
	else:
		info.add_child(_label("初次相见", 15, MUTED))
	center.add_child(_paragraph(person.description, INK))
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
		center.add_child(_paragraph("神通 · %s
心法 · %s%s" % ["、".join(arts), "、".join(methods), "
法宝 · " + "、".join(gear) if not gear.is_empty() else ""]))
	var where: String = session.npc_location(person_id)
	if where != session.player.location:
		var place: String = session.content.locations[where].name if not where.is_empty() else "下落不明"
		center.add_child(_paragraph("此人现在 · " + place + "。须到当地才能与其交往。", MUTED))
	var options := GridContainer.new()
	options.columns = 2
	options.add_theme_constant_override("h_separation", 12)
	options.add_theme_constant_override("v_separation", 10)
	center.add_child(options)
	if where == session.player.location:
		for option: Dictionary in session.npc_options(person_id):
			var option_id: String = option.id
			var button := _button(option.label, func() -> void: _run(func() -> String: return session.interact(person_id, option_id)), option.reason)
			button.disabled = not option.available
			button.size_flags_horizontal = Control.SIZE_EXPAND_FILL
			options.add_child(button)
	elif not where.is_empty():
		var locate := _button("在舆图上查看", func() -> void:
			map_target = where
			selected_npc = ""
			_set_view("map"))
		options.add_child(locate)
	options.add_child(_button("返回", _close_person))

func _portrait(person_id: String, person: Dictionary) -> Control:
	var texture: Texture2D = ArtLibrary.local_texture(_local_portrait(person_id))
	if texture == null:
		texture = ArtLibrary.texture(ArtLibrary.portrait_path(person_id))
	if texture != null:
		var image := TextureRect.new()
		image.texture = texture
		image.custom_minimum_size = Vector2(120, 150)
		image.expand_mode = TextureRect.EXPAND_IGNORE_SIZE
		image.stretch_mode = TextureRect.STRETCH_KEEP_ASPECT_COVERED
		return image
	# Placeholder: an ink seal with the person's first character until portrait art exists.
	var seal := PanelContainer.new()
	seal.custom_minimum_size = Vector2(120, 150)
	seal.add_theme_stylebox_override("panel", _style(Color("#1b3236"), Color("#e39a82") if person.attitude == "hostile" else GOLD, 0))
	var initial := _label(str(person.name).left(1), 56, GOLD)
	initial.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	initial.vertical_alignment = VERTICAL_ALIGNMENT_CENTER
	seal.add_child(initial)
	return seal

## A person's image from the local pack: their own file first, then their assigned pool image.
func _local_portrait(person_id: String) -> String:
	var own := ArtLibrary.find_image(portrait_root.path_join(person_id.replace(":", "_")))
	if not own.is_empty() or not person_id.begins_with("g:"):
		return own
	var index := ArtLibrary.pool_index(portrait_root)
	var key := "%d:%s" % [int(session.world.get("seed", 0)), str(index.hash())]
	if key != _pool_key:
		_pool_key = key
		_pool_assignments = ArtLibrary.assign_pool(session.content.people, int(session.world.get("seed", 0)), index)
	return str(_pool_assignments.get(person_id, ""))

func _open_spots(location_id: String) -> Array[Dictionary]:
	var result: Array[Dictionary] = []
	for spot: Dictionary in session.content.locations[location_id].spots:
		if not spot.has("requires_flag") or session.has_flag(spot.requires_flag):
			result.append(spot)
	if result.is_empty():
		result.append({"id": "", "name": "此地", "description": "", "actions": []})
	return result

func _select_spot(spot_id: String) -> void:
	selected_spot = spot_id
	audio.cue("page")
	_render()

func _spot_action(grid: GridContainer, action: String) -> void:
	var rules: Dictionary = session.content.rules
	if action.begins_with("battle:"):
		var enemy_id := action.trim_prefix("battle:")
		var enemy: Dictionary = session.content.enemies[enemy_id]
		var tooltip := "获胜得 %d 灵石、%d 修为、%d 灵草，斗法有受伤风险" % [enemy.reward_stones, enemy.reward_xp, enemy.reward_herbs]
		if int(enemy.min_realm) > 0:
			tooltip = "需达到%s。" % session.content.realm_title(int(enemy.min_realm), 0) + tooltip
		var button := _enemy_action(grid, ("切磋 · " if enemy_id == "disciple" else "挑战 · ") + enemy.name, enemy_id, tooltip)
		button.disabled = int(session.player.realm) < int(enemy.min_realm) or (enemy.has("world_flag") and session.has_flag(enemy.world_flag))
		return
	match action:
		"cultivate":
			for days: Variant in rules.cultivate_options:
				var span := int(days)
				var gain := span * session.cultivation_rate() / Calendar.DAYS_PER_MONTH
				_timed(grid, "闭关  ·  " + Calendar.duration_text(span), func() -> String: return session.cultivate(span), "修为约 +%d，恢复全部灵力；约定或寿元告急时会提前出关" % gain)
		"rest":
			_action(grid, "静室休整  ·  " + Calendar.duration_text(session.rest_days()), "rest", "恢复全部气血与灵力；伤得越重，需要的日子越长")
		"breakthrough":
			_action(grid, "突破境界  ·  " + _duration("breakthrough"), "breakthrough", _breakthrough_tooltip())
		"sell":
			_action(grid, "全部出售", "sell", "把这里收购的东西全部卖掉，不耗时日")
			for item_id: String in session.player.items.keys():
				var price: int = session.sell_price(item_id)
				if price > 0:
					var sold := item_id
					_timed(grid, "出售%s（%d）· 每件 %d" % [session.content.item(item_id).name, session.item_count(item_id), price], func() -> String: return session.sell(sold, 1), session.content.item(item_id).description)
		"shop":
			for good: Dictionary in session.shop_goods():
				var bought: String = good.item
				_timed(grid, "购买%s  ·  %d 灵石" % [session.content.item(bought).name, int(good.price)], func() -> String: return session.buy(bought), session.content.item(bought).description)
		"gather":
			var gather: Dictionary = session.content.locations[session.player.location].gather
			var kinds: Array[String] = []
			for entry: Dictionary in gather.table:
				kinds.append(session.content.item(entry.item).name)
			_action(grid, "采集灵草  ·  " + _duration("gather"), "gather", "采得 %d–%d 株，此地出产：%s" % [int(gather.picks[0]), int(gather.picks[1]), "、".join(kinds)])
		"inn_rest":
			_action(grid, "客栈歇息  ·  %s · %d 灵石" % [_duration("inn_rest"), int(rules.inn_price)], "inn_rest", "恢复全部气血与灵力")
		"search_ruin":
			_action(grid, "翻找石室  ·  " + _duration("search_ruin"), "search_ruin", "或得灵石、灵草，偶有丹药；搜过后需隔些时日")
		"study":
			pass
		"inquire":
			var cost: Dictionary = session.content.rules.inquire
			_timed(grid, "打听消息  ·  %s · %d 灵石" % [Calendar.duration_text(int(cost.days)), int(cost.price)], session.inquire, "请人喝壶茶，听听最近的消息：人物去向、宝物、委托与世事。")
		"commissions":
			var board: String = session.board_here()
			for offer: Dictionary in session.commission_offers(board):
				var shown: Dictionary = session.commission_text(offer)
				var key: String = offer.key
				_timed(grid, "接下：%s（灵石 %d%s）" % [shown.title, int(offer.reward.stones), "、修为 %d" % int(offer.reward.xp) if int(offer.reward.xp) > 0 else ""], func() -> String: return session.accept_commission(key), shown.text)
			for quest: Dictionary in session.player.quests:
				if quest.board != board:
					continue
				var reason: String = session.delivery_block(quest)
				var handed: String = quest.key
				var deliver := _button("交付：%s" % session.commission_text(quest).title, func() -> void: _run(func() -> String: return session.deliver_commission(handed)), reason)
				deliver.disabled = not reason.is_empty()
				deliver.size_flags_horizontal = Control.SIZE_EXPAND_FILL
				grid.add_child(deliver)
		"teach":
			for technique_id: String in session.teachings():
				var taught: Dictionary = session.content.technique(technique_id)
				var reason: String = session.learn_block(technique_id)
				var learned_id := technique_id
				var button := _button("参悟%s  ·  %s · %d 日" % [taught.name, taught.tier_name, int(taught.study_days)], func() -> void: _run(func() -> String: return session.learn_here(learned_id)), reason if not reason.is_empty() else taught.description)
				button.disabled = not reason.is_empty()
				button.size_flags_horizontal = Control.SIZE_EXPAND_FILL
				grid.add_child(button)

## Map view: pick a node to see the route, days and danger, then set out.
func _render_map() -> void:
	world_map = WorldMap.new()
	world_map.custom_minimum_size.y = 430
	world_map.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	center.add_child(world_map)
	var path: Array[String] = []
	if not map_target.is_empty() and map_target != session.player.location:
		path = session.path_to(map_target)
	var people_at := {}
	for person_id: String in session.known_npcs():
		var where: String = session.npc_location(person_id)
		if not where.is_empty():
			if not people_at.has(where):
				people_at[where] = []
			people_at[where].append(session.content.people[person_id].name)
	world_map.configure(session.content, session.world.flags, session.player.location, map_target, path, str(session.player.journey.get("to", "")), people_at)
	world_map.location_selected.connect(_select_map_target)
	if map_target.is_empty() or not session.location_visible(map_target):
		center.add_child(_paragraph("点选舆图上的地点，查看路线与危险。路上每段都可能有遭遇，境界越高越少受扰。", MUTED))
		return
	var target: Dictionary = session.content.locations[map_target]
	center.add_child(_label("%s  ·  %s" % [target.name, target.subtitle], 20, GOLD))
	center.add_child(_paragraph(target.description))
	if map_target == session.player.location:
		center.add_child(_paragraph("你就在此地。", INK))
		return
	if path.is_empty():
		center.add_child(_paragraph("眼下没有通往此地的路。", INK))
		return
	var names: Array[String] = []
	var worst := 0
	for index: int in path.size():
		names.append(session.content.locations[path[index]].name)
		if index > 0:
			worst = maxi(worst, int(session.content.route_between(path[index - 1], path[index]).danger))
	var danger_names := ["太平", "略有风险", "颇为凶险", "九死一生"]
	center.add_child(_paragraph("路线 · %s\n共 %d 日 · 沿途%s" % [" → ".join(names), session.content.path_days(path), danger_names[worst]], INK))
	var go := _button("启程前往" + target.name, func() -> void: _depart(map_target))
	go.disabled = not _settled()
	center.add_child(go)

## 功法: arts and 心法 in their slots, everything learned, worn equipment and the resulting stats.
func _render_arts() -> void:
	center.add_child(_label("功 法", 26, GOLD))
	var extra: Dictionary = session.bonuses()
	var elements: Array[String] = []
	for element: String in extra.element_damage:
		var label: String = "全属性" if element == "*" else session.content.technique_data.elements[element].name
		elements.append("%s +%d%%" % [label, int(round(float(extra.element_damage[element]) * 100.0))])
	center.add_child(_paragraph("攻击加成 +%d · 受伤 -%d%% · 修炼 ×%.2f%s" % [session.attack_bonus(), int(round(session.defense() * 100.0)), session.cultivation_speed(), " · " + "，".join(elements) if not elements.is_empty() else ""], INK))
	var rules: Dictionary = session.content.rules
	for group: Array in [["art", "主动神通", session.player.arts, int(rules.art_slots)], ["method", "心法", session.player.methods, int(rules.method_slots)]]:
		center.add_child(_label("%s  %d / %d" % [group[1], group[2].size(), group[3]], 17, GOLD))
		for technique_id: String in group[2]:
			_technique_row(technique_id, true)
	var idle: Array = session.player.learned.filter(func(technique_id: String) -> bool: return not technique_id in session.player.arts and not technique_id in session.player.methods)
	if not idle.is_empty():
		center.add_child(_label("已习得", 17, GOLD))
		for technique_id: String in idle:
			_technique_row(technique_id, false)
	center.add_child(_label("法 宝", 17, GOLD))
	for slot: String in session.content.equipment_data.slots:
		var worn: String = str(session.player.equipment.get(slot, ""))
		var row := HBoxContainer.new()
		row.add_theme_constant_override("separation", 10)
		center.add_child(row)
		var slot_label := _label(session.content.equipment_data.slots[slot], 16, MUTED)
		slot_label.custom_minimum_size.x = 60
		row.add_child(slot_label)
		if worn.is_empty():
			row.add_child(_label("未佩戴", 15, MUTED))
			continue
		var gear: Dictionary = session.content.equipment(worn)
		var text := _paragraph("%s · %s" % [gear.name, gear.description], INK)
		text.size_flags_horizontal = Control.SIZE_EXPAND_FILL
		row.add_child(text)
		var taken := slot
		row.add_child(_button("取下", func() -> void: _run(func() -> String: return session.unequip_slot(taken))))
	center.add_child(_button("返回", func() -> void: _set_view("place")))

func _technique_row(technique_id: String, active: bool) -> void:
	var t: Dictionary = session.content.technique(technique_id)
	var row := HBoxContainer.new()
	row.add_theme_constant_override("separation", 10)
	center.add_child(row)
	var title := _label("%s\n%s · %s" % [t.name, t.tier_name, session.content.technique_data.elements[t.element].name], 15, GOLD if int(t.tier) >= 3 else INK)
	title.custom_minimum_size.x = 120
	row.add_child(title)
	var text := _paragraph(t.description)
	text.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	row.add_child(text)
	var chosen := technique_id
	if active:
		row.add_child(_button("停下", func() -> void: _run(func() -> String: return session.unequip_technique(chosen))))
		return
	var slots: Array = session.player.arts if t.slot == "art" else session.player.methods
	var limit := int(session.content.rules.art_slots if t.slot == "art" else session.content.rules.method_slots)
	var full := slots.size() >= limit
	var button := _button("运转", func() -> void: _run(func() -> String: return session.equip_technique(chosen)), "栏位已满，先停下一门" if full else "放入栏位")
	button.disabled = full or not session.battle.is_empty()
	row.add_child(button)

## 行囊: everything carried, grouped by category, with use and (where bought) sell buttons.
func _render_bag() -> void:
	center.add_child(_label("行 囊", 26, GOLD))
	if session.player.items.is_empty():
		center.add_child(_paragraph("行囊空空如也。", MUTED))
	for category: String in session.content.ITEM_CATEGORIES:
		var ids: Array = session.player.items.keys().filter(func(item_id: String) -> bool: return session.content.item(item_id).get("category", "") == category)
		if ids.is_empty():
			continue
		ids.sort()
		center.add_child(_label(session.content.ITEM_CATEGORIES[category], 17, GOLD))
		for item_id: String in ids:
			var item: Dictionary = session.content.item(item_id)
			var row := HBoxContainer.new()
			row.add_theme_constant_override("separation", 10)
			center.add_child(row)
			var name_label := _label("%s ×%d" % [item.name, session.item_count(item_id)], 16)
			name_label.custom_minimum_size.x = 150
			row.add_child(name_label)
			var text := _paragraph(item.description)
			text.size_flags_horizontal = Control.SIZE_EXPAND_FILL
			row.add_child(text)
			var used := item_id
			if item.has("use"):
				var reason: String = session.use_block(item_id)
				var use_button := _button("服用", func() -> void: _run(func() -> String: return session.use_item(used)), reason)
				use_button.disabled = not reason.is_empty()
				row.add_child(use_button)
			if item.get("category", "") == "manual":
				var block: String = session.learn_block(item.teaches)
				var study := _button("参悟 · %d 日" % int(session.content.technique(item.teaches).study_days), func() -> void: _run(func() -> String: return session.study_manual(used)), block)
				study.disabled = not block.is_empty()
				row.add_child(study)
			if item.get("category", "") == "equipment":
				row.add_child(_button("装备", func() -> void: _run(func() -> String: return session.equip_item(used)), "换上这件法宝"))
			var price: int = session.sell_price(item_id)
			if price > 0:
				row.add_child(_button("出售 · %d" % price, func() -> void: _run(func() -> String: return session.sell(used, 1)), "在此地出售一件"))
	center.add_child(_button("返回", func() -> void: _set_view("place")))

func _select_map_target(location_id: String) -> void:
	map_target = location_id
	audio.cue("page")
	_render()

func _depart(location_id: String) -> void:
	audio.cue("depart")
	view = "place"
	_run(func() -> String: return session.travel(location_id))

func _set_view(next_view: String) -> void:
	if presenting:
		return
	view = next_view
	if next_view == "map" and map_target.is_empty():
		map_target = str(session.player.journey.get("to", ""))
	_render()

func _settled() -> bool:
	return session.battle.is_empty() and session.pending_event.is_empty() and session.ended.is_empty()

func _update_audio() -> void:
	if not session.ended.is_empty():
		audio.play_music("ending")
	elif not session.battle.is_empty():
		audio.play_music("battle")
	elif not session.pending_event.is_empty():
		audio.play_music("event")
	elif view == "map":
		audio.play_music("map")
	else:
		audio.play_music(session.player.location)
	audio.play_ambience(session.player.location)

func _build_settings() -> void:
	settings_dialog = AcceptDialog.new()
	settings_dialog.title = "设置"
	settings_dialog.ok_button_text = "完成"
	var rows := VBoxContainer.new()
	rows.add_theme_constant_override("separation", 10)
	settings_dialog.add_child(rows)
	for entry: Array in [["Master", "总音量"], ["Music", "配乐"], ["SFX", "音效"], ["Ambience", "环境声"]]:
		var bus_name: String = entry[0]
		var row := HBoxContainer.new()
		row.add_child(_label(entry[1], 16))
		var slider := HSlider.new()
		slider.name = bus_name
		slider.min_value = 0.0
		slider.max_value = 1.0
		slider.step = 0.05
		slider.custom_minimum_size.x = 260
		slider.value_changed.connect(func(value: float) -> void: audio.set_volume(bus_name, value))
		row.add_child(slider)
		rows.add_child(row)
	add_child(settings_dialog)

func _open_settings() -> void:
	for slider: HSlider in settings_dialog.find_children("*", "HSlider", true, false):
		slider.set_value_no_signal(float(audio.volumes.get(slider.name, 0.0)))
	settings_dialog.popup_centered(Vector2i(420, 240))

func _timed(parent: GridContainer, title: String, callback: Callable, tooltip: String) -> void:
	var button := _button(title, func() -> void: _run(callback), tooltip)
	button.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	parent.add_child(button)

func _render_upcoming() -> void:
	var soon: Array[Dictionary] = session.upcoming()
	var lifespan_year := Calendar.year(session.lifespan_end_day())
	stats.add_child(_label("寿元尽于历元 %d 年" % lifespan_year, 14, MUTED))
	if soon.is_empty():
		return
	stats.add_child(_label("近 期 约 定", 15, GOLD))
	for entry: Dictionary in soon:
		var place: String = session.content.locations[entry.location].name
		var state := "进行中" if int(entry.from) <= int(session.world.day) else "始于 " + Calendar.short_text(int(entry.from))
		var label := _label("%s · %s\n%s，至 %s" % [entry.title, place, state, Calendar.short_text(int(entry.to))], 14)
		label.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
		stats.add_child(label)

func _render_event() -> void:
	var definition: Dictionary = session.pending_definition()
	var title_row := HBoxContainer.new()
	title_row.add_theme_constant_override("separation", 20)
	center.add_child(title_row)
	title_row.add_child(_label(definition.title, 30, GOLD))
	title_row.add_child(_label(session.content.locations[session.player.location].name, 16, MUTED))
	center.add_child(_paragraph(definition.text, INK))
	var choices := VBoxContainer.new()
	choices.add_theme_constant_override("separation", 10)
	center.add_child(choices)
	for choice: Dictionary in definition.choices:
		var choice_id: String = choice.id
		var button := _button(choice.label, func() -> void: _choose(choice_id), "" if session.choice_available(choice) else "条件不足")
		button.disabled = not session.choice_available(choice)
		choices.add_child(button)

func _choose(choice_id: String) -> void:
	_run(func() -> String: return session.choose_event(choice_id))

func _render_ending() -> void:
	center.add_child(_label("此 生 已 尽", 30, GOLD))
	center.add_child(_paragraph("%s，%s，享年 %d 岁。" % [session.player.name, session.realm_name(), session.age()], INK))
	center.add_child(_label("生 平", 16, GOLD))
	for entry: Dictionary in session.chronicle.entries:
		if entry.major:
			center.add_child(_paragraph("【%s】%s" % [Calendar.short_text(int(entry.day)), session.chronicle.format(entry, session.content)]))
	center.add_child(_paragraph("可按 F9 读取手动存档，或开启新旅程。", GOLD))

func _action(parent: GridContainer, title: String, action: String, tooltip: String) -> void:
	var button := _button(title, func() -> void: _run(func() -> String: return session.act(action)), tooltip)
	button.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	parent.add_child(button)

func _enemy_action(parent: GridContainer, title: String, enemy_id: String, tooltip: String) -> Button:
	var button := _button(title, func() -> void: _run(func() -> String: return session.start_battle(enemy_id)), tooltip)
	button.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	parent.add_child(button)
	return button

func _render_battle() -> void:
	if preview_mode:
		_sect_choices(center, true)
	var b: Dictionary = session.battle
	var enemy: Dictionary = session.content.enemies[b.enemy_id].duplicate()
	if b.has("foe"):
		enemy.name = b.foe.name
		enemy.hp = b.foe.hp
	center.add_child(_label("斗 法  ·  %s     第 %d 回合" % [enemy.name, b.turn], 23, GOLD))
	battle_stage = BattleStage.new()
	battle_stage.custom_minimum_size.y = 245 if preview_mode else 300
	battle_stage.configure(session.snapshot(), enemy)
	center.add_child(battle_stage)
	battle_stage.cue.connect(audio.cue)
	center.add_child(_paragraph("选择神通 · 守御回灵并减伤 · 出招期间请等待命中与对手反击"))
	var grid := GridContainer.new()
	grid.columns = 6
	grid.add_theme_constant_override("h_separation", 8)
	grid.add_theme_constant_override("v_separation", 10)
	center.add_child(grid)
	var index := 1
	for skill_id: String in session.active_skills():
		var skill: Dictionary = session.content.technique(skill_id)
		var remaining := int(b.cooldowns.get(skill_id, 0))
		var suffix := "\n冷却 %d" % remaining if remaining > 0 else "\n%d 灵力" % int(skill.qi_cost)
		var button := _button("[%d] %s%s" % [index, skill.name, suffix], func() -> void: _skill(skill_id), "%s · %s\n%s%s" % [skill.tier_name, session.content.technique_data.elements[skill.element].name, skill.description, _realm_bonus_text()])
		button.disabled = remaining > 0 or int(session.player.qi) < int(skill.qi_cost)
		button.size_flags_horizontal = Control.SIZE_EXPAND_FILL
		grid.add_child(button)
		index += 1
	grid.add_child(_button("守御\n空格", func() -> void: _battle_action("guard"), "恢复 6 灵力，受到伤害减半"))
	grid.add_child(_button("撤离\n耗时 " + _duration("flee"), func() -> void: _battle_action("flee"), "保留资源，耗时 " + _duration("flee")))
	center.add_child(_paragraph("落败可休整后继续 · 最多损失 10 灵石", MUTED))

func _skill(skill_id: String) -> void:
	await _battle_action(skill_id)

func _battle_action(action: String) -> void:
	if presenting or session.battle.is_empty():
		return
	presenting = true
	_lock_buttons(self)
	var message: String
	if action == "guard":
		message = session.defend()
	elif action == "flee":
		message = session.flee()
	else:
		message = session.use_skill(action)
	var events: Array[Dictionary] = session.combat_events.duplicate(true)
	if is_instance_valid(battle_stage) and not events.is_empty():
		await battle_stage.play(events)
	for event: Dictionary in events:
		if event.get("type") == "end" and event.get("result") in ["win", "lose"]:
			audio.cue("victory" if event.result == "win" else "defeat")
	presenting = false
	for entry: Dictionary in locked_buttons:
		if is_instance_valid(entry.button):
			entry.button.disabled = entry.disabled
	locked_buttons.clear()
	_render()
	notice(message + (" 自动存档失败：" + autosave_error if not autosave_error.is_empty() else ""))

func _lock_buttons(node: Node) -> void:
	for child: Node in node.get_children():
		if child is Button:
			locked_buttons.append({"button": child, "disabled": child.disabled})
			child.disabled = true
		_lock_buttons(child)

func _run(callback: Callable) -> void:
	if presenting:
		return
	var before := _cue_state()
	var message: String = callback.call()
	_cue_changes(before)
	notice(message + (" 自动存档失败：" + autosave_error if not autosave_error.is_empty() else ""))

## A small snapshot of what the player would hear change.
func _cue_state() -> Dictionary:
	return {"location": session.player.get("location", ""), "pending": session.pending_event.duplicate(), "realm": int(session.player.get("realm", 0)), "ended": not session.ended.is_empty(), "battle": not session.battle.is_empty()}

func _cue_changes(before: Dictionary) -> void:
	var after := _cue_state()
	if after.ended and not before.ended:
		audio.cue("ending")
	elif after.realm > before.realm:
		audio.cue("breakthrough")
	elif not after.pending.is_empty() and after.pending != before.pending:
		audio.cue("event")
	elif after.battle and not before.battle:
		audio.cue("prepare")
	elif after.location != before.location:
		audio.cue("arrive")
	elif not before.pending.is_empty() and after.pending.is_empty():
		audio.cue("choice")

func notice(message: String) -> void:
	status_label.text = message

func _on_changed() -> void:
	if not presenting:
		_render()
	if started:
		autosave_error = "" if auto_store.save_game(session) else auto_store.last_error

func _save_manual() -> void:
	if not started or presenting:
		return
	if manual_store.save_game(session):
		load_button.disabled = false
		notice("手动存档已保存。可以按 F9 回到这个时刻。")
	else:
		notice(manual_store.last_error)

func _load_manual() -> void:
	if not started or presenting:
		return
	if manual_store.load_game(session):
		notice("已读取手动存档。")
	else:
		notice(manual_store.last_error)

func _ask_new_game() -> void:
	if presenting:
		return
	new_game_dialog.popup_centered(Vector2i(520, 180))

func _show_welcome() -> void:
	if presenting:
		return
	if is_instance_valid(welcome_layer):
		return
	welcome_layer = ColorRect.new()
	welcome_layer.color = Color(0.025, 0.045, 0.055, 0.97)
	welcome_layer.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	add_child(welcome_layer)
	var centered := CenterContainer.new()
	centered.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	welcome_layer.add_child(centered)
	var panel := _panel()
	panel.custom_minimum_size.x = 520
	centered.add_child(panel)
	var box := VBoxContainer.new()
	box.add_theme_constant_override("separation", 18)
	panel.add_child(box)
	box.add_child(_label("凡 途", 48, GOLD))
	box.add_child(_label("一介凡身，问道长生。", 22))
	box.add_child(_paragraph("历元元年 · 青云山外门\n修炼、游历、结交，在流转的岁月里寻求长生之道。"))
	name_input = LineEdit.new()
	name_input.placeholder_text = "道号（最多 16 字）"
	name_input.max_length = 16
	name_input.custom_minimum_size.y = 46
	name_input.text_submitted.connect(func(_value: String) -> void: _begin())
	box.add_child(name_input)
	# Spirit roots are sensed at random; the player may sense again until satisfied.
	var sense_rng := RandomNumberGenerator.new()
	sense_rng.randomize()
	welcome_roots = session.roll_roots(sense_rng)
	var roots_row := HBoxContainer.new()
	roots_row.add_theme_constant_override("separation", 12)
	box.add_child(roots_row)
	roots_label = _label("", 18, GOLD)
	roots_label.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	roots_row.add_child(roots_label)
	roots_row.add_child(_button("重新感应", func() -> void:
		welcome_roots = session.roll_roots(sense_rng)
		_show_roots(), "再测一次灵根"))
	_show_roots()
	var begin_button := _button("踏入仙途", _begin)
	box.add_child(begin_button)
	var continue_button := _button("继续旅程", _continue)
	continue_button.disabled = not (auto_store.has_save() or manual_store.has_save())
	box.add_child(continue_button)
	if started:
		box.add_child(_button("返回当前旅程", _close_welcome))
	box.add_child(_paragraph("开发版 · Windows 单机 · 本地存档\n二维手绘角色 · 施法演出 · 命中与受击反馈"))
	name_input.grab_focus()

func _show_roots() -> void:
	var grade: Dictionary = session.content.root_grade(welcome_roots)
	roots_label.text = "灵根 · %s（修炼 ×%.2f）" % [session.content.root_title(welcome_roots), float(grade.speed)]

func _close_welcome() -> void:
	remove_child(welcome_layer)
	welcome_layer.queue_free()
	welcome_layer = null

func _begin() -> void:
	var character_name := name_input.text
	_close_welcome()
	started = true
	session.new_game(character_name, -1, welcome_roots)
	notice("先在青云山修炼，再去落霞谷采草。灵草可在坊市换灵石、购买筑基丹。")

func _continue() -> void:
	# Suppress auto-save while deciding which existing save to restore.
	started = false
	if auto_store.load_game(session) or manual_store.load_game(session):
		started = true
		_close_welcome()
		_render()
		notice("已继续上次旅程。")
	else:
		notice("存档读取失败，请开启新旅程。")

func _unhandled_key_input(event: InputEvent) -> void:
	if not event is InputEventKey or not event.pressed or event.echo:
		return
	if presenting or is_instance_valid(welcome_layer) or new_game_dialog.visible:
		return
	match event.keycode:
		KEY_F5:
			_save_manual()
		KEY_F9:
			_load_manual()
		KEY_1, KEY_2, KEY_3, KEY_4:
			if not session.battle.is_empty():
				var ids := session.active_skills()
				if event.keycode - KEY_1 < ids.size():
					_skill(ids[event.keycode - KEY_1])
		KEY_SPACE:
			if not session.battle.is_empty():
				_battle_action("guard")
		_:
			return
	get_viewport().set_input_as_handled()

func _sect_choices(parent: VBoxContainer, is_preview: bool) -> void:
	var row := HBoxContainer.new()
	row.add_theme_constant_override("separation", 10)
	parent.add_child(row)
	row.add_child(_label("我方传承" if is_preview else "研习传承", 15, GOLD))
	var ids: Array[String] = ["wanderer", "qingyun", "chixiao", "changqing", "canglan", "xuanyue"]
	var select := OptionButton.new()
	select.custom_minimum_size = Vector2(145, 34)
	for id: String in ids:
		select.add_item(session.content.sects[id].name)
	select.select(ids.find(str(session.player.get("sect", "wanderer"))))
	select.item_selected.connect(func(index: int) -> void:
		if is_preview:
			_reset_preview(ids[index], preview_opponent)
		else:
			_run(func() -> String: return session.choose_sect(ids[index]))
	)
	row.add_child(select)
	if is_preview:
		row.add_child(_label("对手", 15, MUTED))
		var opponent := OptionButton.new()
		opponent.custom_minimum_size = Vector2(145, 34)
		var foe_ids: Array[String] = ["qingyun", "chixiao", "changqing", "canglan", "xuanyue"]
		for id: String in foe_ids:
			opponent.add_item(session.content.sects[id].name)
		opponent.select(foe_ids.find(preview_opponent))
		opponent.item_selected.connect(func(index: int) -> void: _reset_preview(str(session.player.sect), foe_ids[index]))
		row.add_child(opponent)
		row.add_child(_button("重置试演", func() -> void: _reset_preview(str(session.player.sect), preview_opponent)))
	else:
		parent.add_child(_paragraph(session.content.sects[session.player.get("sect", "wanderer")].description))

func _reset_preview(sect_id: String = "qingyun", opponent_id: String = "qingyun") -> void:
	if presenting:
		return
	preview_opponent = opponent_id
	session.new_game("青禾")
	session.choose_sect(sect_id)
	session.player.hp = maxi(1, int(session.player.max_hp) - 20)
	session.start_battle("disciple", opponent_id)
	notice("门派试演 · 1 / 2 / 3 施法，空格护体；切换传承会重置试演，正常旅程不受影响。")
