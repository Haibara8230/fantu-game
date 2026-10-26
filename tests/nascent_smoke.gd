extends SceneTree
## 结婴 as a stage (nascent.gd, docs/MCS_SYSTEMS_GAP_20261026.md A1): the attempt's odds become the 意志,
## the 金丹's grade its 丹坚 and 经脉; 秘术 crack the core, which pours its pearls back as qi of its kind;
## then a 念 each round, answered to lower the 魔势 (none left: the 元婴 at once), unanswered to strike the
## 意志. The 意志 kept grades the 元婴, which adds to the 金丹's grade; worn to none, or the core never
## broken, the attempt fails. No 心魔 comes before the stage. A stage under way survives a save.
const Session = preload("res://scripts/core/session.gd")
const Nascent = preload("res://scripts/core/nascent.gd")
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
	_opening()
	_shatter()
	_thoughts()
	_arts()
	_saved()
	_formed()
	_broken()
	_unbroken()
	_grades()
	_treasure()
	print("NASCENT: %d checks, %d failures" % [checks, failures])
	quit(0 if failures == 0 else 1)

func _game(roots: Array = ["metal", "wood", "fire"], seed_value: int = 11, core_grade: int = 4) -> Session:
	var game := Session.new()
	game.encounters_enabled = false
	game.new_game("结婴", seed_value, roots)
	game.player.realm = 2
	game.player.stage = 3
	game.player.core_grade = core_grade
	game.player["core_kind"] = {"id": "pure", "elements": ["fire"]}
	game.player.xp = 80000
	game.player.mind = 210
	game.refresh_realm_stats()
	game.player.hp = game.player.max_hp
	game.player.stones = 5000
	game.travel("sect")
	game.fortune = {"demon": 0.0, "grade": 0.99}
	return game

func _begin(game: Session, plan: Dictionary = {}) -> bool:
	var chosen: Dictionary = game.breakthrough_plan()
	chosen.merge(plan, true)
	game.breakthrough(chosen)
	return not game.nascent.is_empty()

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

## Breaks the core at once, as if the 秘术 had done it.
func _crack(game: Session) -> void:
	game.nascent.orbs = ["fire", "fire", "fire"]
	game.nascent.core = 1
	game.nascent_cast("suidan")

func _data() -> void:
	var game := Session.new()
	check(game.content.error_message.is_empty() and Nascent.valid_data(game.content), "the 结婴 data loads and is valid (%s)" % game.content.error_message)
	check(Nascent.applies(3) and not Nascent.applies(2) and not Nascent.applies(4), "only the 元婴 is formed in this stage")

func _opening() -> void:
	var game := _game()
	var odds: int = int(game.breakthrough_odds(game.breakthrough_plan()).total)
	check(not bool(game.breakthrough_odds(game.breakthrough_plan()).demon), "no 心魔 waits before the stage: it is within")
	check(_begin(game), "breaking through to 元婴 opens the stage instead of a roll")
	check(int(game.player.realm) == 2 and game.battle.is_empty() and game.pending_event.is_empty() and not game.player.has("attempt"), "no realm entered yet, no duel, no choice waiting")
	check(int(game.nascent.will) == odds and int(game.nascent.most) == odds, "the 意志 starts at the odds (%d / %d)" % [int(game.nascent.will), odds])
	var d: Dictionary = Nascent.data(game)
	check(int(game.nascent.core) == int(d.core.base) + 4 * int(d.core.per_grade) and Nascent.cap(game) == int(d.cap_by_core[4]), "a 五品 core: its 丹坚 and 经脉")
	var short: int = (game.Breakthrough.demon_mind(game) - 210) / int(d.demon.per_mind)
	check(short > 0 and int(game.nascent.demon) == clampi(int(d.demon.base) + short, int(d.demon.least), int(d.demon.most)), "the 魔势 rises with the mind short of the 元婴 (%d)" % int(game.nascent.demon))
	check(int(game.nascent.round) == 1 and game.nascent.orbs.size() == int(d.draw) and str(game.nascent.thought).is_empty(), "the first round draws its qi; no 念 before the core breaks")
	check(not game.blocked().is_empty() and game.travel("market") != "" and str(game.player.location) == "sect", "nothing else can be done while forming the 元婴")
	check(game.journal_lines().any(func(line: String) -> bool: return line.contains("碎丹结婴")), "the chronicle tells the stage began")
	var calm := _game()
	calm.player.mind = 300
	_begin(calm)
	check(int(calm.nascent.demon) < int(d.demon.base), "a mind well above the need weakens the 心魔 (%d)" % int(calm.nascent.demon))

