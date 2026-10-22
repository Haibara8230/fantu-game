extends SceneTree
## 鬼市夜灯与残玉三更；百花谷「一炉冷香」、飞鱼帮「洗手」 (docs/SIDEQUESTS_DRAFT_20261020.md, step 6): the
## fifteenth night's market (sealed lots and what the 神识 sees, the fence, contracts, hiring, the black
## auction, being followed out) and 灯婆's war; the 残玉 from 云溪's autumn sale to the 藏锋洞; the
## switched incense; the debt at the ferry. All of it survives a save.
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
	_night()
	_lots()
	_fence_and_jobs()
	_followed()
	_war()
	_canyu()
	_canyu_endings()
	_lengxiang()
	_xishou()
	_saves()
	print("GUISHI: %d checks, %d failures" % [checks, failures])
	quit(0 if failures == 0 else 1)

func _game(realm: int = 1, stage: int = 2) -> Session:
	var game := Session.new()
	game.encounters_enabled = false
	game.new_game("夜灯", 59, ["metal", "wood", "water"], "free")
	game.world.flags["tiannan_known"] = true
	game.world.storylines["rushi"] = {"state": "done", "step": game.content.storylines.rushi.steps.size(), "since": 0, "begun": true, "base": {}}
	game.world.flags["rushi_done"] = true
	game.player.stones = 20000
	game.player.realm = realm
	game.player.stage = stage
	game.player.xp = int(game.content.stage(realm, stage).xp)
	game.refresh_realm_stats()
	game.player.hp = game.player.max_hp
	game.player.qi = game.player.max_qi
	game.player.location = "ridge"
	return game

## The fifteenth of a month in `year`.
func _fifteenth(game: Session, year: int, month: int = 1) -> void:
	game.world.day = Calendar.to_day(year, month, 15)

## Somewhere, with whatever waits there set aside unless it is `wanted`.
func _go(game: Session, place: String, wanted: String = "") -> void:
	# A day on the road: a storyline asks its choice once a day.
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

## Open the fifteenth night only, to foundation and up.
func _night() -> void:
	var game := _game()
	game.world.day = Calendar.to_day(20, 1, 14)
	game.player.location = "market"
	check(game.Guishi.block(game).contains("十五"), "the pier is empty on other nights")
	game.world.day = Calendar.to_day(20, 1, 15)
	check(game.Guishi.block(game).is_empty() and game.available_here("guishi"), "on the fifteenth the lamps are lit")
	var young := _game(0, 3)
	young.world.day = Calendar.to_day(20, 1, 15)
	young.player.location = "market"
	check(not young.Guishi.block(young).is_empty(), "a 炼气 is not dealt with")

## Sealed lots: fixed by the night, seen by the 神识; bought and opened.
func _lots() -> void:
	var game := _game()
	_fifteenth(game, 20)
	game.player.location = "market"
	check(game.Guishi.lots(game) == game.Guishi.lots(game) and game.Guishi.lots(game).size() == 3, "three lots, the same however often looked at")
	var dim := game.Guishi.insight(game)
	game.player.stage = 3
	game.refresh_realm_stats()
	check(game.Guishi.insight(game) > dim, "a keener 神识 sees more of them")
	var lot: Dictionary = game.Guishi.lots(game)[0]
	var inside: Dictionary = game.Guishi.contents(game, 0)
	var stones := int(game.player.stones)
	game.guishi_gamble(0)
	check(int(game.player.stones) == stones - int(lot.price) + int(inside.stones) and 0 in game.Guishi.state(game).bought, "bought and opened: paid, and what was inside kept")
	check(not game.Guishi.gamble_block(game, 0).is_empty(), "a lot opens once")
	var right := 0
	var probe := _game(1, 3)
	for month: int in 12:
		_fifteenth(probe, 30 + month)
		for shown: Dictionary in probe.Guishi.lots(probe):
			if int(shown.hint) == int(shown.tier):
				right += 1
	check(right > 12 and right < 36, "the hints are right more often than not, but not always (%d of 36)" % right)

