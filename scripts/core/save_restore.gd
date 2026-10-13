extends RefCounted
## Restores a Session from save data: upgrades older versions first, then validates everything before
## changing the session, so a malformed save leaves the current journey untouched.
const Calendar = preload("res://scripts/core/calendar.gd")
const Chronicle = preload("res://scripts/core/chronicle.gd")
const SaveMigration = preload("res://scripts/core/save_migration.gd")
const Cultivation = preload("res://scripts/core/cultivation.gd")
const Talents = preload("res://scripts/core/talents.gd")
const PLAYER_COUNTS := ["realm", "xp", "hp", "qi", "stones", "cultivation_carry", "fatigue", "fatigue_day", "insight"]
const LIMIT := 1000000000.0

static func restore(s, data: Variant) -> bool:
	if not data is Dictionary:
		return false
	var saved: Dictionary = SaveMigration.migrate(data)
	if saved.is_empty() or int(saved.version) != SaveMigration.CURRENT_VERSION:
		return false
	var content = s.content
	var saved_world: Variant = saved.get("world")
	var saved_player: Variant = saved.get("player")
	var saved_battle: Variant = saved.get("battle")
	var saved_pending: Variant = saved.get("pending_event")
	var saved_ended: Variant = saved.get("ended")
	var saved_rng: Variant = saved.get("rng")
	for part: Variant in [saved_world, saved_player, saved_battle, saved_pending, saved_ended, saved_rng]:
		if not part is Dictionary:
			return false
	if not _whole_nonnegative(saved_world.get("day")) or not saved_world.get("flags") is Dictionary:
		return false
	if not saved_world.get("events") is Dictionary or not saved_world.get("people") is Dictionary:
		return false
	var day := int(saved_world.day)
	for flag: Variant in saved_world.flags:
		if not flag is String or not saved_world.flags[flag] is bool:
			return false
	var events: Variant = _valid_event_progress(saved_world.events)
	var people: Variant = _valid_people(content, saved_world.people, day)
	if events == null or people == null:
		return false
	if not saved_player.get("name") is String or not saved_player.get("location") is String or not content.locations.has(saved_player.location):
		return false
	for key: String in PLAYER_COUNTS:
		if not _whole_nonnegative(saved_player.get(key)):
			return false
	if int(saved_player.cultivation_carry) >= Cultivation.CARRY_UNIT:
		return false
	if int(saved_player.fatigue_day) > day or int(saved_player.insight) > Cultivation.insight_needed(s):
		return false
	# The mind (心境): optional, since saves before it lack it.
	var mind: Variant = saved_player.get("mind", -1)
	if not _whole_signed(mind) or int(mind) < -1:
		return false
	var birth: Variant = saved_player.get("birth_day")
	if not _whole_signed(birth) or int(birth) > day:
		return false
	var warned: Variant = saved_player.get("warned_for")
	if not _whole_signed(warned) or int(warned) < -1:
		return false
	var items: Variant = saved_player.get("items")
	if not items is Dictionary:
		return false
	var journey: Variant = saved_player.get("journey")
	if not journey is Dictionary or (not journey.is_empty() and (not journey.get("to") is String or not content.location_visible(journey.to, saved_world.flags))):
		return false
	var cooldowns: Variant = saved_player.get("cooldowns")
	if not cooldowns is Dictionary:
		return false
	for action_id: Variant in cooldowns:
		if not action_id is String or not _whole_nonnegative(cooldowns[action_id]):
			return false
	if not content.location_visible(saved_player.location, saved_world.flags):
		return false
	for item_id: Variant in items:
		if not item_id is String or not _whole_nonnegative(items[item_id]) or int(items[item_id]) < 1:
			return false
	if int(saved_player.realm) >= content.realms.size():
		return false
	# The sub-stage always follows from xp; stat caps follow from the stage.
	# Older saves follow from xp; since version 11 the stage is kept, because xp may wait at a bottleneck
	# (never above the next threshold).
	var saved_stage: int = content.stage_index(int(saved_player.realm), int(saved_player.xp))
	if saved_player.has("stage"):
		var stages: Array = content.realm(int(saved_player.realm)).stages
		if not _whole_nonnegative(saved_player.stage) or int(saved_player.stage) >= stages.size():
			return false
		saved_stage = int(saved_player.stage)
		if saved_stage + 1 < stages.size() and int(saved_player.xp) > int(stages[saved_stage + 1].xp):
			return false
	var loadout := _valid_loadout(content, saved_player)
	if loadout.is_empty():
		return false
	var quests: Variant = _valid_quests(content, saved_player.get("quests"))
	if quests == null:
		return false
	var rumors := {}
	for key: Variant in saved_world.get("rumors", {}):
		if not key is String or not _whole_nonnegative(saved_world.rumors[key]):
			return false
		rumors[key] = int(saved_world.rumors[key])
	var taken := {}
	for key: Variant in saved_world.get("quests_taken", {}):
		if not key is String:
			return false
		taken[key] = true
	var storylines: Variant = _valid_storylines(content, saved_world.get("storylines", {}), day)
	var letters: Variant = _valid_letters(content, saved_world.get("letters", []), day)
	var deeds: Variant = _valid_counts(saved_player.get("deeds", {}))
	var taught: Variant = saved_player.get("taught", [])
	if storylines == null or letters == null or deeds == null or not taught is Array or taught.any(func(tip: Variant) -> bool: return not tip is String):
		return false
	var progress: Variant = _valid_breakthrough(content, saved_player, saved_pending)
	var standing: Variant = _valid_standing(content, saved_player, day)
	if progress == null or standing == null:
		return false
	# Talents: optional, since saves before them lack them; then they awaken from the world seed.
	var born: Variant = _valid_talents(content, saved_player)
	if born == null:
		return false
	var awakened: bool = born.is_empty()
	if awakened:
		var rng := RandomNumberGenerator.new()
		rng.seed = hash([int(saved_world.get("seed", 0)), "awaken"])
		born = Talents.roll(content, rng, str(content.talent_data.player.table))
	# Health and qi within the caps the save was made with (before any talents awakened).
	var holder: Dictionary = loadout.duplicate()
	holder.merge({"realm": int(saved_player.realm), "stage": saved_stage, "talents": [] if awakened else born.talents, "flaws": [] if awakened else born.flaws, "foundation_grade": int(progress.foundation_grade)}, true)
	var saved_caps: Dictionary = s.stat_caps(holder)
	if int(saved_player.hp) <= 0 or int(saved_player.hp) > int(saved_caps.max_hp) or int(saved_player.qi) > int(saved_caps.max_qi):
		return false
	holder.merge({"talents": born.talents, "flaws": born.flaws}, true)
	var caps: Dictionary = s.stat_caps(holder)
	var roots: Variant = saved_player.get("roots")
	if not roots is Array or roots.is_empty() or roots.size() > content.rules.spirit_roots.elements.size():
		return false
	for element: Variant in roots:
		if not element in content.rules.spirit_roots.elements or roots.count(element) != 1:
			return false
	var saved_sect: Variant = saved_player.get("sect")
	if not saved_sect is String or not content.sects.has(saved_sect):
		return false
	if not saved_battle.is_empty():
		if not saved_battle.get("enemy_id") is String or not content.enemies.has(saved_battle.enemy_id):
			return false
		var foe: Variant = saved_battle.get("foe", {})
		if not foe is Dictionary or (not foe.is_empty() and (not _whole_nonnegative(foe.get("hp")) or not _whole_nonnegative(foe.get("damage_min")) or not _whole_nonnegative(foe.get("damage_max")) or not foe.get("name") is String)):
			return false
		# Saves before duel looks lack the foe's sect and gender; the stage then uses the shared sprite.
		if foe.has("sect") and (not foe.sect is String or not content.sects.has(foe.sect)):
			return false
		if foe.has("gender") and not foe.gender in ["male", "female"]:
			return false
		# Saves before duel backdrops lack the place; the stage then uses the shared background.
		var place: Variant = saved_battle.get("place", "road")
		if not place is String or (place != "road" and not content.locations.has(place)):
			return false
		var hp_cap: int = int(foe.hp) if not foe.is_empty() else int(content.enemies[saved_battle.enemy_id].hp)
		if not _whole_nonnegative(saved_battle.get("hp")) or int(saved_battle.hp) <= 0 or int(saved_battle.hp) > hp_cap:
			return false
		if not _whole_nonnegative(saved_battle.get("turn")) or int(saved_battle.turn) < 1 or not saved_battle.get("cooldowns") is Dictionary:
			return false
		for skill_id: Variant in saved_battle.cooldowns:
			if not skill_id is String or content.technique(skill_id).is_empty() or not _whole_nonnegative(saved_battle.cooldowns[skill_id]):
				return false
		if saved_battle.has("context") and not saved_battle.context in ["event", "spar", "tournament"]:
			return false
		var status: Variant = saved_battle.get("status", {})
		if not status is Dictionary:
			return false
		for key: Variant in status:
			if not key in ["burn", "weaken"] or not status[key] is Array or status[key].size() != 2:
				return false
		if saved_battle.has("npc") and (not saved_battle.npc is String or not s.is_person(saved_battle.npc)):
			return false
		var opponent: Variant = saved_battle.get("opponent_sect")
		if not opponent is String or not content.sects.has(opponent):
			return false
	if not saved_pending.is_empty():
		var pending_id: Variant = saved_pending.get("id")
		if not pending_id is String or not content.events.has(pending_id) or not content.events[pending_id].has("choices"):
			return false
		if not _whole_nonnegative(saved_pending.get("day")) or int(saved_pending.day) != day or not saved_battle.is_empty():
			return false
	if not saved_ended.is_empty():
		if saved_ended.get("kind") != "lifespan" or not _whole_nonnegative(saved_ended.get("day")) or int(saved_ended.day) > day:
			return false
	for stream: String in ["combat", "world"]:
		if not saved_rng.get(stream) is String or not saved_rng[stream].is_valid_int():
			return false
	var saved_chronicle: Variant = Chronicle.parse(saved.get("chronicle"), day)
	if saved_chronicle == null:
		return false
	var sold := {}
	for key: Variant in saved_world.get("stock_sold", {}):
		if key is String:
			sold[key] = true
	var seed_value: Variant = saved_world.get("seed", 0)
	var shaped: Variant = saved_world.get("talent_lives", false)
	if not shaped is bool:
		return false
	var bonds: Variant = _valid_bonds(s, content, saved_world, day)
	if bonds == null:
		return false
	s.world = {"day": day, "flags": saved_world.flags.duplicate(), "events": events, "people": people, "seed": int(seed_value) if _whole_nonnegative(seed_value) else 0, "stock_sold": sold, "rumors": rumors, "quests_taken": taken, "storylines": storylines, "letters": letters, "talent_lives": shaped, "invites": bonds.invites, "loans": bonds.loans, "visit_period": bonds.visit_period}
	s.populate()
	var player: Dictionary = saved_player.duplicate(true)
	for key: String in PLAYER_COUNTS:
		player[key] = int(player[key])
	player.birth_day = int(birth)
	player.stage = saved_stage
	# Journeys from before the mind start with what their stage asks, so nothing they had slows down.
	player["mind"] = int(mind) if int(mind) >= 0 else int(content.stage(int(saved_player.realm), saved_stage).get("mind", 0))
	player.roots = roots.duplicate()
	for key: String in loadout:
		player[key] = loadout[key]
	player.quests = quests
	player["deeds"] = deeds
	player["taught"] = taught.duplicate()
	player["talents"] = born.talents.duplicate()
	player["flaws"] = born.flaws.duplicate()
	for key: String in progress:
		player[key] = progress[key]
	for key: String in standing:
		player[key] = standing[key]
	if not progress.has("attempt"):
		player.erase("attempt")
	# Health and qi stay within the caps; talents that awaken may lower them.
	player.hp = mini(int(player.hp), int(caps.max_hp))
	player.qi = mini(int(player.qi), int(caps.max_qi))
	player.warned_for = int(warned)
	for item_id: String in player.items:
		player.items[item_id] = int(player.items[item_id])
	player.journey = {} if journey.is_empty() else {"to": journey.to}
	for action_id: String in player.cooldowns:
		player.cooldowns[action_id] = int(player.cooldowns[action_id])
	s.player = player
	s.refresh_realm_stats()
	# The fatigue limit depends on the realm, so it is applied once the player is in place.
	player.fatigue = mini(int(player.fatigue), Cultivation.fatigue_cap(s))
	var battle: Dictionary = saved_battle.duplicate(true)
	if not battle.is_empty():
		if not battle.has("status"):
			battle.status = {}
		battle.hp = int(battle.hp)
		battle.turn = int(battle.turn)
		for skill_id: String in battle.cooldowns:
			battle.cooldowns[skill_id] = int(battle.cooldowns[skill_id])
	s.battle = battle
	s.pending_event = {} if saved_pending.is_empty() else {"id": saved_pending.id, "day": int(saved_pending.day)}
	s.ended = {} if saved_ended.is_empty() else {"kind": saved_ended.kind, "day": int(saved_ended.day)}
	s.chronicle.entries = saved_chronicle
	s.combat_rng.state = int(saved_rng.combat)
	s.world_rng.state = int(saved_rng.world)
	s.combat_events.clear()
	if awakened:
		s.log_event("talents_awaken", {"talents": ",".join(born.talents + born.flaws)}, true)
	s.changed.emit()
	return true

