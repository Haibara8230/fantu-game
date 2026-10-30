extends RefCounted
## 天赋 definitions live in data/talents.json. New openings use the separate `opening_only` catalogue
## with explicit prices; legacy saves and generated people retain the original birth tables below.
## six tiers from 寻常 (white) to 天命 (red), and 先天缺陷 (flaws) apart from them. Birth tables decide
## how often each tier is born: around 青云山 most people have none or a white one and nobody rises
## above blue; only the protagonist may be born with more, very rarely. A talent changes the
## rules only through a shared set of modifiers (MODIFIERS), summed over everything a person has; the
## formulas that use them live with their own systems. Talents marked `gained` are never born with:
## fortune (机缘) bestows them later.
## The player's talents are rolled at creation (player.talents, player.flaws); the generated
## population's follow from the world seed and the life, so nothing about them is saved.
## Legacy 资质 sums roots and tier scores; new opening rarity is visual and contributes no hidden score.

## Every modifier a talent may carry; all whole numbers. Percentages unless noted: cultivation speed,
## max_hp/max_qi (of the stage's), attack (flat), defense, damage_<element> and damage_all, lifespan
## (years), retreat_days (the longest retreat), fresh_days (retreat days before weariness), insight,
## mind_gain, mind_need (the mind a stage asks), breakthrough (points of the odds), pill (a pill's effect),
## pill_cooldown (the 丹毒 a pill leaves), alchemy (points of a brew's success; half as much for a fine
## pill), grade (chance of a better foundation), demon (chance to keep 心魔 away), boon (chance of
## fortune), study (days to study), gather (finds), sell, buy (prices), favor (favor gained), travel
## (days on the road), encounter (chance of trouble on the road), rest (days to recover), stones (flat,
## at the start); in duels, flat: orb_draw (more qi orbs a turn), orb_cap (more held), orb_first (more
## in the first hand) and orb_<element> (that element drawn more often, added to its weight); sense
## (神识, flat).
const MODIFIERS := [
	"cultivation", "max_hp", "max_qi", "attack", "defense",
	"damage_metal", "damage_wood", "damage_water", "damage_fire", "damage_earth", "damage_all",
	"lifespan", "retreat_days", "fresh_days", "insight", "mind_gain", "mind_need",
	"breakthrough", "pill", "pill_cooldown", "alchemy", "grade", "demon", "boon",
	"study", "gather", "sell", "buy", "favor", "travel", "encounter", "rest", "stones",
	"orb_draw", "orb_cap", "orb_first", "orb_metal", "orb_wood", "orb_water", "orb_fire", "orb_earth",
	"sense", "comprehension", "hp_flat", "hp_growth", "sense_flat", "speed_flat", "dao_realm", "immortal_start",
]
## The duel modifiers (qi orbs), summed as they are wherever they come from.
const ORB_KEYS := ["orb_draw", "orb_cap", "orb_first", "orb_metal", "orb_wood", "orb_water", "orb_fire", "orb_earth"]

static func data(content) -> Dictionary:
	return content.talent_data

## A talent's or a flaw's definition, or {}.
static func definition(content, id: String) -> Dictionary:
	var talents: Dictionary = data(content).get("talents", {})
	if talents.has(id):
		return talents[id]
	return data(content).get("flaws", {}).get(id, {})

static func is_flaw(content, id: String) -> bool:
	return data(content).get("flaws", {}).has(id)

## The tier entry of a talent ({"id", "name", "color", "weight", "score"}); flaws use the flaw entry.
static func tier_of(content, id: String) -> Dictionary:
	if is_flaw(content, id):
		return data(content).flaw
	var tier := str(definition(content, id).get("tier", ""))
	for entry: Dictionary in data(content).tiers:
		if entry.id == tier:
			return entry
	return {}

