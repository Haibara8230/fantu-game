extends RefCounted
## Storylines: the guided start and the stories of key people, after Mi Chang Sheng's 引导任务 and
## 师门任务. Operates on a Session. Definitions live in data/storylines.json; progress in
## world.storylines[id] = {"state", "step", "since", "begun", "base"}.
## A storyline runs its steps in order. A step begins once its `requires` hold: its words (`say`) are
## told then, in person or, with `letter`, as a 传音 that ends a retreat. It is done when its `done`
## conditions hold and its `deeds` have been done since it began, after `wait_days`, or when a person's
## interaction advances it (effect story_advance); then its `effects` apply and its `after` words are
## told. `close_if` on the storyline or on a step closes it unfinished; a step whose `skip_if` holds
## before it begins passes unspoken. A storyline starts by an effect
## (start_story) or by itself once its `begin_if` holds.
## The guided storyline (`guide`) holds the player to its current step: travel only toward the step's
## place, retreats only where the step allows them, and no ambushes on the road meanwhile.
const Events = preload("res://scripts/core/events.gd")
const STATES := ["active", "done", "closed"]
# Updates that keep finding something to do are cut off here; content checks keep real chains short.
const MAX_ROUNDS := 64

static func definitions(s) -> Dictionary:
	return s.content.storylines

static func progress(s, story_id: String) -> Dictionary:
	return s.world.get("storylines", {}).get(story_id, {})

## "", "active", "done" or "closed".
static func state(s, story_id: String) -> String:
	return str(progress(s, story_id).get("state", ""))

## The current step's definition while the storyline is active, or {}.
static func current_step(s, story_id: String) -> Dictionary:
	var saved := progress(s, story_id)
	if str(saved.get("state", "")) != "active":
		return {}
	var steps: Array = definitions(s)[story_id].steps
	var index := int(saved.step)
	return steps[index] if index < steps.size() else {}

## Serialize a stable step ID alongside the legacy index, without changing live progress.
static func saved_world(s) -> Dictionary:
	var world: Dictionary = s.world.duplicate(true)
	for story_id: String in world.get("storylines", {}):
		var saved: Dictionary = world.storylines[story_id]
		var steps: Array = definitions(s).get(story_id, {}).get("steps", [])
		var index := int(saved.step)
		saved["step_id"] = str(steps[index].id) if index < steps.size() else ""
	return world

## Consumable items requested by the current begun step, shared by UI, selling and playtests.
## A possession threshold without a consuming effect is not a delivery cost.
static func required_items(s, story_id: String) -> Dictionary:
	var step := current_step(s, story_id)
	if step.is_empty() or not bool(progress(s, story_id).get("begun", false)):
		return {}
	var required := _consumed(step.get("effects", []))
	for person_id: String in s.content.people:
		for interaction: Dictionary in s.content.people[person_id].get("interactions", []):
			var belongs: bool = interaction.get("conditions", []).any(func(c: Dictionary) -> bool: return c.has("story_at") and c.story_at == [story_id, str(step.id)])
			if not belongs or not _cost_option_known(s, interaction):
				continue
			var costs := _consumed(interaction.get("effects", []))
			for item_id: String in costs:
				required[item_id] = maxi(int(required.get(item_id, 0)), int(costs[item_id]))
	return required

static func required_herbs(s, story_id: String) -> int:
	var step := current_step(s, story_id)
	if step.is_empty() or not bool(progress(s, story_id).get("begun", false)):
		return 0
	var count := 0
	for effect: Dictionary in step.get("effects", []):
		count += maxi(0, -int(effect.get("herbs", 0)))
	for person_id: String in s.content.people:
		for interaction: Dictionary in s.content.people[person_id].get("interactions", []):
			if not interaction.get("conditions", []).any(func(c: Dictionary) -> bool: return c.has("story_at") and c.story_at == [story_id, str(step.id)]):
				continue
			if not _cost_option_known(s, interaction):
				continue
			var cost := 0
			for effect: Dictionary in interaction.get("effects", []):
				cost += maxi(0, -int(effect.get("herbs", 0)))
			count = maxi(count, cost)
	return count

## Material shortages do not hide delivery costs, but an unchosen branch must not reserve them.
static func _cost_option_known(s, interaction: Dictionary) -> bool:
	var known: Array = interaction.get("conditions", []).filter(func(c: Dictionary) -> bool: return not c.has("item_at_least") and not c.has("herbs_at_least") and not c.has("stones_at_least") and not c.has("at_location") and not c.has("deed_at_least"))
	return Events.all_met(s, known)

static func _consumed(effects: Array) -> Dictionary:
	var result := {}
	for effect: Dictionary in effects:
		if effect.has("item") and int(effect.item[1]) < 0:
			var item_id := str(effect.item[0])
			result[item_id] = int(result.get(item_id, 0)) - int(effect.item[1])
		elif effect.has("take_item"):
			result[str(effect.take_item)] = 1
	return result

