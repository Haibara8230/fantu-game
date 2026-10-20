extends SceneTree
## 五城成形 (docs/GAME_OUTLINE.md 20, batch 4): 沧澜城, 望海城 and their wilds, the second trade between
## cities, 客卿 and the four sects' own stories, 叶知微's master and 闻人照's chart, 五宗论道 in five
## cities, 《照水分光诀》 and 听潮剑, and the preparing of a 金丹. Each part plays through the rules a player
## would use, and survives a save.
const Session = preload("res://scripts/core/session.gd")
const Calendar = preload("res://scripts/core/calendar.gd")
const TC2 := "e:tingchao:2:water::0"
const TC3 := "e:tingchao:3:water::0"
const TC4 := "e:tingchao:4:water::0"
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
	_demand()
	_guest()
	_zhaoshui()
	_tingchao()
	_caves()
	_sects()
	_ye()
	_wenren()
	_wuzong()
	_jindan()
	print("WUCHENG: %d checks, %d failures" % [checks, failures])
	quit(0 if failures == 0 else 1)

func _game(start: String = "free", seed_value: int = 31, roots: Array = ["metal", "wood", "water"]) -> Session:
	var game := Session.new()
	game.encounters_enabled = false
	game.new_game("五城", seed_value, roots, start)
	return game

## A cultivator of `realm`, healthy and with stones for the road; 天南 known.
func _found(game: Session, stage: int = 0, realm: int = 1) -> void:
	game.player.realm = realm
	game.player.stage = stage
	game.player.xp = int(game.content.stage(realm, stage).xp)
	game.player.mind = 300
	game.refresh_realm_stats()
	game.player.hp = game.player.max_hp
	game.player.qi = game.player.max_qi
	game.player.stones = 5000
	game.world.flags["tiannan_known"] = true

func _at(game: Session, year: int, month: int = 1, day: int = 1) -> void:
	game.world.day = Calendar.to_day(year, month, day)

## Stands at `place` and lets a day pass there, so what happens there happens.
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

func _reload(game: Session) -> Session:
	var copy := Session.new()
	check(copy.restore(JSON.parse_string(JSON.stringify(game.snapshot()))), "the journey survives a save")
	return copy

func _befriend(game: Session, person_id: String, relation: int) -> void:
	game.mark_met(person_id)
	game.world.people[person_id].relation = relation

## 沧澜城, 望海城, 近海群岛 and 毒泽: hidden until 天南 is known, each with its roads and rooms.
func _geography() -> void:
	var game := _game()
	for place: String in ["canglan", "wanghai", "jinhai", "duze"]:
		check(not game.location_visible(place), "%s stays hidden until 天南 is known" % place)
	_found(game)
	for place: String in ["canglan", "wanghai", "jinhai", "duze"]:
		check(game.location_visible(place), "%s is on the map once 天南 is known" % place)
	var all := {}
	for flag: String in game.content.world_flags:
		all[flag] = true
	check(game.content.find_path("canglan_pavilion", "canglan", all, 0).size() == 2, "沧澜城 lies a day below 沧澜阁")
	check(game.content.find_path("nanming", "jinhai", all, 0).size() == 3, "the islands are reached through 望海")
	var sea: Dictionary = game.content.route_between("wanghai", "jinhai")
	check(int(sea.get("fee", 0)) == 20 and int(sea.days) == 2, "a sea-boat to the islands costs twenty stones")
	check(not game.content.route_between("ferry", "wanghai").is_empty(), "白鹭渡's river runs down to 望海")
	for place: String in ["canglan", "wanghai"]:
		game.player.location = place
		check(game.available_here("cultivate") and game.available_here("inn_rest") and int(game.Cultivation.rent(game, 30)) == 10, "%s's inn lets a room by the month" % place)
		check(game.available_here("commissions"), "%s has a board" % place)
	game.player.location = "wanghai"
	check(game.Inventory.shop_goods(game).any(func(good: Dictionary) -> bool: return str(good.item) == TC2), "望海's sea market has a rusted sword for sale")
	check(game.content.item(TC2).name == "锈蚀的听潮剑" and game.content.item(TC4).name == "听潮剑", "听潮剑 has a name at each stage")
	check(game.content.equipment("e:tingchao:1:water::0").is_empty() and game.content.equipment("e:tingchao:5:water::0").is_empty(), "and no stage it was never mended to")
	var rng := RandomNumberGenerator.new()
	var generated := false
	for index: int in 200:
		rng.seed = index
		generated = generated or game.Arsenal.generate_equipment(game.content, rng, 3).contains("tingchao")
	check(not generated, "nobody forges or finds another 听潮剑 by chance")

