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
	check(gear.slot == "weapon" and gear.tier_name == "灵器" and gear.name.ends_with("玄铁剑") and int(gear.stats.attack) == 10, "equipment is described by its id")
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
	check(game.active_skills() == ["qi_strike", "qi_shield", "qi_gather", "sword", "seal_metal"], "a journey starts with the wanderer's three 气 arts, and the first root's small art and 印")
	var low := "j:t:breath:wood:1::0"
	game.add_item(low, 1)
	var day := int(game.world.day)
	game.study_manual(low)
	check(int(game.world.day) == day + 8 and "t:breath:wood:1::0" in game.player.learned and game.player.methods == ["t:breath:wood:1::0"], "studying a slip takes the tier's days (a fifth less for a wood art with a wood root) and fills a free 心法 slot")
	check(game.item_count(low) == 0 and game.journal_lines().back().contains("习得"), "the slip is used up and the learning recorded")
	game.add_item("j:t:burst:fire:5::0", 1)
	check(game.study_manual("j:t:burst:fire:5::0").contains("筑基初期"), "a 天阶 art is three realms beyond 炼气: it waits for 筑基")
	game.add_item("j:t:bolt:water:1::0", 1)
	game.study_manual("j:t:bolt:water:1::0")
	check(game.active_skills().size() == 6, "the sixth art slot fills")
	game.add_item("j:t:bolt:earth:1::0", 1)
	game.study_manual("j:t:bolt:earth:1::0")
	check(game.active_skills().size() == 6 and "t:bolt:earth:1::0" in game.player.learned, "a seventh art is learned but waits outside the slots")
	check(game.equip_technique("t:bolt:earth:1::0").contains("栏位已满"), "a full row needs a choice")
	game.equip_technique("t:bolt:earth:1::0", "seal_metal")
	check("t:bolt:earth:1::0" in game.active_skills() and not "seal_metal" in game.active_skills(), "swapping an art")
	for art: String in game.active_skills().duplicate():
		game.unequip_technique(art)
	check(game.active_skills().size() == 1, "at least one art always stays")
	var learned: int = game.player.learned.size()
	check(game.choose_sect("chixiao").contains("只传本门") and game.player.learned.size() == learned and str(game.player.sect) == "wanderer", "the hall teaches no other sect's lineage")
	var study_from := int(game.world.day)
	game.choose_sect("qingyun")
	check(game.active_skills().slice(0, 3) == ["sword", "sword_rain", "sword_arc"] and "sword_arc" in game.player.learned and int(game.world.day) == study_from + 30, "studying the home lineage takes a month, then teaches and slots its arts first")
	check(game.choose_sect("qingyun").contains("已在研习"), "and is studied once")

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
	_mastery()

## 驾驭度 (docs/WORLD_EXPANSION.md 2.3): a piece above its wielder's realm gives half its stats and one
## affix a realm short, a fifth and none two short, and cannot be used three short.
func _mastery() -> void:
	var game := _game()
	var content = game.content
	var blade: Dictionary = content.equipment(Arsenal.equipment_id("sword", 3, "none", ["sharp", "tough"], 0))
	check(int(blade.realm) == 1 and blade.affix_stats.size() == 2, "a 灵器 is wielded fully from 筑基")
	var full := Arsenal.wielded(content, blade, 1)
	check(full.usable and is_equal_approx(float(full.share), 1.0) and full.stats == blade.stats, "at 筑基 all of it")
	var short := Arsenal.wielded(content, blade, 0)
	check(short.usable and is_equal_approx(float(short.share), 0.5) and int(short.affixes) == 1 and int(short.stats.attack) < int(blade.stats.attack) and not short.stats.has("max_hp"), "at 炼气 half its stats and only its first affix (%s)" % [short.stats])
	var treasure: Dictionary = content.equipment(Arsenal.equipment_id("sword", 5, "none", ["sharp"], 0))
	check(int(Arsenal.wielded(content, treasure, 1).affixes) == 0 and is_equal_approx(float(Arsenal.wielded(content, treasure, 1).share), 0.2), "a 灵宝 at 筑基: a fifth, no affix")
	check(not Arsenal.wielded(content, treasure, 0).usable, "and beyond reach for 炼气")
	var base := int(game.attack_bonus())
	var blade_id: String = blade.id
	game.add_item(blade_id, 1)
	game.equip_item(blade_id)
	check(int(game.attack_bonus()) == base + int(short.stats.attack), "worn at 炼气, the 灵器 adds only what can be drawn on")
	var treasure_id: String = treasure.id
	game.add_item(treasure_id, 1)
	check(game.equip_item(treasure_id).contains("元婴") and game.item_count(treasure_id) == 1, "a 灵宝 refuses a 炼气 wielder and stays in the pack")
	check(Arsenal.mastery_text(content, blade, 0).contains("50%") and Arsenal.mastery_text(content, blade, 1).is_empty(), "the bag says how much can be drawn on")

