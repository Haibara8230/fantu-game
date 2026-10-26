extends RefCounted
## The retreat scroll, opened where one can retreat (the chamber): 修炼 picks how long to stay in
## seclusion and previews what it brings; 突破 lays out the attempt — the pills, a treasure, a guard —
## and its odds part by part. The deadlines coming up are listed beside both, so a long retreat does not
## miss them. The rules are the session's; this only shows them and plays a retreat back.
const Calendar = preload("res://scripts/core/calendar.gd")
const Cultivation = preload("res://scripts/core/cultivation.gd")
const Goals = preload("res://scripts/ui/goals.gd")
const ArtLibrary = preload("res://scripts/ui/art_library.gd")
# Goals that are dates to keep in mind while in seclusion.
const DEADLINE_GOALS := ["serpent", "auction", "tournament", "sealed"]

static func render_retreat(ui) -> void:
	var session = ui.session
	var columns := _columns(ui)
	var right: VBoxContainer = columns.get_child(1)
	if not ui.retreat_playback.is_empty():
		_playback(ui, right)
		return
	if not ui.retreat_result.is_empty():
		right.add_child(ui.paragraph(ui.retreat_result, ui.INK))
	var efficiency: int = session.retreat_efficiency()
	var mind_percent: int = session.mind_percent()
	right.add_child(ui.paragraph(limitation(session), ui.GOLD))
	# The room the retreat is spent in: its rate and rent, and the days the stones pay for.
	var room: Dictionary = session.Cultivation.room(session)
	if int(room.get("rent", 0)) > 0:
		right.add_child(ui.paragraph("%s：修炼收益 ×%.1f，每月房钱 %d 灵石；手头灵石够住 %s。" % [room.name, float(room.rate), int(room.rent), Calendar.duration_text(mini(session.Cultivation.paid_days(session), 36000))], ui.INK))
	elif not room.is_empty() and not is_equal_approx(float(room.rate), 1.0):
		right.add_child(ui.paragraph("%s：修炼收益 ×%.1f，不收房钱。" % [room.name, float(room.rate)], ui.INK))
	right.add_child(ui.label("每月修为  %d" % int(round(session.cultivation_rate() * mind_percent / 100.0 * efficiency / 100.0)), 26, ui.GOLD))
	var grade: Dictionary = session.content.root_grade(session.player.get("roots", []))
	var sources := GridContainer.new()
	sources.columns = 2
	sources.add_theme_constant_override("h_separation", 24)
	right.add_child(sources)
	sources.add_child(ui.label("灵根 · %s  ×%.2f" % [session.root_title(), float(grade.speed)], 15))
	sources.add_child(ui.label("心法与宝物  +%d%%" % int(round(float(session.bonuses().cultivation) * 100.0)), 15))
	sources.add_child(ui.label("心神 · %s  收益 %d%%" % [_mood(efficiency), efficiency], 15, ui.INK if efficiency >= 100 else Color("#e3c08a")))
	sources.add_child(ui.label("当前修为  %d / %d（此境上限）" % [int(session.player.xp), Cultivation.xp_cap(session)], 15))
	sources.add_child(ui.label(("心境  %d · 此阶段无心境门槛" % int(session.player.mind) if session.mind_needed() == 0 else "心境 · %s  当前 %d / 所需 %d" % [mind_word(mind_percent), int(session.player.mind), session.mind_needed()]), 15, ui.INK if mind_percent >= 100 else Color("#e3c08a")))
	sources.add_child(ui.label("心境收益  %d%%" % mind_percent, 15, ui.INK if mind_percent >= 100 else Color("#e3c08a")))
	if session.at_bottleneck():
		right.add_child(ui.paragraph("修为卡在瓶颈，闭关难有寸进。需外出历练（斗法、切磋、委托、奇遇），或服一枚破障丹。", Color("#e39a82")))
		return
	if session.at_xp_cap():
		right.add_child(ui.paragraph(session.cap_text(), Color("#e39a82")))
		return
	var held: String = session.guide_block("cultivate")
	if not held.is_empty():
		right.add_child(ui.paragraph(held, Color("#e3c08a")))
		return
	if mind_percent < 100:
		right.add_child(ui.paragraph("心境不及此境所需：闭关收益减半，单次闭关也只能维持一半时日。斗法、委托、奇遇与人事都能磨砺心境。", Color("#e3c08a")))
	var step := step_days(session)
	var cap: int = session.retreat_most()
	var most := maxi(1, cap / step)
	right.add_child(ui.label("选择闭关时间 · 此番至多 %s" % Calendar.duration_text(most * step), 16, ui.GOLD))
	var slider := HSlider.new()
	slider.min_value = 1
	slider.max_value = most
	slider.step = 1
	slider.value = clampi(ui.retreat_days / step, 1, most)
	slider.custom_minimum_size.x = 320
	slider.editable = most > 1
	right.add_child(slider)
	var length: Label = ui.label("", 18)
	right.add_child(length)
	var preview: Label = ui.paragraph("", ui.INK)
	right.add_child(preview)
	var start: Button = ui.button("开始闭关", func() -> void: ui.start_retreat(ui.retreat_days), "只在勾选的约定到期或寿元告急时提前出关")
	start.custom_minimum_size.x = 200
	right.add_child(start)
	var refresh := func(value: float) -> void:
		ui.retreat_days = mini(int(value) * step, cap)
		length.text = Calendar.duration_text(ui.retreat_days)
		preview.text = preview_text(session, ui.retreat_days)
	slider.value_changed.connect(refresh)
	refresh.call(slider.value)
	var presets := HBoxContainer.new()
	presets.add_theme_constant_override("separation", 8)
	right.add_child(presets)
	for units: int in [1, 3, 12]:
		var days := mini(cap, units * step)
		var pick: Button = ui.button(Calendar.duration_text(days), func() -> void: slider.value = clampi(units, 1, most), "选择时间并更新出关预览")
		pick.disabled = units > most
		presets.add_child(pick)

