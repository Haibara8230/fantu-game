extends RefCounted
## 炼器: forging a piece of equipment from materials at a forge (the market's 器铺). Operates on a
## Session. Data in data/forge.json: each material's family (metal, cloth, jade — the families of the
## bases in data/equipment.json) and tier. A forging takes `count` materials of one kind for a base of
## the same family, an element chosen by the player (or none), a fee and days by the tier; the piece
## comes out at the material's tier. Its affixes and variant follow from the world seed and how many
## pieces have been forged in this life (player.forged), so loading a save forges the same piece again.
## plan: {"base", "material", "element", "flux"}. With `flux` (data `flux`, 地火精 from 天南) one more is
## spent and the piece comes out with that many more affixes.
const Arsenal = preload("res://scripts/core/arsenal.gd")

static func data(s) -> Dictionary:
	return s.content.forge_data

## The bases a material can make, by family.
static func bases_for(s, material_id: String) -> Array[String]:
	var found: Array[String] = []
	var family := str(data(s).materials.get(material_id, {}).get("family", ""))
	for base_id: String in s.content.equipment_data.bases:
		if str(s.content.equipment_data.bases[base_id].material) == family:
			found.append(base_id)
	found.sort()
	return found

## The materials in the pack, cheapest first.
static func materials_held(s) -> Array[String]:
	var found: Array[String] = []
	for material_id: String in data(s).materials:
		if s.item_count(material_id) > 0:
			found.append(material_id)
	found.sort_custom(func(a: String, b: String) -> bool: return int(data(s).materials[a].tier) < int(data(s).materials[b].tier) or (int(data(s).materials[a].tier) == int(data(s).materials[b].tier) and a < b))
	return found

static func tier_of(s, material_id: String) -> int:
	return int(data(s).materials.get(material_id, {}).get("tier", 1))

static func fee(s, material_id: String) -> int:
	return int(data(s).fee[tier_of(s, material_id) - 1])

static func days(s, material_id: String) -> int:
	return int(data(s).days[tier_of(s, material_id) - 1])

## Why the plan cannot be forged here and now, or "".
static func block(s, plan: Dictionary) -> String:
	var reason: String = s.blocked()
	if not reason.is_empty():
		return reason
	if not s.available_here("forge"):
		return "此地没有器铺。"
	var material := str(plan.get("material", ""))
	if not data(s).materials.has(material):
		return "先选一种材料。"
	if not str(plan.get("base", "")) in bases_for(s, material):
		return "这种材料打不出此物。"
	var element := str(plan.get("element", "none"))
	if element != "none" and not s.content.technique_data.elements.has(element):
		return "未知的属性。"
	if s.item_count(material) < int(data(s).count):
		return "%s不足 %d 份。" % [s.content.item(material).name, int(data(s).count)]
	if int(s.player.stones) < fee(s, material):
		return "灵石不足：炉火与器师要 %d 灵石。" % fee(s, material)
	if bool(plan.get("flux", false)) and s.item_count(flux_item(s)) < 1:
		return "行囊里没有%s。" % s.content.item(flux_item(s)).name
	return ""

## What can be thrown into the furnace for more affixes (地火精), or "" when nothing can.
static func flux_item(s) -> String:
	return str(data(s).get("flux", {}).get("item", ""))

## The affixes a piece of this material comes out with, with or without the flux.
static func affix_count(s, material_id: String, flux: bool) -> int:
	var count := int(s.content.equipment_data.tiers[tier_of(s, material_id) - 1].affixes)
	if flux and not flux_item(s).is_empty():
		count += int(data(s).flux.affixes)
	return mini(count, s.content.equipment_data.affixes.size())

## Forges the piece: materials and fee are spent, the days pass, the piece goes into the pack.
static func forge(s, plan: Dictionary) -> String:
	var reason := block(s, plan)
	if not reason.is_empty():
		return reason
	var material := str(plan.material)
	var tier := tier_of(s, material)
	s.remove_item(material, int(data(s).count))
	var flux := bool(plan.get("flux", false))
	if flux:
		s.remove_item(flux_item(s), 1)
	s.player.stones = int(s.player.stones) - fee(s, material)
	var made := int(s.player.get("forged", 0))
	s.player["forged"] = made + 1
	var rng := RandomNumberGenerator.new()
	rng.seed = hash([int(s.world.get("seed", 0)), "forge", made, str(plan.base), material])
	var affixes: Array = s.content.equipment_data.affixes.keys()
	affixes.sort()
	var piece := Arsenal.equipment_id(str(plan.base), tier, str(plan.get("element", "none")), Arsenal._pick(rng, affixes, affix_count(s, material, flux)), rng.randi_range(0, 9))
	var passed: Dictionary = s.advance_days(days(s, material))
	if not s.ended.is_empty():
		return s.conclude("", passed)
	s.add_item(piece, 1)
	return s.conclude(s.log_event("forged", {"days": passed.elapsed, "item": piece}), passed)
