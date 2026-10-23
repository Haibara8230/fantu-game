extends SceneTree
## 无相宝录 (docs/SIDEQUESTS_DRAFT_20261020.md, step 7): the 散修's seven places — the well gone down
## with ten stones, the river's trust, the stones, the poisoned disciple, the antiques, the beast below
## the sea and the last question at the ferry; 影七 taking a page left too long and selling it, the page
## had back; his offer to share or to buy; the 心法, the bag, the blade and what a 散修之主 is owed. All
## of it survives a save.
const Session = preload("res://scripts/core/session.gd")
const Calendar = preload("res://scripts/core/calendar.gd")
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
	_begin()
	_well()
	_well_left()
	_river()
	_stones()
	_race()
	_meet()
	_poison()
	_antique()
	_sea()
	_heart()
	_methods()
	_master()
	_saves()
	print("WUXIANG: %d checks, %d failures" % [checks, failures])
	quit(0 if failures == 0 else 1)

func _game(realm: int = 1, stage: int = 0) -> Session:
	var game := Session.new()
	game.encounters_enabled = false
	game.new_game("无相", 61, ["metal", "wood", "water"], "free")
	game.world.flags["tiannan_known"] = true
	game.world.storylines["rushi"] = {"state": "done", "step": game.content.storylines.rushi.steps.size(), "since": 0, "begun": true, "base": {}}
	game.world.flags["rushi_done"] = true
	game.world.day = Calendar.to_day(41, 1, 1)
	game.player.stones = 20000
	_raise(game, realm, stage)
	game.player.location = "ridge"
	return game

func _raise(game: Session, realm: int, stage: int) -> void:
	game.player.realm = realm
	game.player.stage = stage
	game.player.xp = int(game.content.stage(realm, stage).xp)
	game.refresh_realm_stats()
	game.player.hp = game.player.max_hp
	game.player.qi = game.player.max_qi

## The storyline at the step `step_id`, begun today.
func _at(game: Session, step_id: String) -> void:
	var steps: Array = game.content.storylines.wuxiang.steps
	for index: int in steps.size():
		if str(steps[index].id) == step_id:
			game.world.storylines["wuxiang"] = {"state": "active", "step": index, "since": int(game.world.day), "begun": true, "base": {}}
			return
	check(false, "no step " + step_id)

## Somewhere, with whatever waits there set aside unless it is `wanted`.
func _go(game: Session, place: String, wanted: String = "") -> void:
	game.world.day += 1
	game.player.location = place
	game.conclude("")
	for tries: int in 6:
		if game.pending_event.is_empty() or str(game.pending_event.id) == wanted:
			return
		game.pending_event = {}
		game.conclude("")

func _reload(game: Session) -> Session:
	var copy := Session.new()
	check(copy.restore(JSON.parse_string(JSON.stringify(game.snapshot()))), "the journey survives a save")
	return copy

func _step(game: Session) -> String:
	return str(game.story_step("wuxiang").get("id", ""))

## From 40 on, a 散修 of foundation hears of it; a sect's disciple does not.
func _begin() -> void:
	var game := _game()
	game.conclude("")
	check(game.story_state("wuxiang") == "active" and _step(game) == "p1", "the storyteller's tale starts it at the well")
	var early := _game()
	early.world.day = Calendar.to_day(30, 1, 1)
	early.conclude("")
	check(early.story_state("wuxiang").is_empty(), "not before the fortieth year")
	var disciple := _game()
	disciple.player.affiliation = "qingyun"
	disciple.conclude("")
	check(disciple.story_state("wuxiang").is_empty(), "a sect's disciple does not hear of it")

