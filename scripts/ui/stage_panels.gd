extends RefCounted
## What the breakthrough stages' screens share (forming_view.gd 结丹, nascent_view.gd 结婴): the qi held
## in the 丹田, the qi chosen for a 秘术, the 秘术 to pick and ending the round. `stage` is the stage's
## rules (forming.gd or nascent.gd), which answer the same questions: state, cap, over_cap,
## discard_cost, MEASURE, entries, cost_of, block, preview_words, end_words.
## Presentation only: choosing qi changes nothing until 确定.
const ArtLibrary = preload("res://scripts/ui/art_library.gd")
const ELEMENTS := ["metal", "wood", "water", "fire", "earth"]
const STEADY := Color("#8fd0c4")
const SHAKEN := Color("#c9574e")

## A measure (道基, 意志) as a bar: green while above `low` of its most, red below.
static func meter(ui, parent: Control, label: String, value: int, most: int, tip: String, low: float = 0.45) -> void:
	var share := float(value) / float(maxi(1, most))
	var words: Label = ui.label("%s %d / %d" % [label, value, most], 20, STEADY if share >= low else SHAKEN)
	words.tooltip_text = tip
	words.mouse_filter = Control.MOUSE_FILTER_PASS
	parent.add_child(words)
	var bar := ProgressBar.new()
	bar.custom_minimum_size = Vector2(220, 18)
	bar.max_value = most
	bar.value = value
	bar.show_percentage = false
	bar.size_flags_vertical = Control.SIZE_SHRINK_CENTER
	var fill := StyleBoxFlat.new()
	fill.bg_color = STEADY if share >= low else SHAKEN
	fill.set_corner_radius_all(3)
	bar.add_theme_stylebox_override("fill", fill)
	bar.add_theme_stylebox_override("background", ui.style(Color(0.05, 0.08, 0.08, 0.9), Color("#41615e"), 0))
	parent.add_child(bar)

## The right-hand column: the 丹田, the payment, the 秘术 and the round's end.
static func column(ui, session, stage) -> VBoxContainer:
	var right := VBoxContainer.new()
	right.add_theme_constant_override("separation", 10)
	right.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	right.add_child(dantian(ui, session, stage))
	right.add_child(payment(ui, session, stage))
	right.add_child(arts(ui, session, stage))
	right.add_child(ending(ui, session, stage))
	return right

## The qi held in the 丹田: each element's count; clicking one chooses it for the payment, or, with
## nothing chosen, lets it go.
static func dantian(ui, session, stage) -> PanelContainer:
	var held_orbs: Array = stage.state(session).orbs
	var panel := PanelContainer.new()
	panel.add_theme_stylebox_override("panel", ui.style(Color(0.04, 0.09, 0.08, 0.85), Color("#6f6342"), 10))
	var rows := VBoxContainer.new()
	panel.add_child(rows)
	var over: int = stage.over_cap(session)
	rows.add_child(ui.label("丹田灵气 %d / %d%s" % [held_orbs.size(), stage.cap(session), "　须散去 %d 颗" % over if over > 0 else ""], 17, SHAKEN if over > 0 else ui.INK))
	var row := HBoxContainer.new()
	row.add_theme_constant_override("separation", 8)
	rows.add_child(row)
	var choosing: bool = not ui.forming_selection.is_empty()
	for element: String in ELEMENTS:
		var held: int = held_orbs.count(element) - ui.forming_payment.count(element)
		var name := str(session.content.element_info(element).name)
		var tip := "%s灵气 %d 颗。%s" % [name, held, "点击配入" if choosing else "点击散去一颗（%s -%d）" % [stage.MEASURE, stage.discard_cost(session)]]
		var pick: Button = ui.button("%d" % held, func() -> void: ui.forming_orb(element), tip)
		pick.icon = ArtLibrary.ui_icon("orbs/" + element)
		pick.add_theme_constant_override("icon_max_width", 30)
		pick.custom_minimum_size = Vector2(76, 48)
		pick.disabled = held <= 0
		ui.tint(pick, Color(session.content.element_info(element).color))
		row.add_child(pick)
	return panel

