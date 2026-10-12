extends Control
## The desktop interface: layout, view switching, input, saving and loading, and battle presentation.
## Each view is built by its own script from this node's state, using the widget helpers and handlers
## here: sidebar.gd, place_view.gd, people_view.gd, map_view.gd, bag_view.gd, arts_view.gd,
## battle_view.gd, event_view.gd and welcome_screen.gd.
const Session = preload("res://scripts/core/session.gd")
const SaveStore = preload("res://scripts/core/save_store.gd")
const Calendar = preload("res://scripts/core/calendar.gd")
const AudioDirector = preload("res://scripts/presentation/audio_director.gd")
const ArtLibrary = preload("res://scripts/ui/art_library.gd")
const Sidebar = preload("res://scripts/ui/sidebar.gd")
const PlaceView = preload("res://scripts/ui/place_view.gd")
const PeopleView = preload("res://scripts/ui/people_view.gd")
const MapView = preload("res://scripts/ui/map_view.gd")
const BagView = preload("res://scripts/ui/bag_view.gd")
const ArtsView = preload("res://scripts/ui/arts_view.gd")
const BattleView = preload("res://scripts/ui/battle_view.gd")
const EventView = preload("res://scripts/ui/event_view.gd")
const WelcomeScreen = preload("res://scripts/ui/welcome_screen.gd")
const Guide = preload("res://scripts/ui/guide.gd")
const Settings = preload("res://scripts/ui/settings.gd")
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
var show_everyone_here := false
var welcome_roots: Array = []
# The local portrait pack (see ArtLibrary); tests point this elsewhere.
var portrait_root := ArtLibrary.LOCAL_PORTRAITS
# Pool portraits assigned to generated people, kept by people_view.gd for the current world and pool.
var _pool_assignments := {}
var _pool_key := ""
var roots_label: Label
var map_target := ""
var world_map
var audio
var settings_dialog: AcceptDialog
# The settings dialog's controls, by name (settings.gd).
var settings_controls := {}
var view_buttons: Dictionary = {}
var journey_button: Button
var journal_text: RichTextLabel
var status_label: Label
var clock_label: Label
var save_button: Button
var load_button: Button
var welcome_layer: ColorRect
var name_input: LineEdit
var new_game_dialog: ConfirmationDialog
var battle_stage
var presenting := false
var locked_buttons: Array[Dictionary] = []
var preview_mode := false
var preview_opponent := "qingyun"
# A story moment staged in the centre panel until dismissed: {"event", "title", "text"}.
var story: Dictionary = {}
# The words just exchanged with the open person: {"npc", "lines"}.
var dialogue: Dictionary = {}
# What the centre panel last showed, so that a new scene fades in.
var _scene_key := ""
# The new-player guide (guide.gd): whether tips are shown and which were dismissed, kept in the
# player's guide file at guide_path (tests point it elsewhere).
var guide_path := Guide.DEFAULT_PATH
var guide_enabled := true
var guide_seen := {}
var guide_toggle: CheckBox
# Preferences kept in the player's settings file (settings.gd); tests point settings_path elsewhere.
var settings_path := Settings.DEFAULT_PATH
var fullscreen := false
var window_size := Settings.DEFAULT_SIZE
var text_speed := Settings.DEFAULT_TEXT_SPEED
var autosave_enabled := true
var keys: Dictionary = Settings.DEFAULT_KEYS.duplicate()
# The action waiting for a new key in the settings dialog ("" when none).
var binding_action := ""
# Texts that have typed themselves out in the current scene, by key.
var _typed := {}

