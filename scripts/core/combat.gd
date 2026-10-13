extends RefCounted
## Turn-based duel rules. Operates on a Session; only the combat random stream is used here.

static func start_battle(s, enemy_id: String, opponent_sect: String = "") -> String:
	if not s.blocked().is_empty() or not s.content.enemies.has(enemy_id):
		return "当前无法开始斗法。"
	var enemy: Dictionary = s.content.enemies[enemy_id]
	if not s.available_here("battle:" + enemy_id):
		return "此地没有这个对手。"
	if not opponent_sect.is_empty() and not s.content.sects.has(opponent_sect):
		return "未知对手传承。"
	if int(s.player.realm) < int(enemy.min_realm):
		return "%s气息凶险，需达到%s。" % [enemy.name, s.content.realm_title(int(enemy.min_realm), 0)]
	if enemy.has("world_flag") and s.has_flag(enemy.world_flag):
		return "%s已经伏诛，此地重归安宁。" % enemy.name
	return s.finish(begin_battle(s, enemy_id, "", opponent_sect))

## Starts a duel without location checks; used by spots and by event effects (context "event").
static func begin_battle(s, enemy_id: String, context: String = "", opponent_sect: String = "") -> String:
	var enemy: Dictionary = s.content.enemies[enemy_id]
	if opponent_sect.is_empty():
		opponent_sect = str(enemy.get("sect", s.player.get("sect", "wanderer")))
		if opponent_sect == "wanderer":
			opponent_sect = "qingyun"
	var hp := int(enemy.hp)
	# A foe whose weakness the player has prepared (the serpent after 破鳞散) starts the duel hurt.
	var weakened: Dictionary = enemy.get("weakened_by", {})
	if not weakened.is_empty() and s.has_flag(weakened.flag):
		hp = maxi(1, hp * int(weakened.hp_percent) / 100)
	s.battle = {"enemy_id": enemy_id, "hp": hp, "turn": 1, "cooldowns": {}, "opponent_sect": opponent_sect, "status": {}, "place": _battle_place(s)}
	if not context.is_empty():
		s.battle.context = context
	return s.log_event("battle_start", {"enemy": enemy_id})

## A friendly bout with a generated person: their stage's health and their best art, nothing at stake.
static func begin_spar(s, person_id: String) -> void:
	var someone: Dictionary = s.person(person_id)
	var foe: Dictionary = s.Population.foe(s.content, person_id, someone)
	var lineage: String = str(someone.get("sect", "qingyun"))
	s.battle = {"enemy_id": "cultivator", "hp": int(foe.hp), "turn": 1, "cooldowns": {}, "opponent_sect": "qingyun" if lineage == "wanderer" else lineage, "status": {}, "context": "spar", "npc": person_id, "foe": foe, "place": _battle_place(s)}
	s.log_event("spar_start", {"npc": person_id})

## A tournament round against the sect's outer disciples present, weakest first.
static func begin_tournament(s, round: int) -> void:
	var disciples: Array = s.present_npcs().filter(func(person_id: String) -> bool: return s.is_generated(person_id) and s.person(person_id).kind == "disciple")
	disciples.sort_custom(func(a: String, b: String) -> bool:
		var ra := int(s.person(a).realm) * 10 + int(s.person(a).stage)
		var rb := int(s.person(b).realm) * 10 + int(s.person(b).stage)
		return ra < rb or (ra == rb and a < b))
	if disciples.is_empty():
		begin_battle(s, "disciple", "event")
		s.battle.context = "tournament"
		s.battle.round = round
		return
	var opponent: String = disciples[clampi(round - 1 + disciples.size() / 3 * (round - 1), 0, disciples.size() - 1)]
	begin_spar(s, opponent)
	s.battle.context = "tournament"
	s.battle.round = round

## Where a duel is fought, for its backdrop: "road" while a road encounter is open, otherwise here.
static func _battle_place(s) -> String:
	if not s.pending_event.is_empty() and str(s.content.events[s.pending_event.id].get("trigger", "")) == "route":
		return "road"
	return str(s.player.location)

