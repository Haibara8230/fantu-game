extends RefCounted
## The title screen over the interface: a new journey chosen page by page after 觅长生 (opening.gd) —
## difficulty, spirit roots, then one entry on each page of talents — with the name and an overview at
## the end; or continuing a saved one.
const Talents = preload("res://scripts/core/talents.gd")
const TalentCards = preload("res://scripts/ui/talent_cards.gd")
const Opening = preload("res://scripts/core/opening.gd")
## The kinds of effect a talent page can be filtered by, each by the modifiers that make it.
const EFFECTS := {
	"修炼": ["cultivation", "retreat_days", "fresh_days", "breakthrough", "grade", "mind_need"],
	"斗法": ["attack", "defense", "damage_all", "damage_metal", "damage_wood", "damage_water", "damage_fire", "damage_earth", "max_hp", "max_qi", "orb_draw", "orb_cap", "orb_first", "orb_metal", "orb_wood", "orb_water", "orb_fire", "orb_earth"],
	"悟性心境": ["insight", "study", "mind_gain", "demon", "sense"],
	"寿元养伤": ["lifespan", "rest"],
	"机缘行路": ["boon", "encounter", "travel", "favor"],
	"丹药采集": ["pill", "pill_cooldown", "alchemy", "gather"],
	"钱财": ["stones", "sell", "buy"],
}

static func build(ui) -> void:
	var session = ui.session
	var welcome_layer := ColorRect.new()
	ui.welcome_layer = welcome_layer
	welcome_layer.z_index = 20
	ui.status_label.visible = false
	welcome_layer.color = Color(0.025, 0.045, 0.055, 0.97)
	welcome_layer.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	ui.add_child(welcome_layer)
	# The skip box lives on the overview page; none until it is drawn.
	ui.skip_intro = null
	var scroll := ScrollContainer.new()
	scroll.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	scroll.offset_top = 32
	scroll.offset_bottom = -32
	scroll.horizontal_scroll_mode = ScrollContainer.SCROLL_MODE_DISABLED
	welcome_layer.add_child(scroll)
	var centered := CenterContainer.new()
	centered.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	centered.size_flags_vertical = Control.SIZE_EXPAND_FILL
	scroll.add_child(centered)
	var panel: PanelContainer = ui.panel()
	panel.custom_minimum_size.x = 900
	centered.add_child(panel)
	var box := VBoxContainer.new()
	box.add_theme_constant_override("separation", 14)
	panel.add_child(box)
	box.add_child(ui.label("凡 途", 48, ui.GOLD))
	box.add_child(ui.label("一介凡身，问道长生。", 22))
	var name_input := LineEdit.new()
	ui.name_input = name_input
	name_input.placeholder_text = "道号（最多 16 字）"
	name_input.max_length = 16
	name_input.custom_minimum_size.y = 46
	# Enter begins only from a complete choice; otherwise it shows the overview and what is missing.
	name_input.text_submitted.connect(func(_value: String) -> void:
		if Opening.block(session.content, ui.welcome_choice).is_empty():
			ui.begin()
		else:
			goto(ui, pages(session.content).size() - 1))
	box.add_child(name_input)
	# The choice survives the screen being built again (back from settings); a new one starts fresh.
	if ui.welcome_choice.is_empty():
		ui.welcome_choice = Opening.fresh(session.content)
		ui.welcome_page = 0
	var body := VBoxContainer.new()
	body.add_theme_constant_override("separation", 12)
	ui.welcome_body = body
	box.add_child(body)
	_render(ui)
	var continue_button: Button = ui.button("继续旅程", ui.continue_saved)
	continue_button.disabled = not (ui.auto_store.has_save() or ui.manual_store.has_save())
	box.add_child(continue_button)
	if ui.started:
		box.add_child(ui.button("返回当前旅程", ui.close_welcome))
	box.add_child(ui.paragraph("开发版 · Windows 单机 · 本地存档\n二维手绘角色 · 施法演出 · 命中与受击反馈"))
	name_input.grab_focus()

