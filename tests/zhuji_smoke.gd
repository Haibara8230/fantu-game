extends SceneTree
## 筑基篇 (docs/GAME_OUTLINE.md 19, batch 3): 南明城 and 北岳城 with their roads, the 同辈 growing on the
## calendar, the five places a 筑基 cultivator explores, 《藏息录》, 青云试剑崖 and the 散修's 历练帖,
## 天南大比, 守川司 at the old archive, 陆家's funeral and its mine, 柳寒舟's old case, and the first
## trade between cities. Each part plays through the rules a player would use, and survives a save.
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
	_geography()
	_phases()
	_caves()
	_cangxi()
	_jianya()
	_lilian()
	_contest()
	_archive()
	_lu()
	_liu()
	_demand()
	print("ZHUJI: %d checks, %d failures" % [checks, failures])
	quit(0 if failures == 0 else 1)

func _game(start: String = "free", seed_value: int = 31, roots: Array = ["metal", "wood", "water"]) -> Session:
	var game := Session.new()
	game.encounters_enabled = false
	game.new_game("筑基", seed_value, roots, start)
	return game

## A 筑基 cultivator, healthy and with stones for the road; 天南 known.
func _found(game: Session, stage: int = 0) -> void:
	game.player.realm = 1
	game.player.stage = stage
	game.player.xp = int(game.content.stage(1, stage).xp)
	game.player.mind = 120
	game.refresh_realm_stats()
	game.player.hp = game.player.max_hp
	game.player.qi = game.player.max_qi
	game.player.stones = 3000
	game.world.flags["tiannan_known"] = true

func _at(game: Session, year: int, month: int = 1, day: int = 1) -> void:
	game.world.day = Calendar.to_day(year, month, day)

func _settle(game: Session, prefer: String = "") -> void:
	var guard := 0
	while not game.pending_event.is_empty() and guard < 10:
		guard += 1
		var choices: Array = game.pending_definition().get("choices", [])
		var pick := str(choices.back().id) if not choices.is_empty() else ""
		for choice: Dictionary in choices:
			if str(choice.id) == prefer and game.choice_available(choice):
				pick = prefer
		game.choose_event(pick)

func _go(game: Session, place: String) -> void:
	if str(game.player.location) != place:
		game.player.hp = game.player.max_hp
		game.travel(place)
	_settle(game)

## Wins whatever duel is open, wave after wave: each foe falls to the next blow.
func _win(game: Session) -> void:
	var guard := 0
	while not game.battle.is_empty() and guard < 40:
		guard += 1
		game.player.hp = game.player.max_hp
		game.battle.hp = 1
		game.plain_turn()

func _standing(game: Session, person_id: String) -> Array:
	return game.Bonds.standing(game, person_id).map(func(part: Variant) -> int: return int(part))

func _option(game: Session, person_id: String, option_id: String) -> Dictionary:
	for option: Dictionary in game.npc_options(person_id):
		if option.id == option_id:
			return option
	return {}

func _reload(game: Session) -> Session:
	var copy := Session.new()
	check(copy.restore(JSON.parse_string(JSON.stringify(game.snapshot()))), "the journey survives a save")
	return copy

## 南明城 and 北岳城: a room by the month in each, the roads north, and a short way flown at 筑基.
func _geography() -> void:
	var game := _game()
	check(game.content.locations.nanming.name == "南明城" and game.content.locations.beiyue.region == "tiannan", "南明 is a city now, and 北岳 stands in 天南")
	check(not game.location_visible("beiyue") and not game.location_visible("duanjian"), "北岳 and 断剑峡 stay hidden until 天南 is known")
	var all := {}
	for flag: String in game.content.world_flags:
		all[flag] = true
	all.erase("serpent_rampage")
	check(game.content.find_path("xuanyue_gate", "duanjian", all, 0).size() == 3, "on foot 断剑峡 is reached through 北岳")
	check(game.content.find_path("xuanyue_gate", "duanjian", all, 1).size() == 2, "a 筑基 cultivator flies the short way")
	_found(game)
	game.player.location = "nanming"
	check(game.available_here("cultivate") and game.available_here("inn_rest"), "南明's 火塘客栈 lets a room to retreat in")
	check(int(game.Cultivation.rent(game, 30)) == 10, "for ten stones a month")
	game.travel("beiyue")
	_settle(game)
	check(str(game.player.location) == "beiyue" and game.available_here("cultivate") and game.available_here("commissions"), "北岳 has its own inn and board")
	check(not game.content.spot_open(game.content.locations.beiyue.spots[3], game.world.flags, 0, ""), "the old archive needs a way in")