func _shatter() -> void:
	var game := _game()
	_begin(game)
	check(not Nascent.block(game, "fenshen").is_empty() and not Nascent.block(game, "nizhoutian").is_empty(), "the 结婴 arts wait for the core to break")
	check(not Nascent.block(game, "liedan").is_empty() and not "liedan" in Nascent.known_arts(game), "裂丹诀 asks the 凝婴之法")
	game.world.flags["ningying_known"] = true
	check("liedan" in Nascent.known_arts(game) and not "nizhoutian" in Nascent.known_arts(game), "the 凝婴之法 teaches 裂丹诀; 逆周天结婴术 asks the 无相凝婴诀")
	game.nascent.orbs = ["metal", "wood", "fire", "fire", "fire"]
	var core := int(game.nascent.core)
	game.nascent_cast("xieling", ["metal", "wood"])
	check(int(game.nascent.core) == core - 2 and game.nascent.orbs == ["fire", "fire", "fire"], "卸灵术 pays two qi for 丹坚 -2")
	game.nascent_cast("suidan")
	check(int(game.nascent.core) == core - 8 and game.nascent.orbs.is_empty(), "碎丹诀 pays three of one element for 丹坚 -6")
	var will := int(game.nascent.will)
	game.nascent_end_round(true)
	check(int(game.nascent.will) == will - int(Nascent.data(game).core.strain) and int(game.nascent.round) == 2, "a round the core stands jars the 意志")
	game.nascent.orbs = ["metal", "metal", "metal", "metal"]
	will = int(game.nascent.will)
	var told := game.nascent_cast("liedan")
	check(Nascent.shattered(game) and int(game.nascent.will) == will - 6, "裂丹诀 breaks it, at a cost to the 意志 (%s)" % told)
	var pouring: int = int(Nascent.data(game).release.base) + 4 / int(Nascent.data(game).release.per_grades)
	check(game.nascent.orbs.size() == pouring and game.nascent.orbs.count("fire") == pouring, "the shattered 纯火 core pours back %d fire qi" % pouring)
	check(not str(game.nascent.thought).is_empty() and game.nascent.acts.is_empty(), "the first 念 rises at once, the round's 秘术 so far not counted")
	check(not Nascent.block(game, "suidan").is_empty(), "the 碎丹 arts are spent with the core")
	var mixed := _game()
	mixed.player.core_kind = {"id": "mixed", "elements": []}
	_begin(mixed)
	_crack(mixed)
	check(mixed.nascent.orbs.all(func(element: String) -> bool: return element in mixed.player.roots), "a 混元 core pours back qi by the roots")

func _thoughts() -> void:
	var game := _game()
	_begin(game)
	_crack(game)
	game.nascent.thought = "fear"
	game.nascent.orbs = ["water", "water", "water"]
	check(not Nascent.answered(game), "惧念 is not answered by nothing")
	game.nascent_cast("qingxin")
	check(Nascent.answered(game), "惧念 answered by 清心咒")
	var demon := int(game.nascent.demon)
	var will := int(game.nascent.will)
	game.nascent_end_round(true)
	check(int(game.nascent.demon) == demon - int(Nascent.data(game).demon.answer) and int(game.nascent.will) == will, "answered, the 魔势 falls and the 意志 is spared")
	check(str(game.nascent.thought) != "fear", "the next 念 is another")
	game.nascent.thought = "greed"
	game.nascent.orbs = ["metal", "wood"]
	check(not Nascent.answered(game), "贪念 asks the qi let go")
	game.nascent.orbs = []
	check(Nascent.answered(game), "贪念 answered by holding nothing")
	game.nascent.acts = ["qingxin"]
	check(not Nascent.answered(game), "贪念 not answered once a 秘术 ran")
	game.nascent.acts = []
	game.nascent.thought = "sorrow"
	game.nascent.orbs = ["metal", "wood", "fire"]
	check(not Nascent.answered(game), "悲念 asks two qi at most")
	game.Nascent.release_to(game, 2)
	check(Nascent.answered(game) and game.nascent.orbs.size() == 2, "letting one go answers it")
	game.nascent.thought = "longing"
	game.nascent.orbs = ["metal", "metal", "wood"]
	check(not Nascent.answered(game), "思念 asks three elements")
	game.nascent.orbs = ["metal", "water", "wood"]
	check(Nascent.answered(game), "three elements answer it")
	game.nascent.thought = "pride"
	game.nascent.orbs = ["metal", "water", "wood"]
	game.nascent_cast("fenshen")
	check(Nascent.answered(game) and int(game.nascent.ward) == 3 and int(game.nascent.later) == 2, "傲念 answered by 分神术, which also wards and costs the next round")
	# Unanswered: the 意志 takes the 魔势.
	game.nascent.thought = "longing"
	game.nascent.orbs = []
	will = int(game.nascent.will)
	var blow := Nascent.blow(game)
	game.nascent_end_round(true)
	check(blow == int(game.nascent.get("demon", 0)) - 3 and int(game.nascent.will) == will - blow, "unanswered, the 意志 takes the 魔势 less the ward (%d)" % blow)
	check(int(game.nascent.extra) == 2 and Nascent.blow(game) == int(game.nascent.demon) + 2, "and the next round the 心魔 strikes harder")

