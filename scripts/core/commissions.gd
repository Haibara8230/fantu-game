extends RefCounted
## Commission boards. Operates on a Session.
## Boards post a few offers per period (deterministic per world, board and period). Accepted ones live
## in player.quests with a deadline; world.quests_taken keeps an offer from being posted twice.
## Three kinds: deliver items, hunt beasts, and (on the sect's board) patrol a place and report back.
## The sect's own board (data/sect.json `board`) also pays contribution (`contribution` per count).

static func board_here(s) -> String:
	if not s.available_here("commissions"):
		return ""
	for board: String in s.content.commission_data.boards:
		if s.content.commission_data.boards[board].location == s.player.location:
			return board
	return ""

static func offers(s, board: String) -> Array[Dictionary]:
	var result: Array[Dictionary] = []
	var data: Dictionary = s.content.commission_data
	var period := int(s.world.day) / int(data.period_days)
	var rng := RandomNumberGenerator.new()
	rng.seed = hash([int(s.world.get("seed", 0)), "commission", board, period])
	var kinds: Array = data.templates.keys().filter(func(kind: String) -> bool: return board in data.templates[kind].boards)
	kinds.sort()
	var total := 0
	for kind: String in kinds:
		total += int(data.templates[kind].weight)
	for index: int in int(data.offers):
		var roll := rng.randi_range(1, total)
		var kind: String = kinds[0]
		for candidate: String in kinds:
			roll -= int(data.templates[candidate].weight)
			if roll <= 0:
				kind = candidate
				break
		var template: Dictionary = data.templates[kind]
		var offer := {"key": "%s:%d:%d" % [board, period, index], "kind": kind, "board": board, "count": rng.randi_range(int(template.count[0]), int(template.count[1])), "days": int(template.days)}
		if template.has("items"):
			offer.item = template.items[rng.randi_range(0, template.items.size() - 1)]
			offer.reward = {"stones": int(round(float(s.content.item(offer.item).price) * float(offer.count) * float(template.reward_scale))), "xp": 0}
		elif template.has("places"):
			offer.place = template.places[rng.randi_range(0, template.places.size() - 1)]
			offer.reward = {"stones": int(template.reward_stones), "xp": int(template.reward_xp)}
		else:
			offer.enemy = template.enemies[rng.randi_range(0, template.enemies.size() - 1)]
			offer.reward = {"stones": int(template.reward_stones) * int(offer.count), "xp": int(template.reward_xp) * int(offer.count)}
		offer.reward.contribution = int(template.get("contribution", 0)) * int(offer.count) if board == str(s.content.sect_data.get("board", "")) else 0
		if not s.world.quests_taken.has(offer.key):
			result.append(offer)
	return result

## Title and description of an offer or an accepted commission.
static func text(s, quest: Dictionary) -> Dictionary:
	var template: Dictionary = s.content.commission_data.templates[quest.kind]
	var values := {"count": quest.count, "days": quest.days, "board_name": s.content.commission_data.boards[quest.board].name}
	if quest.has("item"):
		values.item_name = s.content.item(quest.item).name
	if quest.has("enemy"):
		values.enemy_name = s.content.enemies[quest.enemy].name
	if quest.has("place"):
		values.place_name = s.content.locations[quest.place].name
	return {"title": str(template.title).format(values), "text": str(template.text).format(values)}

static func accept(s, key: String) -> String:
	var blocked: String = s.blocked()
	if not blocked.is_empty():
		return blocked
	var board := board_here(s)
	if board.is_empty():
		return "此地没有委托告示。"
	if s.player.quests.size() >= int(s.content.commission_data.max_active):
		return "手头的委托已经够多了。"
	for offer: Dictionary in offers(s, board):
		if offer.key == key:
			var quest := offer.duplicate(true)
			quest.deadline = int(s.world.day) + int(offer.days)
			quest.progress = 0
			s.player.quests.append(quest)
			s.world.quests_taken[key] = true
			return s.conclude(s.log_event("quest_accept", {"quest_title": text(s, quest).title}))
	return "这张委托已经不在了。"

## Why a commission cannot be handed in here and now, or "".
static func delivery_block(s, quest: Dictionary) -> String:
	var blocked: String = s.blocked()
	if not blocked.is_empty():
		return blocked
	if board_here(s) != quest.board:
		return "须回%s交付。" % s.content.commission_data.boards[quest.board].name
	if quest.has("item") and s.pill_count(quest.item) < int(quest.count):
		return "%s还不够 %d。" % [s.content.item(quest.item).name, int(quest.count)]
	if quest.has("enemy") and int(quest.progress) < int(quest.count):
		return "还差 %d 头。" % (int(quest.count) - int(quest.progress))
	if quest.has("place") and int(quest.progress) < 1:
		return "还未去过%s。" % s.content.locations[quest.place].name
	return ""

static func deliver(s, key: String) -> String:
	for quest: Dictionary in s.player.quests:
		if quest.key != key:
			continue
		var reason := delivery_block(s, quest)
		if not reason.is_empty():
			return reason
		if quest.has("item"):
			s.Inventory.remove_family(s, quest.item, int(quest.count))
		s.player.quests.erase(quest)
		s.player.stones += int(quest.reward.stones)
		s.record_deed("commission")
		var done: String = s.log_event("quest_done", {"quest_title": text(s, quest).title, "stones": int(quest.reward.stones), "xp": int(quest.reward.xp)})
		var merit := int(quest.reward.get("contribution", 0))
		if merit > 0:
			done += " " + s.Sect.gain(s, merit, "宗门差事办妥")
		var milestones: Array[String] = s.gain_insight("commission")
		milestones.append_array(s.gain_xp(int(quest.reward.xp)))
		if not milestones.is_empty():
			done += " " + " ".join(milestones)
		return s.conclude(done)
	return "没有这件委托。"

## Counts a defeated enemy toward hunting commissions.
static func record_kill(s, enemy_id: String) -> void:
	for quest: Dictionary in s.player.get("quests", []):
		if quest.get("enemy", "") == enemy_id and int(quest.progress) < int(quest.count):
			quest.progress = int(quest.progress) + 1

## Counts a visit toward patrol commissions.
static func record_visit(s, location_id: String) -> void:
	for quest: Dictionary in s.player.get("quests", []):
		if quest.get("place", "") == location_id:
			quest.progress = 1

## Drops commissions past their deadline; returns the chronicle texts.
static func expire(s) -> Array[String]:
	var texts: Array[String] = []
	for quest: Dictionary in s.player.get("quests", []).duplicate():
		if int(s.world.day) > int(quest.deadline):
			s.player.quests.erase(quest)
			texts.append(s.log_event("quest_expired", {"quest_title": text(s, quest).title}))
	return texts
