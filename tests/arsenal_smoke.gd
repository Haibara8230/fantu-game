extends SceneTree
## M3c: generated techniques and equipment, learning and slots, derived stats, combat effects,
## teaching, rotating stock, drops, saves and tiered effects.
const Session = preload("res://scripts/core/session.gd")
const Content = preload("res://scripts/core/content.gd")
const Arsenal = preload("res://scripts/core/arsenal.gd")
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
	check(content.load_data(), "content with techniques and equipment loads: " + content.error_message)
	_ids(content)
	_scaling(content)
	_generation(content)
	_learning()
	_bonuses()
	_effects()
	_teaching_and_stock()
	_drops()
	_saves()
	_static_checks()
	print("ARSENAL: %d checks, %d failures" % [checks, failures])
	quit(0 if failures == 0 else 1)

func _game(roots: Array = ["metal", "wood", "fire"]) -> Session:
	var game := Session.new()
	game.encounters_enabled = false
	game.new_game("铸剑", 3, roots)
	return game

func _ids(content: Content) -> void:
	check(Arsenal.technique_id("bolt", "fire", 2, ["burn"], 3) == "t:bolt:fire:2:burn:3", "technique ids are canonical")
	check(Arsenal.technique_id("burst", "fire", 3, ["pierce", "burn"], 0) == Arsenal.technique_id("burst", "fire", 3, ["burn", "pierce"], 0), "affix order does not matter")
	var bolt := content.technique("t:bolt:fire:2:burn:3")
	check(bolt.name == "炎阳诀" and bolt.tier_name == "黄阶" and bolt.burn == [5, 3], "a generated technique is fully described by its id")
	for bad: String in ["t:bolt:fire:9::0", "t:comet:fire:1::0", "t:bolt:void:1::0", "t:mend:fire:2:burn:0", "t:bolt:fire:3:burn+burn:0", "t:bolt:fire:1::-2", "t:bolt:fire", "sword_dance"]:
		check(content.technique(bad).is_empty(), "malformed technique rejected: " + bad)
	check(content.technique("sword").name == "御剑诀" and content.technique("sword").tier == 2 and content.technique("sword").element == "metal", "handwritten sect arts share the same model")
	var gear := content.equipment("e:sword:3:fire:sharp+tough:2")
	check(gear.slot == "weapon" and gear.tier_name == "玄阶" and gear.name.ends_with("玄铁剑") and int(gear.stats.attack) == 10, "equipment is described by its id")
	check(content.equipment("e:sword:3:fire:sharp+sharp:2").is_empty() and content.equipment("e:cannon:1:none::0").is_empty(), "malformed equipment rejected")
	var manual := content.item("j:t:bolt:fire:2:burn:3")
	check(manual.category == "manual" and manual.teaches == "t:bolt:fire:2:burn:3" and manual.name == "《炎阳诀》玉简", "jade slips teach the technique in their id")

func _scaling(content: Content) -> void:
	var data: Dictionary = content.technique_data
	var all_valid := true
	var rising := true
	for archetype: String in data.archetypes:
		for element: String in data.elements:
			var previous := {}
			for tier: int in range(1, data.tiers.size() + 1):
				var t := content.technique(Arsenal.technique_id(archetype, element, tier, [], 0))
				all_valid = all_valid and not t.is_empty() and not str(t.description).is_empty()
				if t.slot == "art" and not previous.is_empty():
					if t.has("damage_max"):
						rising = rising and int(t.damage_max) > int(previous.damage_max)
					if t.has("heal"):
						rising = rising and int(t.heal) > int(previous.heal)
				if not previous.is_empty():
					rising = rising and int(t.value) > int(previous.value)
				previous = t
	check(all_valid, "every archetype, element and tier forms a valid technique")
	check(rising, "each tier is strictly stronger and dearer than the last")
	var previous_hp := 0.0
	for tier: int in range(1, 6):
		var robe := content.equipment(Arsenal.equipment_id("robe", tier, "none", [], 0))
		check(float(robe.stats.max_hp) > previous_hp, "robes grow with tier (%d)" % tier)
		previous_hp = float(robe.stats.max_hp)

