extends Control
## The desktop interface, built as screens after Mi Chang Sheng: the world (a place drawn as a scene,
## or the map) with the HUD's few always-visible things; full screens that take everything over (an
## event, a story moment, a duel, a breakthrough, the end of a life); and scrolls laid over the world —
## the character panel, the 任务 scroll, the retreat scroll and the trading table. This node picks the
## screen, arranges it, switches views and handles input, saving and loading, and the playback of
## duels, journeys and retreats. Each view is built by its own script from this node's state, using the
## widget helpers and handlers here: hud.gd, place_view.gd, people_view.gd, map_view.gd, bag_view.gd,
## arts_view.gd, status_view.gd, tasks_view.gd, system_view.gd, retreat_view.gd, trade_view.gd,
## battle_view.gd, event_view.gd, chronicle_view.gd and welcome_screen.gd.
const Session = preload("res://scripts/core/session.gd")
const SaveStore = preload("res://scripts/core/save_store.gd")
const Calendar = preload("res://scripts/core/calendar.gd")
const AudioDirector = preload("res://scripts/presentation/audio_director.gd")
const ArtLibrary = preload("res://scripts/ui/art_library.gd")
const Landscape = preload("res://scripts/ui/landscape.gd")
const UiSkin = preload("res://scripts/ui/ui_skin.gd")
const Hud = preload("res://scripts/ui/hud.gd")
const StatusView = preload("res://scripts/ui/status_view.gd")
const SectView = preload("res://scripts/ui/sect_view.gd")
const AlchemyView = preload("res://scripts/ui/alchemy_view.gd")
const Rite = preload("res://scripts/presentation/rite.gd")
const TasksView = preload("res://scripts/ui/tasks_view.gd")
const SystemView = preload("res://scripts/ui/system_view.gd")
const WorldMap = preload("res://scripts/ui/world_map.gd")
const RetreatView = preload("res://scripts/ui/retreat_view.gd")
const TradeView = preload("res://scripts/ui/trade_view.gd")
const PlaceView = preload("res://scripts/ui/place_view.gd")
const PeopleView = preload("res://scripts/ui/people_view.gd")
const MapView = preload("res://scripts/ui/map_view.gd")
const BagView = preload("res://scripts/ui/bag_view.gd")
const ArtsView = preload("res://scripts/ui/arts_view.gd")
const BattleView = preload("res://scripts/ui/battle_view.gd")
const AuctionView = preload("res://scripts/ui/auction_view.gd")
const ForgeView = preload("res://scripts/ui/forge_view.gd")
const EventView = preload("res://scripts/ui/event_view.gd")
const WelcomeScreen = preload("res://scripts/ui/welcome_screen.gd")
const ChronicleView = preload("res://scripts/ui/chronicle_view.gd")
const Guide = preload("res://scripts/ui/guide.gd")
const Settings = preload("res://scripts/ui/settings.gd")
const GOLD := Color("#d5b777")
const INK := Color("#e3e8dc")
const MUTED := Color("#97aaa4")
# The scrolls laid over the world and their tabs: the view each tab shows, and its name.
const PANEL_TABS := [["status", "属性"], ["sect", "宗门"], ["arts", "神通"], ["methods", "功法"], ["bag", "行囊"], ["people", "相识"], ["chronicle", "编年史"], ["system", "系统"]]
const SCROLL_TABS := [["goals", "当前目标"], ["stories", "剧情"], ["quests", "委托"], ["letters", "传音"], ["upcoming", "约定"], ["messages", "消息"]]
const RETREAT_TABS := [["retreat", "修炼"], ["breakthrough", "突破"]]
const TAB_GROUPS := {"panel": PANEL_TABS, "scroll": SCROLL_TABS, "retreat": RETREAT_TABS, "trade": [["trade", "交易"]], "alchemy": [["alchemy", "炼丹"]], "field": [["field", "灵田"]], "forge": [["forge", "炼器"]]}
var session = Session.new()
var manual_store = SaveStore.new("user://saves/manual")
var auto_store = SaveStore.new("user://saves/auto")
var started := false
var autosave_error := ""
# The content of the current screen; every view builds into it.
var center: VBoxContainer
var view := "place"
# The world view ("place" or "map") that closing a panel returns to.
var world_view := "place"
# The screen's parts: the backdrop picture and its shade, the window holding `center` with the tab row
# above it (for the panel and the scroll).
var backdrop: TextureRect
# A place whose picture is not drawn yet shows a code-drawn landscape of its terrain instead.
var backdrop_sketch: Control
var shade: ColorRect
var window: PanelContainer
var tab_row: HBoxContainer
var window_style: StyleBox
# A place's scene (place_view.gd): its title, the spots as paper tags and the people drawer.
var scene_layer: Control
# The state of the screens: the duel's record shown, the retreat's chosen length and its playback,
# the breakthrough just achieved, the open person's details, the people drawer, the filters of the
# 神通 / 功法 and 行囊 pages, and what is laid out on the trading table.
var battle_record_open := false
var battle_scout_open := false
var retreat_days := 90
var retreat_playback: Dictionary = {}
var retreat_labels: Dictionary = {}
var ceremony: Dictionary = {}
# The breakthrough being prepared on the retreat scroll: {"pills", "treasure", "guard"} (retreat_view.gd).
var breakthrough_plan: Dictionary = {}
var profile_open := false
var drawer_open := true
var arts_filter := "all"
var bag_filter := "all"
var trade: Dictionary = {"sell": {}, "buy": []}
# The brew being set out on the alchemy page: {"recipe", "guide", "fire", "aid"}.
var alchemy_plan: Dictionary = {}
# The HUD (hud.gd).
var hud_left: PanelContainer
var hud_right: PanelContainer
var hud_status: VBoxContainer
var hud_icons: Dictionary = {}
var place_label: Label
var goal_label: Label
var journey_box: HBoxContainer
var notice_tween: Tween
var selected_spot := ""
# The person whose profile is open in the centre panel ("" when none).
var selected_npc := ""
# The room chosen on the old cave's map (cave_view.gd).
var cave_room := ""
# The forging being set out (forge_view.gd): {"material", "base", "element"}.
var forge_plan := {}
var shown_location := ""
var show_everyone_here := false
var welcome_roots: Array = []
# The talents sensed with them ({"talents", "flaws"}), the senses left, and the action to sense again.
var welcome_born: Dictionary = {"talents": [], "flaws": []}
var welcome_senses := 0
var welcome_resense: Callable
# The local portrait pack (see ArtLibrary); tests point this elsewhere.
var portrait_root := ArtLibrary.LOCAL_PORTRAITS
# Pool portraits assigned to generated people, kept by people_view.gd for the current world and pool.
var _pool_assignments := {}
var _pool_key := ""
var map_target := ""
# The region the map is turned to (map_view.gd); empty is the one the player is in.
var map_region := ""
# The 编年史 view's filter (a group in data/chronicle_groups.json, or "all") and page (0 = newest).
var chronicle_filter := "all"
var chronicle_page := 0
var world_map
var audio
var settings_dialog: AcceptDialog
# The settings dialog's controls, by name (settings.gd).
var settings_controls := {}
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
# The teaching cards (guide.gd): whether cards are shown and whether this player has finished the
# introduction once, kept in the player's guide file at guide_path (tests point it elsewhere); the
# cards dismissed are the journey's own (player.taught). tip_page is the page of the card on screen.
var guide_path := Guide.DEFAULT_PATH
var guide_enabled := true
var intro_finished_once := false
var tip_page: Dictionary = {}
# The card on screen, if any, so it can be turned into a bubble beside its button (guide.gd).
var tip_card: Control = null
var guide_toggle: CheckBox
# The welcome screen's choice to skip the introduction (shown once it has been finished before).
var skip_intro: CheckBox
# How many 传音 were unread when the inbox was opened, to mark them as new there.
var letters_fresh := 0
# Preferences kept in the player's settings file (settings.gd); tests point settings_path elsewhere.
var settings_path := Settings.DEFAULT_PATH
var fullscreen := false
var window_size := Settings.DEFAULT_SIZE
var text_speed := Settings.DEFAULT_TEXT_SPEED
var autosave_enabled := true
# Whether the HUD shows the first current goal (goals.gd).
var goals_enabled := true
var keys: Dictionary = Settings.DEFAULT_KEYS.duplicate()
# The action waiting for a new key in the settings dialog ("" when none).
var binding_action := ""
# Texts that have typed themselves out in the current scene, by key.
var _typed := {}