func _ready() -> void:
	get_window().min_size = Vector2i(1000, 640)
	_build_theme()
	audio = AudioDirector.new()
	add_child(audio)
	Settings.load_state(self)
	_build_layout()
	Settings.apply_window(self, true)
	Guide.load_state(self)
	if not session.content.error_message.is_empty():
		notice(session.content.error_message)
		return
	session.new_game()
	session.changed.connect(_on_changed)
	render()
	preview_mode = "--art-preview" in OS.get_cmdline_user_args() or "--sect-preview" in OS.get_cmdline_user_args()
	if preview_mode:
		manual_store = SaveStore.new("user://art_preview/manual")
		auto_store = SaveStore.new("user://art_preview/auto")
		guide_enabled = false
		started = true
		reset_preview()
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
	game_theme.set_stylebox("normal", "Button", style(Color("#213b3f"), Color("#41615e"), 10))
	game_theme.set_stylebox("hover", "Button", style(Color("#305451"), GOLD, 10))
	game_theme.set_stylebox("pressed", "Button", style(Color("#152b2f"), GOLD, 10))
	game_theme.set_stylebox("disabled", "Button", style(Color("#182b30"), Color("#2b4445"), 10))
	game_theme.set_stylebox("focus", "Button", style(Color(0, 0, 0, 0), GOLD, 10))
	game_theme.set_color("font_color", "LineEdit", INK)
	game_theme.set_stylebox("normal", "LineEdit", style(Color("#14282c"), Color("#41615e"), 10))
	game_theme.set_stylebox("focus", "LineEdit", style(Color("#14282c"), GOLD, 10))
	game_theme.set_stylebox("panel", "PopupMenu", style(Color("#152a30"), GOLD, 10))
	theme = game_theme

# --- Widgets used by every view ---------------------------------------------------------------

func style(fill: Color, border: Color, padding: float) -> StyleBoxFlat:
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

func label(text_value: String, font_size: int = 17, color: Color = INK) -> Label:
	var result := Label.new()
	result.text = text_value
	result.add_theme_font_size_override("font_size", font_size)
	result.add_theme_color_override("font_color", color)
	return result

func paragraph(text_value: String, color: Color = MUTED) -> Label:
	var result := label(text_value, 16, color)
	result.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	return result

func button(text_value: String, callback: Callable, tooltip: String = "") -> Button:
	var result := Button.new()
	result.text = text_value
	result.tooltip_text = tooltip
	result.custom_minimum_size.y = 42
	result.mouse_default_cursor_shape = Control.CURSOR_POINTING_HAND
	result.pressed.connect(func() -> void: audio.cue("click"))
	result.pressed.connect(callback)
	return result

func panel() -> PanelContainer:
	var result := PanelContainer.new()
	result.add_theme_stylebox_override("panel", style(Color("#112329"), Color("#304749"), 18))
	return result

func clear(container: Node) -> void:
	for child: Node in container.get_children():
		container.remove_child(child)
		child.queue_free()

func meter(parent: VBoxContainer, title: String, value: float, maximum: float, color: Color) -> void:
	parent.add_child(label("%s    %d / %d" % [title, value, maximum], 15, MUTED))
	var bar := ProgressBar.new()
	bar.show_percentage = false
	bar.max_value = maximum
	bar.value = value
	bar.custom_minimum_size.y = 8
	bar.add_theme_stylebox_override("background", style(Color("#1d3539"), Color("#1d3539"), 0))
	bar.add_theme_stylebox_override("fill", style(color, color, 0))
	parent.add_child(bar)

## An illustration across the panel at `height`, cropped to fit; null while the art is missing.
func picture(path: String, height: float) -> TextureRect:
	var texture := ArtLibrary.texture(path)
	if texture == null:
		return null
	var image := TextureRect.new()
	image.texture = texture
	image.custom_minimum_size.y = height
	image.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	image.expand_mode = TextureRect.EXPAND_IGNORE_SIZE
	image.stretch_mode = TextureRect.STRETCH_KEEP_ASPECT_COVERED
	return image

## Lets story text type itself out at the chosen text speed, once per `key` in a scene, starting after
## `delay` seconds; returns when it will have finished.
func type_out(node: Label, key: String, delay: float = 0.0) -> float:
	var speed := Settings.characters_per_second(self)
	if speed <= 0 or _typed.has(key):
		return delay
	_typed[key] = true
	var seconds := node.text.length() / float(speed)
	node.visible_ratio = 0.0
	create_tween().bind_node(node).tween_property(node, "visible_ratio", 1.0, seconds).set_delay(delay)
	return delay + seconds

## How long an action takes, as text.
func duration(action: String) -> String:
	return Calendar.duration_text(session.content.action_days(action))

