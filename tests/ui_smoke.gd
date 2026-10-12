extends SceneTree
const SaveStore = preload("res://scripts/core/save_store.gd")
var main
var captures := 0
var checks := 0
var failures := 0

func _initialize() -> void:
	create_timer(20.0).timeout.connect(func() -> void: printerr("UI test timed out" ); quit(1))
	call_deferred("_run")

# Counted checks instead of assert(): a failed assert halts a headless run instead of failing it.
func check(condition: bool, message: String) -> void:
	checks += 1
	if not condition:
		failures += 1
		printerr("FAIL: " + message)

func _capture(filename: String) -> void:
	await process_frame
	await process_frame
	if not DisplayServer.get_name() == "headless":
		await RenderingServer.frame_post_draw
		var image := root.get_texture().get_image()
		image.save_png("res://builds/previews/" + filename + ".png")
		captures += 1

func _texts(node: Node, type: String) -> String:
	return "\n".join(node.find_children("*", type, true, false).map(func(control: Control) -> String: return control.text))

func _button(text_part: String) -> Button:
	for button: Button in main.center.find_children("*", "Button", true, false):
		if button.text.contains(text_part):
			return button
	return null

func _has_art(file_name: String) -> bool:
	return main.center.find_children("*", "TextureRect", true, false).any(func(image: TextureRect) -> bool: return image.texture != null and image.texture.resource_path.ends_with(file_name + ".png"))

