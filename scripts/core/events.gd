extends RefCounted
## Event engine: conditions, windows, the due-item scheduler, location triggers and choices.
## Event definitions live in data/events.json; per-event progress lives in world.events.
## Undiscovered and available states are derived; saved states are completed and expired.
const Calendar = preload("res://scripts/core/calendar.gd")
const NEVER := 2147483647
const STATES := ["completed", "expired"]

# --- Windows ---------------------------------------------------------------

## The window that contains `day`, or an empty Dictionary. Events without a window are always open.
static func window_at(definition: Dictionary, day: int) -> Dictionary:
	if definition.has("window"):
		var fixed := _fixed_window(definition)
		return fixed if day >= fixed.from and day <= fixed.to else {}
	if definition.has("periodic"):
		var periodic: Dictionary = definition.periodic
		var year := Calendar.year(day)
		if year < int(periodic.start_year):
			return {}
		var occurrence: int = (year - int(periodic.start_year)) / int(periodic.every_years)
		var candidate := _periodic_window(periodic, occurrence)
		return candidate if day >= candidate.from and day <= candidate.to else {}
	return {"from": 0, "to": NEVER, "occurrence": 0}

## The first window that starts on or after `day`, or an empty Dictionary.
static func next_window(definition: Dictionary, day: int) -> Dictionary:
	if definition.has("window"):
		var fixed := _fixed_window(definition)
		return fixed if fixed.from >= day else {}
	if definition.has("periodic"):
		var periodic: Dictionary = definition.periodic
		var occurrence := maxi(0, (Calendar.year(day) - int(periodic.start_year)) / int(periodic.every_years))
		while true:
			var candidate := _periodic_window(periodic, occurrence)
			if candidate.from >= day:
				return candidate
			occurrence += 1
	return {}

static func _fixed_window(definition: Dictionary) -> Dictionary:
	var from: Array = definition.window.from
	var to: Array = definition.window.to
	return {"from": Calendar.to_day(from[0], from[1], from[2]), "to": Calendar.to_day(to[0], to[1], to[2]), "occurrence": 0}

static func _periodic_window(periodic: Dictionary, occurrence: int) -> Dictionary:
	var year := int(periodic.start_year) + occurrence * int(periodic.every_years)
	return {
		"from": Calendar.to_day(year, int(periodic.month), int(periodic.from_day)),
		"to": Calendar.to_day(year, int(periodic.month), int(periodic.to_day)),
		"occurrence": occurrence,
	}

# --- Conditions and effects --------------------------------------------------

static func all_met(s, conditions: Array) -> bool:
	for condition: Dictionary in conditions:
		if not met(s, condition):
			return false
	return true

static func met(s, condition: Dictionary) -> bool:
	var key: String = condition.keys()[0]
	var value: Variant = condition[key]
	match key:
		"all":
			return all_met(s, value)
		"any":
			for option: Dictionary in value:
				if met(s, option):
					return true
			return false
		"not":
			return not met(s, value)
		"realm_at_least":
			return int(s.player.realm) >= int(value)
		"flag":
			return s.has_flag(value)
		"item_at_least":
			return int(s.player.items.get(value[0], 0)) >= int(value[1])
		"stones_at_least":
			return int(s.player.stones) >= int(value)
		"herbs_at_least":
			return s.herb_count() >= int(value)
		"met":
			return bool(s.world.people.get(value, {}).get("met", false))
		"relation_at_least":
			return int(s.world.people.get(value[0], {}).get("relation", 0)) >= int(value[1])
		"event_state":
			return str(s.world.events.get(value[0], {}).get("state", "")) == value[1]
	return false

