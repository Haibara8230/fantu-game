extends RefCounted
## 开局 (docs/OPENING_DRAFT_20261022.md), after 觅长生: a difficulty gives the talent points, then the
## spirit roots are chosen by kind and element and one entry is taken on each page (出身, 先天体质, 天资,
## 性格, 儿时经历, 青年经历; or none of them, for nothing). A talent costs its tier's price; a flaw gives
## points back by how heavy it is (`refunds`); the roots cost by how many there are. Some talents need a
## root of their element (`root_bound`); some are left for play to grant (`earned`). Pure rules on the
## content and a choice: {"difficulty", "roots": [elements], "root_count", "picks": {page id: talent or
## flaw id}}; the welcome screen (welcome_screen.gd) shows them and Session.new_game starts from them.
const Talents = preload("res://scripts/core/talents.gd")

static func data(content) -> Dictionary:
	return content.opening_data

static func difficulty(content, difficulty_id: String) -> Dictionary:
	for entry: Dictionary in data(content).difficulties:
		if str(entry.id) == difficulty_id:
			return entry
	return {}

## The choice a new journey starts from: the default difficulty, three roots not yet chosen, nothing taken.
static func fresh(content) -> Dictionary:
	var chosen := ""
	for entry: Dictionary in data(content).difficulties:
		if bool(entry.get("default", false)):
			chosen = str(entry.id)
	return {"difficulty": chosen, "roots": [], "root_count": int(data(content).default_roots), "picks": {}}

## Points the roots cost (negative: points given back).
static func root_cost(content, count: int) -> int:
	for entry: Dictionary in data(content).roots:
		if int(entry.count) == count:
			return int(entry.cost)
	return 0

## Points an entry costs: a talent its tier's price, a flaw the negative of its refund.
static func cost(content, id: String) -> int:
	if id.is_empty():
		return 0
	if Talents.is_flaw(content, id):
		return -int(data(content).refunds.get(id, 0))
	return int(data(content).tier_costs.get(str(Talents.definition(content, id).get("tier", "")), 0))

## The page an entry is offered on, or {}.
static func page(content, page_id: String) -> Dictionary:
	for entry: Dictionary in data(content).pages:
		if str(entry.id) == page_id:
			return entry
	return {}

## Whether the roots allow an entry: those bound to elements need every one of them among the roots.
static func fits_roots(content, id: String, roots: Array) -> bool:
	return data(content).root_bound.get(id, []).all(func(element: Variant) -> bool: return element in roots)

## The entries a page offers for these roots, talents by price then flaws.
static func offered(content, page_id: String, roots: Array) -> Array[String]:
	var found: Array[String] = []
	var entry := page(content, page_id)
	var talents: Array = entry.get("talents", []).filter(func(id: Variant) -> bool: return fits_roots(content, str(id), roots))
	talents.sort_custom(func(a: Variant, b: Variant) -> bool: return cost(content, str(a)) < cost(content, str(b)) or (cost(content, str(a)) == cost(content, str(b)) and str(a) < str(b)))
	for id: Variant in talents:
		found.append(str(id))
	for id: Variant in entry.get("flaws", []):
		if fits_roots(content, str(id), roots):
			found.append(str(id))
	return found

static func points(content, choice: Dictionary) -> int:
	return int(difficulty(content, str(choice.get("difficulty", ""))).get("points", 0))

static func spent(content, choice: Dictionary) -> int:
	var total := root_cost(content, int(choice.get("root_count", 3)))
	for page_id: String in choice.get("picks", {}):
		total += cost(content, str(choice.picks[page_id]))
	return total

static func left(content, choice: Dictionary) -> int:
	return points(content, choice) - spent(content, choice)

## The talents and flaws taken: {"talents", "flaws"} (Session.new_game's `born`).
static func born(content, choice: Dictionary) -> Dictionary:
	var talents: Array = []
	var flaws: Array = []
	for entry: Dictionary in data(content).pages:
		var id := str(choice.get("picks", {}).get(str(entry.id), ""))
		if not id.is_empty():
			(flaws if Talents.is_flaw(content, id) else talents).append(id)
	return {"talents": talents, "flaws": flaws}

## Why `id` cannot be taken on its page now, or "": its points, its roots, or a talent it cannot sit with.
static func pick_block(content, choice: Dictionary, page_id: String, id: String) -> String:
	if id.is_empty():
		return ""
	if not id in offered(content, page_id, choice.get("roots", [])):
		return "灵根不合：须有%s灵根。" % "、".join(data(content).root_bound.get(id, []).map(func(element: Variant) -> String: return str(content.rules.spirit_roots.names.get(element, element))))
	var other := choice.duplicate(true)
	other.picks[page_id] = id
	if left(content, other) < 0:
		return "天赋点不够（还差 %d 点）。" % -left(content, other)
	var taken := born(content, choice)
	var owned: Array = taken.talents + taken.flaws
	owned.erase(str(choice.picks.get(page_id, "")))
	if not Talents.fits(content, owned, id):
		return "与已选的天赋相冲。"
	return ""

## Why the journey cannot start from this choice, or "".
static func block(content, choice: Dictionary) -> String:
	if difficulty(content, str(choice.get("difficulty", ""))).is_empty():
		return "先选难度。"
	var roots: Array = choice.get("roots", [])
	var count := int(choice.get("root_count", 3))
	if roots.size() != count:
		return "灵根还差 %d 行没选。" % (count - roots.size())
	for page_id: String in choice.get("picks", {}):
		var id := str(choice.picks[page_id])
		if not id.is_empty() and not fits_roots(content, id, roots):
			return "%s须有对应的灵根。" % Talents.definition(content, id).get("name", id)
	if left(content, choice) < 0:
		return "天赋点超支 %d 点。" % -left(content, choice)
	return ""

## Roots chosen: kind first (how many), then elements; changing the kind keeps those still allowed and
## drops picks the new roots no longer allow.
static func set_root_count(content, choice: Dictionary, count: int) -> void:
	choice.root_count = clampi(count, 1, 5)
	var roots: Array = choice.get("roots", [])
	if count >= 5:
		roots = content.rules.spirit_roots.elements.duplicate()
	choice.roots = roots.slice(0, choice.root_count)
	_drop_unfit(content, choice)

static func toggle_root(content, choice: Dictionary, element: String) -> void:
	var roots: Array = choice.get("roots", [])
	if element in roots:
		roots.erase(element)
	elif roots.size() < int(choice.root_count):
		roots.append(element)
	choice.roots = roots
	_drop_unfit(content, choice)

static func _drop_unfit(content, choice: Dictionary) -> void:
	for page_id: String in choice.get("picks", {}).keys():
		if not fits_roots(content, str(choice.picks[page_id]), choice.roots):
			choice.picks.erase(page_id)
