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
	_limits()
	_pacing()
	_saves()
	_items()
	_golden_core()
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
	once.retreat_limits = false
	pieces.retreat_limits = false
	once.cultivate(1080)
	for i: int in range(36):
		pieces.cultivate(30)
	check(once.player.xp == pieces.player.xp and once.player.xp == 2000 and once.world.day == pieces.world.day and once.world.day < 1080, "faster roots keep one long retreat equal to many short ones, both stopping at the first bottleneck")
	check(once.player.cultivation_carry == pieces.player.cultivation_carry and once.player.fatigue == pieces.player.fatigue, "and leave the same remainder and fatigue")

func _stages() -> void:
	var game := _game()
	check(game.realm_name() == "炼气初期" and game.player.max_hp == 90, "a journey starts at 炼气初期")
	game.player.xp = 1999
	game.player.hp = 50
	Session.Events.apply(game, [{"xp": 1}])
	check(game.player.stage == 0 and game.player.xp == 2000 and game.at_bottleneck() and game.realm_name() == "炼气初期", "2000 xp waits at the bottleneck before 炼气中期")
	Session.Events.apply(game, [{"xp": 50}])
	check(game.player.xp == 2000, "xp does not pile up behind a bottleneck")
	check(game.journal_lines().back().contains("其中 50 点未能化入"), "and the chronicle says what was held back")
	check(game.cultivate(30).contains("瓶颈") and game.world.day == 0, "a retreat at a bottleneck is refused without passing time")
	game.set_item_count("pozhang_pill", 1)
	game.use_item("pozhang_pill")
	check(game.player.stage == 1 and game.realm_name() == "炼气中期" and not game.at_bottleneck(), "a 破障丹 breaks the bottleneck")
	check(game.player.max_hp == 100 and game.player.hp == 60 and game.player.max_qi == 34, "the new stage raises caps and grants the headroom")
	check(game.journal_lines().back().contains("你已至炼气中期"), "the stage is recorded")
	for i: int in range(4):
		game.gain_insight("battle_win")
	Session.Events.apply(game, [{"xp": 2100}])
	check(game.player.stage == 1 and game.player.xp == 4000 and game.player.insight == 80, "eighty insight is not yet enough")
	game.gain_insight("battle_win")
	check(game.player.stage == 2 and game.player.insight == 0, "the next duel's insight breaks through at once and is spent")
	for i: int in range(5):
		game.gain_insight("commission")
	check(game.player.insight == game.insight_needed(), "insight is capped at what a bottleneck needs")
	Session.Events.apply(game, [{"xp": 2800}])
	check(game.player.stage == 3 and game.player.xp == 6800, "insight gathered beforehand carries xp straight through the bottleneck")
	check(game.journal_lines().filter(func(line: String) -> bool: return line.contains("修为精进")).size() == 3, "each stage entered is recorded")
	game.set_item_count("foundation_pill", 1)
	check(game.act("breakthrough").contains("8000 修为"), "breakthrough needs the full requirement")
	Session.Events.apply(game, [{"xp": 1200}])
	_steady(game)
	game.act("breakthrough")
	_weather(game)
	check(game.player.realm == 1 and game.player.stage == 0 and game.realm_name() == "筑基初期" and game.lifespan() == 220, "breakthrough from 炼气圆满 into 筑基初期")
	var stronger := _game()
	stronger.player.xp = 6000
	stronger.player.stage = 3
	stronger.refresh_realm_stats()
	stronger.start_battle("disciple")
	_sword(stronger)
	var hit: int = stronger.combat_events.filter(func(e: Dictionary) -> bool: return not e.type in ["spend", "draw", "discard"])[0].amount
	var boost: float = stronger.element_multiplier(stronger.content.technique("sword"))
	# The stage's attack bonus counts half for each of the two orbs a 剑诀 spends.
	var held: Dictionary = stronger.held_technique("sword")
	var bonus := int(stronger.attack_bonus())
	# Arts grow with the realm (combat.gd realm_power).
	var power: float = stronger.Combat.realm_power(stronger, int(stronger.player.realm))
	check(is_equal_approx(boost, 1.1) and bonus == 6 and hit >= int(round((int(held.damage_min) + bonus) * boost * power)) and hit <= int(round((int(held.damage_max) + bonus) * boost * power)), "a higher stage hits harder, and a matching root a little more (%d)" % hit)

