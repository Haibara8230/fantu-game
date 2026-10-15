extends RefCounted
## Travel along the region's routes. Operates on a Session.
## player.journey holds the destination while a journey is under way, so one interrupted by an
## encounter or an event can be continued.
const Events = preload("res://scripts/core/events.gd")

## The shortest way the player can take: roads that ask a higher realm (a 传送阵) are left out.
static func path_to(s, location_id: String) -> Array[String]:
	return s.content.find_path(s.player.location, location_id, s.world.flags, int(s.player.realm))

## The stones the roads of `path` ask (a 传送阵's fee), paid leg by leg.
static func path_fee(s, path: Array[String]) -> int:
	var total := 0
	for index: int in range(1, path.size()):
		total += int(s.content.route_between(path[index - 1], path[index]).get("fee", 0))
	return total

## Sets out for a destination along the shortest known path and walks it leg by leg.
static func travel(s, location_id: String) -> String:
	var blocked: String = s.blocked()
	if not blocked.is_empty():
		return "斗法中无法离开。" if not s.battle.is_empty() else blocked
	if not s.content.locations.has(location_id) or not s.location_visible(location_id):
		return "未知地点。"
	if s.player.location != location_id and s.content.location_sealed(location_id, s.world.flags):
		return "%s已被封锁，暂时无法进入。" % s.content.locations[location_id].name
	if s.player.location == location_id:
		return "你已在此处。"
	var path := path_to(s, location_id)
	if path.is_empty():
		return "两地之间没有可走的路。"
	var fee := path_fee(s, path)
	if fee > int(s.player.stones):
		return "盘缠不足：这一路要 %d 灵石。" % fee
	var held: String = s.guide_block("travel", location_id)
	if not held.is_empty():
		return held
	s.player.journey = {"to": location_id}
	return _walk(s)

## Resumes a journey interrupted by an encounter or an event on the way.
static func continue_journey(s) -> String:
	var blocked: String = s.blocked()
	if not blocked.is_empty():
		return blocked
	if s.player.journey.is_empty():
		return "眼下没有未竟的行程。"
	return _walk(s)

## Each leg: time passes on the road, the player arrives at the next node, the road may bring an
## encounter, then the node's own events fire. Anything that needs the player stops the journey there.
static func _walk(s) -> String:
	var parts: Array[String] = []
	while not s.player.journey.is_empty():
		var path := path_to(s, s.player.journey.to)
		if path.size() < 2:
			s.player.journey = {}
			parts.append("前路已断，行程作罢。")
			break
		var next: String = path[1]
		var route: Dictionary = s.content.route_between(s.player.location, next)
		var fee := int(route.get("fee", 0))
		if fee > 0:
			if int(s.player.stones) < fee:
				s.player.journey = {}
				parts.append("灵石不够%s的 %d 灵石，行程作罢。" % [route.get("by", "这一程"), fee])
				break
			s.player.stones = int(s.player.stones) - fee
			parts.append(s.log_event("route_fee", {"fee": fee, "by": str(route.get("by", "")), "location": next}))
		var passed: Dictionary = s.advance_days(s.route_days(route))
		parts.append_array(passed.messages)
		if not s.ended.is_empty():
			s.player.journey = {}
			break
		s.player.location = next
		s.Commissions.record_visit(s, next)
		if next == s.player.journey.to:
			s.player.journey = {}
		var leg := {"days": passed.elapsed, "location": next}
		if s.flying():
			leg.fly = true
		parts.append(s.log_event("travel", leg))
		# Beasts leave a newcomer on the guided start alone, and nothing on the road troubles one in flight.
		if s.encounters_enabled and s.guide_step().is_empty() and not s.flying():
			parts.append(Events.roll_encounter(s, route))
		if s.pending_event.is_empty():
			parts.append_array(Events.check_location(s, not s.player.journey.is_empty()))
		if not s.pending_event.is_empty() or not s.battle.is_empty():
			break
	parts.append_array(s.Storylines.update(s))
	s.changed.emit()
	return " ".join(parts.filter(func(part: String) -> bool: return not part.is_empty()))
