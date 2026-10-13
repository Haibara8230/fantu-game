extends RefCounted
## 炼丹 and the 灵田, each a scroll of its own over the place. The alchemy page sets out one brew: the
## recipe, its main herbs, the 药引 that balances them, the fire and a 控火符, with the odds before the
## furnace is lit. The field page shows the plots of the 洞府's field, what grows there and when it
## ripens, and what improving the field asks.
const Calendar = preload("res://scripts/core/calendar.gd")
const WARN := Color("#e3c08a")

static func render(ui) -> void:
	var session = ui.session
	var center: VBoxContainer = ui.center
	var known: Array[String] = session.known_recipes()
	var heading := HBoxContainer.new()
	heading.add_theme_constant_override("separation", 16)
	center.add_child(heading)
	heading.add_child(ui.label("炼 丹", 26, ui.GOLD))
	if known.is_empty():
		center.add_child(ui.paragraph("你还不会任何丹方。云溪坊市的丹铺卖疗伤丹、回气丹的方子；凝气丹、破障丹与筑基丹的方子，可到青云山执事堂以贡献兑换。买来的丹方在行囊里研读后便可开炉。"))
		return
	if not str(ui.alchemy_plan.get("recipe", "")) in known:
		ui.alchemy_plan = session.alchemy_plan(known[0])
	var plan: Dictionary = ui.alchemy_plan
	var chances: Dictionary = session.alchemy_odds(plan)
	heading.add_child(ui.label("丹炉 · %s" % chances.furnace.name, 17, ui.INK))
	var toxin: int = session.toxin()
	if toxin > 0:
		heading.add_child(ui.label("丹毒 %d" % toxin, 15, ui.MUTED))
	var recipes := HBoxContainer.new()
	recipes.add_theme_constant_override("separation", 8)
	center.add_child(recipes)
	for recipe_id: String in known:
		var chosen := recipe_id
		var pill: Dictionary = session.content.item(str(session.content.alchemy_data.recipes[recipe_id].pill))
		var tab: Button = ui.button(pill.name, func() -> void: ui.choose_recipe(chosen), str(pill.description))
		ui.tint(tab, ui.grade_color(pill))
		tab.disabled = recipe_id == str(plan.recipe)
		tab.custom_minimum_size = Vector2(96, 36)
		recipes.add_child(tab)
	center.add_child(HSeparator.new())
	_herbs(ui, center, plan)
	_guide(ui, center, plan)
	_fire(ui, center, plan)
	center.add_child(HSeparator.new())
	var outlook := "成丹把握 %d%%　·　上品 %d%%　·　成丹 %s 枚　·　耗时 %s" % [int(chances.success), int(chances.fine), _span(chances.yield), Calendar.duration_text(int(chances.days))]
	if int(chances.fee) > 0:
		outlook += "　·　借炉 %d 灵石" % int(chances.fee)
	center.add_child(ui.label(outlook, 18, ui.GOLD))
	var parts: Array[String] = []
	for part: Array in chances.parts:
		parts.append("%s %s" % [part[0], ("%+d" % int(part[1])) if parts.size() > 0 else str(int(part[1]))])
	center.add_child(ui.paragraph("　".join(parts), ui.MUTED))
	if bool(chances.burst):
		center.add_child(ui.paragraph("武火失手会炸炉：药材尽毁，自身也要受些灼伤。", WARN))
	var reason: String = session.alchemy_block(plan)
	var light: Button = ui.button("开炉 · %s" % Calendar.duration_text(int(chances.days)), func() -> void: ui.brew_now(), reason if not reason.is_empty() else "药材入炉，开始炼制")
	light.disabled = not reason.is_empty()
	light.custom_minimum_size = Vector2(180, 44)
	center.add_child(light)

static func _span(pair: Array) -> String:
	return str(int(pair[0])) if int(pair[0]) == int(pair[1]) else "%d–%d" % [int(pair[0]), int(pair[1])]

## The main herbs the recipe takes, and how many are carried.
static func _herbs(ui, center: VBoxContainer, plan: Dictionary) -> void:
	var session = ui.session
	var natures: Dictionary = session.content.alchemy_data.natures
	var recipe: Dictionary = session.content.alchemy_data.recipes[str(plan.recipe)]
	var row := HBoxContainer.new()
	row.add_theme_constant_override("separation", 14)
	center.add_child(row)
	row.add_child(ui.label("主药", 17, ui.GOLD))
	for herb_id: String in recipe.main:
		var need := int(recipe.main[herb_id])
		var have: int = session.item_count(herb_id)
		var herb: Dictionary = session.content.item(herb_id)
		row.add_child(ui.label("%s（%s）×%d　行囊 %d" % [herb.name, natures[herb.nature], need, have], 16, ui.INK if have >= need else WARN))

## The 药引: what the main herbs ask for, and the herbs carried that could go in.
static func _guide(ui, center: VBoxContainer, plan: Dictionary) -> void:
	var session = ui.session
	var natures: Dictionary = session.content.alchemy_data.natures
	var recipe_id := str(plan.recipe)
	var wanted: String = session.Alchemy.guide_nature(session, recipe_id)
	var lean: String = session.Alchemy.lean(session, recipe_id)
	var words := "主药寒热相济，以一株平性灵草作引即可。" if lean == "neutral" else "主药偏%s，须以一株%s性灵草作引，调和寒热。" % [natures[lean], natures[wanted]]
	center.add_child(ui.paragraph(words + "寒热不调也能成丹，只是少成一枚，也出不了上品。"))
	var row := HBoxContainer.new()
	row.add_theme_constant_override("separation", 8)
	center.add_child(row)
	row.add_child(ui.label("药引", 17, ui.GOLD))
	for herb_id: String in session.Alchemy.guide_options(session, recipe_id):
		var herb: Dictionary = session.content.item(herb_id)
		var fits: bool = herb.nature == wanted
		var picked := herb_id
		var choice: Button = ui.button("%s（%s）%s" % [herb.name, natures[herb.nature], " ✓" if fits else ""], func() -> void: ui.set_alchemy("guide", picked), "寒热相合" if fits else "药性不合，寒热调不平")
		choice.disabled = str(plan.guide) == herb_id
		row.add_child(choice)
	var none: Button = ui.button("不用药引", func() -> void: ui.set_alchemy("guide", ""), "省下一株灵草，成丹少一枚")
	none.disabled = str(plan.guide).is_empty()
	row.add_child(none)

