extends RefCounted
## Payment-based triggers. These do not read the preceding spell, target element or RNG.
const LABELS := {"generate": "生", "same": "同", "overcome": "克"}

static func valid(definition: Variant, elements: Dictionary) -> bool:
	if not definition is Dictionary:
		return false
	for key: Variant in definition:
		if not LABELS.has(key) or not definition[key] is Dictionary or definition[key].is_empty():
			return false
		for field: Variant in definition[key]:
			var value: Variant = definition[key][field]
			if field == "absorb":
				if not value is Array or value.size() != 2 or not elements.has(value[0]) or not _count(value[1]):
					return false
			elif not field in ["damage", "shield", "heal", "gather"] or not _count(value):
				return false
	return true

static func _count(value: Variant) -> bool:
	return (value is int or value is float) and is_finite(float(value)) and float(value) == floor(float(value)) and float(value) > 0.0 and float(value) <= 10000.0

static func classify(payment: Array, generates: Dictionary) -> Array[String]:
	var result: Array[String] = []
	if payment.size() < 2:
		return result
	var kinds: Array = []
	for element: Variant in payment:
		if not element is String or not generates.has(element):
			return result
		if not element in kinds:
			kinds.append(element)
	if kinds.size() == 1:
		result.append("same")
	elif kinds.size() == 2:
		var a: String = kinds[0]
		var b: String = kinds[1]
		if str(generates[a]) == b or str(generates[b]) == a:
			result.append("generate")
		elif str(generates[generates[a]]) == b or str(generates[generates[b]]) == a:
			result.append("overcome")
	return result

static func triggers(art: Dictionary, payment: Array, generates: Dictionary) -> Array[String]:
	return classify(payment, generates).filter(func(key: String) -> bool: return art.get("on_payment", {}).has(key))

static func effect(art: Dictionary, payment: Array, generates: Dictionary) -> Dictionary:
	var result := {}
	for key: String in triggers(art, payment, generates):
		for field: String in art.on_payment[key]:
			var value: Variant = art.on_payment[key][field]
			if field == "absorb":
				result.absorb = value.duplicate()
			else:
				result[field] = int(result.get(field, 0)) + int(value)
	return result

static func describe(art: Dictionary, element_names: Dictionary) -> String:
	var parts: Array[String] = []
	for key: String in art.get("on_payment", {}):
		var terms: Array[String] = []
		var value: Dictionary = art.on_payment[key]
		for field: String in ["damage", "shield", "heal", "gather"]:
			if value.has(field):
				terms.append("%s +%d" % [{"damage": "伤害", "shield": "护罩", "heal": "恢复", "gather": "下回合吸气"}[field], int(value[field])])
		if value.has("absorb"):
			terms.append("额外吸收 %d 颗%s灵气" % [int(value.absorb[1]), element_names[value.absorb[0]].name])
		parts.append("【%s】%s。" % [LABELS[key], "，".join(terms)])
	return "".join(parts)
