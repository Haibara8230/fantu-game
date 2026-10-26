extends SceneTree
## 筑基 as a stage (founding.gd, docs/MCS_SYSTEMS_GAP_20261026.md A1): the attempt's odds (the 筑基丹
## among them) become the 真元; nine rounds of qi drawn by the roots, pressed into 灵液 by 秘术; the 灵液
## at the goal lays the foundation, past it a finer one; short of it, or the 真元 worn to none, the
## attempt fails. 心魔 may still come before it. A stage under way survives a save.
const Session = preload("res://scripts/core/session.gd")
const Founding = preload("res://scripts/core/founding.gd")
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
	_arts()
	_saved()
	_laid()
	_grades()
	_short()
	_broken()
	_demon()
	_treasure()
	print("FOUNDING: %d checks, %d failures" % [checks, failures])
	quit(0 if failures == 0 else 1)

func _game(roots: Array = ["metal", "wood", "fire"], seed_value: int = 11, pills: int = 1) -> Session:
	var game := Session.new()
	game.encounters_enabled = false
	game.new_game("筑基", seed_value, roots)
	game.player.stage = 3
	game.player.xp = 8000
	game.player.mind = 40
	game.refresh_realm_stats()
	game.player.hp = game.player.max_hp
	game.travel("sect")
	game.set_item_count("foundation_pill", pills)
	game.fortune = {"demon": 0.99, "grade": 0.99}
	return game

func _begin(game: Session, plan: Dictionary = {}) -> bool:
	var chosen: Dictionary = game.breakthrough_plan()
	chosen.merge(plan, true)
	game.breakthrough(chosen)
	return not game.founding.is_empty()

func _reload(game: Session) -> Session:
	var copy := Session.new()
	check(copy.restore(JSON.parse_string(JSON.stringify(game.snapshot()))), "the journey survives a save")
	return copy

## Plays the stage out with the 灵液 set to `liquid` before the last round ends.
func _finish(game: Session, liquid: int) -> void:
	game.founding.round = int(Founding.data(game).rounds)
	game.founding.liquid = liquid
	game.founding.orbs = []
	game.founding_end_round(true)

func _data() -> void:
	var game := Session.new()
	check(game.content.error_message.is_empty() and Founding.valid_data(game.content), "the 筑基 data loads and is valid (%s)" % game.content.error_message)
	check(Founding.applies(1) and not Founding.applies(2), "only the foundation is laid in this stage")

func _opening() -> void:
	var game := _game()
	var odds: int = int(game.breakthrough_odds(game.breakthrough_plan()).total)
	check(_begin(game), "breaking through to 筑基 opens the stage instead of a roll")
	check(int(game.player.realm) == 0 and game.battle.is_empty() and not game.player.has("attempt"), "no realm entered yet, no duel, no attempt waiting")
	check(int(game.founding.essence) == odds and int(game.founding.most) == odds and game.item_count("foundation_pill") == 0, "the 真元 starts at the odds, the 筑基丹 taken (%d)" % odds)
	check(int(game.founding.round) == 1 and game.founding.orbs.size() == int(Founding.data(game).draw) and int(game.founding.liquid) == 0, "the first round draws its qi; no 灵液 yet")
	check(game.founding.orbs.all(func(element: String) -> bool: return element in game.player.roots), "qi comes by the spirit roots")
	check(not game.blocked().is_empty() and game.travel("market") != "" and str(game.player.location) == "sect", "nothing else can be done while laying the foundation")
	check(game.journal_lines().any(func(line: String) -> bool: return line.contains("开始筑基")), "the chronicle tells the stage began")
	var two := _game(["metal", "wood", "fire"], 11, 2)
	_begin(two, {"pills": 2})
	check(int(two.founding.most) > odds, "a second 筑基丹 means more 真元 (%d)" % int(two.founding.most))
	var none := _game(["metal", "wood", "fire"], 11, 0)
	check(not _begin(none) and none.founding.is_empty(), "no 筑基丹, no stage")