func _fight(technique_id: String) -> Session:
	var game := _game(["water"])
	game.player.learned.append(technique_id)
	game.player.arts = [technique_id]
	game.start_battle("disciple")
	game.combat_rng.seed = 5
	# Orbs enough for any one art.
	game.battle.orbs = []
	for element: String in game.Combat.elements(game):
		game.battle.orbs.append_array([element, element, element])
	return game

func _effects() -> void:
	var burn := _fight("t:bolt:fire:2:burn:0")
	burn.use_skill("t:bolt:fire:2:burn:0")
	var first: Dictionary = burn.combat_events[0]
	check(first.name == "赤焰诀" and first.vfx == "flame_bolt" and first.tier == 2 and first.style == "t:bolt:fire:2:burn:0", "events carry the generated art's name, effect and tier")
	burn.end_turn()
	check(burn.combat_events.any(func(event: Dictionary) -> bool: return event.get("style", "") == "burn"), "burning ticks before the opponent strikes")
	check(int(burn.battle.status.burn[1]) == 2, "the burn counts down")
	check(not first.has("legacy"), "a generated art carries no lineage")
	var disciple := _game(["metal"])
	disciple.choose_sect("qingyun")
	disciple.start_battle("disciple")
	disciple.battle.orbs = ["metal", "metal", "metal"]
	disciple.use_skill("sword_rain")
	check(disciple.combat_events[0].get("legacy", "") == "qingyun", "a sect's own art cast by its disciple carries the lineage's layer")
	var wanderer := _game(["metal"])
	wanderer.start_battle("disciple")
	_sword(wanderer)
	check(not wanderer.combat_events[0].has("legacy"), "a wanderer's arts have no lineage")
	var chill := _fight("t:bolt:water:2:chill:0")
	chill.use_skill("t:bolt:water:2:chill:0")
	chill.end_turn()
	check(chill.battle.status.has("weaken") and int(chill.battle.status.weaken[1]) == 1, "a chilled opponent is weakened for the next turns")
	# 破甲: the sundered take more, for two of their turns.
	var sunder := _fight("t:burst:fire:2:sunder:0")
	sunder.use_skill("t:burst:fire:2:sunder:0")
	check(sunder.battle.status.has("sunder") and int(sunder.battle.status.sunder[1]) == 2, "a sundering art lays 破甲 on the opponent")
	sunder.end_turn()
	check(int(sunder.battle.status.sunder[1]) == 1, "破甲 counts down at the opponent's turn")
	# 冰封: an opponent without orbs strikes weaker; a slowed player draws one orb fewer.
	var frost := _fight("t:bolt:water:2:frost:0")
	frost.use_skill("t:bolt:water:2:frost:0")
	check(frost.battle.status.has("slow"), "a freezing art lays 冰封 on the opponent")
	var slowed := _fight("t:bolt:metal:1::0")
	slowed.battle.orbs = []
	slowed.battle.player_status["slow"] = [1, 2]
	slowed.end_turn()
	check(slowed.battle.is_empty() or slowed.battle.orbs.size() == slowed.Combat.draw_count(slowed) - 1, "a slowed player draws one orb fewer")
	var hit := _fight("t:bolt:metal:1::0")
	hit.battle.player_status["sunder"] = [0.5, 2]
	hit.battle.orbs = []
	var hp_before_hit := int(hit.player.hp)
	hit.end_turn()
	var taken := hp_before_hit - int(hit.player.hp)
	check(taken >= int(round(6 * (1.0 - hit.defense()) * 1.5)) - 1, "a sundered player takes more (%d)" % taken)
	var drain := _fight("t:bolt:wood:2:drain:0")
	drain.player.hp = 30
	drain.use_skill("t:bolt:wood:2:drain:0")
	check(drain.combat_events.filter(func(event: Dictionary) -> bool: return event.type == "heal").size() == 1, "draining heals the caster")
	var echo := _fight("t:bolt:metal:2:echo:0")
	echo.use_skill("t:bolt:metal:2:echo:0")
	check(int(echo.combat_events[0].hits) == 2, "an echoing art hits twice")
	var renew := _fight("t:mend:wood:2:renew:0")
	renew.player.hp = 20
	var wood_before: int = renew.battle.orbs.count("wood")
	renew.use_skill("t:mend:wood:2:renew:0")
	check(renew.battle.orbs.count("wood") == wood_before - 2 + 1 and int(renew.player.hp) > 20, "a renewing heal brings back an orb of its element")
	var guarded := _fight("t:ward:earth:1::0")
	guarded.use_skill("t:ward:earth:1::0")
	check(guarded.combat_events[0].type == "guard" and int(guarded.battle.shield) == int(round(float(guarded.content.technique("t:ward:earth:1::0").shield) * guarded.Combat.realm_power(guarded, 0) * (1.3 if guarded.combat_events.any(func(event: Dictionary) -> bool: return event.type == "combo") else 1.0))), "a ward raises a shield")
	var hp_before := int(guarded.player.hp)
	guarded.end_turn()
	var soaked: int = guarded.combat_events.filter(func(event: Dictionary) -> bool: return event.get("actor", "") == "enemy").reduce(func(sum: int, event: Dictionary) -> int: return sum + int(event.get("absorbed", 0)), 0)
	check(soaked > 0 and int(guarded.player.hp) == hp_before - guarded.combat_events.filter(func(event: Dictionary) -> bool: return event.get("actor", "") == "enemy").reduce(func(sum: int, event: Dictionary) -> int: return sum + int(event.amount), 0), "the shield takes the blows before health")
	var plain := _fight("t:bolt:metal:1::0")
	var bolt: Dictionary = plain.content.technique("t:bolt:metal:1::0")
	plain.use_skill("t:bolt:metal:1::0")
	var plain_damage: int = plain.combat_events[0].amount
	var share := int(round(float(plain.attack_bonus()) * 2.0 / 2.0))
	var factor: float = plain.element_multiplier(bolt)
	check(plain_damage >= int(round((int(bolt.damage_min) + share) * factor)) and plain_damage <= int(round((int(bolt.damage_max) + share) * factor)), "a 凡品 bolt hits for its base damage (%d)" % plain_damage)

