extends RefCounted
## 行囊: everything carried, grouped by category, with use and (where bought) sell buttons.

static func render(ui) -> void:
	var session = ui.session
	var center: VBoxContainer = ui.center
	center.add_child(ui.label("行 囊", 26, ui.GOLD))
	if session.player.items.is_empty():
		center.add_child(ui.paragraph("行囊空空如也。", ui.MUTED))
	for category: String in session.content.ITEM_CATEGORIES:
		var ids: Array = session.player.items.keys().filter(func(item_id: String) -> bool: return session.content.item(item_id).get("category", "") == category)
		if ids.is_empty():
			continue
		ids.sort()
		center.add_child(ui.label(session.content.ITEM_CATEGORIES[category], 17, ui.GOLD))
		for item_id: String in ids:
			var item: Dictionary = session.content.item(item_id)
			var row := HBoxContainer.new()
			row.add_theme_constant_override("separation", 10)
			center.add_child(row)
			var name_label: Label = ui.label("%s ×%d" % [item.name, session.item_count(item_id)], 16)
			name_label.custom_minimum_size.x = 150
			row.add_child(name_label)
			var text: Label = ui.paragraph(item.description)
			text.size_flags_horizontal = Control.SIZE_EXPAND_FILL
			row.add_child(text)
			var used := item_id
			if item.has("use"):
				var reason: String = session.use_block(item_id)
				var use_button: Button = ui.button("服用", func() -> void: ui.run(func() -> String: return session.use_item(used)), reason)
				use_button.disabled = not reason.is_empty()
				row.add_child(use_button)
			if item.get("category", "") == "manual":
				var block: String = session.learn_block(item.teaches)
				var study: Button = ui.button("参悟 · %d 日" % int(session.content.technique(item.teaches).study_days), func() -> void: ui.run(func() -> String: return session.study_manual(used)), block)
				study.disabled = not block.is_empty()
				row.add_child(study)
			if item.get("category", "") == "equipment":
				row.add_child(ui.button("装备", func() -> void: ui.run(func() -> String: return session.equip_item(used)), "换上这件法宝"))
			var price: int = session.sell_price(item_id)
			if price > 0:
				row.add_child(ui.button("出售 · %d" % price, func() -> void: ui.run(func() -> String: return session.sell(used, 1)), "在此地出售一件"))
	center.add_child(ui.button("返回", func() -> void: ui.set_view("place")))
