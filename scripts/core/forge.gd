extends RefCounted
## 炼器: forging a piece of equipment from materials at a forge (the market's 器铺). Operates on a
## Session. Data in data/forge.json: each material's family (metal, cloth, jade — the families of the
## bases in data/equipment.json) and tier. A forging takes `count` materials of one kind for a base of
## the same family, an element chosen by the player (or none), a fee and days by the tier; the piece
## comes out at the material's tier, or the lowest tier in an optional mixed-material plan.
## Materials can select affinity-based affixes; unselected slots and the variant follow the world seed and how many
## pieces have been forged in this life (player.forged), so loading a save forges the same piece again.
## plan: {"base", "material", "element", "flux"}. With `flux` (data `flux`, 地火精 from 天南) one more is
## spent and the piece comes out with that many more affixes.
const Arsenal = preload("res://scripts/core/arsenal.gd")
const Formulation = preload("res://scripts/core/formulation.gd")

static func ingredients(s, plan: Dictionary) -> Dictionary:
	return plan.materials.duplicate() if plan.get("materials") is Dictionary else {str(plan.get("material", "")): int(data(s).count)}

static func tier_for_plan(s, plan: Dictionary) -> int:
	var tier := tier_of(s, str(plan.get("material", "")))
	for id: String in ingredients(s, plan):
		tier = mini(tier, tier_of(s, id))
	return tier

static func affixes_for(s, plan: Dictionary) -> Array[String]:
	var result: Array[String] = []
	for id: String in ingredients(s, plan):
		var family := str(data(s).materials.get(id, {}).get("family", ""))
		for key: String in s.content.formulation_data.forge_affinities.get(family, []):
			if not key in result:
				result.append(key)
	return result

static func data(s) -> Dictionary:
	return s.content.forge_data

## The bases a material can make, by family.
static func bases_for(s, material_id: String) -> Array[String]:
	var found: Array[String] = []
	var family := str(data(s).materials.get(material_id, {}).get("family", ""))
	for base_id: String in s.content.equipment_data.bases:
		if str(s.content.equipment_data.bases[base_id].material) == family and not s.content.equipment_data.bases[base_id].has("named"):
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

## The furnace's fee; nothing at 赤霄's own furnace for its 客卿 (guest.gd).
static func fee(s, material_id: String) -> int:
	if s.Guest.perk_here(s, "forge_free"):
		return 0
	return int(data(s).fee[tier_of(s, material_id) - 1])

static func days(s, material_id: String) -> int:
	return maxi(1, int(round(int(data(s).days[tier_of(s, material_id) - 1]) * (1.0 - s.Dao.value(s, "forge_speed")))))

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
	if plan.has("materials") and not plan.materials is Dictionary:
		return "炼器材料配置无效。"
	var total := 0
	var parts := ingredients(s, plan)
	if not parts.has(material):
		return "须投入选定的主材。"
	for id: Variant in parts:
		if not id is String or not data(s).materials.has(id) or not Formulation.whole(parts[id], 12) or int(parts[id]) < 1:
			return "每种炼器材料须投入 1 至 12 份。"
		total += int(parts[id])
		if s.item_count(id) < int(parts[id]):
			return "%s不足 %d 份。" % [s.content.item(id).name, int(parts[id])]
	if total < int(data(s).count) or total > 12:
		return "每炉合计需 %d 至 12 份材料。" % int(data(s).count)
	var chosen: Variant = plan.get("affixes", [])
	var budget := int(s.content.equipment_data.tiers[tier_for_plan(s, plan) - 1].affixes) + (int(data(s).flux.affixes) if bool(plan.get("flux", false)) else 0)
	if not chosen is Array or chosen.size() > budget or chosen.any(func(id: Variant) -> bool: return not id is String or not id in affixes_for(s, plan) or chosen.count(id) != 1):
		return "材料承载不了所选词条，或词条数量超过成器品阶。"
	var sigil := str(plan.get("sigil", ""))
	if not sigil.is_empty():
		var rule: Dictionary = s.content.formulation_data.sigils.get(sigil, {})
		if rule.is_empty() or s.Dao.value(s, str(rule.dao)) <= 0 or s.content.equipment_data.bases[str(plan.base)].slot != "weapon":
			return "尚未领悟此灵纹，或器型不能铭刻。"
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
	var tier := tier_for_plan(s, plan)
	for id: String in ingredients(s, plan):
		s.remove_item(id, int(ingredients(s, plan)[id]))
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
	var picked: Array = plan.get("affixes", []).duplicate()
	var budget := mini(affix_count(s, material, flux), int(s.content.equipment_data.tiers[tier - 1].affixes) + (int(data(s).flux.affixes) if flux else 0))
	var pool: Array = affixes.filter(func(id: String) -> bool: return not id in picked)
	picked.append_array(Arsenal._pick(rng, pool, maxi(0, budget - picked.size())))
	var piece := Arsenal.equipment_id(str(plan.base), tier, str(plan.get("element", "none")), picked, rng.randi_range(0, 9))
	var passed: Dictionary = s.advance_days(days(s, material))
	if not s.ended.is_empty():
		return s.conclude("", passed)
	if not str(plan.get("sigil", "")).is_empty():
		var instance: String = s.Gear._create(s, piece)
		s.player.gear[instance].sigil = str(plan.sigil)
	else:
		s.add_item(piece, 1)
	s.Dao.gain(s, "craft", tier * 288)
	return s.conclude(s.log_event("forged", {"days": passed.elapsed, "item": piece}), passed)
