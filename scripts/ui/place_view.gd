extends RefCounted
## The place the player is at: its scenes as tabs, each with a banner and its actions, the people here
## and, at the sect's hall, the lineage choice.
const Calendar = preload("res://scripts/core/calendar.gd")
const Landscape = preload("res://scripts/ui/landscape.gd")
const PeopleView = preload("res://scripts/ui/people_view.gd")

static func render(ui) -> void:
	var session = ui.session
	var center: VBoxContainer = ui.center
	if ui.preview_mode:
		sect_choices(ui, center, true)
	var location_id: String = session.player.location
	var location: Dictionary = session.content.locations[location_id]
	var title_row := HBoxContainer.new()
	title_row.add_theme_constant_override("separation", 20)
	center.add_child(title_row)
	title_row.add_child(ui.label(location.name, 30, ui.GOLD))
	title_row.add_child(ui.label(location.subtitle, 16, ui.MUTED))
	center.add_child(ui.paragraph(location.description))
	center.add_child(ui.paragraph(_objective(session), ui.GOLD))
	PeopleView.render_here(ui)
	if not ui.selected_npc.is_empty():
		PeopleView.render_person(ui, ui.selected_npc)
		return
	# Second-level scenes: each spot has its own banner, text and actions; moving between them is free.
	var spots := _open_spots(session, location_id)
	if not spots.any(func(spot: Dictionary) -> bool: return spot.id == ui.selected_spot):
		ui.selected_spot = spots[0].id
	var tabs := HBoxContainer.new()
	tabs.add_theme_constant_override("separation", 8)
	center.add_child(tabs)
	var spot: Dictionary = {}
	for candidate: Dictionary in spots:
		var spot_id: String = candidate.id
		var tab: Button = ui.button(candidate.name, func() -> void: ui.select_spot(spot_id))
		tab.disabled = spot_id == ui.selected_spot
		tabs.add_child(tab)
		if spot_id == ui.selected_spot:
			spot = candidate
	var landscape = Landscape.new()
	landscape.location_id = location_id
	landscape.terrain = location.terrain
	landscape.spot_id = spot.id
	landscape.custom_minimum_size.y = 190
	center.add_child(landscape)
	center.add_child(ui.paragraph(spot.description, ui.INK))
	var grid := GridContainer.new()
	grid.columns = 2
	grid.add_theme_constant_override("h_separation", 12)
	grid.add_theme_constant_override("v_separation", 10)
	center.add_child(grid)
	for action: String in spot.actions:
		_spot_action(ui, grid, action)
	for days: Variant in session.content.rules.wait_options:
		var span := int(days)
		_timed(ui, grid, "停留  ·  " + Calendar.duration_text(span), func() -> String: return session.wait(span), "原地停留，等候时机；约定临近时会提醒")
	if "study" in spot.actions and not ui.preview_mode:
		sect_choices(ui, center, false)
	var names: Array[String] = []
	for id: String in session.active_skills():
		names.append(session.content.skills[id].name)
	center.add_child(ui.paragraph("已习神通 · " + " / ".join(names) + "。悬停神通按钮可查看效果。"))

static func _objective(session) -> String:
	if session.has_flag("serpent_slain"):
		return "落霞谷灵泉已复。世事仍在流转，你可以继续修炼与游历。"
	var need: Dictionary = session.next_breakthrough()
	if need.is_empty():
		return "当前目标 · 休整后前往落霞谷，平定赤鳞妖蟒。"
	return "当前目标 · 修至%s，积攒 %d 修为与 %d 枚筑基丹，在青云山突破。" % [session.content.realm_title(int(session.player.realm), session.content.realm(int(session.player.realm)).stages.size() - 1), int(need.xp), int(need.pills)]

static func _breakthrough_tooltip(session) -> String:
	var need: Dictionary = session.next_breakthrough()
	if need.is_empty():
		return "后续境界尚未开放"
	return "需修至%s，并有 %d 修为与 %d 枚筑基丹" % [session.content.realm_title(int(session.player.realm), session.content.realm(int(session.player.realm)).stages.size() - 1), int(need.xp), int(need.pills)]

