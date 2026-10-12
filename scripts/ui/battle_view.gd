extends RefCounted
## Duel view: the stage, the active arts with their costs and cooldowns, guard and retreat.
const BattleStage = preload("res://scripts/presentation/battle_stage.gd")
const PlaceView = preload("res://scripts/ui/place_view.gd")
const Settings = preload("res://scripts/ui/settings.gd")

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
	center.add_child(ui.label("斗 法  ·  %s     第 %d 回合" % [enemy.name, b.turn], 23, ui.GOLD))
	var battle_stage = BattleStage.new()
	ui.battle_stage = battle_stage
	battle_stage.custom_minimum_size.y = 245 if ui.preview_mode else 300
	battle_stage.configure(session.snapshot(), enemy)
	center.add_child(battle_stage)
	battle_stage.cue.connect(ui.audio.cue)
	center.add_child(ui.paragraph("选择神通 · 守御回灵并减伤 · 出招期间请等待命中与对手反击"))
	var grid := GridContainer.new()
	grid.columns = 6
	grid.add_theme_constant_override("h_separation", 8)
	grid.add_theme_constant_override("v_separation", 10)
	center.add_child(grid)
	var index := 1
	for skill_id: String in session.active_skills():
		var skill: Dictionary = session.content.technique(skill_id)
		var remaining := int(b.cooldowns.get(skill_id, 0))
		var suffix := "\n冷却 %d" % remaining if remaining > 0 else "\n%d 灵力" % int(skill.qi_cost)
		var cast: Button = ui.button("[%s] %s%s" % [Settings.key_name(ui, "skill_%d" % index), skill.name, suffix], func() -> void: ui.skill(skill_id), "%s · %s\n%s%s" % [skill.tier_name, session.content.technique_data.elements[skill.element].name, skill.description, _realm_bonus_text(session)])
		cast.disabled = remaining > 0 or int(session.player.qi) < int(skill.qi_cost)
		cast.size_flags_horizontal = Control.SIZE_EXPAND_FILL
		grid.add_child(cast)
		index += 1
	grid.add_child(ui.button("守御\n" + Settings.key_name(ui, "guard"), func() -> void: ui.battle_action("guard"), "恢复 6 灵力，受到伤害减半"))
	grid.add_child(ui.button("撤离\n耗时 " + ui.duration("flee"), func() -> void: ui.battle_action("flee"), "保留资源，耗时 " + ui.duration("flee")))
	center.add_child(ui.paragraph("落败可休整后继续 · 最多损失 10 灵石", ui.MUTED))

static func _realm_bonus_text(session) -> String:
	var bonus: int = session.attack_bonus()
	return " 境界加成：攻击伤害 +%d。" % bonus if bonus > 0 else ""
