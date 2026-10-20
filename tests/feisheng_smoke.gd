extends SceneTree
## 元婴与飞升 (docs/GAME_OUTLINE.md 22, batch 6): the four keys to 照川城, 温照雪 and the city's
## people, the 阵枢 and its rift, 晏无咎 at the end, the three ways over the river and the 飞升天劫,
## the truth made known or kept, and the 同辈 growing old. Each part plays through the rules a player
## would use, and survives a save.
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
	create_timer(240.0).timeout.connect(func() -> void: printerr("TIMEOUT: test did not finish (likely a script error)"); quit(1))
	_keys()
	_city()
	_yan()
	_routes()
	_failed_trial()
	_generations()
	print("FEISHENG: %d checks, %d failures" % [checks, failures])
	quit(0 if failures == 0 else 1)

func _game(seed_value: int = 31) -> Session:
	var game := Session.new()
	game.encounters_enabled = false
	game.new_game("飞升", seed_value, ["metal", "wood", "water"], "free")
	return game

func _found(game: Session, realm: int = 3, stage: int = 0) -> void:
	game.player.realm = realm
	game.player.stage = stage
	game.player.xp = int(game.content.stage(realm, stage).xp)
	game.player.mind = 900
	game.refresh_realm_stats()
	game.player.hp = game.player.max_hp
	game.player.qi = game.player.max_qi
	game.player.stones = 20000
	game.world.flags["tiannan_known"] = true

func _at(game: Session, year: int, month: int = 1, day: int = 1) -> void:
	game.world.day = Calendar.to_day(year, month, day)

func _stop(game: Session, place: String) -> void:
	game.player.location = place
	game.player.hp = game.player.max_hp
	game.wait(1)

func _win(game: Session) -> void:
	var guard := 0
	while not game.battle.is_empty() and guard < 40:
		guard += 1
		game.player.hp = game.player.max_hp
		game.battle.hp = 1
		game.plain_turn()

func _befriend(game: Session, person_id: String, relation: int) -> void:
	game.mark_met(person_id)
	game.world.people[person_id].relation = relation

func _reload(game: Session) -> Session:
	var copy := Session.new()
	check(copy.restore(JSON.parse_string(JSON.stringify(game.snapshot()))), "the journey survives a save")
	return copy

## A 元婴 at the sixth step of 镜中旧城.
func _at_gate(seed_value: int = 31) -> Session:
	var game := _game(seed_value)
	_found(game)
	_at(game, 260)
	game.world.storylines["mirror"] = {"state": "active", "step": 5, "since": int(game.world.day), "begun": false, "base": {}}
	game.wait(1)
	return game

## Four keys to the door over the ferry.
func _keys() -> void:
	var game := _at_gate()
	check(game.story_at("mirror", "fengcun"), "a 元婴 is sent to open 照川城's door")
	check(not game.location_visible("zhaochuan"), "the city is nowhere on the map before")
	game.add_item("zhaochuan_zhentu", 1)
	_stop(game, "ferry")
	check(game.pending_event.get("id", "") == "zhaochuan_gate", "at the crossing the door waits for a key")
	var choices: Array = game.pending_definition().choices
	check(game.choice_available(choices[0]) and not game.choice_available(choices[1]) and not game.choice_available(choices[2]), "温照衡's map is a key; nothing else is yet")
	game.choose_event("map")
	check(game.has_flag("zhaochuan_open") and game.location_visible("zhaochuan"), "the bridge reaches across")
	check(int(game.content.route_between("ferry", "zhaochuan").get("realm", 0)) == 3, "and only a 元婴 crosses it")
	game.travel("zhaochuan")
	game.wait(1)
	check(game.has_flag("zhaochuan_entered") and game.world.people.wen_zhaoxue.met, "inside, 温照雪")
	check(str(game.Storylines.current_step(game, "mirror").get("id", "")) == "zhenshu", "the seventh step")
	# 守川司's key, 庞守拙's reckoning, and 闻人照's sea gate.
	var keyed := _at_gate()
	keyed.world.flags["shouchuan_pact"] = true
	_stop(keyed, "ferry")
	check(keyed.choice_available(keyed.pending_definition().choices[1]), "a pact with 守川司 brings 晏无咎's key")
	var studied := _at_gate()
	studied.add_item("wen_diary", 1)
	studied.player.location = "beiyue"
	studied.mark_met("pang_shouzhuo")
	studied.interact("pang_shouzhuo", "seal_study")
	check(studied.has_flag("seal_studied") and int(studied.player.stones) == 18000, "庞守拙 reckons the door from the diary and the copper plate")
	_stop(studied, "ferry")
	check(studied.choice_available(studied.pending_definition().choices[2]), "the copper plate is a key")
	var sea := _at_gate()
	sea.world.flags["wenren_found_alive"] = true
	sea.world.flags["chart_verified"] = true
	_stop(sea, "jinhai")
	check(sea.pending_event.get("id", "") == "zhaochuan_seagate", "闻人照 waits at the sea gate")
	sea.choose_event("sea")
	check(sea.has_flag("zhaochuan_open") and sea.has_flag("gate_by_sea"), "and leads the way in")

