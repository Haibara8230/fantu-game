extends RefCounted
## Rumors. Operates on a Session.
## Inquiring at a teahouse, dock or street costs a day and a little money and yields one piece of news
## drawn from the actual state of the world. world.rumors remembers when each was heard, so the same
## news is not repeated for a while.
const Calendar = preload("res://scripts/core/calendar.gd")
const Events = preload("res://scripts/core/events.gd")

## Everything worth hearing right now: [{"key", "id", "args"}], sorted by key.
static func candidates(s) -> Array[Dictionary]:
	var found: Array[Dictionary] = []
	var day := int(s.world.day)
	# The autumn auction at 云溪, in the two months before it opens.
	var autumn: Dictionary = Events.next_window(s.content.events.yunxi_autumn, day)
	if not autumn.is_empty() and int(autumn.from) - day <= 2 * Calendar.DAYS_PER_MONTH:
		found.append({"key": "auction:%d" % int(autumn.occurrence), "id": "rumor_auction", "args": {}})
	if not s.has_flag("found_ruin"):
		found.append({"key": "ruin", "id": "rumor_ruin", "args": {}})
	if s.has_flag("serpent_rampage"):
		found.append({"key": "sealed", "id": "rumor_sealed", "args": {}})
	elif not s.has_flag("serpent_slain") and day < Calendar.to_day(12, 3, 1):
		found.append({"key": "serpent", "id": "rumor_serpent", "args": {}})
	var tournament: Dictionary = Events.next_window(s.content.events.qianlong_entry, day)
	if not tournament.is_empty() and int(tournament.from) - day <= 2 * Calendar.DAYS_PER_YEAR:
		found.append({"key": "tournament:%d" % int(tournament.occurrence), "id": "rumor_tournament", "args": {}})
	for good: Dictionary in s.rotating_stock("market"):
		if str(good.item).begins_with("j:"):
			found.append({"key": "stock:" + str(good.key), "id": "rumor_stock", "args": {"item": good.item}})
	for board: String in s.content.commission_data.boards:
		if not s.commission_offers(board).is_empty():
			found.append({"key": "commission:%s:%d" % [board, day / int(s.content.commission_data.period_days)], "id": "rumor_commission", "args": {"board": board}})
	for person_id: String in s.living_people():
		var where: String = s.npc_location(person_id)
		if where.is_empty() or bool(s.world.people.get(person_id, {}).get("met", false)) or not s.location_visible(where):
			continue
		found.append({"key": "person:%s:%s" % [person_id, where], "id": "rumor_person", "args": {"npc": person_id, "title": s.person(person_id).title, "location": where}})
	var recent := int(s.content.rules.inquire.repeat_after_days)
	# Word of the wider world (data/lore.json): the other sects, the 化神 of distant lands. One piece at a
	# time, in order, so news of the player's own surroundings is not crowded out; only lore the player's
	# standing lets them make sense of is heard, and none of it gives away a storyline.
	for lore: Dictionary in s.content.lore_data.rumors:
		var key := "lore:" + str(lore.id)
		if day - int(s.world.rumors.get(key, -recent)) >= recent and Events.all_met(s, lore.get("conditions", [])):
			found.append({"key": key, "id": "rumor_lore", "args": {"lore": lore.id}})
			break
	found = found.filter(func(rumor: Dictionary) -> bool: return day - int(s.world.rumors.get(rumor.key, -recent)) >= recent)
	found.sort_custom(func(a: Dictionary, b: Dictionary) -> bool: return a.key < b.key)
	return found

static func inquire(s) -> String:
	var blocked: String = s.blocked()
	if not blocked.is_empty():
		return blocked
	if not s.available_here("inquire"):
		return "此地无处打听消息。"
	var price := int(s.content.rules.inquire.price)
	if int(s.player.stones) < price:
		return "囊中羞涩，连一壶茶钱也拿不出。"
	s.player.stones -= price
	var passed: Dictionary = s.advance_days(int(s.content.rules.inquire.days))
	if not s.ended.is_empty():
		return s.conclude("", passed)
	var heard := candidates(s)
	if heard.is_empty():
		return s.conclude(s.log_event("rumor_none"), passed)
	var rumor: Dictionary = heard[s.world_rng.randi_range(0, heard.size() - 1)]
	s.world.rumors[rumor.key] = int(s.world.day)
	return s.conclude(s.log_event(rumor.id, rumor.args), passed)