func _arts() -> void:
	var game := _game()
	game.world.flags["wuxiang_ningying"] = true
	_begin(game)
	_crack(game)
	game.nascent.orbs = ["wood", "fire", "earth"]
	game.nascent.will = int(game.nascent.most) - 10
	var will := int(game.nascent.will)
	check(game.nascent_cast("qingxin").contains("配气不符") or not Nascent.block(game, "qingxin").is_empty(), "清心咒 asks three of one element")
	game.nascent.orbs = ["wood", "wood", "wood"]
	game.nascent_cast("qingxin")
	check(int(game.nascent.will) == will + 5 and not Nascent.block(game, "qingxin").is_empty(), "清心咒: 意志 +5, once a round")
	game.nascent.orbs = ["earth", "earth", "earth", "earth", "earth"]
	var demon := int(game.nascent.demon)
	var cap := Nascent.cap(game)
	game.nascent_cast("nizhoutian")
	check(int(game.nascent.demon) == demon - 3 and Nascent.cap(game) == cap - 1 and not Nascent.block(game, "nizhoutian").is_empty(), "逆周天结婴术: 魔势 -3, the 经脉 narrowed, once")
	game.nascent.orbs = ["metal"]
	will = int(game.nascent.will)
	game.nascent_discard("metal")
	check(int(game.nascent.will) == will - int(Nascent.data(game).discard), "letting qi go costs the 意志")
	game.nascent.orbs = ["metal", "metal", "metal", "metal", "metal", "metal", "metal", "metal", "metal", "metal"]
	check(game.nascent_end_round().contains("先散去"), "the round cannot end with qi over the 经脉")

func _saved() -> void:
	var game := _game()
	_begin(game)
	_crack(game)
	var copy := _reload(game)
	check(copy.nascent == game.nascent and not copy.blocked().is_empty(), "the stage under way survives a save")
	var data: Dictionary = JSON.parse_string(JSON.stringify(game.snapshot()))
	for broken: Callable in [
		func(d: Dictionary) -> void: d.nascent.round = 99,
		func(d: Dictionary) -> void: d.nascent.orbs = ["gold"],
		func(d: Dictionary) -> void: d.nascent.will = int(d.nascent.most) + 1,
		func(d: Dictionary) -> void: d.nascent.thought = "envy",
		func(d: Dictionary) -> void: d.nascent.thought = "",
		func(d: Dictionary) -> void: d.nascent.used = {"nothing": 1},
		func(d: Dictionary) -> void: d.player.realm = 3,
		func(d: Dictionary) -> void: d.forming = d.nascent.duplicate(true),
		func(d: Dictionary) -> void: d.player.nascent_grade = 9,
	]:
		var bad: Dictionary = data.duplicate(true)
		broken.call(bad)
		check(not Session.new().restore(bad), "a malformed stage or grade is refused")
	var older: Dictionary = data.duplicate(true)
	older.erase("nascent")
	check(Session.new().restore(older), "saves from before the stage still load")

func _formed() -> void:
	var game := _game()
	game.world.flags["ningying_known"] = true
	_begin(game)
	game.nascent_auto()
	check(game.nascent.is_empty() and str(game.battle.get("context", "")) == "tribulation", "played out, the 元婴 waits on its 天劫")
	check(game.journal_lines().any(func(line: String) -> bool: return line.contains("凝成")), "the chronicle tells the 元婴 formed")
	_weather(game)
	check(int(game.player.realm) == 3 and game.player.has("nascent_grade") and not game.nascent_grade().is_empty(), "the realm is entered with a 元婴 grade (%s)" % game.nascent_grade().get("name", ""))
	check(int(game.player.core_grade) == 4 and game.player.core_kind == {"id": "pure", "elements": ["fire"]}, "the 金丹's grade and kind are kept")
	var copy := _reload(game)
	check(int(copy.player.nascent_grade) == int(game.player.nascent_grade), "the 元婴 grade survives a save")
	var many := _game(["metal", "wood", "water", "fire", "earth"], 5, 0)
	many.player.core_kind = {"id": "mixed", "elements": []}
	_begin(many)
	many.nascent_auto()
	_weather(many)
	check(many.nascent.is_empty() and (int(many.player.realm) == 3 or int(many.player.lessons) == 1), "a 九品 混元 core and five roots play the stage out by the plain way, formed or failed (%s)" % many.nascent_grade().get("name", "failed"))

