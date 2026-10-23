extends RefCounted
## A twelve-path scroll. Rules and node availability are always read from Dao.

static func render(ui) -> void:
	var s = ui.session
	var dao = s.Dao
	var path: String = ui.dao_path
	var current: Dictionary = dao.state(s)
	ui.center.add_child(ui.label("悟 道  ·  余 %d 点" % dao.points(s), 26, ui.GOLD))
	ui.center.add_child(ui.paragraph("学习、功法突破积累道境；斗法与论道所得感悟需闭关吸收。境界成长、论道积累及各道融会贯通提供悟道点。"))
	var row := HBoxContainer.new()
	row.add_theme_constant_override("separation", 20)
	ui.center.add_child(row)
	var paths := GridContainer.new()
	paths.columns = 2
	paths.add_theme_constant_override("h_separation", 6)
	paths.add_theme_constant_override("v_separation", 6)
	row.add_child(paths)
	for id: String in s.content.dao_data.paths:
		var stage: int = dao.stage_of(s, id)
		var title: String = "未入门" if stage == 0 else s.content.dao_data.stages[stage - 1].name
		var button: Button = ui.button("%s道\n%s" % [s.content.dao_data.paths[id], title], func() -> void:
			ui.dao_path = id
			ui.render())
		button.custom_minimum_size = Vector2(92, 56)
		button.disabled = id == path
		paths.add_child(button)
	var detail := VBoxContainer.new()
	detail.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	detail.add_theme_constant_override("separation", 12)
	row.add_child(detail)
	var xp := int(current.xp.get(path, 0))
	var stage: int = dao.stage_of(s, path)
	var ceiling: int = int(s.content.dao_data.stages[mini(stage, 4)].xp)
	detail.add_child(ui.label("%s道 · 理解 %d / %d" % [s.content.dao_data.paths[path], xp, ceiling], 20, ui.GOLD))
	ui.meter(detail, "道境", xp, ceiling, ui.GOLD)
	var pending := int(current.pending.get(path, 0))
	var reflect: Button = ui.button("闭关感悟 · 待吸收 %d" % pending, func() -> void: ui.run(func() -> String: return dao.reflect(s, path)), "在可闭关之处感悟三十日，按实际经过的日数吸收感悟并支付房钱。")
	reflect.disabled = pending <= 0 or not s.blocked().is_empty() or not s.Layers.seclusion_block(s).is_empty()
	detail.add_child(reflect)
	var tree := HBoxContainer.new()
	tree.add_theme_constant_override("separation", 8)
	detail.add_child(tree)
	var nodes: Dictionary = dao.catalogue(s.content)
	for tier: int in 5:
		var column := VBoxContainer.new()
		column.size_flags_horizontal = Control.SIZE_EXPAND_FILL
		column.add_theme_constant_override("separation", 8)
		tree.add_child(column)
		column.add_child(ui.label(s.content.dao_data.stages[tier].name, 14, ui.GOLD if stage > tier else ui.MUTED))
		for id: String in nodes:
			var node: Dictionary = nodes[id]
			if node.path != path or int(node.stage) != tier + 1:
				continue
			var picked: bool = id in current.nodes
			var reason: String = dao.pick_block(s, id)
			var button: Button = ui.button("%s\n%s" % [node.name, "已领悟" if picked else "%d 悟道点" % int(node.cost)], func() -> void:
				ui.run(func() -> String: return dao.forget(s, id) if picked else dao.pick(s, id)), str(node.text) + ("\n点击遗忘并归还悟道点。" if picked and bool(node.get("forget", true)) else "\n" + reason if not picked else "\n不可遗忘。"))
			button.custom_minimum_size = Vector2(100, 64)
			button.disabled = (not picked and not reason.is_empty()) or (picked and not bool(node.get("forget", true)))
			if picked:
				ui.tint(button, ui.GOLD)
			column.add_child(button)