## The 同辈 on the calendar: 柳寒舟 settles in 北岳, 陆承舟 founds at eighteen, a choice changes a title.
func _phases() -> void:
	var game := _game()
	check(game.person("wounded").title == "受伤的散修", "历元元年 柳寒舟 is a wounded wanderer")
	game.world.flags["tiannan_known"] = true
	_at(game, 3)
	check(game.person("wounded").title == "北岳的散修剑客" and game.npc_location("wounded") == "beiyue", "from 历元三年 he lives in 北岳 (%s)" % game.npc_location("wounded"))
	_at(game, 17)
	check(_standing(game, "wounded") == [1, 0] and game.person("wounded").realm_text == "筑基初期", "by seventeen he has founded")
	_at(game, 18)
	check(_standing(game, "lu_chengzhou") == [1, 0], "陆承舟 founds at eighteen")
	_at(game, 31)
	game.world.flags["lu_head"] = true
	check(game.person("lu_chengzhou").title == "陆家当家", "after the funeral he heads the house")
	game.world.flags["lu_leave"] = true
	check(game.person("lu_chengzhou").title == "离家修行的散修" and game.npc_location("lu_chengzhou") == "ferry", "and leaving it, he is a wanderer at 白鹭渡")
	check(game.content.people.lu_chengzhou.title == "云溪陆家少爷", "the data itself is untouched")

## The five places a 筑基 cultivator explores, as far as batch 3 takes them.
func _caves() -> void:
	# 落霞谷's spring: once the serpent is dead, the vein under it, and the 灵眼 at its end.
	var game := _game()
	_found(game)
	game.world.flags["serpent_slain"] = true
	game.travel("wild")
	_settle(game)
	check(game.has_flag("spring_open") and game.cave_here("veins") == "spring_depths" and game.cave_here("chenxia").is_empty(), "the spring's vein opens beside the closed 古境")
	for room: String in ["vent", "channel", "eye"]:
		game.player.hp = game.player.max_hp
		game.enter_room("spring_depths", room)
	check(game.has_flag("spirit_eye_found"), "the vein's end is the valley's 灵眼")
	check(str(game.Caves.room(game, "spring_depths", "vent").text).contains("火脉改了道"), "and the vent tells why the spring grew hot")
	# 断剑峡: 筑基 to go in; 剑冢 waits for 金丹.
	var gorge := _game()
	gorge.world.flags["tiannan_known"] = true
	gorge.player.location = "duanjian"
	check(gorge.cave_here("gorge").is_empty(), "炼气 cannot go into the gorge")
	_found(gorge)
	check(gorge.cave_here("gorge") == "duanjian", "筑基 can")
	gorge.enter_room("duanjian", "swords")
	_win(gorge)
	check(gorge.has_flag("duanjian_ling_down"), "the sword spirit falls")
	_settle(gorge)
	check(gorge.Caves.enter_block(gorge, "duanjian", "tomb").contains("金丹"), "剑冢 is told to wait for 金丹")
	# 地火熔窟: a fire root finds its way through the heat.
	for roots: Array in [["metal", "wood", "water"], ["fire", "earth"]]:
		var furnace := _game("free", 31, roots)
		furnace.world.flags["tiannan_known"] = true
		furnace.world.flags["dihuo_lizard_down"] = true
		furnace.player.location = "chifeng"
		furnace.world["caves"] = {"dihuo": {"explored": ["mouth", "tunnel", "nest"], "taken": [], "fortune": {}}}
		var blocked: String = furnace.Caves.enter_block(furnace, "dihuo", "core")
		check(blocked.is_empty() == ("fire" in roots), "the heat of 地火之心 %s (%s)" % ["parts for a fire root" if "fire" in roots else "turns others back", blocked])
	# 古修洞府's warded room: 筑基 to go in, its ward a trap 秦砚's 阵谱 helps read.
	var ruin := _game()
	ruin.world.flags["ruin_cleared"] = true
	ruin.player.location = "ruin"
	ruin.world["caves"] = {"ruin": {"explored": ["hall", "corridor", "study", "armory", "sealed"], "taken": [], "fortune": {}}}
	ruin.world.flags["ruin_den_cleared"] = true
	check(ruin.Caves.enter_block(ruin, "ruin", "warded").contains("筑基"), "炼气 is turned back from the warded room")
	_found(ruin)
	ruin.world.flags["trap_lore"] = true
	var hp: int = ruin.player.hp
	ruin.enter_room("ruin", "warded")
	check(ruin.Caves.explored(ruin, "ruin", "warded") and int(ruin.player.hp) == hp, "with the 阵谱 the ward is read and passed unhurt")

