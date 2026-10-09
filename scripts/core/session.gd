extends RefCounted
## Gameplay state and rules. No UI or filesystem dependency.
const Content = preload("res://scripts/core/content.gd")
const Calendar = preload("res://scripts/core/calendar.gd")
const Chronicle = preload("res://scripts/core/chronicle.gd")
const Combat = preload("res://scripts/core/combat.gd")
const Events = preload("res://scripts/core/events.gd")
const SaveMigration = preload("res://scripts/core/save_migration.gd")
const SAVE_VERSION := SaveMigration.CURRENT_VERSION
const PLAYER_COUNTS := ["realm", "xp", "hp", "qi", "stones", "herbs", "pills", "cultivation_carry"]
const LIMIT := 1000000000.0
const MAX_SPAN_DAYS := 3600
const MAX_DUE_PER_SPAN := 100000
const TALK_COOLDOWN_DAYS := 30
# How long someone stays away after leaving, when their data gives no time.
const LONG_ABSENCE_DAYS := 3600
signal changed
var content = Content.new()
# Separate streams: world-side draws (gathering, later simulation) never shift duel results.
var combat_rng := RandomNumberGenerator.new()
var world_rng := RandomNumberGenerator.new()
var world: Dictionary = {}
var player: Dictionary = {}
var battle: Dictionary = {}
# A location event waiting for the player's choice: {"id", "day"}.
var pending_event: Dictionary = {}
# Set when this life is over: {"kind", "day"}.
var ended: Dictionary = {}
# Road encounters can be switched off by tests that exercise other systems along fixed paths.
var encounters_enabled := true
# The person whose interaction is being applied, for effects such as "leave".
var acting_npc := ""
var chronicle = Chronicle.new()
# Ephemeral presentation events; not part of the save format.
var combat_events: Array[Dictionary] = []

func _init() -> void:
	content.load_data()
	combat_rng.randomize()
	world_rng.randomize()

func new_game(character_name: String = "无名", seed_value: int = -1) -> void:
	if seed_value >= 0:
		combat_rng.seed = seed_value
		world_rng.seed = hash(str(seed_value) + ":world")
	var chosen_name := character_name.strip_edges().left(16)
	if chosen_name.is_empty():
		chosen_name = "无名"
	world = {"day": 0, "flags": {}, "events": {}, "people": {}}
	player = {
		"name": chosen_name, "birth_day": -int(content.rules.starting_age) * Calendar.DAYS_PER_YEAR,
		"realm": 0, "xp": 0, "hp": 0, "qi": 0, "cultivation_carry": 0, "warned_for": -1,
		"stones": int(content.rules.starting_stones), "herbs": 0, "pills": 0, "items": {},
		"journey": {}, "cooldowns": {},
		"location": "sect", "sect": "wanderer"
	}
	_refresh_realm_stats()
	player.hp = player.max_hp
	player.qi = player.max_qi
	battle.clear()
	pending_event = {}
	ended = {}
	combat_events.clear()
	chronicle.clear()
	log_event("start", {}, true)
	Events.check_location(self)
	changed.emit()

## The single entry point that moves world time. Every due item inside the span is fired on its own day,
## in order. Interruptible spans stop on the day an interrupting item fires; a life that ends stops time.
## Returns {"elapsed", "interrupted", "messages"}.
func advance_days(days: int, interruptible: bool = false) -> Dictionary:
	assert(days >= 0, "time cannot move backwards")
	var start := int(world.day)
	var target := start + maxi(0, days)
	var messages: Array[String] = []
	var interrupted := false
	var fired := 0
	while ended.is_empty():
		fired += 1
		if fired > MAX_DUE_PER_SPAN:
			push_error("scheduler did not settle; a due item failed to record its progress")
			break
		var due: Dictionary = Events.next_due(self, int(world.day))
		if due.is_empty() or int(due.day) > target:
			break
		world.day = int(due.day)
		var result: Dictionary = Events.fire(self, due)
		if not str(result.message).is_empty():
			messages.append(result.message)
		if result.interrupt and interruptible and int(world.day) < target:
			interrupted = true
			break
	if ended.is_empty() and not interrupted:
		world.day = target
	return {"elapsed": int(world.day) - start, "interrupted": interrupted, "messages": messages}

