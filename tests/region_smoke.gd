extends SceneTree
## M2 acceptance: node map, journeys, road encounters, scenes, the hidden ruin, saves and audio.
const Session = preload("res://scripts/core/session.gd")
const Content = preload("res://scripts/core/content.gd")
const AudioDirector = preload("res://scripts/presentation/audio_director.gd")
const ArtLibrary = preload("res://scripts/ui/art_library.gd")
const SaveStore = preload("res://scripts/core/save_store.gd")
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
	call_deferred("_run")

func _run() -> void:
	_static_checks()
	_paths()
	_journeys()
	_encounters()
	_flight()
	_scenes()
	_ruin()
	_azhi()
	_people()
	_saves()
	_tiannan()
	_tiannan_market()
	_tiannan_sects()
	await _tiannan_screens()
	await _audio()
	_art()
	print("REGION: %d checks, %d failures" % [checks, failures])
	quit(0 if failures == 0 else 1)

func _game(seed_value: int, encounters := false) -> Session:
	var game := Session.new()
	game.encounters_enabled = encounters
	game.new_game("行者", seed_value)
	return game

## 御剑飞行: from 金丹 the roads take half the days, and nothing on them troubles the traveller.
func _flight() -> void:
	var walker := _game(71, true)
	var flier := _game(71, true)
	flier.player.realm = 2
	flier.refresh_realm_stats()
	var route: Dictionary = walker.content.route_between("sect", "town")
	check(flier.route_days(route) == maxi(1, int(round(float(walker.route_days(route)) * 0.5))), "a 金丹 flies the road in half the days")
	for chance: int in flier.content.rules.encounter_chance.size():
		flier.content.rules.encounter_chance[chance] = 1.0
	for trip: int in 4:
		flier.travel("wild" if trip % 2 == 0 else "sect")
	check(flier.battle.is_empty() and not str(flier.pending_event.get("id", "")).begins_with("road_") and not flier.journal_lines().any(func(line: String) -> bool: return line.contains("拦路")), "nothing on the road troubles one in flight")
	check(flier.journal_lines().any(func(line: String) -> bool: return line.contains("御剑而行")), "and the record says so")

func _texts(game: Session) -> String:
	return "\n".join(game.journal_lines())

func _broken(change: Callable) -> String:
	var content := Content.new()
	content.load_data()
	change.call(content)
	return content._validate()

func _static_checks() -> void:
	var content := Content.new()
	check(content.load_data(), "shipped region passes static checks: " + content.error_message)
	check(_broken(func(c) -> void: c.routes.append({"between": ["sect", "moon"], "days": 1, "danger": 0})).contains("未知地点"), "route to unknown place reported")
	check(_broken(func(c) -> void: c.routes[0].danger = 7).contains("危险度"), "danger out of range reported")
	check(_broken(func(c) -> void: c.locations.islet = {"name": "孤岛", "subtitle": "", "description": "", "terrain": "ferry", "map": [0.9, 0.1], "spots": [{"id": "a", "name": "滩", "actions": []}]}).contains("无法到达"), "unreachable place reported")
	check(_broken(func(c) -> void: c.locations.town.spots[0].actions.append("fly")).contains("未知行为"), "unknown scene action reported")
	check(_broken(func(c) -> void: c.locations.town.spots[0].actions.append("battle:dragon")).contains("未知敌人"), "unknown scene enemy reported")
	check(_broken(func(c) -> void: c.locations.sect.erase("map")).contains("地图坐标"), "missing coordinates reported")
	check(_broken(func(c) -> void:
		c.events.erase("teahouse_story")
		c.events.erase("valley_trail")
		c.people.storyteller.interactions = []).contains("永远无法发现"), "hidden place without any way to discover it reported")
	check(_broken(func(c) -> void: c.events.road_wolf.routes = [["sect", "market"]]).contains("不存在的路线"), "encounter on a missing road reported")
	check(_broken(func(c) -> void: c.events.road_wolf.erase("choices")).contains("需要选项"), "road encounters cannot be people stopping the player")
	check(_broken(func(c) -> void: c.people.peddler.home = "town").contains("二选一"), "a person either lives somewhere or follows a schedule")
	check(_broken(func(c) -> void: c.people.shen_mo.spot = "kitchen").contains("常驻场景"), "unknown home scene reported")
	check(_broken(func(c) -> void: c.people.peddler.schedule.append({"location": "moon", "days": 3})).contains("无效的一站"), "schedule stop at an unknown place reported")
	check(_broken(func(c) -> void: c.people.rogue.interactions[0].id = "talk").contains("唯一 ID"), "interactions cannot shadow built-in ones")