## 领悟, after Mi Chang Sheng's: everything studied in seclusion in one place — the 玉简 in the 行囊,
## the lineage (in the sect's own chamber) and the next layer of what is already learned. Each takes its
## days here, and the scroll plays the study back (main.gd start_insight).
static func render_insight(ui) -> void:
	var session = ui.session
	var columns := _columns(ui)
	var right: VBoxContainer = columns.get_child(1)
	if not ui.retreat_playback.is_empty():
		_playback(ui, right)
		return
	if not ui.retreat_result.is_empty():
		right.add_child(ui.paragraph(ui.retreat_result, ui.INK))
	right.add_child(ui.paragraph("悟性与灵根决定领悟的快慢：功法与灵根同属，耗时更少。闭关时运转的心法与神通也会慢慢积累熟练。", ui.MUTED))
	var insight: Array[String] = []
	for path: String in session.content.dao_data.paths:
		var amount := int(session.Dao.state(session).pending.get(path, 0))
		if amount > 0:
			insight.append("%s道 %d" % [session.content.dao_data.paths[path], amount])
	if not insight.is_empty():
		right.add_child(ui.paragraph("待吸收感悟 · " + "、".join(insight), ui.GOLD))
		right.add_child(ui.button("感悟大道", func() -> void: ui.set_view("dao"), "选择大道吸收感悟，或领悟悟道节点。"))
	right.add_child(ui.label("研读玉简", 20, ui.GOLD))
	var manuals: Array = session.player.items.keys().filter(func(item_id: String) -> bool: return str(session.content.item(item_id).get("category", "")) == "manual")
	manuals.sort()
	if manuals.is_empty():
		right.add_child(ui.paragraph("行囊里没有玉简。传功堂可领入门功法的玉简；坊市、拍卖、斗法缴获，或请交情深的人传授，也能得到。"))
	for item_id: String in manuals:
		var manual: Dictionary = session.content.item(item_id)
		var taught: Dictionary = session.content.technique(str(manual.teaches))
		var reason: String = session.learn_block(str(manual.teaches))
		var days: int = session.study_days(taught)
		var about := "%s · %s · %s" % [taught.tier_name, "心法" if taught.slot == "method" else "神通", session.content.element_info(str(taught.element)).get("name", "")]
		_insight_row(ui, right, ArtLibrary.item_icon(session.content, manual), "%s\n%s" % [manual.name, about], ui.grade_color(taught), "领悟 · %d 日" % days, reason, str(taught.description),
			func() -> void: ui.start_insight(func() -> String: return session.study_manual(item_id), str(taught.name)))
	var home: String = session.Loadout.home_lineage(session)
	if session.available_here("study") and not home.is_empty() and str(session.player.get("sect", "wanderer")) != home:
		var sect: Dictionary = session.content.sects[home]
		var arts: Array[String] = []
		for skill_id: String in sect.skills:
			arts.append(str(session.content.technique(skill_id).name))
		right.add_child(ui.label("本门传承", 20, ui.GOLD))
		var reason: String = session.Loadout.lineage_block(session, home)
		_insight_row(ui, right, null, "%s\n%s" % [sect.name, "、".join(arts)], ui.INK, "研习传承 · %d 日" % int(session.content.rules.lineage.study_days), reason, "换上%s三门神通" % "、".join(arts),
			func() -> void: ui.start_insight(func() -> String: return session.choose_sect(home), str(sect.name)))
	right.add_child(ui.label("参悟功法", 20, ui.GOLD))
	for technique_id: String in session.player.learned:
		var held: Dictionary = session.held_technique(technique_id)
		if held.is_empty():
			continue
		var reason: String = session.comprehend_block(technique_id)
		var cost: Dictionary = session.Layers.comprehend_cost(session, technique_id)
		var action := "圆满" if int(held.layer) >= int(held.layers) else "参悟 · %d 日%s" % [int(cost.days), " · %d 灵石" % int(cost.stones) if int(cost.stones) > 0 else ""]
		var kind := "心法" if held.slot == "method" else "神通"
		_insight_row(ui, right, ArtLibrary.technique_icon(held), "%s · %s\n%s" % [held.name, kind, session.Layers.progress_text(session, technique_id)], ui.grade_color(held), action, reason, "补足所差的熟练，即刻修至下一层",
			func() -> void: ui.start_insight(func() -> String: return session.comprehend(technique_id), str(held.name)))

