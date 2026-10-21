extends SceneTree
## 多宗底座 (docs/SIDEQUESTS_DRAFT_20261020.md 2): sects in six tiers, each with its own gate, ranks,
## duties, exchange and board; the ways the sects take disciples; moving to a higher sect against
## betraying one's own; 客卿 at up to two sects, a disciple's only where the sects do not clash; and all
## of it surviving a save.
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
	_data()
	_gates()
	_moving()
	_life()
	_guests()
	_saves()
	_seven()
	print("ZONGMEN: %d checks, %d failures" % [checks, failures])
	quit(0 if failures == 0 else 1)

func _game(roots: Array = ["metal", "wood", "water"], seed_value: int = 41) -> Session:
	var game := Session.new()
	game.encounters_enabled = false
	game.new_game("多宗", seed_value, roots, "free")
	game.world.flags["tiannan_known"] = true
	game.player.stones = 5000
	return game

## A cultivator of `realm` and `stage`, healthy.
func _grow(game: Session, realm: int, stage: int) -> void:
	game.player.realm = realm
	game.player.stage = stage
	game.player.xp = int(game.content.stage(realm, stage).xp)
	game.refresh_realm_stats()
	game.player.hp = game.player.max_hp
	game.player.qi = game.player.max_qi

func _at_year(game: Session, year: int) -> void:
	game.world.day = Calendar.to_day(year, 3, 1)

func _join(game: Session, place: String) -> String:
	game.player.location = place
	return game.join_sect()

func _reload(game: Session) -> Session:
	var copy := Session.new()
	check(copy.restore(JSON.parse_string(JSON.stringify(game.snapshot()))), "the journey survives a save")
	return copy

## Eight sects in their tiers, each with a gate, an office and a board of its own.
func _data() -> void:
	var game := _game()
	var sects: Dictionary = game.content.sect_data.sects
	check(sects.size() == 8 and sects.has("qingyun") and sects.has("baicao") and sects.has("feiyu"), "八宗: 青云, the four of 天南 and three 入流")
	check(game.Sect.tier_order(game, "baicao") < game.Sect.tier_order(game, "qingyun") and game.Sect.tier_order(game, "qingyun") < game.Sect.tier_order(game, "chixiao"), "入流 below 小宗 below 中宗")
	check(game.Sect.tier_name(game, "baihua") == "入流" and game.Sect.tier_name(game, "canglan") == "中宗", "the tiers have their names")
	check(game.content.locations.has("baihua") and int(game.content.route_between("market", "baihua").get("days", 0)) == 1, "百花谷 lies a day from 云溪")
	for sect_id: String in sects:
		var table: Dictionary = sects[sect_id]
		check(game.content.commission_data.boards[str(table.board)].get("affiliation", "") == sect_id, sect_id + " has its own board")
	check(game.content.rank_index("inner") == 2 and game.content.rank_index("head") == 4, "rank ids are shared by every sect")