func _paths() -> void:
	var content := Content.new()
	content.load_data()
	var to_market := content.find_path("sect", "market", {})
	check(to_market == ["sect", "town", "ferry", "market"] and content.path_days(to_market) == 7, "shortest road to the market")
	check(content.find_path("sect", "wild", {}) == ["sect", "ridge", "wild"], "shortest road to the valley")
	check(content.find_path("sect", "ruin", {}).is_empty(), "undiscovered ruin unreachable")
	check(content.find_path("sect", "ruin", {"found_ruin": true}) == ["sect", "ridge", "wild", "ruin"], "discovered ruin reachable")
	check(content.find_path("market", "ridge", {}) == ["market", "ferry", "town", "ridge"], "eight days by the ferry beats nine through the valley")

func _journeys() -> void:
	var game := _game(1)
	game.travel("market")
	var legs: Array = game.chronicle.entries.filter(func(entry: Dictionary) -> bool: return entry.id == "travel")
	check(legs.map(func(entry: Dictionary) -> int: return int(entry.args.days)) == [2, 3, 2], "each leg recorded with its own days")
	check(game.player.location == "market" and game.player.journey.is_empty() and int(game.world.day) == 7, "journey completes")
	check(_texts(game).contains("老艄公") and _texts(game).contains("沈墨"), "plain events fire along the way and on arrival")
	check(game.travel("ruin") == "未知地点。", "cannot travel to an undiscovered place")
	# People are seen only where the player stops; passing through meets no one.
	var passing := _game(2)
	passing.travel("ferry")
	check(passing.player.location == "ferry" and not "storyteller" in passing.known_npcs(), "passing through town meets no one there")
	check("boatman" in passing.known_npcs(), "stopping at the ferry meets the boatman")
	passing.travel("town")
	check("storyteller" in passing.known_npcs() and passing.pending_event.is_empty(), "stopping in town meets the storyteller without any forced choice")
	passing.world.flags.helped_wanderer = true
	passing.travel("sect")
	passing.travel("ferry")
	check(_texts(passing).contains("三十灵石作谢"), "plain event fires while passing through")

## 天南 (docs/WORLD_EXPANSION.md, stage two, batch A): a region of its own on the map, opened after
## foundation by 顾长庚's 「南行」; the 传送阵 from the 云溪 market asks foundation and 40 stones a way,
## and a long road from the ferry asks nothing but the days.
func _tiannan() -> void:
	var content := Content.new()
	content.load_data()
	check(content.region_of("market") == "qingyun" and content.region_of("nanming") == "tiannan", "places belong to regions; those that name none, to the first")
	check(_broken(func(c) -> void: c.locations.nanming.region = "moon").contains("未知地区"), "an unknown region is reported")
	check(_broken(func(c) -> void: c.routes.back().fee = 0).contains("费用"), "a fee must be a number of stones")
	check(_broken(func(c) -> void: c.routes.back().realm = 9).contains("境界"), "a realm asked must exist")
	var opened := {"tiannan_known": true}
	check(content.find_path("market", "nanming", opened) == ["market", "nanming"], "the gate is the short way")
	check(content.find_path("market", "nanming", opened, 0) == ["market", "ferry", "chifeng", "nanming"], "before foundation only the long road is open")
	var game := _game(81)
	check(game.travel("nanming") == "未知地点。", "天南 is unknown at first")
	game.player.realm = 1
	game.refresh_realm_stats()
	game.world.flags.intro_done = true
	game.wait(1)
	check(game.story_state("south_journey") == "active", "after foundation 顾长庚 has word of the south")
	var waited := 0
	while not game.story_at("south_journey", "summon") and waited < 6:
		waited += 1
		game.wait(30)
	game.travel("sect")
	check(game.has_flag("tiannan_known") and game.story_at("south_journey", "visit"), "and at the hall he tells of it: 天南 opens")
	game.travel("market")
	game.player.stones = 30
	check(game.travel("nanming").contains("盘缠不足") and game.player.location == "market", "the gate wants its fee before setting out")
	game.player.stones = 100
	var day := int(game.world.day)
	game.travel("nanming")
	check(game.player.location == "nanming" and int(game.world.day) == day + 1 and int(game.player.stones) == 60, "one day and 40 stones through the gate")
	check(_texts(game).contains("经传送阵前往南明坊市"), "the fee is in the chronicle")
	check(game.story_state("south_journey") == "done", "arriving ends 南行")
	check(game.available_here("shop") and game.available_here("sell") and game.available_here("forge") and game.available_here("inquire"), "the market trades, forges and has news")
	check(not game.Inventory.shop_goods(game).filter(func(good: Dictionary) -> bool: return good.item == "ore_xuantie").is_empty(), "天南 sells what 灵器 are forged from")
	# Batch B: 天南 has people of its own, drawn from seats that were 'elsewhere' before.
	var southerners: Array = game.present_npcs().filter(func(person_id: String) -> bool: return game.is_generated(person_id))
	check(not southerners.is_empty() and southerners.all(func(person_id: String) -> bool: return str(game.life_by_id(person_id).region) == "tiannan"), "the market has people of its own, all of 天南 (%d)" % southerners.size())
	var talk: Array = game.person(southerners[0]).talk
	var all_talk: Array = []
	for lines: Array in game.content.population_data.region_talk.tiannan.values():
		all_talk.append_array(lines)
	check(talk.all(func(line: String) -> bool: return line in all_talk), "and they talk of 天南, not of 青云")
	game.travel("chixiao_gate")
	check(game.player.location == "chixiao_gate" and game.available_here("forge"), "赤霄门's foundry lends its fire")
	var disciples: Array = game.present_npcs().filter(func(person_id: String) -> bool: return game.is_generated(person_id) and str(game.life_by_id(person_id).kind) == "chixiao_disciple")
	check(disciples.size() >= 5 and game.person(disciples[0]).title == "赤霄门弟子", "赤霄门's own disciples live at its gate (%d)" % disciples.size())
	var home := _game(81)
	var fellows: Array = home.present_npcs().filter(func(person_id: String) -> bool: return home.is_generated(person_id))
	check(fellows.all(func(person_id: String) -> bool: return str(home.life_by_id(person_id).region) == "qingyun" and not game.content.population_data.kinds[home.life_by_id(person_id).kind].has("region")), "青云山's people stay as they were")
	# The long road home: no fee, no realm, eighteen days.
	var walker := _game(82)
	walker.world.flags.tiannan_known = true
	walker.travel("ferry")
	var start := int(walker.world.day)
	walker.travel("chifeng")
	check(walker.player.location == "chifeng" and int(walker.world.day) == start + 18, "a 炼气 disciple can walk the long road south")
	check(walker.path_to("market") == ["chifeng", "ferry", "market"], "and walks it back, the gate being closed to them")

