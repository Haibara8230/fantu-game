extends RefCounted
## The 结婴 screen (nascent.gd): the round and its phase, the 意志, the 金丹 cracking (or, once shattered,
## the 元婴 within the 心魔's shadow and the 念 of the round), and beside them the 丹田, the 秘术 to pay
## for and ending the round (stage_panels.gd). Presentation only.
const Nascent = preload("res://scripts/core/nascent.gd")
const StagePanels = preload("res://scripts/ui/stage_panels.gd")
const GOLDEN := Color("#e8c35a")
const DEMON := Color("#7a3f8f")

## The 金丹 under the 秘术's blows, cracks spreading as its 丹坚 wears; shattered, a small 元婴 sits in the
## shards, the 心魔's shadow around it as thick as its 魔势.
class Core extends Control:
	var cracked := 0.0
	var shattered := false
	var shadow := 0.0
	var color := GOLDEN

	func _draw() -> void:
		var middle := size / 2.0
		var radius := minf(size.x, size.y) * 0.3
		draw_circle(middle, radius * 1.45, Color(0.03, 0.06, 0.06, 0.85))
		draw_arc(middle, radius * 1.45, 0.0, TAU, 72, Color("#a89955"), 2.0, true)
		if not shattered:
			draw_circle(middle, radius, Color(color, 0.85))
			draw_circle(middle - Vector2(radius, radius) * 0.3, radius * 0.25, Color(1, 1, 0.9, 0.35))
			# Cracks from the centre outward, more and longer as the 丹坚 goes.
			var lines := int(round(cracked * 9.0))
			for index: int in lines:
				var angle := TAU * float(index) / 9.0 + 0.4
				var reach := radius * (0.35 + 0.65 * cracked)
				var bend := Vector2(cos(angle + 0.35), sin(angle + 0.35)) * reach * 0.5
				draw_polyline(PackedVector2Array([middle, middle + bend, middle + Vector2(cos(angle), sin(angle)) * reach]), Color(0.25, 0.12, 0.05, 0.9), 2.0, true)
			return
		# The shadow of 心魔, then the shards, then the 元婴.
		for ring: int in 4:
			draw_circle(middle, radius * (1.4 - 0.12 * ring), Color(DEMON, 0.12 * shadow))
		for index: int in 7:
			var angle := TAU * float(index) / 7.0
			var at := middle + Vector2(cos(angle), sin(angle)) * radius * 1.1
			draw_colored_polygon(PackedVector2Array([at + Vector2(-6, 4), at + Vector2(0, -8), at + Vector2(6, 5)]), Color(color, 0.7))
		draw_circle(middle, radius * 0.75, Color(1.0, 0.92, 0.7, 0.18))
		var head := middle + Vector2(0, -radius * 0.28)
		draw_circle(head, radius * 0.17, Color("#f3e2c0"))
		draw_arc(head, radius * 0.17, 0.0, TAU, 24, Color("#5a4630"), 2.0, true)
		var body := PackedVector2Array([head + Vector2(-radius * 0.26, radius * 0.6), head + Vector2(0, radius * 0.12), head + Vector2(radius * 0.26, radius * 0.6)])
		draw_colored_polygon(body, Color("#f3e2c0"))
		draw_polyline(PackedVector2Array([body[0], body[1], body[2], body[0]]), Color("#5a4630"), 2.0, true)

static func render(ui) -> void:
	var session = ui.session
	var n: Dictionary = session.nascent
	var center: VBoxContainer = ui.center
	var d: Dictionary = Nascent.data(session)
	var phase: Dictionary = Nascent.phase(session)
	var head := HBoxContainer.new()
	head.add_theme_constant_override("separation", 16)
	center.add_child(head)
	head.add_child(ui.label("结婴 · 第 %d / %d 回合 · %s" % [int(n.round), int(d.rounds), str(phase.name)], 26, ui.GOLD))
	var spacer := Control.new()
	spacer.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	head.add_child(spacer)
	StagePanels.meter(ui, head, "意志", int(n.will), int(n.most), "意志由突破把握而来。金丹未碎时的反冲、散去灵气、未能应对的心魔会消磨它；清心咒能补回。耗尽则结婴失败；成婴时剩下几成定元婴品质。")
	center.add_child(ui.paragraph("%s 经脉可存 %d 颗灵气，每回合吸 %d 颗。" % [str(phase.text), Nascent.cap(session), Nascent.round_draw(session)]))
	var body := HBoxContainer.new()
	body.add_theme_constant_override("separation", 22)
	body.size_flags_vertical = Control.SIZE_EXPAND_FILL
	center.add_child(body)
	body.add_child(_core(ui, session))
	body.add_child(StagePanels.column(ui, session, Nascent))
	center.add_child(StagePanels.record(ui, session))