func _teaching_and_stock() -> void:
	var game := _game()
	game.encounters_enabled = false
	game.travel("ridge")
	check(game.teachings().is_empty(), "nothing is taught outside the sect")
	check(game.take_slip("t:breath:wood:1::0") == "这里不传授此法。", "slips come from the hall")
	game.add_item("j:t:breath:wood:1::0", 1)
	check(game.study_manual("j:t:breath:wood:1::0").contains("静室") and game.item_count("j:t:breath:wood:1::0") == 1, "a slip is not studied on the road: 领悟 needs seclusion")
	check(game.comprehend("sword").contains("静室"), "nor is a layer")
	# A room let by the month at the inn will do, for its rent.
	game.travel("town")
	var rent_from := int(game.player.stones)
	var studied := game.study_manual("j:t:breath:wood:1::0")
	check("t:breath:wood:1::0" in game.player.learned and int(game.player.stones) < rent_from, "in the inn's 静房 a slip is studied, the room paid for (%s)" % studied.left(30))
	game.travel("sect")
	check(game.available_here("teach"), "the sect's 传功堂 teaches")
	check(game.teachings().size() == 4, "four entry techniques are taught")
	var day := int(game.world.day)
	game.take_slip("t:body:earth:1::5")
	check(int(game.world.day) == day and game.item_count("j:t:body:earth:1::5") == 1 and not "t:body:earth:1::5" in game.player.learned, "the hall hands out the slip at once; nothing is learned yet")
	check(game.take_slip("t:body:earth:1::5").contains("已领过") and game.item_count("j:t:body:earth:1::5") == 1, "one slip each")
	game.study_manual("j:t:body:earth:1::5")
	check(int(game.world.day) == day + 10 and "t:body:earth:1::5" in game.player.methods, "studied in the chamber, it takes its days")
	check(game.take_slip("t:body:earth:1::5").contains("已习得"), "and is not handed out again")
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
	_sword(game)
	var loot: Array = game.player.items.keys().filter(func(item_id: String) -> bool: return item_id.begins_with("j:") or item_id.begins_with("e:"))
	check(loot.size() == 1 and game.journal_lines().any(func(line: String) -> bool: return line.contains("缴获")), "a defeated cultivator drops a slip or a piece of equipment")
	check(int(game.content.item(loot[0]).tier) == 2, "the drop has the enemy's tier")