## The qi chosen for the 秘术 picked, what it would bring, 确定 and 取消.
static func payment(ui, session, stage) -> HBoxContainer:
	var row := HBoxContainer.new()
	row.add_theme_constant_override("separation", 8)
	var chosen: String = ui.forming_selection
	if chosen.is_empty():
		row.add_child(ui.label("选一门秘术，再配灵气；不选时点灵气即散去。", 15, ui.MUTED))
		return row
	var cost: Dictionary = stage.cost_of(session, chosen)
	var name := chosen
	for entry: Dictionary in stage.entries(session):
		if str(entry.id) == chosen:
			name = str(entry.art.name)
	row.add_child(ui.label("%s · 须%s：" % [name, session.Arsenal.cost_text(session.content, cost)], 16, ui.GOLD))
	for index: int in ui.forming_payment.size():
		var element := str(ui.forming_payment[index])
		var back: Button = ui.button("", func() -> void: ui.forming_unreserve(element), "退回这颗灵气")
		back.icon = ArtLibrary.ui_icon("orbs/" + element)
		back.add_theme_constant_override("icon_max_width", 26)
		back.custom_minimum_size = Vector2(40, 40)
		row.add_child(back)
	var valid: bool = session.Combat.payment_valid(stage.state(session).orbs, cost, ui.forming_payment)
	var result: Label = ui.label(stage.preview_words(session, chosen, ui.forming_payment) if valid else "", 15, STEADY)
	result.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	row.add_child(result)
	var confirm: Button = ui.button("确定", ui.forming_confirm, "按此配气运转")
	confirm.disabled = not valid
	row.add_child(confirm)
	row.add_child(ui.button("取消", ui.forming_cancel, "不运转，灵气不动"))
	return row

## The 秘术: each with its cost and words; those not yet known shown with what teaches them.
static func arts(ui, session, stage) -> GridContainer:
	var grid := GridContainer.new()
	grid.columns = 3
	grid.add_theme_constant_override("h_separation", 8)
	grid.add_theme_constant_override("v_separation", 8)
	for entry: Dictionary in stage.entries(session):
		var art_id := str(entry.id)
		var art: Dictionary = entry.art
		var reason: String = stage.block(session, art_id)
		var label := "%s · %s" % [art.name, session.Arsenal.cost_short(session.content, art.cost)]
		var pick: Button = ui.button(label, func() -> void: ui.forming_select(art_id), "%s\n%s" % [str(art.text), reason] if not reason.is_empty() else str(art.text) + "\n点击选用，再点切换配气。")
		pick.size_flags_horizontal = Control.SIZE_EXPAND_FILL
		pick.disabled = not reason.is_empty()
		if art_id == ui.forming_selection:
			ui.tint(pick, Color("#ffe5a4"))
		elif not bool(entry.known):
			ui.tint(pick, ui.MUTED)
		grid.add_child(pick)
	return grid

## Ending the round, and leaving the rest to the plain way of running it.
static func ending(ui, session, stage) -> HBoxContainer:
	var row := HBoxContainer.new()
	row.add_theme_constant_override("separation", 10)
	var over: int = stage.over_cap(session)
	var words: Array = stage.end_words(session)
	var finish: Button = ui.button(str(words[0]), ui.forming_end, "灵气超过丹田所存，须先散去或用秘术耗去" if over > 0 else str(words[1]))
	finish.disabled = over > 0
	finish.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	row.add_child(finish)
	row.add_child(ui.button("顺其自然", ui.forming_auto, "按寻常的路数运转完余下的回合（不必逐一操作，结果未必最好）"))
	return row

## The last things that happened in the stage.
static func record(ui, session) -> Label:
	var told: Array[String] = session.journal_lines().slice(-4)
	var words: Label = ui.paragraph("\n".join(told))
	words.add_theme_font_size_override("font_size", 14)
	return words
