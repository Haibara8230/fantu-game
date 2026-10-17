extends SceneTree
## The sect and the people: rank, contribution, stipend, exchange and donations; patrols and the
## contribution commissions and deeds bring; promotion and what it opens; how the standing survives a
## save and how older journeys start.
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
	_standing()
	_commissions()
	_promotion()
	_stipend()
	_exchange()
	_donations()
	_saves()
	_favor_opens()
	_letters()
	_appointments()
	_loans()
	_aid()
	_kin()
	_duties()
	print("BONDS: %d checks, %d failures" % [checks, failures])
	quit(0 if failures == 0 else 1)

func _game(seed_value: int = 41) -> Session:
	var game := Session.new()
	game.encounters_enabled = false
	game.new_game("宗门", seed_value, ["metal", "wood", "fire"])
	return game

func _standing() -> void:
	var game := _game()
	check(game.content.error_message.is_empty(), "content loads: " + game.content.error_message)
	check(game.sect_rank().name == "外门弟子" and int(game.player.contribution) == 0 and int(game.player.merit) == 0, "a new disciple starts in the outer sect with nothing")
	check(game.available_here("sect"), "the 执事堂 handles the sect's business")
	Session.Events.apply(game, [{"contribution": 15}])
	check(int(game.player.contribution) == 15 and int(game.player.merit) == 15, "contribution counts twice: to spend and toward promotion")
	check(Session.Events.met(game, {"rank_at_least": "outer"}) and not Session.Events.met(game, {"rank_at_least": "elite"}), "conditions can ask for a rank")

func _commissions() -> void:
	var game := _game()
	var sect_offers := game.commission_offers("sect")
	check(not sect_offers.is_empty() and sect_offers.all(func(offer: Dictionary) -> bool: return int(offer.reward.contribution) > 0), "the sect's own board pays contribution")
	var market := _game()
	market.player.location = "market"
	check(market.commission_offers("market").all(func(offer: Dictionary) -> bool: return int(offer.reward.contribution) == 0), "the market's board does not")
	# A patrol: go there, come back, report.
	var quest := {"key": "sect:test:0", "kind": "patrol", "board": "sect", "count": 1, "days": 45, "place": "ridge", "reward": {"stones": 10, "xp": 20, "contribution": 25}, "deadline": 45, "progress": 0}
	game.player.quests.append(quest)
	check(not game.delivery_block(quest).is_empty() and game.commission_text(quest).title == "巡视松风岭", "a patrol must first be walked")
	game.travel("ridge")
	game.travel("sect")
	var stones := int(game.player.stones)
	var text := game.deliver_commission("sect:test:0")
	check(int(game.player.contribution) == 25 and int(game.player.stones) == stones + 10 and text.contains("贡献 25"), "and reported for its contribution")
	# Deliveries count by the piece (the board's first delivery in the next few periods).
	var today := int(game.world.day)
	var delivery := {}
	for period: int in 12:
		game.world.day = today + period * int(game.content.commission_data.period_days)
		for offer: Dictionary in game.commission_offers("sect"):
			if offer.has("item"):
				delivery = offer
				break
		if not delivery.is_empty():
			break
	check(not delivery.is_empty(), "the sect's board posts deliveries")
	if not delivery.is_empty():
		var before := int(game.player.contribution)
		var per := int(game.content.commission_data.templates[delivery.kind].get("contribution", 0))
		game.accept_commission(delivery.key)
		game.set_item_count(delivery.item, int(delivery.count))
		game.deliver_commission(delivery.key)
		check(per > 0 and int(game.player.contribution) == before + per * int(delivery.count), "a delivery pays its contribution by the piece (%s)" % delivery.kind)
	game.world.day = today
	check(int(game.content.enemies.serpent.contribution) == 100 and int(game.content.sect_data.awards.tournament_champion) == 80, "great deeds for the sect count too")

