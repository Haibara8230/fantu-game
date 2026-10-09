extends SceneTree
## M2 acceptance: node map, journeys, road encounters, scenes, the hidden ruin, saves and audio.
const Session = preload("res://scripts/core/session.gd")
const Content = preload("res://scripts/core/content.gd")
const AudioDirector = preload("res://scripts/presentation/audio_director.gd")
const ArtLibrary = preload("res://scripts/ui/art_library.gd")
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
	_scenes()
	_ruin()
	_people()
	_saves()
	await _audio()
	_art()
	print("REGION: %d checks, %d failures" % [checks, failures])
	quit(0 if failures == 0 else 1)

func _game(seed_value: int, encounters := false) -> Session:
	var game := Session.new()
	game.encounters_enabled = encounters
	game.new_game("行者", seed_value)
	return game

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
	trail._refresh_realm_stats()
	trail.travel("wild")
	check(trail.has_flag("found_ruin"), "a foundation cultivator finds the trail without the storyteller")

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
	check(int(trader.item_count("foundation_pill")) == 1 and int(trader.player.stones) == 10 and _option(trader, "peddler", "buy_pill").reason == "条件不足。", "trades repeat whenever affordable")
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
	check(director.last_cue == "impact" and director.music_key == "sect", "cues and music requests tracked without audio files")
	director.queue_free()
	reloaded.queue_free()
	await create_timer(0.2).timeout

func _art() -> void:
	check(ArtLibrary.texture(ArtLibrary.map_path()) == null or ArtLibrary.texture(ArtLibrary.map_path()) is Texture2D, "map art optional")
	check(ArtLibrary.texture("res://assets/art/locations/__missing__.png") == null, "missing art falls back to placeholders")
	check(ArtLibrary.scene_path("sect", "chamber") == "res://assets/art/scenes/sect_chamber.png", "scene art path convention")
