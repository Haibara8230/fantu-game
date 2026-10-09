extends SceneTree
## M3d: generated population and loadout uniqueness, sparring, the changeable serpent rampage,
## rumors, commissions, the outer-disciple tournament and meeting people during stays.
const Session = preload("res://scripts/core/session.gd")
const Content = preload("res://scripts/core/content.gd")
const Calendar = preload("res://scripts/core/calendar.gd")
const Population = preload("res://scripts/core/population.gd")
var checks := 0
var failures := 0

func check(condition: bool, message: String) -> void:
	checks += 1
	if not condition:
		failures += 1
		printerr("FAIL: " + message)

func _initialize() -> void:
	create_timer(240.0).timeout.connect(func() -> void: printerr("TIMEOUT: test did not finish (likely a script error)"); quit(1))
	_population()
	_sparring()
	_rampage()
	_rumors()
	_commissions()
	_tournament()
	_meetings_and_saves()
	print("SOCIETY: %d checks, %d failures" % [checks, failures])
	quit(0 if failures == 0 else 1)

func _game(seed_value: int = 5) -> Session:
	var game := Session.new()
	game.encounters_enabled = false
	game.new_game("入世", seed_value, ["metal", "wood", "fire"])
	return game

func _jump(game: Session, year: int, month: int, day: int) -> void:
	game.advance_days(Calendar.to_day(year, month, day) - int(game.world.day))

func _loadout_key(person: Dictionary) -> String:
	var parts: Array = person.loadout.arts + person.loadout.methods + person.loadout.equipment.values()
	parts.sort()
	return "|".join(parts)

func _population() -> void:
	var content := Content.new()
	content.load_data()
	var people := Population.generate(content, 77)
	check(people.size() == 24 and people == Population.generate(content, 77), "twenty-four people, the same for the same world")
	check(people != Population.generate(content, 78), "another world has other people")
	var valid := true
	var names := {}
	var disciples := 0
	for person_id: String in people:
		var person: Dictionary = people[person_id]
		var problem: String = content._validate_person(person)
		valid = valid and problem.is_empty()
		if not problem.is_empty():
			printerr(person_id + ": " + problem)
		names[person.name] = true
		if person.sect == "qingyun":
			disciples += 1
		valid = valid and person.loadout.arts.size() == 4 and person.loadout.methods.size() == 2 and content.technique(person.loadout.arts[0]).kind == "attack"
		for technique_id: String in person.loadout.arts + person.loadout.methods:
			valid = valid and int(content.technique(technique_id).min_realm) <= int(person.realm)
	check(valid, "every generated person is a valid profile with a usable loadout for their realm")
	check(names.size() == 24, "names are unique within a world")
	check(disciples >= 2, "the sect has outer disciples (%d)" % disciples)
	# The M3 goal: in a region, identical loadouts between people stay under two percent of pairs.
	var keys: Array[String] = []
	for world_seed: int in range(10):
		for person: Dictionary in Population.generate(content, 1000 + world_seed).values():
			keys.append(_loadout_key(person))
	var same := 0
	var pairs := 0
	for a: int in keys.size():
		for b: int in range(a + 1, keys.size()):
			pairs += 1
			if keys[a] == keys[b]:
				same += 1
	check(float(same) / float(pairs) < 0.02, "identical loadouts in %d of %d pairs across ten worlds" % [same, pairs])
	var game := _game()
	var at_sect: Array = game.present_npcs().filter(func(person_id: String) -> bool: return person_id.begins_with("g:"))
	check(not at_sect.is_empty() and game.content.people[at_sect[0]].title == "青云外门弟子", "outer disciples are found at the sect")

func _a_disciple(game: Session) -> String:
	return game.present_npcs().filter(func(person_id: String) -> bool: return person_id.begins_with("g:"))[0]