func _promotion() -> void:
	var game := _game()
	check(game.promotion_block().contains("累计贡献 0 / 120") and game.promotion_block().contains("炼气中期"), "promotion asks for merit and a stage")
	game.player.merit = 120
	check(game.promotion_block().contains("炼气中期") and not game.promotion_block().contains("贡献"), "merit alone is not enough")
	game.player.stage = 1
	game.player.xp = 500
	game.refresh_realm_stats()
	game.player.location = "town"
	check(game.promote().contains("执事堂"), "promotion is asked for at the 执事堂")
	game.player.location = "sect"
	var text := game.promote()
	check(game.sect_rank().name == "外门精英" and text.contains("外门精英") and text.contains("腰牌"), "and given there, with words from the steward")
	check(game.chronicle.entries.any(func(entry: Dictionary) -> bool: return entry.id == "rank_up" and entry.major), "a promotion is a great event of the life")
	check(game.cultivation_rate() == 63, "an elite disciple's retreats go a little faster")
	check(game.promotion_block().contains("筑基初期"), "the inner sect asks for foundation")
	game.player.merit = 400
	game.player.realm = 1
	game.player.stage = 0
	game.player.xp = 0
	game.refresh_realm_stats()
	game.promote()
	check(game.sect_rank().name == "内门弟子" and game.next_sect_rank().name == "真传弟子" and not game.promotion_block().is_empty(), "an inner disciple looks to 真传, which waits for 筑基后期")
	game.player.merit = 1200
	check(game.promotion_block().contains("筑基后期"), "a 真传弟子 must have reached 筑基后期 (%s)" % game.promotion_block())
	game.player.stage = 2
	game.refresh_realm_stats()
	game.promote()
	check(game.sect_rank().name == "真传弟子" and game.next_sect_rank().is_empty(), "at 筑基后期, 真传: the highest a small sect gives")
	check(game.promotion_block().contains("最高身份"), "and nothing above it")
	check(game.story_state("inner_court") == "active", "and opens the inner court's storyline")

func _stipend() -> void:
	var game := _game()
	check(int(game.stipend_due().periods) == 0 and game.collect_stipend().contains("领过"), "no stipend before a month has passed")
	game.advance_days(95)
	var due := game.stipend_due()
	var stones := int(game.player.stones)
	game.collect_stipend()
	check(int(due.periods) == 3 and int(due.stones) == 9 and int(game.player.stones) == stones + 9 and int(game.player.stipend_day) == 90, "three months of an outer disciple's stipend, the odd days kept")
	game.advance_days(30 * 20)
	check(int(game.stipend_due().periods) == 12, "a stipend piles up for a year at most")
	game.collect_stipend()
	check(int(game.player.stipend_day) == int(game.world.day), "months beyond it are lost")

func _exchange() -> void:
	var game := _game()
	game.player.contribution = 500
	var key_of := func(good_id: String) -> String:
		for good: Dictionary in game.sect_goods():
			if str(good.key).begins_with(good_id + ":"):
				return good.key
		return ""
	var huiqi: String = key_of.call("huiqi")
	for i: int in 3:
		game.sect_exchange(huiqi)
	check(game.item_count("huiqi_pill") == 3 and int(game.player.contribution) == 476, "pills for contribution")
	check(game.sect_exchange(huiqi).contains("已换完"), "each within its limit per period")
	game.advance_days(30)
	check(game.sect_exchange(key_of.call("huiqi")).contains("换得"), "the next period brings more")
	var foundation: String = key_of.call("foundation")
	check(game.sect_exchange(foundation).contains("外门精英"), "foundation pills only for the elite")
	game.player.rank = 1
	game.sect_exchange(foundation)
	check(game.item_count("foundation_pill") == 1 and game.sect_exchange(key_of.call("foundation")).contains("已换完"), "one in two years")
	var slips: Array = game.sect_goods().filter(func(good: Dictionary) -> bool: return str(good.key).begins_with("yellow:"))
	check(slips.size() == 2 and slips.all(func(good: Dictionary) -> bool: return str(good.item).begins_with("j:")), "two yellow-tier jade slips each period")
	# 青云 is a small sect: its slips and gear stop at 黄阶 and 法器 (docs/WORLD_EXPANSION.md, part four).
	check(game.sect_goods().all(func(good: Dictionary) -> bool: return not str(good.item).begins_with("j:") and not str(good.item).begins_with("e:") or int(game.content.item(good.item).tier) <= 2), "a small sect's exchange stops at 黄阶 and 法器")
	# Breakthroughs past 筑基 ask no pill, so the exchange keeps none for them.
	check(not game.sect_goods().any(func(good: Dictionary) -> bool: return game.content.item(str(good.item)).has("breakthrough")), "the sect exchanges no breakthrough aid past the 筑基丹")
	game.player.location = "town"
	check(game.sect_exchange(key_of.call("liaoshang")).contains("执事堂"), "the exchange is at the 执事堂")
	var poor := _game()
	check(poor.sect_exchange(key_of.call("liaoshang")) != "" and poor.item_count("liaoshang_pill") == 0, "no contribution, no pills")

