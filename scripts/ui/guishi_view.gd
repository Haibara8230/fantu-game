extends RefCounted
## 鬼市: the night market at the old pier (guishi.gd) — tonight's sealed lots and what the 神识 makes of
## them, stolen things to fence, the night's contract, grudges to hire out, and the black auction.
const Calendar = preload("res://scripts/core/calendar.gd")

static func render(ui) -> void:
	var session = ui.session
	var center: VBoxContainer = ui.center
	var guishi = session.Guishi
	guishi.visit(session)
	center.add_child(ui.label("鬼市 · 废码头夜灯", 24, ui.GOLD))
	var reason: String = guishi.block(session)
	if not reason.is_empty():
		center.add_child(ui.paragraph(reason, ui.MUTED))
		return
	var lines: Array[String] = ["人人戴着面具，不问来历。灯婆坐在码头尽头的灯下，鬼市里谁动手谁死；出了鬼市，她便不管了。"]
	if guishi.second(session):
		lines.append("你是鬼市的二灯：看货多看两成，销赃价高，也没人敢跟着你。")
	elif bool(guishi.state(session).get("tail", false)):
		lines.append("今夜你出手阔绰，已经有人盯上你了。")
	center.add_child(ui.paragraph(" ".join(lines)))
	_lots(ui, center)
	_fence(ui, center)
	_jobs(ui, center)

## Tonight's sealed lots, each with what the 神识 sees.
static func _lots(ui, center: VBoxContainer) -> void:
	var session = ui.session
	var guishi = session.Guishi
	center.add_child(ui.label("赌宝 · 神识看出 %d 成" % guishi.insight(session), 19, ui.GOLD))
	var tiers: Array = guishi.data(session).tiers
	var bought: Array = guishi.state(session).get("bought", [])
	var grid := GridContainer.new()
	grid.columns = 2
	grid.add_theme_constant_override("h_separation", 12)
	grid.add_theme_constant_override("v_separation", 8)
	center.add_child(grid)
	var index := 0
	for lot: Dictionary in guishi.lots(session):
		var at := index
		var words: String = "已经开过了。" if at in bought else "%s 看出的：%s" % [lot.text, tiers[int(lot.hint)].hint]
		var text: Label = ui.paragraph("%s · %d 灵石　%s" % [lot.name, int(lot.price), words], ui.MUTED if at in bought else ui.INK)
		text.size_flags_horizontal = Control.SIZE_EXPAND_FILL
		grid.add_child(text)
		var block: String = guishi.gamble_block(session, at)
		var buy: Button = ui.button("买下开封", func() -> void: ui.run(func() -> String: return session.guishi_gamble(at)), block)
		buy.disabled = not block.is_empty()
		grid.add_child(buy)
		index += 1

## Stolen things the shops would not take.
static func _fence(ui, center: VBoxContainer) -> void:
	var session = ui.session
	var guishi = session.Guishi
	var goods: Array[String] = guishi.fenceable(session)
	center.add_child(ui.label("销赃", 19, ui.GOLD))
	if goods.is_empty():
		center.add_child(ui.paragraph("行囊里没有明面上卖不出去的东西。", ui.MUTED))
		return
	for item_id: String in goods:
		var picked := item_id
		var sell: Button = ui.button("出手%s ×%d · 每件 %d 灵石" % [session.content.item(item_id).name, session.item_count(item_id), guishi.fence_price(session, item_id)], func() -> void: ui.run(func() -> String: return session.guishi_fence(picked)), str(session.content.item(item_id).get("description", "")))
		center.add_child(sell)

## The night's contract, grudges to hire out, and the black auction.
static func _jobs(ui, center: VBoxContainer) -> void:
	var session = ui.session
	var guishi = session.Guishi
	center.add_child(ui.label("接单 · 雇凶 · 黑拍", 19, ui.GOLD))
	var deal: Dictionary = guishi.contract(session)
	var block: String = guishi.contract_block(session)
	var take: Button = ui.button("接单：截杀%s%s（酬 %d 灵石，凶人榜记名）" % [deal.title, deal.name, int(deal.reward)], func() -> void: ui.run(session.guishi_contract), block if not block.is_empty() else "出了鬼市就动手，生死自负。做成了，天机阁的凶人榜会记下一笔。")
	take.disabled = not block.is_empty()
	center.add_child(take)
	for grudge: Dictionary in session.world.get("grudges", []):
		var grudge_id := str(grudge.id)
		var hire: Button = ui.button("雇人了结%s（%d 灵石）" % [grudge.name, guishi.hire_cost(session)], func() -> void: ui.run(func() -> String: return session.guishi_hire(grudge_id)), "鬼市里有的是拿钱办事的人。")
		hire.disabled = int(session.player.stones) < guishi.hire_cost(session)
		center.add_child(hire)
	var black_block: String = guishi.black_block(session)
	var black: Button = ui.button("入黑拍", func() -> void: ui.run(session.guishi_black), black_block if not black_block.is_empty() else "每季一场，拍的是明面上见不得光的东西。")
	black.disabled = not black_block.is_empty()
	center.add_child(black)
