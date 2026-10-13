extends SceneTree
const SaveStore = preload("res://scripts/core/save_store.gd")
const Session = preload("res://scripts/core/session.gd")
const Goals = preload("res://scripts/ui/goals.gd")
const Calendar = preload("res://scripts/core/calendar.gd")
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

## When each current goal applies, on a session of its own (goals.gd reads the state, never changes it).
func _goals() -> void:
	check(Goals.goals().all(func(goal: Dictionary) -> bool: return Goals.known(goal.id) and goal.title is String and goal.text is String), "every goal in the data has a known situation, a title and a text")
	var game := Session.new()
	game.encounters_enabled = false
	game.new_game("目标", 7, ["metal", "wood", "fire"])
	var ids := func() -> Array: return Goals.current(game).map(func(goal: Dictionary) -> String: return goal.id)
	var filled := func() -> bool: return Goals.current(game).all(func(goal: Dictionary) -> bool: return not goal.text.contains("{"))
	check(ids.call() == ["serpent", "foundation_xp"] and filled.call(), "a new life aims at the serpent and at breaking through")
	game.player.xp = 500
	check(ids.call() == ["bottleneck", "serpent"], "a bottleneck comes first and hides the plain xp goal")
	game.player.xp = 2000
	game.player.stage = 3
	check("foundation_pill" in ids.call() and Goals.current(game)[ids.call().find("foundation_pill")].text.contains("120 灵石"), "enough xp: the pill is next, with its price")
	game.set_item_count("foundation_pill", 1)
	check("foundation_breach" in ids.call(), "with the pill: back to the chamber")
	# Breaking through starts the new realm's xp from nothing.
	game.player.realm = 1
	game.player.stage = 0
	game.player.xp = 0
	game.set_item_count("foundation_pill", 0)
	game.refresh_realm_stats()
	check(not ids.call().any(func(id: String) -> bool: return id.begins_with("foundation")) and "cultivate" in ids.call(), "after foundation the next sub-stage is the goal")
	game.world.flags.serpent_rampage = true
	check(not "serpent" in ids.call() and "sealed" in ids.call() and filled.call(), "once the valley is sealed, the goal says when it opens")
	game.world.flags.serpent_rampage = false
	game.world.flags.serpent_slain = true
	game.world.flags.azhi_promised = true
	check("azhi_token" in ids.call() and Goals.current(game)[ids.call().find("azhi_token")].text.contains("说书先生"), "a promise is a goal, with a hint where to start")
	game.set_item_count("azhi_token", 1)
	check(ids.call()[0] == "azhi_return", "carrying the token: take it back")
	game.set_item_count("azhi_token", 0)
	game.world.flags.azhi_mourned = true
	game.set_item_count("auction_invitation", 1)
	check("auction" in ids.call() and filled.call(), "an invitation points at the auction")
	game.world.day = Calendar.to_day(5, 5, 1)
	check(not "auction" in ids.call(), "and is forgotten once the auction has passed")
	game.world.day = Calendar.to_day(10, 1, 1)
	var soon: Array[Dictionary] = Goals.current(game)
	check("tournament" in ids.call() and soon[ids.call().find("tournament")].text.contains("历元 10 年 6 月初一至十五"), "the tournament is mentioned within a year of it")
	game.world.day = Calendar.to_day(10, 6, 16)
	check(not "tournament" in ids.call(), "and not again until the next one draws near")
	check(Goals.current(game).size() <= Goals.SHOWN, "at most a few goals at once")

