extends RefCounted
## Gameplay state and rules. No UI or filesystem dependency.
## The state, time and the core actions live here; each system's rules live in its own module, which
## operates on this Session. The forwarders below keep one public interface for the interface and tests.
const Content = preload("res://scripts/core/content.gd")
const Calendar = preload("res://scripts/core/calendar.gd")
const Chronicle = preload("res://scripts/core/chronicle.gd")
const Combat = preload("res://scripts/core/combat.gd")
const Events = preload("res://scripts/core/events.gd")
const Arsenal = preload("res://scripts/core/arsenal.gd")
const Population = preload("res://scripts/core/population.gd")
const Inventory = preload("res://scripts/core/inventory.gd")
const Loadout = preload("res://scripts/core/loadout.gd")
const Commissions = preload("res://scripts/core/commissions.gd")
const Rumors = preload("res://scripts/core/rumors.gd")
const People = preload("res://scripts/core/people.gd")
const Journey = preload("res://scripts/core/journey.gd")
const Cultivation = preload("res://scripts/core/cultivation.gd")
const Storylines = preload("res://scripts/core/storylines.gd")
const Talents = preload("res://scripts/core/talents.gd")
const Breakthrough = preload("res://scripts/core/breakthrough.gd")
const Fortune = preload("res://scripts/core/fortune.gd")
const Sect = preload("res://scripts/core/sect.gd")
const Bonds = preload("res://scripts/core/bonds.gd")
const Alchemy = preload("res://scripts/core/alchemy.gd")
const SaveRestore = preload("res://scripts/core/save_restore.gd")
const SaveMigration = preload("res://scripts/core/save_migration.gd")
const SAVE_VERSION := SaveMigration.CURRENT_VERSION
const MAX_SPAN_DAYS := 3600
const MAX_DUE_PER_SPAN := 100000
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
# The single-retreat limit can be switched off by tests that run long spans of time through a retreat.
var retreat_limits := true
# Fixed rolls in [0, 1) for chance draws by tag ("breakthrough", "demon", "slay", "grade", fortune's own),
# for tests; otherwise they come from the world stream.
var fortune: Dictionary = {}
# The person whose interaction is being applied, for effects such as "leave".
var acting_npc := ""
# 传音 sent since this session began; a storyline wait that sends one ends a retreat. Not saved.
var letters_sent := 0
# Population caches kept by people.gd, rebuilt from the world seed and never saved: who can be found
# where today and the people indexes it comes from; seats of built regions, their lives, and per-day
# views and per-realm loadouts.
var _people_at := {}
var _index_cache: Array[Dictionary] = []
var _local_seats: Array[int] = []
var _lives := {}
var _views := {}
var _loadouts := {}
var _life_ids := {}
var _met_through := {}
var _obituary_cache := {"dirty": true}
# How many generated people hold a 传音符 with the player (-1 until counted again), kept by bonds.gd.
var _writers := -1
var chronicle = Chronicle.new()
# Ephemeral presentation events; not part of the save format.
var combat_events: Array[Dictionary] = []

func _init() -> void:
	content.load_data()
	combat_rng.randomize()
	world_rng.randomize()

