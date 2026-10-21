extends SceneTree
## 天机阁与天骄榜、萧家麒麟子 (docs/SIDEQUESTS_DRAFT_20261020.md 三与五, step 3): the scrolls posted at the
## five cities' 榜亭, revised every ten years; 战帖 up the board and challenges from below; the ten
## highest's gift and prices; 批注. 萧凌云's four bouts: 潜龙会, 天南大比 (the pill and the rigged draw),
## the 金丹卷 with 萧家's 供奉 in the way, and the reckoning at 萧家. All of it survives a save.
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
	_board()
	_challenge()
	_defend()
	_rewards()
	_revision()
	_qianlong()
	_dabi()
	_bang()
	_house()
	_saves()
	print("TIANJI: %d checks, %d failures" % [checks, failures])
	quit(0 if failures == 0 else 1)

func _game(seed_value: int = 43) -> Session:
	var game := Session.new()
	game.encounters_enabled = false
	game.new_game("天骄", seed_value, ["metal", "wood", "water"], "free")
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

func _year(game: Session, year: int) -> void:
	game.world.day = Calendar.to_day(year, 1, 1)

## The story at a step, begun.
func _story(game: Session, step_id: String) -> void:
	var steps: Array = game.content.storylines.xiao_rival.steps
	var index := 0
	for at: int in steps.size():
		if steps[at].id == step_id:
			index = at
	game.world.storylines["xiao_rival"] = {"state": "active", "step": index, "since": int(game.world.day), "begun": true, "base": {}}

func _reload(game: Session) -> Session:
	var copy := Session.new()
	check(copy.restore(JSON.parse_string(JSON.stringify(game.snapshot()))), "the journey survives a save")
	return copy

## Two scrolls of thirty, a 榜亭 in each of the five cities, the prodigies and the rival's numbers.
func _data() -> void:
	var game := _game()
	var data: Dictionary = game.Tianji.data(game)
	check(data.scrolls.size() == 2 and int(data.scrolls.zhuji.size) == 30 and int(data.scrolls.jindan.realm) == 2, "筑基卷 and 金丹卷, thirty each")
	for location_id: String in ["market", "nanming", "beiyue", "canglan", "wanghai"]:
		check(game.content.locations[location_id].spots.any(func(spot: Dictionary) -> bool: return "tianji" in spot.actions), "%s has a 榜亭" % location_id)
	check(data.prodigies.size() == 10 and game.content.people.has("xiao_lingyun") and game.content.storylines.has("xiao_rival"), "ten 天骄, 萧凌云 and his story")
	check(game.content.items.has("jiedu_dan") and game.content.locations.changqing_valley.shop.any(func(good: Dictionary) -> bool: return good.item == "jiedu_dan"), "长青谷 sells the 解毒丹")

## The order of a revision: the prodigies at their seats, nameless ones filling the rest.
func _board() -> void:
	var game := _game()
	_year(game, 5)
	var rows: Array = game.Tianji.order(game, "zhuji")
	check(rows.size() == 30 and rows[0] == "wuming" and rows[1] == "bai_tinglan" and not rows.has("xiao_lingyun"), "year 5: 无名 heads the 筑基卷, 萧凌云 not yet on it")
	check(not rows.has("player") and game.Tianji.rank(game, "zhuji") == 0, "the player is not on it")
	var nameless: Dictionary = game.Tianji.entry(game, "zhuji", str(rows[29]))
	check(not str(nameless.name).is_empty() and game.content.sects.has(str(nameless.sect)), "a nameless cultivator has a name and a lineage")
	check(game.Tianji.entry(game, "zhuji", str(rows[29])).name == nameless.name, "and the same name when read again")
	_year(game, 20)
	rows = game.Tianji.order(game, "zhuji")
	check(rows[2] == "xiao_lingyun" and game.Tianji.period(game) == 20, "year 20: 萧凌云 third on the new 筑基卷")
	check(not game.Tianji.order(game, "jindan").has("wuming") and not game.Tianji.order(game, "jindan").has("xiao_lingyun"), "the 金丹卷 has its own, none of them yet")
	_year(game, 70)
	check(game.Tianji.order(game, "jindan")[0] == "wuming" and game.Tianji.order(game, "jindan")[1] == "xiao_lingyun", "year 70: 无名 and 萧凌云 head the 金丹卷")

