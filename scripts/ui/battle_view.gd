extends RefCounted
## Duel screen: the stage fills the screen, with the opponent's intent and both sides' shields and
## lingering effects laid over its top corners. Along the bottom a dock: the turn, the hand of qi orbs
## (click an element to 相生 two of its orbs into one of the next) and the pills that may be taken; below,
## the active arts with their keys, orb costs and 克制, 结束回合, 守御, retreat and the duel's record.
const BattleStage = preload("res://scripts/presentation/battle_stage.gd")
const PlaceView = preload("res://scripts/ui/place_view.gd")
const Settings = preload("res://scripts/ui/settings.gd")
const RECORD_LINES := 6
const DOCK_HEIGHT := 178.0
const STATUS_NAMES := {"burn": "灼烧", "weaken": "寒蚀", "sunder": "破甲", "slow": "冰封", "bleed": "流血", "entangle": "缠绕", "wound": "禁疗", "focus": "蓄势", "minions": "帮手", "fervor": "秘术"}
const FOE_COLOR := Color("#f0b49a")

static func render(ui) -> void:
	var session = ui.session
	var center: VBoxContainer = ui.center
	if ui.preview_mode:
		PlaceView.sect_choices(ui, center, true)
	var b: Dictionary = session.battle
	var enemy: Dictionary = session.content.enemies[b.enemy_id].duplicate()
	if b.has("foe"):
		enemy.name = b.foe.name
		enemy.hp = b.foe.hp
	var battle_stage = BattleStage.new()
	ui.battle_stage = battle_stage
	# The stage fills the screen above the dock (and the record when it is open).
	var room: float = ui.get_viewport_rect().size.y - DOCK_HEIGHT - (170.0 if ui.battle_record_open else 0.0)
	battle_stage.custom_minimum_size.y = 245 if ui.preview_mode else maxf(260.0, room)
	battle_stage.size_flags_vertical = Control.SIZE_EXPAND_FILL
	battle_stage.configure(session.snapshot(), enemy)
	center.add_child(battle_stage)
	battle_stage.sound.connect(ui.audio.cue)
	_corners(ui, battle_stage)
	if ui.battle_record_open:
		var record := PanelContainer.new()
		record.add_theme_stylebox_override("panel", ui.style(Color(0.03, 0.07, 0.08, 0.86), Color("#41615e"), 10))
		if ui.battle_secret_open:
			record.add_child(_secret_row(ui))
		else:
			var shown: Array = session.Combat.scout(session).lines if ui.battle_scout_open else session.journal_lines().slice(-RECORD_LINES)
			var lines: Label = ui.label("\n".join(shown), 14, ui.INK)
			lines.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
			record.add_child(lines)
		center.add_child(record)
	var dock := PanelContainer.new()
	dock.add_theme_stylebox_override("panel", ui.style(Color(0.05, 0.11, 0.12, 0.94), Color("#5d7a6f"), 10))
	center.add_child(dock)
	var rows := VBoxContainer.new()
	rows.add_theme_constant_override("separation", 6)
	dock.add_child(rows)
	rows.add_child(_hand_row(ui))
	var row := HBoxContainer.new()
	row.add_theme_constant_override("separation", 8)
	rows.add_child(row)
	var arts := HBoxContainer.new()
	arts.add_theme_constant_override("separation", 8)
	arts.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	row.add_child(arts)
	var index := 1
	for skill_id: String in session.active_skills():
		arts.add_child(_art_button(ui, skill_id, index))
		index += 1
	var end: Button = ui.button("结束回合\n" + Settings.key_name(ui, "end_turn"), func() -> void: ui.battle_action("end_turn"), "把回合交给对手。回合末手中灵气超过 %d 颗的部分会散去。" % session.Combat.hand_cap(session))
	ui.tint(end, ui.GOLD)
	end.custom_minimum_size = Vector2(104, 62)
	row.add_child(end)
	var guard: Button = ui.button("守御\n" + Settings.key_name(ui, "guard"), func() -> void: ui.battle_action("guard"), "凝神守御并结束回合：对手这一回合的出手减半，下回合多抽 %d 颗灵气。" % int(session.content.rules.duel.guard_orbs))
	guard.custom_minimum_size = Vector2(84, 62)
	row.add_child(guard)
	var quick: Button = ui.button("速战", func() -> void: ui.battle_action("quick"), "按简单的出法自动打完这一场：气血低时疗伤，否则出最强的神通，灵气闲着便相生。对付弱敌省事，强敌还是亲手来。")
	quick.custom_minimum_size = Vector2(72, 62)
	row.add_child(quick)
	# The lesser controls (撤离, 祭出, targets, 求援, 记录, 探查) two abreast, so the dock stays low.
	var side := GridContainer.new()
	side.columns = 2
	side.add_theme_constant_override("h_separation", 4)
	side.add_theme_constant_override("v_separation", 4)
	row.add_child(side)
	var odds := "比斗中随时可认输" if session.battle.get("context", "") in ["spar", "tournament", "summit", "arena"] else "约 %d%% 能脱身，脱不了身便挨对手一回合" % int(round(session.Combat.flee_chance(session) * 100.0))
	var flee: Button = ui.button("撤离 · " + ui.duration("flee"), func() -> void: ui.battle_action("flee"), "保留资源，耗时 %s；%s；被缠住时走不了" % [ui.duration("flee"), odds])
	# 天劫 cannot be fled; turning from 心魔 is evading it.
	if session.battle.get("context", "") == "tribulation":
		flee.disabled = true
		flee.tooltip_text = "天劫临身，无处可逃"
	elif session.battle.get("context", "") == "demon":
		flee.text = "紧守灵台"
		flee.tooltip_text = "不与心魔纠缠：突破把握略减"
	_small(flee)
	side.add_child(flee)
	# 阵修 布阵 (schools.gd): a turn to lay the formation.
	if session.Schools.player(session) == "array":
		var array_reason: String = session.Combat.array_block(session)
		var lay: Button = ui.button("布阵", func() -> void: ui.battle_action("array"), array_reason if not array_reason.is_empty() else str(session.content.technique_data.schools.array.text) + "（结束本回合）")
		lay.disabled = not array_reason.is_empty()
		_small(lay)
		side.add_child(lay)
	# 祭出 the worn 兵刃 (combat.gd release): its own move, once a duel (twice from 法宝 up).
	var release: Dictionary = session.Combat.release_of(session)
	if not release.is_empty():
		var reason: String = session.Combat.release_block(session)
		var thrown: Button = ui.button("祭出 · %s（余 %d）" % [release.move.name, int(release.left)], func() -> void: ui.battle_action("release"), reason if not reason.is_empty() else "祭出%s，打出约 %d 点伤害，不占回合" % [release.name, int(release.damage)])
		thrown.disabled = not reason.is_empty()
		_small(thrown)
		side.add_child(thrown)
	# 群敌: whom the arts strike (连击 catch the others for a third).
	var pack: Array = session.battle.get("pack", [])
	if not pack.is_empty():
		var aimed := int(session.battle.get("target", 0))
		var foes: Array = [{"enemy_id": session.battle.enemy_id, "hp": session.battle.hp}] + pack
		for foe_index: int in foes.size():
			var member: Dictionary = session.content.enemies[str(foes[foe_index].enemy_id)]
			var mark := "◆ " if foe_index == aimed else ""
			var pick: Button = ui.button("%s%s %d/%d" % [mark, member.name, int(foes[foe_index].hp), int(member.hp)], func() -> void: ui.battle_action("target:%d" % foe_index), "以神通攻击%s（不占回合）。%s" % [member.name, "领头的按意图出手，其余每回合各扑一次；连击神通会波及其余对手。" if foe_index == 0 else "围攻者：每回合各扑一次。打倒领头的，下一个顶上来。"])
			pick.disabled = foe_index == aimed
			_small(pick)
			side.add_child(pick)
	var allies: Array[String] = session.duel_allies()
	if not allies.is_empty():
		var friend: String = allies[0]
		var call: Button = ui.button("传音求援", func() -> void: ui.battle_action("aid:" + friend), "以传音符请%s出手一击（每场一次，不占回合）" % session.person(friend).name)
		_small(call)
		side.add_child(call)
	var record_toggle: Button = ui.button("收起记录" if ui.battle_record_open and not ui.battle_scout_open else "记录", ui.toggle_battle_record, "这场斗法的最近几条记载")
	_small(record_toggle)
	side.add_child(record_toggle)
	var seen: bool = session.Combat.scout(session).seen
	if int(session.player.realm) >= 1 and not session.battle.get("context", "") in ["spar", "tournament", "summit", "arena"]:
		var secret_toggle: Button = ui.button("收起秘术" if ui.battle_secret_open else "禁忌秘术", ui.toggle_battle_secret, "以寿元、重伤或妖丹换一时爆发，每门每场一次")
		_small(secret_toggle)
		side.add_child(secret_toggle)
	var scout_toggle: Button = ui.button("收起探查" if ui.battle_scout_open else "神识探查", ui.toggle_battle_scout, "以神识探查对手：神识压过对手可看清它的招式、阶段、五行与身上可取之物" if seen else "神识不及对手，只能看出大致修为")
	_small(scout_toggle)
	side.add_child(scout_toggle)