## The breakthrough's saved progress, normalized: the foundation's grade (a middling one for journeys
## founded before grades), an injury, lessons, fortune met, and an attempt waiting on 心魔 (only while
## that choice is pending). Null when malformed.
static func _valid_breakthrough(content, saved_player: Dictionary, saved_pending: Dictionary) -> Variant:
	var rules: Dictionary = content.rules.breakthrough
	var result := {}
	var grade: Variant = saved_player.get("foundation_grade", 1)
	if not _whole_nonnegative(grade) or int(grade) >= rules.grades.size():
		return null
	result["foundation_grade"] = int(grade)
	var injury: Variant = saved_player.get("injury_until", 0)
	var lessons: Variant = saved_player.get("lessons", 0)
	if not _whole_nonnegative(injury) or not _whole_nonnegative(lessons) or int(lessons) > int(rules.lesson.most):
		return null
	result["injury_until"] = int(injury)
	result["lessons"] = int(lessons)
	var boons: Variant = saved_player.get("boons", {})
	if not boons is Dictionary:
		return null
	var kept := {}
	for id: Variant in boons:
		if not id is String or not id in content.boon_ids() or not boons[id] in ["ready", "spent"]:
			return null
		kept[id] = str(boons[id])
	result["boons"] = kept
	var waiting: bool = str(saved_pending.get("id", "")) == "heart_demon"
	var attempt: Variant = saved_player.get("attempt", null)
	if waiting != (attempt != null):
		return null
	if attempt != null:
		if not attempt is Dictionary or not _whole_nonnegative(attempt.get("odds")) or int(attempt.odds) > 100 or not attempt.get("certain") is bool or not _whole_nonnegative(attempt.get("steps")) or not _whole_nonnegative(attempt.get("xp")) or not attempt.get("guard") is String:
			return null
		result["attempt"] = {"odds": int(attempt.odds), "certain": attempt.certain, "steps": int(attempt.steps), "xp": int(attempt.xp), "guard": attempt.guard}
	return result

