extends RefCounted
## 宗门: the player's standing in the sect on the 人物 panel — rank, contribution and merit, what the
## next rank asks and gives, the stipend, the exchange and donations. The business itself is done at
## the 执事堂; elsewhere the page only shows it.
const Calendar = preload("res://scripts/core/calendar.gd")

static func render(ui) -> void:
	var session = ui.session
	var center: VBoxContainer = ui.center
	var p: Dictionary = session.player
	var rank: Dictionary = session.sect_rank()
	var at_hall: bool = session.available_here("sect")
	var heading := HBoxContainer.new()
	heading.add_theme_constant_override("separation", 16)
	center.add_child(heading)
	heading.add_child(ui.label("青云剑宗 · " + str(rank.name), 26, ui.GOLD))
	heading.add_child(ui.label("贡献 %d　·　累计 %d" % [int(p.get("contribution", 0)), int(p.get("merit", 0))], 18, ui.INK))
	center.add_child(ui.paragraph("月俸每月自动入账 %d 灵石%s。贡献来自执事堂的委托与巡视、师门差事、捐献、潜龙会与为宗门立下的大功；兑换花去的只是贡献，累计贡献只增不减，用来晋升。" % [int(rank.stipend), "，在宗门闭关修炼 +%d%%" % int(rank.retreat) if int(rank.retreat) > 0 else ""]))
	if not at_hall:
		center.add_child(ui.paragraph("晋升、兑换与捐献，须到青云山执事堂办理。月俸会按月自动入账。", Color("#e3c08a")))
	_promotion(ui, center, at_hall)
	center.add_child(HSeparator.new())
	var due: Dictionary = session.stipend_due()
	var row := HBoxContainer.new()
	row.add_theme_constant_override("separation", 12)
	center.add_child(row)
	row.add_child(ui.label("待结月俸：%d 个月，共 %d 灵石" % [int(due.periods), int(due.stones)], 16))
	var collect: Button = ui.button("领取月俸", func() -> void: ui.run(session.collect_stipend), "回执事堂一并领取")
	collect.disabled = not at_hall or int(due.periods) < 1
	row.add_child(collect)
	_duties(ui, center)
	center.add_child(HSeparator.new())
	center.add_child(ui.label("宗门兑换", 18, ui.GOLD))
	var grid := GridContainer.new()
	grid.columns = 2
	grid.add_theme_constant_override("h_separation", 12)
	grid.add_theme_constant_override("v_separation", 8)
	center.add_child(grid)
	for good: Dictionary in session.sect_goods():
		var item: Dictionary = session.content.item(str(good.item))
		var key: String = good.key
		var reason: String = "须到执事堂兑换。" if not at_hall else str(good.block)
		var take: Button = ui.button("%s · %d 贡献（本期余 %d）" % [item.get("name", good.item), int(good.price), int(good.left)], func() -> void: ui.run(func() -> String: return session.sect_exchange(key)), reason if not reason.is_empty() else str(item.get("description", "")))
		ui.tint(take, ui.grade_color(item))
		take.disabled = not reason.is_empty()
		take.size_flags_horizontal = Control.SIZE_EXPAND_FILL
		grid.add_child(take)
	center.add_child(HSeparator.new())
	_donations(ui, center, at_hall)

## The next rank: what it asks, what it gives, and the request for it.
static func _promotion(ui, center: VBoxContainer, at_hall: bool) -> void:
	var session = ui.session
	var next: Dictionary = session.next_sect_rank()
	if next.is_empty():
		center.add_child(ui.label("已是宗门眼下能给的最高身份。", 16, ui.MUTED))
		return
	var stage: Array = next.stage
	var row := HBoxContainer.new()
	row.add_theme_constant_override("separation", 12)
	center.add_child(row)
	row.add_child(ui.label("晋升%s：累计贡献 %d，修为%s。月俸 %d，闭关 +%d%%" % [next.name, int(next.merit), session.content.realm_title(int(stage[0]), int(stage[1])), int(next.stipend), int(next.retreat)], 16, ui.INK))
	var reason: String = session.promotion_block()
	if reason.is_empty() and not at_hall:
		reason = "须到执事堂申请。"
	var go: Button = ui.button("申请晋升", func() -> void: ui.run(session.promote), reason if not reason.is_empty() else "条件已齐")
	go.disabled = not reason.is_empty()
	row.add_child(go)

## Herbs and materials in the 行囊 the sect takes, each offered up to what still counts this month.
static func _donations(ui, center: VBoxContainer, at_hall: bool) -> void:
	var session = ui.session
	var rule: Dictionary = session.content.sect_data.donation
	center.add_child(ui.label("捐献 · 本月尚可记贡献 %d" % session.donation_left(), 18, ui.GOLD))
	var grid := GridContainer.new()
	grid.columns = 2
	grid.add_theme_constant_override("h_separation", 12)
	grid.add_theme_constant_override("v_separation", 8)
	center.add_child(grid)
	var any := false
	for item_id: String in session.player.items.keys():
		var item: Dictionary = session.content.item(item_id)
		if item.is_empty() or not str(item.get("category", "")) in rule.categories:
			continue
		any = true
		var each := float(item.price) * float(rule.rate)
		var count := mini(session.item_count(item_id), maxi(1, int(ceil(float(session.donation_left()) / maxf(0.01, each)))))
		var value: int = session.donation_value(item_id, count)
		var donated_id := item_id
		var give: Button = ui.button("捐献%s×%d（贡献 +%d）" % [item.name, count, value], func() -> void: ui.run(func() -> String: return session.donate(donated_id, count)), "灵草按市价的一半折算，每月有上限")
		give.disabled = not at_hall or value <= 0
		give.size_flags_horizontal = Control.SIZE_EXPAND_FILL
		grid.add_child(give)
	if not any:
		center.add_child(ui.paragraph("行囊里没有宗门收的灵草或材料。"))

## The duties of the inner court: the one held, and the others to take (once a year).
static func _duties(ui, center: VBoxContainer) -> void:
	var session = ui.session
	var duties: Dictionary = session.content.sect_data.duties
	var held: Dictionary = session.Sect.duty(session)
	center.add_child(HSeparator.new())
	center.add_child(ui.label("职司 · " + (str(held.name) if not held.is_empty() else "未任"), 18, ui.GOLD))
	var row := HBoxContainer.new()
	row.add_theme_constant_override("separation", 10)
	center.add_child(row)
	for duty_id: String in duties.list:
		var duty: Dictionary = duties.list[duty_id]
		var reason: String = session.Sect.duty_block(session, duty_id)
		var chosen := duty_id
		var take: Button = ui.button(str(duty.name), func() -> void: ui.run(func() -> String: return session.take_duty(chosen)), str(duty.text) + ("\n" + reason if not reason.is_empty() else ""))
		take.disabled = not reason.is_empty()
		if str(session.player.get("duty", "")) == duty_id:
			ui.tint(take, ui.GOLD)
		row.add_child(take)