## `roots` are the spirit-root elements chosen at creation; when empty they are sensed (rolled) here.
## `start` is how the journey begins: "guided" plays the introduction (data/storylines.json) and holds
## the player to it; "skipped" counts it as done and lets the sect's storylines follow; "plain" opens
## the sect without any storyline (the systems' own tests).
## `born` holds the talents sensed at creation ({"talents", "flaws"}, see roll_talents); without it the
## player has none, which keeps the systems' own tests to the plain rules.
func new_game(character_name: String = "无名", seed_value: int = -1, roots: Array = [], start: String = "plain", born: Dictionary = {}) -> void:
	if seed_value >= 0:
		combat_rng.seed = seed_value
		world_rng.seed = hash(str(seed_value) + ":world")
	if roots.is_empty():
		roots = roll_roots(world_rng)
	var chosen_name := character_name.strip_edges().left(16)
	if chosen_name.is_empty():
		chosen_name = "无名"
	# talent_lives: the generated population's talents shape their lives (journeys begun before talents
	# keep the lives they had).
	world = {"day": 0, "flags": {}, "events": {}, "people": {}, "seed": seed_value if seed_value >= 0 else absi(int(world_rng.randi())), "stock_sold": {}, "rumors": {}, "quests_taken": {}, "storylines": {}, "letters": [], "talent_lives": true, "invites": [], "loans": [], "visit_period": 0}
	populate()
	player = {
		"name": chosen_name, "birth_day": -int(content.rules.starting_age) * Calendar.DAYS_PER_YEAR,
		"realm": 0, "stage": 0, "xp": 0, "hp": 0, "qi": 0, "cultivation_carry": 0, "warned_for": -1, "roots": roots.duplicate(),
		"fatigue": 0, "fatigue_day": 0, "insight": 0, "mind": 0,
		"stones": int(content.rules.starting_stones), "items": {},
		"journey": {}, "cooldowns": {},
		"location": "sect", "sect": "wanderer",
		"learned": [], "arts": [], "methods": [], "equipment": {"weapon": "", "robe": "", "accessory": ""}, "quests": [],
		"deeds": {}, "taught": [],
		"talents": born.get("talents", []).duplicate(), "flaws": born.get("flaws", []).duplicate(),
		"foundation_grade": 1, "injury_until": 0, "lessons": 0, "boons": {},
		"rank": 0, "contribution": 0, "merit": 0, "stipend_day": 0, "exchanged": {}, "donated": {},
		"recipes": [], "practice": {}, "toxin": 0, "toxin_day": 0, "field": {"grade": 0, "plots": []},
	}
	player.stones = maxi(0, int(player.stones) + talent_modifier("stones"))
	for skill_id: String in content.sects.wanderer.skills:
		player.learned.append(skill_id)
		player.arts.append(skill_id)
	refresh_realm_stats()
	player.hp = player.max_hp
	player.qi = player.max_qi
	battle.clear()
	pending_event = {}
	ended = {}
	combat_events.clear()
	chronicle.clear()
	log_event("start", {}, true)
	match start:
		"guided":
			Storylines.start(self, "intro")
		"skipped":
			world.flags["intro_done"] = true
			Storylines.mark_done(self, "intro")
			Storylines.update(self)
		_:
			world.flags["intro_done"] = true
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
	parts.append_array(Commissions.expire(self))
	parts.append_array(Bonds.expire(self))
	parts.append_array(Events.check_location(self))
	parts.append_array(Storylines.update(self))
	changed.emit()
	return " ".join(parts.filter(func(part: String) -> bool: return not part.is_empty()))

## Records a chronicle entry and returns its display text.
func log_event(id: String, args: Dictionary = {}, major: bool = false) -> String:
	return chronicle.format(chronicle.add(int(world.day), id, args, major), content)

func finish(message: String) -> String:
	var told := Storylines.update(self)
	changed.emit()
	return message if told.is_empty() else " ".join([message] + told)

func journal_lines() -> Array[String]:
	return chronicle.lines(content)

func has_flag(flag: String) -> bool:
	return bool(world.get("flags", {}).get(flag, false))

func realm_name() -> String:
	return content.realm_title(int(player.get("realm", 0)), int(player.get("stage", 0)))

func stage_stats() -> Dictionary:
	return content.stage(int(player.realm), int(player.stage))

## Spirit roots: a random number of elements, weighted by grade (rarer roots cultivate faster).
func roll_roots(rng: RandomNumberGenerator) -> Array:
	var spec: Dictionary = content.rules.spirit_roots
	var total := 0
	for grade: Dictionary in spec.grades:
		total += int(grade.weight)
	var pick := rng.randi_range(1, total)
	var count := 3
	for grade: Dictionary in spec.grades:
		pick -= int(grade.weight)
		if pick <= 0:
			count = int(grade.count)
			break
	var pool: Array = spec.elements.duplicate()
	var chosen: Array = []
	for index: int in count:
		chosen.append(pool.pop_at(rng.randi_range(0, pool.size() - 1)))
	var ordered: Array = []
	for element: String in spec.elements:
		if element in chosen:
			ordered.append(element)
	return ordered

## Talents for a new character, from the protagonist's birth table.
func roll_talents(rng: RandomNumberGenerator) -> Dictionary:
	return Talents.roll(content, rng, str(content.talent_data.player.table))

func root_title() -> String:
	return content.root_title(player.get("roots", []))

func cultivation_speed() -> float:
	var grade := Breakthrough.grade_of(self)
	return float(content.root_grade(player.get("roots", [])).speed) * (1.0 + float(bonuses().cultivation)) * (1.0 + float(grade.get("speed", 0)) / 100.0) * (1.0 + float(Sect.retreat_bonus(self)) / 100.0)

## Xp gained per 30 days of closed-door cultivation with these roots.
func cultivation_rate() -> int:
	return int(round(float(content.rules.cultivate_xp) * cultivation_speed()))

