extends RefCounted
## Event engine: conditions, windows, the due-item scheduler, location triggers and choices.
## Event definitions live in data/events.json; per-event progress lives in world.events.
## Undiscovered and available states are derived; saved states are completed and expired.
const Calendar = preload("res://scripts/core/calendar.gd")
const NEVER := 2147483647
const STATES := ["completed", "expired"]
# A periodic dated event's next window to fire in, by event id: {"lo", "from", "to", "last"}. It follows
# from the definition, the day asked from and the occurrence last fired alone, so it holds for any later
# day up to the window's end while the event has not fired again (next_due asks it for every event on
# every step of time).
static var _due_windows := {}

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

## Where a location event is held in `window`: a periodic event may move round its `venues` (五宗论道,
## one city after another); otherwise its `location`.
static func venue(definition: Dictionary, window: Dictionary) -> String:
	var venues: Array = definition.get("periodic", {}).get("venues", [])
	if venues.is_empty():
		return str(definition.get("location", ""))
	return str(venues[int(window.get("occurrence", 0)) % venues.size()])

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

## A handwritten person still in the world: their 年表's `present_if` holds today.
static func _present_in_world(s, person_id: String) -> bool:
	return s.content.people.has(person_id) and all_met(s, s.People.view_on(s, person_id, int(s.world.day)).get("present_if", []))

## A work worth showing (五宗论道's 展示): a piece of at least `tier` carried or worn, or an art or
## 心法 of at least `tier` learned.
static func _work_at_least(s, tier: int) -> bool:
	var pieces: Array = s.player.get("items", {}).keys() + s.player.get("equipment", {}).values() + s.player.get("gear", {}).keys()
	for item_id: Variant in pieces:
		var piece: Dictionary = s.Gear.item(s, str(item_id))
		if str(piece.get("category", "")) == "equipment" and int(piece.get("tier", 0)) >= tier:
			return true
	for technique_id: Variant in s.player.get("learned", []):
		if int(s.content.technique(str(technique_id)).get("tier", 0)) >= tier:
			return true
	return false

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
		"grudge":
			return s.Feuds.any(s) == bool(value)
		"grudge_pay":
			return (int(s.player.stones) >= s.Feuds.pay(s)) == bool(value)
		"flag":
			return s.has_flag(value)
		"item_at_least":
			# A fine pill counts as the pill it is made beside.
			return s.pill_count(value[0]) >= int(value[1])
		"guest":
			return s.Guest.is_guest(s, str(value))
		# 天南散修盟 (league.gd): a member, its 副盟主, or one it cast out.
		"league":
			match str(value):
				"member":
					return s.League.member(s)
				"deputy":
					return s.League.deputy(s)
				"banned":
					return s.League.banned(s)
			return false
		# 天骄榜 (tianji.gd): the player within a rank on a scroll.
		"tianji":
			var held: int = s.Tianji.rank(s, str(value[0]))
			return held >= 1 and held <= int(value[1])
		# 萧家麒麟子 (rival.gd): how the bouts went, or what the player has heard.
		"rival":
			return s.Rival.met(s, str(value))
		# 无相宝录 (wuxiang.gd): a page held or lost to 影七, a favor owed, how it ended.
		"wuxiang":
			return s.Wuxiang.met(s, str(value))
		"holds_gear":
			return s.Gear.holds(s, str(value))
		"present":
			# A handwritten person still in the world (not gone by their 年表's `present_if`).
			return _present_in_world(s, str(value))
		"party":
			return s.Caves.party(s, str(value[0])) == str(value[1])
		"work_at_least":
			return _work_at_least(s, int(value))
		"stones_at_least":
			return int(s.player.stones) >= int(value)
		"year_at_least":
			return Calendar.year(int(s.world.day)) >= int(value)
		# [trial, score, within years]: a good enough sitting lately (trials.gd).
		"trial_at_least":
			return s.Trials.best(s, str(value[0]), int(value[2])) >= int(value[1])
		"herbs_at_least":
			return s.herb_count() >= int(value)
		"met":
			return bool(s.world.people.get(value, {}).get("met", false))
		"relation_at_least":
			return int(s.world.people.get(value[0], {}).get("relation", 0)) >= int(value[1])
		"mind_at_least":
			return int(s.player.get("mind", 0)) >= int(value)
		# 心境 enough for the stage (or short of it, false).
		"mind_ready":
			return (int(s.player.get("mind", 0)) >= s.mind_needed()) == bool(value)
		"sense_at_least":
			return s.sense() >= int(value)
		"stage_at_least":
			return int(s.player.realm) > int(value[0]) or (int(s.player.realm) == int(value[0]) and int(s.player.stage) >= int(value[1]))
		"sect":
			return str(s.player.get("sect", "")) == value
		# [from, to] days of the month, both included: the full moon is the fifteenth.
		"month_day":
			var today := Calendar.day_of_month(int(s.world.day))
			return today >= int(value[0]) and today <= int(value[1])
		# The sect the player formally belongs to ("" for a wanderer).
		"affiliation":
			return str(s.player.get("affiliation", "")) == str(value)
		"talked":
			return int(s.world.people.get(value, {}).get("talks", 0)) > 0
		"at_location":
			return str(s.player.get("location", "")) == value
		"deed_at_least":
			return s.deed_count(value[0]) >= int(value[1])
		"story_at":
			return s.story_at(value[0], value[1])
		"story_state":
			return s.story_state(value[0]) == ("" if value[1] == "none" else value[1])
		"event_state":
			return str(s.world.events.get(value[0], {}).get("state", "")) == value[1]
		"event_applied":
			return applied(s, str(value))
		"talent":
			return s.has_talent(value)
		"rank_at_least":
			return int(s.player.get("rank", 0)) >= s.Sect.rank_index(s, value)
		"recipe":
			return s.Alchemy.knows(s, value)
	return false

