extends RefCounted
## 尘/沙 resource loop. No scene, UI, inventory, or random-state dependencies.
const CAP := 1000000
const OPERATIONS := ["shed", "scatter", "return", "consume", "earth_to_dust"]

static func valid(rule: Variant, realms: int) -> bool:
	if not rule is Dictionary or not rule.get("operation") in OPERATIONS or not rule.get("once_per_turn", false) is bool:
		return false
	var required: Array = {"shed": ["shield"], "scatter": [], "return": [], "consume": ["consume", "damage", "fire_bonus"], "earth_to_dust": ["per_orb"]}[rule.operation]
	for key: String in required:
		var values: Variant = rule.get(key)
		if not values is Array or values.size() != realms:
			return false
		for value: Variant in values:
			if not (value is int or value is float) or not is_finite(float(value)) or float(value) != floor(float(value)) or float(value) <= 0 or float(value) > CAP:
				return false
	return rule.keys().all(func(key: Variant) -> bool: return key in required or key in ["operation", "once_per_turn"])

static func amount(art: Dictionary, key: String, realm: int) -> int:
	var values: Array = art.get("dust_flow", {}).get(key, [])
	return int(values[clampi(realm, 0, values.size() - 1)]) if not values.is_empty() else 0

static func counters(battle: Dictionary, enemy: bool) -> Dictionary:
	return battle.get("foe_resources" if enemy else "resources", {})

static func block(battle: Dictionary, art: Dictionary, realm: int, enemy: bool = false) -> String:
	var rule: Dictionary = art.get("dust_flow", {})
	if rule.is_empty():
		return ""
	var own := counters(battle, enemy)
	var other := counters(battle, not enemy)
	var used: Dictionary = battle.get("foe_flow_used" if enemy else "flow_used", {})
	if bool(rule.get("once_per_turn", false)) and int(used.get(art.id, 0)) == int(battle.turn):
		return "【后继无力】本回合已施展过此神通。"
	match str(rule.operation):
		"scatter":
			if int(own.get("dust", 0)) <= 0:
				return "需要自身有【尘】。"
		"return":
			if int(other.get("sand", 0)) <= 0:
				return "需要对手有【沙】。"
		"consume":
			if int(own.get("dust", 0)) < amount(art, "consume", realm):
				return "需要【尘】至少 %d 层。" % amount(art, "consume", realm)
	return ""

static func apply(battle: Dictionary, art: Dictionary, realm: int, enemy: bool = false) -> Dictionary:
	var rule: Dictionary = art.get("dust_flow", {})
	if rule.is_empty():
		return {}
	var own := counters(battle, enemy).duplicate()
	var other := counters(battle, not enemy).duplicate()
	var shield_key := "foe_shield" if enemy else "shield"
	var hand: Array = battle.get("foe_orbs" if enemy else "orbs", [])
	var removed: Array = []
	var moved := 0
	match str(rule.operation):
		"shed":
			moved = int(battle.get(shield_key, 0)) + amount(art, "shield", realm)
			battle[shield_key] = 0
			own.dust = mini(CAP, int(own.get("dust", 0)) + moved)
		"scatter":
			moved = int(own.get("dust", 0))
			own.dust = 0
			other.sand = mini(CAP, int(other.get("sand", 0)) + moved)
		"return":
			moved = int(other.get("sand", 0))
			other.sand = 0
			own.dust = mini(CAP, int(own.get("dust", 0)) + moved)
		"consume":
			moved = amount(art, "consume", realm)
			own.dust = int(own.get("dust", 0)) - moved
		"earth_to_dust":
			while "earth" in hand:
				hand.erase("earth")
				removed.append("earth")
			moved = removed.size() * amount(art, "per_orb", realm)
			own.dust = mini(CAP, int(own.get("dust", 0)) + moved)
	battle["foe_resources" if enemy else "resources"] = own
	battle["resources" if enemy else "foe_resources"] = other
	var used_key := "foe_flow_used" if enemy else "flow_used"
	var used: Dictionary = battle.get(used_key, {})
	if bool(rule.get("once_per_turn", false)):
		used[art.id] = int(battle.turn)
		battle[used_key] = used
	return {"operation": str(rule.operation), "moved": moved, "discarded": removed, "own": own.duplicate(), "other": other.duplicate()}
