extends RefCounted
## 天机阁与天骄榜 (docs/SIDEQUESTS_DRAFT_20261020.md 三; 第五稿 3.1–3.2): 天机阁 takes no disciples; its 执笔
## post the 天骄榜 at every city's 榜亭 (a spot with the `tianji` action), one scroll (卷) for each realm it
## ranks: 筑基卷 and 金丹卷, thirty names each. Operates on a Session; the terms live in data/tianji.json.
## A scroll is revised (大修) every `revise_years`: the 天骄 of the player's generation (`prodigies`, each
## on a scroll from one year to another, at a seat) take their seats, nameless cultivators of the world
## stream fill the rest, and a player of the scroll's realm keeps their place. Between revisions the order
## changes by duels, by a prodigy gone from the world (`absent_if`) and by 批注 (effect `tianji`: a great
## deed sets the player at a rank and is written beside their name).
## A player of the scroll's realm sends a 战帖 at a 榜亭 to someone up to `reach` places above (unranked,
## to the last `reach`); a win takes that seat and everyone from it down moves one place, a loss changes
## nothing, and one 战帖 waits `cooldown_days` for the next. Holding a seat, someone below comes to
## challenge in turn every few years (`defend_years`, sooner the higher the seat), found at a city with a
## 榜亭: a loss gives them the seat (one place down), a refusal trades places with them. The ten highest
## of the scroll of the player's realm receive the 天机阁's gift each year and better prices at the shops
## (`discounts`); some deeds earn one place's favor (`favors`: 萧家's 丹坊 in 云溪).
## A prodigy may have a story in the way (`intercept`: an event before the duel while a story is at a
## step and its `unless` fails) and a story's stake in the duel (`bout`: effects for a win or a loss, an
## event after a win).
## Duels are 点到为止: battle.context "tianji", battle.tianji {"scroll", "target", "kind"}; the foe is built
## like 擂台大会's (summit.gd) at the strength of the seat fought for (`tiers`).
## world.tianji: {scroll: {"period", "order": [entry ids, best first]}}; an id is "player", a prodigy's,
## or "f<n>" for a nameless cultivator of that period. player.tianji: {"best": {scroll: rank}, "notes":
## [{"day", "text"}], "next_challenge", "defend_day", "gift_year"}.
const Calendar = preload("res://scripts/core/calendar.gd")
const Events = preload("res://scripts/core/events.gd")
const Population = preload("res://scripts/core/population.gd")
const Storylines = preload("res://scripts/core/storylines.gd")
const PLAYER := "player"
const MAX_NOTES := 12

static func data(s) -> Dictionary:
	return s.content.tianji_data

static func scroll(s, scroll_id: String) -> Dictionary:
	return data(s).scrolls.get(scroll_id, {})

static func state(s) -> Dictionary:
	return s.player.get("tianji", {})

static func _held(s) -> Dictionary:
	if not s.player.get("tianji") is Dictionary:
		s.player["tianji"] = {}
	return s.player.tianji

## The scroll of the player's realm, or "" (炼气, 元婴 and above have none).
static func own_scroll(s) -> String:
	for scroll_id: String in data(s).scrolls:
		if int(data(s).scrolls[scroll_id].realm) == int(s.player.realm):
			return scroll_id
	return ""

## The first year of the revision in force on `day` (today by default).
static func period(s, day: int = -1) -> int:
	var every := int(data(s).revise_years)
	return Calendar.year(int(s.world.day) if day < 0 else day) / every * every

static func next_revision(s) -> int:
	return period(s) + int(data(s).revise_years)

static func _absent(s, prodigy: Dictionary) -> bool:
	return not prodigy.get("absent_if", []).is_empty() and Events.all_met(s, prodigy.absent_if)

## Whether a prodigy sits on the scroll in the revision beginning `year`.
static func _seated(s, prodigy: Dictionary, scroll_id: String, year: int) -> bool:
	var span: Array = prodigy.get(scroll_id, [])
	return not span.is_empty() and maxi(year, 1) >= int(span[0]) and maxi(year, 1) < int(span[1]) and not _absent(s, prodigy)