## Retreat fatigue: a fresh mind for the first year in a row (炼气), then less each day down to half;
## two days of anything else ease one day of it. 炼气圆满 keeps the bottlenecks out of the way.
## Test setup only: the single-retreat limit is off and the realm's xp cap lifted, to run the curve.
func _retreat() -> void:
	var game := _game()
	game.retreat_limits = false
	game.content.realms[0].breakthrough = {"xp": 1000000, "pills": 1}
	game.player.stage = 3
	game.player.xp = 6000
	game.player.mind = 24
	game.refresh_realm_stats()
	game.cultivate(360)
	check(game.player.xp == 6720 and game.retreat_efficiency() == 100, "the first year in a row yields fully")
	game.cultivate(180)
	var tired_gain: int = int(game.player.xp) - 6720
	check(tired_gain < 360 and tired_gain > 270 and game.retreat_efficiency() == 75, "the next half year yields less (%d) and leaves the mind at 75%%" % tired_gain)
	game.wait(90)
	check(game.retreat_fatigue() == 360 and game.retreat_efficiency() == 100, "ninety days of other things ease half a year of fatigue")
	game.cultivate(360)
	game.cultivate(360)
	check(game.retreat_efficiency() == 50 and game.player.fatigue == 720, "a long unbroken retreat bottoms out at half")
	game.wait(360)
	check(game.retreat_fatigue() == 0, "and the mind recovers fully")
	var fresh := _game()
	fresh.retreat_limits = false
	var preview: Dictionary = fresh.retreat_preview(3600)
	var message := fresh.cultivate(3600)
	check(fresh.player.xp == 2000 and fresh.world.day < 3600 and message.contains("触及瓶颈"), "a retreat ends on the day it reaches a bottleneck (day %d)" % fresh.world.day)
	check(int(preview.days) == fresh.world.day and int(preview.xp) == 2000, "the retreat buttons' preview foresees it")