func _ready() -> void:
	get_window().min_size = Settings.WINDOW_SIZES[0]
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
	game_theme.set_color("font_disabled_color", "Button", Color("#8d9f99"))
	game_theme.set_stylebox("normal", "Button", style(Color("#213b3f"), Color("#41615e"), 10))
	game_theme.set_stylebox("hover", "Button", style(Color("#305451"), GOLD, 10))
	game_theme.set_stylebox("pressed", "Button", style(Color("#152b2f"), GOLD, 10))
	game_theme.set_stylebox("disabled", "Button", style(Color("#1a2f33"), Color("#34504f"), 10))
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
	result.add_theme_stylebox_override("panel", UiSkin.scroll_style(18))
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
	backdrop = TextureRect.new()
	backdrop.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	backdrop.expand_mode = TextureRect.EXPAND_IGNORE_SIZE
	backdrop.stretch_mode = TextureRect.STRETCH_KEEP_ASPECT_COVERED
	backdrop.mouse_filter = Control.MOUSE_FILTER_IGNORE
	add_child(backdrop)
	backdrop_sketch = Landscape.new()
	backdrop_sketch.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	backdrop_sketch.visible = false
	add_child(backdrop_sketch)
	shade = ColorRect.new()
	shade.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	shade.color = Color(0.02, 0.05, 0.06, 0.4)
	shade.mouse_filter = Control.MOUSE_FILTER_IGNORE
	add_child(shade)
	# The region's map fills the screen on the map screen, under the HUD and the route window.
	world_map = WorldMap.new()
	world_map.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	world_map.visible = false
	world_map.location_selected.connect(select_map_target)
	add_child(world_map)
	scene_layer = Control.new()
	scene_layer.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	scene_layer.mouse_filter = Control.MOUSE_FILTER_IGNORE
	add_child(scene_layer)
	window = PanelContainer.new()
	window_style = UiSkin.scroll_style(18, 0.96)
	window.add_theme_stylebox_override("panel", window_style)
	add_child(window)
	var body := VBoxContainer.new()
	body.add_theme_constant_override("separation", 12)
	window.add_child(body)
	tab_row = HBoxContainer.new()
	tab_row.add_theme_constant_override("separation", 8)
	body.add_child(tab_row)
	var scroll := ScrollContainer.new()
	scroll.horizontal_scroll_mode = ScrollContainer.SCROLL_MODE_DISABLED
	scroll.size_flags_vertical = Control.SIZE_EXPAND_FILL
	body.add_child(scroll)
	center = VBoxContainer.new()
	center.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	center.add_theme_constant_override("separation", 10)
	scroll.add_child(center)
	Hud.build(self)
	new_game_dialog = ConfirmationDialog.new()
	new_game_dialog.title = "开启新旅程"
	new_game_dialog.dialog_text = "新旅程会替换自动存档。手动存档将保留，直到你再次手动保存。"
	new_game_dialog.ok_button_text = "开启新旅程"
	new_game_dialog.cancel_button_text = "返回"
	new_game_dialog.confirmed.connect(_show_welcome)
	add_child(new_game_dialog)
	Settings.build(self)
	notice("鼠标选择行动 · {save} 保存 · {load} 读取 · 斗法中按 {skills} 施法，{end_turn}结束回合，{guard}守御".format(Settings.key_hints(self)))

