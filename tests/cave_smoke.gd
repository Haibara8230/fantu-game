extends SceneTree
## 神识 and the old cave's rooms: the stat and what it unifies (people's talents, the riverbed, the
## 灵眼), the cave opening after its squatter leaves, rooms entered one by one with their traps, things,
## hidden places, seal and guardian, the same cave in the same world, saves, and the cave's scroll.
const Session = preload("res://scripts/core/session.gd")
const Store = preload("res://scripts/core/save_store.gd")
var checks := 0
var failures := 0
var main

func check(condition: bool, message: String) -> void:
	checks += 1
	if not condition:
		failures += 1
		printerr("FAIL: " + message)

func _initialize() -> void:
	# A script error aborts before quit(); the watchdog turns that hang into a failure.
	create_timer(120.0).timeout.connect(func() -> void: printerr("TIMEOUT: test did not finish (likely a script error)"); quit(1))
	# The scroll needs the scene tree running.
	call_deferred("_run")

func _run() -> void:
	_content()
	_sense()
	_rooms()
	_guardian()
	_saves()
	_chenxia()
	_dihuo()
	_flux()
	await _scroll()
	print("CAVES: %d checks, %d failures" % [checks, failures])
	quit(0 if failures == 0 else 1)

func _game(stage: int = 0, born: Dictionary = {}, seed_value: int = 31) -> Session:
	var game := Session.new()
	game.encounters_enabled = false
	game.new_game("洞府", seed_value, ["metal", "wood", "fire"], "plain", born)
	game.player.stage = stage
	game.refresh_realm_stats()
	game.player.hp = game.player.max_hp
	game.player.qi = game.player.max_qi
	return game

## 地火熔窟 in 天南 (stage two, batch C): open once 天南 is known; a trap, a vein of 地火精, the 火蜥
## guarding the way, and the 地火之心 that asks a 避火珠 or 神识 45.
func _dihuo() -> void:
	var game := _game(0)
	game.player.realm = 1
	game.player.stage = 0
	game.refresh_realm_stats()
	game.player.hp = game.player.max_hp
	game.player.location = "chifeng"
	check(game.cave_here().is_empty(), "the 熔窟 is not known before 天南 is")
	game.world.flags["tiannan_known"] = true
	check(game.cave_here() == "dihuo", "at 赤枫岭 the 地火熔窟 can be explored")
	game.enter_room("dihuo", "tunnel")
	game.enter_room("dihuo", "vein")
	check(game.Caves.explored(game, "dihuo", "vein"), "the vein is reached")
	var before := game.item_count("dihuo_jing")
	game.enter_room("dihuo", "nest")
	check(game.battle.get("enemy_id", "") == "huo_xi", "a 火蜥 guards its nest")
	game.battle.hp = 1
	game.battle.orbs = ["water", "water", "water"]
	for skill_id: String in game.player.arts:
		if game.battle.is_empty():
			break
		game.use_skill(skill_id)
	if not game.battle.is_empty():
		game.battle.hp = 0
		game.use_skill(game.player.arts[0])
	check(game.has_flag("dihuo_lizard_down") and game.Caves.reachable(game, "dihuo", "core"), "fallen, the way to the 地火之心 opens")
	var roots: Array = game.player.roots
	check(game.Caves.enter_block(game, "dihuo", "core").is_empty(), "a fire root finds its own way through the heat")
	game.player.roots = ["metal", "wood", "water"]
	var blocked: String = game.Caves.enter_block(game, "dihuo", "core")
	check(blocked.contains("避火珠") and blocked.contains("神识 45"), "without one, the heat asks a 避火珠, or 神识 45 to find a cooler way (%s)" % blocked)
	game.player.roots = roots
	game.set_item_count("bihuo_zhu", 1)
	check(game.Caves.enter_block(game, "dihuo", "core").is_empty(), "with a 避火珠 the heat gives way")
	var keen := _game(0)
	keen.world.flags["tiannan_known"] = true
	keen.world.flags["dihuo_lizard_down"] = true
	keen.player.location = "chifeng"
	keen.world.caves = {"dihuo": {"explored": ["mouth", "tunnel", "nest"], "taken": [], "fortune": {}}}
	keen.player.realm = 2
	keen.player.stage = 0
	keen.refresh_realm_stats()
	check(keen.sense() >= 45 and keen.item_count("bihuo_zhu") == 0 and keen.Caves.enter_block(keen, "dihuo", "core").is_empty(), "a 金丹's 神识 finds the cooler way without the pearl")
	check(game.content.item("bihuo_zhu").category == "tool" and game.content.item("dihuo_jing").category == "material", "the pearl is a tool, the 地火精 a material")
	check(before >= 0 and game.content.locations.nanming.shop.any(func(good: Dictionary) -> bool: return good.item == "dihuo_jing") and game.content.locations.chifeng.gather.table.any(func(entry: Dictionary) -> bool: return entry.item == "dihuo_jing"), "地火精 is sold at 南明 and found now and then at 赤枫岭, so it never runs out")