func _arts() -> void:
	var game := _game()
	_begin(game)
	game.founding.orbs = ["metal", "metal", "wood"]
	game.founding_cast("ningye")
	check(int(game.founding.liquid) == 9 and game.founding.orbs == ["wood"], "凝液 presses two of a kind into 灵液")
	game.founding.orbs = ["wood", "wood", "fire"]
	game.founding_cast("huaqi")
	check(int(game.founding.liquid) == 9 + 6 + 4, "化气 with two that generate each other makes more (【生】)")
	game.founding.orbs = ["metal", "wood", "earth"]
	game.founding_cast("huaqi")
	check(int(game.founding.liquid) == 9 + 10 + 6, "化气 of three elements: the plain amount")
	game.founding.orbs = ["fire", "fire", "fire", "fire"]
	var essence := int(game.founding.essence)
	game.founding_cast("yasuo")
	check(int(game.founding.liquid) == 25 + 25 and int(game.founding.essence) == essence - 6 and not Founding.block(game, "yasuo").is_empty(), "压缩灵液: four of a kind, much 灵液, at a cost; once a round")
	game.founding.orbs = ["metal"]
	essence = int(game.founding.essence)
	game.founding_cast("yinqi")
	check(game.founding.orbs.size() == 2 and int(game.founding.essence) == essence - 5, "引气入体 draws two more for 真元")
	game.founding.orbs = ["metal", "fire"]
	essence = int(game.founding.essence)
	game.founding_cast("tiaoxi")
	check(int(game.founding.essence) == mini(int(game.founding.most), essence + 5), "调息 shores the 真元 up")
	check(Founding.preview_words(game, "ningye", ["metal", "metal"]).is_empty(), "nothing to preview without the qi")
	game.founding.orbs = ["wood", "wood", "fire"]
	check(Founding.preview_words(game, "huaqi", ["wood", "wood", "fire"]).contains("【生】") and Founding.preview_words(game, "huaqi", ["wood", "wood", "fire"]).contains("灵液 +10"), "the preview tells the 生 and the 灵液")
	game.founding.orbs = ["metal", "metal", "metal", "metal", "metal", "metal", "metal", "metal"]
	check(game.founding_end_round().contains("先散去"), "the round cannot end with qi over the cap")
	essence = int(game.founding.essence)
	game.founding_discard("metal")
	check(int(game.founding.essence) == essence - int(Founding.data(game).discard), "letting qi go costs the 真元")
	var round_was := int(game.founding.round)
	essence = int(game.founding.essence)
	var strain := Founding.strain(game)
	game.founding_end_round(true)
	check(int(game.founding.round) == round_was + 1 and int(game.founding.essence) <= essence - strain, "the round's 灵压 wears the 真元")

func _saved() -> void:
	var game := _game()
	_begin(game)
	game.founding.orbs = ["metal", "metal"]
	game.founding_cast("ningye")
	var copy := _reload(game)
	check(copy.founding == game.founding and not copy.blocked().is_empty(), "the stage under way survives a save")
	var data: Dictionary = JSON.parse_string(JSON.stringify(game.snapshot()))
	for broken: Callable in [
		func(d: Dictionary) -> void: d.founding.round = 99,
		func(d: Dictionary) -> void: d.founding.orbs = ["gold"],
		func(d: Dictionary) -> void: d.founding.essence = int(d.founding.most) + 1,
		func(d: Dictionary) -> void: d.founding.liquid = -3,
		func(d: Dictionary) -> void: d.founding.used = {"nothing": 1},
		func(d: Dictionary) -> void: d.player.realm = 1,
		func(d: Dictionary) -> void: d.forming = {"round": 1},
	]:
		var bad: Dictionary = data.duplicate(true)
		broken.call(bad)
		check(not Session.new().restore(bad), "a malformed stage is refused")
	var older: Dictionary = data.duplicate(true)
	older.erase("founding")
	check(Session.new().restore(older), "saves from before the stage still load")

func _laid() -> void:
	var game := _game(["fire"])
	_begin(game)
	game.founding_auto()
	check(game.founding.is_empty() and int(game.player.realm) == 1 and game.battle.is_empty(), "played out, the foundation is laid (no 天劫 at 筑基)")
	check(game.journal_lines().any(func(line: String) -> bool: return line.contains("铺成一方道台")) and game.journal_lines().any(func(line: String) -> bool: return line.contains("根基品质")), "the chronicle tells the 灵液 and the grade")
	check(not game.foundation_grade().is_empty(), "a grade is kept (%s)" % game.foundation_grade().get("name", ""))
	var plain := _game(["metal", "wood", "water", "fire", "earth"], 5)
	_begin(plain)
	plain.founding_auto()
	check(plain.founding.is_empty() and (int(plain.player.realm) == 1 or int(plain.player.lessons) == 1), "five roots play it out by the plain way, laid or failed")