static func apply(s, effects: Array) -> void:
	for effect: Dictionary in effects:
		var key: String = effect.keys()[0]
		var value: Variant = effect[key]
		match key:
			"stones":
				s.player.stones = maxi(0, int(s.player.stones) + int(value))
			"xp":
				# Gains stop at a bottleneck like cultivation does; losses never undo a stage.
				if int(value) >= 0:
					s.gain_xp(int(value))
				else:
					s.player.xp = maxi(0, int(s.player.xp) + int(value))
			"breach":
				s.breach()
			"mind":
				s.gain_mind(int(value))
			"contribution":
				s.Sect.gain(s, int(value))
			"start_story":
				s.start_story(value)
			"story_advance":
				s.story_advance(value)
			"sound":
				s.exchange_sound(value)
			"manual":
				s.add_item("j:" + s.Arsenal.generate_technique(s.content, s.world_rng, int(value)), 1)
			# A named slip (a handwritten technique: 《藏息录》).
			"slip":
				s.add_item("j:" + str(value), 1)
			# A 心法's slip of this tier in the first root's element (an 出身's family art).
			"method":
				var roots: Array = s.player.get("roots", [])
				var filters := {"slot": "method"}
				if not roots.is_empty():
					filters["element"] = str(roots[0])
				s.add_item("j:" + s.Arsenal.generate_technique(s.content, s.world_rng, int(value), filters), 1)
			# A piece of gear as named (an 出身's sword from home).
			"gear":
				s.add_item(str(value), 1)
			"reforge":
				s.Gear.reforge(s, str(value[0]), str(value[1]))
			"give_gear":
				s.Gear.give_up(s, str(value))
			"guest_invite":
				s.world.flags["guest_invite_" + str(value)] = true
			# A choice that ends the life (`final`): the ending's words.
			"end_life":
				s.ended = {"kind": "story", "day": int(s.world.day), "text": str(value)}
			# A sect's story: its seat given (门主), or the sect merged into another ("" disbands it).
			"sect_rank":
				s.Sect.raise_to(s, str(value))
			"close_sect":
				s.Sect.close(s, str(value[0]), str(value[1]))
			# 天南散修盟's word: 副盟主 ("deputy") or cast out ("ban"), and standing gained.
			"league":
				s.League.apply(s, str(value))
			"league_standing":
				s.League.gain(s, int(value))
			# The 天机阁's 批注 ([scroll, seat, words]), a 战帖 sent past whoever stood in the way, the
			# answer to a challenge, and the rival's turns (rival.gd).
			"tianji":
				s.Tianji.annotate(s, str(value[0]), int(value[1]), str(value[2]))
			"tianji_duel":
				s.Tianji.duel(s, str(value))
			"tianji_defend":
				s.Tianji.defend(s, str(value))
			"rival":
				s.Rival.apply(s, str(value))
			"talent":
				s.gain_talent(value)
			"demon":
				s.face_demon(value)
			"fortune":
				s.Fortune.bestow(s, value)
			"recipe":
				s.Alchemy.learn(s, value)
			"longevity":
				s.extend_life(str(value[0]), int(value[1]))
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
				if int(value[1]) < 0:
					s.Inventory.remove_family(s, str(value[0]), mini(-int(value[1]), s.pill_count(str(value[0]))))
					continue
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
			"clear_flag":
				s.world.flags.erase(value)
			"meet":
				s.mark_met(value)
			"relation":
				s.mark_met(value[0])
				var person := _person(s, value[0])
				# Talents for getting along change what is gained, never what is lost.
				var delta := int(value[1])
				if delta > 0:
					delta = s.Talents.scaled(delta, s.talent_modifier("favor"), 1)
				person.relation = clampi(int(person.relation) + delta, -s.content.FAVOR_MAX, s.content.FAVOR_MAX)
				# A 传音符 is exchanged once the bond is close enough (bonds.gd).
				var sound_at: int = s.Bonds.sound_at(s, value[0])
				if sound_at >= 0 and int(person.relation) >= sound_at:
					s.exchange_sound(value[0])
			"leave":
				s.npc_depart(s.acting_npc)
			"battle":
				s.begin_battle(value, "event")
			"pack":
				if not s.battle.is_empty():
					s.Combat.add_pack(s, value)
			"series":
				s.Series.begin(s, value)
			"mend_wound":
				s.player["wound_until"] = 0
			"deadly":
				if not s.battle.is_empty():
					s.battle.deadly = true
			"terms_search":
				s.Feuds.search(s)
			"terms_press":
				s.Feuds.press(s)
			"grudge_fight":
				s.Feuds.fight(s)
			"grudge_pay":
				s.Feuds.pay_off(s)
			"grudge_evade":
				s.Feuds.evade(s)
			"bounty_fight":
				s.Feuds.bounty_fight(s)
			"bounty_wait":
				s.Feuds.bounty_wait(s)
			"bounty_drop":
				s.Feuds.bounty_drop(s)
			"spar":
				s.begin_spar(s.acting_npc)
			"tournament":
				s.begin_tournament(1)
			"auction":
				s.Auctions.open(s, value)
			"summit":
				s.Summit.begin(s, 1)
			"contest":
				s.Rival.contest(s, str(value))
			"reset_cave":
				s.Caves.reset(s, value)
			# 秘境 (mijing.gd): opened and shut on their days, gone into by a way, and what is done inside.
			"mijing_open":
				s.Mijing.open(s, str(value))
			"mijing_close":
				s.Mijing.close(s, str(value))
			"mijing_enter":
				s.Mijing.enter(s, str(value[0]), str(value[1]))
			"mijing":
				s.Mijing.apply(s, str(value))
			# 鬼市 (guishi.gd): the shadow that followed the player out answered.
			"guishi":
				s.Guishi.apply(s, str(value))
			# 无相宝录 (wuxiang.gd): the well gone down, a page found or bought back, its gift, 影七's offer.
			"wuxiang":
				s.Wuxiang.apply(s, str(value))
			"party":
				if not s.world.has("party"):
					s.world["party"] = {}
				s.world.party[str(value[0])] = str(value[1])