func _saves() -> void:
	var lineage := Session.new()
	check(lineage.restore(JSON.parse_string(FileAccess.get_file_as_string("res://tests/fixtures/v7_chixiao.json"))), "v7 save migrates")
	check(lineage.active_skills() == ["flame_bolt", "fire", "fire_burst", "qi_strike", "qi_shield", "qi_gather"] and lineage.player.methods.is_empty() and int(lineage.world.seed) > 0, "an old 赤霄门 journey keeps its lineage arts, and learns the 气 arts into its free slots")
	var fighting := Session.new()
	check(fighting.restore(JSON.parse_string(FileAccess.get_file_as_string("res://tests/fixtures/v7_battle.json"))) and fighting.battle.status.is_empty() and fighting.battle.orbs.size() > 0 and not fighting.battle.intent.is_empty(), "a v7 duel resumes with a fresh hand of qi orbs")
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
	check(_broken(func(c) -> void: c.vfx_tiers[4].rune = 0).contains("低于上一阶"), "a layer that has unlocked never falls back")
	check(_broken(func(c) -> void: c.vfx_tiers[4].zoom = 0).contains("任何品阶都不出现"), "every unlocking layer appears at some tier")
	check(_broken(func(c) -> void: c.vfx_legacy.erase("canglan")).contains("传承特效"), "every sect has a signature layer")
	check(_broken(func(c) -> void: c.technique_data.archetypes.bolt.vfx.fire = "meteor").contains("缺少特效"), "an art without a known effect is reported")
	check(_broken(func(c) -> void: c.technique_data.tiers[3].power = 1.2).contains("品阶配置错误"), "tiers must grow in power")
	check(_broken(func(c) -> void: c.locations.sect.spots.filter(func(spot: Dictionary) -> bool: return spot.id == "hall")[0].teach.append("t:comet:fire:1::0")).contains("无效的功法"), "teaching an invalid technique is reported")
	check(_broken(func(c) -> void: c.enemies.rogue.drops = {"chance": 0.5}).contains("掉落配置"), "malformed drops reported")

## Casts 御剑诀 with the orbs it asks (金×1、任意×1): a journey begins with it only on a metal root.
func _sword(game) -> String:
	if not "sword" in game.player.learned:
		game.player.learned.append("sword")
	if not "sword" in game.player.arts:
		game.player.arts.append("sword")
	game.battle.orbs.append_array(["metal", "metal"])
	return game.use_skill("sword")