func time_name() -> String:
	return Calendar.date_text(int(world.get("day", 0)))

func age() -> int:
	return Calendar.age_years(int(player.birth_day), int(world.day))

func lifespan() -> int:
	return maxi(int(content.rules.starting_age) + 10, int(content.realm(int(player.realm)).lifespan_years) + talent_modifier("lifespan"))

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

## Sets the stat caps from the stage and the loadout, keeping current hp and qi within them.
func refresh_realm_stats() -> void:
	var caps := stat_caps(player)
	player.max_hp = int(caps.max_hp)
	player.max_qi = int(caps.max_qi)
	if player.has("hp"):
		player.hp = mini(int(player.hp), int(player.max_hp))
		player.qi = mini(int(player.qi), int(player.max_qi))

## Health and qi caps for a player-shaped Dictionary (realm, stage, loadout, talents, foundation grade):
## the stage's, plus the loadout's, raised by the talents' and the grade's percentages.
func stat_caps(holder: Dictionary) -> Dictionary:
	var current: Dictionary = content.stage(int(holder.get("realm", 0)), int(holder.get("stage", 0)))
	var extra := bonuses(holder)
	var grade := int(Breakthrough.grade_of(self, holder).get("stats", 0))
	return {
		"max_hp": maxi(1, (int(current.max_hp) + int(extra.max_hp)) * (100 + int(extra.max_hp_percent) + grade) / 100),
		"max_qi": maxi(1, (int(current.max_qi) + int(extra.max_qi)) * (100 + int(extra.max_qi_percent) + grade) / 100),
	}

## Why the player cannot act right now, or an empty String.
func blocked() -> String:
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
	var reason := blocked()
	if not reason.is_empty():
		return reason
	var days := content.action_days(action)
	if action in content.PLAIN_ACTIONS and not available_here(action):
		return "此地无法如此行事。"
	match action:
		"cultivate":
			return cultivate(days)
		"rest":
			var passed := advance_days(rest_days())
			if not ended.is_empty():
				return conclude("", passed)
			player.hp = player.max_hp
			player.qi = player.max_qi
			return conclude(log_event("rest", {"days": passed.elapsed}), passed)
		"gather":
			var passed := advance_days(days)
			if not ended.is_empty():
				return conclude("", passed)
			var found := Inventory.gather_picks(self, content.locations[player.location].gather)
			# A friend who asked to gather here together doubles the finds.
			var outing := Bonds.outing_here(self)
			if not outing.is_empty():
				for item_id: String in found:
					found[item_id] = int(found[item_id]) * 2
			for item_id: String in found:
				add_item(item_id, int(found[item_id]))
			record_deed("gather")
			var gathered := [log_event("gather_items", {"days": passed.elapsed, "location": player.location, "loot": loot_code(found)})]
			if not outing.is_empty():
				gathered.append(Bonds.finish_outing(self, outing))
			gathered.append_array(Fortune.after_gather(self))
			return conclude(" ".join(gathered), passed)
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
			add_item("huichun_grass", int(found.herbs))
			add_item("foundation_pill", int(found.pills))
			player.cooldowns[action] = int(world.day) + int(content.rules.action_cooldowns.get(action, 0))
			var searched := [log_event("search_ruin", found)]
			searched.append_array(Fortune.after_search(self))
			return conclude(" ".join(searched), passed)
		"sell":
			# Sell every item this place buys, in one go.
			var sold := {}
			# Treasures are sold one at a time, never swept up with the rest.
			for item_id: String in player.items.keys():
				if sell_price(item_id) > 0 and content.item(item_id).get("category", "") != "treasure":
					sold[item_id] = item_count(item_id)
			if sold.is_empty():
				return "行囊里没有这里收购的东西。"
			var revenue := 0
			for item_id: String in sold:
				revenue += sell_price(item_id) * int(sold[item_id])
				remove_item(item_id, int(sold[item_id]))
			player.stones += revenue
			record_deed("trade")
			return conclude(log_event("sell_all", {"loot": loot_code(sold), "revenue": revenue}))
		"breakthrough":
			return Breakthrough.attempt(self, Breakthrough.default_plan(self))
	return "未知操作。"

