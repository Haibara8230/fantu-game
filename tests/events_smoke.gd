extends SceneTree
## M1 acceptance: scheduler, event states, interruption, lifespan, equivalence, long simulation and content checks.
const Session = preload("res://scripts/core/session.gd")
const Content = preload("res://scripts/core/content.gd")
const Calendar = preload("res://scripts/core/calendar.gd")
const PERFORMANCE_BUDGET_MSEC := 4000
var checks := 0
var failures := 0

func check(condition: bool, message: String) -> void:
	checks += 1
	if not condition:
		failures += 1
		printerr("FAIL: " + message)

func _initialize() -> void:
	_arrival_and_rumor()
	_invitation_path_with_interrupt()
	_introduction_path_and_cooldown()
	_missed_event()
	_periodic_and_cross_year()
	_lifespan()
	_pending_event_rules()
	_equivalence()
	_long_simulation()
	_static_checks()
	_v2_migration()
	print("EVENTS: %d checks, %d failures" % [checks, failures])
	quit(0 if failures == 0 else 1)

func _game(seed_value: int) -> Session:
	var game := Session.new()
	game.encounters_enabled = false
	game.new_game("事件", seed_value)
	return game

## Test setup only: moves the world to a date without player actions in between.
func _jump(game: Session, year: int, month: int, day: int) -> void:
	game.advance_days(Calendar.to_day(year, month, day) - int(game.world.day))

func _foundation(game: Session) -> void:
	game.player.realm = 1
	game._refresh_realm_stats()
	game.player.hp = game.player.max_hp

func _state(game: Session, event_id: String) -> String:
	return str(game.world.events.get(event_id, {}).get("state", ""))

func _arrival_and_rumor() -> void:
	var game := _game(1)
	game.travel("market")
	check(game.world.people.get("shen_mo", {}).get("met", false), "arriving at the market introduces the shopkeeper")
	check(not game.has_flag("heard_auction_rumor"), "rumor waits for its window")
	_jump(game, 4, 1, 1)
	check(not game.has_flag("heard_auction_rumor"), "time passing elsewhere does not fire location events")
	game.wait(1)
	check(game.has_flag("heard_auction_rumor") and _state(game, "auction_rumor") == "completed", "rumor heard on the first action inside the window")
	var lines := game.journal_lines()
	check(lines.back().contains("坊间传言"), "event text rendered into the chronicle")
	check(game.upcoming().size() == 1 and game.upcoming()[0].event == "special_auction", "known auction listed as upcoming")

func _invitation_path_with_interrupt() -> void:
	var game := _game(2)
	_foundation(game)
	_jump(game, 4, 6, 1)
	game.travel("market")
	game.travel("sect")
	check(int(game.player.items.get("auction_invitation", 0)) == 1, "foundation disciples receive the invitation at the sect")
	_jump(game, 5, 1, 1)
	var before := int(game.world.day)
	var message := game.cultivate(360)
	check(int(game.world.day) == Calendar.to_day(5, 3, 1), "retreat stops on the day the auction opens")
	check(message.contains("提前出关") and message.contains("特殊拍卖已经开场"), "interruption explains why")
	check(int(game.player.xp) == (int(game.world.day) - before) * 18 / 30, "cultivation credited only for elapsed days")
	game.player.stones = 50
	game.travel("market")
	check(game.pending_event.get("id", "") == "special_auction", "arrival inside the window opens the auction")
	check(not game.player.items.has("auction_invitation"), "invitation handed over at the door")
	var refused := game.choose_event("ganoderma")
	check(refused == "条件不足，无法如此选择。" and not game.pending_event.is_empty(), "unaffordable lot cannot be chosen")
	game.choose_event("pill")
	check(game.pending_event.is_empty() and int(game.player.pills) == 1 and int(game.player.stones) == 5, "lot bought")
	check(_state(game, "special_auction") == "completed", "auction completed")
	game.wait(1)
	check(game.pending_event.is_empty(), "completed event does not repeat")
	check(game.upcoming().is_empty(), "completed event leaves the upcoming list")

func _introduction_path_and_cooldown() -> void:
	var game := _game(3)
	game.travel("market")
	game.player.herbs = 5
	check(game.pending_event.is_empty(), "the shopkeeper never forces a request on the player")
	game.interact("shen_mo", "request")
	check(game.favor("shen_mo") == 10 and int(game.player.herbs) == 0, "favor done by choice")
	_jump(game, 5, 3, 10)
	game.world.people.shen_mo.relation = 39
	game.wait(1)
	check(game.pending_event.is_empty(), "an introduction needs the 相熟 stage")
	game.world.people.shen_mo.relation = 40
	game.wait(1)
	check(game.pending_event.get("id", "") == "special_auction" and int(game.player.realm) == 0, "introduction opens the auction without foundation or invitation")
	game.choose_event("watch")

