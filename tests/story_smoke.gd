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
	var game := _opening()
	_sect_storylines(game)
	_saves(game)
	_key_people()
	_requests()
	_foundation_pace()
	_true_disciple()
	_furnace_bounty()
	_older_journeys()
	_qi_years()
	print("STORIES: %d checks, %d failures" % [checks, failures])
	quit(0 if failures == 0 else 1)

func _game(start: String = "rushi", seed_value: int = 21) -> Session:
	var game := Session.new()
	game.encounters_enabled = false
	game.new_game("入门", seed_value, ["metal", "wood", "fire"], start)
	return game

func _option(game: Session, person_id: String, option_id: String) -> Dictionary:
	for option: Dictionary in game.npc_options(person_id):
		if option.id == option_id:
			return option
	return {}

func _last(game: Session) -> String:
	return game.journal_lines().back()

func _duel(game: Session, enemy_id: String) -> void:
	game.start_battle(enemy_id)
	var turns := 0
	while not game.battle.is_empty() and turns < 60:
		turns += 1
		game.plain_turn()

func _content() -> void:
	var game := Session.new()
	check(game.content.error_message.is_empty(), "content with storylines loads (%s)" % game.content.error_message)
	check(game.content.storylines.has("rushi") and not bool(game.content.storylines.rushi.get("guide", false)), "the 入世 opening is a storyline that holds nobody to it")
	var broken := Session.new()
	broken.content.storylines.errands.giver = "nobody"
	check(not broken.content._validate().is_empty(), "a storyline with an unknown giver is rejected")
	broken = Session.new()
	broken.content.storylines.errands.steps[1].deeds = {"win:dragon": 1}
	check(not broken.content._validate().is_empty(), "a step counting an unknown deed is rejected")
	broken = Session.new()
	broken.content.storylines.rushi.steps[0].letter = true
	broken.content.storylines.rushi.steps[0].erase("say")
	check(not broken.content._validate().is_empty(), "a 传音 step without words is rejected")
	var plain := _game("plain")
	check(plain.story_state("rushi").is_empty() and plain.has_flag("rushi_done") and plain.guide_step().is_empty() and plain.available_here("study"), "a plain journey has no storyline and the sect's halls are open")