## Closed-door cultivation for a chosen number of days. Reminders and lifespan warnings can end it early,
## and so does reaching a bottleneck. Cultivation is credited per elapsed day with the day's efficiency
## (see cultivation.gd), so one long retreat equals several short ones.
func cultivate(days: int) -> String:
	var reason := blocked()
	if not reason.is_empty():
		return reason
	if not available_here("cultivate"):
		return "此地无法闭关，请回青云山静室。"
	if days < 1 or days > MAX_SPAN_DAYS:
		return "闭关天数不合常理。"
	var held := guide_block("cultivate")
	if not held.is_empty():
		return held
	if at_bottleneck():
		return "修为卡在瓶颈，闭关难有寸进。需外出历练（斗法、切磋、委托、奇遇），或服一枚破障丹。"
	if at_xp_cap():
		return cap_text()
	# A retreat longer than the mind (or the guided start) allows ends at the limit.
	days = mini(days, retreat_most())
	var tired := Cultivation.fatigue(self)
	var plan := Cultivation.plan_retreat(self, days, tired)
	var start := int(world.day)
	var passed := advance_days(int(plan.days), true)
	if not ended.is_empty():
		return conclude("", passed)
	var done := Cultivation.plan_retreat(self, int(passed.elapsed), tired, start)
	player.cultivation_carry = int(done.carry)
	player.fatigue = int(done.fatigue)
	player.fatigue_day = int(world.day)
	player.qi = player.max_qi
	record_deed("retreat_days", int(passed.elapsed))
	var text := log_event("cultivate", {"days": passed.elapsed, "xp": int(done.xp)})
	var milestones := gain_xp(int(done.xp))
	if not milestones.is_empty():
		text += " " + " ".join(milestones)
	if passed.interrupted:
		text = "闭关第 %d 日，外事惊动，你提前出关。%s" % [passed.elapsed, text]
	elif int(passed.elapsed) < days and at_xp_cap():
		text = "闭关第 %d 日，修为已臻此境之极。%s" % [passed.elapsed, text]
	elif int(passed.elapsed) < days:
		text = "闭关第 %d 日，修为触及瓶颈，再难寸进，你出关寻求机缘。%s" % [passed.elapsed, text]
	return conclude(text, passed)

## Stays where the player is. Interruptible like a retreat, but without cultivation.
func wait(days: int) -> String:
	var reason := blocked()
	if not reason.is_empty():
		return reason
	if days < 1 or days > MAX_SPAN_DAYS:
		return "停留天数不合常理。"
	var start := int(world.day)
	var passed := advance_days(days, true)
	if not ended.is_empty():
		return conclude("", passed)
	meet_during(start + 1, int(world.day))
	var text := log_event("wait", {"days": passed.elapsed, "location": player.location})
	Fortune.after_wait(self, int(passed.elapsed))
	return conclude(text, passed)

## The stays offered at a place: longer ones open with the realm, when a season is a short while.
func wait_options() -> Array:
	var options: Array = content.realm(int(player.realm)).get("wait_options", [])
	return options if not options.is_empty() else content.rules.wait_options

## Days of quiet rest needed to recover fully: proportional to the missing health, at least one.
func rest_days() -> int:
	var missing := float(int(player.max_hp) - int(player.hp)) / float(player.max_hp)
	return maxi(1, int(ceil(missing * float(content.rules.rest_full_days) * float(100 + talent_modifier("rest")) / 100.0)))

func choose_event(choice_id: String) -> String:
	if pending_event.is_empty():
		return "眼下没有需要抉择的事。"
	var message: String = Events.choose(self, choice_id)
	# A breakthrough that met 心魔 goes on once it is faced.
	if pending_event.is_empty() and player.has("attempt") and ended.is_empty():
		message = Breakthrough.resolve(self, message)
	var told := Storylines.update(self)
	if not told.is_empty():
		message = " ".join([message] + told)
	changed.emit()
	return message

func available_here(action: String) -> bool:
	return action in content.spot_actions(player.location, world.flags, int(player.get("rank", 0)))

func location_visible(location_id: String) -> bool:
	return content.location_visible(location_id, world.flags)

func snapshot() -> Dictionary:
	return {
		"version": SAVE_VERSION, "world": world.duplicate(true), "player": player.duplicate(true),
		"battle": battle.duplicate(true), "pending_event": pending_event.duplicate(true), "ended": ended.duplicate(true),
		"chronicle": chronicle.to_save(), "rng": {"combat": str(combat_rng.state), "world": str(world_rng.state)}
	}

## Replaces this session with saved data after migrating and validating it; see save_restore.gd.
func restore(data: Variant) -> bool:
	return SaveRestore.restore(self, data)

# --- Cultivation progress (cultivation.gd) ----------------------------------------------------

