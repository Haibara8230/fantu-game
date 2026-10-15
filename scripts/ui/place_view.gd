extends RefCounted
## The place the player is at, drawn as a scene after Mi Chang Sheng: the place's picture fills the
## screen with its name at the top, its spots hang on their buildings as paper tags and the people here
## wait in a drawer at the left edge (render_scene). Nothing covers the scene until the player turns to
## a spot or a person; then a scroll opens in the middle with its picture, text and actions, and closes
## again with 关闭 or Esc.
const Calendar = preload("res://scripts/core/calendar.gd")
const Landscape = preload("res://scripts/ui/landscape.gd")
const PeopleView = preload("res://scripts/ui/people_view.gd")
const CaveView = preload("res://scripts/ui/cave_view.gd")
const PAPER := Color("#e9dfc4")
const INK_DARK := Color("#2c261c")

## The scene over the place's picture: its name, the spots as tags, the people drawer and the way out.
static func render_scene(ui, layer: Control) -> void:
	var session = ui.session
	var location: Dictionary = session.content.locations[session.player.location]
	var title := PanelContainer.new()
	title.add_theme_stylebox_override("panel", ui.style(Color(0.04, 0.09, 0.1, 0.78), Color("#5d7a6f"), 10))
	title.anchor_left = 0.5
	title.anchor_right = 0.5
	title.offset_left = -170.0
	title.offset_right = 170.0
	title.offset_top = 16.0
	title.grow_horizontal = Control.GROW_DIRECTION_BOTH
	layer.add_child(title)
	var names := VBoxContainer.new()
	names.add_theme_constant_override("separation", 0)
	title.add_child(names)
	var name_label: Label = ui.label(location.name, 28, ui.GOLD)
	name_label.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	names.add_child(name_label)
	var subtitle: Label = ui.label(location.subtitle, 14, ui.MUTED)
	subtitle.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	names.add_child(subtitle)
	var spots := _open_spots(session, session.player.location)
	for index: int in spots.size():
		var spot: Dictionary = spots[index]
		var spot_id: String = spot.id
		var tag := Button.new()
		tag.text = "\n".join(str(spot.name).split(""))
		tag.tooltip_text = spot.name
		tag.mouse_default_cursor_shape = Control.CURSOR_POINTING_HAND
		var chosen: bool = spot_id == ui.selected_spot and ui.selected_npc.is_empty()
		var paper: StyleBoxFlat = ui.style(PAPER if not chosen else Color("#f6e7b8"), ui.GOLD if chosen else Color("#6b5536"), 8)
		for state: String in ["normal", "hover", "pressed", "focus"]:
			tag.add_theme_stylebox_override(state, paper)
		tag.add_theme_color_override("font_color", INK_DARK)
		tag.add_theme_color_override("font_hover_color", Color("#000000"))
		tag.add_theme_color_override("font_pressed_color", INK_DARK)
		tag.add_theme_font_size_override("font_size", 19)
		# Each tag hangs on its own building (`tag` in the data); spots without one line up mid-screen.
		var at: Array = spot.get("tag", [0.3 + index * 0.09, 0.45])
		tag.anchor_left = float(at[0])
		tag.anchor_right = tag.anchor_left
		tag.anchor_top = float(at[1])
		tag.anchor_bottom = tag.anchor_top
		tag.pressed.connect(func() -> void: ui.audio.cue("click"))
		tag.pressed.connect(func() -> void:
			ui.selected_npc = ""
			ui.select_spot(spot_id))
		layer.add_child(tag)
	PeopleView.render_drawer(ui, layer)
	# The way out sits under the place's name, clear of the people and the records at the bottom.
	var leave: Button = ui.button("离开 · 舆图", func() -> void: ui.set_view("map"), "到舆图上选择去处")
	leave.anchor_left = 0.5
	leave.anchor_right = 0.5
	leave.offset_top = 100.0
	leave.grow_horizontal = Control.GROW_DIRECTION_BOTH
	leave.disabled = not ui.settled()
	layer.add_child(leave)

