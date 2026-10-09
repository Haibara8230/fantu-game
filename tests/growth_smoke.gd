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
	# A script error aborts this function before quit(); the watchdog turns that hang into a failure.
	create_timer(240.0).timeout.connect(func() -> void: printerr("TIMEOUT: test did not finish (likely a script error)"); quit(1))
	_roots()
	_stages()
	_pacing()
	_saves()
	_items()
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
	game.set_item_count("foundation_pill", 1)
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
	var boost: float = stronger.element_multiplier(stronger.content.technique("sword"))
	check(is_equal_approx(boost, 1.1) and hit >= int(round((11 + 6) * boost)) and hit <= int(round((15 + 6) * boost)), "a higher stage hits harder, and a matching root a little more (%d)" % hit)

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
	check(int(game.content.locations.market.shop[0].price) == 120 and int(game.content.items.huichun_grass.price) == 4, "prices follow the slower economy")

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

func _items() -> void:
	var game := _game()
	game.travel("wild")
	for i: int in range(30):
		game.act("gather")
	var valley: Array = game.player.items.keys()
	check(valley.all(func(item_id: String) -> bool: return item_id in ["huichun_grass", "chiyan_flower", "lingzhi"]) and "chiyan_flower" in valley, "the valley yields its own herbs")
	check(game.journal_lines().any(func(line: String) -> bool: return line.contains("在落霞谷采得")), "what was gathered is recorded")
	game.travel("ridge")
	game.player.items.clear()
	for i: int in range(20):
		game.act("gather")
	check(game.player.items.keys().all(func(item_id: String) -> bool: return item_id in ["huichun_grass", "ninglu_grass"]), "the ridge yields different herbs")
	check(game.sell("huichun_grass") == "这里不收这件东西。", "herbs are sold at the herb shop, not on the ridge")
	game.travel("market")
	game.player.items.clear()
	game.set_item_count("huichun_grass", 3)
	game.set_item_count("chiyan_flower", 2)
	game.set_item_count("auction_invitation", 1)
	var stones := int(game.player.stones)
	game.sell("chiyan_flower", 1)
	check(int(game.player.stones) == stones + 9 and game.item_count("chiyan_flower") == 1, "each herb sells at its own price")
	game.act("sell")
	check(int(game.player.stones) == stones + 9 + 9 + 12 and game.herb_count() == 0 and game.item_count("auction_invitation") == 1, "selling everything keeps what the shop does not buy")
	game.player.stones = 30
	check(game.buy("foundation_pill").contains("灵石不足"), "a pill costs 120 at the shop")
	game.buy("liaoshang_pill")
	check(game.item_count("liaoshang_pill") == 1 and int(game.player.stones) == 10, "the shop sells pills")
	game.player.hp = 30
	game.use_item("liaoshang_pill")
	check(int(game.player.hp) == 70 and game.item_count("liaoshang_pill") == 0, "a healing pill heals")
	game.set_item_count("ningqi_pill", 2)
	var xp := int(game.player.xp)
	game.use_item("ningqi_pill")
	check(int(game.player.xp) == xp + 100 and game.use_block("ningqi_pill").contains("丹毒未消"), "condensing pills need thirty days between them")
	game.wait(30)
	check(game.use_block("ningqi_pill").is_empty(), "and can be taken again afterwards")
	game.set_item_count("lingzhi", 1)
	game.player.xp = 400
	game.use_item("lingzhi")
	check(int(game.player.xp) == 700 and game.player.stage == 1, "a hundred-year lingzhi can carry the player into the next stage")
	game.player.items.clear()
	game.set_item_count("chiyan_flower", 1)
	game.set_item_count("ninglu_grass", 1)
	game.set_item_count("huichun_grass", 1)
	game.remove_herbs(2)
	check(game.item_count("chiyan_flower") == 1 and game.herb_count() == 1, "generic herb costs take the cheapest herbs first")
	check(Session.Chronicle.loot_text("huichun_grass:2,chiyan_flower:1", game.content) == "回春草×2、赤炎花", "loot reads naturally")
	var old := Session.new()
	check(old.restore(JSON.parse_string(FileAccess.get_file_as_string("res://tests/fixtures/v6_herbs_pills.json"))), "v6 save migrates")
	check(old.item_count("huichun_grass") >= 9 and old.item_count("foundation_pill") == 2 and old.item_count("auction_invitation") == 1 and not old.player.has("herbs"), "herbs and pills become items")

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
	check(_broken(func(c) -> void: c.locations.wild.gather.table.append({"item": "moonstone", "weight": 5})).contains("采集表条目"), "unknown herb in a gather table reported")
	check(_broken(func(c) -> void: c.locations.market.shop.append({"item": "moonstone", "price": 5})).contains("商店货品"), "unknown shop goods reported")
	check(_broken(func(c) -> void: c.locations.town.spots[0].actions.append("sell")).contains("收购品类"), "a place that buys must say what it buys")
	check(_broken(func(c) -> void: c.items.huiqi_pill.use = [{"mana": 5}]).contains("效果无效"), "unknown item effects reported")