func settle_stage() -> Array[String]:
	return Cultivation.settle_stage(self)

func gain_xp(amount: int) -> Array[String]:
	return Cultivation.gain_xp(self, amount)

func gain_insight(source: String) -> Array[String]:
	return Cultivation.gain_insight(self, source)

func breach() -> Array[String]:
	return Cultivation.breach(self)

func at_bottleneck() -> bool:
	return Cultivation.at_bottleneck(self)

func xp_limit() -> int:
	return Cultivation.xp_limit(self)

func insight_needed() -> int:
	return Cultivation.insight_needed(self)

func retreat_fatigue() -> int:
	return Cultivation.fatigue(self)

# --- The sect (sect.gd) -----------------------------------------------------------------------

## The rank held: {"id", "name", "merit", "stage", "stipend", "retreat", ...}.
func sect_rank() -> Dictionary:
	return Sect.rank(self)

func next_sect_rank() -> Dictionary:
	return Sect.next_rank(self)

func promotion_block() -> String:
	return Sect.promotion_block(self)

func promote() -> String:
	return Sect.promote(self)

## {"periods", "stones"}.
func stipend_due() -> Dictionary:
	return Sect.stipend_due(self)

func collect_stipend() -> String:
	return Sect.collect_stipend(self)

## [{"key", "item", "price", "left", "block"}].
func sect_goods() -> Array[Dictionary]:
	return Sect.goods(self)

func sect_exchange(key: String) -> String:
	return Sect.exchange(self, key)

func donation_left() -> int:
	return Sect.donation_left(self)

func donation_value(item_id: String, count: int) -> int:
	return Sect.donation_value(self, item_id, count)

func donate(item_id: String, count: int) -> String:
	return Sect.donate(self, item_id, count)

# --- Alchemy and the field (alchemy.gd) --------------------------------------------------------

func known_recipes() -> Array[String]:
	return Alchemy.known(self)

func alchemy_plan(recipe_id: String) -> Dictionary:
	return Alchemy.default_plan(self, recipe_id)

func alchemy_block(plan: Dictionary) -> String:
	return Alchemy.block(self, plan)

## {"success", "fine", "yield", "balanced", "days", "fee", "furnace", "parts", "burst"}.
func alchemy_odds(plan: Dictionary) -> Dictionary:
	return Alchemy.odds(self, plan)

func brew(plan: Dictionary) -> String:
	return Alchemy.brew(self, plan)

## The 丹毒 left today.
func toxin() -> int:
	return Alchemy.toxin(self)

func field_plots() -> Array:
	return Alchemy.plots(self)

func plant(index: int, herb_id: String) -> String:
	return Alchemy.plant(self, index, herb_id)

func harvest(index: int) -> String:
	return Alchemy.harvest(self, index)

func upgrade_field() -> String:
	return Alchemy.upgrade(self)

# --- Bonds (bonds.gd) -------------------------------------------------------------------------

## Appointments and requests friends have sent by 传音 that wait for an answer.
func open_invites() -> Array:
	return world.get("invites", [])

func answer_loan(invite_id: String, lend: bool) -> String:
	return Bonds.answer_loan(self, invite_id, lend)

## Close friends who can be called into the duel now.
func duel_allies() -> Array[String]:
	return Bonds.allies(self)

func call_aid(person_id: String) -> String:
	return Combat.call_aid(self, person_id)

# --- Breakthrough (breakthrough.gd) -------------------------------------------------------------

## Breaks through with a plan: {"pills", "treasure", "guard"}.
func breakthrough(plan: Dictionary) -> String:
	var reason := blocked()
	if not reason.is_empty():
		return reason
	return Breakthrough.attempt(self, plan)

func breakthrough_plan() -> Dictionary:
	return Breakthrough.default_plan(self)

func breakthrough_block(plan: Dictionary) -> String:
	return Breakthrough.block(self, plan)

## {"total", "parts", "certain", "steps", "demon"}.
func breakthrough_odds(plan: Dictionary) -> Dictionary:
	return Breakthrough.odds(self, plan)

func breakthrough_guards() -> Array[String]:
	return Breakthrough.guards(self)

func breakthrough_treasures() -> Array[String]:
	return Breakthrough.treasures(self)

func face_demon(stance: String) -> String:
	return Breakthrough.face_demon(self, stance)

## The foundation's grade ({"name", "stats", "speed"}), or {} before foundation.
func foundation_grade() -> Dictionary:
	return Breakthrough.grade_of(self)