## The scroll's order in the revision in force, revised once a new one has begun.
static func order(s, scroll_id: String) -> Array:
	if not s.world.get("tianji") is Dictionary:
		s.world["tianji"] = {}
	var now := period(s)
	var held: Dictionary = s.world.tianji.get(scroll_id, {})
	if held.is_empty() or int(held.get("period", -1)) != now:
		held = {"period": now, "order": _revise(s, scroll_id, now, held.get("order", []))}
		s.world.tianji[scroll_id] = held
	# A prodigy gone from the world leaves the seat at once; those below move up, a new name comes last.
	var kept: Array = held.order.filter(func(id: String) -> bool: return not data(s).prodigies.has(id) or not _absent(s, data(s).prodigies[id]))
	while kept.size() < held.order.size():
		kept.append(_new_name(kept))
	held.order = kept
	return held.order

static func _revise(s, scroll_id: String, year: int, old: Array) -> Array:
	var size := int(scroll(s, scroll_id).size)
	var seats: Array = []
	seats.resize(size)
	var prodigies: Array = data(s).prodigies.keys().filter(func(id: String) -> bool: return _seated(s, data(s).prodigies[id], scroll_id, year))
	prodigies.sort_custom(func(a: String, b: String) -> bool: return int(data(s).prodigies[a][scroll_id][2]) < int(data(s).prodigies[b][scroll_id][2]))
	for id: String in prodigies:
		var at := clampi(int(data(s).prodigies[id][scroll_id][2]) - 1, 0, size - 1)
		while at < size - 1 and seats[at] != null:
			at += 1
		if seats[at] == null:
			seats[at] = id
	var serial := 0
	for index: int in size:
		if seats[index] == null:
			seats[index] = "f%d" % serial
			serial += 1
	# The player keeps their place on the scroll of their realm.
	var at := old.find(PLAYER)
	if at >= 0 and int(s.player.realm) == int(scroll(s, scroll_id).realm):
		seats.insert(mini(at, size - 1), PLAYER)
		seats.resize(size)
	return seats

static func _new_name(taken: Array) -> String:
	var serial := 0
	while ("f%d" % serial) in taken:
		serial += 1
	return "f%d" % serial

## {"id", "name", "title", "sect", "gender", "power"} for an entry of the scroll; "player" and "prodigy"
## mark who they are.
static func entry(s, scroll_id: String, id: String) -> Dictionary:
	if id == PLAYER:
		var lineage := str(s.player.get("sect", "wanderer"))
		return {"id": id, "name": str(s.player.name), "title": str(s.content.sects.get(lineage, {}).get("name", "散修")), "sect": lineage, "gender": str(s.player.get("gender", "male")), "power": 0.0, "player": true}
	if data(s).prodigies.has(id):
		var prodigy: Dictionary = data(s).prodigies[id]
		return {"id": id, "name": str(prodigy.name), "title": str(prodigy.title), "sect": str(prodigy.sect), "gender": str(prodigy.gender), "power": float(prodigy.get("power", 0.0)), "prodigy": true}
	var rng := RandomNumberGenerator.new()
	rng.seed = hash([int(s.world.seed), scroll_id, period(s), id])
	var lineages: Array = data(s).filler.lineages
	var lineage: String = lineages[rng.randi_range(0, lineages.size() - 1)]
	var gender := "female" if rng.randf() < 0.4 else "male"
	var title: String = "散修" if lineage == "wanderer" else str(s.content.sects[lineage].name) + "弟子"
	return {"id": id, "name": Population._name(rng, s.content.population_data), "title": title, "sect": lineage, "gender": gender, "power": 0.0}

## The player's rank on the scroll (1 is the head), or 0 when not on it.
static func rank(s, scroll_id: String) -> int:
	return order(s, scroll_id).find(PLAYER) + 1

## The player's rank on the scroll of their realm, or 0.
static func own_rank(s) -> int:
	var scroll_id := own_scroll(s)
	return 0 if scroll_id.is_empty() else rank(s, scroll_id)

static func best(s, scroll_id: String) -> int:
	return int(state(s).get("best", {}).get(scroll_id, 0))

## The ranks the player may send a 战帖 to on the scroll: [highest, lowest], or [] for none.
static func reach(s, scroll_id: String) -> Array:
	var size := order(s, scroll_id).size()
	var mine := rank(s, scroll_id)
	var far := int(data(s).reach)
	if mine == 0:
		return [maxi(1, size - far + 1), size]
	if mine == 1:
		return []
	return [maxi(1, mine - far), mine - 1]

