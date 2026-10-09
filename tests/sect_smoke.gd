extends SceneTree
const Session = preload("res://scripts/core/session.gd")
const Store = preload("res://scripts/core/save_store.gd")
const Effect = preload("res://scripts/presentation/effect.gd")
var main
var checks := 0
var failures := 0
var shots := 0
var captured: Dictionary = {}
var cue_types: Array[String] = []
var screenshot_prefix := ""
var stage_reference
var hit_sum := 0

func _initialize() -> void:
	create_timer(60).timeout.connect(func() -> void: printerr("Sect test timed out"); quit(1))
	call_deferred("_run")

func check(value: bool, message: String) -> void:
	checks += 1
	if not value:
		failures += 1
		printerr("FAIL: " + message)

func _capture(name: String, delay: float = 0.0) -> void:
	if DisplayServer.get_name() == "headless":
		return
	if delay > 0:
		await create_timer(delay).timeout
	await process_frame
	await RenderingServer.frame_post_draw
	check(root.get_texture().get_image().save_png("res://builds/previews/" + name + ".png") == OK, "screenshot writes")
	shots += 1

func _run() -> void:
	var visual = Effect.new()
	check(visual is Node2D, "VFX script compiled")
	visual.free()
	var legacy = Session.new()
	legacy.new_game("旧档", 42)
	legacy.start_battle("disciple")
	var old: Dictionary = legacy.snapshot()
	old.player.erase("sect")
	old.battle.erase("opponent_sect")
	var migrated = Session.new()
	check(migrated.restore(JSON.parse_string(JSON.stringify(old))), "old active-battle save migrates")
	check(migrated.player.sect == "wanderer" and migrated.battle.opponent_sect == "qingyun", "old loadout and opponent defaults preserved")
	var bad: Dictionary = legacy.snapshot()
	bad.player.sect = "missing"
	check(not migrated.restore(bad), "unknown saved sect rejected")
	legacy.flee()
	legacy.choose_sect("canglan")
	legacy.start_battle("disciple", "chixiao")
	var before: Dictionary = legacy.snapshot()
	legacy.choose_sect("qingyun")
	check(legacy.snapshot() == before, "sect cannot change during battle")
	legacy.use_skill("fire_burst")
	check(legacy.snapshot() == before, "unlearned skill rejected without consuming resources")
	legacy.use_skill("ice_lance")
	check(legacy.combat_events[0].style == "ice_lance" and legacy.combat_events[1].style == "flame_bolt", "player and enemy retain distinct elemental styles")
	before = legacy.snapshot()
	legacy.use_skill("ice_lance")
	check(legacy.snapshot() == before and legacy.combat_events.is_empty(), "cooldown prevents repeated casts")
	var loaded = Session.new()
	check(loaded.restore(JSON.parse_string(JSON.stringify(before))) and loaded.snapshot() == before, "sect and cooldown persist")
	var path := "res://.godot/sect_test_%d" % Time.get_ticks_usec()
	var store = Store.new(path)
	check(store.save_game(legacy) and store.load_game(loaded), "school battle save loads")
	root.size = Vector2i(1280, 800)
	main = load("res://scenes/main.tscn").instantiate()
	main.manual_store = Store.new(path + "/manual")
	main.auto_store = Store.new(path + "/auto")
	root.add_child(main)
	main.name_input.text = "青禾"
	main._begin()
	main.preview_mode = true
	DirAccess.make_dir_recursive_absolute(ProjectSettings.globalize_path("res://builds/previews"))
	for sect_id: String in ["qingyun", "chixiao", "changqing", "canglan", "xuanyue"]:
		for slot: int in range(3):
			main._reset_preview(sect_id, sect_id)
			main.session.rng.seed = 73
			var id: String = main.session.active_skills()[slot]
			print("CHECKING: " + sect_id + " / " + id)
			var definition: Dictionary = main.session.content.skills[id]
			await process_frame
			stage_reference = main.battle_stage
			captured.clear()
			cue_types.clear()
			hit_sum = 0
			var last_visual_hp: Array[int] = [45]
			stage_reference.hit_resolved.connect(func(enemy_target: bool, amount: int, hp_after: int) -> void:
				if enemy_target:
					hit_sum += amount
					last_visual_hp[0] = hp_after
			)
			screenshot_prefix = "sect_" + sect_id + "_" + id
			stage_reference.cue.connect(func(kind: String) -> void:
				cue_types.append(kind)
				if kind in ["release", "impact", "heal", "guard"] and not captured.has(kind):
					captured[kind] = true
					_capture(screenshot_prefix + "_" + kind, 0.12 if kind in ["release", "heal", "guard"] else 0.065)
			)
			var old_qi: int = main.session.player.qi
			await main._skill(id)
			check(main.session.player.qi == old_qi - int(definition.qi_cost), "qi cost " + id)
			check(int(main.session.battle.cooldowns.get(id, 0)) == int(definition.cooldown), "cooldown " + id)
			if definition.kind == "attack":
				check(cue_types.count("impact") == int(definition.get("hits", 1)) + 1, "impact count " + id)
				check(hit_sum == int(main.session.combat_events[0].amount), "displayed damage sum " + id)
				check(last_visual_hp[0] == int(main.session.battle.hp), "displayed final HP " + id)
			else:
				check(cue_types[0] == ("heal" if definition.kind == "heal" else "guard"), "support cue " + id)
			check(not main.presenting, "input unlocked " + id)
			check(main.session.player.sect == sect_id and main.session.battle.opponent_sect == sect_id, "factions retained " + id)
			var buttons: Array[Node] = main.center.find_children("*", "Button", true, false)
			for button: Button in buttons:
				check(button.get_global_rect().end.y <= main.get_global_rect().end.y, "preview button visible " + id)
			await process_frame
	main._reset_preview("qingyun", "xuanyue")
	await _capture("sect_selector")
	# Restore to a smaller window and ensure selectors/skill controls remain usable.
	root.size = Vector2i(1000, 640)
	await _capture("sect_selector_small")
	await process_frame
	for button: Button in main.center.find_children("*", "Button", true, false):
		check(button.get_global_rect().end.y <= main.get_global_rect().end.y, "small preview control visible")
	print("SECTS: %d checks, %d failures, %d captures" % [checks, failures, shots])
	main.queue_free()
	await process_frame
	quit(0 if failures == 0 else 1)
