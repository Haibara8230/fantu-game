extends RefCounted
## 炼丹, 丹毒 and the 灵田, after Mi Chang Sheng and the web novels. Operates on a Session; the rules'
## numbers live in data/alchemy.json.
## A recipe (丹方) names its pill, its fine (上品) pill, its main herbs and its days. Every herb is cold,
## hot or neutral; the main herbs lean one way or are balanced, and the 药引 — one more herb of the
## opposite nature, or a neutral one when they are balanced — brings the furnace to balance. A brew
## without a fitting 药引 still works but yields one pill fewer and never a fine one.
## The odds add the recipe's, the furnace's (the best one carried, else the one at the place), the
## place's own help, practice (each brew of a recipe teaches a little, up to a limit), talents, the fire
## (武火 is riskier but finer) and a 控火符. A failed brew loses the herbs; under 武火 the furnace bursts
## and burns too, unless a 控火符 held the fire. The draws come from the world seed, the day and the
## brews before, so loading a save does not change a brew's outcome.
## 丹毒: pills that carry it add to player.toxin, which fades by the day; a pill is refused while it
## would pass the limit, and toxin at a breakthrough costs a little of the odds.
## 灵田: an inner disciple's 洞府 has plots by the field's grade. A herb planted ripens after its days
## (sooner on a better field) and yields its count (more on a better field); nothing is left to chance.
## player.recipes lists the recipes known; player.practice counts brews per recipe; player.toxin is the
## toxin as of player.toxin_day; player.field is {"grade", "plots": [{"herb", "day"} or {}]}.
const Talents = preload("res://scripts/core/talents.gd")
const Calendar = preload("res://scripts/core/calendar.gd")
const Formulation = preload("res://scripts/core/formulation.gd")

static func data(s) -> Dictionary:
	return s.content.alchemy_data

static func recipe(s, recipe_id: String) -> Dictionary:
	return data(s).recipes.get(recipe_id, {})

static func knows(s, recipe_id: String) -> bool:
	return recipe_id in s.player.get("recipes", [])

## Learns a recipe (a 丹方 read, or one taught by someone); nothing when it is known.
static func learn(s, recipe_id: String) -> void:
	if not knows(s, recipe_id) and data(s).recipes.has(recipe_id):
		s.player.recipes.append(recipe_id)

## Known recipes, in the order of the data.
static func known(s) -> Array[String]:
	var result: Array[String] = []
	for recipe_id: String in data(s).recipes:
		if knows(s, recipe_id):
			result.append(recipe_id)
	return result

static func nature(s, herb_id: String) -> String:
	return str(s.content.item(herb_id).get("nature", "neutral"))

## The way the main herbs lean: "cold", "hot" or "neutral" when they balance.
static func lean(s, recipe_id: String, main_override: Variant = null) -> String:
	var heat := 0
	var main: Dictionary = main_override if main_override is Dictionary else recipe(s, recipe_id).main
	for herb_id: String in main:
		match nature(s, herb_id):
			"cold":
				heat -= int(main[herb_id])
			"hot":
				heat += int(main[herb_id])
	return "cold" if heat < 0 else ("hot" if heat > 0 else "neutral")

## The nature a 药引 needs for this recipe.
static func guide_nature(s, recipe_id: String, main_override: Variant = null) -> String:
	match lean(s, recipe_id, main_override):
		"cold":
			return "hot"
		"hot":
			return "cold"
	return "neutral"

## Herbs held that could go in as 药引 (beyond what the main herbs take), fitting ones first.
static func guide_options(s, recipe_id: String, main_override: Variant = null) -> Array[String]:
	var main: Dictionary = main_override if main_override is Dictionary else recipe(s, recipe_id).main
	var fitting: Array[String] = []
	var other: Array[String] = []
	for herb_id: String in s.content.herbs_by_value():
		if s.item_count(herb_id) <= int(main.get(herb_id, 0)):
			continue
		if nature(s, herb_id) == guide_nature(s, recipe_id, main):
			fitting.append(herb_id)
		else:
			other.append(herb_id)
	return fitting + other