## Stolen things only the market takes; a contract; a grudge hired out; the black auction.
func _fence_and_jobs() -> void:
	var game := _game()
	_fifteenth(game, 20, 3)
	game.player.location = "market"
	game.add_item("yiwu_jian", 1)
	check(game.sell("yiwu_jian").contains("鬼市") and game.item_count("yiwu_jian") == 1, "a shop will not take a stolen sword")
	var stones := int(game.player.stones)
	game.guishi_fence("yiwu_jian")
	check(game.item_count("yiwu_jian") == 0 and int(game.player.stones) == stones + 120, "the market takes it at six tenths")
	game.world.grudges = [{"id": "g1", "name": "仇家", "enemy": "rogue", "cause": "exposed", "since": 0, "region": "qingyun"}]
	game.guishi_hire("g1")
	check(game.world.grudges.is_empty(), "a grudge hired out")
	var refused: String = game.Guishi.black_block(game)
	game.guishi_black()
	check(not game.auction.is_empty() and str(game.auction.id) == "guishi_black", "the third month's fifteenth: a black auction (%s)" % refused)
	game.auction = {}
	game.guishi_contract()
	check(game.battle.get("context", "") == "guishi", "a contract is a duel")
	stones = int(game.player.stones)
	game.Combat._win(game)
	check(int(game.player.stones) > stones and game.has_flag("xiongren_guishi"), "done: paid, and the 凶人榜 marks it")
	check(not game.Guishi.contract_block(game).is_empty(), "one contract a night")

## Spend too freely and someone follows the player out.
func _followed() -> void:
	var game := _game()
	_fifteenth(game, 20)
	game.player.location = "market"
	for index: int in 3:
		game.guishi_gamble(index)
	game.Guishi._spend(game, 2000, "")
	check(bool(game.Guishi.state(game).tail), "someone took note of the player")
	game.world.day += 1
	game.player.location = "ferry"
	game.Guishi.check(game)
	check(game.pending_event.get("id", "") == "guishi_tail", "and waits for them out of the city")
	game.choose_event("pay")
	check(game.pending_event.get("id", "") != "guishi_tail" and not bool(game.Guishi.state(game).get("tail", false)), "paid off")

## 灯婆's war: three nights' visits, then a side.
func _war() -> void:
	for side: String in ["dengpo", "wuzong"]:
		var game := _game(2, 0)
		for month: int in 3:
			_fifteenth(game, 80, month + 1)
			game.player.location = "market"
			game.Guishi.visit(game)
		_fifteenth(game, 80, 4)
		game.world.day -= 1
		_go(game, "market", "guishi_war")
		check(game.story_state("guishi_war") == "active" and game.pending_event.get("id", "") == "guishi_war", "%s: a regular is drawn into 灯婆's war" % side)
		game.choose_event(side)
		game.Combat._win(game)
		if side == "dengpo":
			check(game.Guishi.second(game) and game.has_flag("dengpo_lu_ledger") and game.has_flag("xiongren_guishi"), "held: the player is the market's 二灯, and hears of 陆家's black ledger")
			check(game.Guishi.insight(game) >= 3 and game.Guishi.fence_price(game, "yiwu_jian") == 160, "the 二灯 sees more and sells higher")
		else:
			check(game.has_flag("guishi_gone") and not game.Guishi.block(game).is_empty(), "the market is gone")
			check(game.has_flag("guishi_hated"), "and the wanderers remember who opened the gate")