## Joins an action's text with what happened meanwhile, fires location events, and notifies listeners.
func conclude(text: String, passed: Dictionary = {}) -> String:
	var parts: Array[String] = [text]
	parts.append_array(passed.get("messages", []))
	parts.append_array(Events.check_location(self))
	changed.emit()
	return " ".join(parts.filter(func(part: String) -> bool: return not part.is_empty()))

## Records a chronicle entry and returns its display text.
func log_event(id: String, args: Dictionary = {}, major: bool = false) -> String:
	return chronicle.format(chronicle.add(int(world.day), id, args, major), content)

func finish(message: String) -> String:
	changed.emit()
	return message

func journal_lines() -> Array[String]:
	return chronicle.lines(content)

func has_flag(flag: String) -> bool:
	return bool(world.get("flags", {}).get(flag, false))

func realm_name() -> String:
	return content.realm(int(player.get("realm", 0))).name

func time_name() -> String:
	return Calendar.date_text(int(world.get("day", 0)))

func age() -> int:
	return Calendar.age_years(int(player.birth_day), int(world.day))

func lifespan() -> int:
	return int(content.realm(int(player.realm)).lifespan_years)

func lifespan_end_day() -> int:
	return int(player.birth_day) + lifespan() * Calendar.DAYS_PER_YEAR

func upcoming() -> Array[Dictionary]:
	return Events.upcoming(self)

func pending_definition() -> Dictionary:
	return {} if pending_event.is_empty() else content.events[pending_event.id]

func choice_available(choice: Dictionary) -> bool:
	return Events.all_met(self, choice.get("conditions", []))

## Requirements to leave the current realm, or an empty Dictionary at the highest open realm.
func next_breakthrough() -> Dictionary:
	var current: Dictionary = content.realm(int(player.realm))
	if int(player.realm) + 1 >= content.realms.size() or not current.has("breakthrough"):
		return {}
	return current.breakthrough

func _refresh_realm_stats() -> void:
	var current: Dictionary = content.realm(int(player.realm))
	player.max_hp = int(current.max_hp)
	player.max_qi = int(current.max_qi)

## Why the player cannot act right now, or an empty String.
func _blocked() -> String:
	if player.is_empty():
		return "请先创建角色。"
	if not ended.is_empty():
		return "此生已尽。可读取存档，或开启新旅程。"
	if not pending_event.is_empty():
		return "眼前之事尚未了结。"
	if not battle.is_empty():
		return "斗法中无法进行此操作。"
	return ""

func act(action: String) -> String:
	var blocked := _blocked()
	if not blocked.is_empty():
		return blocked
	var days := content.action_days(action)
	if action in content.PLAIN_ACTIONS and not available_here(action):
		return "此地无法如此行事。"
	match action:
		"cultivate":
			return cultivate(days)
		"rest":
			var passed := advance_days(days)
			if not ended.is_empty():
				return conclude("", passed)
			player.hp = player.max_hp
			player.qi = player.max_qi
			return conclude(log_event("rest", {"days": passed.elapsed}), passed)
		"gather":
			var passed := advance_days(days)
			if not ended.is_empty():
				return conclude("", passed)
			var span: Array = content.locations[player.location].gather
			var amount := world_rng.randi_range(int(span[0]), int(span[1]))
			player.herbs += amount
			return conclude(log_event("gather_at", {"days": passed.elapsed, "amount": amount, "location": player.location}), passed)
		"inn_rest":
			var price := int(content.rules.inn_price)
			if int(player.stones) < price:
				return "灵石不足：客栈歇息需要 %d 灵石。" % price
			player.stones -= price
			var passed := advance_days(days)
			if not ended.is_empty():
				return conclude("", passed)
			player.hp = player.max_hp
			player.qi = player.max_qi
			return conclude(log_event("inn_rest", {"days": passed.elapsed, "price": price}), passed)
		"search_ruin":
			var ready := int(player.cooldowns.get(action, 0))
			if int(world.day) < ready:
				return "石室刚翻找过，%s后再来或许会有新发现。" % Calendar.duration_text(ready - int(world.day))
			var passed := advance_days(days)
			if not ended.is_empty():
				return conclude("", passed)
			var loot: Dictionary = content.rules.ruin_search
			var found := {
				"days": passed.elapsed,
				"stones": world_rng.randi_range(int(loot.stones[0]), int(loot.stones[1])),
				"herbs": world_rng.randi_range(int(loot.herbs[0]), int(loot.herbs[1])),
				"pills": 1 if world_rng.randf() < float(loot.pill_chance) else 0,
			}
			player.stones += found.stones
			player.herbs += found.herbs
			player.pills += found.pills
			player.cooldowns[action] = int(world.day) + int(content.rules.action_cooldowns.get(action, 0))
			return conclude(log_event("search_ruin", found), passed)
		"sell":
			if int(player.herbs) == 0:
				return "背包中没有灵草。"
			var revenue := int(player.herbs) * int(content.rules.herb_price)
			var passed := advance_days(days)
			if not ended.is_empty():
				return conclude("", passed)
			player.stones += revenue
			player.herbs = 0
			return conclude(log_event("sell", {"revenue": revenue}), passed)
		"buy_pill":
			var price := int(content.rules.pill_price)
			if int(player.stones) < price:
				return "灵石不足：筑基丹需要 %d 灵石。" % price
			var passed := advance_days(days)
			if not ended.is_empty():
				return conclude("", passed)
			player.stones -= price
			player.pills += 1
			return conclude(log_event("buy_pill", {"price": price}), passed)
		"breakthrough":
			var need := next_breakthrough()
			if need.is_empty():
				return "后续境界尚未开放。"
			if int(player.xp) < int(need.xp) or int(player.pills) < int(need.pills):
				return "突破需要 %d 修为与 %d 枚筑基丹。" % [int(need.xp), int(need.pills)]
			player.pills -= int(need.pills)
			player.xp -= int(need.xp)
			var passed := advance_days(days)
			if not ended.is_empty():
				return conclude("", passed)
			player.realm += 1
			_refresh_realm_stats()
			player.hp = player.max_hp
			player.qi = player.max_qi
			return conclude(log_event("breakthrough", {"days": passed.elapsed, "realm": int(player.realm)}, true), passed)
	return "未知操作。"