## The other sects of 天南: 长青谷's herb garden (百年灵芝 now and then) and pill hall with a furnace to
## borrow, 沧澜阁's library of slips, 玄岳宗's training ground; each with disciples of its own.
func _tiannan_sects() -> void:
	var game := _game(85)
	game.player.realm = 1
	game.refresh_realm_stats()
	game.player.hp = game.player.max_hp
	game.player.stones = 800
	game.world.flags.tiannan_known = true
	for place: String in ["changqing_valley", "canglan_pavilion", "xuanyue_gate"]:
		check(not game.path_to(place).is_empty() and game.content.region_of(place) == "tiannan", place + " lies in 天南 and can be reached")
	game.travel("changqing_valley")
	check(game.available_here("gather") and game.available_here("alchemy") and game.available_here("shop"), "长青谷: a garden to gather in, a furnace to borrow, a pill shop")
	check(game.content.locations.changqing_valley.gather.table.any(func(entry: Dictionary) -> bool: return entry.item == "lingzhi"), "and its garden is another source of 百年灵芝")
	var gardeners: Array = game.present_npcs().filter(func(person_id: String) -> bool: return game.is_generated(person_id) and str(game.life_by_id(person_id).kind) == "changqing_disciple")
	check(not gardeners.is_empty(), "长青谷's own disciples live there")
	game.travel("canglan_pavilion")
	var slips: Array = game.Inventory.shop_goods(game).filter(func(good: Dictionary) -> bool: return str(good.item).begins_with("j:"))
	check(slips.size() == 5 and slips.all(func(good: Dictionary) -> bool: return int(game.content.item(good.item).tier) <= 3), "沧澜阁's library sells five slips a month, none above 玄阶")
	game.travel("xuanyue_gate")
	check(game.available_here("battle:yue_disciple"), "玄岳宗's training ground offers a bout with its disciples")
	game.start_battle("yue_disciple")
	check(game.battle.get("enemy_id", "") == "yue_disciple" and str(game.battle.get("opponent_sect", "")) == "xuanyue", "who fight with 玄岳's earth arts")