func _run() -> void:
	root.size = Vector2i(1280, 800)
	DirAccess.make_dir_recursive_absolute(ProjectSettings.globalize_path("res://builds/previews"))
	main = load("res://scenes/main.tscn").instantiate()
	var test_path := "res://.godot/ui_saves_%d" % Time.get_ticks_usec()
	main.manual_store = SaveStore.new(test_path + "/manual")
	main.auto_store = SaveStore.new(test_path + "/auto")
	root.add_child(main)
	main.session.encounters_enabled = false
	main.audio.settings_path = test_path + "/settings.cfg"
	main.guide_path = test_path + "/guide.cfg"
	main.Guide.load_state(main)
	await _capture("welcome")
	main.name_input.text = "青禾"
	# Sensed roots are random; an ordinary three-element root keeps the cultivation numbers below fixed.
	main.welcome_roots = ["metal", "wood", "fire"]
	main.begin()
	await _capture("sect")
	# The new-player guide: one tip at a time where it applies; dismissed tips stay dismissed.
	var tips: Array = main.Guide.tips()
	check(not tips.is_empty() and tips.all(func(tip: Dictionary) -> bool: return main.Guide.known(tip.id) and tip.title is String and tip.text is String and not tip.where.is_empty()), "every tip in the data has a known situation, a title and a text")
	check(_texts(main.center, "Label").contains("指引 · 闭关修炼") and _button("知道了") != null, "a new player first sees the retreat tip")
	_button("知道了").pressed.emit()
	check(main.guide_seen.has("retreat") and _texts(main.center, "Label").contains("指引 · 此地人物"), "dismissing it brings the next tip that applies here")
	var dismissed := 0
	while _button("知道了") != null and dismissed < 10:
		dismissed += 1
		_button("知道了").pressed.emit()
	check(not _texts(main.center, "Label").contains("指引 ·") and not main.guide_seen.has("map") and not main.guide_seen.has("battle"), "tips for situations not met yet wait their turn")
	main.guide_seen = {}
	main.Guide.load_state(main)
	check(main.guide_seen.has("retreat") and main.guide_seen.has("people"), "dismissed tips are remembered in the guide file")
	main.set_guide_enabled(false)
	main.guide_seen.erase("retreat")
	main.render()
	check(not _texts(main.center, "Label").contains("指引 ·"), "the guide can be switched off")
	main.reset_guide()
	check(main.guide_enabled and main.guide_seen.is_empty() and _texts(main.center, "Label").contains("指引 · 闭关修炼"), "and every tip can be shown again")
	main.set_guide_enabled(false)
	check(_button("静室") != null and _button("演武坪") != null and _button("传功堂") != null, "sect scenes offered as tabs")
	_button("传功堂").pressed.emit()
	check(_texts(main.center, "Label").contains("研习传承") and _button("闭关  ·  1 个月") == null, "scene switch shows only that scene's actions")
	check(_button("参悟吐纳法") != null or _button("参悟") != null, "the hall offers techniques to study")
	_button("执事堂").pressed.emit()
	check(_button("接下：") != null, "the 执事堂 board lists commissions")
	var disciple: String = main.session.present_npcs().filter(func(person_id: String) -> bool: return person_id.begins_with("g:"))[0]
	main.open_person(disciple)
	check(_texts(main.center, "Label").contains("神通 ·") and _button("切磋") != null, "a generated disciple shows a loadout and can spar")
	main.close_person()
	main.set_view("arts")
	await _capture("arts")
	var arts_text := _texts(main.center, "Label")
	check(arts_text.contains("主动神通  3 / 4") and arts_text.contains("心法  0 / 2") and arts_text.contains("御剑诀"), "the 功法 view shows slots and arts")
	main.set_view("place")
	_button("静室").pressed.emit()
	check(main.status_label.get_global_rect().end.y <= main.get_global_rect().end.y + 1, "status line inside the window")
	check(main.clock_label.text == "历元 1 年 1 月初一", "calendar shown")
	check(main.journal_text.text.begins_with("【1年1月初一】你拜入青云山"), "chronicle shown")
	var sidebar := _texts(main.stats, "Label")
	check(sidebar.contains("年岁 16") and sidebar.contains("寿元 120") and sidebar.contains("寿元尽于历元 105 年"), "age and lifespan shown")
	check(_button("闭关  ·  1 个月") != null and _button("闭关  ·  1 年") != null and _button("停留  ·  1 日") != null, "retreat lengths and waiting offered")
	check(sidebar.contains("心境 · 平和 · 闭关收益 100%") and sidebar.contains("历练  0 / 100") and not _button("闭关  ·  1 年").disabled, "a fresh mind and no insight yet")
	check(_button("闭关  ·  1 年").tooltip_text.contains("触及瓶颈"), "a year's retreat warns that it will stop at the bottleneck")
	main.session.player.xp = 500
	main.render()
	check(_texts(main.stats, "Label").contains("瓶颈") and _button("闭关  ·  1 个月").disabled and _button("闭关  ·  1 个月").tooltip_text.contains("破障丹"), "a bottleneck shows in the sidebar and closes the retreat")
	main.session.player.xp = 0
	main.render()
	main._save_manual()
	main.run(func() -> String: return main.session.travel("wild"))
	await _capture("wild")
	check(main.clock_label.text == "历元 1 年 1 月初八", "travel advances the calendar by route days")
	check(main.audio.music_key == "wild" and main.audio.ambience_key == "wild", "music and ambience follow the location")
	main.set_guide_enabled(true)
	main.run(func() -> String: return main.session.start_battle("wolf"))
	check(_texts(main.center, "Label").contains("指引 · 斗法"), "the first duel explains the controls")
	main.set_guide_enabled(false)
	await main.skill("fire")
	await _capture("battle")
	root.size = Vector2i(1000, 640)
	await _capture("battle_small")
	check(main.status_label.get_global_rect().end.y <= main.get_global_rect().end.y + 1, "status line inside the small window")
	root.size = Vector2i(1280, 800)
	main._show_welcome()
	main.continue_saved()
	check(main.started and main.session.battle.get("enemy_id", "") == "wolf", "continue restores the battle")
	main._load_manual()
	check(main.session.player.location == "sect" and main.session.battle.is_empty(), "manual load restores the sect")
	# People where the player stops: listed and opened on demand, never forced.
	main.run(func() -> String: return main.session.travel("market"))
	check(main.session.pending_event.is_empty() and _button("沈墨 · 云溪药铺掌柜") != null, "people here listed without forcing anything")
	check(_texts(main.stats, "Button").contains("沈墨 · 云溪坊市"), "acquaintance listed with whereabouts")
	var local_root := test_path + "/local_portraits"
	DirAccess.make_dir_recursive_absolute(ProjectSettings.globalize_path(local_root))
	var face := Image.create(16, 20, false, Image.FORMAT_RGB8)
	face.save_png(local_root.path_join("shen_mo.png"))
	main.portrait_root = local_root
	main.session.set_item_count("huichun_grass", 5)
	_button("沈墨 · 云溪药铺掌柜").pressed.emit()
	var portraits: Array = main.center.find_children("*", "TextureRect", true, false)
	check(not portraits.is_empty() and portraits[0].texture.get_width() == 16, "a local image replaces the portrait")
	await _capture("person")
	var card := _texts(main.center, "Label")
	check(card.contains("精明和气") and card.contains("炼气后期") and card.contains("好感 · 初识"), "profile shows who they are and how they feel")
	check(_button("代他收五株回春草") != null and _button("交谈") != null and _button("赠一株灵草") != null, "interactions offered")
	_button("代他收五株回春草").pressed.emit()
	await process_frame
	check(main.session.favor("shen_mo") == 10 and _button("代他收五株回春草").disabled, "interaction applied; the repeat waits for its cooldown")
	check(_texts(main.center, "Label").contains("你交给沈墨五株回春草"), "what just happened shows in a dialogue box on the card")
	_button("交谈").pressed.emit()
	await process_frame
	var said := _texts(main.center, "Label")
	var first_line: String = main.session.content.people.shen_mo.talk[0]
	check(said.contains(first_line) and not said.contains("沈墨：" + first_line), "a talk line is shown under the speaker's name, once")
	_button("返回").pressed.emit()
	check(main.selected_npc.is_empty() and _button("闭关") == null, "back to the market scenes")
	# The street shop and the 行囊.
	main.select_spot("street")
	check(_button("购买筑基丹  ·  120 灵石") != null and _button("购买回气丹") != null, "the street shop lists its goods")
	main.session.player.stones = 40
	_button("购买疗伤丹").pressed.emit()
	main.set_view("bag")
	await _capture("bag")
	check(_texts(main.center, "Label").contains("疗伤丹 ×1") and _button("服用") != null, "the 行囊 lists items with a use button")
	main.set_view("place")
	# The region map: hidden places stay hidden; picking a node previews the route; departing travels it.
	main.set_view("map")
	await _capture("map")
	check(main.world_map != null and not "ruin" in main.world_map.visible_ids(), "map drawn without undiscovered places")
	check("沈墨" in main.world_map.people_at.get("market", []), "known people marked on the map")
	main.world_map.location_selected.emit("ridge")
	var route_text := _texts(main.center, "Label")
	check(route_text.contains("云溪坊市 → 白鹭渡 → 青石镇 → 松风岭") and route_text.contains("共 8 日"), "shortest route previewed with days")
	_button("启程前往松风岭").pressed.emit()
	await process_frame
	check(main.session.player.location == "ridge" and main.view == "place", "departing from the map walks the route")
	check(main.audio.last_cue == "arrive" and main.audio.music_key == "ridge", "arrival cue and local music")
	# Story moments: a person met in a scene of their own, a choice event and a moment without a choice.
	var art: Dictionary = JSON.parse_string(FileAccess.get_file_as_string("res://data/art.json"))
	check(art.event_art.keys().all(func(id: String) -> bool: return main.session.content.events.has(id)) and art.person_art.keys().all(func(id: String) -> bool: return main.session.content.people.has(id)), "story art points at real events and people")
	check((art.event_art.values() + art.person_art.values()).all(func(path: String) -> bool: return ResourceLoader.exists(path)), "and every story illustration exists")
	main.run(func() -> String: return main.session.travel("town"))
	check(main.center.modulate.a < 1.0, "a new place fades in")
	await create_timer(0.4).timeout
	check(is_equal_approx(main.center.modulate.a, 1.0), "and settles fully visible")
	if "storyteller" in main.session.present_npcs():
		main.open_person("storyteller")
		check(_has_art("teahouse_story"), "the storyteller is met on his stage")
		main.close_person()
	main.session.pending_event = {"id": "night_market", "day": int(main.session.world.day)}
	main.render()
	check(_has_art("yunxi_night_market") and _button("随意逛逛") != null, "an event opens on its illustration above the choices")
	main.session.pending_event = {}
	main.render()
	var rampage_day: int = main.Calendar.to_day(6, 3, 1)
	main.run(func() -> String:
		main.session.advance_days(rampage_day - int(main.session.world.day))
		return "")
	check(main.story.get("event", "") == "serpent_rampage" and _has_art("serpent_rampage") and _texts(main.center, "Label").contains("妖蟒之乱"), "the serpent breaking out is staged with its illustration")
	_button("继续").pressed.emit()
	check(main.story.is_empty() and _texts(main.center, "Label").contains("青石镇"), "继续 returns to the place")
	# Audio settings persist outside the save files.
	main._open_settings()
	var music_slider: HSlider = main.settings_dialog.find_child("Music", true, false)
	music_slider.value = 0.3
	main.settings_dialog.hide()
	check(is_equal_approx(float(main.audio.volumes.Music), 0.3) and FileAccess.file_exists(test_path + "/settings.cfg"), "volume change applied and saved")
	# The end of a life.
	main.run(func() -> String: return main.session.travel("sect"))
	main.session.player.birth_day = int(main.session.world.day) + 30 - 120 * 360
	main.run(func() -> String: return main.session.cultivate(360))
	main.run(func() -> String: return main.session.cultivate(360))
	await _capture("ending")
	check(not main.session.ended.is_empty() and _texts(main.center, "Label").contains("此 生 已 尽"), "ending screen shown")
	main._load_manual()
	check(main.session.ended.is_empty(), "loading a save returns from the ending")
	main._ask_new_game()
	await process_frame
	main.new_game_dialog.hide()
	print("UI: %d checks, %d failures; %d captures" % [checks, failures, captures])
	main.queue_free()
	# Give the audio server a moment to release stopped playbacks before quitting.
	await create_timer(0.2).timeout
	quit(0 if failures == 0 else 1)
