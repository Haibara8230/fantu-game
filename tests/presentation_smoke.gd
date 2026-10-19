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
	root.size = Vector2i(1920, 1080)
	DirAccess.make_dir_recursive_absolute(ProjectSettings.globalize_path("res://builds/previews"))
	var scene: PackedScene = load("res://scenes/main.tscn")
	_step("main scene loaded")
	main = scene.instantiate()
	_step("main scene instantiated")
	var path := "res://.godot/presentation_saves_%d" % Time.get_ticks_usec()
	main.manual_store = SaveStore.new(path + "/manual")
	main.auto_store = SaveStore.new(path + "/auto")
	root.add_child(main)
	# The new-player guide has its own checks in ui_smoke; its tips would only shift this layout.
	main.guide_enabled = false
	# Default settings (keys, auto-save), whatever the player's own settings file says.
	main.settings_path = path + "/settings.cfg"
	main.Settings.load_state(main)
	main.refresh_key_labels()
	_step("main scene added")
	main.session.encounters_enabled = false
	main.name_input.text = "青禾"
	main.begin()
	# A fixed world and an ordinary three-element root keep the long progression below repeatable;
	# sensed roots are random, and a weak one would reach the serpent too late.
	main.session.new_game("青禾", 42, ["metal", "wood", "fire"])
	# The guided start's opening words belong to the journey just replaced.
	main.close_story()
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
	# A known hand: enough for the sword, and for the fire and healing arts later.
	main.session.battle.orbs = ["metal", "fire", "fire", "wood", "wood"]
	_watch_stage("art_sword")
	main.skill("sword")
	check(main.presenting, "input lock starts before animation")
	var after: Dictionary = main.session.snapshot()
	main.skill("fire")
	main._load_manual()
	main.run(func() -> String: return main.session.travel("wild"))
	check(main.session.snapshot() == after, "repeated actions, load and travel blocked during animation")
	await _wait_action()
	check(cue_sequence == ["prepare", "release", "impact"], "a cast plays the art alone; the turn goes on")
	check(not main.presenting, "input unlocks after animation")
	_watch_stage("art_answer")
	await main.battle_action("end_turn")
	check(cue_sequence == ["prepare", "release", "impact"], "ending the turn plays the opponent's answer")
	# Fleeing a foe of one's own realm may fail (the foe then takes its turn); keep trying.
	while not main.session.battle.is_empty():
		await main.battle_action("flee")
	main.run(func() -> String: return main.session.act("rest"))
	main.run(func() -> String: return main.session.travel("wild"))
	main.run(func() -> String: return main.session.start_battle("wolf"))
	_step("wolf duel: fire, heal, guard")
	for art: String in ["fire", "wood"]:
		if not art in main.session.player.learned:
			main.session.player.learned.append(art)
	main.session.player.arts = ["qi_strike", "fire", "wood"]
	main.session.battle.orbs = ["fire", "fire", "wood", "wood"]
	_watch_stage("art_fire")
	await main.skill("fire")
	check(cue_sequence.count("impact") == 1 and not main.session.battle.is_empty(), "fire produces its impact cue")
	_watch_stage("art_heal")
	await main.skill("wood")
	check(cue_sequence[0] == "heal", "healing has its own visual event")
	_watch_stage("art_guard")
	await main.battle_action("guard")
	check(cue_sequence[0] == "guard", "guard has its own visual event")
	while not main.session.battle.is_empty():
		await main.battle_action("flee")
	# Legal progression so boss presentation also exercises the real game's gate.
	_step("progressing to foundation")
	main.run(func() -> String: return main.session.travel("sect"))
	# Retreat while the mind is fresh; otherwise spar (which tempers the mind), gather, which eases it,
	# and buy a 破障丹 for a bottleneck (as in core_smoke), so the serpent is met before it breaks out.
	var game = main.session
	var rounds := 0
	while game.player.xp < 2000 and rounds < 300:
		rounds += 1
		if game.at_bottleneck() and game.item_count("pozhang_pill") > 0:
			main.run(func() -> String: return game.use_item("pozhang_pill"))
		elif not game.at_bottleneck() and game.retreat_efficiency() >= 100 and game.mind_percent() >= 100:
			main.run(func() -> String: return game.cultivate(90))
		else:
			for bout: int in 2:
				main.run(func() -> String: return game.start_battle("disciple"))
				while not game.battle.is_empty():
					main.run(func() -> String: return game.plain_turn())
			main.run(func() -> String: return game.act("rest"))
			main.run(func() -> String: return game.travel("wild"))
			for i: int in 3:
				main.run(func() -> String: return game.act("gather"))
			main.run(func() -> String: return game.travel("market"))
			while not game.pending_event.is_empty():
				main.choose(str(game.pending_definition().choices.back().id))
			main.run(func() -> String: return game.act("sell"))
			if game.at_bottleneck():
				main.run(func() -> String: return game.buy("pozhang_pill"))
			main.run(func() -> String: return game.travel("sect"))
			while not game.pending_event.is_empty():
				main.choose(str(game.pending_definition().choices.back().id))
	main.run(func() -> String: return main.session.act("rest"))
	main.run(func() -> String: return main.session.travel("wild"))
	while int(main.session.herb_count()) * 4 + int(main.session.player.stones) < 120:
		main.run(func() -> String: return main.session.act("gather"))
	main.run(func() -> String: return main.session.travel("market"))
	while not main.session.pending_event.is_empty():
		main.choose(str(main.session.pending_definition().choices.back().id))
	main.run(func() -> String: return main.session.act("sell"))
	main.run(func() -> String: return main.session.buy("foundation_pill"))
	main.run(func() -> String: return main.session.travel("sect"))
	# The breakthrough's rolls are fixed: no 心魔, and well under the odds.
	main.session.fortune = {"demon": 0.99, "breakthrough": 0.0}
	main.run(func() -> String: return main.session.act("breakthrough"))
	main.run(func() -> String: return main.session.travel("wild"))
	main.run(func() -> String: return main.session.start_battle("serpent"))
	_step("serpent duel started")
	await _capture("art_boss_idle")
	check(main.battle_stage.enemy.sprite.region_rect.position.y == 472, "serpent uses its own calibrated atlas region")
	main.session.battle.orbs = ["fire", "fire", "metal"]
	_watch_stage("art_boss")
	await main.skill("fire")
	main._save_manual()
	await main.battle_action("guard")
	main._load_manual()
	check(not main.presenting and main.session.battle.enemy_id == "serpent", "load restores idle stage and active boss")
	# Tiered staging (data/vfx_tiers.json): a 天阶 sect art gathers, opens a rune circle, shows its
	# lineage, darkens and tints the stage, pushes the camera in, slows and leaves a mark; 凡品 does none.
	_step("tiered staging")
	var stage = main.battle_stage
	var layer_kinds := {}
	stage.world.child_entered_tree.connect(func(node: Node) -> void:
		# Supporting layers carry their settings; an art's own effect has none.
		if node.get("extra") is Dictionary and not node.extra.is_empty():
			layer_kinds[str(node.kind)] = true)
	var staged := {}
	stage.cue.connect(func(kind: String) -> void:
		if kind == "release":
			staged.closeup = stage.closeup
			staged.tint = stage.tint_alpha
			staged.backdrop = stage.backdrop_alpha
		elif kind == "impact" and not staged.has("zoom"):
			staged.zoom = stage.zoom)
	var sounds: Array[String] = []
	stage.sound.connect(func(kind: String) -> void: sounds.append(kind))
	var textured := {"particles": 0, "sprites": 0}
	stage.world.child_entered_tree.connect(func(node: Node) -> void:
		if node is CPUParticles2D:
			textured.particles += 1
		elif node is Sprite2D and node.material is CanvasItemMaterial:
			textured.sprites += 1)
	var trauma_seen := {"most": 0.0, "frame": false}
	stage.cue.connect(func(kind: String) -> void:
		if kind == "impact":
			trauma_seen.most = maxf(float(trauma_seen.most), stage.trauma)
			trauma_seen.frame = trauma_seen.frame or stage.impact_until > Time.get_ticks_msec())
	_watch_stage("art_tier5")
	var strike := {"type": "attack", "actor": "player", "style": "sword_rain", "name": "焚天剑雨", "vfx": "sword_rain", "tier": 5, "element": "fire", "legacy": "qingyun", "hits": 1, "amount": 1, "hp_after": int(main.session.battle.hp)}
	var strikes: Array[Dictionary] = [strike]
	await stage.play(strikes)
	check(["gather", "array", "legacy", "residue", "bloom"].all(func(kind: String) -> bool: return layer_kinds.has(kind)), "a 天阶 sect art gathers, opens a rune circle, shows its lineage, leaves a mark and glows")
	check(staged.get("closeup", "") == "焚天剑雨" and float(staged.get("tint", 0.0)) > 0.1 and float(staged.get("backdrop", 0.0)) > 0.4, "the stage darkens and takes the art's color, its name in close-up")
	check(float(staged.get("zoom", 0.0)) > 0.0 and cue_sequence.find("surge") >= 0 and cue_sequence.find("surge") < cue_sequence.find("release"), "the camera pushes in and the highest tier adds its sound layer")
	await create_timer(0.4).timeout
	check(stage.closeup.is_empty() and stage.zoom < 0.01 and stage.tint_alpha < 0.01 and stage.backdrop_alpha < 0.01, "the staging clears after the strike")
	check(sounds.has("prepare_sword") and sounds.has("release_sword") and sounds.has("impact_sword") and sounds.has("impact_heavy"), "a sword art sounds of steel, and a heavy blow lands with weight: %s" % [sounds])
	check(int(textured.particles) >= 3 and int(textured.sprites) >= 3, "textured sparks, flashes and trails over the drawn effect: %s" % [textured])
	check(float(trauma_seen.most) > 0.3 and bool(trauma_seen.frame), "a heavy blow shakes the screen and shows an impact frame")
	check(is_equal_approx(Engine.time_scale, 1.0), "the hit-stop ends and the duel runs at its own speed again")
	check(stage.enemy_chip >= float(stage.enemy_hp), "the health bar keeps a pale chip of what was lost")
	layer_kinds.clear()
	cue_sequence.clear()
	var plain := strike.duplicate()
	plain.tier = 1
	plain.erase("legacy")
	strikes = [plain]
	await stage.play(strikes)
	check(layer_kinds.is_empty() and not "surge" in cue_sequence and stage.tint_alpha == 0.0, "a 凡品 art is drawn without the high tiers' layers")
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