## Closed-door cultivation for a chosen number of days. Reminders and lifespan warnings can end it early;
## cultivation is credited per elapsed day, so one long retreat equals several short ones.
func cultivate(days: int) -> String:
	var blocked := _blocked()
	if not blocked.is_empty():
		return blocked
	if not available_here("cultivate"):
		return "此地无法闭关，请回青云山静室。"
	if days < 1 or days > MAX_SPAN_DAYS:
		return "闭关天数不合常理。"
	var passed := advance_days(days, true)
	if not ended.is_empty():
		return conclude("", passed)
	var gained := _gain_cultivation(int(passed.elapsed))
	player.qi = player.max_qi
	var text := log_event("cultivate", {"days": passed.elapsed, "xp": gained})
	if passed.interrupted:
		text = "闭关第 %d 日，外事惊动，你提前出关。%s" % [passed.elapsed, text]
	return conclude(text, passed)

## Stays where the player is. Interruptible like a retreat, but without cultivation.
func wait(days: int) -> String:
	var blocked := _blocked()
	if not blocked.is_empty():
		return blocked
	if days < 1 or days > MAX_SPAN_DAYS:
		return "停留天数不合常理。"
	var passed := advance_days(days, true)
	if not ended.is_empty():
		return conclude("", passed)
	return conclude(log_event("wait", {"days": passed.elapsed, "location": player.location}), passed)

func _gain_cultivation(days: int) -> int:
	var total := int(player.cultivation_carry) + days * int(content.rules.cultivate_xp)
	var gained := total / Calendar.DAYS_PER_MONTH
	player.cultivation_carry = total % Calendar.DAYS_PER_MONTH
	player.xp += gained
	return gained

# --- People ------------------------------------------------------------------------
# People live in the world on their own: residents stay home, wanderers follow a schedule computed
# from the date. The player only sees who is at the place where they stop; anyone seen there becomes
# an acquaintance whose whereabouts can be looked up. Nothing about people stops a journey.

## Where a person is today, or "" when absent (left, outside their window, or somewhere undiscovered).
func npc_location(person_id: String) -> String:
	var person: Dictionary = content.people[person_id]
	var day := int(world.day)
	if int(world.people.get(person_id, {}).get("absent_until", -1)) > day:
		return ""
	if person.has("window"):
		var from: Array = person.window.from
		var to: Array = person.window.to
		if day < Calendar.to_day(from[0], from[1], from[2]) or day > Calendar.to_day(to[0], to[1], to[2]):
			return ""
	if not Events.all_met(self, person.get("present_if", [])):
		return ""
	var location: String = content.person_base_location(person_id, day)
	return location if location_visible(location) else ""

func present_npcs() -> Array[String]:
	var result: Array[String] = []
	for person_id: String in content.people:
		if npc_location(person_id) == player.location:
			result.append(person_id)
	return result