func _generation(content: Content) -> void:
	var rng := RandomNumberGenerator.new()
	rng.seed = 11
	var ids := {}
	var valid := true
	var affixes_right := true
	for i: int in range(1000):
		var tier := 1 + i % 5
		var id := Arsenal.generate_technique(content, rng, tier)
		var t := content.technique(id)
		valid = valid and not t.is_empty()
		var applicable: int = content.technique_data.affixes.values().filter(func(affix: Dictionary) -> bool: return t.archetype in affix.applies).size()
		affixes_right = affixes_right and t.affixes.size() == mini(int(content.technique_data.tiers[tier - 1].affixes), applicable)
		ids[id] = true
	check(valid and affixes_right, "generated techniques are valid with the tier's number of affixes")
	check(ids.size() > 900, "a thousand rolls give over nine hundred distinct techniques (%d)" % ids.size())
	var again := RandomNumberGenerator.new()
	again.seed = 11
	check(Arsenal.generate_technique(content, again, 1) == Arsenal.generate_technique(content, _seeded(11), 1), "generation is reproducible from the seed")
	var gear := {}
	for i: int in range(500):
		gear[Arsenal.generate_equipment(content, rng, 1 + i % 5)] = true
	check(gear.size() > 400, "five hundred rolls give over four hundred distinct pieces (%d)" % gear.size())
	check(content.equipment(Arsenal.generate_equipment(content, rng, 2, "robe")).slot == "robe", "slot filter respected")
	# Preview of the M3 uniqueness goal: whole loadouts of four arts, two 心法 and three pieces.
	var loadouts := {}
	for i: int in range(200):
		var parts: Array[String] = []
		for slot: int in range(4):
			parts.append(Arsenal.generate_technique(content, rng, 1 + rng.randi_range(0, 1), {"slot": "art"}))
		for slot: int in range(2):
			parts.append(Arsenal.generate_technique(content, rng, 1 + rng.randi_range(0, 1), {"slot": "method"}))
		for slot: String in ["weapon", "robe", "accessory"]:
			parts.append(Arsenal.generate_equipment(content, rng, 1 + rng.randi_range(0, 1), slot))
		parts.sort()
		loadouts["|".join(parts)] = true
	check(loadouts.size() == 200, "two hundred random loadouts are all different")

func _seeded(value: int) -> RandomNumberGenerator:
	var rng := RandomNumberGenerator.new()
	rng.seed = value
	return rng

func _learning() -> void:
	var game := _game()
	check(game.active_skills() == ["sword", "fire", "wood"], "a journey starts with the wanderer's three arts")
	var low := "j:t:breath:wood:1::0"
	game.add_item(low, 1)
	var day := int(game.world.day)
	game.study_manual(low)
	check(int(game.world.day) == day + 10 and "t:breath:wood:1::0" in game.player.learned and game.player.methods == ["t:breath:wood:1::0"], "studying a slip takes the tier's days and fills a free 心法 slot")
	check(game.item_count(low) == 0 and game.journal_lines().back().contains("习得"), "the slip is used up and the learning recorded")
	game.add_item("j:t:burst:fire:3::0", 1)
	check(game.study_manual("j:t:burst:fire:3::0").contains("筑基初期"), "a 玄阶 art needs 筑基")
	game.add_item("j:t:bolt:water:1::0", 1)
	game.study_manual("j:t:bolt:water:1::0")
	check(game.active_skills().size() == 4, "the fourth art slot fills")
	game.add_item("j:t:bolt:earth:1::0", 1)
	game.study_manual("j:t:bolt:earth:1::0")
	check(game.active_skills().size() == 4 and "t:bolt:earth:1::0" in game.player.learned, "a fifth art is learned but waits outside the slots")
	check(game.equip_technique("t:bolt:earth:1::0").contains("栏位已满"), "a full row needs a choice")
	game.equip_technique("t:bolt:earth:1::0", "wood")
	check("t:bolt:earth:1::0" in game.active_skills() and not "wood" in game.active_skills(), "swapping an art")
	for art: String in game.active_skills().duplicate():
		game.unequip_technique(art)
	check(game.active_skills().size() == 1, "at least one art always stays")
	game.choose_sect("chixiao")
	check(game.active_skills() == ["flame_bolt", "fire", "fire_burst"] and "fire_burst" in game.player.learned, "taking up a lineage teaches and slots its arts")

