extends SceneTree
## Storylines: the guided start that holds a new disciple to its steps, the sect's own errands and
## lessons that follow by 传音, the key people's stories, ordinary acquaintances' requests, friends'
## congratulations, and how all of it survives a save.
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
	_content()
	var game := _guided_start()
	_sect_storylines(game)
	_saves(game)
	_key_people()
	_requests()
	_older_journeys()
	print("STORIES: %d checks, %d failures" % [checks, failures])
	quit(0 if failures == 0 else 1)

func _game(start: String = "guided", seed_value: int = 21) -> Session:
	var game := Session.new()
	game.encounters_enabled = false
	game.new_game("入门", seed_value, ["metal", "wood", "fire"], start)
	return game

func _last(game: Session) -> String:
	return game.journal_lines().back()

func _duel(game: Session, enemy_id: String) -> void:
	game.start_battle(enemy_id)
	var turns := 0
	while not game.battle.is_empty() and turns < 60:
		turns += 1
		if game.player.hp < game.player.max_hp / 3 and int(game.battle.cooldowns.get("wood", 0)) == 0 and game.player.qi >= 8:
			game.use_skill("wood")
		else:
			game.use_skill("sword")

func _content() -> void:
	var game := Session.new()
	check(game.content.error_message.is_empty(), "content with storylines loads (%s)" % game.content.error_message)
	check(game.content.storylines.has("intro") and bool(game.content.storylines.intro.guide), "the introduction is the guided storyline")
	var broken := Session.new()
	broken.content.storylines.errands.giver = "nobody"
	check(not broken.content._validate().is_empty(), "a storyline with an unknown giver is rejected")
	broken = Session.new()
	broken.content.storylines.errands.steps[1].deeds = {"win:dragon": 1}
	check(not broken.content._validate().is_empty(), "a step counting an unknown deed is rejected")
	broken = Session.new()
	broken.content.storylines.intro.steps[0].letter = true
	broken.content.storylines.intro.steps[0].erase("say")
	check(not broken.content._validate().is_empty(), "a 传音 step without words is rejected")
	var plain := _game("plain")
	check(plain.story_state("intro").is_empty() and plain.has_flag("intro_done") and plain.guide_step().is_empty(), "a plain journey has no storyline and the sect's halls are open")

## The introduction, step by step: what it allows, what it refuses, and what each step leaves.
func _guided_start() -> Session:
	var game := _game()
	check(game.story_at("intro", "retreat") and not game.has_flag("intro_done"), "a guided journey begins at the first step")
	check(_last(game).contains("许清和") and _last(game).contains("闭关一个月"), "the mentor's words open it (%s)" % _last(game))
	check(not game.available_here("commissions") and not game.available_here("study"), "the commission board and the hall wait until the introduction is done")
	var day := int(game.world.day)
	check(game.travel("ridge").contains("嘱咐") and int(game.world.day) == day, "the guided start holds the player at the sect")
	game.cultivate(90)
	check(int(game.world.day) == 30 and game.story_at("intro", "spar"), "the first retreat lasts the month the mentor asked for and moves the guide on")
	check(game.cultivate(30).contains("嘱咐") and int(game.world.day) == 30, "no second retreat before the next step")
	_duel(game, "disciple")
	check(game.story_at("intro", "herbs"), "a spar, won or lost, moves the guide on")
	day = int(game.world.day)
	check(game.travel("market").contains("嘱咐") and int(game.world.day) == day, "only the step's place can be travelled to")
	game.travel("ridge")
	check(game.player.location == "ridge" and game.pending_event.is_empty(), "the road to the step's place is open and quiet")
	var rounds := 0
	while game.herb_count() < 3 and rounds < 10:
		rounds += 1
		game.act("gather")
	check(game.story_at("intro", "herbs"), "herbs alone are not the whole step")
	game.interact("azhi", "talk")
	check(game.story_at("intro", "return"), "herbs and a word with 阿芷 finish it")
	game.travel("sect")
	var stones := int(game.player.stones)
	var herbs: int = game.herb_count()
	check(not game.npc_options("xu_qinghe").filter(func(option: Dictionary) -> bool: return option.id == "hand_herbs").is_empty(), "the mentor asks for the herbs")
	game.interact("xu_qinghe", "hand_herbs")
	check(game.story_at("intro", "market") and int(game.player.stones) == stones + 30 and game.herb_count() == herbs - 3 and game.item_count("huiqi_pill") == 2, "handing them in pays and sends the player to market")
	game.travel("market")
	if not game.pending_event.is_empty():
		game.choose_event(str(game.pending_definition().choices.back().id))
	game.buy("huiqi_pill")
	check(game.story_at("intro", "report"), "one trade at the market is enough")
	game.travel("sect")
	game.interact("xu_qinghe", "report")
	check(game.story_state("intro") == "done" and game.has_flag("intro_done") and game.guide_step().is_empty(), "the report ends the introduction")
	check(bool(game.world.people.xu_qinghe.get("sound", false)) and game.item_count("pozhang_pill") == 1, "the mentor leaves a 传音符 and a 破障丹")
	check(game.available_here("commissions") and game.available_here("study"), "the board and the hall are open now")
	check(game.story_state("errands") == "active" and game.story_state("lineage") == "active" and game.story_at("lineage", "visit"), "the sect's own storylines follow")
	check(game.journal_lines().any(func(line: String) -> bool: return line.contains("顾长庚长老")), "and the next one is told at once")
	day = int(game.world.day)
	game.travel("town")
	check(game.player.location == "town", "travel is free after the introduction")
	game.travel("sect")
	check(int(game.world.day) > day, "time went by on the road")
	return game

