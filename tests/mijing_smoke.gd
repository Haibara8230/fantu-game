extends SceneTree
## 秘境框架与赤霞谷、万剑冢 (docs/SIDEQUESTS_DRAFT_20261020.md 四, step 4): realms open on their days and
## shut whoever stays; who may go in and by which way; someone after a room's things, a companion who
## turns, the story's events inside and at the door, the share handed over, robbers outside. 赤霞谷's
## blood pool and its endings; 万剑冢's sword that chooses its owner and 天阙剑宗 at the door. All of it
## survives a save.
const Session = preload("res://scripts/core/session.gd")
const Calendar = preload("res://scripts/core/calendar.gd")
const SWORD := "e:queguang:4:metal:sharp+spirit+attune:0"
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
	_calendar()
	_gate()
	_rooms()
	_duels()
	_betrayal()
	_pool()
	_endings()
	_shares()
	_ambush()
	_trapped()
	_carried()
	_sword()
	_saves()
	print("MIJING: %d checks, %d failures" % [checks, failures])
	quit(0 if failures == 0 else 1)

func _game(realm: int = 0, stage: int = 3) -> Session:
	var game := Session.new()
	game.encounters_enabled = false
	game.new_game("秘境", 47, ["metal", "wood", "water"], "free")
	game.world.flags["tiannan_known"] = true
	game.world.storylines["rushi"] = {"state": "done", "step": 0, "since": 0, "begun": true, "base": {}}
	game.world.flags["rushi_done"] = true
	game.player.stones = 5000
	game.player.location = "market"
	_grow(game, realm, stage)
	# Nobody in the way and nobody at the door unless a test asks.
	game.fortune["mijing_meet"] = 1.0
	game.fortune["mijing_ambush"] = 1.0
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

## Lives on to the realm's first opening and stops the player where they are.
func _open(game: Session, realm_id: String) -> void:
	var opening: Dictionary = game.content.events[realm_id + "_open"].periodic
	game.advance_days(Calendar.to_day(int(opening.start_year), int(opening.month), 1) - int(game.world.day))
	game.conclude("")
	# Whatever else waits there (a stranger at the crossing) is set aside.
	for tries: int in 5:
		if game.pending_event.is_empty() or str(game.pending_event.id).ends_with("_gate"):
			break
		game.pending_event = {}
		game.conclude("")

## Into 赤霞谷 by a way, the first days' events answered.
func _inside(game: Session, way: String = "buy", partner: String = "alone") -> void:
	_open(game, "chixia")
	game.choose_event(way)
	if game.pending_event.get("id", "") == "chixia_pair":
		game.choose_event(partner)
	if game.pending_event.get("id", "") == "chixia_bribe":
		game.choose_event("no")

func _enter(game: Session, room_id: String) -> String:
	return game.enter_room(game.Mijing.realm(game, game.Mijing.inside(game)).cave, room_id)

## Two realms at places of their own, no road in, each room in a circle.
func _data() -> void:
	var game := _game()
	var realms: Dictionary = game.content.mijing_data.realms
	check(realms.has("chixia") and realms.has("wanjian"), "赤霞谷 and 万剑冢")
	for realm_id: String in realms:
		var info: Dictionary = realms[realm_id]
		check(game.content.neighbors(str(info.location), game.world.flags).is_empty(), "no road reaches %s" % info.name)
		check(game.content.cave_data[info.cave].rooms.all(func(room: Dictionary) -> bool: return room.has("layer")), "%s's rooms each have a circle" % info.name)
	check(game.content.items.xiaxue_zhi.breakthrough.realm == 1 and not game.content.equipment(SWORD).is_empty(), "the 霞血芝 stands in for the 筑基丹, the 阙光剑 exists")
	check(game.content.locations.chifeng.spots.any(func(spot: Dictionary) -> bool: return spot.id == "abode" and spot.requires_flag == "chixia_abode"), "the 赤枫别院 waits on its flag")