## One line of the 领悟 page: a picture, the name with a line under it, and the button that studies it.
## `block` is why it cannot be studied now ("" when it can), shown in place of `tip`.
static func _insight_row(ui, parent: VBoxContainer, picture: Texture2D, text: String, color: Color, action: String, block: String, tip: String, callback: Callable) -> void:
	if not block.is_empty():
		tip = block
	var row := HBoxContainer.new()
	row.add_theme_constant_override("separation", 10)
	parent.add_child(row)
	var icon := TextureRect.new()
	icon.texture = picture
	icon.custom_minimum_size = Vector2(44, 44)
	icon.expand_mode = TextureRect.EXPAND_IGNORE_SIZE
	icon.stretch_mode = TextureRect.STRETCH_KEEP_ASPECT_CENTERED
	icon.texture_filter = CanvasItem.TEXTURE_FILTER_LINEAR_WITH_MIPMAPS
	row.add_child(icon)
	var name: Label = ui.label(text, 15, color)
	name.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	name.tooltip_text = tip
	name.mouse_filter = Control.MOUSE_FILTER_PASS
	row.add_child(name)
	var go: Button = ui.button(action, callback, tip)
	go.custom_minimum_size.x = 170
	go.disabled = not block.is_empty() or not ui.settled()
	row.add_child(go)

