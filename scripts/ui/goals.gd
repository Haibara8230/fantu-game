extends RefCounted
## Current goals: a few short hints in the sidebar about what the player could aim for now (breaking
## through, an appointment coming up, a promise kept open). Only presentation: nothing is saved and no
## goal is required. The texts live in data/goals.json in order of importance; when each applies and
## the numbers in it are worked out here.
const Calendar = preload("res://scripts/core/calendar.gd")
const Sources = preload("res://scripts/core/sources.gd")
const GOALS_PATH := "res://data/goals.json"
# The goals whose situation applies() knows; every goal in the data must be one of them.
const GOAL_IDS := ["bottleneck", "azhi_return", "auction", "serpent", "tournament", "summit", "foundation_breach", "foundation_pill", "foundation_xp", "core_breach", "azhi_token", "ruin", "sealed", "cultivate", "promotion", "rank"]
# Upcoming dates are mentioned this long ahead.
const TOURNAMENT_NOTICE_DAYS := 360
## The autumn auction is told this many days ahead.
const AUCTION_NOTICE_DAYS := 60
static var _goals: Array = []

static func goals() -> Array:
	if _goals.is_empty():
		var parsed: Variant = JSON.parse_string(FileAccess.get_file_as_string(GOALS_PATH))
		_goals = parsed if parsed is Array else []
	return _goals

static func known(goal_id: String) -> bool:
	return goal_id in GOAL_IDS

## All goals that apply now, with active story errands first: {"id", "title", "text"}. The guided
## start's step comes before everything; other storylines' steps after the goals of data/goals.json.
static func current(session) -> Array[Dictionary]:
	var result: Array[Dictionary] = []
	var told := story_goals(session)
	for goal: Dictionary in told:
		if goal.guide:
			result.append(goal)
	if not result.is_empty():
		return result
	for goal: Dictionary in told:
		result.append(goal)
	for id: String in ["humble_spring", "humble_echo", "humble_temper"]:
		if str(session.player.get("boons", {}).get(id, "")) == "ready":
			var places: Array = session.content.rules.fortune[id].get("places", ["sect"])
			result.append({"id": "fortune:" + id, "title": str(session.content.events[id].title) + "线索", "text": "已记下线索，到%s花十日追寻；暂缓不会失去机会。" % session.content.locations[str(places[0])].name})
	for goal: Dictionary in goals():
		if applies(session, goal.id):
			var filled: Dictionary = values(session, goal.id)
			result.append({"id": goal.id, "title": str(goal.title).format(filled), "text": str(goal.text).format(filled)})
	return actionable(session, result)

## Tracking changes order only; all goals remain accessible and guidance remains first.
static func displayed(ui) -> Array[Dictionary]:
	var result := current(ui.session)
	for index: int in result.size():
		if str(result[index].id) == ui.tracked_goal and not result.any(func(g: Dictionary) -> bool: return bool(g.get("guide", false))):
			var selected: Dictionary = result.pop_at(index)
			result.push_front(selected)
			break
	return result