## 赤霞谷 every fifteen years from 15 for a month; 万剑冢 every thirty from 40 for three months.
func _calendar() -> void:
	var game := _game()
	game.advance_days(Calendar.to_day(15, 3, 2) - int(game.world.day))
	check(game.Mijing.is_open(game, "chixia") and game.Mijing.days_left(game, "chixia") == 29, "赤霞谷 opens in the third month of 15, a month to go")
	check(game.location_visible("chixia"), "and shows on the map")
	game.advance_days(Calendar.to_day(15, 4, 2) - int(game.world.day))
	check(not game.Mijing.is_open(game, "chixia"), "and shuts a month later")
	game.advance_days(Calendar.to_day(30, 3, 2) - int(game.world.day))
	check(game.Mijing.is_open(game, "chixia"), "fifteen years on it opens again")
	game.advance_days(Calendar.to_day(40, 6, 20) - int(game.world.day))
	check(game.Mijing.is_open(game, "wanjian") and game.Mijing.days_left(game, "wanjian") == 11, "万剑冢 opens in the fourth month of 40, three months long")
	game.advance_days(Calendar.to_day(40, 7, 2) - int(game.world.day))
	check(not game.Mijing.is_open(game, "wanjian"), "the sword tide comes back")

## Asked in at the places it calls from, once each opening, only within its realms; the ways in.
func _gate() -> void:
	var low := _game(0, 1)
	_open(low, "chixia")
	check(low.pending_event.is_empty(), "炼气中期 is not let in")
	var high := _game(2, 0)
	_open(high, "chixia")
	check(high.pending_event.is_empty(), "nor a 金丹")
	var game := _game()
	game.player.location = "ridge"
	_open(game, "chixia")
	check(game.pending_event.is_empty(), "nobody asks on the ridge")
	game.player.location = "market"
	game.conclude("")
	check(game.pending_event.get("id", "") == "chixia_gate" and int(game.pending_event.values.days) == 30, "at 云溪 the gate asks, a month to go")
	var choices: Array = game.pending_definition().choices
	check(not game.choice_available(choices[0]) and game.choice_available(choices[2]), "a wanderer cannot go with a sect, but may stand in for 赤霄")
	var stones := int(game.player.stones)
	game.choose_event("proxy")
	check(game.Mijing.inside(game) == "chixia" and game.player.location == "chixia" and int(game.player.stones) == stones + 50, "in for 赤霄, fifty stones paid")
	check(game.pending_event.get("id", "") == "chixia_pair", "two at the gate would go along")
	game.choose_event("su")
	check(game.Caves.party(game, "chixia") == "su_heng", "苏蘅 comes along")
	check(game.pending_event.get("id", "") == "chixia_bribe", "robbers at the door can be paid beforehand")
	game.choose_event("pay")
	check(game.has_flag("chixia_bribed") and int(game.player.stones) == stones - 30, "paid off")
	check(game.travel("nanming").contains("出口"), "no walking off inside")
	game.player.location = "market"
	game.Mijing.state(game).inside = ""
	game.conclude("")
	check(game.pending_event.is_empty(), "asked only once an opening")
	check(game.travel("chixia").contains("没有路"), "and no road to it")
	var declining := _game()
	_open(declining, "chixia")
	declining.choose_event("decline")
	declining.conclude("")
	check(declining.pending_event.is_empty() and declining.Mijing.inside(declining).is_empty(), "declined, it is not asked again")
	var disciple := _game()
	disciple.player.affiliation = "qingyun"
	disciple.player.sect = "qingyun"
	disciple.player.location = "sect"
	_open(disciple, "chixia")
	check(disciple.pending_event.get("id", "") == "chixia_gate" and disciple.choice_available(disciple.pending_definition().choices[0]), "a 五宗 disciple is called at the sect and goes with the leader")

