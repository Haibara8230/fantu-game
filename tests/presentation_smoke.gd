extends SceneTree
const SaveStore = preload("res://scripts/core/save_store.gd")
var main
var checks := 0
var failures := 0
var screenshots := 0
var shot_prefix := ""
var captured_cues: Dictionary = {}
var cue_sequence: Array[String] = []

func _initialize() -> void:
	create_timer(40).timeout.connect(func() -> void: printerr("Presentation test timeout"); quit(1))
	call_deferred("_run")

func check(condition: bool, message: String) -> void:
	checks += 1
	if not condition:
		failures += 1
		printerr("FAIL: " + message)

func _capture(name: String) -> void:
	await process_frame
	if DisplayServer.get_name() == "headless":
		return
	await RenderingServer.frame_post_draw
	var image := root.get_texture().get_image()
	var error := image.save_png("res://builds/previews/" + name + ".png")
	check(error == OK, "capture " + name)
	screenshots += 1

func _watch_stage(prefix: String) -> void:
	shot_prefix = prefix
	captured_cues.clear()
	cue_sequence.clear()
	main.battle_stage.cue.connect(func(kind: String) -> void:
		cue_sequence.append(kind)
		if kind in ["release", "impact", "heal", "guard"] and not captured_cues.has(kind):
			captured_cues[kind] = true
			_capture(shot_prefix + "_" + kind)
	)

func _wait_action() -> void:
	while main.presenting:
		await process_frame
	await process_frame

func _run() -> void:
	root.size = Vector2i(1280, 800)
	DirAccess.make_dir_recursive_absolute(ProjectSettings.globalize_path("res://builds/previews"))
	main = load("res://scenes/main.tscn").instantiate()
	var path := "res://.godot/presentation_saves_%d" % Time.get_ticks_usec()
	main.manual_store = SaveStore.new(path + "/manual")
	main.auto_store = SaveStore.new(path + "/auto")
	root.add_child(main)
	main.session.encounters_enabled = false
	main.name_input.text = "青禾"
	main._begin()
	main.session.combat_rng.seed = 42
	main._run(func() -> String: return main.session.start_battle("disciple"))
	await _capture("art_duel_idle")
	check(main.battle_stage.hero.sprite.texture.get_width() == 1536, "hero atlas loaded")
	check(main.battle_stage.enemy.sprite.flip_h, "rival faces player")
	_watch_stage("art_sword")
	main._skill("sword")
	check(main.presenting, "input lock starts before animation")
	var after: Dictionary = main.session.snapshot()
	main._skill("fire")
	main._load_manual()
	main._run(func() -> String: return main.session.travel("wild"))
	check(main.session.snapshot() == after, "repeated actions, load and travel blocked during animation")
	await _wait_action()
	check(cue_sequence == ["prepare", "release", "impact", "prepare", "release", "impact"], "player attack then enemy counterattack timeline")
	check(not main.presenting, "input unlocks after animation")
	await main._battle_action("flee")
	main._run(func() -> String: return main.session.act("rest"))
	main._run(func() -> String: return main.session.travel("wild"))
	main._run(func() -> String: return main.session.start_battle("wolf"))
	_watch_stage("art_fire")
	await main._skill("fire")
	check(cue_sequence.count("impact") == 2, "fire and counterattack produce impact cues")
	_watch_stage("art_heal")
	await main._skill("wood")
	check(cue_sequence[0] == "heal", "healing has its own visual event")
	_watch_stage("art_guard")
	await main._battle_action("guard")
	check(cue_sequence[0] == "guard", "guard has its own visual event")
	await main._battle_action("flee")
	# Legal progression so boss presentation also exercises the real game's gate.
	main._run(func() -> String: return main.session.travel("sect"))
	while main.session.player.xp < 2000:
		main._run(func() -> String: return main.session.cultivate(360))
	main._run(func() -> String: return main.session.act("rest"))
	main._run(func() -> String: return main.session.travel("wild"))
	while int(main.session.herb_count()) * 4 + int(main.session.player.stones) < 120:
		main._run(func() -> String: return main.session.act("gather"))
	main._run(func() -> String: return main.session.travel("market"))
	if not main.session.pending_event.is_empty():
		main._choose("decline")
	main._run(func() -> String: return main.session.act("sell"))
	main._run(func() -> String: return main.session.buy("foundation_pill"))
	main._run(func() -> String: return main.session.travel("sect"))
	main._run(func() -> String: return main.session.act("breakthrough"))
	main._run(func() -> String: return main.session.travel("wild"))
	main._run(func() -> String: return main.session.start_battle("serpent"))
	await _capture("art_boss_idle")
	check(main.battle_stage.enemy.sprite.region_rect.position.y == 472, "serpent uses its own calibrated atlas region")
	_watch_stage("art_boss")
	await main._skill("fire")
	main._save_manual()
	await main._battle_action("guard")
	main._load_manual()
	check(not main.presenting and main.session.battle.enemy_id == "serpent", "load restores idle stage and active boss")
	await process_frame
	var buttons: Array[Node] = main.center.find_children("*", "Button", true, false)
	check(not buttons.is_empty(), "skill controls available")
	for button: Button in buttons:
		check(button.get_global_rect().end.y <= main.get_global_rect().end.y, "skill control inside screen")
	print("PRESENTATION: %d checks, %d failures, %d screenshots" % [checks, failures, screenshots])
	main.queue_free()
	await process_frame
	quit(0 if failures == 0 else 1)
