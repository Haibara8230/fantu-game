extends SceneTree
## Screenshots of the main screens for layout review, run from a copy of the project whose override.cfg
## puts the window off-screen without focus and keeps a user dir of its own (tools/capture.ps1), so
## the player's settings and saves are never touched. Usage after `--`: <output dir> <width>x<height>.
const SaveStore = preload("res://scripts/core/save_store.gd")
const Calendar = preload("res://scripts/core/calendar.gd")
var main
var out_dir := ""
var shots := 0
var only: PackedStringArray = []

func _initialize() -> void:
	# Only from capture.ps1's copy: anywhere else this would write into the player's own user dir.
	if not OS.get_user_data_dir().ends_with("fantu_capture"):
		printerr("CAPTURE refused: not running with the capture's own user dir (%s); use tools/capture.ps1" % OS.get_user_data_dir())
		quit(1)
		return
	create_timer(120.0).timeout.connect(func() -> void: printerr("CAPTURE timed out"); quit(1))
	call_deferred("_run")

func _shot(name: String) -> void:
	main.render()
	if not only.is_empty() and not name in only:
		return
	for frame: int in 4:
		await process_frame
	await RenderingServer.frame_post_draw
	var image := root.get_texture().get_image()
	image.save_png(out_dir.path_join(name + ".png"))
	shots += 1

