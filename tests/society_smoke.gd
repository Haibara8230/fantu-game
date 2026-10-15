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
	_lives()
	_sparring()
	_rampage()
	_rumors()
	_commissions()
	_tournament()
	_summit()
	_demon_hunts()
	_calamity()
	_meetings_and_saves()
	_portraits()
	print("SOCIETY: %d checks, %d failures" % [checks, failures])
	quit(0 if failures == 0 else 1)

func _game(seed_value: int = 5) -> Session:
	var game := Session.new()
	game.encounters_enabled = false
	game.new_game("入世", seed_value, ["metal", "wood", "fire"])
	return game

## 五宗论道: offered at 青云山 every sixty years to those of foundation or above; four rounds against
## the other sects' senior disciples; the champion's reward; a loss costs nothing; a save keeps it.
func _summit_game(seed_value: int) -> Session:
	var game := _game(seed_value)
	game.player.realm = 1
	game.player.stage = 1
	game.player.xp = 1500
	game.player.mind = 60
	game.refresh_realm_stats()
	game.player.hp = game.player.max_hp
	_jump(game, 60, 8, 29)
	game.travel("sect")
	game.wait(1)
	game.wait(1)
	return game

func _summit() -> void:
	var game := _summit_game(5)
	check(game.pending_event.get("id", "") == "five_sects_entry", "the five sects' summit opens at 青云山 in year sixty")
	game.choose_event("enter")
	check(game.battle.get("context", "") == "summit" and int(game.battle.round) == 1 and str(game.battle.foe.name).contains("赤霄") and game.battle.foe.arts == game.content.sects.chixiao.skills, "round one: 赤霄's senior disciple with 赤霄's own arts")
	var copy := Session.new()
	check(copy.restore(JSON.parse_string(JSON.stringify(game.snapshot()))) and copy.battle.context == "summit", "a summit duel survives a save")
	var stones := int(game.player.stones)
	var merit := int(game.player.get("contribution", 0))
	var foes: Array[String] = []
	for round: int in 4:
		if game.battle.is_empty():
			break
		foes.append(str(game.battle.foe.sect))
		game.battle.hp = 1
		game.battle.orbs = ["metal"]
		game.use_skill("sword")
	check(foes == ["chixiao", "changqing", "canglan", "xuanyue"] and game.battle.is_empty(), "four rounds, one for each of the other sects")
	check(int(game.player.stones) >= stones + 4 * 50 + 500 and int(game.player.get("contribution", 0)) > merit and game.player.items.keys().any(func(item_id: String) -> bool: return item_id.begins_with("j:") and int(game.content.item(item_id).tier) == 4), "the champion takes stones, contribution and a 地阶 slip")
	check(game.chronicle.entries.any(func(entry: Dictionary) -> bool: return entry.major and entry.id == "summit_champion"), "and a milestone")
	var out := _summit_game(6)
	out.choose_event("enter")
	out.player.hp = 1
	for turn: int in 8:
		if not out.battle.is_empty():
			out.defend()
	check(out.battle.is_empty() and out.player.location == "sect" and out.journal_lines().any(func(line: String) -> bool: return line.contains("下台")), "a loss ends the run without penalty")
	var young := _game(7)
	_jump(young, 60, 8, 29)
	young.travel("sect")
	young.wait(1)
	young.wait(1)
	check(young.pending_event.get("id", "") != "five_sects_entry", "a 炼气 disciple is not sent")

func _jump(game: Session, year: int, month: int, day: int) -> void:
	game.advance_days(Calendar.to_day(year, month, day) - int(game.world.day))

func _loadout_key(person: Dictionary) -> String:
	var parts: Array = person.loadout.arts + person.loadout.methods + person.loadout.equipment.values()
	parts.sort()
	return "|".join(parts)

