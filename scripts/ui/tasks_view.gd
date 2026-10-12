extends RefCounted
## 任务卷轴: what there is to aim for and to keep — current goals (goals.gd), accepted commissions with
## their progress and deadline, and the appointments coming up.
const Calendar = preload("res://scripts/core/calendar.gd")
const Goals = preload("res://scripts/ui/goals.gd")

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