## The pages in order: difficulty, roots, the talent pages, the overview.
static func pages(content) -> Array[Dictionary]:
	var found: Array[Dictionary] = [{"id": "difficulty", "name": "难度"}, {"id": "roots", "name": "灵根"}]
	for entry: Dictionary in Opening.data(content).pages:
		found.append({"id": str(entry.id), "name": str(entry.name)})
	found.append({"id": "summary", "name": "总览"})
	return found

## The roots and talents the journey will start with, kept on the interface for begin().
static func _sync(ui) -> void:
	var content = ui.session.content
	ui.welcome_roots = ui.welcome_choice.get("roots", []).duplicate()
	ui.welcome_born = Opening.born(content, ui.welcome_choice)

static func goto(ui, index: int) -> void:
	ui.welcome_page = clampi(index, 0, pages(ui.session.content).size() - 1)
	_render(ui)

static func _render(ui) -> void:
	var content = ui.session.content
	_sync(ui)
	var body: VBoxContainer = ui.welcome_body
	ui.clear(body)
	var steps := HFlowContainer.new()
	steps.add_theme_constant_override("h_separation", 6)
	steps.add_theme_constant_override("v_separation", 6)
	body.add_child(steps)
	var all := pages(content)
	for index: int in all.size():
		var at := index
		var step: Button = ui.button(str(all[index].name), func() -> void: goto(ui, at))
		step.toggle_mode = true
		step.button_pressed = index == int(ui.welcome_page)
		step.custom_minimum_size.y = 36
		steps.add_child(step)
	var left: int = Opening.left(content, ui.welcome_choice)
	body.add_child(ui.label("天赋点 · 剩余 %d / %d" % [left, Opening.points(content, ui.welcome_choice)], 18, ui.GOLD if left >= 0 else Color("#e0574e")))
	var page: Dictionary = all[int(ui.welcome_page)]
	match str(page.id):
		"difficulty":
			_difficulty(ui, body)
		"roots":
			_roots(ui, body)
		"summary":
			_summary(ui, body)
		_:
			_talents(ui, body, str(page.id))
	var nav := HBoxContainer.new()
	nav.add_theme_constant_override("separation", 12)
	body.add_child(nav)
	if int(ui.welcome_page) > 0:
		nav.add_child(ui.button("上一页", func() -> void: goto(ui, int(ui.welcome_page) - 1)))
	if int(ui.welcome_page) < all.size() - 1:
		nav.add_child(ui.button("下一页", func() -> void: goto(ui, int(ui.welcome_page) + 1)))

static func _difficulty(ui, body: VBoxContainer) -> void:
	var content = ui.session.content
	body.add_child(ui.paragraph("难度只决定开局的天赋点，不改别的规则。"))
	for entry: Dictionary in Opening.data(content).difficulties:
		var id := str(entry.id)
		var choice: Button = ui.button("%s · %d 点　%s" % [entry.name, int(entry.points), entry.get("text", "")], func() -> void:
			ui.welcome_choice.difficulty = id
			_render(ui))
		choice.toggle_mode = true
		choice.button_pressed = str(ui.welcome_choice.get("difficulty", "")) == id
		choice.alignment = HORIZONTAL_ALIGNMENT_LEFT
		body.add_child(choice)