## 战帖 up the board: unranked, only the last five; a win takes the seat, a loss changes nothing.
func _challenge() -> void:
	var game := _game()
	_year(game, 20)
	check(not game.Tianji.block(game).is_empty(), "炼气 has no scroll")
	_grow(game, 1, 2)
	check(game.Tianji.block(game).is_empty() and game.Tianji.reach(game, "zhuji") == [26, 30], "an unranked 筑基 may challenge 26–30")
	check(not game.Tianji.block(game, 20).is_empty(), "but not the twentieth")
	game.player.location = "ridge"
	check(not game.Tianji.block(game).is_empty(), "no 榜亭 on the ridge")
	game.player.location = "market"
	var beaten: String = game.Tianji.order(game, "zhuji")[25]
	var stones := int(game.player.stones)
	game.tianji_challenge(26)
	check(game.battle.get("context", "") == "tianji" and game.battle.tianji.target == beaten, "the duel begins at the 榜亭")
	check(int(game.battle.foe.realm) == 1 and is_equal_approx(float(game.battle.foe.power), 0.85), "against a 筑基 at the seat's strength")
	game.Combat._win(game)
	check(game.Tianji.rank(game, "zhuji") == 26 and game.Tianji.order(game, "zhuji")[26] == beaten, "the player takes the twenty-sixth seat, the beaten one moves down")
	check(int(game.player.stones) > stones and game.Tianji.best(game, "zhuji") == 26, "paid, and the best seat remembered")
	check(not game.Tianji.block(game, 21).is_empty(), "one 战帖 a month")
	game.player.tianji.next_challenge = 0
	check(game.Tianji.reach(game, "zhuji") == [21, 25], "now up to five places above")
	game.tianji_challenge(21)
	game.Combat._lose(game)
	check(game.Tianji.rank(game, "zhuji") == 26 and game.battle.is_empty(), "a loss changes nothing")
	game.player.tianji.next_challenge = 0
	game.tianji_challenge(22)
	game.Combat.flee(game)
	check(game.battle.is_empty() and game.Tianji.rank(game, "zhuji") == 26, "conceding is losing")

## Someone below comes for the seat: beaten, the player moves down one; refusing, they trade places.
func _defend() -> void:
	var game := _game()
	_year(game, 21)
	_grow(game, 1, 2)
	game.Tianji.place(game, "zhuji", 12)
	check(int(game.player.tianji.defend_day) > int(game.world.day), "a seat is left alone a while")
	game.Tianji.check(game)
	check(game.pending_event.is_empty(), "not yet")
	game.player.tianji.defend_day = int(game.world.day)
	game.Tianji.check(game)
	check(game.pending_event.get("id", "") == "tianji_challenged", "a challenger finds the player at the 榜亭's city")
	var challenger := str(game.pending_event.values.challenger)
	var theirs: int = game.Tianji.order(game, "zhuji").find(challenger) + 1
	check(theirs > 12 and theirs <= 17, "someone up to five below")
	game.choose_event("fight")
	check(game.battle.get("context", "") == "tianji" and game.battle.tianji.kind == "defend", "the defence is a duel")
	game.Combat._lose(game)
	check(game.Tianji.rank(game, "zhuji") == 13 and game.Tianji.order(game, "zhuji")[11] == challenger, "beaten: the challenger sits twelfth, the player thirteenth")
	check(int(game.player.tianji.defend_day) > int(game.world.day), "and is left alone again a while")
	game.player.tianji.defend_day = int(game.world.day)
	game.Tianji.check(game)
	challenger = str(game.pending_event.values.challenger)
	theirs = game.Tianji.order(game, "zhuji").find(challenger) + 1
	game.choose_event("refuse")
	check(game.Tianji.rank(game, "zhuji") == theirs and game.Tianji.order(game, "zhuji")[12] == challenger and game.battle.is_empty(), "refusing trades places with the challenger")
	game.player.tianji.defend_day = int(game.world.day)
	game.Tianji.check(game)
	game.choose_event("fight")
	var held := game.Tianji.rank(game, "zhuji")
	game.Combat._win(game)
	check(game.Tianji.rank(game, "zhuji") == held, "won, the seat is kept")