## Batch E: 南明坊市's rule against duels, a stone house let by the year for retreats far from home,
## and 万宝楼's board, open to anyone.
func _tiannan_market() -> void:
	var game := _game(84)
	game.player.realm = 1
	game.refresh_realm_stats()
	game.player.stones = 600
	game.world.flags.tiannan_known = true
	game.travel("nanming")
	check(_texts(game).contains("坊内不许斗法切磋"), "arriving, the market's rule is told")
	var local: Array = game.present_npcs().filter(func(person_id: String) -> bool: return game.is_generated(person_id))
	var spar := _option(game, str(local[0]), "spar")
	check(not spar.is_empty() and not bool(spar.available) and str(spar.reason).contains("不许斗法"), "no spar inside the market, and the rule says why (%s)" % spar.get("reason", ""))
	check(not game.available_here("cultivate"), "no retreat at the market before a house is let")
	var stones := int(game.player.stones)
	game.take_lease()
	check(game.available_here("cultivate") and game.available_here("breakthrough") and int(game.player.stones) == stones - 150, "150 stones let the stone house for a year: retreat, rest and breakthrough")
	var until: int = game.Leases.until(game, "nanming_abode")
	check(until == int(game.world.day) + 359, "the term runs a year from today")
	game.take_lease()
	check(game.Leases.until(game, "nanming_abode") == until + 360, "taking it again adds a year after the first")
	var kept := Session.new()
	check(kept.restore(JSON.parse_string(JSON.stringify(game.snapshot()))) and kept.Leases.until(kept, "nanming_abode") == until + 360 and kept.available_here("cultivate"), "the term survives a save")
	var held := int(game.item_count("huichun_grass"))
	game.advance_days(until + 361 - int(game.world.day))
	check(not game.available_here("cultivate") and game.Leases.until(game, "nanming_abode") == -1 and _texts(game).contains("租期满了"), "when the term ends the house closes and the chronicle says so")
	check(int(game.item_count("huichun_grass")) == held, "and nothing of the player's is lost with it")
	check(not game.commission_offers("nanming").is_empty() and game.available_here("commissions"), "万宝楼's board offers work to anyone")
	# 「此地」 recall: each record remembers where the player was, and a save keeps it.
	var here: Array = game.chronicle.entries.filter(func(entry: Dictionary) -> bool: return str(entry.get("at", "")) == "nanming").map(func(entry: Dictionary) -> String: return str(entry.id))
	check("lease_taken" in here and "event" in here and not "start" in here, "what happened at 南明坊市 is recalled there (%s)" % [here])
	var reloaded := Session.new()
	reloaded.restore(JSON.parse_string(JSON.stringify(game.snapshot())))
	check(reloaded.chronicle.entries.filter(func(entry: Dictionary) -> bool: return str(entry.get("at", "")) == "nanming").size() == here.size(), "and a save remembers where")
	var board: Array = game.commission_offers("nanming").map(func(offer: Dictionary) -> String: return str(offer.kind))
	check(board.all(func(kind: String) -> bool: return kind in ["fire_herbs", "fire_essence", "south_wolves", "fire_parts", "wanted"]), "of its own kinds (%s)" % [board])

## The map turns to 天南 on its own page, and the new places render (without their art yet).
func _tiannan_screens() -> void:
	var main = load("res://scenes/main.tscn").instantiate()
	var isolated := "res://.godot/region_saves_%d" % Time.get_ticks_usec()
	main.manual_store = SaveStore.new(isolated + "/manual")
	main.auto_store = SaveStore.new(isolated + "/auto")
	main.settings_path = isolated + "/settings.cfg"
	main.guide_path = isolated + "/guide.cfg"
	root.add_child(main)
	main.close_welcome()
	main.started = true
	main.guide_enabled = false
	main.session.encounters_enabled = false
	main.session.new_game("南行", 83, ["metal", "wood", "fire"])
	main.story = {}
	main.session.player.realm = 1
	main.session.refresh_realm_stats()
	main.session.world.flags.tiannan_known = true
	main.set_view("map")
	var tabs: Array = main.center.find_children("*", "Button", true, false).map(func(button: Button) -> String: return button.text)
	check(tabs.has("青云山周边（此处）") and tabs.has("天南"), "two regions known, two map pages (%s)" % [tabs])
	check(main.world_map.region == "qingyun" and not "nanming" in main.world_map.visible_ids(), "the map opens on the player's own region")
	main.set_map_region("tiannan")
	check(main.world_map.region == "tiannan" and main.world_map.visible_ids().has("nanming") and not main.world_map.visible_ids().has("sect"), "and turns to 天南")
	main.select_map_target("nanming")
	var told := "\n".join(main.center.find_children("*", "Label", true, false).map(func(label: Label) -> String: return label.text))
	check(told.contains("传送阵共 40 灵石") and told.contains("云溪坊市 → 南明坊市"), "the route tells the gate's fee (%s)" % told)
	main.session.player.realm = 0
	main.render()
	told = "\n".join(main.center.find_children("*", "Label", true, false).map(func(label: Label) -> String: return label.text))
	check(told.contains("南下远路") or told.contains("路线"), "before foundation the long road is offered instead")
	for location_id: String in ["nanming", "chifeng", "chixiao_gate"]:
		main.session.player.location = location_id
		main.set_view("place")
		await process_frame
		check(main.current_screen() == "place", location_id + " shows its place without its art yet")
	main.queue_free()
	await process_frame

