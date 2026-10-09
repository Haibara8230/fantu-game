extends RefCounted
## Gameplay state and rules. No UI or filesystem dependency.
const Content = preload("res://scripts/core/content.gd")
const Calendar = preload("res://scripts/core/calendar.gd")
const Chronicle = preload("res://scripts/core/chronicle.gd")
const Combat = preload("res://scripts/core/combat.gd")
const Events = preload("res://scripts/core/events.gd")
const Arsenal = preload("res://scripts/core/arsenal.gd")
const SaveMigration = preload("res://scripts/core/save_migration.gd")
const SAVE_VERSION := SaveMigration.CURRENT_VERSION
const PLAYER_COUNTS := ["realm", "xp", "hp", "qi", "stones", "cultivation_carry"]
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

## `roots` are the spirit-root elements chosen at creation; when empty they are sensed (rolled) here.
func new_game(character_name: String = "无名", seed_value: int = -1, roots: Array = []) -> void:
	if seed_value >= 0:
		combat_rng.seed = seed_value
		world_rng.seed = hash(str(seed_value) + ":world")
	if roots.is_empty():
		roots = roll_roots(world_rng)
	var chosen_name := character_name.strip_edges().left(16)
	if chosen_name.is_empty():
		chosen_name = "无名"
	world = {"day": 0, "flags": {}, "events": {}, "people": {}, "seed": seed_value if seed_value >= 0 else absi(int(world_rng.randi())), "stock_sold": {}}
	player = {
		"name": chosen_name, "birth_day": -int(content.rules.starting_age) * Calendar.DAYS_PER_YEAR,
		"realm": 0, "stage": 0, "xp": 0, "hp": 0, "qi": 0, "cultivation_carry": 0, "warned_for": -1, "roots": roots.duplicate(),
		"stones": int(content.rules.starting_stones), "items": {},
		"journey": {}, "cooldowns": {},
		"location": "sect", "sect": "wanderer",
		"learned": [], "arts": [], "methods": [], "equipment": {"weapon": "", "robe": "", "accessory": ""}
	}
	for skill_id: String in content.sects.wanderer.skills:
		player.learned.append(skill_id)
		player.arts.append(skill_id)
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

func root_title() -> String:
	return content.root_title(player.get("roots", []))

func cultivation_speed() -> float:
	return float(content.root_grade(player.get("roots", [])).speed) * (1.0 + float(bonuses().cultivation))

## Xp gained per 30 days of closed-door cultivation with these roots.
func cultivation_rate() -> int:
	return int(round(float(content.rules.cultivate_xp) * cultivation_speed()))

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

## Recomputes the sub-stage from xp. Reaching a higher stage raises the stat caps, gives the new
## headroom to current hp and qi, and is recorded as a milestone. Returns the milestone texts.
func settle_stage() -> Array[String]:
	var texts: Array[String] = []
	var reached: int = content.stage_index(int(player.realm), int(player.xp))
	while int(player.stage) < reached:
		var old_hp := int(player.max_hp)
		var old_qi := int(player.max_qi)
		player.stage = int(player.stage) + 1
		_refresh_realm_stats()
		player.hp = int(player.hp) + int(player.max_hp) - old_hp
		player.qi = int(player.qi) + int(player.max_qi) - old_qi
		texts.append(log_event("stage_up", {"realm": int(player.realm), "stage": int(player.stage)}, true))
	return texts