static func _person(s, person_id: String) -> Dictionary:
	if not s.world.people.has(person_id):
		s.world.people[person_id] = {"met": false, "relation": 0, "last": {}, "absent_until": -1, "talks": 0, "met_day": -1, "met_place": ""}
	return s.world.people[person_id]

static func person(s, person_id: String) -> Dictionary:
	return _person(s, person_id)

static func _progress(s, event_id: String) -> Dictionary:
	if not s.world.events.has(event_id):
		s.world.events[event_id] = {"state": "", "count": 0, "last_day": -1, "last_occurrence": -1, "reminded": -1}
	return s.world.events[event_id]

## Completed scheduling is not proof that an event's effects actually occurred.
static func applied(s, event_id: String) -> bool:
	var progress: Dictionary = s.world.events.get(event_id, {})
	if progress.has("applied"):
		return bool(progress.applied)
	# Older saves keep dated world changes as permanent major chronicle entries.
	return s.chronicle.entries.any(func(entry: Dictionary) -> bool: return str(entry.id) == "event" and str(entry.args.get("event", "")) == event_id and str(entry.args.get("part", "")) == "chronicle")

static func progress_of(s, event_id: String) -> Dictionary:
	return s.world.events[event_id] if s.world.events.has(event_id) else {"state": "", "count": 0, "last_day": -1, "last_occurrence": -1, "reminded": -1}

## Whether the event may fire in `window` given its saved progress (not its conditions).
static func open_for(s, event_id: String, window: Dictionary, day: int) -> bool:
	var definition: Dictionary = s.content.events[event_id]
	var progress := progress_of(s, event_id)
	if definition.has("periodic"):
		return int(progress.last_occurrence) != int(window.occurrence)
	if definition.has("repeat"):
		return int(progress.last_day) < 0 or day >= int(progress.last_day) + int(definition.repeat.cooldown_days)
	return not str(progress.state) in STATES

