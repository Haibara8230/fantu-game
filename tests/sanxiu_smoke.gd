extends SceneTree
## 天南散修盟 (docs/SIDEQUESTS_DRAFT_20261020.md 2.2, step 2): a wanderer joins and leaves at any
## branch, a sect takes them out of it; members rest and retreat in the branches' rooms, rent a 灵地 at
## 金丹 with standing, read the 青灯簿 for standing, are carried home when beaten in the wild; and
## 「青灯账」 ends with the player 副盟主 or cast out. All of it survives a save.
const Session = preload("res://scripts/core/session.gd")
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
	_data()
	_joining()
	_rooms()
	_board()
	_shelter()
	_ledger()
	_saves()
	print("SANXIU: %d checks, %d failures" % [checks, failures])
	quit(0 if failures == 0 else 1)

func _game(seed_value: int = 43) -> Session:
	var game := Session.new()
	game.encounters_enabled = false
	game.new_game("散修", seed_value, ["metal", "wood", "water"], "free")
	game.world.flags["tiannan_known"] = true
	game.world.storylines["rushi"] = {"state": "done", "step": 0, "since": 0, "begun": true, "base": {}}
	game.world.flags["rushi_done"] = true
	game.player.stones = 5000
	game.player.location = "market"
	return game

func _grow(game: Session, realm: int, stage: int) -> void:
	game.player.realm = realm
	game.player.stage = stage
	game.player.xp = int(game.content.stage(realm, stage).xp)
	game.refresh_realm_stats()
	game.player.hp = game.player.max_hp
	game.player.qi = game.player.max_qi

func _reload(game: Session) -> Session:
	var copy := Session.new()
	check(copy.restore(JSON.parse_string(JSON.stringify(game.snapshot()))), "the journey survives a save")
	return copy

## A branch in each of the five cities, each with a room for members; 灵地 at 北岳 and 望海.
func _data() -> void:
	var game := _game()
	var league: Dictionary = game.League.data(game)
	check(league.branches.size() == 5 and game.content.people.has(str(league.head)), "five branches under 何不归")
	for location_id: String in league.branches:
		var spots: Array = game.content.locations[location_id].spots
		check(spots.any(func(spot: Dictionary) -> bool: return "league" in spot.actions), "%s has a lamp to join at" % location_id)
		check(spots.any(func(spot: Dictionary) -> bool: return spot.id == "lamp_room" and spot.lodging.get("league", false)), "%s has a room for members" % location_id)
	for location_id: String in ["beiyue", "wanghai"]:
		var land: Array = game.content.locations[location_id].spots.filter(func(spot: Dictionary) -> bool: return spot.id == "land")
		check(land.size() == 1 and float(land[0].lodging.rate) > 1.0 and int(land[0].lodging.realm) == 2, "%s lets a 灵地 to 金丹 members" % location_id)

## Joining at a branch, leaving, a sect taking one out, and no way back for one cast out.
func _joining() -> void:
	var game := _game()
	game.player.location = "ridge"
	check(not game.League.block(game).is_empty(), "no branch on the ridge")
	game.player.location = "market"
	check(game.League.block(game).is_empty() and game.available_here("league"), "a wanderer may join at 云溪's lamp")
	game.league_join()
	check(game.League.member(game) and game.has_flag("league_member") and game.League.home(game) == "market" and game.affiliation().is_empty(), "a member, still a 散修")
	check(not game.League.block(game).is_empty(), "no joining twice")
	game.league_leave()
	check(not game.League.member(game) and not game.has_flag("league_member"), "left, and the rooms close")
	game.league_join()
	check(game.League.member(game), "and back again at will")
	game.player.location = "sect"
	game.join_sect()
	check(game.affiliation() == "qingyun" and not game.League.member(game) and not game.has_flag("league_member"), "a sect takes one out of the alliance")
	game.player.location = "market"
	check(game.League.block(game).contains("宗门"), "a disciple may not join")
	var outcast := _game()
	outcast.league_join()
	outcast.Events.apply(outcast, [{"league": "ban"}])
	check(outcast.League.banned(outcast) and not outcast.League.member(outcast) and not outcast.League.block(outcast).is_empty(), "one cast out cannot come back")

