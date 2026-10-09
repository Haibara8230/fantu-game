extends RefCounted
## Gameplay state and rules. No UI or filesystem dependency.
const Content = preload("res://scripts/core/content.gd")
const SAVE_VERSION := 1
signal changed
var content = Content.new()
var rng := RandomNumberGenerator.new()
var player: Dictionary = {}
var battle: Dictionary = {}
var journal: Array[String] = []
# Ephemeral presentation events; not part of the save format.
var combat_events: Array[Dictionary] = []

func _init() -> void:
	content.load_data()
	rng.randomize()

func new_game(character_name: String = "无名", seed_value: int = -1) -> void:
	if seed_value >= 0:
		rng.seed = seed_value
	var chosen_name := character_name.strip_edges().left(16)
	if chosen_name.is_empty():
		chosen_name = "无名"
	var rules: Dictionary = content.rules
	player = {
		"name": chosen_name, "month": 0, "realm": 0, "xp": 0,
		"hp": int(rules.starting_hp), "max_hp": int(rules.starting_hp),
		"qi": int(rules.starting_qi), "max_qi": int(rules.starting_qi),
		"stones": int(rules.starting_stones), "herbs": 0, "pills": 0,
		"location": "sect", "completed": false, "sect": "wanderer"
	}
	battle.clear()
	combat_events.clear()
	journal.clear()
	_record("你拜入青云山。先修炼功法、积攒灵石，再寻筑基之机。")
	changed.emit()

func _record(message: String) -> void:
	journal.append("【%d年%d月】%s" % [1 + int(player.month) / 12, 1 + int(player.month) % 12, message])
	if journal.size() > 100:
		journal.pop_front()

func _finish(message: String) -> String:
	_record(message)
	changed.emit()
	return message

func realm_name() -> String:
	return "筑基初期" if int(player.get("realm", 0)) == 1 else "炼气期"

func time_name() -> String:
	return "历元 %d 年 · %d 月" % [1 + int(player.get("month", 0)) / 12, 1 + int(player.get("month", 0)) % 12]

func act(action: String) -> String:
	if player.is_empty():
		return "请先创建角色。"
	if not battle.is_empty():
		return "斗法中无法进行此操作。"
	match action:
		"cultivate":
			if player.location != "sect":
				return "请返回青云山修炼。"
			player.month += 1
			player.xp += int(content.rules.cultivate_xp)
			player.qi = player.max_qi
			return _finish("闭关一月，修为增加 %d，灵力恢复。" % int(content.rules.cultivate_xp))
		"rest":
			if player.location != "sect":
				return "请返回青云山休整。"
			player.month += 1
			player.hp = player.max_hp
			player.qi = player.max_qi
			return _finish("静养一月，气血与灵力尽复。")
		"gather":
			if player.location != "wild":
				return "落霞谷中才有灵草。"
			player.month += 1
			var amount := rng.randi_range(int(content.rules.gather_min), int(content.rules.gather_max))
			player.herbs += amount
			return _finish("在山谷采得 %d 株灵草。" % amount)
		"sell":
			if player.location != "market":
				return "请前往坊市交易。"
			if int(player.herbs) == 0:
				return "背包中没有灵草。"
			var revenue := int(player.herbs) * int(content.rules.herb_price)
			player.stones += revenue
			player.herbs = 0
			return _finish("售出全部灵草，获得 %d 灵石。" % revenue)
		"buy_pill":
			if player.location != "market":
				return "请前往坊市购买丹药。"
			var price := int(content.rules.pill_price)
			if int(player.stones) < price:
				return "灵石不足：筑基丹需要 %d 灵石。" % price
			player.stones -= price
			player.pills += 1
			return _finish("花费 %d 灵石，购入一枚筑基丹。" % price)
		"breakthrough":
			if player.location != "sect":
				return "请返回青云山，在静室中突破。"
			if int(player.realm) >= 1:
				return "后续境界尚未开放，去落霞谷挑战妖蟒吧。"
			if int(player.xp) < int(content.rules.breakthrough_xp) or int(player.pills) < 1:
				return "突破需要 %d 修为与一枚筑基丹。" % int(content.rules.breakthrough_xp)
			player.pills -= 1
			player.xp -= int(content.rules.breakthrough_xp)
			player.month += 3
			player.realm = 1
			player.max_hp = int(content.rules.foundation_hp)
			player.max_qi = int(content.rules.foundation_qi)
			player.hp = player.max_hp
			player.qi = player.max_qi
			return _finish("闭关三月，丹田化海。你已筑基！前往落霞谷，寻找灵泉。")
	return "未知操作。"