## 地火精 in the furnace: one more spent, one more affix on the piece.
func _flux() -> void:
	var plain := _game(0)
	var fired := _game(0)
	for game: Session in [plain, fired]:
		game.player.location = "market"
		game.player.stones = 500
		game.set_item_count("ore_xuantie", 3)
	fired.set_item_count("dihuo_jing", 1)
	var plan := {"material": "ore_xuantie", "base": "sword", "element": "fire"}
	var with_flux := plan.duplicate()
	with_flux.flux = true
	check(plain.Forge.block(plain, with_flux).contains("地火精"), "no 地火精, no flux")
	plain.forge_item(plan.duplicate())
	fired.forge_item(with_flux)
	var made := func(game: Session) -> Dictionary:
		for item_id: String in game.player.items:
			if item_id.begins_with("e:"):
				return game.content.item(item_id)
		return {}
	var a: Dictionary = made.call(plain)
	var b: Dictionary = made.call(fired)
	check(a.affixes.size() == 2 and b.affixes.size() == 3 and fired.item_count("dihuo_jing") == 0, "a 灵器 sword has two affixes, three with a 地火精 (%d, %d)" % [a.affixes.size(), b.affixes.size()])

func _at_cave(game: Session) -> void:
	game.world.flags["found_ruin"] = true
	game.world.flags["ruin_cleared"] = true
	game.player.location = "ruin"

func _content() -> void:
	var game := Session.new()
	check(game.content.error_message.is_empty(), "the caves load and pass their checks: " + game.content.error_message)
	var broken := Session.new()
	broken.content.cave_data.ruin.rooms[1].links = ["hall", "elixir"]
	check(not broken.content._validate().is_empty(), "a passage that only runs one way is rejected")
	broken = Session.new()
	broken.content.cave_data.ruin.rooms[2].loot = [[{"item": ["no_such_herb", 1]}]]
	check(not broken.content._validate().is_empty(), "things that do not exist are rejected")
	broken = Session.new()
	broken.content.cave_data.ruin.rooms[5].guardian = "wolf"
	check(not broken.content._validate().is_empty(), "a guardian without a world flag to fall by is rejected")

func _sense() -> void:
	var game := _game()
	check(game.sense() == 10, "神识 starts from the stage's (%d)" % game.sense())
	game.player.stage = 3
	check(game.sense() == 16, "and grows with it")
	var seer := _game(0, {"talents": ["tianyan"], "flaws": []})
	check(seer.sense() == 30, "a talent of the eyes adds to it (%d)" % seer.sense())
	# People: their talents show to a keener 神识.
	var someone := ""
	for id: Variant in game.present_npcs():
		if game.is_generated(str(id)) and int(game.person(str(id)).realm) == 0:
			someone = str(id)
			break
	if not someone.is_empty():
		game.player.stage = 0
		check(game.talents_visible(someone) == (game.sense() > game.person_sense(someone)), "talents show exactly when the 神识 is keener than theirs")
		seer.player.stage = 0
		check(seer.talents_visible(someone) or seer.person_sense(someone) >= 30, "a 天眼 sees through a fellow at 炼气")
	check(not someone.is_empty(), "a generated fellow at 炼气 is at the sect to look at")
	# The riverbed asks 神识 30, not foundation itself.
	var dive := {"sense_at_least": 30}
	check(not game.Events.met(game, dive) and seer.Events.met(seer, dive), "probing the riverbed asks 神识, which a 天眼 has before foundation")
	# The 灵眼: found more readily the keener the 神识.
	var dull := _game()
	dull.player.location = "wild"
	dull.fortune = {"lingshen": 0.99, "spirit_eye": 0.025}
	dull.act("gather")
	var keen := _game(3)
	keen.player.location = "wild"
	keen.fortune = {"lingshen": 0.99, "spirit_eye": 0.025}
	keen.act("gather")
	check(not dull.has_flag("spirit_eye_found") and keen.has_flag("spirit_eye_found"), "the same luck finds the 灵眼 with a keener 神识 only")