static func render_breakthrough(ui) -> void:
	var session = ui.session
	var columns := _columns(ui)
	var right: VBoxContainer = columns.get_child(1)
	var need: Dictionary = session.next_breakthrough()
	if need.is_empty():
		right.add_child(ui.paragraph("后续境界尚未开放。", ui.INK))
		return
	var realm := int(session.player.realm)
	var last_stage: int = session.content.realm(realm).stages.size() - 1
	right.add_child(ui.label("突破至%s" % session.content.realm(realm + 1).name, 26, ui.GOLD))
	var ready_stage := int(session.player.stage) >= last_stage
	var ready_xp := int(session.player.xp) >= int(need.xp)
	for line: Array in [[ready_stage, "修至%s" % session.content.realm_title(realm, last_stage)], [ready_xp, "修为  %d / %d" % [int(session.player.xp), int(need.xp)]]]:
		right.add_child(ui.label(("✓  " if line[0] else "·  ") + str(line[1]), 17, ui.INK if line[0] else ui.MUTED))
	var plan := plan_of(ui)
	_plan_controls(ui, right, plan)
	var chances: Dictionary = session.breakthrough_odds(plan)
	var parts: Array[String] = []
	for part: Array in chances.parts:
		parts.append("%s %+d" % [part[0], int(part[1])])
	# 结丹 is a stage (forming.gd): the odds become its 道基, the pearls condensed grade the core.
	# 结婴 likewise (nascent.gd): the odds become its 意志.
	var forming: bool = session.Forming.applies(int(session.player.realm) + 1)
	var nascent: bool = session.Nascent.applies(int(session.player.realm) + 1)
	# 筑基 too (founding.gd): the odds, the 筑基丹 among them, become its 真元.
	var founding: bool = session.Founding.applies(int(session.player.realm) + 1)
	if founding:
		right.add_child(ui.label("真元  %d" % int(chances.total) if not chances.certain else "真元  %d（残魂灌顶，不会耗尽）" % int(chances.total), 22, ui.GOLD))
	elif forming:
		right.add_child(ui.label("道基  %d" % int(chances.total) if not chances.certain else "道基  %d（残魂灌顶，不会崩散）" % int(chances.total), 22, ui.GOLD))
	elif nascent:
		right.add_child(ui.label("意志  %d" % int(chances.total) if not chances.certain else "意志  %d（残魂灌顶，不会溃散）" % int(chances.total), 22, ui.GOLD))
	else:
		right.add_child(ui.label("成功率  %d%%" % int(chances.total) if not chances.certain else "成功率  十成（残魂灌顶）", 22, ui.GOLD))
	right.add_child(ui.paragraph("　".join(parts)))
	if forming:
		var d: Dictionary = session.Forming.data(session)
		var known: Array = session.Forming.known_arts(session).map(func(art_id: String) -> String: return str(d.arts[art_id].name))
		right.add_child(ui.paragraph("闭关期满后亲手结丹：共 %d 回合，按灵根吸纳灵气，第 %d 回合起三颗同属灵气凝一颗灵珠。灵珠的数目定金丹品级，五行配比定金丹属性（纯属性、双属性、混元），各有斗法开场之利。道基即上面的把握：灵压、散气与相克的灵珠会消磨它，耗尽则失败。可运转的秘术：%s%s。" % [int(d.rounds), int(d.condense_from), "、".join(known), "" if session.has_flag("ningdan_known") else "（懂得凝丹之法另有大周天吐纳、抱元守一）"], ui.INK))
	if founding:
		var fd: Dictionary = session.Founding.data(session)
		var lines: Array[String] = []
		for index: int in fd.grades.size():
			lines.append("%d 为%s" % [int(fd.grades[index]), session.content.rules.breakthrough.grades[index].name])
		right.add_child(ui.paragraph("闭关期满后亲手筑基：共 %d 回合，按灵根吸纳灵气，用凝液、化气、压缩灵液把灵气压成灵液。九回合后灵液满 %d 即成，凝得越多根基越好：%s；无瑕要靠天材地宝或机缘再提。真元即上面的把握：灵压、散气与几门耗力的秘术会消磨它，耗尽则失败。" % [int(fd.rounds), int(fd.goal), "，".join(lines)], ui.INK))
	if nascent:
		var nd: Dictionary = session.Nascent.data(session)
		var arts: Array = session.Nascent.known_arts(session).map(func(art_id: String) -> String: return str(nd.arts[art_id].name))
		var grade := clampi(int(session.player.get("core_grade", 0)), 0, nd.cap_by_core.size() - 1)
		var missing: Array[String] = []
		for art_id: String in nd.arts:
			if not art_id in session.Nascent.known_arts(session):
				missing.append("%s（%s）" % [nd.arts[art_id].name, session.Nascent._lore_name(session, str(nd.arts[art_id].requires))])
		right.add_child(ui.paragraph("闭关期满后亲手结婴：共 %d 回合。先碎丹，%s丹坚 %d，碎后化回 %d 颗灵气；再应对心魔诸念，心境 %d、元婴需 %d，魔势 %d，每应对一念 -%d，降到零即刻成婴。经脉可存 %d 颗灵气。意志即上面的把握，耗尽则失败，成婴时剩下几成定元婴品质。可运转的秘术：%s%s。" % [int(nd.rounds), str(session.core_grade().get("name", "金丹")), session.Nascent.core_strength(session), int(nd.release.base) + grade / int(nd.release.per_grades), int(session.player.get("mind", 0)), session.Breakthrough.demon_mind(session), session.Nascent.demon_of(session, str(plan.get("treasure", ""))), int(nd.demon.answer), int(nd.cap_by_core[grade]), "、".join(arts), "（另有" + "、".join(missing) + "）" if not missing.is_empty() else ""], ui.INK))
	if not chances.steps.is_empty():
		right.add_child(ui.paragraph(("金丹可望再提品级：" if forming else ("元婴可望再提一档：" if nascent else "根基可望更上一层：")) + "、".join(chances.steps), ui.INK))
	# From the 金丹 on, Heaven's lightning tests the breakthrough (combat.gd 天劫).
	var trial: String = session.Breakthrough.tribulation_of(int(session.player.realm) + 1, session)
	if not trial.is_empty():
		var bolts: Dictionary = session.content.enemies[trial]
		right.add_child(ui.paragraph("冲关成功后还要渡%s：%d 道天雷，每道 %d–%d，不能撤离。攻击神通可散去来雷三成，护盾神通与符箓可抵挡；丹药须战前服用；渡不过则冲关失败，内伤加倍。" % [bolts.name, int(bolts.hp), int(bolts.damage_min), int(bolts.damage_max)], Color("#e3c08a")))
	if bool(chances.demon):
		right.add_child(ui.paragraph("心境 %d，%s需 %d：心境不足，突破关头可能心魔丛生（约 %d%%），可与它斗法、以心境硬压或避而不战。请人护法可保无虞。" % [int(session.player.mind), session.content.realm(int(session.player.realm) + 1).name, session.Breakthrough.demon_mind(session), int(round(session.Breakthrough.demon_chance(session) * 100.0))], Color("#e3c08a")))
	var failure: Dictionary = session.content.rules.breakthrough.failure
	right.add_child(ui.paragraph("闭关 %s。若失败：这次投入的丹药、天材地宝与机缘随之散尽，修为只退回 %d，内伤 %d 日（其间闭关收益减半），但性命无碍，且下次把握更大。" % [ui.duration("breakthrough"), int(need.xp) * int(failure.xp_percent) / 100, int(failure.injury_days)]))
	var block: String = session.breakthrough_block(plan)
	var go: Button = ui.button("开始突破", ui.start_breakthrough, block if not block.is_empty() else "成败只在此一举")
	go.custom_minimum_size.x = 200
	go.disabled = not block.is_empty() or not ui.settled()
	right.add_child(go)