## Counts the event as handled in this window without its own choices (an event entered by other means).
static func mark_fired(s, event_id: String, window: Dictionary, day: int) -> void:
	_mark_fired(s, event_id, window, day)

static func _mark_fired(s, event_id: String, window: Dictionary, day: int) -> void:
	var definition: Dictionary = s.content.events[event_id]
	var progress := _progress(s, event_id)
	progress["applied"] = true
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
	var obituary: Dictionary = s.next_obituary(from_day)
	if not obituary.is_empty():
		best = _earlier(best, {"day": int(obituary.day), "kind": "obituary", "event": obituary.id})
	var story: Dictionary = s.story_due(from_day)
	if not story.is_empty():
		best = _earlier(best, {"day": int(story.day), "kind": "story", "event": story.story})
	var bond: Dictionary = s.Bonds.next_due(s, from_day)
	if not bond.is_empty():
		best = _earlier(best, {"day": int(bond.day), "kind": str(bond.kind), "event": ""})
	for event_id: String in s.content.scheduled_events():
		var definition: Dictionary = s.content.events[event_id]
		var progress := progress_of(s, event_id)
		# Completed fixed windows cannot become due again. Avoid rebuilding their calendars.
		if str(progress.state) in STATES and not definition.has("periodic"):
			continue
		if definition.trigger == "date" and definition.has("periodic"):
			var held: Dictionary = _due_windows.get(event_id, {})
			if held.is_empty() or from_day < int(held.lo) or from_day > int(held.to) or int(held.last) != int(progress.last_occurrence):
				var found := window_at(definition, from_day)
				if found.is_empty() or not open_for(s, event_id, found, from_day):
					found = next_window(definition, from_day + 1) if not found.is_empty() else next_window(definition, from_day)
				held = {"lo": from_day, "from": int(found.from), "to": int(found.to), "last": int(progress.last_occurrence)}
				_due_windows[event_id] = held
			best = _earlier(best, {"day": maxi(from_day, int(held.from)), "kind": "date", "event": event_id})
			continue
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
	var lease: Dictionary = s.Leases.next_end(s, from_day)
	if not lease.is_empty():
		best = _earlier(best, {"day": int(lease.day), "kind": "lease_end", "event": str(lease.flag)})
	# Last, so on a shared day the appointment's own reminder is told before the retreat ends for it.
	for wake: Dictionary in s.player.get("wake", []):
		best = _earlier(best, {"day": maxi(from_day, int(wake.day)), "kind": "wake", "event": str(wake.event)})
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
		"obituary":
			var progress := _person(s, due.event)
			progress.mourned = true
			s.obituaries_changed()
			var life: Dictionary = s.life_by_id(due.event)
			if str(s.world.get("companion", "")) == str(due.event):
				return {"interrupt": true, "message": s.log_event("companion_gone", {"npc": due.event}, true)}
			return {"interrupt": false, "message": s.log_event("obituary", {"npc": due.event, "age": (int(life.death) - int(life.birth)) / 360})}
		"story":
			return s.story_fire(due.event)
		"wake":
			s.player.wake = s.player.wake.filter(func(wake: Dictionary) -> bool: return str(wake.event) != str(due.event))
			return {"interrupt": true, "message": s.log_event("wake", {"event": due.event})}
		"lease_end":
			return {"interrupt": true, "message": s.Leases.end(s, str(due.event))}
		"visits":
			return {"interrupt": false, "message": " ".join(s.Bonds.write_letters(s))}
		"loan":
			return {"interrupt": false, "message": " ".join(s.Bonds.settle_loans(s))}
		"lifespan_end":
			# Once in a life the end waits on a choice: to sit in peace, or to defy fate.
			if not s.player.get("longevity", {}).has("defied"):
				s.ended = {"kind": "lifespan", "day": day, "choice": true}
				return {"interrupt": true, "message": s.log_event("lifespan_brink", {}, true)}
			s.ended = {"kind": "lifespan", "day": day}
			return {"interrupt": true, "message": s.log_event("lifespan_end", {"location": s.player.location, "age": s.age()}, true)}
		"date":
			var definition: Dictionary = s.content.events[due.event]
			var window := window_at(definition, day)
			if window.is_empty():
				window = {"occurrence": -2}
			_mark_fired(s, due.event, window, day)
			if not all_met(s, definition.get("conditions", [])):
				_progress(s, due.event)["applied"] = false
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
	for event_id: String in s.content.location_events(s.player.location):
		var definition: Dictionary = s.content.events[event_id]
		if passing and definition.has("choices"):
			continue
		var group: String = definition.get("group", "")
		if not group.is_empty() and used_groups.has(group):
			continue
		var window := window_at(definition, day)
		if window.is_empty() or venue(definition, window) != str(s.player.location) or not open_for(s, event_id, window, day) or not all_met(s, definition.get("conditions", [])):
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
	# Stopping somewhere means seeing who is there (after first-meeting stories have had their say), and
	# perhaps finding an outlaw the player hunts (feuds.gd).
	if not passing:
		s.meet_present()
		s.Feuds.update(s)
		s.Feuds.collect_stash(s)
		s.Feuds.check_bounties(s)
		s.Tianji.check(s)
		s.Mijing.check(s)
		s.Guishi.check(s)
		s.Wuxiang.check(s)
	return messages

