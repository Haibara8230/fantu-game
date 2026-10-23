extends SceneTree
const Session = preload("res://scripts/core/session.gd")
const SaveStore = preload("res://scripts/core/save_store.gd")
var checks := 0
var failures := 0
var main

func check(ok: bool, message: String) -> void:
	checks += 1
	if not ok:
		failures += 1
		printerr("FAIL: " + message)

func _initialize() -> void:
	create_timer(40).timeout.connect(func() -> void: printerr("Battle layout test timeout"); quit(1))
	call_deferred("_run")

func _game():
	var s := Session.new()
	s.encounters_enabled = false
	s.new_game("配气测试", 42, ["metal", "fire", "wood"])
	return s

func _rules() -> void:
	var s = _game()
	check(not s.has_method("defend") and not s.Combat.has_method("defend"), "independent guard rule and public wrapper are removed")
	s.set_item_count("huiqi_pill", 2)
	s.player.qi = 0
	s.use_item("huiqi_pill")
	check(s.item_count("huiqi_pill") == 1 and s.player.qi == 20 and s.player.prepared_pill == "huiqi_pill", "pre-battle dose consumes item and restores qi, retaining next-battle opening benefit")
	var saved: Dictionary = JSON.parse_string(JSON.stringify(s.snapshot()))
	var loaded := Session.new()
	check(loaded.restore(saved) and loaded.player.prepared_pill == "huiqi_pill", "pending preparation survives save")
	check(not s.use_block("huiqi_pill").is_empty() and s.item_count("huiqi_pill") == 1, "pending qi preparation cannot be stacked")
	s.begin_battle("wolf", "event")
	check(not s.player.has("prepared_pill") and s.battle.orbs.size() == 7 and s.battle.prepared_pill == "huiqi_pill", "all battle entries consume pending dose once into opening draw")
	var state: Dictionary = s.snapshot()
	check(s.take_duel_pill("huiqi_pill").contains("战前") and s.snapshot() == state, "battle pill entry is blocked without spending resources")
	s.use_item("huiqi_pill")
	check(s.snapshot() == state, "general inventory entry also blocks pills during battle")
	loaded = Session.new()
	check(loaded.restore(JSON.parse_string(JSON.stringify(state))) and loaded.snapshot() == state, "battle restore neither repeats opening draw nor consumes another pill")
	s.battle.clear()
	s.begin_battle("wolf")
	check(s.battle.orbs.size() == 5, "next encounter receives no repeated preparation")
	s.set_item_count("lei_fu", 1)
	var hp: int = s.battle.hp
	s.take_duel_pill("lei_fu")
	check(s.item_count("lei_fu") == 0 and s.battle.hp < hp, "talisman use is preserved")
	var pool: Array = ["metal", "metal", "fire", "fire", "wood"]
	check(s.Combat.payment_valid(pool, {"same": 2, "any": 1}, ["fire", "fire", "wood"]), "same plus any accepts an explicit alternate choice")
	check(not s.Combat.payment_valid(pool, {"same": 2}, ["fire", "wood"]), "mixed elements cannot pay a same-element cost")
	check(not s.Combat.payment_valid(pool, {"fire": 2}, ["fire", "wood"]), "named elements cannot be substituted")
	check(not s.Combat.payment_valid(pool, {"any": 2}, ["water", "water"]), "unheld qi cannot be paid")
	s.player.arts = ["qi_strike", "fire", "wood"]
	s.battle.orbs = pool.duplicate()
	state = s.snapshot()
	var plan: Array = s.Combat.payment_plan(s, "qi_strike")
	check(s.snapshot() == state and not plan.is_empty(), "automatic planning does not mutate hand, memory or RNG")
	s.use_skill("qi_strike", ["water", "water"])
	check(s.snapshot() == state, "illegal confirmation is atomic")
	s.use_skill("qi_strike", plan)
	check(s.battle.orbs.size() == pool.size() - plan.size() and s.combat_events[0].type == "spend", "confirmation spends exactly once and emits consumption before action")
	check(s.battle.payment_memory.qi_strike == plan, "confirmed choice is remembered for the spell")
	s.battle.orbs = pool.duplicate()
	check(s.Combat.payment_plan(s, "qi_strike") == plan, "a valid previous payment is reused")
	s.battle.guarded_turns = 2
	loaded = Session.new()
	check(loaded.restore(JSON.parse_string(JSON.stringify(s.snapshot()))), "legacy guarded-turn metadata remains loadable")
	saved = JSON.parse_string(JSON.stringify(s.snapshot()))
	state = loaded.snapshot()
	saved.player.prepared_pill = "wolf"
	check(not loaded.restore(saved) and loaded.snapshot() == state, "malformed pending pill is rejected atomically")
	saved = JSON.parse_string(JSON.stringify(s.snapshot()))
	saved.battle.payment_memory = {"qi_strike": ["void"]}
	check(not loaded.restore(saved) and loaded.snapshot() == state, "malformed payment memory is rejected atomically")

