extends SceneTree
## 结丹 as a stage (forming.gd, docs/MCS_SYSTEMS_GAP_20261026.md A1): the attempt's odds become the 道基,
## nine rounds of qi drawn by the roots, 秘术 paid like arts, pearls condensed from the seventh round,
## their count the grade and their elements the kind; the 道基 worn to none fails the attempt. The kind
## opens later duels with more qi. A stage under way survives a save; a malformed one is refused.
const Session = preload("res://scripts/core/session.gd")
const Forming = preload("res://scripts/core/forming.gd")
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
	_pearls()
	_saved()
	_formed()
	_broken()
	_empty()
	_kinds()
	_duel()
	_treasure()
	print("FORMING: %d checks, %d failures" % [checks, failures])
	quit(0 if failures == 0 else 1)

func _game(roots: Array = ["metal", "wood", "fire"], seed_value: int = 11) -> Session:
	var game := Session.new()
	game.encounters_enabled = false
	game.new_game("结丹", seed_value, roots)
	game.player.realm = 1
	game.player.stage = 3
	game.player.xp = 30000
	game.player.mind = 200
	game.refresh_realm_stats()
	game.player.hp = game.player.max_hp
	game.player.stones = 5000
	game.travel("sect")
	game.fortune = {"demon": 0.99, "grade": 0.99}
	return game

## Starts the stage; true when it is open.
func _begin(game: Session, plan: Dictionary = {}) -> bool:
	var chosen: Dictionary = game.breakthrough_plan()
	chosen.merge(plan, true)
	game.breakthrough(chosen)
	return not game.forming.is_empty()

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
	check(game.content.error_message.is_empty() and Forming.valid_data(game.content), "the 结丹 data loads and is valid (%s)" % game.content.error_message)
	check(Forming.applies(2) and not Forming.applies(1) and not Forming.applies(3), "only the 金丹 is formed in a stage")

func _opening() -> void:
	var game := _game()
	var odds: int = int(game.breakthrough_odds(game.breakthrough_plan()).total)
	check(_begin(game), "breaking through to 金丹 opens the stage instead of a roll")
	check(int(game.player.realm) == 1 and game.battle.is_empty() and not game.player.has("attempt"), "no realm is entered yet, no duel, no attempt left waiting")
	check(int(game.forming.stability) == odds and int(game.forming.most) == odds, "the 道基 starts at the odds (%d / %d)" % [int(game.forming.stability), odds])
	check(int(game.forming.round) == 1 and game.forming.orbs.size() == int(Forming.data(game).draw), "the first round draws its qi (%d)" % game.forming.orbs.size())
	check(game.forming.orbs.all(func(element: String) -> bool: return element in game.player.roots), "qi comes by the spirit roots")
	check(Forming.cap(game) == int(Forming.data(game).cap) + int(Forming.data(game).cap_by_foundation[1]), "a 中品 foundation keeps the plain cap")
	check(not game.blocked().is_empty() and game.travel("market") != "" and str(game.player.location) == "sect", "nothing else can be done while forming")
	check(game.journal_lines().any(func(line: String) -> bool: return line.contains("开始结丹")), "the chronicle tells the stage began")
	var fine := _game()
	fine.player.foundation_grade = 3
	_begin(fine)
	check(Forming.cap(fine) == int(Forming.data(fine).cap) + 2, "a 无瑕 foundation holds more qi")

func _arts() -> void:
	var game := _game()
	_begin(game)
	check(not Forming.block(game, "pearl").is_empty(), "no pearl before the seventh round")
	check(not Forming.block(game, "da_zhoutian").is_empty() and not "da_zhoutian" in Forming.known_arts(game), "大周天 asks the 凝丹之法")
	game.world.flags["ningdan_known"] = true
	check("da_zhoutian" in Forming.known_arts(game) and "baoyuan" in Forming.known_arts(game), "the 凝丹之法 teaches 大周天 and 抱元守一")
	game.forming.orbs = ["metal", "metal", "wood", "fire"]
	game.forming.stability = int(game.forming.most) - 10
	var before := int(game.forming.stability)
	check(not game.forming_cast("tiaoxi", ["metal", "fire"]).contains("配气不符") and int(game.forming.stability) == before + 4 and game.forming.orbs == ["metal", "wood"], "调息 pays two qi for 道基 +4")
	check(not Forming.block(game, "tiaoxi").is_empty(), "调息 once a round")
	game.forming.used.erase("tiaoxi")
	game.forming.orbs = ["wood", "fire"]
	before = int(game.forming.stability)
	game.forming_cast("tiaoxi", ["wood", "fire"])
	check(int(game.forming.stability) == mini(int(game.forming.most), before + 6), "two that generate each other shore it up more (【生】)")
	game.forming.orbs = ["metal", "metal", "metal", "metal", "wood", "fire"]
	game.forming_cast("da_zhoutian")
	check(int(game.forming.boost.draw) == 1 and game.forming.orbs.is_empty() and not Forming.block(game, "da_zhoutian").is_empty(), "大周天 adds a qi to every round, once")
	game.forming.orbs = ["wood", "wood", "fire", "fire"]
	game.forming_cast("baoyuan")
	check(Forming.cap(game) == int(Forming.data(game).cap) + 3 and int(game.forming.boost.next) == 3, "抱元守一 widens the 丹田 and gathers for the next round")
	var told := game.forming_end_round()
	check(int(game.forming.round) == 2 and game.forming.drawn.size() == int(Forming.data(game).draw) + 1 + 3 and int(game.forming.boost.next) == 0, "the next round brings the boosts (%s)" % told)
	game.forming.orbs = ["metal", "metal", "metal", "metal", "metal", "metal", "metal", "metal", "metal", "metal", "metal", "metal", "metal"]
	check(game.forming_end_round().contains("先散去") and int(game.forming.round) == 2, "the round cannot end with qi over the cap")
	before = int(game.forming.stability)
	game.forming_discard("metal")
	check(int(game.forming.stability) == before - int(Forming.data(game).discard), "letting qi go costs the 道基")
	game.forming.orbs = ["metal", "metal"]
	before = int(game.forming.stability)
	game.forming_cast("nixing")
	check(game.forming.orbs.size() == 5 and int(game.forming.stability) == before - 6, "逆行经脉 draws five at once and hurts the 道基")