static func _roots(ui, body: VBoxContainer) -> void:
	var content = ui.session.content
	var spec: Dictionary = content.rules.spirit_roots
	body.add_child(ui.paragraph("先选品类，再点选对应个数的五行。灵根越少修炼越快，花的点数也越多；四灵根、伪灵根反倒返还点数。"))
	var kinds := HFlowContainer.new()
	kinds.add_theme_constant_override("h_separation", 8)
	body.add_child(kinds)
	for grade: Dictionary in spec.grades:
		var count := int(grade.count)
		var price: int = Opening.root_cost(content, count)
		var kind: Button = ui.button("%s（%s · 修炼 ×%.2f）" % [grade.name, _price_text(price), float(grade.speed)], func() -> void:
			Opening.set_root_count(content, ui.welcome_choice, count)
			_render(ui))
		kind.toggle_mode = true
		kind.button_pressed = int(ui.welcome_choice.root_count) == count
		kinds.add_child(kind)
	var elements := HBoxContainer.new()
	elements.add_theme_constant_override("separation", 8)
	body.add_child(elements)
	var roots: Array = ui.welcome_choice.get("roots", [])
	for element: String in spec.elements:
		var picked := element
		var toggle: Button = ui.button(str(spec.names[element]), func() -> void:
			Opening.toggle_root(content, ui.welcome_choice, picked)
			_render(ui))
		toggle.toggle_mode = true
		toggle.button_pressed = element in roots
		toggle.disabled = int(ui.welcome_choice.root_count) >= 5
		toggle.custom_minimum_size.x = 64
		elements.add_child(toggle)
	var count := int(ui.welcome_choice.root_count)
	if roots.size() == count:
		body.add_child(ui.label("灵根 · %s" % content.root_title(roots), 18, ui.GOLD))
	else:
		body.add_child(ui.label("还要选 %d 行。" % (count - roots.size()), 16, ui.MUTED))

static func _talents(ui, body: VBoxContainer, page_id: String) -> void:
	var content = ui.session.content
	var page: Dictionary = Opening.page(content, page_id)
	var roots: Array = ui.welcome_choice.get("roots", [])
	var picked := str(ui.welcome_choice.picks.get(page_id, ""))
	body.add_child(ui.paragraph("此页只选一样，或什么都不选。鼠标停留可看效果；缺陷返还点数，与灵根相关的只在有那一行灵根时出现。"))
	var all: Array[String] = Opening.offered(content, page_id, roots)
	var shown: Array = all.filter(func(id: String) -> bool: return id == picked or _passes(ui, page_id, id))
	_filters(ui, body, all.size(), shown.size())
	var flow := HFlowContainer.new()
	flow.add_theme_constant_override("h_separation", 8)
	flow.add_theme_constant_override("v_separation", 8)
	body.add_child(flow)
	var plain: Button = ui.button("%s（0）" % page.plain, func() -> void:
		ui.welcome_choice.picks.erase(page_id)
		_render(ui))
	plain.toggle_mode = true
	plain.button_pressed = picked.is_empty()
	flow.add_child(plain)
	for id: String in shown:
		var entry := id
		var price: int = Opening.cost(content, id)
		var reason: String = "" if id == picked else Opening.pick_block(content, ui.welcome_choice, page_id, id)
		var tip: String = TalentCards.tooltip(content, id) + ("\n" + reason if not reason.is_empty() else "")
		var option: Button = ui.button("%s（%s）" % [Talents.definition(content, id).get("name", id), _price_text(price)], func() -> void:
			ui.welcome_choice.picks[page_id] = entry
			_render(ui), tip)
		option.toggle_mode = true
		option.button_pressed = id == picked
		option.disabled = not reason.is_empty()
		option.add_theme_color_override("font_color", Color(str(Talents.tier_of(content, id).get("color", "#d6d0c2"))))
		flow.add_child(option)