func _bonuses() -> void:
	var game := _game()
	var base_hp := int(game.player.max_hp)
	game.player.learned.append("t:body:earth:1::0")
	game.equip_technique("t:body:earth:1::0")
	check(int(game.player.max_hp) == base_hp + 15, "a 炼体 心法 raises max health")
	var robe := Arsenal.equipment_id("vest", 2, "none", ["guard"], 0)
	game.add_item(robe, 1)
	game.equip_item(robe)
	check(game.item_count(robe) == 0 and game.player.equipment.robe == robe and game.defense() > 0.1 and int(game.player.max_hp) == base_hp + 15 + 11, "wearing a vest moves it out of the 行囊 and adds its stats")
	var second := Arsenal.equipment_id("robe", 1, "none", [], 1)
	game.add_item(second, 1)
	game.equip_item(second)
	check(game.item_count(robe) == 1 and game.player.equipment.robe == second, "changing robes puts the old one back")
	game.unequip_slot("robe")
	check(game.item_count(second) == 1 and int(game.player.max_hp) == base_hp + 15, "taking it off removes its stats")
	var fan := Arsenal.equipment_id("fan", 2, "fire", ["attune"], 0)
	game.add_item(fan, 1)
	game.equip_item(fan)
	check(is_equal_approx(game.element_multiplier(game.content.technique("fire")), 1.0 + 0.07 + 0.07 + 0.1), "a fire fan boosts fire arts, on top of the fire root")
	check(is_equal_approx(game.element_multiplier(game.content.technique("water")), 1.0), "and leaves other elements alone")
	var calm := _game()
	var ring := Arsenal.equipment_id("ring", 2, "none", ["calm"], 0)
	calm.add_item(ring, 1)
	calm.equip_item(ring)
	check(calm.cultivation_rate() > 60, "a ring of calm speeds cultivation (%d)" % calm.cultivation_rate())

func _fight(technique_id: String) -> Session:
	var game := _game(["water"])
	game.player.learned.append(technique_id)
	game.player.arts = [technique_id]
	game.start_battle("disciple")
	game.combat_rng.seed = 5
	return game

func _effects() -> void:
	var burn := _fight("t:bolt:fire:2:burn:0")
	burn.use_skill("t:bolt:fire:2:burn:0")
	var first: Dictionary = burn.combat_events[0]
	check(first.name == "赤焰诀" and first.vfx == "flame_bolt" and first.tier == 2 and first.style == "t:bolt:fire:2:burn:0", "events carry the generated art's name, effect and tier")
	check(burn.combat_events.any(func(event: Dictionary) -> bool: return event.get("style", "") == "burn"), "burning ticks before the opponent strikes")
	check(int(burn.battle.status.burn[1]) == 2, "the burn counts down")
	var chill := _fight("t:bolt:water:2:chill:0")
	chill.use_skill("t:bolt:water:2:chill:0")
	check(chill.battle.status.has("weaken") and int(chill.battle.status.weaken[1]) == 1, "a chilled opponent is weakened for the next turns")
	var drain := _fight("t:bolt:wood:2:drain:0")
	drain.player.hp = 30
	drain.use_skill("t:bolt:wood:2:drain:0")
	check(drain.combat_events.filter(func(event: Dictionary) -> bool: return event.type == "heal").size() == 1, "draining heals the caster")
	var echo := _fight("t:bolt:metal:2:echo:0")
	echo.use_skill("t:bolt:metal:2:echo:0")
	check(int(echo.combat_events[0].hits) == 2, "an echoing art hits twice")
	var renew := _fight("t:mend:wood:2:renew:0")
	renew.player.hp = 20
	renew.player.qi = 20
	renew.use_skill("t:mend:wood:2:renew:0")
	check(int(renew.player.qi) == 20 - 8 + 3 and int(renew.player.hp) > 20, "a renewing heal returns some qi")
	var guarded := _fight("t:ward:earth:1::0")
	var hp_before := int(guarded.player.hp)
	guarded.use_skill("t:ward:earth:1::0")
	check(guarded.combat_events[0].type == "guard" and int(guarded.player.hp) <= hp_before + 12, "a ward heals and guards")
	var plain := _fight("t:bolt:metal:1::0")
	plain.use_skill("t:bolt:metal:1::0")
	var plain_damage: int = plain.combat_events[0].amount
	check(plain_damage >= 11 and plain_damage <= 15, "a 凡品 bolt hits for its base damage (%d)" % plain_damage)

