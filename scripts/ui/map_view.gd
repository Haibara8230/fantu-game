extends RefCounted
## Map view: the region's map fills the screen (main.gd keeps it as a layer); pick a node to see the
## route, days and danger in the small window, then set out. With more than one region known, tabs
## above turn the map to another region (ui.map_region; empty is the one the player is in).

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
	var shown := _shown_region(ui)
	world_map.configure(session.content, session.world.flags, session.player.location, map_target, path, str(session.player.journey.get("to", "")), people_at, shown)
	_region_tabs(ui, shown)
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
		center.add_child(ui.paragraph(_no_path_reason(session, map_target), ui.INK))
		return
	var names: Array[String] = []
	var worst := 0
	for index: int in path.size():
		names.append(session.content.locations[path[index]].name)
		if index > 0:
			worst = maxi(worst, int(session.content.route_between(path[index - 1], path[index]).danger))
	var danger_names := ["太平", "略有风险", "颇为凶险", "九死一生"]
	var fee: int = session.Journey.path_fee(session, path)
	var cost := "\n沿途过传送阵共 %d 灵石" % fee if fee > 0 else ""
	center.add_child(ui.paragraph("路线 · %s\n共 %d 日 · 沿途%s%s" % [" → ".join(names), session.path_days(path), danger_names[worst], cost], ui.INK))
	# On the guided start only the step's place is open; the mentor's words say so.
	var held: String = session.guide_block("travel", map_target)
	if held.is_empty() and fee > int(session.player.stones):
		held = "盘缠不足：这一路要 %d 灵石。" % fee
	var go: Button = ui.button("启程前往" + target.name, func() -> void: ui.depart(ui.map_target), held)
	go.disabled = not ui.settled() or not held.is_empty()
	center.add_child(go)
	if not held.is_empty():
		center.add_child(ui.paragraph(held, Color("#e3c08a")))

## The region the map shows: the one picked with the tabs while it still has a place the player
## knows, else the one the player is in.
static func _shown_region(ui) -> String:
	var session = ui.session
	var picked: String = ui.map_region
	for location_id: String in session.content.locations:
		if session.content.region_of(location_id) == picked and session.location_visible(location_id):
			return picked
	return str(session.content.region_of(session.player.location))

## One tab per region with a place the player knows, shown once there is more than one.
static func _region_tabs(ui, shown: String) -> void:
	var session = ui.session
	var known: Array[String] = []
	for location_id: String in session.content.locations:
		var region_id: String = session.content.region_of(location_id)
		if session.location_visible(location_id) and not region_id in known:
			known.append(region_id)
	if known.size() < 2:
		return
	var tabs := HBoxContainer.new()
	tabs.add_theme_constant_override("separation", 6)
	ui.center.add_child(tabs)
	for region_id: String in known:
		var name: String = session.content.regions[region_id].name
		var here: bool = region_id == session.content.region_of(session.player.location)
		var tab: Button = ui.button(name + ("（此处）" if here else ""), func() -> void: ui.set_map_region(region_id), "翻到%s的舆图" % name)
		tab.disabled = region_id == shown
		tabs.add_child(tab)

## Why no road leads there now: one that asks a higher realm (a 传送阵 before foundation), or none.
static func _no_path_reason(session, target_id: String) -> String:
	var open: Array[String] = session.content.find_path(session.player.location, target_id, session.world.flags)
	var asked := 0
	var by := ""
	for index: int in range(1, open.size()):
		var route: Dictionary = session.content.route_between(open[index - 1], open[index])
		if int(route.get("realm", 0)) > asked:
			asked = int(route.realm)
			by = str(route.get("by", "这条路"))
	if asked > int(session.player.realm):
		return "此去须经%s，%s以后方可通行。" % [by, session.content.realm(asked).name]
	return "眼下没有通往此地的路。"
