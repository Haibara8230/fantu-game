extends RefCounted
## Gameplay state and rules. No UI or filesystem dependency.
const Content = preload("res://scripts/core/content.gd")
const Calendar = preload("res://scripts/core/calendar.gd")
const Chronicle = preload("res://scripts/core/chronicle.gd")
const Combat = preload("res://scripts/core/combat.gd")
const SaveMigration = preload("res://scripts/core/save_migration.gd")
const SAVE_VERSION := SaveMigration.CURRENT_VERSION
const PLAYER_COUNTS := ["realm", "xp", "hp", "qi", "stones", "herbs", "pills"]
const LIMIT := 1000000000.0
signal changed
var content = Content.new()
# Separate streams: world-side draws (gathering, later simulation) never shift duel results.
var combat_rng := RandomNumberGenerator.new()
var world_rng := RandomNumberGenerator.new()
var world: Dictionary = {}
var player: Dictionary = {}
var battle: Dictionary = {}
var chronicle = Chronicle.new()
# Ephemeral presentation events; not part of the save format.
var combat_events: Array[Dictionary] = []

func _init() -> void:
	content.load_data()
	combat_rng.randomize()
	world_rng.randomize()

func new_game(character_name: String = "无名", seed_value: int = -1) -> void:
	if seed_value >= 0:
		combat_rng.seed = seed_value
		world_rng.seed = hash(str(seed_value) + ":world")
	var chosen_name := character_name.strip_edges().left(16)
	if chosen_name.is_empty():
		chosen_name = "无名"
	world = {"day": 0, "flags": {}}
	player = {
		"name": chosen_name, "birth_day": -int(content.rules.starting_age) * Calendar.DAYS_PER_YEAR,
		"realm": 0, "xp": 0, "hp": 0, "qi": 0,
		"stones": int(content.rules.starting_stones), "herbs": 0, "pills": 0,
		"location": "sect", "sect": "wanderer"
	}
	_refresh_realm_stats()
	player.hp = player.max_hp
	player.qi = player.max_qi
	battle.clear()
	combat_events.clear()
	chronicle.clear()
	log_event("start", {}, true)
	changed.emit()

## The single entry point that moves world time. Later milestones process due events here.
func advance_days(days: int) -> void:
	assert(days >= 0, "time cannot move backwards")
	world.day = int(world.day) + maxi(0, days)

## Records a chronicle entry and returns its display text.
func log_event(id: String, args: Dictionary = {}, major: bool = false) -> String:
	return chronicle.format(chronicle.add(int(world.day), id, args, major), content)

func finish(message: String) -> String:
	changed.emit()
	return message

func journal_lines() -> Array[String]:
	return chronicle.lines(content)

func has_flag(flag: String) -> bool:
	return bool(world.get("flags", {}).get(flag, false))

func realm_name() -> String:
	return content.realm(int(player.get("realm", 0))).name

func time_name() -> String:
	return Calendar.date_text(int(world.get("day", 0)))

func age() -> int:
	return Calendar.age_years(int(player.birth_day), int(world.day))

func lifespan() -> int:
	return int(content.realm(int(player.realm)).lifespan_years)

## Requirements to leave the current realm, or an empty Dictionary at the highest open realm.
func next_breakthrough() -> Dictionary:
	var current: Dictionary = content.realm(int(player.realm))
	if int(player.realm) + 1 >= content.realms.size() or not current.has("breakthrough"):
		return {}
	return current.breakthrough

func _refresh_realm_stats() -> void:
	var current: Dictionary = content.realm(int(player.realm))
	player.max_hp = int(current.max_hp)
	player.max_qi = int(current.max_qi)

func act(action: String) -> String:
	if player.is_empty():
		return "请先创建角色。"
	if not battle.is_empty():
		return "斗法中无法进行此操作。"
	var days := content.action_days(action)
	match action:
		"cultivate":
			if player.location != "sect":
				return "请返回青云山修炼。"
			advance_days(days)
			player.xp += int(content.rules.cultivate_xp)
			player.qi = player.max_qi
			return finish(log_event("cultivate", {"days": days, "xp": int(content.rules.cultivate_xp)}))
		"rest":
			if player.location != "sect":
				return "请返回青云山休整。"
			advance_days(days)
			player.hp = player.max_hp
			player.qi = player.max_qi
			return finish(log_event("rest", {"days": days}))
		"gather":
			if player.location != "wild":
				return "落霞谷中才有灵草。"
			advance_days(days)
			var amount := world_rng.randi_range(int(content.rules.gather_min), int(content.rules.gather_max))
			player.herbs += amount
			return finish(log_event("gather", {"days": days, "amount": amount}))
		"sell":
			if player.location != "market":
				return "请前往坊市交易。"
			if int(player.herbs) == 0:
				return "背包中没有灵草。"
			var revenue := int(player.herbs) * int(content.rules.herb_price)
			advance_days(days)
			player.stones += revenue
			player.herbs = 0
			return finish(log_event("sell", {"revenue": revenue}))
		"buy_pill":
			if player.location != "market":
				return "请前往坊市购买丹药。"
			var price := int(content.rules.pill_price)
			if int(player.stones) < price:
				return "灵石不足：筑基丹需要 %d 灵石。" % price
			advance_days(days)
			player.stones -= price
			player.pills += 1
			return finish(log_event("buy_pill", {"price": price}))
		"breakthrough":
			if player.location != "sect":
				return "请返回青云山，在静室中突破。"
			var need := next_breakthrough()
			if need.is_empty():
				return "后续境界尚未开放。"
			if int(player.xp) < int(need.xp) or int(player.pills) < int(need.pills):
				return "突破需要 %d 修为与 %d 枚筑基丹。" % [int(need.xp), int(need.pills)]
			player.pills -= int(need.pills)
			player.xp -= int(need.xp)
			advance_days(days)
			player.realm += 1
			_refresh_realm_stats()
			player.hp = player.max_hp
			player.qi = player.max_qi
			return finish(log_event("breakthrough", {"days": days, "realm": int(player.realm)}, true))
	return "未知操作。"

