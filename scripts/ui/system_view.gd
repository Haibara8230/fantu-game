extends RefCounted
## 系统: saving and loading by hand, a new journey and the settings, with the keys that do the same.
const Settings = preload("res://scripts/ui/settings.gd")

static func render(ui) -> void:
	var center: VBoxContainer = ui.center
	var grid := GridContainer.new()
	grid.columns = 2
	grid.add_theme_constant_override("h_separation", 12)
	grid.add_theme_constant_override("v_separation", 10)
	center.add_child(grid)
	ui.save_button = ui.button("保存 " + Settings.key_name(ui, "save"), ui._save_manual, "手动存档，可随时读回这个时刻")
	ui.load_button = ui.button("读取 " + Settings.key_name(ui, "load"), ui._load_manual, "读取手动存档")
	ui.load_button.disabled = not ui.manual_store.has_save()
	for entry: Button in [ui.save_button, ui.load_button, ui.button("新旅程", ui._ask_new_game), ui.button("设置", ui._open_settings)]:
		entry.custom_minimum_size.x = 220
		grid.add_child(entry)
	var hints: Dictionary = Settings.key_hints(ui)
	center.add_child(ui.paragraph("%s 保存 · %s 读取 · Esc 取消配气／关闭面板 · 斗法中按 %s 选招，%s 确认／结束回合。自动存档%s。" % [hints.save, hints.load, hints.skills, hints.end_turn, "开启" if ui.autosave_enabled else "已关闭"]))

	if not ui.audio.library.get("music_credits", []).is_empty():
		center.add_child(ui.button("配乐鸣谢", func() -> void: _show_music_credits(ui)))

## Credits travel in audio.json, so they are available in source builds and exported games alike.
static func _show_music_credits(ui) -> void:
	var dialog := AcceptDialog.new()
	dialog.title = "配乐鸣谢"
	dialog.ok_button_text = "关闭"
	var scroll := ScrollContainer.new()
	scroll.custom_minimum_size = Vector2(680, 360)
	scroll.horizontal_scroll_mode = ScrollContainer.SCROLL_MODE_DISABLED
	dialog.add_child(scroll)
	var body := VBoxContainer.new()
	body.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	body.add_theme_constant_override("separation", 10)
	scroll.add_child(body)
	for entry: Dictionary in ui.audio.library.get("music_credits", []):
		body.add_child(ui.label("%s · %s" % [entry.title, entry.author], 17, ui.GOLD))
		body.add_child(ui.paragraph(str(entry.changes)))
		var links := HBoxContainer.new()
		links.add_theme_constant_override("separation", 24)
		body.add_child(links)
		var source := LinkButton.new()
		source.text = "作品来源"
		source.pressed.connect(func() -> void: OS.shell_open(str(entry.source)))
		links.add_child(source)
		var license_link := LinkButton.new()
		license_link.text = str(entry.license)
		license_link.pressed.connect(func() -> void: OS.shell_open(str(entry.license_url)))
		links.add_child(license_link)
	ui.add_child(dialog)
	dialog.visibility_changed.connect(func() -> void:
		if not dialog.visible:
			dialog.queue_free())
	dialog.popup_centered(Vector2i(740, 480))
