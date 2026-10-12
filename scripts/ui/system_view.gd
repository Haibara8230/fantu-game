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
	center.add_child(ui.paragraph("%s 保存 · %s 读取 · Esc 关闭面板 · 斗法中按 %s 施法，%s 守御。自动存档%s。" % [hints.save, hints.load, hints.skills, hints.guard, "开启" if ui.autosave_enabled else "已关闭"]))
