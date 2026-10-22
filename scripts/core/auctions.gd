extends RefCounted
## 拍卖: lots sold one after another to the highest bidder, after 觅长生's auction houses. Operates on a
## Session. Definitions live in data/auctions.json; an event's effect {"auction": id} opens one.
## - The lots are drawn from the auction's pool by the world seed and the year (a lot marked `last`
##   always closes the sale); slips and equipment are made when it opens. Named generated cultivators of the region sit in as bidders.
## - Each bidder's ceiling for a lot follows from the lot's value, their cultivation (wealth), their
##   personality (temper) and a spread fixed by the world seed, so reloading changes nothing.
## - A lot opens at its starting price; the keenest bidder who will pay it opens the bidding. The player
##   raises by steps; whenever a bidder still under their ceiling is outbid, the keenest of them answers
##   one step higher. When nobody answers the player, the lot is theirs; when the player passes, the
##   bidders settle it among themselves (the keenest pays a step over the runner-up's ceiling).
## - Lots the player does not win are told in the chronicle: who took them, and for how much.
## State while it runs: s.auction = {"id", "lots": [{"item", "count", "start", "step", "value"}],
## "index", "price", "leader" ("" | "player" | a person), "bidders": [ids]}.

static func data(s) -> Dictionary:
	return s.content.auction_data

static func definition(s, auction_id: String) -> Dictionary:
	return data(s).auctions.get(auction_id, {})

## Opens an auction: its lots and bidders for this world and year, then the first lot.
static func open(s, auction_id: String) -> String:
	var auction := definition(s, auction_id)
	var year := int(s.world.day) / 360
	# A lot marked `last` is the 压轴: always sold, after the others drawn.
	# A lot offered only while its conditions hold (`if`: the 残玉 at 云溪's autumn sale).
	var offered: Array = auction.pool.filter(func(entry: Dictionary) -> bool: return s.Events.all_met(s, entry.get("if", [])))
	var pool: Array = offered.filter(func(entry: Dictionary) -> bool: return not bool(entry.get("last", false)))
	var closing: Array = offered.filter(func(entry: Dictionary) -> bool: return bool(entry.get("last", false)))
	pool.sort_custom(func(a: Dictionary, b: Dictionary) -> bool: return _roll(s, "%s:%d:lot:%s" % [auction_id, year, JSON.stringify(a)]) < _roll(s, "%s:%d:lot:%s" % [auction_id, year, JSON.stringify(b)]))
	var lots: Array = []
	for entry: Dictionary in pool.slice(0, maxi(0, int(auction.lots) - closing.size())) + closing:
		var item := ""
		if entry.has("manual"):
			item = "j:" + s.Arsenal.generate_technique(s.content, s.world_rng, int(entry.manual))
		elif entry.has("equipment"):
			item = s.Arsenal.generate_equipment(s.content, s.world_rng, int(entry.equipment))
		else:
			item = str(entry.item)
		lots.append({"item": item, "count": int(entry.get("count", 1)), "start": int(entry.start), "step": int(entry.step), "value": int(entry.value)})
	s.auction = {"id": auction_id, "lots": lots, "index": 0, "price": 0, "leader": "", "bidders": _bidders(s, auction_id, year, int(auction.bidders))}
	var text: String = s.log_event("auction_open", {"auction": auction_id, "amount": lots.size()})
	_open_lot(s)
	return text

## Named generated people of the region, those the player knows first, then others by the seed.
static func _bidders(s, auction_id: String, year: int, count: int) -> Array:
	var known: Array = []
	var others: Array = []
	var here: String = s.content.region_of(s.player.location)
	for person_id: String in s.living_people():
		if not s.is_generated(person_id) or str(s.life_by_id(person_id).get("region", "")) != here:
			continue
		if bool(s.world.people.get(person_id, {}).get("met", false)):
			known.append(person_id)
		else:
			others.append(person_id)
	var by_roll := func(a: String, b: String) -> bool: return _roll(s, "%s:%d:seat:%s" % [auction_id, year, a]) < _roll(s, "%s:%d:seat:%s" % [auction_id, year, b])
	known.sort_custom(by_roll)
	others.sort_custom(by_roll)
	var chosen: Array = known.slice(0, mini(2, count))
	chosen.append_array(others.slice(0, count - chosen.size()))
	return chosen

## A number in [0, 1) fixed by the world seed and `key`.
static func _roll(s, key: String) -> float:
	return s.seeded_roll(["auction", key])

