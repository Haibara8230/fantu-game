extends SceneTree
## M3 growth: spirit roots, sub-stages, breakthrough gating, injury-based rest and day-based pacing.
const Session = preload("res://scripts/core/session.gd")
const Content = preload("res://scripts/core/content.gd")
var checks := 0
var failures := 0

func check(condition: bool, message: String) -> void:
	checks += 1
	if not condition:
		failures += 1
		printerr("FAIL: " + message)

func _initialize() -> void:
	_roots()
	_stages()
	_pacing()
	_saves()
	_static_checks()
	print("GROWTH: %d checks, %d failures" % [checks, failures])
	quit(0 if failures == 0 else 1)

func _game(roots: Array = ["metal", "wood", "fire"]) -> Session:
	var game := Session.new()
	game.encounters_enabled = false
	game.new_game("修行者", 7, roots)
	return game

func _roots() -> void:
	var game := _game()
	var rng := RandomNumberGenerator.new()
	rng.seed = 2026
	var counts := {}
	var valid := true
	for i: int in range(4000):
		var roots: Array = game.roll_roots(rng)
		counts[roots.size()] = int(counts.get(roots.size(), 0)) + 1
		var ordered: Array = game.content.rules.spirit_roots.elements.filter(func(element: String) -> bool: return element in roots)
		valid = valid and roots == ordered and roots.size() >= 1 and roots.size() <= 5
	check(valid, "rolled roots are distinct known elements in a fixed order")
	for grade: Dictionary in game.content.rules.spirit_roots.grades:
		var share := float(counts.get(int(grade.count), 0)) / 4000.0
		check(absf(share - float(grade.weight) / 100.0) < 0.03, "%s appears about %d%% of the time (%.1f%%)" % [grade.name, int(grade.weight), share * 100.0])
	var heavenly := _game(["fire"])
	var false_root := _game(["metal", "wood", "water", "fire", "earth"])
	check(heavenly.root_title() == "火天灵根" and heavenly.cultivation_rate() == 108, "a heavenly root cultivates 1.8 times as fast")
	check(false_root.root_title() == "金木水火土伪灵根" and false_root.cultivation_rate() == 30, "a false root cultivates at half speed")
	var a := Session.new()
	var b := Session.new()
	a.new_game("甲", 99)
	b.new_game("乙", 99)
	check(a.player.roots == b.player.roots and not a.player.roots.is_empty(), "roots sensed from the seed when none are chosen")
	var once := _game(["fire"])
	var pieces := _game(["fire"])
	once.cultivate(360)
	for i: int in range(12):
		pieces.cultivate(30)
	check(once.player.xp == pieces.player.xp and once.player.xp == 1296, "faster roots keep one long retreat equal to many short ones")

func _stages() -> void:
	var game := _game()
	check(game.realm_name() == "炼气初期" and game.player.max_hp == 90, "a journey starts at 炼气初期")
	game.player.xp = 499
	game.player.hp = 50
	Session.Events.apply(game, [{"xp": 1}])
	check(game.player.stage == 1 and game.realm_name() == "炼气中期", "500 xp reaches 炼气中期")
	check(game.player.max_hp == 100 and game.player.hp == 60 and game.player.max_qi == 34, "the new stage raises caps and grants the headroom")
	check(game.journal_lines().back().contains("你已至炼气中期"), "the stage is recorded")
	Session.Events.apply(game, [{"xp": 1200}])
	check(game.player.stage == 3 and game.journal_lines().filter(func(line: String) -> bool: return line.contains("修为精进")).size() == 3, "crossing several stages at once records each one")
	game.player.pills = 1
	check(game.act("breakthrough").contains("2000 修为"), "breakthrough needs the full requirement")
	Session.Events.apply(game, [{"xp": 300}])
	game.act("breakthrough")
	check(game.player.realm == 1 and game.player.stage == 0 and game.realm_name() == "筑基初期" and game.lifespan() == 220, "breakthrough from 炼气圆满 into 筑基初期")
	var stronger := _game()
	stronger.player.xp = 1500
	stronger.settle_stage()
	stronger.start_battle("disciple")
	stronger.use_skill("sword")
	var hit: int = stronger.combat_events[0].amount
	check(hit >= 11 + 6 and hit <= 15 + 6, "a higher stage hits harder (%d)" % hit)

func _pacing() -> void:
	var game := _game()
	check(game.rest_days() == 1, "resting unhurt takes a day")
	game.player.hp = 45
	check(game.rest_days() == 6, "resting from half health takes half of twelve days")
	var day := int(game.world.day)
	game.act("rest")
	check(int(game.world.day) == day + 6 and game.player.hp == game.player.max_hp, "rest heals fully in that time")
	game.travel("wild")
	day = int(game.world.day)
	game.act("gather")
	check(int(game.world.day) == day + 5, "gathering takes five days")
	check(game.content.rules.pill_price == 120 and game.content.rules.herb_price == 4, "prices follow the slower economy")

func _saves() -> void:
	var qi := Session.new()
	check(qi.restore(JSON.parse_string(FileAccess.get_file_as_string("res://tests/fixtures/v5_qi_market.json"))), "v5 save migrates")
	check(qi.player.roots == ["metal", "wood", "fire"] and qi.player.stage == 0 and qi.cultivation_rate() == 60, "old journeys keep an ordinary three-element root")
	var base := Session.new()
	check(base.restore(JSON.parse_string(FileAccess.get_file_as_string("res://tests/fixtures/v5_foundation_ridge.json"))) and base.realm_name() == "筑基初期" and base.player.max_hp == 140, "v5 foundation save keeps its realm")
	var game := _game(["water", "earth"])
	Session.Events.apply(game, [{"xp": 1000}])
	var copy := Session.new()
	check(copy.restore(JSON.parse_string(JSON.stringify(game.snapshot()))) and copy.player.stage == 2 and copy.player.roots == ["water", "earth"], "stage and roots survive a save")
	var bad: Dictionary = game.snapshot()
	bad.player.roots = ["fire", "fire"]
	check(not copy.restore(bad), "duplicate root elements rejected")
	bad = game.snapshot()
	bad.player.roots = ["lightning"]
	check(not copy.restore(bad), "unknown root element rejected")
	bad = game.snapshot()
	bad.player.hp = 115
	check(not copy.restore(bad), "health above the stage cap rejected")

func _broken(change: Callable) -> String:
	var content := Content.new()
	content.load_data()
	change.call(content)
	return content._validate()

func _static_checks() -> void:
	check(_broken(func(c) -> void: c.realms[0].stages[2].xp = 400).contains("递增"), "stage thresholds must increase")
	check(_broken(func(c) -> void: c.realms[0].stages[0].xp = 10).contains("必须是 0"), "the first stage starts at zero")
	check(_broken(func(c) -> void: c.realms[0].breakthrough.xp = 900).contains("不能低于"), "breakthrough cannot be easier than the last stage")
	check(_broken(func(c) -> void: c.rules.spirit_roots.grades[0].count = 9).contains("灵根等级"), "root grades must fit the elements")