func travel(location_id: String) -> String:
	if not battle.is_empty():
		return "斗法中无法离开。"
	if player.is_empty() or not content.locations.has(location_id):
		return "未知地点。"
	if player.location == location_id:
		return "你已在此处。"
	player.month += int(content.locations[location_id].travel_months)
	player.location = location_id
	return _finish("跋涉一月，抵达%s。" % content.locations[location_id].name)

func active_skills() -> Array[String]:
	var result: Array[String] = []
	for id: String in content.sects[player.get("sect", "wanderer")].skills:
		result.append(id)
	return result

func choose_sect(sect_id: String) -> String:
	if player.is_empty() or not content.sects.has(sect_id):
		return "未知门派。"
	if not battle.is_empty():
		return "斗法中无法更换传承。"
	if player.location != "sect":
		return "请返回青云山研习门派传承。"
	if player.get("sect", "wanderer") == sect_id:
		return "你已在研习此传承。"
	player.sect = sect_id
	return _finish("开始研习%s传承，神通已更换。" % content.sects[sect_id].name)

func start_battle(enemy_id: String, opponent_sect: String = "") -> String:
	if player.is_empty() or not battle.is_empty() or not content.enemies.has(enemy_id):
		return "当前无法开始斗法。"
	if (enemy_id == "disciple" and player.location != "sect") or (enemy_id != "disciple" and player.location != "wild"):
		return "此地没有这个对手。"
	if opponent_sect.is_empty():
		opponent_sect = str(player.get("sect", "wanderer"))
		if opponent_sect == "wanderer":
			opponent_sect = "qingyun"
	if not content.sects.has(opponent_sect):
		return "未知对手传承。"
	var enemy: Dictionary = content.enemies[enemy_id]
	if bool(enemy.boss) and int(player.realm) == 0:
		return "妖蟒气息凶险，请先筑基。"
	if bool(enemy.boss) and bool(player.completed):
		return "灵泉已安宁，妖蟒已经被你击败。"
	battle = {"enemy_id": enemy_id, "hp": int(enemy.hp), "turn": 1, "cooldowns": {}, "opponent_sect": opponent_sect}
	return _finish("与%s展开斗法。" % enemy.name)

func use_skill(skill_id: String) -> String:
	combat_events.clear()
	if battle.is_empty() or not content.skills.has(skill_id):
		return "当前无法施展神通。"
	if skill_id not in active_skills():
		return "尚未研习此门派神通。"
	var skill: Dictionary = content.skills[skill_id]
	if int(battle.cooldowns.get(skill_id, 0)) > 0:
		return "此神通仍在冷却。"
	if int(player.qi) < int(skill.qi_cost):
		return "灵力不足。"
	for cooldown_id: String in battle.cooldowns:
		battle.cooldowns[cooldown_id] = maxi(0, int(battle.cooldowns[cooldown_id]) - 1)
	player.qi -= int(skill.qi_cost)
	battle.cooldowns[skill_id] = int(skill.cooldown)
	if skill.kind == "heal":
		var recovered := mini(int(skill.heal), int(player.max_hp) - int(player.hp))
		player.hp += recovered
		combat_events.append({"type": "heal", "amount": recovered, "hp_after": int(player.hp), "style": skill_id})
		_record("施展%s，恢复 %d 气血。" % [skill.name, recovered])
	elif skill.kind == "guard":
		var recovered := mini(int(skill.heal), int(player.max_hp) - int(player.hp))
		player.hp += recovered
		combat_events.append({"type": "guard", "style": skill_id, "amount": recovered, "hp_after": int(player.hp)})
		_record("施展%s，恢复 %d 气血，本回合伤害减半。" % [skill.name, recovered])
		return _enemy_turn(true)
	else:
		var bonus := int(content.rules.foundation_attack_bonus) if int(player.realm) == 1 else 0
		var damage := rng.randi_range(int(skill.damage_min), int(skill.damage_max)) + bonus
		battle.hp = maxi(0, int(battle.hp) - damage)
		combat_events.append({"type": "attack", "actor": "player", "style": skill_id, "amount": damage, "hp_after": int(battle.hp)})
		_record("施展%s，造成 %d 点伤害。" % [skill.name, damage])
	if int(battle.hp) <= 0:
		return _win_battle()
	return _enemy_turn(false)