## Each sect's way of taking disciples.
func _gates() -> void:
	# 赤霄: a fire root, and only every third year.
	var fire := _game(["fire", "wood"])
	_at_year(fire, 4)
	fire.player.location = "chixiao_gate"
	check(fire.Sect.here(fire) == "chixiao" and fire.join_block().contains("每 3 年") and fire.join_block().contains("6 年"), "赤霄 opens its furnace every third year, next in year 6")
	_at_year(fire, 6)
	check(fire.join_block().is_empty(), "in year 6 a fire root may join")
	var metal := _game(["metal", "water"])
	_at_year(metal, 6)
	metal.player.location = "chixiao_gate"
	check(metal.join_block().contains("火灵根"), "without a fire root 赤霄 takes no one")
	var text := fire.join_sect()
	check(fire.affiliation() == "chixiao" and text.contains("开炉台") and fire.sect_rank().name == "学徒", "joined, a 学徒 of 赤霄")
	# 长青: 炼气 only, and a year of chores before the first promotion.
	var herb := _game()
	_grow(herb, 1, 0)
	herb.player.location = "changqing_valley"
	check(herb.join_block().contains("收不下"), "长青 takes no 筑基")
	_grow(herb, 0, 2)
	_join(herb, "changqing_valley")
	check(herb.affiliation() == "changqing", "a 炼气 cultivator joins 长青")
	herb.player.merit = 500
	check(herb.promotion_block().contains("再待"), "the first promotion waits for a year of chores")
	herb.world.day += 361
	check(herb.promotion_block().is_empty(), "a year on, the 药师 is earned")
	# 沧澜: once in ten years, and 神识 enough for the chart.
	var water := _game()
	_at_year(water, 10)
	_grow(water, 0, 0)
	water.player.location = "canglan_pavilion"
	check(water.join_block().contains("神识"), "a 炼气初期 eye cannot read 沧澜's chart")
	_grow(water, 0, 2)
	check(water.join_block().is_empty(), "炼气后期 reads it, in a tenth year")
	_at_year(water, 11)
	check(water.join_block().contains("10 年"), "and in other years the gate is shut")
	# 玄岳: 气血 enough for 负山, and a 金丹 still taken.
	var stone := _game()
	_grow(stone, 0, 0)
	stone.player.location = "xuanyue_gate"
	check(stone.join_block().contains("负山"), "a 炼气 body cannot carry the stone")
	_grow(stone, 2, 0)
	check(stone.join_block().is_empty(), "a 金丹 can, and 玄岳 still takes one")
	_join(stone, "xuanyue_gate")
	check(stone.sect_rank().name == "镇岳弟子", "a newcomer starts at the rank their cultivation merits, the inner court at most")
	# 入流: anyone of 炼气 or 筑基.
	var pine := _game()
	_grow(pine, 0, 3)
	_join(pine, "ridge")
	check(pine.affiliation() == "baicao" and pine.sect_rank().name == "入室弟子", "百草门 takes a 炼气圆满 straight into its inner rooms")
	check(pine.next_sect_rank().name == "亲传弟子", "with 亲传 next")
	pine.player.rank = 3
	check(pine.promotion_block().contains("门中大事"), "门主 is not earned by merit")
	check(pine.Sect.raise_to(pine, "head").contains("门主") and pine.sect_rank().name == "门主", "but given by the sect's story")

## Moving up is a parting; moving level or down is betrayal.
func _moving() -> void:
	var game := _game(["fire", "metal"])
	_grow(game, 0, 1)
	_join(game, "ridge")
	game.player.merit = 300
	game.player.contribution = 120
	_join(game, "sect")
	check(game.affiliation() == "qingyun" and game.player.get("betrayed", []).is_empty(), "百草门 to 青云 is a move up, not a betrayal")
	check(int(game.player.merit) == 0 and int(game.player.contribution) == 0 and game.sect_rank().name == "外门精英", "the standing starts afresh, at the rank cultivation merits")
	check(game.chronicle.entries.any(func(entry: Dictionary) -> bool: return entry.id == "sect_moved"), "the parting is written down")
	game.mark_met("xu_qinghe")
	var before := game.favor("xu_qinghe")
	game.player.location = "baihua"
	check(game.Sect.betrays(game, "baihua"), "百花谷 is lower than 青云")
	game.join_sect()
	check(game.affiliation() == "baihua" and "qingyun" in game.player.betrayed, "leaving 青云 for 入流 is betrayal")
	check(game.favor("xu_qinghe") == before - 30, "and 青云's people remember it")
	check(game.chronicle.format(game.chronicle.entries.filter(func(entry: Dictionary) -> bool: return entry.id == "sect_betrayed")[0], game.content).contains("青云剑宗"), "the betrayal names the sect")
	game.player.location = "sect"
	check(game.join_block().contains("叛出过"), "青云 never takes a traitor back")
	_at_year(game, 6)
	_join(game, "chixiao_gate")
	check(game.affiliation() == "chixiao" and not "baihua" in game.player.betrayed, "百花谷 to 赤霄 is a move up again")

