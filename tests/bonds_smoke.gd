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
	# Deliveries count by the piece.
	for offer: Dictionary in game.commission_offers("sect"):
		if offer.has("item"):
			game.accept_commission(offer.key)
			game.set_item_count(offer.item, int(offer.count))
			game.deliver_commission(offer.key)
			check(int(game.player.contribution) == 25 + 3 * int(offer.count), "an herb commission pays three a piece")
			break
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
	check(game.sect_rank().name == "内门弟子" and game.next_sect_rank().is_empty() and not game.promotion_block().is_empty(), "the inner sect is the highest rank for now")
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
	var mystic: Array = game.sect_goods().filter(func(good: Dictionary) -> bool: return str(good.key).begins_with("mystic:"))
	check(mystic.size() == 1 and str(mystic[0].block).contains("内门弟子"), "a mystic-tier slip only for the inner sect")
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