static func _open_spots(session, location_id: String) -> Array[Dictionary]:
	var result: Array[Dictionary] = []
	for spot: Dictionary in session.content.locations[location_id].spots:
		if not spot.has("requires_flag") or session.has_flag(spot.requires_flag):
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
			for days: Variant in rules.cultivate_options:
				var span := int(days)
				var gain: int = span * session.cultivation_rate() / Calendar.DAYS_PER_MONTH
				_timed(ui, grid, "闭关  ·  " + Calendar.duration_text(span), func() -> String: return session.cultivate(span), "修为约 +%d，恢复全部灵力；约定或寿元告急时会提前出关" % gain)
		"rest":
			_action(ui, grid, "静室休整  ·  " + Calendar.duration_text(session.rest_days()), "rest", "恢复全部气血与灵力；伤得越重，需要的日子越长")
		"breakthrough":
			_action(ui, grid, "突破境界  ·  " + ui.duration("breakthrough"), "breakthrough", _breakthrough_tooltip(session))
		"sell":
			_action(ui, grid, "全部出售", "sell", "把这里收购的东西全部卖掉，不耗时日")
			for item_id: String in session.player.items.keys():
				var price: int = session.sell_price(item_id)
				if price > 0:
					var sold := item_id
					_timed(ui, grid, "出售%s（%d）· 每件 %d" % [session.content.item(item_id).name, session.item_count(item_id), price], func() -> String: return session.sell(sold, 1), session.content.item(item_id).description)
		"shop":
			for good: Dictionary in session.shop_goods():
				var bought: String = good.item
				_timed(ui, grid, "购买%s  ·  %d 灵石" % [session.content.item(bought).name, int(good.price)], func() -> String: return session.buy(bought), session.content.item(bought).description)
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
		"study":
			pass
		"inquire":
			var cost: Dictionary = session.content.rules.inquire
			_timed(ui, grid, "打听消息  ·  %s · %d 灵石" % [Calendar.duration_text(int(cost.days)), int(cost.price)], session.inquire, "请人喝壶茶，听听最近的消息：人物去向、宝物、委托与世事。")
		"commissions":
			var board: String = session.board_here()
			for offer: Dictionary in session.commission_offers(board):
				var shown: Dictionary = session.commission_text(offer)
				var key: String = offer.key
				_timed(ui, grid, "接下：%s（灵石 %d%s）" % [shown.title, int(offer.reward.stones), "、修为 %d" % int(offer.reward.xp) if int(offer.reward.xp) > 0 else ""], func() -> String: return session.accept_commission(key), shown.text)
			for quest: Dictionary in session.player.quests:
				if quest.board != board:
					continue
				var reason: String = session.delivery_block(quest)
				var handed: String = quest.key
				var deliver: Button = ui.button("交付：%s" % session.commission_text(quest).title, func() -> void: ui.run(func() -> String: return session.deliver_commission(handed)), reason)
				deliver.disabled = not reason.is_empty()
				deliver.size_flags_horizontal = Control.SIZE_EXPAND_FILL
				grid.add_child(deliver)
		"teach":
			for technique_id: String in session.teachings():
				var taught: Dictionary = session.content.technique(technique_id)
				var reason: String = session.learn_block(technique_id)
				var learned_id := technique_id
				var study: Button = ui.button("参悟%s  ·  %s · %d 日" % [taught.name, taught.tier_name, int(taught.study_days)], func() -> void: ui.run(func() -> String: return session.learn_here(learned_id)), reason if not reason.is_empty() else taught.description)
				study.disabled = not reason.is_empty()
				study.size_flags_horizontal = Control.SIZE_EXPAND_FILL
				grid.add_child(study)

## A button that runs a session action and shows its text.
static func _timed(ui, parent: GridContainer, title: String, callback: Callable, tooltip: String) -> void:
	var entry: Button = ui.button(title, func() -> void: ui.run(callback), tooltip)
	entry.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	parent.add_child(entry)

static func _action(ui, parent: GridContainer, title: String, action: String, tooltip: String) -> void:
	var entry: Button = ui.button(title, func() -> void: ui.run(func() -> String: return ui.session.act(action)), tooltip)
	entry.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	parent.add_child(entry)

static func _enemy_action(ui, parent: GridContainer, title: String, enemy_id: String, tooltip: String) -> Button:
	var entry: Button = ui.button(title, func() -> void: ui.run(func() -> String: return ui.session.start_battle(enemy_id)), tooltip)
	entry.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	parent.add_child(entry)
	return entry

## The lineage choice: at the sect's hall it studies a lineage; in the sect preview it picks both
## sides and resets the duel.
static func sect_choices(ui, parent: VBoxContainer, is_preview: bool) -> void:
	var session = ui.session
	var row := HBoxContainer.new()
	row.add_theme_constant_override("separation", 10)
	parent.add_child(row)
	row.add_child(ui.label("我方传承" if is_preview else "研习传承", 15, ui.GOLD))
	var ids: Array[String] = ["wanderer", "qingyun", "chixiao", "changqing", "canglan", "xuanyue"]
	var select := OptionButton.new()
	select.custom_minimum_size = Vector2(145, 34)
	for id: String in ids:
		select.add_item(session.content.sects[id].name)
	select.select(ids.find(str(session.player.get("sect", "wanderer"))))
	select.item_selected.connect(func(index: int) -> void:
		if is_preview:
			ui.reset_preview(ids[index], ui.preview_opponent)
		else:
			ui.run(func() -> String: return session.choose_sect(ids[index]))
	)
	row.add_child(select)
	if is_preview:
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
	else:
		parent.add_child(ui.paragraph(session.content.sects[session.player.get("sect", "wanderer")].description))