## The three limits on seclusion: one retreat lasts at most the stage's span; the mind (心境) must keep
## up with the stage or retreats yield half and last half as long; xp stops at what the realm holds.
func _limits() -> void:
	var game := _game()
	check(game.retreat_cap() == 180 and game.mind_percent() == 100, "炼气初期 allows half a year at a time")
	var message := game.cultivate(720)
	check(int(game.world.day) == 180 and int(game.player.xp) == 360 and message.contains("闭关 6 个月"), "a longer retreat ends at the limit (%s)" % message)
	game.set_item_count("pozhang_pill", 1)
	Session.Events.apply(game, [{"xp": 1640}])
	game.use_item("pozhang_pill")
	check(game.player.stage == 1 and int(game.player.mind) == 0 and game.mind_needed() == 6, "炼气中期 asks for a mind of six")
	check(game.mind_percent() == 50 and game.retreat_cap() == 120, "short of it, retreats yield half and last half as long")
	var day := int(game.world.day)
	var xp := int(game.player.xp)
	game.cultivate(360)
	check(int(game.world.day) == day + 120 and int(game.player.xp) == xp + 120, "so a hasty disciple gains little (%d)" % (int(game.player.xp) - xp))
	for i: int in 3:
		game.gain_insight("battle_win")
	check(int(game.player.mind) == 6 and game.mind_percent() == 100 and game.retreat_cap() == 240, "duels temper the mind up to the stage's need")
	Session.Events.apply(game, [{"mind": 10}])
	check(game.mind_percent() == 120, "a mind well above the need yields a fifth more")
	var ripe := _game()
	ripe.player.stage = 3
	ripe.player.xp = 7990
	ripe.player.mind = 24
	ripe.refresh_realm_stats()
	ripe.cultivate(180)
	check(int(ripe.player.xp) == 8000 and int(ripe.world.day) == 5 and ripe.at_xp_cap(), "炼气圆满 stops at the breakthrough's 8000 (day %d)" % ripe.world.day)
	day = int(ripe.world.day)
	check(ripe.cultivate(90).contains("之极") and int(ripe.world.day) == day, "and a retreat at the cap is refused without passing time")
	Session.Events.apply(ripe, [{"xp": 50}])
	check(int(ripe.player.xp) == 8000 and ripe.journal_lines().back().contains("50 点未能化入"), "rewards do not pile xp above it either")
	ripe.set_item_count("foundation_pill", 1)
	_steady(ripe)
	ripe.act("breakthrough")
	_weather(ripe)
	check(ripe.player.realm == 1 and int(ripe.player.xp) == 0 and ripe.retreat_cap() == 360 and ripe.mind_percent() == 50, "筑基 asks more of the mind (36) and allows two years at a time once it is there")
	ripe.player.mind = 36
	check(ripe.retreat_cap() == 720, "two years in seclusion are nothing to a foundation cultivator")
	ripe.player.stage = 3
	ripe.player.xp = 29990
	ripe.player.mind = 84
	ripe.refresh_realm_stats()
	ripe.cultivate(1800)
	check(int(ripe.player.xp) == 30000 and ripe.cultivate(30).contains("便可突破"), "foundation holds 30000 at most; the core is formed from there")
	var old := Session.new()
	check(old.restore(JSON.parse_string(FileAccess.get_file_as_string("res://tests/fixtures/v10_heavenly_midstage.json"))) and int(old.player.mind) == 6 and old.mind_percent() == 100, "older journeys start with the mind their stage asks for")
	var copy := Session.new()
	game.player.mind = 17
	check(copy.restore(JSON.parse_string(JSON.stringify(game.snapshot()))) and int(copy.player.mind) == 17, "the mind survives a save")

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
	check(int(game.content.locations.market.shop[0].price) == 280 and int(game.content.items.huichun_grass.price) == 4, "prices follow the slower economy: the 筑基丹 is something to save for")
	# Waiting anywhere is 调息: half the quiet room's pace, so a hurt player need not walk home.
	game.player.hp = 45
	game.wait(6)
	check(int(game.player.hp) == 45 + int(round(90.0 * 6.0 * 0.5 / 12.0)), "six days of 调息 in the wild heal a quarter (%d)" % int(game.player.hp))
	# 全部卖出 keeps what an accepted commission asks for.
	game.travel("market")
	game.set_item_count("huichun_grass", 5)
	game.player.quests = [{"key": "market:0:0", "kind": "gather", "board": "market", "item": "huichun_grass", "count": 3, "days": 60, "deadline": int(game.world.day) + 60, "progress": 0, "reward": {"stones": 30, "xp": 0, "contribution": 0}}]
	var told: String = game.act("sell")
	check(game.item_count("huichun_grass") == 3 and told.contains("留着没卖"), "selling everything keeps the commission's herbs")
	game.player.quests = []

## Takes away the talents an old journey awakened with, so the migrated numbers can be checked as saved.
func _untalented(game) -> void:
	game.player.talents = []
	game.player.flaws = []
	game.refresh_realm_stats()

