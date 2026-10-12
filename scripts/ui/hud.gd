extends RefCounted
## The few things always on screen in the world (at a place or on the map), after Mi Chang Sheng: who
## you are and how you stand at the top left with buttons for the panels; the date, the place, the
## current goal and the 任务 scroll at the top right; the latest records at the bottom left and a short
## notice of what just happened at the bottom. Everything else has a screen or a panel of its own.
const Goals = preload("res://scripts/ui/goals.gd")
const StatusView = preload("res://scripts/ui/status_view.gd")
# The top-left buttons: the view each one opens, and its name.
const ICONS := [["status", "人物"], ["bag", "行囊"], ["arts", "功法"], ["map", "舆图"], ["chronicle", "编年史"]]
const LOG_LINES := 2
const NOTICE_SECONDS := 6.0

static func build(ui) -> void:
	var fill := Color(0.04, 0.09, 0.1, 0.86)
	var left := PanelContainer.new()
	left.add_theme_stylebox_override("panel", ui.style(fill, Color("#41615e"), 10))
	left.position = Vector2(14, 12)
	ui.add_child(left)
	ui.hud_left = left
	var column := VBoxContainer.new()
	column.add_theme_constant_override("separation", 8)
	left.add_child(column)
	var status := VBoxContainer.new()
	status.add_theme_constant_override("separation", 2)
	status.custom_minimum_size.x = 270
	column.add_child(status)
	ui.hud_status = status
	var icons := HBoxContainer.new()
	icons.add_theme_constant_override("separation", 6)
	column.add_child(icons)
	ui.hud_icons = {}
	for pair: Array in ICONS:
		var view_id: String = pair[0]
		var icon: Button = ui.button(pair[1], func() -> void: ui.toggle_view(view_id))
		icon.custom_minimum_size = Vector2(0, 32)
		icon.add_theme_font_size_override("font_size", 14)
		icons.add_child(icon)
		ui.hud_icons[view_id] = icon

	var right := PanelContainer.new()
	right.add_theme_stylebox_override("panel", ui.style(fill, Color("#41615e"), 10))
	right.anchor_left = 1.0
	right.anchor_right = 1.0
	right.offset_left = -14.0
	right.offset_right = -14.0
	right.offset_top = 12.0
	right.grow_horizontal = Control.GROW_DIRECTION_BEGIN
	ui.add_child(right)
	ui.hud_right = right
	var info := VBoxContainer.new()
	info.add_theme_constant_override("separation", 4)
	right.add_child(info)
	var row := HBoxContainer.new()
	row.add_theme_constant_override("separation", 14)
	info.add_child(row)
	var where := VBoxContainer.new()
	where.add_theme_constant_override("separation", 0)
	row.add_child(where)
	ui.clock_label = ui.label("", 16, ui.GOLD)
	where.add_child(ui.clock_label)
	ui.place_label = ui.label("", 15)
	where.add_child(ui.place_label)
	var tasks: Button = ui.button("任务", func() -> void: ui.toggle_view("goals"), "当前目标、委托与约定")
	tasks.custom_minimum_size = Vector2(64, 40)
	row.add_child(tasks)
	ui.hud_icons["goals"] = tasks
	ui.goal_label = ui.label("", 14, ui.MUTED)
	ui.goal_label.mouse_filter = Control.MOUSE_FILTER_PASS
	info.add_child(ui.goal_label)
	ui.journey_box = HBoxContainer.new()
	ui.journey_box.add_theme_constant_override("separation", 8)
	info.add_child(ui.journey_box)

	var record := RichTextLabel.new()
	record.bbcode_enabled = false
	record.scroll_active = false
	record.mouse_filter = Control.MOUSE_FILTER_IGNORE
	record.add_theme_font_size_override("normal_font_size", 13)
	record.add_theme_color_override("default_color", Color(ui.INK, 0.8))
	record.anchor_top = 1.0
	record.anchor_bottom = 1.0
	record.anchor_right = 0.32
	record.offset_left = 16.0
	record.offset_top = -52.0
	record.offset_bottom = -8.0
	ui.add_child(record)
	ui.journal_text = record

	var notice := Label.new()
	notice.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	notice.mouse_filter = Control.MOUSE_FILTER_IGNORE
	notice.add_theme_font_size_override("font_size", 14)
	notice.add_theme_color_override("font_color", ui.INK)
	notice.add_theme_stylebox_override("normal", ui.style(Color(0.03, 0.07, 0.08, 0.8), Color(0, 0, 0, 0), 8))
	notice.anchor_left = 0.34
	notice.anchor_right = 0.985
	notice.anchor_top = 1.0
	notice.anchor_bottom = 1.0
	notice.offset_top = -50.0
	notice.offset_bottom = -8.0
	notice.vertical_alignment = VERTICAL_ALIGNMENT_CENTER
	notice.z_index = 10
	ui.add_child(notice)
	ui.status_label = notice