## 禁忌秘术: each with its price written on it, once a duel (combat.gd).
static func _secret_row(ui) -> HBoxContainer:
	var session = ui.session
	var row := HBoxContainer.new()
	row.add_theme_constant_override("separation", 10)
	var arts: Dictionary = session.content.rules.duel.get("secret_arts", {})
	for art_id: String in arts:
		var art: Dictionary = arts[art_id]
		var reason: String = session.Combat.secret_block(session, art_id)
		var cast: Button = ui.button("%s\n%s" % [art.name, str(art.text).get_slice("：", 0)], func() -> void: ui.battle_action("secret:" + art_id), reason if not reason.is_empty() else str(art.text) + "（不占回合；代价立即记下，读档换装都抹不去）")
		cast.disabled = not reason.is_empty()
		cast.size_flags_horizontal = Control.SIZE_EXPAND_FILL
		cast.custom_minimum_size = Vector2(0, 58)
		ui.tint(cast, Color("#c9785f"))
		row.add_child(cast)
	return row

static func _small(target: Button) -> void:
	target.custom_minimum_size = Vector2(110, 0)
	target.add_theme_font_size_override("font_size", 14)
	target.size_flags_vertical = Control.SIZE_EXPAND_FILL

## The turn, the qi orbs in hand by element (each a 相生 button) and the pills for the duel.
static func _hand_row(ui) -> HBoxContainer:
	var session = ui.session
	var b: Dictionary = session.battle
	var row := HBoxContainer.new()
	row.add_theme_constant_override("separation", 6)
	var turn: Label = ui.label("斗 法  ·  第 %d 回合" % int(b.turn), 16, ui.GOLD)
	turn.custom_minimum_size.x = 150
	row.add_child(turn)
	var orbs: Array = b.get("orbs", [])
	var cap: int = session.Combat.hand_cap(session)
	var count: Label = ui.label("灵气 %d / %d" % [orbs.size(), cap], 15, Color("#ffb08a") if orbs.size() > cap else Color("#8fd0d2"))
	count.tooltip_text = "回合末最多留 %d 颗，多的散去（由灵力上限而定）。" % cap
	count.mouse_filter = Control.MOUSE_FILTER_PASS
	row.add_child(count)
	var elements: Dictionary = session.content.technique_data.elements
	var duel: Dictionary = session.content.rules.duel
	var need := int(duel.convert)
	for element: String in elements:
		var held := orbs.count(element)
		if held == 0:
			continue
		var made := str(duel.generates[element])
		var chip: Button = ui.button("%s %d" % [elements[element].name, held], func() -> void: ui.battle_action("convert:" + element), "%s灵气 %d 颗。点击以两颗相生为一颗%s灵气（%s生%s，不占回合）。" % [elements[element].name, held, elements[made].name, elements[element].name, elements[made].name])
		_orb_style(ui, chip, Color(elements[element].color))
		chip.disabled = held < need
		row.add_child(chip)
	if orbs.is_empty():
		row.add_child(ui.label("手中无灵气", 14, ui.MUTED))
	var gap := Control.new()
	gap.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	row.add_child(gap)
	var taken := int(b.get("pills", 0))
	for item_id: String in _duel_pills(session):
		var item: Dictionary = session.content.item(item_id)
		var limit := "每场至多 %d 张符箓，已用 %d 张" % [int(duel.get("talismans", 3)), int(b.get("talismans", 0))] if str(item.get("category", "")) == "talisman" else "每场至多 %d 枚，已服 %d 枚" % [int(duel.pills), taken]
		var pill: Button = ui.button("%s ×%d" % [item.name, session.item_count(item_id)], func() -> void: ui.battle_action("pill:" + item_id), "%s（不占回合；%s）" % [item.description, limit])
		ui.tint(pill, ui.grade_color(item))
		pill.add_theme_font_size_override("font_size", 14)
		pill.custom_minimum_size = Vector2(0, 34)
		pill.disabled = not session.duel_pill_block(item_id).is_empty()
		row.add_child(pill)
	return row

