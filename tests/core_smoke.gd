extends SceneTree
const Session = preload("res://scripts/core/session.gd")
const SaveStore = preload("res://scripts/core/save_store.gd")
const Calendar = preload("res://scripts/core/calendar.gd")
var checks := 0
var failures := 0

func check(condition: bool, message: String) -> void:
	checks += 1
	if not condition:
		failures += 1
		printerr("FAIL: " + message)

## Answers whatever stops the journey with its last choice (declining, strolling on).
func _settle(game) -> void:
	while not game.pending_event.is_empty():
		game.choose_event(str(game.pending_definition().choices.back().id))

func _initialize() -> void:
	# A script error aborts this function before quit(); the watchdog turns that hang into a failure.
	create_timer(240.0).timeout.connect(func() -> void: printerr("TIMEOUT: test did not finish (likely a script error)"); quit(1))
	var game = Session.new()
	# Road encounters have their own suite; this one follows fixed paths.
	game.encounters_enabled = false
	check(game.content.error_message.is_empty(), "content loads")
	# A plain three-element root cultivates at the base rate, keeping the numbers below predictable.
	game.new_game("测试修士", 42, ["metal", "wood", "fire"])
	check(game.player.hp == 90 and game.player.location == "sect", "starting state")
	var unchanged: Dictionary = game.snapshot()
	game.act("gather")
	check(game.snapshot() == unchanged, "invalid action does not consume time or resources")
	game.act("breakthrough")
	check(game.player.realm == 0, "breakthrough requirements enforced")
	for i: int in range(6):
		game.act("cultivate")
	check(game.player.xp == 360 and game.world.day == 180 and game.cultivation_rate() == 60, "cultivation progression at the base rate")
	game.travel("wild")
	game.start_battle("serpent")
	check(game.battle.is_empty(), "boss gated by realm")
	var pill_price := 0
	for good: Dictionary in game.content.locations.market.shop:
		if good.item == "foundation_pill":
			pill_price = int(good.price)
	while game.herb_count() * 4 + game.player.stones < pill_price:
		game.act("gather")
	game.travel("market")
	if not game.pending_event.is_empty():
		game.choose_event("decline")
	game.act("sell")
	game.buy("foundation_pill")
	check(game.item_count("foundation_pill") == 1, "gather-trade-pill economy")
	game.travel("sect")
	game.act("breakthrough")
	check(game.player.realm == 0, "breakthrough needs the last sub-stage")
	# Mixed legal play: retreat while the mind is fresh; otherwise spar with fellow disciples (which
	# tempers the mind), gather in the valley, sell the herbs and buy a 破障丹 when a bottleneck holds.
	var trips := 0
	while game.player.xp < 8000 and trips < 600:
		trips += 1
		if game.at_bottleneck() and game.item_count("pozhang_pill") > 0:
			game.use_item("pozhang_pill")
		elif not game.at_bottleneck() and game.retreat_efficiency() >= 100 and game.mind_percent() >= 100:
			game.cultivate(game.retreat_most())
		else:
			for bout: int in 2:
				game.start_battle("disciple")
				while not game.battle.is_empty():
					game.plain_turn()
			game.act("rest")
			game.travel("wild")
			for i: int in 3:
				game.act("gather")
			game.travel("market")
			_settle(game)
			for herb: String in game.content.herbs_by_value():
				if game.item_count(herb) > 0:
					game.sell(herb, game.item_count(herb))
			if game.at_bottleneck():
				game.buy("pozhang_pill")
			game.travel("sect")
			_settle(game)
	check(int(game.world.day) < Calendar.to_day(26, 1, 1) and game.item_count("foundation_pill") == 1, "mixed play reaches 炼气圆满 within the outline's 15–25 years (历元 %d 年)" % (int(game.world.day) / Calendar.DAYS_PER_YEAR + 1))
	# The serpent's duel below wants it alive: the valley as before its outbreak.
	for flag: String in ["serpent_rampage", "serpent_slain"]:
		game.world.flags.erase(flag)
	check(game.player.stage == 3 and game.player.max_hp == 120 and game.realm_name() == "炼气圆满", "sub-stages reached by cultivation raise the caps")
	check(game.chronicle.entries.any(func(entry: Dictionary) -> bool: return entry.id == "stage_up" and int(entry.args.stage) == 1 and entry.major), "each sub-stage is a recorded milestone")
	var before_breakthrough: int = game.player.xp
	_steady(game)
	game.act("breakthrough")
	check(game.player.realm == 1 and game.player.stage == 0 and game.player.hp == 140 and game.item_count("foundation_pill") == 0 and game.player.xp == before_breakthrough - 8000, "breakthrough consumes resources and upgrades stats")
	game.travel("wild")
	game.start_battle("serpent")
	check(game.battle.orbs.size() == game.Combat.draw_count(game) + int(game.content.rules.duel.first_extra) and not game.battle.intent.is_empty(), "a duel opens with a hand of qi orbs and the opponent's intent")
	var hand: Array = game.battle.orbs.duplicate()
	for art: String in ["wood", "fire", "seal_wood"]:
		if not art in game.player.learned:
			game.player.learned.append(art)
	game.player.arts = ["qi_strike", "wood", "fire", "seal_wood"]
	game.battle.orbs = ["water", "wood", "wood", "fire", "fire", "metal"]
	game.battle.last = ""
	game.use_skill("wood")
	game.use_skill("fire")
	check(game.battle.orbs == ["water", "metal"] and game.battle.last == "fire" and game.combat_events.any(func(event: Dictionary) -> bool: return event.type == "combo"), "arts spend the orbs their costs name; 离火术 after a wood art is a 连击")
	unchanged = game.snapshot()
	game.use_skill("fire")
	check(game.snapshot() == unchanged, "blocked skill has no side effects")
	game.battle.orbs = ["water", "water", "metal"]
	game.use_skill("qi_strike")
	check(game.battle.orbs == ["metal"], "驱物术 takes two orbs of one element, whichever (同×2)")
	game.battle.orbs = ["metal", "earth"]
	check(not game.Combat.affordable(game.battle.orbs, game.held_technique("qi_strike").cost), "and two of different elements will not do")
	game.battle.orbs = ["wood", "water"]
	game.battle.last = "water"
	game.use_skill("seal_wood")
	check(game.battle.orbs == ["fire", "fire"], "上清印 gains its extra fire orb from generating paid qi")
	# Five qi a turn from the spirit roots alone; four kept, the player choosing what goes.
	check(game.Combat.draw_count(game) == 5 and game.Combat.hand_cap(game) == 4 + int(game.orb_bonus("orb_cap")), "five qi a turn, four kept")
	check(game.Combat.player_weights(game).keys().all(func(element: String) -> bool: return int(game.Combat.player_weights(game)[element]) > 0 == (element in game.player.roots or int(game.orb_bonus("orb_" + element)) > 0)), "qi comes only from the spirit roots")
	game.battle.orbs = ["metal", "metal", "metal", "metal", "metal", "earth"]
	var waiting := int(game.battle.turn)
	check(game.end_turn(false).contains("散去") and int(game.battle.turn) == waiting, "over the cap the turn does not end until the player lets orbs go")
	game.discard_orb("earth")
	check(game.battle.orbs.size() == 5 and not "earth" in game.battle.orbs, "an orb of the chosen element goes")
	game.player.arts = ["qi_strike", "qi_gather", "wood", "fire"]
	game.battle.orbs = ["metal", "metal"]
	game.use_skill("qi_gather")
	check(int(game.battle.get("next_draw", 0)) == 2 and game.battle.orbs.is_empty(), "聚气 brings two more orbs next turn")
	game.battle.orbs = hand
	var copy = Session.new()
	check(copy.restore(JSON.parse_string(JSON.stringify(game.snapshot()))), "active battle JSON round trip")
	game.plain_turn()
	copy.plain_turn()
	check(game.snapshot() == copy.snapshot(), "RNG continues identically after loading")
	var held: int = game.battle.orbs.size()
	game.end_turn()
	# A coil (缠绕) or a freeze (冰封) put on the player in the serpent's turn draws fewer.
	var held_back := 0
	for binding: String in ["slow", "entangle"]:
		if not game.battle.is_empty() and game.battle.player_status.has(binding):
			held_back += int(game.battle.player_status[binding][0])
	check(game.battle.is_empty() or game.battle.orbs.size() == mini(held, game.Combat.hand_cap(game)) + maxi(1, game.Combat.draw_count(game) - held_back), "ending the turn brings the normal draw without guard bonuses")
	var rounds := 0
	while not game.battle.is_empty() and rounds < 40:
		rounds += 1
		game.plain_turn()
	check(game.has_flag("serpent_slain"), "full legal progression slays the serpent (%d turns)" % rounds)
	var after_serpent: int = game.world.day
	var way_home: int = game.content.path_days(game.path_to("sect"))
	game.travel("sect")
	game.act("cultivate")
	check(game.world.day == after_serpent + way_home + 30 and game.player.location == "sect", "world continues after the serpent falls")
	game.travel("wild")
	var settled: Dictionary = game.snapshot()
	game.start_battle("serpent")
	check(game.snapshot() == settled, "slain serpent cannot be fought again")
	var defeated = Session.new()
	defeated.new_game("落败测试", 3)
	defeated.player.hp = 1
	defeated.start_battle("disciple")
	defeated.end_turn()
	check(defeated.battle.is_empty() and defeated.player.location == "sect" and defeated.player.hp > 0, "defeat recovers into playable state")
	check(defeated.player.stones == 20, "defeat penalty bounded")
	var hasty = Session.new()
	hasty.new_game("速战测试", 4)
	hasty.start_battle("disciple")
	hasty.quick_duel()
	check(hasty.battle.is_empty() and hasty.journal_lines().any(func(line: String) -> bool: return line.contains("切磋") or line.contains("获胜") or line.contains("落败") or line.contains("胜")), "速战 plays the duel to its end")
	var escaping = Session.new()
	escaping.new_game("撤离测试", 6)
	escaping.start_battle("disciple")
	# Fleeing a foe of one's own realm may fail (it costs the turn, not days); try until away.
	for attempt: int in 10:
		if escaping.battle.is_empty():
			break
		escaping.player.hp = escaping.player.max_hp
		escaping.flee()
	check(escaping.battle.is_empty() and escaping.world.day == escaping.content.action_days("flee"), "retreat consumes configured days")
	var corrupt: Dictionary = game.snapshot()
	corrupt.player.hp = -1
	unchanged = copy.snapshot()
	check(not copy.restore(corrupt) and copy.snapshot() == unchanged, "bad save rejected without altering current game")
	corrupt = game.snapshot()
	corrupt.version = 99
	check(not copy.restore(corrupt), "future save version rejected")
	var path := "res://.godot/test_saves_%d" % Time.get_ticks_usec()
	var store = SaveStore.new(path)
	check(store.save_game(game), "first save writes")
	var old_day: int = game.world.day
	game.act("gather")
	check(store.save_game(game), "second save writes")
	var loaded = Session.new()
	check(store.load_game(loaded) and loaded.snapshot() == game.snapshot(), "latest save loads")
	var broken_file := FileAccess.open(path.path_join("journey_0.json"), FileAccess.WRITE)
	broken_file.store_string("{broken")
	broken_file.close()
	check(store.load_game(loaded) and loaded.world.day == old_day, "damaged newest save falls back to previous generation")
	print("CORE: %d checks, %d failures" % [checks, failures])
	quit(0 if failures == 0 else 1)

## Fixes the breakthrough's rolls: no 心魔, and a roll twenty points under the odds (a 中品 foundation,
## whose numbers are the plain ones).
func _steady(game) -> void:
	game.fortune = {"demon": 0.99, "breakthrough": maxf(0.0, float(game.breakthrough_odds(game.breakthrough_plan()).total - 20) / 100.0)}