## The 入世 opening, step by step (docs/GAME_OUTLINE.md 4): a wanderer at the 青石镇 inn, 云溪 and its
## gathering, the first auction, 潜龙会 and the banquet; then the old city's first clue and 青云.
func _opening() -> Session:
	var game := _game()
	check(game.player.location == "town" and game.affiliation().is_empty() and game.story_at("rushi", "inn") and not game.has_flag("rushi_done"), "a journey begins as a wanderer at the 青石镇 inn")
	check(game.pending_event.get("id", "") == "rushi_inn", "where someone is paying the rent with a fake ring")
	check(not game.available_here("commissions") and game.available_here("cultivate"), "a wanderer has no sect board, but the inn lets a room to retreat in")
	game.choose_event("help")
	check(game.story_at("rushi", "road") and game.world.people.lu_chengzhou.met, "陆承舟 met, the road to 云溪 lies ahead")
	check(game.travel("ridge").contains("抵达"), "nothing holds the player to the story")
	game.travel("market")
	check(game.pending_event.get("id", "") == "rushi_gate", "at the gate of 云溪 a cart has overturned")
	game.choose_event("help")
	game.wait(1)
	check(game.pending_event.get("id", "") == "rushi_fair", "inside, the gathering")
	game.choose_event("ask")
	check(game.world.people.ye_zhiwei.met and game.world.people.shen_mo.met, "叶知微 and 沈墨 are met at the gathering")
	while game.pending_event.is_empty() and int(game.world.day) < 60:
		game.wait(1)
	check(game.pending_event.get("id", "") == "rushi_auction" and game.has_flag("mirror_seen") and game.world.people.wen_zhaoheng.met, "the first auction: the broken mirror shows a city, the old cultivator watches")
	game.choose_event("watch")
	while game.pending_event.is_empty() and int(game.world.day) < 90:
		game.wait(1)
	check(game.pending_event.get("id", "") == "qianlong_entry" and game.world.people.wenren_zhao.met, "三月初 潜龙会 opens; 闻人照 is there")
	game.choose_event("watch")
	while game.pending_event.is_empty() and int(game.world.day) < 120:
		game.wait(1)
	check(game.pending_event.get("id", "") == "rushi_banquet", "the 陆府 banquet follows")
	game.choose_event("ye")
	check(game.story_state("rushi") == "done" and game.has_flag("rushi_done") and game.has_flag("heard_qingyun_recruit"), "the banquet ends the opening, with 青云's recruiting known")
	check(game.story_at("mirror", "tianhe"), "and the old city's first clue: the 天河 crossing on a full moon")
	game.travel("ferry")
	while not game.has_flag("tianhe_seen") and int(game.world.day) < 200:
		if not game.pending_event.is_empty():
			game.choose_event(str(game.pending_definition().choices[0].id))
		else:
			game.wait(1)
	check(game.has_flag("tianhe_seen") and game.Calendar.day_of_month(int(game.world.day)) == 15 and game.story_at("mirror", "accounts"), "on the fifteenth the water shows the city, and its crest is to be asked about")
	while not game.pending_event.is_empty():
		game.choose_event(str(game.pending_definition().choices[0].id))
	game.travel("sect")
	while not game.pending_event.is_empty():
		game.choose_event(str(game.pending_definition().choices[0].id))
	check(not game.available_here("cultivate") and game.available_here("join_sect"), "a wanderer at 青云 sees only the recruiting terrace")
	game.join_sect()
	check(game.affiliation() == "qingyun" and game.available_here("cultivate") and game.available_here("commissions") and game.available_here("study") and not game.available_here("join_sect"), "joining opens the chamber, the board and the hall")
	game.wait(1)
	check(game.story_state("errands") == "active" and game.story_state("lineage") == "active" and game.story_at("lineage", "visit"), "the sect's own storylines follow")
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
	game.player.xp = 6000
	game.refresh_realm_stats()
	game.wait(1)
	check(game.story_at("lineage", "foundation") and game.world.letters.any(func(letter: Dictionary) -> bool: return letter.story == "lineage" and letter.step == "foundation"), "reaching 圆满 brings his 传音")
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
	var opening := _game()
	var held := Session.new()
	check(held.restore(JSON.parse_string(JSON.stringify(opening.snapshot()))) and held.story_at("rushi", "inn") and held.pending_event.get("id", "") == "rushi_inn", "the opening survives a save")

func _key_people() -> void:
	# 沈墨 and the 破鳞散: the serpent starts the duel hurt.
	var game := _game("free", 31)
	check(game.story_state("rushi") == "done" and game.player.location == "town" and game.affiliation().is_empty(), "a skipped opening leaves a wanderer free at the inn")
	game.travel("sect")
	game.join_sect()
	game.wait(1)
	check(game.story_state("lineage") == "active", "joining 青云 lets the sect's storylines follow")
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
	check(int(game.battle.hp) == int(game.content.enemies.serpent.hp) * 7 / 10, "the serpent starts the duel with seven tenths of its health (%d)" % int(game.battle.hp))
	game.world.people.azhi.relation = 39
	Session.Events.apply(game, [{"relation": ["azhi", 1]}])
	check(bool(game.world.people.azhi.get("sound", false)) and _last(game).contains("传音符"), "a close enough bond exchanges 传音符")
	game.battle.hp = 1
	var letters: int = game.world.letters.size()
	_sword(game)
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
	check(liu.story_state("liu_squatter") == "done" and int(liu.player.stones) == stones + 53 and liu.item_count("ningqi_pill") == 1, "a month later his thanks arrive")
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
		road.plain_turn()
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

