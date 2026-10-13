extends RefCounted
## Breaking through to the next realm (筑基), after the web novels: it may fail. Operates on a Session.
## The odds start from the 资质 and add what was prepared: 筑基丹 (each worth less than the one before),
## a 天材地宝 in their place, a mind beyond what the stage asks, a 心法 suited to the roots, someone to
## stand guard (护法), the 灵眼 to break through at, fortune met on the way (机缘: 顿悟, 生死之间), the
## lessons of earlier failures, and talents. They are shown before the attempt (`odds`).
## A mind short of the next realm's need, unguarded, may meet 心魔 first: a choice, slain or evaded.
## Success enters the realm with a 品质 (grade) from how far the roll fell under the odds, raised by
## fortune; 无瑕 only by fortune. Failure costs the pills, some xp and months of injury, never the life,
## and leaves a lesson for the next attempt. A 残魂灌顶 accepted makes the next attempt certain, without
## pills, at a middling grade.
## player.attempt holds an attempt waiting on 心魔; player.foundation_grade the grade reached;
## player.injury_until the day the injury heals; player.lessons the failures learned from; player.boons
## the fortune met in this life ({id: "ready" | "spent"}).
const Talents = preload("res://scripts/core/talents.gd")
const DEMON_EVENT := "heart_demon"

static func rules(s) -> Dictionary:
	return s.content.rules.breakthrough

## Treasures in the 行囊 that can stand in for 筑基丹: item ids, cheapest first.
static func treasures(s) -> Array[String]:
	var found: Array[String] = []
	for item_id: String in s.content.items:
		if s.content.items[item_id].has("breakthrough") and s.item_count(item_id) > 0:
			found.append(item_id)
	found.sort()
	return found

## The plan a plain 突破 uses: one 筑基丹 if there is one, else the first treasure.
static func default_plan(s) -> Dictionary:
	if s.item_count("foundation_pill") > 0:
		return {"pills": 1, "treasure": "", "guard": ""}
	var owned := treasures(s)
	return {"pills": 0, "treasure": owned[0] if not owned.is_empty() else "", "guard": ""}

## Who can stand guard: the mentor once his lineage storyline is done, and anyone trusted (信赖).
static func guards(s) -> Array[String]:
	var found: Array[String] = []
	var guard: Dictionary = rules(s).guard
	if s.story_state(str(guard.mentor_story)) == "done" and s.is_person(str(guard.mentor)):
		found.append(str(guard.mentor))
	for person_id: String in s.known_npcs():
		if person_id in found or s.favor(person_id) < int(guard.favor):
			continue
		if s.is_generated(person_id) and s.npc_location(person_id).is_empty() and not s.life_by_id(person_id).is_empty() and int(s.life_by_id(person_id).death) <= int(s.world.day):
			continue
		found.append(person_id)
	return found

static func _ready_boon(s, id: String) -> bool:
	return str(s.player.get("boons", {}).get(id, "")) == "ready"

## Whether the breakthrough is done at the 灵眼.
static func at_eye(s) -> bool:
	var eye: Dictionary = rules(s).eye
	return str(s.player.location) == str(eye.location) and s.has_flag(str(eye.flag))

## Why the plan cannot be attempted now, or "".
static func block(s, plan: Dictionary) -> String:
	var need: Dictionary = s.next_breakthrough()
	if need.is_empty():
		return "后续境界尚未开放。"
	if not s.available_here("breakthrough"):
		return "此地无法闭关突破，请回青云山静室。"
	var last_stage: int = s.content.realm(int(s.player.realm)).stages.size() - 1
	if int(s.player.stage) < last_stage or int(s.player.xp) < int(need.xp):
		return "突破需修至%s，并有 %d 修为。" % [s.content.realm_title(int(s.player.realm), last_stage), int(need.xp)]
	var pills := int(plan.get("pills", 0))
	var treasure := str(plan.get("treasure", ""))
	if pills < 0 or pills > rules(s).pill_bonus.size() or s.item_count("foundation_pill") < pills:
		return "行囊里没有那么多筑基丹。"
	if not treasure.is_empty() and (not s.content.item(treasure).has("breakthrough") or s.item_count(treasure) < 1):
		return "行囊里没有此物。"
	if pills < int(need.pills) and treasure.is_empty() and not _ready_boon(s, "remnant"):
		return "突破至少需要 %d 枚筑基丹，或一样天材地宝。" % int(need.pills)
	var guard := str(plan.get("guard", ""))
	if not guard.is_empty() and not guard in guards(s):
		return "此人无法为你护法。"
	return ""

