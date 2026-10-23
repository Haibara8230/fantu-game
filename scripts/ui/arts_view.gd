extends RefCounted
## The panel's 神通 and 功法 pages, after Mi Chang Sheng: what is in use on the left (the active arts
## with their keys, the 心法 in their slots), everything learned on the right, filtered by element.
## A learned art is put into use, or taken out, by pressing it.
const Settings = preload("res://scripts/ui/settings.gd")
const ArtLibrary = preload("res://scripts/ui/art_library.gd")

static func render_arts(ui) -> void:
	var session = ui.session
	var extra: Dictionary = session.bonuses()
	var elements: Array[String] = []
	for element: String in extra.element_damage:
		var element_name: String = "全属性" if element == "*" else session.content.technique_data.elements[element].name
		elements.append("%s +%d%%" % [element_name, int(round(float(extra.element_damage[element]) * 100.0))])
	ui.center.add_child(ui.paragraph("攻击加成 +%d · 受伤 -%d%%%s" % [session.attack_bonus(), int(round(session.defense() * 100.0)), " · " + "，".join(elements) if not elements.is_empty() else ""], ui.INK))
	_page(ui, "art", "主动神通", session.player.arts, int(session.content.rules.art_slots), true)

static func render_methods(ui) -> void:
	var session = ui.session
	ui.center.add_child(ui.paragraph("心法常驻运转：修炼速度 ×%.2f。" % session.cultivation_speed(), ui.INK))
	_page(ui, "method", "心法", session.player.methods, int(session.content.rules.method_slots), false)

