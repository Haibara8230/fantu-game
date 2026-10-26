extends RefCounted
## The 筑基 screen (founding.gd): the round, the 真元, the 灵液 rising in the 丹田 against the grade lines,
## and beside them the 丹田's qi, the 秘术 to pay for and ending the round (stage_panels.gd).
## Presentation only.
const Founding = preload("res://scripts/core/founding.gd")
const StagePanels = preload("res://scripts/ui/stage_panels.gd")
const LIQUID := Color("#7fc8d8")
const LINE := Color("#a89955")

## The 丹田 as a round vessel filling with 灵液, a line for each grade (下品 at the goal) across it.
class Vessel extends Control:
	var liquid := 0
	var top := 200
	var lines: Array = []
	var names: Array = []

	func _draw() -> void:
		var middle := size / 2.0
		var radius := minf(size.x, size.y) * 0.42
		draw_circle(middle, radius + 6.0, Color(0.03, 0.06, 0.06, 0.85))
		var share := clampf(float(liquid) / float(maxi(1, top)), 0.0, 1.0)
		# The 灵液 fills from the bottom: the arc below its level, closed by the chord across it.
		if share >= 0.999:
			draw_circle(middle, radius, Color(LIQUID, 0.75))
		elif share > 0.02:
			var from := asin(clampf(1.0 - 2.0 * share, -1.0, 1.0))
			var points := PackedVector2Array()
			for step: int in 49:
				var angle := lerpf(from, PI - from, float(step) / 48.0)
				points.append(middle + Vector2(cos(angle), sin(angle)) * radius)
			draw_colored_polygon(points, Color(LIQUID, 0.75))
		draw_arc(middle, radius, 0.0, TAU, 72, Color("#d8cfa8"), 2.0, true)
		var font := ThemeDB.fallback_font
		for index: int in lines.size():
			var y := middle.y + radius - 2.0 * radius * clampf(float(lines[index]) / float(maxi(1, top)), 0.0, 1.0)
			var half := sqrt(maxf(0.0, radius * radius - pow(y - middle.y, 2.0)))
			var reached := liquid >= int(lines[index])
			draw_dashed_line(Vector2(middle.x - half, y), Vector2(middle.x + half, y), Color(LINE if not reached else Color("#ffe5a4"), 0.9), 2.0, 6.0)
			draw_string(font, Vector2(middle.x + half + 6.0, y + 5.0), str(names[index]), HORIZONTAL_ALIGNMENT_LEFT, -1, 14, Color("#ffe5a4") if reached else Color(0.8, 0.78, 0.68, 0.8))

static func render(ui) -> void:
	var session = ui.session
	var f: Dictionary = session.founding
	var center: VBoxContainer = ui.center
	var d: Dictionary = Founding.data(session)
	var head := HBoxContainer.new()
	head.add_theme_constant_override("separation", 16)
	center.add_child(head)
	head.add_child(ui.label("筑基 · 第 %d / %d 回合 · 凝液" % [int(f.round), int(d.rounds)], 26, ui.GOLD))
	var spacer := Control.new()
	spacer.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	head.add_child(spacer)
	StagePanels.meter(ui, head, "真元", int(f.essence), int(f.most), "真元由突破把握而来（筑基丹也算在里面）。每回合灵压、散去灵气、压缩灵液与引气入体会消磨它；调息能补回。耗尽则筑基失败。", 0.4)
	center.add_child(ui.paragraph("把灵气压成灵液，九回合后满 %d 即可筑基，凝得越多根基越好。本回合末灵压 -%d；丹田最多存 %d 颗灵气，每回合吸 %d 颗。" % [int(d.goal), Founding.strain(session), Founding.cap(session), Founding.round_draw(session)]))
	var body := HBoxContainer.new()
	body.add_theme_constant_override("separation", 22)
	body.size_flags_vertical = Control.SIZE_EXPAND_FILL
	center.add_child(body)
	body.add_child(_vessel(ui, session))
	body.add_child(StagePanels.column(ui, session, Founding))
	center.add_child(StagePanels.record(ui, session))

## The 灵液 so far, the grade lines, and the grade it makes now.
static func _vessel(ui, session) -> VBoxContainer:
	var f: Dictionary = session.founding
	var d: Dictionary = Founding.data(session)
	var grades: Array = session.content.rules.breakthrough.grades
	var column := VBoxContainer.new()
	column.add_theme_constant_override("separation", 6)
	var vessel := Vessel.new()
	vessel.custom_minimum_size = Vector2(320, 280)
	vessel.liquid = int(f.liquid)
	vessel.lines = d.grades.duplicate()
	vessel.top = maxi(int(d.grades.back()) + int(d.goal) / 4, int(f.liquid))
	for index: int in d.grades.size():
		vessel.names.append(str(grades[index].name))
	vessel.tooltip_text = "灵液满 %s 分别为 %s；无瑕要靠天材地宝或机缘再提。" % ["、".join(d.grades.map(func(value: Variant) -> String: return str(int(value)))), "、".join(vessel.names)]
	column.add_child(vessel)
	var now: int = Founding.grade_now(session)
	var words: Label = ui.label("灵液 %d / %d　%s" % [int(f.liquid), int(d.goal), ("照此筑基：" + str(grades[now].name)) if now >= 0 else "尚未满 %d" % int(d.goal)], 17, ui.GOLD if now >= 0 else ui.INK)
	words.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	column.add_child(words)
	if int(f.get("steps", 0)) > 0:
		var steps: Label = ui.label("此番所备另提 %d 档" % int(f.steps), 14, ui.MUTED)
		steps.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
		column.add_child(steps)
	return column