func _teaching_and_stock() -> void:
	var game := _game()
	game.encounters_enabled = false
	game.travel("town")
	check(game.teachings().is_empty(), "nothing is taught outside the sect")
	check(game.learn_here("t:breath:wood:1::0") == "这里不传授此法。", "learning needs the hall")
	game.travel("sect")
	check(game.available_here("teach"), "the sect's 传功堂 teaches")
	check(game.teachings().size() == 4, "four entry techniques are taught")
	var day := int(game.world.day)
	game.learn_here("t:body:earth:1::5")
	check(int(game.world.day) == day + 10 and "t:body:earth:1::5" in game.player.methods, "learning at the hall takes days too")
	game.travel("market")
	var stock: Array[Dictionary] = game.rotating_stock("market")
	check(stock.size() == 5 and stock.filter(func(good: Dictionary) -> bool: return str(good.item).begins_with("j:")).size() == 3, "the market stocks three slips and two pieces of equipment")
	var twin := _game()
	twin.world.day = game.world.day
	check(twin.rotating_stock("market") == stock, "stock depends only on world, place and month")
	var other := Session.new()
	other.new_game("他人", 4)
	other.world.day = game.world.day
	check(other.rotating_stock("market") != stock, "another world has other stock")
	game.player.stones = 5000
	var bought: String = stock[0].item
	game.buy(bought)
	check(game.item_count(bought) == 1 and game.rotating_stock("market").size() == 4, "bought stock is gone until the restock")
	game.wait(30)
	check(game.rotating_stock("market").size() == 5 and game.rotating_stock("market") != stock, "a month later the stock is new")

func _drops() -> void:
	var game := _game()
	game.world.flags.found_ruin = true
	game.travel("ruin")
	game.interact("squatter", "fight")
	game.battle.hp = 1
	game.use_skill("sword")
	var loot: Array = game.player.items.keys().filter(func(item_id: String) -> bool: return item_id.begins_with("j:") or item_id.begins_with("e:"))
	check(loot.size() == 1 and game.journal_lines().any(func(line: String) -> bool: return line.contains("缴获")), "a defeated cultivator drops a slip or a piece of equipment")
	check(int(game.content.item(loot[0]).tier) == 2, "the drop has the enemy's tier")

func _saves() -> void:
	var lineage := Session.new()
	check(lineage.restore(JSON.parse_string(FileAccess.get_file_as_string("res://tests/fixtures/v7_chixiao.json"))), "v7 save migrates")
	check(lineage.active_skills() == ["flame_bolt", "fire", "fire_burst"] and lineage.player.methods.is_empty() and int(lineage.world.seed) > 0, "an old 赤霄门 journey keeps its lineage arts")
	var fighting := Session.new()
	check(fighting.restore(JSON.parse_string(FileAccess.get_file_as_string("res://tests/fixtures/v7_battle.json"))) and int(fighting.battle.cooldowns.ice_lance) == 2 and fighting.battle.status.is_empty(), "a v7 duel resumes")
	var game := _game()
	game.player.learned.append("t:burst:fire:2:pierce:4")
	game.player.arts.append("t:burst:fire:2:pierce:4")
	var gear := Arsenal.equipment_id("pendant", 2, "water", ["spirit"], 3)
	game.add_item(gear, 1)
	game.equip_item(gear)
	game.add_item("j:t:affinity:fire:2:deep:1", 1)
	var copy := Session.new()
	check(copy.restore(JSON.parse_string(JSON.stringify(game.snapshot()))) and copy.snapshot() == game.snapshot(), "generated techniques, worn equipment and slips survive a save")
	var odd: Dictionary = game.snapshot()
	odd.player.learned.append("t:comet:fire:1::0")
	odd.player.arts.append("t:comet:fire:1::0")
	odd.player.equipment.weapon = "e:robe:1:none::0"
	check(copy.restore(odd) and not "t:comet:fire:1::0" in copy.player.learned and copy.player.equipment.weapon == "", "retired or misplaced entries are dropped, not fatal")

func _broken(change: Callable) -> String:
	var content := Content.new()
	content.load_data()
	change.call(content)
	return content._validate()

func _static_checks() -> void:
	check(_broken(func(c) -> void: c.vfx_tiers[2].rings = 1).contains("没有高于上一阶"), "a tier whose effects do not rise is reported")
	check(_broken(func(c) -> void: c.technique_data.archetypes.bolt.vfx.fire = "meteor").contains("缺少特效"), "an art without a known effect is reported")
	check(_broken(func(c) -> void: c.technique_data.tiers[3].power = 1.2).contains("品阶配置错误"), "tiers must grow in power")
	check(_broken(func(c) -> void: c.locations.sect.spots.filter(func(spot: Dictionary) -> bool: return spot.id == "hall")[0].teach.append("t:comet:fire:1::0")).contains("无效的功法"), "teaching an invalid technique is reported")
	check(_broken(func(c) -> void: c.enemies.rogue.drops = {"chance": 0.5}).contains("掉落配置"), "malformed drops reported")
