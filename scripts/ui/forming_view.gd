extends RefCounted
## The 结丹 screen (forming.gd): the round and its phase, the 道基, the core's nine pearl seats, and
## beside them the 丹田, the pearl and 秘术 to pay for and ending the round (stage_panels.gd).
## Presentation only: choosing qi changes nothing until 确定.
const ArtLibrary = preload("res://scripts/ui/art_library.gd")
const Forming = preload("res://scripts/core/forming.gd")
const StagePanels = preload("res://scripts/ui/stage_panels.gd")
const ELEMENTS := StagePanels.ELEMENTS
const STEADY := StagePanels.STEADY
const SHAKEN := StagePanels.SHAKEN

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
	StagePanels.meter(ui, head, "道基", int(f.stability), int(f.most), "道基由突破把握而来。每回合灵压、散去灵气、相克的灵珠会消磨它；调息与相生的灵珠能补回。耗尽则结丹失败。")
	var strain := int(d.strain[int(f.round) - 1])
	center.add_child(ui.paragraph("%s 本回合末灵压 -%d；丹田最多存 %d 颗灵气，下回合吸 %d 颗。" % [str(phase.text), strain, Forming.cap(session), Forming.round_draw(session) if int(f.round) < int(d.rounds) else 0]))
	var body := HBoxContainer.new()
	body.add_theme_constant_override("separation", 22)
	body.size_flags_vertical = Control.SIZE_EXPAND_FILL
	center.add_child(body)
	body.add_child(_core(ui, session))
	body.add_child(StagePanels.column(ui, session, Forming))
	center.add_child(StagePanels.record(ui, session))

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