## Talent ids by tier, born-with talents only, in a stable order; cached on the content.
static func _pools(content) -> Dictionary:
	if content.talent_pools.is_empty():
		for entry: Dictionary in data(content).tiers:
			content.talent_pools[entry.id] = []
		var ids: Array = data(content).talents.keys()
		ids.sort()
		for id: String in ids:
			var talent: Dictionary = data(content).talents[id]
			if not bool(talent.get("gained", false)) and not bool(talent.get("opening_only", false)):
				content.talent_pools[talent.tier].append(id)
		var flaws: Array = data(content).flaws.keys().filter(func(id: String) -> bool: return not bool(data(content).flaws[id].get("gained", false)) and not bool(data(content).flaws[id].get("opening_only", false)))
		flaws.sort()
		content.talent_pools["_flaw"] = flaws
	return content.talent_pools

## Draws someone's talents from a birth table (data/talents.json `tables`): how many, each one's tier by
## weight (tiers the table leaves out are never born from it), no two from one group, and perhaps one
## flaw that clashes with none of them: {"talents": [...], "flaws": [...]}. With `roots` known (the
## player's), a talent or flaw bound to elements is born only with all of those roots (suits).
static func roll(content, rng: RandomNumberGenerator, table_id: String, roots: Array = []) -> Dictionary:
	var pools := _pools(content)
	var table: Dictionary = data(content).tables.get(table_id, data(content).tables.default)
	var count := int(_weighted(rng, table.counts.map(func(entry: Array) -> Array: return [int(entry[0]), float(entry[1])])))
	var tiers: Array = []
	for tier: Dictionary in data(content).tiers:
		if float(table.weights.get(tier.id, 0)) > 0.0:
			tiers.append([tier.id, float(table.weights[tier.id])])
	var chosen: Array = []
	var groups := {}
	for slot: int in count:
		var id := _draw(content, rng, pools[str(_weighted(rng, tiers))], chosen, groups, roots)
		if not id.is_empty():
			chosen.append(id)
	var flaws: Array = []
	if rng.randf() < float(table.flaw_chance):
		var flaw := _draw(content, rng, pools._flaw, chosen, groups, roots)
		if not flaw.is_empty():
			flaws.append(flaw)
	return {"talents": chosen, "flaws": flaws}

## One value from [[value, weight], ...] by weight.
static func _weighted(rng: RandomNumberGenerator, entries: Array) -> Variant:
	var total := 0.0
	for entry: Array in entries:
		total += float(entry[1])
	var pick := rng.randf() * total
	for entry: Array in entries:
		pick -= float(entry[1])
		if pick < 0.0:
			return entry[0]
	return entries.back()[0]

static func _draw(content, rng: RandomNumberGenerator, pool: Array, chosen: Array, groups: Dictionary, roots: Array = []) -> String:
	var open := pool.filter(func(id: String) -> bool:
		return not id in chosen and not groups.has(str(definition(content, id).get("group", "#" + id))) and suits(content, id, roots))
	if open.is_empty():
		return ""
	var id: String = open[rng.randi_range(0, open.size() - 1)]
	groups[str(definition(content, id).get("group", "#" + id))] = true
	return id

## The elements a talent or flaw is bound to: those its modifiers name (damage_<element>, orb_<element>).
static func elements_of(content, id: String) -> Array[String]:
	var bound: Array[String] = []
	for key: String in definition(content, id).get("mods", {}):
		for prefix: String in ["damage_", "orb_"]:
			var element := key.trim_prefix(prefix)
			if key.begins_with(prefix) and element in content.technique_data.elements and not element in bound:
				bound.append(element)
	return bound

## Whether someone with `roots` can be born with `id`: a 水灵根 has no 离火之体. Unknown roots (empty, as
## for generated people) suit anything.
static func suits(content, id: String, roots: Array) -> bool:
	if roots.is_empty():
		return true
	for element: String in elements_of(content, id):
		if not element in roots:
			return false
	return true