func _population() -> void:
	var game := _game(77)
	var seats: Array[int] = game._local_seats
	var home := seats.filter(func(seat: int) -> bool: return game.Population.region_of(game.content, 77, seat) == "qingyun").size()
	var south := seats.filter(func(seat: int) -> bool: return game.Population.region_of(game.content, 77, seat) == "tiannan").size()
	check(int(game.content.population_data.world_total) == 1200 and home > 120 and home < 240 and south > 90 and south < 200 and home + south == seats.size(), "a world of 1200 seats: about 15%% in 青云山周边 (%d), 12%% in 天南 (%d)" % [home, south])
	check(seats == game.Population.local_seats(game.content, 77) and seats != game.Population.local_seats(game.content, 78), "the same world keeps its people; another world has others")
	var living: Variant = game.living_people().filter(func(person_id: String) -> bool: return game.is_generated(person_id))
	check(living.size() > seats.size() * 0.85, "nearly every seat is held by someone at the start (%d of %d)" % [living.size(), seats.size()])
	var valid := true
	var names := {}
	var disciples := 0
	for person_id: String in living:
		var person: Dictionary = game.person(person_id)
		var problem: String = game.content._validate_person(person)
		valid = valid and problem.is_empty()
		if not problem.is_empty():
			printerr(person_id + ": " + problem)
		names[person.name] = true
		if person.kind == "disciple":
			disciples += 1
		valid = valid and person.loadout.arts.size() == 4 and person.loadout.methods.size() == 2 and game.content.technique(person.loadout.arts[0]).kind == "attack"
		for technique_id: String in person.loadout.arts + person.loadout.methods:
			valid = valid and int(game.content.technique(technique_id).min_realm) <= int(person.realm)
	check(valid, "every living person is a valid profile with a usable loadout for their realm")
	check(names.size() >= living.size() * 0.97, "names are nearly all different (%d names for %d people)" % [names.size(), living.size()])
	check(disciples >= 15, "the sect has dozens of outer disciples (%d)" % disciples)
	# The M3 goal: in a region, identical loadouts between people stay under two percent of pairs.
	var keys: Array[String] = []
	for person_id: String in living:
		keys.append(_loadout_key(game.person(person_id)))
	var same := 0
	var pairs := 0
	for a: int in keys.size():
		for b: int in range(a + 1, keys.size()):
			pairs += 1
			if keys[a] == keys[b]:
				same += 1
	check(float(same) / float(pairs) < 0.02, "identical loadouts in %d of %d pairs across the region" % [same, pairs])
	var at_sect: Array = game.present_npcs().filter(func(person_id: String) -> bool: return game.is_generated(person_id))
	check(at_sect.size() >= 10 and at_sect.all(func(person_id: String) -> bool: return game.person(person_id).title == "青云外门弟子"), "outer disciples crowd the sect (%d)" % at_sect.size())

func _lives() -> void:
	var game := _game(77)
	var risers: Array = []
	for seat: int in game._local_seats:
		for life: Dictionary in game.seat_lives(seat, 200 * 360):
			if int(life.generation) > 0 and int(life.foundation_age) > 0:
				risers.append(life)
	check(risers.size() > 10, "newcomers with talent break through later in life (%d)" % risers.size())
	var riser: Dictionary = risers[0]
	var breakthrough_day := int(riser.birth) + int(riser.foundation_age) * 360
	check(game.Population.standing(game.content, riser, breakthrough_day - 360).realm == 0 and game.Population.standing(game.content, riser, breakthrough_day).realm == 1, "they reach 筑基 at their own pace")
	var first_lives: Variant = game._local_seats.map(func(seat: int) -> String: return str(game.life_at(seat, 0).get("id", "")))
	game.encounters_enabled = false
	game.travel("town")
	for i: int in range(10):
		game.wait(3600)
	var later: Variant = game._local_seats.map(func(seat: int) -> String: return str(game.life_at(seat, int(game.world.day)).get("id", "")))
	var replaced := 0
	for index: int in first_lives.size():
		if first_lives[index] != later[index]:
			replaced += 1
	check(replaced > first_lives.size() * 0.8, "a century later most faces are new (%d of %d seats changed hands)" % [replaced, first_lives.size()])
	var alive: Variant = later.filter(func(person_id: String) -> bool: return not person_id.is_empty()).size()
	check(alive > first_lives.size() * 0.75, "the region stays populated as newcomers take empty seats (%d)" % alive)
	var successor: Dictionary = game.life_at(game._local_seats[0], int(game.world.day))
	if not successor.is_empty():
		var previous: Dictionary = game.life_by_id("g:%d:%d" % [int(successor.seat), maxi(0, int(successor.generation) - 1)])
		check(int(successor.generation) == 0 or int(successor.appear) > int(previous.death), "a newcomer arrives after the last holder of the seat died")
	check(game.journal_lines().any(func(line: String) -> bool: return line.contains("已经故去")), "news reaches the player when an acquaintance dies")
	var mourned: Variant = game.world.people.keys().filter(func(person_id: String) -> bool: return bool(game.world.people[person_id].get("mourned", false)))
	var obituaries: Variant = game.chronicle.entries.filter(func(entry: Dictionary) -> bool: return entry.id == "obituary").size()
	check(not mourned.is_empty() and obituaries <= mourned.size(), "each death is reported at most once (%d reports, %d mourned)" % [obituaries, mourned.size()])
	var view: Dictionary = game.person(mourned[0])
	check(game.npc_location(mourned[0]).is_empty() and not view.is_empty(), "the dead are no longer anywhere, but are remembered")