## Shows the HUD for the world screens and hides it on the others.
static func set_shown(ui, shown: bool) -> void:
	for part: Control in [ui.hud_left, ui.hud_right, ui.journal_text]:
		part.visible = shown

static func render(ui) -> void:
	var session = ui.session
	var p: Dictionary = session.player
	ui.clear(ui.hud_status)
	var title := HBoxContainer.new()
	title.add_theme_constant_override("separation", 10)
	ui.hud_status.add_child(title)
	var seal := PanelContainer.new()
	seal.custom_minimum_size = Vector2(44, 44)
	seal.add_theme_stylebox_override("panel", ui.style(Color("#1b3236"), ui.GOLD, 0))
	var initial: Label = ui.label(str(p.name).left(1), 24, ui.GOLD)
	initial.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	initial.vertical_alignment = VERTICAL_ALIGNMENT_CENTER
	seal.add_child(initial)
	title.add_child(seal)
	var names := VBoxContainer.new()
	names.add_theme_constant_override("separation", 0)
	title.add_child(names)
	names.add_child(ui.label(p.name, 19))
	names.add_child(ui.label(session.realm_name(), 14, ui.GOLD))
	_bar(ui, "气血", int(p.hp), int(p.max_hp), Color("#a96f66"))
	_bar(ui, "灵力", int(p.qi), int(p.max_qi), Color("#5f999b"))
	_bar(ui, "修为", int(p.xp), maxi(1, maxi(int(p.xp), StatusView.xp_goal(session))), ui.GOLD)
	var on_map: bool = ui.view == "map"
	ui.hud_icons.map.text = "此地" if on_map else "舆图"
	ui.hud_icons.map.disabled = not on_map and not ui.settled()
	ui.clock_label.text = session.time_name()
	ui.place_label.text = session.content.locations[p.location].name
	var goals: Array[Dictionary] = []
	if ui.goals_enabled:
		goals = Goals.current(session)
	ui.goal_label.visible = not goals.is_empty()
	if not goals.is_empty():
		ui.goal_label.text = "目标 · " + goals[0].title
		ui.goal_label.tooltip_text = goals[0].text
	ui.clear(ui.journey_box)
	ui.journey_button = null
	if not p.journey.is_empty():
		var remaining: int = session.content.path_days(session.path_to(p.journey.to))
		ui.journey_box.add_child(ui.label("行程未竟 · %s · 约 %d 日" % [session.content.locations[p.journey.to].name, remaining], 14))
		var go_on: Button = ui.button("继续赶路", ui.continue_journey, "沿原定路线继续前进")
		go_on.custom_minimum_size.y = 30
		go_on.disabled = not ui.settled()
		ui.journey_box.add_child(go_on)
		ui.journey_button = go_on
	ui.journal_text.text = "\n".join(session.journal_lines().slice(-LOG_LINES))

## A thin meter with its numbers on one line.
static func _bar(ui, title: String, value: int, maximum: int, color: Color) -> void:
	ui.hud_status.add_child(ui.label("%s  %d / %d" % [title, value, maximum], 13, ui.MUTED))
	var bar := ProgressBar.new()
	bar.show_percentage = false
	bar.max_value = maximum
	bar.value = value
	bar.custom_minimum_size.y = 6
	bar.add_theme_stylebox_override("background", ui.style(Color("#1d3539"), Color("#1d3539"), 0))
	bar.add_theme_stylebox_override("fill", ui.style(color, color, 0))
	ui.hud_status.add_child(bar)

## Shows what just happened, then lets it fade.
static func notice(ui, message: String) -> void:
	var label: Label = ui.status_label
	label.text = message
	label.visible = not message.is_empty()
	label.modulate.a = 1.0
	if ui.notice_tween != null and ui.notice_tween.is_valid():
		ui.notice_tween.kill()
	ui.notice_tween = ui.create_tween()
	ui.notice_tween.tween_interval(NOTICE_SECONDS)
	ui.notice_tween.tween_property(label, "modulate:a", 0.0, 1.2)
