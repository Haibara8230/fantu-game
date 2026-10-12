extends RefCounted
## The retreat scroll, opened where one can retreat (the chamber): 修炼 picks how long to stay in
## seclusion and previews what it brings; 突破 shows what breaking through needs. The deadlines coming
## up are listed beside both, so a long retreat does not miss them. The rules are the session's; this
## only shows them and plays a retreat back.
const Calendar = preload("res://scripts/core/calendar.gd")
const Cultivation = preload("res://scripts/core/cultivation.gd")
const Goals = preload("res://scripts/ui/goals.gd")
const MAX_MONTHS := 60
# Goals that are dates to keep in mind while in seclusion.
const DEADLINE_GOALS := ["serpent", "auction", "tournament", "sealed"]

static func render_retreat(ui) -> void:
	var session = ui.session
	var columns := _columns(ui)
	var right: VBoxContainer = columns.get_child(1)
	if not ui.retreat_playback.is_empty():
		_playback(ui, right)
		return
	var efficiency: int = session.retreat_efficiency()
	right.add_child(ui.label("每月修为  %d" % int(round(session.cultivation_rate() * efficiency / 100.0)), 26, ui.GOLD))
	var grade: Dictionary = session.content.root_grade(session.player.get("roots", []))
	var sources := GridContainer.new()
	sources.columns = 2
	sources.add_theme_constant_override("h_separation", 24)
	right.add_child(sources)
	sources.add_child(ui.label("灵根 · %s  ×%.2f" % [session.root_title(), float(grade.speed)], 15))
	sources.add_child(ui.label("心法与法宝  +%d%%" % int(round(float(session.bonuses().cultivation) * 100.0)), 15))
	sources.add_child(ui.label("心境 · %s  收益 %d%%" % [_mood(efficiency), efficiency], 15, ui.INK if efficiency >= 100 else Color("#e3c08a")))
	sources.add_child(ui.label("修为  %d" % int(session.player.xp), 15))
	if session.at_bottleneck():
		right.add_child(ui.paragraph("修为卡在瓶颈，闭关难有寸进。需外出历练（斗法、切磋、委托、奇遇），或服一枚破障丹。", Color("#e39a82")))
		return
	right.add_child(ui.label("选择闭关时间", 16, ui.GOLD))
	var slider := HSlider.new()
	slider.min_value = 1
	slider.max_value = MAX_MONTHS
	slider.step = 1
	slider.value = clampi(ui.retreat_months, 1, MAX_MONTHS)
	slider.custom_minimum_size.x = 320
	right.add_child(slider)
	var length: Label = ui.label("", 18)
	right.add_child(length)
	var preview: Label = ui.paragraph("", ui.INK)
	right.add_child(preview)
	var start: Button = ui.button("开始闭关", func() -> void: ui.start_retreat(ui.retreat_months * Calendar.DAYS_PER_MONTH), "约定或寿元告急时会提前出关")
	start.custom_minimum_size.x = 200
	right.add_child(start)
	var refresh := func(value: float) -> void:
		ui.retreat_months = int(value)
		length.text = months_text(int(value))
		preview.text = preview_text(session, int(value) * Calendar.DAYS_PER_MONTH)
	slider.value_changed.connect(refresh)
	refresh.call(slider.value)

