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
const ArtLibrary = preload("res://scripts/ui/art_library.gd")
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
		var paper: StyleBox = _paper_tag(ui, chosen)
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
	# The hall's own lineage comes first, above the everyday actions and the stays.
	if "study" in spot.actions and not ui.preview_mode:
		sect_choices(ui, center, false)
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
		_timed(ui, grid, "停留  ·  " + Calendar.duration_text(span), func() -> String: return session.wait(span), "原地停留调息，气血慢慢恢复（静室的一半快）；约定临近时会提醒")

## A spot's paper tag (assets/art/ui/tag.svg): a strip hung by a red cord, ragged at the foot; the chosen
## one brighter with a gold edge. Flat paper when the art is missing.
static func _paper_tag(ui, chosen: bool) -> StyleBox:
	var art: Texture2D = ArtLibrary.ui_icon("tag_chosen" if chosen else "tag")
	if art == null:
		return ui.style(PAPER if not chosen else Color("#f6e7b8"), ui.GOLD if chosen else Color("#6b5536"), 8)
	var box := StyleBoxTexture.new()
	box.texture = art
	# The cord and knot stay whole above, the ragged foot below; the paper between stretches.
	box.texture_margin_top = 24.0
	box.texture_margin_bottom = 12.0
	box.texture_margin_left = 8.0
	box.texture_margin_right = 8.0
	box.content_margin_top = 28.0
	box.content_margin_bottom = 14.0
	box.content_margin_left = 12.0
	box.content_margin_right = 12.0
	return box

static func _breakthrough_tooltip(session) -> String:
	var need: Dictionary = session.next_breakthrough()
	if need.is_empty():
		return "后续境界尚未开放"
	var stage: String = session.content.realm_title(int(session.player.realm), session.content.realm(int(session.player.realm)).stages.size() - 1)
	if int(need.get("pills", 0)) <= 0:
		return "需修至%s，并有 %d 修为；不靠丹药，成败看自身的把握，天材地宝与机缘可添几分" % [stage, int(need.xp)]
	return "需修至%s，并有 %d 修为与 %d 枚%s（或天材地宝）；成败看把握" % [stage, int(need.xp), int(need.pills), session.content.item(str(need.pill)).name]