func _single_encounter(game: Session, keep: String) -> void:
	for event_id: String in game.content.events.keys():
		if game.content.events[event_id].trigger == "route" and event_id != keep:
			game.content.events.erase(event_id)
	game.content.rules.encounter_chance = [1.0, 1.0, 1.0, 1.0]

func _encounters() -> void:
	var game := _game(3, true)
	var road: Dictionary = game.content.route_between("ridge", "wild")
	check(is_equal_approx(game.content.rules.encounter_chance[2], 0.3) and is_equal_approx(Session.Events.encounter_chance(game, road), 0.3), "danger sets the encounter chance")
	game.player.realm = 1
	check(is_equal_approx(Session.Events.encounter_chance(game, road), 0.18), "a higher realm makes roads safer")
	var a := _game(4, true)
	var b := _game(4, true)
	a.travel("market")
	b.travel("market")
	check(a.snapshot() == b.snapshot(), "encounters are reproducible from the seed")
	var stopped := _game(5, true)
	_single_encounter(stopped, "road_wolf")
	stopped.world.flags.found_ruin = true
	stopped.travel("ruin")
	check(stopped.player.location == "wild" and stopped.pending_event.get("id", "") == "road_wolf" and stopped.player.journey.get("to", "") == "ruin", "a beast ambush stops the journey on the road")
	stopped.choose_event("fight")
	check(stopped.battle.get("context", "") == "event" and stopped.battle.enemy_id == "wolf", "fighting the ambush")
	check(stopped.battle.get("place", "") == "road", "an ambush is fought on the road, not at the node reached")
	var day := int(stopped.world.day)
	# Fleeing may fail (遁逃 by the odds); a failed try costs the turn, not days.
	while not stopped.battle.is_empty():
		stopped.player.hp = stopped.player.max_hp
		stopped.flee()
	check(int(stopped.world.day) == day + 1, "a road skirmish costs a day, not a month")
	stopped.content.rules.encounter_chance = [0.0, 0.0, 0.0, 0.0]
	stopped.continue_journey()
	check(stopped.player.location == "ruin" and stopped.player.journey.is_empty(), "journey resumes to its destination")
	var lured := _game(6, true)
	_single_encounter(lured, "road_wolf")
	lured.set_item_count("huichun_grass", 1)
	lured.travel("wild")
	lured.travel("wild")
	check(lured.pending_event.get("id", "") == "road_wolf", "wolves wait on dangerous roads")
	lured.choose_event("lure")
	check(lured.battle.is_empty() and int(lured.herb_count()) == 0, "a herb buys a way around the wolf")
	var quiet := _game(7, true)
	_single_encounter(quiet, "road_wolf")
	quiet.travel("market")
	check(quiet.player.location == "market" and quiet.pending_event.is_empty(), "safe roads have no ambushes, and people never stop a journey")

func _scenes() -> void:
	var game := _game(8)
	check(game.act("gather") == "此地无法如此行事。", "no herbs to gather in the sect")
	game.travel("ridge")
	var herbs := int(game.herb_count())
	game.act("gather")
	check(int(game.herb_count()) - herbs >= 1 and int(game.herb_count()) - herbs <= 2, "the ridge yields its own amount")
	game.travel("town")
	game.player.hp = 10
	var stones := int(game.player.stones)
	var day := int(game.world.day)
	game.act("inn_rest")
	check(int(game.player.hp) == int(game.player.max_hp) and int(game.player.stones) == stones - 5 and int(game.world.day) == day + 1, "the inn heals for five stones and a day")
	check(game.cultivate(30) == "此地无法闭关，请回青云山静室。" and game.choose_sect("chixiao").contains("传功堂"), "retreat and study need their scenes")

