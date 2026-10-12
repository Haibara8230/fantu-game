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
	_step("script started")
	create_timer(40).timeout.connect(func() -> void: printerr("Presentation test timeout"); quit(1))
	call_deferred("_run")

## Progress line, so a hung run's log shows the last stage it reached (see docs/BACKLOG.md).
func _step(stage: String) -> void:
	print("PRESENTATION step %d ms: %s" % [Time.get_ticks_msec(), stage])

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
	_step("run started")
	root.size = Vector2i(1280, 800)
	DirAccess.make_dir_recursive_absolute(ProjectSettings.globalize_path("res://builds/previews"))
	var scene: PackedScene = load("res://scenes/main.tscn")
	_step("main scene loaded")
	main = scene.instantiate()
	_step("main scene instantiated")
	var path := "res://.godot/presentation_saves_%d" % Time.get_ticks_usec()
	main.manual_store = SaveStore.new(path + "/manual")
	main.auto_store = SaveStore.new(path + "/auto")
	root.add_child(main)
	_step("main scene added")
	main.session.encounters_enabled = false
	main.name_input.text = "青禾"
	main.begin()
	main.session.combat_rng.seed = 42
	main.run(func() -> String: return main.session.start_battle("disciple"))
	_step("disciple duel started")
	await _capture("art_duel_idle")
	check(main.battle_stage.hero.sprite.texture.get_width() == 1536, "hero atlas loaded")
	check(main.battle_stage.enemy.sprite.flip_h, "rival faces player")
	check(main.battle_stage.background.resource_path == "res://assets/art/battle/%s.png" % main.session.snapshot().battle.place, "the battle place selects its generated backdrop")
	check(main.battle_stage.art_path(["res://assets/art/battle/none.png", "res://assets/art/beasts_atlas_v1.png", "res://assets/art/bamboo_arena_v1.png"]) == "res://assets/art/beasts_atlas_v1.png", "the first existing art wins")
	check(main.battle_stage.art_path(["res://assets/art/battle/none.png", "res://assets/art/bamboo_arena_v1.png"]) == "res://assets/art/bamboo_arena_v1.png", "missing art falls back")
	var looks: Dictionary = main.battle_stage._enemy_art("cultivator", {"foe": {"sect": "chixiao", "gender": "male"}})
	check(looks.texture == "res://assets/art/actors/cultivator_chixiao_male.png" and looks.columns == 3 and looks.rows == 2, "sect and gender select the generated six-pose atlas")
	var missing_look: Dictionary = main.battle_stage._enemy_art("cultivator", {"foe": {"sect": "missing", "gender": "male"}})
	check(missing_look.texture == "res://assets/art/rival_atlas_v2.png" and missing_look.columns == 3, "a missing look keeps the shared sprite grid")
	check(main.battle_stage._enemy_art("rogue", {}).texture == "res://assets/art/actors/rogue.png", "a named foe selects its generated sprite")
	check(main.battle_stage._enemy_art("ruin_rogue", {}).texture == "res://assets/art/actors/ruin_rogue.png", "the ruin rogue selects its generated sprite")
	var rogue_preferred: String = main.battle_stage.art.actors.rogue.preferred
	main.battle_stage.art.actors.rogue.preferred = "res://assets/art/actors/missing_rogue.png"
	check(main.battle_stage._enemy_art("rogue", {}).texture == "res://assets/art/rival_atlas_v2.png", "a named foe without its own sprite uses the shared one")
	main.battle_stage.art.actors.rogue.preferred = rogue_preferred
	_step("sword timeline")
	_watch_stage("art_sword")
	main.skill("sword")
	check(main.presenting, "input lock starts before animation")
	var after: Dictionary = main.session.snapshot()
	main.skill("fire")
	main._load_manual()
	main.run(func() -> String: return main.session.travel("wild"))
	check(main.session.snapshot() == after, "repeated actions, load and travel blocked during animation")
	await _wait_action()
	check(cue_sequence == ["prepare", "release", "impact", "prepare", "release", "impact"], "player attack then enemy counterattack timeline")
	check(not main.presenting, "input unlocks after animation")
	await main.battle_action("flee")
	main.run(func() -> String: return main.session.act("rest"))
	main.run(func() -> String: return main.session.travel("wild"))
	main.run(func() -> String: return main.session.start_battle("wolf"))
	_step("wolf duel: fire, heal, guard")
	_watch_stage("art_fire")
	await main.skill("fire")
	check(cue_sequence.count("impact") == 2, "fire and counterattack produce impact cues")
	_watch_stage("art_heal")
	await main.skill("wood")
	check(cue_sequence[0] == "heal", "healing has its own visual event")
	_watch_stage("art_guard")
	await main.battle_action("guard")
	check(cue_sequence[0] == "guard", "guard has its own visual event")
	await main.battle_action("flee")
	# Legal progression so boss presentation also exercises the real game's gate.
	_step("progressing to foundation")
	main.run(func() -> String: return main.session.travel("sect"))
	# Retreat while the mind is fresh; otherwise gather, which eases the mind, and buy a 破障丹 for a
	# bottleneck (as in core_smoke), so the serpent is met before it breaks out.
	var game = main.session
	var rounds := 0
	while game.player.xp < 2000 and rounds < 100:
		rounds += 1
		if game.at_bottleneck() and game.item_count("pozhang_pill") > 0:
			main.run(func() -> String: return game.use_item("pozhang_pill"))
		elif not game.at_bottleneck() and game.retreat_efficiency() >= 100:
			main.run(func() -> String: return game.cultivate(90))
		else:
			main.run(func() -> String: return game.travel("wild"))
			for i: int in 3:
				main.run(func() -> String: return game.act("gather"))
			main.run(func() -> String: return game.travel("market"))
			if not game.pending_event.is_empty():
				main.choose("decline")
			main.run(func() -> String: return game.act("sell"))
			if game.at_bottleneck():
				main.run(func() -> String: return game.buy("pozhang_pill"))
			main.run(func() -> String: return game.travel("sect"))
			if not game.pending_event.is_empty():
				main.choose("decline")
	main.run(func() -> String: return main.session.act("rest"))
	main.run(func() -> String: return main.session.travel("wild"))
	while int(main.session.herb_count()) * 4 + int(main.session.player.stones) < 120:
		main.run(func() -> String: return main.session.act("gather"))
	main.run(func() -> String: return main.session.travel("market"))
	if not main.session.pending_event.is_empty():
		main.choose("decline")
	main.run(func() -> String: return main.session.act("sell"))
	main.run(func() -> String: return main.session.buy("foundation_pill"))
	main.run(func() -> String: return main.session.travel("sect"))
	main.run(func() -> String: return main.session.act("breakthrough"))
	main.run(func() -> String: return main.session.travel("wild"))
	main.run(func() -> String: return main.session.start_battle("serpent"))
	_step("serpent duel started")
	await _capture("art_boss_idle")
	check(main.battle_stage.enemy.sprite.region_rect.position.y == 472, "serpent uses its own calibrated atlas region")
	_watch_stage("art_boss")
	await main.skill("fire")
	main._save_manual()
	await main.battle_action("guard")
	main._load_manual()
	check(not main.presenting and main.session.battle.enemy_id == "serpent", "load restores idle stage and active boss")
	_step("checking skill controls")
	await process_frame
	var buttons: Array[Node] = main.center.find_children("*", "Button", true, false)
	check(not buttons.is_empty(), "skill controls available")
	for button: Button in buttons:
		check(button.get_global_rect().end.y <= main.get_global_rect().end.y, "skill control inside screen")
	print("PRESENTATION: %d checks, %d failures, %d screenshots" % [checks, failures, screenshots])
	main.queue_free()
	await process_frame
	quit(0 if failures == 0 else 1)