## Errands come by 传音 after a while and end a stay; the elder's lessons follow the player's own steps.
func _sect_storylines(game: Session) -> void:
	var since := int(game.world.storylines.errands.since)
	var message := game.wait(360)
	check(int(game.world.day) == since + 90 and message.contains("传音") and game.story_at("errands", "dew"), "a 传音 ends a stay on the day the errand comes (%d)" % (int(game.world.day) - since))
	check(game.unread_letters() == 1 and str(game.world.letters.back().npc) == "xu_qinghe", "the letter waits in the inbox")
	game.mark_letters_read()
	check(game.unread_letters() == 0, "and is marked read once looked at")
	game.set_item_count("ninglu_grass", 3)
	var mind := int(game.player.mind)
	game.interact("xu_qinghe", "hand_dew")
	check(game.story_step("errands").id == "wait_wolf" and game.item_count("ninglu_grass") == 0 and int(game.player.mind) == mind + 2, "handing in the dew grass pays and tempers the mind")
	game.interact("gu_changgeng", "talk")
	check(game.story_at("lineage", "choose"), "a word with the elder is the visit")
	game.choose_sect("qingyun")
	check(game.story_step("lineage").id == "foundation" and not game.story_at("lineage", "foundation") and bool(game.world.people.gu_changgeng.get("sound", false)), "choosing a lineage pleases him; the next lesson waits for 炼气圆满")
	game.player.stage = 3
	game.player.xp = 1500
	game.refresh_realm_stats()
	game.wait(1)
	check(game.story_at("lineage", "foundation") and game.world.letters.back().story == "lineage", "reaching 圆满 brings his 传音")
	game.interact("gu_changgeng", "ask_foundation")
	check(game.story_step("lineage").id == "ruin" and game.item_count("ningqi_pill") == 1, "his lesson comes with a 凝气丹")

func _saves(game: Session) -> void:
	var copy := Session.new()
	check(copy.restore(JSON.parse_string(JSON.stringify(game.snapshot()))) and copy.snapshot() == game.snapshot(), "storylines, letters and deeds survive a save")
	var bad: Dictionary = game.snapshot()
	bad.world.storylines.errands.state = "lost"
	check(not copy.restore(bad), "an unknown storyline state is rejected")
	bad = game.snapshot()
	bad.world.storylines.errands.step = 99
	check(not copy.restore(bad), "an active step past the end is rejected")
	bad = game.snapshot()
	bad.player.deeds.duel = -1
	check(not copy.restore(bad), "a negative deed count is rejected")
	bad = game.snapshot()
	bad.world.letters[0].day = int(game.world.day) + 5
	check(not copy.restore(bad), "a letter from the future is rejected")
	var retired: Dictionary = game.snapshot()
	retired.world.storylines["forgotten"] = {"state": "active", "step": 0, "since": 0, "begun": true, "base": {}}
	retired.world.letters.append({"npc": "xu_qinghe", "day": 0, "read": false, "story": "forgotten", "step": "x"})
	check(copy.restore(retired) and not copy.world.storylines.has("forgotten") and copy.world.letters.size() == game.world.letters.size(), "retired storylines and their letters are dropped, not fatal")
	var guided := _game()
	guided.cultivate(10)
	var held := Session.new()
	check(held.restore(JSON.parse_string(JSON.stringify(guided.snapshot()))) and held.story_at("intro", "retreat") and held.travel("ridge").contains("嘱咐"), "a guided journey stays guided after loading")