# --- Layout and rendering ----------------------------------------------------------------------

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
	header.add_child(label("凡 途", 32, GOLD))
	header.add_child(label("修仙纪事", 16, MUTED))
	var spacer := Control.new()
	spacer.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	header.add_child(spacer)
	clock_label = label("", 16, GOLD)
	header.add_child(clock_label)
	view_buttons.place = button("此地", func() -> void: set_view("place"))
	header.add_child(view_buttons.place)
	view_buttons.map = button("舆图", func() -> void: set_view("map"))
	header.add_child(view_buttons.map)
	view_buttons.bag = button("行囊", func() -> void: set_view("bag"))
	header.add_child(view_buttons.bag)
	view_buttons.arts = button("功法", func() -> void: set_view("arts"))
	header.add_child(view_buttons.arts)
	save_button = button("", _save_manual)
	header.add_child(save_button)
	load_button = button("", _load_manual)
	header.add_child(load_button)
	header.add_child(button("新旅程", _ask_new_game))
	header.add_child(button("设置", _open_settings))
	var body := HBoxContainer.new()
	body.size_flags_vertical = Control.SIZE_EXPAND_FILL
	body.add_theme_constant_override("separation", 16)
	page.add_child(body)
	var sidebar := panel()
	sidebar.custom_minimum_size.x = 258
	body.add_child(sidebar)
	stats = VBoxContainer.new()
	stats.add_theme_constant_override("separation", 8)
	var sidebar_scroll := ScrollContainer.new()
	sidebar_scroll.horizontal_scroll_mode = ScrollContainer.SCROLL_MODE_DISABLED
	sidebar.add_child(sidebar_scroll)
	stats.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	sidebar_scroll.add_child(stats)
	var main_panel := panel()
	main_panel.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	body.add_child(main_panel)
	var scroll := ScrollContainer.new()
	scroll.horizontal_scroll_mode = ScrollContainer.SCROLL_MODE_DISABLED
	main_panel.add_child(scroll)
	center = VBoxContainer.new()
	center.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	center.add_theme_constant_override("separation", 10)
	scroll.add_child(center)
	var log_panel := panel()
	log_panel.custom_minimum_size.y = 140
	page.add_child(log_panel)
	var log_box := VBoxContainer.new()
	log_panel.add_child(log_box)
	log_box.add_child(label("修 行 手 记", 16, GOLD))
	journal_text = RichTextLabel.new()
	journal_text.bbcode_enabled = false
	journal_text.scroll_following = true
	journal_text.size_flags_vertical = Control.SIZE_EXPAND_FILL
	journal_text.add_theme_font_size_override("normal_font_size", 15)
	log_box.add_child(journal_text)
	status_label = label("鼠标选择行动 · {save} 保存 · {load} 读取 · 斗法中按 {skills} 施法，{guard}守御".format(Settings.key_hints(self)), 14, MUTED)
	status_label.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	page.add_child(status_label)
	new_game_dialog = ConfirmationDialog.new()
	new_game_dialog.title = "开启新旅程"
	new_game_dialog.dialog_text = "新旅程会替换自动存档。手动存档将保留，直到你再次手动保存。"
	new_game_dialog.ok_button_text = "开启新旅程"
	new_game_dialog.cancel_button_text = "返回"
	new_game_dialog.confirmed.connect(_show_welcome)
	add_child(new_game_dialog)
	Settings.build(self)
	refresh_key_labels()

## Rebuilds the sidebar and the centre panel from the session. An ending, a story moment, a pending
## event or a duel takes the centre panel over; otherwise the chosen view is shown. A new scene fades in.
func render() -> void:
	if session.player.is_empty():
		return
	clock_label.text = session.time_name()
	if session.player.location != shown_location:
		shown_location = session.player.location
		selected_npc = ""
		dialogue = {}
		show_everyone_here = false
	Sidebar.render(self)
	load_button.disabled = not manual_store.has_save()
	view_buttons.place.disabled = view == "place"
	view_buttons.map.disabled = view == "map" or not settled()
	view_buttons.bag.disabled = view == "bag"
	view_buttons.arts.disabled = view == "arts"
	clear(center)
	var scene := "%s|%s|%s|%s|%s|%s" % [view, session.player.location, session.pending_event.get("id", ""), story.get("event", ""), session.battle.is_empty(), selected_npc]
	var new_scene := scene != _scene_key
	if new_scene:
		_scene_key = scene
		_typed = {}
	Guide.render(self, _guide_place())
	if not session.ended.is_empty():
		EventView.render_ending(self)
	elif not story.is_empty():
		EventView.render_story(self)
	elif not session.pending_event.is_empty():
		EventView.render_event(self)
	elif not session.battle.is_empty():
		BattleView.render(self)
	elif view == "map":
		MapView.render(self)
	elif view == "bag":
		BagView.render(self)
	elif view == "arts":
		ArtsView.render(self)
	elif view == "people":
		PeopleView.render_list(self)
	else:
		PlaceView.render(self)
	if new_scene:
		center.modulate.a = 0.0
		create_tween().tween_property(center, "modulate:a", 1.0, 0.25)
	_update_audio()
	journal_text.text = "\n".join(session.journal_lines())