## Slots on the left, the learned arts of this kind on the right.
static func _page(ui, slot_kind: String, title: String, in_use: Array, limit: int, keyed: bool) -> void:
	var session = ui.session
	var columns := HBoxContainer.new()
	columns.add_theme_constant_override("separation", 24)
	ui.center.add_child(columns)
	var slots := VBoxContainer.new()
	slots.custom_minimum_size.x = 330
	slots.add_theme_constant_override("separation", 8)
	columns.add_child(slots)
	slots.add_child(ui.label("%s  %d / %d" % [title, in_use.size(), limit], 18, ui.GOLD))
	ui.arts_slot = clampi(ui.arts_slot, 0, limit - 1)
	var selected_slot: int = ui.arts_slot
	var slot_grid := GridContainer.new()
	slot_grid.columns = 5 if keyed else 3
	slot_grid.add_theme_constant_override("h_separation", 7)
	slot_grid.add_theme_constant_override("v_separation", 7)
	slots.add_child(slot_grid)
	for index: int in limit:
		var key_text := ("[%s]" % Settings.key_name(ui, "skill_%d" % (index + 1))) if keyed else "主修" if index == 0 else "辅修%d" % index
		var id: String = in_use[index] if index < in_use.size() else ""
		var t: Dictionary = session.held_technique(id)
		var cell: Button = ui.button("", func() -> void: ui.arts_slot = index; ui.render(), "空槽" if t.is_empty() else str(t.name) + "\n" + str(t.description))
		cell.custom_minimum_size = Vector2(59, 81)
		cell.name = "LoadoutSlot%d" % (index + 1)
		cell.disabled = not session.battle.is_empty()
		if index == selected_slot:
			ui.tint(cell, ui.GOLD)
		slot_grid.add_child(cell)
		if not t.is_empty():
			var picture := _technique_picture(t, 43)
			picture.position = Vector2(8, 15)
			picture.mouse_filter = Control.MOUSE_FILTER_IGNORE
			cell.add_child(picture)
		var key: Label = ui.label(key_text, 12, ui.GOLD)
		key.position = Vector2(4, 0)
		key.mouse_filter = Control.MOUSE_FILTER_IGNORE
		cell.add_child(key)
		var caption: Label = ui.label(str(t.get("name", "空")), 12, ui.GOLD if index == selected_slot else ui.INK)
		caption.position = Vector2(1, 59)
		caption.size = Vector2(57, 20)
		caption.clip_text = true
		caption.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
		caption.mouse_filter = Control.MOUSE_FILTER_IGNORE
		cell.add_child(caption)
	var selected_id: String = in_use[selected_slot] if selected_slot < in_use.size() else ""
	if selected_id.is_empty():
		slots.add_child(ui.paragraph("已选择空槽 · 从右侧选择一门功法放入。"))
	else:
		var selected: Dictionary = session.held_technique(selected_id)
		slots.add_child(ui.label(str(selected.name), 20, ui.grade_color(selected)))
		slots.add_child(ui.paragraph(session.Layers.progress_text(session, selected_id), ui.GOLD))
		slots.add_child(ui.paragraph(str(selected.description)))
		var stop: Button = ui.button("停下", func() -> void: ui.run(func() -> String: return session.unequip_technique(selected_id)), "移出当前选中栏位")
		stop.disabled = not session.battle.is_empty()
		slots.add_child(stop)
	var library := VBoxContainer.new()
	library.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	library.add_theme_constant_override("separation", 8)
	columns.add_child(library)
	var filters := HBoxContainer.new()
	filters.add_theme_constant_override("separation", 6)
	library.add_child(filters)
	var choices: Array = [["all", "全部"]]
	for element: String in session.content.technique_data.elements:
		choices.append([element, session.content.technique_data.elements[element].name])
	for pair: Array in choices:
		var element_id: String = pair[0]
		var tab: Button = ui.button(pair[1], func() -> void: ui.set_arts_filter(element_id))
		tab.disabled = ui.arts_filter == element_id
		tab.custom_minimum_size = Vector2(48, 34)
		filters.add_child(tab)
	var grid := GridContainer.new()
	grid.columns = 2
	grid.add_theme_constant_override("h_separation", 8)
	grid.add_theme_constant_override("v_separation", 8)
	library.add_child(grid)
	var shown := 0
	for technique_id: String in session.player.learned:
		var t: Dictionary = session.held_technique(technique_id)
		if t.slot != slot_kind or (ui.arts_filter != "all" and t.element != ui.arts_filter):
			continue
		shown += 1
		var active: bool = technique_id in in_use
		var card: Button = ui.button("%s%s\n%s · %s · 第 %d / %d 层" % [t.name, "（运转中）" if active else "", t.tier_name, session.content.element_info(str(t.element)).get("name", ""), int(t.layer), int(t.layers)], func() -> void:
			if active:
				ui.arts_slot = in_use.find(technique_id)
				ui.render()
			else:
				if selected_id.is_empty():
					ui.arts_slot = in_use.size()
				ui.run(func() -> String: return session.equip_technique(technique_id, selected_id)), t.description + ("\n点击查看所在栏位" if active else "\n放入选中槽位；该槽有功法时直接替换。"))
		ui.tint(card, ui.grade_color(t))
		ui.with_icon(card, ArtLibrary.technique_icon(t), 40)
		card.size_flags_horizontal = Control.SIZE_EXPAND_FILL
		card.custom_minimum_size.y = 56
		card.alignment = HORIZONTAL_ALIGNMENT_LEFT
		card.disabled = not session.battle.is_empty()
		grid.add_child(card)
	if shown == 0:
		library.add_child(ui.paragraph("没有此类已学的功法。"))
	# Layers are studied in seclusion, on the retreat scroll's 领悟 page (retreat_view.gd).
	library.add_child(ui.paragraph("功法层数在静室或洞府参悟：打开「闭关修炼」，在「领悟」页进行。斗法施展与闭关运转也会积累熟练。"))

## A technique's composed icon (art_library.gd technique_icon) at `side` pixels square.
static func _technique_picture(t: Dictionary, side: float) -> TextureRect:
	var rect := TextureRect.new()
	rect.texture = ArtLibrary.technique_icon(t)
	rect.custom_minimum_size = Vector2(side, side)
	rect.size_flags_vertical = Control.SIZE_SHRINK_CENTER
	rect.expand_mode = TextureRect.EXPAND_IGNORE_SIZE
	rect.stretch_mode = TextureRect.STRETCH_KEEP_ASPECT_CENTERED
	rect.texture_filter = CanvasItem.TEXTURE_FILTER_LINEAR_WITH_MIPMAPS
	return rect