## Which screen the state calls for: "full" while an ending, a breakthrough, a story moment, an event
## or a duel holds the player; the scroll a view belongs to ("panel", "scroll", "retreat", "trade");
## otherwise the world, "place" or "map".
func current_screen() -> String:
	if not session.ended.is_empty() or not ceremony.is_empty() or not story.is_empty() or not session.pending_event.is_empty() or not session.battle.is_empty() or not session.auction.is_empty():
		return "full"
	var group := _tab_group(view)
	if not group.is_empty():
		return group
	return "map" if view == "map" else "place"

## The scroll whose tabs hold a view, else "".
func _tab_group(view_id: String) -> String:
	for group: String in TAB_GROUPS:
		for pair: Array in TAB_GROUPS[group]:
			if pair[0] == view_id:
				return group
	return ""

## Sets out the screen: the backdrop, the window's place, the HUD and the tab row.
func _arrange(screen: String) -> void:
	window.visible = true
	var world := screen in ["place", "map"]
	Hud.set_shown(self, world, screen == "map")
	world_map.visible = screen == "map"
	scene_layer.visible = screen == "place"
	if screen != "place":
		_sketch_backdrop(false)
	var dueling: bool = screen == "full" and not session.battle.is_empty() and ceremony.is_empty() and story.is_empty() and session.pending_event.is_empty() and session.ended.is_empty()
	window.add_theme_stylebox_override("panel", StyleBoxEmpty.new() if dueling else window_style)
	Hud.place_notice(self, dueling)
	match screen:
		"place":
			# The place's picture fills the screen as its scene; the window on the right holds the spot
			# or the person the player turned to.
			backdrop.texture = ArtLibrary.texture(ArtLibrary.fullscreen_location_path(str(session.player.location)))
			backdrop.visible = true
			_sketch_backdrop(backdrop.texture == null)
			# The scene stays whole; a spot or a person opens as a scroll in the middle over a dimmed scene.
			if place_popup_open():
				shade.color.a = 0.45
				_place_window(0.26, 0.975, 110.0, -70.0)
			else:
				shade.color.a = 0.1
				window.visible = false
		"map":
			# The map is the screen; the route window sits under the top-right corner, where the region
			# has no places.
			backdrop.visible = false
			shade.color.a = 0.0
			_place_window(0.68, 0.985, 124.0, 404.0)
			window.anchor_bottom = 0.0
		"full":
			backdrop.visible = false
			shade.color.a = 0.0
			var art := _telling_art()
			if dueling:
				# The duel's stage is the screen; its dock runs along the bottom.
				_place_window(0.0, 1.0, 0.0, 0.0)
			elif not session.auction.is_empty() and session.pending_event.is_empty() and story.is_empty() and ceremony.is_empty():
				# The auction sits over the darkened market.
				backdrop.texture = ArtLibrary.texture(ArtLibrary.fullscreen_location_path(str(session.player.location)))
				backdrop.visible = true
				shade.color.a = 0.6
				_place_window(0.14, 0.86, 64.0, -96.0)
			elif not art.is_empty():
				# An event or a story moment with its illustration: the picture is the screen and the
				# words and choices sit in a box along the bottom, like a picture book.
				backdrop.texture = ArtLibrary.texture(art)
				backdrop.visible = true
				shade.color.a = 0.12
				_place_window(0.06, 0.94, 0.0, -20.0)
				window.anchor_top = 1.0
				window.offset_top = -300.0
			else:
				_place_window(0.0, 1.0, 14.0, -60.0, 14.0)
		"retreat", "trade", "alchemy", "field", "forge":
			# Smaller scrolls over the place, which darkens behind them.
			shade.color.a = 0.6
			_place_window(0.0, 1.0, 40.0, -64.0, 96.0)
		_:
			# The panel and the task scroll lie over the world, which darkens behind them.
			shade.color.a = 0.72
			_place_window(0.0, 1.0, 22.0, -60.0, 40.0)
	tab_row.visible = TAB_GROUPS.has(screen)
	clear(tab_row)
	if tab_row.visible:
		for pair: Array in TAB_GROUPS[screen]:
			var view_id: String = pair[0]
			var tab: Button = button(pair[1], func() -> void: set_view(view_id))
			tab.disabled = view_id == view
			tab_row.add_child(tab)
		var spacer := Control.new()
		spacer.size_flags_horizontal = Control.SIZE_EXPAND_FILL
		tab_row.add_child(spacer)
		tab_row.add_child(button("关闭 Esc", close_overlay, "回到" + ("舆图" if world_view == "map" else "此地")))