func known_npcs() -> Array[String]:
	var result: Array[String] = []
	for person_id: String in world.people:
		if content.people.has(person_id) and bool(world.people[person_id].get("met", false)):
			result.append(person_id)
	return result

func meet_present() -> void:
	for person_id: String in present_npcs():
		Events.person(self, person_id).met = true

func favor(person_id: String) -> int:
	return int(world.people.get(person_id, {}).get("relation", 0))

## The person goes away for their leave time (paid off, defeated, healed and moving on).
func npc_depart(person_id: String) -> void:
	if person_id.is_empty():
		return
	var days := int(content.people[person_id].get("leave_days", LONG_ABSENCE_DAYS))
	Events.person(self, person_id).absent_until = int(world.day) + days

## Everything the player could do with a person here: {"id", "label", "available", "reason"}.
func npc_options(person_id: String) -> Array[Dictionary]:
	var options: Array[Dictionary] = []
	var person: Dictionary = content.people[person_id]
	if person.attitude != "hostile" and not person.get("talk", []).is_empty():
		options.append({"id": "talk", "label": "交谈", "cooldown_days": TALK_COOLDOWN_DAYS})
	if person.attitude != "hostile" and int(person.get("gift_favor", 0)) > 0:
		options.append({"id": "gift", "label": "赠一株灵草（好感 +%d）" % int(person.gift_favor), "conditions": [{"herbs_at_least": 1}], "cooldown_days": TALK_COOLDOWN_DAYS})
	for interaction: Dictionary in person.get("interactions", []):
		options.append(interaction)
	var result: Array[Dictionary] = []
	var here: bool = npc_location(person_id) == str(player.get("location", ""))
	var last: Dictionary = world.people.get(person_id, {}).get("last", {})
	var blocked := _blocked()
	for option: Dictionary in options:
		# Interactions repeat unless marked "once"; "cooldown_days" spaces repeats out.
		var reason := ""
		if not blocked.is_empty():
			reason = blocked
		elif not here:
			reason = "此人不在这里。"
		elif bool(option.get("once", false)) and last.has(option.id):
			reason = "此事已了。"
		elif last.has(option.id) and int(world.day) < int(last[option.id]) + int(option.get("cooldown_days", 0)):
			reason = "%s后再来。" % Calendar.duration_text(int(last[option.id]) + int(option.cooldown_days) - int(world.day))
		elif not Events.all_met(self, option.get("conditions", [])):
			reason = "条件不足。"
		result.append({"id": option.id, "label": option.label, "available": reason.is_empty(), "reason": reason})
	return result

func interact(person_id: String, option_id: String) -> String:
	if not content.people.has(person_id):
		return "未知人物。"
	var chosen: Dictionary = {}
	for option: Dictionary in npc_options(person_id):
		if option.id == option_id:
			chosen = option
	if chosen.is_empty():
		return "没有这个选项。"
	if not chosen.available:
		return chosen.reason
	var person: Dictionary = content.people[person_id]
	var progress := Events.person(self, person_id)
	progress.met = true
	progress.last[option_id] = int(world.day)
	var text := ""
	match option_id:
		"talk":
			var lines: Array = person.talk
			text = log_event("talk", {"npc": person_id, "line": int(progress.talks) % lines.size()})
			progress.talks = int(progress.talks) + 1
			Events.apply(self, [{"relation": [person_id, int(person.get("talk_favor", 0))]}])
		"gift":
			Events.apply(self, [{"herbs": -1}, {"relation": [person_id, int(person.gift_favor)]}])
			text = log_event("gift", {"npc": person_id, "favor": int(person.gift_favor)})
		_:
			for interaction: Dictionary in person.interactions:
				if interaction.id == option_id:
					acting_npc = person_id
					Events.apply(self, interaction.get("effects", []))
					acting_npc = ""
					if not battle.is_empty():
						battle.npc = person_id
			text = log_event("npc", {"npc": person_id, "interaction": option_id})
	return conclude(text)

func choose_event(choice_id: String) -> String:
	if pending_event.is_empty():
		return "眼下没有需要抉择的事。"
	var message: String = Events.choose(self, choice_id)
	changed.emit()
	return message

func available_here(action: String) -> bool:
	return action in content.spot_actions(player.location, world.flags)

func location_visible(location_id: String) -> bool:
	return content.location_visible(location_id, world.flags)