## The guided start as a first-time player meets it: the mentor's words open it, the HUD's goal follows
## the step, the map holds the player to the step's place, the first retreat lasts the month asked for,
## and a 传音 later shows in the scroll and on the HUD.
func _guided() -> void:
	main.intro_finished_once = false
	main._show_welcome()
	check(main.skip_intro == null, "no skipping before the introduction was finished once")
	var sensed := _texts(main.welcome_layer, "Label")
	check(sensed.contains("灵根 · ") and sensed.contains("资质 · ") and sensed.contains("先天天赋") and _welcome_button("重新感应（余 5 次）") != null, "the welcome senses roots, talents and aptitude")
	for i: int in 5:
		_welcome_button("重新感应（余 %d 次）" % (5 - i)).pressed.emit()
	check(_welcome_button("重新感应（余 0 次）") != null and _welcome_button("重新感应（余 0 次）").disabled, "and may sense again only five times")
	main.name_input.text = "新人"
	main.welcome_roots = ["metal", "wood", "fire"]
	main.welcome_born = {"talents": [], "flaws": []}
	main.begin()
	check(main.current_screen() == "full" and main.story.title == "初入山门" and _texts(main.center, "Label").contains("许清和"), "a guided journey opens with the mentor's words")
	main.close_story()
	check(main.goal_label.text == "目标 · 初入山门" and main.goal_label.tooltip_text.contains("闭关修炼一个月"), "the HUD's goal is the step at hand")
	main.set_view("retreat")
	var length: HSlider = main.center.find_children("*", "HSlider", true, false)[0]
	check(int(length.max_value) == 3 and _texts(main.center, "Label").contains("此番至多 1 个月"), "the first retreat is the month the mentor asked for")
	main.set_view("map")
	main.select_map_target("ridge")
	check(_button("启程前往松风岭").disabled and _texts(main.center, "Label").contains("许清和嘱咐过"), "the map says why the road is closed for now")
	main.set_view("place")
	main.session.world.letters.append({"npc": "xu_qinghe", "day": int(main.session.world.day), "read": false, "story": "errands", "step": "dew"})
	main.render()
	check(main.hud_icons.goals.text == "任务 · 传音 1", "an unread 传音 shows on the HUD")
	main.set_view("letters")
	check(_texts(main.center, "Label").contains("新 · 许清和") and _texts(main.center, "Label").contains("凝露草") and main.session.unread_letters() == 0, "the inbox shows it as new and reads it")
	main.set_view("stories")
	check(_texts(main.center, "Label").contains("初入山门 · 许清和") and _texts(main.center, "Label").contains("闭关修炼一个月"), "剧情 lists the storyline with its step")
	main.close_overlay()

## Waits out a journey played on the map: whether the traveller's mark showed, and how many dates passed.
func _watch_walk() -> Dictionary:
	var marked := false
	var dates := {}
	while main.presenting:
		if main.world_map.traveller is Vector2:
			marked = true
		dates[main.clock_label.text] = true
		await process_frame
	await process_frame
	return {"marked": marked, "dates": dates.size()}

## A button in the window, or on the place's scene (the people drawer, the way out).
func _button(text_part: String) -> Button:
	for button: Button in main.center.find_children("*", "Button", true, false) + main.scene_layer.find_children("*", "Button", true, false):
		if button.text.contains(text_part):
			return button
	return null

func _welcome_button(text_part: String) -> Button:
	for button: Button in main.welcome_layer.find_children("*", "Button", true, false):
		if button.text.contains(text_part):
			return button
	return null

## A spot's paper tag on the place's scene (its text runs top to bottom; the tooltip names it).
func _tag(spot_name: String) -> Button:
	for button: Button in main.scene_layer.find_children("*", "Button", true, false):
		if button.tooltip_text == spot_name:
			return button
	return null

## Whether an illustration shows: filling the screen behind an event or story, or in the window.
func _has_art(file_name: String) -> bool:
	var images: Array = main.center.find_children("*", "TextureRect", true, false) + [main.backdrop]
	return images.any(func(image: TextureRect) -> bool: return image.visible and image.texture != null and image.texture.resource_path.ends_with(file_name + ".png"))

