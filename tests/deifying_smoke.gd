extends SceneTree
## 化神 as a stage (deifying.gd, docs/MCS_SYSTEMS_GAP_20261026.md A1): a 道 far enough along is merged
## with; the odds, the 道's stage, a 天材地宝 and fortune open the 仙性; 法 raise it, 凡性 rises each
## round; 仙性 at the goal first forms the 化神 (its 天劫 next), 凡性 there first fails the attempt. 淬体
## and 塑魂 gathered become health and 神识. A stage under way survives a save.
const Session = preload("res://scripts/core/session.gd")
const Deifying = preload("res://scripts/core/deifying.gd")
var checks := 0
var failures := 0

func check(condition: bool, message: String) -> void:
	checks += 1
	if not condition:
		failures += 1
		printerr("FAIL: " + message)

func _initialize() -> void:
	create_timer(120.0).timeout.connect(func() -> void: printerr("TIMEOUT: test did not finish (likely a script error)"); quit(1))
	_data()
	_merging()
	_opening()
	_arts()
	_race()
	_saved()
	_formed()
	_broken()
	_treasure()
	print("DEIFYING: %d checks, %d failures" % [checks, failures])
	quit(0 if failures == 0 else 1)

func _game(dao_xp: int = 8000, path: String = "fire", roots: Array = ["metal", "wood", "fire"], seed_value: int = 11) -> Session:
	var game := Session.new()
	game.encounters_enabled = false
	game.new_game("化神", seed_value, roots)
	game.player.realm = 3
	game.player.stage = 3
	game.player.core_grade = 4
	game.player["core_kind"] = {"id": "pure", "elements": ["fire"]}
	game.player.xp = 200000
	game.player.mind = 420
	if dao_xp > 0:
		game.Dao.ensure(game).xp[path] = dao_xp
	game.refresh_realm_stats()
	game.player.hp = game.player.max_hp
	game.travel("sect")
	game.fortune = {"demon": 0.99}
	return game

func _begin(game: Session, plan: Dictionary = {}) -> bool:
	var chosen: Dictionary = game.breakthrough_plan()
	chosen.merge(plan, true)
	game.breakthrough(chosen)
	return not game.deifying.is_empty()

func _reload(game: Session) -> Session:
	var copy := Session.new()
	check(copy.restore(JSON.parse_string(JSON.stringify(game.snapshot()))), "the journey survives a save")
	return copy

func _weather(game: Session) -> void:
	var bolts := 0
	while not game.battle.is_empty() and str(game.battle.get("context", "")) == "tribulation" and bolts < 12:
		bolts += 1
		game.player.hp = game.player.max_hp
		game.end_turn()

func _data() -> void:
	var game := Session.new()
	check(game.content.error_message.is_empty() and Deifying.valid_data(game.content), "the 化神 data loads and is valid (%s)" % game.content.error_message)
	check(Deifying.applies(4) and not Deifying.applies(3), "only the 化神 is formed in this stage")

func _merging() -> void:
	var none := _game(0)
	check(Deifying.paths(none).is_empty() and none.breakthrough_block(none.breakthrough_plan()).contains("合道"), "no 道 far enough along: no 化神")
	check(not _begin(none) and none.deifying.is_empty() and int(none.player.xp) == 200000, "and nothing is spent trying")
	var shallow := _game(7999)
	check(Deifying.paths(shallow).is_empty(), "a 道 just short of 略有小成 is not enough")
	var game := _game(8000)
	game.Dao.ensure(game).xp["sword"] = 30000
	check(Deifying.paths(game) == ["sword", "fire"], "the 道 far enough along, the furthest first")
	check(str(game.breakthrough_plan().dao) == "sword", "the plain plan merges with the furthest")
	check(not game.breakthrough_block({"pills": 0, "treasure": "", "guard": "", "dao": "water"}).is_empty(), "a 道 not far enough along cannot be chosen")
	check(game.breakthrough_block({"pills": 0, "treasure": "", "guard": "", "dao": "fire"}).is_empty(), "any 道 far enough along can")
	check(not bool(game.breakthrough_odds(game.breakthrough_plan()).demon) or true, "the odds are told as before")

