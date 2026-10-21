extends RefCounted
## Cultivation progress: retreat fatigue, sub-stage bottlenecks and insight. Operates on a Session.
## Closed-door cultivation tires the mind: after rules.retreat.fresh_days of retreat in a row each day
## yields less, down to floor_percent; every day spent otherwise eases recovery_per_day of it.
## player.fatigue is the tiredness when the last retreat ended on player.fatigue_day, so one long retreat
## and several back-to-back short ones tire the same.
## Each sub-stage threshold is a bottleneck: xp stops there until enough insight (player.insight, from
## duels, spars, commissions and events) or a 破障丹 breaks it. Breaking one enters the next stage and
## clears the insight. The realm breakthrough keeps its own requirements, and xp stops at it (or at the
## realm's xp_cap when no breakthrough is open yet), so no retreat runs on with nothing to gain.
## The same experience also builds the mind (player.mind, 心境), which never resets. Each sub-stage asks
## for some: short of it a retreat yields half and may last half as long; well above it, a fifth more.
## A single retreat lasts at most the stage's retreat_days, so seclusion alternates with going out; the
## limit grows a great deal with the realm.
## Talents change every one of these limits through their modifiers (talents.gd).
const Calendar = preload("res://scripts/core/calendar.gd")
const Talents = preload("res://scripts/core/talents.gd")
# player.cultivation_carry counts hundredths of a retreat day's xp-thirtieths, so partial efficiency
# carries over exactly.
const CARRY_SCALE := 100
const CARRY_UNIT := Calendar.DAYS_PER_MONTH * CARRY_SCALE

## 客栈静房 (docs/GAME_OUTLINE.md 5.2): a room let by the day where one may retreat, study and break
## through without a sect — a spot's `lodging` {"rate" (of the retreat's xp), "rent" (stones a month)},
## paid for the days spent there. A free place (a sect's chamber, a house let by the term) yields whole
## and asks nothing. The rooms of 天南散修盟 (`league`) ask no rent of its 副盟主, and a 灵地 takes only
## the realm and standing it asks (`realm`, `standing`; league.gd).
## Of the places open here the retreat takes the richest whose month the purse can pay, else the
## cheapest: {"name", "rate", "rent"}, or {} where there is no place to retreat.
static func room(s) -> Dictionary:
	var rooms: Array[Dictionary] = []
	for spot: Dictionary in s.content.locations[str(s.player.location)].get("spots", []):
		if not "cultivate" in spot.actions or not usable(s, spot):
			continue
		var let: Dictionary = spot.get("lodging", {})
		var rent := 0 if bool(let.get("league", false)) and s.League.deputy(s) else int(let.get("rent", 0))
		rooms.append({"name": str(spot.name), "rate": float(let.get("rate", 1.0)), "rent": rent})
	rooms.sort_custom(func(a: Dictionary, b: Dictionary) -> bool: return a.rate > b.rate or (a.rate == b.rate and a.rent < b.rent))
	for kept: Dictionary in rooms:
		if int(kept.rent) <= int(s.player.stones):
			return kept
	var cheapest: Dictionary = {}
	for kept: Dictionary in rooms:
		if cheapest.is_empty() or int(kept.rent) < int(cheapest.rent):
			cheapest = kept
	return cheapest

## Whether a spot to retreat in takes the player: open to them, and for a 灵地 their realm and standing.
static func usable(s, spot: Dictionary) -> bool:
	return s.spot_open(spot) and (not spot.has("lodging") or s.League.room_open(s, spot.lodging))

## The room here when it asks rent, else {}.
static func lodging(s) -> Dictionary:
	var kept := room(s)
	return kept if int(kept.get("rent", 0)) > 0 else {}

## How richly a retreat here goes: the room's rate, else whole.
static func place_rate(s) -> float:
	return float(room(s).get("rate", 1.0))

## Stones the room asks for `days`, rounded up to whole stones.
static func rent(s, days: int) -> int:
	var let := lodging(s)
	return 0 if let.is_empty() else ceili(float(days) * float(let.rent) / float(Calendar.DAYS_PER_MONTH))

## The days the stones in hand pay for here (no limit where nothing is asked).
static func paid_days(s) -> int:
	var let := lodging(s)
	if let.is_empty() or int(let.rent) <= 0:
		return 2147483647
	return int(s.player.stones) * Calendar.DAYS_PER_MONTH / int(let.rent)

## Why `days` in the room cannot be paid for, or "".
static func rent_block(s, days: int) -> String:
	var cost := rent(s, days)
	if cost > int(s.player.stones):
		return "静房每月 %d 灵石，%s须付 %d 灵石，灵石不足。" % [int(lodging(s).rent), Calendar.duration_text(days), cost]
	return ""

## Pays the room for the days spent; returns the stones paid.
static func pay_rent(s, days: int) -> int:
	var cost := mini(rent(s, days), int(s.player.stones))
	s.player.stones = int(s.player.stones) - cost
	return cost

## Retreat tiredness today, after the days spent since the last retreat.
static func fatigue(s) -> int:
	var retreat: Dictionary = s.content.rules.retreat
	var rested := maxi(0, int(s.world.day) - int(s.player.fatigue_day))
	return maxi(0, int(s.player.fatigue) - rested * int(retreat.recovery_per_day))

