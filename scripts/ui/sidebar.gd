extends RefCounted
## The left column: the character and their meters, commissions, acquaintances, appointments and the
## journey. Built into the main interface's `stats` container.
const Calendar = preload("res://scripts/core/calendar.gd")
const PeopleView = preload("res://scripts/ui/people_view.gd")
const SIDEBAR_ACQUAINTANCES := 8

static func render(ui) -> void:
	var session = ui.session
	var p: Dictionary = session.player
	var stats: VBoxContainer = ui.stats
	ui.clear(stats)
	stats.add_child(ui.label(p.name, 25))
	stats.add_child(ui.label(session.realm_name(), 18, ui.GOLD))
	stats.add_child(ui.label(session.content.sects[session.player.get("sect", "wanderer")].name, 16, ui.MUTED))
	ui.meter(stats, "气血", p.hp, p.max_hp, Color("#a96f66"))
	ui.meter(stats, "灵力", p.qi, p.max_qi, Color("#5f999b"))
	stats.add_child(ui.label("年岁 %d  ·  寿元 %d" % [session.age(), session.lifespan()], 15, ui.MUTED))
	stats.add_child(ui.label("灵根 · %s · 修炼 ×%.2f" % [session.root_title(), session.cultivation_speed()], 14, ui.MUTED))
	ui.meter(stats, "修为", p.xp, maxi(1, maxi(int(p.xp), _xp_goal(session))), ui.GOLD)
	_render_progress(ui)
	stats.add_child(ui.label("灵石  %d    灵草  %d    筑基丹  %d" % [p.stones, session.herb_count(), session.item_count("foundation_pill")], 15))
	_render_quests(ui)
	_render_acquaintances(ui)
	_render_upcoming(ui)
	stats.add_child(HSeparator.new())
	stats.add_child(ui.label("山 川 行 旅", 16, ui.GOLD))
	stats.add_child(ui.label("身在 · " + session.content.locations[p.location].name, 15))
	ui.journey_button = null
	if not p.journey.is_empty():
		var destination: String = session.content.locations[p.journey.to].name
		var remaining: int = session.content.path_days(session.path_to(p.journey.to))
		stats.add_child(ui.paragraph("行程未竟 · 前往%s，尚余约 %d 日" % [destination, remaining], ui.INK))
		var journey_button: Button = ui.button("继续赶路", func() -> void: ui.run(session.continue_journey), "沿原定路线继续前进")
		journey_button.disabled = not ui.settled()
		ui.journey_button = journey_button
		stats.add_child(journey_button)
	var open_map: Button = ui.button("展开舆图", func() -> void: ui.set_view("map"), "选择目的地，查看路程与危险")
	open_map.disabled = not ui.settled()
	stats.add_child(open_map)

## The next xp milestone: the next sub-stage, or the breakthrough once at the last stage.
static func _xp_goal(session) -> int:
	var stages: Array = session.content.realm(int(session.player.realm)).stages
	if int(session.player.stage) + 1 < stages.size():
		return int(stages[int(session.player.stage) + 1].xp)
	return int(session.next_breakthrough().get("xp", 0))

## The mind after retreats, insight toward the next bottleneck, and the bottleneck itself when reached.
static func _render_progress(ui) -> void:
	var session = ui.session
	var stats: VBoxContainer = ui.stats
	var efficiency: int = session.retreat_efficiency()
	var mood := "平和" if efficiency >= 100 else ("浮躁" if efficiency >= 75 else "倦怠")
	stats.add_child(ui.label("心境 · %s · 闭关收益 %d%%" % [mood, efficiency], 14, ui.MUTED if efficiency >= 100 else ui.INK))
	if session.xp_limit() >= 0:
		stats.add_child(ui.label("历练  %d / %d" % [int(session.player.insight), session.insight_needed()], 14, ui.MUTED))
	if session.at_bottleneck():
		stats.add_child(ui.paragraph("瓶颈 · 闭关难进，需外出历练或服破障丹", Color("#e39a82")))

## Accepted commissions with their progress and deadline.
static func _render_quests(ui) -> void:
	var session = ui.session
	var stats: VBoxContainer = ui.stats
	if session.player.get("quests", []).is_empty():
		return
	stats.add_child(ui.label("委 托", 15, ui.GOLD))
	for quest: Dictionary in session.player.quests:
		var progress := ""
		if quest.has("enemy"):
			progress = " %d/%d" % [int(quest.progress), int(quest.count)]
		elif quest.has("item"):
			progress = " %d/%d" % [mini(session.item_count(quest.item), int(quest.count)), int(quest.count)]
		var entry: Label = ui.label("%s%s\n限 %s · %s" % [session.commission_text(quest).title, progress, Calendar.short_text(int(quest.deadline)), session.content.commission_data.boards[quest.board].name], 14)
		entry.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
		stats.add_child(entry)

## The most relevant acquaintances (handwritten first, then by favor); everyone is in the 相识 view.
static func _render_acquaintances(ui) -> void:
	var stats: VBoxContainer = ui.stats
	var known := PeopleView.sorted_acquaintances(ui)
	if known.is_empty():
		return
	stats.add_child(ui.label("相 识", 15, ui.GOLD))
	for person_id: String in known.slice(0, SIDEBAR_ACQUAINTANCES):
		stats.add_child(PeopleView.acquaintance_button(ui, person_id))
	if known.size() > SIDEBAR_ACQUAINTANCES:
		stats.add_child(ui.button("全部相识 · %d 人" % known.size(), func() -> void: ui.set_view("people"), "查看所有认识的人与他们的去向"))

## When this life runs out, and the appointments coming up.
static func _render_upcoming(ui) -> void:
	var session = ui.session
	var stats: VBoxContainer = ui.stats
	var soon: Array[Dictionary] = session.upcoming()
	var lifespan_year := Calendar.year(session.lifespan_end_day())
	stats.add_child(ui.label("寿元尽于历元 %d 年" % lifespan_year, 14, ui.MUTED))
	if soon.is_empty():
		return
	stats.add_child(ui.label("近 期 约 定", 15, ui.GOLD))
	for entry: Dictionary in soon:
		var place: String = session.content.locations[entry.location].name
		var state := "进行中" if int(entry.from) <= int(session.world.day) else "始于 " + Calendar.short_text(int(entry.from))
		var line: Label = ui.label("%s · %s\n%s，至 %s" % [entry.title, place, state, Calendar.short_text(int(entry.to))], 14)
		line.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
		stats.add_child(line)
