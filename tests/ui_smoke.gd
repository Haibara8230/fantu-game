extends SceneTree
const SaveStore = preload("res://scripts/core/save_store.gd")
var main
var captures := 0

func _initialize() -> void:
	create_timer(15.0).timeout.connect(func() -> void: printerr("UI test timed out" ); quit(1))
	call_deferred("_run")

func _capture(filename: String) -> void:
	await process_frame
	await process_frame
	if not DisplayServer.get_name() == "headless":
		await RenderingServer.frame_post_draw
		var image := root.get_texture().get_image()
		image.save_png("res://builds/previews/" + filename + ".png")
		captures += 1

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
	assert(main.status_label.get_global_rect().end.y <= main.get_global_rect().end.y + 1)
	main._save_manual()
	main._run(func() -> String: return main.session.travel("wild"))
	await _capture("wild")
	main._run(func() -> String: return main.session.start_battle("wolf"))
	await main._skill("fire")
	await _capture("battle")
	root.size = Vector2i(1000, 640)
	await _capture("battle_small")
	assert(main.status_label.get_global_rect().end.y <= main.get_global_rect().end.y + 1)
	root.size = Vector2i(1280, 800)
	main._show_welcome()
	main._continue()
	assert(main.started and main.session.battle.get("enemy_id", "") == "wolf")
	main._load_manual()
	assert(main.session.player.location == "sect" and main.session.battle.is_empty())
	main._ask_new_game()
	await process_frame
	main.new_game_dialog.hide()
	print("UI: scene, welcome, gameplay, battle, save/load passed; %d captures" % captures)
	main.queue_free()
	await process_frame
	quit()
