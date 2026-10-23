extends SceneTree
const Session = preload("res://scripts/core/session.gd")
const Relations = preload("res://scripts/core/qi_relations.gd")
const Motion = preload("res://scripts/presentation/qi_motion.gd")
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
	s.new_game("尘沙测试", 42, ["earth", "fire"])
	return s

func _initialize() -> void:
	create_timer(40).timeout.connect(func() -> void: printerr("Combat flow timeout"); quit(1))
	call_deferred("run")

func run() -> void:
	var s = game()
	check(s.content.error_message.is_empty(), "new combat definitions validate")
	if not s.content.error_message.is_empty():
		printerr(s.content.error_message)
		quit(1)
		return
	var cycle: Dictionary = s.Combat.rules(s).generates
	for a: String in cycle:
		for b: String in cycle:
			var expected := "same" if a == b else "generate" if cycle[a] == b or cycle[b] == a else "overcome"
			check(Relations.classify([a, b], cycle) == [expected], "all paid element pairs: %s/%s" % [a, b])
	check(Relations.classify(["metal"], cycle).is_empty() and Relations.classify(["metal", "water", "wood"], cycle).is_empty(), "one orb and three distinct elements do not fabricate a relation")
	check(Relations.classify(["metal", "metal", "water", "water"], cycle) == ["generate"], "repeated groups retain their generating relationship")
	check(Relations.classify(["metal", "void"], cycle).is_empty(), "unknown payment rejected by relation classification")
	s.begin_battle("disciple")
	s.player.arts = ["seal_wood", "qi_strike"]
	s.battle.orbs = ["wood", "water", "metal", "metal"]
	var before: Dictionary = s.snapshot()
	var preview: Dictionary = s.Combat.payment_preview(s, s.held_technique("seal_wood"), ["wood", "water"])
	check(preview.triggers == ["generate"] and s.snapshot() == before, "preview computes the effect without touching save or RNG")
	s.battle.last = "water"
	s.use_skill("seal_wood", ["wood", "water"])
	check(s.battle.orbs == ["metal", "metal", "fire", "fire"], "generating payment gives base and bonus qi once")
	s.battle.orbs = ["wood", "water"]
	before = s.snapshot()
	check(s.use_skill("seal_wood").contains("后继无力") and s.snapshot() == before, "second cast of exhausted art is atomic")
	var other = game()
	other.begin_battle("disciple")
	other.player.arts = ["seal_wood"]
	other.battle.last = "water"
	other.battle.orbs = ["wood", "metal"]
	other.use_skill("seal_wood")
	check(other.battle.orbs == ["fire"], "previous water art cannot substitute for a generating payment")
	# Full loop, including its ordinary purchase and learning route outside a battle.
	s = game()
	s.player.location = "market"
	s.player.stones = 2000
	var goods: Array = s.shop_goods()
	for id: String in s.content.combat_flow_data.skills:
		while not s.pending_event.is_empty():
			s.choose_event(str(s.pending_definition().choices.back().id))
		check(goods.any(func(good: Dictionary) -> bool: return good.item == "j:" + id), "flow manual available in ordinary shop: " + id)
		s.buy("j:" + id)
		s.study_manual("j:" + id)
		check(id in s.player.learned, "ordinary purchase and study teaches " + id)
	while not s.pending_event.is_empty():
		s.choose_event(str(s.pending_definition().choices.back().id))
	s.player.arts = s.content.combat_flow_data.preview_loadout.duplicate()
	for id: String in s.player.arts:
		if not id in s.player.learned:
			s.player.learned.append(id)
	s.begin_battle("disciple")
	s.battle.orbs = []
	for i: int in 20:
		s.battle.orbs.append("earth")
	s.battle.shield = 1
	s.use_skill("dust_shed")
	s.use_skill("dust_shed")
	check(s.battle.resources.dust == 5 and s.battle.shield == 0, "卸甲 adds its shield then converts all of it into dust")
	s.use_skill("dust_scatter")
	check(s.battle.resources.dust == 0 and s.battle.foe_resources.sand == 5, "化沙 transfers all dust into opponent sand")
	var loaded := Session.new()
	check(loaded.restore(JSON.parse_string(JSON.stringify(s.snapshot()))) and loaded.snapshot() == s.snapshot(), "sand and used-per-turn state survive JSON restore")
	s.use_skill("dust_return")
	check(s.battle.resources.dust == 5 and s.battle.foe_resources.sand == 0, "还尘 recovers all sand into dust")
	var hp: int = s.battle.hp
	s.use_skill("dust_burst")
	check(s.battle.resources.dust == 2 and s.battle.hp < hp, "绝尘 consumes exactly three dust and deals damage")
	before = s.snapshot()
	check(s.use_skill("dust_burst").contains("至少") and s.snapshot() == before, "insufficient dust cannot spend qi or RNG")
	s.battle.turn += 1
	s.use_skill("dust_scatter")
	check(s.battle.foe_resources.sand == 2, "exhaustion expires on the next turn")
	s.use_skill("dust_return")
	s.battle.orbs = ["earth", "earth", "earth", "fire"]
	s.use_skill("dust_condense")
	check(s.battle.resources.dust == 4 and s.battle.orbs == ["fire"] and s.combat_events.any(func(e: Dictionary) -> bool: return e.type == "discard" and e.orbs == ["earth", "earth"]), "万土归尘 consumes remaining earth once and reports every discarded orb")
	var saved: Dictionary = JSON.parse_string(JSON.stringify(s.snapshot()))
	before = loaded.snapshot()
	for value: Variant in [-1, 0.5, "3", 1000001]:
		var broken := saved.duplicate(true)
		broken.battle.resources.dust = value
		check(not loaded.restore(broken) and loaded.snapshot() == before, "invalid resource rejected atomically: %s" % value)
	var legacy := saved.duplicate(true)
	for key: String in ["resources", "foe_resources", "flow_used", "foe_flow_used"]:
		legacy.battle.erase(key)
	check(loaded.restore(legacy), "pre-resource saves remain loadable")
	legacy.battle.orbs.resize(80)
	legacy.battle.orbs.fill("earth")
	check(loaded.restore(legacy) and loaded.battle.orbs.size() == 80, "large legal hands from combined insight and gathering restore")
	# Both advanced methods hook the resource operation, once per legal cast.
	s = game()
	s.player.methods = ["dust_method", "dust_breath"]
	s.begin_battle("disciple")
	s.battle.foe_resources = {"sand": 4}
	s.Combat._flow_event(s, s.content.technique("dust_return"))
	check(s.battle.shield == 2 and s.battle.next_draw == 1 and s.battle.resources.dust == 4, "return triggers shield and next-turn qi from equipped methods")
	s.battle.foe = {"realm": 0, "methods": ["dust_method", "dust_breath"]}
	s.battle.resources.sand = 6
	s.Combat._flow_event(s, s.content.technique("dust_return"), true)
	check(s.battle.foe_shield == 2 and s.battle.foe_next_draw == 1 and s.battle.foe_resources.dust == 6, "opponent method hooks mirror the same rules")
	check(not s.Combat.skill_block(s, s.content.technique("dust_return"), true).is_empty(), "enemy exhaustion uses its own per-turn record")
	var motion: Dictionary = JSON.parse_string(FileAccess.get_file_as_string("res://data/battle_presentation.json"))
	check(Motion.batch_seconds(motion.profiles.spend, 12) < 0.7 and Motion.batch_seconds(motion.profiles.reserve, 12) < 1.3, "batch timing is bounded rather than multiplied by orb count")
	for kind: String in ["draw", "reserve", "return", "spend", "discard"]:
		check(Motion.point(Vector2(2, 3), Vector2(9, 8), kind, 0, 2).is_equal_approx(Vector2(2, 3)) and Motion.point(Vector2(2, 3), Vector2(9, 8), kind, 1, 2).is_equal_approx(Vector2(9, 8)), "motion endpoints agree: " + kind)
	print("COMBAT FLOW: %d checks, %d failures" % [checks, failures])
	quit(1 if failures else 0)