func _key_people() -> void:
	# 沈墨 and the 破鳞散: the serpent starts the duel hurt.
	var game := _game("skipped", 31)
	check(game.story_state("intro") == "done" and game.story_state("lineage") == "active", "a skipped introduction lets the sect's storylines follow")
	game.travel("ridge")
	game.interact("azhi", "talk")
	game.world.people.shen_mo = {"met": true, "relation": 15, "last": {}, "absent_until": -1, "talks": 0, "met_day": 0, "met_place": "market"}
	game.travel("market")
	game.interact("shen_mo", "ask_redscale")
	check(game.story_at("shen_redscale", "brew") and _last(game).contains("破鳞散"), "沈墨 tells of the 赤鳞果 and offers the 破鳞散")
	game.set_item_count("ninglu_grass", 3)
	game.set_item_count("chiyan_flower", 2)
	game.interact("shen_mo", "brew")
	check(game.item_count("polin_powder") == 1 and game.story_at("shen_redscale", "slay"), "the herbs become a 破鳞散")
	game.use_item("polin_powder")
	check(game.has_flag("serpent_weakened"), "taking it readies the player")
	game.player.realm = 1
	game.player.mind = 36
	game.refresh_realm_stats()
	game.player.hp = game.player.max_hp
	game.travel("wild")
	game.start_battle("serpent")
	check(int(game.battle.hp) == 112, "the serpent starts the duel with seven tenths of its health (%d)" % int(game.battle.hp))
	game.world.people.azhi.relation = 39
	Session.Events.apply(game, [{"relation": ["azhi", 1]}])
	check(bool(game.world.people.azhi.get("sound", false)) and _last(game).contains("传音符"), "a close enough bond exchanges 传音符")
	game.battle.hp = 1
	var letters: int = game.world.letters.size()
	game.use_skill("sword")
	check(game.has_flag("serpent_slain") and game.story_state("shen_redscale") == "done", "slaying it ends 沈墨's story")
	check(game.world.letters.size() > letters and game.world.letters.any(func(letter: Dictionary) -> bool: return letter.npc == "azhi" and letter.get("kind", "") == "serpent"), "friends send word of the serpent")
	# 柳寒舟 and 石寒: persuading opens the cave without a fight.
	var liu := _game("plain", 41)
	liu.world.flags.helped_wanderer = true
	liu.world.flags.found_ruin = true
	liu.wait(1)
	check(liu.story_at("liu_squatter", "persuade") and liu.world.letters.back().npc == "wounded", "柳寒舟 asks by 传音 to spare his brother")
	liu.travel("ruin")
	liu.interact("squatter", "persuade")
	check(liu.has_flag("ruin_cleared") and liu.npc_location("squatter").is_empty() and liu.story_step("liu_squatter").id == "wait_thanks", "his words send 石寒 away and open the cave")
	var stones := int(liu.player.stones)
	liu.wait(40)
	check(liu.story_state("liu_squatter") == "done" and int(liu.player.stones) == stones + 50 and liu.item_count("ningqi_pill") == 1, "a month later his thanks arrive")
	var fought := _game("plain", 42)
	fought.world.flags.helped_wanderer = true
	fought.world.flags.found_ruin = true
	fought.wait(1)
	fought.world.flags.ruin_cleared = true
	fought.wait(1)
	check(fought.story_state("liu_squatter") == "closed" and _last(fought).contains("不怪你"), "fighting instead closes his story with a word")
	# 钱货郎 and the robber.
	var road := _game("plain", 43)
	road.world.people.peddler = {"met": true, "relation": 6, "last": {}, "absent_until": -1, "talks": 0, "met_day": 0, "met_place": "town"}
	road.travel("ferry")
	while road.npc_location("peddler") != road.player.location:
		road.wait(1)
	road.interact("peddler", "ask_trouble")
	check(road.story_at("peddler_robbed", "hunt"), "the peddler tells of the robbery")
	road.player.realm = 1
	road.refresh_realm_stats()
	road.player.hp = road.player.max_hp
	while road.npc_location("rogue") != road.player.location:
		road.wait(1)
	road.interact("rogue", "fight")
	var turns := 0
	while not road.battle.is_empty() and turns < 60:
		turns += 1
		road.use_skill("sword")
	check(road.item_count("peddler_pack") == 1 and road.story_at("peddler_robbed", "return"), "beating the robber wins back the pack")
	while road.npc_location("peddler") != road.player.location:
		road.wait(1)
	road.interact("peddler", "return_pack")
	road.player.stones = 60
	var offers := road.npc_options("peddler")
	check(road.has_flag("peddler_friend") and offers.any(func(option: Dictionary) -> bool: return option.id == "buy_pill_friend" and option.available) and offers.any(func(option: Dictionary) -> bool: return option.id == "buy_pill" and not option.available), "returning it earns the friend's price")
	# 老艄公's sword mark needs foundation.
	var river := _game("plain", 44)
	river.travel("ferry")
	river.world.people.boatman.relation = 10
	river.interact("boatman", "ask_sword")
	check(river.story_at("boatman_sword", "dive") and not river.npc_options("boatman").filter(func(option: Dictionary) -> bool: return option.id == "dive")[0].available, "the boatman's story waits for foundation")
	river.player.realm = 1
	river.refresh_realm_stats()
	river.interact("boatman", "dive")
	check(river.story_state("boatman_sword") == "done" and river.player.items.keys().any(func(item_id: String) -> bool: return item_id.begins_with("j:")), "the sword mark becomes a manual")
	# 何三更 turns deeds into tales.
	var tales := _game("plain", 45)
	tales.travel("town")
	tales.world.flags.ruin_cleared = true
	var mind := int(tales.player.mind)
	tales.wait(1)
	check(int(tales.player.mind) == mind + 2 and tales.journal_lines().any(func(line: String) -> bool: return line.contains("新段子")), "the storyteller tells of the cleared cave")

