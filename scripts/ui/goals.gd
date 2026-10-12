extends RefCounted
## Current goals: a few short hints in the sidebar about what the player could aim for now (breaking
## through, an appointment coming up, a promise kept open). Only presentation: nothing is saved and no
## goal is required. The texts live in data/goals.json in order of importance; when each applies and
## the numbers in it are worked out here.
const Calendar = preload("res://scripts/core/calendar.gd")
const GOALS_PATH := "res://data/goals.json"
const SHOWN := 3
# The goals whose situation applies() knows; every goal in the data must be one of them.
const GOAL_IDS := ["bottleneck", "azhi_return", "auction", "serpent", "tournament", "foundation_breach", "foundation_pill", "foundation_xp", "azhi_token", "ruin", "sealed", "cultivate"]
# Upcoming dates are mentioned this long ahead.
const TOURNAMENT_NOTICE_DAYS := 360
static var _goals: Array = []

static func goals() -> Array:
	if _goals.is_empty():
		var parsed: Variant = JSON.parse_string(FileAccess.get_file_as_string(GOALS_PATH))
		_goals = parsed if parsed is Array else []
	return _goals

static func known(goal_id: String) -> bool:
	return goal_id in GOAL_IDS

## The goals that apply now, most important first, at most SHOWN: {"id", "title", "text"}.
static func current(session) -> Array[Dictionary]:
	var result: Array[Dictionary] = []
	for goal: Dictionary in goals():
		if result.size() >= SHOWN:
			break
		if applies(session, goal.id):
			result.append({"id": goal.id, "title": str(goal.title), "text": str(goal.text).format(values(session, goal.id))})
	return result

static func applies(session, goal_id: String) -> bool:
	var player: Dictionary = session.player
	var flags := func(flag: String) -> bool: return session.has_flag(flag)
	var day := int(session.world.day)
	match goal_id:
		"bottleneck":
			return session.at_bottleneck()
		"azhi_return":
			return session.item_count("azhi_token") > 0
		"auction":
			var state := _event_state(session, "special_auction")
			var invited: bool = session.item_count("auction_invitation") > 0 or session.favor("shen_mo") >= 40
			return state.is_empty() and invited and day <= _window_end(session, "special_auction")
		"serpent":
			return not flags.call("serpent_slain") and not flags.call("serpent_rampage") and day < _window_start(session, "serpent_rampage")
		"tournament":
			var next := _next_tournament(session)
			return next >= day and next - day <= TOURNAMENT_NOTICE_DAYS
		"foundation_breach", "foundation_pill", "foundation_xp":
			var breakthrough: Dictionary = session.next_breakthrough()
			if int(player.realm) != 0 or breakthrough.is_empty():
				return false
			var ready_xp := int(player.xp) >= int(breakthrough.xp)
			var ready_pill: bool = session.item_count("foundation_pill") >= int(breakthrough.get("pills", 1))
			match goal_id:
				"foundation_breach":
					return ready_xp and ready_pill
				"foundation_pill":
					return ready_xp and not ready_pill
			return not ready_xp and not session.at_bottleneck()
		"azhi_token":
			return flags.call("azhi_promised") and not flags.call("azhi_mourned") and session.item_count("azhi_token") == 0
		"ruin":
			return flags.call("found_ruin") and not flags.call("ruin_cleared") and not flags.call("azhi_promised")
		"sealed":
			return flags.call("serpent_rampage")
		"cultivate":
			return int(player.realm) >= 1 and not _next_stage(session).is_empty() and not session.at_bottleneck()
	return false

## The numbers and names a goal's text mentions.
static func values(session, goal_id: String) -> Dictionary:
	var player: Dictionary = session.player
	var day := int(session.world.day)
	match goal_id:
		"bottleneck":
			return {"insight": int(player.insight), "insight_needed": session.insight_needed(), "pozhang_price": _price(session, "pozhang_pill")}
		"auction":
			var access := "持请柬入场" if session.item_count("auction_invitation") > 0 else "沈墨愿为你引荐"
			var start := _window_start(session, "special_auction")
			return {"date": Calendar.date_text(start), "access": access, "until": _span(start - day)}
		"serpent":
			var start := _window_start(session, "serpent_rampage")
			return {"date": Calendar.date_text(start), "until": _span(start - day)}
		"sealed":
			var start := _window_start(session, "serpent_rampage_ends")
			return {"date": Calendar.date_text(start), "until": _span(start - day)}
		"tournament":
			var next := _next_tournament(session)
			return {"date": Calendar.date_text(next), "until": _span(next - day)}
		"foundation_pill":
			return {"pill_price": _price(session, "foundation_pill")}
		"foundation_xp":
			return {"xp": int(player.xp), "breakthrough_xp": int(session.next_breakthrough().xp)}
		"azhi_token":
			var hint := ""
			if not session.has_flag("found_ruin"):
				hint = "洞府的方位，青石镇茶馆的说书先生最清楚。"
			elif not session.has_flag("ruin_cleared"):
				hint = "洞府被散修石寒占据，须先击败他。"
			else:
				hint = "到洞府石室看看。"
			return {"ruin_hint": hint}
		"cultivate":
			var next := _next_stage(session)
			return {"xp": int(player.xp), "next_xp": int(next.xp), "next_stage": session.content.realm_title(int(player.realm), int(player.stage) + 1)}
	return {}

## Time left as text: "N 日", "N 个月" or "N 年 M 个月".
static func _span(days: int) -> String:
	days = maxi(0, days)
	if days < Calendar.DAYS_PER_MONTH:
		return "%d 日" % days
	var years := days / Calendar.DAYS_PER_YEAR
	var months := (days % Calendar.DAYS_PER_YEAR) / Calendar.DAYS_PER_MONTH
	if years == 0:
		return "%d 个月" % months
	return "%d 年" % years if months == 0 else "%d 年 %d 个月" % [years, months]

static func _event_state(session, event_id: String) -> String:
	return str(session.world.events.get(event_id, {}).get("state", ""))

static func _window_start(session, event_id: String) -> int:
	var from: Array = session.content.events[event_id].window.from
	return Calendar.to_day(int(from[0]), int(from[1]), int(from[2]))

static func _window_end(session, event_id: String) -> int:
	var to: Array = session.content.events[event_id].window.to
	return Calendar.to_day(int(to[0]), int(to[1]), int(to[2]))

## The first day of the next tournament's sign-up that has not closed yet.
static func _next_tournament(session) -> int:
	var periodic: Dictionary = session.content.events.tournament_entry.periodic
	var day := int(session.world.day)
	var year := maxi(int(periodic.start_year), Calendar.year(day))
	year += posmod(int(periodic.start_year) - year, int(periodic.every_years))
	if Calendar.to_day(year, int(periodic.month), int(periodic.to_day)) < day:
		year += int(periodic.every_years)
	return Calendar.to_day(year, int(periodic.month), int(periodic.from_day))

## The next sub-stage of the current realm, or {} at its last.
static func _next_stage(session) -> Dictionary:
	var stages: Array = session.content.realm(int(session.player.realm)).stages
	var next := int(session.player.stage) + 1
	return stages[next] if next < stages.size() else {}

static func _price(session, item_id: String) -> int:
	for line: Dictionary in session.content.locations.market.get("shop", []):
		if line.item == item_id:
			return int(line.price)
	return int(session.content.item(item_id).get("price", 0))