func _donations() -> void:
	var game := _game()
	game.set_item_count("huichun_grass", 30)
	check(game.donation_value("huichun_grass", 10) == 20 and game.donation_value("foundation_pill", 1) == 0, "herbs count at half their price; pills are not taken")
	game.donate("huichun_grass", 10)
	check(int(game.player.contribution) == 20 and game.item_count("huichun_grass") == 20, "a donation becomes contribution")
	game.donate("huichun_grass", 15)
	check(int(game.player.contribution) == 40 and game.donation_left() == 0, "up to forty a month")
	check(game.donate("huichun_grass", 1).contains("上限"), "then no more this month")
	game.advance_days(30)
	check(game.donation_left() == 40, "a new month, a new allowance")

func _saves() -> void:
	var game := _game()
	game.player.rank = 1
	game.player.contribution = 33
	game.player.merit = 150
	game.player.exchanged = {"huiqi:0": 2}
	game.player.donated = {"period": 0, "amount": 12}
	var copy := Session.new()
	check(copy.restore(JSON.parse_string(JSON.stringify(game.snapshot()))) and copy.snapshot() == game.snapshot(), "the standing survives a save")
	for broken: Array in [["rank", 9], ["contribution", -1], ["merit", "many"], ["stipend_day", 999999], ["exchanged", {"huiqi:0": -1}], ["donated", {"period": "now"}]]:
		var data: Dictionary = game.snapshot()
		data.player[broken[0]] = broken[1]
		check(not copy.restore(data), "malformed %s rejected" % broken[0])
	var old := Session.new()
	check(old.restore(JSON.parse_string(FileAccess.get_file_as_string("res://tests/fixtures/v13_commissions.json"))) and old.snapshot().version == Session.SAVE_VERSION, "a version 13 save migrates")
	check(old.sect_rank().name == "外门弟子" and int(old.player.merit) == 30 and int(old.player.contribution) == 30 and int(old.player.stipend_day) == int(old.world.day), "its delivered commissions count as contribution; the stipend starts now")