## Friends' open appointments and requests, silver lent, and the last period letters were written in
## (optional: saves before them have none, and letters start from the period of loading). Invites
## from people no longer known are dropped; anything malformed is null.
static func _valid_bonds(s, content, saved_world: Dictionary, day: int) -> Variant:
	var kinds: Dictionary = content.bonds_data.visits.kinds
	var invites: Array = []
	var saved_invites: Variant = saved_world.get("invites", [])
	if not saved_invites is Array:
		return null
	for invite: Variant in saved_invites:
		if not invite is Dictionary or not invite.get("id") is String or not invite.get("npc") is String or not kinds.has(invite.get("kind", "")) or not _whole_nonnegative(invite.get("made")) or int(invite.made) > day:
			return null
		if invite.has("deadline") and not _whole_nonnegative(invite.deadline):
			return null
		if invite.has("item") and content.item(str(invite.item)).is_empty():
			return null
		if invite.has("place") and not content.locations.has(str(invite.place)):
			return null
		for key: String in ["count", "amount"]:
			if invite.has(key) and not _whole_nonnegative(invite[key]):
				return null
		if not s.is_person(invite.npc):
			continue
		var kept: Dictionary = invite.duplicate()
		for key: String in ["made", "deadline", "count", "amount"]:
			if kept.has(key):
				kept[key] = int(kept[key])
		invites.append(kept)
	var loans: Array = []
	var saved_loans: Variant = saved_world.get("loans", [])
	if not saved_loans is Array:
		return null
	for loan: Variant in saved_loans:
		if not loan is Dictionary or not loan.get("npc") is String or not _whole_nonnegative(loan.get("amount")) or not _whole_nonnegative(loan.get("repay")) or not _whole_nonnegative(loan.get("due")):
			return null
		if s.is_person(loan.npc):
			loans.append({"npc": loan.npc, "amount": int(loan.amount), "repay": int(loan.repay), "due": int(loan.due)})
	var period: Variant = saved_world.get("visit_period", day / int(content.bonds_data.visits.period_days))
	if not _whole_nonnegative(period):
		return null
	return {"invites": invites, "loans": loans, "visit_period": int(period)}