func defend() -> String:
	combat_events.clear()
	if battle.is_empty():
		return "当前没有对手。"
	for cooldown_id: String in battle.cooldowns:
		battle.cooldowns[cooldown_id] = maxi(0, int(battle.cooldowns[cooldown_id]) - 1)
	var recovered := mini(6, int(player.max_qi) - int(player.qi))
	player.qi += recovered
	combat_events.append({"type": "guard", "amount": recovered, "sect": str(player.get("sect", "wanderer"))})
	_record("凝神守御，恢复 %d 灵力，本回合受到的伤害减半。" % recovered)
	return _enemy_turn(true)

func _enemy_turn(guarding: bool) -> String:
	var enemy: Dictionary = content.enemies[battle.enemy_id]
	var damage := rng.randi_range(int(enemy.damage_min), int(enemy.damage_max))
	if guarding:
		damage = maxi(1, damage / 2)
	player.hp = maxi(0, int(player.hp) - damage)
	combat_events.append({"type": "attack", "actor": "enemy", "style": _counter_style(), "amount": damage, "hp_after": int(player.hp)})
	_record("%s反击，造成 %d 点伤害。" % [enemy.name, damage])
	if int(player.hp) <= 0:
		combat_events.append({"type": "end", "result": "lose"})
		battle.clear()
		var lost := mini(int(player.stones), 10)
		player.stones -= lost
		player.location = "sect"
		player.month += 1
		player.hp = maxi(1, int(player.max_hp) / 2)
		player.qi = player.max_qi
		return _finish("斗法落败，被救回青云山。损失 %d 灵石，静养后可再出发。" % lost)
	battle.turn += 1
	changed.emit()
	return "轮到你施展神通。"

func _counter_style() -> String:
	if battle.enemy_id != "disciple":
		return "enemy"
	var sect_id: String = battle.get("opponent_sect", "qingyun")
	return str(content.sects[sect_id].skills[0])

func _win_battle() -> String:
	combat_events.append({"type": "end", "result": "win"})
	var enemy: Dictionary = content.enemies[battle.enemy_id]
	player.stones += int(enemy.reward_stones)
	player.xp += int(enemy.reward_xp)
	player.herbs += int(enemy.reward_herbs)
	player.month += 1
	if bool(enemy.boss):
		player.completed = true
	battle.clear()
	var message := "斗法获胜，获得 %d 灵石、%d 修为、%d 灵草。" % [enemy.reward_stones, enemy.reward_xp, enemy.reward_herbs]
	if bool(enemy.boss):
		message += " 灵泉重现，你的第一段修仙旅程圆满落幕。仍可继续游历。"
	return _finish(message)

func flee() -> String:
	combat_events.clear()
	if battle.is_empty():
		return "当前无需撤退。"
	combat_events.append({"type": "end", "result": "flee"})
	battle.clear()
	player.month += 1
	return _finish("收起神通，撤出斗法。修为与物品保留，耗时一月。")