## Talents grow with their bearer: a flat bonus (攻击, 神识) counts for more in each realm, so what
## stood out in 炼气 still does in 化神 (data/talents.json `realm_scale`).
static func realm_scale(content, realm: int) -> float:
	var scale: Array = data(content).get("realm_scale", [1])
	return float(scale[clampi(realm, 0, scale.size() - 1)])

## A flat modifier at `realm`.
static func flat(content, value: int, realm: int) -> int:
	return int(round(float(value) * realm_scale(content, realm)))

## Whether `id` may join `owned` (it is not owned and shares no group with what is).
static func fits(content, owned: Array, id: String) -> bool:
	if id in owned:
		return false
	var group := str(definition(content, id).get("group", "#" + id))
	for other: Variant in owned:
		if str(definition(content, str(other)).get("group", "#" + str(other))) == group:
			return false
	return true

## Every modifier summed over these talents and flaws.
static func sum(content, ids: Array) -> Dictionary:
	var total := {}
	for id: Variant in ids:
		var mods: Dictionary = definition(content, str(id)).get("mods", {})
		for key: String in mods:
			total[key] = int(total.get(key, 0)) + int(mods[key])
	return total

## The player's talents and flaws together.
static func owned(s) -> Array:
	return s.player.get("talents", []) + s.player.get("flaws", [])

## One of the player's modifiers, summed.
static func modifier(s, key: String) -> int:
	var total := 0
	for id: Variant in owned(s):
		total += int(definition(s.content, str(id)).get("mods", {}).get(key, 0))
	return total

## `value` scaled by a percentage modifier: value × (100 + percent) / 100, rounded, never below `least`.
static func scaled(value: int, percent: int, least: int = 0) -> int:
	return maxi(least, int(round(float(value) * float(100 + percent) / 100.0)))

## A probability scaled by a percentage modifier.
static func chance(base: float, percent: int) -> float:
	return clampf(base * float(100 + percent) / 100.0, 0.0, 1.0)

# --- 资质 -------------------------------------------------------------------------------

## The spirit roots' share of the aptitude score.
static func root_score(content, roots: Array) -> int:
	return int(data(content).root_scores.get(str(roots.size()), 0))

## A generated person's roots are unknown; their pace of cultivation stands in for them.
static func speed_score(content, speed: int) -> int:
	var score := 0
	for step: Array in data(content).speed_scores:
		if speed >= int(step[0]):
			score = int(step[1])
	return score

static func score(content, base: int, ids: Array) -> int:
	var total := base
	for id: Variant in ids:
		if not bool(definition(content, str(id)).get("opening_only", false)):
			total += int(tier_of(content, str(id)).get("score", 0))
	return total

## The aptitude grade of a score: {"index", "name", "color"}.
static func aptitude(content, value: int) -> Dictionary:
	var grades: Array = data(content).aptitude
	var index := 0
	for i: int in grades.size():
		if value >= int(grades[i].score):
			index = i
	return {"index": index, "name": grades[index].name, "color": grades[index].color}

static func player_aptitude(s) -> Dictionary:
	return aptitude(s.content, score(s.content, root_score(s.content, s.player.get("roots", [])), owned(s)))

# --- Generated people ----------------------------------------------------------------------

## A generated life's talents and flaws, drawn from the world seed and the life on their own stream, so
## adding them shifted nothing else about the life.
## Their region's birth table decides how gifted its people can be.
static func of_life(content, world_seed: int, seat: int, generation: int, region: String) -> Dictionary:
	var rng := RandomNumberGenerator.new()
	rng.seed = hash([world_seed, "talents", seat, generation])
	return roll(content, rng, region)

## Short display of talents for lists: names joined.
static func names(content, ids: Array) -> String:
	var parts: Array[String] = []
	for id: Variant in ids:
		parts.append(str(definition(content, str(id)).get("name", id)))
	return "、".join(parts)