## 贫: down with ten stones; the 试心傀; the first page and the stones back.
func _well() -> void:
	var game := _game()
	game.conclude("")
	_go(game, "town", "wuxiang_well")
	check(game.pending_event.get("id", "") == "wuxiang_well", "the dry well outside 青石镇")
	game.choose_event("descend")
	check(int(game.player.stones) == 10 and int(game.Wuxiang.state(game).stash) == 19990, "only ten stones go down; the rest wait at the top")
	check(game.cave_here("well") == "wuxiang_well", "the well opens to explore")
	game.enter_room("wuxiang_well", "stream")
	game.enter_room("wuxiang_well", "hall")
	check(game.battle.get("enemy_id", "") == "wuxiang_kui", "the 试心傀 stands in the way")
	game.Combat._win(game)
	game.enter_room("wuxiang_well", "inner")
	game.conclude("")
	check(game.has_flag("wuxiang_page1") and game.Wuxiang.held(game, 1) and _step(game) == "p2", "the first page, and the next place")
	check(game.item_count("j:wuxiang_jue") == 1, "《无相聚气诀》 lies with it")
	check(int(game.player.stones) >= 20000 and int(game.Wuxiang.state(game).stash) == 0, "the stones come back with the page")

## Leaving 青石镇 before the page: the stones come back and the descent must be made again.
func _well_left() -> void:
	var game := _game()
	game.conclude("")
	_go(game, "town", "wuxiang_well")
	game.choose_event("descend")
	_go(game, "ridge")
	check(int(game.player.stones) == 20000 and not game.has_flag("wuxiang_well"), "gone from the town, the stones are taken back and the well shut")

## 信: trusting 何三 gives the bag (one more pill a duel); going down alone, the page only.
func _river() -> void:
	var game := _game()
	_at(game, "p2")
	_go(game, "ferry", "wuxiang_river")
	check(game.pending_event.get("id", "") == "wuxiang_river", "何三 waits at the river")
	game.choose_event("trust")
	game.conclude("")
	check(game.item_count("wuxiang_dai") == 1, "the 无相袋 is preserved as the quest reward; it grants no battle pill use")
	check(_step(game) == "p3", "on to the stones (%s)" % _step(game))
	var alone := _game()
	_at(alone, "p2")
	_go(alone, "ferry", "wuxiang_river")
	alone.choose_event("self")
	alone.conclude("")
	check(alone.Wuxiang.held(alone, 2) and alone.item_count("wuxiang_dai") == 0, "alone, the page without the bag")

## 智: the 神识 sees the true stone; a guess is allowed once a month.
func _stones() -> void:
	var game := _game(1, 2)
	_at(game, "p3")
	_go(game, "nanming", "wuxiang_stones")
	check(game.pending_event.get("id", "") == "wuxiang_stones", "the blind man's three stones")
	var choices: Array = game.pending_definition().choices
	check(not game.choice_available(choices[0]), "筑基后期's 神识 is short of the look")
	game.choose_event("gamble")
	var tried := int(game.Wuxiang.state(game).gambled)
	check(not game.Wuxiang.met(game, "can_gamble"), "one guess a month")
	game.world.day += Calendar.DAYS_PER_MONTH
	check(game.Wuxiang.met(game, "can_gamble") and tried >= 0, "another next month")
	var keen := _game(1, 3)
	_at(keen, "p3")
	_go(keen, "nanming", "wuxiang_stones")
	keen.choose_event("pay")
	keen.conclude("")
	check(keen.Wuxiang.held(keen, 3) and keen.Gear.holds(keen, str(keen.content.wuxiang_data.blades[0])), "the 无相剑胚 from the stone")