## The strength of a seat: [stage, power].
static func tier(s, seat: int) -> Array:
	for step: Array in data(s).tiers:
		if seat <= int(step[0]):
			return [int(step[1]), float(step[2])]
	var last: Array = data(s).tiers.back()
	return [int(last[1]), float(last[2])]

## How long a seat is left alone before someone below comes for it.
static func defend_days(s, seat: int) -> int:
	for step: Array in data(s).defend_years:
		if seat <= int(step[0]):
			return int(step[1]) * Calendar.DAYS_PER_YEAR
	return int(data(s).defend_years.back()[1]) * Calendar.DAYS_PER_YEAR

## Why the player cannot send a 战帖 (to the one at `target_rank`, when given) now, or "".
static func block(s, target_rank: int = 0) -> String:
	var reason: String = s.blocked()
	if not reason.is_empty():
		return reason
	if not s.available_here("tianji"):
		return "此地没有天机阁的榜亭。"
	var scroll_id := own_scroll(s)
	if scroll_id.is_empty():
		return "天骄榜只录筑基、金丹两境的修士。"
	var wait := int(state(s).get("next_challenge", 0)) - int(s.world.day)
	if wait > 0:
		return "上一封战帖的事才了，%s后再递。" % Calendar.duration_text(wait)
	if target_rank > 0:
		var span := reach(s, scroll_id)
		if span.is_empty():
			return "你已是榜首。"
		if target_rank < int(span[0]) or target_rank > int(span[1]):
			return "未上榜的，只能挑榜尾 %d 人。" % int(data(s).reach) if rank(s, scroll_id) == 0 else "战帖只能递给比你高 %d 名以内的人。" % int(data(s).reach)
	return ""

## Sends a 战帖 to the one at `target_rank` on the scroll of the player's realm; the duel is fought at once
## at this 榜亭, unless a story stands in the way first.
static func challenge(s, target_rank: int) -> String:
	var reason := block(s, target_rank)
	if not reason.is_empty():
		return reason
	var scroll_id := own_scroll(s)
	var target: String = order(s, scroll_id)[target_rank - 1]
	_held(s).next_challenge = int(s.world.day) + int(data(s).cooldown_days)
	var args := {"scroll": str(scroll(s, scroll_id).name), "rank": target_rank, "foe": str(entry(s, scroll_id, target).name), "location": str(s.player.location)}
	var stop: Dictionary = data(s).prodigies.get(target, {}).get("intercept", {})
	if not stop.is_empty() and _story_at(s, stop.story) and not Events.all_met(s, stop.get("unless", [])):
		s.pending_event = {"id": str(stop.event), "day": int(s.world.day), "values": {"place": str(s.content.locations[s.player.location].name), "foe": args.foe}}
		return s.finish(s.log_event("tianji_start", args))
	begin(s, scroll_id, target, "challenge")
	s.changed.emit()
	return s.log_event("tianji_start", args)

## A 战帖 sent past whatever stood in the way (story effect `tianji_duel`): the duel begins at once.
static func duel(s, target: String) -> void:
	var scroll_id := own_scroll(s)
	if scroll_id.is_empty() or not order(s, scroll_id).has(target):
		return
	begin(s, scroll_id, target, "challenge")

static func _story_at(s, at: Array) -> bool:
	return str(Storylines.current_step(s, str(at[0])).get("id", "")) == str(at[1])

## Begins a duel with `target` on the scroll: a "challenge" for their seat or a "defend" of the player's.
static func begin(s, scroll_id: String, target: String, kind: String) -> void:
	var seat := order(s, scroll_id).find(target) + 1 if kind == "challenge" else rank(s, scroll_id)
	var info := entry(s, scroll_id, target)
	var strength := tier(s, maxi(seat, 1))
	var foe: Dictionary = s.Summit.foe(s, "%s · %s" % [info.title, info.name], str(info.sect), str(info.gender), int(scroll(s, scroll_id).realm), int(strength[0]), float(strength[1]) + float(info.power), int(scroll(s, scroll_id).win.xp))
	s.battle = {"enemy_id": "cultivator", "hp": int(foe.hp), "turn": 1, "cooldowns": {}, "opponent_sect": "qingyun" if info.sect == "wanderer" else str(info.sect), "status": {}, "context": "tianji", "tianji": {"scroll": scroll_id, "target": target, "kind": kind}, "foe": foe, "place": s.Combat._battle_place(s)}
	s.combat_events.clear()
	s.Combat.open_hand(s)