## A generated person met and present here.
## 道侣 and 师徒: who may be asked, what they bring, how they end, and that a save keeps them.
func _kin() -> void:
	var game := _game(43)
	var other := _someone(game)
	game.world.people[other].relation = 200
	check(not game.npc_options(other).any(func(option: Dictionary) -> bool: return option.id == "companion"), "no 道侣 before foundation")
	game.player.realm = 1
	game.refresh_realm_stats()
	var speed: float = game.cultivation_speed()
	check(game.npc_options(other).any(func(option: Dictionary) -> bool: return option.id == "companion" and option.available), "from foundation, one 亲密 may become 道侣")
	game.interact(other, "companion")
	check(game.world.companion == other and is_equal_approx(game.cultivation_speed(), speed * 1.1), "a 道侣 quickens cultivation by a tenth")
	check(game.chronicle.entries.any(func(entry: Dictionary) -> bool: return entry.id == "companion_bound" and entry.major), "and is a milestone")
	var life: Dictionary = game.life_by_id(other)
	var copy := Session.new()
	check(copy.restore(JSON.parse_string(JSON.stringify(game.snapshot()))) and copy.world.companion == other, "a 道侣 survives a save")
	game.world.day = int(life.death) + 1
	check(game.Bonds.companion_speed(game) == 0, "and the quickening ends with their life")
	# 结拜: 信赖 is enough, and a sworn sibling answers the call to aid.
	var kin := _game(45)
	var brother := _someone(kin)
	kin.world.people[brother].relation = 140
	kin.world.people[brother].sound = true
	kin.interact(brother, "sworn")
	check(brother in kin.world.sworn, "one trusted may become a sworn sibling")
	kin.start_battle("disciple")
	check(brother in kin.Bonds.allies(kin), "who answers a 传音 for aid before 亲密")
	# Fleeing may fail (遁逃 by the odds); a failed try costs the turn, not days.
	while not kin.battle.is_empty():
		kin.player.hp = kin.player.max_hp
		kin.flee()
	var kept := Session.new()
	check(kept.restore(JSON.parse_string(JSON.stringify(kin.snapshot()))) and brother in kept.world.sworn, "sworn siblings survive a save")
	# 师徒.
	var master := _game(44)
	var pupil := ""
	for person_id: String in master.present_npcs():
		if master.is_generated(person_id) and int(master.person(person_id).realm) == 0:
			pupil = person_id
			master.mark_met(person_id)
			break
	master.world.people[pupil].relation = 80
	check(not master.npc_options(pupil).any(func(option: Dictionary) -> bool: return option.id == "disciple"), "no disciples before 金丹")
	master.player.realm = 2
	master.refresh_realm_stats()
	master.interact(pupil, "disciple")
	check(pupil in master.world.disciples and master.npc_options(pupil).any(func(option: Dictionary) -> bool: return option.id == "instruct"), "a 金丹 takes a disciple, and may teach them")
	var mind := int(master.player.mind)
	master.interact(pupil, "instruct")
	check(int(master.player.mind) > mind and not master.npc_options(pupil).filter(func(option: Dictionary) -> bool: return option.id == "instruct")[0].available, "teaching tempers the mind, once a year")
	var stones := int(master.player.stones)
	master.world.day = 6 * 60 * 3
	master.Bonds.write_letters(master)
	check(int(master.player.stones) > stones and master.world.letters.any(func(letter: Dictionary) -> bool: return str(letter.get("kind", "")) == "bond:tribute"), "now and then a disciple sends silver")

## 职司: the inner court may hold one duty, changed once a year; each changes its own rule.
func _duties() -> void:
	var game := _game(46)
	check(game.Sect.duty_block(game, "alchemy").contains("内门弟子"), "an outer disciple holds no duty")
	game.player.rank = game.Sect.rank_index(game, "inner")
	var odds: int = int(game.alchemy_odds(game.alchemy_plan("liaoshang")).success)
	game.take_duty("alchemy")
	check(game.player.duty == "alchemy" and game.Sect.duty_value(game, "alchemy") == 10, "the inner court takes the 丹房 duty")
	var raised: int = int(game.alchemy_odds(game.alchemy_plan("liaoshang")).success)
	check(raised == odds + 10 or raised >= 95, "which raises the odds of a brew (%d → %d)" % [odds, raised])
	check(game.Sect.duty_block(game, "lore").contains("一年一换"), "a duty is held a year before it changes")
	var days: int = game.study_days({"study_days": 10, "element": "earth"})
	game.world.day = int(game.world.day) + 360
	game.take_duty("lore")
	check(game.study_days({"study_days": 10, "element": "earth"}) == days - 2, "the 传功 duty quickens study")
	var copy := Session.new()
	check(copy.restore(JSON.parse_string(JSON.stringify(game.snapshot()))) and copy.player.duty == "lore", "a duty survives a save")

func _someone(game: Session) -> String:
	for person_id: String in game.present_npcs():
		if game.is_generated(person_id) and game.person(person_id).attitude != "hostile":
			game.mark_met(person_id)
			return person_id
	return ""