## Whether a failed breakthrough still hurts.
func injured() -> bool:
	return Breakthrough.injured(self)

## A chance draw in [0, 1): fixed by tests through `fortune`, else from the world stream.
func fortune_roll(tag: String) -> float:
	if fortune.has(tag):
		return float(fortune[tag])
	return world_rng.randf()

# --- Talents and aptitude (talents.gd) ---------------------------------------------------------

## The player's modifier from talents and flaws (talents.gd).
func talent_modifier(key: String) -> int:
	return Talents.modifier(self, key)

func has_talent(id: String) -> bool:
	return id in player.get("talents", []) or id in player.get("flaws", [])

## Gives a talent (or a flaw) fortune bestows; nothing when it is owned or clashes with one that is.
## Returns the chronicle text, or "".
func gain_talent(id: String) -> String:
	if not Talents.fits(content, Talents.owned(self), id):
		return ""
	var list: Array = player.flaws if Talents.is_flaw(content, id) else player.talents
	list.append(id)
	refresh_realm_stats()
	return log_event("talent_gained", {"talent": id}, true)

## The player's 资质: {"index", "name", "color"}.
func aptitude() -> Dictionary:
	return Talents.player_aptitude(self)

## Someone's talents and flaws: {"talents", "flaws"}; the player's for "".
func talents_of(person_id: String = "") -> Dictionary:
	if person_id.is_empty():
		return {"talents": player.get("talents", []), "flaws": player.get("flaws", [])}
	return People.talents_of(self, person_id)

## Someone's 资质, judged from their pace of cultivation and their talents.
func person_aptitude(person_id: String) -> Dictionary:
	return People.aptitude_of(self, person_id)

## Whether the player can see through someone's talents: once acquainted (相熟), or when standing above
## a generated person in cultivation (handwritten people only show theirs to those they know).
func talents_visible(person_id: String) -> bool:
	if favor(person_id) >= int(content.FAVOR_STAGES[1][0]):
		return true
	var someone := person(person_id)
	if not someone.get("generated", false):
		return false
	return int(player.realm) * 10 + int(player.stage) > int(someone.realm) * 10 + int(someone.stage)

## Days to study a technique, after talents.
func study_days(technique: Dictionary) -> int:
	return Talents.scaled(int(technique.study_days), talent_modifier("study"), 1)

## Days on the road along a path, after talents.
func path_days(path: Array[String]) -> int:
	var total := 0
	for index: int in range(1, path.size()):
		total += route_days(content.route_between(path[index - 1], path[index]))
	return total

func route_days(route: Dictionary) -> int:
	return Talents.scaled(int(route.days), talent_modifier("travel"), 1)

# --- Storylines, deeds and 传音 (storylines.gd) -------------------------------------------------

func start_story(story_id: String) -> Array[String]:
	return Storylines.start(self, story_id)

func story_advance(story_id: String) -> Array[String]:
	return Storylines.advance(self, story_id)

## "", "active", "done" or "closed".
func story_state(story_id: String) -> String:
	return Storylines.state(self, story_id)

func story_step(story_id: String) -> Dictionary:
	return Storylines.current_step(self, story_id)

func story_at(story_id: String, step_id: String) -> bool:
	return Storylines.at_step(self, story_id, step_id)

## The guided start's current step, or {} once the player is free.
func guide_step() -> Dictionary:
	return Storylines.guide_step(self)

## Why the guided start holds the player back from an action ("travel" toward `target`, or
## "cultivate"), or "".
func guide_block(action: String, target: String = "") -> String:
	var step := guide_step()
	if step.is_empty():
		return ""
	var mentor: String = content.people[Storylines.giver(self, Storylines.guide_story(self))].name
	var reason := "%s嘱咐过，先%s" % [mentor, str(step.get("goal", "把眼前的事做完。"))]
	match action:
		"travel":
			return "" if str(step.get("place", "")) == target else reason
		"cultivate":
			return "" if step.has("retreat_days") else reason
	return ""

func record_deed(deed: String, amount: int = 1) -> void:
	Storylines.record(self, deed, amount)

func deed_count(deed: String) -> int:
	return Storylines.deed_count(self, deed)

func exchange_sound(person_id: String) -> String:
	return Storylines.exchange_sound(self, person_id)

func congratulate(kind: String) -> Array[String]:
	return Storylines.congratulate(self, kind)

func unread_letters() -> int:
	return Storylines.unread_letters(self)

## Marks every 传音 as read; looking at the inbox takes no time.
func mark_letters_read() -> void:
	Storylines.mark_letters_read(self)