static func apply(s, effects: Array) -> void:
	for effect: Dictionary in effects:
		var key: String = effect.keys()[0]
		var value: Variant = effect[key]
		match key:
			"stones", "xp":
				s.player[key] = maxi(0, int(s.player[key]) + int(value))
				if key == "xp":
					s.settle_stage()
			"herbs":
				if int(value) >= 0:
					s.add_item("huichun_grass", int(value))
				else:
					s.remove_herbs(mini(-int(value), s.herb_count()))
			"pills":
				if int(value) >= 0:
					s.add_item("foundation_pill", int(value))
				else:
					s.remove_item("foundation_pill", mini(-int(value), s.item_count("foundation_pill")))
			"hp":
				s.player.hp = clampi(int(s.player.hp) + int(value), 1, int(s.player.max_hp))
			"qi":
				s.player.qi = clampi(int(s.player.qi) + int(value), 0, int(s.player.max_qi))
			"item":
				var count := maxi(0, int(s.player.items.get(value[0], 0)) + int(value[1]))
				if count == 0:
					s.player.items.erase(value[0])
				else:
					s.player.items[value[0]] = count
			"take_item":
				if int(s.player.items.get(value, 0)) > 0:
					apply(s, [{"item": [value, -1]}])
			"flag":
				s.world.flags[value] = true
			"meet":
				_person(s, value).met = true
			"relation":
				var person := _person(s, value[0])
				person.met = true
				person.relation = clampi(int(person.relation) + int(value[1]), -s.content.FAVOR_MAX, s.content.FAVOR_MAX)
			"leave":
				s.npc_depart(s.acting_npc)
			"battle":
				s.begin_battle(value, "event")

static func _person(s, person_id: String) -> Dictionary:
	if not s.world.people.has(person_id):
		s.world.people[person_id] = {"met": false, "relation": 0, "last": {}, "absent_until": -1, "talks": 0}
	return s.world.people[person_id]

static func person(s, person_id: String) -> Dictionary:
	return _person(s, person_id)

static func _progress(s, event_id: String) -> Dictionary:
	if not s.world.events.has(event_id):
		s.world.events[event_id] = {"state": "", "count": 0, "last_day": -1, "last_occurrence": -1, "reminded": -1}
	return s.world.events[event_id]

static func progress_of(s, event_id: String) -> Dictionary:
	return s.world.events.get(event_id, {"state": "", "count": 0, "last_day": -1, "last_occurrence": -1, "reminded": -1})

## Whether the event may fire in `window` given its saved progress (not its conditions).
static func open_for(s, event_id: String, window: Dictionary, day: int) -> bool:
	var definition: Dictionary = s.content.events[event_id]
	var progress := progress_of(s, event_id)
	if definition.has("periodic"):
		return int(progress.last_occurrence) != int(window.occurrence)
	if definition.has("repeat"):
		return int(progress.last_day) < 0 or day >= int(progress.last_day) + int(definition.repeat.cooldown_days)
	return not str(progress.state) in STATES

static func _mark_fired(s, event_id: String, window: Dictionary, day: int) -> void:
	var definition: Dictionary = s.content.events[event_id]
	var progress := _progress(s, event_id)
	progress.count = int(progress.count) + 1
	progress.last_day = day
	progress.last_occurrence = int(window.occurrence)
	if not definition.has("periodic") and not definition.has("repeat"):
		progress.state = "completed"

static func _sorted_ids(s) -> Array[String]:
	return s.content.events_by_priority()

# --- Scheduler -----------------------------------------------------------------

## The earliest due item on or after `from_day`: {"day", "kind", "event"}; empty when nothing is pending.
## Every kind changes saved state when fired, so the same item is never returned twice.
static func next_due(s, from_day: int) -> Dictionary:
	var best := {}
	var lifespan_end: int = s.lifespan_end_day()
	var warning_day: int = lifespan_end - int(s.content.rules.lifespan_warning_years) * Calendar.DAYS_PER_YEAR
	if int(s.player.get("warned_for", -1)) != lifespan_end:
		best = _earlier(best, {"day": maxi(from_day, warning_day), "kind": "lifespan_warning", "event": ""})
	best = _earlier(best, {"day": maxi(from_day, lifespan_end), "kind": "lifespan_end", "event": ""})
	for event_id: String in _sorted_ids(s):
		var definition: Dictionary = s.content.events[event_id]
		var progress := progress_of(s, event_id)
		var window := window_at(definition, from_day)
		if window.is_empty() or not open_for(s, event_id, window, from_day):
			window = next_window(definition, from_day + 1) if not window.is_empty() else next_window(definition, from_day)
		if definition.trigger == "date":
			if not window.is_empty():
				best = _earlier(best, {"day": maxi(from_day, int(window.from)), "kind": "date", "event": event_id})
			continue
		if str(progress.state) in STATES or not definition.has("window"):
			continue
		var fixed := _fixed_window(definition)
		if definition.has("remind") and int(progress.reminded) != 0 and from_day <= int(fixed.to):
			best = _earlier(best, {"day": maxi(from_day, int(fixed.from)), "kind": "remind", "event": event_id})
		best = _earlier(best, {"day": maxi(from_day, int(fixed.to) + 1), "kind": "expire", "event": event_id})
	return best