## The plan a brew starts from: the recipe, the cheapest fitting 药引 held, a gentle fire and no talisman.
static func default_plan(s, recipe_id: String) -> Dictionary:
	var options := guide_options(s, recipe_id)
	var guide := ""
	if not options.is_empty() and nature(s, options[0]) == guide_nature(s, recipe_id):
		guide = options[0]
	return {"recipe": recipe_id, "guide": guide, "fire": "gentle", "aid": ""}

## The place's furnace and help here ({"name", "success", "fee", ...}), or {} where nobody brews.
## 长青's 丹坊 lends its furnace free to its 客卿 (guest.gd).
static func place(s) -> Dictionary:
	if not s.available_here("alchemy"):
		return {}
	var here: Dictionary = data(s).places.get(str(s.player.location), {})
	if s.Guest.perk_here(s, "alchemy_free") and int(here.get("fee", 0)) > 0:
		here = here.duplicate()
		here.fee = 0
	return here

## The furnace a brew uses: the best one carried, else the place's own.
## {"name", "item" ("" for the place's), "success", "fine", "yield"}.
static func furnace(s) -> Dictionary:
	var best := {"name": str(place(s).get("name", "公用丹炉")), "item": "", "success": 0, "fine": 0, "yield": 0}
	for item_id: String in s.player.get("items", {}):
		var stats: Dictionary = s.content.item(item_id).get("furnace", {})
		if stats.is_empty() or int(stats.success) + int(stats.fine) + 10 * int(stats.yield) <= int(best.success) + int(best.fine) + 10 * int(best.yield):
			continue
		best = {"name": str(s.content.item(item_id).name), "item": item_id, "success": int(stats.success), "fine": int(stats.fine), "yield": int(stats.yield)}
	return best

## Talismans held that help a brew (控火符), item ids.
static func aids(s) -> Array[String]:
	var result: Array[String] = []
	for item_id: String in s.content.items:
		if s.content.items[item_id].has("aid") and s.item_count(item_id) > 0:
			result.append(item_id)
	return result

## The herbs a plan takes: {herb_id: count}.
static func cost(s, plan: Dictionary) -> Dictionary:
	var herbs := Formulation.main_for(s.content, plan)
	var guide := str(plan.get("guide", ""))
	if not guide.is_empty():
		herbs[guide] = int(herbs.get(guide, 0)) + 1
	return herbs

static func balanced(s, plan: Dictionary) -> bool:
	var guide := str(plan.get("guide", ""))
	return not guide.is_empty() and nature(s, guide) == guide_nature(s, str(plan.recipe), Formulation.main_for(s.content, plan))

## Why the plan cannot be brewed now, or "".
static func block(s, plan: Dictionary) -> String:
	var reason: String = s.blocked()
	if not reason.is_empty():
		return reason
	var here := place(s)
	if here.is_empty():
		return "此地无处开炉。"
	if here.has("needs_met") and not bool(s.world.people.get(str(here.needs_met), {}).get("met", false)):
		return "与%s素不相识，借不到药炉。" % s.content.people[str(here.needs_met)].name
	var recipe_id := str(plan.get("recipe", ""))
	if not knows(s, recipe_id):
		return "你还不会这张丹方。"
	var formula_problem := Formulation.problem(s.content, plan)
	if not formula_problem.is_empty():
		return formula_problem
	var guide := str(plan.get("guide", ""))
	if not guide.is_empty() and s.content.item(guide).get("category", "") != "herb":
		return "药引须是灵草。"
	var herbs := cost(s, plan)
	for herb_id: String in herbs:
		if s.item_count(herb_id) < int(herbs[herb_id]):
			return "药材不足：%s需要 %d 株。" % [s.content.item(herb_id).name, int(herbs[herb_id])]
	if not data(s).fires.has(str(plan.get("fire", ""))):
		return "火候不明。"
	var aid := str(plan.get("aid", ""))
	if not aid.is_empty() and (not s.content.item(aid).has("aid") or s.item_count(aid) < 1):
		return "行囊里没有此符。"
	if int(s.player.stones) < int(here.get("fee", 0)):
		return "灵石不足：借炉需要 %d 灵石。" % int(here.fee)
	return ""