## The filter row: by grade (缺陷 among them), by kind of effect, only what the points still allow.
static func _filters(ui, body: VBoxContainer, total: int, shown: int) -> void:
	var content = ui.session.content
	var filter: Dictionary = ui.welcome_filter
	var tiers := HFlowContainer.new()
	tiers.add_theme_constant_override("h_separation", 6)
	tiers.add_theme_constant_override("v_separation", 6)
	body.add_child(tiers)
	var grades: Array = [["", "全部品级", ui.INK]]
	for tier: Dictionary in content.talent_data.tiers:
		grades.append([str(tier.id), str(tier.name), Color(str(tier.color))])
	grades.append(["flaw", "缺陷", Color(str(content.talent_data.flaw.color))])
	for grade: Array in grades:
		var value := str(grade[0])
		var chip: Button = ui.button(str(grade[1]), func() -> void:
			ui.welcome_filter.tier = value
			_render(ui))
		chip.toggle_mode = true
		chip.button_pressed = str(filter.get("tier", "")) == value
		chip.custom_minimum_size.y = 34
		chip.add_theme_color_override("font_color", grade[2])
		tiers.add_child(chip)
	var effects := HFlowContainer.new()
	effects.add_theme_constant_override("h_separation", 6)
	effects.add_theme_constant_override("v_separation", 6)
	body.add_child(effects)
	for kind: String in [""] + EFFECTS.keys():
		var value := kind
		var chip: Button = ui.button("全部效果" if kind.is_empty() else kind, func() -> void:
			ui.welcome_filter.effect = value
			_render(ui))
		chip.toggle_mode = true
		chip.button_pressed = str(filter.get("effect", "")) == value
		chip.custom_minimum_size.y = 34
		effects.add_child(chip)
	var row := HBoxContainer.new()
	row.add_theme_constant_override("separation", 16)
	body.add_child(row)
	var affordable := CheckBox.new()
	affordable.text = "只看点数够的"
	affordable.button_pressed = bool(filter.get("affordable", false))
	affordable.toggled.connect(func(on: bool) -> void:
		ui.welcome_filter.affordable = on
		_render(ui))
	row.add_child(affordable)
	row.add_child(ui.label("显示 %d / %d 项" % [shown, total], 15, ui.MUTED))

## Whether an entry passes the filter (the one taken is always shown).
static func _passes(ui, page_id: String, id: String) -> bool:
	var content = ui.session.content
	var filter: Dictionary = ui.welcome_filter
	var tier := str(filter.get("tier", ""))
	if not tier.is_empty():
		var flaw: bool = Talents.is_flaw(content, id)
		if (tier == "flaw") != flaw or (not flaw and str(Talents.definition(content, id).get("tier", "")) != tier):
			return false
	var kind := str(filter.get("effect", ""))
	if not kind.is_empty():
		var mods: Dictionary = Talents.definition(content, id).get("mods", {})
		if not EFFECTS.get(kind, []).any(func(key: String) -> bool: return int(mods.get(key, 0)) != 0):
			return false
	if bool(filter.get("affordable", false)) and Opening.pick_block(content, ui.welcome_choice, page_id, id).contains("不够"):
		return false
	return true

static func _summary(ui, body: VBoxContainer) -> void:
	var content = ui.session.content
	var choice: Dictionary = ui.welcome_choice
	var roots: Array = choice.get("roots", [])
	body.add_child(ui.label("%s · 灵根 %s" % [Opening.difficulty(content, str(choice.get("difficulty", ""))).get("name", ""), content.root_title(roots) if roots.size() == int(choice.root_count) else "未选全"], 18, ui.GOLD))
	var born: Dictionary = ui.welcome_born
	body.add_child(TalentCards.row(ui, content, born))
	if roots.size() == int(choice.root_count):
		var score := Talents.score(content, Talents.root_score(content, roots), born.talents + born.flaws)
		body.add_child(TalentCards.aptitude_label(ui, Talents.aptitude(content, score)))
	# The 入世 opening is played the first time; once finished, a new journey may skip it.
	ui.skip_intro = null
	if ui.intro_finished_once:
		var skip := CheckBox.new()
		skip.text = "跳过入世经历（直接以散修身份自由行动）"
		body.add_child(skip)
		ui.skip_intro = skip
	var reason: String = Opening.block(content, choice)
	var begin_button: Button = ui.button("踏入仙途", ui.begin, reason)
	begin_button.disabled = not reason.is_empty()
	body.add_child(begin_button)
	if not reason.is_empty():
		body.add_child(ui.label(reason, 16, Color("#e0574e")))

static func _price_text(price: int) -> String:
	return "返还 %d" % -price if price < 0 else str(price)
