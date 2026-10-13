extends RefCounted
## The player's items: stacks, buying and selling, shop stock and using items. Operates on a Session.
## Everything the player carries is an item stack in player.items (id -> count). Content may still
## speak of "herbs" in general (any herb, cheapest paid first) and "pills" (筑基丹).
const Calendar = preload("res://scripts/core/calendar.gd")
const Events = preload("res://scripts/core/events.gd")
const Arsenal = preload("res://scripts/core/arsenal.gd")
const Talents = preload("res://scripts/core/talents.gd")

static func item_count(s, item_id: String) -> int:
	return int(s.player.get("items", {}).get(item_id, 0))

static func herb_count(s) -> int:
	var total := 0
	for item_id: String in s.content.herbs_by_value():
		total += item_count(s, item_id)
	return total

static func add_item(s, item_id: String, count: int) -> void:
	if count <= 0:
		return
	s.player.items[item_id] = item_count(s, item_id) + count

## Removes up to `count`; returns false (and removes nothing) when there are not enough.
static func remove_item(s, item_id: String, count: int) -> bool:
	if count <= 0:
		return true
	if item_count(s, item_id) < count:
		return false
	var left := item_count(s, item_id) - count
	if left == 0:
		s.player.items.erase(item_id)
	else:
		s.player.items[item_id] = left
	return true

## Pays a generic herb cost, cheapest herbs first.
static func remove_herbs(s, count: int) -> bool:
	if herb_count(s) < count:
		return false
	for item_id: String in s.content.herbs_by_value():
		var taken := mini(count, item_count(s, item_id))
		remove_item(s, item_id, taken)
		count -= taken
	return true

## Sets a stack directly (tests and tools).
static func set_item_count(s, item_id: String, count: int) -> void:
	s.player.items.erase(item_id)
	add_item(s, item_id, count)

## What this place pays for one of the item, or 0 when it does not buy it here.
static func sell_price(s, item_id: String) -> int:
	if not s.available_here("sell") or s.content.item(item_id).is_empty():
		return 0
	var item: Dictionary = s.content.item(item_id)
	if not item.category in s.content.locations[s.player.location].get("buys", []):
		return 0
	return Talents.scaled(int(item.price), s.talent_modifier("sell"), 1)

## Fixed goods plus this period's rotating stock (manuals, equipment), at the prices the player pays.
static func shop_goods(s) -> Array:
	if not s.available_here("shop"):
		return []
	var goods: Array = s.content.locations[s.player.location].get("shop", []).duplicate(true)
	goods.append_array(rotating_stock(s, s.player.location))
	var percent: int = s.talent_modifier("buy")
	for good: Dictionary in goods:
		good.price = Talents.scaled(int(good.price), percent, 1)
	return goods

## A place's stock that changes every restock period: deterministic per world, place and period.
## Returns [{"item", "price", "key"}]; sold goods are left out until the next restock.
static func rotating_stock(s, location_id: String) -> Array[Dictionary]:
	var goods: Array[Dictionary] = []
	var location: Dictionary = s.content.locations[location_id]
	if not location.has("stock"):
		return goods
	var period := int(s.world.day) / int(location.stock.restock_days)
	var rng := RandomNumberGenerator.new()
	rng.seed = hash([int(s.world.get("seed", 0)), location_id, period])
	var index := 0
	for line: Dictionary in location.stock.lines:
		for count: int in int(line.count):
			var tier := rng.randi_range(int(line.tiers[0]), int(line.tiers[1]))
			var item_id := ""
			if line.kind == "manual":
				item_id = "j:" + Arsenal.generate_technique(s.content, rng, tier, {"slot": line.slot} if line.has("slot") else {})
			else:
				item_id = Arsenal.generate_equipment(s.content, rng, tier)
			var key := "%s:%d:%d" % [location_id, period, index]
			index += 1
			if not s.world.stock_sold.has(key):
				goods.append({"item": item_id, "price": int(s.content.item(item_id).price) * 2, "key": key})
	return goods