## A plan's chances: {"success", "fine", "yield": [least, most], "balanced", "days", "fee", "furnace",
## "parts": [[label, points]] of the success}.
static func odds(s, plan: Dictionary) -> Dictionary:
	var rules := data(s)
	var recipe_id := str(plan.recipe)
	var r := recipe(s, recipe_id)
	var used := furnace(s)
	var fire: Dictionary = rules.fires.get(str(plan.get("fire", "gentle")), rules.fires.gentle)
	var aid: Dictionary = s.content.item(str(plan.get("aid", ""))).get("aid", {})
	var brews := int(s.player.get("practice", {}).get(recipe_id, 0))
	var practice: Dictionary = rules.practice
	var talent: int = s.talent_modifier("alchemy")
	var parts: Array = [["丹方", int(r.success)]]
	for part: Array in [[str(used.name), int(used.success)], [str(place(s).get("help", "")), int(place(s).get("success", 0))], ["熟能生巧", mini(int(practice.success_most), brews * int(practice.success_step))], ["天赋", talent], [str(s.Sect.duty(s).get("name", "")), s.Sect.duty_value(s, "alchemy")], [str(fire.name), int(fire.success)], [str(s.content.item(str(plan.get("aid", ""))).get("name", "")), int(aid.get("success", 0))]]:
		if int(part[1]) != 0 and not str(part[0]).is_empty():
			parts.append(part)
	var success := 0
	for part: Array in parts:
		success += int(part[1])
	var range_of: Array = rules.success_range
	var is_balanced := balanced(s, plan)
	var fine := int(rules.fine_base) + int(used.fine) + mini(int(practice.fine_most), brews * int(practice.fine_step)) + talent / 2 + int(fire.fine)
	var least := int(r.yield[0]) + int(used.yield) - (0 if is_balanced else 1)
	var most := int(r.yield[1]) + int(used.yield) - (0 if is_balanced else 1)
	var yield_scale: float = 1.0 + s.Dao.value(s, "brew_scale")
	return {
		"success": clampi(success, int(range_of[0]), int(range_of[1])), "fine": clampi(fine, 0, int(rules.fine_most)) if is_balanced else 0,
		"yield": [int(round(maxi(1, least) * yield_scale)), int(round(maxi(1, most) * yield_scale))], "balanced": is_balanced, "days": int(r.days), "fee": int(place(s).get("fee", 0)),
		"furnace": used, "parts": parts, "burst": bool(fire.get("burst", false)) and not bool(aid.get("safe", false)),
	}

## Brews a plan: pays the herbs, the fee and the talisman, spends the days, then tells what came out.
static func brew(s, plan: Dictionary) -> String:
	var reason := block(s, plan)
	if not reason.is_empty():
		return reason
	var recipe_id := str(plan.recipe)
	var r := recipe(s, recipe_id)
	var chances := odds(s, plan)
	var herbs := cost(s, plan)
	var rng := RandomNumberGenerator.new()
	rng.seed = hash([int(s.world.get("seed", 0)), "alchemy", int(s.world.day), recipe_id, _brews_total(s)])
	var success_roll := _roll(s, rng, "alchemy")
	var fine_roll := _roll(s, rng, "alchemy_fine")
	var count := rng.randi_range(int(chances.yield[0]), int(chances.yield[1]))
	for herb_id: String in herbs:
		s.remove_item(herb_id, int(herbs[herb_id]))
	s.player.stones = int(s.player.stones) - int(chances.fee)
	if not str(plan.get("aid", "")).is_empty():
		s.remove_item(str(plan.aid), 1)
	s.player.practice[recipe_id] = int(s.player.practice.get(recipe_id, 0)) + 1
	var passed: Dictionary = s.advance_days(int(chances.days))
	if not s.ended.is_empty():
		return s.conclude("", passed)
	var text := ""
	if success_roll * 100.0 < float(chances.success):
		var fine := fine_roll * 100.0 < float(chances.fine)
		var pill: String = str(r.fine) if fine else str(r.pill)
		s.add_item(pill, count)
		s.Dao.gain(s, "alchemy", int(r.get("tier", 1)) * 288)
		text = s.log_event("alchemy_fine" if fine else "alchemy_done", {"days": passed.elapsed, "loot": "%s:%d" % [pill, count]}, fine and recipe_id == "foundation")
		if not bool(chances.balanced):
			text += " 寒热未调，这一炉少成了一枚，也出不了上品。"
	elif bool(chances.burst):
		var burn := maxi(1, int(s.player.max_hp) * int(data(s).burst_hp_percent) / 100)
		s.player.hp = maxi(1, int(s.player.hp) - burn)
		text = s.log_event("alchemy_burst", {"days": passed.elapsed, "item": str(r.pill), "amount": burn})
	else:
		text = s.log_event("alchemy_fail", {"days": passed.elapsed, "item": str(r.pill)})
	return s.conclude(text, passed)