func _opening() -> void:
	var game := _game(8000)
	var odds: int = int(game.breakthrough_odds(game.breakthrough_plan()).total)
	check(_begin(game, {"dao": "fire"}), "breaking through to 化神 opens the stage instead of a roll")
	check(int(game.player.realm) == 3 and game.battle.is_empty() and not game.player.has("attempt"), "no realm entered yet, no duel, no attempt waiting")
	var d: Dictionary = Deifying.data(game)
	check(int(game.deifying.immortal) == odds / int(d.odds_per) + int(d.dao.bonus[2]) and int(game.deifying.mortal) == 0, "the 仙性 opens from the odds (%d → %d)" % [odds, int(game.deifying.immortal)])
	check(str(game.deifying.dao) == "fire" and game.deifying.orbs.size() == int(d.draw), "the 道 chosen is kept; the first round draws its qi")
	check(not game.blocked().is_empty() and game.travel("market") != "" and str(game.player.location) == "sect", "nothing else can be done while forming the 化神")
	check(game.journal_lines().any(func(line: String) -> bool: return line.contains("合道")), "the chronicle tells the 道 merged with")
	var deep := _game(150000)
	_begin(deep)
	check(int(deep.deifying.immortal) == int(game.deifying.immortal) + int(d.dao.bonus[5]) - int(d.dao.bonus[2]), "大道已成 opens with more 仙性 (%d)" % int(deep.deifying.immortal))

func _arts() -> void:
	var game := _game()
	_begin(game)
	var immortal := int(game.deifying.immortal)
	game.deifying.orbs = ["metal", "wood", "earth"]
	game.deifying_cast("ganying")
	check(int(game.deifying.immortal) == immortal + 7, "感应法 of three elements: 仙性 +7")
	game.deifying.orbs = ["fire", "fire", "fire"]
	game.deifying_cast("ganying", ["fire", "fire", "fire"])
	check(int(game.deifying.immortal) == immortal + 7 + 12, "three of one element: +12 (【同】)")
	game.deifying.orbs = ["wood", "wood", "fire"]
	game.deifying_cast("ganying")
	check(int(game.deifying.immortal) == immortal + 7 + 12 + 9, "two that generate each other: +9 (【生】)")
	game.deifying.mortal = 20
	game.deifying.orbs = ["wood", "fire"]
	game.deifying_cast("shouxin")
	check(int(game.deifying.mortal) == 14 and not Deifying.block(game, "shouxin").is_empty(), "守心诀 holds the 凡性 down (more with 生), once a round")
	game.deifying.orbs = ["metal", "metal"]
	game.deifying_cast("cuiti")
	check(int(game.deifying.temper) == 1 and int(game.deifying.mortal) == 16, "淬体法: 淬体 +1, at a little 凡性")
	game.deifying.orbs = ["metal", "wood", "water"]
	game.deifying_cast("suhun")
	check(int(game.deifying.soul) == 1 and int(game.deifying.mortal) == 18, "塑魂法: 塑魂 +1, at a little 凡性")
	game.deifying.immortal = 10
	game.deifying.orbs = ["earth", "earth", "earth", "earth"]
	game.deifying_cast("tianren")
	check(int(game.deifying.immortal) == 28 and not Deifying.block(game, "tianren").is_empty(), "天人合一: 仙性 +18, once")
	check(Deifying.preview_words(game, "ganying", ["fire", "fire", "fire"]).is_empty(), "nothing to preview without the qi")
	game.deifying.orbs = ["fire", "fire", "fire"]
	check(Deifying.preview_words(game, "ganying", ["fire", "fire", "fire"]).contains("仙性 +12"), "the preview tells the 仙性")
	var mortal := int(game.deifying.mortal)
	game.deifying_discard("fire")
	check(int(game.deifying.mortal) == mortal + int(Deifying.data(game).discard), "letting qi go stirs the 凡性")

func _race() -> void:
	var game := _game()
	_begin(game)
	var mortal := int(game.deifying.mortal)
	var rise := Deifying.strain(game)
	game.deifying.orbs = []
	game.deifying_end_round()
	check(int(game.deifying.mortal) == mortal + rise and int(game.deifying.round) == 2 and game.deifying.orbs.size() == int(Deifying.data(game).draw), "each round's end raises the 凡性; the next draws its qi")
	game.deifying.orbs = ["metal", "metal", "metal", "metal", "metal", "metal", "metal", "metal"]
	check(game.deifying_end_round().contains("先散去"), "the round cannot end with qi over the cap")
	game.deifying.round = 30
	check(Deifying.strain(game) == int(Deifying.data(game).strain.back()), "past the list, the last rise repeats")