## After foundation the sect's summons come years apart, each gap longer than the last, and longer stays
## are offered: a year or two is a short while now.
func _foundation_pace() -> void:
	var game := _game("plain", 61)
	check(game.wait_options().map(func(days: Variant) -> int: return int(days)) == [1, 10], "炼气 offers stays of a day or ten")
	game.player.realm = 1
	game.player.mind = 36
	game.refresh_realm_stats()
	game.player.hp = game.player.max_hp
	game.wait(1)
	check(game.story_state("inner_court") == "" and game.wait_options().map(func(days: Variant) -> int: return int(days)) == [1, 10, 30, 90], "foundation opens longer stays; the inner court waits for promotion")
	game.player.merit = 400
	check(game.promote().contains("外门精英") and game.promote().contains("内门弟子"), "enough merit after foundation earns two promotions at the hall")
	check(game.story_state("inner_court") == "active", "and entering the inner court opens its storyline")
	var letters: Array[int] = []
	var start := int(game.world.day)
	# Other 传音 of those years (南行 after foundation, the auction's reminder) may end a stay first.
	var stays := 0
	while not game.story_at("inner_court", "patrol") and stays < 6:
		stays += 1
		game.wait(400)
	letters.append(int(game.world.day) - start)
	check(game.story_at("inner_court", "patrol") and letters[0] == 360, "a year later the first summons ends the stay (%d)" % letters[0])
	game.record_deed("win:rogue")
	game.wait(1)
	check(game.story_step("inner_court").id == "wait_tide", "the patrol done, the court is quiet again")
	start = int(game.world.day)
	stays = 0
	while not game.story_at("inner_court", "tide") and stays < 6:
		stays += 1
		game.wait(800)
	letters.append(int(game.world.day) - start)
	check(game.story_at("inner_court", "tide") and letters[1] == 720, "two years later the spirit tide (%d)" % letters[1])
	var xp := int(game.player.xp)
	game.travel("wild")
	check(game.story_step("inner_court").id == "wait_trial" and int(game.player.xp) == xp + 1800, "reaching the spring takes in the tide")
	start = int(game.world.storylines.inner_court.since)
	stays = 0
	while not game.story_at("inner_court", "trial") and stays < 10:
		stays += 1
		game.wait(1200)
	letters.append(int(game.world.day) - start)
	check(game.story_at("inner_court", "trial") and letters[2] == 1080, "three years later the trial (%d)" % letters[2])
	game.travel("sect")
	_duel(game, "disciple")
	check(game.story_state("inner_court") == "done" and game.player.items.keys().any(func(item_id: String) -> bool: return item_id.begins_with("j:")), "the trial ends with the elder's own manual")

## 真传之责: forming the core summons the player to the elder; two 魔修 put down; two years on, an old
## story and a 地阶 slip.
func _true_disciple() -> void:
	var game := _game("plain", 62)
	game.player.realm = 2
	game.player.mind = 120
	game.refresh_realm_stats()
	game.player.hp = game.player.max_hp
	game.wait(1)
	check(game.story_at("true_disciple", "summon") or game.story_at("true_disciple", "demons"), "forming the core summons the player to the elder")
	game.travel("ferry")
	game.travel("sect")
	check(game.story_at("true_disciple", "demons"), "who sends them after the 魔修")
	game.record_deed("win:mo_xiu", 2)
	var stones := int(game.player.stones)
	game.wait(1)
	check(game.story_step("true_disciple").id == "wait_secret" and int(game.player.stones) == stones + 300, "two put down, the sect rewards it")
	game.travel("ferry")
	var stays := 0
	while not game.story_at("true_disciple", "secret") and stays < 6:
		stays += 1
		game.wait(400)
	check(game.story_at("true_disciple", "secret"), "two years later an old story waits at the hall")
	game.travel("sect")
	check(game.story_state("true_disciple") == "done" and game.player.items.keys().any(func(item_id: String) -> bool: return item_id.begins_with("j:") and int(game.content.item(item_id).tier) == 4), "and a 地阶 slip from the old secret realm")