## Whether the storyline is active at the step with this id, and that step has begun.
static func at_step(s, story_id: String, step_id: String) -> bool:
	var step := current_step(s, story_id)
	return not step.is_empty() and str(step.id) == step_id and bool(progress(s, story_id).get("begun", false))

## The guided storyline's current step once begun, or {} when no guidance holds the player.
static func guide_step(s) -> Dictionary:
	for story_id: String in definitions(s):
		if bool(definitions(s)[story_id].get("guide", false)) and state(s, story_id) == "active" and bool(progress(s, story_id).get("begun", false)):
			return current_step(s, story_id)
	return {}

static func guide_story(s) -> String:
	for story_id: String in definitions(s):
		if bool(definitions(s)[story_id].get("guide", false)) and state(s, story_id) == "active":
			return story_id
	return ""

## Starts a storyline at its first step; returns the texts told.
static func start(s, story_id: String) -> Array[String]:
	var texts: Array[String] = []
	if not state(s, story_id).is_empty() or not definitions(s).has(story_id):
		return texts
	s.world.storylines[story_id] = {"state": "active", "step": 0, "since": int(s.world.day), "begun": false, "base": {}}
	texts.append_array(update(s))
	return texts

## Ends a storyline as done without playing its steps (a skipped introduction, an older journey).
static func mark_done(s, story_id: String) -> void:
	s.world.storylines[story_id] = {"state": "done", "step": definitions(s)[story_id].steps.size(), "since": int(s.world.day), "begun": false, "base": {}}

## Settles every storyline after an action: starts those whose time has come, closes those overtaken,
## begins steps whose requirements hold and completes steps that are done. Returns the texts told.
static func update(s) -> Array[String]:
	var texts: Array[String] = []
	if s.player.is_empty() or not s.ended.is_empty():
		return texts
	for round: int in MAX_ROUNDS:
		var moved := false
		for story_id: String in definitions(s):
			var definition: Dictionary = definitions(s)[story_id]
			var saved: Dictionary = s.world.storylines.get(story_id, {})
			var now := str(saved.get("state", ""))
			if now.is_empty():
				if definition.has("begin_if") and Events.all_met(s, definition.begin_if):
					s.world.storylines[story_id] = {"state": "active", "step": 0, "since": int(s.world.day), "begun": false, "base": {}}
					moved = true
				continue
			if now != "active":
				continue
			var step: Dictionary = definition.steps[int(saved.step)]
			var closing: Array = definition.get("close_if", []) + step.get("close_if", [])
			if _any_met(s, closing):
				texts.append(_close(s, story_id, step))
				moved = true
				continue
			if not bool(saved.begun):
				# A step overtaken by events (a question about foundation once past it) passes unspoken.
				if _any_met(s, step.get("skip_if", [])):
					saved.step = int(saved.step) + 1
					if int(saved.step) >= definition.steps.size():
						saved.state = "done"
					moved = true
				elif Events.all_met(s, step.get("requires", [])):
					texts.append_array(_begin(s, story_id))
					moved = true
				continue
			if step.has("choice_event") and s.pending_event.is_empty() and s.battle.is_empty():
				s.pending_event = {"id": str(step.choice_event), "day": int(s.world.day)}
			if _finished(s, story_id, step):
				texts.append_array(complete_step(s, story_id))
				moved = true
		if not moved:
			return texts
	push_error("storylines did not settle")
	return texts

## True when any of the conditions holds (each entry is one condition).
static func _any_met(s, conditions: Array) -> bool:
	for condition: Dictionary in conditions:
		if Events.met(s, condition):
			return true
	return false

static func _close(s, story_id: String, step: Dictionary) -> String:
	s.world.storylines[story_id].state = "closed"
	var definition: Dictionary = definitions(s)[story_id]
	if step.has("closed") or definition.has("closed"):
		return s.log_event("story", {"story": story_id, "step": str(step.get("id", "")), "part": "closed"})
	return ""

## A step begins: deeds are counted from here and its words are told, in person or by 传音.
static func _begin(s, story_id: String) -> Array[String]:
	var texts: Array[String] = []
	var saved: Dictionary = s.world.storylines[story_id]
	var step := current_step(s, story_id)
	saved.begun = true
	saved.since = int(s.world.day)
	var base := {}
	for deed: String in step.get("deeds", {}):
		base[deed] = deed_count(s, deed)
	saved.base = base
	if step.has("say"):
		if bool(step.get("letter", false)):
			texts.append(send_letter(s, giver(s, story_id, step), {"story": story_id, "step": str(step.id)}))
		else:
			texts.append(s.log_event("story", {"story": story_id, "step": str(step.id), "part": "say"}))
	return texts

