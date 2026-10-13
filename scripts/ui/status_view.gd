extends RefCounted
## 属性: the character page of the panel — realm and meters, age and lifespan, spirit roots, the mind
## (心境) against the stage's need, the weariness after retreats (心神) and insight toward the next
## bottleneck, aptitude and talents, what is carried and the sect.
const Calendar = preload("res://scripts/core/calendar.gd")
const TalentCards = preload("res://scripts/ui/talent_cards.gd")

static func render(ui) -> void:
	var session = ui.session
	var p: Dictionary = session.player
	var center: VBoxContainer = ui.center
	var heading := HBoxContainer.new()
	heading.add_theme_constant_override("separation", 16)
	center.add_child(heading)
	heading.add_child(ui.label(p.name, 28, ui.GOLD))
	heading.add_child(ui.label(session.realm_name(), 20, ui.INK))
	heading.add_child(ui.label(session.content.sects[p.get("sect", "wanderer")].name, 16, ui.MUTED))
	var columns := HBoxContainer.new()
	columns.add_theme_constant_override("separation", 28)
	center.add_child(columns)
	var left := VBoxContainer.new()
	left.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	left.add_theme_constant_override("separation", 8)
	columns.add_child(left)
	ui.meter(left, "气血", p.hp, p.max_hp, Color("#a96f66"))
	ui.meter(left, "灵力", p.qi, p.max_qi, Color("#5f999b"))
	ui.meter(left, "修为", p.xp, maxi(1, maxi(int(p.xp), xp_goal(session))), ui.GOLD)
	var right := VBoxContainer.new()
	right.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	right.add_theme_constant_override("separation", 8)
	columns.add_child(right)
	right.add_child(ui.label("年岁 %d  ·  寿元 %d" % [session.age(), session.lifespan()], 16))
	right.add_child(ui.label("寿元尽于历元 %d 年" % Calendar.year(session.lifespan_end_day()), 15, ui.MUTED))
	right.add_child(ui.label("灵根 · %s · 修炼 ×%.2f" % [session.root_title(), session.cultivation_speed()], 15))
	_render_progress(ui, right)
	center.add_child(HSeparator.new())
	var talents := HBoxContainer.new()
	talents.add_theme_constant_override("separation", 12)
	center.add_child(talents)
	talents.add_child(TalentCards.aptitude_label(ui, session.aptitude()))
	talents.add_child(ui.label("先天天赋（鼠标停留可看效果）", 15, ui.MUTED))
	center.add_child(TalentCards.row(ui, session.content, session.talents_of()))
	center.add_child(HSeparator.new())
	center.add_child(ui.label("灵石  %d    灵草  %d    筑基丹  %d" % [p.stones, session.herb_count(), session.pill_count("foundation_pill")], 16))

## The next xp milestone: the next sub-stage, or the breakthrough once at the last stage.
static func xp_goal(session) -> int:
	var stages: Array = session.content.realm(int(session.player.realm)).stages
	if int(session.player.stage) + 1 < stages.size():
		return int(stages[int(session.player.stage) + 1].xp)
	return int(session.next_breakthrough().get("xp", 0))

## The mind after retreats, insight toward the next bottleneck, and the bottleneck itself when reached.
static func _render_progress(ui, parent: VBoxContainer) -> void:
	var session = ui.session
	var efficiency: int = session.retreat_efficiency()
	var mood := "平和" if efficiency >= 100 else ("浮躁" if efficiency >= 75 else "倦怠")
	var mind_percent: int = session.mind_percent()
	parent.add_child(ui.label("心境  %d / %d · 闭关收益 %d%% · 单次闭关至多 %s" % [int(session.player.mind), session.mind_needed(), mind_percent, Calendar.duration_text(session.retreat_cap())], 15, ui.MUTED if mind_percent >= 100 else Color("#e3c08a")))
	parent.add_child(ui.label("心神 · %s · 闭关收益 %d%%" % [mood, efficiency], 15, ui.MUTED if efficiency >= 100 else ui.INK))
	if session.xp_limit() >= 0:
		parent.add_child(ui.label("历练  %d / %d" % [int(session.player.insight), session.insight_needed()], 15, ui.MUTED))
	var toxin: int = session.toxin()
	if toxin > 0:
		var rule: Dictionary = session.content.alchemy_data.toxin
		parent.add_child(ui.label("丹毒  %d / %d · 每日消退 %d · 突破把握 -%d" % [toxin, int(rule.limit), int(rule.decay_per_day), toxin / int(rule.breakthrough_step)], 15, ui.MUTED if toxin * 2 < int(rule.limit) else Color("#e3c08a")))
	var grade: Dictionary = session.foundation_grade()
	if not grade.is_empty():
		parent.add_child(ui.label("根基 · %s" % grade.name, 15, ui.INK))
	if session.injured():
		parent.add_child(ui.paragraph("冲关受创 · 尚需将养 %s，其间闭关收益减半" % Calendar.duration_text(int(session.player.injury_until) - int(session.world.day)), Color("#e39a82")))
	if session.at_bottleneck():
		parent.add_child(ui.paragraph("瓶颈 · 闭关难进，需外出历练或服破障丹", Color("#e39a82")))