## A disciple's places at their own gate: the chamber, the office, the board, the hall.
func _life() -> void:
	var game := _game(["fire"])
	_at_year(game, 3)
	game.player.location = "chixiao_gate"
	check(not game.available_here("sect") and not game.available_here("study"), "an outsider sees no office or hall at 赤霄")
	game.join_sect()
	check(game.available_here("cultivate") and game.available_here("sect") and game.available_here("study") and game.available_here("teach"), "a disciple retreats, does business and studies at the gate")
	check(game.Commissions.board_here(game) == "sect_chixiao", "the 器堂 posts the sect's commissions")
	var offers: Array = game.Commissions.offers(game, "sect_chixiao")
	check(not offers.is_empty() and offers.all(func(offer: Dictionary) -> bool: return int(offer.reward.contribution) > 0), "and they pay contribution")
	check(game.Sect.goods(game).any(func(good: Dictionary) -> bool: return good.item == "dihuo_jing"), "赤霄's exchange trades in the furnace's goods")
	check(game.Loadout.home_lineage(game) == "chixiao" and game.Loadout.lineage_block(game, "chixiao").is_empty(), "the hall keeps 赤霄's own lineage")
	check(game.Sect.office_text(game) == "赤霄门器堂", "business is done at 赤霄门器堂")
	check(game.Sect.duty_block(game, "patrol").contains("炉头"), "the inner court's duty waits for 炉头")
	var pine := _game()
	_join(pine, "ridge")
	check(pine.Loadout.home_lineage(pine).is_empty() and pine.available_here("teach") and pine.teachings().size() > 0, "百草门 has no lineage of its own, only slips to teach")
	check(pine.Commissions.board_here(pine) == "sect_baicao", "and a board of its own")
	var wanderer := _game()
	wanderer.player.location = "ridge"
	check(wanderer.Commissions.board_here(wanderer).is_empty(), "a wanderer reads no sect's board")

## 客卿 at up to two sects; a disciple's only where the sects do not clash.
func _guests() -> void:
	var game := _game()
	_grow(game, 1, 0)
	for sect: String in ["chixiao", "changqing", "xuanyue"]:
		game.world.flags["guest_invite_" + sect] = true
	game.player.location = "chixiao_gate"
	game.guest_accept()
	game.player.location = "changqing_valley"
	game.guest_accept()
	check(game.Guest.is_guest(game, "chixiao") and game.Guest.is_guest(game, "changqing"), "a wanderer stands as guest of two sects")
	check(game.Guest.block(game, "xuanyue").contains("至多"), "but not of a third")
	game.player.location = "chixiao_gate"
	check(game.Commissions.board_here(game) == "guest_chixiao", "a guest at 赤霄 reads its guest board")
	var stones := int(game.player.stones)
	game.wait(31)
	check(int(game.player.stones) - stones == 2 * game.Guest.stipend(game), "each bond pays its own stipend (%d)" % (int(game.player.stones) - stones))
	# Joining 沧澜 (water) keeps both; a 长青 disciple could not stand as 长青's guest.
	_at_year(game, 10)
	_grow(game, 1, 0)
	_join(game, "canglan_pavilion")
	check(game.affiliation() == "canglan" and game.Guest.bonds(game).size() == 2, "a 沧澜 disciple keeps the fire and wood bonds")
	check(game.Guest.clash(game, "canglan").contains("本门"), "and needs no bond with their own sect")
	var wood := _game()
	_grow(wood, 0, 3)
	_join(wood, "ridge")
	_grow(wood, 1, 0)
	wood.world.flags["guest_invite_changqing"] = true
	wood.world.flags["guest_invite_chixiao"] = true
	check(wood.Guest.block(wood, "changqing").contains("同出一路"), "a 百草门 disciple may not serve 长青, of the same lineage")
	wood.player.location = "chixiao_gate"
	wood.guest_accept()
	check(wood.Guest.is_guest(wood, "chixiao"), "but may serve 赤霄")
	var disciple := _game()
	_join(disciple, "sect")
	_grow(disciple, 1, 0)
	disciple.world.flags["guest_invite_chixiao"] = true
	disciple.player.location = "chixiao_gate"
	disciple.guest_accept()
	check(disciple.Guest.is_guest(disciple, "chixiao"), "a 青云 disciple may now stand as 赤霄's guest")
	# Joining the sect one serves lays that bond down.
	var guest := _game(["fire"])
	_grow(guest, 0, 3)
	guest.world.flags["guest_invite_chixiao"] = true
	_grow(guest, 1, 0)
	guest.player.location = "chixiao_gate"
	guest.guest_accept()
	_at_year(guest, 6)
	guest.join_sect()
	check(guest.affiliation() == "chixiao" and not guest.Guest.is_guest(guest, "chixiao") and not guest.has_flag("guest_chixiao"), "joining 赤霄 lays its guest bond down")