func story_due(from_day: int) -> Dictionary:
	return Storylines.next_due(self, from_day)

func story_fire(story_id: String) -> Dictionary:
	return Storylines.fire(self, story_id)

## A teaching card dismissed in this journey (the interface's guide) is not shown again.
func mark_taught(tip_id: String) -> void:
	if not tip_id in player.taught:
		player.taught.append(tip_id)

## The longest single retreat now, in days (see cultivation.gd).
func retreat_cap() -> int:
	return Cultivation.retreat_cap(self)

## The longest retreat the player may start now: the mind's limit, and the guided start's.
func retreat_most() -> int:
	var most := retreat_cap() if retreat_limits else MAX_SPAN_DAYS
	var step := guide_step()
	if step.has("retreat_days"):
		most = mini(most, int(step.retreat_days))
	return most

func mind_needed() -> int:
	return Cultivation.mind_needed(self)

## Percent of the usual retreat xp the mind allows.
func mind_percent() -> int:
	return Cultivation.mind_percent(self)

func gain_mind(amount: int) -> void:
	Cultivation.gain_mind(self, amount)

## The most xp this realm holds, or -1.
func xp_cap() -> int:
	return Cultivation.xp_cap(self)

func at_xp_cap() -> bool:
	return Cultivation.at_cap(self)

## Why a retreat cannot add to xp held at the realm's most.
func cap_text() -> String:
	if next_breakthrough().is_empty():
		return "修为已臻%s之极，后续境界尚未开放，闭关再难寸进。" % realm_name()
	return "修为已臻%s之极，闭关再难寸进；备齐所需，便可突破。" % realm_name()

## Percent of the usual xp the next retreat day would yield.
func retreat_efficiency() -> int:
	return Cultivation.efficiency(self, retreat_fatigue())

## What a retreat of `days` would bring if nothing interrupts it: {"days", "xp", "carry", "fatigue"}.
func retreat_preview(days: int) -> Dictionary:
	return Cultivation.plan_retreat(self, days, retreat_fatigue())

# --- Inventory (inventory.gd) ---------------------------------------------------------------

func item_count(item_id: String) -> int:
	return Inventory.item_count(self, item_id)

func herb_count() -> int:
	return Inventory.herb_count(self)

## A pill and its fine kind together (筑基丹 and 上品筑基丹).
func pill_count(item_id: String) -> int:
	return Inventory.family_count(self, item_id)

func add_item(item_id: String, count: int) -> void:
	Inventory.add_item(self, item_id, count)

func remove_item(item_id: String, count: int) -> bool:
	return Inventory.remove_item(self, item_id, count)

func remove_herbs(count: int) -> bool:
	return Inventory.remove_herbs(self, count)

func set_item_count(item_id: String, count: int) -> void:
	Inventory.set_item_count(self, item_id, count)

func sell_price(item_id: String) -> int:
	return Inventory.sell_price(self, item_id)

func shop_goods() -> Array:
	return Inventory.shop_goods(self)

func rotating_stock(location_id: String) -> Array[Dictionary]:
	return Inventory.rotating_stock(self, location_id)

func loot_code(found: Dictionary) -> String:
	return Inventory.loot_code(found)

func sell(item_id: String, count: int = 1) -> String:
	return Inventory.sell(self, item_id, count)

func buy(item_id: String) -> String:
	return Inventory.buy(self, item_id)

func use_block(item_id: String) -> String:
	return Inventory.use_block(self, item_id)

func use_item(item_id: String) -> String:
	return Inventory.use_item(self, item_id)

# --- Techniques, equipment and lineage (loadout.gd) -------------------------------------------

func bonuses(holder: Dictionary = {}) -> Dictionary:
	return Loadout.bonuses(self, holder)

func attack_bonus() -> int:
	return Loadout.attack_bonus(self)

func defense() -> float:
	return Loadout.defense(self)

func element_multiplier(t: Dictionary) -> float:
	return Loadout.element_multiplier(self, t)

func active_skills() -> Array[String]:
	return Loadout.active_skills(self)

func learn_block(technique_id: String) -> String:
	return Loadout.learn_block(self, technique_id)

func study_manual(item_id: String) -> String:
	return Loadout.study_manual(self, item_id)

func teachings() -> Array[String]:
	return Loadout.teachings(self)

func learn_here(technique_id: String) -> String:
	return Loadout.learn_here(self, technique_id)