func _a_disciple(game: Session) -> String:
	return game.present_npcs().filter(func(person_id: String) -> bool: return person_id.begins_with("g:"))[0]

func _sparring() -> void:
	var game := _game()
	var rival := _a_disciple(game)
	var person: Dictionary = game.person(rival)
	var stones := int(game.player.stones)
	game.interact(rival, "spar")
	check(game.battle.get("context", "") == "spar" and int(game.battle.hp) == int(game.content.stage(int(person.realm), int(person.stage)).max_hp), "a spar uses the person's own strength")
	check(game.battle.place == "sect" and game.battle.foe.sect == person.sect and game.battle.foe.gender == person.gender, "a spar records where it is fought and how the foe looks")
	var saved: Dictionary = JSON.parse_string(JSON.stringify(game.snapshot()))
	var older: Dictionary = saved.duplicate(true)
	older.battle.erase("place")
	older.battle.foe.erase("sect")
	older.battle.foe.erase("gender")
	check(_game().restore(older), "a duel saved before backdrops and looks still loads")
	for broken: Callable in [func(b: Dictionary) -> void: b.place = "moon", func(b: Dictionary) -> void: b.place = 3, func(b: Dictionary) -> void: b.foe.sect = "nowhere", func(b: Dictionary) -> void: b.foe.gender = "x"]:
		var bad: Dictionary = saved.duplicate(true)
		broken.call(bad.battle)
		check(not _game().restore(bad), "a duel with a broken place or look is rejected")
	game.use_skill("sword")
	game.end_turn()
	var counter: Dictionary = game.combat_events.filter(func(event: Dictionary) -> bool: return event.get("actor", "") == "enemy")[0]
	check(counter.style in game.battle.foe.arts and counter.has("vfx"), "they answer with their own arts")
	game.battle.hp = 1
	var xp := int(game.player.xp)
	var insight := int(game.player.insight)
	game.use_skill("sword")
	check(game.battle.is_empty() and game.favor(rival) == 5 and int(game.player.xp) > xp and int(game.player.stones) == stones, "winning a spar earns respect and insight, not money")
	check(int(game.player.insight) == insight + 10, "a spar is insight toward the next bottleneck")
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
	# Word of the wider world (data/lore.json), one piece at a time; the distant 化神 only once the player
	# has built a foundation.
	var lore := func() -> Array: return game.rumor_candidates().filter(func(rumor: Dictionary) -> bool: return rumor.id == "rumor_lore")
	check(lore.call().size() == 1 and str(lore.call()[0].key) in ["lore:five_sects", "lore:tianyan"], "one piece of lore about the five sects at a time")
	game.world.rumors["lore:five_sects"] = int(game.world.day)
	game.world.rumors["lore:tianyan"] = int(game.world.day)
	check(lore.call().is_empty(), "a 炼气 disciple hears nothing of the distant 化神")
	game.player.realm = 1
	check(lore.call().size() == 1 and lore.call()[0].key == "lore:xuanwei", "after foundation, word of 玄微真君")
	game.log_event("rumor_lore", {"lore": "tianyan"})
	check(game.journal_lines().back().contains("天衍宗"), "and lore reads as its own words")
	game.player.realm = 0
	_jump(game, 4, 2, 1)
	check(game.rumor_candidates().any(func(rumor: Dictionary) -> bool: return rumor.key == "auction"), "in the auction year people talk about it")
	# News is drawn at random among everything worth hearing; enough asking hears of the auction.
	game.player.stones = 2000
	for i: int in range(400):
		if game.has_flag("heard_auction_rumor"):
			break
		game.inquire()
	check(game.has_flag("heard_auction_rumor") and game.upcoming().size() == 1, "hearing of the auction counts as knowing about it")