## The pills in the pack that can be taken in a duel, in the data's order.
static func _duel_pills(session) -> Array[String]:
	var pills: Array[String] = []
	for item_id: String in session.content.items:
		if session.content.items[item_id].has("duel") and session.item_count(item_id) > 0:
			pills.append(item_id)
	return pills

static func _orb_style(ui, chip: Button, color: Color) -> void:
	chip.custom_minimum_size = Vector2(54, 34)
	chip.add_theme_font_size_override("font_size", 15)
	chip.add_theme_stylebox_override("normal", ui.style(color.darkened(0.62), color, 4))
	chip.add_theme_stylebox_override("hover", ui.style(color.darkened(0.45), color.lightened(0.3), 4))
	chip.add_theme_stylebox_override("pressed", ui.style(color.darkened(0.3), color.lightened(0.3), 4))
	chip.add_theme_stylebox_override("disabled", ui.style(color.darkened(0.62), color.darkened(0.2), 4))
	ui.tint(chip, color.lightened(0.15))
	# Short of a pair the chip still reads clearly: it only cannot 相生 yet.
	chip.add_theme_color_override("font_disabled_color", color)

static func _art_button(ui, skill_id: String, index: int) -> Button:
	var session = ui.session
	var skill: Dictionary = session.content.technique(skill_id)
	var cost_text: String = session.Arsenal.cost_text(session.content, skill.cost)
	var counter: float = session.Combat.counter_multiplier(session, str(skill.element))
	var counter_text := ""
	if skill.kind == "attack" and counter > 1.0:
		counter_text = " · 克 ×%s" % _number(counter)
	elif skill.kind == "attack" and counter < 1.0:
		counter_text = " · 被克 ×%s" % _number(counter)
	var tooltip := "%s · %s\n%s%s" % [skill.tier_name, session.content.technique_data.elements[skill.element].name, skill.description, _realm_bonus_text(session)]
	if not counter_text.is_empty():
		tooltip += "\n对手属%s：%s伤害 ×%s。" % [session.content.technique_data.elements[session.Combat.foe_element(session)].name, "克制，" if counter > 1.0 else "被克，", _number(counter)]
	var cast: Button = ui.button("[%s] %s\n%s%s" % [Settings.key_name(ui, "skill_%d" % index), skill.name, cost_text, counter_text], func() -> void: ui.skill(skill_id), tooltip)
	ui.tint(cast, ui.grade_color(skill))
	cast.disabled = not session.Combat.affordable(session.battle.get("orbs", []), skill.cost)
	cast.custom_minimum_size = Vector2(124, 62)
	cast.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	return cast