## Which part of the screen the centre panel shows, for the guide's tips ("" when no tip fits).
func _guide_place() -> String:
	if not started or not session.ended.is_empty() or not story.is_empty():
		return ""
	if not session.pending_event.is_empty():
		return "event"
	if not session.battle.is_empty():
		return "battle"
	if view == "place" and not selected_npc.is_empty():
		return ""
	return view

func dismiss_tip(tip_id: String) -> void:
	guide_seen[tip_id] = true
	Guide.save_state(self)
	render()

func set_guide_enabled(enabled: bool) -> void:
	guide_enabled = enabled
	Guide.save_state(self)
	render()

## Shows every tip again, from the first.
func reset_guide() -> void:
	guide_seen = {}
	guide_enabled = true
	guide_toggle.set_pressed_no_signal(true)
	Guide.save_state(self)
	render()

# --- Navigation ------------------------------------------------------------------------------------

func set_view(next_view: String) -> void:
	if presenting:
		return
	view = next_view
	if next_view == "map" and map_target.is_empty():
		map_target = str(session.player.journey.get("to", ""))
	render()

func select_spot(spot_id: String) -> void:
	selected_spot = spot_id
	audio.cue("page")
	render()

func open_person(person_id: String) -> void:
	if presenting:
		return
	if person_id != str(dialogue.get("npc", "")):
		dialogue = {}
	selected_npc = person_id
	view = "place"
	audio.cue("page")
	render()

func close_person() -> void:
	selected_npc = ""
	dialogue = {}
	render()

func close_story() -> void:
	story = {}
	audio.cue("page")
	render()

func select_map_target(location_id: String) -> void:
	map_target = location_id
	audio.cue("page")
	render()

func depart(location_id: String) -> void:
	audio.cue("depart")
	view = "place"
	run(func() -> String: return session.travel(location_id))

## True when nothing (a duel, an event or the end of a life) holds the player in place.
func settled() -> bool:
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

func _open_settings() -> void:
	Settings.open(self)

## Puts the bound keys into the labels that name them.
func refresh_key_labels() -> void:
	save_button.text = "保存 " + Settings.key_name(self, "save")
	load_button.text = "读取 " + Settings.key_name(self, "load")
	if started and not presenting:
		render()

# --- Actions -----------------------------------------------------------------------------------------

func choose(choice_id: String) -> void:
	run(func() -> String: return session.choose_event(choice_id))

func skill(skill_id: String) -> void:
	await battle_action(skill_id)

## A duel turn: the input stays locked while the stage plays the turn's events.
func battle_action(action: String) -> void:
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
	render()
	notice(message + (" 自动存档失败：" + autosave_error if not autosave_error.is_empty() else ""))

func _lock_buttons(node: Node) -> void:
	for child: Node in node.get_children():
		if child is Button:
			locked_buttons.append({"button": child, "disabled": child.disabled})
			child.disabled = true
		_lock_buttons(child)

## Runs a session action (ignored while a duel turn is playing) and shows its text.
func run(callback: Callable) -> void:
	if presenting:
		return
	var before := _cue_state()
	var mark: int = session.chronicle.added
	var message: String = callback.call()
	_stage_story(mark)
	_cue_changes(before)
	notice(message + (" 自动存档失败：" + autosave_error if not autosave_error.is_empty() else ""))