func _refresh_realm_stats() -> void:
	var current: Dictionary = stage_stats()
	var extra := bonuses()
	player.max_hp = int(current.max_hp) + int(extra.max_hp)
	player.max_qi = int(current.max_qi) + int(extra.max_qi)
	if player.has("hp"):
		player.hp = mini(int(player.hp), int(player.max_hp))
		player.qi = mini(int(player.qi), int(player.max_qi))

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
			var found := _gather_picks(content.locations[player.location].gather)
			for item_id: String in found:
				add_item(item_id, int(found[item_id]))
			return conclude(log_event("gather_items", {"days": passed.elapsed, "location": player.location, "loot": loot_code(found)}), passed)
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
			return conclude(log_event("search_ruin", found), passed)
		"sell":
			# Sell every item this place buys, in one go.
			var sold := {}
			for item_id: String in player.items.keys():
				if sell_price(item_id) > 0:
					sold[item_id] = item_count(item_id)
			if sold.is_empty():
				return "行囊里没有这里收购的东西。"
			var revenue := 0
			for item_id: String in sold:
				revenue += sell_price(item_id) * int(sold[item_id])
				remove_item(item_id, int(sold[item_id]))
			player.stones += revenue
			return conclude(log_event("sell_all", {"loot": loot_code(sold), "revenue": revenue}))
		"breakthrough":
			var need := next_breakthrough()
			if need.is_empty():
				return "后续境界尚未开放。"
			var last_stage: int = content.realm(int(player.realm)).stages.size() - 1
			if int(player.stage) < last_stage or int(player.xp) < int(need.xp) or item_count("foundation_pill") < int(need.pills):
				return "突破需修至%s，并有 %d 修为与 %d 枚筑基丹。" % [content.realm_title(int(player.realm), last_stage), int(need.xp), int(need.pills)]
			remove_item("foundation_pill", int(need.pills))
			player.xp -= int(need.xp)
			var passed := advance_days(days)
			if not ended.is_empty():
				return conclude("", passed)
			player.realm += 1
			player.stage = 0
			_refresh_realm_stats()
			player.hp = player.max_hp
			player.qi = player.max_qi
			var texts: Array[String] = [log_event("breakthrough", {"days": passed.elapsed, "realm": int(player.realm), "stage": 0}, true)]
			texts.append_array(settle_stage())
			return conclude(" ".join(texts), passed)
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
	var milestones := settle_stage()
	if not milestones.is_empty():
		text += " " + " ".join(milestones)
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

## Days of quiet rest needed to recover fully: proportional to the missing health, at least one.
func rest_days() -> int:
	var missing := float(int(player.max_hp) - int(player.hp)) / float(player.max_hp)
	return maxi(1, int(ceil(missing * float(content.rules.rest_full_days))))

func _gain_cultivation(days: int) -> int:
	var total := int(player.cultivation_carry) + days * cultivation_rate()
	var gained := total / Calendar.DAYS_PER_MONTH
	player.cultivation_carry = total % Calendar.DAYS_PER_MONTH
	player.xp += gained
	return gained

# --- Inventory -----------------------------------------------------------------------
# Everything the player carries is an item stack in player.items (id -> count). Content may still
# speak of "herbs" in general (any herb, cheapest paid first) and "pills" (筑基丹).

func item_count(item_id: String) -> int:
	return int(player.get("items", {}).get(item_id, 0))

func herb_count() -> int:
	var total := 0
	for item_id: String in content.herbs_by_value():
		total += item_count(item_id)
	return total

func add_item(item_id: String, count: int) -> void:
	if count <= 0:
		return
	player.items[item_id] = item_count(item_id) + count

## Removes up to `count`; returns false (and removes nothing) when there are not enough.
func remove_item(item_id: String, count: int) -> bool:
	if count <= 0:
		return true
	if item_count(item_id) < count:
		return false
	var left := item_count(item_id) - count
	if left == 0:
		player.items.erase(item_id)
	else:
		player.items[item_id] = left
	return true

## Pays a generic herb cost, cheapest herbs first.
func remove_herbs(count: int) -> bool:
	if herb_count() < count:
		return false
	for item_id: String in content.herbs_by_value():
		var taken := mini(count, item_count(item_id))
		remove_item(item_id, taken)
		count -= taken
	return true

## Sets a stack directly (tests and tools).
func set_item_count(item_id: String, count: int) -> void:
	player.items.erase(item_id)
	add_item(item_id, count)

## What this place pays for one of the item, or 0 when it does not buy it here.
func sell_price(item_id: String) -> int:
	if not available_here("sell") or content.item(item_id).is_empty():
		return 0
	var item: Dictionary = content.item(item_id)
	return int(item.price) if item.category in content.locations[player.location].get("buys", []) else 0

## Fixed goods plus this period's rotating stock (manuals, equipment).
func shop_goods() -> Array:
	if not available_here("shop"):
		return []
	var goods: Array = content.locations[player.location].get("shop", []).duplicate()
	goods.append_array(rotating_stock(player.location))
	return goods

## Compact loot record for the chronicle: "id:count,id:count".
func loot_code(found: Dictionary) -> String:
	var parts: Array[String] = []
	for item_id: String in found:
		parts.append("%s:%d" % [item_id, int(found[item_id])])
	return ",".join(parts)

func _gather_picks(gather: Dictionary) -> Dictionary:
	var found := {}
	var total := 0
	for entry: Dictionary in gather.table:
		total += int(entry.weight)
	for pick: int in world_rng.randi_range(int(gather.picks[0]), int(gather.picks[1])):
		var roll := world_rng.randi_range(1, total)
		for entry: Dictionary in gather.table:
			roll -= int(entry.weight)
			if roll <= 0:
				found[entry.item] = int(found.get(entry.item, 0)) + 1
				break
	return found

