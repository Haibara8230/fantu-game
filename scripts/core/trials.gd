extends RefCounted
## 试炼 (docs/GAME_OUTLINE.md 19.4–19.5): what the player made of each sitting of a recurring trial —
## the floors climbed on 青云试剑崖 (series.gd, a `ranked` series), the 历练帖 merits earned in a season
## (commissions.gd, a `lilian` template). 天南大比 asks for a good showing in a recent sitting (events.gd
## `trial_at_least`). Operates on a Session. player.trials: {trial id: {year (a String): score}}.
const Calendar = preload("res://scripts/core/calendar.gd")
const TRIALS := ["jianya", "lilian"]

## Sets a sitting's score for the trial to `score` when it is better (a climb), or adds to it (merits).
## The sitting is this year's, or the season `year` named (a 历练帖 handed in after its year ends).
static func record(s, trial_id: String, score: int, add: bool = false, year_of: int = -1) -> void:
	if not s.player.has("trials"):
		s.player["trials"] = {}
	var sittings: Dictionary = s.player.trials.get(trial_id, {})
	var year := str(Calendar.year(int(s.world.day)) if year_of < 0 else year_of)
	sittings[year] = int(sittings.get(year, 0)) + score if add else maxi(int(sittings.get(year, 0)), score)
	s.player.trials[trial_id] = sittings

## The best score in the sittings of the last `within_years` years (this one included).
static func best(s, trial_id: String, within_years: int) -> int:
	var now := Calendar.year(int(s.world.day))
	var found := 0
	var sittings: Dictionary = s.player.get("trials", {}).get(trial_id, {})
	for year: String in sittings:
		if now - int(year) < within_years:
			found = maxi(found, int(sittings[year]))
	return found

## One sitting's score.
static func score(s, trial_id: String, year: int) -> int:
	return int(s.player.get("trials", {}).get(trial_id, {}).get(str(year), 0))
