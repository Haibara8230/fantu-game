extends RefCounted
## 炼器, a scroll of its own over the place (forge.gd): the materials in the pack, the bases a chosen
## material can make, the element to forge into it, what the piece will be before its random affixes,
## and the cost.
const Calendar = preload("res://scripts/core/calendar.gd")

static func render(ui) -> void:
	var session = ui.session
	var forge = session.Forge
	var center: VBoxContainer = ui.center
	center.add_child(ui.label("炼 器", 26, ui.GOLD))
	var held: Array[String] = forge.materials_held(session)
	if held.is_empty():
		center.add_child(ui.paragraph("行囊里没有炼器的材料。长街器铺卖青钢锭、青丝与青玉料；更好的玄铁、玄蚕丝与墨玉可到青云山执事堂以贡献兑换，或到天南南明坊市的万宝楼买，古修洞府、沉霞古境与拍卖里也有。每炉要同一种材料 %d 份。" % int(forge.data(session).count)))
		return
	var plan: Dictionary = ui.forge_plan
	if not str(plan.get("material", "")) in held:
		plan = {"material": held[0], "base": "", "element": "none"}
	var material := str(plan.material)
	var bases: Array[String] = forge.bases_for(session, material)
	if not str(plan.get("base", "")) in bases:
		plan.base = bases[0]
	ui.forge_plan = plan
	# Materials.
	center.add_child(ui.label("材料", 17, ui.MUTED))
	var row := HBoxContainer.new()
	row.add_theme_constant_override("separation", 8)
	center.add_child(row)
	for material_id: String in held:
		var item: Dictionary = session.content.item(material_id)
		var chosen := material_id
		var pick: Button = ui.button("%s ×%d" % [item.name, session.item_count(material_id)], func() -> void: ui.forge_plan = {"material": chosen, "base": "", "element": str(ui.forge_plan.get("element", "none"))}; ui.render(), str(item.description))
		ui.tint(pick, ui.grade_color(item))
		pick.disabled = material_id == material
		row.add_child(pick)
	# Bases.
	center.add_child(ui.label("打成", 17, ui.MUTED))
	var shapes := HBoxContainer.new()
	shapes.add_theme_constant_override("separation", 8)
	center.add_child(shapes)
	var slots: Dictionary = session.content.equipment_data.slots
	for base_id: String in bases:
		var base: Dictionary = session.content.equipment_data.bases[base_id]
		var shape := base_id
		var pick: Button = ui.button("%s · %s" % [base.nouns[base.nouns.size() - 1], slots[base.slot]], func() -> void: ui.forge_plan.base = shape; ui.render())
		pick.disabled = base_id == str(plan.base)
		shapes.add_child(pick)
	# Element.
	center.add_child(ui.label("属性", 17, ui.MUTED))
	var natures := HBoxContainer.new()
	natures.add_theme_constant_override("separation", 8)
	center.add_child(natures)
	var elements: Dictionary = session.content.technique_data.elements
	for element: String in ["none"] + elements.keys():
		var nature := element
		var pick: Button = ui.button("无属性" if element == "none" else str(elements[element].name), func() -> void: ui.forge_plan.element = nature; ui.render(), "宝物带上属性，同属神通伤害更高" if element != "none" else "不带属性")
		if element != "none":
			ui.tint(pick, Color(elements[element].color))
		pick.disabled = element == str(plan.element)
		natures.add_child(pick)
	# The flux (地火精): one more into the furnace, one more affix.
	var flux_id: String = forge.flux_item(session)
	if not flux_id.is_empty() and session.item_count(flux_id) > 0:
		var fire := CheckBox.new()
		fire.text = "投一枚%s（%d）：多一条词条" % [session.content.item(flux_id).name, session.item_count(flux_id)]
		fire.button_pressed = bool(plan.get("flux", false))
		fire.toggled.connect(func(on: bool) -> void: ui.forge_plan.flux = on; ui.render())
		# On the element row, so the furnace's button stays in view.
		natures.add_child(fire)
	else:
		plan.erase("flux")
	center.add_child(HSeparator.new())
	# What will come out, before its random affixes.
	var tier: int = forge.tier_of(session, material)
	var plain: Dictionary = session.content.equipment(session.Arsenal.equipment_id(str(plan.base), tier, str(plan.element), [], 0))
	var affixes: int = forge.affix_count(session, material, bool(plan.get("flux", false)))
	center.add_child(ui.label("将炼出 · %s" % plain.get("name", ""), 20, ui.grade_color(plain)))
	center.add_child(ui.paragraph(str(plain.get("description", "")) + ("　另有随机词条 %d 条。" % affixes if affixes > 0 else ""), ui.INK))
	center.add_child(ui.label("耗%s %d 份　·　%d 灵石　·　耗时 %s" % [session.content.item(material).name, int(forge.data(session).count), forge.fee(session, material), Calendar.duration_text(forge.days(session, material))], 17, ui.GOLD))
	var reason: String = forge.block(session, plan)
	var light: Button = ui.button("开炉炼器", func() -> void: ui.run(func() -> String: return session.forge_item(ui.forge_plan)), reason if not reason.is_empty() else "材料入炉，打出一件宝物")
	light.disabled = not reason.is_empty()
	light.custom_minimum_size = Vector2(180, 44)
	center.add_child(light)
