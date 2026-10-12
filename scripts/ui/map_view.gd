extends RefCounted
## Map view: the region's map fills the screen (main.gd keeps it as a layer); pick a node to see the
## route, days and danger in the small window, then set out.

static func render(ui) -> void:
	var session = ui.session
	var center: VBoxContainer = ui.center
	var map_target: String = ui.map_target
	var world_map = ui.world_map
	var path: Array[String] = []
	if not map_target.is_empty() and map_target != session.player.location:
		path = session.path_to(map_target)
	var people_at := {}
	for person_id: String in session.known_npcs():
		var where: String = session.npc_location(person_id)
		if not where.is_empty():
			if not people_at.has(where):
				people_at[where] = []
			people_at[where].append(session.person(person_id).name)
	world_map.configure(session.content, session.world.flags, session.player.location, map_target, path, str(session.player.journey.get("to", "")), people_at)
	if map_target.is_empty() or not session.location_visible(map_target):
		center.add_child(ui.paragraph("点选舆图上的地点，查看路线与危险。路上每段都可能有遭遇，境界越高越少受扰。", ui.MUTED))
		return
	var target: Dictionary = session.content.locations[map_target]
	center.add_child(ui.label("%s  ·  %s" % [target.name, target.subtitle], 20, ui.GOLD))
	center.add_child(ui.paragraph(target.description))
	if map_target == session.player.location:
		center.add_child(ui.paragraph("你就在此地。", ui.INK))
		return
	if path.is_empty():
		center.add_child(ui.paragraph("眼下没有通往此地的路。", ui.INK))
		return
	var names: Array[String] = []
	var worst := 0
	for index: int in path.size():
		names.append(session.content.locations[path[index]].name)
		if index > 0:
			worst = maxi(worst, int(session.content.route_between(path[index - 1], path[index]).danger))
	var danger_names := ["太平", "略有风险", "颇为凶险", "九死一生"]
	center.add_child(ui.paragraph("路线 · %s\n共 %d 日 · 沿途%s" % [" → ".join(names), session.content.path_days(path), danger_names[worst]], ui.INK))
	var go: Button = ui.button("启程前往" + target.name, func() -> void: ui.depart(ui.map_target))
	go.disabled = not ui.settled()
	center.add_child(go)