func _pearls() -> void:
	var game := _game()
	_begin(game)
	game.forming.round = 7
	game.forming.orbs = ["wood", "wood", "wood", "fire", "fire", "fire", "metal", "metal", "metal"]
	check(Forming.block(game, "pearl").is_empty(), "pearls may be condensed from the seventh round")
	check(game.forming_cast("pearl", ["wood", "wood", "fire"]).contains("配气不符"), "a pearl asks three of one element")
	game.forming_cast("pearl", ["wood", "wood", "wood"])
	var before := int(game.forming.stability)
	check(Forming.link_of(game, "fire") == "generate" and int(Forming.preview(game, "pearl", ["fire", "fire", "fire"]).stability) == 3, "a fire pearl after wood is shown as 生")
	game.forming.stability = int(game.forming.most) - 10
	before = int(game.forming.stability)
	game.forming_cast("pearl", ["fire", "fire", "fire"])
	check(game.forming.pearls == ["wood", "fire"] and int(game.forming.stability) == before + 3, "生 shores the 道基 up")
	before = int(game.forming.stability)
	game.forming_cast("pearl", ["metal", "metal", "metal"])
	check(Forming.link_of(game, "metal") == "same" and int(game.forming.stability) == before - 8, "金 after 火 is 克 and costs the 道基")
	game.forming.pearls = ["wood", "wood", "wood", "wood", "wood", "wood", "wood", "wood", "wood"]
	game.forming.orbs = ["wood", "wood", "wood"]
	check(not Forming.block(game, "pearl").is_empty(), "nine pearls at most")

func _saved() -> void:
	var game := _game()
	_begin(game)
	game.world.flags["ningdan_known"] = true
	game.forming.orbs = ["metal", "metal", "metal", "metal", "wood", "fire"]
	game.forming_cast("da_zhoutian")
	var copy := _reload(game)
	check(copy.forming == game.forming and not copy.blocked().is_empty(), "the stage under way survives a save")
	var data: Dictionary = JSON.parse_string(JSON.stringify(game.snapshot()))
	for broken: Callable in [
		func(d: Dictionary) -> void: d.forming.round = 99,
		func(d: Dictionary) -> void: d.forming.orbs = ["gold"],
		func(d: Dictionary) -> void: d.forming.stability = int(d.forming.most) + 1,
		func(d: Dictionary) -> void: d.forming.used = {"nothing": 1},
		func(d: Dictionary) -> void: d.player.realm = 2,
		func(d: Dictionary) -> void: d.player.core_kind = {"id": "pure", "elements": ["metal", "wood"]},
	]:
		var bad: Dictionary = data.duplicate(true)
		broken.call(bad)
		check(not Session.new().restore(bad), "a malformed stage or core kind is refused")
	var older: Dictionary = data.duplicate(true)
	older.erase("forming")
	check(Session.new().restore(older), "saves from before the stage still load")

