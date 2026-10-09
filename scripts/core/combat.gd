extends RefCounted
## Turn-based duel rules. Operates on a Session; only the combat random stream is used here.

static func use_skill(s, skill_id: String) -> String:
	s.combat_events.clear()
	if s.battle.is_empty() or not s.content.skills.has(skill_id):
		return "当前无法施展神通。"
	if skill_id not in s.active_skills():
		return "尚未研习此门派神通。"
	var skill: Dictionary = s.content.skills[skill_id]
	if int(s.battle.cooldowns.get(skill_id, 0)) > 0:
		return "此神通仍在冷却。"
	if int(s.player.qi) < int(skill.qi_cost):
		return "灵力不足。"
	_tick_cooldowns(s)
	s.player.qi -= int(skill.qi_cost)
	s.battle.cooldowns[skill_id] = int(skill.cooldown)
	if skill.kind == "heal":
		var recovered := mini(int(skill.heal), int(s.player.max_hp) - int(s.player.hp))
		s.player.hp += recovered
		s.combat_events.append({"type": "heal", "amount": recovered, "hp_after": int(s.player.hp), "style": skill_id})
		s.log_event("skill_heal", {"skill": skill_id, "amount": recovered})
	elif skill.kind == "guard":
		var recovered := mini(int(skill.heal), int(s.player.max_hp) - int(s.player.hp))
		s.player.hp += recovered
		s.combat_events.append({"type": "guard", "style": skill_id, "amount": recovered, "hp_after": int(s.player.hp)})
		s.log_event("skill_guard", {"skill": skill_id, "amount": recovered})
		return _enemy_turn(s, true)
	else:
		var bonus := int(s.stage_stats().attack_bonus)
		var damage: int = s.combat_rng.randi_range(int(skill.damage_min), int(skill.damage_max)) + bonus
		s.battle.hp = maxi(0, int(s.battle.hp) - damage)
		s.combat_events.append({"type": "attack", "actor": "player", "style": skill_id, "amount": damage, "hp_after": int(s.battle.hp)})
		s.log_event("skill_attack", {"skill": skill_id, "amount": damage})
	if int(s.battle.hp) <= 0:
		return _win(s)
	return _enemy_turn(s, false)

static func defend(s) -> String:
	s.combat_events.clear()
	if s.battle.is_empty():
		return "当前没有对手。"
	_tick_cooldowns(s)
	var recovered := mini(6, int(s.player.max_qi) - int(s.player.qi))
	s.player.qi += recovered
	s.combat_events.append({"type": "guard", "amount": recovered, "sect": str(s.player.get("sect", "wanderer"))})
	s.log_event("defend", {"amount": recovered})
	return _enemy_turn(s, true)

static func flee(s) -> String:
	s.combat_events.clear()
	if s.battle.is_empty():
		return "当前无需撤退。"
	s.combat_events.append({"type": "end", "result": "flee"})
	var days := _recovery_days(s, "flee")
	s.battle.clear()
	# Outcomes are recorded on the day they happen; the recovery time follows.
	var message: String = s.log_event("flee", {"days": days})
	return s.conclude(message, s.advance_days(days))

## Duels started by events (road encounters, ruins) only cost a short rest afterwards.
static func _recovery_days(s, action: String) -> int:
	return s.content.action_days("road_recovery" if s.battle.get("context", "") == "event" else action)

static func _tick_cooldowns(s) -> void:
	for cooldown_id: String in s.battle.cooldowns:
		s.battle.cooldowns[cooldown_id] = maxi(0, int(s.battle.cooldowns[cooldown_id]) - 1)

static func _enemy_turn(s, guarding: bool) -> String:
	var enemy_id: String = s.battle.enemy_id
	var enemy: Dictionary = s.content.enemies[enemy_id]
	var damage: int = s.combat_rng.randi_range(int(enemy.damage_min), int(enemy.damage_max))
	if guarding:
		damage = maxi(1, damage / 2)
	s.player.hp = maxi(0, int(s.player.hp) - damage)
	s.combat_events.append({"type": "attack", "actor": "enemy", "style": _counter_style(s), "amount": damage, "hp_after": int(s.player.hp)})
	s.log_event("enemy_attack", {"enemy": enemy_id, "amount": damage})
	if int(s.player.hp) <= 0:
		s.combat_events.append({"type": "end", "result": "lose"})
		s.battle.clear()
		var lost := mini(int(s.player.stones), 10)
		s.player.stones -= lost
		s.player.location = "sect"
		s.player.journey = {}
		var message: String = s.log_event("battle_defeat", {"lost": lost})
		var passed: Dictionary = s.advance_days(s.content.action_days("battle_defeat"))
		s.player.hp = maxi(1, int(s.player.max_hp) / 2)
		s.player.qi = s.player.max_qi
		return s.conclude(message, passed)
	s.battle.turn += 1
	s.changed.emit()
	return "轮到你施展神通。"

static func _counter_style(s) -> String:
	if not bool(s.content.enemies[s.battle.enemy_id].get("human", false)):
		return "enemy"
	var sect_id: String = s.battle.get("opponent_sect", "qingyun")
	return str(s.content.sects[sect_id].skills[0])

static func _win(s) -> String:
	s.combat_events.append({"type": "end", "result": "win"})
	var enemy_id: String = s.battle.enemy_id
	var enemy: Dictionary = s.content.enemies[enemy_id]
	var days := _recovery_days(s, "battle_victory")
	var npc: String = s.battle.get("npc", "")
	s.player.stones += int(enemy.reward_stones)
	s.player.xp += int(enemy.reward_xp)
	s.player.herbs += int(enemy.reward_herbs)
	s.battle.clear()
	var message: String = s.log_event("battle_victory", {"enemy": enemy_id, "stones": int(enemy.reward_stones), "xp": int(enemy.reward_xp), "herbs": int(enemy.reward_herbs)})
	# A defeated regional threat changes the world; the journey itself continues.
	var flag: String = enemy.get("world_flag", "")
	if not flag.is_empty() and not s.has_flag(flag):
		s.world.flags[flag] = true
		message += " " + s.log_event(enemy.flag_event, {}, true)
	var milestones: Array[String] = s.settle_stage()
	if not milestones.is_empty():
		message += " " + " ".join(milestones)
	s.npc_depart(npc)
	return s.conclude(message, s.advance_days(days))
