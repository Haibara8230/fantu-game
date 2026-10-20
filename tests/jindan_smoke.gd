extends SceneTree
## 金丹大经历 (docs/GAME_OUTLINE.md 21, batch 5): 沉霞古境 with a companion and its 机缘, 守川司 at the
## mirror wall and 晏无咎's offer, the search for 闻人照 and the sea, the old battlefield and the sea
## pillar, 温照衡's last years, and the 凝婴之法. Each part plays through the rules a player would use,
## and survives a save.
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
	_party()
	_mirror()
	_boon()
	_search()
	_evidence()
	_wen()
	_ningying()
	print("JINDAN: %d checks, %d failures" % [checks, failures])
	quit(0 if failures == 0 else 1)

func _game(seed_value: int = 31) -> Session:
	var game := Session.new()
	game.encounters_enabled = false
	game.new_game("金丹", seed_value, ["metal", "wood", "water"], "free")
	return game

func _found(game: Session, realm: int = 2, stage: int = 0) -> void:
	game.player.realm = realm
	game.player.stage = stage
	game.player.xp = int(game.content.stage(realm, stage).xp)
	game.player.mind = 400
	game.refresh_realm_stats()
	game.player.hp = game.player.max_hp
	game.player.qi = game.player.max_qi
	game.player.stones = 5000
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

## 沉霞古境 opens in 历元一百五十年; a friend may go along, each with a gift; a lost one cannot.
func _opened(seed_value: int = 31) -> Session:
	var game := _game(seed_value)
	_found(game)
	_at(game, 150, 2, 25)
	game.player.location = "ridge"
	game.wait(10)
	return game

func _party() -> void:
	var game := _opened()
	check(game.has_flag("chenxia_open"), "历元一百五十年三月古境开了")
	_befriend(game, "wounded", 90)
	_befriend(game, "wenren_zhao", 90)
	game.world.flags["wenren_lost"] = true
	_stop(game, "wild")
	check(game.pending_event.get("id", "") == "chenxia_party", "at the valley floor a friend may be asked along")
	var choices: Array = game.pending_definition().choices
	check(game.choice_available(choices[0]) and not game.choice_available(choices[2]), "柳寒舟 can come; 闻人照, lost at sea, cannot")
	game.choose_event("with_wounded")
	check(game.Caves.party(game, "chenxia") == "wounded", "柳寒舟 goes along")
	game.enter_room("chenxia", "stairs")
	game.player.hp = game.player.max_hp
	game.enter_room("chenxia", "tomb")
	var full := int(game.content.enemies.jian_kui.hp)
	check(str(game.battle.get("enemy_id", "")) == "jian_kui" and int(game.battle.hp) == int(full * 0.7), "his sword leaves the 剑傀 seven tenths (%d of %d)" % [int(game.battle.get("hp", 0)), full])
	_win(game)
	var copy := _reload(game)
	check(copy.Caves.party(copy, "chenxia") == "wounded", "who went along survives a save")
	# 叶知微 mends between rooms; below 金丹 the long stair stays shut.
	var healer := _opened()
	_befriend(healer, "ye_zhiwei", 90)
	_stop(healer, "wild")
	healer.choose_event("with_ye_zhiwei")
	healer.player.hp = 10
	healer.enter_room("chenxia", "stairs")
	check(int(healer.player.hp) > 10, "叶知微 mends the wounds of the way (%d)" % int(healer.player.hp))
	var low := _opened()
	low.player.realm = 1
	low.refresh_realm_stats()
	low.player.location = "wild"
	check(low.Caves.enter_block(low, "chenxia", "stairs").contains("金丹"), "a 筑基 is turned back at the stair")
	game.world.day = Calendar.to_day(151, 2, 28)
	game.wait(5)
	check(not game.has_flag("chenxia_open"), "a year on the gate sinks again")