static func _number(value: float) -> String:
	return str(snappedf(value, 0.01))

## Over the stage: the player's shield and lingering effects at the top left, the opponent's intent,
## shield, effects and orbs at the top right.
static func _corners(ui, stage: Control) -> void:
	var session = ui.session
	var b: Dictionary = session.battle
	var mine := _effects_text(int(b.get("shield", 0)), b.get("player_status", {}))
	if not mine.is_empty():
		var left := _corner(ui, stage, mine, Color("#cfe9e1"))
		left.set_anchors_and_offsets_preset(Control.PRESET_TOP_LEFT)
		left.position = Vector2(16, 60)
	var lines: Array[String] = ["对手下一回合：" + intent_text(session)]
	# 死斗: lost, the life ends (a save from its start is kept).
	if bool(b.get("deadly", false)):
		lines.append("死斗：落败即身死（已留劫前存档）")
	# 地利: the ground's favour for some elements, and a sect's own ground.
	var ground: String = session.Combat.ground_text(session)
	if not ground.is_empty():
		lines.append("地利 · " + ground)
	var theirs := _effects_text(int(b.get("foe_shield", 0)), b.get("status", {}))
	if not b.get("foe", {}).get("arts", []).is_empty():
		theirs = ("灵气 %d" % b.get("foe_orbs", []).size()) + ("  ·  " + theirs if not theirs.is_empty() else "")
	if not theirs.is_empty():
		lines.append(theirs)
	var right := _corner(ui, stage, "\n".join(lines), FOE_COLOR)
	right.set_anchors_and_offsets_preset(Control.PRESET_TOP_RIGHT)
	right.grow_horizontal = Control.GROW_DIRECTION_BEGIN
	right.offset_right = -16
	right.offset_top = 60