## Picks out of an action's new chronicle entries what the centre panel should stage: an illustrated
## moment that needed no choice (the serpent breaking out), or the words just exchanged with the open
## person. Only presentation; the session knows nothing of it.
func _stage_story(mark: int) -> void:
	var count := mini(int(session.chronicle.added) - mark, session.chronicle.entries.size())
	if count <= 0:
		return
	var lines: Array[String] = []
	var staged := false
	for entry: Dictionary in session.chronicle.entries.slice(-count):
		var args: Dictionary = entry.args
		if entry.id == "event" and args.get("part", "") == "chronicle" and not staged:
			var definition: Dictionary = session.content.events.get(str(args.event), {})
			if not ArtLibrary.event_art(str(args.event)).is_empty() and not definition.has("choices"):
				story = {"event": str(args.event), "title": str(definition.get("title", "")), "text": session.chronicle.format(entry, session.content), "mark": mark}
				staged = true
		elif entry.id in ["talk", "gift", "npc"] and not selected_npc.is_empty() and str(args.get("npc", "")) == selected_npc:
			lines.append(session.chronicle.format(entry, session.content))
	if not lines.is_empty():
		dialogue = {"npc": selected_npc, "lines": lines, "mark": mark}
	if staged or not lines.is_empty():
		render()

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
		render()
	if started and autosave_enabled:
		autosave_error = "" if auto_store.save_game(session) else auto_store.last_error
	else:
		autosave_error = ""

# --- Saving, loading and new journeys ------------------------------------------------------------

func _save_manual() -> void:
	if not started or presenting:
		return
	if manual_store.save_game(session):
		load_button.disabled = false
		notice("手动存档已保存。可以按 %s 回到这个时刻。" % Settings.key_name(self, "load"))
	else:
		notice(manual_store.last_error)

func _load_manual() -> void:
	if not started or presenting:
		return
	story = {}
	dialogue = {}
	if manual_store.load_game(session):
		notice("已读取手动存档。")
	else:
		notice(manual_store.last_error)

func _ask_new_game() -> void:
	if presenting:
		return
	new_game_dialog.dialog_text = "新旅程会替换自动存档。手动存档将保留，直到你再次手动保存。" if autosave_enabled else "自动存档已关闭：新旅程只在你手动保存后才会留下存档，手动存档在此之前保留。"
	new_game_dialog.popup_centered(Vector2i(520, 180))

func _show_welcome() -> void:
	if presenting:
		return
	if is_instance_valid(welcome_layer):
		return
	WelcomeScreen.build(self)

func close_welcome() -> void:
	remove_child(welcome_layer)
	welcome_layer.queue_free()
	welcome_layer = null

func begin() -> void:
	var character_name := name_input.text
	close_welcome()
	started = true
	story = {}
	dialogue = {}
	session.new_game(character_name, -1, welcome_roots)
	notice("先在青云山修炼，再去落霞谷采草。灵草可在坊市换灵石、购买筑基丹。")

func continue_saved() -> void:
	# Suppress auto-save while deciding which existing save to restore.
	started = false
	story = {}
	dialogue = {}
	# The newer of the two saves: with auto-save switched off, the manual save can be the later one.
	var stores: Array = [auto_store, manual_store]
	if manual_store.saved_at() > auto_store.saved_at():
		stores.reverse()
	if stores[0].load_game(session) or stores[1].load_game(session):
		started = true
		close_welcome()
		render()
		notice("已继续上次旅程。")
	else:
		notice("存档读取失败，请开启新旅程。")

func _unhandled_key_input(event: InputEvent) -> void:
	if not event is InputEventKey or not event.pressed or event.echo:
		return
	if presenting or is_instance_valid(welcome_layer) or new_game_dialog.visible or settings_dialog.visible:
		return
	var action := Settings.action_for_key(self, event.keycode)
	match action:
		"save":
			_save_manual()
		"load":
			_load_manual()
		"skill_1", "skill_2", "skill_3", "skill_4":
			if not session.battle.is_empty():
				var ids := session.active_skills()
				var index := int(action.right(1)) - 1
				if index < ids.size():
					skill(ids[index])
		"guard":
			if not session.battle.is_empty():
				battle_action("guard")
		_:
			return
	get_viewport().set_input_as_handled()

## The sect preview (preview_sects.cmd): a fresh duel with the chosen lineages, separate from any journey.
func reset_preview(sect_id: String = "qingyun", opponent_id: String = "qingyun") -> void:
	if presenting:
		return
	preview_opponent = opponent_id
	story = {}
	dialogue = {}
	session.new_game("青禾")
	session.choose_sect(sect_id)
	session.player.hp = maxi(1, int(session.player.max_hp) - 20)
	session.start_battle("disciple", opponent_id)
	notice("门派试演 · {skills} 施法，{guard}护体；切换传承会重置试演，正常旅程不受影响。".format(Settings.key_hints(self)))
