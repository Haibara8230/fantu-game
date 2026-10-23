extends RefCounted
## Presentation of action summaries. Never changes rules, history or player knowledge.
const Goals = preload("res://scripts/ui/goals.gd")

static func important_person(s, id: String) -> bool:
	return s.favor(id) >= 40 or bool(s.world.people.get(id, {}).get("sound", false)) or id == str(s.world.get("companion", "")) or id in s.world.get("sworn", []) or id in s.world.get("disciples", [])

static func next_step(s) -> String:
	for goal: Dictionary in Goals.current(s):
		if str(goal.get("state", "ready")) != "waiting":
			return "接下来可做 · %s：%s" % [goal.title, str(goal.text).split("\n")[0]]
	return "眼下可先休整，或与相识交谈、查看委托。"

static func defeat_advice(s, entry: Dictionary) -> String:
	var facts: Dictionary = entry.args
	if bool(facts.get("old_wound", false)):
		return "开战时旧伤未愈；先休整，并等伤势消退后再挑战。"
	if int(facts.get("opening_percent", 100)) < 70:
		return "开战气血不足七成；先到静室或客栈恢复气血，再准备下一战。"
	if str(facts.get("enemy", "")) == "serpent" and not s.has_flag("serpent_weakened") and bool(s.world.people.get("shen_mo", {}).get("met", false)):
		return "妖蟒鳞甲尚未削弱，可回云溪药铺向沈墨打听准备之法。"
	return "先休整伤势，再检查神通克制与装备；也可暂缓挑战，处理别的托付。"

static func notice(s, message: String) -> String:
	var count := 0
	for entry: Dictionary in s.chronicle.entries:
		if str(entry.id) == "obituary" and not important_person(s, str(entry.args.get("npc", ""))):
			var words: String = s.chronicle.format(entry, s.content)
			if message.contains(words):
				count += message.count(words)
				message = message.replace(words, "")
		elif str(entry.id) == "battle_review" and message.contains(s.chronicle.format(entry, s.content)):
			message += " " + defeat_advice(s, entry)
	if count > 0:
		message += " 另有 %d 位旧识故去，详见「任务·消息」，完整记载仍在编年史。" % count
	return message.strip_edges()

static func messages(s, entries: Array) -> Array[Dictionary]:
	var important: Array[Dictionary] = []
	var ordinary: Array[Dictionary] = []
	var obituaries := 0
	for entry: Dictionary in entries:
		if str(entry.id) == "obituary" and not important_person(s, str(entry.args.get("npc", ""))):
			obituaries += 1
			continue
		var text: String = s.chronicle.format(entry, s.content)
		if str(entry.id) == "battle_review":
			text += "\n" + defeat_advice(s, entry)
		var row := {"day":int(entry.day), "text":text, "important":bool(entry.major) or str(entry.id) in ["letter", "breakthrough", "battle_review", "obituary"]}
		(important if row.important else ordinary).append(row)
	if obituaries > 0:
		ordinary.push_front({"day":-1,"text":"近来有 %d 位普通旧识故去。姓名、日期与享年可在编年史查看。" % obituaries,"important":false})
	important.append_array(ordinary)
	return important
