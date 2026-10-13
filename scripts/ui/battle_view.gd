extends RefCounted
## Duel screen: the stage fills the screen; along the bottom a dock holds the turn and qi, the active
## arts with their keys, costs and cooldowns, guard, retreat and the duel's record.
const BattleStage = preload("res://scripts/presentation/battle_stage.gd")
const PlaceView = preload("res://scripts/ui/place_view.gd")
const Settings = preload("res://scripts/ui/settings.gd")
const RECORD_LINES := 6

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
	battle_stage.custom_minimum_size.y = 245 if ui.preview_mode else 300
	battle_stage.size_flags_vertical = Control.SIZE_EXPAND_FILL
	battle_stage.configure(session.snapshot(), enemy)
	center.add_child(battle_stage)
	battle_stage.sound.connect(ui.audio.cue)
	if ui.battle_record_open:
		var record := PanelContainer.new()
		record.add_theme_stylebox_override("panel", ui.style(Color(0.03, 0.07, 0.08, 0.86), Color("#41615e"), 10))
		var lines: Label = ui.label("\n".join(session.journal_lines().slice(-RECORD_LINES)), 14, ui.INK)
		lines.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
		record.add_child(lines)
		center.add_child(record)
	var dock := PanelContainer.new()
	dock.add_theme_stylebox_override("panel", ui.style(Color(0.05, 0.11, 0.12, 0.94), Color("#5d7a6f"), 12))
	center.add_child(dock)
	var row := HBoxContainer.new()
	row.add_theme_constant_override("separation", 10)
	dock.add_child(row)
	var state := VBoxContainer.new()
	state.custom_minimum_size.x = 150
	state.add_theme_constant_override("separation", 2)
	row.add_child(state)
	state.add_child(ui.label("斗 法  ·  第 %d 回合" % int(b.turn), 17, ui.GOLD))
	state.add_child(ui.label("对手 · " + str(enemy.name), 14))
	state.add_child(ui.label("灵力  %d / %d" % [int(session.player.qi), int(session.player.max_qi)], 15, Color("#8fd0d2")))
	var arts := HBoxContainer.new()
	arts.add_theme_constant_override("separation", 8)
	arts.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	row.add_child(arts)
	var index := 1
	for skill_id: String in session.active_skills():
		var skill: Dictionary = session.content.technique(skill_id)
		var remaining := int(b.cooldowns.get(skill_id, 0))
		var suffix := "\n冷却 %d" % remaining if remaining > 0 else "\n%d 灵力" % int(skill.qi_cost)
		var cast: Button = ui.button("[%s] %s%s" % [Settings.key_name(ui, "skill_%d" % index), skill.name, suffix], func() -> void: ui.skill(skill_id), "%s · %s\n%s%s" % [skill.tier_name, session.content.technique_data.elements[skill.element].name, skill.description, _realm_bonus_text(session)])
		cast.disabled = remaining > 0 or int(session.player.qi) < int(skill.qi_cost)
		cast.custom_minimum_size = Vector2(132, 62)
		cast.size_flags_horizontal = Control.SIZE_EXPAND_FILL
		arts.add_child(cast)
		index += 1
	var guard: Button = ui.button("守御\n" + Settings.key_name(ui, "guard"), func() -> void: ui.battle_action("guard"), "恢复 6 灵力，受到伤害减半")
	guard.custom_minimum_size = Vector2(96, 62)
	row.add_child(guard)
	var side := VBoxContainer.new()
	side.add_theme_constant_override("separation", 4)
	row.add_child(side)
	var flee: Button = ui.button("撤离 · " + ui.duration("flee"), func() -> void: ui.battle_action("flee"), "保留资源，耗时 %s；落败可休整后继续，最多损失 10 灵石" % ui.duration("flee"))
	flee.custom_minimum_size = Vector2(110, 29)
	flee.add_theme_font_size_override("font_size", 14)
	side.add_child(flee)
	var allies: Array[String] = session.duel_allies()
	if not allies.is_empty():
		var friend: String = allies[0]
		var call: Button = ui.button("传音求援", func() -> void: ui.battle_action("aid:" + friend), "以传音符请%s出手一击（每场一次，算作你的回合）" % session.person(friend).name)
		call.custom_minimum_size = Vector2(110, 29)
		call.add_theme_font_size_override("font_size", 14)
		side.add_child(call)
	var record_toggle: Button = ui.button("收起记录" if ui.battle_record_open else "记录", ui.toggle_battle_record, "这场斗法的最近几条记载")
	record_toggle.custom_minimum_size = Vector2(110, 29)
	record_toggle.add_theme_font_size_override("font_size", 14)
	side.add_child(record_toggle)

static func _realm_bonus_text(session) -> String:
	var bonus: int = session.attack_bonus()
	return " 境界加成：攻击伤害 +%d。" % bonus if bonus > 0 else ""