## The window: the person the player faces, or the spot they turned to with its actions.
static func render(ui) -> void:
	var session = ui.session
	var center: VBoxContainer = ui.center
	if ui.preview_mode:
		sect_choices(ui, center, true)
	if not ui.selected_npc.is_empty():
		PeopleView.render_person(ui, ui.selected_npc)
		return
	var location_id: String = session.player.location
	var location: Dictionary = session.content.locations[location_id]
	var spots := _open_spots(session, location_id)
	if not spots.any(func(spot: Dictionary) -> bool: return spot.id == ui.selected_spot):
		ui.selected_spot = ""
		return
	var spot: Dictionary = spots.filter(func(candidate: Dictionary) -> bool: return candidate.id == ui.selected_spot)[0]
	var title_row := HBoxContainer.new()
	title_row.add_theme_constant_override("separation", 14)
	center.add_child(title_row)
	title_row.add_child(ui.label(spot.name, 26, ui.GOLD))
	var where: Label = ui.label(location.name, 15, ui.MUTED)
	where.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	title_row.add_child(where)
	title_row.add_child(ui.button("关闭 Esc", ui.close_spot, "回到%s" % location.name))
	# The cave's depths show their rooms in place of the picture: the map is what the scroll is for.
	if "explore_cave" in spot.actions:
		CaveView.render(ui, center)
	else:
		var landscape = Landscape.new()
		landscape.location_id = location_id
		landscape.terrain = location.terrain
		landscape.spot_id = spot.id
		landscape.custom_minimum_size.y = 170
		center.add_child(landscape)
		center.add_child(ui.paragraph(spot.description if not str(spot.description).is_empty() else location.description, ui.INK))
	var grid := GridContainer.new()
	grid.columns = 2
	grid.add_theme_constant_override("h_separation", 12)
	grid.add_theme_constant_override("v_separation", 10)
	center.add_child(grid)
	var trading := false
	for action: String in spot.actions:
		if action in ["shop", "sell"]:
			if not trading:
				trading = true
				_open(ui, grid, "交易  ·  不耗时日", ui.open_trade, "买卖在一张台面上摆好，确定后才成交")
			continue
		_spot_action(ui, grid, action)
	for days: Variant in session.wait_options():
		var span := int(days)
		_timed(ui, grid, "停留  ·  " + Calendar.duration_text(span), func() -> String: return session.wait(span), "原地停留，等候时机；约定临近时会提醒")
	if "study" in spot.actions and not ui.preview_mode:
		sect_choices(ui, center, false)

static func _breakthrough_tooltip(session) -> String:
	var need: Dictionary = session.next_breakthrough()
	if need.is_empty():
		return "后续境界尚未开放"
	return "需修至%s，并有 %d 修为与 %d 枚%s（或天材地宝）；成败看把握" % [session.content.realm_title(int(session.player.realm), session.content.realm(int(session.player.realm)).stages.size() - 1), int(need.xp), int(need.pills), session.content.item(str(need.get("pill", "foundation_pill"))).name]

static func _open_spots(session, location_id: String) -> Array[Dictionary]:
	var result: Array[Dictionary] = []
	for spot: Dictionary in session.content.locations[location_id].spots:
		if session.content.spot_open(spot, session.world.flags, int(session.player.get("rank", 0))):
			result.append(spot)
	if result.is_empty():
		result.append({"id": "", "name": "此地", "description": "", "actions": []})
	return result

