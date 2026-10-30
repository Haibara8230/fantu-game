extends RefCounted
## Explicit prices and compatible combinations for new journeys; legacy IDs stay in old saves.
const Talents = preload("res://scripts/core/talents.gd")

static func data(content) -> Dictionary:
	return content.opening_data

## Historical field name: a character point budget, not combat difficulty.
static func difficulty(content, id: String) -> Dictionary:
	for entry: Dictionary in data(content).difficulties:
		if str(entry.id) == id:
			return entry
	return {}

static func fresh(content) -> Dictionary:
	var chosen := ""
	for entry: Dictionary in data(content).difficulties:
		if bool(entry.get("default", false)):
			chosen = str(entry.id)
	return {"difficulty": chosen, "roots": [], "root_count": int(data(content).default_roots), "picks": {}}

static func root_cost(content, count: int) -> int:
	for entry: Dictionary in data(content).roots:
		if int(entry.count) == count:
			return int(entry.cost)
	return 0

static func cost(content, id: String) -> int:
	if Talents.is_flaw(content, id):
		return -int(data(content).refunds.get(id, 0))
	return int(data(content).costs.get(id, 0))

static func page(content, page_id: String) -> Dictionary:
	for entry: Dictionary in data(content).pages:
		if str(entry.id) == page_id:
			return entry
	return {}

static func fits_roots(content, id: String, roots: Array) -> bool:
	return data(content).root_bound.get(id, []).all(func(element: Variant) -> bool: return element in roots)

static func offered(content, page_id: String, roots: Array) -> Array[String]:
	var found: Array[String] = []
	var entry := page(content, page_id)
	for id: Variant in entry.get("talents", []) + entry.get("flaws", []):
		if fits_roots(content, str(id), roots):
			found.append(str(id))
	return found

static func selected(choice: Dictionary, page_id: String) -> Array:
	var value: Variant = choice.get("picks", {}).get(page_id, [])
	return value if value is Array else ([] if str(value).is_empty() else [str(value)])

static func points(content, choice: Dictionary) -> int:
	return int(difficulty(content, str(choice.get("difficulty", ""))).get("points", 0))

static func spent(content, choice: Dictionary) -> int:
	var total := root_cost(content, int(choice.get("root_count", 3)))
	for page_id: String in choice.get("picks", {}):
		for id: Variant in selected(choice, page_id):
			total += cost(content, str(id))
	return total

static func left(content, choice: Dictionary) -> int:
	return points(content, choice) - spent(content, choice)

static func born(content, choice: Dictionary) -> Dictionary:
	var talents: Array = []
	var flaws: Array = []
	for entry: Dictionary in data(content).pages:
		for id: Variant in selected(choice, str(entry.id)):
			(flaws if Talents.is_flaw(content, str(id)) else talents).append(id)
	return {"talents": talents, "flaws": flaws}

static func pick_block(content, choice: Dictionary, page_id: String, id: String) -> String:
	if id in selected(choice, page_id) or id.is_empty():
		return ""
	if not id in offered(content, page_id, choice.get("roots", [])):
		return "该天赋不在此页，或灵根不合。"
	var taken := born(content, choice)
	if not Talents.fits(content, taken.talents + taken.flaws, id):
		return "与已选天赋互斥，请先取消冲突项。"
	# Defects remain selectable while in debt, making negative-budget roles usable.
	if cost(content, id) > 0 and left(content, choice) < cost(content, id):
		return "天赋点不够（还差 %d 点）。" % (cost(content, id) - left(content, choice))
	return ""

static func toggle(content, choice: Dictionary, page_id: String, id: String) -> void:
	var picks := selected(choice, page_id).duplicate()
	if id in picks:
		picks.erase(id)
	elif pick_block(content, choice, page_id, id).is_empty():
		picks.append(id)
	choice.picks[page_id] = picks

static func block(content, choice: Dictionary) -> String:
	if difficulty(content, str(choice.get("difficulty", ""))).is_empty():
		return "先选角色出身点数。"
	var roots: Array = choice.get("roots", [])
	var count := int(choice.get("root_count", 0))
	if count < 1 or count > 5 or roots.size() != count:
		return "请选齐对应数量的灵根。"
	var unique := {}
	for element: Variant in roots:
		if not element in content.rules.spirit_roots.elements or unique.has(element):
			return "灵根不可重复或含未知五行。"
		unique[element] = true
	var owned: Array = []
	for page_id: String in choice.get("picks", {}):
		if page(content, page_id).is_empty():
			return "天赋页无效，请重新选择。"
		for id: Variant in selected(choice, page_id):
			if not id is String or not id in offered(content, page_id, roots):
				return "天赋不属于此页或灵根不合。"
			if not Talents.fits(content, owned, id):
				return "天赋重复或互斥，请重新选择。"
			owned.append(id)
	if left(content, choice) < 0:
		return "天赋点超支 %d 点；取消天赋、降低灵根品类或选择缺陷。" % -left(content, choice)
	return ""

static func set_root_count(content, choice: Dictionary, count: int) -> void:
	choice.root_count = clampi(count, 1, 5)
	var roots: Array = choice.get("roots", [])
	if count >= 5:
		roots = content.rules.spirit_roots.elements.duplicate()
	choice.roots = roots.slice(0, choice.root_count)
	_drop_unfit(content, choice)

static func toggle_root(content, choice: Dictionary, element: String) -> void:
	if not element in content.rules.spirit_roots.elements:
		return
	var roots: Array = choice.get("roots", [])
	if element in roots:
		roots.erase(element)
	elif roots.size() < int(choice.root_count):
		roots.append(element)
	choice.roots = roots
	_drop_unfit(content, choice)

static func _drop_unfit(content, choice: Dictionary) -> void:
	for page_id: String in choice.get("picks", {}).keys():
		choice.picks[page_id] = selected(choice, page_id).filter(func(id: Variant) -> bool: return fits_roots(content, str(id), choice.roots))