## The odds of a plan: {"total", "parts": [[label, points]], "certain", "steps": [labels of grade steps
## promised], "demon": whether 心魔 may come}.
static func odds(s, plan: Dictionary) -> Dictionary:
	var r := rules(s)
	var parts: Array = []
	var grade: Dictionary = s.aptitude()
	parts.append(["资质 · %s" % grade.name, int(r.base[int(grade.index)])])
	var talents: int = s.talent_modifier("breakthrough")
	if talents != 0:
		parts.append(["天赋", talents])
	var pills := int(plan.get("pills", 0))
	var pill_points := 0
	for index: int in mini(pills, r.pill_bonus.size()):
		pill_points += int(r.pill_bonus[index])
	if pills > 0:
		parts.append(["筑基丹 ×%d" % pills, Talents.scaled(pill_points, s.talent_modifier("pill"))])
	var steps: Array = []
	var treasure := str(plan.get("treasure", ""))
	if not treasure.is_empty():
		var item: Dictionary = s.content.item(treasure)
		parts.append([str(item.name), int(item.breakthrough.bonus)])
		if int(item.breakthrough.get("grade", 0)) > 0:
			steps.append(str(item.name))
	var surplus: int = int(s.player.get("mind", 0)) - s.mind_needed()
	if surplus >= int(r.mind_step):
		parts.append(["心境盈余", mini(int(r.mind_most), surplus / int(r.mind_step))])
	var method := _method_points(s)
	if method[1] > 0:
		parts.append([method[0], method[1]])
	var guard := str(plan.get("guard", ""))
	if not guard.is_empty():
		var bonus := int(r.guard.mentor_bonus) if guard == str(r.guard.mentor) else int(r.guard.bonus)
		parts.append(["护法 · %s" % s.person(guard).name, bonus])
	if at_eye(s):
		parts.append(["灵眼", int(r.eye.bonus)])
	for boon: Dictionary in r.boons:
		if _ready_boon(s, str(boon.id)):
			parts.append([str(boon.name), int(boon.bonus)])
			if int(boon.get("grade", 0)) > 0:
				steps.append(str(boon.name))
	var lessons := int(s.player.get("lessons", 0))
	if lessons > 0:
		parts.append(["前车之鉴", lessons * int(r.lesson.bonus)])
	var total := 0
	for part: Array in parts:
		total += int(part[1])
	var certain := _ready_boon(s, "remnant")
	total = 100 if certain else clampi(total, int(r.least), int(r.most))
	return {"total": total, "parts": parts, "certain": certain, "steps": steps, "demon": demon_threatens(s, guard)}

## A 心法 in use suited to the roots, and the best 心法's tier: [label, points].
static func _method_points(s) -> Array:
	var r := rules(s)
	var points := 0
	var best_tier := 0
	var suited := false
	for method_id: Variant in s.player.get("methods", []):
		var method: Dictionary = s.content.technique(str(method_id))
		if method.is_empty():
			continue
		best_tier = maxi(best_tier, int(method.tier))
		suited = suited or str(method.element) in s.player.get("roots", [])
	if suited:
		points += int(r.method_root)
	points += int(r.method_tier.get(str(best_tier), 0))
	return ["心法" + ("（与灵根相合）" if suited else ""), points]

## The mind the next realm's first stage asks for, after talents.
static func demon_mind(s) -> int:
	var next: Dictionary = s.content.stage(int(s.player.realm) + 1, 0)
	return Talents.scaled(int(next.get("mind", 0)), s.talent_modifier("mind_need"))

## How likely 心魔 comes when it threatens: the rules' chance, less what talents keep away.
static func demon_chance(s) -> float:
	return clampf(float(rules(s).demon.chance) * (1.0 - float(s.talent_modifier("demon")) / 100.0), 0.0, 1.0)

## Whether 心魔 may come: the mind falls short of the next realm and nobody stands guard.
static func demon_threatens(s, guard: String) -> bool:
	return guard.is_empty() and int(s.player.get("mind", 0)) < demon_mind(s)

## Starts an attempt: pays for it, then either meets 心魔 (the choice becomes pending) or goes straight
## on to the retreat. Returns the texts.
static func attempt(s, plan: Dictionary) -> String:
	var reason := block(s, plan)
	if not reason.is_empty():
		return reason
	var need: Dictionary = s.next_breakthrough()
	var chances := odds(s, plan)
	s.remove_item("foundation_pill", int(plan.get("pills", 0)))
	if not str(plan.get("treasure", "")).is_empty():
		s.remove_item(str(plan.treasure), 1)
	s.player.xp = int(s.player.xp) - int(need.xp)
	s.player["attempt"] = {"odds": int(chances.total), "certain": bool(chances.certain), "steps": chances.steps.size(), "xp": int(need.xp), "guard": str(plan.get("guard", ""))}
	if bool(chances.demon) and not chances.certain and s.fortune_roll("demon") < demon_chance(s):
		s.pending_event = {"id": DEMON_EVENT, "day": int(s.world.day)}
		return s.finish(s.log_event("heart_demon", {}, true))
	return resolve(s, "")

