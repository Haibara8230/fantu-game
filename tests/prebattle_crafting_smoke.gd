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
	s.new_game("丹器测试", 42, ["earth", "fire"])
	s.player.stones = 3000
	return s

func _initialize() -> void:
	create_timer(40).timeout.connect(func() -> void: printerr("Preparation/crafting timeout"); quit(1))
	call_deferred("run")

func run() -> void:
	var s = game()
	check(s.content.error_message.is_empty(), "new preparation and formulation definitions validate")
	if not s.content.error_message.is_empty():
		printerr(s.content.error_message)
		quit(1)
		return
	var sense: int = s.sense()
	for id: String in ["ningshen_dan", "longhu_dan", "jujia_dan", "bingyuan_dan", "houtu_dan", "leidie_dan"]:
		check(s.content.item(id).get("id", "") == id, "merged medicine keeps its catalogue identity for icons and trading: " + id)
		s.add_item(id, 2)
		s.use_item(id)
		check(s.item_count(id) == 1 and id in s.Prebattle.pending(s), "dose consumed in advance: " + id)
		var before: Dictionary = s.snapshot()
		s.use_item(id)
		check(s.snapshot() == before, "same group does not stack: " + id)
	check(s.sense() == sense, "prepared sense bonus waits for battle")
	var loaded := Session.new()
	check(loaded.restore(JSON.parse_string(JSON.stringify(s.snapshot()))), "multiple prepared groups restore")
	s.begin_battle("disciple")
	check(s.Prebattle.pending(s).is_empty() and s.battle.prepared_pills.size() == 6 and s.battle.shield == 5 and s.sense() == sense + 1, "opening consumes preparation once and applies shield and whole-fight sense")
	check(s.battle.orbs.size() == s.Combat.draw_count(s) + int(s.content.rules.duel.first_extra) + 1, "per-turn earth dose includes opening draw")
	s.Combat._inflict_player(s, "burn", [3, 3])
	check(not s.battle.player_status.has("burn"), "ice medicine blocks burning during its active turns")
	s.battle.turn = 4
	s.Combat._inflict_player(s, "burn", [3, 3])
	check(s.battle.player_status.has("burn"), "three-turn immunity expires")
	var before: Dictionary = s.snapshot()
	s.use_item("longhu_dan")
	check(s.snapshot() == before, "all preparation medicines remain unavailable during battle")
	check(loaded.restore(JSON.parse_string(JSON.stringify(s.snapshot()))) and loaded.battle.shield == 5 and loaded.Prebattle.pending(loaded).is_empty(), "battle restore does not add opening shield or re-prepare doses")
	var bad: Dictionary = JSON.parse_string(JSON.stringify(s.snapshot()))
	bad.battle.prepared_pills.append("houtu_dan")
	before = loaded.snapshot()
	check(not loaded.restore(bad) and loaded.snapshot() == before, "duplicate medicine group rejected atomically")
	for key: String in ["dao_hit_turn", "array_driven", "dao_chain_earth", "foe_next_draw"]:
		bad = s.snapshot()
		bad.battle[key] = 0.5
		check(not loaded.restore(bad) and loaded.snapshot() == before, "fractional optional combat count rejected: " + key)
	s.battle.clear()
	s.begin_battle("disciple")
	check(not s.battle.has("prepared_pills") and s.battle.shield == 0 and s.sense() == sense, "medicine cannot leak into the following fight")
	# A costly substitute works by its actual potency; insufficient or malformed mixtures cost nothing.
	s = game()
	s.Alchemy.learn(s, "liaoshang")
	s.add_item("lingzhi", 2)
	s.add_item("huichun_grass", 5)
	var plan: Dictionary = s.alchemy_plan("liaoshang")
	plan.main = {"lingzhi": 1}
	plan.guide = "huichun_grass"
	s.fortune.alchemy = 0.0
	s.fortune.alchemy_fine = 0.99
	check(s.alchemy_block(plan).is_empty(), "alternative main herb satisfies the recipe potency")
	s.brew(plan)
	check(s.item_count("lingzhi") == 1 and s.item_count("huichun_grass") == 4 and s.item_count("liaoshang_pill") > 0, "custom recipe consumes exactly its substitute and guide")
	var normal_yield: Array = s.alchemy_odds(plan).yield
	s.Dao.ensure(s).nodes = ["alchemy_herb", "alchemy_antitoxin", "alchemy_sage"]
	var double_yield: Array = s.alchemy_odds(plan).yield
	check(int(double_yield[0]) == int(normal_yield[0]) * 2 and int(double_yield[1]) == int(normal_yield[1]) * 2, "alchemy mastery doubles the displayed yield range used by the actual brew")
	s.Dao.ensure(s).nodes = []
	for main: Variant in [{"huichun_grass": 1}, {"lingzhi": -1}, {"lingzhi": 0.5}, ["lingzhi"]]:
		plan.main = main
		before = s.snapshot()
		s.brew(plan)
		check(s.snapshot() == before, "invalid or insufficient main mixture is atomic")
	# A two-family piece can carry a chosen jade-derived affix on its metal frame.
	s = game()
	s.player.location = "market"
	s.add_item("ore_qinggang", 8)
	s.add_item("jade_qing", 8)
	plan = {"material": "ore_qinggang", "base": "sword", "element": "earth", "materials": {"ore_qinggang": 2, "jade_qing": 1}, "affixes": ["spirit"]}
	check(s.Forge.block(s, plan).is_empty(), "mixed material recipe admits an affix carried by the second family")
	s.forge_item(plan)
	var pieces: Array = s.player.items.keys().filter(func(id: String) -> bool: return id.begins_with("e:sword:"))
	check(pieces.size() == 1 and "聚灵" in s.content.equipment(str(pieces[0])).affixes and s.item_count("ore_qinggang") == 6 and s.item_count("jade_qing") == 7, "chosen affix is produced and each material is spent exactly once")
	before = s.snapshot()
	plan.affixes = ["spirit", "guard"]
	s.forge_item(plan)
	check(s.snapshot() == before, "too many selected affixes cannot consume ingredients")
	plan.affixes = ["sharp"]
	s.Dao.gain(s, "craft", 1000)
	s.Dao.pick(s, "craft_bird")
	plan.sigil = "vermilion"
	s.forge_item(plan)
	var instance: String = s.Gear.carried(s)[0]
	check(s.gear_item(instance).sigil == "vermilion" and s.gear_item(instance).description.contains("朱雀"), "sigil creates an independent, described equipment instance")
	check(loaded.restore(JSON.parse_string(JSON.stringify(s.snapshot()))) and loaded.gear_item(instance).sigil == "vermilion", "sigil survives save without being stripped")
	s.equip_item(instance)
	s.begin_battle("disciple")
	var normal: int = s.Combat.release_of(s).damage
	s.player.hp = s.player.max_hp / 3
	check(s.Combat.release_of(s).damage == normal * 2, "low-health sigil changes the actual weapon release")
	print("PREPARATION AND CRAFTING: %d checks, %d failures" % [checks, failures])
	quit(1 if failures else 0)
