extends RefCounted
## The 结丹 screen (forming.gd): the round and its phase, the 道基, the core's nine pearl seats, the qi
## held in the 丹田, the 秘术 and the pearl to pay for, the qi chosen for it, and ending the round.
## Presentation only: choosing qi changes nothing until 确定.
const ArtLibrary = preload("res://scripts/ui/art_library.gd")
const Forming = preload("res://scripts/core/forming.gd")
const ELEMENTS := ["metal", "wood", "water", "fire", "earth"]
const STEADY := Color("#8fd0c4")
const SHAKEN := Color("#c9574e")

## The core drawn as a ring of pearl seats: the pearls condensed in their elements' colours, the empty
## seats dim, and between each pearl and the next a thread, green where it generates, red where it
## overcomes.
class CoreRing extends Control:
	var pearls: Array = []
	var most := 9
	var colors := {}
	var generates := {}
	var icons := {}

	func _draw() -> void:
		var middle := size / 2.0
		var radius := minf(size.x, size.y) * 0.38
		draw_circle(middle, radius * 1.22, Color(0.03, 0.06, 0.06, 0.85))
		draw_arc(middle, radius * 1.22, 0.0, TAU, 72, Color("#a89955"), 2.0, true)
		draw_arc(middle, radius * 0.55, 0.0, TAU, 48, Color("#6f6342"), 1.0, true)
		var seats: Array[Vector2] = []
		for index: int in most:
			var angle := -PI / 2.0 + TAU * float(index) / float(most)
			seats.append(middle + Vector2(cos(angle), sin(angle)) * radius)
		for index: int in range(1, pearls.size()):
			var before := str(pearls[index - 1])
			var after := str(pearls[index])
			var thread := Color(0.8, 0.8, 0.7, 0.35)
			if str(generates.get(before, "")) == after or str(generates.get(after, "")) == before:
				thread = Color(STEADY, 0.9)
			elif before != after:
				thread = Color(SHAKEN, 0.9)
			draw_line(seats[index - 1], seats[index], thread, 3.0, true)
		var side := radius * 0.42
		for index: int in most:
			if index < pearls.size():
				var element := str(pearls[index])
				draw_circle(seats[index], side * 0.62, Color(colors.get(element, Color.WHITE), 0.35))
				var icon: Texture2D = icons.get(element)
				if icon != null:
					draw_texture_rect(icon, Rect2(seats[index] - Vector2.ONE * side * 0.5, Vector2.ONE * side), false)
			else:
				draw_arc(seats[index], side * 0.45, 0.0, TAU, 24, Color(0.75, 0.72, 0.6, 0.35), 1.5, true)
		var glow := float(pearls.size()) / float(maxi(1, most))
		draw_circle(middle, radius * 0.5, Color(0.95, 0.8, 0.4, 0.12 + 0.5 * glow))

static func render(ui) -> void:
	var session = ui.session
	var f: Dictionary = session.forming
	var center: VBoxContainer = ui.center
	var d: Dictionary = Forming.data(session)
	var phase: Dictionary = Forming.phase(session)
	# The round, its phase and the 道基.
	var head := HBoxContainer.new()
	head.add_theme_constant_override("separation", 16)
	center.add_child(head)
	head.add_child(ui.label("结丹 · 第 %d / %d 回合 · %s" % [int(f.round), int(d.rounds), str(phase.name)], 26, ui.GOLD))
	var spacer := Control.new()
	spacer.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	head.add_child(spacer)
	var share := float(f.stability) / float(maxi(1, int(f.most)))
	var steady: Label = ui.label("道基 %d / %d" % [int(f.stability), int(f.most)], 20, STEADY if share >= 0.45 else SHAKEN)
	steady.tooltip_text = "道基由突破把握而来。每回合灵压、散去灵气、相克的灵珠会消磨它；调息与相生的灵珠能补回。耗尽则结丹失败。"
	steady.mouse_filter = Control.MOUSE_FILTER_PASS
	head.add_child(steady)
	var bar := ProgressBar.new()
	bar.custom_minimum_size = Vector2(220, 18)
	bar.max_value = int(f.most)
	bar.value = int(f.stability)
	bar.show_percentage = false
	bar.size_flags_vertical = Control.SIZE_SHRINK_CENTER
	var fill := StyleBoxFlat.new()
	fill.bg_color = STEADY if share >= 0.45 else SHAKEN
	fill.set_corner_radius_all(3)
	bar.add_theme_stylebox_override("fill", fill)
	bar.add_theme_stylebox_override("background", ui.style(Color(0.05, 0.08, 0.08, 0.9), Color("#41615e"), 0))
	head.add_child(bar)
	var strain := int(d.strain[int(f.round) - 1])
	center.add_child(ui.paragraph("%s 本回合末灵压 -%d；丹田最多存 %d 颗灵气，下回合吸 %d 颗。" % [str(phase.text), strain, Forming.cap(session), Forming.round_draw(session) if int(f.round) < int(d.rounds) else 0]))
	var body := HBoxContainer.new()
	body.add_theme_constant_override("separation", 22)
	body.size_flags_vertical = Control.SIZE_EXPAND_FILL
	center.add_child(body)
	body.add_child(_core(ui, session))
	var right := VBoxContainer.new()
	right.add_theme_constant_override("separation", 10)
	right.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	body.add_child(right)
	right.add_child(_dantian(ui, session))
	right.add_child(_payment(ui, session))
	right.add_child(_arts(ui, session))
	right.add_child(_ending(ui, session))
	# The last things that happened in the stage.
	var told: Array[String] = session.journal_lines().slice(-4)
	var record: Label = ui.paragraph("\n".join(told))
	record.add_theme_font_size_override("font_size", 14)
	center.add_child(record)