## The illustration of the event or story moment on screen, or "".
func _telling_art() -> String:
	if not session.ended.is_empty() or not ceremony.is_empty():
		return ""
	if not story.is_empty():
		return ArtLibrary.event_art(str(story.event))
	if not session.pending_event.is_empty():
		return ArtLibrary.event_art(str(session.pending_event.id))
	return ""

## Shows the code-drawn landscape behind a place that has no picture yet (or hides it).
func _sketch_backdrop(shown: bool) -> void:
	backdrop_sketch.visible = shown
	if not shown:
		return
	var here := str(session.player.location)
	if backdrop_sketch.location_id != here or backdrop_sketch.art != null:
		backdrop_sketch.location_id = here
		backdrop_sketch.terrain = str(session.content.locations[here].terrain)
		backdrop_sketch.art = null
		backdrop_sketch.queue_redraw()

func _place_window(left: float, right: float, top: float, bottom: float, side: float = 0.0) -> void:
	window.anchor_left = left
	window.anchor_right = right
	window.anchor_top = 0.0
	window.anchor_bottom = 1.0
	window.offset_left = side
	window.offset_right = -side
	window.offset_top = top
	window.offset_bottom = bottom

## Rebuilds the screen from the session: the HUD, then the view the screen shows. An ending, a story
## moment, a pending event or a duel takes the whole screen; otherwise the chosen view is shown. A new
## scene fades in.
func render() -> void:
	if session.player.is_empty():
		return
	if session.player.location != shown_location:
		shown_location = session.player.location
		selected_npc = ""
		selected_spot = ""
		dialogue = {}
		show_everyone_here = false
	if view in ["place", "map"]:
		world_view = view
	var screen := current_screen()
	_arrange(screen)
	Hud.render(self)
	clear(scene_layer)
	if screen == "place":
		PlaceView.render_scene(self, scene_layer)
	clear(center)
	center.alignment = BoxContainer.ALIGNMENT_BEGIN
	var scene := "%s|%s|%s|%s|%s|%s" % [view, session.player.location, session.pending_event.get("id", ""), story.get("event", ""), session.battle.is_empty(), selected_npc]
	var new_scene := scene != _scene_key
	if new_scene:
		_scene_key = scene
		_typed = {}
	if screen == "place" and not place_popup_open():
		# With no scroll open the card floats low in the middle, clear of the tags and the place's name.
		var holder := VBoxContainer.new()
		holder.anchor_left = 0.3
		holder.anchor_right = 0.74
		holder.anchor_top = 1.0
		holder.anchor_bottom = 1.0
		holder.offset_top = -96.0
		holder.offset_bottom = -96.0
		holder.grow_vertical = Control.GROW_DIRECTION_BEGIN
		scene_layer.add_child(holder)
		Guide.render(self, _guide_place(), holder)
	else:
		Guide.render(self, _guide_place())
	if not session.ended.is_empty():
		EventView.render_ending(self)
	elif not ceremony.is_empty():
		EventView.render_ceremony(self)
	elif not story.is_empty():
		EventView.render_story(self)
	elif not session.pending_event.is_empty():
		EventView.render_event(self)
	elif not session.battle.is_empty():
		BattleView.render(self)
	elif not session.auction.is_empty():
		AuctionView.render(self)
	else:
		match view:
			"map":
				MapView.render(self)
			"bag":
				BagView.render(self)
			"arts":
				ArtsView.render_arts(self)
			"methods":
				ArtsView.render_methods(self)
			"retreat":
				RetreatView.render_retreat(self)
			"breakthrough":
				RetreatView.render_breakthrough(self)
			"trade":
				TradeView.render(self)
			"people":
				PeopleView.render_list(self)
			"chronicle":
				ChronicleView.render(self)
			"status":
				StatusView.render(self)
			"sect":
				SectView.render(self)
			"alchemy":
				AlchemyView.render(self)
			"forge":
				ForgeView.render(self)
			"field":
				AlchemyView.render_field(self)
			"goals":
				TasksView.render_goals(self)
			"quests":
				TasksView.render_quests(self)
			"upcoming":
				TasksView.render_upcoming(self)
			"stories":
				TasksView.render_stories(self)
			"letters":
				TasksView.render_letters(self)
			"messages":
				TasksView.render_messages(self)
			"system":
				SystemView.render(self)
			_:
				PlaceView.render(self)
	# The due card's button, once the view is built.
	Guide.highlight(self, _guide_place())
	if new_scene:
		center.modulate.a = 0.0
		create_tween().tween_property(center, "modulate:a", 1.0, 0.25)
	_update_audio()

