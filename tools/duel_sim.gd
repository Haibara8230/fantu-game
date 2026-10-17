extends SceneTree
## Duel balance under the qi-orb rules, headless: many fights of a fresh character (and of one at
## foundation) against the opponents near them, played by the plain policy (Combat.plain_turn: heal
## when low, otherwise the strongest affordable arts, 相生 idle orbs, end the turn). Prints turns, win
## rate and health left per opponent.
const Session = preload("res://scripts/core/session.gd")
const SERIES := [["beast_tide", "town", 1, 0, ["qingyun"]], ["beast_tide", "town", 1, 1, ["qingyun"]], ["beast_tide", "town", 1, 1, []], ["beast_tide", "town", 1, 2, []], ["escort_qingshi", "town", 0, 1, []], ["escort_qingshi", "town", 0, 2, []], ["escort_qingshi", "town", 0, 2, ["qingyun"]], ["escort_qingshi", "town", 0, 3, ["qingyun"]], ["escort_nanming", "nanming", 1, 2, ["qingyun"]], ["escort_nanming", "nanming", 1, 3, []]]
const ROOTS := [["metal", "wood", "fire"], ["water", "earth"], ["metal"], ["wood", "water", "fire", "earth"], ["fire", "earth", "metal"]]

func _initialize() -> void:
	# Focused early-game sample for polish work; the broad simulation remains available by default.
	if OS.get_environment("FANTU_SIM") == "polish":
		for setup: Array in [["wolf",0,0,[]],["qinglin_snake",0,0,[]],["wolf_pack",0,2,[]],["rogue",0,2,[]],["serpent",1,0,[]],["serpent",1,0,["qingyun"]]]:
			_report(str(setup[0]), int(setup[1]), int(setup[2]), setup[3])
		_report("serpent",1,0,[],true)
		quit(0)
		return
	# FANTU_SIM=series runs only the series (and their bosses), for quick calibration.
	if OS.get_environment("FANTU_SIM") == "series":
		for setup: Array in [["bear_king", 1, 1, ["qingyun"]], ["bear_king", 1, 2, []], ["chixiao_zhifa", 2, 0, ["qingyun"]], ["chixiao_zhifa", 2, 0, []], ["chixiao_zhifa", 2, 1, ["qingyun"]], ["mo_xiu", 2, 0, ["qingyun"]]]:
			_report(str(setup[0]), int(setup[1]), int(setup[2]), setup[3])
		for setup: Array in SERIES:
			_series(str(setup[0]), str(setup[1]), int(setup[2]), int(setup[3]), setup[4])
		for setup: Array in [["tribulation_core", 1, 3], ["tribulation_nascent", 2, 3], ["tribulation_deity", 3, 3], ["demon", 0, 3], ["demon", 1, 3], ["demon", 2, 3]]:
			_trial(str(setup[0]), int(setup[1]), int(setup[2]))
		quit(0)
		return
	for setup: Array in [["wolf", 0, 0, []], ["disciple", 0, 0, []], ["rogue", 0, 2, []], ["wolf", 0, 3, ["qingyun"]], ["serpent", 1, 0, ["qingyun"]], ["serpent", 1, 0, []], ["ruin_rogue", 0, 3, ["qingyun"]], ["ruin_rogue", 0, 3, []], ["den_wolf", 0, 3, []], ["den_wolf", 0, 3, ["qingyun"]], ["mo_xiu", 2, 0, ["qingyun"]], ["mo_xiu", 2, 0, []], ["jian_kui", 2, 1, ["qingyun"]], ["can_nian", 2, 2, ["qingyun"]], ["can_nian", 2, 3, []], ["mo_jiang", 2, 3, ["qingyun"]], ["mo_jiang", 3, 0, ["qingyun"]], ["jiao", 3, 0, ["qingyun"]], ["jiao", 3, 1, []], ["qinglin_snake", 0, 0, []], ["shan_xiao", 0, 1, []], ["wolf_pack", 0, 2, []], ["wolf_pack", 0, 3, ["qingyun"]], ["chilian_snake", 1, 0, ["qingyun"]], ["huo_ya", 1, 1, ["qingyun"]], ["yanjia_xi", 1, 2, ["qingyun"]], ["yanjia_xi", 1, 1, []], ["zhui_bing", 0, 2, []], ["shui_fei", 1, 0, ["qingyun"]], ["mo_tan", 1, 2, ["qingyun"]], ["xuesha_tu", 1, 2, ["qingyun"]], ["xuesha_tu", 1, 3, []], ["bear_king", 1, 1, ["qingyun"]], ["bear_king", 1, 2, []], ["chixiao_zhifa", 2, 0, ["qingyun"]], ["chixiao_zhifa", 2, 1, []]]:
		_report(str(setup[0]), int(setup[1]), int(setup[2]), setup[3])
	for setup: Array in SERIES:
		_series(str(setup[0]), str(setup[1]), int(setup[2]), int(setup[3]), setup[4])
	_spars()
	for setup: Array in [[1, 1], [1, 3], [2, 0], [2, 2]]:
		_summit(int(setup[0]), int(setup[1]))
	quit(0)