func _sparring() -> void:
	var game := _game()
	var rival := _a_disciple(game)
	var person: Dictionary = game.content.people[rival]
	var stones := int(game.player.stones)
	game.interact(rival, "spar")
	check(game.battle.get("context", "") == "spar" and int(game.battle.hp) == int(game.content.stage(int(person.realm), int(person.stage)).max_hp), "a spar uses the person's own strength")
	game.use_skill("sword")
	var counter: Dictionary = game.combat_events.filter(func(event: Dictionary) -> bool: return event.get("actor", "") == "enemy")[0]
	check(counter.style == game.battle.foe.art and counter.has("vfx"), "they answer with their own art")
	game.battle.hp = 1
	var xp := int(game.player.xp)
	game.use_skill("sword")
	check(game.battle.is_empty() and game.favor(rival) == 5 and int(game.player.xp) > xp and int(game.player.stones) == stones, "winning a spar earns respect and insight, not money")
	check(rival in game.present_npcs() and game.npc_options(rival).filter(func(option: Dictionary) -> bool: return option.id == "spar")[0].reason.contains("后再来"), "the rival stays, and spars wait a month")
	var loser := _game()
	var other := _a_disciple(loser)
	loser.interact(other, "spar")
	loser.player.hp = 1
	loser.defend()
	check(loser.battle.is_empty() and int(loser.player.hp) >= 1 and loser.player.location == "sect" and int(loser.player.stones) == 30 and loser.favor(other) == 2, "losing a spar costs nothing")

func _rampage() -> void:
	var game := _game()
	game.travel("wild")
	_jump(game, 6, 3, 2)
	check(game.has_flag("serpent_rampage") and game.journal_lines().any(func(line: String) -> bool: return line.contains("下令封谷")), "the serpent breaks out in the spring of year six")
	game.travel("ridge")
	check(game.player.location == "ridge", "people inside the sealed valley can still leave")
	check(game.travel("wild").contains("已被封锁") and game.path_to("wild").is_empty() and game.content.find_path("sect", "ruin", {"found_ruin": true, "serpent_rampage": true}).is_empty(), "nobody can enter, nor pass through to the ruin")
	_jump(game, 9, 3, 2)
	check(not game.has_flag("serpent_rampage") and game.has_flag("serpent_slain") and not game.path_to("wild").is_empty(), "three years later the elders end it and the valley reopens")
	var hero := _game()
	hero.world.flags.serpent_slain = true
	_jump(hero, 6, 3, 2)
	check(not hero.has_flag("serpent_rampage") and hero.favor("shen_mo") == 10 and hero.journal_lines().any(func(line: String) -> bool: return line.contains("安然无恙")), "slaying the serpent beforehand changes history")

func _rumors() -> void:
	var game := _game()
	check(game.inquire() == "此地无处打听消息。", "rumors are heard in teahouses, docks and streets")
	game.travel("town")
	var keys: Array = game.rumor_candidates().map(func(rumor: Dictionary) -> String: return rumor.key)
	check("ruin" in keys and "serpent" in keys and keys.any(func(key: String) -> bool: return key.begins_with("person:")), "news follows the world: the ruin, the restless serpent, people not yet met")
	var day := int(game.world.day)
	var stones := int(game.player.stones)
	game.inquire()
	check(int(game.world.day) == day + 1 and int(game.player.stones) == stones - 2 and game.world.rumors.size() == 1, "asking around takes a day and a pot of tea")
	var heard: String = game.world.rumors.keys()[0]
	check(not game.rumor_candidates().any(func(rumor: Dictionary) -> bool: return rumor.key == heard), "the same news is not repeated soon")
	check(game.journal_lines().back().length() > 4 and not game.journal_lines().back().contains("{"), "the rumor reads as a sentence")
	_jump(game, 4, 2, 1)
	check(game.rumor_candidates().any(func(rumor: Dictionary) -> bool: return rumor.key == "auction"), "in the auction year people talk about it")
	game.player.stones = 200
	for i: int in range(30):
		if game.has_flag("heard_auction_rumor"):
			break
		game.inquire()
	check(game.has_flag("heard_auction_rumor") and game.upcoming().size() == 1, "hearing of the auction counts as knowing about it")

