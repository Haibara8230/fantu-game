extends RefCounted
## 属性: the character page of the panel, after Mi Chang Sheng and Tale of Immortal — the full figure on
## the left with name, realm and standing; the attributes in groups in the middle (cultivation, body,
## lifespan, mind, roots and pills), each with a tooltip saying what it does; aptitude and talents,
## what is worn and the arts in use on the right, coloured by 品级.
const Calendar = preload("res://scripts/core/calendar.gd")
const ArtLibrary = preload("res://scripts/ui/art_library.gd")
const TalentCards = preload("res://scripts/ui/talent_cards.gd")
const WARN := Color("#e3c08a")
const BAD := Color("#e39a82")

static func render(ui) -> void:
	var session = ui.session
	var columns := HBoxContainer.new()
	columns.add_theme_constant_override("separation", 26)
	ui.center.add_child(columns)
	_figure(ui, columns)
	var middle := VBoxContainer.new()
	middle.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	middle.size_flags_stretch_ratio = 1.15
	middle.add_theme_constant_override("separation", 6)
	columns.add_child(middle)
	_cultivation(ui, middle)
	_body(ui, middle)
	_life(ui, middle)
	var right := VBoxContainer.new()
	right.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	right.add_theme_constant_override("separation", 6)
	columns.add_child(right)
	_roots(ui, right)
	_loadout(ui, right)

## The full figure, name, realm, lineage and standing in the sect.
static func _figure(ui, parent: HBoxContainer) -> void:
	var session = ui.session
	var p: Dictionary = session.player
	var column := VBoxContainer.new()
	column.custom_minimum_size.x = 250
	column.add_theme_constant_override("separation", 4)
	parent.add_child(column)
	var frame: Dictionary = ArtLibrary.actor_frame("hero", "idle")
	if not frame.is_empty():
		var atlas := AtlasTexture.new()
		atlas.atlas = frame.texture
		atlas.region = frame.region
		var figure := TextureRect.new()
		figure.texture = atlas
		figure.expand_mode = TextureRect.EXPAND_IGNORE_SIZE
		figure.stretch_mode = TextureRect.STRETCH_KEEP_ASPECT_CENTERED
		figure.custom_minimum_size = Vector2(250, 330)
		figure.flip_h = not bool(frame.faces_right)
		column.add_child(figure)
	var name_label: Label = ui.label(str(p.name), 28, ui.GOLD)
	name_label.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	column.add_child(name_label)
	var realm: Label = ui.label(session.realm_name(), 19, ui.INK)
	realm.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	column.add_child(realm)
	var standing: Label = ui.label("%s · %s传承" % [session.Sect.name_of(session, session.affiliation()) + str(session.sect_rank().name) if session.Sect.member(session) else ("散修 · %s" % ("副盟主" if session.League.deputy(session) else "散修盟") if session.League.member(session) else "散修"), session.content.sects[p.get("sect", "wanderer")].name], 15, ui.MUTED)
	standing.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	column.add_child(standing)
	# 天骄榜 (tianji.gd): the seat on the scroll of the player's realm, else the best ever held.
	var scroll_id: String = session.Tianji.own_scroll(session)
	var seat: int = 0 if scroll_id.is_empty() else session.Tianji.rank(session, scroll_id)
	var fame := ""
	if seat > 0:
		fame = "%s第 %d" % [session.Tianji.scroll(session, scroll_id).name, seat]
	else:
		for held_id: String in session.Tianji.data(session).scrolls:
			if session.Tianji.best(session, held_id) > 0:
				fame = "曾列%s第 %d" % [session.Tianji.scroll(session, held_id).name, session.Tianji.best(session, held_id)]
	if not fame.is_empty():
		var ranked: Label = ui.label(fame, 15, ui.GOLD)
		ranked.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
		column.add_child(ranked)
	var purse: Label = ui.label("灵石 %d · 贡献 %d" % [int(p.stones), int(p.get("contribution", 0))], 15, ui.GOLD)
	purse.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	column.add_child(purse)

## A group heading.
## A section's name, with the cloud-scroll divider (assets/art/ui/divider.svg) under it.
static func _heading(ui, parent: VBoxContainer, title: String) -> void:
	if parent.get_child_count() > 0:
		var gap := Control.new()
		gap.custom_minimum_size.y = 6
		parent.add_child(gap)
	parent.add_child(ui.label(title, 18, ui.GOLD))
	var line := TextureRect.new()
	line.texture = ArtLibrary.ui_icon("divider")
	line.custom_minimum_size = Vector2(0, 12)
	line.expand_mode = TextureRect.EXPAND_IGNORE_SIZE
	line.stretch_mode = TextureRect.STRETCH_SCALE
	line.texture_filter = CanvasItem.TEXTURE_FILTER_LINEAR_WITH_MIPMAPS
	line.modulate = Color(1, 1, 1, 0.8)
	parent.add_child(line)

