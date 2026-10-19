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
	for index: int in limit:
		var row := HBoxContainer.new()
		row.add_theme_constant_override("separation", 8)
		slots.add_child(row)
		var key: Label = ui.label(("[%s]" % Settings.key_name(ui, "skill_%d" % (index + 1))) if keyed else "%d" % (index + 1), 15, ui.MUTED)
		key.custom_minimum_size.x = 48
		row.add_child(key)
		if index >= in_use.size():
			row.add_child(ui.label("空", 15, ui.MUTED))
			continue
		var technique_id: String = in_use[index]
		var t: Dictionary = session.held_technique(technique_id)
		row.add_child(_technique_picture(t, 44))
		var name: Label = ui.label("%s\n%s" % [t.name, session.Layers.progress_text(session, technique_id)], 15, ui.grade_color(t))
		name.tooltip_text = "%s\n%s" % [session.Arsenal.technique_tag(session.content, t), t.description]
		name.mouse_filter = Control.MOUSE_FILTER_PASS
		name.size_flags_horizontal = Control.SIZE_EXPAND_FILL
		row.add_child(name)
		var stop: Button = ui.button("停下", func() -> void: ui.run(func() -> String: return session.unequip_technique(technique_id)), "移出栏位")
		stop.disabled = not session.battle.is_empty()
		row.add_child(stop)
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
	var full := in_use.size() >= limit
	var shown := 0
	for technique_id: String in session.player.learned:
		var t: Dictionary = session.held_technique(technique_id)
		if t.slot != slot_kind or (ui.arts_filter != "all" and t.element != ui.arts_filter):
			continue
		shown += 1
		var active: bool = technique_id in in_use
		var card: Button = ui.button("%s%s\n%s · %s · 第 %d / %d 层" % [t.name, "（运转中）" if active else "", t.tier_name, session.content.element_info(str(t.element)).get("name", ""), int(t.layer), int(t.layers)], func() -> void:
			if active:
				ui.run(func() -> String: return session.unequip_technique(technique_id))
			else:
				ui.run(func() -> String: return session.equip_technique(technique_id)), t.description + ("\n点击停下" if active else ("\n栏位已满，先停下一门" if full else "\n点击运转")))
		ui.tint(card, ui.grade_color(t))
		ui.with_icon(card, ArtLibrary.technique_icon(t), 40)
		card.size_flags_horizontal = Control.SIZE_EXPAND_FILL
		card.custom_minimum_size.y = 56
		card.alignment = HORIZONTAL_ALIGNMENT_LEFT
		card.disabled = (not active and full) or not session.battle.is_empty()
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