## The mirror wall: 照川, 守川司 at one's back, and 晏无咎 at the gate.
func _mirror() -> void:
	for way: String in ["fight", "trade", "yield"]:
		var game := _opened()
		game.world.storylines["mirror"] = {"state": "active", "step": 3, "since": int(game.world.day), "begun": false, "base": {}}
		game.player.location = "wild"
		game.world["caves"] = {"chenxia": {"explored": ["gate", "stairs", "tomb", "library"], "taken": [], "fortune": {}}}
		game.world.flags["chenxia_puppet_down"] = true
		game.pending_event = {}
		game.enter_room("chenxia", "mirror")
		check(game.has_flag("zhaochuan_seen") and game.pending_event.get("id", "") == "chenxia_shouchuan", "%s: the wall shows 照川, and 守川司 comes in behind" % way)
		game.choose_event(way)
		if way == "fight":
			check(str(game.battle.get("enemy_id", "")) == "shouchuan_lead", "their leader stands to it")
			_win(game)
		game.wait(1)
		check(game.pending_event.get("id", "") == "yan_recruit" and game.world.people.yan_wujiu.met, "%s: 晏无咎 waits at the gate" % way)
		var bargain: Dictionary = game.pending_definition().choices[2]
		check(game.choice_available(bargain) == (way == "trade"), "a bargain only with the favour of a trade (%s)" % way)
		game.choose_event("accept" if way == "fight" else "refuse")
		check(game.story_at("mirror", "zhaoheng") or game.story_state("mirror") == "active", "the mirror's story moves on")
		if way == "fight":
			check(game.has_flag("shouchuan_hostile") and game.has_flag("shouchuan_joined") and game.has_flag("ningying_known"), "fought, yet joined: 守川司 hands over the way to 元婴")
	var story := _opened()
	story.world.storylines["mirror"] = {"state": "active", "step": 3, "since": int(story.world.day), "begun": true, "base": {}}
	story.world.flags["zhaochuan_seen"] = true
	story.Storylines.update(story)
	check(story.story_at("mirror", "zhaoheng"), "seeing 照川 is the fourth step")

## The 机缘 at the seat: kept, or given to the friend along.
func _boon() -> void:
	var game := _opened()
	_befriend(game, "ye_zhiwei", 90)
	_stop(game, "wild")
	game.choose_event("with_ye_zhiwei")
	game.world.flags["chenxia_remnant_down"] = true
	game.wait(1)
	check(game.pending_event.get("id", "") == "chenxia_boon", "the guardian of the seat gone, one 机缘 is left")
	var choices: Array = game.pending_definition().choices
	check(game.choice_available(choices[2]) and not game.choice_available(choices[1]), "it may go to 叶知微, who came, not to 柳寒舟, who did not")
	game.choose_event("give_ye_zhiwei")
	check(game.has_flag("boon_ye_zhiwei") and game.item_count("yanghun_mu") == 0, "given away")
	_at(game, 156)
	check(game.person("ye_zhiwei").realm_text == "金丹后期", "and she goes further sooner for it")
	var keeper := _opened()
	keeper.world.flags["chenxia_remnant_down"] = true
	_stop(keeper, "wild")
	keeper.choose_event("alone")
	keeper.wait(1)
	keeper.choose_event("keep")
	check(keeper.item_count("yanghun_mu") == 1, "or kept: 养魂木 for one's own 元婴")

## 闻人照, lost at sea: asked after in 望海, sought on the fog island; how he is found follows the help given.
func _search() -> void:
	for helped: bool in [true, false]:
		var game := _game()
		_found(game)
		game.mark_met("wenren_zhao")
		if helped:
			game.world.flags["wenren_supplied"] = true
		game.world.flags["wenren_lost"] = true
		_at(game, 131)
		game.wait(1)
		check(game.story_state("wenren_search") == "active", "word of the lost ship")
		_stop(game, "wanghai")
		check(game.has_flag("wenren_heard") and game.world.people.wei_sanniang.met, "卫三娘 points south-east")
		check(int(game.content.route_between("jinhai", "waihai").get("realm", 0)) == 2, "the fog island is flown to at 金丹")
		_stop(game, "waihai")
		check(game.story_state("wenren_search") == "done", "the island searched")
		if helped:
			check(game.has_flag("wenren_found_alive") and game.npc_location("wenren_zhao") == "wanghai" and game.person("wenren_zhao").title == "可靠的领航者", "the supplies kept him alive: he guides ships out of 望海")
		else:
			check(game.has_flag("wenren_found_dead") and game.item_count("wenren_log") == 1 and game.npc_location("wenren_zhao").is_empty(), "alone, only his log is found")

