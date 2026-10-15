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