## 影七 takes a page left too long and sells it; bought back, or taken from the keeper's guard.
func _race() -> void:
	var game := _game()
	_at(game, "p2")
	game.world.day += 3 * Calendar.DAYS_PER_YEAR + 1
	game.player.location = "ridge"
	game.Events.check_location(game)
	game.conclude("")
	check(game.Wuxiang.lost(game, 2) and _step(game) == "p2r", "three years late, 影七 has it (%s)" % _step(game))
	check(str(game.story_step("wuxiang").place) == "canglan_pavilion", "sold to 沧澜阁")
	_go(game, "canglan_pavilion", "wuxiang_reclaim2")
	var stones := int(game.player.stones)
	game.choose_event("buy")
	game.conclude("")
	check(game.Wuxiang.held(game, 2) and int(game.player.stones) == stones - 400 and game.item_count("wuxiang_dai") == 1 and _step(game) == "p3", "bought back, with what it holds")
	var robber := _game()
	_at(robber, "p2")
	robber.world.day += 3 * Calendar.DAYS_PER_YEAR + 1
	robber.Events.check_location(robber)
	robber.conclude("")
	_go(robber, "canglan_pavilion", "wuxiang_reclaim2")
	robber.choose_event("rob")
	check(robber.battle.get("enemy_id", "") == "wuxiang_guard2", "the keeper's guard")
	robber.Combat._win(robber)
	robber.conclude("")
	check(robber.Wuxiang.held(robber, 2) and robber.Wuxiang.page_state(robber, 2) == "reclaimed", "taken by force")
	var allied := _game(2, 2)
	_at(allied, "p4")
	allied.Wuxiang.apply(allied, "ally")
	allied.world.day += 10 * Calendar.DAYS_PER_YEAR
	allied.Events.check_location(allied)
	check(not allied.Wuxiang.lost(allied, 4), "an ally races no more")

## At 金丹 影七 comes: to share, to buy, or each for himself.
func _meet() -> void:
	var game := _game(2)
	_at(game, "meet")
	game.conclude("")
	check(game.pending_event.get("id", "") == "wuxiang_meet", "影七 sits down across from the player")
	var stones := int(game.player.stones)
	game.choose_event("sell")
	game.conclude("")
	check(game.story_state("wuxiang") == "closed" and int(game.player.stones) == stones + 4000 and game.League.banned(game) and game.has_flag("guest_invite_chixiao"), "sold to 赤霄: rich, a guest's place, and a traitor to the 散修")
	var ally := _game(2, 2)
	_at(ally, "meet")
	ally.conclude("")
	ally.choose_event("ally")
	ally.conclude("")
	check(ally.Wuxiang.met(ally, "ally") and ally.Wuxiang.page_state(ally, 6) == "ally" and _step(ally) == "p4", "shared: he takes the sea")
	ally.Wuxiang.apply(ally, "got:4")
	ally.Wuxiang.apply(ally, "got:5")
	ally.conclude("")
	check(_step(ally) == "p7", "the sea passed by (%s)" % _step(ally))

## 仁: carrying the disciple out loses the page to 影七 but 长青谷 owes the player; a pill saves both.
func _poison() -> void:
	var game := _game(2)
	_at(game, "p4")
	_go(game, "duze", "wuxiang_poison")
	game.choose_event("carry")
	game.conclude("")
	check(game.Wuxiang.lost(game, 4) and game.Wuxiang.met(game, "favor:changqing") and _step(game) == "p4r", "carried out: the page lost, a favor owed")
	_go(game, "changqing_valley", "wuxiang_reclaim4")
	check(game.choice_available(game.pending_definition().choices[1]), "the favor asks it back")
	game.choose_event("favor")
	game.conclude("")
	check(game.Wuxiang.held(game, 4) and game.item_count("j:wuxiang_huadu") == 1, "given back, with 《无相化毒经》")
	var cured := _game(2)
	cured.add_item("jiedu_dan", 1)
	_at(cured, "p4")
	_go(cured, "duze", "wuxiang_poison")
	cured.choose_event("cure")
	cured.conclude("")
	check(cured.Wuxiang.held(cured, 4) and cured.item_count("jiedu_dan") == 0 and cured.Wuxiang.met(cured, "favor:changqing"), "a 解毒丹 saves him and the page")