## The steps of active storylines that ask something of the player now: {"id", "title", "text", "guide"}.
## Steps still waiting (for days to pass or for the player to reach a stage) ask nothing yet.
static func story_goals(session) -> Array[Dictionary]:
	var result: Array[Dictionary] = []
	for story_id: String in session.content.storylines:
		var definition: Dictionary = session.content.storylines[story_id]
		var step: Dictionary = session.story_step(story_id)
		if step.is_empty() or not step.has("goal") or not session.story_at(story_id, str(step.id)):
			continue
		var shown := described_step(session, step)
		var text := str(shown.goal)
		if shown.has("place") and str(shown.place) != str(session.player.location):
			text += "（%s）" % session.content.locations[shown.place].name
		var needs: Dictionary = session.Storylines.required_items(session, story_id)
		for item_id: String in needs:
			text += "\n%s %d/%d" % [session.content.item(item_id).name, session.pill_count(item_id), int(needs[item_id])]
			if session.pill_count(item_id) < int(needs[item_id]):
				text += " " + Sources.line(session, item_id)
		result.append({"id": "story:" + story_id, "title": str(definition.title), "text": text, "guide": bool(definition.get("guide", false))})
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
			var opening := _next_opening(session, "yunxi_autumn")
			return opening >= day and opening - day <= AUCTION_NOTICE_DAYS
		"serpent":
			return flags.call("rushi_done") and not flags.call("serpent_slain") and not flags.call("serpent_rampage") and day < _window_start(session, "serpent_rampage")
		"tournament":
			var next := _next_tournament(session)
			return int(player.realm) == 0 and next >= day and next - day <= TOURNAMENT_NOTICE_DAYS
		"summit":
			var opening := _next_opening(session, "five_sects_entry")
			return int(player.realm) >= 1 and opening >= day and opening - day <= TOURNAMENT_NOTICE_DAYS
		"foundation_breach", "foundation_pill", "foundation_xp":
			var breakthrough: Dictionary = session.next_breakthrough()
			if int(player.realm) != 0 or breakthrough.is_empty():
				return false
			var ready_xp := int(player.xp) >= int(breakthrough.xp)
			var ready_pill: bool = session.pill_count("foundation_pill") >= int(breakthrough.get("pills", 1)) or not session.breakthrough_treasures().is_empty() or str(player.get("boons", {}).get("remnant", "")) == "ready"
			match goal_id:
				"foundation_breach":
					return ready_xp and ready_pill
				"foundation_pill":
					return ready_xp and not ready_pill
			return not ready_xp and not session.at_bottleneck()
		"core_breach":
			# From 金丹 on a breakthrough asks no pill: the xp is all.
			var forming: Dictionary = session.next_breakthrough()
			return int(player.realm) >= 1 and not forming.is_empty() and int(player.xp) >= int(forming.xp)
		"azhi_token":
			return flags.call("azhi_promised") and not flags.call("azhi_mourned") and session.item_count("azhi_token") == 0
		"ruin":
			return flags.call("found_ruin") and not flags.call("ruin_cleared") and not flags.call("azhi_promised")
		"sealed":
			return flags.call("serpent_rampage")
		"cultivate":
			return int(player.realm) >= 1 and not _next_stage(session).is_empty() and not session.at_bottleneck()
		"promotion":
			return flags.call("rushi_done") and not session.next_sect_rank().is_empty() and session.promotion_block().is_empty()
		"rank":
			# Mentioned once half the merit is in hand, so a new disciple's goals stay few.
			var next: Dictionary = session.next_sect_rank()
			return flags.call("rushi_done") and not next.is_empty() and not session.promotion_block().is_empty() and int(player.get("merit", 0)) * 2 >= int(next.merit)
	return false