## A duel ends: a seat changes hands or stays, the prodigy's story takes its share.
static func over(s, won: bool) -> String:
	var bout: Dictionary = s.battle.tianji
	var scroll_id := str(bout.scroll)
	var target := str(bout.target)
	var kind := str(bout.kind)
	var info := entry(s, scroll_id, target)
	var terms: Dictionary = scroll(s, scroll_id).win
	var args := {"scroll": str(scroll(s, scroll_id).name), "foe": str(info.name)}
	s.battle.clear()
	s.record_deed("duel")
	s.player.hp = maxi(int(s.player.hp), 1)
	var message := ""
	if kind == "challenge":
		# The seat fought for (one gone from the scroll meanwhile leaves the player where they were).
		var seat := order(s, scroll_id).find(target) + 1
		if won and seat >= 1:
			place(s, scroll_id, seat)
			s.player.stones = int(s.player.stones) + int(terms.stones)
			message = _join(s.log_event("tianji_rise", args.merged({"rank": seat, "stones": int(terms.stones)}), seat <= 10), s.gain_xp(int(terms.xp)))
		else:
			message = s.log_event("tianji_fail", args)
		# A prodigy's story may ride on the duel (`bout`).
		var stake: Dictionary = data(s).prodigies.get(target, {}).get("bout", {})
		if not stake.is_empty() and _story_at(s, stake.story):
			Events.apply(s, stake.get("won" if won else "lost", []))
			if won and stake.has("won_event"):
				s.pending_event = {"id": str(stake.won_event), "day": int(s.world.day)}
	else:
		if won:
			message = _join(s.log_event("tianji_held", args.merged({"rank": rank(s, scroll_id)})), s.gain_xp(int(terms.xp) / 2))
		else:
			_give_way(s, scroll_id, target, false)
			message = s.log_event("tianji_lost", args.merged({"rank": rank(s, scroll_id)}))
		_held(s).defend_day = int(s.world.day) + defend_days(s, maxi(rank(s, scroll_id), 1))
	message = _join(message, s.gain_insight("spar"))
	return s.conclude(message, s.advance_days(s.content.action_days("road_recovery")))

## Sets the player at `seat` on the scroll; everyone from it down moves one place, the last falls off.
static func place(s, scroll_id: String, seat: int) -> void:
	var rows := order(s, scroll_id)
	var size := int(scroll(s, scroll_id).size)
	rows.erase(PLAYER)
	rows.insert(clampi(seat - 1, 0, rows.size()), PLAYER)
	rows.resize(size)
	var held := _held(s)
	if not held.get("best") is Dictionary:
		held["best"] = {}
	if best(s, scroll_id) == 0 or seat < best(s, scroll_id):
		held.best[scroll_id] = seat
	if not held.has("defend_day") or int(held.defend_day) <= int(s.world.day):
		held.defend_day = int(s.world.day) + defend_days(s, seat)

## A 批注 (effect `tianji`): a deed the 天机阁 writes beside the player's name, setting them at `seat` on
## the scroll when that is higher than where they stand (and they are of its realm).
static func annotate(s, scroll_id: String, seat: int, text: String) -> String:
	if int(s.player.realm) == int(scroll(s, scroll_id).realm) and (rank(s, scroll_id) == 0 or rank(s, scroll_id) > seat):
		place(s, scroll_id, seat)
	return note(s, text)

## Writes a note beside the player's name; returns its chronicle text.
static func note(s, text: String) -> String:
	var held := _held(s)
	if not held.get("notes") is Array:
		held["notes"] = []
	held.notes.append({"day": int(s.world.day), "text": text})
	while held.notes.size() > MAX_NOTES:
		held.notes.pop_front()
	return s.log_event("tianji_note", {"text": text}, true)

## A prodigy moves one place up (a bout the player lost to them in a great contest).
static func promote(s, scroll_id: String, id: String) -> void:
	var rows := order(s, scroll_id)
	var at := rows.find(id)
	if at > 0:
		rows[at] = rows[at - 1]
		rows[at - 1] = id

## The player takes a prodigy's seat (a bout won in a great contest): placed at it if higher.
static func overtake(s, scroll_id: String, id: String) -> void:
	var at := order(s, scroll_id).find(id)
	if at >= 0 and int(s.player.realm) == int(scroll(s, scroll_id).realm) and (rank(s, scroll_id) == 0 or rank(s, scroll_id) > at + 1):
		place(s, scroll_id, at + 1)