func sell(item_id: String, count: int = 1) -> String:
	var blocked := _blocked()
	if not blocked.is_empty():
		return blocked
	var price := sell_price(item_id)
	if price <= 0:
		return "这里不收这件东西。"
	if count < 1 or not remove_item(item_id, count):
		return "行囊里没有那么多。"
	player.stones += price * count
	return conclude(log_event("sell_item", {"item": item_id, "count": count, "revenue": price * count}))

func buy(item_id: String) -> String:
	var blocked := _blocked()
	if not blocked.is_empty():
		return blocked
	for good: Dictionary in shop_goods():
		if good.item == item_id:
			if int(player.stones) < int(good.price):
				return "灵石不足：%s需要 %d 灵石。" % [content.item(item_id).name, int(good.price)]
			player.stones -= int(good.price)
			add_item(item_id, 1)
			if good.has("key"):
				world.stock_sold[good.key] = true
			return conclude(log_event("buy_item", {"item": item_id, "price": int(good.price)}))
	return "这里买不到这件东西。"

## Why an item cannot be used right now, or "".
func use_block(item_id: String) -> String:
	var blocked := _blocked()
	if not blocked.is_empty():
		return blocked
	if not content.item(item_id).has("use"):
		return "此物不能直接服用。"
	if item_count(item_id) < 1:
		return "行囊里没有此物。"
	var ready := int(player.cooldowns.get("use:" + item_id, 0))
	if int(world.day) < ready:
		return "丹毒未消，%s后再服。" % Calendar.duration_text(ready - int(world.day))
	return ""

func use_item(item_id: String) -> String:
	var reason := use_block(item_id)
	if not reason.is_empty():
		return reason
	var item: Dictionary = content.item(item_id)
	remove_item(item_id, 1)
	if item.has("use_cooldown_days"):
		player.cooldowns["use:" + item_id] = int(world.day) + int(item.use_cooldown_days)
	var text := log_event("use_item", {"item": item_id})
	Events.apply(self, item.use)
	return conclude(text)

# --- Techniques and equipment ------------------------------------------------------------
# player.learned lists every technique known; player.arts (up to rules.art_slots) are usable in duels
# and player.methods (up to rules.method_slots) are passive 心法. player.equipment holds one item id
# per slot; equipped items leave the 行囊 and return to it when taken off.

## Totals from 心法 and equipment: attack, max_hp, max_qi, defense, cultivation, element_damage {element|"*": x}.
func bonuses(holder: Dictionary = {}) -> Dictionary:
	if holder.is_empty():
		holder = player
	var total := {"attack": 0, "max_hp": 0, "max_qi": 0, "defense": 0.0, "cultivation": 0.0, "element_damage": {}}
	var sources: Array[Dictionary] = []
	for technique_id: Variant in holder.get("methods", []):
		var method: Dictionary = content.technique(str(technique_id))
		if not method.is_empty():
			sources.append({"stats": method.passive, "element": method.element})
	for slot: String in holder.get("equipment", {}):
		var gear: Dictionary = content.equipment(str(holder.equipment[slot]))
		if not gear.is_empty():
			sources.append({"stats": gear.stats, "element": "*" if gear.element == "none" else gear.element})
	for source: Dictionary in sources:
		for key: String in source.stats:
			if key == "element_damage":
				total.element_damage[source.element] = float(total.element_damage.get(source.element, 0.0)) + float(source.stats[key])
			elif key in ["defense", "cultivation"]:
				total[key] = float(total[key]) + float(source.stats[key])
			else:
				total[key] = int(total[key]) + int(source.stats[key])
	return total

func attack_bonus() -> int:
	return int(stage_stats().attack_bonus) + int(bonuses().attack)

## Share of incoming damage avoided by equipment, capped at half.
func defense() -> float:
	return minf(0.5, float(bonuses().defense))

## Damage multiplier for a technique: element bonuses, plus a little extra when it matches a spirit root.
func element_multiplier(t: Dictionary) -> float:
	var damage: Dictionary = bonuses().element_damage
	var multiplier := 1.0 + float(damage.get(t.element, 0.0)) + float(damage.get("*", 0.0))
	if t.element in player.get("roots", []):
		multiplier += float(content.technique_data.root_bonus)
	return multiplier