## Rooms by circles: things found count as gathered; a companion's gifts; the blood pool behind the mist.
func _rooms() -> void:
	var game := _game()
	_inside(game, "buy", "su")
	_enter(game, "slope")
	check(int(game.Mijing.state(game).haul.get("xiaxue_zhi", 0)) >= 1, "the 霞血芝 found counts as gathered")
	check(not game.Caves.enter_block(game, "chixia", "garden").is_empty(), "the inner garden is not reached yet")
	_enter(game, "beds")
	_enter(game, "garden")
	check(game.Caves.enter_block(game, "chixia", "pool").contains("雾"), "the mist bars the pool")
	var lei := _game()
	_inside(lei, "buy", "lei")
	_enter(lei, "slope")
	check(int(lei.Mijing.state(lei).haul.get("xiaxue_zhi", 0)) >= 2, "雷三 finds one more")

## Someone after a room's things: fight, give, or leave it to them; a 天骄 met inside.
func _duels() -> void:
	var game := _game(1, 1)
	_inside(game, "buy")
	game.Mijing.state(game).beats.append("chixia_vanish")
	game.fortune["mijing_meet"] = 0.0
	_enter(game, "slope")
	check(game.pending_event.get("id", "") == "chixia_meet" and game.Caves.loot_waits(game, "chixia", "slope"), "someone is after the slope's 霞血芝, still lying there")
	game.choose_event("fight")
	check(game.battle.get("context", "") == "mijing" and int(game.battle.foe.realm) == 1, "a duel with them, of the player's realm")
	var stones := int(game.player.stones)
	game.Combat._win(game)
	check(int(game.Mijing.state(game).wins) == 1 and int(game.player.stones) > stones and game.Mijing.inside(game) == "chixia", "won: their stones, a win counted, still inside")
	game.collect_room("chixia", "slope")
	check(int(game.Mijing.state(game).haul.get("xiaxue_zhi", 0)) >= 1, "and the slope's things taken")
	_enter(game, "beds")
	game.choose_event("ally")
	check(bool(game.Mijing.state(game).ally) and not game.Caves.loot_waits(game, "chixia", "beds"), "left to them, an ally for the way out")
	game.add_item("xiaxue_zhi", 2)
	game.Mijing.record(game, {"xiaxue_zhi": 2})
	var held := game.item_count("xiaxue_zhi")
	_enter(game, "cliff")
	game.choose_event("fight")
	game.Combat._lose(game)
	check(game.Mijing.inside(game) == "chixia" and game.item_count("xiaxue_zhi") < held, "lost: a third gone, still inside")
	# A 天骄 of the 筑基卷 inside: a win moves the player up the scroll.
	var meeting: Dictionary = game.content.mijing_data.realms.chixia.meet
	var was: float = float(meeting.prodigy)
	meeting.prodigy = 1.0
	_enter(game, "den")
	game.Combat._win(game)
	game.collect_room("chixia", "den")
	_enter(game, "garden")
	check(str(game.pending_event.get("values", {}).get("title", "")).begins_with("天骄榜"), "one of the 天骄 is in the garden")
	game.choose_event("fight")
	game.Combat._win(game)
	check(game.Tianji.rank(game, "zhuji") >= 1 and not game.player.tianji.get("notes", []).is_empty(), "the win is written on the 筑基卷")
	meeting.prodigy = was

## 雷三 turns on the ninth day.
func _betrayal() -> void:
	var game := _game()
	_inside(game, "buy", "lei")
	game.advance_days(9)
	game.conclude("")
	check(game.pending_event.get("id", "") == "chixia_betray", "on the ninth day 雷三 is gone")
	game.choose_event("know")
	check(game.Caves.party(game, "chixia").is_empty() and game.has_flag("chixia_reported"), "he told 焦长老 where the player is")
	game.advance_days(1)
	game.conclude("")
	check(game.pending_event.get("id", "") == "chixia_vanish" and game.has_flag("chixia_reported"), "the tenth day: people vanish")

