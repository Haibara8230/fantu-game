extends SceneTree
const Session = preload("res://scripts/core/session.gd")
var checks := 0
var failures := 0

func check(ok: bool, message: String) -> void:
	checks += 1
	if not ok:
		failures += 1
		printerr("FAIL: " + message)

func game():
	var s := Session.new()
	s.encounters_enabled = false
	s.new_game("悟道测试", 42, ["earth", "fire"])
	return s

func _initialize() -> void:
	create_timer(40).timeout.connect(func() -> void: printerr("Dao timeout"); quit(1))
	call_deferred("run")

func run() -> void:
	var s = game()
	check(s.content.error_message.is_empty() and s.content.dao_data.paths.size() == 12 and s.content.dao_data.stages.size() == 5, "twelve paths and five stages load")
	if not s.content.error_message.is_empty():
		printerr(s.content.error_message)
		quit(1)
		return
	var dao = s.Dao
	check(dao.stage_of(s, "earth") > 0 and dao.points(s) == 2, "starter knowledge bootstraps once with initial points")
	var before: Dictionary = s.snapshot()
	check(not dao.pick(s, "earth_master").is_empty() and s.snapshot() == before, "locked node cannot mutate state")
	dao.pick(s, "earth_guard")
	check(dao.points(s) == 1 and dao.value(s, "element_guard", "earth") == 1, "node spends points and exposes its actual effect")
	dao.forget(s, "earth_guard")
	check(dao.points(s) == 2, "forget refunds exact node cost")
	var art: Dictionary = s.content.technique("t:bolt:water:3::0")
	check(not dao.learning_block(s, art).is_empty(), "new high-tier study requires understanding")
	for path: String in dao.paths_for(art):
		dao.gain(s, path, 1000)
	check(dao.learning_block(s, art).is_empty(), "understanding unlocks study independently of cultivation")
	var xp := int(dao.state(s).xp.get("body", 0))
	dao.gain(s, "body", 1200, true)
	check(dao.stage_of(s, "body") == 0, "unabsorbed insight does not award understanding")
	s.player.stones = 3000
	dao.reflect(s, "body")
	check(int(dao.state(s).xp.body) == xp + 900 and int(dao.state(s).pending.body) == 300, "reflection absorbs only the days spent")
	dao.gain(s, "body", 1000)
	var maximum: int = s.player.max_hp
	dao.pick(s, "body_blood")
	check(s.player.max_hp == maximum + 10 and dao.forget(s, "body_blood").contains("不可"), "permanent body node changes health and cannot be refunded")
	s.player.hp = s.player.max_hp
	var loaded := Session.new()
	check(loaded.restore(JSON.parse_string(JSON.stringify(s.snapshot()))) and loaded.snapshot() == s.snapshot(), "chosen nodes and insight restore without repeating bonuses")
	check(loaded.player.hp == loaded.player.max_hp, "health above the former cap restores using saved Dao allocation")
	before = loaded.snapshot()
	var saved: Dictionary = JSON.parse_string(JSON.stringify(s.snapshot()))
	for field: String in ["xp", "pending"]:
		var broken := saved.duplicate(true)
		broken.player.dao[field].body = -1
		check(not loaded.restore(broken) and loaded.snapshot() == before, "malformed " + field + " is atomic")
	var broken := saved.duplicate(true)
	broken.player.dao.nodes.append("body_blood")
	check(not loaded.restore(broken) and loaded.snapshot() == before, "duplicate node rejected")
	broken = saved.duplicate(true)
	broken.player.dao.nodes.append("earth_master")
	check(not loaded.restore(broken) and loaded.snapshot() == before, "locked and overspent nodes rejected")
	saved.player.erase("dao")
	saved.player.hp = mini(int(saved.player.hp), maximum)
	check(loaded.restore(saved) and dao.stage_of(loaded, "earth") > 0, "old journey has safe derived knowledge and retains learned arts")
	s = game()
	s.Dao.gain(s, "earth", 1000)
	s.Dao.pick(s, "earth_guard")
	s.begin_battle("disciple")
	s.battle.orbs = ["earth", "earth", "earth"]
	s.player.hp = s.player.max_hp
	s.Combat._hurt_player(s, 10, 1.0, {"element": "water", "name": "水击"})
	check(s.player.hp == s.player.max_hp - 7, "御土 reduces actual incoming water damage by held earth qi")
	var snapshot: Dictionary = s.snapshot()
	check(not s.Dao.pick_block(s, "qi_cap").is_empty() and s.snapshot() == snapshot, "battle cannot change allocated nodes")
	s = game()
	s.Dao.ensure(s).debate_xp = 90000
	s.Dao.gain(s, "water", 150000)
	s.Dao.pick(s, "water_guard")
	before = s.snapshot()
	s.Dao.pick(s, "water_master")
	check(s.snapshot() == before, "a first-stage node cannot skip existing intermediate stages")
	for id: String in ["water_strong", "water_draw", "water_chain", "water_master"]:
		s.Dao.pick(s, id)
	check(s.Dao.value(s, "element_master", "water") == 1, "complete prerequisite chain unlocks mastery")
	s.Dao.forget(s, "water_strong")
	check("water_strong" in s.Dao.state(s).nodes, "middle node cannot be removed under higher nodes")
	s.begin_battle("disciple")
	check(s.Combat._player_healing(s, 10) == 13, "water mastery increases effective healing by thirty percent")
	s.battle.player_status.wound = [0.5, 2]
	check(s.Combat._player_healing(s, 20) == 13, "healing mastery still respects wound reduction")
	var broken_turn := s.snapshot()
	broken_turn.battle.dao_hit_turn = int(s.battle.turn) + 1
	check(not loaded.restore(broken_turn), "future per-turn flags cannot be restored")
	s = game()
	s.Dao.ensure(s).xp.body = 149999
	s.Dao.gain(s, "body", 100, true)
	s.player.stones = 3000
	s.Dao.reflect(s, "body")
	check(int(s.Dao.state(s).xp.body) == 150000 and int(s.Dao.state(s).pending.body) == 99, "reflection only consumes insight needed to reach the final cap")
	s = game()
	for id: String in s.content.sects:
		if s.content.sects[id].skills.any(func(art: String) -> bool: return not art in s.player.learned):
			var previous_xp: Dictionary = s.Dao.state(s).xp.duplicate()
			s.Loadout.take_lineage(s, id)
			check(s.Dao.state(s).xp != previous_xp, "new lineage teachings award understanding through the normal learning hook")
			previous_xp = s.Dao.state(s).xp.duplicate()
			s.Loadout.take_lineage(s, id)
			check(s.Dao.state(s).xp == previous_xp, "reapplying known lineage cannot farm understanding")
			break
	print("DAO: %d checks, %d failures" % [checks, failures])
	quit(1 if failures else 0)