## Compact loot record for the chronicle: "id:count,id:count".
static func loot_code(found: Dictionary) -> String:
	var parts: Array[String] = []
	for item_id: String in found:
		parts.append("%s:%d" % [item_id, int(found[item_id])])
	return ",".join(parts)

## What one gathering trip finds, drawn from the world stream: {item_id: count}.
static func gather_picks(s, gather: Dictionary) -> Dictionary:
	var found := {}
	var total := 0
	for entry: Dictionary in gather.table:
		total += int(entry.weight)
	var picks: int = s.world_rng.randi_range(int(gather.picks[0]), int(gather.picks[1]))
	for pick: int in Talents.scaled(picks, s.talent_modifier("gather"), 1):
		var roll: int = s.world_rng.randi_range(1, total)
		for entry: Dictionary in gather.table:
			roll -= int(entry.weight)
			if roll <= 0:
				found[entry.item] = int(found.get(entry.item, 0)) + 1
				break
	return found

static func sell(s, item_id: String, count: int = 1) -> String:
	var blocked: String = s.blocked()
	if not blocked.is_empty():
		return blocked
	var price := sell_price(s, item_id)
	if price <= 0:
		return "这里不收这件东西。"
	if count < 1 or not remove_item(s, item_id, count):
		return "行囊里没有那么多。"
	s.player.stones += price * count
	s.record_deed("trade")
	return s.conclude(s.log_event("sell_item", {"item": item_id, "count": count, "revenue": price * count}))

static func buy(s, item_id: String) -> String:
	var blocked: String = s.blocked()
	if not blocked.is_empty():
		return blocked
	for good: Dictionary in shop_goods(s):
		if good.item == item_id:
			if int(s.player.stones) < int(good.price):
				return "灵石不足：%s需要 %d 灵石。" % [s.content.item(item_id).name, int(good.price)]
			s.player.stones -= int(good.price)
			add_item(s, item_id, 1)
			s.record_deed("trade")
			if good.has("key"):
				s.world.stock_sold[good.key] = true
			return s.conclude(s.log_event("buy_item", {"item": item_id, "price": int(good.price)}))
	return "这里买不到这件东西。"

## Why an item cannot be used right now, or "".
static func use_block(s, item_id: String) -> String:
	var blocked: String = s.blocked()
	if not blocked.is_empty():
		return blocked
	if not s.content.item(item_id).has("use"):
		return "此物不能直接服用。"
	if item_count(s, item_id) < 1:
		return "行囊里没有此物。"
	var ready := int(s.player.cooldowns.get("use:" + item_id, 0))
	if int(s.world.day) < ready:
		return "丹毒未消，%s后再服。" % Calendar.duration_text(ready - int(s.world.day))
	# Pills that would be wasted by the bottleneck are refused rather than swallowed.
	for effect: Dictionary in s.content.item(item_id).use:
		if effect.has("breach") and not s.at_bottleneck():
			return "修为未至瓶颈，服之无益。"
		if effect.has("xp") and s.at_bottleneck():
			return "修为卡在瓶颈，药力难以化入，先冲开瓶颈再服。"
	return ""

static func use_item(s, item_id: String) -> String:
	var reason := use_block(s, item_id)
	if not reason.is_empty():
		return reason
	var item: Dictionary = s.content.item(item_id)
	remove_item(s, item_id, 1)
	if item.has("use_cooldown_days"):
		s.player.cooldowns["use:" + item_id] = int(s.world.day) + Talents.scaled(int(item.use_cooldown_days), s.talent_modifier("pill_cooldown"), 1)
	var text: String = s.log_event("use_item", {"item": item_id})
	Events.apply(s, pill_effects(s, item))
	return s.conclude(text)

## An item's effects when used: a pill's xp, health and qi follow the talents for pills.
static func pill_effects(s, item: Dictionary) -> Array:
	if item.category != "pill":
		return item.use
	var percent: int = s.talent_modifier("pill")
	var effects: Array = []
	for effect: Dictionary in item.use:
		var key: String = effect.keys()[0]
		if key in ["xp", "hp", "qi"] and int(effect[key]) > 0:
			effects.append({key: Talents.scaled(int(effect[key]), percent, 1)})
		else:
			effects.append(effect)
	return effects