## The ten highest: the yearly gift and better prices; 批注 set the player higher, never lower.
func _rewards() -> void:
	var game := _game()
	_year(game, 21)
	_grow(game, 1, 1)
	var plain: int = game.shop_goods()[0].price
	game.Tianji.place(game, "zhuji", 5)
	check(game.Tianji.discount(game) < 1.0 and game.shop_goods()[0].price < plain, "the tenth and above buy cheaper")
	game.Tianji.pay_passive(game)
	var stones := int(game.player.stones)
	var pills: int = int(game.player.items.get("ningqi_pill_fine", 0))
	game.advance_days(Calendar.DAYS_PER_YEAR)
	check(int(game.player.stones) >= stones + 150 and int(game.player.items.get("ningqi_pill_fine", 0)) == pills + 2, "a year among the ten brings the 天机阁's gift")
	game.Tianji.annotate(game, "zhuji", 3, "试笔。")
	check(game.Tianji.rank(game, "zhuji") == 3 and game.player.tianji.notes.back().text == "试笔。", "a 批注 sets the player third")
	game.Tianji.annotate(game, "zhuji", 8, "再试。")
	check(game.Tianji.rank(game, "zhuji") == 3 and game.player.tianji.notes.size() == 2, "but never lower")
	game.Tianji.place(game, "zhuji", 25)
	check(game.Tianji.discount(game) == 1.0, "the twenty-fifth pays the full price")

## A revision keeps the player's seat on their realm's scroll; a 金丹 leaves the 筑基卷.
func _revision() -> void:
	var game := _game()
	_year(game, 19)
	_grow(game, 1, 2)
	game.Tianji.place(game, "zhuji", 7)
	_year(game, 20)
	check(game.Tianji.rank(game, "zhuji") == 7 and game.Tianji.period(game) == 20, "the new revision keeps the player seventh")
	check(game.Tianji.order(game, "zhuji").has("xiao_lingyun"), "the new 天骄 take their seats")
	_grow(game, 2, 0)
	_year(game, 30)
	check(game.Tianji.rank(game, "zhuji") == 0 and game.Tianji.best(game, "zhuji") == 7, "a 金丹 is off the 筑基卷 at the next revision, the best seat remembered")
	check(game.Tianji.own_scroll(game) == "jindan" and game.Tianji.rank(game, "jindan") == 0, "and starts the 金丹卷 unranked")

## 潜龙会: the last round against 萧凌云; a loss anywhere is his day.
func _qianlong() -> void:
	var game := _game()
	_year(game, 6)
	game.Storylines.update(game)
	check(game.Storylines.state(game, "xiao_rival") == "active" and game.Rival.at_step(game, "qianlong"), "the story begins in 云溪 at the 潜龙会 bout")
	check(game.Rival.qianlong_due(game), "the bout is due while he is of 炼气")
	game.begin_tournament(3)
	check(bool(game.battle.get("rival", false)) and str(game.battle.foe.name).contains("萧凌云"), "the third round is against him")
	game.Combat._win(game)
	check(game.has_flag("xiao_bout1") and game.has_flag("xiao_win1") and game.pending_event.get("id", "") == "xiao_after1", "won, and how to end it is asked")
	check(game.player.tianji.notes.size() == 1, "the 天机阁 writes it down")
	game.choose_event("spare")
	check(game.has_flag("xiao_spare1"), "spared")
	game.Storylines.update(game)
	check(game.Rival.at_step(game, "dabi") or game.Storylines.current_step(game, "xiao_rival").id == "dabi", "on to 天南大比")
	var lost := _game()
	_year(lost, 6)
	lost.Storylines.update(lost)
	lost.begin_tournament(1)
	lost.Combat._lose(lost)
	check(lost.has_flag("xiao_loss1") and not lost.has_flag("xiao_win1"), "out in the first round: 萧凌云 takes 潜龙会")
	var late := _game()
	_year(late, 16)
	late.Storylines.update(late)
	check(late.Storylines.current_step(late, "xiao_rival").get("id", "") == "dabi", "past his 炼气, the first bout is missed")