static func _spot_action(ui, grid: GridContainer, action: String) -> void:
	var session = ui.session
	var rules: Dictionary = session.content.rules
	if action.begins_with("battle:"):
		var enemy_id := action.trim_prefix("battle:")
		var enemy: Dictionary = session.content.enemies[enemy_id]
		var tooltip := "获胜得 %d 灵石、%d 修为、%d 灵草，斗法有受伤风险" % [enemy.reward_stones, enemy.reward_xp, enemy.reward_herbs]
		if int(enemy.min_realm) > 0:
			tooltip = "需达到%s。" % session.content.realm_title(int(enemy.min_realm), 0) + tooltip
		var challenge := _enemy_action(ui, grid, ("切磋 · " if enemy_id == "disciple" else "挑战 · ") + enemy.name, enemy_id, tooltip)
		challenge.disabled = int(session.player.realm) < int(enemy.min_realm) or (enemy.has("world_flag") and session.has_flag(enemy.world_flag))
		return
	match action:
		"cultivate":
			var tooltip := "选择闭关的时日，看看能得多少修为"
			if session.at_bottleneck():
				tooltip = "修为卡在瓶颈，闭关难进；需外出历练或服破障丹"
			elif session.at_xp_cap():
				tooltip = session.cap_text()
			elif session.mind_percent() < 100:
				tooltip = "心境不及此境所需，闭关收益减半；外出历练可磨砺心境"
			elif session.retreat_efficiency() < 100:
				tooltip = "连日闭关心神渐倦，收益降至 %d%%；外出做些别的事可以平复" % session.retreat_efficiency()
			_open(ui, grid, "闭关修炼", func() -> void: ui.set_view("retreat"), tooltip)
		"rest":
			_action(ui, grid, "静室休整  ·  " + Calendar.duration_text(session.rest_days()), "rest", "恢复全部气血与灵力；伤得越重，需要的日子越长")
		"breakthrough":
			_open(ui, grid, "突破境界", func() -> void: ui.set_view("breakthrough"), _breakthrough_tooltip(session))
		"gather":
			var gather: Dictionary = session.content.locations[session.player.location].gather
			var kinds: Array[String] = []
			for entry: Dictionary in gather.table:
				kinds.append(session.content.item(entry.item).name)
			_action(ui, grid, "采集灵草  ·  " + ui.duration("gather"), "gather", "采得 %d–%d 株，此地出产：%s" % [int(gather.picks[0]), int(gather.picks[1]), "、".join(kinds)])
		"inn_rest":
			_action(ui, grid, "客栈歇息  ·  %s · %d 灵石" % [ui.duration("inn_rest"), int(rules.inn_price)], "inn_rest", "恢复全部气血与灵力")
		"search_ruin":
			_action(ui, grid, "翻找石室  ·  " + ui.duration("search_ruin"), "search_ruin", "或得灵石、灵草，偶有丹药；搜过后需隔些时日")
		"study", "explore_cave":
			pass
		"inquire":
			var cost: Dictionary = session.content.rules.inquire
			_timed(ui, grid, "打听消息  ·  %s · %d 灵石" % [Calendar.duration_text(int(cost.days)), int(cost.price)], session.inquire, "请人喝壶茶，听听最近的消息：人物去向、宝物、委托与世事。")
		"commissions":
			var board: String = session.board_here()
			for offer: Dictionary in session.commission_offers(board):
				var shown: Dictionary = session.commission_text(offer)
				var key: String = offer.key
				var merit := int(offer.reward.get("contribution", 0))
				_timed(ui, grid, "接下：%s（灵石 %d%s%s）" % [shown.title, int(offer.reward.stones), "、修为 %d" % int(offer.reward.xp) if int(offer.reward.xp) > 0 else "", "、贡献 %d" % merit if merit > 0 else ""], func() -> String: return session.accept_commission(key), shown.text)
			for quest: Dictionary in session.player.quests:
				if quest.board != board:
					continue
				var reason: String = session.delivery_block(quest)
				var handed: String = quest.key
				var deliver: Button = ui.button("交付：%s" % session.commission_text(quest).title, func() -> void: ui.run(func() -> String: return session.deliver_commission(handed)), reason)
				deliver.disabled = not reason.is_empty()
				deliver.size_flags_horizontal = Control.SIZE_EXPAND_FILL
				grid.add_child(deliver)
		"tournament":
			var reason: String = session.tournament_block()
			var enter: Button = _timed(ui, grid, "报名外门小比", session.enter_tournament, reason if not reason.is_empty() else "三轮斗法，点到为止；头名可得功法玉简")
			enter.disabled = not reason.is_empty()
		"alchemy":
			var known: int = session.known_recipes().size()
			_open(ui, grid, "开炉炼丹", ui.open_alchemy, "已会 %d 张丹方：按丹方投入主药与药引，择火候开炉" % known if known > 0 else "还不会丹方；坊市丹铺与宗门执事堂可得")
		"ascend":
			var reason: String = session.ascend_block()
			var rise: Button = _timed(ui, grid, "踏上渡桥 · 白日飞升", func() -> String: return session.act("ascend"), reason if not reason.is_empty() else "此去便是天上，人间的一切都留在身后。这一生就此圆满。")
			rise.disabled = not reason.is_empty()
		"forge":
			_open(ui, grid, "炼器", ui.open_forge, "以三份同种材料打一件宝物：材料定品阶，属性自选，词条看火候")
		"field":
			_open(ui, grid, "照料灵田", func() -> void: ui.set_view("field"), "种下灵草，到了日子便可收获")
		"sect":
			var rank: Dictionary = session.sect_rank()
			_open(ui, grid, "宗门事务", func() -> void: ui.set_view("sect"), "%s · 贡献 %d：领月俸、申请晋升、兑换与捐献" % [rank.name, int(session.player.get("contribution", 0))])
		"teach":
			for technique_id: String in session.teachings():
				var taught: Dictionary = session.content.technique(technique_id)
				var reason: String = session.learn_block(technique_id)
				var learned_id := technique_id
				var study: Button = ui.button("参悟%s  ·  %d 日" % [taught.name, session.study_days(taught)], func() -> void: ui.run(func() -> String: return session.learn_here(learned_id)), "%s\n%s" % [session.Arsenal.technique_tag(session.content, taught), reason if not reason.is_empty() else taught.description])
				ui.tint(study, ui.grade_color(taught))
				study.disabled = not reason.is_empty()
				study.size_flags_horizontal = Control.SIZE_EXPAND_FILL
				grid.add_child(study)