## 功法层数 (layers.gd): a character just begun holds their arts at the first layer; one further on has
## practised them to the realm's cap (a technique without a record is held at the cap).
func _seasoned(game) -> void:
	if int(game.player.realm) > 0 or int(game.player.stage) > 0:
		game.player.layers = {}

## Spars with the generated disciples at the sect, who cast their whole loadout from orbs.
func _spars() -> void:
	var wins := 0
	var turns := 0
	var fights := 0
	var foe_casts := 0
	var stages: Array = []
	for seed_value: int in range(20):
		var game := Session.new()
		game.encounters_enabled = false
		game.new_game("试", 2000 + seed_value, ROOTS[seed_value % ROOTS.size()])
		game.Loadout.take_lineage(game, "qingyun")
		var people: Array = game.present_npcs().filter(func(id: String) -> bool: return game.is_generated(id))
		if people.is_empty():
			continue
		var foe_id := str(people[seed_value % people.size()])
		stages.append(int(game.person(foe_id).stage))
		# Matched in cultivation: the fair test of the rules.
		game.player.stage = int(game.person(foe_id).stage)
		_seasoned(game)
		game.refresh_realm_stats()
		game.player.hp = game.player.max_hp
		game.begin_spar(foe_id)
		var count := 0
		while not game.battle.is_empty() and count < 30:
			count += 1
			foe_casts += game.battle.get("intent", []).filter(func(entry: Dictionary) -> bool: return entry.has("art")).size()
			_play_turn(game)
		fights += 1
		turns += count
		if game.chronicle.entries.any(func(entry: Dictionary) -> bool: return entry.id == "spar_win"):
			wins += 1
	print("spar       generated disciples       turns %.1f  win %d%%  foe arts planned per turn %.1f" % [float(turns) / maxi(1, fights), wins * 100 / maxi(1, fights), float(foe_casts) / maxi(1, turns)], " stages ", stages)

func _report(enemy_id: String, realm: int, stage: int, lineage: Array, prepared: bool = false) -> void:
	var wins := 0
	var turns := 0
	var left := 0
	var fights := 0
	for seed_value: int in range(60):
		var game := Session.new()
		game.encounters_enabled = false
		game.new_game("试", 1000 + seed_value, ROOTS[seed_value % ROOTS.size()])
		game.player.realm = realm
		game.player.stage = stage
		if not lineage.is_empty():
			game.Loadout.take_lineage(game, str(lineage[0]))
		_seasoned(game)
		game.refresh_realm_stats()
		game.player.hp = game.player.max_hp
		if prepared:
			game.add_item("polin_powder", 1)
			game.use_item("polin_powder")
		game.begin_battle(enemy_id, "event")
		var count := 0
		while not game.battle.is_empty() and count < 30:
			count += 1
			_play_turn(game)
		fights += 1
		turns += count
		if game.battle.is_empty() and int(game.player.hp) > 0 and game.journal_lines()[-1].find("落败") < 0 and not game.chronicle.entries.any(func(entry: Dictionary) -> bool: return entry.id == "battle_defeat"):
			wins += 1
			left += int(game.player.hp) * 100 / int(game.player.max_hp)
	print("%-10s realm %d stage %d %-8s  turns %.1f  win %d%%  hp left %d%%" % [enemy_id + ("+破鳞散" if prepared else ""), realm, stage, str(lineage), float(turns) / fights, wins * 100 / fights, left / maxi(1, wins)])