func _saves() -> void:
	var qi := Session.new()
	check(qi.restore(JSON.parse_string(FileAccess.get_file_as_string("res://tests/fixtures/v5_qi_market.json"))), "v5 save migrates")
	_untalented(qi)
	check(qi.player.roots == ["metal", "wood", "fire"] and qi.player.stage == 0 and int(round(float(qi.content.rules.cultivate_xp) * qi.cultivation_speed())) == 60, "old journeys keep an ordinary three-element root")
	var base := Session.new()
	check(base.restore(JSON.parse_string(FileAccess.get_file_as_string("res://tests/fixtures/v5_foundation_ridge.json"))) and base.realm_name() == "筑基初期", "v5 foundation save keeps its realm")
	_untalented(base)
	check(base.player.max_hp == 140, "its stats follow the realm")
	var game := _game(["water", "earth"])
	Session.Events.apply(game, [{"xp": 2000}])
	game.gain_insight("event")
	game.cultivate(30)
	game.player.fatigue = 200
	var copy := Session.new()
	check(copy.restore(JSON.parse_string(JSON.stringify(game.snapshot()))) and copy.player.stage == 0 and copy.at_bottleneck() and copy.player.roots == ["water", "earth"], "a bottleneck and the roots survive a save")
	check(copy.player.insight == 15 and copy.retreat_fatigue() == 200 and copy.player.fatigue_day == game.player.fatigue_day, "insight and retreat fatigue survive a save")
	for field: Array in [["stage", 4], ["xp", 2001], ["insight", 101], ["fatigue_day", 999999], ["mind", -2], ["cultivation_carry", 3000]]:
		var broken: Dictionary = game.snapshot()
		broken.player[field[0]] = field[1]
		check(not copy.restore(broken), "%s %d rejected" % field)
	var stageless: Dictionary = game.snapshot()
	stageless.player.erase("stage")
	check(copy.restore(stageless) and copy.player.stage == 1, "a save without a stage takes it from xp")
	var v10 := Session.new()
	check(v10.restore(JSON.parse_string(FileAccess.get_file_as_string("res://tests/fixtures/v10_heavenly_midstage.json"))), "v10 save migrates")
	_untalented(v10)
	check(v10.player.stage == 1 and v10.player.xp == 3612 and v10.player.cultivation_carry == 1800 and v10.player.insight == 0 and v10.retreat_fatigue() == 0, "v10 keeps its stage and its finer remainder, with a fresh mind and no insight")
	v10.cultivate(1)
	check(v10.player.xp == 3616 and v10.player.cultivation_carry == 600, "the migrated remainder carries into the next retreat day")
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
	game.set_item_count("jingbei_tongpian", 1)
	var stones := int(game.player.stones)
	var flower: int = game.sell_price("chiyan_flower")
	game.sell("chiyan_flower", 1)
	check(int(game.player.stones) == stones + flower and flower >= 7 and flower <= 11 and game.item_count("chiyan_flower") == 1, "each herb sells at its own price, give or take the month (%d)" % flower)
	var rest: int = game.sell_price("chiyan_flower") + 3 * game.sell_price("huichun_grass")
	game.act("sell")
	check(int(game.player.stones) == stones + flower + rest and game.herb_count() == 0 and game.item_count("jingbei_tongpian") == 1, "selling everything keeps what the shop does not buy")
	# 坊市行情: a glut lowers a herb's price, which recovers with time; the month moves it too.
	var glutted: int = game.sell_price("huichun_grass")
	game.set_item_count("huichun_grass", 20)
	game.sell("huichun_grass", 20)
	check(game.Inventory.glut(game, "huichun_grass") > 20.0 and game.sell_price("huichun_grass") < glutted, "selling a heap lowers the price")
	var month_start := int(game.world.day)
	for step: int in 3:
		game.wait(10)
		_watch(game)
	check(game.Inventory.glut(game, "huichun_grass") < 20.0, "and the glut eases with the days")
	var copy := Session.new()
	check(copy.restore(JSON.parse_string(JSON.stringify(game.snapshot()))) and copy.sell_price("huichun_grass") == game.sell_price("huichun_grass"), "the market's memory survives a save")
	var prices := {}
	for month: int in 12:
		game.world.day = month_start + 30 * (month + 2) + 3000
		prices[game.sell_price("chiyan_flower")] = true
	check(prices.size() > 1, "prices move from month to month")
	game.player.stones = 30
	check(game.buy("foundation_pill").contains("灵石不足"), "a pill costs more than a new disciple has")
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
	game.player.xp = 1900
	game.use_item("lingzhi")
	check(int(game.player.xp) == 2000 and game.player.stage == 0 and game.at_bottleneck(), "a hundred-year lingzhi fills cultivation only up to the bottleneck")
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
	check(old.item_count("huichun_grass") >= 9 and old.item_count("foundation_pill") == 2 and not old.player.has("herbs"), "herbs and pills become items")

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