## The second trade: 望海's shells sell dear in 沧澜, its fleet pays twice for salves.
func _demand() -> void:
	var game := _game()
	_found(game)
	game.add_item("hai_lingbei", 10)
	game.add_item("liaoshang_pill", 10)
	game.player.location = "wanghai"
	var at_sea: int = game.sell_price("hai_lingbei")
	var salve_sea: int = game.sell_price("liaoshang_pill")
	game.player.location = "canglan"
	var at_city: int = game.sell_price("hai_lingbei")
	check(at_city > at_sea, "沧澜's 丹会 pays more for a shell than 望海 does (%d > %d)" % [at_city, at_sea])
	game.player.location = "market"
	check(salve_sea > game.sell_price("liaoshang_pill"), "望海's fleet pays more for salves than 云溪 (%d)" % salve_sea)
	game.player.location = "nanming"
	check(game.sell_price("hai_lingbei") > at_sea, "and 南明's forges want shells too")

## 客卿: asked, taken up at the gate, paid, sent on errands, and let go when the errands lapse.
func _guest() -> void:
	var game := _game()
	_found(game)
	game.player.location = "chixiao_gate"
	check(game.Guest.sect_here(game) == "chixiao" and game.Guest.block(game, "chixiao").contains("邀"), "without an invitation 赤霄 has no place for a guest")
	game.world.flags["guest_invite_chixiao"] = true
	game.guest_accept()
	check(game.Guest.of(game) == "chixiao" and game.has_flag("guest_chixiao"), "invited, the player stands as 赤霄's 客卿")
	check(game.available_here("cultivate") and game.available_here("breakthrough"), "and may retreat in its guest house")
	check(game.Forge.fee(game, "ore_xuantie") == 0, "赤霄's furnace asks its guest no fee")
	game.player.location = "nanming"
	check(game.Forge.fee(game, "ore_xuantie") > 0, "elsewhere the fee stands")
	game.player.location = "chixiao_gate"
	check(not game.Guest.block(game, "xuanyue").is_empty(), "one sect at a time")
	var stones := int(game.player.stones)
	game.wait(65)
	check(int(game.player.stones) - stones == 40, "two months pay forty stones (%d)" % (int(game.player.stones) - stones))
	game.world.day = int(game.player.guest.next_call) - 1
	game.wait(2)
	var errands: Array = game.player.quests.filter(func(quest: Dictionary) -> bool: return str(quest.get("guest", "")) == "chixiao")
	check(errands.size() == 1 and int(errands[0].deadline) - int(game.player.guest.next_call) < 0, "three years on, a 差遣 comes with a year to report")
	var copy := _reload(game)
	check(copy.Guest.of(copy) == "chixiao" and copy.player.quests.any(func(quest: Dictionary) -> bool: return quest.has("guest")), "the bond and its errand survive a save")
	game.world.day = int(errands[0].deadline) + 1
	game.wait(1)
	check(game.Guest.of(game) == "chixiao" and int(game.player.guest.missed) == 1, "a lapsed errand is counted")
	game.world.day = int(game.player.guest.next_call) + 400
	game.wait(1)
	check(game.Guest.of(game).is_empty() and game.has_flag("guest_ended_chixiao") and not game.has_flag("guest_chixiao"), "a second lapse breaks the bond")
	check(not game.Guest.invited(game, "chixiao"), "and 赤霄 asks no more")
	# 沧澜's shops sell to their guest for less; 玄岳 opens the archive.
	var water := _game()
	_found(water)
	water.player.location = "canglan"
	var full: int = water.Inventory.shop_goods(water).filter(func(good: Dictionary) -> bool: return str(good.item) == "ningdan_yaolue")[0].price
	water.world.flags["guest_invite_canglan"] = true
	water.player.location = "canglan_pavilion"
	water.guest_accept()
	water.player.location = "canglan"
	var less: int = water.Inventory.shop_goods(water).filter(func(good: Dictionary) -> bool: return str(good.item) == "ningdan_yaolue")[0].price
	check(less == int(round(full * 0.8)), "沧澜's guest buys at eight tenths (%d of %d)" % [less, full])
	water.guest_leave()
	check(water.Guest.of(water).is_empty() and water.Guest.invited(water, "canglan"), "laid down, the invitation stays")
	var stone := _game()
	_found(stone)
	stone.world.flags["tiannan_champion"] = true
	stone.player.location = "xuanyue_gate"
	check(stone.Guest.invited(stone, "chixiao") and stone.Guest.invited(stone, "xuanyue"), "天南大比's champion is asked by all four")
	stone.guest_accept()
	check(stone.has_flag("archive_pass"), "玄岳 gives its guest the archive's door")
	var disciple := _game("plain", 41)
	_found(disciple)
	disciple.world.flags["guest_invite_xuanyue"] = true
	disciple.player.location = "xuanyue_gate"
	check(disciple.Guest.block(disciple, "xuanyue").contains("宗门弟子"), "a 青云 disciple cannot be another sect's guest")