func _missed_event() -> void:
	var game := _game(4)
	game.player.items["auction_invitation"] = 1
	_jump(game, 5, 2, 1)
	var message := game.cultivate(360)
	check(int(game.world.day) == Calendar.to_day(5, 3, 1), "reminder interrupts")
	message = game.cultivate(90)
	check(_state(game, "special_auction") == "expired", "auction expires after its window")
	check(message.contains("已经落幕"), "player who knew hears how it ended")
	game.travel("market")
	check(game.pending_event.is_empty(), "missed event cannot be entered later")
	var unaware := _game(5)
	unaware.cultivate(3600)
	check(_state(unaware, "special_auction") == "expired" and not unaware.journal_lines().any(func(line: String) -> bool: return line.contains("落幕")), "unknown events expire silently")

func _periodic_and_cross_year() -> void:
	var game := _game(6)
	game.travel("market")
	_jump(game, 3, 9, 5)
	game.wait(1)
	check(game.pending_event.get("id", "") == "night_market", "night market opens in year three")
	game.choose_event("stroll")
	game.wait(1)
	check(game.pending_event.is_empty(), "one visit per occurrence")
	_jump(game, 6, 8, 25)
	game.wait(10)
	check(int(game.world.day) == Calendar.to_day(6, 9, 5) and game.pending_event.get("id", "") == "night_market", "next occurrence three years later")
	game.choose_event("stroll")
	check(int(game.world.events.night_market.count) == 2, "occurrences counted")
	var crossing := _game(7)
	_jump(crossing, 9, 11, 1)
	crossing.cultivate(360)
	check(int(crossing.world.day) == Calendar.to_day(10, 11, 1), "retreat crosses the year boundary")
	check(int(crossing.world.events.sect_tournament.count) == 1 and crossing.journal_lines().any(func(line: String) -> bool: return line.begins_with("【10年6月初一】青云剑宗外门小比")), "dated world event fires on its own day inside the span")

func _lifespan() -> void:
	var game := _game(8)
	var day := int(game.world.day)
	game.player.birth_day = day + 6 * 360 - 120 * 360
	check(game.lifespan_end_day() == day + 6 * 360, "lifespan end computed from realm")
	var message := game.cultivate(3600)
	check(int(game.world.day) == day + 360 and message.contains("寿元将尽"), "lifespan warning interrupts a retreat")
	game.cultivate(3600)
	check(not game.ended.is_empty() and int(game.world.day) == day + 6 * 360, "life ends on the exact day")
	check(game.journal_lines().back().contains("坐化"), "ending recorded")
	var frozen := game.snapshot()
	check(game.cultivate(30) == "此生已尽。可读取存档，或开启新旅程。" and game.travel("market") != "" and game.snapshot() == frozen, "nothing moves after the end")
	var copy := Session.new()
	check(copy.restore(JSON.parse_string(JSON.stringify(frozen))) and not copy.ended.is_empty(), "ended state persists")
	var extended := _game(9)
	var old_end := extended.lifespan_end_day()
	_foundation(extended)
	check(extended.lifespan_end_day() == old_end + 100 * 360, "breakthrough extends the lifespan")

func _pending_event_rules() -> void:
	var game := _game(10)
	game.travel("market")
	_jump(game, 3, 9, 5)
	game.wait(1)
	var held := game.snapshot()
	check(game.travel("sect") == "眼前之事尚未了结。" and game.cultivate(30) != "" and game.snapshot() == held, "pending choice blocks other actions and time")
	var copy := Session.new()
	check(copy.restore(JSON.parse_string(JSON.stringify(held))) and copy.pending_event.id == "night_market", "pending choice persists through saves")
	var bad: Dictionary = held.duplicate(true)
	bad.pending_event.id = "missing_event"
	check(not copy.restore(bad), "unknown pending event rejected")
	bad = held.duplicate(true)
	bad.ended = {"kind": "ascension", "day": 0}
	check(not copy.restore(bad), "unknown ending rejected")
	bad = held.duplicate(true)
	bad.world.events.night_market.state = "lost"
	check(not copy.restore(bad), "unknown event state rejected")

func _comparable(game: Session) -> Dictionary:
	var data := game.snapshot()
	data.erase("chronicle")
	return data

func _equivalence() -> void:
	var once := _game(11)
	var pieces := _game(11)
	once.cultivate(3600)
	for i: int in range(120):
		pieces.cultivate(30)
	check(_comparable(once) == _comparable(pieces), "one ten-year retreat equals 120 one-month retreats")
	check(int(once.world.events.sect_tournament.count) == 1 and _state(once, "special_auction") == "expired", "both spans processed the same world events")