## Which part of the screen the centre panel shows, for the guide's tips ("" when no tip fits).
func _guide_place() -> String:
	if not started or not session.ended.is_empty() or not story.is_empty():
		return ""
	if not session.pending_event.is_empty():
		return "event"
	if not session.battle.is_empty():
		return "battle"
	if not session.auction.is_empty():
		return "auction"
	if view == "place" and not selected_npc.is_empty():
		return ""
	return view

## Dismisses a teaching card for this journey; the journey is saved with it.
func dismiss_tip(tip_id: String) -> void:
	tip_page = {}
	session.mark_taught(tip_id)
	session.changed.emit()

## Turns the card on screen a page forward or back.
func turn_tip(step: int) -> void:
	tip_page.page = int(tip_page.get("page", 0)) + step
	audio.cue("page")
	render()

func set_guide_enabled(enabled: bool) -> void:
	guide_enabled = enabled
	Guide.save_state(self)
	render()

## Shows every card of this journey again, from the first.
func reset_guide() -> void:
	tip_page = {}
	if not session.player.is_empty():
		session.player.taught.clear()
	guide_enabled = true
	guide_toggle.set_pressed_no_signal(true)
	Guide.save_state(self)
	render()

# --- Navigation ------------------------------------------------------------------------------------

func set_view(next_view: String) -> void:
	if presenting:
		return
	view = next_view
	if next_view == "chronicle":
		chronicle_page = 0
	# Opening the inbox reads the 传音; the ones that were new keep their mark while it stays open.
	if next_view == "letters":
		letters_fresh = session.unread_letters()
		session.mark_letters_read()
	if next_view == "map" and map_target.is_empty():
		map_target = str(session.player.journey.get("to", ""))
	if next_view == "map":
		map_region = ""
	render()

func set_chronicle_filter(filter: String) -> void:
	chronicle_filter = filter
	chronicle_page = 0
	audio.cue("page")
	render()

func set_chronicle_page(page: int) -> void:
	chronicle_page = clampi(page, 0, ChronicleView.page_count(self) - 1)
	audio.cue("page")
	render()

## A HUD button: opens its view, or closes it when it is already open (the map goes back to the place).
func toggle_view(view_id: String) -> void:
	if view != view_id:
		set_view(view_id)
	elif view_id == "map":
		set_view("place")
	else:
		close_overlay()

## Closes the panel or the scroll, back to the place or the map it was opened from.
func close_overlay() -> void:
	if view == "trade":
		trade = {"sell": {}, "buy": []}
	set_view(world_view)

## The open person's details and their record (查看).
func toggle_profile() -> void:
	profile_open = not profile_open
	render()

## The people drawer at the left edge of a place's scene.
func toggle_drawer() -> void:
	drawer_open = not drawer_open
	render()

func toggle_battle_record() -> void:
	battle_record_open = not battle_record_open
	battle_scout_open = false
	render()

## 探查: the opponent's make-up, in the record's place (combat.gd scout).
func toggle_battle_scout() -> void:
	battle_scout_open = not battle_scout_open
	battle_record_open = battle_scout_open
	render()

func set_arts_filter(element: String) -> void:
	arts_filter = element
	render()

func set_bag_filter(category: String) -> void:
	bag_filter = category
	render()

# --- 品级 colors ------------------------------------------------------------------------------------

## The color of an item's or a technique's 品级 (白、绿、蓝、紫、橙、红).
func grade_color(entry: Dictionary) -> Color:
	return session.content.rarity_color(session.content.rarity_of(entry))

## Colors a button's text the same in every state.
func tint(target: Button, color: Color) -> Button:
	for state: String in ["font_color", "font_hover_color", "font_focus_color", "font_pressed_color", "font_hover_pressed_color"]:
		target.add_theme_color_override(state, color)
	target.add_theme_color_override("font_disabled_color", Color(color, 0.5))
	return target

# --- The alchemy page (alchemy_view.gd) -------------------------------------------------------------

func open_forge() -> void:
	forge_plan = {}
	set_view("forge")

func open_alchemy() -> void:
	alchemy_plan = {}
	set_view("alchemy")

func choose_recipe(recipe_id: String) -> void:
	var fire := str(alchemy_plan.get("fire", "gentle"))
	alchemy_plan = session.alchemy_plan(recipe_id)
	alchemy_plan.fire = fire
	render()

## Changes one part of the brew being set out: "guide", "fire" or "aid".
func set_alchemy(key: String, value: String) -> void:
	alchemy_plan[key] = value
	render()