## The plan on the scroll, kept by the interface and checked against what is in hand.
static func plan_of(ui) -> Dictionary:
	var session = ui.session
	var plan: Dictionary = ui.breakthrough_plan
	if plan.is_empty():
		plan = session.breakthrough_plan()
	var most := mini(session.pill_count(session.Breakthrough.pill_of(session)), session.content.rules.breakthrough.pill_bonus.size())
	plan.pills = clampi(int(plan.get("pills", 0)), 0, most)
	if not str(plan.get("treasure", "")) in session.breakthrough_treasures():
		plan.treasure = ""
	if not str(plan.get("guard", "")) in session.breakthrough_guards():
		plan.guard = ""
	ui.breakthrough_plan = plan
	return plan

## How many 筑基丹 to take (only 筑基 asks a pill), a treasure, and who stands guard.
static func _plan_controls(ui, parent: VBoxContainer, plan: Dictionary) -> void:
	var session = ui.session
	var pill_id: String = session.Breakthrough.pill_of(session)
	if pill_id.is_empty():
		parent.add_child(ui.paragraph("此番突破不靠丹药，全凭自身修为、心境与准备；天材地宝与机缘可添几分把握。", ui.INK))
		_treasure_controls(ui, parent, plan)
		_guard_controls(ui, parent, plan)
		return
	var pills := HBoxContainer.new()
	pills.add_theme_constant_override("separation", 10)
	parent.add_child(pills)
	var most := mini(session.pill_count(pill_id), session.content.rules.breakthrough.pill_bonus.size())
	var fewer: Button = ui.button("－", func() -> void: ui.breakthrough_plan.pills = int(plan.pills) - 1; ui.render(), "少服一枚")
	fewer.disabled = int(plan.pills) <= 0
	pills.add_child(fewer)
	pills.add_child(ui.label("服%s %d 枚（行囊 %d，至多 %d）" % [session.content.item(pill_id).name, int(plan.pills), session.pill_count(pill_id), session.content.rules.breakthrough.pill_bonus.size()], 17))
	var more: Button = ui.button("＋", func() -> void: ui.breakthrough_plan.pills = int(plan.pills) + 1; ui.render(), "多服一枚，一枚比一枚见效少")
	more.disabled = int(plan.pills) >= most
	pills.add_child(more)
	_treasure_controls(ui, parent, plan)
	_guard_controls(ui, parent, plan)