## The fire, and a 控火符 when one is carried.
static func _fire(ui, center: VBoxContainer, plan: Dictionary) -> void:
	var session = ui.session
	var row := HBoxContainer.new()
	row.add_theme_constant_override("separation", 8)
	center.add_child(row)
	row.add_child(ui.label("火候", 17, ui.GOLD))
	var fires: Dictionary = session.content.alchemy_data.fires
	for fire_id: String in fires:
		var picked := fire_id
		var choice: Button = ui.button(str(fires[fire_id].name), func() -> void: ui.set_alchemy("fire", picked), str(fires[fire_id].get("text", "")))
		choice.disabled = str(plan.fire) == fire_id
		row.add_child(choice)
	for aid_id: String in session.Alchemy.aids(session):
		var aid: Dictionary = session.content.item(aid_id)
		var using := str(plan.get("aid", "")) == aid_id
		var picked := "" if using else aid_id
		var toggle: Button = ui.button("%s%s（余 %d）" % ["已贴" if using else "贴一张", aid.name, session.item_count(aid_id)], func() -> void: ui.set_alchemy("aid", picked), str(aid.description))
		row.add_child(toggle)

## The 洞府's field: every plot, what to plant, what has ripened, and improving the field.
static func render_field(ui) -> void:
	var session = ui.session
	var center: VBoxContainer = ui.center
	var grade: Dictionary = session.Alchemy.field_grade(session)
	var heading := HBoxContainer.new()
	heading.add_theme_constant_override("separation", 16)
	center.add_child(heading)
	heading.add_child(ui.label("洞府灵田 · %s" % grade.name, 26, ui.GOLD))
	heading.add_child(ui.label("%d 块 · 生长 %d%% 时日 · 每株多收 %d" % [int(grade.plots), int(grade.growth), int(grade.bonus)], 15, ui.MUTED))
	center.add_child(ui.paragraph("一株灵草种下，长成后可收数株。灵田不靠运气：到了日子便能收，品级越高，长得越快、收得越多。"))
	var plots: Array = session.field_plots()
	for index: int in plots.size():
		_plot(ui, center, index, plots[index])
	center.add_child(HSeparator.new())
	var next: Dictionary = session.Alchemy.next_grade(session)
	if next.is_empty():
		center.add_child(ui.label("灵田已是最好的了。", 16, ui.MUTED))
		return
	var row := HBoxContainer.new()
	row.add_theme_constant_override("separation", 12)
	center.add_child(row)
	var stage: Array = next.stage
	row.add_child(ui.label("扩建为%s：%d 块，生长 %d%% 时日，每株多收 %d。需%s，%d 灵石、%d 贡献" % [next.name, int(next.plots), int(next.growth), int(next.bonus), session.content.realm_title(int(stage[0]), int(stage[1])), int(next.cost.stones), int(next.cost.contribution)], 15, ui.INK))
	var reason: String = session.Alchemy.upgrade_block(session)
	var go: Button = ui.button("扩建灵田", func() -> void: ui.run(session.upgrade_field), reason if not reason.is_empty() else "翻整灵田、引来灵泉")
	go.disabled = not reason.is_empty()
	row.add_child(go)

static func _plot(ui, center: VBoxContainer, index: int, plot: Dictionary) -> void:
	var session = ui.session
	var row := HBoxContainer.new()
	row.add_theme_constant_override("separation", 10)
	center.add_child(row)
	var name: Label = ui.label("第 %d 块" % (index + 1), 17, ui.GOLD)
	name.custom_minimum_size.x = 70
	row.add_child(name)
	var at := index
	if plot.is_empty():
		row.add_child(ui.label("空着", 16, ui.MUTED))
		var any := false
		for herb_id: String in session.Alchemy.plantable(session):
			if session.item_count(herb_id) < 1:
				continue
			any = true
			var herb: Dictionary = session.content.item(herb_id)
			var planted := herb_id
			var days: int = session.Alchemy.ripe_day(session, {"herb": herb_id, "day": int(session.world.day)}) - int(session.world.day)
			row.add_child(ui.button("种%s" % herb.name, func() -> void: ui.run(func() -> String: return session.plant(at, planted)), "用一株作种，%s后收 %d 株" % [Calendar.duration_text(days), session.Alchemy.harvest_count(session, {"herb": herb_id})]))
		if not any:
			row.add_child(ui.label("行囊里没有能种的灵草。", 15, ui.MUTED))
		return
	var herb: Dictionary = session.content.item(str(plot.herb))
	var left: int = session.Alchemy.ripe_day(session, plot) - int(session.world.day)
	if left > 0:
		row.add_child(ui.label("%s · 还需 %s" % [herb.name, Calendar.duration_text(left)], 16, ui.INK))
		return
	row.add_child(ui.label("%s · 已长成" % herb.name, 16, ui.GOLD))
	row.add_child(ui.button("收获 %d 株" % session.Alchemy.harvest_count(session, plot), func() -> void: ui.run(func() -> String: return session.harvest(at)), "收下这一茬"))