func path_to(location_id: String) -> Array[String]:
	return content.find_path(player.location, location_id, world.flags)

## Sets out for a destination along the shortest known path and walks it leg by leg.
func travel(location_id: String) -> String:
	var blocked := _blocked()
	if not blocked.is_empty():
		return "斗法中无法离开。" if not battle.is_empty() else blocked
	if not content.locations.has(location_id) or not location_visible(location_id):
		return "未知地点。"
	if player.location == location_id:
		return "你已在此处。"
	if path_to(location_id).is_empty():
		return "两地之间没有可走的路。"
	player.journey = {"to": location_id}
	return _walk()

## Resumes a journey interrupted by an encounter or an event on the way.
func continue_journey() -> String:
	var blocked := _blocked()
	if not blocked.is_empty():
		return blocked
	if player.journey.is_empty():
		return "眼下没有未竟的行程。"
	return _walk()

## Each leg: time passes on the road, the player arrives at the next node, the road may bring an
## encounter, then the node's own events fire. Anything that needs the player stops the journey there.
func _walk() -> String:
	var parts: Array[String] = []
	while not player.journey.is_empty():
		var path := path_to(player.journey.to)
		if path.size() < 2:
			player.journey = {}
			parts.append("前路已断，行程作罢。")
			break
		var next: String = path[1]
		var route: Dictionary = content.route_between(player.location, next)
		var passed := advance_days(int(route.days))
		parts.append_array(passed.messages)
		if not ended.is_empty():
			player.journey = {}
			break
		player.location = next
		if next == player.journey.to:
			player.journey = {}
		parts.append(log_event("travel", {"days": passed.elapsed, "location": next}))
		if encounters_enabled:
			parts.append(Events.roll_encounter(self, route))
		if pending_event.is_empty():
			parts.append_array(Events.check_location(self, not player.journey.is_empty()))
		if not pending_event.is_empty() or not battle.is_empty():
			break
	changed.emit()
	return " ".join(parts.filter(func(part: String) -> bool: return not part.is_empty()))

func active_skills() -> Array[String]:
	var result: Array[String] = []
	for id: String in content.sects[player.get("sect", "wanderer")].skills:
		result.append(id)
	return result

func choose_sect(sect_id: String) -> String:
	if player.is_empty() or not content.sects.has(sect_id):
		return "未知门派。"
	if not battle.is_empty():
		return "斗法中无法更换传承。"
	var blocked := _blocked()
	if not blocked.is_empty():
		return blocked
	if not available_here("study"):
		return "请回青云山传功堂研习门派传承。"
	if player.get("sect", "wanderer") == sect_id:
		return "你已在研习此传承。"
	player.sect = sect_id
	return finish(log_event("choose_sect", {"sect": sect_id}, true))

func start_battle(enemy_id: String, opponent_sect: String = "") -> String:
	if not _blocked().is_empty() or not content.enemies.has(enemy_id):
		return "当前无法开始斗法。"
	var enemy: Dictionary = content.enemies[enemy_id]
	if not available_here("battle:" + enemy_id):
		return "此地没有这个对手。"
	if not opponent_sect.is_empty() and not content.sects.has(opponent_sect):
		return "未知对手传承。"
	if int(player.realm) < int(enemy.min_realm):
		return "%s气息凶险，需达到%s。" % [enemy.name, content.realm(int(enemy.min_realm)).name]
	if enemy.has("world_flag") and has_flag(enemy.world_flag):
		return "%s已经伏诛，此地重归安宁。" % enemy.name
	return finish(begin_battle(enemy_id, "", opponent_sect))

## Starts a duel without location checks; used by spots and by event effects (context "event").
func begin_battle(enemy_id: String, context: String = "", opponent_sect: String = "") -> String:
	var enemy: Dictionary = content.enemies[enemy_id]
	if opponent_sect.is_empty():
		opponent_sect = str(enemy.get("sect", player.get("sect", "wanderer")))
		if opponent_sect == "wanderer":
			opponent_sect = "qingyun"
	battle = {"enemy_id": enemy_id, "hp": int(enemy.hp), "turn": 1, "cooldowns": {}, "opponent_sect": opponent_sect}
	if not context.is_empty():
		battle.context = context
	return log_event("battle_start", {"enemy": enemy_id})

func use_skill(skill_id: String) -> String:
	return Combat.use_skill(self, skill_id)

func defend() -> String:
	return Combat.defend(self)

func flee() -> String:
	return Combat.flee(self)

