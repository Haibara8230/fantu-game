extends RefCounted
## 任务卷轴: what there is to aim for and to keep — current goals (goals.gd), the storylines under way,
## accepted commissions with their progress and deadline, the 传音 received, and the appointments
## coming up.
const Calendar = preload("res://scripts/core/calendar.gd")
const Goals = preload("res://scripts/ui/goals.gd")
const Chronicle = preload("res://scripts/core/chronicle.gd")

static func render_goals(ui) -> void:
	var center: VBoxContainer = ui.center
	var current: Array[Dictionary] = Goals.current(ui.session)
	if current.is_empty():
		center.add_child(ui.paragraph("眼下没有特别的目标，随心修行便是。"))
		return
	for goal: Dictionary in current:
		center.add_child(ui.label(goal.title, 18, ui.GOLD))
		center.add_child(ui.paragraph(goal.text, ui.INK))

static func render_quests(ui) -> void:
	var session = ui.session
	var center: VBoxContainer = ui.center
	if session.player.get("quests", []).is_empty():
		center.add_child(ui.paragraph("没有接下的委托。执事堂与坊市长街贴有委托告示。"))
		return
	for quest: Dictionary in session.player.quests:
		var progress := ""
		if quest.has("enemy"):
			progress = " %d/%d" % [int(quest.progress), int(quest.count)]
		elif quest.has("item"):
			progress = " %d/%d" % [mini(session.item_count(quest.item), int(quest.count)), int(quest.count)]
		center.add_child(ui.label(session.commission_text(quest).title + progress, 18, ui.GOLD))
		center.add_child(ui.paragraph("限 %s · 交付于%s" % [Calendar.short_text(int(quest.deadline)), session.content.commission_data.boards[quest.board].name], ui.INK))

## 剧情: the storylines under way with the step at hand (or what they wait for), then those finished.
static func render_stories(ui) -> void:
	var session = ui.session
	var center: VBoxContainer = ui.center
	var finished: Array[String] = []
	var any := false
	for story_id: String in session.content.storylines:
		var definition: Dictionary = session.content.storylines[story_id]
		var state: String = session.story_state(story_id)
		if state in ["done", "closed"]:
			finished.append("%s%s" % [definition.title, "（作罢）" if state == "closed" else ""])
			continue
		if state != "active":
			continue
		var step: Dictionary = session.story_step(story_id)
		var giver: String = session.content.people[definition.giver].name
		var line := ""
		if session.story_at(story_id, str(step.id)) and step.has("goal"):
			line = str(step.goal)
			if step.has("place"):
				line += "\n去处 · " + session.content.locations[step.place].name
		elif step.has("wait_days"):
			line = "暂无吩咐。%s若有事，自会传音。" % giver
		else:
			line = "时机未到。"
		any = true
		center.add_child(ui.label("%s · %s" % [definition.title, giver], 18, ui.GOLD))
		center.add_child(ui.paragraph(line, ui.INK))
	if not any:
		center.add_child(ui.paragraph("眼下没有托付在身的事。与重要人物多打交道，或许会有人求到你头上。"))
	if not finished.is_empty():
		center.add_child(ui.label("已了之事", 16, ui.MUTED))
		center.add_child(ui.paragraph("、".join(finished)))

## 传音: the letters received, newest first; those unread when the inbox was opened are marked.
static func render_letters(ui) -> void:
	var session = ui.session
	var center: VBoxContainer = ui.center
	var letters: Array = session.world.get("letters", [])
	if letters.is_empty():
		center.add_child(ui.paragraph("还没有收到传音。与人交情深了会互留传音符，师长与故人有事也会传音过来。"))
		return
	var fresh: int = ui.letters_fresh
	for index: int in range(letters.size() - 1, -1, -1):
		var letter: Dictionary = letters[index]
		var person: Dictionary = session.content.people.get(letter.npc, {})
		var mark := "新 · " if index >= letters.size() - fresh else ""
		center.add_child(ui.label("%s%s · %s" % [mark, person.get("name", letter.npc), Calendar.short_text(int(letter.day))], 16, ui.GOLD))
		center.add_child(ui.paragraph(Chronicle.letter_text(letter, session.content), ui.INK))

## When this life runs out, and the appointments coming up.
static func render_upcoming(ui) -> void:
	var session = ui.session
	var center: VBoxContainer = ui.center
	center.add_child(ui.label("寿元尽于历元 %d 年" % Calendar.year(session.lifespan_end_day()), 16, ui.MUTED))
	var soon: Array[Dictionary] = session.upcoming()
	if soon.is_empty():
		center.add_child(ui.paragraph("近期没有约定。"))
		return
	for entry: Dictionary in soon:
		var place: String = session.content.locations[entry.location].name
		var state := "进行中" if int(entry.from) <= int(session.world.day) else "始于 " + Calendar.short_text(int(entry.from))
		center.add_child(ui.label("%s · %s" % [entry.title, place], 18, ui.GOLD))
		center.add_child(ui.paragraph("%s，至 %s" % [state, Calendar.short_text(int(entry.to))], ui.INK))