static func _brews_total(s) -> int:
	var total := 0
	for recipe_id: String in s.player.get("practice", {}):
		total += int(s.player.practice[recipe_id])
	return total

## A draw in [0, 1): fixed by tests through the session's `fortune`, else from the brew's own stream.
static func _roll(s, rng: RandomNumberGenerator, tag: String) -> float:
	var drawn := rng.randf()
	return float(s.fortune[tag]) if s.fortune.has(tag) else drawn

# --- 丹毒 -----------------------------------------------------------------------------------------

## The toxin left today.
static func toxin(s) -> int:
	var rule: Dictionary = data(s).toxin
	var faded := maxi(0, int(s.world.day) - int(s.player.get("toxin_day", 0))) * int(rule.decay_per_day)
	return maxi(0, int(s.player.get("toxin", 0)) - faded)

## The toxin a pill would add, after talents.
static func toxin_of(s, item: Dictionary) -> int:
	if not item.has("toxin"):
		return 0
	return maxi(0, Talents.scaled(int(item.toxin), s.talent_modifier("pill_cooldown"), 1) - int(s.Dao.value(s, "toxin_cut")))

## Why the toxin refuses this pill now, or "".
static func toxin_block(s, item: Dictionary) -> String:
	var rule: Dictionary = data(s).toxin
	var adding := toxin_of(s, item)
	var over := toxin(s) + adding - int(rule.limit)
	if adding <= 0 or over <= 0:
		return ""
	return "丹毒未消，%s后再服。" % Calendar.duration_text(int(ceil(float(over) / float(rule.decay_per_day))))

static func add_toxin(s, item: Dictionary) -> void:
	var adding := toxin_of(s, item)
	if adding <= 0:
		return
	s.player.toxin = mini(int(data(s).toxin.limit), toxin(s) + adding)
	s.player.toxin_day = int(s.world.day)

## Points the toxin takes off a breakthrough's odds.
static func toxin_penalty(s) -> int:
	return toxin(s) / int(data(s).toxin.breakthrough_step)

# --- 灵田 -----------------------------------------------------------------------------------------

## Whether the player holds the rank that comes with a field.
static func field_open(s) -> bool:
	return int(s.player.get("rank", 0)) >= s.Sect.rank_index(s, str(data(s).field.rank))

static func field_grade(s) -> Dictionary:
	var grades: Array = data(s).field.grades
	return grades[clampi(int(s.player.field.get("grade", 0)), 0, grades.size() - 1)]

## The plots of the field, as many as its grade has: {} when empty, else {"herb", "day"}.
static func plots(s) -> Array:
	var held: Array = s.player.field.get("plots", [])
	while held.size() < int(field_grade(s).plots):
		held.append({})
	s.player.field.plots = held
	return held