## Lights the furnace; afterwards the 药引 and the talisman are chosen afresh from what is left.
func brew_now() -> void:
	var plan := alchemy_plan.duplicate()
	var mark: int = session.chronicle.added
	run(func() -> String: return session.brew(plan))
	var count := mini(int(session.chronicle.added) - mark, session.chronicle.entries.size())
	for entry: Dictionary in session.chronicle.entries.slice(-count) if count > 0 else []:
		if str(entry.id).begins_with("alchemy_"):
			var result := str(entry.id).trim_prefix("alchemy_")
			var pill_name := str(session.content.item(str(session.content.alchemy_data.recipes[str(plan.recipe)].pill)).name)
			await _rite(func(rite) -> void: await rite.play_brew(result, pill_name))
			break
	if not session.known_recipes().has(str(plan.get("recipe", ""))):
		return
	alchemy_plan = session.alchemy_plan(str(plan.recipe))
	alchemy_plan.fire = str(plan.fire)
	if not str(plan.get("aid", "")).is_empty() and session.item_count(str(plan.aid)) > 0:
		alchemy_plan.aid = str(plan.aid)
	render()

# --- The trading table (trade_view.gd): goods are laid out, and only 确定 trades them. --------------

func open_trade() -> void:
	trade = {"sell": {}, "buy": []}
	set_view("trade")

## Lays one more of an item on the table to sell, or takes one back (`count` -1).
func stage_sale(item_id: String, count: int = 1) -> void:
	var laid := int(trade.sell.get(item_id, 0)) + count
	if laid <= 0:
		trade.sell.erase(item_id)
	else:
		trade.sell[item_id] = mini(laid, session.item_count(item_id))
	render()

## Lays a good on the table to buy (a good of the rotating stock only once), or takes it back.
func stage_purchase(item_id: String, add: bool = true) -> void:
	if add:
		trade.buy.append(item_id)
	else:
		trade.buy.erase(item_id)
	render()

## Sells and buys what is on the table, in that order, as the shop's own actions.
func confirm_trade() -> void:
	var sales: Dictionary = trade.sell.duplicate()
	var purchases: Array = trade.buy.duplicate()
	trade = {"sell": {}, "buy": []}
	run(func() -> String:
		var messages: Array[String] = []
		for item_id: String in sales:
			messages.append(session.sell(item_id, int(sales[item_id])))
		for item_id: String in purchases:
			messages.append(session.buy(item_id))
		return " ".join(messages))

# --- Retreat and breakthrough (retreat_view.gd) ----------------------------------------------------

## A retreat of `days`: the rules run it at once; the scroll then plays the days and the xp going by,
## input locked meanwhile. An event that cuts it short takes the screen afterwards.
func start_retreat(days: int) -> void:
	if presenting or not settled():
		return
	var before := _cue_state()
	var mark: int = session.chronicle.added
	var from_day := int(session.world.day)
	var from_xp := int(session.player.xp)
	presenting = true
	var message: String = session.cultivate(days)
	retreat_playback = {"from_day": from_day, "to_day": int(session.world.day), "from_xp": from_xp, "to_xp": int(session.player.xp)}
	render()
	_lock_buttons(self)
	# The figure meditates over the whole screen while the days and the xp go by.
	var to_day := int(session.world.day)
	var to_xp := int(session.player.xp)
	var goal: int = StatusView.xp_goal(session)
	await _rite(func(rite) -> void: await rite.play_retreat(from_day, to_day, from_xp, to_xp, goal))
	retreat_playback = {}
	presenting = false
	_unlock_buttons()
	_stage_story(mark)
	_cue_changes(before)
	render()
	notice(message + (" 自动存档失败：" + autosave_error if not autosave_error.is_empty() else ""))

## Breaking through: the rules decide; the outcome — a realm reached with its grade, or a failure — is
## shown in its own screen until 确定. Should 心魔 come first, the event screen takes its choice and the
## outcome follows it (choose).
func start_breakthrough() -> void:
	if presenting or not settled():
		return
	var plan: Dictionary = RetreatView.plan_of(self)
	var mark: int = session.chronicle.added
	var before := _breakthrough_before()
	run(func() -> String: return session.breakthrough(plan))
	await _breakthrough_rite(mark)
	_breakthrough_outcome(mark, before)

## Plays the breakthrough among the entries added since `mark`: the gathering, then the realm reached,
## the failure, or 心魔 rising.
func _breakthrough_rite(mark: int) -> void:
	var count := mini(int(session.chronicle.added) - mark, session.chronicle.entries.size())
	for entry: Dictionary in session.chronicle.entries.slice(-count) if count > 0 else []:
		match str(entry.id):
			"breakthrough":
				var core: Dictionary = session.core_grade()
				var grade: Dictionary = session.foundation_grade()
				var realm_name: String = str(session.content.realm(int(session.player.realm)).name)
				var grade_name: String = ("金丹 · " + str(core.name)) if not core.is_empty() else ("根基 · " + str(grade.name) if not grade.is_empty() else "")
				await _rite(func(rite) -> void: await rite.play_breakthrough("success", realm_name, grade_name))
				return
			"breakthrough_failed":
				await _rite(func(rite) -> void: await rite.play_breakthrough("failure"))
				return
			"heart_demon":
				await _rite(func(rite) -> void: await rite.play_breakthrough("demon"))
				return

