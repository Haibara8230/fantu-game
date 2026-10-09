extends SceneTree
const SaveStore = preload("res://scripts/core/save_store.gd")
var main
var captures := 0
var checks := 0
var failures := 0

func _initialize() -> void:
	create_timer(20.0).timeout.connect(func() -> void: printerr("UI test timed out" ); quit(1))
	call_deferred("_run")

# Counted checks instead of assert(): a failed assert halts a headless run instead of failing it.
func check(condition: bool, message: String) -> void:
	checks += 1
	if not condition:
		failures += 1
		printerr("FAIL: " + message)

func _capture(filename: String) -> void:
	await process_frame
	await process_frame
	if not DisplayServer.get_name() == "headless":
		await RenderingServer.frame_post_draw
		var image := root.get_texture().get_image()
		image.save_png("res://builds/previews/" + filename + ".png")
		captures += 1

func _texts(node: Node, type: String) -> String:
	return "\n".join(node.find_children("*", type, true, false).map(func(control: Control) -> String: return control.text))

func _button(text_part: String) -> Button:
	for button: Button in main.center.find_children("*", "Button", true, false):
		if button.text.contains(text_part):
			return button
	return null

func _run() -> void:
	root.size = Vector2i(1280, 800)
	DirAccess.make_dir_recursive_absolute(ProjectSettings.globalize_path("res://builds/previews"))
	main = load("res://scenes/main.tscn").instantiate()
	var test_path := "res://.godot/ui_saves_%d" % Time.get_ticks_usec()
	main.manual_store = SaveStore.new(test_path + "/manual")
	main.auto_store = SaveStore.new(test_path + "/auto")
	root.add_child(main)
	await _capture("welcome")
	main.name_input.text = "青禾"
	main._begin()
	await _capture("sect")
	check(main.status_label.get_global_rect().end.y <= main.get_global_rect().end.y + 1, "status line inside the window")
	check(main.clock_label.text == "历元 1 年 1 月初一", "calendar shown")
	check(main.journal_text.text.begins_with("【1年1月初一】你拜入青云山"), "chronicle shown")
	var sidebar := _texts(main.stats, "Label")
	check(sidebar.contains("年岁 16") and sidebar.contains("寿元 120") and sidebar.contains("寿元尽于历元 105 年"), "age and lifespan shown")
	check(_button("闭关  ·  1 个月") != null and _button("闭关  ·  1 年") != null and _button("停留  ·  1 日") != null, "retreat lengths and waiting offered")
	main._save_manual()
	main._run(func() -> String: return main.session.travel("wild"))
	await _capture("wild")
	check(main.clock_label.text == "历元 1 年 2 月初一", "travel advances the calendar")
	main._run(func() -> String: return main.session.start_battle("wolf"))
	await main._skill("fire")
	await _capture("battle")
	root.size = Vector2i(1000, 640)
	await _capture("battle_small")
	check(main.status_label.get_global_rect().end.y <= main.get_global_rect().end.y + 1, "status line inside the small window")
	root.size = Vector2i(1280, 800)
	main._show_welcome()
	main._continue()
	check(main.started and main.session.battle.get("enemy_id", "") == "wolf", "continue restores the battle")
	main._load_manual()
	check(main.session.player.location == "sect" and main.session.battle.is_empty(), "manual load restores the sect")
	# Location events and the choice panel.
	main._run(func() -> String: return main.session.travel("market"))
	check(_texts(main.stats, "Label").contains("相识 · 沈墨"), "new acquaintance listed")
	main.session.player.herbs = 5
	_button("停留  ·  1 日").pressed.emit()
	await _capture("event")
	check(main.session.pending_event.get("id", "") == "shen_request" and _button("交出五株灵草") != null, "choice panel shown")
	var travel_locked := true
	for button: Button in main.travel_buttons.values():
		travel_locked = travel_locked and button.disabled
	check(travel_locked, "travel locked while a choice is pending")
	_button("交出五株灵草").pressed.emit()
	await process_frame
	check(main.session.pending_event.is_empty() and _texts(main.stats, "Label").contains("交情 1"), "choice resolves and updates the sidebar")
	# The end of a life.
	main._run(func() -> String: return main.session.travel("sect"))
	main.session.player.birth_day = int(main.session.world.day) + 30 - 120 * 360
	main._run(func() -> String: return main.session.cultivate(360))
	main._run(func() -> String: return main.session.cultivate(360))
	await _capture("ending")
	check(not main.session.ended.is_empty() and _texts(main.center, "Label").contains("此 生 已 尽"), "ending screen shown")
	main._load_manual()
	check(main.session.ended.is_empty(), "loading a save returns from the ending")
	main._ask_new_game()
	await process_frame
	main.new_game_dialog.hide()
	print("UI: %d checks, %d failures; %d captures" % [checks, failures, captures])
	main.queue_free()
	await process_frame
	quit(0 if failures == 0 else 1)
