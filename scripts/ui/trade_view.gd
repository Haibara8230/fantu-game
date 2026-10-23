extends RefCounted
## The trading table, after Mi Chang Sheng: what you carry that this place buys on the left, what you
## lay out to sell and to buy in the middle with the stones it comes to, the shop's goods on the right.
## Nothing changes hands until 确定, which sells and buys through the shop's own actions.

static func render(ui) -> void:
	var session = ui.session
	var center: VBoxContainer = ui.center
	var location: String = session.content.locations[session.player.location].name
	var columns := HBoxContainer.new()
	columns.add_theme_constant_override("separation", 18)
	center.add_child(columns)
	var mine := _column(ui, columns, "行囊 · 灵石 %d" % int(session.player.stones))
	var table := _column(ui, columns, "交易")
	var shop := _column(ui, columns, location + " · 店家")

	var reserved: Dictionary = session.Inventory.reserved(session)
	var sellable := 0
	# Refined 宝物 are offered one by one (gear.gd); 全部摆上 leaves them out.
	for item_id: String in session.player.items.keys() + session.Gear.carried(session):
		var price: int = session.sell_price(item_id)
		var left: int = session.item_count(item_id) - int(ui.trade.sell.get(item_id, 0))
		if price <= 0:
			continue
		sellable += 1
		var item: Dictionary = _item(session, item_id)
		if item.has("instance"):
			item.description = "%s\n%s" % [item.description, session.Gear.refine_text(item)]
		# Herbs follow the market (inventory.gd market_factor): this month's rate against the usual.
		var rate: float = session.Inventory.market_factor(session, item_id)
		var trend := ""
		if rate >= 1.05:
			trend = " ↑"
		elif rate <= 0.95:
			trend = " ↓"
		var held_for_delivery := int(reserved.get(item_id, 0))
		if held_for_delivery > 0:
			mine.add_child(ui.label("交付预留 · %s ×%d" % [item.name, mini(held_for_delivery, session.item_count(item_id))], 14, ui.GOLD))
		var tip := str(item.description) + ("
本月行情：收价为常价的 %d%%（各月有涨落，同一种卖得多了会压价，过些日子回升）" % int(round(rate * 100.0)) if not is_equal_approx(rate, 1.0) else "")
		# A place short of it (inventory.gd demand) pays a premium until the shortage is filled.
		var shortage: Dictionary = session.Inventory.demand_entry(session, item_id)
		if not shortage.is_empty():
			var premium: float = session.Inventory.demand_factor(session, item_id)
			if premium > 1.01:
				trend = " ↑"
				tip += "
%s：眼下收价为常价的 %d%%，卖得越多越不缺，约 %d 日缺回来。" % [shortage.text, int(round(premium * 100.0)), int(shortage.days)]
		var offer: Button = ui.button("%s ×%d · 售 %d%s" % [item.name, left, price, trend], func() -> void: ui.stage_sale(item_id), tip)
		ui.tint(offer, ui.grade_color(item))
		_set_icon(ui, offer, item)
		offer.disabled = left <= 0
		offer.alignment = HORIZONTAL_ALIGNMENT_LEFT
		mine.add_child(offer)
	if sellable == 0:
		mine.add_child(ui.paragraph("此地不收你行囊里的东西。" if session.available_here("sell") else "这里只卖不收。"))
	else:
		mine.add_child(ui.button("全部摆上", func() -> void:
			var keep: Dictionary = session.Inventory.reserved(session)
			for item_id: String in session.player.items.keys():
				var count: int = session.item_count(item_id) - int(keep.get(item_id, 0))
				if session.sell_price(item_id) > 0 and count > 0:
					ui.trade.sell[item_id] = count
			ui.render(), "把这里收购的东西全部摆上台面（委托与差事要交的留着）"))

	var goods: Array = session.shop_goods()
	for good: Dictionary in goods:
		var bought: String = good.item
		var item: Dictionary = session.content.item(bought)
		var once := good.has("key")
		var pick: Button = ui.button("%s · %d 灵石" % [item.name, int(good.price)], func() -> void: ui.stage_purchase(bought), item.description)
		ui.tint(pick, ui.grade_color(item))
		_set_icon(ui, pick, item)
		pick.disabled = once and bought in ui.trade.buy
		pick.alignment = HORIZONTAL_ALIGNMENT_LEFT
		shop.add_child(pick)
	if goods.is_empty():
		shop.add_child(ui.paragraph("这里只收不卖。"))

	table.add_child(ui.label("出 售", 16, ui.GOLD))
	var income := 0
	for item_id: String in ui.trade.sell:
		var count := int(ui.trade.sell[item_id])
		income += session.Inventory.sale_value(session, item_id, count)
		table.add_child(ui.button("%s ×%d" % [_item(session, item_id).name, count], func() -> void: ui.stage_sale(item_id, -1), "撤回一件"))
	table.add_child(ui.label("购 入", 16, ui.GOLD))
	var cost := 0
	for item_id: String in ui.trade.buy:
		cost += _price(goods, item_id)
		table.add_child(ui.button(session.content.item(item_id).name, func() -> void: ui.stage_purchase(item_id, false), "撤回"))
	var net := income - cost
	table.add_child(ui.label("灵石  %+d" % net, 20, ui.GOLD if net >= 0 else Color("#e39a82")))
	var short := int(session.player.stones) + net < 0
	if short:
		table.add_child(ui.paragraph("灵石不够。", Color("#e39a82")))
	var actions := HBoxContainer.new()
	actions.add_theme_constant_override("separation", 10)
	table.add_child(actions)
	actions.add_child(ui.button("返回", ui.close_overlay))
	var confirm: Button = ui.button("确定", ui.confirm_trade, "成交")
	confirm.disabled = short or (ui.trade.sell.is_empty() and ui.trade.buy.is_empty())
	actions.add_child(confirm)

static func _column(ui, parent: HBoxContainer, title: String) -> VBoxContainer:
	var frame := VBoxContainer.new()
	frame.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	parent.add_child(frame)
	frame.add_child(ui.label(title, 18, ui.GOLD))
	var scroll := ScrollContainer.new()
	scroll.horizontal_scroll_mode = ScrollContainer.SCROLL_MODE_DISABLED
	scroll.custom_minimum_size = Vector2(0, 350)
	scroll.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	frame.add_child(scroll)
	var column := VBoxContainer.new()
	column.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	column.add_theme_constant_override("separation", 6)
	scroll.add_child(column)
	return column

static func _price(goods: Array, item_id: String) -> int:
	for good: Dictionary in goods:
		if good.item == item_id:
			return int(good.price)
	return 0

## An item by its id, or a refined 宝物 by its instance id.
static func _item(session, item_id: String) -> Dictionary:
	return session.gear_item(item_id) if session.Gear.is_instance(item_id) else session.content.item(item_id)

## A good's own icon (a 宝物's or a 玉简's composed one) on its button, else its grade's badge.
static func _set_icon(ui, button: Button, item: Dictionary) -> void:
	var picture: Texture2D = ui.ArtLibrary.item_icon(ui.session.content, item)
	if picture != null:
		ui.with_icon(button, picture, 30)
	else:
		ui.with_icon(button, ui.grade_icon(item), 16)