static func use_skill(s, skill_id: String) -> String:
	s.combat_events.clear()
	var t: Dictionary = s.content.technique(skill_id)
	if s.battle.is_empty() or t.is_empty() or t.slot != "art":
		return "当前无法施展神通。"
	if skill_id not in s.active_skills():
		return "此神通未在运转。"
	if int(s.battle.cooldowns.get(skill_id, 0)) > 0:
		return "此神通仍在冷却。"
	if int(s.player.qi) < int(t.qi_cost):
		return "灵力不足。"
	_tick_cooldowns(s)
	s.player.qi -= int(t.qi_cost)
	s.battle.cooldowns[skill_id] = int(t.cooldown)
	var look := {"style": skill_id, "name": t.name, "vfx": t.vfx, "tier": int(t.tier), "element": t.element}
	# A sect's own art cast by its disciple carries the lineage's signature layer.
	var lineage: String = s.content.legacy_sect(skill_id, str(s.player.get("sect", "wanderer")))
	if not lineage.is_empty():
		look.legacy = lineage
	var guarding := false
	match str(t.kind):
		"heal", "guard":
			var recovered := mini(int(t.heal), int(s.player.max_hp) - int(s.player.hp))
			s.player.hp += recovered
			guarding = t.kind == "guard"
			s.combat_events.append(_event({"type": t.kind, "amount": recovered, "hp_after": int(s.player.hp)}, look))
			s.log_event("skill_guard" if guarding else "skill_heal", {"skill": skill_id, "amount": recovered})
		_:
			var roll: int = s.combat_rng.randi_range(int(t.damage_min), int(t.damage_max)) + s.attack_bonus()
			var damage := maxi(1, int(round(float(roll) * s.element_multiplier(t))))
			s.battle.hp = maxi(0, int(s.battle.hp) - damage)
			s.combat_events.append(_event({"type": "attack", "actor": "player", "hits": int(t.hits), "amount": damage, "hp_after": int(s.battle.hp)}, look))
			s.log_event("skill_attack", {"skill": skill_id, "amount": damage})
			if t.has("lifesteal"):
				var healed := mini(int(round(damage * float(t.lifesteal))), int(s.player.max_hp) - int(s.player.hp))
				if healed > 0:
					s.player.hp += healed
					s.combat_events.append(_event({"type": "heal", "amount": healed, "hp_after": int(s.player.hp)}, look))
			for status: String in ["burn", "weaken"]:
				if t.has(status):
					s.battle.status[status] = t[status].duplicate()
	if t.has("qi_gain"):
		s.player.qi = mini(int(s.player.max_qi), int(s.player.qi) + int(t.qi_gain))
	if int(s.battle.hp) <= 0:
		return _win(s)
	return _enemy_turn(s, guarding)

## Presentation fields travel with each event, so generated techniques need no lookup tables.
static func _event(fields: Dictionary, look: Dictionary) -> Dictionary:
	var event := look.duplicate()
	event.merge(fields, true)
	return event

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
	# Lingering effects on the opponent act first: burning can finish a fight.
	var status: Dictionary = s.battle.get("status", {})
	if status.has("burn"):
		var burn: Array = status.burn
		s.battle.hp = maxi(0, int(s.battle.hp) - int(burn[0]))
		s.combat_events.append({"type": "attack", "actor": "player", "style": "burn", "name": "灼烧", "vfx": "flame_bolt", "tier": 1, "hits": 1, "amount": int(burn[0]), "hp_after": int(s.battle.hp)})
		_count_down(status, "burn")
		if int(s.battle.hp) <= 0:
			return _win(s)
	var foe: Dictionary = s.battle.get("foe", {})
	var stats: Dictionary = foe if not foe.is_empty() else enemy
	var damage: int = s.combat_rng.randi_range(int(stats.damage_min), int(stats.damage_max))
	var factor: float = 1.0 - s.defense()
	if status.has("weaken"):
		factor *= 1.0 - float(status.weaken[0])
		_count_down(status, "weaken")
	damage = maxi(1, int(round(float(damage) * factor)))
	if guarding:
		damage = maxi(1, damage / 2)
	s.player.hp = maxi(0, int(s.player.hp) - damage)
	var counter := {"type": "attack", "actor": "enemy", "style": _counter_style(s), "amount": damage, "hp_after": int(s.player.hp)}
	if not foe.is_empty():
		counter.merge({"style": foe.art, "name": foe.art_name, "vfx": foe.vfx, "tier": int(foe.tier)}, true)
	s.combat_events.append(counter)
	s.log_event("enemy_attack", {"enemy": enemy_id, "amount": damage})
	if int(s.player.hp) <= 0:
		s.combat_events.append({"type": "end", "result": "lose"})
		if s.battle.get("context", "") == "spar":
			return _spar_over(s, false)
		if s.battle.get("context", "") == "tournament":
			return _tournament_over(s, false)
		s.battle.clear()
		s.record_deed("duel")
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

## A spar ends without loss: the loser keeps a sliver of health, both sides gain a little.
static func _spar_over(s, won: bool) -> String:
	var npc: String = s.battle.npc
	var xp: int = int(s.battle.foe.xp) if won else int(s.battle.foe.xp) / 2
	s.battle.clear()
	s.record_deed("duel")
	s.player.hp = maxi(int(s.player.hp), 1)
	s.Events.apply(s, [{"relation": [npc, 5 if won else 2]}])
	var message: String = s.log_event("spar_win" if won else "spar_lose", {"npc": npc, "xp": xp})
	message = _with_milestones(message, s.gain_insight("spar"))
	message = _with_milestones(message, s.gain_xp(xp))
	if won:
		message = _with_milestones(message, s.Fortune.after_win(s, int(s.person(npc).get("realm", 0))))
	return s.conclude(message, s.advance_days(s.content.action_days("road_recovery")))

