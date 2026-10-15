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
	# An event raised with values (an avenger's name, an outlaw's) shows them in its words.
	var values: Dictionary = session.pending_event.get("values", {})
	var text: Label = ui.paragraph(str(definition.text).format(values), ui.INK)
	center.add_child(text)
	ui.type_out(text, "event|%d" % session.pending_event.hash())
	var choices := VBoxContainer.new()
	choices.add_theme_constant_override("separation", 10)
	center.add_child(choices)
	for choice: Dictionary in definition.choices:
		var choice_id: String = choice.id
		var option: Button = ui.button(str(choice.label).format(values), func() -> void: ui.choose(choice_id), "" if session.choice_available(choice) else "条件不足")
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
	if ui.ceremony.get("failed", false):
		_render_failure(ui)
		return
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
	var core: Dictionary = session.core_grade()
	var grade: Dictionary = core if not core.is_empty() else session.foundation_grade()
	if int(ui.ceremony.get("grade", -1)) >= 0 and not grade.is_empty():
		var top := 7 if not core.is_empty() else 3
		var named: Label = ui.label(("金丹 · %s" if not core.is_empty() else "根基 · %s") % grade.name, 26, Color("#e59d52") if int(ui.ceremony.grade) >= top else ui.INK)
		named.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
		center.add_child(named)
	var gains: Label = ui.label("气血上限 %d → %d　·　灵力上限 %d → %d　·　寿元 %d → %d 年" % [int(before.max_hp), int(session.player.max_hp), int(before.max_qi), int(session.player.max_qi), int(before.lifespan), session.lifespan()], 17)
	gains.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	center.add_child(gains)
	var row := HBoxContainer.new()
	row.alignment = BoxContainer.ALIGNMENT_CENTER
	center.add_child(row)
	var done: Button = ui.button("确定", ui.close_ceremony)
	done.custom_minimum_size.x = 200
	row.add_child(done)

## A breakthrough that failed: what it cost, until 确定.
static func _render_failure(ui) -> void:
	var center: VBoxContainer = ui.center
	center.alignment = BoxContainer.ALIGNMENT_CENTER
	var title: Label = ui.label("冲 关 失 败", 72, Color("#c9877a"))
	title.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	center.add_child(title)
	var text: Label = ui.paragraph(str(ui.ceremony.text), ui.INK)
	text.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	center.add_child(text)
	var row := HBoxContainer.new()
	row.alignment = BoxContainer.ALIGNMENT_CENTER
	center.add_child(row)
	var done: Button = ui.button("确定", ui.close_ceremony)
	done.custom_minimum_size.x = 200
	row.add_child(done)

## An ending's title and its first words, centred, clear of the frame's corners.
static func _ending_head(ui, center: VBoxContainer, title: String, words: String) -> void:
	var heading: Label = ui.label(title, 30, ui.GOLD)
	heading.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	center.add_child(heading)
	var line: Label = ui.paragraph(words, ui.INK)
	line.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	center.add_child(line)

static func render_ending(ui) -> void:
	var session = ui.session
	var center: VBoxContainer = ui.center
	if session.at_brink():
		# Once in a life the end waits: to sit in peace, or to defy fate.
		_ending_head(ui, center, "大 限 将 至", "%s，%s，寿元已尽，享年 %d 岁。气机一点点散去，是就此坐化，还是强提最后一口真元，逆冲死关？" % [session.player.name, session.realm_name(), session.age()])
		var row := HBoxContainer.new()
		row.add_theme_constant_override("separation", 14)
		center.add_child(row)
		var years := int(session.content.rules.longevity.defy_years)
		var defy: Button = ui.button("逆天续命 · 约 %d%% 成算" % int(round(session.defy_chance() * 100.0)), func() -> void: ui.run(session.defy_fate), "成则续命 %d 年，经脉重创须将养许久；败则此生就此终结。一生只此一次。" % years)
		defy.size_flags_horizontal = Control.SIZE_EXPAND_FILL
		row.add_child(defy)
		var rest: Button = ui.button("就此坐化", func() -> void: ui.run(session.accept_end), "平静地走完这一生")
		rest.size_flags_horizontal = Control.SIZE_EXPAND_FILL
		row.add_child(rest)
		return
	if str(session.ended.get("kind", "")) == "ascension":
		_ending_head(ui, center, "白 日 飞 升", "%s，%s，享年 %d 岁，踏天河而去，大道得成。" % [session.player.name, session.realm_name(), session.age()])
	elif str(session.ended.get("kind", "")) == "fallen":
		_ending_head(ui, center, "斗 法 陨 落", "%s，%s，在一场死斗中落败，陨落时 %d 岁。" % [session.player.name, session.realm_name(), session.age()])
		if ui.trial_store.has_save():
			var back: Button = ui.button("读取劫前存档", ui.load_trial, "回到这场死斗开打之时")
			center.add_child(back)
	else:
		_ending_head(ui, center, "此 生 已 尽", "%s，%s，享年 %d 岁。" % [session.player.name, session.realm_name(), session.age()])
	center.add_child(ui.label("生 平", 16, ui.GOLD))
	for entry: Dictionary in session.chronicle.entries:
		if entry.major:
			center.add_child(ui.paragraph("【%s】%s" % [Calendar.short_text(int(entry.day)), session.chronicle.format(entry, session.content)]))
	center.add_child(ui.paragraph("可按 %s 读取手动存档，或开启新旅程。" % Settings.key_name(ui, "load"), ui.GOLD))