func _ruin() -> void:
	var game := _game(9)
	game.travel("town")
	game.interact("storyteller", "story")
	check(game.has_flag("found_ruin") and game.location_visible("ruin"), "the storyteller reveals the ruin")
	game.travel("ruin")
	check(game.pending_event.is_empty() and "squatter" in game.present_npcs(), "the ruin is occupied, without a forced confrontation")
	check(game.act("search_ruin") == "此地无法如此行事。", "the stone room stays closed while he holds it")
	game.interact("squatter", "fight")
	check(game.battle.get("npc", "") == "squatter", "the duel remembers who it is with")
	game.battle.hp = 1
	game.use_skill("sword")
	check(game.has_flag("ruin_cleared") and _texts(game).contains("石室从此归于寂静"), "defeating the occupant clears the ruin")
	check(not "squatter" in game.present_npcs(), "the occupant is gone")
	var before := int(game.player.stones) + int(game.herb_count()) + int(game.item_count("foundation_pill"))
	game.act("search_ruin")
	check(int(game.player.stones) + int(game.herb_count()) + int(game.item_count("foundation_pill")) > before, "searching the stone room finds something")
	check(game.act("search_ruin").contains("后再来"), "the stone room needs time before another search")
	game.wait(90)
	check(not game.act("search_ruin").contains("后再来"), "searchable again after the cooldown")
	var trail := _game(10)
	trail.player.realm = 1
	trail.refresh_realm_stats()
	trail.travel("wild")
	check(trail.has_flag("found_ruin"), "a foundation cultivator finds the trail without the storyteller")

## 阿芷's line: a promise on the ridge, her father's basket in the cleared ruin, the token returned,
## the spring after the serpent; and the closed valley in between.
func _azhi() -> void:
	var game := _game(14)
	game.travel("ridge")
	check("azhi" in game.known_npcs() and game.pending_event.is_empty(), "the herb gatherer is met on the ridge without a forced scene")
	game.travel("town")
	game.travel("ridge")
	check(game.pending_event.is_empty(), "her worry waits for some trust")
	# Test setup: the favor of a few talks and gifts.
	game.world.people.azhi.relation = 20
	game.travel("town")
	game.travel("ridge")
	check(game.pending_event.get("id", "") == "azhi_father", "with enough trust she tells of her lost father")
	game.choose_event("promise")
	check(game.has_flag("azhi_promised"), "the promise is remembered")
	# Test setup: the ruin found and cleared (its own line, checked in _ruin).
	game.world.flags.found_ruin = true
	game.world.flags.ruin_cleared = true
	game.travel("ruin")
	check(game.pending_event.get("id", "") == "azhi_token", "the cleared stone room holds her father's basket")
	game.choose_event("take")
	check(game.item_count("azhi_token") == 1, "the token is carried as a keepsake")
	var pills: int = game.item_count("ningqi_pill")
	game.travel("ridge")
	check(_option(game, "azhi", "token").get("available", false), "she can be given the token")
	game.interact("azhi", "token")
	check(game.item_count("azhi_token") == 0 and game.has_flag("azhi_mourned") and game.item_count("ningqi_pill") == pills + 2 and game.favor("azhi") >= 65, "returning it settles her grief and earns her trust")
	check(_option(game, "azhi", "token").get("reason", "") == "此事已了。", "the token is returned only once")
	var herbs: int = game.item_count("huichun_grass")
	game.world.flags.serpent_slain = true
	game.travel("town")
	game.travel("ridge")
	check(_texts(game).contains("在泉边给父亲立了块木牌") and game.item_count("huichun_grass") == herbs + 3, "once the serpent is gone she visits the spring")
	# While the valley is sealed she cannot work, and can be helped through it.
	var sealed := _game(15)
	sealed.travel("ridge")
	sealed.world.flags.serpent_rampage = true
	# Those who would go into the sealed valley turn aside to the ridge meanwhile.
	var wanderers: Array = sealed.living_people().filter(func(person_id: String) -> bool: return sealed.is_generated(person_id) and sealed.Population.location_on(sealed.life_by_id(person_id), int(sealed.world.day)) == "wild")
	check(wanderers.is_empty() or wanderers.all(func(person_id: String) -> bool: return sealed.npc_location(person_id) == "ridge"), "people bound for the sealed valley turn aside to the ridge (%d)" % wanderers.size())
	sealed.player.stones = 40
	sealed.travel("town")
	sealed.travel("ridge")
	check(_texts(sealed).contains("采到的草连买米都不够"), "the sealed valley takes her living")
	check(_option(sealed, "azhi", "aid").get("available", false) and not _option(game, "azhi", "aid").get("available", true), "she can be helped only while the valley is sealed")
	sealed.interact("azhi", "aid")
	check(int(sealed.player.stones) == 20 and sealed.favor("azhi") == 15, "helping her costs twenty stones")