## The player's standing in the sect, normalized (optional fields default to an outer disciple with
## nothing yet), or null when malformed.
static func _valid_standing(content, saved_player: Dictionary, day: int) -> Variant:
	var result := {}
	var rank: Variant = saved_player.get("rank", 0)
	if not _whole_nonnegative(rank) or int(rank) >= content.sect_data.ranks.size():
		return null
	result["rank"] = int(rank)
	for key: String in ["contribution", "merit"]:
		var value: Variant = saved_player.get(key, 0)
		if not _whole_nonnegative(value):
			return null
		result[key] = int(value)
	var stipend_day: Variant = saved_player.get("stipend_day", day)
	if not _whole_signed(stipend_day) or int(stipend_day) > day:
		return null
	result["stipend_day"] = int(stipend_day)
	var exchanged: Variant = _valid_counts(saved_player.get("exchanged", {}))
	if exchanged == null:
		return null
	result["exchanged"] = exchanged
	var donated: Variant = saved_player.get("donated", {})
	if not donated is Dictionary or (not donated.is_empty() and (not _whole_nonnegative(donated.get("period")) or not _whole_nonnegative(donated.get("amount")))):
		return null
	result["donated"] = {} if donated.is_empty() else {"period": int(donated.period), "amount": int(donated.amount)}
	return result