## The tenth day lifts the mist; the pool and its choices.
func _pool() -> void:
	var game := _game(1, 0)
	_inside(game, "buy", "su")
	game.advance_days(10)
	game.conclude("")
	check(game.pending_event.get("id", "") == "chixia_vanish", "people vanish on the tenth day")
	check(game.choice_available(game.pending_definition().choices[0]), "苏蘅 saw where they went")
	game.choose_event("su")
	for room_id: String in ["slope", "beds", "garden"]:
		_enter(game, room_id)
	_enter(game, "pool")
	check(game.pending_event.get("id", "") == "chixia_pool", "焦长老 at the blood pool")
	check(game.choice_available(game.pending_definition().choices[1]), "神识 enough to pull the flags unseen")
	game.choose_event("sneak")
	check(game.has_flag("chixia_rescued"), "the hanging ones freed")
	game.mijing_exit()
	check(game.pending_event.get("id", "") == "chixia_exit", "焦长老 accuses the player at the door")
	game.choose_event("witness")
	check(game.Mijing.inside(game).is_empty() and game.player.location == "market", "out, back at 云溪")
	check(game.has_flag("chixia_done") and game.has_flag("chixia_free") and game.has_flag("chixia_abode"), "焦长老 falls: the valley free to wanderers, the 赤枫别院 given")
	game.player.location = "chifeng"
	check(game.available_here("cultivate"), "the 赤枫别院 takes a retreat")
	var reported := _game(1, 0)
	_inside(reported, "buy", "lei")
	reported.advance_days(9)
	reported.conclude("")
	reported.choose_event("know")
	reported.advance_days(1)
	reported.conclude("")
	reported.choose_event("look")
	for room_id: String in ["slope", "beds", "garden", "pool"]:
		_enter(reported, room_id)
	check(not reported.choice_available(reported.pending_definition().choices[1]), "told on, the flags cannot be pulled unseen")
	reported.choose_event("expose")
	check(reported.battle.get("enemy_id", "") == "jiao_array", "a fight with 焦长老 at his array")
	reported.Combat._win(reported)
	check(reported.has_flag("chixia_jiao_down") and reported.Mijing.inside(reported) == "chixia", "his flags cut")
	reported.mijing_exit()
	check(reported.Mijing.inside(reported).is_empty() and reported.has_flag("chixia_free"), "nobody to accuse anyone: out, and the valley free")

## The other endings: the 血元丹, 苏蘅's thanks, nothing done.
func _endings() -> void:
	var dan := _game(1, 0)
	_inside(dan, "buy")
	dan.world.flags["chixia_mist"] = true
	for room_id: String in ["slope", "beds", "garden", "pool"]:
		_enter(dan, room_id)
	dan.choose_event("take")
	check(dan.item_count("xueyuan_dan") == 1, "the 血元丹 taken")
	var mind := int(dan.player.get("mind", 0))
	dan.mijing_exit()
	dan.choose_event("hand")
	check(dan.has_flag("chixia_done") and dan.has_flag("chixia_dan") and dan.item_count("xiaxue_zhi") == 0, "his mouth stopped with the 霞血芝, the 血元丹 kept")
	check(int(dan.player.get("mind", 0)) < mind, "and it weighs on the mind")
	var su := _game()
	_inside(su, "buy", "su")
	su.world.flags["chixia_mist"] = true
	su.mijing_exit()
	check(su.has_flag("chixia_suheng") and su.item_count("xiaxue_zhi") == 2, "out with 苏蘅: her thanks")
	su.player.location = "changqing_valley"
	check(su.Tianji.discount(su) < 1.0, "长青谷's shop lets the price go")
	var idle := _game()
	_inside(idle, "buy")
	idle.mijing_exit()
	check(not idle.has_flag("chixia_done"), "out before the tenth day: the story waits for the next opening")

## What a way hands over on the way out: 赤霄's seven tenths, a sect's half for merit.
func _shares() -> void:
	var game := _game()
	_inside(game, "proxy")
	game.add_item("xiaxue_zhi", 3)
	game.Mijing.record(game, {"xiaxue_zhi": 3})
	game.mijing_exit()
	check(game.item_count("xiaxue_zhi") == 1, "two of three to 赤霄")
	var disciple := _game()
	disciple.player.affiliation = "qingyun"
	disciple.player.sect = "qingyun"
	disciple.player.location = "sect"
	_open(disciple, "chixia")
	disciple.choose_event("sect")
	disciple.choose_event("alone")
	disciple.choose_event("no")
	disciple.add_item("xiaxue_zhi", 4)
	disciple.Mijing.record(disciple, {"xiaxue_zhi": 4})
	var merit := int(disciple.player.get("contribution", 0))
	disciple.mijing_exit()
	check(disciple.item_count("xiaxue_zhi") == 2 and int(disciple.player.get("contribution", 0)) > merit and disciple.player.location == "sect", "half to the sect, for merit, back at the sect")
	var free := _game()
	free.world.flags["chixia_free"] = true
	_open(free, "chixia")
	check(not free.choice_available(free.pending_definition().choices[2]) and free.choice_available(free.pending_definition().choices[1]), "once free, wanderers walk in")