## 熔窟逃人 (stage two, batch D): 袁赤锋 at 赤霄门's foundry asks three 地火精, then names a bounty on
## 韩烬, hidden past the 火蜥 in the 熔窟. Three endings: turned in for the bounty, exposed with his
## ledger (only once heard out; the 执事 is dismissed), or let go north.
func _furnace_bounty() -> void:
	for ending: String in ["turn_in", "expose", "let_go"]:
		var game := _game("plain", 64)
		game.player.realm = 1
		game.refresh_realm_stats()
		game.player.hp = game.player.max_hp
		game.player.stones = 400
		game.world.flags.tiannan_known = true
		game.travel("chixiao_gate")
		check(game.player.location == "chixiao_gate" and "yuan_chifeng" in game.present_npcs(), "袁赤锋 keeps 赤霄门's foundry (%s)" % ending)
		game.interact("yuan_chifeng", "ask_bounty")
		check(game.story_at("furnace_bounty", "fire"), "he asks for three 地火精")
		game.set_item_count("dihuo_jing", 3)
		var stones := int(game.player.stones)
		game.wait(1)
		check(game.story_at("furnace_bounty", "find") and game.item_count("dihuo_jing") == 0 and int(game.player.stones) == stones + 200, "brought, they are paid for, and the bounty on 韩烬 is named")
		game.world.flags.dihuo_lizard_down = true
		game.travel("chifeng")
		check(game.story_at("furnace_bounty", "decide") and "han_jin" in game.present_npcs(), "past the 火蜥 he is found at the 熔窟")
		if ending == "expose":
			check(_option(game, "han_jin", "expose").is_empty() or not _option(game, "han_jin", "expose").get("reason", "").is_empty(), "the ledger cannot be shown before he is heard out")
			game.interact("han_jin", "hear_out")
			game.travel("chixiao_gate")
			game.interact("yuan_chifeng", "verify_forge")
			check(game.has_flag("furnace_evidence"), "the ledger is corroborated at the foundry")
			game.travel("chifeng")
		stones = int(game.player.stones)
		game.interact("han_jin", ending)
		game.wait(1)
		check(game.story_state("furnace_bounty") == "done" and not "han_jin" in game.present_npcs(), "%s ends the storyline, and he is gone" % ending)
		match ending:
			"turn_in":
				check(game.has_flag("bounty_turned_in") and int(game.player.stones) == stones + 300, "turned in: three hundred stones")
			"expose":
				game.travel("chixiao_gate")
				check(game.has_flag("bounty_exposed") and int(game.player.stones) >= stones + 150 and not "yuan_chifeng" in game.present_npcs(), "exposed: half the bounty, and 袁赤锋 is dismissed from the foundry")
			"let_go":
				check(game.has_flag("bounty_let_go") and int(game.player.stones) == stones, "let go: no bounty paid")

## Journeys from before the storylines are past the introduction, and the sect's storylines begin.
## Settles whatever the day brought, with the named choice where it is offered, else the last one.
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

## Goes to where someone is today and settles what the road brought.
func _visit(game: Session, person_id: String) -> void:
	var place: String = game.npc_location(person_id)
	if not place.is_empty() and place != str(game.player.location):
		game.travel(place)
		_settle(game)