## The saved talents and flaws ({"talents", "flaws"}), {} when the save has none yet, or null when they
## are malformed: unknown ids, a flaw among the talents or the other way round, or the same one twice.
static func _valid_talents(content, saved_player: Dictionary) -> Variant:
	if not saved_player.has("talents"):
		return {}
	var result := {}
	for key: String in ["talents", "flaws"]:
		var list: Variant = saved_player.get(key, [])
		if not list is Array:
			return null
		var kept: Array = []
		for id: Variant in list:
			if not content.is_talent(id) or Talents.is_flaw(content, id) != (key == "flaws") or id in kept:
				return null
			kept.append(id)
		result[key] = kept
	return result

## Normalized copy of saved event progress, or null. Progress for events no longer in content is kept.
static func _valid_event_progress(data: Dictionary) -> Variant:
	var result := {}
	for event_id: Variant in data:
		var progress: Variant = data[event_id]
		if not event_id is String or not progress is Dictionary or not str(progress.get("state", "")) in ["", "completed", "expired"]:
			return null
		var normalized := {"state": str(progress.get("state", ""))}
		for key: String in ["count", "last_day", "last_occurrence", "reminded"]:
			if not _whole_signed(progress.get(key)) or int(progress[key]) < -1:
				return null
			normalized[key] = int(progress[key])
		result[event_id] = normalized
	return result

