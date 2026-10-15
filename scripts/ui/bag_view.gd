extends RefCounted
## The panel's 行囊, after Mi Chang Sheng: what is worn on the left (the three equipment slots and what
## they add), everything carried on the right, filtered by category, each with what can be done with it.

static func render(ui) -> void:
	var session = ui.session
	var columns := HBoxContainer.new()
	columns.add_theme_constant_override("separation", 24)
	ui.center.add_child(columns)
	var worn := VBoxContainer.new()
	worn.custom_minimum_size.x = 300
	worn.add_theme_constant_override("separation", 8)
	columns.add_child(worn)
	worn.add_child(ui.label("宝 物", 18, ui.GOLD))
	for slot: String in session.content.equipment_data.slots:
		var item_id: String = str(session.player.equipment.get(slot, ""))
		var row := HBoxContainer.new()
		row.add_theme_constant_override("separation", 8)
		worn.add_child(row)
		var slot_label: Label = ui.label(session.content.equipment_data.slots[slot], 15, ui.MUTED)
		slot_label.custom_minimum_size.x = 48
		row.add_child(slot_label)
		if item_id.is_empty():
			row.add_child(ui.label("未佩戴", 15, ui.MUTED))
			continue
		var gear: Dictionary = session.content.equipment(item_id)
		var name: Label = ui.label(gear.name, 15, ui.grade_color(gear))
		name.tooltip_text = (gear.description + "\n" + session.Arsenal.mastery_text(session.content, gear, int(session.player.realm))).strip_edges()
		name.mouse_filter = Control.MOUSE_FILTER_PASS
		name.size_flags_horizontal = Control.SIZE_EXPAND_FILL
		row.add_child(name)
		row.add_child(ui.button("取下", func() -> void: ui.run(func() -> String: return session.unequip_slot(slot))))
	worn.add_child(ui.paragraph("攻击加成 +%d · 受伤 -%d%% · 修炼 ×%.2f" % [session.attack_bonus(), int(round(session.defense() * 100.0)), session.cultivation_speed()], ui.INK))
	worn.add_child(ui.label("灵石  %d" % int(session.player.stones), 17, ui.GOLD))

	var carried := VBoxContainer.new()
	carried.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	carried.add_theme_constant_override("separation", 8)
	columns.add_child(carried)
	var filters := HBoxContainer.new()
	filters.add_theme_constant_override("separation", 6)
	carried.add_child(filters)
	var present := {}
	for item_id: String in session.player.items:
		present[str(session.content.item(item_id).get("category", ""))] = true
	var choices: Array = [["all", "全部"]]
	for category: String in session.content.ITEM_CATEGORIES:
		if present.has(category):
			choices.append([category, session.content.ITEM_CATEGORIES[category]])
	for pair: Array in choices:
		var category_id: String = pair[0]
		var tab: Button = ui.button(pair[1], func() -> void: ui.set_bag_filter(category_id))
		tab.disabled = ui.bag_filter == category_id
		tab.custom_minimum_size = Vector2(56, 34)
		filters.add_child(tab)
	if session.player.items.is_empty():
		carried.add_child(ui.paragraph("行囊空空如也。", ui.MUTED))
		return
	var ids: Array = session.player.items.keys().filter(func(item_id: String) -> bool: return ui.bag_filter == "all" or session.content.item(item_id).get("category", "") == ui.bag_filter)
	ids.sort_custom(func(a: String, b: String) -> bool:
		var ca: String = session.content.item(a).get("category", "")
		var cb: String = session.content.item(b).get("category", "")
		return ca < cb or (ca == cb and a < b))
	for item_id: String in ids:
		_item_row(ui, carried, item_id)

static func _item_row(ui, parent: VBoxContainer, item_id: String) -> void:
	var session = ui.session
	var item: Dictionary = session.content.item(item_id)
	var row := HBoxContainer.new()
	row.add_theme_constant_override("separation", 8)
	parent.add_child(row)
	var name_label: Label = ui.label("%s ×%d" % [item.name, session.item_count(item_id)], 16, ui.grade_color(item))
	name_label.custom_minimum_size.x = 150
	row.add_child(name_label)
	var mastery: String = session.Arsenal.mastery_text(session.content, item, int(session.player.realm)) if item.get("category", "") == "equipment" else ""
	var text: Label = ui.paragraph(item.description + ("\n" + mastery if not mastery.is_empty() else ""))
	text.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	row.add_child(text)
	if item.has("use"):
		var reason: String = session.use_block(item_id)
		var use_button: Button = ui.button("研读" if item.get("category", "") == "recipe" else "服用", func() -> void: ui.run(func() -> String: return session.use_item(item_id)), reason)
		use_button.disabled = not reason.is_empty()
		row.add_child(use_button)
	if item.get("category", "") == "manual":
		var block: String = session.learn_block(item.teaches)
		var study: Button = ui.button("参悟 · %d 日" % session.study_days(session.content.technique(item.teaches)), func() -> void: ui.run(func() -> String: return session.study_manual(item_id)), block)
		study.disabled = not block.is_empty()
		row.add_child(study)
	if item.get("category", "") == "equipment":
		var usable: bool = session.Arsenal.wielded(session.content, item, int(session.player.realm)).usable
		var wear: Button = ui.button("装备", func() -> void: ui.run(func() -> String: return session.equip_item(item_id)), "换上这件宝物" if usable else mastery)
		wear.disabled = not usable
		row.add_child(wear)
	var price: int = session.sell_price(item_id)
	if price > 0:
		row.add_child(ui.button("出售 · %d" % price, func() -> void: ui.run(func() -> String: return session.sell(item_id, 1)), "在此地出售一件"))