## Tiredness beyond which retreat days yield no less.
static func fatigue_cap(s) -> int:
	var retreat: Dictionary = s.content.rules.retreat
	return fresh_days(s) + int(retreat.decline_days) * (100 - int(retreat.floor_percent)) / 100

## Days of retreat in a row that yield fully; higher realms keep a fresh mind for longer.
static func fresh_days(s) -> int:
	var days := int(s.content.realm(int(s.player.realm)).get("fresh_days", s.content.rules.retreat.fresh_days))
	return Talents.scaled(days, s.talent_modifier("fresh_days"), 1)

## Percent of the usual xp a retreat day yields after `tired` days of retreat in a row.
static func efficiency(s, tired: int) -> int:
	var retreat: Dictionary = s.content.rules.retreat
	if tired <= fresh_days(s):
		return 100
	return maxi(int(retreat.floor_percent), 100 - (tired - fresh_days(s)) * 100 / int(retreat.decline_days))

## The mind the current sub-stage asks for.
static func mind_needed(s) -> int:
	return Talents.scaled(int(s.stage_stats().get("mind", 0)), s.talent_modifier("mind_need"))

## Percent of the usual xp the mind allows: short of the stage's need, enough, or well above it.
static func mind_percent(s) -> int:
	var rules: Dictionary = s.content.rules.mind
	var mind := int(s.player.get("mind", 0))
	if mind < mind_needed(s):
		return int(rules.short_percent)
	if mind >= mind_needed(s) + int(rules.ample_margin):
		return int(rules.ample_percent)
	return 100

## The longest single retreat now: the stage's own limit, halved while the mind falls short.
static func retreat_cap(s) -> int:
	var days := Talents.scaled(int(s.stage_stats().get("retreat_days", 3600)), s.talent_modifier("retreat_days"), 1)
	if int(s.player.get("mind", 0)) < mind_needed(s):
		days = days * int(s.content.rules.mind.short_percent) / 100
	return maxi(1, days)

## The most xp this realm holds: the breakthrough's requirement, or the realm's cap; -1 when unbounded.
static func xp_cap(s) -> int:
	var realm: Dictionary = s.content.realm(int(s.player.realm))
	if realm.has("breakthrough"):
		return int(realm.breakthrough.xp)
	return int(realm.get("xp_cap", -1))

## Whether xp has reached the most this realm holds.
static func at_cap(s) -> bool:
	var cap := xp_cap(s)
	return cap >= 0 and int(s.player.xp) >= cap

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

## Walks up to `days` retreat days from the current xp, starting `tired` on `start_day` (today by default),
## without applying anything:
## {"days", "xp", "carry", "fatigue"}. Stops on the day xp reaches a bottleneck the current insight
## cannot break, since further days would yield nothing.
static func plan_retreat(s, days: int, tired: int, start_day: int = -1) -> Dictionary:
	var rate: int = s.cultivation_rate() * mind_percent(s) / 100
	# An injury from a failed breakthrough slows the days before it heals.
	var injured_until := int(s.player.get("injury_until", 0))
	var injured_rate: int = rate * int(s.content.rules.breakthrough.failure.injury_percent) / 100
	var cap := fatigue_cap(s)
	var carry := int(s.player.cultivation_carry)
	var start := int(s.player.xp)
	var xp := start
	var stop := _retreat_stop(s)
	var elapsed := 0
	while elapsed < days:
		var today := injured_rate if (int(s.world.day) if start_day < 0 else start_day) + elapsed < injured_until else rate
		var total := carry + today * efficiency(s, tired)
		carry = total % CARRY_UNIT
		xp += total / CARRY_UNIT
		tired = mini(cap, tired + 1)
		elapsed += 1
		if stop >= 0 and xp >= stop:
			xp = stop
			break
	return {"days": elapsed, "xp": xp - start, "carry": carry, "fatigue": tired}

## Where a retreat must stop: the next threshold, or the one after if the insight already suffices;
## past the last threshold, the most the realm holds.
static func _retreat_stop(s) -> int:
	var stages: Array = s.content.realm(int(s.player.realm)).stages
	var next := int(s.player.stage) + 1
	if int(s.player.insight) >= insight_needed(s):
		next += 1
	return int(stages[next].xp) if next < stages.size() else xp_cap(s)

## Adds xp up to the next bottleneck; enough insight breaks it on the way. Xp the bottleneck holds back
## is recorded, so a reward's stated xp never reads as gained when it was not. Returns the texts.
static func gain_xp(s, amount: int) -> Array[String]:
	var texts: Array[String] = []
	var left := amount
	while left > 0:
		var limit := xp_limit(s)
		if limit < 0:
			limit = xp_cap(s)
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

## Experience from outside the retreat: insight toward the bottleneck (at one it may break through at
## once) and mind.
static func gain_insight(s, source: String) -> Array[String]:
	var bottleneck: Dictionary = s.content.rules.bottleneck
	var gained := Talents.scaled(int(bottleneck.insight[source]), s.talent_modifier("insight"))
	s.player.insight = mini(insight_needed(s), int(s.player.insight) + gained)
	gain_mind(s, int(s.content.rules.mind.gain.get(source, 0)))
	return settle_stage(s)

## Talents change how much a gain brings, never a loss.
static func gain_mind(s, amount: int) -> void:
	if amount > 0:
		amount = Talents.scaled(amount, s.talent_modifier("mind_gain"))
	s.player["mind"] = maxi(0, int(s.player.get("mind", 0)) + amount)

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