## One attribute: its name, its value and what it means when the pointer rests on it.
static func _row(ui, parent: VBoxContainer, title: String, value: String, tooltip: String, color: Color = Color(0, 0, 0, 0)) -> void:
	var row := HBoxContainer.new()
	row.add_theme_constant_override("separation", 10)
	row.tooltip_text = tooltip
	row.mouse_filter = Control.MOUSE_FILTER_PASS
	parent.add_child(row)
	var name: Label = ui.label(title, 15, ui.MUTED)
	name.custom_minimum_size.x = 76
	name.mouse_filter = Control.MOUSE_FILTER_PASS
	name.tooltip_text = tooltip
	row.add_child(name)
	var shown: Label = ui.label(value, 15, ui.INK if color.a == 0.0 else color)
	shown.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	shown.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	shown.mouse_filter = Control.MOUSE_FILTER_PASS
	shown.tooltip_text = tooltip
	row.add_child(shown)

static func _cultivation(ui, parent: VBoxContainer) -> void:
	var session = ui.session
	var p: Dictionary = session.player
	_heading(ui, parent, "修 为")
	ui.meter(parent, "修为", p.xp, maxi(1, maxi(int(p.xp), xp_goal(session))), ui.GOLD)
	_row(ui, parent, "修炼速度", "×%.2f · 每月闭关约 %d 修为" % [session.cultivation_speed(), session.cultivation_rate()], "灵根、心法与宝物、根基、宗门身份共同决定")
	if session.xp_limit() >= 0:
		_row(ui, parent, "历练", "%d / %d" % [int(p.insight), session.insight_needed()], "斗法、切磋、委托、奇遇积累历练，攒满可冲开下一个瓶颈")
	if session.at_bottleneck():
		_row(ui, parent, "瓶颈", "修为卡在瓶颈，闭关难进", "需外出历练，或服一枚破障丹", BAD)
	var grade: Dictionary = session.foundation_grade()
	var core: Dictionary = session.core_grade()
	if not grade.is_empty():
		_row(ui, parent, "根基", str(grade.name), "筑基时的根基品质；结丹前影响体魄与修炼速度，结丹时决定金丹品级的大半")
	if not core.is_empty():
		_row(ui, parent, "金丹", str(core.name), "结丹时由根基、心法品阶与把握定下，影响体魄与修炼速度")

static func _body(ui, parent: VBoxContainer) -> void:
	var session = ui.session
	var p: Dictionary = session.player
	_heading(ui, parent, "体 魄")
	ui.meter(parent, "气血", p.hp, p.max_hp, Color("#a96f66"))
	ui.meter(parent, "灵力", p.qi, p.max_qi, Color("#5f999b"))
	_row(ui, parent, "攻击加成", "+%d" % session.attack_bonus(), "每次神通伤害额外增加；随境界与宝物、天赋提升")
	_row(ui, parent, "减伤", "%d%%" % int(round(session.defense() * 100.0)), "受到的伤害减少，至多五成")
	var school: String = session.Schools.player(session)
	if not school.is_empty():
		var way: Dictionary = session.content.technique_data.schools[school]
		_row(ui, parent, "流派", str(way.name), str(way.text))
	_row(ui, parent, "神识", str(session.sense()), "随境界与天赋增长：识破洞府机关、看见暗格，看穿神识不及你的人的天赋")
	var toxin: int = session.toxin()
	var rule: Dictionary = session.content.alchemy_data.toxin
	_row(ui, parent, "丹毒", "%d / %d · 每日消退 %d" % [toxin, int(rule.limit), int(rule.decay_per_day)] + (" · 突破把握 -%d" % (toxin / int(rule.breakthrough_step)) if toxin >= int(rule.breakthrough_step) else ""), "服增长修为的丹药会积丹毒；积满便服不下，突破时也少几分把握", ui.INK if toxin * 2 < int(rule.limit) else WARN)
	if session.Combat.wounded(session):
		_row(ui, parent, "外伤", "尚需将养 %s" % Calendar.duration_text(int(p.wound_until) - int(session.world.day)), "斗法留下的外伤：其间开打时气血至多七成半。服疗伤丹或到客栈歇一夜可治", BAD)
	if session.injured():
		_row(ui, parent, "内伤", "尚需将养 %s" % Calendar.duration_text(int(p.injury_until) - int(session.world.day)), "冲关受创或斗法落败所致，其间闭关收益减半", BAD)

