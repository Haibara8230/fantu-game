extends RefCounted
## Approved V6 layout: full stage, two rows of arts, central payment wheel and five-element pool.
const BattleStage = preload("res://scripts/presentation/battle_stage.gd")
const PlaceView = preload("res://scripts/ui/place_view.gd")
const ArtLibrary = preload("res://scripts/ui/art_library.gd")
const RECORD_LINES := 6
const STATUS_NAMES := {"burn": "灼烧", "weaken": "寒蚀", "sunder": "破甲", "slow": "冰封", "bleed": "流血", "entangle": "缠绕", "wound": "禁疗", "focus": "蓄势", "minions": "帮手", "fervor": "秘术"}
const FOE_COLOR := Color("#f0b49a")

static func render(ui) -> void:
	var session = ui.session
	var center: VBoxContainer = ui.center
	var selector: bool = ui.preview_mode and not "--battle-v6-preview" in OS.get_cmdline_user_args()
	if selector:
		PlaceView.sect_choices(ui, center, true)
	var b: Dictionary = session.battle
	var enemy: Dictionary = session.content.enemies[b.enemy_id].duplicate()
	if b.has("foe"):
		enemy.name = b.foe.name
		enemy.hp = b.foe.hp
	var battle_stage = BattleStage.new()
	ui.battle_stage = battle_stage
	battle_stage.custom_minimum_size.y = 520 if selector else ui.get_viewport_rect().size.y
	battle_stage.size_flags_vertical = Control.SIZE_EXPAND_FILL
	battle_stage.configure(session.snapshot(), enemy)
	center.add_child(battle_stage)
	battle_stage.sound.connect(ui.audio.cue)
	_corners(ui, battle_stage)
	var dock = preload("res://scripts/ui/battle_dock.gd").new()
	ui.battle_dock = dock
	dock.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	battle_stage.add_child(dock)
	dock.configure(ui)
	battle_stage.qi_view = dock
	if ui.battle_record_open:
		var record := PanelContainer.new()
		record.position = Vector2(24, 165)
		record.custom_minimum_size = Vector2(540, 160)
		record.add_theme_stylebox_override("panel", ui.style(Color(0.03, 0.07, 0.08, 0.94), Color("#8d915d"), 10))
		if ui.battle_secret_open:
			record.add_child(_secret_row(ui))
		else:
			var shown: Array = session.Combat.scout(session).lines if ui.battle_scout_open else session.journal_lines().slice(-RECORD_LINES)
			var lines: Label = ui.label("\n".join(shown), 14, ui.INK)
			lines.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
			lines.custom_minimum_size.x = 500
			record.add_child(lines)
		battle_stage.add_child(record)
	if not ui.battle_more_open and b.get("pack", []).is_empty():
		return
	var panel := PanelContainer.new()
	panel.set_anchors_and_offsets_preset(Control.PRESET_BOTTOM_RIGHT)
	panel.offset_left = -360
	panel.offset_right = -24
	panel.offset_top = -410
	panel.offset_bottom = -200
	panel.add_theme_stylebox_override("panel", ui.style(Color(0.03, 0.08, 0.07, 0.96), Color("#8d915d"), 10))
	battle_stage.add_child(panel)
	# The lesser controls (撤离, 祭出, targets, 求援, 记录, 探查) two abreast, so the dock stays low.
	var side := GridContainer.new()
	side.columns = 2
	side.add_theme_constant_override("h_separation", 4)
	side.add_theme_constant_override("v_separation", 4)
	panel.add_child(side)
	var quick: Button = ui.button("速战", func() -> void: ui.battle_action("quick"), "自动施展可用神通并结束回合")
	_small(quick)
	side.add_child(quick)
	for skill_id: String in session.active_skills().slice(10):
		var skill: Dictionary = session.held_technique(skill_id)
		var extra: Button = ui.button(skill.name, func() -> void: ui.skill(skill_id), skill.description)
		extra.disabled = not session.Combat.affordable(b.orbs, skill.cost)
		_small(extra)
		side.add_child(extra)
	for item_id: String in session.content.items:
		var item: Dictionary = session.content.item(item_id)
		if item.get("category", "") != "talisman" or session.item_count(item_id) <= 0:
			continue
		var charm: Button = ui.button("%s ×%d" % [item.name, session.item_count(item_id)], func() -> void: ui.battle_action("pill:" + item_id), item.description + "（符箓）")
		charm.disabled = not session.duel_pill_block(item_id).is_empty()
		_small(charm)
		side.add_child(charm)
	var odds := "比斗中随时可认输" if session.battle.get("context", "") in ["spar", "tournament", "summit", "arena", "tianji"] else "约 %d%% 能脱身，脱不了身便挨对手一回合" % int(round(session.Combat.flee_chance(session) * 100.0))
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
	var record_toggle: Button = ui.button("收起记录" if ui.battle_record_open and not ui.battle_scout_open and not ui.battle_secret_open else "记录", ui.toggle_battle_record, "这场斗法的最近几条记载")
	_small(record_toggle)
	side.add_child(record_toggle)
	var seen: bool = session.Combat.scout(session).seen
	if int(session.player.realm) >= 1 and not session.battle.get("context", "") in ["spar", "tournament", "summit", "arena", "tianji"]:
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

static func _number(value: float) -> String:
	return str(snappedf(value, 0.01))