## The 残玉: bought at the autumn sale, waylaid, the auction house, the reading, the race, the 藏锋洞.
func _canyu() -> void:
	var game := _game(1, 3)
	game.world.day = Calendar.to_day(40, 10, 2)
	game.player.location = "market"
	game.Auctions.open(game, "yunxi_special")
	check(game.auction.lots.any(func(lot: Dictionary) -> bool: return lot.item == "canyu"), "from 40 on, a nameless 残玉 closes the autumn sale")
	game.auction = {}
	game.add_item("canyu", 1)
	game.conclude("")
	check(game.story_state("canyu") == "active", "held, the story begins")
	_go(game, "ferry", "canyu_ambush")
	check(game.pending_event.get("id", "") == "canyu_ambush", "waylaid outside the ferry")
	game.choose_event("fight")
	game.Combat._win(game)
	check(game.story_at("canyu", "house"), "a token of the auction house on the leader")
	_go(game, "market", "canyu_house")
	game.choose_event("night")
	check(game.has_flag("canyu_ledger") and game.story_at("canyu", "read"), "the ledger from the counting room")
	_go(game, "beiyue", "canyu_read")
	check(game.pending_event.get("id", "") == "canyu_read", "the 阵师会馆 looks at it (%s)" % game.pending_event.get("id", ""))
	game.choose_event("pay")
	check(game.story_at("canyu", "race"), "the jade is a map to 赤枫岭")
	_go(game, "chifeng", "canyu_race")
	check(game.choice_available(game.pending_definition().choices[2]), "the ledger lets 陆家 deal with 鬼手")
	var stones := int(game.player.stones)
	game.choose_event("lu")
	game.conclude("")
	check(game.has_flag("guishou_slain") and game.has_flag("canyu_open") and int(game.player.stones) == stones + 1500, "鬼手 is cut down, the stone door found, the robbed paid back")
	check(game.cave_here("cangfeng") == "cangfeng", "the 藏锋洞 opens (%s at %s)" % [game.cave_here("cangfeng"), game.player.location])
	for room_id: String in ["corridor", "hall"]:
		game.enter_room("cangfeng", room_id)
	game.Combat._win(game)
	game.player.mind = 999
	game.enter_room("cangfeng", "inner")
	check(game.pending_event.get("id", "") == "canyu_shi", "石无锋 opens his eyes")
	game.choose_event("truth")
	check(game.has_flag("canyu_free") and game.item_count("j:cangfeng_jue") == 1 and game.story_state("canyu") == "done", "the truth frees him: his sword art and his cave")
	game.player.location = "chifeng"
	check(game.available_here("cultivate"), "the 藏锋洞府 takes a retreat")

## Handing the jade over ends it; the appraiser sells the news; the relics and their owners.
func _canyu_endings() -> void:
	var given := _game()
	given.add_item("canyu", 1)
	given.player.location = "market"
	given.conclude("")
	_go(given, "ferry", "canyu_ambush")
	given.choose_event("give")
	given.conclude("")
	check(given.story_state("canyu") == "closed" and given.item_count("canyu") == 0, "handed over, it is none of the player's business")
	var leaked := _game()
	leaked.add_item("canyu", 1)
	leaked.world.storylines["canyu"] = {"state": "active", "step": 2, "since": 0, "begun": true, "base": {}}
	_fifteenth(leaked, 50)
	leaked.world.day -= 1
	_go(leaked, "market", "canyu_read_ghost")
	leaked.choose_event("ask")
	check(leaked.has_flag("canyu_leaked") and leaked.has_flag("canyu_read"), "the 鬼市's appraiser reads it, and sells the news")
	_go(leaked, "chifeng", "canyu_race")
	leaked.choose_event("ambush_crowd")
	check(leaked.battle.get("enemy_id", "") == "guishou_pass" and not leaked.battle.get("pack", []).is_empty(), "more come to the ambush")
	var owner := _game()
	owner.add_item("yiwu_pei", 1)
	_go(owner, "canglan", "kuzhu_pei")
	check(owner.pending_event.get("id", "") == "kuzhu_pei", "the owner's widow knows the jade pendant")
	owner.choose_event("return")
	check(owner.item_count("yiwu_pei") == 0, "given back")

