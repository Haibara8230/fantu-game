extends SceneTree
## Stage three of docs/WORLD_EXPANSION.md: 功法层数 (layers.gd) and 宝物实例与祭炼 (gear.gd) — layer
## shares and affix unlocks, realm caps, practice from duels and retreats, 参悟, everyone else at their
## realm's cap, refining instances, and saves.
const Session = preload("res://scripts/core/session.gd")
const Content = preload("res://scripts/core/content.gd")
const Arsenal = preload("res://scripts/core/arsenal.gd")
const Layers = preload("res://scripts/core/layers.gd")
const Gear = preload("res://scripts/core/gear.gd")
var checks := 0
var failures := 0

func check(condition: bool, message: String) -> void:
	checks += 1
	if not condition:
		failures += 1
		printerr("FAIL: " + message)

func _initialize() -> void:
	create_timer(240.0).timeout.connect(func() -> void: printerr("TIMEOUT: test did not finish (likely a script error)"); quit(1))
	var content := Content.new()
	check(content.load_data(), "content with layers and 祭炼 loads: " + content.error_message)
	_shares(content)
	_caps(content)
	_learning()
	_practice()
	_comprehend()
	_others(content)
	_refining()
	_saves()
	print("LAYERS: %d checks, %d failures" % [checks, failures])
	quit(0 if failures == 0 else 1)

func _game(roots: Array = ["metal", "wood", "fire"]) -> Session:
	var game := Session.new()
	game.encounters_enabled = false
	game.new_game("层数", 7, roots)
	return game

func _shares(content: Content) -> void:
	var id := "t:bolt:fire:2:burn:0"
	var full := Arsenal.technique(content, id)
	var first := Arsenal.technique(content, id, 1)
	check(int(full.layer) == 5 and int(full.layers) == 5 and int(first.layer) == 1, "a 黄阶 art has five layers; 0 reads it fully cultivated")
	check(int(first.damage_max) < int(full.damage_max) and int(first.damage_max) == int(round(8.0 * 1.25 * 0.8)), "the first layer gives four fifths of the tier's power")
	check(int(Arsenal.technique(content, "t:bolt:fire:1::0").damage_max) == int(first.damage_max), "the first layer of a 黄阶 art matches a 凡阶 art fully cultivated")
	check(not first.has("burn") and Arsenal.technique(content, id, 3).has("burn"), "the 黄阶 affix unlocks at the third layer")
	check(first.description.contains("第 3 层解封") and not full.description.contains("解封"), "a locked affix says where it unlocks")
	check(first.cost == full.cost, "the cost does not shrink with the layer")
	var method := Arsenal.technique(content, "t:body:earth:1::0", 1)
	check(int(method.passive.max_hp) == 12 and int(Arsenal.technique(content, "t:body:earth:1::0").passive.max_hp) == 15, "a 心法's passive grows with its layers too")
	var handwritten := Arsenal.technique(content, "sword", 1)
	check(int(handwritten.damage_max) < int(Arsenal.technique(content, "sword").damage_max) and handwritten.description.contains("眼下第 1 层"), "a sect's own art grows with its layers and says what it does now")
	# The 地阶 affixes unlock at 3, 6 and 9 in the order the data defines them, whatever the id's spelling.
	var deep := Arsenal.technique(content, "t:burst:fire:4:burn+fierce+pierce:0", 3)
	check(deep.affix_unlocks == [3, 6, 9] and deep.affixes[0] == content.technique_data.affixes.pierce.name, "affixes unlock in the data's order")

func _caps(content: Content) -> void:
	var mystic := Arsenal.technique(content, "t:bolt:fire:3::0")
	var earth := Arsenal.technique(content, "t:bolt:fire:4::0")
	var heaven := Arsenal.technique(content, "t:bolt:fire:5::0")
	check(Layers.cap(content, mystic, 0) == 3 and Layers.cap(content, mystic, 1) == 7, "a 玄阶 art: three of seven layers at 炼气, all at 筑基")
	check(Layers.cap(content, earth, 0) == 2 and Layers.cap(content, earth, 1) == 4 and Layers.cap(content, earth, 2) == 9, "a 地阶 art: two at 炼气, four at 筑基, nine at 金丹")
	check(Layers.cap(content, heaven, 0) == 0 and Layers.cap(content, heaven, 1) == 2, "a 天阶 art cannot be begun at 炼气, two layers at 筑基")