static func _treasure_controls(ui, parent: VBoxContainer, plan: Dictionary) -> void:
	var session = ui.session
	for item_id: String in session.breakthrough_treasures():
		var use := CheckBox.new()
		var item: Dictionary = session.content.item(item_id)
		var target := int(session.player.realm) + 1
		var stage: Variant = session.Founding if session.Founding.applies(target) else (session.Forming if session.Forming.applies(target) else (session.Nascent if session.Nascent.applies(target) else null))
		var gift: Dictionary = stage.data(session).get("treasures", {}).get(item_id, {}) if stage != null else {}
		var measure := "成功率" if stage == null else str(stage.MEASURE)
		var step := "，根基更稳" if stage == null or stage == session.Founding else ("，金丹再提一品" if stage == session.Forming else "，元婴再提一档")
		use.text = "服下%s（%s +%d%s%s）" % [item.name, measure, int(item.breakthrough.bonus), step if int(item.breakthrough.get("grade", 0)) > 0 else "", "；" + str(gift.text) if not gift.is_empty() else ""]
		use.button_pressed = plan.treasure == item_id
		use.toggled.connect(func(on: bool) -> void: ui.breakthrough_plan.treasure = item_id if on else ""; ui.render())
		parent.add_child(use)

static func _guard_controls(ui, parent: VBoxContainer, plan: Dictionary) -> void:
	var session = ui.session
	var guards: Array[String] = session.breakthrough_guards()
	if guards.is_empty():
		parent.add_child(ui.paragraph("无人护法：交情到了信赖的人，或传功长老，可以为你护法。"))
		return
	var row := HBoxContainer.new()
	row.add_theme_constant_override("separation", 10)
	parent.add_child(row)
	row.add_child(ui.label("护法", 17))
	var select := OptionButton.new()
	select.add_item("无人护法")
	for person_id: String in guards:
		select.add_item(session.person(person_id).name)
	select.selected = guards.find(str(plan.guard)) + 1
	select.item_selected.connect(func(index: int) -> void: ui.breakthrough_plan.guard = "" if index == 0 else guards[index - 1]; ui.render())
	row.add_child(select)

## The slider's step in days: ten days in the first realm, a month from foundation on.
static func step_days(session) -> int:
	return int(session.content.realm(int(session.player.realm)).get("retreat_step_days", Calendar.DAYS_PER_MONTH))

## Explain the strongest present constraint with actionable alternatives.
static func limitation(session) -> String:
	if session.at_bottleneck():
		return "当前限制：阶段瓶颈。可切磋、完成委托积累历练，或服破障丹。"
	if session.at_xp_cap():
		return "当前限制：此境修为已满。请在突破页检查丹药、护法与冲关准备。"
	if session.mind_percent() < 100:
		return "当前限制：心境不足。可处理人物托付或完成委托；疲惫时同时减少连续闭关。"
	if session.retreat_efficiency() < 100:
		return "当前限制：连续闭关后心神疲惫。可外出采药、办委托，再回山修炼。"
	return "眼下可安心修炼。下方可预估日期、修为与出关时的状态。"

## The mind against the stage's need, in a word.
static func mind_word(percent: int) -> String:
	return "不足" if percent < 100 else ("澄明" if percent > 100 else "安定")

## What a retreat of `days` would bring, as the rules plan it.
## A marked appointment inside the span ends it on its day (player.wake is kept soonest first).
static func preview_text(session, days: int) -> String:
	var stop := days
	var woken := ""
	for wake: Dictionary in session.player.get("wake", []):
		var at := int(wake.day) - int(session.world.day)
		if at > 0 and at < stop:
			stop = at
			woken = str(session.content.events[wake.event].title)
			break
	var plan: Dictionary = session.retreat_preview(stop)
	var lines: Array[String] = ["修为约 +%d" % int(plan.xp)]
	var rent: int = session.Cultivation.rent(session, int(plan.days))
	if rent > 0:
		lines.append("房钱 %d 灵石" % rent)
	if not woken.is_empty() and int(plan.days) >= stop:
		lines.append("第 %d 日%s开始，届时出关" % [stop, woken])
	if int(plan.days) < stop:
		lines.append("约第 %d 日修为%s而出关" % [int(plan.days), "臻于此境之极" if int(session.player.xp) + int(plan.xp) >= session.xp_cap() and session.xp_cap() >= 0 else "触及瓶颈"])
	var after := Cultivation.efficiency(session, int(plan.fatigue))
	lines.append("出关时心神%s，闭关收益 %d%%" % [_mood(after), after])
	return "\n".join(lines)