## Why the player cannot learn this technique now, or "".
func learn_block(technique_id: String) -> String:
	var t: Dictionary = content.technique(technique_id)
	if t.is_empty():
		return "此法无从参悟。"
	if technique_id in player.learned:
		return "你已习得此法。"
	if int(player.realm) < int(t.min_realm):
		return "%s之法，需达到%s方可参悟。" % [t.tier_name, content.realm_title(int(t.min_realm), 0)]
	return _blocked()

## Studies a technique for its tier's days; the new technique goes into a free slot if there is one.
func _study(technique_id: String) -> Dictionary:
	var t: Dictionary = content.technique(technique_id)
	var passed := advance_days(int(t.study_days))
	if not ended.is_empty():
		return passed
	player.learned.append(technique_id)
	var slots: Array = player.arts if t.slot == "art" else player.methods
	if slots.size() < int(content.rules.art_slots if t.slot == "art" else content.rules.method_slots):
		slots.append(technique_id)
	_refresh_realm_stats()
	passed.text = log_event("learn", {"technique": technique_id, "days": passed.elapsed}, int(t.tier) >= 3)
	return passed

## Studies the technique written in a jade slip from the 行囊.
func study_manual(item_id: String) -> String:
	var manual: Dictionary = content.item(item_id)
	if manual.get("category", "") != "manual" or item_count(item_id) < 1:
		return "行囊里没有这枚玉简。"
	var reason := learn_block(manual.teaches)
	if not reason.is_empty():
		return reason
	remove_item(item_id, 1)
	var passed := _study(manual.teaches)
	return conclude(str(passed.get("text", "")), passed)

## Techniques taught by the scene here (the sect's 传功堂).
func teachings() -> Array[String]:
	var result: Array[String] = []
	if not available_here("teach"):
		return result
	for spot: Dictionary in content.locations[player.location].spots:
		for technique_id: String in spot.get("teach", []):
			result.append(technique_id)
	return result

func learn_here(technique_id: String) -> String:
	if not technique_id in teachings():
		return "这里不传授此法。"
	var reason := learn_block(technique_id)
	if not reason.is_empty():
		return reason
	var passed := _study(technique_id)
	return conclude(str(passed.get("text", "")), passed)

## Puts a learned technique into its slots, replacing `replace` when the slots are full.
func equip_technique(technique_id: String, replace: String = "") -> String:
	var t: Dictionary = content.technique(technique_id)
	if not technique_id in player.learned or t.is_empty():
		return "尚未习得此法。"
	if not battle.is_empty():
		return "斗法中无法更换功法。"
	var slots: Array = player.arts if t.slot == "art" else player.methods
	var limit := int(content.rules.art_slots if t.slot == "art" else content.rules.method_slots)
	if technique_id in slots:
		return "此法已在运转。"
	if slots.size() >= limit:
		if not replace in slots:
			return "栏位已满，请先选择要替换的功法。"
		slots.erase(replace)
	slots.append(technique_id)
	_refresh_realm_stats()
	return finish("改为运转%s。" % t.name)

func unequip_technique(technique_id: String) -> String:
	if not battle.is_empty():
		return "斗法中无法更换功法。"
	var t: Dictionary = content.technique(technique_id)
	var slots: Array = player.arts if t.get("slot", "art") == "art" else player.methods
	if not technique_id in slots:
		return "此法并未运转。"
	if t.get("slot", "art") == "art" and slots.size() <= 1:
		return "至少保留一门神通。"
	slots.erase(technique_id)
	_refresh_realm_stats()
	return finish("停下了%s。" % t.name)

func equip_item(item_id: String) -> String:
	var gear: Dictionary = content.equipment(item_id)
	if gear.is_empty() or item_count(item_id) < 1:
		return "行囊里没有这件法宝。"
	if not battle.is_empty():
		return "斗法中无法更换法宝。"
	var worn := str(player.equipment.get(gear.slot, ""))
	remove_item(item_id, 1)
	if not worn.is_empty():
		add_item(worn, 1)
	player.equipment[gear.slot] = item_id
	_refresh_realm_stats()
	return finish("换上了%s。" % gear.name)

func unequip_slot(slot: String) -> String:
	var worn := str(player.equipment.get(slot, ""))
	if worn.is_empty():
		return "此处没有佩戴法宝。"
	if not battle.is_empty():
		return "斗法中无法更换法宝。"
	player.equipment[slot] = ""
	add_item(worn, 1)
	_refresh_realm_stats()
	return finish("取下了%s。" % content.equipment(worn).name)