## A staged moment over the whole screen (presentation/rite.gd), input locked meanwhile.
func _rite(play: Callable) -> void:
	var was_presenting := presenting
	presenting = true
	if not was_presenting:
		_lock_buttons(self)
	var rite = Rite.new()
	add_child(rite)
	await play.call(rite)
	rite.queue_free()
	presenting = was_presenting
	if not was_presenting:
		_unlock_buttons()

func _breakthrough_before() -> Dictionary:
	return {"max_hp": int(session.player.max_hp), "max_qi": int(session.player.max_qi), "lifespan": session.lifespan()}

## Stages the outcome of a breakthrough among the entries added since `mark`, if there is one.
func _breakthrough_outcome(mark: int, before: Dictionary) -> void:
	if not session.ended.is_empty():
		return
	var count := mini(int(session.chronicle.added) - mark, session.chronicle.entries.size())
	for entry: Dictionary in session.chronicle.entries.slice(-count) if count > 0 else []:
		if entry.id == "breakthrough":
			breakthrough_plan = {}
			ceremony = {"realm": int(session.player.realm), "before": before, "grade": int(entry.args.get("grade", -1))}
		elif entry.id == "breakthrough_failed":
			breakthrough_plan = {}
			ceremony = {"failed": true, "text": session.chronicle.format(entry, session.content)}
	if not ceremony.is_empty():
		story = {}
		render()

func close_ceremony() -> void:
	ceremony = {}
	set_view("place")

func select_spot(spot_id: String) -> void:
	selected_spot = spot_id
	audio.cue("page")
	render()

## Whether a spot or a person is open over the place's scene.
func place_popup_open() -> bool:
	if view != "place":
		return false
	if not selected_npc.is_empty():
		return true
	var rank := int(session.player.get("rank", 0))
	return session.content.locations[session.player.location].spots.any(func(spot: Dictionary) -> bool: return spot.id == selected_spot and session.content.spot_open(spot, session.world.flags, rank))

## Closes the spot or the person open over the scene.
func close_spot() -> void:
	selected_spot = ""
	selected_npc = ""
	dialogue = {}
	audio.cue("page")
	render()

func open_person(person_id: String) -> void:
	if presenting:
		return
	if person_id != str(dialogue.get("npc", "")):
		dialogue = {}
	if person_id != selected_npc:
		profile_open = false
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

## Turns the map to another region's page.
func set_map_region(region_id: String) -> void:
	map_region = region_id
	audio.cue("page")
	render()

func select_map_target(location_id: String) -> void:
	map_target = location_id
	audio.cue("page")
	render()

func depart(location_id: String) -> void:
	await _travel(func() -> String: return session.travel(location_id))

## Resumes a journey cut short on the road, walking the rest on the map.
func continue_journey() -> void:
	await _travel(session.continue_journey)

## A journey: the rules walk it at once; the map then plays it back leg by leg with the date moving,
## input locked meanwhile. Arriving enters the place; an encounter or an event on the way takes the
## screen, and afterwards the map is back with the journey to continue.
func _travel(action: Callable) -> void:
	if presenting or not settled():
		return
	view = "map"
	render()
	var before := _cue_state()
	var mark: int = session.chronicle.added
	var start: String = session.player.location
	var day := int(session.world.day)
	presenting = true
	_lock_buttons(self)
	audio.cue("depart")
	var message: String = action.call()
	# The legs walked, in order, from the chronicle's travel entries the journey added.
	var legs: Array[Dictionary] = []
	var count := mini(int(session.chronicle.added) - mark, session.chronicle.entries.size())
	var walked: Array[Dictionary] = []
	if count > 0:
		walked = session.chronicle.entries.slice(-count)
	for entry: Dictionary in walked:
		if entry.id == "travel":
			legs.append({"to": str(entry.args.location), "from_day": day, "day": int(entry.day), "days": int(entry.day) - day, "fly": bool(entry.args.get("fly", false))})
			day = int(entry.day)
	if not legs.is_empty():
		await world_map.walk(start, legs, func(index: int, progress: float) -> void:
			clock_label.text = Calendar.date_text(int(lerpf(int(legs[index].from_day), int(legs[index].day), progress))))
	presenting = false
	_unlock_buttons()
	if session.player.journey.is_empty() and settled() and session.player.location != start:
		view = "place"
	_stage_story(mark)
	_cue_changes(before)
	render()
	notice(message + (" 自动存档失败：" + autosave_error if not autosave_error.is_empty() else ""))

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
	if is_instance_valid(save_button):
		save_button.text = "保存 " + Settings.key_name(self, "save")
	if is_instance_valid(load_button):
		load_button.text = "读取 " + Settings.key_name(self, "load")
	if started and not presenting:
		render()

# --- Actions -----------------------------------------------------------------------------------------