## 《藏息录》: a named 心法 that quickens 遁速 and keeps trouble off the road, not before 守川司.
func _cangxi() -> void:
	var game := _game()
	_found(game)
	var t: Dictionary = game.content.technique("cangxi_lu")
	check(t.slot == "method" and t.tier_name == "玄阶" and is_equal_approx(float(t.passive.dun_speed), 0.2), "《藏息录》 is a 玄阶 心法 of 遁速")
	check(game.content.item("j:cangxi_lu").name == "《藏息录》玉简", "and comes as a slip")
	var road := {"between": ["beiyue", "duanjian"], "days": 3, "danger": 2}
	var before: int = game.Combat.speed(game)
	var risk: float = game.Events.encounter_chance(game, road)
	# 莫辞 on the shoal: met crossing it, taught for three salves once a friend.
	game.player.location = "duanjian"
	game.wait(1)
	check(game.pending_event.get("id", "") == "mo_ci_crossing", "a grey wanderer crosses the shoal the sword spirits roam")
	_settle(game, "greet")
	check(game.world.people.mo_ci.met and not _option(game, "mo_ci", "cangxi").get("available", false), "莫辞 met; he teaches only a friend")
	game.world.people.mo_ci.relation = 90
	game.add_item("liaoshang_pill", 3)
	game.interact("mo_ci", "cangxi")
	check(game.item_count("j:cangxi_lu") == 1 and game.has_flag("cangxi_taught"), "three salves for the slip")
	game.travel("beiyue")
	_settle(game)
	game.study_manual("j:cangxi_lu")
	check("cangxi_lu" in game.player.methods, "studied in a room at the inn, it is held (%s)" % str(game.player.methods))
	check(game.Combat.speed(game) > before and game.Events.encounter_chance(game, road) < risk, "遁速 quickens (%d > %d) and the road grows quieter" % [game.Combat.speed(game), before])
	game.begin_battle("shouchuan_wei", "event")
	check(game.Combat.speed(game) == before, "but a 守川司 巡使 is not fooled")
	game.battle.clear()

## 青云试剑崖: ten-yearly, five floors; each floor counts, three send one to 天南大比.
func _jianya() -> void:
	var game := _game("plain", 41)
	_found(game)
	game.player.location = "sect"
	_at(game, 10, 3, 25)
	game.wait(10)
	check(game.pending_event.get("id", "") == "jianya_open", "in 历元十年四月 the cliff opens to 青云's 筑基 disciples")
	var merit := int(game.player.get("merit", 0))
	game.choose_event("climb")
	check(not game.battle.is_empty() and str(game.player.series.id) == "jianya", "the first floor's puppet steps out")
	game.player.hp = game.player.max_hp
	game.battle.hp = 1
	game.plain_turn()
	game.battle.hp = 1
	game.plain_turn()
	check(game.Trials.best(game, "jianya", 20) == 2 and int(game.player.merit) == merit + 80, "two floors climbed, each worth forty merit (%d)" % game.Trials.best(game, "jianya", 20))
	var copy := _reload(game)
	check(copy.Trials.best(copy, "jianya", 20) == 2, "the climb is kept in the save")
	_win(game)
	check(game.Trials.best(game, "jianya", 20) == 5 and game.player.items.keys().any(func(id: String) -> bool: return id.begins_with("j:t:") and game.content.technique(id.substr(2)).element == "metal"), "at the top a 剑诀 slip waits")
	var outsider := _game()
	_found(outsider)
	outsider.player.location = "sect"
	_at(outsider, 10, 4, 2)
	check(not outsider.Events.all_met(outsider, outsider.content.events.jianya_open.conditions), "a wanderer has no cliff to climb")