func _formed() -> void:
	var game := _game(["fire"])
	game.world.flags["ningdan_known"] = true
	_begin(game)
	game.forming_auto()
	check(game.forming.is_empty() and str(game.battle.get("context", "")) == "tribulation" and game.player.has("core_kind"), "played out, the core waits on its 天劫 (%s)" % str(game.player.get("core_kind", {})))
	var pearls := 0
	for line: String in game.journal_lines():
		if line.contains("颗灵珠聚为一体"):
			pearls = int(line.get_slice("毕，", 1).to_int())
	check(pearls >= 5 and str(game.player.core_kind.id) == "pure" and game.player.core_kind.elements == ["fire"], "a single fire root condenses a 纯火 core (%d pearls)" % pearls)
	_weather(game)
	check(int(game.player.realm) == 2 and int(game.player.core_grade) == clampi(pearls - 1, 0, 8), "the grade is the pearls' count (%d → %s)" % [pearls, game.core_grade().get("name", "")])
	var copy := _reload(game)
	check(copy.player.core_kind == game.player.core_kind, "the core's kind survives a save")
	var plain := _game(["metal", "wood", "water", "fire", "earth"], 5)
	_begin(plain)
	plain.forming_auto()
	_weather(plain)
	check(int(plain.player.realm) == 2 and plain.player.has("core_kind"), "even five roots form some core (%s, %s)" % [plain.core_grade().get("name", ""), str(plain.player.get("core_kind", {}))])

func _broken() -> void:
	var game := _game()
	_begin(game)
	var xp := int(game.forming.xp)
	game.forming.stability = 2
	game.forming.orbs = ["metal"]
	game.forming_discard("metal")
	check(game.forming.is_empty() and int(game.player.realm) == 1 and game.injured() and int(game.player.lessons) == 1, "the 道基 worn to none fails the attempt")
	check(int(game.player.xp) == xp * int(game.content.rules.breakthrough.failure.xp_percent) / 100 and not game.player.has("core_kind"), "the cultivation falls back a little; no core is kept")
	check(game.journal_lines().any(func(line: String) -> bool: return line.contains("道基崩散")), "the chronicle tells the 道基 gave way")
	var certain := _game()
	_begin(certain)
	certain.forming.certain = true
	certain.forming.stability = 2
	certain.forming.orbs = ["metal", "metal"]
	certain.forming_discard("metal")
	certain.forming_discard("metal")
	check(not certain.forming.is_empty() and int(certain.forming.stability) == 1, "a certain attempt (残魂灌顶) cannot give way")

func _empty() -> void:
	var game := _game()
	_begin(game)
	var guard := 0
	while not game.forming.is_empty() and guard < 20:
		guard += 1
		game.forming.stability = int(game.forming.most)
		game.forming_end_round(true)
	check(int(game.player.realm) == 1 and game.battle.is_empty() and game.journal_lines().any(func(line: String) -> bool: return line.contains("一颗灵珠也未凝成")), "nine rounds without a pearl form nothing")

func _kinds() -> void:
	var game := _game()
	check(Forming.kind_of(game, ["fire", "fire", "fire", "fire", "fire", "wood"]) == {"id": "pure", "elements": ["fire"]}, "five of one element: 纯")
	check(Forming.kind_of(game, ["fire", "fire", "fire", "fire", "wood", "wood", "wood", "wood", "metal"]) == {"id": "dual", "elements": ["fire", "wood"]}, "four and four: 双")
	check(Forming.kind_of(game, ["fire", "wood", "metal"]).id == "mixed", "the rest: 混元")
	check(Forming.kind_name(game, {"id": "pure", "elements": ["fire"]}) == "纯火金丹", "the kind is named")

func _duel() -> void:
	var game := Session.new()
	game.encounters_enabled = false
	game.new_game("斗法", 3, ["metal", "fire"])
	game.player.realm = 2
	game.refresh_realm_stats()
	game.player.hp = game.player.max_hp
	game.player["core_kind"] = {"id": "pure", "elements": ["fire"]}
	check(Forming.opening_orbs(game) == ["fire", "fire"] and Forming.weight(game, "fire") == 1 and Forming.weight(game, "metal") == 0, "a 纯火 core opens with two fire and draws fire more")
	check(int(game.Combat.player_weights(game).fire) == int(game.Combat.player_weights(game).metal) + 1, "the weight shows in the draw")
	game.Combat.begin_battle(game, "disciple")
	var held: Array = game.battle.get("orbs", []) + game.battle.get("core_orbs", [])
	check(held.count("fire") >= 2, "the duel opens with the core's qi")
	game.player["core_kind"] = {"id": "dual", "elements": ["fire", "metal"]}
	check(Forming.opening_orbs(game) == ["fire", "metal"], "a 双 core opens with one of each")
	game.player.realm = 1
	check(Forming.opening_orbs(game).is_empty(), "nothing before the 金丹")

func _treasure() -> void:
	var game := _game(["metal", "wood", "water"])
	game.set_item_count("dixin_huolian", 1)
	_begin(game, {"treasure": "dixin_huolian"})
	check(game.forming.orbs.count("fire") == 3 and game.item_count("dixin_huolian") == 0, "地心火莲 opens the stage with three fire qi")
	var copy := _reload(game)
	check(str(copy.forming.treasure) == "dixin_huolian", "and is remembered across a save")
	var sui := _game()
	sui.set_item_count("xiaguang_lingsui", 1)
	_begin(sui, {"treasure": "xiaguang_lingsui"})
	check(Forming.round_draw(sui) == int(Forming.data(sui).draw) + 1, "霞光灵髓 adds a qi to every round")