## The most a bidder will pay for the current lot.
static func ceiling(s, person_id: String, lot: Dictionary) -> int:
	var someone: Dictionary = s.person(person_id)
	var wealth: Array = data(s).wealth
	var realm := clampi(int(someone.get("realm", 0)), 0, wealth.size() - 1)
	var rich := float(wealth[realm][clampi(int(someone.get("stage", 0)), 0, wealth[realm].size() - 1)])
	var temper := float(data(s).temper.get(str(someone.get("personality", "")), 1.0))
	var spread: Array = data(s).spread
	var luck := lerpf(float(spread[0]), float(spread[1]), _roll(s, "%s:%d:want:%s:%s" % [s.auction.id, int(s.auction.index), person_id, lot.item]))
	return int(round(float(lot.value) * rich * temper * luck))

static func lot(s) -> Dictionary:
	return s.auction.lots[int(s.auction.index)]

## The bidders other than `leader` who would pay `price`, keenest first.
static func _keen(s, price: int, leader: String) -> Array:
	var current := lot(s)
	var keen: Array = s.auction.bidders.filter(func(person_id: String) -> bool: return person_id != leader and ceiling(s, person_id, current) >= price)
	keen.sort_custom(func(a: String, b: String) -> bool: return ceiling(s, a, current) > ceiling(s, b, current))
	return keen

static func _open_lot(s) -> void:
	var current := lot(s)
	s.auction.price = int(current.start)
	s.auction.leader = ""
	var keen := _keen(s, int(current.start), "")
	if not keen.is_empty():
		s.auction.leader = keen[0]

## What the player would bid with `steps` more: the opening price if nobody has bid, else above it.
static func next_bid(s, steps: int = 1) -> int:
	if str(s.auction.leader).is_empty():
		return int(s.auction.price) + int(lot(s).step) * (steps - 1)
	return int(s.auction.price) + int(lot(s).step) * steps

## Why the player cannot bid `steps` now, or "".
static func bid_block(s, steps: int = 1) -> String:
	if s.auction.is_empty():
		return "没有在拍卖。"
	if str(s.auction.leader) == "player":
		return "你的出价最高，等对手应价。"
	if int(s.player.stones) < next_bid(s, steps):
		return "灵石不足：要出 %d 灵石。" % next_bid(s, steps)
	return ""

## The player raises; the keenest bidder still under their ceiling answers a step higher, or the lot is
## the player's.
static func bid(s, steps: int = 1) -> String:
	var reason := bid_block(s, steps)
	if not reason.is_empty():
		return reason
	s.auction.price = next_bid(s, steps)
	s.auction.leader = "player"
	var current := lot(s)
	var answer := int(s.auction.price) + int(current.step)
	var keen := _keen(s, answer, "player")
	if keen.is_empty():
		return _sold(s)
	s.auction.price = answer
	s.auction.leader = keen[0]
	s.changed.emit()
	return "%s应价 %d 灵石。" % [s.person(keen[0]).name, answer]

## The player lets this lot go: the bidders settle it among themselves.
static func pass_lot(s) -> String:
	if s.auction.is_empty():
		return "没有在拍卖。"
	if str(s.auction.leader) == "player":
		return "你的出价最高，不能放弃。"
	return _settle(s)

static func _settle(s) -> String:
	var current := lot(s)
	var keen := _keen(s, int(current.start), "")
	if keen.is_empty():
		var unsold: String = s.log_event("auction_unsold", {"auction": s.auction.id, "loot": "%s:%d" % [current.item, int(current.count)]})
		return _next(s, unsold)
	var price := int(s.auction.price)
	if keen.size() > 1:
		price = maxi(price, mini(ceiling(s, keen[0], current), ceiling(s, keen[1], current) + int(current.step)))
	var lost: String = s.log_event("auction_lost", {"auction": s.auction.id, "loot": "%s:%d" % [current.item, int(current.count)], "npc": keen[0], "stones": price})
	return _next(s, lost)

## The lot goes to the player at the price.
static func _sold(s) -> String:
	var current := lot(s)
	s.player.stones = int(s.player.stones) - int(s.auction.price)
	s.add_item(str(current.item), int(current.count))
	var won: String = s.log_event("auction_won", {"auction": s.auction.id, "loot": "%s:%d" % [current.item, int(current.count)], "stones": int(s.auction.price)})
	return _next(s, won)

## On to the next lot, or the end of the auction.
static func _next(s, text: String) -> String:
	s.auction.index = int(s.auction.index) + 1
	if int(s.auction.index) >= s.auction.lots.size():
		var auction_id: String = s.auction.id
		s.auction = {}
		return s.finish(text + " " + s.log_event("auction_close", {"auction": auction_id}))
	_open_lot(s)
	s.changed.emit()
	return text

## Leaves before the end: the remaining lots are settled without the player.
static func leave(s) -> String:
	if s.auction.is_empty():
		return "没有在拍卖。"
	if str(s.auction.leader) == "player":
		return "你的出价最高，等这一件落槌再走。"
	var texts: Array[String] = []
	while not s.auction.is_empty():
		texts.append(_settle(s))
	return " ".join(texts)