## 散修历练帖: a year in ten, the cities' boards post 历练帖 for 筑基; each handed in is a merit.
func _lilian() -> void:
	var game := _game()
	_found(game)
	game.player.location = "market"
	_at(game, 15, 2, 1)
	var offers: Array[Dictionary] = game.commission_offers("market")
	var scout: Array = offers.filter(func(offer: Dictionary) -> bool: return str(offer.kind) == "lilian_scout")
	check(offers.filter(func(offer: Dictionary) -> bool: return str(offer.kind).begins_with("lilian_")).size() == 3, "in 历元十五年 the board posts all three kinds of 历练帖")
	game.accept_commission(str(scout[0].key))
	var place := str(game.player.quests[0].place)
	game.travel(place)
	_settle(game)
	game.travel("market")
	_settle(game)
	game.deliver_commission(str(scout[0].key))
	check(game.Trials.score(game, "lilian", 15) == 1 and game.journal_lines().any(func(line: String) -> bool: return line.contains("一功")), "handed in, it counts one merit")
	_at(game, 16, 2, 1)
	check(not game.commission_offers("market").any(func(offer: Dictionary) -> bool: return str(offer.kind).begins_with("lilian_")), "the next year posts none")
	var low := _game()
	low.player.location = "market"
	_at(low, 15, 2, 1)
	check(not low.commission_offers("market").any(func(offer: Dictionary) -> bool: return str(offer.kind).begins_with("lilian_")), "炼气 cultivators are not offered them")

## 天南大比: 历元二十年 at 云溪; qualifying, four rounds, a champion; 柳寒舟's story begins.
func _contest() -> void:
	var game := _game()
	_found(game, 1)
	game.player.location = "market"
	_at(game, 20, 8, 28)
	game.wait(5)
	check(game.pending_event.get("id", "") == "tiannan_contest_yunxi", "九月, 天南大比 opens in 云溪")
	var enter: Dictionary = game.pending_definition().choices[0]
	check(not game.choice_available(enter), "without a sitting, a merit or a word for them, none may enter")
	game.world.people["shen_mo"] = game.world.people.get("shen_mo", {"met": true, "relation": 0, "last": {}, "absent_until": -1, "talks": 0, "met_day": -1, "met_place": ""})
	game.world.people.shen_mo.relation = 90
	check(game.choice_available(enter), "沈墨's word is enough")
	check(game.story_state("liu_case") == "active", "柳寒舟 is in the crowd: his old case begins")
	game.choose_event("enter")
	check(str(game.battle.get("contest", "")) == "tiannan" and str(game.battle.foe.name).contains("玄岳"), "round one: a 玄岳 disciple")
	var copy := _reload(game)
	check(str(copy.battle.get("contest", "")) == "tiannan" and int(copy.battle.round) == 1, "a contest duel survives a save")
	_win(game)
	check(game.has_flag("tiannan_champion") and game.chronicle.entries.any(func(entry: Dictionary) -> bool: return entry.id == "contest_champion"), "four wins crown the champion")
	_settle(game)
	var golden := _game()
	_found(golden)
	golden.player.realm = 2
	golden.refresh_realm_stats()
	golden.player.location = "market"
	_at(golden, 20, 9, 2)
	golden.wait(1)
	check(golden.pending_event.get("id", "") == "tiannan_contest_yunxi" and not golden.choice_available(golden.pending_definition().choices[0]), "a 金丹 cultivator only watches")
	check(int(golden.content.events.five_sects_entry.periodic.start_year) == 120, "五宗论道 waits for 历元一百二十年 and 金丹")

## 镜中旧城, step three: through 阵师会馆 into the archive, where 守川司 is taking the old rolls away.
func _archive() -> void:
	for way: String in ["parley", "seize"]:
		var game := _game()
		_found(game)
		game.world.flags["crest_puzzled"] = true
		game.world.storylines["mirror"] = {"state": "active", "step": 2, "since": int(game.world.day), "begun": false, "base": {}}
		game.wait(1)
		check(game.story_at("mirror", "archive"), "the crest leads north to 北岳's archive")
		game.player.location = "beiyue"
		game.mark_met("pang_shouzhuo")
		game.interact("pang_shouzhuo", "deposit")
		check(game.has_flag("archive_pass"), "two hundred stones held, a note for the archive")
		game.wait(1)
		check(game.pending_event.get("id", "") == "archive_shouchuan", "守川司 is packing the rolls away")
		game.choose_event(way)
		_win(game)
		_settle(game)
		check(game.story_state("mirror") == "done" and game.world.people.yan_wujiu.met, "%s: the missing pages are 守川司's work; 晏无咎 has seen the player" % way)
		check(game.has_flag("shouchuan_wary" if way == "parley" else "shouchuan_hostile"), "and 守川司 remembers how (%s)" % way)