## 温照雪, the 阵枢 and its rift.
func _city() -> void:
	var game := _at_gate()
	game.world.flags["zhaochuan_open"] = true
	game.world.flags["wen_diary"] = true
	_stop(game, "zhaochuan")
	_befriend(game, "ye_zhiwei", 90)
	game.add_item("liaoshang_pill", 10)
	for option: String in ["hear", "tell_brother", "medicine", "ye"]:
		game.interact("wen_zhaoxue", option)
	check(game.favor("wen_zhaoxue") >= 100, "heard, told of her brother, the people tended: 温照雪 trusts (%d)" % game.favor("wen_zhaoxue"))
	check(game.cave_here("shu") == "zhenshu", "the 阵枢 can be explored")
	for room: String in ["conduit", "core", "rift"]:
		game.player.hp = game.player.max_hp
		game.enter_room("zhenshu", room)
		_win(game)
	check(game.has_flag("zhenshu_cleared") and game.has_flag("rift_seen"), "past its warden, the rift")
	check(str(game.Caves.room(game, "zhenshu", "rift").text).contains("守川司"), "and the door 守川司 keeps")
	game.wait(1)
	check(str(game.Storylines.current_step(game, "mirror").get("id", "")) == "choice" and game.pending_event.get("id", "") != "zhenshu_choice", "the choice waits for 化神")
	_stop(game, "beiyue")
	check(game.pending_event.get("id", "") == "truth_choice", "in 北岳's archive, the missing pages")
	game.choose_event("publish")
	check(game.has_flag("truth_public"), "the truth told")

## 晏无咎 at 化神: support, a bargain, or a fight.
func _ready_choice(game: Session) -> void:
	_found(game, 4)
	game.world.flags["zhaochuan_open"] = true
	game.world.flags["zhaochuan_entered"] = true
	game.world.flags["rift_seen"] = true
	game.world.storylines["mirror"] = {"state": "active", "step": 7, "since": int(game.world.day), "begun": false, "base": {}}

func _yan() -> void:
	var friend := _game()
	_ready_choice(friend)
	friend.world.flags["shouchuan_pact"] = true
	_stop(friend, "zhaochuan")
	check(friend.has_flag("yan_supports"), "with a pact, 晏无咎 stands with the player")
	var trader := _game()
	_ready_choice(trader)
	trader.world.flags["shouchuan_refused"] = true
	trader.add_item("wen_diary", 1)
	trader.player.location = "zhaochuan"
	trader.pending_event = {}
	trader.wait(1)
	if str(trader.pending_event.get("id", "")) == "zhenshu_choice":
		trader.choose_event("later")
		trader.wait(1)
	check(trader.pending_event.get("id", "") == "yan_trade", "turned down once, he trades")
	trader.choose_event("diary")
	check(trader.has_flag("yan_traded"), "a copy of the diary for his help")
	var foe := _game()
	_ready_choice(foe)
	foe.world.flags["shouchuan_hostile"] = true
	_stop(foe, "zhaochuan")
	if str(foe.pending_event.get("id", "")) == "zhenshu_choice":
		var reopen: Dictionary = foe.pending_definition().choices[0]
		check(not foe.choice_available(reopen), "while he blocks the way, nothing can be settled")
		foe.choose_event("later")
		foe.wait(1)
	check(foe.pending_event.get("id", "") == "yan_obstructs", "made an enemy, he bars the 阵枢")
	foe.choose_event("fight")
	check(str(foe.battle.get("enemy_id", "")) == "yan_wujiu_boss", "a duel with 晏无咎")
	_win(foe)
	check(foe.has_flag("yan_beaten"), "beaten, he stands aside")