static func _valid_people(content, data: Dictionary, day: int) -> Variant:
	var result := {}
	for person_id: Variant in data:
		var person: Variant = data[person_id]
		if not person_id is String or not person is Dictionary or not person.get("met") is bool or not _whole_signed(person.get("relation")):
			return null
		if absi(int(person.relation)) > content.FAVOR_MAX or not person.get("last") is Dictionary:
			return null
		if not _whole_signed(person.get("absent_until")) or int(person.absent_until) < -1 or not _whole_nonnegative(person.get("talks")):
			return null
		var last := {}
		for option_id: Variant in person.last:
			if not option_id is String or not _whole_nonnegative(person.last[option_id]):
				return null
			last[option_id] = int(person.last[option_id])
		# When and where they were met: optional (saves before 2026-10-12 lack it), -1 and "" when unknown.
		var met_day: Variant = person.get("met_day", -1)
		var met_place: Variant = person.get("met_place", "")
		if not _whole_signed(met_day) or int(met_day) < -1 or int(met_day) > day or not met_place is String or not (met_place.is_empty() or content.locations.has(met_place)):
			return null
		result[person_id] = {"met": person.met, "relation": int(person.relation), "last": last, "absent_until": int(person.absent_until), "talks": int(person.talks), "met_day": int(met_day), "met_place": met_place}
		var mourned: Variant = person.get("mourned", false)
		if mourned is bool and mourned:
			result[person_id].mourned = true
		# Whether 传音符 were exchanged: optional, saves before version 12 lack it.
		var sound: Variant = person.get("sound", false)
		if not sound is bool:
			return null
		if sound:
			result[person_id]["sound"] = true
	return result

## Normalized storyline progress, or null when malformed. Progress of storylines no longer in the
## content is dropped.
static func _valid_storylines(content, data: Variant, day: int) -> Variant:
	if not data is Dictionary:
		return null
	var result := {}
	for story_id: Variant in data:
		var saved: Variant = data[story_id]
		if not story_id is String or not saved is Dictionary or not str(saved.get("state", "")) in ["active", "done", "closed"]:
			return null
		if not _whole_nonnegative(saved.get("step")) or not _whole_nonnegative(saved.get("since")) or int(saved.since) > day or not saved.get("begun") is bool:
			return null
		var base: Variant = _valid_counts(saved.get("base", {}))
		if base == null:
			return null
		if not content.storylines.has(story_id):
			continue
		var steps := int(content.storylines[story_id].steps.size())
		if int(saved.step) > steps or (saved.state == "active" and int(saved.step) >= steps):
			return null
		result[story_id] = {"state": saved.state, "step": int(saved.step), "since": int(saved.since), "begun": saved.begun, "base": base}
	return result

## Normalized 传音, or null when malformed. Letters about storylines no longer in the content are dropped.
static func _valid_letters(content, data: Variant, day: int) -> Variant:
	if not data is Array:
		return null
	var result: Array = []
	for letter: Variant in data:
		if not letter is Dictionary or not letter.get("npc") is String or not _whole_nonnegative(letter.get("day")) or int(letter.day) > day or not letter.get("read") is bool:
			return null
		if not content.people.has(letter.npc):
			continue
		if letter.has("story"):
			if not letter.story is String or not letter.get("step") is String:
				return null
			if not content.storylines.has(letter.story):
				continue
			result.append({"npc": letter.npc, "day": int(letter.day), "read": letter.read, "story": letter.story, "step": letter.step})
		elif letter.get("kind") is String:
			result.append({"npc": letter.npc, "day": int(letter.day), "read": letter.read, "kind": letter.kind})
		else:
			return null
	return result

