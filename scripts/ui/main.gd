extends Control
const Session = preload("res://scripts/core/session.gd")
const SaveStore = preload("res://scripts/core/save_store.gd")
const Landscape = preload("res://scripts/ui/landscape.gd")
const BattleStage = preload("res://scripts/presentation/battle_stage.gd")
const Calendar = preload("res://scripts/core/calendar.gd")
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
var travel_buttons: Dictionary = {}
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
	header.add_child(_button("保存 F5", _save_manual))
	load_button = _button("读取 F9", _load_manual)
	header.add_child(load_button)
	header.add_child(_button("新旅程", _ask_new_game))
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
	_clear(stats)
	stats.add_child(_label(p.name, 25))
	stats.add_child(_label(session.realm_name(), 18, GOLD))
	stats.add_child(_label(session.content.sects[session.player.get("sect", "wanderer")].name, 16, MUTED))
	_meter(stats, "气血", p.hp, p.max_hp, Color("#a96f66"))
	_meter(stats, "灵力", p.qi, p.max_qi, Color("#5f999b"))
	stats.add_child(_label("年岁 %d  ·  寿元 %d" % [session.age(), session.lifespan()], 15, MUTED))
	_meter(stats, "修为", p.xp, maxi(1, maxi(int(p.xp), int(session.next_breakthrough().get("xp", 0)))), GOLD)
	stats.add_child(_label("灵石  %d    灵草  %d" % [p.stones, p.herbs], 16))
	stats.add_child(_label("筑基丹  %d" % p.pills, 16))
	stats.add_child(HSeparator.new())
	stats.add_child(_label("山 川 行 旅", 16, GOLD))
	travel_buttons.clear()
	for location_id: String in ["sect", "market", "wild"]:
		var definition: Dictionary = session.content.locations[location_id]
		var current: bool = p.location == location_id
		var days: int = session.content.route_days(p.location, location_id)
		var button := _button(definition.name + ("  ·  当前" if current else "  →"), func() -> void: _run(func() -> String: return session.travel(location_id)), "" if current else "路程 " + Calendar.duration_text(days))
		button.disabled = current or not session.battle.is_empty()
		stats.add_child(button)
		travel_buttons[location_id] = button
	load_button.disabled = not manual_store.has_save()
	_clear(center)
	if session.battle.is_empty():
		_render_location()
	else:
		_render_battle()
	journal_text.text = "\n".join(session.journal_lines())

func _objective() -> String:
	if session.has_flag("serpent_slain"):
		return "落霞谷灵泉已复。世事仍在流转，你可以继续修炼与游历。"
	var need: Dictionary = session.next_breakthrough()
	if need.is_empty():
		return "当前目标 · 休整后前往落霞谷，平定赤鳞妖蟒。"
	return "当前目标 · 积攒 %d 修为与 %d 枚筑基丹，在青云山突破。" % [int(need.xp), int(need.pills)]

func _duration(action: String) -> String:
	return Calendar.duration_text(session.content.action_days(action))

func _breakthrough_tooltip() -> String:
	var need: Dictionary = session.next_breakthrough()
	if need.is_empty():
		return "后续境界尚未开放"
	return "需要 %d 修为与 %d 枚筑基丹" % [int(need.xp), int(need.pills)]

func _realm_bonus_text() -> String:
	var bonus := int(session.content.realm(int(session.player.realm)).attack_bonus)
	return " 境界加成：攻击伤害 +%d。" % bonus if bonus > 0 else ""

