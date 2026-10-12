extends RefCounted
## The settings dialog and the preferences it keeps besides the volumes: window mode and size, how
## fast story text types itself out, the key bindings and auto-save. They live in the player's
## settings file next to the volumes (audio_director.gd keeps the "audio" section), never in saves.
const DEFAULT_PATH := "user://settings.cfg"
const WINDOW_SIZES: Array[Vector2i] = [Vector2i(1000, 640), Vector2i(1280, 800), Vector2i(1440, 900), Vector2i(1600, 1000), Vector2i(1920, 1200)]
const DEFAULT_SIZE := Vector2i(1280, 800)
# Characters per second when story text types itself out; 0 shows it at once.
const TEXT_SPEEDS := {"instant": 0, "fast": 60, "normal": 30, "slow": 15}
const TEXT_SPEED_NAMES := {"instant": "即时", "fast": "快", "normal": "中", "slow": "慢"}
const DEFAULT_TEXT_SPEED := "fast"
# The rebindable keys, in the order the dialog lists them.
const ACTIONS := ["save", "load", "skill_1", "skill_2", "skill_3", "skill_4", "guard"]
const ACTION_NAMES := {"save": "保存", "load": "读取", "skill_1": "第一门神通", "skill_2": "第二门神通", "skill_3": "第三门神通", "skill_4": "第四门神通", "guard": "守御"}
const DEFAULT_KEYS := {"save": KEY_F5, "load": KEY_F9, "skill_1": KEY_1, "skill_2": KEY_2, "skill_3": KEY_3, "skill_4": KEY_4, "guard": KEY_SPACE}
# Keys the dialogs need themselves, and modifiers that are no key on their own.
const RESERVED_KEYS := [KEY_ESCAPE, KEY_ENTER, KEY_KP_ENTER, KEY_TAB, KEY_SHIFT, KEY_CTRL, KEY_ALT, KEY_META, KEY_CAPSLOCK]

static func load_state(ui) -> void:
	ui.fullscreen = false
	ui.window_size = DEFAULT_SIZE
	ui.text_speed = DEFAULT_TEXT_SPEED
	ui.autosave_enabled = true
	ui.keys = DEFAULT_KEYS.duplicate()
	var config := ConfigFile.new()
	if config.load(ui.settings_path) != OK:
		return
	var fullscreen: Variant = config.get_value("display", "fullscreen", false)
	ui.fullscreen = fullscreen is bool and fullscreen
	var size: Variant = config.get_value("display", "window_size", DEFAULT_SIZE)
	if size is Vector2i and size in WINDOW_SIZES:
		ui.window_size = size
	var speed: Variant = config.get_value("text", "speed", DEFAULT_TEXT_SPEED)
	if speed is String and TEXT_SPEEDS.has(speed):
		ui.text_speed = speed
	# Only an explicit false switches auto-save off.
	var autosave: Variant = config.get_value("saves", "autosave", true)
	ui.autosave_enabled = not (autosave is bool and not autosave)
	var saved: Variant = config.get_value("controls", "keys", {})
	if saved is Dictionary:
		var keys: Dictionary = DEFAULT_KEYS.duplicate()
		for action: String in ACTIONS:
			var code: Variant = saved.get(action)
			if code is int and code > 0 and not code in RESERVED_KEYS:
				keys[action] = code
		# A file with one key on two actions falls back to the defaults.
		var codes := {}
		for action: String in ACTIONS:
			codes[keys[action]] = true
		if codes.size() == ACTIONS.size():
			ui.keys = keys

## Writes this module's sections, keeping whatever else the file holds (the volumes).
static func save_state(ui) -> void:
	var config := ConfigFile.new()
	config.load(ui.settings_path)
	config.set_value("display", "fullscreen", ui.fullscreen)
	config.set_value("display", "window_size", ui.window_size)
	config.set_value("text", "speed", ui.text_speed)
	config.set_value("saves", "autosave", ui.autosave_enabled)
	config.set_value("controls", "keys", ui.keys.duplicate())
	config.save(ui.settings_path)

# --- Window ------------------------------------------------------------------------------------

## Whether a window of `size` fits on the screen the game is on (always, without a screen).
static func fits(ui, size: Vector2i) -> bool:
	if DisplayServer.get_name() == "headless":
		return true
	var usable := DisplayServer.screen_get_usable_rect(ui.get_window().current_screen).size
	return size.x <= usable.x and size.y <= usable.y

## Puts the window into the chosen mode and size. `at_start` leaves an unchanged default window alone.
static func apply_window(ui, at_start: bool = false) -> void:
	if DisplayServer.get_name() == "headless" or (at_start and not ui.fullscreen and ui.window_size == DEFAULT_SIZE):
		return
	var window: Window = ui.get_window()
	if ui.fullscreen:
		window.mode = Window.MODE_FULLSCREEN
		return
	window.mode = Window.MODE_WINDOWED
	var size: Vector2i = ui.window_size
	if not fits(ui, size):
		size = DEFAULT_SIZE if fits(ui, DEFAULT_SIZE) else WINDOW_SIZES[0]
	window.size = size
	window.move_to_center()

