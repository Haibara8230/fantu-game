extends SceneTree
const Session = preload("res://scripts/core/session.gd")
const SaveStore = preload("res://scripts/core/save_store.gd")
var checks := 0
var failures := 0

func check(condition: bool, message: String) -> void:
	checks += 1
	if not condition:
		failures += 1
		printerr("FAIL: " + message)

func _initialize() -> void:
	var game = Session.new()
	# Road encounters have their own suite; this one follows fixed paths.
	game.encounters_enabled = false
	check(game.content.error_message.is_empty(), "content loads")
	# A plain three-element root cultivates at the base rate, keeping the numbers below predictable.
	game.new_game("测试修士", 42, ["metal", "wood", "fire"])
	check(game.player.hp == 90 and game.player.location == "sect", "starting state")
	var unchanged: Dictionary = game.snapshot()
	game.act("gather")
	check(game.snapshot() == unchanged, "invalid action does not consume time or resources")
	game.act("breakthrough")
	check(game.player.realm == 0, "breakthrough requirements enforced")
	for i: int in range(6):
		game.act("cultivate")
	check(game.player.xp == 360 and game.world.day == 180 and game.cultivation_rate() == 60, "cultivation progression at the base rate")
	game.travel("wild")
	game.start_battle("serpent")
	check(game.battle.is_empty(), "boss gated by realm")
	while game.player.herbs < 23:
		game.act("gather")
	game.travel("market")
	if not game.pending_event.is_empty():
		game.choose_event("decline")
	game.act("sell")
	game.act("buy_pill")
	check(game.player.pills == 1, "gather-trade-pill economy")
	game.travel("sect")
	game.act("breakthrough")
	check(game.player.realm == 0, "breakthrough needs the last sub-stage")
	while game.player.xp < 2000:
		game.cultivate(360)
	check(game.player.stage == 3 and game.player.max_hp == 120 and game.realm_name() == "炼气圆满", "sub-stages reached by cultivation raise the caps")
	check(game.journal_lines().any(func(line: String) -> bool: return line.contains("你已至炼气中期")), "each sub-stage is a recorded milestone")
	var before_breakthrough: int = game.player.xp
	game.act("breakthrough")
	check(game.player.realm == 1 and game.player.stage == 0 and game.player.hp == 140 and game.player.pills == 0 and game.player.xp == before_breakthrough - 2000, "breakthrough consumes resources and upgrades stats")
	game.travel("wild")
	game.start_battle("serpent")
	game.use_skill("fire")
	check(game.battle.cooldowns.fire == 2 and game.player.qi == 40, "skill costs and cooldown")
	unchanged = game.snapshot()
	game.use_skill("fire")
	check(game.snapshot() == unchanged, "blocked skill has no side effects")
	var copy = Session.new()
	check(copy.restore(JSON.parse_string(JSON.stringify(game.snapshot()))), "active battle JSON round trip")
	game.use_skill("sword")
	copy.use_skill("sword")
	check(game.snapshot() == copy.snapshot(), "RNG continues identically after loading")
	game.defend()
	check(game.battle.cooldowns.fire == 0, "cooldown expires after two other turns")
	var rounds := 0
	while not game.battle.is_empty() and rounds < 40:
		rounds += 1
		if game.player.hp < 65 and int(game.battle.cooldowns.get("wood", 0)) == 0 and game.player.qi >= 8:
			game.use_skill("wood")
		elif int(game.battle.cooldowns.get("fire", 0)) == 0 and game.player.qi >= 10:
			game.use_skill("fire")
		else:
			game.use_skill("sword")
	check(game.has_flag("serpent_slain"), "full legal progression slays the serpent")
	var after_serpent: int = game.world.day
	var way_home: int = game.content.path_days(game.path_to("sect"))
	game.travel("sect")
	game.act("cultivate")
	check(game.world.day == after_serpent + way_home + 30 and game.player.location == "sect", "world continues after the serpent falls")
	game.travel("wild")
	var settled: Dictionary = game.snapshot()
	game.start_battle("serpent")
	check(game.snapshot() == settled, "slain serpent cannot be fought again")
	var defeated = Session.new()
	defeated.new_game("落败测试", 3)
	defeated.player.hp = 1
	defeated.start_battle("disciple")
	defeated.defend()
	check(defeated.battle.is_empty() and defeated.player.location == "sect" and defeated.player.hp > 0, "defeat recovers into playable state")
	check(defeated.player.stones == 20, "defeat penalty bounded")
	var escaping = Session.new()
	escaping.new_game("撤离测试", 6)
	escaping.start_battle("disciple")
	escaping.flee()
	check(escaping.battle.is_empty() and escaping.world.day == escaping.content.action_days("flee"), "retreat consumes configured days")
	var corrupt: Dictionary = game.snapshot()
	corrupt.player.hp = -1
	unchanged = copy.snapshot()
	check(not copy.restore(corrupt) and copy.snapshot() == unchanged, "bad save rejected without altering current game")
	corrupt = game.snapshot()
	corrupt.version = 99
	check(not copy.restore(corrupt), "future save version rejected")
	var path := "res://.godot/test_saves_%d" % Time.get_ticks_usec()
	var store = SaveStore.new(path)
	check(store.save_game(game), "first save writes")
	var old_day: int = game.world.day
	game.act("gather")
	check(store.save_game(game), "second save writes")
	var loaded = Session.new()
	check(store.load_game(loaded) and loaded.snapshot() == game.snapshot(), "latest save loads")
	var broken_file := FileAccess.open(path.path_join("journey_0.json"), FileAccess.WRITE)
	broken_file.store_string("{broken")
	broken_file.close()
	check(store.load_game(loaded) and loaded.world.day == old_day, "damaged newest save falls back to previous generation")
	print("CORE: %d checks, %d failures" % [checks, failures])
	quit(0 if failures == 0 else 1)