## The core: its pearl seats, what kind it would be, and the grade the pearls make so far.
static func _core(ui, session) -> VBoxContainer:
	var f: Dictionary = session.forming
	var column := VBoxContainer.new()
	column.add_theme_constant_override("separation", 6)
	var ring := CoreRing.new()
	ring.custom_minimum_size = Vector2(300, 300)
	ring.pearls = f.pearls.duplicate()
	ring.most = int(Forming.data(session).pearl.most)
	ring.generates = session.content.rules.duel.generates
	for element: String in ELEMENTS:
		ring.colors[element] = Color(session.content.element_info(element).color)
		ring.icons[element] = ArtLibrary.ui_icon("orbs/" + element)
	ring.tooltip_text = "灵珠的数目定金丹品级（一颗九品，九颗一品），五行配比定金丹属性：\n" + "\n".join(["pure", "dual", "mixed"].map(func(kind: String) -> String: return "· %s：%s" % [Forming.data(session).kinds[kind].name, Forming.data(session).kinds[kind].text]))
	column.add_child(ring)
	var kind: Dictionary = Forming.kind_of(session, f.pearls)
	var grades: Array = session.content.rules.breakthrough.core.grades
	var shape := "尚无灵珠" if kind.is_empty() else "%s · %s" % [Forming.kind_name(session, kind), str(grades[Forming.grade_now(session)].name)]
	var words: Label = ui.label("灵珠 %d / %d　%s" % [f.pearls.size(), ring.most, shape], 17, ui.GOLD)
	words.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	column.add_child(words)
	if int(f.get("steps", 0)) > 0:
		var steps: Label = ui.label("此番所备另提 %d 品" % int(f.steps), 14, ui.MUTED)
		steps.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
		column.add_child(steps)
	return column

## The qi held in the 丹田: each element's count; clicking one chooses it for the payment, or, with
## nothing chosen, lets it go.
static func _dantian(ui, session) -> PanelContainer:
	var f: Dictionary = session.forming
	var panel := PanelContainer.new()
	panel.add_theme_stylebox_override("panel", ui.style(Color(0.04, 0.09, 0.08, 0.85), Color("#6f6342"), 10))
	var column := VBoxContainer.new()
	panel.add_child(column)
	var over: int = Forming.over_cap(session)
	column.add_child(ui.label("丹田灵气 %d / %d%s" % [f.orbs.size(), Forming.cap(session), "　须散去 %d 颗" % over if over > 0 else ""], 17, SHAKEN if over > 0 else ui.INK))
	var row := HBoxContainer.new()
	row.add_theme_constant_override("separation", 8)
	column.add_child(row)
	var choosing: bool = not ui.forming_selection.is_empty()
	for element: String in ELEMENTS:
		var held: int = f.orbs.count(element) - ui.forming_payment.count(element)
		var name := str(session.content.element_info(element).name)
		var tip := "%s灵气 %d 颗。%s" % [name, held, "点击配入" if choosing else "点击散去一颗（道基 -%d）" % int(Forming.data(session).discard)]
		var pick: Button = ui.button("%d" % held, func() -> void: ui.forming_orb(element), tip)
		pick.icon = ArtLibrary.ui_icon("orbs/" + element)
		pick.add_theme_constant_override("icon_max_width", 30)
		pick.custom_minimum_size = Vector2(76, 48)
		pick.disabled = held <= 0
		ui.tint(pick, Color(session.content.element_info(element).color))
		row.add_child(pick)
	return panel