static func set_fullscreen(ui, on: bool) -> void:
	ui.fullscreen = on
	save_state(ui)
	apply_window(ui)
	sync(ui)

static func set_window_size(ui, index: int) -> void:
	ui.window_size = WINDOW_SIZES[clampi(index, 0, WINDOW_SIZES.size() - 1)]
	save_state(ui)
	apply_window(ui)

# --- Text and saving ------------------------------------------------------------------------------

static func set_text_speed(ui, speed: String) -> void:
	if TEXT_SPEEDS.has(speed):
		ui.text_speed = speed
		save_state(ui)

static func characters_per_second(ui) -> int:
	return int(TEXT_SPEEDS.get(ui.text_speed, 0))

static func set_autosave(ui, on: bool) -> void:
	ui.autosave_enabled = on
	save_state(ui)

# --- Keys --------------------------------------------------------------------------------------------

## The action bound to a key, or "".
static func action_for_key(ui, keycode: int) -> String:
	for action: String in ACTIONS:
		if int(ui.keys.get(action, 0)) == keycode:
			return action
	return ""

static func key_name(ui, action: String) -> String:
	var code := int(ui.keys.get(action, DEFAULT_KEYS[action]))
	return "空格" if code == KEY_SPACE else OS.get_keycode_string(code)

## Key names for texts that mention the controls (the guide's tips): {save}, {load}, {skills}, {guard}.
static func key_hints(ui) -> Dictionary:
	var skills: Array[String] = []
	for index: int in range(1, 5):
		skills.append(key_name(ui, "skill_%d" % index))
	return {"save": key_name(ui, "save"), "load": key_name(ui, "load"), "skills": " / ".join(skills), "guard": key_name(ui, "guard")}

## Binds `keycode` to `action`; an action that had the key takes the action's old key instead.
static func bind_key(ui, action: String, keycode: int) -> bool:
	if not action in ACTIONS or keycode <= 0 or keycode in RESERVED_KEYS:
		return false
	var previous := int(ui.keys[action])
	for other: String in ACTIONS:
		if other != action and int(ui.keys[other]) == keycode:
			ui.keys[other] = previous
	ui.keys[action] = keycode
	save_state(ui)
	ui.refresh_key_labels()
	sync(ui)
	return true

static func reset_keys(ui) -> void:
	ui.keys = DEFAULT_KEYS.duplicate()
	save_state(ui)
	ui.refresh_key_labels()
	sync(ui)

## Waits for the next key press in the dialog for `action`; pressing the same button again cancels.
static func begin_binding(ui, action: String) -> void:
	if ui.binding_action == action:
		end_binding(ui)
		return
	ui.binding_action = action
	ui.settings_dialog.dialog_close_on_escape = false
	var target: Button = ui.settings_controls.keys[action]
	target.text = "请按键…"
	target.release_focus()

static func end_binding(ui) -> void:
	ui.binding_action = ""
	# Deferred, so the Esc that cancelled a binding does not also close the dialog.
	ui.settings_dialog.set_deferred("dialog_close_on_escape", true)
	sync(ui)

static func _capture(ui, event: InputEvent) -> void:
	if ui.binding_action.is_empty() or not event is InputEventKey or not event.pressed or event.echo:
		return
	var code: int = (event as InputEventKey).keycode
	if code == KEY_ESCAPE:
		end_binding(ui)
	elif bind_key(ui, ui.binding_action, code):
		end_binding(ui)
	else:
		return
	ui.settings_dialog.set_input_as_handled()

# --- The dialog -------------------------------------------------------------------------------------