## Herb ids that can be planted, cheapest first.
static func plantable(s) -> Array[String]:
	var result: Array[String] = []
	for herb_id: String in s.content.herbs_by_value():
		if s.content.item(herb_id).has("grow"):
			result.append(herb_id)
	return result

## The day a plot's herb ripens, on the field as it is now.
static func ripe_day(s, plot: Dictionary) -> int:
	var grow: Dictionary = s.content.item(str(plot.herb)).grow
	return int(plot.day) + int(ceil(float(int(grow.days) * int(field_grade(s).growth)) / 100.0))

static func harvest_count(s, plot: Dictionary) -> int:
	return int(s.content.item(str(plot.herb)).grow.yield) + int(field_grade(s).bonus)

static func _field_block(s) -> String:
	var reason: String = s.blocked()
	if not reason.is_empty():
		return reason
	if not field_open(s):
		return "内门弟子才有洞府灵田。"
	if not s.available_here("field"):
		return "须回洞府照料灵田。"
	return ""

static func plant(s, index: int, herb_id: String) -> String:
	var reason := _field_block(s)
	if not reason.is_empty():
		return reason
	var held := plots(s)
	if index < 0 or index >= held.size():
		return "没有这块灵田。"
	if not held[index].is_empty():
		return "这块灵田已经种着灵草。"
	if not herb_id in plantable(s):
		return "此物种不活。"
	if not s.remove_item(herb_id, 1):
		return "行囊里没有%s。" % s.content.item(herb_id).name
	held[index] = {"herb": herb_id, "day": int(s.world.day)}
	return s.conclude(s.log_event("field_plant", {"item": herb_id, "days": ripe_day(s, held[index]) - int(s.world.day)}))

static func harvest(s, index: int) -> String:
	var reason := _field_block(s)
	if not reason.is_empty():
		return reason
	var held := plots(s)
	if index < 0 or index >= held.size() or held[index].is_empty():
		return "这块灵田空着。"
	var plot: Dictionary = held[index]
	if int(s.world.day) < ripe_day(s, plot):
		return "%s尚未长成，还需%s。" % [s.content.item(str(plot.herb)).name, Calendar.duration_text(ripe_day(s, plot) - int(s.world.day))]
	var count := harvest_count(s, plot)
	s.add_item(str(plot.herb), count)
	held[index] = {}
	s.record_deed("gather")
	return s.conclude(s.log_event("field_harvest", {"loot": "%s:%d" % [plot.herb, count]}))

## The next grade of the field, or {} at the best.
static func next_grade(s) -> Dictionary:
	var grades: Array = data(s).field.grades
	var index := int(s.player.field.get("grade", 0)) + 1
	return grades[index] if index < grades.size() else {}

static func upgrade_block(s) -> String:
	var reason := _field_block(s)
	if not reason.is_empty():
		return reason
	var next := next_grade(s)
	if next.is_empty():
		return "灵田已是最好的了。"
	var stage: Array = next.stage
	if int(s.player.realm) < int(stage[0]) or (int(s.player.realm) == int(stage[0]) and int(s.player.stage) < int(stage[1])):
		return "须修至%s。" % s.content.realm_title(int(stage[0]), int(stage[1]))
	if int(s.player.stones) < int(next.cost.stones):
		return "灵石不足：需要 %d 灵石。" % int(next.cost.stones)
	if int(s.player.get("contribution", 0)) < int(next.cost.contribution):
		return "贡献不足：需要 %d 贡献。" % int(next.cost.contribution)
	return ""

## Improves the field one grade, for stones and contribution; what grows keeps growing.
static func upgrade(s) -> String:
	var reason := upgrade_block(s)
	if not reason.is_empty():
		return reason
	var next := next_grade(s)
	s.player.stones = int(s.player.stones) - int(next.cost.stones)
	s.player.contribution = int(s.player.contribution) - int(next.cost.contribution)
	s.player.field.grade = int(s.player.field.get("grade", 0)) + 1
	plots(s)
	return s.conclude(s.log_event("field_upgrade", {"field": str(next.name)}, true))