func _render_location() -> void:
	if preview_mode:
		_sect_choices(center, true)
	var location: Dictionary = session.content.locations[session.player.location]
	var title_row := HBoxContainer.new()
	title_row.add_theme_constant_override("separation", 20)
	center.add_child(title_row)
	title_row.add_child(_label(location.name, 30, GOLD))
	title_row.add_child(_label(location.subtitle, 16, MUTED))
	var landscape = Landscape.new()
	landscape.location_id = session.player.location
	landscape.custom_minimum_size.y = 145
	center.add_child(landscape)
	center.add_child(_paragraph(location.description))
	center.add_child(_paragraph(_objective(), GOLD))
	var grid := GridContainer.new()
	grid.columns = 2
	grid.add_theme_constant_override("h_separation", 12)
	grid.add_theme_constant_override("v_separation", 10)
	center.add_child(grid)
	match session.player.location:
		"sect":
			_action(grid, "闭关修炼  ·  " + _duration("cultivate"), "cultivate", "修为 +18，恢复全部灵力")
			_action(grid, "静室休整  ·  " + _duration("rest"), "rest", "恢复全部气血与灵力")
			_enemy_action(grid, "同门切磋", "disciple", "获胜获得 12 修为与 12 灵石，斗法有受伤风险")
			_action(grid, "突破境界  ·  " + _duration("breakthrough"), "breakthrough", _breakthrough_tooltip())
		"market":
			_action(grid, "出售全部灵草", "sell", "每株灵草可换取 8 灵石")
			_action(grid, "购买筑基丹  ·  60 灵石", "buy_pill", "突破筑基所需丹药")
			center.add_child(_paragraph("坊市交易不耗时日。灵草可从落霞谷采集，也能通过斗法获得。"))
		"wild":
			_action(grid, "采集灵草  ·  " + _duration("gather"), "gather", "采得 2–4 株灵草")
			_enemy_action(grid, "讨伐妖狼", "wolf", "获胜获得 24 灵石、18 修为、2 灵草")
			var boss_button := _enemy_action(grid, "挑战赤鳞妖蟒", "serpent", "需达到筑基初期；平定后落霞谷重归安宁")
			boss_button.disabled = int(session.player.realm) < int(session.content.enemies.serpent.min_realm) or session.has_flag("serpent_slain")
	if session.player.location == "sect" and not preview_mode:
		_sect_choices(center, false)
	var names: Array[String] = []
	for id: String in session.active_skills():
		names.append(session.content.skills[id].name)
	center.add_child(_paragraph("已习神通 · " + " / ".join(names) + "。悬停神通按钮可查看效果。"))

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
	var enemy: Dictionary = session.content.enemies[b.enemy_id]
	center.add_child(_label("斗 法  ·  %s     第 %d 回合" % [enemy.name, b.turn], 23, GOLD))
	battle_stage = BattleStage.new()
	battle_stage.custom_minimum_size.y = 245 if preview_mode else 300
	battle_stage.configure(session.snapshot(), enemy)
	center.add_child(battle_stage)
	center.add_child(_paragraph("选择神通 · 守御回灵并减伤 · 出招期间请等待命中与对手反击"))
	var grid := GridContainer.new()
	grid.columns = 5
	grid.add_theme_constant_override("h_separation", 8)
	grid.add_theme_constant_override("v_separation", 10)
	center.add_child(grid)
	var index := 1
	for skill_id: String in session.active_skills():
		var skill: Dictionary = session.content.skills[skill_id]
		var remaining := int(b.cooldowns.get(skill_id, 0))
		var suffix := "\n冷却 %d" % remaining if remaining > 0 else "\n%d 灵力" % int(skill.qi_cost)
		var button := _button("[%d] %s%s" % [index, skill.name, suffix], func() -> void: _skill(skill_id), skill.description + _realm_bonus_text())
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
	if is_instance_valid(battle_stage) and not session.combat_events.is_empty():
		await battle_stage.play(session.combat_events.duplicate(true))
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
	var message: String = callback.call()
	notice(message + (" 自动存档失败：" + autosave_error if not autosave_error.is_empty() else ""))

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
	var begin_button := _button("踏入仙途", _begin)
	box.add_child(begin_button)
	var continue_button := _button("继续旅程", _continue)
	continue_button.disabled = not (auto_store.has_save() or manual_store.has_save())
	box.add_child(continue_button)
	if started:
		box.add_child(_button("返回当前旅程", _close_welcome))
	box.add_child(_paragraph("开发版 · Windows 单机 · 本地存档\n二维手绘角色 · 施法演出 · 命中与受击反馈"))
	name_input.grab_focus()

func _close_welcome() -> void:
	remove_child(welcome_layer)
	welcome_layer.queue_free()
	welcome_layer = null

func _begin() -> void:
	var character_name := name_input.text
	_close_welcome()
	started = true
	session.new_game(character_name)
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
		KEY_1, KEY_2, KEY_3:
			if not session.battle.is_empty():
				var ids := session.active_skills()
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
