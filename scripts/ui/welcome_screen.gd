extends RefCounted
## The title screen over the interface: name, spirit roots (sensed again on request), a new journey or
## continuing a saved one.

static func build(ui) -> void:
	var session = ui.session
	var welcome_layer := ColorRect.new()
	ui.welcome_layer = welcome_layer
	welcome_layer.color = Color(0.025, 0.045, 0.055, 0.97)
	welcome_layer.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	ui.add_child(welcome_layer)
	var centered := CenterContainer.new()
	centered.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	welcome_layer.add_child(centered)
	var panel: PanelContainer = ui.panel()
	panel.custom_minimum_size.x = 520
	centered.add_child(panel)
	var box := VBoxContainer.new()
	box.add_theme_constant_override("separation", 18)
	panel.add_child(box)
	box.add_child(ui.label("凡 途", 48, ui.GOLD))
	box.add_child(ui.label("一介凡身，问道长生。", 22))
	box.add_child(ui.paragraph("历元元年 · 青云山外门\n修炼、游历、结交，在流转的岁月里寻求长生之道。"))
	var name_input := LineEdit.new()
	ui.name_input = name_input
	name_input.placeholder_text = "道号（最多 16 字）"
	name_input.max_length = 16
	name_input.custom_minimum_size.y = 46
	name_input.text_submitted.connect(func(_value: String) -> void: ui.begin())
	box.add_child(name_input)
	# Spirit roots are sensed at random; the player may sense again until satisfied.
	var sense_rng := RandomNumberGenerator.new()
	sense_rng.randomize()
	ui.welcome_roots = session.roll_roots(sense_rng)
	var roots_row := HBoxContainer.new()
	roots_row.add_theme_constant_override("separation", 12)
	box.add_child(roots_row)
	var roots_label: Label = ui.label("", 18, ui.GOLD)
	ui.roots_label = roots_label
	roots_label.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	roots_row.add_child(roots_label)
	roots_row.add_child(ui.button("重新感应", func() -> void:
		ui.welcome_roots = session.roll_roots(sense_rng)
		_show_roots(ui), "再测一次灵根"))
	_show_roots(ui)
	var begin_button: Button = ui.button("踏入仙途", ui.begin)
	box.add_child(begin_button)
	var continue_button: Button = ui.button("继续旅程", ui.continue_saved)
	continue_button.disabled = not (ui.auto_store.has_save() or ui.manual_store.has_save())
	box.add_child(continue_button)
	if ui.started:
		box.add_child(ui.button("返回当前旅程", ui.close_welcome))
	box.add_child(ui.paragraph("开发版 · Windows 单机 · 本地存档\n二维手绘角色 · 施法演出 · 命中与受击反馈"))
	name_input.grab_focus()

static func _show_roots(ui) -> void:
	var grade: Dictionary = ui.session.content.root_grade(ui.welcome_roots)
	ui.roots_label.text = "灵根 · %s（修炼 ×%.2f）" % [ui.session.content.root_title(ui.welcome_roots), float(grade.speed)]