func _broken() -> void:
	var game := _game()
	_begin(game)
	var xp := int(game.nascent.xp)
	game.nascent.will = 1
	game.nascent.orbs = ["metal"]
	game.nascent_discard("metal")
	check(game.nascent.is_empty() and int(game.player.realm) == 2 and game.injured() and int(game.player.lessons) == 1, "the 意志 worn to none fails the attempt")
	check(int(game.player.xp) == xp * int(game.content.rules.breakthrough.failure.xp_percent) / 100 and game.player.has("core_kind"), "the cultivation falls back a little; the 金丹 is kept")
	check(game.journal_lines().any(func(line: String) -> bool: return line.contains("意志溃散")), "the chronicle tells the 意志 gave way")
	var certain := _game()
	_begin(certain)
	certain.nascent.certain = true
	certain.nascent.will = 2
	certain.nascent.orbs = ["metal", "metal"]
	certain.nascent_discard("metal")
	certain.nascent_discard("metal")
	check(not certain.nascent.is_empty() and int(certain.nascent.will) == 1, "a certain attempt (残魂灌顶) cannot give way")

func _unbroken() -> void:
	var game := _game()
	_begin(game)
	var guard := 0
	while not game.nascent.is_empty() and guard < 20:
		guard += 1
		game.nascent.will = int(game.nascent.most)
		game.nascent.orbs = []
		game.nascent_end_round(true)
	check(int(game.player.realm) == 2 and game.battle.is_empty() and game.journal_lines().any(func(line: String) -> bool: return line.contains("金丹仍未碎开")), "nine rounds without breaking the core form nothing")

func _grades() -> void:
	var game := _game()
	_begin(game)
	_crack(game)
	var grades: Array = game.content.rules.breakthrough.nascent.grades
	game.nascent.will = int(game.nascent.most)
	game.nascent.demon = 1
	check(Nascent.grade_now(game) == 1, "with 心魔 unsubdued, no better than %s" % grades[1].name)
	game.nascent.demon = 0
	check(Nascent.grade_now(game) == grades.size() - 1, "all the 意志 kept, 心魔 gone: %s" % grades[-1].name)
	game.nascent.will = maxi(1, int(game.nascent.most) / 5)
	check(Nascent.grade_now(game) == 0, "a fifth of it: %s" % grades[0].name)
	# Subduing the last of it forms the 元婴 at once.
	game.nascent.will = int(game.nascent.most)
	game.nascent.demon = int(Nascent.data(game).demon.answer)
	game.nascent.thought = "greed"
	game.nascent.orbs = []
	game.nascent.acts = []
	game.nascent_end_round(true)
	check(game.nascent.is_empty() and str(game.battle.get("context", "")) == "tribulation", "the last 念 answered, the 元婴 forms at once")
	_weather(game)
	check(int(game.player.realm) == 3 and int(game.player.nascent_grade) == grades.size() - 1, "a 元婴 with all its 意志 is %s" % grades[-1].name)
	var core: Dictionary = game.core_grade()
	var shaped: Dictionary = game.Breakthrough.grade_of(game)
	check(int(shaped.stats) == int(core.stats) + int(grades[-1].stats) and int(shaped.speed) == int(core.speed) + int(grades[-1].speed), "the 元婴's grade adds to the 金丹's")
	var older := _game()
	older.player.realm = 3
	check(older.nascent_grade().name == grades[1].name, "a 元婴 formed before the stage counts as %s" % grades[1].name)

func _treasure() -> void:
	var game := _game()
	game.set_item_count("yanghun_mu", 1)
	var plain := int(Nascent.demon_of(game, ""))
	_begin(game, {"treasure": "yanghun_mu"})
	check(int(game.nascent.demon) == plain - 2 and game.item_count("yanghun_mu") == 0, "养魂木 weakens the 心魔")
	var fruit := _game()
	fruit.set_item_count("qiannian_zhuguo", 1)
	_begin(fruit, {"treasure": "qiannian_zhuguo"})
	check(Nascent.cap(fruit) == int(Nascent.data(fruit).cap_by_core[4]) + 2, "千年朱果 widens the 经脉")
	var copy := _reload(fruit)
	check(str(copy.nascent.treasure) == "qiannian_zhuguo", "and is remembered across a save")