func _run() -> void:
	_rules()
	var scene: PackedScene = load("res://scenes/main.tscn")
	main = scene.instantiate()
	var path := "res://.tmp/battle_layout_test_%d" % Time.get_ticks_usec()
	main.manual_store = SaveStore.new(path + "/manual")
	main.auto_store = SaveStore.new(path + "/auto")
	main.settings_path = path + "/settings.cfg"
	main.guide_path = path + "/guide.cfg"
	root.add_child(main)
	main.close_welcome()
	main.started = true
	main.autosave_enabled = false
	main.guide_enabled = false
	main.session.encounters_enabled = false
	main.session.new_game("青禾", 42, ["metal", "fire", "wood"])
	main.story = {}
	main.session.begin_battle("wolf")
	main.session.player.arts = ["qi_strike", "fire", "wood"]
	main.session.battle.orbs = ["fire", "fire", "wood", "wood", "metal", "metal"]
	main.render()
	await process_frame
	main.battle_stage.motion_enabled = false
	var state: Dictionary = main.session.snapshot()
	await main.skill("fire")
	check(main.battle_selection == "fire" and main.battle_payment == ["fire", "fire"] and main.session.snapshot() == state, "selecting an art reserves its qi without a rules change")
	check(main.battle_dock.cancel.visible and not main.battle_dock.confirm.disabled, "payment displays cancellation and valid confirmation")
	await main.cancel_battle_selection()
	check(main.battle_selection.is_empty() and main.battle_dock.reserved.is_empty() and main.session.snapshot() == state, "cancelling returns all reservations without affecting rules")
	await main.skill("qi_strike")
	await main.battle_unreserve(str(main.battle_payment[0]))
	check(main.battle_dock.confirm.disabled and main.session.snapshot() == state, "incomplete manual payment disables confirmation")
	await main.battle_unreserve(str(main.battle_payment[0]))
	var element := "wood"
	await main.battle_orb(element)
	await main.battle_orb(element)
	check(main.battle_payment.has(element) and not main.battle_dock.confirm.disabled, "pool click inserts a held element into manual payment")
	await main.confirm_battle_selection()
	check(main.session.battle.orbs.size() == 4 and main.battle_selection.is_empty(), "confirmed UI cast commits exactly one payment")
	main.battle_stage.motion_enabled = false
	main.session.battle.orbs = ["fire", "fire", "wood", "wood", "metal", "metal"]
	main.render()
	main.battle_stage.motion_enabled = false
	await main.battle_action("end_turn")
	check(main.battle_discarding and main.session.battle.turn == 1 and main.battle_dock.confirm.disabled, "over-cap turn end enters explicit discard phase")
	await main.battle_orb("metal", true)
	check(main.session.battle.orbs.size() == 4 and not main.battle_dock.confirm.disabled, "right click discards only the required quantity")
	var count: int = main.session.battle.orbs.size()
	await main.battle_orb("wood", true)
	check(main.session.battle.orbs.size() == count, "discard cannot exceed the turn limit")
	await main.confirm_battle_selection()
	check(main.session.battle.turn == 2 and not main.battle_discarding, "discard confirmation advances the opponent then next normal draw")
	check(main.battle_dock.held == main.session.battle.orbs, "visual hand ends in exact agreement with authoritative draw events")
	for resolution: Vector2i in [Vector2i(1280,720), Vector2i(1920,1080), Vector2i(2560,1440)]:
		root.size = resolution
		main.render()
		await process_frame
		await process_frame
		var dock = main.battle_dock
		check(dock.art_buttons.size() == 10 and dock.pool_buttons.size() == 5, "ten stable art slots and all five elements at %s" % resolution)
		var normalized_x: float = dock.art_buttons[0].get_global_rect().position.x / root.get_visible_rect().size.x
		check(normalized_x > 0.20 and normalized_x < 0.22, "left panel stays registered to approved sample at %s" % resolution)
		for button: Button in dock.art_buttons + [dock.confirm, dock.cancel]:
			check(root.get_visible_rect().encloses(button.get_global_rect()), "battle control remains inside viewport: %s at %s" % [button.name, resolution])
		var stage_rect: Rect2 = main.battle_stage.get_global_rect()
		main.toggle_battle_record()
		await process_frame
		check(main.battle_stage.get_global_rect().is_equal_approx(stage_rect), "record drawer never resizes battle at %s" % resolution)
		main.toggle_battle_record()
	check(not main.Settings.ACTIONS.has("guard") and main.Settings.DEFAULT_KEYS.skill_6 == KEY_Q and main.Settings.DEFAULT_KEYS.skill_10 == KEY_T, "new keyboard grid has no retired guard binding")
	DirAccess.make_dir_recursive_absolute(ProjectSettings.globalize_path(path))
	var config := ConfigFile.new()
	config.set_value("controls", "keys", {"skill_1": KEY_Q, "guard": KEY_SPACE})
	config.save(main.settings_path)
	main.Settings.load_state(main)
	check(main.keys.skill_1 == KEY_Q and main.keys.skill_6 != KEY_Q and not main.keys.has("guard"), "new actions preserve valid older rebindings while ignoring retired guard")
	# A faster generated foe can draw, spend, then draw again before the player's opening.
	# Observe the retiring stage, before render replaces it, to verify replay rather than final snapshot.
	main.session.battle.foe_orbs = ["fire", "fire", "fire", "fire", "fire", "fire"]
	main.session.combat_events.clear()
	main.session.combat_events.append({"type": "draw", "actor": "enemy", "orbs": ["fire", "fire", "fire", "fire", "fire"]})
	main.session.combat_events.append({"type": "spend", "actor": "enemy", "orbs": ["fire", "fire", "fire", "fire"]})
	main.session.combat_events.append({"type": "draw", "actor": "enemy", "orbs": ["fire", "fire", "fire", "fire", "fire"]})
	main.render()
	main.battle_stage.motion_enabled = false
	var retiring = main.battle_stage
	var observed := {"qi": -1}
	retiring.tree_exiting.connect(func() -> void: observed.qi = retiring.enemy_qi)
	await main._play_opening()
	check(observed.qi == 6, "faster-foe opening reconstructs all draws and payments without negative or lost visual qi")
	main.session.battle.orbs = ["fire", "fire", "wood"]
	main.render()
	main.battle_stage.motion_enabled = true
	var dock = main.battle_dock
	state = main.session.snapshot()
	await dock.set_payment("qi_strike", ["fire", "fire"])
	check(dock.held.size() == 3 and dock.pool_reserved.size() == 2 and main.session.snapshot() == state, "animated reservation updates available pool while keeping authoritative total")
	await dock.play_event({"type": "spend", "actor": "player", "orbs": ["fire", "fire"]})
	check(dock.held == ["wood"] and dock.reserved.is_empty() and dock.pool_reserved.is_empty() and dock.flights.is_empty(), "animated spending shrinks payment icons and clears tails without double subtraction")
	check(main.session.snapshot() == state and not dock.busy, "animated replay only changes presentation and releases the input lock")
	main.queue_free()
	await process_frame
	print("BATTLE LAYOUT: %d checks, %d failures" % [checks, failures])
	quit(1 if failures else 0)