## The room a retreat takes: the inn, the branch room, a let house, a 灵地 — by rate, then rent.
func _rooms() -> void:
	var game := _game()
	var room: Dictionary = game.Cultivation.room(game)
	check(is_equal_approx(float(room.rate), 0.8) and int(room.rent) == 8, "a wanderer in 云溪 has the inn's room")
	game.league_join()
	room = game.Cultivation.room(game)
	check(room.name == "分舵静室" and is_equal_approx(game.Cultivation.place_rate(game), 1.0) and int(game.Cultivation.rent(game, 30)) == 12, "a member takes the branch's room: whole, twelve stones a month")
	check(game.available_here("rest"), "and rests there for nothing")
	game.world.flags["yunxi_abode"] = true
	check(game.Cultivation.lodging(game).is_empty() and is_equal_approx(game.Cultivation.place_rate(game), 1.0), "a house let by the term asks nothing more")
	game.world.flags.erase("yunxi_abode")
	game.player.stones = 5
	check(int(game.Cultivation.room(game).rent) == 8, "a purse short of the branch's month falls back on the cheaper inn")
	game.player.stones = 5000
	game.Events.apply(game, [{"league": "deputy"}])
	check(game.Cultivation.lodging(game).is_empty() and is_equal_approx(game.Cultivation.place_rate(game), 1.0), "the 副盟主 pays no rent at the branch")
	var north := _game()
	north.league_join()
	north.player.location = "beiyue"
	_grow(north, 1, 3)
	check(is_equal_approx(north.Cultivation.place_rate(north), 1.0) and north.Breakthrough.settled_ground(north).is_empty(), "a 筑基 member at 北岳 has the branch room, not the 灵地")
	_grow(north, 2, 0)
	check(is_equal_approx(north.Cultivation.place_rate(north), 1.0), "金丹 without standing, still not")
	north.League.gain(north, 150)
	var land: Dictionary = north.Cultivation.room(north)
	check(land.name == "负岳灵窟" and is_equal_approx(float(land.rate), 1.2) and int(land.rent) == 60, "金丹 with standing rents the 灵窟")
	check(str(north.Breakthrough.settled_ground(north).get("name", "")) == "负岳灵窟", "and breaks through there with its bonus")
	var before := north.cultivation_rate()
	north.player.location = "market"
	check(north.cultivation_rate() < before, "the 灵地 yields more than the branch room")

## The 青灯簿: offers beside the city board for members only, handed in there for standing.
func _board() -> void:
	var game := _game()
	var board := game.board_here()
	check(board == "market" and game.commission_offers(board).all(func(offer: Dictionary) -> bool: return offer.board == "market"), "a wanderer reads only the city board")
	game.league_join()
	var mine: Array = game.commission_offers(board).filter(func(offer: Dictionary) -> bool: return offer.board == "league_market")
	check(not mine.is_empty() and mine.all(func(offer: Dictionary) -> bool: return int(offer.reward.get("standing", 0)) > 0), "a member reads the 青灯簿 beside it, for standing")
	var salve: Array = []
	for period: int in 12:
		game.world.day = period * int(game.content.commission_data.period_days)
		salve = game.commission_offers(board).filter(func(offer: Dictionary) -> bool: return offer.kind == "league_salve")
		if not salve.is_empty():
			break
	check(not salve.is_empty(), "the branch asks for salves some season")
	if salve.is_empty():
		return
	var offer: Dictionary = salve[0]
	game.accept_commission(str(offer.key))
	var quest: Dictionary = game.player.quests[0]
	game.add_item(str(quest.item), int(quest.count))
	check(game.delivery_block(quest).is_empty(), "handed in at the city where the branch is")
	game.deliver_commission(str(quest.key))
	check(game.League.standing(game) == int(offer.reward.standing) and game.player.quests.is_empty(), "the alliance remembers it")
	var other := _game()
	other.league_join()
	for period: int in 12:
		other.world.day = period * int(other.content.commission_data.period_days)
		var any: Array = other.commission_offers("market").filter(func(o: Dictionary) -> bool: return o.board == "league_market")
		if not any.is_empty():
			other.accept_commission(str(any[0].key))
			break
	check(other.player.quests.size() == 1, "a member takes a branch commission")
	other.league_leave()
	check(other.player.quests.is_empty(), "leaving drops it")

