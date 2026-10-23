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
		center.add_child(ui.paragraph("行囊里没有炼器的材料。长街器铺卖青钢锭、青丝与青玉料；更好的玄铁、玄蚕丝与墨玉可到青云山执事堂以贡献兑换，或到天南南明城的万宝楼买，古修洞府、沉霞古境与拍卖里也有。每炉要同一种材料 %d 份。" % int(forge.data(session).count)))
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
	_custom_materials(ui, center, plan, held)
	_custom_effects(ui, center, plan)
	center.add_child(HSeparator.new())
	# What will come out, before its random affixes.
	var tier: int = forge.tier_for_plan(session, plan)
	var plain: Dictionary = session.content.equipment(session.Arsenal.equipment_id(str(plan.base), tier, str(plan.element), [], 0))
	var affixes := int(session.content.equipment_data.tiers[tier - 1].affixes) + (int(forge.data(session).flux.affixes) if bool(plan.get("flux", false)) else 0)
	var selected: Array = plan.get("affixes", [])
	var effect_text := ""
	for id: String in selected:
		effect_text += "　已定向：%s。" % session.content.equipment_data.affixes[id].name
	if plan.has("sigil"):
		effect_text += "　%s" % session.content.formulation_data.sigils[plan.sigil].text
	center.add_child(ui.label("将炼出 · %s" % plain.get("name", ""), 20, ui.grade_color(plain)))
	center.add_child(ui.paragraph(str(plain.get("description", "")) + effect_text + "　空余随机词条 %d 条。" % maxi(0, affixes - selected.size()), ui.INK))
	var costs: Array[String] = []
	for id: String in forge.ingredients(session, plan):
		costs.append("%s ×%d" % [session.content.item(id).name, int(forge.ingredients(session, plan)[id])])
	if bool(plan.get("flux", false)):
		costs.append("%s ×1" % session.content.item(flux_id).name)
	center.add_child(ui.paragraph("消耗 " + "、".join(costs) + "　·　%d 灵石　·　耗时 %s" % [forge.fee(session, material), Calendar.duration_text(forge.days(session, material))], ui.GOLD))
	var reason: String = forge.block(session, plan)
	var light: Button = ui.button("开炉炼器", func() -> void: ui.run(func() -> String: return session.forge_item(ui.forge_plan)), reason if not reason.is_empty() else "材料入炉，打出一件宝物")
	light.disabled = not reason.is_empty()
	light.custom_minimum_size = Vector2(180, 44)
	center.add_child(light)

static func _custom_materials(ui, center: VBoxContainer, plan: Dictionary, held: Array[String]) -> void:
	var s = ui.session
	var mixed := CheckBox.new()
	mixed.text = "组合多种材料（主材决定器型，品阶取投入材料中的最低品阶）"
	mixed.button_pressed = plan.has("materials")
	mixed.toggled.connect(func(on: bool) -> void:
		if on:
			plan.materials = {str(plan.material): int(s.Forge.data(s).count)}
		else:
			plan.erase("materials")
		plan.erase("affixes")
		ui.render())
	center.add_child(mixed)
	if not plan.has("materials"):
		return
	var grid := GridContainer.new()
	grid.columns = 3
	grid.add_theme_constant_override("h_separation", 12)
	center.add_child(grid)
	for id: String in held:
		var line := HBoxContainer.new()
		grid.add_child(line)
		line.add_child(ui.label("%s ×%d" % [s.content.item(id).name, int(plan.materials.get(id, 0))], 15))
		for delta: int in [-1, 1]:
			var change: Button = ui.button("−" if delta < 0 else "+", func() -> void:
				var count := int(plan.materials.get(id, 0)) + delta
				if count <= 0:
					plan.materials.erase(id)
				else:
					plan.materials[id] = count
				plan.erase("affixes")
				ui.render())
			change.custom_minimum_size = Vector2(34, 30)
			change.disabled = int(plan.materials.get(id, 0)) <= 0 if delta < 0 else int(plan.materials.get(id, 0)) >= mini(12, s.item_count(id))
			line.add_child(change)

static func _custom_effects(ui, center: VBoxContainer, plan: Dictionary) -> void:
	var s = ui.session
	var tier: int = s.Forge.tier_for_plan(s, plan)
	var budget := int(s.content.equipment_data.tiers[tier - 1].affixes) + (int(s.Forge.data(s).flux.affixes) if bool(plan.get("flux", false)) else 0)
	center.add_child(ui.label("定向词条 · %d 槽（空余槽由炉中自然成纹）" % budget, 17, ui.GOLD))
	var row := HFlowContainer.new()
	row.add_theme_constant_override("h_separation", 8)
	center.add_child(row)
	for id: String in s.Forge.affixes_for(s, plan):
		var selected: bool = id in plan.get("affixes", [])
		var button: Button = ui.button(str(s.content.equipment_data.affixes[id].name) + (" ✓" if selected else ""), func() -> void:
			var choices: Array = plan.get("affixes", []).duplicate()
			if id in choices:
				choices.erase(id)
			else:
				choices.append(id)
			plan.affixes = choices
			ui.render())
		button.disabled = not selected and plan.get("affixes", []).size() >= budget
		row.add_child(button)
	var sigils: Dictionary = s.content.formulation_data.sigils
	var none: Button = ui.button("不铭刻灵纹", func() -> void: plan.erase("sigil"); ui.render())
	none.disabled = str(plan.get("sigil", "")).is_empty()
	row.add_child(none)
	for id: String in sigils:
		var rule: Dictionary = sigils[id]
		var button: Button = ui.button(str(rule.name) + "灵纹", func() -> void: plan.sigil = id; ui.render(), str(rule.text))
		button.disabled = s.Dao.value(s, str(rule.dao)) <= 0 or str(plan.get("sigil", "")) == id or s.content.equipment_data.bases[str(plan.base)].slot != "weapon"
		row.add_child(button)