func travel(location_id: String) -> String:
	if not battle.is_empty():
		return "斗法中无法离开。"
	if player.is_empty() or not content.locations.has(location_id):
		return "未知地点。"
	if player.location == location_id:
		return "你已在此处。"
	var days := content.route_days(player.location, location_id)
	if days < 0:
		return "两地之间没有可走的路。"
	advance_days(days)
	player.location = location_id
	return finish(log_event("travel", {"days": days, "location": location_id}))

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
	return finish(log_event("choose_sect", {"sect": sect_id}, true))

func start_battle(enemy_id: String, opponent_sect: String = "") -> String:
	if player.is_empty() or not battle.is_empty() or not content.enemies.has(enemy_id):
		return "当前无法开始斗法。"
	var enemy: Dictionary = content.enemies[enemy_id]
	if not player.location in enemy.locations:
		return "此地没有这个对手。"
	if opponent_sect.is_empty():
		opponent_sect = str(player.get("sect", "wanderer"))
		if opponent_sect == "wanderer":
			opponent_sect = "qingyun"
	if not content.sects.has(opponent_sect):
		return "未知对手传承。"
	if int(player.realm) < int(enemy.min_realm):
		return "%s气息凶险，需达到%s。" % [enemy.name, content.realm(int(enemy.min_realm)).name]
	if enemy.has("world_flag") and has_flag(enemy.world_flag):
		return "%s已经伏诛，此地重归安宁。" % enemy.name
	battle = {"enemy_id": enemy_id, "hp": int(enemy.hp), "turn": 1, "cooldowns": {}, "opponent_sect": opponent_sect}
	return finish(log_event("battle_start", {"enemy": enemy_id}))

func use_skill(skill_id: String) -> String:
	return Combat.use_skill(self, skill_id)

func defend() -> String:
	return Combat.defend(self)

func flee() -> String:
	return Combat.flee(self)

func snapshot() -> Dictionary:
	return {
		"version": SAVE_VERSION, "world": world.duplicate(true), "player": player.duplicate(true),
		"battle": battle.duplicate(true), "chronicle": chronicle.to_save(),
		"rng": {"combat": str(combat_rng.state), "world": str(world_rng.state)}
	}

func restore(data: Variant) -> bool:
	# Upgrade older versions first, then validate everything before changing the current session.
	if not data is Dictionary:
		return false
	var saved: Dictionary = SaveMigration.migrate(data)
	if saved.is_empty() or int(saved.version) != SAVE_VERSION:
		return false
	var saved_world: Variant = saved.get("world")
	var saved_player: Variant = saved.get("player")
	var saved_battle: Variant = saved.get("battle")
	var saved_rng: Variant = saved.get("rng")
	if not saved_world is Dictionary or not saved_player is Dictionary or not saved_battle is Dictionary or not saved_rng is Dictionary:
		return false
	if not _whole_nonnegative(saved_world.get("day")) or not saved_world.get("flags") is Dictionary:
		return false
	var day := int(saved_world.day)
	for flag: Variant in saved_world.flags:
		if not flag is String or not saved_world.flags[flag] is bool:
			return false
	if not saved_player.get("name") is String or not saved_player.get("location") is String or not content.locations.has(saved_player.location):
		return false
	for key: String in PLAYER_COUNTS:
		if not _whole_nonnegative(saved_player.get(key)):
			return false
	var birth: Variant = saved_player.get("birth_day")
	if not (birth is int or birth is float) or not is_finite(float(birth)) or float(birth) != floor(float(birth)) or absf(float(birth)) > LIMIT or int(birth) > day:
		return false
	if int(saved_player.realm) >= content.realms.size():
		return false
	var realm: Dictionary = content.realm(int(saved_player.realm))
	if int(saved_player.hp) <= 0 or int(saved_player.hp) > int(realm.max_hp) or int(saved_player.qi) > int(realm.max_qi):
		return false
	var saved_sect: Variant = saved_player.get("sect")
	if not saved_sect is String or not content.sects.has(saved_sect):
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
		var opponent: Variant = saved_battle.get("opponent_sect")
		if not opponent is String or not content.sects.has(opponent):
			return false
	for stream: String in ["combat", "world"]:
		if not saved_rng.get(stream) is String or not saved_rng[stream].is_valid_int():
			return false
	var saved_chronicle: Variant = Chronicle.parse(saved.get("chronicle"), day)
	if saved_chronicle == null:
		return false
	world = {"day": day, "flags": saved_world.flags.duplicate()}
	player = saved_player.duplicate(true)
	for key: String in PLAYER_COUNTS:
		player[key] = int(player[key])
	player.birth_day = int(birth)
	_refresh_realm_stats()
	battle = saved_battle.duplicate(true)
	if not battle.is_empty():
		battle.hp = int(battle.hp)
		battle.turn = int(battle.turn)
		for skill_id: String in battle.cooldowns:
			battle.cooldowns[skill_id] = int(battle.cooldowns[skill_id])
	chronicle.entries = saved_chronicle
	combat_rng.state = int(saved_rng.combat)
	world_rng.state = int(saved_rng.world)
	combat_events.clear()
	changed.emit()
	return true

func _whole_nonnegative(value: Variant) -> bool:
	if not (value is int or value is float):
		return false
	return is_finite(float(value)) and float(value) >= 0.0 and float(value) == floor(float(value)) and float(value) <= LIMIT