## The standing, the betrayals and the bonds survive a save; an older single bond is read as one.
func _saves() -> void:
	var game := _game(["fire"])
	_grow(game, 1, 0)
	game.world.flags["guest_invite_chixiao"] = true
	game.player.location = "chixiao_gate"
	game.guest_accept()
	_join(game, "ridge")
	_join(game, "ferry")
	game.player.rank = 2
	game.player.duty = "patrol"
	var copy := _reload(game)
	check(copy.affiliation() == "feiyu" and copy.sect_rank().name == "头目" and copy.player.duty == "patrol", "the sect, the rank and the duty come back")
	check("baicao" in copy.player.betrayed and copy.Guest.is_guest(copy, "chixiao") and int(copy.player.sect_day) == int(game.player.sect_day), "so do the betrayal, the bond and the day of joining")
	var old: Dictionary = JSON.parse_string(JSON.stringify(game.snapshot()))
	old.player.erase("guests")
	old.player.erase("betrayed")
	old.player.erase("sect_day")
	old.player["guest"] = {"sect": "chixiao", "since": 0, "pay_day": 0, "next_call": 1080, "missed": 1}
	var older := Session.new()
	check(older.restore(old), "an older journey with one bond loads")
	check(older.Guest.bonds(older).size() == 1 and older.Guest.is_guest(older, "chixiao") and int(older.Guest.bond(older, "chixiao").missed) == 1 and older.player.betrayed.is_empty(), "its bond is kept, with nothing betrayed")
	var broken: Dictionary = JSON.parse_string(JSON.stringify(game.snapshot()))
	broken.player["affiliation"] = "nowhere"
	check(not Session.new().restore(broken), "an unknown sect is refused")
	broken.player["affiliation"] = "feiyu"
	broken.player["rank"] = 4
	check(not Session.new().restore(broken), "a rank the sect does not have is refused")
	broken.player["rank"] = 0
	broken.player["guests"] = [{"sect": "chixiao", "since": 0, "pay_day": 0, "next_call": 0, "missed": 0}, {"sect": "chixiao", "since": 0, "pay_day": 0, "next_call": 0, "missed": 0}]
	check(not Session.new().restore(broken), "the same bond twice is refused")

## 百草门「七人门」: 松翁 asks, a year on he calls, and the sect is taken up, given to 青云 or let go.
func _seven() -> void:
	for ending: String in ["take", "merge", "disband"]:
		var game := _game()
		_grow(game, 0, 3)
		_join(game, "ridge")
		game.wait(1)
		check(game.story_state("baicao_seven") == "active", "at 松风岭 the old temple's master asks after its future (%s)" % ending)
		game.interact("song_weng", "talk")
		check(game.story_at("baicao_seven", "wait"), "he tells of the seven left and 青云's offer")
		var waited := 0
		while game.pending_event.get("id", "") != "baicao_choice" and waited < 400:
			waited += 1
			# What else happens on the ridge (the storm's old shrine) is answered and passed by.
			if not game.pending_event.is_empty():
				game.choose_event(str(game.pending_definition().choices[0].id))
			game.wait(1)
		check(game.pending_event.get("id", "") == "baicao_choice", "a year on, at the temple, he asks what is to become of it")
		var take: Dictionary = game.pending_definition().choices[0]
		check(not game.choice_available(take), "a 炼气 disciple cannot take the seat")
		match ending:
			"take":
				_grow(game, 1, 0)
				check(game.choice_available(take), "a 筑基 disciple can")
				game.choose_event("take")
				check(game.affiliation() == "baicao" and game.sect_rank().name == "门主" and game.has_flag("baicao_head"), "the ninth master of 百草门")
			"merge":
				game.choose_event("merge")
				check(game.affiliation() == "qingyun" and game.player.betrayed.is_empty() and game.Sect.closed(game, "baicao"), "given to 青云, its disciples go with it, betraying no one")
				game.player.location = "ridge"
				check(game.join_block().contains("没有了"), "and 百草门 takes no one again")
			"disband":
				game.choose_event("disband")
				check(game.affiliation().is_empty() and game.item_count("lingzhi") >= 1 and game.Sect.closed(game, "baicao"), "let go, its people scatter, leaving a wanderer and an old 灵芝")
		check(game.story_state("baicao_seven") == "done" and not game.Events.met(game, {"present": "song_weng"}), "松翁 passes on (%s)" % ending)
		var copy := _reload(game)
		check(copy.affiliation() == game.affiliation() and copy.Sect.closed(copy, "baicao") == game.Sect.closed(game, "baicao"), "the end of the story survives a save (%s)" % ending)