## A challenger takes the player's seat: beaten, the player moves one place down; refusing, they trade.
static func _give_way(s, scroll_id: String, challenger: String, refused: bool) -> void:
	var rows := order(s, scroll_id)
	var mine := rows.find(PLAYER)
	var theirs := rows.find(challenger)
	if refused:
		rows[mine] = challenger
		if theirs >= 0:
			rows[theirs] = PLAYER
		return
	if theirs >= 0:
		rows.remove_at(theirs)
	rows.insert(mine, challenger)
	rows.resize(int(scroll(s, scroll_id).size))

## Stopping at a city with a 榜亭 while a seat is due to be challenged: the challenger is there.
static func check(s) -> void:
	if not s.pending_event.is_empty() or not s.battle.is_empty() or not s.ended.is_empty() or not s.available_here("tianji"):
		return
	var scroll_id := own_scroll(s)
	var mine := 0 if scroll_id.is_empty() else rank(s, scroll_id)
	if mine == 0 or int(s.world.day) < int(state(s).get("defend_day", 0)):
		return
	var rows := order(s, scroll_id)
	var below: int = mine - 1 + s.world_rng.randi_range(1, int(data(s).reach))
	var challenger: String = rows[below] if below < rows.size() else _new_name(rows)
	var info := entry(s, scroll_id, challenger)
	s.pending_event = {"id": "tianji_challenged", "day": int(s.world.day), "values": {"foe": str(info.name), "foe_title": str(info.title), "scroll": str(scroll(s, scroll_id).name), "rank": str(mine), "challenger": challenger, "scroll_id": scroll_id}}

## The answer to a challenge (effect `tianji_defend`): "fight" or "refuse".
static func defend(s, how: String) -> String:
	var values: Dictionary = s.pending_event.get("values", {})
	var scroll_id := str(values.get("scroll_id", ""))
	var challenger := str(values.get("challenger", ""))
	if scroll_id.is_empty() or rank(s, scroll_id) == 0:
		return ""
	if how == "fight":
		begin(s, scroll_id, challenger, "defend")
		return ""
	_give_way(s, scroll_id, challenger, true)
	_held(s).defend_day = int(s.world.day) + defend_days(s, maxi(rank(s, scroll_id), 1))
	return s.log_event("tianji_refused", {"scroll": str(scroll(s, scroll_id).name), "foe": str(entry(s, scroll_id, challenger).name), "rank": rank(s, scroll_id)})

## The 天机阁's yearly gift to the ten highest of the scroll of the player's realm (session.gd, after time
## passes): one for each new year spent among them, up to a revision's worth.
static func pay_passive(s) -> String:
	var year := Calendar.year(int(s.world.day))
	var scroll_id := own_scroll(s)
	var mine := 0 if scroll_id.is_empty() else rank(s, scroll_id)
	if mine == 0 and state(s).is_empty():
		return ""
	var held := _held(s)
	var last := int(held.get("gift_year", year))
	held.gift_year = year
	if mine == 0 or mine > 10 or year <= last:
		return ""
	var gift: Dictionary = scroll(s, scroll_id).gift
	var years := mini(year - last, int(data(s).revise_years))
	var stones := int(gift.stones) * years
	s.player.stones = int(s.player.stones) + stones
	var got: Array[String] = []
	for item_id: String in gift.get("items", {}):
		s.add_item(item_id, int(gift.items[item_id]) * years)
		got.append("%s × %d" % [s.content.item(item_id).name, int(gift.items[item_id]) * years])
	return s.log_event("tianji_gift", {"scroll": str(scroll(s, scroll_id).name), "stones": stones, "more": "" if got.is_empty() else "、" + "、".join(got)})

## The price factor at this place's shop: the seat's discount or a place's favor, whichever is better.
static func discount(s) -> float:
	var rate := 1.0
	var mine := own_rank(s)
	if mine > 0:
		for pair: Array in data(s).discounts:
			if mine <= int(pair[0]):
				rate = minf(rate, float(pair[1]))
	for favor: Dictionary in data(s).get("favors", []):
		if str(favor.location) == str(s.player.location) and s.has_flag(str(favor.flag)):
			rate = minf(rate, float(favor.rate))
	return rate

static func _join(message: String, more: Array[String]) -> String:
	return message if more.is_empty() else message + " " + " ".join(more)
