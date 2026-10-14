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
const STATUS_NAMES := {"burn": "灼烧", "weaken": "寒蚀", "sunder": "破甲", "slow": "冰封"}
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
		var lines: Label = ui.label("\n".join(session.journal_lines().slice(-RECORD_LINES)), 14, ui.INK)
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
	var side := VBoxContainer.new()
	side.add_theme_constant_override("separation", 4)
	row.add_child(side)
	var flee: Button = ui.button("撤离 · " + ui.duration("flee"), func() -> void: ui.battle_action("flee"), "保留资源，耗时 %s；落败可休整后继续，最多损失 10 灵石" % ui.duration("flee"))
	_small(flee)
	side.add_child(flee)
	var allies: Array[String] = session.duel_allies()
	if not allies.is_empty():
		var friend: String = allies[0]
		var call: Button = ui.button("传音求援", func() -> void: ui.battle_action("aid:" + friend), "以传音符请%s出手一击（每场一次，不占回合）" % session.person(friend).name)
		_small(call)
		side.add_child(call)
	var record_toggle: Button = ui.button("收起记录" if ui.battle_record_open else "记录", ui.toggle_battle_record, "这场斗法的最近几条记载")
	_small(record_toggle)
	side.add_child(record_toggle)

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
		var pill: Button = ui.button("%s ×%d" % [item.name, session.item_count(item_id)], func() -> void: ui.battle_action("pill:" + item_id), "%s（不占回合；每场至多 %d 枚，已服 %d 枚）" % [item.description, int(duel.pills), taken])
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
				parts.append("%s %d–%d" % [entry.name, int(entry.min), int(entry.max)])
			"heal":
				parts.append("%s 回复 %d" % [entry.name, int(entry.amount)])
			"guard":
				parts.append("%s 护盾 %d" % [entry.name, int(entry.amount)])
			_:
				parts.append(str(entry.name))
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
				"slow":
					amount = "少抽 %d 颗" % int(value)
			parts.append("%s %s（余 %d 回合）" % [STATUS_NAMES[key], amount, int(status[key][1])])
	return "  ·  ".join(parts)

static func _realm_bonus_text(session) -> String:
	var bonus: int = session.attack_bonus()
	return "\n境界加成：每耗一颗灵气，伤害 +%s。" % _number(bonus / 2.0) if bonus > 0 else ""