## A place's stock that changes every restock period: deterministic per world, place and period.
## Returns [{"item", "price", "key"}]; sold goods are left out until the next restock.
func rotating_stock(location_id: String) -> Array[Dictionary]:
	var goods: Array[Dictionary] = []
	var location: Dictionary = content.locations[location_id]
	if not location.has("stock"):
		return goods
	var period := int(world.day) / int(location.stock.restock_days)
	var rng := RandomNumberGenerator.new()
	rng.seed = hash([int(world.get("seed", 0)), location_id, period])
	var index := 0
	for line: Dictionary in location.stock.lines:
		for count: int in int(line.count):
			var tier := rng.randi_range(int(line.tiers[0]), int(line.tiers[1]))
			var item_id := ""
			if line.kind == "manual":
				item_id = "j:" + Arsenal.generate_technique(content, rng, tier, {"slot": line.slot} if line.has("slot") else {})
			else:
				item_id = Arsenal.generate_equipment(content, rng, tier)
			var key := "%s:%d:%d" % [location_id, period, index]
			index += 1
			if not world.stock_sold.has(key):
				goods.append({"item": item_id, "price": int(content.item(item_id).price) * 2, "key": key})
	return goods

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
	for id: Variant in player.get("arts", []):
		result.append(str(id))
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
	# Taking up a lineage teaches its three arts and puts them in the art slots.
	player.sect = sect_id
	player.arts = []
	for skill_id: String in content.sects[sect_id].skills:
		if not skill_id in player.learned:
			player.learned.append(skill_id)
		player.arts.append(skill_id)
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
		return "%s气息凶险，需达到%s。" % [enemy.name, content.realm_title(int(enemy.min_realm), 0)]
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
	battle = {"enemy_id": enemy_id, "hp": int(enemy.hp), "turn": 1, "cooldowns": {}, "opponent_sect": opponent_sect, "status": {}}
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
	# The sub-stage always follows from xp; stat caps follow from the stage.
	var saved_stage: int = content.stage_index(int(saved_player.realm), int(saved_player.xp))
	var loadout := _valid_loadout(saved_player)
	if loadout.is_empty():
		return false
	var caps: Dictionary = content.stage(int(saved_player.realm), saved_stage)
	var extra := bonuses(loadout)
	if int(saved_player.hp) <= 0 or int(saved_player.hp) > int(caps.max_hp) + int(extra.max_hp) or int(saved_player.qi) > int(caps.max_qi) + int(extra.max_qi):
		return false
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
		if not _whole_nonnegative(saved_battle.get("hp")) or int(saved_battle.hp) <= 0 or int(saved_battle.hp) > int(content.enemies[saved_battle.enemy_id].hp):
			return false
		if not _whole_nonnegative(saved_battle.get("turn")) or int(saved_battle.turn) < 1 or not saved_battle.get("cooldowns") is Dictionary:
			return false
		for skill_id: Variant in saved_battle.cooldowns:
			if not skill_id is String or content.technique(skill_id).is_empty() or not _whole_nonnegative(saved_battle.cooldowns[skill_id]):
				return false
		if saved_battle.has("context") and saved_battle.context != "event":
			return false
		var status: Variant = saved_battle.get("status", {})
		if not status is Dictionary:
			return false
		for key: Variant in status:
			if not key in ["burn", "weaken"] or not status[key] is Array or status[key].size() != 2:
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
	var sold := {}
	for key: Variant in saved_world.get("stock_sold", {}):
		if key is String:
			sold[key] = true
	var seed_value: Variant = saved_world.get("seed", 0)
	world = {"day": day, "flags": saved_world.flags.duplicate(), "events": events, "people": people, "seed": int(seed_value) if _whole_nonnegative(seed_value) else 0, "stock_sold": sold}
	player = saved_player.duplicate(true)
	for key: String in PLAYER_COUNTS:
		player[key] = int(player[key])
	player.birth_day = int(birth)
	player.stage = saved_stage
	player.roots = roots.duplicate()
	for key: String in loadout:
		player[key] = loadout[key]
	player.warned_for = int(warned)
	for item_id: String in player.items:
		player.items[item_id] = int(player.items[item_id])
	player.journey = {} if journey.is_empty() else {"to": journey.to}
	for action_id: String in player.cooldowns:
		player.cooldowns[action_id] = int(player.cooldowns[action_id])
	_refresh_realm_stats()
	battle = saved_battle.duplicate(true)
	if not battle.is_empty():
		if not battle.has("status"):
			battle.status = {}
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

## The saved techniques and equipment, keeping only what the content still knows. {} when malformed.
## Unknown ids are dropped instead of rejecting the save, so retired content cannot lock a journey.
func _valid_loadout(saved_player: Dictionary) -> Dictionary:
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