## Fixes the breakthrough's rolls: no 心魔, and a roll twenty points under the odds (a 中品 foundation,
## whose numbers are the plain ones).
## 金丹: foundation's end asks no pill and is harder; the core is formed in a stage (forming.gd) whose
## pearls grade it; the treasures of foundation do not serve; the grade survives a save.
func _golden_core() -> void:
	var game := _game()
	game.player.realm = 1
	game.player.stage = 3
	game.player.xp = 30000
	game.player.mind = 200
	game.player.foundation_grade = 2
	game.refresh_realm_stats()
	game.travel("sect")
	check(not game.next_breakthrough().has("pill") and game.breakthrough_block(game.breakthrough_plan()).is_empty(), "forming the core asks no pill: the cultivator stands on their own")
	game.set_item_count("qiannian_shiru", 1)
	check(game.breakthrough_treasures().is_empty(), "a treasure for foundation does not serve the core")
	var odds: Dictionary = game.breakthrough_odds(game.breakthrough_plan())
	check(odds.parts.any(func(part: Array) -> bool: return str(part[0]) == "冲击金丹" and int(part[1]) == 10), "the realm's own share of the odds is shown")
	game.set_item_count("xiaguang_lingsui", 1)
	var aided: Dictionary = game.breakthrough_odds(game.breakthrough_plan())
	check(game.breakthrough_treasures() == ["xiaguang_lingsui"] and int(aided.total) == mini(int(game.content.rules.breakthrough.most), int(odds.total) + 20) and aided.parts.any(func(part: Array) -> bool: return str(part[0]) == "霞光灵髓"), "a 天材地宝 for the core adds to the odds")
	game.set_item_count("xiaguang_lingsui", 0)
	var method := "t:breath:wood:3::0"
	game.player.learned.append(method)
	game.player.methods = [method]
	game.fortune = {"demon": 0.99, "breakthrough": 0.0, "grade": 0.99}
	game.act("breakthrough")
	check(not game.forming.is_empty() and game.battle.is_empty(), "the core is formed in a stage, not by a roll")
	# Nine pearls of one element: the stage's best.
	game.forming.round = int(game.Forming.data(game).rounds)
	game.forming.pearls = ["wood", "wood", "wood", "wood", "wood", "wood", "wood", "wood", "wood"]
	game.forming.orbs = []
	game.forming_end_round(true)
	_weather(game)
	check(game.player.realm == 2 and game.realm_name() == "金丹初期" and game.lifespan() >= 400, "the core is formed: 金丹初期, four hundred years")
	check(int(game.player.core_grade) == 8 and game.core_grade().name == "一品金丹" and game.player.core_kind == {"id": "pure", "elements": ["wood"]}, "nine pearls make an 一品金丹, of wood (%s)" % game.core_grade().get("name", ""))
	check(int(game.player.max_hp) > int(game.content.stage(2, 0).max_hp), "and a fine core strengthens the body")
	var copy := Session.new()
	check(copy.restore(JSON.parse_string(JSON.stringify(game.snapshot()))) and copy.core_grade() == game.core_grade(), "the core's grade survives a save")
	var broken: Dictionary = JSON.parse_string(JSON.stringify(game.snapshot()))
	broken.player.core_grade = 99
	check(not Session.new().restore(broken), "a grade out of range is refused")
	check(not game.next_breakthrough().is_empty() and not game.next_breakthrough().has("pill"), "past 金丹 lies 元婴, asking no pill either")
	# 元婴: the core keeps its grade; 天阶 arts can be studied.
	var core_before: int = int(game.player.core_grade)
	game.player.stage = 3
	game.player.xp = 80000
	game.player.mind = 400
	game.refresh_realm_stats()
	game.fortune = {"demon": 0.99, "breakthrough": 0.0, "grade": 0.99}
	game.act("breakthrough")
	# The 元婴 is formed in a stage too (nascent.gd), played out the plain way.
	check(not game.nascent.is_empty() and game.battle.is_empty(), "the 元婴 is formed in a stage, not by a roll")
	game.nascent.certain = true
	game.nascent_auto()
	_weather(game)
	check(game.player.realm == 3 and game.realm_name() == "元婴初期" and int(game.player.core_grade) == core_before and game.lifespan() >= 700, "元婴 is reached, the core's grade kept, seven hundred years")
	check(game.journal_lines().any(func(line: String) -> bool: return line.contains("元婴初期") and line.contains("元婴品质")) and not game.journal_lines().back().contains("金丹品级"), "the record names the realm and the 元婴's grade without regrading the core")
	# 化神, then the crossing at the ferry from 480.
	game.player.stage = 3
	game.player.xp = 200000
	game.player.mind = 600
	game.refresh_realm_stats()
	game.fortune = {"demon": 0.99, "breakthrough": 0.0, "grade": 0.99}
	# 化神 merges with a 道 far enough along (deifying.gd), and is formed in a stage played out.
	check(game.breakthrough_block(game.breakthrough_plan()).contains("合道"), "化神 asks a 道 to merge with")
	game.Dao.ensure(game).xp["wood"] = 30000
	game.act("breakthrough")
	check(not game.deifying.is_empty() and game.battle.is_empty(), "the 化神 is formed in a stage, not by a roll")
	game.deifying.certain = true
	game.deifying_auto()
	_weather(game)
	check(game.player.realm == 4 and game.realm_name() == "化神初期" and game.lifespan() >= 1200, "化神 is reached: twelve hundred years")
	game.player.mind = 600
	var sat := int(game.world.day)
	game.cultivate(game.retreat_cap())
	check(int(game.world.day) - sat > 3600, "a 化神 retreat may run past ten years (%d days)" % (int(game.world.day) - sat))
	game.player.birth_day = int(game.Calendar.to_day(400, 1, 1))
	game.travel("ferry")
	game.world.day = game.Calendar.to_day(480, 5, 30)
	game.wait(1)
	check(not game.has_flag("ascension_open") and not game.available_here("ascend"), "no fixed year opens the crossing any more (batch 6)")
	# The way settled at 照川城's 阵枢 opens it (ascension.gd); any stage of 化神 may cross.
	game.world.flags["ascension_open"] = true
	check(game.act("ascend").contains("阵枢"), "a 化神 with no way settled finds no path over the river")
	game.world.flags["path_self"] = true
	game.act("ascend")
	check(str(game.battle.get("context", "")) == "tribulation" and str(game.battle.get("ascension", "")) == "self", "the 飞升天劫 comes down")
	_weather(game)
	check(game.ended.get("kind", "") == "ascension" and str(game.ended.get("route", "")) == "self" and game.chronicle.entries.back().id == "ascended", "weathered, the life ends in the way of the Dao")
	var risen := Session.new()
	check(risen.restore(JSON.parse_string(JSON.stringify(game.snapshot()))) and risen.ended.kind == "ascension", "an ascension survives a save")
	var plain := _game()
	plain.player.realm = 1
	plain.player.stage = 3
	plain.player.xp = 30000
	plain.player.mind = 200
	plain.player.foundation_grade = 0
	plain.refresh_realm_stats()
	plain.travel("sect")
	plain.fortune = {"demon": 0.99, "grade": 0.99}
	plain.act("breakthrough")
	plain.forming.round = int(plain.Forming.data(plain).rounds)
	plain.forming.pearls = ["metal"]
	plain.forming.orbs = []
	plain.forming_end_round(true)
	_weather(plain)
	check(plain.player.realm == 2 and int(plain.player.core_grade) == 0 and plain.core_grade().name == "九品金丹" and str(plain.player.core_kind.id) == "mixed", "a single pearl makes a 九品金丹")