func _learning() -> void:
	var game := _game()
	check(int(game.player.layers.get("wood", {}).get("layer", 0)) == 1, "a new journey begins its arts at the first layer")
	game.add_item("j:t:bolt:fire:3::0", 1)
	check(game.learn_block("t:bolt:fire:3::0").is_empty(), "a 玄阶 slip can be begun at 炼气")
	game.study_manual("j:t:bolt:fire:3::0")
	check(int(game.player.layers["t:bolt:fire:3::0"].layer) == 1 and int(game.held_technique("t:bolt:fire:3::0").layer) == 1, "a technique learned begins at the first layer")
	game.player.learned.append("t:breath:wood:2::0")
	check(Layers.layer_of(game, "t:breath:wood:2::0") == 5, "a technique without a record is held at the realm's cap, as before layers")

func _practice() -> void:
	var game := _game()
	var t: Dictionary = game.content.technique("wood")
	var need := Layers.need_days(game, t, 1) * Layers.TENTHS
	check(Layers.practise(game, "wood", need - 1).is_empty() and Layers.layer_of(game, "wood") == 1, "practice short of the layer keeps the layer and the progress")
	var lines := Layers.practise(game, "wood", 1)
	check(Layers.layer_of(game, "wood") == 2 and int(game.player.layers.wood.practice) == 0 and lines.size() == 1 and lines[0].contains("第 2 层"), "enough practice climbs a layer and says so")
	# Practice adds up the same whether given at once or in parts.
	var once := _game()
	var parts := _game()
	Layers.practise(once, "wood", 3000)
	for step: int in 10:
		Layers.practise(parts, "wood", 300)
	check(once.player.layers == parts.player.layers, "practice at once equals practice in parts")
	check(Layers.layer_of(once, "wood") == 5 and int(once.player.layers.wood.practice) == 0, "practice stops at the last layer")
	# A 地阶 art at 炼气 waits at its cap, its practice full, and climbs with the realm.
	game.player.learned.append("t:bolt:fire:4::0")
	Layers.begin(game, "t:bolt:fire:4::0")
	Layers.practise(game, "t:bolt:fire:4::0", 100000)
	var deep: Dictionary = game.content.technique("t:bolt:fire:4::0")
	check(Layers.layer_of(game, "t:bolt:fire:4::0") == 2 and int(game.player.layers["t:bolt:fire:4::0"].practice) == Layers.need_days(game, deep, 2) * Layers.TENTHS, "practice past the realm's cap waits, full")
	check(game.comprehend_block("t:bolt:fire:4::0").contains("突破") or game.comprehend_block("t:bolt:fire:4::0").contains("只能修到"), "参悟 is barred at the cap")
	game.player.realm = 1
	game.player.stage = 0
	check(not Layers.after_breakthrough(game).is_empty() and Layers.layer_of(game, "t:bolt:fire:4::0") == 3, "a breakthrough lets the waiting practice climb")
	# Casting in a duel and retreating are practice.
	var fighter := _game()
	fighter.start_battle("disciple")
	fighter.battle.orbs = ["wood", "wood", "wood", "metal", "metal", "fire"]
	fighter.use_skill("wood")
	check(int(fighter.player.layers.wood.practice) == int(fighter.content.technique_data.layer_rule.cast_practice), "casting an art is practice toward its next layer")
	var hermit := _game()
	hermit.player.learned.append("t:breath:wood:2::0")
	Layers.begin(hermit, "t:breath:wood:2::0")
	hermit.player.methods = ["t:breath:wood:2::0"]
	var rule: Dictionary = hermit.content.technique_data.layer_rule
	Layers.after_retreat(hermit, 10)
	check(int(hermit.player.layers["t:breath:wood:2::0"].practice) == 10 * int(rule.retreat_method), "a slotted 心法 practises through a retreat")
	check(int(hermit.player.layers.wood.practice) == 10 * int(rule.retreat_art), "a slotted art practises a little")