static func _mood(efficiency: int) -> String:
	return "平和" if efficiency >= 100 else ("浮躁" if efficiency >= 75 else "倦怠")

## The scroll's two columns: the deadlines coming up on the left, the tab's own content on the right.
static func _columns(ui) -> HBoxContainer:
	var session = ui.session
	var columns := HBoxContainer.new()
	columns.add_theme_constant_override("separation", 28)
	ui.center.add_child(columns)
	var left := VBoxContainer.new()
	left.custom_minimum_size.x = 300
	left.add_theme_constant_override("separation", 6)
	columns.add_child(left)
	var right := VBoxContainer.new()
	right.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	right.add_theme_constant_override("separation", 10)
	columns.add_child(right)
	left.add_child(ui.label("近 期 大 事", 18, ui.GOLD))
	var any := false
	for goal: Dictionary in Goals.current(session):
		if goal.id in DEADLINE_GOALS:
			var fixed := {"serpent": "serpent_rampage"}
			if fixed.has(str(goal.id)):
				var opening := Calendar.to_day(session.content.events[fixed[str(goal.id)]].window.from[0], session.content.events[fixed[str(goal.id)]].window.from[1], session.content.events[fixed[str(goal.id)]].window.from[2])
				if opening - int(session.world.day) > 360:
					continue
			left.add_child(ui.label("%s · 还有 %s" % [goal.title, Goals.values(session, goal.id).until], 15))
			any = true
	var markable := false
	for entry: Dictionary in session.upcoming():
		if int(entry.from) - int(session.world.day) > 360:
			continue
		any = true
		if int(entry.from) <= int(session.world.day):
			left.add_child(ui.label("%s · 进行中" % entry.title, 15))
			continue
		# An appointment still ahead can be marked to leave the retreat for; nothing else ends it.
		markable = true
		var event_id: String = entry.event
		var wake := CheckBox.new()
		wake.text = "%s · 始于 %s" % [entry.title, Calendar.short_text(int(entry.from))]
		wake.tooltip_text = "勾选后，闭关到此日便出关"
		wake.button_pressed = session.wakes_for(event_id)
		wake.add_theme_font_size_override("font_size", 15)
		wake.toggled.connect(func(on: bool) -> void: session.set_wake(event_id, on); ui.render())
		left.add_child(wake)
	# Dwellings let for a term (leases.gd): when the house is taken back.
	for location_id: String in session.content.locations:
		var lease: Dictionary = session.content.locations[location_id].get("lease", {})
		if not lease.is_empty() and session.Leases.until(session, str(lease.flag)) >= 0:
			left.add_child(ui.label("%s · 租期至 %s" % [lease.name, Calendar.short_text(session.Leases.until(session, str(lease.flag)))], 15))
			any = true
	if not any:
		left.add_child(ui.label("近期无事", 15, ui.MUTED))
	if markable:
		left.add_child(ui.paragraph("勾选的约定到期时提前出关；其余消息不打断闭关，出关后在「任务 · 消息」查看。", ui.MUTED))
	left.add_child(ui.paragraph("远期约定可在「任务 · 约定」查看。", ui.MUTED))
	left.add_child(ui.label("寿元尽于历元 %d 年" % Calendar.year(session.lifespan_end_day()), 14, ui.MUTED))
	return columns

## A retreat being played back: the days and the xp going by.
static func _playback(ui, parent: VBoxContainer) -> void:
	parent.add_child(ui.label("闭 关 中", 30, ui.GOLD))
	var date: Label = ui.label(Calendar.date_text(int(ui.retreat_playback.from_day)), 20)
	var xp: Label = ui.label("修为  %d" % int(ui.retreat_playback.from_xp), 20, ui.INK)
	parent.add_child(date)
	parent.add_child(xp)
	ui.retreat_labels = {"date": date, "xp": xp}
