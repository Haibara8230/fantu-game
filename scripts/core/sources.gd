extends RefCounted
## Where the player knows an item can be had: the shops of places they can reach, the sect's exchange,
## and the recipes they know, with the herbs in hand. Only what the player can know is listed, so a
## tracked goal never points at a hidden cave or a lot not yet announced. Operates on a Session.
## First version of the material tracking in docs/WORLD_EXPANSION.md 7.6 (item 41): the realm's
## breakthrough pills, read from the same data the shop, the exchange and the furnace use.

## [{"kind": "shop" | "exchange" | "recipe", "text": String, "ready": bool}], in that order. "ready" is
## whether the player could take it now (stones, contribution and rank, or every herb in hand).
static func of(s, item_id: String) -> Array[Dictionary]:
	var result: Array[Dictionary] = []
	for location_id: String in s.content.locations:
		var location: Dictionary = s.content.locations[location_id]
		if not s.location_visible(location_id):
			continue
		for line: Dictionary in location.get("shop", []):
			if line.item == item_id:
				result.append({"kind": "shop", "text": "%s丹铺 %d 灵石" % [location.name, int(line.price)], "ready": int(s.player.stones) >= int(line.price)})
	for location_id: String in s.content.locations:
		if not s.location_visible(location_id):
			continue
		var place: Dictionary = s.content.locations[location_id]
		for drop: Dictionary in place.get("gather", {}).get("table", []):
			if str(drop.item) == item_id:
				var sealed: bool = s.content.location_sealed(location_id, s.world.flags)
				result.append({"kind":"gather", "text":"%s采集%s" % [place.name, "（暂时封锁）" if sealed else ""], "ready":not sealed})
	for person_id: String in s.content.people:
		if not bool(s.world.people.get(person_id, {}).get("met", false)):
			continue
		var person: Dictionary = s.content.people[person_id]
		for interaction: Dictionary in person.get("interactions", []):
			if not interaction.get("effects", []).any(func(effect: Dictionary) -> bool: return effect.has("item") and str(effect.item[0]) == item_id and int(effect.item[1]) > 0):
				continue
			var known_conditions: Array = interaction.get("conditions", []).filter(func(c: Dictionary) -> bool: return not c.has("stones_at_least") and not c.has("item_at_least") and not c.has("herbs_at_least"))
			if not s.Events.all_met(s, known_conditions):
				continue
			if bool(interaction.get("once", false)) and s.world.people[person_id].get("last", {}).has(interaction.id):
				continue
			var ready := false
			var reason := ""
			for option: Dictionary in s.npc_options(person_id):
				if str(option.id) == str(interaction.id):
					ready = bool(option.available)
					reason = str(option.reason)
			result.append({"kind":"person", "text":"%s：%s%s" % [person.name, interaction.label, "（%s）" % reason if not reason.is_empty() else ""], "ready":ready})
	var exchanged := {}
	for good: Dictionary in s.sect_goods():
		if good.item != item_id or exchanged.has(good.item):
			continue
		exchanged[good.item] = true
		var block: String = good.block
		var text := "青云执事堂 %d 贡献" % int(good.price)
		if block.begins_with("须为"):
			text += "（%s）" % block.trim_suffix("。")
		result.append({"kind": "exchange", "text": text, "ready": block.is_empty()})
	for recipe_id: String in s.Alchemy.known(s):
		var recipe: Dictionary = s.Alchemy.recipe(s, recipe_id)
		if recipe.pill != item_id and str(recipe.get("fine", "")) != item_id:
			continue
		var parts: Array[String] = []
		var ready := true
		for herb_id: String in recipe.main:
			var held: int = s.item_count(herb_id)
			ready = ready and held >= int(recipe.main[herb_id])
			parts.append("%s %d/%d" % [s.content.item(herb_id).name, held, int(recipe.main[herb_id])])
		result.append({"kind": "recipe", "text": "自炼：" + "、".join(parts), "ready": ready})
	return result

## The known sources as one line for a goal's text: "可得于：…；…". Empty when none is known.
static func line(s, item_id: String) -> String:
	var texts: Array[String] = []
	for source: Dictionary in of(s, item_id):
		texts.append(source.text)
	return "" if texts.is_empty() else "可得于：" + "；".join(texts) + "。"