func snapshot() -> Dictionary:
	return {
		"version": SAVE_VERSION, "world": world.duplicate(true), "player": player.duplicate(true),
		"battle": battle.duplicate(true), "pending_event": pending_event.duplicate(true), "ended": ended.duplicate(true),
		"chronicle": chronicle.to_save(), "rng": {"combat": str(combat_rng.state), "world": str(world_rng.state)}
	}

func restore(data: Variant) -> bool:
	# Upgrade older versions first, then validate everything before changing the current session.
	if not data is Dictionary:
		return false
	var saved: Dictionary = SaveMigration.migrate(data)
	if saved.is_empty() or int(saved.version) != SAVE_VERSION:
		return false
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
	var people: Variant = _valid_people(saved_world.people)
	if events == null or people == null:
		return false
	if not saved_player.get("name") is String or not saved_player.get("location") is String or not content.locations.has(saved_player.location):
		return false
	for key: String in PLAYER_COUNTS:
		if not _whole_nonnegative(saved_player.get(key)):
			return false
	if int(saved_player.cultivation_carry) >= Calendar.DAYS_PER_MONTH:
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
	var realm: Dictionary = content.realm(int(saved_player.realm))
	if int(saved_player.hp) <= 0 or int(saved_player.hp) > int(realm.max_hp) or int(saved_player.qi) > int(realm.max_qi):
		return false
	var saved_sect: Variant = saved_player.get("sect")
	if not saved_sect is String or not content.sects.has(saved_sect):
		return false
	if not saved_battle.is_empty():
		if not saved_battle.get("enemy_id") is String or not content.enemies.has(saved_battle.enemy_id):
			return false
		if not _whole_nonnegative(saved_battle.get("hp")) or int(saved_battle.hp) <= 0 or int(saved_battle.hp) > int(content.enemies[saved_battle.enemy_id].hp):
			return false
		if not _whole_nonnegative(saved_battle.get("turn")) or int(saved_battle.turn) < 1 or not saved_battle.get("cooldowns") is Dictionary:
			return false
		for skill_id: Variant in saved_battle.cooldowns:
			if not content.skills.has(skill_id) or not _whole_nonnegative(saved_battle.cooldowns[skill_id]):
				return false
		if saved_battle.has("context") and saved_battle.context != "event":
			return false
		if saved_battle.has("npc") and (not saved_battle.npc is String or not content.people.has(saved_battle.npc)):
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
	world = {"day": day, "flags": saved_world.flags.duplicate(), "events": events, "people": people}
	player = saved_player.duplicate(true)
	for key: String in PLAYER_COUNTS:
		player[key] = int(player[key])
	player.birth_day = int(birth)
	player.warned_for = int(warned)
	for item_id: String in player.items:
		player.items[item_id] = int(player.items[item_id])
	player.journey = {} if journey.is_empty() else {"to": journey.to}
	for action_id: String in player.cooldowns:
		player.cooldowns[action_id] = int(player.cooldowns[action_id])
	_refresh_realm_stats()
	battle = saved_battle.duplicate(true)
	if not battle.is_empty():
		battle.hp = int(battle.hp)
		battle.turn = int(battle.turn)
		for skill_id: String in battle.cooldowns:
			battle.cooldowns[skill_id] = int(battle.cooldowns[skill_id])
	pending_event = {} if saved_pending.is_empty() else {"id": saved_pending.id, "day": int(saved_pending.day)}
	ended = {} if saved_ended.is_empty() else {"kind": saved_ended.kind, "day": int(saved_ended.day)}
	chronicle.entries = saved_chronicle
	combat_rng.state = int(saved_rng.combat)
	world_rng.state = int(saved_rng.world)
	combat_events.clear()
	changed.emit()
	return true

## Normalized copy of saved event progress, or null. Progress for events no longer in content is kept.
func _valid_event_progress(data: Dictionary) -> Variant:
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

func _valid_people(data: Dictionary) -> Variant:
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
		result[person_id] = {"met": person.met, "relation": int(person.relation), "last": last, "absent_until": int(person.absent_until), "talks": int(person.talks)}
	return result

func _whole_nonnegative(value: Variant) -> bool:
	return _whole_signed(value) and float(value) >= 0.0

func _whole_signed(value: Variant) -> bool:
	if not (value is int or value is float):
		return false
	return is_finite(float(value)) and float(value) == floor(float(value)) and absf(float(value)) <= LIMIT