static func _earlier(a: Dictionary, b: Dictionary) -> Dictionary:
	if a.is_empty() or int(b.day) < int(a.day):
		return b
	return a

## Fires a due item at the current world day. Returns {"interrupt": bool, "message": String}.
static func fire(s, due: Dictionary) -> Dictionary:
	var day: int = s.world.day
	match due.kind:
		"lifespan_warning":
			s.player.warned_for = s.lifespan_end_day()
			var years: int = int(s.content.rules.lifespan_warning_years)
			return {"interrupt": true, "message": s.log_event("lifespan_warning", {"years": years}, true)}
		"lifespan_end":
			s.ended = {"kind": "lifespan", "day": day}
			return {"interrupt": true, "message": s.log_event("lifespan_end", {"location": s.player.location, "age": s.age()}, true)}
		"date":
			var definition: Dictionary = s.content.events[due.event]
			var window := window_at(definition, day)
			if window.is_empty():
				window = {"occurrence": -2}
			_mark_fired(s, due.event, window, day)
			if not all_met(s, definition.get("conditions", [])):
				return {"interrupt": false, "message": ""}
			apply(s, definition.get("effects", []))
			var text: String = s.log_event("event", {"event": due.event, "part": "chronicle"}, bool(definition.get("major", false)))
			return {"interrupt": bool(definition.get("interrupt", false)), "message": text}
		"remind":
			var definition: Dictionary = s.content.events[due.event]
			_progress(s, due.event).reminded = 0
			if not all_met(s, definition.remind.get("conditions", [])):
				return {"interrupt": false, "message": ""}
			return {"interrupt": true, "message": s.log_event("event", {"event": due.event, "part": "remind"})}
		"expire":
			var definition: Dictionary = s.content.events[due.event]
			_progress(s, due.event).state = "expired"
			if not definition.has("expire") or not all_met(s, definition.expire.get("conditions", [])):
				return {"interrupt": false, "message": ""}
			return {"interrupt": false, "message": s.log_event("event", {"event": due.event, "part": "expire"})}
	return {"interrupt": false, "message": ""}

# --- Location triggers and choices ----------------------------------------------

## Fires location events available where the player stands. At most one choice event becomes pending.
## When only passing through a node on a journey, choice events wait until the player stops there.
## Returns the chronicle texts produced.
static func check_location(s, passing: bool = false) -> Array[String]:
	var messages: Array[String] = []
	if not s.pending_event.is_empty() or not s.ended.is_empty() or not s.battle.is_empty():
		return messages
	var day: int = s.world.day
	var used_groups := {}
	for event_id: String in _sorted_ids(s):
		var definition: Dictionary = s.content.events[event_id]
		if definition.trigger != "location" or definition.location != s.player.location:
			continue
		if passing and definition.has("choices"):
			continue
		var group: String = definition.get("group", "")
		if not group.is_empty() and used_groups.has(group):
			continue
		var window := window_at(definition, day)
		if window.is_empty() or not open_for(s, event_id, window, day) or not all_met(s, definition.get("conditions", [])):
			continue
		if definition.has("choices") and not s.pending_event.is_empty():
			continue
		if not group.is_empty():
			used_groups[group] = true
		_mark_fired(s, event_id, window, day)
		apply(s, definition.get("effects", []))
		if definition.has("choices"):
			s.pending_event = {"id": event_id, "day": day}
		else:
			messages.append(s.log_event("event", {"event": event_id, "part": "chronicle"}, bool(definition.get("major", false))))
	# Stopping somewhere means seeing who is there (after first-meeting stories have had their say).
	if not passing:
		s.meet_present()
	return messages