func _run() -> void:
	var args := OS.get_cmdline_user_args()
	if args.size() > 2 and not args[2].is_empty():
		only = args[2].split(",")
	out_dir = args[0] if args.size() > 0 else OS.get_user_data_dir().path_join("captures")
	var size := Vector2i(1920, 1080)
	if args.size() > 1 and args[1].contains("x"):
		size = Vector2i(int(args[1].get_slice("x", 0)), int(args[1].get_slice("x", 1)))
	DirAccess.make_dir_recursive_absolute(out_dir)
	var window := root.get_window()
	window.mode = Window.MODE_WINDOWED
	window.size = size
	window.position = Vector2i(-size.x - 4000, -size.y - 4000)
	main = load("res://scenes/main.tscn").instantiate()
	# Saves, teaching cards and settings stay in the copy (inside the project's .tmp), off the system drive.
	var local := "res://.capture_data"
	main.manual_store = SaveStore.new(local + "/manual")
	main.auto_store = SaveStore.new(local + "/auto")
	main.trial_store = SaveStore.new(local + "/trial")
	main.guide_path = local + "/guide.cfg"
	main.settings_path = local + "/settings.cfg"
	root.add_child(main)
	main.audio.settings_path = local + "/settings.cfg"
	window.size = size
	window.position = Vector2i(-size.x - 4000, -size.y - 4000)
	main.session.encounters_enabled = false
	# Cards switched off by an earlier run would stay off in the capture's own user dir.
	main.set_guide_enabled(true)
	await _shot("01_welcome")
	main.name_input.text = "青禾"
	main.welcome_roots = ["metal", "wood", "fire"]
	main.welcome_born = {"talents": ["danqi", "touyao"], "flaws": []}
	main.intro_finished_once = true
	main.close_welcome()
	main._show_welcome()
	main.name_input.text = "青禾"
	main.welcome_roots = ["metal", "wood", "fire"]
	main.welcome_born = {"talents": ["danqi", "touyao"], "flaws": []}
	main.begin()
	# The 入世 opening: the inn at 青石镇, then the gate of 云溪 and the city with its inn.
	await _shot("02a_rushi_inn")
	main.choose("help")
	main.set_guide_enabled(false)
	await _shot("02b_town")
	main.select_spot("inn")
	await _shot("02c_town_inn")
	main.close_spot()
	main.run(func() -> String: return main.session.travel("market"))
	await _shot("02d_yunxi_gate")
	main.choose("pass")
	main.story = {}
	main.GainsCard.close(main)
	await _shot("02e_market")
	# The lodge by the stream, let by the year, beside the inn.
	main.session.world.flags["yunxi_abode"] = true
	main.render()
	await _shot("02g_market_abode")
	main.session.world.flags.erase("yunxi_abode")
	main.render()
	while not main.session.pending_event.is_empty():
		main.choose(str(main.session.pending_definition().choices[0].id))
	main.story = {}
	main.set_guide_enabled(true)
	# The rest is a disciple of 青云: to the sect, where a wanderer sees only the recruiting terrace.
	main.run(func() -> String: return main.session.travel("sect"))
	while not main.session.pending_event.is_empty():
		main.choose(str(main.session.pending_definition().choices[0].id))
	main.story = {}
	main.GainsCard.close(main)
	main.set_guide_enabled(false)
	await _shot("02f_sect_wanderer")
	main.set_guide_enabled(true)
	main.run(main.session.join_sect)
	await _shot("02_story")
	main.close_story()
	await _shot("03_sect_with_card")
	main.set_guide_enabled(false)
	await _shot("04_sect")
	main.select_spot("chamber")
	await _shot("04b_sect_chamber")
	main.select_spot("hall")
	await _shot("05_sect_hall")
	# A handwritten person's card, then a generated one's.
	main.open_person("xu_qinghe")
	await _shot("05b_person")
	var fellows: Array = main.session.present_npcs().filter(func(id: String) -> bool: return main.session.is_generated(id))
	if not fellows.is_empty():
		main.open_person(str(fellows[0]))
		await _shot("05c_person_generated")
	main.close_spot()
	main.notice("闭关 3 个月，修为增加 360，灵力恢复。云溪斗法台贴出告示：潜龙会于三月一日至十五日报名，限四十岁以下的炼气修士，三轮斗法，点到为止；魁首得筑基丹一枚与功法玉简。沈墨传音：药铺新到了一批凝露草，道友若要炼回气丹，可来取用。")
	await _shot("06_long_notice")
	main.set_view("status")
	await _shot("07_status")
	var s = main.session
	s.set_item_count("huichun_grass", 6)
	s.set_item_count("chiyan_flower", 2)
	s.set_item_count("foundation_pill_fine", 1)
	s.set_item_count("qiannian_shiru", 1)
	s.set_item_count("furnace_bronze", 1)
	s.set_item_count("recipe_huiqi", 1)
	s.add_item("j:" + s.Arsenal.generate_technique(s.content, s.world_rng, 3), 1)
	s.add_item(s.Arsenal.generate_equipment(s.content, s.world_rng, 2), 1)
	main.set_view("bag")
	await _shot("08_bag")
	main.set_view("arts")
	await _shot("09_arts")
	main.set_view("goals")
	await _shot("10_goals")
	main.set_view("messages")
	await _shot("11_messages")
	# An appointment ahead to mark on the retreat scroll: the autumn auction at 云溪.
	s.set_wake("yunxi_autumn", true)
	main.set_view("retreat")
	await _shot("12_retreat")
	s.add_item("j:t:breath:wood:1::0", 1)
	s.take_slip("t:body:earth:1::5")
	main.set_view("insight")
	await _shot("12b_insight")
	main.set_view("breakthrough")
	await _shot("13_breakthrough")
	# The 获得 card over the place, as after a commission or a duel.
	main.set_view("place")
	main.run(func() -> String:
		s.add_item("huichun_grass", 3)
		s.add_item("foundation_pill", 1)
		s.add_item("j:t:bolt:fire:2::0", 1)
		s.player.stones = int(s.player.stones) + 60
		return "")
	await _shot("13b_gains")
	main.GainsCard.close(main)
	s.Events.apply(s, [{"recipe": "liaoshang"}, {"recipe": "huiqi"}])
	main.set_view("place")
	main.select_spot("chamber")
	main.open_alchemy()
	await _shot("14_alchemy")
	main.set_view("map")
	await _shot("15_map")
	# 天南 known: the map's two pages, the gate drawn as an exit from the 云溪 market.
	main.session.world.flags["tiannan_known"] = true
	main.session.player.realm = 1
	main.session.refresh_realm_stats()
	main.select_map_target("nanming")
	await _shot("15d_map_gate")
	main.set_map_region("tiannan")
	await _shot("15e_map_tiannan")
	main.session.world.flags.erase("tiannan_known")
	main.session.player.realm = 0
	main.session.refresh_realm_stats()
	main.map_target = ""
	main.map_region = ""
	# The sect page of an inner disciple holding a duty.
	main.session.player.rank = main.session.Sect.rank_index(main.session, "inner")
	main.session.player.duty = "alchemy"
	main.session.player.duty_day = int(main.session.world.day)
	main.set_view("sect")
	await _shot("15c_sect_duty")
	main.session.player.rank = 0
	main.session.player.duty = ""
	main.set_view("map")
	# Mid-flight over the map (御剑): the figure on its blade between two places.
	main.world_map.traveller = main.world_map.node_position("sect").lerp(main.world_map.node_position("town"), 0.5)
	main.world_map.flying = true
	main.world_map.stride = 3.0
	main.world_map.queue_redraw()
	for frame: int in 3:
		await process_frame
	await RenderingServer.frame_post_draw
	root.get_texture().get_image().save_png(out_dir.path_join("15b_map_flight.png"))
	shots += 1
	main.world_map.traveller = null
	main.world_map.flying = false
	s.player.location = "market"
	main.set_view("place")
	await _shot("16_market")
	main.open_trade()
	await _shot("17_trade")
	main.set_view("place")
	s.player.location = "sect"
	main.set_view("place")
	s.start_battle("disciple")
	await _shot("18_battle")
	# The duel's teaching card as a bubble beside 结束回合.
	main.set_guide_enabled(true)
	await _shot("18a_battle_card")
	main.set_guide_enabled(false)
	while not s.battle.is_empty():
		s.flee()
	# A spar with a generated disciple: their arts in the intent, pills, a shield and a burn.
	var rivals: Array = s.present_npcs().filter(func(id: String) -> bool: return s.is_generated(id))
	if not rivals.is_empty():
		s.add_item("huiqi_pill", 2)
		s.add_item("liaoshang_pill", 1)
		s.begin_spar(str(rivals[0]))
		s.battle.shield = 18
		s.battle.status.burn = [4, 2]
		main.set_view("place")
		await _shot("18b_spar")
		s.flee()
	# A pack on 赤枫岭 (群敌): targets, a sword to release, a talisman, the ground's favour and 探查.
	s.player.location = "chifeng"
	var blade: String = s.Arsenal.equipment_id("sword", 2, "fire", [], 0)
	s.add_item(blade, 1)
	s.player.equipment.weapon = blade
	s.add_item("lei_fu", 2)
	s.begin_battle("huo_ya", "event")
	s.Combat.add_pack(s, ["huo_ya", "wolf"])
	main.toggle_battle_scout()
	main.set_view("place")
	await _shot("18i_pack")
	main.toggle_battle_scout()
	while not s.battle.is_empty():
		s.player.hp = s.player.max_hp
		s.flee()
	s.player.equipment.weapon = ""
	s.player.location = "sect"
	main.set_view("place")
	# 天劫 with the 禁忌秘术 open (batch nine), then a 死斗's fall.
	var realm_was := int(s.player.realm)
	s.player.realm = 1
	s.refresh_realm_stats()
	s.player.hp = s.player.max_hp
	s.player["tribulation"] = {"grade": 1, "days": 0, "xp": 0}
	s.Combat.begin_tribulation(s, "tribulation_core")
	main.toggle_battle_secret()
	main.set_view("place")
	await _shot("18j_tribulation")
	main.toggle_battle_secret()
	# A 天雷 coming down (storm.gd), caught as it strikes.
	main.set_view("place")
	await process_frame
	if main.battle_stage != null and main.battle_stage.storm != null:
		main.battle_stage.storm.strike(main.battle_stage.hero.chest() + main.battle_stage.world.position)
		# Held still: an off-screen window draws too seldom to catch a bolt in passing.
		main.battle_stage.storm.set_process(false)
		main.battle_stage.storm.queue_redraw()
		# Not _shot: it renders the screen anew, and the stage with its bolt with it.
		for frame: int in 3:
			await process_frame
		await RenderingServer.frame_post_draw
		root.get_texture().get_image().save_png(out_dir.path_join("18k_tribulation_bolt.png"))
		shots += 1
	s.battle.clear()
	s.player.erase("tribulation")
	s.player.realm = realm_was
	s.refresh_realm_stats()
	s.player.hp = s.player.max_hp
	main.set_view("place")
	# The old cave's depths, a room in.
	s.world.flags["found_ruin"] = true
	s.world.flags["ruin_cleared"] = true
	s.player.location = "ruin"
	s.player.stage = 3
	s.refresh_realm_stats()
	s.enter_room("ruin", "corridor")
	s.enter_room("ruin", "elixir")
	main.set_view("place")
	main.select_spot("depths")
	await _shot("18c_cave")
	main.close_spot()
	# An auction under way.
	s.player.location = "market"
	s.player.stones = 300
	s.Auctions.open(s, "yunxi_special")
	await _shot("18d_auction")
	s.auction = {}
	# The forge, with materials of two kinds.
	s.set_item_count("ore_qinggang", 3)
	s.set_item_count("jade_mo", 4)
	main.open_forge()
	await _shot("18e_forge")
	# 天南: the forge with 地火精 to throw in, 南明坊市 without its art yet, and the broker's window.
	s.world.flags["tiannan_known"] = true
	s.set_item_count("dihuo_jing", 2)
	main.forge_plan["flux"] = true
	main.open_forge()
	await _shot("18f_forge_flux")
	s.player.location = "nanming"
	main.set_view("place")
	await _shot("18g_nanming")
	main.select_spot("broker")
	await _shot("18h_nanming_broker")
	main.close_spot()
	s.world.flags.erase("tiannan_known")
	main.set_view("place")
	s.player.location = "sect"
	main.set_view("place")
	s.pending_event = {"id": "qianlong_entry", "day": int(s.world.day)}
	await _shot("19_event")
	s.pending_event = {}
	main.set_view("place")
	# Frames from the middle of the staged moments.
	for moment: Array in [["20_rite_retreat", "retreat", "", 1.6, 3.6], ["20b_rite_insight", "insight", "", 1.4, 3.0], ["21_rite_gather", "breakthrough", "success", 1.2, 3.4], ["22_rite_success", "breakthrough", "success", 2.7, 3.4], ["23_rite_failure", "breakthrough", "failure", 2.6, 3.4], ["24_rite_brew", "brew", "fine", 1.8, 2.2]]:
		var rite = main.Rite.new()
		rite.scene = main.backdrop.texture
		rite.colors.assign([Color("#e8e2c4"), Color("#a4e9a6"), Color("#ffb579")])
		main.add_child(rite)
		rite.kind = moment[1]
		rite.outcome = moment[2]
		rite.title = {"retreat": "闭 关 中", "insight": "领 悟", "breakthrough": "筑基"}.get(moment[1], "回气丹")
		rite.subtitle = "长春功" if moment[1] == "insight" else "根基 · 上品"
		rite.tint = Color("#d5b777") if moment[2] != "" else Color("#8fd0c4")
		rite.days = [0, 90]
		rite.xp = [0, 180, 500]
		rite.elapsed = moment[3]
		rite.length = moment[4]
		await _shot(moment[0])
		rite.queue_free()
	# High realms: the breakthrough scroll toward 元婴, then the ascension's ending.
	s.player.realm = 2
	s.player.stage = 3
	s.player.xp = 80000
	s.player.mind = 300
	s.player.core_grade = 5
	s.refresh_realm_stats()
	s.set_item_count("yanghun_mu", 1)
	main.set_view("breakthrough")
	await _shot("25_breakthrough_nascent")
	s.player.realm = 4
	s.player.stage = 3
	s.refresh_realm_stats()
	s.ended = {"kind": "ascension", "day": int(s.world.day)}
	s.log_event("ascended", {"age": s.age()}, true)
	main.render()
	await _shot("26_ascension")
	print("CAPTURE: %d shots at %dx%d in %s" % [shots, size.x, size.y, out_dir])
	main.queue_free()
	await create_timer(0.2).timeout
	quit(0)