## The qi chosen for the 秘术 or pearl picked, what it would bring, 确定 and 取消.
static func _payment(ui, session) -> HBoxContainer:
	var row := HBoxContainer.new()
	row.add_theme_constant_override("separation", 8)
	var chosen: String = ui.forming_selection
	if chosen.is_empty():
		row.add_child(ui.label("选一门秘术或「凝珠」，再配灵气；不选时点灵气即散去。", 15, ui.MUTED))
		return row
	var cost: Dictionary = Forming.cost_of(session, chosen)
	var name := "凝珠" if chosen == Forming.PEARL else str(Forming.data(session).arts[chosen].name)
	row.add_child(ui.label("%s · 须%s：" % [name, session.Arsenal.cost_text(session.content, cost)], 16, ui.GOLD))
	for index: int in ui.forming_payment.size():
		var element := str(ui.forming_payment[index])
		var back: Button = ui.button("", func() -> void: ui.forming_unreserve(element), "退回这颗灵气")
		back.icon = ArtLibrary.ui_icon("orbs/" + element)
		back.add_theme_constant_override("icon_max_width", 26)
		back.custom_minimum_size = Vector2(40, 40)
		row.add_child(back)
	var valid: bool = session.Combat.payment_valid(session.forming.orbs, cost, ui.forming_payment)
	var outcome := ""
	if valid:
		var preview: Dictionary = Forming.preview(session, chosen, ui.forming_payment)
		var parts: Array[String] = []
		for key: String in preview.triggers:
			parts.append("【%s】" % session.Combat.QiRelations.LABELS[key])
		if chosen == Forming.PEARL and not str(preview.relation).is_empty():
			parts.append("与上一颗%s" % {"generate": "相生", "same": "同属", "overcome": "相克"}[preview.relation])
		if int(preview.stability) != 0:
			parts.append("道基 %+d" % int(preview.stability))
		outcome = " ".join(parts)
	var result: Label = ui.label(outcome, 15, STEADY)
	result.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	row.add_child(result)
	var confirm: Button = ui.button("确定", ui.forming_confirm, "按此配气运转")
	confirm.disabled = not valid
	row.add_child(confirm)
	row.add_child(ui.button("取消", ui.forming_cancel, "不运转，灵气不动"))
	return row

## 凝珠 and the 秘术: each with its cost and words; those not yet known shown with what teaches them.
static func _arts(ui, session) -> GridContainer:
	var grid := GridContainer.new()
	grid.columns = 3
	grid.add_theme_constant_override("h_separation", 8)
	grid.add_theme_constant_override("v_separation", 8)
	var d: Dictionary = Forming.data(session)
	var entries: Array = [{"id": Forming.PEARL, "art": {"name": "凝珠", "cost": d.pearl.cost, "text": "三颗同属灵气凝成一颗灵珠。与上一颗相生，道基 +%d；相克，道基 %d。" % [int(d.link.generate), int(d.link.overcome)]}, "known": true}]
	entries.append_array(Forming.all_arts(session))
	for entry: Dictionary in entries:
		var art_id := str(entry.id)
		var art: Dictionary = entry.art
		var reason: String = Forming.block(session, art_id)
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
static func _ending(ui, session) -> HBoxContainer:
	var row := HBoxContainer.new()
	row.add_theme_constant_override("separation", 10)
	var over: int = Forming.over_cap(session)
	var last: bool = int(session.forming.round) >= int(Forming.data(session).rounds)
	var finish: Button = ui.button("收功成丹" if last else "回合结束", ui.forming_end, "灵气超过丹田所存，须先散去或用秘术耗去" if over > 0 else ("九回合已尽：以已凝的灵珠成丹" if last else "承受本回合灵压，进入下一回合"))
	finish.disabled = over > 0
	finish.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	row.add_child(finish)
	var auto: Button = ui.button("顺其自然", ui.forming_auto, "按寻常的路数运转完余下的回合（不必逐一操作，结果未必最好）")
	row.add_child(auto)
	return row