## The 魔修: a 金丹 disciple's commission, and a foe at the valley's spring.
func _demon_hunts() -> void:
	var low := _game(9)
	var high := _game(9)
	high.player.realm = 2
	high.refresh_realm_stats()
	var seen_low := false
	var seen_high := false
	for period: int in 30:
		low.world.day = period * 60
		high.world.day = period * 60
		seen_low = seen_low or low.commission_offers("sect").any(func(offer: Dictionary) -> bool: return offer.kind == "demon")
		seen_high = seen_high or high.commission_offers("sect").any(func(offer: Dictionary) -> bool: return offer.kind == "demon")
	check(seen_high and not seen_low, "only a 金丹 disciple is asked to put down 魔修")
	var elder := _game(9)
	elder.player.realm = 3
	elder.refresh_realm_stats()
	var seen_jiao := false
	for period: int in 30:
		elder.world.day = period * 60
		seen_jiao = seen_jiao or elder.commission_offers("sect").any(func(offer: Dictionary) -> bool: return offer.kind == "jiao")
	check(seen_jiao and not high.commission_offers("sect").any(func(offer: Dictionary) -> bool: return offer.kind == "jiao"), "a 元婴 is asked to slay the river's 千年蛟")
	check(elder.content.locations.ferry.spots.any(func(spot: Dictionary) -> bool: return "battle:jiao" in spot.actions), "which lurks under the ferry")
	var hunter := _game(9)
	hunter.player.realm = 2
	hunter.refresh_realm_stats()
	hunter.player.hp = hunter.player.max_hp
	hunter.travel("wild")
	check(hunter.available_here("battle:mo_xiu") or hunter.content.locations.wild.spots.any(func(spot: Dictionary) -> bool: return "battle:mo_xiu" in spot.actions), "a 魔修 lurks at the valley's spring")
	var young := _game(9)
	young.travel("wild")
	young.start_battle("mo_xiu")
	check(young.battle.is_empty(), "too strong a foe for one below 金丹")

## 大劫: omens in 299, the demon tide at 青云山 in the spring of 300, its general at the gate for a
## 金丹; slain, the tide breaks and the sect rewards it; unanswered, the sect is left in ruins.
func _calamity() -> void:
	var game := _game(10)
	game.player.realm = 2
	game.player.stage = 3
	game.refresh_realm_stats()
	game.player.birth_day = int(Calendar.to_day(290, 1, 1))
	game.world.day = Calendar.to_day(298, 12, 30)
	game.wait(1)
	check(game.journal_lines().any(func(line: String) -> bool: return line.contains("北天裂开")), "omens a year ahead")
	game.world.day = Calendar.to_day(300, 2, 30)
	# A storyline's 传音 (南行, 真传之责) may end a stay on its first day; stay on until the spring comes.
	for stay: int in 3:
		if int(game.world.day) <= Calendar.to_day(300, 2, 30):
			game.wait(1)
	check(game.has_flag("calamity") and game.available_here("battle:mo_jiang"), "in the spring of 300 the tide reaches the gate, and a 金丹 may face its general")
	var merit := int(game.player.get("contribution", 0))
	game.start_battle("mo_jiang")
	game.battle.hp = 1
	game.battle.orbs = ["metal"]
	game.use_skill("sword")
	check(game.has_flag("calamity_turned") and int(game.player.get("contribution", 0)) >= merit + 500 and game.player.items.keys().any(func(item_id: String) -> bool: return game.content.item(item_id).get("tier", 0) == 5), "the general slain: the sect's thanks and a 天阶 treasure")
	game.world.day = Calendar.to_day(302, 2, 30)
	game.wait(1)
	check(not game.has_flag("calamity") and game.journal_lines().any(func(line: String) -> bool: return line.contains("青云山保住了")), "the tide breaks and the sect is saved")
	var idle := _game(11)
	idle.player.birth_day = int(Calendar.to_day(290, 1, 1))
	idle.world.day = Calendar.to_day(302, 2, 30)
	idle.world.flags["calamity"] = true
	idle.wait(1)
	check(not idle.has_flag("calamity") and idle.journal_lines().any(func(line: String) -> bool: return line.contains("满目疮痍")), "unanswered, the sect is left in ruins")