## A button that opens a scroll of its own (the retreat, the trading table).
static func _open(ui, parent: GridContainer, title: String, callback: Callable, tooltip: String) -> void:
	var entry: Button = ui.button(title, callback, tooltip)
	entry.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	parent.add_child(entry)

## A button that runs a session action and shows its text.
static func _timed(ui, parent: GridContainer, title: String, callback: Callable, tooltip: String) -> Button:
	var entry: Button = ui.button(title, func() -> void: ui.run(callback), tooltip)
	entry.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	parent.add_child(entry)
	return entry

static func _action(ui, parent: GridContainer, title: String, action: String, tooltip: String) -> void:
	var entry: Button = ui.button(title, func() -> void: ui.run(func() -> String: return ui.session.act(action)), tooltip)
	entry.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	parent.add_child(entry)

static func _enemy_action(ui, parent: GridContainer, title: String, enemy_id: String, tooltip: String) -> Button:
	var entry: Button = ui.button(title, func() -> void: ui.run(func() -> String: return ui.session.start_battle(enemy_id)), tooltip)
	entry.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	parent.add_child(entry)
	return entry

## The lineage: at the sect's hall the home lineage can be studied; in the sect preview both sides
## are picked freely and the duel resets.
static func sect_choices(ui, parent: VBoxContainer, is_preview: bool) -> void:
	var session = ui.session
	if not is_preview:
		_home_lineage(ui, parent)
		return
	var row := HBoxContainer.new()
	row.add_theme_constant_override("separation", 10)
	parent.add_child(row)
	row.add_child(ui.label("我方传承", 15, ui.GOLD))
	var ids: Array[String] = ["wanderer", "qingyun", "chixiao", "changqing", "canglan", "xuanyue"]
	var select := OptionButton.new()
	select.custom_minimum_size = Vector2(145, 34)
	for id: String in ids:
		select.add_item(session.content.sects[id].name)
	select.select(ids.find(str(session.player.get("sect", "wanderer"))))
	select.item_selected.connect(func(index: int) -> void: ui.reset_preview(ids[index], ui.preview_opponent))
	row.add_child(select)
	row.add_child(ui.label("对手", 15, ui.MUTED))
	var opponent := OptionButton.new()
	opponent.custom_minimum_size = Vector2(145, 34)
	var foe_ids: Array[String] = ["qingyun", "chixiao", "changqing", "canglan", "xuanyue"]
	for id: String in foe_ids:
		opponent.add_item(session.content.sects[id].name)
	opponent.select(foe_ids.find(ui.preview_opponent))
	opponent.item_selected.connect(func(index: int) -> void: ui.reset_preview(str(session.player.sect), foe_ids[index]))
	row.add_child(opponent)
	row.add_child(ui.button("重置试演", func() -> void: ui.reset_preview(str(session.player.sect), ui.preview_opponent)))

## The hall's home lineage: what it teaches, and studying it.
static func _home_lineage(ui, parent: VBoxContainer) -> void:
	var session = ui.session
	var home: String = session.Loadout.home_lineage(session)
	var sect: Dictionary = session.content.sects[home]
	var arts: Array[String] = []
	for skill_id: String in sect.skills:
		arts.append(str(session.content.technique(skill_id).name))
	var row := HBoxContainer.new()
	row.add_theme_constant_override("separation", 12)
	parent.add_child(row)
	row.add_child(ui.label("本门传承 · %s" % sect.name, 17, ui.GOLD))
	if str(session.player.get("sect", "wanderer")) == home:
		row.add_child(ui.label("已研习：%s" % "、".join(arts), 15, ui.INK))
	else:
		var days := int(session.content.rules.lineage.study_days)
		row.add_child(ui.button("研习本门传承 · %d 日" % days, func() -> void: ui.run(func() -> String: return session.choose_sect(home)), "换上%s三门神通" % "、".join(arts)))
	parent.add_child(ui.paragraph(str(sect.description)))