static func render_breakthrough(ui) -> void:
	var session = ui.session
	var columns := _columns(ui)
	var right: VBoxContainer = columns.get_child(1)
	var need: Dictionary = session.next_breakthrough()
	if need.is_empty():
		right.add_child(ui.paragraph("后续境界尚未开放。", ui.INK))
		return
	var realm := int(session.player.realm)
	var last_stage: int = session.content.realm(realm).stages.size() - 1
	right.add_child(ui.label("突破至%s" % session.content.realm(realm + 1).name, 26, ui.GOLD))
	var ready_stage := int(session.player.stage) >= last_stage
	var ready_xp := int(session.player.xp) >= int(need.xp)
	var ready_pill: bool = session.item_count("foundation_pill") >= int(need.pills)
	for line: Array in [[ready_stage, "修至%s" % session.content.realm_title(realm, last_stage)], [ready_xp, "修为  %d / %d" % [int(session.player.xp), int(need.xp)]], [ready_pill, "筑基丹  %d / %d" % [session.item_count("foundation_pill"), int(need.pills)]]]:
		right.add_child(ui.label(("✓  " if line[0] else "·  ") + str(line[1]), 17, ui.INK if line[0] else ui.MUTED))
	right.add_child(ui.paragraph("服下筑基丹，闭关 %s，引灵气入丹田化液。突破后气血、灵力上限与寿元都会提升。" % ui.duration("breakthrough")))
	var go: Button = ui.button("开始突破", ui.start_breakthrough, "" if ready_stage and ready_xp and ready_pill else "条件未齐")
	go.custom_minimum_size.x = 200
	go.disabled = not (ready_stage and ready_xp and ready_pill) or not ui.settled()
	right.add_child(go)

## "N 年 M 个月" for a length in months.
static func months_text(months: int) -> String:
	var years := months / 12
	var rest := months % 12
	if years == 0:
		return "%d 个月" % rest
	return "%d 年" % years if rest == 0 else "%d 年 %d 个月" % [years, rest]

## What a retreat of `days` would bring, as the rules plan it.
static func preview_text(session, days: int) -> String:
	var plan: Dictionary = session.retreat_preview(days)
	var lines: Array[String] = ["修为约 +%d" % int(plan.xp)]
	if int(plan.days) < days:
		lines.append("约第 %d 日修为触及瓶颈而出关" % int(plan.days))
	var after := Cultivation.efficiency(session, int(plan.fatigue))
	lines.append("出关时心境%s，闭关收益 %d%%" % [_mood(after), after])
	return "\n".join(lines)

static func _mood(efficiency: int) -> String:
	return "平和" if efficiency >= 100 else ("浮躁" if efficiency >= 75 else "倦怠")

## The scroll's two columns: the deadlines coming up on the left, the tab's own content on the right.
static func _columns(ui) -> HBoxContainer:
	var session = ui.session
	var columns := HBoxContainer.new()
	columns.add_theme_constant_override("separation", 28)
	ui.center.add_child(columns)
	var left := VBoxContainer.new()
	left.custom_minimum_size.x = 300
	left.add_theme_constant_override("separation", 6)
	columns.add_child(left)
	var right := VBoxContainer.new()
	right.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	right.add_theme_constant_override("separation", 10)
	columns.add_child(right)
	left.add_child(ui.label("近 期 大 事", 18, ui.GOLD))
	var any := false
	for goal: Dictionary in Goals.current(session):
		if goal.id in DEADLINE_GOALS:
			left.add_child(ui.label("%s · 还有 %s" % [goal.title, Goals.values(session, goal.id).until], 15))
			any = true
	for entry: Dictionary in session.upcoming():
		var state := "进行中" if int(entry.from) <= int(session.world.day) else "始于 " + Calendar.short_text(int(entry.from))
		left.add_child(ui.label("%s · %s" % [entry.title, state], 15))
		any = true
	if not any:
		left.add_child(ui.label("近期无事", 15, ui.MUTED))
	left.add_child(ui.label("寿元尽于历元 %d 年" % Calendar.year(session.lifespan_end_day()), 14, ui.MUTED))
	return columns

## A retreat being played back: the days and the xp going by.
static func _playback(ui, parent: VBoxContainer) -> void:
	parent.add_child(ui.label("闭 关 中", 30, ui.GOLD))
	var date: Label = ui.label(Calendar.date_text(int(ui.retreat_playback.from_day)), 20)
	var xp: Label = ui.label("修为  %d" % int(ui.retreat_playback.from_xp), 20, ui.INK)
	parent.add_child(date)
	parent.add_child(xp)
	ui.retreat_labels = {"date": date, "xp": xp}