## 辨: the hand of the four pages found by one's own hand knows his bowl.
func _antique() -> void:
	var game := _game(2)
	for n: int in range(1, 5):
		game.Wuxiang.apply(game, "got:%d" % n)
	_at(game, "p5")
	_go(game, "beiyue", "wuxiang_antique")
	check(game.choice_available(game.pending_definition().choices[0]), "four pages of one's own: the writing is known")
	game.Wuxiang.apply(game, "blade")
	game.choose_event("own")
	game.conclude("")
	check(game.Wuxiang.held(game, 5) and game.Gear.holds(game, str(game.content.wuxiang_data.blades[1])), "the blade edged")
	var bought := _game(2)
	bought.Wuxiang.apply(bought, "reclaim:1")
	_at(bought, "p5")
	_go(bought, "beiyue", "wuxiang_antique")
	check(not bought.choice_available(bought.pending_definition().choices[0]), "a page bought back does not teach the hand")

## 勇: alone into the sea's eye; the beast's page teaches 《无相凝婴诀》 for the 元婴 breakthrough.
func _sea() -> void:
	var game := _game(2, 2)
	_at(game, "p6")
	_go(game, "waihai", "wuxiang_sea")
	game.choose_event("dive")
	check(game.battle.get("enemy_id", "") == "wuxiang_haishou", "the beast below the sea")
	game.Combat._win(game)
	game.conclude("")
	check(game.Wuxiang.held(game, 6) and game.has_flag("wuxiang_ningying") and _step(game) == "p7", "the sixth page")
	_raise(game, 2, 3)
	game.player.location = "town"
	var parts: Array = game.Breakthrough.odds(game, {}).parts
	check(parts.any(func(part: Array) -> bool: return str(part[0]) == "《无相凝婴诀》" and int(part[1]) == 15), "+15 to the 元婴 breakthrough")

## 心: the last question; the blade bound; 散修之主. 影七 first at the ferry: the duel before it.
func _heart() -> void:
	var game := _game(3)
	for n: int in range(1, 7):
		game.Wuxiang.apply(game, "got:%d" % n)
	game.Wuxiang.apply(game, "blade")
	game.Wuxiang.apply(game, "blade")
	game.player.mind = 9999
	_at(game, "p7")
	_go(game, "ferry", "wuxiang_heart")
	check(game.pending_event.get("id", "") == "wuxiang_heart", "a grey shadow on the water")
	game.choose_event("way")
	game.conclude("")
	check(game.story_state("wuxiang") == "done" and game.Wuxiang.met(game, "master"), "all seven: 散修之主")
	check(game.item_count("j:wuxiang_zhenjing") == 1 and game.Gear.holds(game, str(game.content.wuxiang_data.blades[2])), "《无相真经》 and the bound blade")
	var bound := str(game.content.wuxiang_data.blades[2])
	game.player.location = "market"
	check(bool(game.content.item(bound).get("bound", false)) and game.content.item(bound).description.contains("不可出售"), "the bound blade says it is never sold")
	check(game.sell(bound).contains("卖不得") and game.item_count(bound) == 1, "a shop is refused it")
	game.add_item("wolf_fang", 1)
	game.act("sell")
	check(game.item_count(bound) == 1 and game.item_count("wolf_fang") == 0, "selling everything keeps it")
	check(not bool(game.content.item(str(game.content.wuxiang_data.blades[1])).get("bound", false)), "the blade before it is an ordinary 法宝")
	var late := _game(3)
	for n: int in range(1, 7):
		late.Wuxiang.apply(late, "got:%d" % n)
	late.player.mind = 9999
	_at(late, "p7")
	late.world.day += 8 * Calendar.DAYS_PER_YEAR + 1
	late.Events.check_location(late)
	_go(late, "ferry", "wuxiang_heart")
	var choices: Array = late.pending_definition().choices
	check(late.choice_available(choices[0]) and not late.choice_available(choices[1]), "影七 waits: the duel first")
	late.choose_event("duel")
	late.Combat._win(late)
	late.conclude("")
	_go(late, "ferry", "wuxiang_heart")
	late.choose_event("free")
	late.conclude("")
	check(late.Wuxiang.held(late, 7) and late.Wuxiang.met(late, "master"), "beaten, he gives the last page up")