func _rooms() -> void:
	var game := _game()
	game.player.location = "ruin"
	check(game.cave_here().is_empty(), "the cave is shut while its squatter holds it")
	_at_cave(game)
	check(game.cave_here() == "ruin" and game.available_here("explore_cave"), "once he is gone its depths can be explored")
	var caves = game.Caves
	check(caves.explored(game, "ruin", "hall") and caves.reachable(game, "ruin", "corridor") and not caves.reachable(game, "ruin", "elixir"), "the hall is open; the corridor leads on, the rooms beyond it are not yet in reach")
	check(not game.enter_room("ruin", "elixir").is_empty() and not game.world.caves.has("ruin"), "a room out of reach cannot be entered")
	# A trap springs on a dull 神识 and never fells.
	var day := int(game.world.day)
	game.player.hp = 5
	game.enter_room("ruin", "corridor")
	check(int(game.world.day) == day + 2 and caves.explored(game, "ruin", "corridor"), "entering a room takes its days")
	check(int(game.player.hp) >= 1 and int(game.player.hp) < 5 and game.journal_lines().any(func(line: String) -> bool: return line.contains("骤然发动")), "a trap springs on a dull 神识, but never fells")
	var keen := _game(3)
	_at_cave(keen)
	var hp := int(keen.player.hp)
	keen.enter_room("ruin", "corridor")
	check(int(keen.player.hp) == hp and keen.journal_lines().any(func(line: String) -> bool: return line.contains("识破")), "a keen 神识 sees the trap and passes it")
	# Things are taken on entering; the same world keeps the same ones.
	game.enter_room("ruin", "elixir")
	check(game.world.caves.ruin.taken.has("elixir") and game.journal_lines().any(func(line: String) -> bool: return line.contains("在丹房找到") or line.contains("在丹房拾得")), "the things lying in a room are taken on entering")
	var twin := _game()
	_at_cave(twin)
	check(caves.loot_of(twin, "ruin", "elixir", caves.room(twin, "ruin", "elixir").loot) == caves.loot_of(game, "ruin", "elixir", caves.room(game, "ruin", "elixir").loot), "the same world holds the same things")
	# Hidden places show to 神识 enough, and cost 灵力 to open.
	check(not caves.hidden_seen(game, "ruin", "elixir") or game.sense() >= 12, "a dull 神识 does not see the hidden place")
	check(game.open_hidden("ruin", "elixir").contains("神识不足") , "nor can it open it")
	keen.enter_room("ruin", "elixir")
	var qi := int(keen.player.qi)
	keen.open_hidden("ruin", "elixir")
	check(int(keen.player.qi) == qi - 10 and keen.world.caves.ruin.taken.has("elixir:hidden"), "a keen 神识 opens it for its 灵力")
	keen.player.qi = 3
	keen.enter_room("ruin", "drip")
	check(keen.open_hidden("ruin", "drip").contains("灵力不足"), "without the 灵力 it stays shut")
	# The seal asks 神识 enough.
	game.world.flags["ruin_den_cleared"] = true
	game.player.hp = game.player.max_hp
	game.enter_room("ruin", "study")
	game.enter_room("ruin", "armory")
	check(game.enter_room("ruin", "sealed").contains("禁制"), "a seal stays shut to a dull 神识")
	game.player.stage = 2
	game.refresh_realm_stats()
	game.enter_room("ruin", "sealed")
	check(caves.explored(game, "ruin", "sealed"), "and opens to 神识 enough")