func snapshot() -> Dictionary:
	return {"version": SAVE_VERSION, "player": player.duplicate(true), "battle": battle.duplicate(true), "journal": journal.duplicate(), "rng_state": str(rng.state)}

func restore(data: Dictionary) -> bool:
	# Validate before changing the current session.
	if not _whole_nonnegative(data.get("version")) or int(data.version) != SAVE_VERSION:
		return false
	var saved_player: Variant = data.get("player")
	var saved_battle: Variant = data.get("battle")
	var saved_journal: Variant = data.get("journal")
	if not saved_player is Dictionary or not saved_battle is Dictionary or not saved_journal is Array:
		return false
	if not saved_player.get("name") is String or not saved_player.get("location") is String or not saved_player.get("completed") is bool:
		return false
	for key: String in ["month", "realm", "xp", "hp", "max_hp", "qi", "max_qi", "stones", "herbs", "pills"]:
		if not _whole_nonnegative(saved_player.get(key)):
			return false
	if int(saved_player.realm) > 1 or not content.locations.has(saved_player.location):
		return false
	var expected_hp := int(content.rules.foundation_hp) if int(saved_player.realm) == 1 else int(content.rules.starting_hp)
	var expected_qi := int(content.rules.foundation_qi) if int(saved_player.realm) == 1 else int(content.rules.starting_qi)
	if int(saved_player.max_hp) != expected_hp or int(saved_player.max_qi) != expected_qi:
		return false
	if int(saved_player.hp) <= 0 or int(saved_player.hp) > expected_hp or int(saved_player.qi) > expected_qi:
		return false
	if not saved_battle.is_empty():
		if not saved_battle.get("enemy_id") is String or not content.enemies.has(saved_battle.enemy_id):
			return false
		if not _whole_nonnegative(saved_battle.get("hp")) or int(saved_battle.hp) <= 0 or int(saved_battle.hp) > int(content.enemies[saved_battle.enemy_id].hp):
			return false
		if not _whole_nonnegative(saved_battle.get("turn")) or int(saved_battle.turn) < 1 or not saved_battle.get("cooldowns") is Dictionary:
			return false
		for skill_id: Variant in saved_battle.cooldowns:
			if not content.skills.has(skill_id) or not _whole_nonnegative(saved_battle.cooldowns[skill_id]):
				return false
	var saved_sect: Variant = saved_player.get("sect", "wanderer")
	if not saved_sect is String or not content.sects.has(saved_sect):
		return false
	var opponent_sect: Variant = saved_battle.get("opponent_sect", "qingyun")
	if not saved_battle.is_empty() and (not opponent_sect is String or not content.sects.has(opponent_sect)):
		return false
	var saved_rng: Variant = data.get("rng_state")
	if not saved_rng is String or not saved_rng.is_valid_int():
		return false
	var safe_journal: Array[String] = []
	for entry: Variant in saved_journal:
		if not entry is String:
			return false
		safe_journal.append(entry.left(1000))
	if safe_journal.size() > 100:
		safe_journal = safe_journal.slice(safe_journal.size() - 100)
	player = saved_player.duplicate(true)
	player.sect = saved_sect
	for key: String in ["month", "realm", "xp", "hp", "max_hp", "qi", "max_qi", "stones", "herbs", "pills"]:
		player[key] = int(player[key])
	battle = saved_battle.duplicate(true)
	if not battle.is_empty():
		battle.opponent_sect = opponent_sect
		battle.hp = int(battle.hp)
		battle.turn = int(battle.turn)
		for skill_id: String in battle.cooldowns:
			battle.cooldowns[skill_id] = int(battle.cooldowns[skill_id])
	journal = safe_journal
	rng.state = int(saved_rng)
	combat_events.clear()
	changed.emit()
	return true

func _whole_nonnegative(value: Variant) -> bool:
	if not (value is int or value is float):
		return false
	return is_finite(float(value)) and float(value) >= 0.0 and float(value) == floor(float(value)) and float(value) <= 1000000000.0