func _favor_opens() -> void:
	var game := _game()
	var friend := _someone(game)
	check(not friend.is_empty(), "someone to befriend at the sect")
	var ids := func() -> Array: return game.npc_options(friend).map(func(option: Dictionary) -> String: return option.id)
	check(not "consult" in ids.call() and not "teach" in ids.call(), "a stranger offers nothing more")
	Session.Events.apply(game, [{"relation": [friend, 40]}])
	check(bool(game.world.people[friend].get("sound", false)), "an acquaintance (相熟) exchanges a 传音符")
	Session.Events.apply(game, [{"relation": [friend, 40]}])
	check("consult" in ids.call(), "a friend (友好) of one's standing can be consulted")
	var day := int(game.world.day)
	var mind := int(game.player.mind)
	var text := game.interact(friend, "consult")
	check(int(game.world.day) == day + 3 and int(game.player.insight) == 15 and int(game.player.mind) == mind + 3 and text.contains("请教"), "consulting takes three days for insight and mind")
	check(not game.npc_options(friend).filter(func(option: Dictionary) -> bool: return option.id == "consult")[0].available, "and waits a while before the next time")
	Session.Events.apply(game, [{"relation": [friend, 60]}])
	var teach: Array = game.npc_options(friend).filter(func(option: Dictionary) -> bool: return option.id == "teach")
	check(not teach.is_empty(), "a trusted friend (信赖) can be asked to teach an art")
	if teach[0].available:
		var slips: int = game.player.items.keys().filter(func(id: String) -> bool: return id.begins_with("j:")).size()
		game.interact(friend, "teach")
		check(game.player.items.keys().filter(func(id: String) -> bool: return id.begins_with("j:")).size() == slips + 1 and game.journal_lines().back().contains("传给了你"), "who writes one of theirs into a jade slip")
		check(not game.npc_options(friend).filter(func(option: Dictionary) -> bool: return option.id == "teach")[0].available, "once in a life")
	else:
		check(str(teach[0].reason).contains("没有能传"), "unless nothing of theirs suits the player")

## A session where every friend writes each period, with one friend holding a 传音符.
func _writer() -> Array:
	var game := _game()
	game.content.bonds_data.visits.chance = 1.0
	var friend := _someone(game)
	Session.Events.apply(game, [{"relation": [friend, 50]}])
	return [game, friend]

func _letters() -> void:
	var pair := _writer()
	var game: Session = pair[0]
	var friend: String = pair[1]
	var before := int(game.world.letters.size())
	var result := game.cultivate(90)
	check(not result.contains("提前出关") and int(game.world.day) == 90, "a friend's letter never ends a retreat")
	check(game.world.letters.size() > before and game.world.letters.back().npc == friend and str(game.world.letters.back().kind).begins_with("bond:"), "friends write on their own")
	var words: String = Session.Chronicle.letter_text(game.world.letters.back(), game.content)
	check(not words.contains("{") and not words.contains("失传"), "in their own words: " + words)
	var gifts := _writer()
	var giver: Session = gifts[0]
	var kinds := {}
	for period: int in 12:
		giver.advance_days(60)
		for letter: Dictionary in giver.world.letters:
			kinds[str(letter.kind)] = true
		giver.world.invites.clear()
	check(kinds.size() >= 3, "and about different things: %s" % str(kinds.keys()))
	var told := game.congratulate("breakthrough")
	check(told.any(func(line: String) -> bool: return line.contains(game.person(friend).name)), "friends among the people send congratulations too")

func _appointments() -> void:
	var game := _game()
	var friend := _someone(game)
	Session.Events.apply(game, [{"relation": [friend, 50]}])
	game.world.invites.append({"id": "spar:0:" + friend, "npc": friend, "kind": "spar", "made": 0, "deadline": 30})
	check("invite_spar" in game.npc_options(friend).map(func(option: Dictionary) -> String: return option.id), "an appointment to spar shows where they are")
	var favor := game.favor(friend)
	game.interact(friend, "invite_spar")
	check(not game.battle.is_empty() and game.battle.get("invite", "") == "spar:0:" + friend, "keeping it starts the spar")
	game.battle.hp = 1
	game.use_skill("sword")
	check(game.battle.is_empty() and game.favor(friend) >= favor + 15 and game.open_invites().is_empty(), "a kept appointment is worth more than a plain spar")
	game.world.invites.append({"id": "spar:1:" + friend, "npc": friend, "kind": "spar", "made": int(game.world.day), "deadline": int(game.world.day) + 30})
	favor = game.favor(friend)
	game.wait(10)
	game.wait(30)
	check(game.favor(friend) == favor - 5 and game.journal_lines().any(func(line: String) -> bool: return line.contains("没有赴")), "one not kept is remembered")
	game.world.invites.append({"id": "help:0:" + friend, "npc": friend, "kind": "help", "made": int(game.world.day), "deadline": int(game.world.day) + 60, "item": "huichun_grass", "count": 2})
	game.set_item_count("huichun_grass", 2)
	var stones := int(game.player.stones)
	game.interact(friend, "invite_help")
	check(game.item_count("huichun_grass") == 0 and int(game.player.stones) == stones + 12 and game.open_invites().is_empty(), "help asked by 传音 is paid for")
	game.world.invites.append({"id": "outing:0:" + friend, "npc": friend, "kind": "outing", "made": int(game.world.day), "deadline": int(game.world.day) + 30, "place": "ridge"})
	game.travel("ridge")
	game.fortune = {"lingshen": 0.99, "spirit_eye": 0.99}
	var herbs := game.herb_count()
	game.act("gather")
	check(game.herb_count() - herbs >= 2 and (game.herb_count() - herbs) % 2 == 0 and game.open_invites().is_empty() and game.journal_lines().back().contains("收获翻倍"), "gathering together brings twice the herbs")