## The 金丹 and its 丹坚; once shattered, the 心魔's 魔势, the 念 of the round and whether it is
## answered, and the 元婴 the stage would make now.
static func _core(ui, session) -> VBoxContainer:
	var n: Dictionary = session.nascent
	var column := VBoxContainer.new()
	column.add_theme_constant_override("separation", 6)
	column.custom_minimum_size.x = 320
	var picture := Core.new()
	picture.custom_minimum_size = Vector2(300, 260)
	picture.shattered = Nascent.shattered(session)
	picture.cracked = 1.0 - float(n.core) / float(maxi(1, int(n.core_most)))
	picture.shadow = float(n.demon) / float(maxi(1, int(n.demon_most)))
	var kind: Dictionary = session.Forming.core_kind(session)
	if str(kind.get("id", "")) == "pure":
		picture.color = Color(session.content.element_info(str(kind.elements[0])).color).lerp(GOLDEN, 0.5)
	column.add_child(picture)
	if not picture.shattered:
		var core: Label = ui.label("金丹丹坚 %d / %d" % [int(n.core), int(n.core_most)], 18, ui.GOLD)
		core.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
		column.add_child(core)
		var waiting: Label = ui.label("心魔魔势 %d，金丹碎后现身" % int(n.demon), 15, ui.MUTED)
		waiting.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
		column.add_child(waiting)
		return column
	var demon: Label = ui.label("心魔魔势 %d / %d" % [int(n.demon), int(n.demon_most)], 18, Color("#c79be0"))
	demon.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	demon.tooltip_text = "每应对一念，魔势 -%d；降到零即刻成婴。" % int(Nascent.data(session).demon.answer)
	demon.mouse_filter = Control.MOUSE_FILTER_PASS
	column.add_child(demon)
	var thought: Dictionary = Nascent.thought(session)
	var panel := PanelContainer.new()
	panel.add_theme_stylebox_override("panel", ui.style(Color(0.08, 0.04, 0.1, 0.85), DEMON, 10))
	column.add_child(panel)
	var words := VBoxContainer.new()
	panel.add_child(words)
	words.add_child(ui.label(str(thought.get("name", "")), 22, Color("#e3c08a")))
	words.add_child(ui.paragraph(str(thought.get("text", ""))))
	var answered: bool = Nascent.answered(session)
	words.add_child(ui.label("此刻已应对：回合末魔势 -%d" % int(Nascent.data(session).demon.answer) if answered else "尚未应对：回合末意志 -%d" % Nascent.blow(session), 16, StagePanels.STEADY if answered else StagePanels.SHAKEN))
	var need: Dictionary = thought.get("need", {})
	if need.has("most") and n.orbs.size() > int(need.most):
		words.add_child(ui.button("散气至 %d 颗（意志 -%d）" % [int(need.most), (n.orbs.size() - int(need.most)) * Nascent.discard_cost(session)], func() -> void: ui.forming_release(int(need.most)), "把多的灵气散去，先散最多的那种"))
	var grades: Array = session.content.rules.breakthrough.nascent.grades
	var now: Label = ui.label("照此成婴：%s%s" % [str(grades[Nascent.grade_now(session)].name), "（此番所备另提 %d 档）" % int(n.steps) if int(n.get("steps", 0)) > 0 else ""], 15, ui.MUTED)
	now.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	column.add_child(now)
	return column
