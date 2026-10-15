extends RefCounted
## 洞府使用权, first version (docs/WORLD_EXPANSION.md 7.5, item 50): a place may let out a dwelling for a
## term (data/world.json location `lease`: flag, name, days, price). Taking it sets the world flag that
## opens the dwelling's scene (retreat, rest, breakthrough) until the term ends; taking it again while it
## runs adds a term. Nothing is kept in the dwelling, so the end of a term takes nothing from the player.
## Operates on a Session. player.leases: {flag: the last day of the term}.

## The dwelling let out where the player stands, or {}.
static func offer(s) -> Dictionary:
	return s.content.locations.get(str(s.player.location), {}).get("lease", {})

## The last day of a running term, or -1.
static func until(s, flag: String) -> int:
	return int(s.player.get("leases", {}).get(flag, -1))

## Why the dwelling cannot be taken now, or "".
static func block(s) -> String:
	var reason: String = s.blocked()
	if not reason.is_empty():
		return reason
	var lease := offer(s)
	if lease.is_empty() or not s.available_here("lease"):
		return "此地没有可赁的住处。"
	if int(s.player.stones) < int(lease.price):
		return "灵石不足：赁下%s要 %d 灵石。" % [lease.name, int(lease.price)]
	return ""

## Takes the dwelling for a term, or a further term after the one that runs.
static func take(s) -> String:
	var reason := block(s)
	if not reason.is_empty():
		return reason
	var lease := offer(s)
	s.player.stones = int(s.player.stones) - int(lease.price)
	var flag := str(lease.flag)
	var start := maxi(int(s.world.day), until(s, flag) + 1)
	if not s.player.has("leases"):
		s.player["leases"] = {}
	s.player.leases[flag] = start + int(lease.days) - 1
	s.world.flags[flag] = true
	return s.conclude(s.log_event("lease_taken", {"location": s.player.location, "lease_name": lease.name, "lease_days": int(lease.days), "price": int(lease.price)}))

## The next term to end on or after `from_day`: {"day", "flag"}, or {}.
static func next_end(s, from_day: int) -> Dictionary:
	var best := {}
	for flag: String in s.player.get("leases", {}):
		var day := maxi(from_day, int(s.player.leases[flag]) + 1)
		if best.is_empty() or day < int(best.day) or (day == int(best.day) and flag < str(best.flag)):
			best = {"day": day, "flag": flag}
	return best

## A term ends: the dwelling's scene closes. Its name for the chronicle is found by its flag.
static func end(s, flag: String) -> String:
	s.player.leases.erase(flag)
	s.world.flags.erase(flag)
	var name := flag
	for location_id: String in s.content.locations:
		var lease: Dictionary = s.content.locations[location_id].get("lease", {})
		if str(lease.get("flag", "")) == flag:
			name = str(lease.name)
	return s.log_event("lease_ended", {"lease_name": name})