## 《照水分光诀》: seen on the water, the first half bought, the second taught; water and metal answer.
func _zhaoshui() -> void:
	var game := _game()
	_found(game)
	_stop(game, "canglan")
	check(game.has_flag("zhaoshui_seen") and game.story_state("zhaoshui") == "active" and game.world.people.bai_tinglan.met, "on the 水榭 白听澜's sword runs water into metal")
	game.buy("zhaoshui_canpian")
	game.wait(1)
	check(game.story_at("zhaoshui", "complete"), "the first half is bought at the 药市")
	game.player.location = "canglan_pavilion"
	_befriend(game, "bai_tinglan", 90)
	game.add_item("chaoxin_shi", 1)
	game.interact("bai_tinglan", "zhaoshui_teach")
	game.wait(1)
	check(game.story_state("zhaoshui") == "done" and game.item_count("j:zhaoshui") == 1 and game.item_count("zhaoshui_canpian") == 0, "a 潮心石 for the second half: the slip is whole")
	check(game.has_flag("guest_invite_canglan"), "and 沧澜 asks the heir of its water sword to stay")
	var t: Dictionary = game.content.technique("zhaoshui")
	check(t.slot == "method" and t.tier_name == "玄阶" and t.description.contains("连击"), "a 玄阶 心法 that tells of its 连击")
	# Water and metal answer each other.
	for holds: bool in [false, true]:
		var duel := _game()
		_found(duel)
		duel.player.learned.append_array(["sword", "water"])
		duel.player.arts = ["sword", "water"]
		duel.player.methods = ["zhaoshui"] if holds else []
		duel.begin_battle("reef_crab", "event")
		duel.battle.orbs = ["metal", "metal", "metal", "metal"]
		duel.battle.last = "water"
		var sword: Dictionary = duel.held_technique("sword")
		check(duel.Combat.combo_holds(duel, sword) == holds, "a metal art after a water one is a 连击 %s 照水" % ("with" if holds else "without"))
		duel.use_skill("sword")
		check(("water" in duel.battle.orbs) == holds, "and the linked 连击 draws water back in (%s)" % str(duel.battle.orbs))