func _option(game: Session, person_id: String, option_id: String) -> Dictionary:
	for option: Dictionary in game.npc_options(person_id):
		if option.id == option_id:
			return option
	return {}

func _people() -> void:
	var game := _game(12)
	check(game.npc_location("shen_mo") == "market", "residents live at home")
	check(game.npc_location("peddler") == "town", "the peddler starts his round in town")
	game.advance_days(9)
	check(game.npc_location("peddler") == "market", "the peddler moves on by his schedule")
	game.advance_days(36)
	check(game.npc_location("peddler") == "market", "schedules repeat")
	# People never stop a journey, and are met only where the player stops.
	var walker := _game(13)
	walker.travel("market")
	check(walker.player.location == "market" and not "peddler" in walker.known_npcs(), "the peddler in town is not met while passing through")
	check("shen_mo" in walker.known_npcs(), "people where you stop become acquaintances")
	walker.travel("sect")
	check(walker.npc_location("shen_mo") == "market" and walker.npc_options("shen_mo").all(func(option: Dictionary) -> bool: return not option.available), "acquaintances can be located from afar but only approached in person")
	# Built-in and person-specific interactions.
	var trader := _game(14)
	trader.travel("town")
	check("peddler" in trader.present_npcs() and trader.pending_event.is_empty(), "the peddler is in town, waiting to be approached")
	trader.interact("peddler", "talk")
	check(trader.favor("peddler") == 2 and _texts(trader).contains("钱货郎：“小本买卖"), "talking raises favor and is recorded")
	check(_option(trader, "peddler", "talk").reason.contains("后再来"), "talking again has to wait")
	check(not _option(trader, "peddler", "buy_pill").available, "a pill needs seventy stones")
	trader.player.stones = 80
	trader.interact("peddler", "buy_pill")
	check(int(trader.item_count("foundation_pill")) == 1 and int(trader.player.stones) == 10 and _option(trader, "peddler", "buy_pill").reason.contains("本月这一份已售出"), "discounted pills share limited monthly stock")
	trader.set_item_count("huichun_grass", 1)
	trader.interact("peddler", "gift")
	check(trader.favor("peddler") == 5 and int(trader.herb_count()) == 0, "a gift of herbs raises favor")
	check(trader.content.favor_stage(40) == "相熟" and trader.content.favor_stage(200) == "亲密", "favor stages follow 觅长生")
	# A hostile rogue on the ridge: no talk, pay him off or fight.
	var road := _game(15)
	road.travel("ridge")
	var ids: Array = road.npc_options("rogue").map(func(option: Dictionary) -> String: return option.id)
	check("rogue" in road.present_npcs() and road.pending_event.is_empty() and not "talk" in ids and "fight" in ids, "the rogue is hostile but does not force a fight")
	road.interact("rogue", "pay")
	check(road.npc_location("rogue") == "" and int(road.player.stones) == 20, "paid off, he leaves for a while")
	road.advance_days(121)
	check(road.npc_location("rogue") == "ridge", "and returns to his round later")
	road.interact("rogue", "fight")
	check(road.battle.get("npc", "") == "rogue" and road.battle.opponent_sect == "chixiao", "fighting the rogue uses his own arts")
	road.battle.hp = 1
	road.use_skill("sword")
	check(road.battle.is_empty() and road.npc_location("rogue") == "", "a defeated rogue leaves")
	# The wounded cultivator appears in his window and leaves once healed.
	var forest := _game(16)
	forest.travel("ridge")
	check(not "wounded" in forest.present_npcs(), "not there before his window")
	forest.wait(30)
	check("wounded" in forest.present_npcs(), "there during his window")
	forest.set_item_count("huichun_grass", 2)
	forest.interact("wounded", "heal")
	check(forest.has_flag("helped_wanderer") and not "wounded" in forest.present_npcs() and "wounded" in forest.known_npcs(), "healed, he moves on and is remembered")