static func _life(ui, parent: VBoxContainer) -> void:
	var session = ui.session
	var p: Dictionary = session.player
	_heading(ui, parent, "心 性 与 寿 元")
	var efficiency: int = session.retreat_efficiency()
	var mood := "平和" if efficiency >= 100 else ("浮躁" if efficiency >= 75 else "倦怠")
	var mind_percent: int = session.mind_percent()
	_row(ui, parent, "心境", "%d / %d · 闭关收益 %d%%" % [int(p.mind), session.mind_needed(), mind_percent], "阅历沉淀的定力；不及此境所需时闭关收益减半", ui.INK if mind_percent >= 100 else WARN)
	_row(ui, parent, "心神", "%s · 闭关收益 %d%%" % [mood, efficiency], "连日闭关心神渐倦；外出做些别的事可平复")
	_row(ui, parent, "闭关上限", Calendar.duration_text(session.retreat_cap()), "单次闭关至多这么久，随境界与心境放宽")
	_row(ui, parent, "年岁", "%d 岁 · 寿元 %d · 尽于历元 %d 年" % [session.age(), session.lifespan(), Calendar.year(session.lifespan_end_day())], "寿元耗尽此生便终；突破境界可增寿")
	var companion := str(session.world.get("companion", ""))
	if not companion.is_empty():
		_row(ui, parent, "道侣", str(session.person(companion).get("name", "")) + ("" if session.Bonds.companion_speed(session) > 0 else " · 已故"), "同修之人在世时，修炼速度 +%d%%" % int(session.content.bonds_data.companion.speed))
	var sworn: Array = session.world.get("sworn", [])
	if not sworn.is_empty():
		_row(ui, parent, "结义", "、".join(sworn.map(func(person_id: String) -> String: return str(session.person(person_id).get("name", "")))), "结义兄弟姐妹在信赖时就肯应你的传音求援")
	var disciples: Array = session.world.get("disciples", [])
	if not disciples.is_empty():
		_row(ui, parent, "弟子", "、".join(disciples.map(func(person_id: String) -> String: return str(session.person(person_id).get("name", "")))), "每年可传道一次；弟子不时捎来灵石")

static func _roots(ui, parent: VBoxContainer) -> void:
	var session = ui.session
	_heading(ui, parent, "根 骨")
	_row(ui, parent, "灵根", session.root_title(), "灵根越少越纯，修炼越快；与灵根相合的心法利于突破")
	var aptitude: Dictionary = session.aptitude()
	_row(ui, parent, "资质", str(aptitude.name), "灵根与天赋合成资质，决定每一次突破的难易", Color(str(aptitude.color)))
	parent.add_child(ui.label("先天天赋（鼠标停留可看效果）", 14, ui.MUTED))
	parent.add_child(TalentCards.row(ui, session.content, session.talents_of()))

## What is worn and the arts and methods in use, each in its 品级's colour.
static func _loadout(ui, parent: VBoxContainer) -> void:
	var session = ui.session
	var p: Dictionary = session.player
	_heading(ui, parent, "宝 物")
	for slot: String in session.content.equipment_data.slots:
		var item_id := str(p.equipment.get(slot, ""))
		var gear: Dictionary = session.gear_item(item_id) if not item_id.is_empty() else {}
		_row(ui, parent, str(session.content.equipment_data.slots[slot]), str(gear.get("name", "未佩戴")), str(gear.get("description", "在「行囊」里佩戴宝物")), ui.MUTED if gear.is_empty() else ui.grade_color(gear))
	_heading(ui, parent, "神 通 与 心 法")
	for technique_id: Variant in p.get("arts", []) + p.get("methods", []):
		var t: Dictionary = session.held_technique(str(technique_id))
		if t.is_empty():
			continue
		_row(ui, parent, "心法" if t.slot == "method" else "神通", t.name, "%s · 第 %d / %d 层\n%s" % [session.Arsenal.technique_tag(session.content, t), int(t.layer), int(t.layers), t.description], ui.grade_color(t))

## The next xp milestone: the next sub-stage, or the breakthrough once at the last stage.
static func xp_goal(session) -> int:
	var stages: Array = session.content.realm(int(session.player.realm)).stages
	if int(session.player.stage) + 1 < stages.size():
		return int(stages[int(session.player.stage) + 1].xp)
	return int(session.next_breakthrough().get("xp", 0))