func _commissions() -> void:
	var game := _game()
	check(game.board_here() == "sect", "the sect board hangs in the 执事堂")
	var offers := game.commission_offers("sect")
	check(offers.size() == 3 and offers == game.commission_offers("sect"), "the board posts three offers, fixed for the period")
	var gather_offer: Dictionary = {}
	var hunt_offer: Dictionary = {}
	for period: int in range(12):
		for offer: Dictionary in game.commission_offers("sect"):
			if offer.kind == "gather" and gather_offer.is_empty():
				gather_offer = offer
			if offer.kind == "hunt" and hunt_offer.is_empty():
				hunt_offer = offer
		if not gather_offer.is_empty() and not hunt_offer.is_empty():
			break
		game.advance_days(60)
	check(not gather_offer.is_empty() and not hunt_offer.is_empty(), "both gathering and hunting work is posted over time")
	game.accept_commission(gather_offer.key)
	game.accept_commission(hunt_offer.key)
	check(game.player.quests.size() == 2 and not game.commission_offers("sect").any(func(offer: Dictionary) -> bool: return offer.key == gather_offer.key), "accepted work leaves the board")
	var quest: Dictionary = game.player.quests[0]
	check(game.delivery_block(quest).contains("还不够"), "delivery needs the goods")
	game.set_item_count(quest.item, int(quest.count))
	var stones := int(game.player.stones)
	game.deliver_commission(quest.key)
	check(game.player.quests.size() == 1 and int(game.player.stones) == stones + int(quest.reward.stones) and game.item_count(quest.item) == 0, "delivering pays and takes the goods")
	var hunt: Dictionary = game.player.quests[0]
	game.travel("wild")
	for kill: int in int(hunt.count):
		game.start_battle("wolf")
		game.battle.hp = 1
		game.use_skill("sword")
	check(int(game.player.quests[0].progress) == int(hunt.count), "slain wolves count toward the hunt")
	check(game.delivery_block(game.player.quests[0]).contains("执事堂告示"), "the hunt is reported back at the board")
	game.travel("sect")
	var xp := int(game.player.xp)
	game.deliver_commission(hunt.key)
	check(game.player.quests.is_empty() and int(game.player.xp) > xp, "the hunt rewards xp too")
	var late := _game()
	var offer: Dictionary = late.commission_offers("sect")[0]
	late.accept_commission(offer.key)
	late.cultivate(int(offer.days) + 30)
	check(late.player.quests.is_empty() and late.journal_lines().any(func(line: String) -> bool: return line.contains("已过期限")), "missed deadlines expire with a note")
	var copy := Session.new()
	var keeper := _game()
	keeper.accept_commission(keeper.commission_offers("sect")[0].key)
	check(copy.restore(JSON.parse_string(JSON.stringify(keeper.snapshot()))) and copy.player.quests == keeper.player.quests, "commissions survive a save")

func _tournament() -> void:
	var game := _game()
	_jump(game, 10, 6, 2)
	game.wait(1)
	check(game.pending_event.get("id", "") == "tournament_entry", "the tournament opens at the sect in year ten")
	game.choose_event("enter")
	check(game.battle.get("context", "") == "tournament" and int(game.battle.round) == 1, "round one begins")
	var opponents: Array[String] = []
	var stones := int(game.player.stones)
	for round: int in range(3):
		opponents.append(str(game.battle.npc))
		game.battle.hp = 1
		game.use_skill("sword")
	check(opponents.size() == 3 and game.battle.is_empty(), "three rounds fought")
	check(int(game.player.stones) == stones + 100 and game.player.items.keys().any(func(item_id: String) -> bool: return item_id.begins_with("j:")), "the champion wins stones and a slip")
	check(game.chronicle.entries.any(func(entry: Dictionary) -> bool: return entry.major and entry.id == "tournament_champion"), "the victory is a life milestone")
	var out := _game()
	_jump(out, 10, 6, 2)
	out.wait(1)
	out.choose_event("enter")
	out.player.hp = 1
	out.defend()
	check(out.battle.is_empty() and out.player.location == "sect" and int(out.player.stones) == 30 and out.journal_lines().any(func(line: String) -> bool: return line.contains("止步")), "losing a round ends the run without penalty")

func _meetings_and_saves() -> void:
	var game := _game()
	game.travel("town")
	var visitors: Array = game._people_at.get("town", []).filter(func(person_id: String) -> bool: return game.content.people[person_id].has("schedule"))
	game.wait(120)
	check(not visitors.is_empty() and visitors.all(func(person_id: String) -> bool: return person_id in game.known_npcs()), "a long stay meets everyone who passes through")
	var old := Session.new()
	check(old.restore(JSON.parse_string(FileAccess.get_file_as_string("res://tests/fixtures/v8_wild_loadout.json"))), "v8 save migrates")
	check(old.player.quests.is_empty() and old.world.rumors.is_empty() and old.player.methods == ["t:breath:wood:1::0"], "commissions and rumors added; the loadout kept")
	var twin := Session.new()
	twin.restore(JSON.parse_string(JSON.stringify(old.snapshot())))
	check(twin.content.people.get("g:0", {}).get("name", "") == old.content.people.get("g:0", {}).get("name", "x"), "the same world regenerates the same people after loading")