## 听潮剑: bought rusted, its story found in 沧澜, mended twice; the tide fills the hand by water.
func _tingchao() -> void:
	var game := _game()
	_found(game, 2)
	game.player.location = "wanghai"
	game.buy(TC2)
	check(game.item_count(TC2) == 1, "a rusted sword for three hundred stones")
	_stop(game, "canglan")
	check(game.story_state("tingchao") == "active" and game.has_flag("tingchao_known"), "沧澜's books tell whose sword it was")
	check(game.story_at("tingchao", "mend1"), "and how to mend it")
	game.add_item("ore_xuantie", 2)
	game.add_item("hai_lingbei", 2)
	_stop(game, "nanming")
	check(game.pending_event.get("id", "") == "tingchao_mend1", "万宝楼's smith looks it over")
	game.choose_event("mend")
	check(game.item_count(TC2) == 0 and game.item_count(TC3) == 1 and game.story_at("tingchao", "mend2"), "the rust is off")
	game.equip_item(TC3)
	check(str(game.player.equipment.get("weapon", "")) == TC3, "worn")
	game.add_item("chaoxin_shi", 1)
	game.add_item("dihuo_jing", 2)
	_stop(game, "chixiao_gate")
	check(game.pending_event.get("id", "") == "tingchao_mend2", "赤霄's smith can set its heart")
	game.choose_event("mend")
	check(str(game.player.equipment.weapon) == TC4 and game.story_state("tingchao") == "done", "听潮剑 is whole, still in hand")
	check(game.content.item(TC4).description.contains("临水"), "its words tell of the tide")
	game.player.location = "wanghai"
	game.begin_battle("reef_crab", "event")
	check(game.Combat.tide_orbs(game) == 1, "a 筑基 draws on only part of a 法宝: one water orb more")
	game.battle.clear()
	_found(game, 0, 2)
	game.begin_battle("reef_crab", "event")
	check(game.Combat.tide_orbs(game) == 2 and game.battle.orbs.count("water") >= 2, "by the sea the duel opens with two water orbs more (%s)" % str(game.battle.orbs))
	game.battle.clear()
	game.player.location = "nanming"
	game.begin_battle("reef_crab", "event")
	check(game.Combat.tide_orbs(game) == 0, "inland, none")
	game.battle.clear()
	var copy := _reload(game)
	check(str(copy.player.equipment.weapon) == TC4, "the mended sword survives a save")

## The new places to explore: the lost garden, the wreck, the fire eye and the sword tomb.
func _caves() -> void:
	var game := _game()
	_found(game)
	game.player.location = "duze"
	check(game.cave_here("heart") == "lost_garden", "毒泽's heart can be explored at 筑基")
	for room: String in ["path", "pond", "shed"]:
		game.player.hp = game.player.max_hp
		game.enter_room("lost_garden", room)
		_win(game)
	check(game.has_flag("garden_cleared") and game.has_flag("garden_seeds_found") and game.item_count("huitian_cao") == 1, "the 瘴蟒 falls; the seed box and a 回天草 wait in the old herb hut")
	var sea := _game()
	_found(sea)
	sea.player.location = "jinhai"
	check(sea.cave_here("wreck") == "chenchuan", "the wreck can be dived at 筑基")
	for room: String in ["hold", "keel", "gate"]:
		sea.player.hp = sea.player.max_hp
		sea.enter_room("chenchuan", room)
		_win(sea)
	check(sea.has_flag("wreck_cleared") and sea.has_flag("zhaoshui_found") and sea.has_flag("chart_verified"), "past the drowned ghost: the second half of 照水, and the stone gate")
	check(sea.item_count(TC2) == 1, "听潮剑 lies in its case (%s)" % str(sea.player.items))
	sea.collect_room("chenchuan", "hold")
	check(sea.item_count("chaoxin_shi") >= 1, "the ghost fallen, a 潮心石 is taken from the hold")
	var fire := _game()
	_found(fire)
	fire.player.location = "chifeng"
	fire.world.flags["dihuo_lizard_down"] = true
	fire.world["caves"] = {"dihuo": {"explored": ["mouth", "tunnel", "nest", "core"], "taken": [], "fortune": {}}}
	fire.enter_room("dihuo", "fire_eye")
	_win(fire)
	check(fire.has_flag("fire_eye_seen"), "the fire eye's spirit falls")
	var tomb := _game()
	_found(tomb, 0, 2)
	tomb.player.location = "duanjian"
	tomb.world.flags["duanjian_ling_down"] = true
	tomb.world["caves"] = {"duanjian": {"explored": ["mouth", "swords"], "taken": [], "fortune": {}}}
	tomb.enter_room("duanjian", "tomb")
	_win(tomb)
	check(tomb.has_flag("tomb_reached") and str(tomb.Caves.room(tomb, "duanjian", "tomb").text).contains("门后有城"), "the tomb's sword will gives way to a stone: a door, a city")