static func _open_spots(session, location_id: String) -> Array[Dictionary]:
	var result: Array[Dictionary] = []
	for spot: Dictionary in session.content.locations[location_id].spots:
		if session.spot_open(spot):
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
		"series":
			for series_id: String in session.Series.here(session):
				var series: Dictionary = session.Series.definition(session, series_id)
				var reason: String = session.Series.block(session, series_id)
				var reward: Dictionary = series.get("reward", {})
				var about := "共 %d 场，接连打完，中间只喘口气；酬金 %d 灵石%s。败了或逃了便前功尽弃。" % [series.waves.size(), int(reward.get("stones", 0)), "，到%s，路上 %d 日" % [session.content.locations[series.to].name, int(series.days)] if series.has("to") else ""]
				var take: Button = _timed(ui, grid, "接下 · %s" % series.name, func() -> String: return session.take_series(series_id), reason if not reason.is_empty() else about)
				take.disabled = not reason.is_empty()
		"arena":
			var stage: Dictionary = session.Arena.stage(session)
			var current: Dictionary = session.Arena.run(session)
			var reason: String = session.Arena.block(session)
			var prizes: Array[String] = []
			for prize: Dictionary in stage.get("prizes", []):
				prizes.append("%d 连胜" % int(prize.streak))
			var about := "每胜一场得 %d × 连胜数的灵石；%s另有彩头。败了不伤和气，随时可下台。最高连胜 %d。" % [int(stage.purse), "、".join(prizes), session.Arena.best(session)]
			if current.is_empty():
				var enter: Button = _timed(ui, grid, "登台 · %s（彩头 %d 灵石）" % [stage.name, int(stage.fee)], session.arena_fight, reason if not reason.is_empty() else about)
				enter.disabled = not reason.is_empty()
			else:
				var next: Button = _timed(ui, grid, "迎战下一位 · 已连胜 %d" % int(current.streak), session.arena_fight, reason if not reason.is_empty() else about)
				next.disabled = not reason.is_empty()
				_timed(ui, grid, "见好就收，下台", session.arena_leave, "保住所得，结束这一轮")
		"hunt":
			var hunting: Dictionary = session.content.locations[session.player.location].hunt
			var beasts: Array[String] = []
			for entry: Dictionary in hunting.table:
				var beast: Dictionary = session.content.enemies[entry.enemy]
				if int(beast.min_realm) <= int(session.player.realm):
					beasts.append(str(beast.name))
			_action(ui, grid, "历练  ·  %s" % Calendar.duration_text(int(hunting.days)), "hunt", "在野外转上几日，撞上什么便斗什么。此地可能遇上：%s；妖兽身上取得材料与妖丹" % ("、".join(beasts) if not beasts.is_empty() else "（你还应付不来此地的妖兽）"))
		"lease":
			var lease: Dictionary = session.Leases.offer(session)
			var last: int = session.Leases.until(session, str(lease.flag))
			var title := ("续租%s" if last >= 0 else "赁下%s") % lease.name
			var term := "租期至 %s" % Calendar.short_text(last) if last >= 0 else "可在里头闭关、静养与突破"
			var reason: String = session.Leases.block(session)
			var take: Button = _timed(ui, grid, "%s  ·  %d 日 · %d 灵石" % [title, int(lease.days), int(lease.price)], session.take_lease, reason if not reason.is_empty() else term)
			take.disabled = not reason.is_empty()
		"inquire":
			var cost: Dictionary = session.content.rules.inquire
			_timed(ui, grid, "打听消息  ·  %s · %d 灵石" % [Calendar.duration_text(int(cost.days)), int(cost.price)], session.inquire, "请人喝壶茶，听听最近的消息：人物去向、宝物、委托与世事。")
		"commissions":
			var board: String = session.board_here()
			for offer: Dictionary in session.commission_offers(board):
				var shown: Dictionary = session.commission_text(offer)
				var key: String = offer.key
				var merit := int(offer.reward.get("contribution", 0))
				var standing := int(offer.reward.get("standing", 0))
				_timed(ui, grid, "接下：%s（灵石 %d%s%s%s）" % [shown.title, int(offer.reward.stones), "、修为 %d" % int(offer.reward.xp) if int(offer.reward.xp) > 0 else "", "、贡献 %d" % merit if merit > 0 else "", "、声望 %d" % standing if standing > 0 else ""], func() -> String: return session.accept_commission(key), shown.text)
			for quest: Dictionary in session.player.quests:
				if not session.Commissions.readable(session, str(quest.board)):
					continue
				var reason: String = session.delivery_block(quest)
				var handed: String = quest.key
				var deliver: Button = ui.button("交付：%s" % session.commission_text(quest).title, func() -> void: ui.run(func() -> String: return session.deliver_commission(handed)), reason)
				deliver.disabled = not reason.is_empty()
				deliver.size_flags_horizontal = Control.SIZE_EXPAND_FILL
				grid.add_child(deliver)
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
		"guest":
			var sect: String = session.Guest.sect_here(session)
			if sect.is_empty():
				return
			var terms: Dictionary = session.Guest.terms(session, sect)
			var sect_name: String = session.Sect.name_of(session, sect)
			if session.Guest.is_guest(session, sect):
				var guest: Dictionary = session.Guest.bond(session, sect)
				_timed(ui, grid, "辞去%s客卿" % sect_name, session.guest_leave, "月俸 %d 灵石；%s。差遣误了 %d 次（%d 次即解约）。辞去后邀约仍在，日后可再应。" % [session.Guest.stipend(session), terms.perk_text, int(guest.get("missed", 0)), int(session.Guest.data(session).missed_most)])
			else:
				var reason: String = session.Guest.block(session, sect)
				var about := "客卿：月俸 %d 灵石，本宗客舍可闭关突破，%s；每 %d 年一次差遣，一年内回客舍复命。" % [session.Guest.stipend(session), terms.perk_text, int(session.Guest.data(session).call_years)]
				var take: Button = _timed(ui, grid, "应邀做%s客卿" % sect_name, session.guest_accept, reason if not reason.is_empty() else about)
				take.disabled = not reason.is_empty()
		"league":
			var league: Dictionary = session.League.data(session)
			var branch: String = session.League.branch_name(session, str(session.player.location))
			if session.League.member(session):
				var about := "%s · 声望 %d%s。分舵静室按月付钱（副盟主免租），青灯簿的差事记声望；金丹以上、声望够了可租灵地。退盟不算背弃，日后可再入。" % [branch, session.League.standing(session), "（副盟主）" if session.League.deputy(session) else ""]
				_timed(ui, grid, "退出%s" % league.name, session.league_leave, about)
			else:
				var reason: String = session.League.block(session)
				var about := "%s是散修自己结的盟，不算拜入：随时可入可退。入盟后可在各城分舵静室闭关、接青灯簿的差事；在野外落败，盟中人会把你抬回%s，不收药钱。拜入宗门即自动退盟。" % [league.name, branch]
				var take: Button = _timed(ui, grid, "加入%s" % league.name, session.league_join, reason if not reason.is_empty() else about)
				take.disabled = not reason.is_empty()
		"tianji":
			var scroll_id: String = session.Tianji.own_scroll(session)
			var seat: int = 0 if scroll_id.is_empty() else session.Tianji.rank(session, scroll_id)
			var about := "天机阁的天骄榜：筑基卷、金丹卷各三十名，十年一大修。同境的修士可递战帖挑战排在前头的人，点到为止，胜了便坐他的位子。"
			if seat > 0:
				about += "