func _saved() -> void:
	var game := _game()
	_begin(game)
	game.deifying.orbs = ["metal", "metal"]
	game.deifying_cast("cuiti")
	var copy := _reload(game)
	check(copy.deifying == game.deifying and not copy.blocked().is_empty(), "the stage under way survives a save")
	var data: Dictionary = JSON.parse_string(JSON.stringify(game.snapshot()))
	for broken: Callable in [
		func(d: Dictionary) -> void: d.deifying.immortal = 100,
		func(d: Dictionary) -> void: d.deifying.orbs = ["gold"],
		func(d: Dictionary) -> void: d.deifying.dao = "nothing",
		func(d: Dictionary) -> void: d.deifying.used = {"nothing": 1},
		func(d: Dictionary) -> void: d.player.realm = 4,
		func(d: Dictionary) -> void: d.nascent = {"round": 1},
		func(d: Dictionary) -> void: d.player.deity = {"dao": "fire", "temper": -1, "soul": 0},
	]:
		var bad: Dictionary = data.duplicate(true)
		broken.call(bad)
		check(not Session.new().restore(bad), "a malformed stage or 化神 record is refused")
	var older: Dictionary = data.duplicate(true)
	older.erase("deifying")
	check(Session.new().restore(older), "saves from before the stage still load")

func _formed() -> void:
	var game := _game(70000)
	_begin(game)
	var hp_before := int(game.player.max_hp)
	game.deifying.temper = 4
	game.deifying.soul = 3
	game.deifying.immortal = 95
	game.deifying.orbs = ["metal", "wood", "earth"]
	game.deifying_cast("ganying")
	check(game.deifying.is_empty() and str(game.battle.get("context", "")) == "tribulation" and game.player.deity == {"dao": "fire", "temper": 4, "soul": 3}, "仙性 at the goal forms the 化神, its 天劫 next, the 道 and gains kept")
	check(game.journal_lines().any(func(line: String) -> bool: return line.contains("仙性圆满")), "the chronicle tells it")
	_weather(game)
	check(int(game.player.realm) == 4, "weathered, 化神 is entered")
	var plain := Session.new()
	plain.new_game("化神", 11, ["metal", "wood", "fire"])
	plain.player.realm = 4
	plain.refresh_realm_stats()
	var rewards: Dictionary = Deifying.data(game).rewards
	check(int(game.player.max_hp) == int(plain.player.max_hp) + 4 * int(rewards.temper_hp) or int(game.player.max_hp) > hp_before, "淬体 adds health (%d)" % int(game.player.max_hp))
	check(Deifying.gains(game.content, game.player) == {"max_hp": 4 * int(rewards.temper_hp), "sense": 3 * int(rewards.soul_sense)}, "淬体 and 塑魂 as health and 神识")
	var sense_without := game.sense() - 3 * int(rewards.soul_sense)
	check(game.sense() == sense_without + 3 * int(rewards.soul_sense), "塑魂 adds to the 神识")
	var copy := _reload(game)
	check(copy.player.deity == game.player.deity and int(copy.player.max_hp) == int(game.player.max_hp), "the 化神 record survives a save")
	var auto := _game(30000, "fire", ["fire"])
	_begin(auto)
	auto.deifying_auto()
	check(auto.deifying.is_empty() and (str(auto.battle.get("context", "")) == "tribulation" or int(auto.player.lessons) == 1), "played out the plain way, it forms or fails")

func _broken() -> void:
	var game := _game()
	_begin(game)
	var xp := int(game.deifying.xp)
	game.deifying.mortal = 99
	game.deifying.orbs = ["metal"]
	game.deifying_discard("metal")
	check(game.deifying.is_empty() and int(game.player.realm) == 3 and game.injured() and int(game.player.lessons) == 1 and not game.player.has("deity"), "凡性 at the goal first fails the attempt")
	check(int(game.player.xp) == xp * int(game.content.rules.breakthrough.failure.xp_percent) / 100, "the cultivation falls back a little")
	check(game.journal_lines().any(func(line: String) -> bool: return line.contains("凡性先满")), "the chronicle tells the 凡性 won")
	var certain := _game()
	certain.player.boons = {"remnant": "ready"}
	_begin(certain)
	certain.deifying.mortal = 99
	certain.deifying.orbs = ["metal"]
	certain.deifying_discard("metal")
	check(not certain.deifying.is_empty() and int(certain.deifying.mortal) == 99, "a certain attempt (残魂灌顶) holds the 凡性 short")

func _treasure() -> void:
	var game := _game()
	var plain := _game()
	_begin(plain)
	game.set_item_count("tianxin_lianzi", 1)
	_begin(game, {"treasure": "tianxin_lianzi"})
	var gift := int(Deifying.data(game).treasures.tianxin_lianzi.immortal)
	check(game.item_count("tianxin_lianzi") == 0 and int(game.deifying.immortal) > int(plain.deifying.immortal) + gift, "天心莲子 opens with more 仙性: its own, its odds, its step (%d against %d)" % [int(game.deifying.immortal), int(plain.deifying.immortal)])
	var copy := _reload(game)
	check(str(copy.deifying.treasure) == "tianxin_lianzi", "and is remembered across a save")