func _grades() -> void:
	var lines: Array = []
	for liquid: int in [100, 124, 125, 149, 150, 240]:
		var game := _game()
		_begin(game)
		_finish(game, liquid)
		lines.append(game.foundation_grade().get("name", ""))
	check(lines == ["下品", "下品", "中品", "中品", "上品", "上品"], "the 灵液 past the goal grades the foundation, 无瑕 never by 灵液 alone (%s)" % str(lines))
	var lifted := _game()
	lifted.player.boons = {"epiphany": "ready"}
	_begin(lifted)
	_finish(lifted, 150)
	check(lifted.foundation_grade().get("name", "") == "无瑕", "fortune lifts a 上品 to 无瑕")

func _short() -> void:
	var game := _game()
	_begin(game)
	var xp := int(game.founding.xp)
	_finish(game, 99)
	check(int(game.player.realm) == 0 and game.injured() and int(game.player.lessons) == 1 and int(game.player.xp) == xp * int(game.content.rules.breakthrough.failure.xp_percent) / 100, "a 灵液 short of the goal fails the attempt")
	check(game.journal_lines().any(func(line: String) -> bool: return line.contains("道台铺不成")), "the chronicle tells it fell short")
	var certain := _game()
	certain.player.boons = {"remnant": "ready"}
	certain.set_item_count("foundation_pill", 0)
	_begin(certain)
	check(bool(certain.founding.certain), "残魂灌顶 needs no pill and makes the attempt certain")
	_finish(certain, 20)
	check(int(certain.player.realm) == 1 and certain.foundation_grade().get("name", "") == "中品", "and lays a middling foundation however little 灵液")

func _broken() -> void:
	var game := _game()
	_begin(game)
	game.founding.essence = 2
	game.founding.orbs = ["metal"]
	game.founding_discard("metal")
	check(game.founding.is_empty() and int(game.player.realm) == 0 and int(game.player.lessons) == 1, "the 真元 worn to none fails the attempt")
	check(game.journal_lines().any(func(line: String) -> bool: return line.contains("真元耗尽")), "the chronicle tells the 真元 gave way")

func _demon() -> void:
	var game := _game()
	game.player.mind = 0
	game.fortune = {"demon": 0.0, "grade": 0.99}
	game.breakthrough(game.breakthrough_plan())
	check(game.founding.is_empty() and str(game.pending_event.get("id", "")) == "heart_demon", "a mind short of 筑基 may still meet 心魔 before the stage")
	game.choose_event("evade")
	check(not game.founding.is_empty(), "evaded, the stage opens")

func _treasure() -> void:
	var game := _game(["metal", "wood", "fire"], 11, 0)
	game.set_item_count("qiannian_shiru", 1)
	_begin(game, {"pills": 0, "treasure": "qiannian_shiru"})
	check(int(game.founding.liquid) == 20 and game.item_count("qiannian_shiru") == 0 and int(game.founding.steps) == 1, "千年石乳 stands in for the 筑基丹 and opens with 灵液")
	var copy := _reload(game)
	check(str(copy.founding.treasure) == "qiannian_shiru", "and is remembered across a save")
	var shen := _game(["metal", "wood", "fire"], 11, 0)
	shen.set_item_count("jiuqu_lingshen", 1)
	_begin(shen, {"pills": 0, "treasure": "jiuqu_lingshen"})
	check(Founding.round_draw(shen) == int(Founding.data(shen).draw) + 1, "九曲灵参 adds a qi to every round")
	var zhi := _game(["metal", "wood", "fire"], 11, 0)
	zhi.set_item_count("xiaxue_zhi", 1)
	_begin(zhi, {"pills": 0, "treasure": "xiaxue_zhi"})
	check(Founding.cap(zhi) == int(Founding.data(zhi).cap) + 2, "霞血芝 widens the 丹田")