## Whether the begun step is done by its own measure (an interaction advances the others).
static func _finished(s, story_id: String, step: Dictionary) -> bool:
	if step.has("wait_days"):
		return false
	if not step.has("done") and not step.has("deeds"):
		return bool(step.get("auto", false))
	if not Events.all_met(s, step.get("done", [])):
		return false
	var base: Dictionary = progress(s, story_id).get("base", {})
	var deeds: Dictionary = step.get("deeds", {})
	for deed: String in deeds:
		if deed_count(s, deed) - int(base.get(deed, 0)) < int(deeds[deed]):
			return false
	return true

## Completes the current step: its effects, its closing words, and on to the next step (or the end).
static func complete_step(s, story_id: String) -> Array[String]:
	var texts: Array[String] = []
	var step := current_step(s, story_id)
	if step.is_empty():
		return texts
	var saved: Dictionary = s.world.storylines[story_id]
	saved.step = int(saved.step) + 1
	saved.begun = false
	saved.base = {}
	saved.since = int(s.world.day)
	if step.has("after"):
		texts.append(s.log_event("story", {"story": story_id, "step": str(step.id), "part": "after"}, bool(step.get("major", false))))
	# The last step ends the storyline before its effects, which may begin another (start_story).
	if int(saved.step) >= definitions(s)[story_id].steps.size():
		saved.state = "done"
	Events.apply(s, step.get("effects", []))
	return texts

## Advances a storyline whose current step has begun (effect story_advance, from an interaction).
static func advance(s, story_id: String) -> Array[String]:
	if state(s, story_id) != "active" or not bool(progress(s, story_id).get("begun", false)):
		return [] as Array[String]
	return complete_step(s, story_id)

## Who speaks for a step: its own speaker, else the storyline's giver.
static func giver(s, story_id: String, step: Dictionary = {}) -> String:
	return str(step.get("speaker", definitions(s)[story_id].giver))

# --- Deeds ---------------------------------------------------------------------------------------

static func deed_count(s, deed: String) -> int:
	return int(s.player.get("deeds", {}).get(deed, 0))

static func record(s, deed: String, amount: int = 1) -> void:
	if not s.player.has("deeds"):
		s.player["deeds"] = {}
	s.player.deeds[deed] = deed_count(s, deed) + amount

# --- 传音 ------------------------------------------------------------------------------------------

## Keeps a 传音 in the inbox and the chronicle; `about` is {"story", "step"} or {"kind"}. Returns its text.
static func send_letter(s, from: String, about: Dictionary) -> String:
	var letter := about.duplicate()
	letter["npc"] = from
	letter["day"] = int(s.world.day)
	letter["read"] = false
	s.world.letters.append(letter)
	s.letters_sent += 1
	while s.world.letters.size() > int(s.content.rules.letters.kept):
		s.world.letters.pop_front()
	var args := about.duplicate()
	args["npc"] = from
	return s.log_event("letter", args)

## Friends who keep a 传音符 with the player send word of a milestone ("breakthrough", "serpent", ...).
static func congratulate(s, kind: String) -> Array[String]:
	var texts: Array[String] = []
	for person_id: String in s.content.people:
		var person: Dictionary = s.content.people[person_id]
		if bool(s.world.people.get(person_id, {}).get("sound", false)) and person.get("congrats", {}).has(kind):
			texts.append(send_letter(s, person_id, {"kind": kind}))
	texts.append_array(s.Bonds.congratulate(s))
	return texts

## Exchanges 传音符 with a person; returns the text, or "" when already exchanged.
static func exchange_sound(s, person_id: String) -> String:
	var record_of: Dictionary = Events.person(s, person_id)
	if bool(record_of.get("sound", false)):
		return ""
	record_of["sound"] = true
	s._writers = -1
	return s.log_event("sound", {"npc": person_id})

static func unread_letters(s) -> int:
	return s.world.get("letters", []).filter(func(letter: Dictionary) -> bool: return not bool(letter.get("read", false))).size()

static func mark_letters_read(s) -> void:
	for letter: Dictionary in s.world.get("letters", []):
		letter.read = true

# --- Scheduler ------------------------------------------------------------------------------------

## The earliest storyline wait that ends on or after `from_day`: {"day", "story"}, or {}.
static func next_due(s, from_day: int) -> Dictionary:
	var best := {}
	for story_id: String in s.world.get("storylines", {}):
		var step := current_step(s, story_id)
		if step.is_empty() or not step.has("wait_days") or not bool(progress(s, story_id).get("begun", false)):
			continue
		var due := maxi(from_day, int(progress(s, story_id).since) + int(step.wait_days))
		if best.is_empty() or due < int(best.day):
			best = {"day": due, "story": story_id}
	return best

## A wait ends: the step completes and the next begins at once when it can; a 传音 ends a retreat.
static func fire(s, story_id: String) -> Dictionary:
	var sent := int(s.letters_sent)
	var texts := complete_step(s, story_id)
	texts.append_array(update(s))
	var interrupt := int(s.letters_sent) > sent
	return {"interrupt": interrupt, "message": " ".join(texts.filter(func(text: String) -> bool: return not text.is_empty()))}