## The four sects' own stories, each ending in an invitation (or not).
func _sects() -> void:
	# 赤霄: the fire fades; a choice put off asks again another day; 以阵导火 needs 秦砚's 阵谱.
	var game := _game()
	_found(game)
	_at(game, 25, 3, 1)
	_stop(game, "chixiao_gate")
	check(game.story_state("chixiao_fire") == "active" and game.world.people.yan_qianqiu.met, "历元二十五年 赤霄's furnace burns low")
	game.world.flags["fire_eye_seen"] = true
	game.player.location = "chifeng"
	game.wait(1)
	check(game.story_at("chixiao_fire", "decide") and game.pending_event.is_empty(), "the choice waits for 赤霄's gate")
	_stop(game, "chixiao_gate")
	check(game.pending_event.get("id", "") == "chixiao_choice" and not game.choice_available(game.pending_definition().choices[2]), "there; without the 阵谱 no array")
	game.choose_event("later")
	game.Storylines.update(game)
	check(game.pending_event.is_empty(), "put off, it does not ask again the same day")
	game.wait(1)
	check(game.pending_event.get("id", "") == "chixiao_choice", "but asks the next")
	game.choose_event("divert")
	check(game.story_state("chixiao_fire") == "done" and game.Guest.invited(game, "chixiao"), "the fire drawn back; 赤霄 asks the player to stay")
	game.world.flags["spirit_eye_found"] = true
	game.player.location = "wild"
	var parts: Array = game.Breakthrough.odds(game, {"pills": 0, "treasure": "", "guard": ""}).parts
	check(parts.any(func(part: Array) -> bool: return str(part[0]).contains("泉脉不稳") and int(part[1]) == 5), "and 落霞谷's eye is less steady for it")
	# 长青: the seed box.
	var herb := _game()
	_found(herb)
	_at(herb, 50, 1, 1)
	_stop(herb, "changqing_valley")
	check(herb.story_state("changqing_garden") == "active", "历元五十年 the old garden shows in the marsh")
	herb.world.flags["garden_seeds_found"] = true
	_stop(herb, "changqing_valley")
	check(herb.pending_event.get("id", "") == "garden_choice", "the box brought back")
	herb.choose_event("return_burn")
	check(herb.has_flag("garden_returned") and herb.has_flag("recipe_burned") and herb.Guest.invited(herb, "changqing"), "returned, the 借命方 burnt")
	# 玄岳: the sword tomb; 断剑门's heir may keep it only after his case is cleared.
	var stone := _game()
	_found(stone, 0, 2)
	_at(stone, 60, 1, 1)
	_stop(stone, "xuanyue_gate")
	check(stone.story_state("xuanyue_tomb") == "active", "a 金丹 is asked to look into the tomb")
	stone.world.flags["tomb_reached"] = true
	_stop(stone, "xuanyue_gate")
	check(stone.pending_event.get("id", "") == "xuanyue_choice" and not stone.choice_available(stone.pending_definition().choices[1]), "without 柳寒舟's case cleared, no keeping for his sect")
	stone.world.flags["liu_redress"] = true
	check(stone.choice_available(stone.pending_definition().choices[1]), "with it, he may keep the tomb")
	stone.choose_event("liu")
	check(stone.has_flag("tomb_liu") and stone.story_state("xuanyue_tomb") == "done", "断剑门 keeps its tomb")