func _commissions() -> void:
	var game := _game()
	check(game.board_here() == "sect", "the sect board hangs in the 执事堂")
	var offers := game.commission_offers("sect")
	check(offers.size() == 3 and offers == game.commission_offers("sect"), "the board posts three offers, fixed for the period")
	var gather_offer: Dictionary = {}
	var hunt_offer: Dictionary = {}
	# A period that posts both gathering and hunting work (the sect's patrols come up among it too).
	for period: int in range(40):
		gather_offer = {}
		hunt_offer = {}
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
	var insight := int(game.player.insight)
	game.deliver_commission(quest.key)
	check(game.player.quests.size() == 1 and int(game.player.stones) == stones + int(quest.reward.stones) and game.item_count(quest.item) == 0, "delivering pays and takes the goods")
	check(int(game.player.insight) == mini(insight + 25, game.insight_needed()), "a finished commission is insight")
	var hunt: Dictionary = game.player.quests[0]
	game.travel("wild")
	insight = int(game.player.insight)
	for kill: int in int(hunt.count):
		game.start_battle("wolf")
		game.battle.hp = 1
		game.use_skill("sword")
	check(int(game.player.quests[0].progress) == int(hunt.count), "slain wolves count toward the hunt")
	check(int(game.player.insight) == mini(insight + 20 * int(hunt.count), game.insight_needed()), "each won duel is insight")
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
	# They may gather qi or guard before they strike.
	for turn: int in 6:
		if not out.battle.is_empty():
			out.defend()
	check(out.battle.is_empty() and out.player.location == "sect" and int(out.player.stones) == 30 and out.journal_lines().any(func(line: String) -> bool: return line.contains("止步")), "losing a round ends the run without penalty")
	check(out.tournament_block().contains("报过名"), "one entry a tournament")
	# Entering at the arena: a retreat through the sign-up no longer misses it, and the 约定 lists it.
	var arena := _game()
	_jump(arena, 10, 4, 20)
	check(arena.tournament_block().contains("开始报名") and arena.upcoming().any(func(entry: Dictionary) -> bool: return entry.event == "tournament_entry"), "the arena tells when sign-up opens, and the 约定 lists it")
	arena.retreat_limits = false
	arena.cultivate(30)
	check(arena.journal_lines().any(func(line: String) -> bool: return line.contains("执事堂贴出告示")), "a notice a month ahead is kept in the record")
	arena.cultivate(15)
	check(arena.pending_event.get("id", "") == "tournament_entry", "back from a retreat inside the sign-up, it is offered at once")
	var later := _game()
	_jump(later, 10, 6, 3)
	check(later.tournament_block().is_empty(), "the arena takes the entry while sign-up is open")
	arena = later
	arena.enter_tournament()
	check(arena.battle.get("context", "") == "tournament" and int(arena.battle.round) == 1 and int(arena.world.events.tournament_entry.last_occurrence) == 0, "entering at the arena begins round one and counts as this tournament's entry")

func _portraits() -> void:
	var ArtLibrary = load("res://scripts/ui/art_library.gd")
	var game := _game()
	var people := {}
	for person_id: String in game.living_people():
		if game.is_generated(person_id):
			people[person_id] = game.person(person_id)
	var generated: Array = people.keys()
	check(generated.all(func(person_id: String) -> bool: return people[person_id].gender in ["male", "female"] and people[person_id].has("kind")), "generated people have a gender and a role")
	# A fake pool: twenty images in every group, a few named for roles.
	var index := {}
	for gender: String in ["male", "female"]:
		for band: String in ["young", "middle", "old"]:
			var files: Array = []
			for n: int in range(20):
				files.append("pool/%s_%s/%s%02d.png" % [gender, band, "disciple_" if n < 5 else "", n])
			index["%s_%s" % [gender, band]] = files
	var assigned: Dictionary = ArtLibrary.assign_pool(people, 5, index)
	check(assigned.size() == generated.size() and _unique(assigned.values()).size() >= mini(int(generated.size() * 0.4), 96), "faces are spread across the pool (most of its 120 images) (%d different images for %d people)" % [_unique(assigned.values()).size(), generated.size()])
	var matched := true
	for person_id: String in assigned:
		var person: Dictionary = people[person_id]
		matched = matched and str(assigned[person_id]).contains("%s_%s" % [person.gender, ArtLibrary.age_band(int(person.age))])
		if person.kind == "disciple":
			matched = matched and str(assigned[person_id]).get_file().begins_with("disciple_")
	check(matched, "images follow gender, age band and role")
	check(ArtLibrary.assign_pool(people, 5, index) == assigned and ArtLibrary.assign_pool(people, 6, index) != assigned, "the same world keeps the same faces; another world deals them anew")
	var tiny := {"any": ["pool/a.png", "pool/b.png"]}
	check(ArtLibrary.assign_pool(people, 5, tiny).size() == generated.size(), "a small pool is shared rather than leaving people blank")
	# Real files on disk, read without import.
	var root := "res://.godot/portrait_test_%d" % Time.get_ticks_usec()
	DirAccess.make_dir_recursive_absolute(ProjectSettings.globalize_path(root.path_join("pool/female_young")))
	var image := Image.create(8, 10, false, Image.FORMAT_RGB8)
	image.fill(Color.DARK_SLATE_GRAY)
	image.save_png(root.path_join("shen_mo.png"))
	image.save_png(root.path_join("pool/female_young/a.png"))
	image.save_png(root.path_join("pool/loose.png"))
	check(ArtLibrary.find_image(root.path_join("shen_mo")).ends_with("shen_mo.png") and ArtLibrary.find_image(root.path_join("boatman")).is_empty(), "a person's own image is found by id")
	var found: Dictionary = ArtLibrary.pool_index(root)
	check(found.keys().size() == 2 and found.has("any") and found.has("female_young"), "the pool is scanned by group")
	var texture: Texture2D = ArtLibrary.local_texture(root.path_join("shen_mo.png"))
	check(texture != null and texture.get_width() == 8, "local images load straight from disk")
	check(ArtLibrary.local_texture(root.path_join("missing.png")) == null, "missing local images are simply absent")