func _guardian() -> void:
	var game := _game(3)
	_at_cave(game)
	for room_id: String in ["corridor", "study"]:
		game.enter_room("ruin", room_id)
	game.enter_room("ruin", "armory")
	check(game.battle.get("enemy_id", "") == "den_wolf", "the guardian falls on whoever enters its room")
	check(not game.Caves.reachable(game, "ruin", "sealed") and not game.Caves.loot_waits(game, "ruin", "armory"), "while it stands, the way on and its room's things are barred")
	# Fleeing may fail (遁逃 by the odds); a failed try costs the turn, not days.
	while not game.battle.is_empty():
		game.player.hp = game.player.max_hp
		game.flee()
	check(game.challenge_guardian("ruin", "armory").contains("斗法") and game.battle.get("enemy_id", "") == "den_wolf", "it can be faced again")
	game.battle.hp = 1
	game.battle.orbs = ["metal"]
	_sword(game)
	check(game.battle.is_empty() and game.has_flag("ruin_den_cleared"), "beaten, it falls for good")
	check(game.Caves.reachable(game, "ruin", "sealed") and game.Caves.loot_waits(game, "ruin", "armory"), "the way on opens and its room's things wait")
	var items: int = game.player.items.size()
	game.collect_room("ruin", "armory")
	check(game.player.items.size() > items and not game.Caves.loot_waits(game, "ruin", "armory"), "they are taken once")

func _saves() -> void:
	var game := _game(3)
	_at_cave(game)
	game.enter_room("ruin", "corridor")
	var copy := Session.new()
	check(copy.restore(JSON.parse_string(JSON.stringify(game.snapshot()))) and copy.world.caves == game.world.caves, "the cave's rooms survive a save")
	var broken: Dictionary = JSON.parse_string(JSON.stringify(game.snapshot()))
	broken.world.caves.ruin.fortune.shiru = "yes"
	check(not Session.new().restore(broken), "a malformed cave is rejected")
	var older: Dictionary = JSON.parse_string(JSON.stringify(game.snapshot()))
	older.world.erase("caves")
	var old := Session.new()
	check(old.restore(older) and old.world.caves.is_empty() and old.cave_here() == "ruin", "a journey from before the cave finds it untouched")
	var gone: Dictionary = JSON.parse_string(JSON.stringify(game.snapshot()))
	gone.world.caves["moon_cave"] = {"explored": [], "taken": [], "fortune": {}}
	gone.world.caves.ruin.explored.append("moon_room")
	var kept := Session.new()
	check(kept.restore(gone) and not kept.world.caves.has("moon_cave") and not "moon_room" in kept.world.caves.ruin.explored, "caves and rooms no longer known are dropped")