func equip_technique(technique_id: String, replace: String = "") -> String:
	return Loadout.equip_technique(self, technique_id, replace)

func unequip_technique(technique_id: String) -> String:
	return Loadout.unequip_technique(self, technique_id)

func equip_item(item_id: String) -> String:
	return Loadout.equip_item(self, item_id)

func unequip_slot(slot: String) -> String:
	return Loadout.unequip_slot(self, slot)

func choose_sect(sect_id: String) -> String:
	return Loadout.choose_sect(self, sect_id)

# --- Commissions (commissions.gd) ---------------------------------------------------------------

func board_here() -> String:
	return Commissions.board_here(self)

func commission_offers(board: String) -> Array[Dictionary]:
	return Commissions.offers(self, board)

func commission_text(quest: Dictionary) -> Dictionary:
	return Commissions.text(self, quest)

func accept_commission(key: String) -> String:
	return Commissions.accept(self, key)

func delivery_block(quest: Dictionary) -> String:
	return Commissions.delivery_block(self, quest)

func deliver_commission(key: String) -> String:
	return Commissions.deliver(self, key)

func record_kill(enemy_id: String) -> void:
	Commissions.record_kill(self, enemy_id)

# --- Rumors (rumors.gd) -----------------------------------------------------------------------

func rumor_candidates() -> Array[Dictionary]:
	return Rumors.candidates(self)

func inquire() -> String:
	return Rumors.inquire(self)

# --- People (people.gd) -------------------------------------------------------------------------

func populate() -> void:
	People.populate(self)

func is_generated(person_id: String) -> bool:
	return People.is_generated(self, person_id)

func is_person(person_id: String) -> bool:
	return People.is_person(self, person_id)

func seat_lives(seat: int, day: int = -1, generation: int = -1) -> Array:
	return People.seat_lives(self, seat, day, generation)

func life_by_id(person_id: String) -> Dictionary:
	return People.life_by_id(self, person_id)

func life_at(seat: int, day: int) -> Dictionary:
	return People.life_at(self, seat, day)

func person(person_id: String) -> Dictionary:
	return People.person(self, person_id)

func npc_location(person_id: String, on_day: int = -1) -> String:
	return People.npc_location(self, person_id, on_day)

func present_npcs() -> Array[String]:
	return People.present_npcs(self)

func living_people() -> Array[String]:
	return People.living_people(self)

func meet_during(first_day: int, last_day: int) -> void:
	People.meet_during(self, first_day, last_day)

func known_npcs() -> Array[String]:
	return People.known_npcs(self)

func meet_present() -> void:
	People.meet_present(self)

func mark_met(person_id: String) -> void:
	People.mark_met(self, person_id)

func obituaries_changed() -> void:
	People.obituaries_changed(self)

func next_obituary(from_day: int) -> Dictionary:
	return People.next_obituary(self, from_day)

func favor(person_id: String) -> int:
	return People.favor(self, person_id)

func npc_depart(person_id: String) -> void:
	People.npc_depart(self, person_id)

## Whether an ordinary acquaintance is waiting for help (people.gd).
func request_open(person_id: String) -> bool:
	return People.request_open(self, person_id)

func npc_options(person_id: String) -> Array[Dictionary]:
	return People.npc_options(self, person_id)

func interact(person_id: String, option_id: String) -> String:
	return People.interact(self, person_id, option_id)

# --- Travel (journey.gd) ------------------------------------------------------------------------

func path_to(location_id: String) -> Array[String]:
	return Journey.path_to(self, location_id)

func travel(location_id: String) -> String:
	return Journey.travel(self, location_id)

func continue_journey() -> String:
	return Journey.continue_journey(self)

# --- Duels (combat.gd) --------------------------------------------------------------------------

func start_battle(enemy_id: String, opponent_sect: String = "") -> String:
	return Combat.start_battle(self, enemy_id, opponent_sect)

func begin_battle(enemy_id: String, context: String = "", opponent_sect: String = "") -> String:
	return Combat.begin_battle(self, enemy_id, context, opponent_sect)

func begin_spar(person_id: String) -> void:
	Combat.begin_spar(self, person_id)

func tournament_block() -> String:
	return Combat.tournament_block(self)

func enter_tournament() -> String:
	return Combat.enter_tournament(self)

func begin_tournament(round: int) -> void:
	Combat.begin_tournament(self, round)

func use_skill(skill_id: String) -> String:
	return Combat.use_skill(self, skill_id)

func defend() -> String:
	return Combat.defend(self)

func flee() -> String:
	return Combat.flee(self)