## 成串的战斗 (series.gd): how often the whole series is seen through, with the breath between waves.
func _series(series_id: String, location: String, realm: int, stage: int, lineage: Array) -> void:
	var done := 0
	var waves := 0
	var runs := 40
	for seed_value: int in range(runs):
		var game := Session.new()
		game.encounters_enabled = false
		game.new_game("试", 4000 + seed_value, ROOTS[seed_value % ROOTS.size()])
		game.player.realm = realm
		game.player.stage = stage
		if not lineage.is_empty():
			game.Loadout.take_lineage(game, str(lineage[0]))
		_seasoned(game)
		game.refresh_realm_stats()
		game.player.hp = game.player.max_hp
		game.player.location = location
		game.Series.begin(game, series_id)
		var count := 0
		while not game.battle.is_empty() and count < 120:
			count += 1
			_play_turn(game)
		if game.chronicle.entries.any(func(entry: Dictionary) -> bool: return entry.id == "series_done"):
			done += 1
		waves += game.chronicle.entries.filter(func(entry: Dictionary) -> bool: return entry.id == "series_wave").size()
	print("%-15s realm %d stage %d %-8s  done %d%%  waves reached %.1f" % [series_id, realm, stage, str(lineage), done * 100 / runs, float(waves) / runs])

## 天劫 and 心魔 (B7) at the end of a realm, 青云 lineage, by the plain policy: how often weathered or won.
func _trial(trial: String, realm: int, stage: int) -> void:
	var won := 0
	var runs := 40
	for seed_value: int in range(runs):
		var game := Session.new()
		game.encounters_enabled = false
		game.new_game("试", 5000 + seed_value, ROOTS[seed_value % ROOTS.size()])
		game.player.realm = realm
		game.player.stage = stage
		game.Loadout.take_lineage(game, "qingyun")
		_seasoned(game)
		game.refresh_realm_stats()
		game.player.hp = game.player.max_hp
		if trial == "demon":
			game.player["attempt"] = {"odds": 50, "certain": false, "steps": 0, "xp": 0, "guard": ""}
			game.Combat.begin_demon(game)
		else:
			game.player["tribulation"] = {"grade": 1, "days": 0, "xp": 0}
			game.Combat.begin_tribulation(game, trial)
		var count := 0
		while not game.battle.is_empty() and count < 40:
			count += 1
			_play_turn(game)
		if game.chronicle.entries.any(func(entry: Dictionary) -> bool: return entry.id in ["tribulation_passed", "demon_slain"]):
			won += 1
	print("%-20s realm %d stage %d  won %d%%" % [trial, realm, stage, won * 100 / runs])

func _play_turn(game) -> void:
	game.plain_turn()

## 五宗论道 at a realm and stage, 青云 lineage: how many of the four rounds are won, on average.
func _summit(realm: int, stage: int) -> void:
	var rounds := 0
	var champions := 0
	var runs := 30
	for seed_value: int in range(runs):
		var game := Session.new()
		game.encounters_enabled = false
		game.new_game("试", 3000 + seed_value, ROOTS[seed_value % ROOTS.size()])
		game.Loadout.take_lineage(game, "qingyun")
		game.player.realm = realm
		game.player.stage = stage
		_seasoned(game)
		game.refresh_realm_stats()
		game.player.hp = game.player.max_hp
		game.Summit.begin(game, 1)
		var turns := 0
		while not game.battle.is_empty() and turns < 120:
			turns += 1
			_play_turn(game)
		var won: int = game.chronicle.entries.filter(func(entry: Dictionary) -> bool: return entry.id == "summit_round").size()
		rounds += won
		if won == 4:
			champions += 1
	print("summit     realm %d stage %d  rounds won %.1f / 4  champion %d%%" % [realm, stage, float(rounds) / runs, champions * 100 / runs])