## The 心魔 choice: "slay" may win a better grade or cost the odds; "evade" costs a little of them.
static func face_demon(s, stance: String) -> String:
	var attempt_state: Dictionary = s.player.get("attempt", {})
	if attempt_state.is_empty():
		return ""
	var demon: Dictionary = rules(s).demon
	var text := ""
	if stance == "slay":
		var chance := clampf(float(s.player.get("mind", 0)) / float(maxi(1, demon_mind(s))), 0.0, 1.0)
		if s.fortune_roll("slay") < chance:
			attempt_state.steps = int(attempt_state.steps) + 1
			s.gain_mind(int(demon.slay_mind))
			text = s.log_event("demon_slain", {"mind": int(demon.slay_mind)}, true)
		else:
			attempt_state.odds = maxi(int(rules(s).least), int(attempt_state.odds) - int(demon.slay_penalty))
			text = s.log_event("demon_lingers", {"points": int(demon.slay_penalty)}, true)
	else:
		attempt_state.odds = maxi(int(rules(s).least), int(attempt_state.odds) - int(demon.evade_penalty))
		text = s.log_event("demon_evaded", {"points": int(demon.evade_penalty)})
	return text

## The retreat of the attempt and its outcome. `told` leads the texts.
static func resolve(s, told: String) -> String:
	var attempt_state: Dictionary = s.player.get("attempt", {})
	s.player.erase("attempt")
	var passed: Dictionary = s.advance_days(s.content.action_days("breakthrough"))
	if not s.ended.is_empty():
		return s.conclude(told, passed)
	var texts: Array[String] = []
	if not told.is_empty():
		texts.append(told)
	var roll: float = s.fortune_roll("breakthrough") * 100.0
	var boons: Dictionary = s.player.get("boons", {})
	for boon: Dictionary in rules(s).boons:
		if str(boons.get(boon.id, "")) == "ready":
			boons[boon.id] = "spent"
	var certain := bool(attempt_state.get("certain", false))
	if certain:
		boons["remnant"] = "spent"
	if certain or roll < float(attempt_state.odds):
		var grade := 1 if certain else _grade(s, float(attempt_state.odds) - roll, int(attempt_state.steps))
		s.player.realm = int(s.player.realm) + 1
		s.player.stage = 0
		s.player["foundation_grade"] = grade
		s.player["lessons"] = 0
		s.player["injury_until"] = 0
		s.refresh_realm_stats()
		s.player.hp = s.player.max_hp
		s.player.qi = s.player.max_qi
		texts.append(s.log_event("breakthrough", {"days": passed.elapsed, "realm": int(s.player.realm), "stage": 0, "grade": grade}, true))
		texts.append_array(s.settle_stage())
		texts.append_array(s.congratulate("breakthrough"))
		return s.conclude(" ".join(texts), passed)
	var failure: Dictionary = rules(s).failure
	s.player.xp = int(attempt_state.xp) * int(failure.xp_percent) / 100
	s.player["injury_until"] = int(s.world.day) + int(failure.injury_days)
	s.player["lessons"] = mini(int(rules(s).lesson.most), int(s.player.get("lessons", 0)) + 1)
	s.gain_mind(int(failure.mind))
	s.player.hp = maxi(1, int(s.player.max_hp) / 3)
	texts.append(s.log_event("breakthrough_failed", {"days": passed.elapsed, "xp": int(s.player.xp), "injury": int(failure.injury_days)}, true))
	return s.conclude(" ".join(texts), passed)

## The grade from the margin under the odds (up to 上品), raised by fortune's steps and by talents, at
## most 无瑕.
static func _grade(s, margin: float, steps: int) -> int:
	var grades: Array = rules(s).grades
	var grade := 0
	for index: int in grades.size():
		if grades[index].has("margin") and margin >= float(grades[index].margin):
			grade = index
	var chance: int = s.talent_modifier("grade")
	steps += chance / 100
	if chance % 100 > 0 and s.fortune_roll("grade") * 100.0 < float(chance % 100):
		steps += 1
	return mini(grades.size() - 1, grade + steps)

## A foundation grade's entry ({"name", "stats", "speed"}), or {} before foundation.
static func grade_of(s, holder: Dictionary = {}) -> Dictionary:
	if holder.is_empty():
		holder = s.player
	if int(holder.get("realm", 0)) < 1:
		return {}
	var grades: Array = rules(s).grades
	return grades[clampi(int(holder.get("foundation_grade", 1)), 0, grades.size() - 1)]

## Whether an earlier failure still hurts on `day`.
static func injured(s, day: int = -1) -> bool:
	return (int(s.world.day) if day < 0 else day) < int(s.player.get("injury_until", 0))