func _steady(game) -> void:
	game.fortune = {"demon": 0.99, "breakthrough": maxf(0.0, float(game.breakthrough_odds(game.breakthrough_plan()).total - 20) / 100.0)}

## 天劫 (combat.gd): from the 金丹 on a breakthrough is tested by lightning; weathered here by guarding
## at full health. Nothing when no 天劫 comes. A 筑基 stage under way (founding.gd) is first played out
## with a 中品 foundation's 灵液, as _steady's roll once made it.
func _weather(game) -> void:
	if not game.founding.is_empty():
		game.founding.round = int(game.Founding.data(game).rounds)
		game.founding.liquid = 125
		game.founding.orbs = []
		game.founding_end_round(true)
	var bolts := 0
	while not game.battle.is_empty() and str(game.battle.get("context", "")) == "tribulation" and bolts < 12:
		bolts += 1
		game.player.hp = game.player.max_hp
		game.end_turn()

## Casts 御剑诀 with the orbs it asks (金×1、任意×1): a journey begins with it only on a metal root.
func _sword(game) -> String:
	if not "sword" in game.player.learned:
		game.player.learned.append("sword")
	if not "sword" in game.player.arts:
		game.player.arts.append("sword")
	game.battle.orbs.append_array(["metal", "metal"])
	return game.use_skill("sword")

## 云溪's own occasions (潜龙会, the autumn auction) ask a choice of whoever stays there: watch.
func _watch(game) -> void:
	while not game.pending_event.is_empty():
		var choices: Array = game.pending_definition().get("choices", [])
		var pick: Array = choices.filter(func(choice: Dictionary) -> bool: return choice.id == "watch")
		game.choose_event(str((pick if not pick.is_empty() else choices)[0].id))
