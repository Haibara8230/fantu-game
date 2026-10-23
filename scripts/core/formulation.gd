extends RefCounted
## A custom formula substitutes by potency, while the ordinary recipe remains an unchanged preset.

static func main_for(content, plan: Dictionary) -> Dictionary:
	if plan.get("main") is Dictionary:
		return plan.main.duplicate()
	return content.alchemy_data.recipes.get(str(plan.get("recipe", "")), {}).get("main", {}).duplicate()

static func potency(content, herbs: Dictionary) -> Dictionary:
	var total := {}
	var properties: Dictionary = content.formulation_data.properties
	for id: String in herbs:
		for key: String in properties.get(id, {}):
			total[key] = int(total.get(key, 0)) + int(herbs[id]) * int(properties[id][key])
	return total

static func problem(content, plan: Dictionary) -> String:
	if not plan.has("main"):
		return ""
	if not plan.main is Dictionary or plan.main.is_empty():
		return "调整丹方后，须投入主药。"
	var count := 0
	for id: Variant in plan.main:
		if not id is String or not content.formulation_data.properties.has(id) or not whole(plan.main[id], 20) or int(plan.main[id]) < 1:
			return "主药须为可入此炉的灵草，数量为 1 至 20 株。"
		count += int(plan.main[id])
	if count > int(content.formulation_data.maximum_herbs):
		return "一炉主药不能超过 %d 株。" % int(content.formulation_data.maximum_herbs)
	var default_main: Dictionary = content.alchemy_data.recipes.get(str(plan.get("recipe", "")), {}).get("main", {})
	var required := potency(content, default_main)
	var provided := potency(content, plan.main)
	for key: String in required:
		if int(provided.get(key, 0)) < int(required[key]):
			return "%s药性不足：%d / %d。" % [content.formulation_data.names[key], int(provided.get(key, 0)), int(required[key])]
	return ""

static func whole(value: Variant, cap: int) -> bool:
	return (value is int or value is float) and is_finite(float(value)) and float(value) == floor(float(value)) and float(value) >= 0 and float(value) <= cap

static func valid_data(content) -> bool:
	var data: Dictionary = content.formulation_data
	if not data.get("properties") is Dictionary or not data.get("names") is Dictionary or not data.get("forge_affinities") is Dictionary or not data.get("sigils") is Dictionary or not whole(data.get("maximum_herbs"), 60):
		return false
	for id: Variant in data.properties:
		if content.item(str(id)).get("category", "") != "herb" or not data.properties[id] is Dictionary:
			return false
		for key: Variant in data.properties[id]:
			if not data.names.has(key) or not whole(data.properties[id][key], 100):
				return false
	for family: Variant in data.forge_affinities:
		var choices: Variant = data.forge_affinities[family]
		if not content.equipment_data.materials.has(family) or not choices is Array or choices.any(func(id: Variant) -> bool: return not content.equipment_data.affixes.has(id)):
			return false
	for id: Variant in data.sigils:
		var rule: Variant = data.sigils[id]
		if not id in ["vermilion", "tiger"] or not rule is Dictionary or not rule.get("name") is String or not rule.get("text") is String or not rule.get("dao") in ["sigil_vermilion", "sigil_tiger"] or not (rule.get("scale") is int or rule.get("scale") is float) or float(rule.scale) < 1 or float(rule.scale) > 3:
			return false
		if not is_finite(float(rule.scale)):
			return false
		if id == "vermilion" and (not (rule.get("threshold") is int or rule.get("threshold") is float) or not is_finite(float(rule.threshold)) or float(rule.threshold) <= 0 or float(rule.threshold) > 1):
			return false
		if id == "tiger" and (not whole(rule.get("self_damage"), 100) or int(rule.self_damage) < 1):
			return false
	return true
