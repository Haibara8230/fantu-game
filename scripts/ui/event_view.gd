extends RefCounted
## A pending event with its choices, a story moment, a realm reached and the end of a life with its
## major milestones. An event's or story's illustration fills the screen behind them (main.gd).
const Calendar = preload("res://scripts/core/calendar.gd")
const Settings = preload("res://scripts/ui/settings.gd")

static func render_event(ui) -> void:
	var session = ui.session
	var center: VBoxContainer = ui.center
	var definition: Dictionary = session.pending_definition()
	var title_row := HBoxContainer.new()
	title_row.add_theme_constant_override("separation", 20)
	center.add_child(title_row)
	title_row.add_child(ui.label(definition.title, 30, ui.GOLD))
	title_row.add_child(ui.label(session.content.locations[session.player.location].name, 16, ui.MUTED))
	var text: Label = ui.paragraph(definition.text, ui.INK)
	center.add_child(text)
	ui.type_out(text, "event|%d" % session.pending_event.hash())
	var choices := VBoxContainer.new()
	choices.add_theme_constant_override("separation", 10)
	center.add_child(choices)
	for choice: Dictionary in definition.choices:
		var choice_id: String = choice.id
		var option: Button = ui.button(choice.label, func() -> void: ui.choose(choice_id), "" if session.choice_available(choice) else "条件不足")
		option.disabled = not session.choice_available(choice)
		choices.add_child(option)

## A moment that needed no choice but deserves a look (the serpent breaking out), until 继续.
static func render_story(ui) -> void:
	var center: VBoxContainer = ui.center
	var story: Dictionary = ui.story
	center.add_child(ui.label(str(story.title), 30, ui.GOLD))
	var text: Label = ui.paragraph(str(story.text), ui.INK)
	center.add_child(text)
	ui.type_out(text, "story|%d" % int(story.get("mark", 0)))
	center.add_child(ui.button("继续", ui.close_story))

## A realm reached: its name large, a few lines of what it feels like, and what it brought, until 确定.
static func render_ceremony(ui) -> void:
	var session = ui.session
	var center: VBoxContainer = ui.center
	var realm: Dictionary = session.content.realm(int(ui.ceremony.realm))
	var before: Dictionary = ui.ceremony.before
	center.alignment = BoxContainer.ALIGNMENT_CENTER
	var title: Label = ui.label(str(realm.name), 96, ui.GOLD)
	title.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	center.add_child(title)
	var text: Label = ui.paragraph(str(realm.get("breakthrough_text", "")), ui.INK)
	text.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	center.add_child(text)
	ui.type_out(text, "ceremony|%d" % int(ui.ceremony.realm))
	var stage: Label = ui.label(session.realm_name(), 22, ui.GOLD)
	stage.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	center.add_child(stage)
	var gains: Label = ui.label("气血上限 %d → %d　·　灵力上限 %d → %d　·　寿元 %d → %d 年" % [int(before.max_hp), int(session.player.max_hp), int(before.max_qi), int(session.player.max_qi), int(before.lifespan), session.lifespan()], 17)
	gains.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	center.add_child(gains)
	var row := HBoxContainer.new()
	row.alignment = BoxContainer.ALIGNMENT_CENTER
	center.add_child(row)
	var done: Button = ui.button("确定", ui.close_ceremony)
	done.custom_minimum_size.x = 200
	row.add_child(done)

static func render_ending(ui) -> void:
	var session = ui.session
	var center: VBoxContainer = ui.center
	center.add_child(ui.label("此 生 已 尽", 30, ui.GOLD))
	center.add_child(ui.paragraph("%s，%s，享年 %d 岁。" % [session.player.name, session.realm_name(), session.age()], ui.INK))
	center.add_child(ui.label("生 平", 16, ui.GOLD))
	for entry: Dictionary in session.chronicle.entries:
		if entry.major:
			center.add_child(ui.paragraph("【%s】%s" % [Calendar.short_text(int(entry.day)), session.chronicle.format(entry, session.content)]))
	center.add_child(ui.paragraph("可按 %s 读取手动存档，或开启新旅程。" % Settings.key_name(ui, "load"), ui.GOLD))