## Robbers outside, by what is carried: handed over, fought, slipped by, paid off.
func _ambush() -> void:
	var game := _game()
	_inside(game)
	game.add_item("xiaxue_zhi", 4)
	game.Mijing.record(game, {"xiaxue_zhi": 4})
	check(game.Mijing.ambush_chance(game, "chixia", game.Mijing.carried(game, game.Mijing.state(game).haul), false) > game.Mijing.ambush_chance(game, "chixia", game.Mijing.carried(game, game.Mijing.state(game).haul), true), "an ally halves the odds")
	game.fortune["mijing_ambush"] = 0.0
	game.mijing_exit()
	check(game.pending_event.get("id", "") == "chixia_ambush", "someone waits outside")
	game.choose_event("pay")
	check(game.item_count("xiaxue_zhi") == 2, "half handed over")
	var fought := _game()
	_inside(fought)
	fought.add_item("xiaxue_zhi", 4)
	fought.Mijing.record(fought, {"xiaxue_zhi": 4})
	fought.fortune["mijing_ambush"] = 0.0
	fought.mijing_exit()
	fought.choose_event("fight")
	check(fought.battle.get("enemy_id", "") == "chixia_robber", "fought for")
	fought.Combat._lose(fought)
	check(fought.item_count("xiaxue_zhi") == 2, "beaten, half taken")
	var bribed := _game()
	_open(bribed, "chixia")
	bribed.choose_event("buy")
	bribed.choose_event("alone")
	bribed.choose_event("pay")
	bribed.add_item("xiaxue_zhi", 4)
	bribed.Mijing.record(bribed, {"xiaxue_zhi": 4})
	bribed.fortune["mijing_ambush"] = 0.0
	bribed.mijing_exit()
	check(bribed.pending_event.is_empty() and bribed.item_count("xiaxue_zhi") == 4, "paid beforehand, nobody waits")

## Shut in: a 遁地符 tears a way out with half; without one, nothing comes out.
func _trapped() -> void:
	var game := _game()
	_inside(game)
	game.add_item("xiaxue_zhi", 4)
	game.Mijing.record(game, {"xiaxue_zhi": 4})
	game.add_item("dundi_fu", 1)
	game.advance_days(31)
	check(game.Mijing.inside(game).is_empty() and game.player.location == "market" and game.item_count("dundi_fu") == 0 and game.item_count("xiaxue_zhi") == 2, "the 遁地符 tore a way out, half lost")
	var stuck := _game()
	_inside(stuck)
	stuck.add_item("xiaxue_zhi", 4)
	stuck.Mijing.record(stuck, {"xiaxue_zhi": 4})
	stuck.advance_days(31)
	check(stuck.Mijing.inside(stuck).is_empty() and stuck.item_count("xiaxue_zhi") == 0 and int(stuck.player.hp) == 1, "without one: everything gone, barely alive")

## Beaten by a guardian inside: carried out, half lost on the way.
func _carried() -> void:
	var game := _game()
	_inside(game)
	game.add_item("xiaxue_zhi", 4)
	game.Mijing.record(game, {"xiaxue_zhi": 4})
	_enter(game, "cliff")
	_enter(game, "den")
	check(game.battle.get("enemy_id", "") == "xiawen_bao", "the 霞纹豹 in its den")
	game.Combat._lose(game)
	check(game.Mijing.inside(game).is_empty() and game.player.location != "chixia" and game.item_count("xiaxue_zhi") < 5, "carried out, half lost")