func choose(choice_id: String) -> void:
	var mark: int = session.chronicle.added
	var before := _breakthrough_before()
	run(func() -> String: return session.choose_event(choice_id))
	await _breakthrough_rite(mark)
	_breakthrough_outcome(mark, before)

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
	elif action == "end_turn":
		message = session.end_turn()
	elif action == "quick":
		message = session.quick_duel()
	elif action.begins_with("convert:"):
		message = session.convert_qi(action.trim_prefix("convert:"))
	elif action.begins_with("pill:"):
		message = session.take_duel_pill(action.trim_prefix("pill:"))
	elif action.begins_with("aid:"):
		message = session.call_aid(action.trim_prefix("aid:"))
	elif action == "flee":
		message = session.flee()
	elif action == "release":
		message = session.Combat.release(session)
	elif action == "array":
		message = session.Combat.lay_array(session)
	elif action.begins_with("target:"):
		message = session.set_target(int(action.trim_prefix("target:")))
	else:
		message = session.use_skill(action)
	var events: Array[Dictionary] = session.combat_events.duplicate(true)
	if is_instance_valid(battle_stage) and not events.is_empty():
		await battle_stage.play(events)
	for event: Dictionary in events:
		if event.get("type") == "end" and event.get("result") in ["win", "lose"]:
			audio.cue("victory" if event.result == "win" else "defeat")
	presenting = false
	_unlock_buttons()
	render()
	notice(message + (" 自动存档失败：" + autosave_error if not autosave_error.is_empty() else ""))

func _unlock_buttons() -> void:
	for entry: Dictionary in locked_buttons:
		if is_instance_valid(entry.button):
			entry.button.disabled = entry.disabled
	locked_buttons.clear()

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
## moment that needed no choice (the serpent breaking out), a storyline's words or a 传音 (told in a
## screen of their own until 继续), or the words just exchanged with the open person. Only
## presentation; the session knows nothing of it.
func _stage_story(mark: int) -> void:
	var count := mini(int(session.chronicle.added) - mark, session.chronicle.entries.size())
	if count <= 0:
		return
	var lines: Array[String] = []
	var told: Array[String] = []
	var told_title := ""
	var staged := false
	for entry: Dictionary in session.chronicle.entries.slice(-count):
		var args: Dictionary = entry.args
		if entry.id == "event" and args.get("part", "") == "chronicle" and not staged:
			var definition: Dictionary = session.content.events.get(str(args.event), {})
			if not ArtLibrary.event_art(str(args.event)).is_empty() and not definition.has("choices"):
				story = {"event": str(args.event), "title": str(definition.get("title", "")), "text": session.chronicle.format(entry, session.content), "mark": mark}
				staged = true
		elif entry.id in ["story", "letter"]:
			if told_title.is_empty():
				told_title = "传音" if entry.id == "letter" and not args.has("story") else str(session.content.storylines.get(str(args.get("story", "")), {}).get("title", "传音"))
			told.append(session.chronicle.format(entry, session.content))
		elif entry.id in ["talk", "gift", "npc", "help"] and not selected_npc.is_empty() and str(args.get("npc", "")) == selected_npc:
			lines.append(session.chronicle.format(entry, session.content))
	if not lines.is_empty():
		dialogue = {"npc": selected_npc, "lines": lines, "mark": mark}
	if not told.is_empty():
		if staged:
			story.text = str(story.text) + "\n\n" + "\n\n".join(told)
		else:
			story = {"event": "", "title": told_title, "text": "\n\n".join(told), "mark": mark}
			staged = true
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
	Hud.notice(self, message)

func _on_changed() -> void:
	# Finishing the introduction once (or playing a journey from before it) lets later journeys skip it.
	if started and not intro_finished_once and session.story_state("intro") == "done":
		intro_finished_once = true
		Guide.save_state(self)
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
		if is_instance_valid(load_button):
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
	tip_page = {}
	var skipped := is_instance_valid(skip_intro) and skip_intro.button_pressed
	var mark: int = session.chronicle.added
	session.new_game(character_name, -1, welcome_roots, "skipped" if skipped else "guided", welcome_born)
	_stage_story(mark)
	notice("入门已略过：执事堂、传功堂都已开放，右上角的「任务」写着眼下可做的事。" if skipped else "跟着许清和走一遍入门：右上角的「目标」写着眼下该做的事。")

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
	if event.keycode == KEY_ESCAPE and not _tab_group(view).is_empty():
		close_overlay()
		get_viewport().set_input_as_handled()
		return
	if event.keycode == KEY_ESCAPE and current_screen() == "place" and place_popup_open():
		close_spot()
		get_viewport().set_input_as_handled()
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
		"guard", "end_turn":
			if not session.battle.is_empty():
				battle_action(action)
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
	session.Loadout.take_lineage(session, sect_id)
	session.player.hp = maxi(1, int(session.player.max_hp) - 20)
	session.start_battle("disciple", opponent_id)
	notice("门派试演 · {skills} 施法，{end_turn}结束回合，{guard}守御；切换传承会重置试演，正常旅程不受影响。".format(Settings.key_hints(self)))