## 天南大比: the pill, the rigged draw, and the final against him.
func _dabi() -> void:
	var game := _game()
	_year(game, 20)
	_grow(game, 1, 2)
	game.world.flags["xiao_win1"] = true
	game.world.flags["xiao_bout1"] = true
	_story(game, "dabi")
	game.Rival.contest(game, "tiannan")
	check(game.pending_event.get("id", "") == "xiao_poison" and game.battle.is_empty(), "the pill comes the night before")
	var hp := int(game.player.hp)
	game.choose_event("swallow")
	check(int(game.player.hp) < hp and game.battle.get("context", "") == "summit", "swallowed: drained, and into the first round")
	var base: float = float(game.Summit.data(game, "tiannan").power[0])
	check(is_equal_approx(float(game.battle.foe.power), base + 0.05), "the draw is rigged")
	var rounds: int = game.Summit.data(game, "tiannan").champions.size()
	for round: int in rounds - 1:
		game.Combat._win(game)
	check(str(game.battle.foe.name).contains("萧凌云"), "the final is against him")
	game.Combat._win(game)
	check(game.has_flag("xiao_win2") and game.pending_event.get("id", "") == "xiao_after2", "won the final, and how to end it is asked")
	check(game.has_flag("xiao_face"), "two wins: 萧家's shop smiles")
	check(game.Tianji.rank(game, "zhuji") >= 1 and game.Tianji.rank(game, "zhuji") <= 3, "the player sits in his seat or the champion's")
	check(not game.choice_available(game.pending_definition().choices[0]), "the poison unfound, it cannot be exposed")
	game.choose_event("spare")
	check(game.has_flag("xiao_spare2"), "spared again")
	var found := _game()
	_year(found, 20)
	_grow(found, 1, 2)
	_story(found, "dabi")
	found.Rival.contest(found, "tiannan")
	found.player.items["jiedu_dan"] = 1
	check(found.choice_available(found.pending_definition().choices[2]), "a 解毒丹 lets the pill be passed by")
	found.world.flags["xiao_poison_found"] = true
	found.choose_event("antidote")
	check(is_equal_approx(float(found.battle.foe.power), float(found.Summit.data(found, "tiannan").power[0])), "the poison found out, the draw is fair again")
	found.Combat._lose(found)
	check(found.has_flag("xiao_loss2") and not found.has_flag("xiao_face"), "out early: 萧凌云 takes the contest")

## The 金丹卷: 萧家's 供奉 in the way, then the duel; or an ambush outside the city.
func _bang() -> void:
	var game := _game()
	_year(game, 80)
	_grow(game, 2, 1)
	_story(game, "bang")
	game.Tianji.place(game, "jindan", 4)
	check(game.Tianji.order(game, "jindan").find("xiao_lingyun") == 1, "萧凌云 sits second on the 金丹卷")
	game.tianji_challenge(2)
	check(game.pending_event.get("id", "") == "xiao_elder" and game.battle.is_empty(), "萧鹤年 stops the 战帖")
	check(not game.choice_available(game.pending_definition().choices[1]), "no way past him unheard of")
	game.choose_event("withdraw")
	game.player.tianji.next_challenge = 0
	game.tianji_challenge(2)
	game.choose_event("fight")
	check(game.battle.get("enemy_id", "") == "xiao_elder", "a fight with 萧鹤年")
	game.Combat._win(game)
	check(game.has_flag("xiao_elder_beaten"), "beaten off")
	game.player.tianji.next_challenge = 0
	game.tianji_challenge(2)
	check(game.battle.get("context", "") == "tianji" and game.battle.tianji.target == "xiao_lingyun", "nobody in the way now")
	game.Combat._win(game)
	check(game.has_flag("xiao_bout3") and game.has_flag("xiao_win3") and game.Tianji.rank(game, "jindan") == 2, "the seat taken")
	check(game.pending_event.get("id", "") == "xiao_after3", "and how to end it asked")
	game.choose_event("spare")
	check(game.has_flag("xiao_spare3"), "spared")
	var outside := _game()
	_year(outside, 80)
	_grow(outside, 2, 2)
	_story(outside, "bang")
	outside.world.rumors["xiao_elder"] = int(outside.world.day)
	outside.Tianji.place(outside, "jindan", 6)
	outside.tianji_challenge(2)
	check(outside.choice_available(outside.pending_definition().choices[1]), "heard of in a teahouse, he can be gone around")
	outside.choose_event("ambush")
	outside.Combat._win(outside)
	check(outside.has_flag("xiao_ambush") and not outside.Tianji.order(outside, "jindan").has("xiao_lingyun"), "ambushed, he is off the scroll")
	check(outside.Tianji.order(outside, "jindan").size() == 30 and outside.Rival.wins(outside) == 1, "a new name comes last; it counts as a win")
	outside.Storylines.update(outside)
	check(outside.Storylines.current_step(outside, "xiao_rival").get("id", "") == "house", "on to 萧家")