## 万剑冢: a sword token or a fight at the door; wins before the heart; the sword chooses; 天阙 at the door.
func _sword() -> void:
	var game := _game(1, 2)
	game.player.location = "duanjian"
	_open(game, "wanjian")
	check(game.pending_event.get("id", "") == "wanjian_gate", "天阙's door wardens at the 万剑冢 (%s)" % game.pending_event.get("id", ""))
	game.choose_event("force")
	check(game.battle.get("enemy_id", "") == "tianque_guard", "pushing past them is a fight")
	game.Combat._win(game)
	check(game.pending_event.get("id", "") == "wanjian_gate" and game.choice_available(game.pending_definition().choices[1]), "one of them down, the way in is open")
	game.choose_event("forced")
	check(game.Mijing.inside(game) == "wanjian" and game.has_flag("tianque_slight"), "in, and 天阙 remembers")
	for room_id: String in ["forest", "stele"]:
		_enter(game, room_id)
	check(game.Caves.enter_block(game, "wanjian", "heart").contains("胜过 3 人"), "the heart asks three wins inside")
	game.Mijing.state(game).wins = 3
	_enter(game, "heart")
	check(game.battle.get("enemy_id", "") == "wanjian_ling", "the sword spirit")
	game.Combat._win(game)
	game.collect_room("wanjian", "heart")
	check(game.Gear.holds(game, SWORD), "阙光 chooses its owner")
	check(game.Mijing._lose(game, 1.0).is_empty() or game.Gear.holds(game, SWORD), "no robber takes a sword that chose its owner")
	game.mijing_exit()
	check(game.pending_event.get("id", "") == "wanjian_exit", "天阙's first disciple waits at the door")
	var stones := int(game.player.stones)
	game.choose_event("return")
	check(not game.Gear.holds(game, SWORD) and game.has_flag("tianque_friend") and int(game.player.stones) >= stones + 1500, "handed back: 天阙 owes a sword")
	check(game.has_flag("wanjian_done") and game.player.location == "duanjian", "out at 断剑峡")
	check(game.Caves.gone(game, "wanjian", "heart") and not game.Caves.guarded(game, "wanjian", "heart"), "the heart stays empty")
	var keeper := _game(2, 0)
	keeper.player.location = "duanjian"
	_open(keeper, "wanjian")
	keeper.choose_event("token")
	keeper.Mijing.state(keeper).wins = 3
	keeper.world.flags["wanjian_ling_down"] = true
	for room_id: String in ["forest", "pool", "heart"]:
		_enter(keeper, room_id)
	keeper.collect_room("wanjian", "heart")
	keeper.equip_item(SWORD)
	keeper.mijing_exit()
	check(keeper.pending_event.get("id", "") == "wanjian_exit", "a worn sword counts too")
	keeper.choose_event("keep")
	check(keeper.battle.get("enemy_id", "") == "tianque_heir", "keeping it is answered with a sword")
	keeper.Combat._win(keeper)
	keeper.mijing_exit()
	check(keeper.Mijing.inside(keeper).is_empty() and keeper.has_flag("tianque_feud") and keeper.Gear.holds(keeper, SWORD), "out with 阙光; 天阙's swordsmen will come for it")

## Inside with things gathered and someone met, and mid-duel: all of it survives a save.
func _saves() -> void:
	var game := _game(1, 0)
	_inside(game, "buy", "su")
	game.fortune["mijing_meet"] = 0.0
	_enter(game, "slope")
	var copy := _reload(game)
	check(copy.Mijing.inside(copy) == "chixia" and copy.pending_event.get("id", "") == "chixia_meet" and copy.Mijing.state(copy).meet.name == game.Mijing.state(game).meet.name, "inside, someone met")
	copy.choose_event("fight")
	var fighting := _reload(copy)
	check(fighting.battle.get("context", "") == "mijing", "mid-duel")
	fighting.Combat._win(fighting)
	check(int(fighting.Mijing.state(fighting).wins) == 1, "and the duel ends as it would have")