## 叶知微's master: a letter in 历元七十年, a choice before the year's end, what each choice leaves.
func _ye() -> void:
	var game := _game()
	_found(game)
	game.mark_met("ye_zhiwei")
	_at(game, 70, 1, 1)
	game.wait(1)
	check(game.story_state("ye_master") == "active" and game.world.letters.any(func(letter: Dictionary) -> bool: return str(letter.get("story", "")) == "ye_master"), "历元七十年 her letter: the master's years are short")
	_stop(game, "canglan")
	check(game.has_flag("ye_crisis") and game.pending_event.get("id", "") == "ye_choice", "at 丹会: the 借命方, or a 回天草")
	check(not game.choice_available(game.pending_definition().choices[0]), "without 回天草 there is no 续元丹")
	game.choose_event("later")
	game.add_item("huitian_cao", 1)
	game.wait(1)
	game.choose_event("cure")
	check(game.has_flag("ye_cure") and game.item_count("huitian_cao") == 0 and game.story_state("ye_master") == "done", "the herb given, ten more years")
	_at(game, 75)
	check(game.person("ye_zhiwei").title == "守底线的丹师" and game.npc_location("ge_qingnang") == "canglan", "she keeps to her line; her master still sees patients")
	_at(game, 83)
	check(game.person("ge_qingnang").realm_text == "已坐化" and game.npc_location("ge_qingnang").is_empty(), "the ten years spent, he is gone")
	_at(game, 86)
	check(game.person("ye_zhiwei").realm_text == "金丹初期", "and she forms her 金丹")
	var late := _game()
	_found(late)
	late.mark_met("ye_zhiwei")
	_at(late, 70, 1, 1)
	late.wait(1)
	_at(late, 71, 12, 25)
	late.wait(10)
	check(late.has_flag("ye_late") and late.story_state("ye_master") == "closed", "never answered: the master dies in 历元七十二年")
	check(late.person("ye_zhiwei").title == "整理遗方的丹师", "she sorts his recipes and never uses the forbidden one")

## 闻人照's chart: proven at the stone gate, a ship made ready, a voyage, and no word after.
func _wenren() -> void:
	for together: bool in [false, true]:
		var game := _game()
		_found(game)
		game.mark_met("wenren_zhao")
		_at(game, 110, 1, 1)
		game.wait(1)
		check(game.story_state("wenren_chart") == "active", "历元一百十年 his letter: the chart is real")
		_stop(game, "wanghai")
		check(game.has_flag("wenren_chart") and game.story_at("wenren_chart", "verify"), "at the dock: a gate drawn under the wreck")
		game.world.flags["chart_verified"] = true
		game.wait(1)
		_stop(game, "wanghai")
		check(game.pending_event.get("id", "") == "wenren_ship", "back at the dock, the ship to make ready")
		game.choose_event("together" if together else "supplies")
		check(game.has_flag("wenren_together" if together else "wenren_supplied"), "the help given is remembered")
		_found(game, 0, 2)
		_at(game, 130, 2, 1)
		game.wait(1)
		_stop(game, "wanghai")
		check(game.pending_event.get("id", "") == "wenren_sail", "in 历元一百三十年 the sails are up")
		check(game.choice_available(game.pending_definition().choices[0]) == together, "only one who promised boards")
		game.choose_event("board" if together else "see_off")
		if together:
			check(str(game.battle.get("enemy_id", "")) == "hai_jiao", "at sea a 海蛟 rises in the storm")
			_win(game)
			check(game.has_flag("wenren_storm"), "the ship breaks apart")
		check(game.story_state("wenren_chart") == "done", "he sails")
		_at(game, 130, 5, 25)
		game.wait(10)
		check(game.has_flag("wenren_lost") and game.npc_location("wenren_zhao").is_empty() and game.person("wenren_zhao").title == "出海未归", "by summer no word comes back")