static func _with_milestones(message: String, milestones: Array[String]) -> String:
	return message if milestones.is_empty() else message + " " + " ".join(milestones)

## Tournament rounds: a win leads straight into the next round with some health back; the third
## win takes the prize. A loss ends the run without any penalty. Every round counts as a spar's insight.
static func _tournament_over(s, won: bool) -> String:
	var round: int = int(s.battle.get("round", 1))
	var npc: String = s.battle.get("npc", "")
	s.battle.clear()
	s.record_deed("duel")
	if not won:
		s.player.hp = maxi(int(s.player.hp), 1)
		var out: String = s.log_event("tournament_out", {"round": round, "npc": npc})
		return s.conclude(_with_milestones(out, s.gain_insight("spar")), s.advance_days(s.content.action_days("road_recovery")))
	var message: String = _with_milestones(s.log_event("tournament_round", {"round": round, "npc": npc}), s.gain_insight("spar"))
	if round < 3:
		s.player.hp = mini(int(s.player.max_hp), int(s.player.hp) + int(s.player.max_hp) * 3 / 10)
		s.player.qi = mini(int(s.player.max_qi), int(s.player.qi) + int(s.player.max_qi) * 3 / 10)
		s.begin_tournament(round + 1)
		s.changed.emit()
		return message + " 下一轮开始。"
	var prize: String = "j:" + s.Arsenal.generate_technique(s.content, s.world_rng, 2, {"slot": "art"})
	s.add_item(prize, 1)
	s.player.stones += 100
	message += " " + s.log_event("tournament_champion", {"stones": 100, "xp": 150, "item": prize}, true)
	s.record_deed("tournament_champion")
	message = _with_milestones(message, s.gain_xp(150))
	message = _with_milestones(message, s.congratulate("champion"))
	return s.conclude(message, s.advance_days(s.content.action_days("road_recovery")))

static func _count_down(status: Dictionary, key: String) -> void:
	status[key][1] = int(status[key][1]) - 1
	if int(status[key][1]) <= 0:
		status.erase(key)

static func _counter_style(s) -> String:
	if not bool(s.content.enemies[s.battle.enemy_id].get("human", false)):
		return "enemy"
	var sect_id: String = s.battle.get("opponent_sect", "qingyun")
	return str(s.content.sects[sect_id].skills[0])

static func _win(s) -> String:
	s.combat_events.append({"type": "end", "result": "win"})
	if s.battle.get("context", "") == "spar":
		return _spar_over(s, true)
	if s.battle.get("context", "") == "tournament":
		return _tournament_over(s, true)
	var enemy_id: String = s.battle.enemy_id
	var enemy: Dictionary = s.content.enemies[enemy_id]
	var days := _recovery_days(s, "battle_victory")
	var npc: String = s.battle.get("npc", "")
	s.record_kill(enemy_id)
	s.record_deed("duel")
	s.record_deed("win:" + enemy_id)
	s.player.stones += int(enemy.reward_stones)
	s.add_item("huichun_grass", int(enemy.reward_herbs))
	s.battle.clear()
	var message: String = s.log_event("battle_victory", {"enemy": enemy_id, "stones": int(enemy.reward_stones), "xp": int(enemy.reward_xp), "herbs": int(enemy.reward_herbs)})
	# A defeated regional threat changes the world; the journey itself continues.
	var flag: String = enemy.get("world_flag", "")
	if not flag.is_empty() and not s.has_flag(flag):
		s.world.flags[flag] = true
		message += " " + s.log_event(enemy.flag_event, {}, true)
		if enemy.has("congrats"):
			message = _with_milestones(message, s.congratulate(str(enemy.congrats)))
	if enemy.has("drops") and s.world_rng.randf() < float(enemy.drops.chance):
		var tier: int = s.world_rng.randi_range(int(enemy.drops.tiers[0]), int(enemy.drops.tiers[1]))
		var loot: String = "j:" + s.Arsenal.generate_technique(s.content, s.world_rng, tier) if s.world_rng.randf() < 0.5 else s.Arsenal.generate_equipment(s.content, s.world_rng, tier)
		s.add_item(loot, 1)
		message += " " + s.log_event("loot", {"loot": loot + ":1"})
	message = _with_milestones(message, s.gain_insight("battle_win"))
	message = _with_milestones(message, s.gain_xp(int(enemy.reward_xp)))
	# Won with almost nothing left against a foe of one's own realm or above: perhaps 生死之间.
	message = _with_milestones(message, s.Fortune.after_win(s, int(enemy.min_realm)))
	s.npc_depart(npc)
	return s.conclude(message, s.advance_days(days))