func _long_simulation() -> void:
	var whole := _game(12)
	var chunked := _game(12)
	for game: Session in [whole, chunked]:
		for realm: Dictionary in game.content.realms:
			realm.lifespan_years = 2000
	var started := Time.get_ticks_msec()
	while int(whole.world.day) < 500 * 360:
		whole.wait(mini(3600, 500 * 360 - int(whole.world.day)))
	var whole_msec := Time.get_ticks_msec() - started
	started = Time.get_ticks_msec()
	while int(chunked.world.day) < 500 * 360:
		chunked.wait(30)
	var chunked_msec := Time.get_ticks_msec() - started
	check(_comparable(whole) == _comparable(chunked), "500 years in long spans equals 500 years month by month")
	check(int(whole.world.events.sect_tournament.count) == 50, "fifty tournaments in five centuries")
	check(whole_msec + chunked_msec < PERFORMANCE_BUDGET_MSEC, "500-year simulations within budget (%d ms + %d ms)" % [whole_msec, chunked_msec])
	print("EVENTS: 500 years in %d ms (long spans) / %d ms (monthly)" % [whole_msec, chunked_msec])

func _broken(event: Dictionary) -> String:
	var content := Content.new()
	content.load_data()
	content.events["probe"] = event
	return content._validate()

func _static_checks() -> void:
	var content := Content.new()
	check(content.load_data() and content.error_message.is_empty(), "shipped events pass static checks")
	var base := {"title": "试", "trigger": "location", "location": "market", "chronicle": "试。"}
	check(_broken(base).is_empty(), "minimal event valid")
	var event: Dictionary = base.duplicate(true)
	event.location = "moon"
	check(_broken(event).contains("未知地点"), "unknown location reported")
	event = base.duplicate(true)
	event.window = {"from": [5, 4, 1], "to": [5, 3, 1]}
	check(_broken(event).contains("颠倒"), "reversed window reported")
	event = base.duplicate(true)
	event.conditions = [{"flag": "no_such_flag"}]
	check(_broken(event).contains("未知世界标记"), "unknown flag reported")
	event = base.duplicate(true)
	event.conditions = [{"realm_at_least": 9}]
	check(_broken(event).contains("境界"), "unreachable realm reported")
	event = base.duplicate(true)
	event.text = "选。"
	event.choices = [{"id": "a", "label": "甲", "chronicle": "甲。", "conditions": [{"stones_at_least": 5}]}]
	check(_broken(event).contains("无条件选项"), "event that could trap the player reported")
	event = base.duplicate(true)
	event.key = true
	event.conditions = [{"realm_at_least": 1}]
	check(_broken(event).contains("两条入场途径"), "key event with a single route reported")
	event = base.duplicate(true)
	event.trigger = "date"
	event.erase("location")
	check(_broken(event).contains("时间窗口或周期"), "undated date event reported")
	event = base.duplicate(true)
	event.periodic = {"start_year": 1, "every_years": 1, "month": 1, "from_day": 1, "to_day": 2}
	event.remind = {"chronicle": "提醒。"}
	check(_broken(event).contains("固定窗口"), "reminder on a periodic event reported")
	event = base.duplicate(true)
	event.effects = [{"item": ["ghost_item", 1]}]
	check(_broken(event).contains("效果无效"), "unknown item effect reported")

func _v2_migration() -> void:
	var market := Session.new()
	check(market.restore(JSON.parse_string(FileAccess.get_file_as_string("res://tests/fixtures/v2_market.json"))), "v2 save migrates to v3")
	check(market.snapshot().version == Session.SAVE_VERSION and market.world.events.is_empty() and market.player.items.is_empty(), "v3 fields added empty")
	market.wait(1)
	check(market.world.people.get("shen_mo", {}).get("met", false), "events run on migrated saves")
	var battle := Session.new()
	check(battle.restore(JSON.parse_string(FileAccess.get_file_as_string("res://tests/fixtures/v2_battle.json"))) and battle.battle.opponent_sect == "canglan", "v2 battle migrates")
	battle.flee()
	check(battle.battle.is_empty() and int(battle.world.day) == 30, "migrated battle resolves through the scheduler")
	var serpent := Session.new()
	check(serpent.restore(JSON.parse_string(FileAccess.get_file_as_string("res://tests/fixtures/v2_foundation_serpent.json"))) and serpent.has_flag("serpent_slain") and int(serpent.player.realm) == 1, "v2 world flags and realm kept")