func _comprehend() -> void:
	var game := _game()
	var t: Dictionary = game.content.technique("wood")
	var cost: Dictionary = Layers.comprehend_cost(game, "wood")
	check(int(cost.days) == Layers.need_days(game, t, 1) and int(cost.stones) == 0, "参悟 of a 黄阶 layer costs its days and no stones")
	Layers.practise(game, "wood", 25)
	check(int(Layers.comprehend_cost(game, "wood").days) == int(cost.days) - 2, "practice already made shortens 参悟 (whole days, rounded up)")
	var day := int(game.world.day)
	var before := int(game.held_technique("wood").heal)
	var text := game.comprehend("wood")
	check(Layers.layer_of(game, "wood") == 2 and int(game.world.day) == day + int(cost.days) - 2 and text.contains("第 2 层"), "参悟 spends the missing days and reaches the next layer")
	check(int(game.held_technique("wood").heal) > before and int(game.player.layers.wood.practice) == 0, "the art is stronger and the practice begins anew")
	check(game.comprehend("t:bolt:fire:1::0").contains("尚未习得"), "only what is learned is studied")
	# 玄阶 layers ask stones.
	var rich := _game()
	rich.player.learned.append("t:bolt:fire:3::0")
	Layers.begin(rich, "t:bolt:fire:3::0")
	rich.player.stones = 5
	check(rich.comprehend_block("t:bolt:fire:3::0").contains("灵石不足"), "a 玄阶 layer needs stones")
	rich.player.stones = 100
	rich.comprehend("t:bolt:fire:3::0")
	check(int(rich.player.stones) == 100 - int(rich.content.technique_data.tiers[2].layer_stones) and Layers.layer_of(rich, "t:bolt:fire:3::0") == 2, "and spends them")
	for step: int in 4:
		Layers.practise(game, "wood", 100000)
	check(game.comprehend_block("wood").contains("圆满"), "a technique fully cultivated cannot be studied further")

func _others(content: Content) -> void:
	var game := _game()
	var deep := Layers.at_realm(content, "t:bolt:fire:4::0", 0)
	check(int(deep.layer) == 2 and int(Layers.at_realm(content, "t:bolt:fire:4::0", 2).layer) == 9, "others hold their techniques at their realm's cap")
	var people: Array = game.present_npcs().filter(func(id: String) -> bool: return game.is_generated(id))
	if not people.is_empty():
		var person: Dictionary = game.person(str(people[0]))
		var foe: Dictionary = game.Population.foe(content, str(people[0]), person)
		check(int(foe.damage_max) >= 1 and int(foe.realm) == int(person.realm), "a generated cultivator's duel numbers come from their layers")
	# Bonuses for someone else count their 心法 at their realm's cap; the player's at their own layer.
	game.player.learned.append("t:body:earth:4::0")
	Layers.begin(game, "t:body:earth:4::0")
	game.player.methods = ["t:body:earth:4::0"]
	game.refresh_realm_stats()
	var own := int(game.bonuses().max_hp)
	var other := int(game.bonuses({"realm": 0, "methods": ["t:body:earth:4::0"]}).max_hp)
	check(own < other, "the player's 心法 counts at their own layer, below the cap others hold it at")