static func build(ui) -> void:
	var dialog := AcceptDialog.new()
	dialog.title = "设置"
	dialog.ok_button_text = "完成"
	ui.settings_dialog = dialog
	var tabs := TabContainer.new()
	dialog.add_child(tabs)
	var controls := {}
	ui.settings_controls = controls

	var sound := _page(tabs, "声音")
	for entry: Array in [["Master", "总音量"], ["Music", "配乐"], ["SFX", "音效"], ["Ambience", "环境声"]]:
		var bus_name: String = entry[0]
		var row := _row(ui, sound, entry[1])
		var slider := HSlider.new()
		slider.name = bus_name
		slider.min_value = 0.0
		slider.max_value = 1.0
		slider.step = 0.05
		slider.custom_minimum_size.x = 280
		slider.size_flags_vertical = Control.SIZE_SHRINK_CENTER
		slider.value_changed.connect(func(value: float) -> void: ui.audio.set_volume(bus_name, value))
		row.add_child(slider)

	var screen := _page(tabs, "画面")
	var fullscreen := CheckBox.new()
	fullscreen.text = "全屏"
	fullscreen.toggled.connect(func(on: bool) -> void: set_fullscreen(ui, on))
	screen.add_child(fullscreen)
	controls.fullscreen = fullscreen
	var sizes := OptionButton.new()
	for size: Vector2i in WINDOW_SIZES:
		sizes.add_item("%d × %d" % [size.x, size.y])
	sizes.item_selected.connect(func(index: int) -> void: set_window_size(ui, index))
	_row(ui, screen, "窗口大小").add_child(sizes)
	controls.sizes = sizes
	screen.add_child(ui.paragraph("画面按比例缩放，排版不变。全屏时使用屏幕本身的分辨率。"))

	var keys := _page(tabs, "按键")
	var grid := GridContainer.new()
	grid.columns = 2
	grid.add_theme_constant_override("h_separation", 16)
	grid.add_theme_constant_override("v_separation", 6)
	keys.add_child(grid)
	controls.keys = {}
	for action: String in ACTIONS:
		grid.add_child(ui.label(ACTION_NAMES[action], 16))
		var key_button: Button = ui.button("", func() -> void: begin_binding(ui, action), "点击后按下新的按键；Esc 取消")
		key_button.custom_minimum_size = Vector2(140, 34)
		grid.add_child(key_button)
		controls.keys[action] = key_button
	keys.add_child(ui.button("恢复默认按键", func() -> void: reset_keys(ui)))

	var play := _page(tabs, "游戏")
	var speeds := OptionButton.new()
	for speed: String in TEXT_SPEEDS:
		speeds.add_item(TEXT_SPEED_NAMES[speed])
	speeds.item_selected.connect(func(index: int) -> void: set_text_speed(ui, TEXT_SPEEDS.keys()[index]))
	_row(ui, play, "文字速度").add_child(speeds)
	controls.speeds = speeds
	var autosave := CheckBox.new()
	autosave.text = "自动存档"
	autosave.toggled.connect(func(on: bool) -> void: set_autosave(ui, on))
	play.add_child(autosave)
	controls.autosave = autosave
	play.add_child(ui.paragraph("关闭后只在手动保存时存档，离开游戏前请先保存。「继续旅程」读取较新的那份存档。"))
	var guide_row := HBoxContainer.new()
	guide_row.add_theme_constant_override("separation", 12)
	var guide := CheckBox.new()
	guide.text = "显示新手指引"
	guide.toggled.connect(ui.set_guide_enabled)
	guide_row.add_child(guide)
	guide_row.add_child(ui.button("重新显示全部指引", ui.reset_guide))
	play.add_child(guide_row)
	ui.guide_toggle = guide

	dialog.window_input.connect(func(event: InputEvent) -> void: _capture(ui, event))
	dialog.visibility_changed.connect(func() -> void:
		if not dialog.visible and not ui.binding_action.is_empty():
			end_binding(ui))
	ui.add_child(dialog)

## Shows the current values in the dialog's controls.
static func sync(ui) -> void:
	var controls: Dictionary = ui.settings_controls
	if controls.is_empty():
		return
	for slider: HSlider in ui.settings_dialog.find_children("*", "HSlider", true, false):
		slider.set_value_no_signal(float(ui.audio.volumes.get(slider.name, 0.0)))
	controls.fullscreen.set_pressed_no_signal(ui.fullscreen)
	var sizes: OptionButton = controls.sizes
	for index: int in range(WINDOW_SIZES.size()):
		sizes.set_item_disabled(index, not fits(ui, WINDOW_SIZES[index]))
	sizes.select(WINDOW_SIZES.find(ui.window_size))
	sizes.disabled = ui.fullscreen
	controls.speeds.select(TEXT_SPEEDS.keys().find(ui.text_speed))
	controls.autosave.set_pressed_no_signal(ui.autosave_enabled)
	ui.guide_toggle.set_pressed_no_signal(ui.guide_enabled)
	for action: String in ACTIONS:
		var key_button: Button = controls.keys[action]
		key_button.text = "请按键…" if ui.binding_action == action else key_name(ui, action)

static func open(ui) -> void:
	sync(ui)
	ui.settings_dialog.popup_centered(Vector2i(520, 400))

static func _page(tabs: TabContainer, title: String) -> VBoxContainer:
	var page := VBoxContainer.new()
	page.add_theme_constant_override("separation", 10)
	tabs.add_child(page)
	tabs.set_tab_title(tabs.get_tab_count() - 1, title)
	return page

static func _row(ui, page: VBoxContainer, title: String) -> HBoxContainer:
	var row := HBoxContainer.new()
	row.add_theme_constant_override("separation", 12)
	var caption: Label = ui.label(title, 16)
	caption.custom_minimum_size.x = 80
	row.add_child(caption)
	page.add_child(row)
	return row
