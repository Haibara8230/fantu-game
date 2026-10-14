extends SceneTree
## Screenshots of the main screens for layout review, run from a copy of the project whose override.cfg
## puts the window off-screen without focus and keeps a user dir of its own (tools/capture.ps1), so
## the player's settings and saves are never touched. Usage after `--`: <output dir> <width>x<height>.
const SaveStore = preload("res://scripts/core/save_store.gd")
const Calendar = preload("res://scripts/core/calendar.gd")
var main
var out_dir := ""
var shots := 0

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
	for frame: int in 4:
		await process_frame
	await RenderingServer.frame_post_draw
	var image := root.get_texture().get_image()
	image.save_png(out_dir.path_join(name + ".png"))
	shots += 1

func _run() -> void:
	var args := OS.get_cmdline_user_args()
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
	root.add_child(main)
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
	main.skip_intro.button_pressed = true
	main.begin()
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
	main.notice("闭关 3 个月，修为增加 360，灵力恢复。青云山执事堂贴出告示：外门小比将于六月一日至十五日在演武坪报名，三轮斗法，点到为止，头名可得宗门赏赐的功法玉简。沈墨传音：药铺新到了一批凝露草，道友若要炼回气丹，可来取用。")
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
	main.set_view("retreat")
	await _shot("12_retreat")
	main.set_view("breakthrough")
	await _shot("13_breakthrough")
	s.Events.apply(s, [{"recipe": "liaoshang"}, {"recipe": "huiqi"}])
	main.set_view("place")
	main.select_spot("chamber")
	main.open_alchemy()
	await _shot("14_alchemy")
	main.set_view("map")
	await _shot("15_map")
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
	main.set_view("place")
	s.player.location = "sect"
	main.set_view("place")
	s.pending_event = {"id": "tournament_entry", "day": int(s.world.day)}
	await _shot("19_event")
	s.pending_event = {}
	main.set_view("place")
	# Frames from the middle of the staged moments.
	for moment: Array in [["20_rite_retreat", "retreat", "", 1.2, 2.4], ["21_rite_gather", "breakthrough", "success", 1.2, 3.4], ["22_rite_success", "breakthrough", "success", 2.7, 3.4], ["23_rite_failure", "breakthrough", "failure", 2.6, 3.4], ["24_rite_brew", "brew", "fine", 1.8, 2.2]]:
		var rite = main.Rite.new()
		main.add_child(rite)
		rite.kind = moment[1]
		rite.outcome = moment[2]
		rite.title = "闭 关" if moment[1] == "retreat" else ("筑基" if moment[1] == "breakthrough" else "回气丹")
		rite.subtitle = "根基 · 上品"
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
	s.player.xp = 16000
	s.player.mind = 300
	s.player.core_grade = 5
	s.refresh_realm_stats()
	s.set_item_count("huaying_dan", 1)
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