func _refining() -> void:
	var game := _game()
	var robe := Arsenal.equipment_id("robe", 3, "none", ["tough", "guard"], 0)
	game.add_item(robe, 2)
	var piece: Dictionary = game.gear_item(robe)
	var held: Dictionary = Arsenal.wielded(game.content, piece, 0)
	check(is_equal_approx(float(held.share), 0.5) and is_equal_approx(float(held.limit), 0.7), "a 灵器 at 炼气: half drawn on, refinable to seven tenths")
	game.player.location = "sect"
	check(game.available_here("cultivate"), "the sect has a quiet room for 祭炼")
	var cost: Dictionary = Gear.refine_cost(game, piece)
	game.player.stones = 1000
	var day := int(game.world.day)
	game.refine_gear(robe)
	var instances: Array[String] = Gear.carried(game)
	check(instances.size() == 1 and game.item_count(robe) == 1, "the first 祭炼 makes the piece an instance, apart from its stack")
	var refined: String = instances[0]
	check(int(game.world.day) == day + int(cost.days) and int(game.player.stones) == 1000 - int(cost.stones), "祭炼 spends its days and stones")
	check(is_equal_approx(float(Arsenal.wielded(game.content, game.gear_item(refined), 0).share), 0.6), "each step adds a tenth")
	check(int(Gear.refine_cost(game, game.gear_item(refined)).days) > int(cost.days), "the next step costs more")
	game.refine_gear(refined)
	check(game.refine_block(refined).contains("尽头"), "祭炼 stops at the realm's limit")
	var hp := int(game.player.max_hp)
	game.equip_item(refined)
	check(game.player.equipment.robe == refined and game.item_count(refined) == 0 and Gear.carried(game).is_empty() and int(game.player.max_hp) > hp, "an instance is worn by its id")
	game.equip_item(robe)
	check(game.player.equipment.robe == robe and Gear.carried(game) == [refined] and game.item_count(robe) == 0, "changing pieces puts the instance back in the 行囊, still itself")
	game.equip_item(refined)
	check(game.item_count(robe) == 1, "and the plain one back on its stack")
	# Refining the plain piece while worn turns the slot's piece into an instance.
	var other := _game()
	other.add_item(robe, 1)
	other.equip_item(robe)
	other.player.stones = 1000
	other.refine_gear(robe, "robe")
	check(Gear.is_instance(str(other.player.equipment.robe)) and other.item_count(robe) == 0 and int(other.player.gear[other.player.equipment.robe].refine) == 1, "a worn piece refined becomes an instance in its slot")
	# Full mastery or too far: no 祭炼.
	var plain := Arsenal.equipment_id("robe", 1, "none", [], 0)
	game.add_item(plain, 1)
	check(game.refine_block(plain).contains("无须"), "a piece wielded fully needs no 祭炼")
	var far := Arsenal.equipment_id("robe", 5, "none", [], 0)
	game.add_item(far, 1)
	check(game.refine_block(far).contains("太远"), "nor one three realms beyond")
	# A breakthrough recounts the share and keeps the steps, never above full.
	game.player.realm = 1
	game.player.stage = 0
	game.refresh_realm_stats()
	check(is_equal_approx(float(Arsenal.wielded(game.content, game.gear_item(refined), 1).share), 1.0), "at the piece's realm it is wielded fully, steps or not")
	var low := _game()
	var treasure := Arsenal.equipment_id("sword", 4, "fire", [], 0)
	low.add_item(treasure, 1)
	low.player.stones = 5000
	low.refine_gear(treasure)
	var kept: String = Gear.carried(low)[0]
	check(is_equal_approx(float(Arsenal.wielded(low.content, low.gear_item(kept), 0).share), 0.3), "a 法宝 at 炼气: one step to three tenths")
	check(is_equal_approx(float(Arsenal.wielded(low.content, low.gear_item(kept), 1).share), 0.6), "at 筑基 the step still counts on the new base")
	# Selling an instance takes it away, refinement and all.
	var seller := _game()
	seller.add_item(robe, 1)
	seller.player.stones = 1000
	seller.refine_gear(robe)
	var sold: String = Gear.carried(seller)[0]
	seller.player.location = "market"
	if seller.sell_price(sold) > 0:
		seller.sell(sold, 1)
		check(not seller.player.gear.has(sold) and seller.journal_lines().any(func(line: String) -> bool: return line.contains("售出" + seller.content.equipment(robe).name)), "selling an instance takes it and its 祭炼 away, named by its type")
	else:
		check(seller.sell_price(robe) == 0, "where 宝物 are not bought, neither is an instance")

func _saves() -> void:
	var game := _game()
	var robe := Arsenal.equipment_id("robe", 3, "none", ["tough", "guard"], 0)
	game.add_item(robe, 1)
	game.player.stones = 1000
	game.refine_gear(robe)
	game.equip_item(Gear.carried(game)[0])
	Layers.practise(game, "wood", 150)
	var copy := Session.new()
	check(copy.restore(JSON.parse_string(JSON.stringify(game.snapshot()))) and copy.snapshot() == game.snapshot(), "layers, practice and refined instances survive a save")
	check(int(copy.player.max_hp) == int(game.player.max_hp), "and give the same stats")
	# A save made before layers and instances: techniques at the realm's cap, no instances.
	var old: Dictionary = JSON.parse_string(JSON.stringify(_game().snapshot()))
	old.player.erase("layers")
	old.player.erase("gear")
	old.player.erase("gear_serial")
	var restored := Session.new()
	check(restored.restore(old) and Layers.layer_of(restored, "wood") == 5 and restored.player.gear.is_empty(), "a journey from before keeps its techniques as they were")
	for broken: Callable in [
		func(data: Dictionary) -> void: data.player.layers = {"wood": {"layer": 0, "practice": 0}},
		func(data: Dictionary) -> void: data.player.layers = {"wood": {"layer": 2, "practice": -1}},
		func(data: Dictionary) -> void: data.player.gear = {"q:9": {"type": robe, "refine": 0}},
		func(data: Dictionary) -> void: data.player.gear = {"q:1": {"type": robe, "refine": 99}},
		func(data: Dictionary) -> void: data.player.items["q:1"] = 1,
	]:
		var data: Dictionary = JSON.parse_string(JSON.stringify(game.snapshot()))
		broken.call(data)
		check(not Session.new().restore(data), "a malformed layer or instance rejects the save")
	var retired: Dictionary = JSON.parse_string(JSON.stringify(game.snapshot()))
	retired.player.gear["q:1"].type = "e:nothing:1:none::0"
	var lenient := Session.new()
	check(lenient.restore(retired) and lenient.player.equipment.robe == "" and lenient.player.gear.is_empty(), "an instance of a retired type is dropped, not fatal")