## 沉霞古境: opens in spring of 150 and every sixty years for one year, in the valley; its stairs ask
## 金丹 and 神识 40; its guardians fall; it closes; the next opening starts afresh.
func _chenxia() -> void:
	var game := _game(0)
	game.player.realm = 1
	game.refresh_realm_stats()
	game.player.location = "wild"
	check(game.cave_here().is_empty(), "before 150 the valley holds no old realm")
	var calendar = game.Calendar
	game.world.day = calendar.to_day(150, 2, 30)
	game.wait(1)
	check(game.has_flag("chenxia_open") and game.cave_here() == "chenxia" and game.journal_lines().any(func(line: String) -> bool: return line.contains("沉霞古境开了")), "in the spring of 150 the 沉霞古境 opens in the valley")
	check(game.enter_room("chenxia", "stairs").contains("金丹"), "its stairs ask 金丹")
	check(game.Caves.fortunes_in(game, "chenxia").is_empty() and game.Caves.fortunes_in(game, "ruin").size() == 2, "the old cave's fortunes stay in the old cave")
	game.player.realm = 2
	game.player.stage = 1
	game.refresh_realm_stats()
	game.player.hp = game.player.max_hp
	# A 金丹 at the gate may ask a friend along (batch 5); this one goes alone.
	game.wait(1)
	if str(game.pending_event.get("id", "")) == "chenxia_party":
		game.choose_event("alone")
	game.enter_room("chenxia", "stairs")
	check(game.Caves.explored(game, "chenxia", "stairs") and game.journal_lines().any(func(line: String) -> bool: return line.contains("识破")), "a 金丹 sees through the stairs' array")
	game.enter_room("chenxia", "tomb")
	check(game.battle.get("enemy_id", "") == "jian_kui", "a sword puppet guards the tomb")
	game.battle.hp = 1
	game.battle.orbs = ["metal"]
	_sword(game)
	check(game.has_flag("chenxia_puppet_down") and game.Caves.reachable(game, "chenxia", "library"), "fallen, the way to the library opens")
	game.world.day = calendar.to_day(151, 2, 30)
	# A storyline's 传音 (南行) may end a stay on its first day; stay on until the day has passed.
	for stay: int in 3:
		if int(game.world.day) <= calendar.to_day(151, 2, 30):
			game.wait(1)
	check(not game.has_flag("chenxia_open") and game.cave_here().is_empty(), "a year later it closes")
	game.world.day = calendar.to_day(210, 2, 30)
	for stay: int in 3:
		if int(game.world.day) <= calendar.to_day(210, 2, 30):
			game.wait(1)
	check(game.has_flag("chenxia_open") and not game.has_flag("chenxia_puppet_down") and not game.world.caves.has("chenxia"), "sixty years on it opens afresh, its guardians standing again")

func _scroll() -> void:
	root.size = Vector2i(1920, 1080)
	main = load("res://scenes/main.tscn").instantiate()
	var path := "res://.godot/cave_test_%d" % Time.get_ticks_usec()
	main.manual_store = Store.new(path + "/manual")
	main.auto_store = Store.new(path + "/auto")
	main.settings_path = path + "/settings.cfg"
	main.guide_path = path + "/guide.cfg"
	root.add_child(main)
	main.guide_enabled = false
	main.session.encounters_enabled = false
	main.name_input.text = "青禾"
	main.intro_finished_once = true
	main.close_welcome()
	main._show_welcome()
	for button: Button in main.welcome_layer.find_children("*", "Button", true, false):
		if button.text == "总览":
			button.pressed.emit()
			break
	main.skip_intro.button_pressed = true
	main.begin()
	main.close_story()
	_at_cave(main.session)
	main.set_view("place")
	main.select_spot("depths")
	await process_frame
	check(_button("探入幽暗甬道") != null and not _button("探入幽暗甬道").disabled, "the depths' scroll offers the corridor")
	_button("探入幽暗甬道").pressed.emit()
	await process_frame
	check(main.session.Caves.explored(main.session, "ruin", "corridor") and _button("丹房 ？") != null and _button("书室 ？") != null, "entered, the rooms beyond show on the map")
	_button("丹房 ？").pressed.emit()
	await process_frame
	check(_button("探入丹房") != null, "choosing a doorway offers to enter it")
	# 沉霞古境 with a friend along (batch 5): the scroll says who and what they bring.
	var game = main.session
	game.world.flags["chenxia_open"] = true
	game.player.realm = 2
	game.refresh_realm_stats()
	game.player.location = "wild"
	game.world["party"] = {"chenxia": "wounded"}
	main.set_view("place")
	main.select_spot("chenxia")
	await process_frame
	var labels := "
".join(main.center.find_children("*", "Label", true, false).map(func(label: Label) -> String: return label.text))
	check(labels.contains("同行 · 柳寒舟"), "the 古境's scroll names the friend along")
	main.queue_free()
	await process_frame

func _button(text_part: String) -> Button:
	for button: Button in main.center.find_children("*", "Button", true, false):
		if button.text.contains(text_part):
			return button
	return null

## Casts 御剑诀 with the orbs it asks (金×1、任意×1): a journey begins with it only on a metal root.
func _sword(game) -> String:
	if not "sword" in game.player.learned:
		game.player.learned.append("sword")
	if not "sword" in game.player.arts:
		game.player.arts.append("sword")
	game.battle.orbs.append_array(["metal", "metal"])
	return game.use_skill("sword")