你在%s第 %d。" % [session.Tianji.scroll(session, scroll_id).name, seat]
			_open(ui, grid, "观天骄榜", func() -> void: ui.set_view("tianji"), about)
		"guishi":
			var reason: String = session.Guishi.block(session)
			var night: Button = ui.button("入鬼市", func() -> void: ui.set_view("guishi"), reason if not reason.is_empty() else "每月十五子时开灯，天亮就散。赌宝、销赃、接单、雇凶，季末还有黑拍。")
			night.size_flags_horizontal = Control.SIZE_EXPAND_FILL
			night.disabled = not reason.is_empty()
			grid.add_child(night)
		"join_sect":
			var sect: String = session.Sect.here(session)
			var reason: String = session.join_block()
			var table: Dictionary = session.Sect.info(session, sect)
			var about := "%s（%s）：静室修行、%s的差事与月俸%s；也要守宗门的规矩" % [table.name, session.Sect.tier_name(session, sect), table.office, "、本门传承" if session.content.sects.has(sect) else ""]
			# Leaving a sect for this one: a move up, or a betrayal the old sect remembers.
			if session.Sect.member(session) and reason.is_empty():
				var old: String = session.Sect.name_of(session, session.Sect.own_id(session))
				about += "\n" + ("叛出：%s不比%s高，改投便是背弃师门，%s从此视你为叛徒、再不收你。" % [table.name, old, old] if session.Sect.betrays(session, sect) else "改投：%s的档次在%s之上，%s会放你走，身份与贡献在新宗门从头算起。" % [table.name, old, old])
			var join: Button = _timed(ui, grid, ("改投" if session.Sect.member(session) else "拜入") + str(table.name), session.join_sect, reason if not reason.is_empty() else about)
			join.disabled = not reason.is_empty()
		"teach":
			for technique_id: String in session.teachings():
				var taught: Dictionary = session.content.technique(technique_id)
				var reason: String = session.slip_block(technique_id)
				var learned_id := technique_id
				var about := "%s\n领回静室，在闭关卷轴的「领悟」页参悟（约 %d 日）。" % [taught.description, session.study_days(taught)]
				var study: Button = ui.button("领取《%s》玉简" % taught.name, func() -> void: ui.run(func() -> String: return session.take_slip(learned_id)), "%s\n%s" % [session.Arsenal.technique_tag(session.content, taught), reason if not reason.is_empty() else about])
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
	if home.is_empty():
		return
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
		row.add_child(ui.label("回本山静室，在闭关卷轴的「领悟」页研习（%d 日）" % int(session.content.rules.lineage.study_days), 15, ui.INK))
	parent.add_child(ui.paragraph(str(sect.description)))