## 萧家: a friend for three spared wins, a fight and his fate, or bowing after nothing but losses.
func _house() -> void:
	var friend := _game()
	_year(friend, 160)
	_grow(friend, 3, 0)
	for flag: String in ["xiao_win1", "xiao_win2", "xiao_win3", "xiao_spare1", "xiao_spare2", "xiao_spare3"]:
		friend.world.flags[flag] = true
	_story(friend, "house")
	friend.world.storylines.xiao_rival.begun = false
	friend.Storylines.update(friend)
	check(friend.pending_event.get("id", "") == "xiao_house", "萧家's 帖子 comes at 云溪")
	check(friend.choice_available(friend.pending_definition().choices[0]), "three spared wins: he asks to talk")
	friend.choose_event("talk")
	check(friend.has_flag("xiao_friend") and friend.Storylines.state(friend, "xiao_rival") == "done", "friends, and the story ends")
	var fought := _game()
	_year(fought, 160)
	_grow(fought, 3, 1)
	fought.world.flags["xiao_win1"] = true
	fought.world.flags["xiao_loss2"] = true
	_story(fought, "house")
	fought.world.storylines.xiao_rival.begun = false
	fought.Storylines.update(fought)
	check(not fought.choice_available(fought.pending_definition().choices[0]) and not fought.choice_available(fought.pending_definition().choices[2]), "neither friend nor beaten")
	fought.choose_event("fight")
	check(fought.battle.get("enemy_id", "") == "xiao_house", "a fight at 萧家")
	fought.Combat._win(fought)
	check(fought.has_flag("xiao_house_won") and fought.pending_event.get("id", "") == "xiao_fate", "won; his fate is asked, not the 帖子 again")
	fought.choose_event("yield")
	check(fought.has_flag("xiao_yield") and fought.Storylines.state(fought, "xiao_rival") == "done", "he yields")
	fought.player.location = "market"
	check(is_equal_approx(fought.Tianji.discount(fought), 0.8), "萧家's 丹坊 sells at eight tenths")
	fought.player.location = "nanming"
	check(fought.Tianji.discount(fought) == 1.0, "only in 云溪")
	var beaten := _game()
	_year(beaten, 160)
	_grow(beaten, 3, 0)
	beaten.world.flags["xiao_loss1"] = true
	beaten.world.flags["xiao_loss2"] = true
	_story(beaten, "house")
	beaten.world.storylines.xiao_rival.begun = false
	beaten.Storylines.update(beaten)
	check(beaten.choice_available(beaten.pending_definition().choices[2]), "never a win: bowing is open")
	beaten.choose_event("avoid")
	check(beaten.has_flag("xiao_bounty"), "ignored, 萧家 posts a bounty")

## The scrolls and the player's notes survive a save; a malformed board is refused.
func _saves() -> void:
	var game := _game()
	_year(game, 21)
	_grow(game, 1, 2)
	game.Tianji.place(game, "zhuji", 9)
	game.Tianji.note(game, "存档。")
	var copy := _reload(game)
	check(copy.Tianji.rank(copy, "zhuji") == 9 and copy.Tianji.order(copy, "zhuji") == game.Tianji.order(game, "zhuji"), "the seat and the order survive")
	check(copy.player.tianji.notes.back().text == "存档。" and copy.Tianji.best(copy, "zhuji") == 9, "and the notes and best seat")
	var bad: Dictionary = JSON.parse_string(JSON.stringify(game.snapshot()))
	bad.world.tianji.zhuji.order = [1, 2]
	check(not Session.new().restore(bad), "a board of numbers is refused")
	var older: Dictionary = JSON.parse_string(JSON.stringify(game.snapshot()))
	older.world.erase("tianji")
	older.player.erase("tianji")
	var restored := Session.new()
	check(restored.restore(older) and restored.Tianji.rank(restored, "zhuji") == 0, "a journey from before the 天骄榜 starts off it")
