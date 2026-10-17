extends RefCounted
## 任务卷轴: what there is to aim for and to keep — current goals (goals.gd), the storylines under way,
## accepted commissions with their progress and deadline, the 传音 received, the appointments coming up,
## and the messages received lately.
const Calendar = preload("res://scripts/core/calendar.gd")
const Goals = preload("res://scripts/ui/goals.gd")
const Chronicle = preload("res://scripts/core/chronicle.gd")

# Turn-by-turn duel records stay in the 编年史; 消息 keeps what happened.
const QUIET := ["skill_attack", "skill_heal", "skill_guard", "defend", "enemy_attack", "battle_start", "spar_start"]
const MESSAGE_COUNT := 80

## 消息: what has reached the player lately, newest first under its date — notices, 传音, world news,
## outcomes — so nothing that passed during a retreat or a stay is lost once its notice fades.
static func render_messages(ui) -> void:
	var session = ui.session
	var center: VBoxContainer = ui.center
	var entries: Array = session.chronicle.entries.filter(func(entry: Dictionary) -> bool: return not str(entry.id) in QUIET)
	entries = entries.slice(-MESSAGE_COUNT)
	entries.reverse()
	center.add_child(ui.label("近来消息 · 最近 %d 条，更早的在「编年史」" % entries.size(), 15, ui.MUTED))
	var important := true
	center.add_child(ui.label("要事与传音", 18, ui.GOLD))
	for row: Dictionary in preload("res://scripts/ui/experience_text.gd").messages(session, entries):
		if important and not row.important:
			important = false
			center.add_child(ui.label("日常与故人近况", 18, ui.MUTED))
		var date := Calendar.short_text(int(row.day)) + " · " if int(row.day) >= 0 else ""
		center.add_child(ui.paragraph(date + str(row.text), ui.GOLD if row.important else ui.INK))
	center.add_child(ui.button("查看完整编年史", func() -> void: ui.set_view("chronicle")))

static func render_goals(ui) -> void:
	var center: VBoxContainer = ui.center
	var current: Array[Dictionary] = Goals.displayed(ui)
	if current.is_empty():
		center.add_child(ui.paragraph("眼下没有特别的目标，随心修行便是。"))
		return
	for goal: Dictionary in current:
		center.add_child(ui.label(("暂缓 · " if goal.get("state", "ready") == "waiting" else "") + goal.title, 18, ui.GOLD))
		center.add_child(ui.paragraph(goal.text, ui.INK))
		var goal_id := str(goal.id)
		center.add_child(ui.button("取消追踪" if ui.tracked_goal == goal_id else "追踪此目标", func() -> void:
			ui.tracked_goal = "" if ui.tracked_goal == goal_id else goal_id
			ui.render(), "追踪目标置前，其他目标仍然保留"))
		if goal_id.begins_with("fortune:"):
			var clue_id := goal_id.trim_prefix("fortune:")
			center.add_child(ui.button("追寻线索", func() -> void: ui.run(func() -> String: return ui.session.Fortune.pursue(ui.session, clue_id))))

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
		elif quest.has("place"):
			progress = " · 已巡视" if int(quest.progress) > 0 else " · 未去"
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
		var step: Dictionary = Goals.described_step(session, session.story_step(story_id))
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
	_render_invites(ui)
	var letters: Array = session.world.get("letters", [])
	if letters.is_empty():
		center.add_child(ui.paragraph("还没有收到传音。与人交情深了（相熟）会互留传音符，往后对方有事、有约、有喜，都会传音过来。"))
		return
	var fresh: int = ui.letters_fresh
	for index: int in range(letters.size() - 1, -1, -1):
		var letter: Dictionary = letters[index]
		var person: Dictionary = session.person(str(letter.npc))
		var mark := "新 · " if index >= letters.size() - fresh else ""
		center.add_child(ui.label("%s%s · %s" % [mark, person.get("name", letter.npc), Calendar.short_text(int(letter.day))], 16, ui.GOLD))
		center.add_child(ui.paragraph(Chronicle.letter_text(letter, session.content), ui.INK))

## Friends' appointments and requests that wait for an answer: where to find them and by when; silver
## asked for can be lent or refused from here.
static func _render_invites(ui) -> void:
	var session = ui.session
	var center: VBoxContainer = ui.center
	var invites: Array = session.open_invites()
	if invites.is_empty():
		return
	center.add_child(ui.label("待 回 复", 18, ui.GOLD))
	for invite: Dictionary in invites:
		var person: Dictionary = session.person(str(invite.npc))
		var where: String = session.npc_location(str(invite.npc))
		var place: String = session.content.locations[where].name if not where.is_empty() else "行踪不明"
		var until := "，限 %s" % Calendar.short_text(int(invite.deadline)) if invite.has("deadline") else ""
		var line := ""
		match str(invite.kind):
			"spar":
				line = "%s约你切磋（此刻在%s%s）" % [person.name, place, until]
			"help":
				line = "%s求%s×%d（此刻在%s%s）" % [person.name, session.content.item(invite.item).name, int(invite.count), place, until]
			"outing":
				line = "%s约你同去%s采药%s" % [person.name, session.content.locations[invite.place].name, until]
			"loan":
				line = "%s想借 %d 灵石，半年后还一倍半%s" % [person.name, int(invite.amount), until]
		var row := HBoxContainer.new()
		row.add_theme_constant_override("separation", 10)
		center.add_child(row)
		var text: Label = ui.label(line, 16, ui.INK)
		text.size_flags_horizontal = Control.SIZE_EXPAND_FILL
		row.add_child(text)
		if invite.kind == "loan":
			var invite_id: String = invite.id
			var lend: Button = ui.button("借给他", func() -> void: ui.run(func() -> String: return session.answer_loan(invite_id, true)), "若他半年内故去，这笔钱便收不回来")
			lend.disabled = int(session.player.stones) < int(invite.amount)
			row.add_child(lend)
			row.add_child(ui.button("婉拒", func() -> void: ui.run(func() -> String: return session.answer_loan(invite_id, false)), "好感略减"))
	center.add_child(HSeparator.new())

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