## 陆家: the funeral in 历元三十年, the ledger, the mine, and what is done about it.
func _lu() -> void:
	var game := _game()
	_found(game)
	game.mark_met("lu_chengzhou")
	game.player.location = "market"
	_at(game, 30, 2, 20)
	game.wait(20)
	check(game.story_state("lu_heir") == "active", "历元三十年春 陆承岳 dies on the northern road")
	game.wait(1)
	check(game.has_flag("lu_head") and game.person("lu_chengzhou").title == "陆家当家", "at 云溪 the funeral; 陆承舟 heads the house")
	var waited := 0
	while not game.story_at("lu_heir", "ledger") and waited < 10:
		waited += 1
		game.wait(400)
	check(game.story_at("lu_heir", "ledger"), "five years on, a ledger he cannot read")
	_go(game, "nanming")
	check(game.has_flag("lu_mine_known"), "延寿药胚 to an old mine")
	game.travel("chifeng")
	check(game.pending_event.get("id", "") == "lu_mine_gate", "guards at the old mine's mouth")
	check(not game.choice_available(game.pending_definition().choices[1]), "without 《藏息录》 or a keen 神识 there is no slipping past")
	game.choose_event("later")
	game.world.people.lu_chengzhou.relation = 90
	game.wait(10)
	check(game.pending_event.get("id", "") == "lu_mine_gate" and game.choice_available(game.pending_definition().choices[2]), "a friend of 陆承舟 can have the gate opened in his name")
	game.choose_event("name")
	game.wait(1)
	check(game.pending_event.get("id", "") == "lu_choice", "behind the guards, people tried with the drug")
	game.choose_event("public")
	check(game.story_state("lu_heir") == "done" and game.person("lu_chengzhou").title == "担责的陆家家主", "owned up to in public, he answers for his house")

## 柳寒舟's old case: told after 天南大比, a witness in 历元四十年, the roll and the token, and an ending.
func _liu() -> void:
	var game := _game()
	_found(game)
	game.player.location = "beiyue"
	game.start_story("liu_case")
	game.wait(1)
	check(game.story_step("liu_case").id == "witness", "in 北岳 he tells of 断剑门")
	_at(game, 39, 12, 20)
	game.wait(15)
	check(game.world.letters.any(func(letter: Dictionary) -> bool: return str(letter.get("story", "")) == "liu_case" and str(letter.get("step", "")) == "witness"), "in 历元四十年 his 传音: the witness has come")
	check(game.story_at("liu_case", "evidence"), "the old porter's account: 玄岳's own men, and the 剑冢")
	game.world.flags["archive_pass"] = true
	game.world.flags["duanjian_ling_down"] = true
	game.wait(1)
	check(game.pending_event.get("id", "") == "liu_choice", "roll, token and witness agree")
	game.choose_event("redress")
	check(game.story_state("liu_case") == "done" and game.person("wounded").title == "北岳的剑修", "the disciples' names cleared, he stays in 北岳")

## 跨城需求: 南明's miners pay thrice for salves until the need is filled; it comes back in two months.
func _demand() -> void:
	var game := _game()
	_found(game)
	game.player.location = "nanming"
	game.add_item("liaoshang_pill", 12)
	var first: int = game.sell_price("liaoshang_pill")
	check(first >= 25, "a salve fetches about thrice its price in 南明 (%d)" % first)
	game.player.location = "market"
	check(game.sell_price("liaoshang_pill") < first, "more than at 云溪 (%d)" % game.sell_price("liaoshang_pill"))
	game.player.location = "nanming"
	check(game.Inventory.sale_value(game, "liaoshang_pill", 12) < first * 12, "the premium fades as the need fills")
	var stones := int(game.player.stones)
	game.sell("liaoshang_pill", 8)
	check(int(game.player.stones) - stones < first * 8 and game.sell_price("liaoshang_pill") <= first / 2, "eight sold fill it (%d left)" % game.sell_price("liaoshang_pill"))
	var copy := _reload(game)
	check(copy.sell_price("liaoshang_pill") == game.sell_price("liaoshang_pill"), "the filled need survives a save")
	game.world.day = int(game.world.day) + 60
	check(game.sell_price("liaoshang_pill") == first, "two months later the mines need salves again")