## Whether the pending event offers a choice that would end the life (`final`), so the interface writes
## a 抉择前 save before it is made.
static func final_pending(s) -> bool:
	if s.pending_event.is_empty():
		return false
	return s.content.events.get(str(s.pending_event.id), {}).get("choices", []).any(func(choice: Dictionary) -> bool: return bool(choice.get("final", false)))

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
		# An event raised with its own values (who waylays the player, whom they hunt) tells them on.
		var args := {"event": event_id, "part": "choice", "choice": choice_id}
		var raised: Dictionary = s.pending_event
		apply(s, choice.get("effects", []))
		args.merge(raised.get("values", {}))
		# A choice may raise the next event itself (rival.gd: the pill before 天南大比); that one stays.
		if is_same(s.pending_event, raised):
			s.pending_event = {}
		var text: String = s.log_event("event", args, bool(definition.get("major", false)))
		# Living through an encounter, whatever the choice, is insight toward the next bottleneck.
		var milestones: Array[String] = []
		if not (event_id.begins_with("humble_") and choice_id == "later"):
			milestones = s.gain_insight("event")
		var follow := check_location(s)
		return " ".join([text] + milestones + follow)
	return "没有这个选项。"

## Danger left after the player's realm: each realm above the first takes one level off.
static func effective_danger(s, route: Dictionary) -> int:
	return maxi(0, int(route.danger) - int(s.player.realm))

static func encounter_chance(s, route: Dictionary) -> float:
	return s.Talents.chance(float(s.content.rules.encounter_chance[effective_danger(s, route)]), s.talent_modifier("encounter") + int(round(float(s.bonuses().encounter) * 100.0)))

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

## The appointments the player chose, before a retreat, to leave it for. Only these and the lifespan's
## alarms end a retreat early; other news waits in 任务 · 消息 (docs/WORLD_EXPANSION.md 7.6, item 42).
## player.wake: [{"event", "day"}] where day is the appointment's opening day.
static func wakes_for(s, event_id: String) -> bool:
	return s.player.get("wake", []).any(func(wake: Dictionary) -> bool: return str(wake.event) == event_id)

## Marks or clears an upcoming appointment to leave a retreat for. Only an appointment still ahead can
## be marked; one already open would end the retreat on its first day.
static func set_wake(s, event_id: String, on: bool) -> void:
	var kept: Array = s.player.get("wake", []).filter(func(wake: Dictionary) -> bool: return str(wake.event) != event_id)
	if on:
		for entry: Dictionary in upcoming(s):
			if entry.event == event_id and int(entry.from) > int(s.world.day):
				kept.append({"event": event_id, "day": int(entry.from)})
	kept.sort_custom(func(a: Dictionary, b: Dictionary) -> bool: return int(a.day) < int(b.day))
	s.player.wake = kept

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
	# Recurring occasions the player should plan for (潜龙会, 兽潮) and may take part in: the open window
	# not yet taken part in, or the next one within a year.
	for event_id: String in s.content.events:
		var definition: Dictionary = s.content.events[event_id]
		if not bool(definition.get("listed", false)) or not definition.has("periodic") or not all_met(s, definition.get("conditions", [])):
			continue
		var window := window_at(definition, day)
		if window.is_empty() or not open_for(s, event_id, window, day):
			window = next_window(definition, day + 1)
		if window.is_empty() or int(window.from) - day > Calendar.DAYS_PER_YEAR:
			continue
		result.append({"event": event_id, "from": int(window.from), "to": int(window.to), "title": definition.title, "location": venue(definition, window)})
	result.sort_custom(func(a: Dictionary, b: Dictionary) -> bool: return a.from < b.from)
	return result