## Ordinary acquaintances sometimes need an herb or a pill.
func _requests() -> void:
	var game := _game("plain", 51)
	game.wait(1)
	var asking := ""
	for rounds: int in 40:
		for person_id: String in game.present_npcs():
			if game.request_open(person_id):
				asking = person_id
				break
		if not asking.is_empty():
			break
		game.wait(180)
	check(not asking.is_empty(), "someone at the sect asks for help sooner or later")
	if asking.is_empty():
		return
	var option: Dictionary = game.npc_options(asking).filter(func(entry: Dictionary) -> bool: return entry.id == "help")[0]
	check(not option.available and option.label.begins_with("相助"), "helping needs what they ask for")
	var request: Dictionary = game.People.request_of(game, asking)
	game.set_item_count(request.item, int(request.count))
	var stones := int(game.player.stones)
	var mind := int(game.player.mind)
	game.interact(asking, "help")
	check(game.item_count(request.item) == 0 and int(game.player.stones) == stones + int(request.stones) and int(game.player.mind) == mind + 2 and game.favor(asking) == 12, "helping pays, tempers the mind and wins favor")
	check(not game.request_open(asking) and game.deed_count("help") == 1, "and answers the request for this season")

## Journeys from before the storylines are past the introduction, and the sect's storylines begin.
func _older_journeys() -> void:
	var old := Session.new()
	check(old.restore(JSON.parse_string(FileAccess.get_file_as_string("res://tests/fixtures/v10_heavenly_midstage.json"))), "an older save loads")
	check(old.story_state("intro") == "done" and old.has_flag("intro_done") and old.guide_step().is_empty(), "an older journey counts the introduction as done")
	check("retreat" in old.player.taught and "arts" in old.player.taught and old.world.letters.is_empty(), "the cards it knew stay dismissed")
	old.wait(1)
	check(old.story_state("lineage") == "active" and old.story_state("errands") == "active", "the sect's storylines begin on its next action")
	var v11 := Session.new()
	check(v11.restore(JSON.parse_string(FileAccess.get_file_as_string("res://tests/fixtures/v11_after_retreats.json"))), "a version 11 save loads")
	check(int(v11.player.xp) == 272 and int(v11.player.mind) == 0 and v11.player.deeds.is_empty() and v11.has_flag("intro_done") and v11.available_here("study"), "it keeps its progress and finds the sect's halls open")
	check(int(v11.world.people.azhi.relation) == 43 and not bool(v11.world.people.azhi.get("sound", false)), "an old bond keeps its favor; the 传音符 come with the next dealings")
	Session.Events.apply(v11, [{"relation": ["azhi", 1]}])
	check(bool(v11.world.people.azhi.get("sound", false)), "and then they do")
	var round_trip := Session.new()
	check(round_trip.restore(JSON.parse_string(JSON.stringify(v11.snapshot()))) and round_trip.snapshot() == v11.snapshot(), "the upgraded journey saves and loads as version 12")