## The other two proofs of 照川: the old battlefield north of 北岳, the pillar under the sea.
func _evidence() -> void:
	var field := _game()
	_found(field)
	field.player.location = "guzhanchang"
	check(field.cave_here("altar") == "guzhan", "the battlefield's altar can be explored at 金丹")
	field.world["caves"] = {"guzhan": {"explored": ["pit", "array"], "taken": [], "fortune": {}}}
	field.enter_room("guzhan", "tent")
	_win(field)
	check(field.has_flag("guzhan_cleared") and str(field.Caves.room(field, "guzhan", "tent").text).contains("照川"), "the general's ghost falls; the 照川 map lies in its stone case")
	var sea := _game()
	_found(sea)
	sea.player.location = "waihai"
	sea.world["caves"] = {"haidi": {"explored": ["reef", "ring"], "taken": [], "fortune": {}}}
	sea.enter_room("haidi", "rift")
	_win(sea)
	check(sea.has_flag("pillar_cleared"), "the pillar's guardian falls")
	sea.world.storylines["mirror"] = {"state": "active", "step": 3, "since": int(sea.world.day), "begun": true, "base": {}}
	sea.Storylines.update(sea)
	check(sea.story_at("mirror", "zhaoheng"), "any one proof is the fourth step")

## 温照衡: told what was found, he gives his account before he dies; after, his diary.
func _wen() -> void:
	var game := _game()
	_found(game)
	game.mark_met("wen_zhaoheng")
	game.world.storylines["mirror"] = {"state": "active", "step": 4, "since": int(game.world.day), "begun": true, "base": {}}
	game.player.location = "ferry"
	_at(game, 180)
	game.interact("wen_zhaoheng", "testimony")
	check(not game.has_flag("wen_testimony"), "a stranger hears nothing")
	for flag: String in ["zhaochuan_seen", "guzhan_cleared", "pillar_cleared", "chart_verified"]:
		game.world.flags[flag] = true
	for option: String in ["tell_mirror", "tell_map", "tell_pillar", "tell_chart"]:
		game.interact("wen_zhaoheng", option)
	check(game.favor("wen_zhaoheng") >= 100, "each proof told brings him closer (%d)" % game.favor("wen_zhaoheng"))
	game.interact("wen_zhaoheng", "testimony")
	game.wait(1)
	check(game.has_flag("wen_testimony") and game.item_count("zhaochuan_zhentu") == 1 and game.has_flag("ningying_known"), "his account, the array map, and the way to 元婴")
	check(str(game.Storylines.current_step(game, "mirror").get("id", "")) == "fengcun", "the fifth step of the mirror's story")
	_at(game, 199, 12, 25)
	game.wait(10)
	check(game.has_flag("wen_gone") and game.npc_location("wen_zhaoheng").is_empty() and game.person("wen_zhaoheng").realm_text == "已坐化", "历元二百年 he dies at the crossing")
	var late := _game()
	_found(late)
	late.mark_met("wen_zhaoheng")
	late.world.storylines["mirror"] = {"state": "active", "step": 4, "since": int(late.world.day), "begun": true, "base": {}}
	_at(late, 199, 12, 25)
	late.wait(10)
	_stop(late, "ferry")
	check(late.has_flag("wen_diary") and late.item_count("wen_diary") == 1 and not late.has_flag("ningying_known"), "too late for his account: the boatman hands over his diary")
	late.wait(1)
	check(str(late.Storylines.current_step(late, "mirror").get("id", "")) == "fengcun", "the diary also closes the fifth step")
	var copy := _reload(late)
	check(copy.has_flag("wen_diary"), "and the diary survives a save")

## 凝婴之法 adds to the odds of the 元婴, not to the 金丹's.
func _ningying() -> void:
	var game := _game()
	_found(game, 2, 3)
	game.player.xp = 200000
	game.world.flags["ningying_known"] = true
	var odds: Dictionary = game.Breakthrough.odds(game, {"pills": 0, "treasure": "", "guard": ""})
	check(odds.parts.any(func(part: Array) -> bool: return str(part[0]) == "凝婴之法" and int(part[1]) == 10), "凝婴之法 adds ten to forming the 元婴")
	var core := _game()
	_found(core, 1, 3)
	core.world.flags["ningying_known"] = true
	check(not core.Breakthrough.odds(core, {"pills": 0, "treasure": "", "guard": ""}).parts.any(func(part: Array) -> bool: return str(part[0]) == "凝婴之法"), "it counts for nothing at 结丹")
	check(game.content.item("ningying_jue").use.any(func(effect: Dictionary) -> bool: return effect.has("flag")), "《凝婴诀》 lies hidden in the 古境's library")
