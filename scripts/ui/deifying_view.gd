extends RefCounted
## The 化神 screen (deifying.gd): the round, the 道 merged with, 仙性 and 凡性 racing to the goal, the
## 淬体 and 塑魂 gathered, and beside them the 丹田's qi, the 法 to pay for and ending the round
## (stage_panels.gd). Presentation only.
const Deifying = preload("res://scripts/core/deifying.gd")
const StagePanels = preload("res://scripts/ui/stage_panels.gd")
const IMMORTAL := Color("#9fd8e8")
const MORTAL := Color("#c98a5a")

## Two columns rising to the goal line: 仙性 on the left, 凡性 on the right.
class Race extends Control:
	var immortal := 0
	var mortal := 0
	var goal := 100
	var rise := 0

	func _draw() -> void:
		var bottom := size.y - 30.0
		var top := 16.0
		var height := bottom - top
		var width := size.x * 0.22
		var font := ThemeDB.fallback_font
		for side: int in 2:
			var value := immortal if side == 0 else mortal
			var x := size.x * (0.3 if side == 0 else 0.7) - width / 2.0
			var color := IMMORTAL if side == 0 else MORTAL
			draw_rect(Rect2(x, top, width, height), Color(0.03, 0.06, 0.06, 0.85))
			var share := clampf(float(value) / float(maxi(1, goal)), 0.0, 1.0)
			draw_rect(Rect2(x, bottom - height * share, width, height * share), Color(color, 0.85))
			# What the round's end will add to the 凡性, shown faint above it.
			if side == 1 and rise > 0:
				var more := clampf(float(value + rise) / float(maxi(1, goal)), 0.0, 1.0) - share
				draw_rect(Rect2(x, bottom - height * (share + more), width, height * more), Color(color, 0.3))
			draw_rect(Rect2(x, top, width, height), Color("#d8cfa8"), false, 2.0)
			draw_string(font, Vector2(x, bottom + 22.0), "%s %d" % ["仙性" if side == 0 else "凡性", value], HORIZONTAL_ALIGNMENT_CENTER, width, 16, color)
		draw_dashed_line(Vector2(size.x * 0.08, top), Vector2(size.x * 0.92, top), Color("#ffe5a4"), 2.0, 6.0)

static func render(ui) -> void:
	var session = ui.session
	var n: Dictionary = session.deifying
	var center: VBoxContainer = ui.center
	var d: Dictionary = Deifying.data(session)
	var head := HBoxContainer.new()
	head.add_theme_constant_override("separation", 16)
	center.add_child(head)
	head.add_child(ui.label("化神 · 第 %d 回合 · 以%s道合道" % [int(n.round), str(session.content.dao_data.paths[str(n.dao)])], 26, ui.GOLD))
	var spacer := Control.new()
	spacer.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	head.add_child(spacer)
	StagePanels.meter(ui, head, "仙性", int(n.immortal), int(d.goal), "仙性先满 %d 即化神。感应法、天人合一推高它。" % int(d.goal), 0.0)
	center.add_child(ui.paragraph("仙性须在凡性之前满 %d。本回合末凡性 +%d；丹田最多存 %d 颗灵气，每回合吸 %d 颗。" % [int(d.goal), Deifying.strain(session), Deifying.cap(session), Deifying.round_draw(session)]))
	var body := HBoxContainer.new()
	body.add_theme_constant_override("separation", 22)
	body.size_flags_vertical = Control.SIZE_EXPAND_FILL
	center.add_child(body)
	body.add_child(_race(ui, session))
	body.add_child(StagePanels.column(ui, session, Deifying))
	center.add_child(StagePanels.record(ui, session))

## The race, and what 淬体 and 塑魂 will bring.
static func _race(ui, session) -> VBoxContainer:
	var n: Dictionary = session.deifying
	var d: Dictionary = Deifying.data(session)
	var column := VBoxContainer.new()
	column.add_theme_constant_override("separation", 6)
	var race := Race.new()
	race.custom_minimum_size = Vector2(300, 280)
	race.immortal = int(n.immortal)
	race.mortal = int(n.mortal)
	race.goal = int(d.goal)
	race.rise = Deifying.strain(session)
	race.tooltip_text = "左为仙性，右为凡性，先到顶线者定成败；凡性上方的浅色是本回合末要涨的。"
	column.add_child(race)
	var gains: Label = ui.label("淬体 %d（气血 +%d）　塑魂 %d（神识 +%d）" % [int(n.temper), int(n.temper) * int(d.rewards.temper_hp), int(n.soul), int(n.soul) * int(d.rewards.soul_sense)], 16, ui.INK)
	gains.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	column.add_child(gains)
	return column