static func _corner(ui, stage: Control, text: String, color: Color) -> PanelContainer:
	var box := PanelContainer.new()
	box.mouse_filter = Control.MOUSE_FILTER_IGNORE
	box.add_theme_stylebox_override("panel", ui.style(Color(0.04, 0.09, 0.1, 0.78), Color(color, 0.5), 8))
	var words: Label = ui.label(text, 15, color)
	words.mouse_filter = Control.MOUSE_FILTER_IGNORE
	box.add_child(words)
	stage.add_child(box)
	return box

## "赤焰诀 12–15 · 金钟罩 护盾 18": what the opponent means to do next.
static func intent_text(session) -> String:
	var parts: Array[String] = []
	for entry: Dictionary in session.battle.get("intent", []):
		match str(entry.kind):
			"attack":
				var hits := " ×%d" % int(entry.hits) if int(entry.get("hits", 1)) > 1 else ""
				parts.append("%s %d–%d%s" % [entry.name, int(entry.min), int(entry.max), hits])
			"charge":
				parts.append("蓄力：%s（下回合 %d–%d，可守御）" % [entry.name, int(entry.min), int(entry.max)])
			"focus":
				parts.append("%s（下一击 +%d%%）" % [entry.name, int(entry.amount)])
			"summon":
				parts.append("%s（帮手每回合 %d）" % [entry.name, int(entry.amount)])
			"heal":
				parts.append("%s 回复 %d" % [entry.name, int(entry.amount)])
			"guard":
				parts.append("%s 护盾 %d" % [entry.name, int(entry.amount)])
			_:
				parts.append(str(entry.name))
	# 天劫: the bolts left, and how much of the next one is dispersed.
	if session.battle.get("context", "") == "tribulation":
		parts.append("余 %d 道天雷；攻击神通的三成化作散雷（已散 %d）" % [int(session.battle.hp), int(session.battle.get("dispel", 0)) * session.Combat.DISPEL_PERCENT / 100])
	# 群敌: the others strike too, each once a turn.
	var pack: Array = session.battle.get("pack", [])
	if not pack.is_empty():
		var low := 0
		var high := 0
		for member: Dictionary in pack:
			var enemy: Dictionary = session.content.enemies[str(member.enemy_id)]
			low += int(round(float(enemy.damage_min) * session.Combat.PACK_BLOW))
			high += int(round(float(enemy.damage_max) * session.Combat.PACK_BLOW))
		parts.append("另有 %d 个围攻（合计约 %d–%d）" % [pack.size(), low, high])
	return " · ".join(parts) if not parts.is_empty() else "不明"

## "护盾 18  ·  灼烧 4（余 2 回合）".
static func _effects_text(shield: int, status: Dictionary) -> String:
	var parts: Array[String] = []
	if shield > 0:
		parts.append("护盾 %d" % shield)
	for key: String in STATUS_NAMES:
		if status.has(key):
			var value: float = float(status[key][0])
			var amount := str(int(value))
			match key:
				"weaken":
					amount = "-%d%% 伤害" % int(round(value * 100))
				"sunder":
					amount = "+%d%% 受伤" % int(round(value * 100))
				"slow", "entangle":
					amount = "少抽 %d 颗" % int(value) + ("、不能撤离" if key == "entangle" else "")
				"wound":
					amount = "疗愈 -%d%%" % int(round(value * 100))
				"focus":
					amount = "下一击 +%d%%" % int(round(value * 100))
				"fervor":
					amount = "神通 +%d%%" % int(round(value * 100))
				"minions":
					amount = "每回合 %d" % int(value)
			parts.append("%s %s（余 %d 回合）" % [STATUS_NAMES[key], amount, int(status[key][1])])
	return "  ·  ".join(parts)

static func _realm_bonus_text(session) -> String:
	var bonus: int = session.attack_bonus()
	return "\n境界加成：每耗一颗灵气，伤害 +%s。" % _number(bonus / 2.0) if bonus > 0 else ""