func _saves() -> void:
	for name: String in ["v3_wild.json", "v3_invited.json", "v3_pending_choice.json"]:
		var game := Session.new()
		var ok: bool = game.restore(JSON.parse_string(FileAccess.get_file_as_string("res://tests/fixtures/" + name)))
		check(ok and game.snapshot().version == Session.SAVE_VERSION and game.player.journey.is_empty() and game.player.cooldowns.is_empty(), "v3 save migrates: " + name)
	var pending := Session.new()
	pending.restore(JSON.parse_string(FileAccess.get_file_as_string("res://tests/fixtures/v3_pending_choice.json")))
	check(pending.pending_event.is_empty() and pending.favor("shen_mo") == 20, "retired pop-up dropped on migration; relation becomes favor")
	var v4_rogue := Session.new()
	check(v4_rogue.restore(JSON.parse_string(FileAccess.get_file_as_string("res://tests/fixtures/v4_road_rogue_pending.json"))) and v4_rogue.pending_event.is_empty() and v4_rogue.player.journey.get("to", "") == "wild", "v4 road rogue choice becomes a person on the road; the journey can go on")
	var v4_friend := Session.new()
	check(v4_friend.restore(JSON.parse_string(FileAccess.get_file_as_string("res://tests/fixtures/v4_teahouse_pending.json"))) and v4_friend.pending_event.is_empty() and v4_friend.favor("shen_mo") == 40, "v4 shopkeeper relation 2 becomes favor 40, keeping the introduction")
	var v4_ruin := Session.new()
	check(v4_ruin.restore(JSON.parse_string(FileAccess.get_file_as_string("res://tests/fixtures/v4_ruin_searched.json"))) and v4_ruin.has_flag("ruin_cleared") and int(v4_ruin.player.cooldowns.get("search_ruin", 0)) > 0 and not "squatter" in v4_ruin.present_npcs(), "v4 cleared ruin stays cleared")
	var walker := _game(11, true)
	_single_encounter(walker, "road_wolf")
	walker.world.flags.found_ruin = true
	walker.travel("ruin")
	var midway: Dictionary = walker.snapshot()
	var copy := Session.new()
	check(copy.restore(JSON.parse_string(JSON.stringify(midway))) and copy.player.journey.get("to", "") == "ruin", "journey persists through saves")
	var bad: Dictionary = midway.duplicate(true)
	bad.world.flags.erase("found_ruin")
	bad.player.journey = {"to": "ruin"}
	check(not copy.restore(bad), "journey to an undiscovered place rejected")
	bad = midway.duplicate(true)
	bad.world.flags.erase("found_ruin")
	bad.player.journey = {}
	bad.player.location = "ruin"
	check(not copy.restore(bad), "standing in an undiscovered place rejected")

func _audio() -> void:
	var director := AudioDirector.new()
	director.settings_path = "res://.godot/audio_test_%d.cfg" % Time.get_ticks_usec()
	root.add_child(director)
	for bus_name: String in ["Music", "SFX", "Ambience"]:
		check(AudioServer.get_bus_index(bus_name) != -1, "bus exists: " + bus_name)
	for cue: String in director.library.sfx:
		var stream := director.placeholder(cue)
		check(stream != null and stream.data.size() > 0, "placeholder for missing cue: " + cue)
	for cue: String in ["prepare", "release", "impact", "heal", "guard", "victory", "defeat", "arrive", "event", "click"]:
		check(director.library.sfx.has(cue), "cue mapped: " + cue)
	for cue: String in director.library.sfx:
		check(director.has_file("sfx", cue), "the cue has its sound files: " + cue)
	check(director.cue_streams("impact_sword").size() >= 4 and director.library.sfx.has("release_fire") and director.library.sfx.has("impact_heavy"), "the duel's sounds vary by element and weight")
	var content := Content.new()
	content.load_data()
	for location_id: String in content.locations:
		check(director.library.music.has(location_id) and director.library.ambience.has(location_id), "music and ambience listed for " + location_id)
	director.set_volume("Music", 1.7)
	check(is_equal_approx(director.volumes.Music, 1.0), "volume clamped")
	director.set_volume("SFX", 0.0)
	check(AudioServer.is_bus_mute(AudioServer.get_bus_index("SFX")), "zero volume mutes")
	director.set_volume("SFX", 0.4)
	var reloaded := AudioDirector.new()
	reloaded.settings_path = director.settings_path
	root.add_child(reloaded)
	check(is_equal_approx(reloaded.volumes.SFX, 0.4) and is_equal_approx(reloaded.volumes.Music, 1.0), "volumes persist in settings")
	director.cue("impact")
	director.play_music("sect")
	check(director.last_cue == "impact" and director.music_key == "sect", "cues and music requests tracked")
	director.queue_free()
	reloaded.queue_free()
	await create_timer(0.2).timeout

func _art() -> void:
	check(ArtLibrary.texture(ArtLibrary.map_path()) == null or ArtLibrary.texture(ArtLibrary.map_path()) is Texture2D, "map art optional")
	check(ArtLibrary.texture("res://assets/art/locations/__missing__.png") == null, "missing art falls back to placeholders")
	check(ArtLibrary.scene_path("sect", "chamber") == "res://assets/art/scenes/sect_chamber.png", "scene art path convention")