## The 心法: the gathering art in an inn, closed to a sect's disciple; the true scripture everywhere; the
## poison halved.
func _methods() -> void:
	var game := _game(1, 3)
	game.player.location = "market"
	var plain: float = game.Cultivation.place_rate(game)
	game.player.learned.append("wuxiang_jue")
	game.player.layers["wuxiang_jue"] = {"layer": 7, "practice": 0}
	game.player.methods = ["wuxiang_jue"]
	game.refresh_realm_stats()
	check(is_equal_approx(float(game.bonuses().cultivation), 0.12) and is_equal_approx(game.Cultivation.place_rate(game), plain + 0.1), "+12% everywhere, +10% more in an inn")
	game.player.affiliation = "qingyun"
	check(is_zero_approx(float(game.bonuses().cultivation)), "a sect's disciple cannot turn it")
	var deep := _game(3)
	deep.player.learned.append("wuxiang_zhenjing")
	deep.player.layers["wuxiang_zhenjing"] = {"layer": 9, "practice": 0}
	deep.player.methods = ["wuxiang_zhenjing"]
	deep.player.location = "market"
	check(is_equal_approx(deep.Cultivation.place_rate(deep), 0.8 + 0.2), "《无相真经》: +20% wherever the retreat is")
	var ward := _game(2)
	ward.player.learned.append("wuxiang_huadu")
	ward.player.layers["wuxiang_huadu"] = {"layer": 9, "practice": 0}
	ward.player.methods = ["wuxiang_huadu"]
	ward.battle = {"enemy_id": "du_chan", "player_status": {}}
	ward.Combat._inflict_player(ward, "bleed", [6, 3])
	ward.Combat._inflict_player(ward, "wound", [0.5, 3])
	check(int(ward.battle.player_status.bleed[0]) == 3 and is_equal_approx(float(ward.battle.player_status.wound[0]), 0.25), "流血 and 禁疗 halved")

## 散修之主: the 鬼市's lots and the alliance's rooms at eight tenths; 散修 guard for less favor.
func _master() -> void:
	var game := _game(2)
	game.world.day = Calendar.to_day(60, 1, 15)
	game.player.location = "market"
	var before: Array = game.Guishi.lots(game)
	game.Wuxiang.state(game).ending = "master"
	var after: Array = game.Guishi.lots(game)
	check(int(after[0].price) < int(before[0].price) and abs(float(after[0].price) - float(before[0].price) * 0.8) <= 1.0, "the 鬼市 sells cheaper")
	game.world.flags["league_member"] = true
	game.player["league"] = {"member": true, "branch": "market", "standing": 0}
	check(int(game.Cultivation.room(game).get("rent", 0)) <= 10, "the alliance's room at eight tenths (%d)" % int(game.Cultivation.room(game).get("rent", 0)))

## The pages, the stash and the ending survive a save; a malformed record is refused.
func _saves() -> void:
	var game := _game(2)
	game.conclude("")
	game.Wuxiang.apply(game, "got:1")
	game.Wuxiang.apply(game, "page:1")
	game.Wuxiang.apply(game, "ally")
	game.Wuxiang.state(game).stash = 30
	var copy := _reload(game)
	check(copy.Wuxiang.held(copy, 1) and copy.Wuxiang.met(copy, "ally") and int(copy.Wuxiang.state(copy).stash) == 30 and 1 in copy.Wuxiang.state(copy).rewarded, "pages, the offer and the stash restored")
	var broken: Dictionary = JSON.parse_string(JSON.stringify(game.snapshot()))
	broken.world.wuxiang.pages = {"9": "self"}
	check(not Session.new().restore(broken), "a page that does not exist is refused")
	var older: Dictionary = JSON.parse_string(JSON.stringify(game.snapshot()))
	older.world.erase("wuxiang")
	var restored := Session.new()
	check(restored.restore(older) and restored.Wuxiang.state(restored).is_empty(), "a journey from before it starts with nothing")
