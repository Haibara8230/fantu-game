extends RefCounted
## 流派 (docs/COMBAT_PLAN.md, part one, stage four; expansion item 9): a 心法 of a school's kind
## (data/techniques.json `schools`: its archetype, perhaps its element, from a tier up) lends its holder a
## way of fighting. The player and generated people alike (their loadout's methods).
##   剑修 (sword): each further metal art in a turn strikes harder (剑意, stacking).
##   体修 (body): a heavy blow taken readies a harder answer (反震); being overcome costs less.
##   魂修 (soul): the first art of a turn shakes the foe's mind: a generated foe loses an orb, a beast's
##                next blow is weakened.
##   阵修 (array): a turn spent laying a formation (布阵) brings an orb and a shield every turn after.
## Later tied to a 心法's layers (功法层数), once those are calibrated.

static func data(content) -> Dictionary:
	return content.technique_data.get("schools", {})

## The school a set of methods belongs to (the first that fits), or "".
static func of(content, methods: Array) -> String:
	for school_id: String in data(content):
		var school: Dictionary = data(content)[school_id]
		for method_id: Variant in methods:
			var method: Dictionary = content.technique(str(method_id))
			if method.is_empty() or str(method.get("archetype", "")) != str(school.archetype) or int(method.tier) < int(school.min_tier):
				continue
			if school.has("element") and str(method.element) != str(school.element):
				continue
			return school_id
	return ""

## The school of a technique on its own (for its description), or "".
static func of_method(content, method: Dictionary) -> String:
	return of(content, [str(method.get("id", ""))]) if not method.is_empty() else ""

static func player(s) -> String:
	return of(s.content, s.player.get("methods", []))

## The opponent's school: a generated person's (their 心法), or "".
static func foe(s) -> String:
	return str(s.battle.get("foe", {}).get("school", ""))

static func value(s, school_id: String, key: String) -> float:
	return float(data(s.content).get(school_id, {}).get(key, 0.0))