## 炼气篇 (docs/GAME_OUTLINE.md, batch 2): the 散修's and the disciple's 筑基 plans, the lodge by the
## stream, the crest's three accounts, two ordinary cultivators' crafts, and the herb road before the
## serpent.
func _qi_years() -> void:
	var game := _game("free", 71)
	check(game.story_state("mirror") == "active", "a skipped opening still leaves 温照衡's note")
	check(int(game.content.realm(0).breakthrough.xp) == 8000 and int(game.content.realm(1).breakthrough.xp) == 30000, "炼气 asks 8000 xp and 筑基 30000: the slower pace of the outline")
	# 筑基之备 for a 散修: at 炼气后期, 沈墨 tells of pill, guard and ground.
	game.player.stage = 2
	game.player.xp = 4000
	game.player.mind = 40
	game.refresh_realm_stats()
	game.wait(1)
	_settle(game)
	check(game.story_at("zhuji_plan", "ask") and game.story_state("zhuji_sect") == "", "炼气后期 opens the 散修's 筑基 plan, not the sect's")
	_visit(game, "shen_mo")
	check(_option(game, "shen_mo", "ask_foundation").get("available", false), "沈墨 can be asked about 筑基")
	game.interact("shen_mo", "ask_foundation")
	check(game.story_at("zhuji_plan", "pill"), "then the pill is the first thing to find")
	game.add_item("foundation_pill", 1)
	game.wait(1)
	_settle(game)
	check(game.story_at("zhuji_plan", "place"), "with the pill in hand, the place to break through")
	# 溪畔竹舍: a lodge let by the year beside the inn; no rent by the month, a whole retreat's yield.
	if str(game.player.location) != "market":
		game.travel("market")
		_settle(game)
	game.player.stones = 300
	var inn_rate: int = game.cultivation_rate()
	check(int(game.Cultivation.rent(game, 30)) == 8, "云来客栈's room asks 8 stones a month")
	check(game.take_lease().contains("溪畔竹舍") and game.has_flag("yunxi_abode") and int(game.player.stones) == 180, "the lodge is let for a year at 120 stones")
	check(game.cultivation_rate() > inn_rate and int(game.Cultivation.rent(game, 30)) == 0, "a retreat in the lodge yields in full and asks no rent (%d > %d)" % [game.cultivation_rate(), inn_rate])
	game.wait(1)
	_settle(game)
	check(game.story_state("zhuji_plan") == "done", "a place of one's own ends the plan")
	game.player.stage = 3
	game.player.xp = 8000
	game.refresh_realm_stats()
	var parts: Array = game.breakthrough_odds(game.breakthrough_plan()).parts
	check(parts.any(func(part: Array) -> bool: return str(part[0]) == "溪畔竹舍" and int(part[1]) == 5), "breaking through in the lodge adds to the odds")
	# The crest: the full moon's ending sends the player to three people who tell it three ways.
	game.world.flags["tianhe_seen"] = true
	game.wait(1)
	_settle(game)
	check(game.story_at("mirror", "accounts"), "after the full moon, the crest's accounts")
	for asked: Array in [["boatman", "crest_boatman"], ["storyteller", "crest_storyteller"], ["qin_yan", "crest_qin"]]:
		_visit(game, str(asked[0]))
		check(_option(game, str(asked[0]), "crest").get("available", false), "%s can be asked about the crest" % asked[0])
		game.interact(str(asked[0]), "crest")
		check(game.has_flag(str(asked[1])), "%s tells their account" % asked[0])
	game.wait(1)
	_settle(game)
	check(game.has_flag("crest_puzzled") and not game.story_at("mirror", "accounts"), "three accounts that disagree: why does nobody remember?")
	check(game.story_step("mirror").id == "archive" and not game.Storylines.at_step(game, "mirror", "archive"), "the next step, 北岳's archive, waits for 筑基 and 天南")
	# Two ordinary cultivators trade a craft for what they need.
	_visit(game, "qin_yan")
	game.add_item("ninglu_grass", 3)
	game.interact("qin_yan", "trap_lore")
	check(game.has_flag("trap_lore") and game.item_count("ninglu_grass") == 0, "秦砚 teaches the 阵谱 for three 凝露草")
	_visit(game, "fan_jiu")
	game.add_item("wolf_fang", 2)
	game.interact("fan_jiu", "beast_lore")
	check(game.has_flag("beast_lore") and game.item_count("wolf_fang") == 0, "樊九 teaches the tracks for two 狼牙")
	var wolf: Dictionary = game.content.events.road_wolf
	check(wolf.choices.any(func(choice: Dictionary) -> bool: return str(choice.id) == "track" and game.choice_available(choice)), "his tracks let one slip past the road's wolves")
	# The sect's plan: 许清和 sends word at 炼气后期.
	var disciple := _game("plain", 72)
	disciple.player.stage = 2
	disciple.player.xp = 4000
	disciple.player.mind = 40
	disciple.refresh_realm_stats()
	disciple.wait(1)
	_settle(disciple)
	check(disciple.story_state("zhuji_sect") == "active" and disciple.story_state("zhuji_plan") == "", "a disciple's 筑基 plan comes from the hall")
	disciple.add_item("foundation_pill", 1)
	disciple.player.stage = 3
	disciple.player.xp = 6000
	disciple.refresh_realm_stats()
	for i: int in 3:
		disciple.wait(1)
		_settle(disciple)
	check(disciple.story_state("zhuji_sect") == "done", "pill and 炼气圆满 complete it")
	# The herb road: prices quarrel in 历元 8 年, and in 11 the spring stirs before the serpent wakes.
	var road := _game("free", 73)
	road.world.day = Calendar.to_day(8, 9, 1)
	road.travel("market")
	var met := ""
	for i: int in 5:
		if road.pending_event.get("id", "") == "herb_shortage":
			met = "herb_shortage"
			road.choose_event("ask")
		_settle(road)
		if met.is_empty():
			road.wait(1)
	check(met == "herb_shortage" and road.has_flag("herb_asked"), "历元 8 年: the herb prices quarrel at 沈墨's shop")
	road.world.day = Calendar.to_day(11, 9, 1)
	road.travel("wild")
	met = ""
	for i: int in 5:
		if road.pending_event.get("id", "") == "spring_omen":
			met = "spring_omen"
			road.choose_event("warn")
		_settle(road)
		if met.is_empty():
			road.wait(1)
	check(met == "spring_omen" and road.story_state("shen_redscale") == "active", "历元 11 年: the hot spring; warning 沈墨 starts his 破鳞散")
	check(road.content.events.serpent_rampage.window.from.map(func(part: Variant) -> int: return int(part)) == [12, 3, 1], "the serpent breaks out in 历元 12 年 spring")
	# The warning is remembered when the serpent comes: the gatherers had gone.
	var azhi := road.favor("azhi")
	road.advance_days(Calendar.to_day(12, 3, 3) - int(road.world.day))
	_settle(road)
	check(road.has_flag("serpent_rampage") and road.favor("azhi") > azhi and road.journal_lines().any(func(line: String) -> bool: return line.contains("人一个没少")), "the warning heeded: nobody at the valley's mouth was lost")
	# The slope after the seal lifts: whoever guided the caravan meets its posts again.
	var slope := _game("free", 74)
	slope.world.flags["slope_leased"] = true
	slope.world.day = Calendar.to_day(15, 6, 1)
	slope.travel("wild")
	met = ""
	for i: int in 5:
		if slope.pending_event.get("id", "") == "slope_leased_return":
			met = "slope_leased_return"
			slope.choose_event("pull")
		_settle(slope)
		if met.is_empty():
			slope.wait(1)
	check(met == "slope_leased_return" and slope.has_flag("slope_common") and slope.has_flag("slope_settled"), "the caravan's posts come back after the seal; pulling them returns the slope to the gatherers")

