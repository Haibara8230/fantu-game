extends RefCounted
## The player's items: stacks, buying and selling, shop stock and using items. Operates on a Session.
## Everything the player carries is an item stack in player.items (id -> count). Content may still
## speak of "herbs" in general (any herb, cheapest paid first) and "pills" (筑基丹).
const Events = preload("res://scripts/core/events.gd")
const Arsenal = preload("res://scripts/core/arsenal.gd")
const Talents = preload("res://scripts/core/talents.gd")
const Alchemy = preload("res://scripts/core/alchemy.gd")
const Gear = preload("res://scripts/core/gear.gd")

## A 宝物 instance (gear.gd) counts once while carried, not while worn.
static func item_count(s, item_id: String) -> int:
	if Gear.is_instance(item_id):
		return 1 if s.player.get("gear", {}).has(item_id) and not Gear.worn(s, item_id) else 0
	return int(s.player.get("items", {}).get(item_id, 0))

static func herb_count(s) -> int:
	var total := 0
	for item_id: String in s.content.herbs_by_value():
		total += item_count(s, item_id)
	return total

static func add_item(s, item_id: String, count: int) -> void:
	if count <= 0 or Gear.is_instance(item_id):
		return
	s.player.items[item_id] = item_count(s, item_id) + count

## Removes up to `count`; returns false (and removes nothing) when there are not enough.
static func remove_item(s, item_id: String, count: int) -> bool:
	if count <= 0:
		return true
	if item_count(s, item_id) < count:
		return false
	# An instance leaves with its 祭炼.
	if Gear.is_instance(item_id):
		s.player.gear.erase(item_id)
		return true
	var left := item_count(s, item_id) - count
	if left == 0:
		s.player.items.erase(item_id)
	else:
		s.player.items[item_id] = left
	return true

## An item and its fine (上品) kind, which count as it wherever it is asked for: [id] or [id, fine id].
static func family(s, item_id: String) -> Array[String]:
	var ids: Array[String] = [item_id]
	var fine: String = s.content.fine_pill(item_id)
	if not fine.is_empty():
		ids.append(fine)
	return ids

static func family_count(s, item_id: String) -> int:
	var total := 0
	for id: String in family(s, item_id):
		total += item_count(s, id)
	return total

## Removes `count` of an item and its fine kind, the plain ones first (or the fine ones first); false
## (and nothing removed) when there are not enough.
static func remove_family(s, item_id: String, count: int, fine_first: bool = false) -> bool:
	if family_count(s, item_id) < count:
		return false
	var ids := family(s, item_id)
	if fine_first:
		ids.reverse()
	for id: String in ids:
		var taken := mini(count, item_count(s, id))
		remove_item(s, id, taken)
		count -= taken
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
	return _price_at(s, item_id, demand_factor(s, item_id))

## What `count` of the item fetch here together. A place short of something (its `demand`) pays the
## premium only until the shortage is filled, one at a time; anything else sells at its one price.
static func sale_value(s, item_id: String, count: int) -> int:
	var entry := demand_entry(s, item_id)
	if entry.is_empty():
		return sell_price(s, item_id) * count
	var filled := demand_filled(s, item_id)
	var total := 0
	for index: int in count:
		total += _price_at(s, item_id, _demand_rate(entry, filled + float(index)))
	return total

static func _price_at(s, item_id: String, factor: float) -> int:
	var item: Dictionary = s.content.item(Gear.type_of(s, item_id))
	if not s.available_here("sell") or item.is_empty():
		return 0
	if not item.category in s.content.locations[s.player.location].get("buys", []):
		return 0
	return Talents.scaled(int(round(float(item.price) * market_factor(s, item_id) * factor)), s.talent_modifier("sell"), 1)

## 跨城需求 (docs/GAME_OUTLINE.md 19.10): a place short of something (location `demand`: the item, the
## premium `factor`, how many it `need`s and the `days` the shortage takes to come back) pays more for
## it. Each one sold fills the need a little; the premium shrinks evenly to nothing as it fills, and the
## need returns over its days. world.demand_supply: {"place:item": {"count", "day"}}.
static func demand_entry(s, item_id: String) -> Dictionary:
	var type := str(Gear.type_of(s, item_id))
	for entry: Dictionary in s.content.locations[s.player.location].get("demand", []):
		if str(entry.item) == type:
			return entry
	return {}

## How much of the place's need for the item is filled now.
static func demand_filled(s, item_id: String) -> float:
	var entry := demand_entry(s, item_id)
	if entry.is_empty():
		return 0.0
	var sold: Dictionary = s.world.get("demand_supply", {}).get("%s:%s" % [s.player.location, entry.item], {})
	if sold.is_empty():
		return 0.0
	return maxf(0.0, float(sold.count) - float(int(s.world.day) - int(sold.day)) * float(entry.need) / float(entry.days))

## The premium on the next one sold here (1.0 when the place is not short of it).
static func demand_factor(s, item_id: String) -> float:
	var entry := demand_entry(s, item_id)
	return 1.0 if entry.is_empty() else _demand_rate(entry, demand_filled(s, item_id))

static func _demand_rate(entry: Dictionary, filled: float) -> float:
	return 1.0 + (float(entry.factor) - 1.0) * maxf(0.0, 1.0 - filled / float(entry.need))