static func choose(s, choice_id: String) -> String:
	if s.pending_event.is_empty():
		return "眼下没有需要抉择的事。"
	var event_id: String = s.pending_event.id
	var definition: Dictionary = s.content.events[event_id]
	for choice: Dictionary in definition.choices:
		if choice.id != choice_id:
			continue
		if not all_met(s, choice.get("conditions", [])):
			return "条件不足，无法如此选择。"
		apply(s, choice.get("effects", []))
		s.pending_event = {}
		var text: String = s.log_event("event", {"event": event_id, "part": "choice", "choice": choice_id}, bool(definition.get("major", false)))
		var follow := check_location(s)
		return " ".join([text] + follow)
	return "没有这个选项。"

## Danger left after the player's realm: each realm above the first takes one level off.
static func effective_danger(s, route: Dictionary) -> int:
	return maxi(0, int(route.danger) - int(s.player.realm))

static func encounter_chance(s, route: Dictionary) -> float:
	return float(s.content.rules.encounter_chance[effective_danger(s, route)])

## Rolls for something on the road just travelled. Uses only the world random stream.
## Returns the chronicle text of a plain encounter, or "" (a choice encounter becomes pending).
static func roll_encounter(s, route: Dictionary) -> String:
	if s.world_rng.randf() >= encounter_chance(s, route):
		return ""
	var danger := effective_danger(s, route)
	var candidates: Array[String] = []
	var total := 0
	for event_id: String in _sorted_ids(s):
		var definition: Dictionary = s.content.events[event_id]
		if definition.trigger != "route" or int(definition.min_danger) > danger:
			continue
		var on_route := false
		for pair: Array in definition.routes:
			on_route = on_route or (pair[0] in route.between and pair[1] in route.between)
		if not on_route or not open_for(s, event_id, {"occurrence": 0}, int(s.world.day)) or not all_met(s, definition.get("conditions", [])):
			continue
		candidates.append(event_id)
		total += int(definition.weight)
	if candidates.is_empty():
		return ""
	var pick: int = s.world_rng.randi_range(1, total)
	for event_id: String in candidates:
		pick -= int(s.content.events[event_id].weight)
		if pick <= 0:
			return start(s, event_id)
	return ""

## Fires an event directly (route encounters). Choice events become pending; others return their text.
static func start(s, event_id: String) -> String:
	var definition: Dictionary = s.content.events[event_id]
	var day: int = s.world.day
	_mark_fired(s, event_id, {"occurrence": 0}, day)
	apply(s, definition.get("effects", []))
	if definition.has("choices"):
		s.pending_event = {"id": event_id, "day": day}
		return ""
	return s.log_event("event", {"event": event_id, "part": "chronicle"}, bool(definition.get("major", false)))

## Upcoming windows the player knows about (reminder conditions hold), soonest first.
static func upcoming(s) -> Array[Dictionary]:
	var result: Array[Dictionary] = []
	var day: int = s.world.day
	for event_id: String in s.content.events:
		var definition: Dictionary = s.content.events[event_id]
		if not definition.has("remind") or not definition.has("window") or str(progress_of(s, event_id).state) in STATES:
			continue
		var fixed := _fixed_window(definition)
		if int(fixed.to) < day or not all_met(s, definition.remind.get("conditions", [])):
			continue
		result.append({"event": event_id, "from": int(fixed.from), "to": int(fixed.to), "title": definition.title, "location": definition.location})
	result.sort_custom(func(a: Dictionary, b: Dictionary) -> bool: return a.from < b.from)
	return result