func _older_journeys() -> void:
	var old := Session.new()
	check(old.restore(JSON.parse_string(FileAccess.get_file_as_string("res://tests/fixtures/v10_heavenly_midstage.json"))), "an older save loads")
	check(old.has_flag("rushi_done") and old.guide_step().is_empty() and old.affiliation() == "qingyun", "an older journey counts the opening as done and stays a disciple of 青云")
	check("retreat" in old.player.taught and "arts" in old.player.taught and old.world.letters.is_empty(), "the cards it knew stay dismissed")
	var v11 := Session.new()
	check(v11.restore(JSON.parse_string(FileAccess.get_file_as_string("res://tests/fixtures/v11_after_retreats.json"))), "a version 11 save loads")
	check(int(v11.player.xp) == 1088 and int(v11.player.mind) == 0 and v11.player.deeds.is_empty() and v11.has_flag("rushi_done") and v11.available_here("study"), "it keeps its progress and finds the sect's halls open")
	check(int(v11.world.people.azhi.relation) == 43 and not bool(v11.world.people.azhi.get("sound", false)), "an old bond keeps its favor; the 传音符 come with the next dealings")
	Session.Events.apply(v11, [{"relation": ["azhi", 1]}])
	check(bool(v11.world.people.azhi.get("sound", false)), "and then they do")
	var round_trip := Session.new()
	check(round_trip.restore(JSON.parse_string(JSON.stringify(v11.snapshot()))) and round_trip.snapshot() == v11.snapshot(), "the upgraded journey saves and loads as version 12")

## Casts 御剑诀 with the orbs it asks (金×1、任意×1): a journey begins with it only on a metal root.
func _sword(game) -> String:
	if not "sword" in game.player.learned:
		game.player.learned.append("sword")
	if not "sword" in game.player.arts:
		game.player.arts.append("sword")
	game.battle.orbs.append_array(["metal", "metal"])
	return game.use_skill("sword")