## 坊市行情 (`rules.market`): what herbs fetch moves from month to month (a spread fixed by the world
## seed, the item and the month, so a reload changes nothing), and selling much of one herb lowers its
## price for a while (each one sold lately takes `drop` off, down to `floor`; the glut eases by
## `recover_per_day`). Other goods keep their price.
static func market_factor(s, item_id: String) -> float:
	var rule: Dictionary = s.content.rules.market
	if not str(s.content.item(item_id).get("category", "")) in rule.categories:
		return 1.0
	var month := int(s.world.day) / 30
	var roll: float = s.seeded_roll(["market", item_id, month])
	var season := 1.0 + float(rule.spread) * (roll * 2.0 - 1.0)
	return season * maxf(float(rule.floor), 1.0 - float(rule.drop) * glut(s, item_id))

## How many of a herb still weigh on the market from recent sales.
static func glut(s, item_id: String) -> float:
	var sold: Dictionary = s.world.get("market_supply", {}).get(item_id, {})
	if sold.is_empty():
		return 0.0
	return maxf(0.0, float(sold.count) - float(int(s.world.day) - int(sold.day)) * float(s.content.rules.market.recover_per_day))

## Records goods sold: a place's shortage fills, and herbs flood the market, so the next sale fetches less.
static func flood(s, item_id: String, count: int) -> void:
	var entry := demand_entry(s, item_id)
	if not entry.is_empty():
		if not s.world.has("demand_supply"):
			s.world["demand_supply"] = {}
		s.world.demand_supply["%s:%s" % [s.player.location, entry.item]] = {"count": snappedf(minf(float(entry.need), demand_filled(s, item_id) + float(count)), 0.01), "day": int(s.world.day)}
	if not str(s.content.item(item_id).get("category", "")) in s.content.rules.market.categories:
		return
	if not s.world.has("market_supply"):
		s.world["market_supply"] = {}
	s.world.market_supply[item_id] = {"count": snappedf(glut(s, item_id) + float(count), 0.01), "day": int(s.world.day)}

## Fixed goods plus this period's rotating stock (manuals, equipment), at the prices the player pays.
static func shop_goods(s) -> Array:
	if not s.available_here("shop"):
		return []
	var goods: Array = s.content.locations[s.player.location].get("shop", []).duplicate(true)
	goods.append_array(rotating_stock(s, s.player.location))
	var percent: int = s.talent_modifier("buy")
	# 沧澜's 客卿 buy at the sect's own price (guest.gd).
	var share: float = s.Guest.discount(s)
	for good: Dictionary in goods:
		good.price = maxi(1, int(round(float(Talents.scaled(int(good.price), percent, 1)) * share)))
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
	# Named by its type: an instance is gone once sold.
	var item_type := Gear.type_of(s, item_id)
	var revenue := sale_value(s, item_id, maxi(count, 0))
	if count < 1 or not remove_item(s, item_id, count):
		return "行囊里没有那么多。"
	s.player.stones += revenue
	flood(s, item_type, count)
	s.record_deed("trade")
	return s.conclude(s.log_event("sell_item", {"item": item_type, "count": count, "revenue": revenue}))

static func buy(s, item_id: String) -> String:
	var blocked: String = s.blocked()
	if not blocked.is_empty():
		return blocked
	if _teaches_known(s, s.content.item(item_id)):
		return "你已通晓此丹方。"
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
	if _teaches_known(s, s.content.item(item_id)):
		return "你已通晓此丹方。"
	var toxic := Alchemy.toxin_block(s, s.content.item(item_id))
	if not toxic.is_empty():
		return toxic
	# Pills that would be wasted by the bottleneck are refused rather than swallowed.
	for effect: Dictionary in s.content.item(item_id).use:
		if effect.has("longevity") and s.player.get("longevity", {}).has(str(effect.longevity[0])):
			return "同种延寿之物一生只见效一次，此物于你已无效。"
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
	Alchemy.add_toxin(s, item)
	var text: String = s.log_event("read_recipe" if item.category == "recipe" else "use_item", {"item": item_id})
	Events.apply(s, pill_effects(s, item))
	return s.conclude(text)

## Whether an item is a 丹方 the player already knows.
static func _teaches_known(s, item: Dictionary) -> bool:
	for effect: Dictionary in item.get("use", []):
		if effect.has("recipe") and Alchemy.knows(s, str(effect.recipe)):
			return true
	return false

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

## Delivery costs of accepted commissions and each current storyline add together.
static func reserved(s) -> Dictionary:
	var keep := {}
	for quest: Dictionary in s.player.get("quests", []):
		if quest.has("item"):
			keep[str(quest.item)] = int(keep.get(str(quest.item), 0)) + int(quest.count)
	for story_id: String in s.world.get("storylines", {}):
		var costs: Dictionary = s.Storylines.required_items(s, story_id)
		for item_id: String in costs:
			keep[item_id] = int(keep.get(item_id, 0)) + int(costs[item_id])
	for item_id: String in keep.keys():
		var fine: String = s.content.fine_pill(item_id)
		if not fine.is_empty():
			var missing := maxi(0, int(keep[item_id]) - item_count(s, item_id))
			keep[fine] = int(keep.get(fine, 0)) + mini(missing, maxi(0, item_count(s, fine) - int(keep.get(fine, 0))))
	var herbs_needed := 0
	for story_id: String in s.world.get("storylines", {}):
		herbs_needed += s.Storylines.required_herbs(s, story_id)
	for item_id: String in s.content.herbs_by_value():
		var taken := mini(herbs_needed, maxi(0, item_count(s, item_id) - int(keep.get(item_id, 0))))
		if taken > 0:
			keep[item_id] = int(keep.get(item_id, 0)) + taken
			herbs_needed -= taken
	return keep

## Ordinary gifts use an unreserved herb and name it before the player chooses.
static func gift_herb(s) -> String:
	var keep := reserved(s)
	for item_id: String in s.content.herbs_by_value():
		if item_count(s, item_id) > int(keep.get(item_id, 0)):
			return item_id
	return ""