## The switched incense: traced to 萧家, or the girl pleaded for, or the valley thrown out.
func _lengxiang() -> void:
	var game := _game(1, 0)
	_go(game, "baihua", "lengxiang_choice")
	check(game.story_state("lengxiang") == "active", "at 百花谷, word of the dead heir")
	check(game.pending_event.get("id", "") == "lengxiang_choice", "梅三娘 asks what the player will do")
	game.choose_event("trace")
	_go(game, "market", "lengxiang_xiao")
	check(game.pending_event.get("id", "") == "lengxiang_xiao", "萧家丹坊's books (%s, %s)" % [game.pending_event.get("id", ""), game.story_state("lengxiang")])
	game.choose_event("read")
	check(game.has_flag("lengxiang_solved") and game.item_count("recipe_jiedu") == 1 and game.story_state("lengxiang") == "done", "萧家's 断魂草 found: the cold incense recipe")
	game.use_item("recipe_jiedu")
	check(game.Alchemy.knows(game, "jiedu"), "and the 解毒丹 can be made")
	var thrown := _game(1, 0)
	_go(thrown, "baihua", "lengxiang_choice")
	thrown.choose_event("expose")
	thrown.conclude("")
	check(thrown.has_flag("sect_closed_baihua") and thrown.story_state("lengxiang") == "closed", "exposed, 百花谷 is driven out")

## The debt at the ferry: settled, sided with, or fought off.
func _xishou() -> void:
	var stranger := _game()
	_go(stranger, "ferry")
	check(stranger.story_state("xishou").is_empty(), "a passer-by at the ferry is not drawn in (%s %s)" % [stranger.story_state("xishou"), stranger.world.people.get("lao_bie", {})])
	var game := _talked(_game())
	_go(game, "ferry", "xishou_debt")
	check(game.pending_event.get("id", "") == "xishou_debt", "赤霄 has come for a forty-year-old debt")
	game.choose_event("mediate")
	game.conclude("")
	var path: Array[String] = ["ferry", "wanghai"]
	check(game.has_flag("feiyu_free_ferry") and game.Journey.path_fee(game, path) == 0 and game.item_count("feiyu_tu") == 1, "settled: 飞鱼帮's boats are free, and an old map")
	var fought := _talked(_game())
	_go(fought, "ferry", "xishou_debt")
	fought.choose_event("defend")
	fought.Combat._win(fought)
	check(fought.has_flag("feiyu_owes") and fought.has_flag("xiongren_feiyu") and fought.story_state("xishou") == "done", "fought off: 飞鱼帮 owes a life, the 凶人榜 notes it")
	var sided := _talked(_game())
	_go(sided, "ferry", "xishou_debt")
	sided.choose_event("side")
	check(sided.has_flag("sect_closed_feiyu"), "sided with 赤霄: 飞鱼帮 is gone")

## Someone who has had a word with 老鳖.
func _talked(game: Session) -> Session:
	game.world.people["lao_bie"] = {"met": true, "relation": 0, "last": {}, "absent_until": -1, "talks": 1, "met_day": 0, "met_place": "ferry"}
	return game

func _saves() -> void:
	var game := _game()
	_fifteenth(game, 20)
	game.player.location = "market"
	game.guishi_gamble(1)
	game.guishi_contract()
	var copy := _reload(game)
	check(copy.battle.get("context", "") == "guishi" and copy.Guishi.state(copy).bought == [1], "mid-contract, a lot opened")
	# The duel's generated foe keeps its strength as a float, written to JSON at its own precision.
	check(copy.snapshot().world == game.snapshot().world and copy.snapshot().player == game.snapshot().player, "and the world reads back the same (%s)" % _differ(copy.snapshot().world, game.snapshot().world, ""))

## The first path where two saves differ, for the message.
func _differ(a: Variant, b: Variant, path: String) -> String:
	if a is Dictionary and b is Dictionary:
		for key: Variant in a.keys() + b.keys():
			if not a.has(key) or not b.has(key):
				return "%s/%s missing" % [path, key]
			var inner := _differ(a[key], b[key], "%s/%s" % [path, key])
			if not inner.is_empty():
				return inner
		return ""
	if a is Array and b is Array:
		if a.size() != b.size():
			return path + " size"
		for index: int in a.size():
			var inner := _differ(a[index], b[index], "%s/%d" % [path, index])
			if not inner.is_empty():
				return inner
		return ""
	return "" if typeof(a) == typeof(b) and a == b else "%s: %s vs %s" % [path, var_to_str(a), var_to_str(b)]
