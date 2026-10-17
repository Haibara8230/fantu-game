extends RefCounted
## The panel's 行囊, after Mi Chang Sheng: what is worn on the left (the three equipment slots and what
## they add), everything carried on the right, filtered by category, each with what can be done with it.
const ArtLibrary = preload("res://scripts/ui/art_library.gd")

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
		var gear: Dictionary = session.gear_item(item_id)
		var worn_icon: Texture2D = ArtLibrary.gear_icon(gear)
		row.add_child(_icon(worn_icon, 36) if worn_icon != null else ArtLibrary.icon_rect("grades/grade_%d" % session.content.rarity_of(gear), 16))
		var name: Label = ui.label(gear.name, 15, ui.grade_color(gear))
		name.tooltip_text = (gear.description + "\n" + session.Gear.refine_text(gear) + "\n" + session.Arsenal.mastery_text(session.content, gear, int(session.player.realm))).strip_edges()
		name.mouse_filter = Control.MOUSE_FILTER_PASS
		name.size_flags_horizontal = Control.SIZE_EXPAND_FILL
		row.add_child(name)
		var refine := _refine_button(ui, item_id, slot)
		if refine != null:
			row.add_child(refine)
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
	# Refined 宝物 are instances of their own (gear.gd), listed apart from the stacks.
	var instances: Array[String] = session.Gear.carried(session)
	if not instances.is_empty():
		present["equipment"] = true
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
	if session.player.items.is_empty() and instances.is_empty():
		carried.add_child(ui.paragraph("行囊空空如也。", ui.MUTED))
		return
	if ui.bag_filter in ["all", "equipment"]:
		for item_id: String in instances:
			_item_row(ui, carried, item_id)
	var ids: Array = session.player.items.keys().filter(func(item_id: String) -> bool: return ui.bag_filter == "all" or session.content.item(item_id).get("category", "") == ui.bag_filter)
	ids.sort_custom(func(a: String, b: String) -> bool:
		var ca: String = session.content.item(a).get("category", "")
		var cb: String = session.content.item(b).get("category", "")
		return ca < cb or (ca == cb and a < b))
	for item_id: String in ids:
		_item_row(ui, carried, item_id)

static func _item_row(ui, parent: VBoxContainer, item_id: String) -> void:
	var session = ui.session
	var item: Dictionary = session.gear_item(item_id) if session.Gear.is_instance(item_id) else session.content.item(item_id)
	var row := HBoxContainer.new()
	row.add_theme_constant_override("separation", 8)
	parent.add_child(row)
	# The item's picture (art_library.gd item_icon): painted art, or the composed icon of a 宝物 or 玉简,
	# whose frame tells the grade; without one, the grade's badge. A holder of fixed width keeps the names
	# in line whether there is a picture or not.
	var icon_holder := CenterContainer.new()
	icon_holder.size_flags_vertical = Control.SIZE_SHRINK_BEGIN
	row.add_child(icon_holder)
	var picture: Texture2D = ArtLibrary.item_icon(session.content, item)
	if picture != null:
		icon_holder.custom_minimum_size = Vector2(44, 44)
		icon_holder.add_child(_icon(picture, 44))
	else:
		# One line high, so the badge sits beside the name.
		icon_holder.custom_minimum_size = Vector2(44, 26)
		icon_holder.add_child(ArtLibrary.icon_rect("grades/grade_%d" % session.content.rarity_of(item), 18))
	var name_label: Label = ui.label(item.name if item.has("instance") else "%s ×%d" % [item.name, session.item_count(item_id)], 16, ui.grade_color(item))
	name_label.custom_minimum_size.x = 200
	name_label.size_flags_horizontal = Control.SIZE_SHRINK_BEGIN
	name_label.clip_text = true
	name_label.tooltip_text = name_label.text
	row.add_child(name_label)
	var mastery: String = session.Arsenal.mastery_text(session.content, item, int(session.player.realm)) if item.get("category", "") == "equipment" else ""
	var details := "\n".join([item.description, session.Gear.refine_text(item), mastery, comparison_text(session, item_id)].filter(func(line: String) -> bool: return not line.is_empty()))
	var text: Label = ui.paragraph(details)
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
		var refine := _refine_button(ui, item_id, "")
		if refine != null:
			row.add_child(refine)
	var price: int = session.sell_price(item_id)
	if price > 0:
		row.add_child(ui.button("出售 · %d" % price, func() -> void: ui.run(func() -> String: return session.sell(item_id, 1)), "在此地出售一件"))

	# Wrapped manual descriptions must not stretch the buttons or centre the item name vertically.
	for child: Control in row.get_children():
		child.size_flags_vertical = Control.SIZE_SHRINK_BEGIN

## 祭炼 for a piece worn short of its realm (gear.gd), its days and stones shown before it is pressed;
## null for a piece already wielded fully or far beyond reach.
static func _refine_button(ui, item_id: String, slot: String) -> Button:
	var session = ui.session
	var piece: Dictionary = session.gear_item(item_id)
	var held: Dictionary = session.Arsenal.wielded(session.content, piece, int(session.player.realm))
	if piece.is_empty() or int(held.short) == 0 or not bool(held.usable):
		return null
	var cost: Dictionary = session.Gear.refine_cost(session, piece)
	var reason: String = session.refine_block(item_id, slot)
	var tip := "祭炼一次：耗 %d 日、灵石 %d，驾驭 +%d%%，至多 %d%%。契合随主人，转手即失。" % [int(cost.days), int(cost.stones), int(round(float(session.content.equipment_data.refine.step) * 100.0)), int(round(float(held.limit) * 100.0))]
	var button: Button = ui.button("祭炼 · %d 日" % int(cost.days), func() -> void: ui.run(func() -> String: return session.refine_gear(item_id, slot)), tip if reason.is_empty() else reason)
	button.disabled = not reason.is_empty()
	return button

static func comparison_text(session, item_id: String) -> String:
	var names := {"attack":"攻击", "max_hp":"气血上限", "max_qi":"灵力上限", "defense":"减伤", "cultivation":"修炼速度", "orb_cap":"灵气上限", "orb_first":"开局灵气"}
	var changes: Dictionary = session.Loadout.equipment_comparison(session, item_id)
	var lines: Array[String] = []
	for key: String in changes:
		var percentage := key in ["defense", "cultivation"]
		var amount := float(changes[key]) * (100.0 if percentage else 1.0)
		lines.append("%s %+d%s" % [names[key], int(round(amount)), "%" if percentage else ""])
	return "换上后：" + "、".join(lines) if not lines.is_empty() else ""

## An item's picture at `side` pixels square, smoothed as it shrinks.
static func _icon(picture: Texture2D, side: float) -> TextureRect:
	var rect := TextureRect.new()
	rect.texture = picture
	rect.custom_minimum_size = Vector2(side, side)
	rect.size_flags_horizontal = Control.SIZE_SHRINK_BEGIN
	rect.size_flags_vertical = Control.SIZE_SHRINK_CENTER
	rect.expand_mode = TextureRect.EXPAND_IGNORE_SIZE
	rect.stretch_mode = TextureRect.STRETCH_KEEP_ASPECT_CENTERED
	rect.texture_filter = CanvasItem.TEXTURE_FILTER_LINEAR_WITH_MIPMAPS
	return rect