## Over the stage: the player's shield and lingering effects at the top left, the opponent's intent,
## shield, effects and orbs at the top right.
static func _corners(ui, stage: Control) -> void:
	var session = ui.session
	var b: Dictionary = session.battle
	var mine := _effect_entries(int(b.get("shield", 0)), b.get("player_status", {}))
	var prepared := str(b.get("prepared_pill", ""))
	if not prepared.is_empty():
		mine.append({"key": "focus", "short": "药", "long": "%s · 战前药力已在开场吸气时生效" % session.content.item(prepared).name})
	if not mine.is_empty():
		var left := _corner(ui, stage, "", Color("#cfe9e1"), mine)
		left.set_anchors_and_offsets_preset(Control.PRESET_TOP_LEFT)
		left.position = Vector2(16, 60)
	var lines: Array[String] = ["对手下一回合：" + intent_text(session)]
	# 遁速: the quicker moves first and gets away more readily.
	lines.append("遁速 · 你 %d / 对手 %d%s" % [session.Combat.speed(session), session.Combat.foe_speed(session), "（对手抢得先手）" if bool(b.get("foe_led", false)) and int(b.turn) == 1 else ""])
	# 死斗: lost, the life ends (a save from its start is kept).
	if bool(b.get("deadly", false)):
		lines.append("死斗：落败即身死（已留劫前存档）")
	# 地利: the ground's favour for some elements, and a sect's own ground.
	var ground: String = session.Combat.ground_text(session)
	if not ground.is_empty():
		lines.append("地利 · " + ground)
	if not b.get("foe", {}).get("arts", []).is_empty():
		lines.append("灵气 %d" % b.get("foe_orbs", []).size())
	var right := _corner(ui, stage, "\n".join(lines), FOE_COLOR, _effect_entries(int(b.get("foe_shield", 0)), b.get("status", {})))
	right.set_anchors_and_offsets_preset(Control.PRESET_TOP_RIGHT)
	right.grow_horizontal = Control.GROW_DIRECTION_BEGIN
	right.offset_right = -16
	right.offset_top = 60

## A panel over a corner of the stage: lines of text, then the lingering effects as badges
## (assets/art/ui/status), each with its figure and turns, the full words when the pointer rests on it.
static func _corner(ui, stage: Control, text: String, color: Color, effects: Array = []) -> PanelContainer:
	var box := PanelContainer.new()
	box.mouse_filter = Control.MOUSE_FILTER_IGNORE
	box.add_theme_stylebox_override("panel", ui.style(Color(0.04, 0.09, 0.08, 0.65), Color(color, 0.2), 4))
	var column := VBoxContainer.new()
	column.add_theme_constant_override("separation", 6)
	column.mouse_filter = Control.MOUSE_FILTER_IGNORE
	box.add_child(column)
	if not text.is_empty():
		var words: Label = ui.label(text, 15, color)
		words.mouse_filter = Control.MOUSE_FILTER_IGNORE
		column.add_child(words)
	if not effects.is_empty():
		var row := HBoxContainer.new()
		row.add_theme_constant_override("separation", 12)
		row.mouse_filter = Control.MOUSE_FILTER_IGNORE
		column.add_child(row)
		for effect: Dictionary in effects:
			var item := HBoxContainer.new()
			item.add_theme_constant_override("separation", 4)
			item.tooltip_text = str(effect.long)
			item.mouse_filter = Control.MOUSE_FILTER_PASS
			var badge: TextureRect = ArtLibrary.icon_rect("status/" + str(effect.key), 28)
			badge.tooltip_text = str(effect.long)
			item.add_child(badge)
			var figure: Label = ui.label(str(effect.short), 14, color)
			figure.mouse_filter = Control.MOUSE_FILTER_PASS
			figure.tooltip_text = str(effect.long)
			item.add_child(figure)
			row.add_child(item)
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
				parts.append("蓄力：%s（下回合 %d–%d，可用护盾神通抵挡）" % [entry.name, int(entry.min), int(entry.max)])
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
	return "  ·  ".join(_effect_entries(shield, status).map(func(effect: Dictionary) -> String: return str(effect.long)))

## The shield and lingering effects: {"key" (its badge), "short" (the figure and turns beside it), "long"
## (the words, as the tooltip reads them)}.
static func _effect_entries(shield: int, status: Dictionary) -> Array:
	var parts: Array = []
	if shield > 0:
		parts.append({"key": "shield", "short": str(shield), "long": "护盾 %d：先替你挡下伤害" % shield})
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
			# Beside the badge only the figure: damage a turn, a share, or orbs short.
			var figure := str(int(value))
			if key in ["weaken", "wound"]:
				figure = "-%d%%" % int(round(value * 100))
			elif key in ["sunder", "focus", "fervor"]:
				figure = "+%d%%" % int(round(value * 100))
			elif key in ["slow", "entangle"]:
				figure = "-%d" % int(value)
			parts.append({"key": key, "short": "%s · %d" % [figure, int(status[key][1])], "long": "%s %s（余 %d 回合）" % [STATUS_NAMES[key], amount, int(status[key][1])]})
	return parts

static func _realm_bonus_text(session) -> String:
	var bonus: int = session.attack_bonus()
	return "\n境界加成：每耗一颗灵气，伤害 +%s。" % _number(bonus / 2.0) if bonus > 0 else ""
