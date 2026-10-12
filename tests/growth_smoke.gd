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
	_retreat()
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
	check(once.player.xp == pieces.player.xp and once.player.xp == 500 and once.world.day == pieces.world.day and once.world.day == 139, "faster roots keep one long retreat equal to many short ones, both stopping at the first bottleneck")
	check(once.player.cultivation_carry == pieces.player.cultivation_carry and once.player.fatigue == pieces.player.fatigue, "and leave the same remainder and fatigue")

func _stages() -> void:
	var game := _game()
	check(game.realm_name() == "炼气初期" and game.player.max_hp == 90, "a journey starts at 炼气初期")
	game.player.xp = 499
	game.player.hp = 50
	Session.Events.apply(game, [{"xp": 1}])
	check(game.player.stage == 0 and game.player.xp == 500 and game.at_bottleneck() and game.realm_name() == "炼气初期", "500 xp waits at the bottleneck before 炼气中期")
	Session.Events.apply(game, [{"xp": 50}])
	check(game.player.xp == 500, "xp does not pile up behind a bottleneck")
	check(game.journal_lines().back().contains("其中 50 点未能化入"), "and the chronicle says what was held back")
	check(game.cultivate(30).contains("瓶颈") and game.world.day == 0, "a retreat at a bottleneck is refused without passing time")
	game.set_item_count("pozhang_pill", 1)
	game.use_item("pozhang_pill")
	check(game.player.stage == 1 and game.realm_name() == "炼气中期" and not game.at_bottleneck(), "a 破障丹 breaks the bottleneck")
	check(game.player.max_hp == 100 and game.player.hp == 60 and game.player.max_qi == 34, "the new stage raises caps and grants the headroom")
	check(game.journal_lines().back().contains("你已至炼气中期"), "the stage is recorded")
	for i: int in range(4):
		game.gain_insight("battle_win")
	Session.Events.apply(game, [{"xp": 600}])
	check(game.player.stage == 1 and game.player.xp == 1000 and game.player.insight == 80, "eighty insight is not yet enough")
	game.gain_insight("battle_win")
	check(game.player.stage == 2 and game.player.insight == 0, "the next duel's insight breaks through at once and is spent")
	for i: int in range(5):
		game.gain_insight("commission")
	check(game.player.insight == game.insight_needed(), "insight is capped at what a bottleneck needs")
	Session.Events.apply(game, [{"xp": 700}])
	check(game.player.stage == 3 and game.player.xp == 1700, "insight gathered beforehand carries xp straight through the bottleneck")
	check(game.journal_lines().filter(func(line: String) -> bool: return line.contains("修为精进")).size() == 3, "each stage entered is recorded")
	game.set_item_count("foundation_pill", 1)
	check(game.act("breakthrough").contains("2000 修为"), "breakthrough needs the full requirement")
	Session.Events.apply(game, [{"xp": 300}])
	game.act("breakthrough")
	check(game.player.realm == 1 and game.player.stage == 0 and game.realm_name() == "筑基初期" and game.lifespan() == 220, "breakthrough from 炼气圆满 into 筑基初期")
	var stronger := _game()
	stronger.player.xp = 1500
	stronger.player.stage = 3
	stronger.refresh_realm_stats()
	stronger.start_battle("disciple")
	stronger.use_skill("sword")
	var hit: int = stronger.combat_events[0].amount
	var boost: float = stronger.element_multiplier(stronger.content.technique("sword"))
	check(is_equal_approx(boost, 1.1) and hit >= int(round((11 + 6) * boost)) and hit <= int(round((15 + 6) * boost)), "a higher stage hits harder, and a matching root a little more (%d)" % hit)