## The numbers and names a goal's text mentions.
static func values(session, goal_id: String) -> Dictionary:
	var player: Dictionary = session.player
	var day := int(session.world.day)
	match goal_id:
		"bottleneck":
			return {"insight": int(player.insight), "insight_needed": session.insight_needed(), "pozhang_price": _price(session, "pozhang_pill")}
		"auction":
			var start := _next_opening(session, "yunxi_autumn")
			return {"date": Calendar.date_text(start), "until": _span(start - day)}
		"serpent":
			var start := _window_start(session, "serpent_rampage")
			return {"date": Calendar.date_text(start), "until": _span(start - day)}
		"sealed":
			var start := _window_start(session, "serpent_rampage_ends")
			return {"date": Calendar.date_text(start), "until": _span(start - day)}
		"tournament":
			var next := _next_tournament(session)
			return {"date": Calendar.date_text(next), "until": _span(next - day)}
		"summit":
			var opening := _next_opening(session, "five_sects_entry")
			return {"date": Calendar.date_text(opening), "until": _span(opening - day)}
		"foundation_pill":
			return {"pill_price": _price(session, "foundation_pill"), "sources": _sources(session, "foundation_pill")}
		"foundation_breach":
			return {"odds": int(session.breakthrough_odds(session.breakthrough_plan()).total)}
		"core_breach":
			return {"odds": int(session.breakthrough_odds(session.breakthrough_plan()).total), "next_realm": session.content.realm(int(player.realm) + 1).name}
		"promotion", "rank":
			var next: Dictionary = session.next_sect_rank()
			return {"rank_name": next.name, "merit": int(player.get("merit", 0)), "merit_needed": int(next.merit), "stage_name": session.content.realm_title(int(next.stage[0]), int(next.stage[1]))}
		"foundation_xp":
			return {"xp": int(player.xp), "breakthrough_xp": int(session.next_breakthrough().xp)}
		"ruin":
			return {"ruin_hint": ruin_hint(session)}
		"azhi_token":
			var hint := ""
			if not session.has_flag("found_ruin"):
				hint = "洞府的方位，青石镇茶馆的说书先生最清楚。"
			elif not session.has_flag("ruin_cleared"):
				hint = ruin_hint(session)
			else:
				hint = "到洞府石室看看。"
			return {"ruin_hint": hint}
		"cultivate":
			var next := _next_stage(session)
			return {"xp": int(player.xp), "next_xp": int(next.xp), "next_stage": session.content.realm_title(int(player.realm), int(player.stage) + 1)}
	return {}

static func ruin_hint(session) -> String:
	if session.story_state("liu_squatter") == "active":
		return "洞府被石寒占据，可转告柳寒舟的话劝他离开，或选择斗法。"
	return "洞府被散修石寒占据，须先设法让他让出石室。"

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
	return _next_opening(session, "qianlong_entry")

## The next day a periodic event opens (today's opening while it is still open).
static func _next_opening(session, event_id: String) -> int:
	var periodic: Dictionary = session.content.events[event_id].periodic
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

## Where the player knows the item can be had, or a word that they know of nowhere yet.
static func _sources(session, item_id: String) -> String:
	var known := Sources.line(session, item_id)
	return known if not known.is_empty() else "眼下还不知何处可得，不妨到茶馆打听。"

static func _price(session, item_id: String) -> int:
	for line: Dictionary in session.content.locations.market.get("shop", []):
		if line.item == item_id:
			return int(line.price)
	return int(session.content.item(item_id).get("price", 0))

## Keep discovered but blocked goals; show another activity before them.
static func actionable(session, goals_list: Array[Dictionary]) -> Array[Dictionary]:
	var ready: Array[Dictionary] = []
	var waiting: Array[Dictionary] = []
	for goal: Dictionary in goals_list:
		var reason := ""
		var id := str(goal.id)
		var place := ""
		if id.begins_with("story:"):
			place = str(described_step(session, session.story_step(id.trim_prefix("story:"))).get("place", ""))
		elif id in ["ruin", "azhi_token", "serpent"]:
			place = "wild"
		if not place.is_empty() and session.content.location_sealed(place, session.world.flags):
			reason = "%s暂时封锁，可先在松风岭采药、处理别处托付。" % session.content.locations[place].name
		elif id == "serpent" and int(session.player.realm) < 1:
			reason = "需先筑基；眼下可修行、筹备丹药与神通。"
		goal["state"] = "waiting" if not reason.is_empty() else "ready"
		if not reason.is_empty():
			goal.text += "\n" + reason
			waiting.append(goal)
		else:
			ready.append(goal)
	ready.append_array(waiting)
	return ready

## Branch wording affects presentation only; the step ID and completion rules never change.
static func described_step(session, step: Dictionary) -> Dictionary:
	for variant: Dictionary in step.get("goal_variants", []):
		if session.Events.all_met(session, variant.get("conditions", [])):
			var shown := step.duplicate()
			shown.goal = variant.goal
			if variant.has("place"):
				shown.place = variant.place
			return shown
	return step
