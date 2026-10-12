extends RefCounted
## 功法: arts and 心法 in their slots, everything learned, worn equipment and the resulting stats.

static func render(ui) -> void:
	var session = ui.session
	var center: VBoxContainer = ui.center
	center.add_child(ui.label("功 法", 26, ui.GOLD))
	var extra: Dictionary = session.bonuses()
	var elements: Array[String] = []
	for element: String in extra.element_damage:
		var element_name: String = "全属性" if element == "*" else session.content.technique_data.elements[element].name
		elements.append("%s +%d%%" % [element_name, int(round(float(extra.element_damage[element]) * 100.0))])
	center.add_child(ui.paragraph("攻击加成 +%d · 受伤 -%d%% · 修炼 ×%.2f%s" % [session.attack_bonus(), int(round(session.defense() * 100.0)), session.cultivation_speed(), " · " + "，".join(elements) if not elements.is_empty() else ""], ui.INK))
	var rules: Dictionary = session.content.rules
	for group: Array in [["art", "主动神通", session.player.arts, int(rules.art_slots)], ["method", "心法", session.player.methods, int(rules.method_slots)]]:
		center.add_child(ui.label("%s  %d / %d" % [group[1], group[2].size(), group[3]], 17, ui.GOLD))
		for technique_id: String in group[2]:
			_technique_row(ui, technique_id, true)
	var idle: Array = session.player.learned.filter(func(technique_id: String) -> bool: return not technique_id in session.player.arts and not technique_id in session.player.methods)
	if not idle.is_empty():
		center.add_child(ui.label("已习得", 17, ui.GOLD))
		for technique_id: String in idle:
			_technique_row(ui, technique_id, false)
	center.add_child(ui.label("法 宝", 17, ui.GOLD))
	for slot: String in session.content.equipment_data.slots:
		var worn: String = str(session.player.equipment.get(slot, ""))
		var row := HBoxContainer.new()
		row.add_theme_constant_override("separation", 10)
		center.add_child(row)
		var slot_label: Label = ui.label(session.content.equipment_data.slots[slot], 16, ui.MUTED)
		slot_label.custom_minimum_size.x = 60
		row.add_child(slot_label)
		if worn.is_empty():
			row.add_child(ui.label("未佩戴", 15, ui.MUTED))
			continue
		var gear: Dictionary = session.content.equipment(worn)
		var text: Label = ui.paragraph("%s · %s" % [gear.name, gear.description], ui.INK)
		text.size_flags_horizontal = Control.SIZE_EXPAND_FILL
		row.add_child(text)
		var taken := slot
		row.add_child(ui.button("取下", func() -> void: ui.run(func() -> String: return session.unequip_slot(taken))))
	center.add_child(ui.button("返回", func() -> void: ui.set_view("place")))

static func _technique_row(ui, technique_id: String, active: bool) -> void:
	var session = ui.session
	var center: VBoxContainer = ui.center
	var t: Dictionary = session.content.technique(technique_id)
	var row := HBoxContainer.new()
	row.add_theme_constant_override("separation", 10)
	center.add_child(row)
	var title: Label = ui.label("%s\n%s · %s" % [t.name, t.tier_name, session.content.technique_data.elements[t.element].name], 15, ui.GOLD if int(t.tier) >= 3 else ui.INK)
	title.custom_minimum_size.x = 120
	row.add_child(title)
	var text: Label = ui.paragraph(t.description)
	text.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	row.add_child(text)
	var chosen := technique_id
	if active:
		row.add_child(ui.button("停下", func() -> void: ui.run(func() -> String: return session.unequip_technique(chosen))))
		return
	var slots: Array = session.player.arts if t.slot == "art" else session.player.methods
	var limit := int(session.content.rules.art_slots if t.slot == "art" else session.content.rules.method_slots)
	var full := slots.size() >= limit
	var equip: Button = ui.button("运转", func() -> void: ui.run(func() -> String: return session.equip_technique(chosen)), "栏位已满，先停下一门" if full else "放入栏位")
	equip.disabled = full or not session.battle.is_empty()
	row.add_child(equip)
