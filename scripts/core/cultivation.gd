extends RefCounted
## Cultivation progress: retreat fatigue, sub-stage bottlenecks and insight. Operates on a Session.
## Closed-door cultivation tires the mind: after rules.retreat.fresh_days of retreat in a row each day
## yields less, down to floor_percent; every day spent otherwise eases recovery_per_day of it.
## player.fatigue is the tiredness when the last retreat ended on player.fatigue_day, so one long retreat
## and several back-to-back short ones tire the same.
## Each sub-stage threshold is a bottleneck: xp stops there until enough insight (player.insight, from
## duels, spars, commissions and events) or a 破障丹 breaks it. Breaking one enters the next stage and
## clears the insight. The realm breakthrough keeps its own requirements.
const Calendar = preload("res://scripts/core/calendar.gd")
# player.cultivation_carry counts hundredths of a retreat day's xp-thirtieths, so partial efficiency
# carries over exactly.
const CARRY_SCALE := 100
const CARRY_UNIT := Calendar.DAYS_PER_MONTH * CARRY_SCALE

## Retreat tiredness today, after the days spent since the last retreat.
static func fatigue(s) -> int:
	var retreat: Dictionary = s.content.rules.retreat
	var rested := maxi(0, int(s.world.day) - int(s.player.fatigue_day))
	return maxi(0, int(s.player.fatigue) - rested * int(retreat.recovery_per_day))

## Tiredness beyond which retreat days yield no less.
static func fatigue_cap(s) -> int:
	var retreat: Dictionary = s.content.rules.retreat
	return int(retreat.fresh_days) + int(retreat.decline_days) * (100 - int(retreat.floor_percent)) / 100

## Percent of the usual xp a retreat day yields after `tired` days of retreat in a row.
static func efficiency(s, tired: int) -> int:
	var retreat: Dictionary = s.content.rules.retreat
	if tired <= int(retreat.fresh_days):
		return 100
	return maxi(int(retreat.floor_percent), 100 - (tired - int(retreat.fresh_days)) * 100 / int(retreat.decline_days))

## The xp at which the next sub-stage waits, or -1 in the last stage (the realm breakthrough).
static func xp_limit(s) -> int:
	var stages: Array = s.content.realm(int(s.player.realm)).stages
	var next := int(s.player.stage) + 1
	return int(stages[next].xp) if next < stages.size() else -1

static func at_bottleneck(s) -> bool:
	var limit := xp_limit(s)
	return limit >= 0 and int(s.player.xp) >= limit

static func insight_needed(s) -> int:
	return int(s.content.rules.bottleneck.insight_needed)

## Walks up to `days` retreat days from the current xp, starting `tired`, without applying anything:
## {"days", "xp", "carry", "fatigue"}. Stops on the day xp reaches a bottleneck the current insight
## cannot break, since further days would yield nothing.
static func plan_retreat(s, days: int, tired: int) -> Dictionary:
	var rate: int = s.cultivation_rate()
	var cap := fatigue_cap(s)
	var carry := int(s.player.cultivation_carry)
	var start := int(s.player.xp)
	var xp := start
	var stop := _retreat_stop(s)
	var elapsed := 0
	while elapsed < days:
		var total := carry + rate * efficiency(s, tired)
		carry = total % CARRY_UNIT
		xp += total / CARRY_UNIT
		tired = mini(cap, tired + 1)
		elapsed += 1
		if stop >= 0 and xp >= stop:
			xp = stop
			break
	return {"days": elapsed, "xp": xp - start, "carry": carry, "fatigue": tired}

## Where a retreat must stop: the next threshold, or the one after if the insight already suffices.
static func _retreat_stop(s) -> int:
	var stages: Array = s.content.realm(int(s.player.realm)).stages
	var next := int(s.player.stage) + 1
	if int(s.player.insight) >= insight_needed(s):
		next += 1
	return int(stages[next].xp) if next < stages.size() else -1

## Adds xp up to the next bottleneck; enough insight breaks it on the way. Xp the bottleneck holds back
## is recorded, so a reward's stated xp never reads as gained when it was not. Returns the texts.
static func gain_xp(s, amount: int) -> Array[String]:
	var texts: Array[String] = []
	var left := amount
	while left > 0:
		var limit := xp_limit(s)
		var take := left if limit < 0 else mini(left, maxi(0, limit - int(s.player.xp)))
		s.player.xp = int(s.player.xp) + take
		left -= take
		var promoted := settle_stage(s)
		texts.append_array(promoted)
		if promoted.is_empty():
			break
	if left > 0:
		texts.append(s.log_event("xp_held", {"xp": left}))
	return texts

## Enters every sub-stage that is reached and unlocked by insight; xp waiting at a bottleneck is held at
## its threshold. Returns the milestone texts.
static func settle_stage(s) -> Array[String]:
	var texts: Array[String] = []
	while true:
		var limit := xp_limit(s)
		if limit < 0 or int(s.player.xp) < limit:
			break
		if int(s.player.insight) < insight_needed(s):
			s.player.xp = limit
			break
		texts.append(_advance(s))
	return texts

## Experience from outside the retreat; at a bottleneck it may break through at once.
static func gain_insight(s, source: String) -> Array[String]:
	var bottleneck: Dictionary = s.content.rules.bottleneck
	s.player.insight = mini(insight_needed(s), int(s.player.insight) + int(bottleneck.insight[source]))
	return settle_stage(s)

## A 破障丹: enters the next sub-stage when xp waits at its bottleneck.
static func breach(s) -> Array[String]:
	var texts: Array[String] = []
	if at_bottleneck(s):
		texts.append(_advance(s))
	return texts

## Enters the next sub-stage: the caps rise, the new headroom goes to hp and qi, insight is spent.
static func _advance(s) -> String:
	var old_hp := int(s.player.max_hp)
	var old_qi := int(s.player.max_qi)
	s.player.stage = int(s.player.stage) + 1
	s.player.insight = 0
	s.refresh_realm_stats()
	s.player.hp = int(s.player.hp) + int(s.player.max_hp) - old_hp
	s.player.qi = int(s.player.qi) + int(s.player.max_qi) - old_qi
	return s.log_event("stage_up", {"realm": int(s.player.realm), "stage": int(s.player.stage)}, true)