## The three ways, each to its own ending.
func _routes() -> void:
	for way: String in ["reopen", "replace", "self_yimin"]:
		var game := _game()
		_ready_choice(game)
		_befriend(game, "wen_zhaoxue", 100)
		match way:
			"reopen":
				game.add_item("chaoxin_shi", 3)
				game.add_item("ore_hantie", 5)
			"replace":
				game.world.flags["pillar_cleared"] = true
				game.add_item("wen_diary", 1)
				game.add_item("dihuo_jing", 5)
				_stop(game, "chixiao_gate")
				check(game.pending_event.get("id", "") == "dai_zhenshu_forge", "赤霄's smith can make a 阵枢 to replace the old")
				game.choose_event("forge")
				check(game.item_count("dai_zhenshu") == 1, "the replacement made")
			"self_yimin":
				game.add_item("tianxin_lianzi", 1)
		if way == "reopen":
			game.player.location = "market"
			game.act("sell")
			check(game.item_count("chaoxin_shi") == 3 and game.item_count("ore_hantie") == 5, "一键卖出 keeps what the 阵枢 would take")
		_stop(game, "zhaochuan")
		# Never dealt with 守川司: 晏无咎 offers his bargain first; turned down, the choice comes.
		if str(game.pending_event.get("id", "")) == "yan_trade":
			game.choose_event("refuse")
		if game.pending_event.is_empty():
			game.wait(1)
		check(game.pending_event.get("id", "") == "zhenshu_choice", "%s: at the 阵枢, the choice" % way)
		game.choose_event(way)
		var route: String = game.Ascension.route(game)
		check(route == way.get_slice("_", 0) and game.has_flag("ascension_open") and game.story_state("mirror") == "done", "%s: settled, the crossing opens to the player" % way)
		if way == "replace":
			check(game.has_flag("survivors_moved") and game.npc_location("wen_zhaoxue") == "ferry", "the city's people come out to 白鹭渡")
		if way == "reopen":
			check(game.person("wen_zhaoxue").title == "照川城主", "照川 lives again under 温照雪")
		game.world.flags["truth_kept"] = true
		_stop(game, "ferry")
		check(game.available_here("ascend") and game.ascend_block().is_empty(), "at the crossing, any stage of 化神 may go")
		game.act("ascend")
		_win(game)
		check(game.ended.get("kind", "") == "ascension" and str(game.ended.get("route", "")) == route, "%s: the 飞升天劫 weathered" % way)
		var words: String = game.Ascension.ending_text(game)
		check(words.contains(str(game.content.rules.ascension.routes[route].ending)) and words.contains("没有几个人知道"), "the ending tells the way and the kept truth")
		var copy := _reload(game)
		check(str(copy.ended.get("route", "")) == route, "the way survives a save")

## Struck down by the 飞升天劫: a year to heal, then again.
func _failed_trial() -> void:
	var game := _game()
	_found(game, 4)
	game.world.flags["path_self"] = true
	game.world.flags["ascension_open"] = true
	game.player.location = "ferry"
	game.act("ascend")
	var guard := 0
	while not game.battle.is_empty() and guard < 30:
		guard += 1
		game.player.hp = 1
		game.defend()
	check(game.ended.is_empty() and game.ascend_block().contains("伤"), "struck down, the body must heal first")
	game.world.day = int(game.player.injury_until) + 1
	check(game.ascend_block().is_empty(), "healed, the crossing waits again")

## The 同辈 grow old: each dies in their years, unless a 机缘 carried them further.
func _generations() -> void:
	var game := _game()
	_found(game)
	for person: String in ["lu_chengzhou", "wounded", "ye_zhiwei"]:
		game.mark_met(person)
	game.world.flags["boon_ye_zhiwei"] = true
	_at(game, 202, 12, 25)
	game.wait(10)
	check(game.person("lu_chengzhou").realm_text == "已坐化" and game.npc_location("lu_chengzhou").is_empty(), "历元二百零三年 陆承舟 dies a 筑基")
	check(game.chronicle.entries.any(func(entry: Dictionary) -> bool: return entry.id == "event" and str(entry.args.get("event", "")) == "passes_lu_chengzhou_203"), "and word of it comes")
	_at(game, 300)
	check(game.person("yan_qianqiu").title == "赤霄门主" and game.person("yan_qianqiu").realm_text == "元婴初期", "by 历元三百年 the first disciples lead their sects")
	_at(game, 385)
	check(game.person("wounded").realm_text == "已坐化" and game.person("ye_zhiwei").realm_text == "元婴初期", "柳寒舟 is gone; 叶知微, given the 古境's 机缘, has reached 元婴")
	_at(game, 681)
	check(game.npc_location("ye_zhiwei").is_empty(), "and in time she too")