## Retreat fatigue: a fresh mind for the first half year in a row, then less each day down to half;
## two days of anything else ease one day of it. 炼气圆满 keeps the bottlenecks out of the way.
func _retreat() -> void:
	var game := _game()
	game.player.stage = 3
	game.player.xp = 1500
	game.refresh_realm_stats()
	game.cultivate(180)
	check(game.player.xp == 1860 and game.retreat_efficiency() == 100, "the first half year in a row yields fully")
	game.cultivate(180)
	var tired_gain: int = int(game.player.xp) - 1860
	check(tired_gain < 360 and tired_gain > 270 and game.retreat_efficiency() == 75, "the next half year yields less (%d) and leaves the mind at 75%%" % tired_gain)
	game.wait(90)
	check(game.retreat_fatigue() == 180 and game.retreat_efficiency() == 100, "ninety days of other things ease half a year of fatigue")
	game.cultivate(360)
	game.cultivate(360)
	check(game.retreat_efficiency() == 50 and game.player.fatigue == 540, "a long unbroken retreat bottoms out at half")
	game.wait(270)
	check(game.retreat_fatigue() == 0, "and the mind recovers fully")
	var fresh := _game()
	var preview: Dictionary = fresh.retreat_preview(360)
	var message := fresh.cultivate(360)
	check(fresh.player.xp == 500 and fresh.world.day < 360 and message.contains("触及瓶颈"), "a retreat ends on the day it reaches a bottleneck (day %d)" % fresh.world.day)
	check(int(preview.days) == fresh.world.day and int(preview.xp) == 500, "the retreat buttons' preview foresees it")

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
	game.gain_insight("event")
	game.cultivate(30)
	game.player.fatigue = 200
	var copy := Session.new()
	check(copy.restore(JSON.parse_string(JSON.stringify(game.snapshot()))) and copy.player.stage == 0 and copy.at_bottleneck() and copy.player.roots == ["water", "earth"], "a bottleneck and the roots survive a save")
	check(copy.player.insight == 15 and copy.retreat_fatigue() == 200 and copy.player.fatigue_day == game.player.fatigue_day, "insight and retreat fatigue survive a save")
	for field: Array in [["stage", 4], ["xp", 501], ["insight", 101], ["fatigue_day", 999999], ["fatigue", 100000], ["cultivation_carry", 3000]]:
		var broken: Dictionary = game.snapshot()
		broken.player[field[0]] = field[1]
		check(not copy.restore(broken), "%s %d rejected" % field)
	var stageless: Dictionary = game.snapshot()
	stageless.player.erase("stage")
	check(copy.restore(stageless) and copy.player.stage == 1, "a save without a stage takes it from xp")
	var v10 := Session.new()
	check(v10.restore(JSON.parse_string(FileAccess.get_file_as_string("res://tests/fixtures/v10_heavenly_midstage.json"))), "v10 save migrates")
	check(v10.player.stage == 1 and v10.player.xp == 903 and v10.player.cultivation_carry == 1800 and v10.player.insight == 0 and v10.retreat_fatigue() == 0, "v10 keeps its stage and its finer remainder, with a fresh mind and no insight")
	v10.cultivate(1)
	check(v10.player.xp == 907 and v10.player.cultivation_carry == 600, "the migrated remainder carries into the next retreat day")
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
	check(int(game.player.xp) == 500 and game.player.stage == 0 and game.at_bottleneck(), "a hundred-year lingzhi fills cultivation only up to the bottleneck")
	check(game.journal_lines().any(func(line: String) -> bool: return line.contains("其中 200 点未能化入")), "the rest of the lingzhi is recorded as held back")
	game.set_item_count("lingzhi", 1)
	check(game.use_block("lingzhi").contains("瓶颈") and game.item_count("lingzhi") == 1, "pills that give xp wait until the bottleneck is broken")
	game.player.stones = 40
	game.buy("pozhang_pill")
	check(game.item_count("pozhang_pill") == 1 and int(game.player.stones) == 0, "the market sells 破障丹 for forty stones")
	game.use_item("pozhang_pill")
	check(game.player.stage == 1 and game.item_count("pozhang_pill") == 0, "and it breaks the bottleneck")
	game.set_item_count("pozhang_pill", 1)
	check(game.use_block("pozhang_pill").contains("未至瓶颈"), "a 破障丹 is not wasted without a bottleneck")
	game.player.items.clear()
	game.set_item_count("chiyan_flower", 1)
	game.set_item_count("ninglu_grass", 1)
	game.set_item_count("huichun_grass", 1)
	game.remove_herbs(2)
	check(game.item_count("chiyan_flower") == 1 and game.herb_count() == 1, "generic herb costs take the cheapest herbs first")
	check(Session.Chronicle.loot_text("huichun_grass:2,chiyan_flower:1", game.content) == "回春草×2、赤炎花", "loot reads naturally")
	var slip := "j:t:affinity:water:1::20"
	var bell := "e:bell:1:metal::6"
	check(not game.content.item(slip).is_empty() and not game.content.item(bell).is_empty(), "generated loot ids resolve")
	check(Session.Chronicle.loot_text(game.loot_code({slip: 2, bell: 1}), game.content) == "%s×2、%s" % [game.content.item(slip).name, game.content.item(bell).name], "generated loot keeps its name and count")
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
	check(_broken(func(c) -> void: c.rules.retreat.floor_percent = 0).contains("效率下限"), "retreat efficiency cannot fall to nothing")
	check(_broken(func(c) -> void: c.rules.bottleneck.insight.erase("spar")).contains("spar"), "every insight source needs a value")
	check(_broken(func(c) -> void: c.items.pozhang_pill.use = [{"breach": 1}]).contains("效果无效"), "the breach effect is a plain switch")
	check(_broken(func(c) -> void: c.locations.wild.gather.table.append({"item": "moonstone", "weight": 5})).contains("采集表条目"), "unknown herb in a gather table reported")
	check(_broken(func(c) -> void: c.locations.market.shop.append({"item": "moonstone", "price": 5})).contains("商店货品"), "unknown shop goods reported")
	check(_broken(func(c) -> void: c.locations.town.spots[0].actions.append("sell")).contains("收购品类"), "a place that buys must say what it buys")
	check(_broken(func(c) -> void: c.items.huiqi_pill.use = [{"mana": 5}]).contains("效果无效"), "unknown item effects reported")