func _run() -> void:
	root.size = Vector2i(1920, 1080)
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
	main.settings_path = test_path + "/settings.cfg"
	main.Settings.load_state(main)
	main.refresh_key_labels()
	await _capture("welcome")
	main.name_input.text = "青禾"
	# Sensed roots and talents are random; an ordinary three-element root and no talents keep the
	# numbers below fixed.
	main.welcome_roots = ["metal", "wood", "fire"]
	main.welcome_born = {"talents": [], "flaws": []}
	check(main.skip_intro == null, "a first-time player cannot skip the introduction")
	# Someone who has finished it once may skip it; the rest of this test plays such a journey, the
	# guided start has its own checks at the end.
	main.intro_finished_once = true
	main.close_welcome()
	main._show_welcome()
	main.name_input.text = "青禾"
	main.welcome_roots = ["metal", "wood", "fire"]
	main.welcome_born = {"talents": [], "flaws": []}
	check(main.skip_intro != null, "once finished, a new journey may skip it")
	main.skip_intro.button_pressed = true
	main.begin()
	check(main.session.story_state("intro") == "done" and main.session.has_flag("intro_done") and main.session.story_state("lineage") == "active", "skipping counts the introduction as done and lets the sect's storylines follow")
	check(main.current_screen() == "full" and _texts(main.center, "Label").contains("顾长庚长老"), "the next storyline's words are told in a screen of their own")
	main.close_story()
	await _capture("sect")
	# Teaching cards: one at a time where it applies, some with pages; dismissed cards stay dismissed in
	# this journey.
	var tips: Array = main.Guide.tips()
	check(not tips.is_empty() and tips.all(func(tip: Dictionary) -> bool: return main.Guide.known(tip.id) and tip.title is String and tip.pages is Array and not tip.pages.is_empty() and not tip.where.is_empty()), "every card in the data has a known situation, a title and pages")
	check(_texts(main.center, "Label").contains("教学 · 闭关修炼  1 / 2") and _button("下一页") != null and _button("知道了") == null, "a new journey first sees the retreat card, page one of two")
	_button("下一页").pressed.emit()
	check(_texts(main.center, "Label").contains("一次闭关有上限") and _button("上一页") != null and _button("知道了") != null, "the last page explains the limits and can be dismissed")
	_button("知道了").pressed.emit()
	check("retreat" in main.session.player.taught and _texts(main.center, "Label").contains("教学 · 此地人物"), "dismissing it brings the next card that applies here")
	var dismissed := 0
	while (_button("知道了") != null or _button("下一页") != null) and dismissed < 20:
		dismissed += 1
		(_button("知道了") if _button("知道了") != null else _button("下一页")).pressed.emit()
	var taught: Array = main.session.player.taught
	check(not _texts(main.center, "Label").contains("教学 ·") and not "map" in taught and not "battle" in taught and "lineage" in taught and "stories" in taught, "cards for situations not met yet wait their turn")
	var copy = main.Session.new()
	check(copy.restore(JSON.parse_string(JSON.stringify(main.session.snapshot()))) and "people" in copy.player.taught, "dismissed cards are kept with the journey")
	main.set_guide_enabled(false)
	main.session.player.taught.erase("retreat")
	main.render()
	check(not _texts(main.center, "Label").contains("教学 ·"), "the cards can be switched off")
	main.reset_guide()
	check(main.guide_enabled and main.session.player.taught.is_empty() and _texts(main.center, "Label").contains("教学 · 闭关修炼"), "and every card of the journey can be shown again")
	main.set_guide_enabled(false)
	# A place is a scene: its name on top, its spots as paper tags, the people in a drawer at the left.
	check(main.scene_layer.visible and _tag("静室") != null and _tag("演武坪") != null and _tag("传功堂") != null, "the sect's spots hang on its scene as paper tags")
	await process_frame
	var tags: Array = main.scene_layer.find_children("*", "Button", true, false).filter(func(button: Button) -> bool: return not button.tooltip_text.is_empty() and button.text.contains("
"))
	check(tags.all(func(tag: Button) -> bool: return tag.get_global_rect().position.y >= main.hud_left.get_global_rect().end.y and tag.get_global_rect().end.x <= main.window.get_global_rect().position.x), "the tags keep clear of the HUD and the window")
	check(_texts(main.scene_layer, "Label").contains("青云山") and _texts(main.scene_layer, "Label").contains("此地人物"), "the scene shows the place's name and the people drawer")
	_tag("传功堂").pressed.emit()
	check(_texts(main.center, "Label").contains("研习传承") and _button("闭关修炼") == null, "a tag opens its spot, with only that spot's actions")
	check(_button("参悟吐纳法") != null or _button("参悟") != null, "the hall offers techniques to study")
	_tag("执事堂").pressed.emit()
	check(_button("接下：") != null, "the 执事堂 board lists commissions")
	main.toggle_drawer()
	check(not _texts(main.scene_layer, "Label").contains("此地人物 ·") and _button("▶") != null, "the drawer folds to its tab")
	main.toggle_drawer()
	var disciple: String = main.session.present_npcs().filter(func(person_id: String) -> bool: return person_id.begins_with("g:"))[0]
	main.open_person(disciple)
	check(_texts(main.center, "Label").contains(main.session.person(disciple).name) and _button("切磋") != null and _button("离开") != null and not _texts(main.center, "Label").contains("神通 ·"), "facing a disciple: their portrait and name, what can be done, details kept back")
	_button("查看").pressed.emit()
	check(_texts(main.center, "Label").contains("神通 ·") and _button("收起") != null, "查看 shows their arts")
	main.close_person()
	main.set_view("arts")
	await _capture("arts")
	var arts_text := _texts(main.center, "Label") + _texts(main.center, "Button")
	check(arts_text.contains("主动神通  3 / 4") and arts_text.contains("[1]") and arts_text.contains("御剑诀"), "the 神通 page: slots with their keys, the arts learned")
	main.set_view("methods")
	check(_texts(main.center, "Label").contains("心法  0 / 2"), "the 功法 page: the 心法 slots")
	main.set_arts_filter("fire")
	check(not (_texts(main.center, "Button")).contains("吐纳"), "the learned arts filter by element")
	main.set_arts_filter("all")
	main.set_view("place")
	_tag("静室").pressed.emit()
	check(main.status_label.get_global_rect().end.y <= main.get_global_rect().end.y + 1, "status line inside the window")
	# The world screen: only the HUD's corners stay on screen besides the window.
	check(main.current_screen() == "place" and main.hud_left.visible and main.hud_right.visible and main.window.get_global_rect().position.x >= main.hud_left.get_global_rect().end.x, "the world screen keeps the window clear of the HUD")
	check(main.clock_label.text == "历元 1 年 1 月初一" and main.place_label.text == "青云山", "the HUD shows the date and the place")
	check(main.journal_text.text == "\n".join(main.session.journal_lines().slice(-2)) and main.journal_text.text.contains("【1年1月初一】"), "the latest records show at the corner")
	var hud := _texts(main.hud_status, "Label")
	check(hud.contains("青禾") and hud.contains("气血") and hud.contains("修为  0 / 500"), "the HUD shows who you are and how you stand")
	check(_button("闭关修炼") != null and _button("突破境界") != null and _button("停留  ·  1 日") != null, "the chamber offers retreat, breakthrough and waiting")
	main.hud_icons.status.pressed.emit()
	check(main.current_screen() == "panel" and not main.hud_left.visible and main.tab_row.visible, "人物 opens the character panel over the world")
	var status := _texts(main.center, "Label")
	check(status.contains("年岁 16") and status.contains("寿元 120") and status.contains("寿元尽于历元 105 年"), "age and lifespan shown")
	check(status.contains("心境  0 / 0 · 闭关收益 100% · 单次闭关至多 3 个月") and status.contains("心神 · 平和 · 闭关收益 100%") and status.contains("历练  0 / 100"), "a fresh mind and no insight yet")
	main.hud_icons.status.pressed.emit()
	check(main.view == "place" and main.hud_left.visible, "the same button closes the panel")
	check(main.goal_label.visible and main.goal_label.text == "目标 · 除去妖蟒", "the HUD names the first goal")
	main.hud_icons.goals.pressed.emit()
	var goals_text := _texts(main.center, "Label")
	check(main.current_screen() == "scroll" and goals_text.contains("除去妖蟒") and goals_text.contains("历元 6 年 3 月初一") and goals_text.contains("还有 5 年 2 个月") and goals_text.contains("修为 0 / 2000"), "任务 opens the scroll: the serpent's deadline and breaking through")
	var close_key := InputEventKey.new()
	close_key.keycode = KEY_ESCAPE
	close_key.pressed = true
	main._unhandled_key_input(close_key)
	check(main.view == "place" and main.current_screen() == "place", "Esc closes the scroll")
	main.Settings.set_goals(main, false)
	check(not main.goal_label.visible, "the HUD's goal can be switched off")
	main.Settings.set_goals(main, true)
	_goals()
	# The retreat scroll: the monthly rate and where it comes from, the deadlines, a length to pick.
	_button("闭关修炼").pressed.emit()
	var scroll := _texts(main.center, "Label")
	check(main.current_screen() == "retreat" and scroll.contains("每月修为") and scroll.contains("灵根 ·") and scroll.contains("近 期 大 事") and scroll.contains("除去妖蟒 · 还有"), "闭关修炼 opens the retreat scroll: the rate, its sources and the deadlines")
	check(scroll.contains("此番至多 3 个月") and scroll.contains("心境 · 安定  0 / 0"), "the scroll names the longest retreat allowed and the mind")
	var length: HSlider = main.center.find_children("*", "HSlider", true, false)[0]
	check(int(length.max_value) == 9, "炼气初期 retreats run in ten-day steps up to ninety days")
	main.session.player.xp = 400
	length.value = 1
	length.value = 9
	check(_texts(main.center, "Label").contains("3 个月") and _texts(main.center, "Label").contains("触及瓶颈"), "a long retreat previews stopping at the bottleneck")
	main.close_overlay()
	main.session.player.xp = 500
	main.set_view("retreat")
	check(_texts(main.center, "Label").contains("修为卡在瓶颈") and _button("开始闭关") == null, "a bottleneck closes the retreat")
	main.set_view("status")
	check(_texts(main.center, "Label").contains("瓶颈"), "and shows on the character page")
	main.close_overlay()
	main.session.player.xp = 0
	main.set_view("retreat")
	length = main.center.find_children("*", "HSlider", true, false)[0]
	length.value = 3
	var retreat_from := int(main.session.world.day)
	_button("开始闭关").pressed.emit()
	await process_frame
	check(main.presenting and _texts(main.center, "Label").contains("闭 关 中") and int(main.session.world.day) == retreat_from + 30, "the rules run the retreat at once; the scroll plays it back")
	while main.presenting:
		await process_frame
	check(main.session.player.xp > 0 and not _texts(main.center, "Label").contains("闭 关 中") and _texts(main.center, "Label").contains("每月修为"), "and comes back to the scroll")
	main.close_overlay()
	main.session.player.xp = 0
	main.render()
	main._save_manual()
	main.run(func() -> String: return main.session.travel("wild"))
	await _capture("wild")
	check(main.clock_label.text == main.Calendar.date_text(retreat_from + 30 + 7), "travel advances the calendar by route days")
	check(main.audio.music_key == "wild" and main.audio.ambience_key == "wild", "music and ambience follow the location")
	main.set_guide_enabled(true)
	main.run(func() -> String: return main.session.start_battle("wolf"))
	check(_texts(main.center, "Label").contains("教学 · 斗法  1 / 2") and _texts(main.center, "Label").contains("按 1 / 2 / 3 / 4 或点按钮") and _button("[1] ") != null, "the first duel explains the controls with the bound keys")
	main.set_guide_enabled(false)
	check(main.current_screen() == "full" and not main.hud_left.visible and main.window.get_global_rect().size.is_equal_approx(main.get_global_rect().size) and _texts(main.center, "Label").contains("斗 法  ·  第 1 回合") and _button("守御") != null and _button("撤离") != null, "the duel takes the whole screen, with its dock along the bottom")
	_button("记录").pressed.emit()
	check(main.battle_record_open and _texts(main.center, "Label").contains("展开斗法"), "记录 shows the duel's latest entries")
	main.toggle_battle_record()
	await main.skill("fire")
	await _capture("battle")
	root.size = Vector2i(1280, 720)
	await _capture("battle_small")
	check(main.status_label.get_global_rect().end.y <= main.get_global_rect().end.y + 1, "status line inside the small window")
	# 16:9 only: a 1280×720 window, 1080p and 2K all lay out the same 1280×720 canvas, scaled.
	var canvases: Array[Vector2] = []
	for screen: Vector2i in [Vector2i(1280, 720), Vector2i(1920, 1080), Vector2i(2560, 1440)]:
		root.size = screen
		await process_frame
		canvases.append(main.get_global_rect().size)
	check(canvases.all(func(canvas: Vector2) -> bool: return canvas.is_equal_approx(Vector2(1280, 720))), "the window, 1080p and 2K share one 1280×720 layout")
	root.size = Vector2i(1920, 1080)
	main._show_welcome()
	main.continue_saved()
	check(main.started and main.session.battle.get("enemy_id", "") == "wolf", "continue restores the battle")
	main._load_manual()
	check(main.session.player.location == "sect" and main.session.battle.is_empty(), "manual load restores the sect")
	# People where the player stops: listed and opened on demand, never forced.
	main.run(func() -> String: return main.session.travel("market"))
	check(main.session.pending_event.is_empty() and _button("沈墨 · 云溪药铺掌柜") != null, "people here listed without forcing anything")
	main.set_view("people")
	check(_texts(main.center, "Button").contains("沈墨 · 云溪坊市"), "the 相识 tab lists acquaintances with their whereabouts")
	main.close_overlay()
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
	_button("查看").pressed.emit()
	var said := _texts(main.center, "Label")
	var first_line: String = main.session.content.people.shen_mo.talk[0]
	check(said.contains(first_line) and not said.contains("沈墨：" + first_line), "a talk line is shown under the speaker's name, once")
	var met: Dictionary = main.session.world.people.shen_mo
	check(said.contains("往 来") and said.contains("初识 · " + main.Calendar.date_text(int(met.met_day)) + " · 云溪坊市") and said.contains("交谈 1 次") and said.contains("上回代他收五株回春草"), "the card records when and where you met and what passed between you")
	check(said.contains("近 来") and said.contains("你交给沈墨五株回春草"), "and the latest chronicle entries about them, apart from what was just said")
	_button("离开").pressed.emit()
	check(main.selected_npc.is_empty() and _button("闭关修炼") == null, "back to the market scenes")
	# 编年史: the whole record by kind, newest first, a page at a time.
	main.set_view("chronicle")
	var record := _texts(main.center, "Label")
	check(record.contains("编 年 史  ·  %d 条" % main.session.chronicle.entries.size()) and record.contains("历元 1 年") and record.contains("你拜入青云山"), "the chronicle view lists the whole record under years")
	var kinds: Array = main.session.content.chronicle.keys() + ["event", "talk", "npc", "story", "letter"]
	check(kinds.all(func(kind: String) -> bool: return main.ChronicleView.groups().any(func(group: Dictionary) -> bool: return kind in group.get("entries", []) )), "every kind of entry has a filter")
	_button("大事").pressed.emit()
	var majors: Array = main.ChronicleView.shown(main)
	check(_button("大事").disabled and not majors.is_empty() and majors.size() < main.session.chronicle.entries.size() and majors.all(func(entry: Dictionary) -> bool: return entry.major), "大事 shows only the entries kept for life")
	_button("人物").pressed.emit()
	check(_texts(main.center, "Label").contains("沈墨") and not _texts(main.center, "Label").contains("你拜入青云山"), "人物 shows dealings with people")
	_button("全部").pressed.emit()
	if main.ChronicleView.page_count(main) > 1:
		_button("较早").pressed.emit()
		check(_texts(main.center, "Label").contains("第 2 / ") and not _button("较近").disabled, "older entries are a page further")
	else:
		check(_button("较早").disabled, "a short record fits on one page")
	_button("返回").pressed.emit()
	check(main.view == "place", "back from the chronicle")
	# The trading table: goods are laid out, and only 确定 trades them.
	main.select_spot("street")
	_button("交易").pressed.emit()
	check(main.current_screen() == "trade" and _button("筑基丹 · 120 灵石") != null and _button("回气丹 ·") != null, "交易 lays out the shop's goods")
	main.session.player.stones = 40
	main.session.set_item_count("huichun_grass", 2)
	_button("疗伤丹 ·").pressed.emit()
	_button("回春草 ×2 · 售").pressed.emit()
	var table := _texts(main.center, "Label")
	check(main.trade.buy == ["liaoshang_pill"] and int(main.trade.sell.get("huichun_grass", 0)) == 1 and main.session.item_count("liaoshang_pill") == 0, "goods are laid on the table, nothing traded yet")
	check(table.contains("灵石  %+d" % (main.session.sell_price("huichun_grass") - 20)), "with what it comes to")
	_button("确定").pressed.emit()
	check(main.session.item_count("liaoshang_pill") == 1 and main.session.item_count("huichun_grass") == 1 and main.trade.buy.is_empty(), "确定 sells and buys what is on the table")
	main.close_overlay()
	main.set_view("bag")
	await _capture("bag")
	check(_texts(main.center, "Label").contains("疗伤丹 ×1") and _button("服用") != null, "the 行囊 lists items with a use button")
	main.set_bag_filter("pill")
	check(not _texts(main.center, "Label").contains("回春草"), "and filters them by kind")
	main.set_bag_filter("all")
	main.set_view("place")
	# The region map: hidden places stay hidden; picking a node previews the route; departing travels it.
	main.set_view("map")
	await _capture("map")
	check(main.world_map != null and not "ruin" in main.world_map.visible_ids(), "map drawn without undiscovered places")
	check("沈墨" in main.world_map.people_at.get("market", []), "known people marked on the map")
	main.world_map.location_selected.emit("ridge")
	var route_text := _texts(main.center, "Label")
	check(route_text.contains("云溪坊市 → 白鹭渡 → 青石镇 → 松风岭") and route_text.contains("共 8 日"), "shortest route previewed with days")
	check(main.current_screen() == "map" and main.world_map.visible and main.window.get_global_rect().end.y < 460, "the map fills the screen, the route in a small window")
	_button("启程前往松风岭").pressed.emit()
	await process_frame
	check(main.presenting and main.world_map.visible and main.session.player.location == "ridge", "the rules walk the route at once; the map plays it back")
	var walk := await _watch_walk()
	check(walk.marked and walk.dates > 2, "the traveller's mark walks the legs while the date moves")
	check(main.session.player.location == "ridge" and main.view == "place" and main.world_map.traveller == null and not main.world_map.visible, "arriving enters the place")
	check(main.audio.last_cue == "arrive" and main.audio.music_key == "ridge", "arrival cue and local music")
	# A journey cut short (by an encounter or an event) is continued from the HUD, walked on the map.
	main.session.player.journey = {"to": "ferry"}
	main.render()
	check(main.journey_button != null and not main.journey_button.disabled, "an unfinished journey offers 继续赶路")
	main.journey_button.pressed.emit()
	await process_frame
	check(main.current_screen() == "map", "continuing goes back to the map")
	walk = await _watch_walk()
	check(walk.marked and main.session.player.location == "ferry" and main.view == "place" and main.session.player.journey.is_empty(), "and walks the rest of the way")
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
	check(_has_art("yunxi_night_market") and _button("随意逛逛") != null and main.window.get_global_rect().position.y > 360, "an event fills the screen with its illustration, its words and choices in a box along the bottom")
	main.session.pending_event = {}
	main.render()
	var rampage_day: int = main.Calendar.to_day(6, 3, 1)
	main.run(func() -> String:
		main.session.advance_days(rampage_day - int(main.session.world.day))
		return "")
	check(main.story.get("event", "") == "serpent_rampage" and _has_art("serpent_rampage") and _texts(main.center, "Label").contains("妖蟒之乱"), "the serpent breaking out is staged with its illustration")
	var typing := func() -> bool: return main.center.find_children("*", "Label", true, false).any(func(text: Label) -> bool: return text.visible_ratio < 1.0)
	check(typing.call(), "the story text types itself out")
	main.render()
	check(not typing.call(), "and is not typed again when the same scene is redrawn")
	main.Settings.set_text_speed(main, "instant")
	main._typed = {}
	main.render()
	check(not typing.call(), "instant text speed shows it at once")
	main.Settings.set_text_speed(main, "fast")
	_button("继续").pressed.emit()
	check(main.story.is_empty() and _texts(main.center, "Label").contains("青石镇"), "继续 returns to the place")
	# The panel's 系统 tab: saving, loading, a new journey and the settings.
	main.set_view("system")
	check(main.save_button.text == "保存 F5" and _button("新旅程") != null and _button("设置") != null, "the 系统 tab holds saving, loading, a new journey and the settings")
	_button("设置").pressed.emit()
	check(main.settings_dialog.visible, "the settings open from the 系统 tab")
	main.settings_dialog.hide()
	# Audio settings persist outside the save files.
	main._open_settings()
	var music_slider: HSlider = main.settings_dialog.find_child("Music", true, false)
	music_slider.value = 0.3
	main.settings_dialog.hide()
	check(is_equal_approx(float(main.audio.volumes.Music), 0.3) and FileAccess.file_exists(test_path + "/settings.cfg"), "volume change applied and saved")
	var tabs: TabContainer = main.settings_dialog.find_children("*", "TabContainer", true, false)[0]
	check(tabs.get_tab_count() == 4 and tabs.get_tab_title(2) == "按键" and main.settings_controls.speeds.selected == 1, "the settings dialog has sound, screen, key and game pages")
	# The other preferences share the settings file with the volumes.
	main.Settings.set_text_speed(main, "slow")
	main.audio.set_volume("SFX", 0.5)
	var config := ConfigFile.new()
	config.load(test_path + "/settings.cfg")
	check(is_equal_approx(float(config.get_value("audio", "Music", 0.0)), 0.3) and config.get_value("text", "speed", "") == "slow", "volumes and the other settings keep each other in the settings file")
	main.Settings.begin_binding(main, "save")
	var key := InputEventKey.new()
	key.keycode = KEY_F6
	key.pressed = true
	main.settings_dialog.window_input.emit(key)
	check(main.keys.save == KEY_F6 and main.binding_action.is_empty() and main.save_button.text == "保存 F6", "a key is rebound by pressing it in the dialog")
	main.Settings.bind_key(main, "guard", KEY_1)
	check(main.keys.guard == KEY_1 and main.keys.skill_1 == KEY_SPACE, "taking another action's key swaps the two")
	check(not main.Settings.bind_key(main, "load", KEY_ESCAPE), "the dialog's own keys cannot be bound")
	main.Settings.begin_binding(main, "load")
	var escape := InputEventKey.new()
	escape.keycode = KEY_ESCAPE
	escape.pressed = true
	main.settings_dialog.window_input.emit(escape)
	check(main.keys.load == KEY_F9 and main.binding_action.is_empty(), "Esc cancels a binding")
	main.Settings.load_state(main)
	check(main.keys.save == KEY_F6 and main.keys.guard == KEY_1 and main.text_speed == "slow", "settings are read back from the file")
	var press := InputEventKey.new()
	press.keycode = KEY_F6
	press.pressed = true
	main._unhandled_key_input(press)
	check(main.status_label.text.begins_with("手动存档已保存"), "the rebound key saves")
	main.Settings.reset_keys(main)
	check(main.keys == main.Settings.DEFAULT_KEYS and main.save_button.text == "保存 F5", "default keys restored")
	config.load(test_path + "/settings.cfg")
	config.set_value("controls", "keys", {"save": KEY_F2, "load": KEY_F2})
	config.set_value("display", "fullscreen", 1)
	config.set_value("saves", "autosave", "no")
	config.save(test_path + "/settings.cfg")
	main.Settings.load_state(main)
	check(main.keys == main.Settings.DEFAULT_KEYS and not main.fullscreen and main.autosave_enabled, "malformed settings fall back to the defaults")
	main.close_overlay()
	# With auto-save off only manual saves are written, and 继续旅程 reads the newer save.
	main.Settings.set_autosave(main, false)
	var generation: int = main.auto_store.generation
	_button("停留  ·  1 日").pressed.emit()
	check(main.auto_store.generation == generation and main.autosave_error.is_empty(), "with auto-save off, actions leave the auto save alone")
	main._ask_new_game()
	check(main.new_game_dialog.dialog_text.contains("自动存档已关闭"), "a new journey warns that nothing is saved automatically")
	main.new_game_dialog.hide()
	# Saves are told apart by their file times, which count whole seconds.
	await create_timer(1.1).timeout
	main._save_manual()
	var saved_day: int = int(main.session.world.day)
	main._show_welcome()
	main.continue_saved()
	check(main.started and int(main.session.world.day) == saved_day and main.manual_store.saved_at() > main.auto_store.saved_at(), "continue reads the newer manual save")
	main.Settings.set_autosave(main, true)
	main.Settings.set_text_speed(main, "fast")
	# Breaking through: the rules decide, and a realm reached has its own screen until 确定.
	main.run(func() -> String: return main.session.travel("sect"))
	main.session.player.stage = 3
	main.session.player.xp = 2000
	main.session.set_item_count("foundation_pill", 1)
	main.session.refresh_realm_stats()
	main.set_view("breakthrough")
	check(_texts(main.center, "Label").contains("✓  修为  2000 / 2000") and not _button("开始突破").disabled, "the 突破 tab lists what breaking through needs")
	_button("开始突破").pressed.emit()
	check(main.current_screen() == "full" and _texts(main.center, "Label").contains("筑基") and _texts(main.center, "Label").contains("寿元 120 → 220 年"), "a realm reached is shown on its own screen")
	_button("确定").pressed.emit()
	check(main.ceremony.is_empty() and main.view == "place" and main.session.player.realm == 1, "确定 returns to the place")
	# The end of a life.
	main.session.player.birth_day = int(main.session.world.day) + 30 - main.session.lifespan() * 360
	main.run(func() -> String: return main.session.cultivate(360))
	main.run(func() -> String: return main.session.cultivate(360))
	await _capture("ending")
	check(not main.session.ended.is_empty() and _texts(main.center, "Label").contains("此 生 已 尽"), "ending screen shown")
	main._load_manual()
	check(main.session.ended.is_empty(), "loading a save returns from the ending")
	main._ask_new_game()
	await process_frame
	main.new_game_dialog.hide()
	_guided()
	print("UI: %d checks, %d failures; %d captures" % [checks, failures, captures])
	main.queue_free()
	# Give the audio server a moment to release stopped playbacks before quitting.
	await create_timer(0.2).timeout
	quit(0 if failures == 0 else 1)