func _loans() -> void:
	var game := _game()
	var friend := _someone(game)
	Session.Events.apply(game, [{"relation": [friend, 50]}])
	game.player.stones = 100
	game.world.invites.append({"id": "loan:0:" + friend, "npc": friend, "kind": "loan", "made": 0, "deadline": 30, "amount": 40})
	game.answer_loan("loan:0:" + friend, true)
	check(int(game.player.stones) == 60 and game.world.loans.size() == 1 and int(game.world.loans[0].repay) == 60, "silver lent, half again to come back")
	var copy := Session.new()
	check(copy.restore(JSON.parse_string(JSON.stringify(game.snapshot()))) and copy.world.loans == game.world.loans, "a loan survives a save")
	var life: Dictionary = game.life_by_id(friend)
	if int(life.death) > 181:
		game.cultivate(90)
		game.cultivate(90)
		game.wait(1)
		check(int(game.player.stones) >= 120 and game.world.loans.is_empty() and game.world.letters.back().kind == "bond:repaid", "repaid in half a year, with a letter")
	game.world.invites.append({"id": "loan:1:" + friend, "npc": friend, "kind": "loan", "made": int(game.world.day), "deadline": int(game.world.day) + 30, "amount": 20})
	var favor := game.favor(friend)
	game.answer_loan("loan:1:" + friend, false)
	check(game.favor(friend) == favor - 3 and game.open_invites().filter(func(invite: Dictionary) -> bool: return invite.id == "loan:1:" + friend).is_empty(), "refusing costs a little favor")
	# A borrower who dies before the day takes the silver along.
	var dying := ""
	for seat: int in game._local_seats:
		var someone: Dictionary = game.life_at(seat, int(game.world.day))
		if not someone.is_empty() and int(someone.death) > int(game.world.day) and int(someone.death) < int(game.world.day) + 150:
			dying = someone.id
			break
	if not dying.is_empty():
		game.world.loans.append({"npc": dying, "amount": 30, "repay": 45, "due": int(game.world.day) + 180})
		var stones := int(game.player.stones)
		game.advance_days(181)
		check(int(game.player.stones) == stones and game.journal_lines().any(func(line: String) -> bool: return line.contains("收不回来")), "a borrower who dies first never repays")

func _aid() -> void:
	var game := _game()
	var friend := _someone(game)
	Session.Events.apply(game, [{"relation": [friend, 200]}])
	game.travel("wild")
	game.start_battle("wolf")
	check(game.duel_allies() == [friend], "a close friend (亲密) can be called into a duel")
	# Sturdy enough to outlast the strike, so the second call is tried.
	game.battle.hp = 999
	var hp := int(game.battle.hp)
	game.call_aid(friend)
	check(game.battle.is_empty() or (int(game.battle.hp) < hp and bool(game.battle.aid_used)), "their strike lands")
	if not game.battle.is_empty():
		check(game.duel_allies().is_empty() and game.call_aid(friend).contains("无人"), "once a duel")
	check(game.journal_lines().any(func(line: String) -> bool: return line.contains("应声而至")), "and is written down")