## A dictionary of names to whole non-negative counts (deeds), normalized, or null.
static func _valid_counts(data: Variant) -> Variant:
	if not data is Dictionary:
		return null
	var result := {}
	for key: Variant in data:
		if not key is String or not _whole_nonnegative(data[key]):
			return null
		result[key] = int(data[key])
	return result

static func _whole_nonnegative(value: Variant) -> bool:
	return _whole_signed(value) and float(value) >= 0.0

static func _whole_signed(value: Variant) -> bool:
	if not (value is int or value is float):
		return false
	return is_finite(float(value)) and float(value) == floor(float(value)) and absf(float(value)) <= LIMIT

## The saved techniques and equipment, keeping only what the content still knows. {} when malformed.
## Unknown ids are dropped instead of rejecting the save, so retired content cannot lock a journey.
static func _valid_loadout(content, saved_player: Dictionary) -> Dictionary:
	for key: String in ["learned", "arts", "methods"]:
		if not saved_player.get(key) is Array:
			return {}
	if not saved_player.get("equipment") is Dictionary:
		return {}
	var learned: Array = []
	for technique_id: Variant in saved_player.learned:
		if technique_id is String and not content.technique(technique_id).is_empty() and not technique_id in learned:
			learned.append(technique_id)
	var arts: Array = []
	var methods: Array = []
	for pair: Array in [["arts", arts, "art", int(content.rules.art_slots)], ["methods", methods, "method", int(content.rules.method_slots)]]:
		for technique_id: Variant in saved_player[pair[0]]:
			if technique_id in learned and content.technique(technique_id).slot == pair[2] and not technique_id in pair[1] and pair[1].size() < pair[3]:
				pair[1].append(technique_id)
	if arts.is_empty():
		# Older journeys knew exactly their lineage's three arts.
		var lineage: String = saved_player.get("sect", "wanderer") if content.sects.has(saved_player.get("sect", "")) else "wanderer"
		for skill_id: String in content.sects[lineage].skills:
			if not skill_id in learned:
				learned.append(skill_id)
			arts.append(skill_id)
	var equipment := {}
	for slot: String in content.equipment_data.slots:
		var worn: Variant = saved_player.equipment.get(slot, "")
		var gear: Dictionary = content.equipment(str(worn)) if worn is String else {}
		equipment[slot] = worn if not gear.is_empty() and gear.slot == slot else ""
	return {"learned": learned, "arts": arts, "methods": methods, "equipment": equipment}

## Normalized accepted commissions, or null when malformed. Quests of retired kinds are dropped.
static func _valid_quests(content, data: Variant) -> Variant:
	if not data is Array:
		return null
	var result: Array = []
	for quest: Variant in data:
		if not quest is Dictionary or not quest.get("key") is String or not quest.get("reward") is Dictionary:
			return null
		for key: String in ["count", "days", "deadline", "progress"]:
			if not _whole_nonnegative(quest.get(key)):
				return null
		if not content.commission_data.templates.has(quest.get("kind", "")) or not content.commission_data.boards.has(quest.get("board", "")):
			continue
		if quest.has("item") and content.item(str(quest.item)).is_empty():
			continue
		if quest.has("enemy") and not content.enemies.has(quest.enemy):
			continue
		if quest.has("place") and not content.locations.has(quest.place):
			continue
		var normalized: Dictionary = quest.duplicate(true)
		for key: String in ["count", "days", "deadline", "progress"]:
			normalized[key] = int(normalized[key])
		# Commissions from before contribution pay none.
		normalized.reward = {"stones": int(quest.reward.get("stones", 0)), "xp": int(quest.reward.get("xp", 0)), "contribution": int(quest.reward.get("contribution", 0))}
		result.append(normalized)
	return result