## 五宗论道: in turn in five cities in the tenth month; who may stand up, and what the others do.
func _wuzong() -> void:
	var game := _game()
	var entry: Dictionary = game.content.events.five_sects_entry
	var places: Array = []
	for occurrence: int in 6:
		places.append(game.Events.venue(entry, {"occurrence": occurrence}))
	check(places == ["canglan", "nanming", "beiyue", "wanghai", "market", "canglan"], "沧澜, 南明, 北岳, 望海, 云溪, and round again (%s)" % str(places))
	_found(game, 0, 2)
	game.player.location = "nanming"
	_at(game, 120, 10, 2)
	game.wait(1)
	check(game.pending_event.get("id", "") != "five_sects_entry", "历元一百二十年 it is not held in 南明")
	_stop(game, "canglan")
	check(game.pending_event.get("id", "") == "five_sects_entry", "but in 沧澜城")
	var enter: Dictionary = game.pending_definition().choices[0]
	check(not game.choice_available(enter), "a wanderer with nobody to vouch only watches")
	game.world.flags["guest_invite_canglan"] = true
	game.player.guest = {"sect": "canglan", "since": 0, "pay_day": int(game.world.day), "next_call": int(game.world.day) + 1000, "missed": 0}
	check(game.choice_available(enter), "沧澜's guest may stand for it")
	game.choose_event("enter")
	check(str(game.battle.get("contest", "")) == "wuzong" and str(game.battle.foe.name).contains("炎千秋"), "the first round: 赤霄's 炎千秋")
	_win(game)
	check(game.has_flag("wuzong_champion") and game.Trials.score(game, "wuzong", 120) == 4, "four rounds won, the crown kept in the trials")
	var trade := _game()
	_found(trade, 0, 2)
	_at(trade, 180, 10, 3)
	trade.player.location = "nanming"
	trade.wait(1)
	check(trade.pending_event.get("id", "") == "five_sects_entry", "历元一百八十年 it is 南明's turn")
	trade.choose_event("mentor")
	check(trade.has_flag("wuzong_mentor"), "the young are taught for ten days")
	trade.wait(1)
	check(trade.pending_event.get("id", "") == "wuzong_trade", "the trading floor opens beside it")
	check(not trade.choice_available(trade.pending_definition().choices[1]), "with nothing to show, the stand stays empty")
	trade.add_item("e:sword:4:none::0", 1)
	var stones := int(trade.player.stones)
	trade.choose_event("show")
	check(trade.has_flag("wuzong_shown") and int(trade.player.stones) - stones == 300, "a 法宝 on the stand draws three hundred stones")
	var nascent := _game()
	_found(nascent, 0, 3)
	check(nascent.Summit.levels(nascent, nascent.content.summit_data.wuzong)[0][0] == 3, "a 元婴 meets the 元婴 group")
	var prep := _game()
	_found(prep, 0, 2)
	prep.world.flags["wuzong_notice"] = true
	prep.wait(1)
	check(prep.story_state("wuzong_prep") == "active", "a 金丹 hears of it and makes ready")

## 结丹之备: a wanderer is sent to 沧澜's books; 《凝丹要略》 adds to the odds and the grade.
func _jindan() -> void:
	var game := _game()
	_found(game, 2)
	game.wait(1)
	check(game.story_state("jindan_plan") == "active", "筑基后期: 沈墨 writes about the 金丹")
	_stop(game, "canglan")
	check(game.story_at("jindan_plan", "prep"), "沧澜's old scholar tells what to prepare")
	game.buy("ningdan_yaolue")
	game.use_item("ningdan_yaolue")
	check(game.has_flag("ningdan_known"), "《凝丹要略》 read")
	game.wait(1)
	check(game.story_state("jindan_plan") == "done", "one preparation is enough to call it ready")
	game.player.stage = 3
	game.player.xp = 200000
	game.player.location = "canglan"
	var odds: Dictionary = game.Breakthrough.odds(game, {"pills": 0, "treasure": "", "guard": ""})
	check(odds.parts.any(func(part: Array) -> bool: return str(part[0]) == "凝丹之法" and int(part[1]) == 10) and "凝丹之法" in odds.steps, "凝丹之法 adds ten and a grade to forming the 金丹")
	var low := _game()
	_found(low, 2)
	low.world.flags["ningdan_known"] = true
	low.player.realm = 0
	low.player.stage = 3
	check(not low.Breakthrough.odds(low, {"pills": 1, "treasure": "", "guard": ""}).parts.any(func(part: Array) -> bool: return str(part[0]) == "凝丹之法"), "it counts for nothing at 筑基")
	var disciple := _game("plain", 41)
	check(disciple.content.sect_data.exchange.any(func(good: Dictionary) -> bool: return str(good.item) == "ningdan_yaolue"), "青云's hall trades the book for contribution")
	_found(disciple, 2)
	disciple.player.location = "sect"
	disciple.wait(1)
	check(disciple.story_state("jindan_sect") == "active" and disciple.story_state("jindan_plan") != "active", "a 青云 disciple hears it from 顾长庚 instead")