func _unique(values: Array) -> Dictionary:
	var seen := {}
	for value: Variant in values:
		seen[value] = true
	return seen

func _meetings_and_saves() -> void:
	var game := _game()
	game.travel("town")
	var visitors: Array = game._people_at.get("town", []).filter(func(person_id: String) -> bool: return game.is_generated(person_id) and game.person(person_id).has("schedule"))
	game.wait(120)
	check(not visitors.is_empty() and visitors.all(func(person_id: String) -> bool: return person_id in game.known_npcs()), "a long stay meets everyone who passes through")
	var arrived := int(game.world.day) - 120
	check(visitors.all(func(person_id: String) -> bool:
		var progress: Dictionary = game.world.people[person_id]
		var first := -1
		for day: int in range(arrived, int(game.world.day) + 1):
			if game.Population.location_on(game.life_by_id(person_id), day) == "town":
				first = day
				break
		return progress.met_place == "town" and int(progress.met_day) == first), "each is recorded as met on the first day they were in town")
	var tampered: Dictionary = JSON.parse_string(JSON.stringify(game.snapshot()))
	tampered.world.people[visitors[0]].met_place = "nowhere"
	check(not Session.new().restore(tampered), "a meeting at an unknown place is rejected")
	tampered.world.people[visitors[0]].met_place = "town"
	tampered.world.people[visitors[0]].met_day = int(game.world.day) + 1
	check(not Session.new().restore(tampered), "a meeting after today is rejected")
	var old := Session.new()
	check(old.restore(JSON.parse_string(FileAccess.get_file_as_string("res://tests/fixtures/v8_wild_loadout.json"))), "v8 save migrates")
	check(old.player.quests.is_empty() and old.world.rumors.is_empty() and old.player.methods == ["t:breath:wood:1::0"], "commissions and rumors added; the loadout kept")
	var acquainted := Session.new()
	check(acquainted.restore(JSON.parse_string(FileAccess.get_file_as_string("res://tests/fixtures/v9_acquainted.json"))), "v9 save migrates")
	check(not acquainted.world.people.keys().any(func(person_id: String) -> bool: return person_id.begins_with("g:") and person_id.count(":") == 1) and acquainted.world.people.has("storyteller") and acquainted.player.quests.size() == 1, "old-style acquaintances give way to the living population; handwritten ones and quests stay")
	check(int(acquainted.world.people.storyteller.met_day) == -1 and acquainted.world.people.storyteller.met_place == "", "older saves read with the meeting unrecorded")
	var twin := Session.new()
	twin.restore(JSON.parse_string(JSON.stringify(old.snapshot())))
	var someone: String = old.living_people().filter(func(person_id: String) -> bool: return old.is_generated(person_id))[0]
	check(twin.person(someone).name == old.person(someone).name, "the same world regenerates the same people after loading")