## Beaten far from any inn, a member is carried to the branch they joined at and keeps the purse.
func _shelter() -> void:
	var game := _game()
	_grow(game, 1, 0)
	game.player.location = "canglan"
	game.league_join()
	game.player.location = "chifeng"
	game.begin_battle("huo_ya", "hunt")
	game.battle.hp = 0
	game.Combat._lose(game)
	check(str(game.player.location) == "canglan" and int(game.player.stones) == 5000, "carried to 沧澜's branch, nothing taken")
	var lone := _game()
	_grow(lone, 1, 0)
	lone.player.location = "chifeng"
	lone.begin_battle("huo_ya", "hunt")
	lone.battle.hp = 0
	lone.Combat._lose(lone)
	check(str(lone.player.location) != "canglan" and int(lone.player.stones) == 4990, "a lone wanderer loses ten stones as before")

## 「青灯账」: 何不归 asks, the ship's books and the trail to 赤枫岭, then 钱三省 — exposed or paid off.
func _ledger() -> void:
	for ending: String in ["expose", "share"]:
		var game := _game()
		_grow(game, 1, 0)
		game.wait(1)
		check(game.story_state("qingdeng") == "", "not before joining (%s)" % ending)
		game.league_join()
		game.wait(1)
		check(game.story_state("qingdeng") == "active", "a 筑基 member at 云溪 is asked")
		game.interact("he_bugui", "talk")
		check(game.story_at("qingdeng", "port"), "何不归 tells of the eleven")
		game.player.location = "wanghai"
		game.wait(1)
		check(game.story_at("qingdeng", "trail"), "望海's books have none of them")
		game.player.location = "chifeng"
		game.wait(1)
		check(game.story_at("qingdeng", "confront") and game.has_flag("qingdeng_token"), "the burnt lamp token at 赤枫岭")
		game.player.location = "market"
		game.wait(1)
		check(game.pending_event.get("id", "") == "qingdeng_choice", "钱三省 at the lamp")
		var stones := int(game.player.stones)
		game.choose_event(ending)
		check(game.story_state("qingdeng") == "done" and not game.Events.met(game, {"present": "qian_sanxing"}), "the ledger closed, 钱三省 gone (%s)" % ending)
		match ending:
			"expose":
				check(game.League.deputy(game) and game.League.standing(game) >= 300 and game.Cultivation.lodging(game).is_empty(), "副盟主: the branch rooms ask nothing")
			"share":
				check(game.League.banned(game) and not game.League.member(game) and int(game.player.stones) == stones + 440 and game.has_flag("xiongren_qingdeng"), "half the money, cast out, and named among the 凶人")
		var copy := _reload(game)
		check(copy.League.deputy(copy) == game.League.deputy(game) and copy.League.banned(copy) == game.League.banned(game), "the ending survives a save (%s)" % ending)
	var leaver := _game()
	_grow(leaver, 1, 0)
	leaver.league_join()
	leaver.wait(1)
	leaver.league_leave()
	check(leaver.story_state("qingdeng") == "closed", "leaving the alliance lets the ledger go")

func _saves() -> void:
	var game := _game()
	game.league_join()
	game.League.gain(game, 40)
	var copy := _reload(game)
	check(copy.League.member(copy) and copy.League.standing(copy) == 40 and copy.League.home(copy) == "market", "membership, standing and branch come back")
	var broken: Dictionary = JSON.parse_string(JSON.stringify(game.snapshot()))
	broken.world.flags.erase("league_member")
	check(not Session.new().restore(broken), "a member without the flag is refused")
	broken = JSON.parse_string(JSON.stringify(game.snapshot()))
	broken.player.league.branch = "ridge"
	check(not Session.new().restore(broken), "a branch that does not exist is refused")
	var old: Dictionary = JSON.parse_string(JSON.stringify(_game().snapshot()))
	old.player.erase("league")
	var older := Session.new()
	check(older.restore(old) and not older.League.member(older), "a journey from before the alliance loads")
