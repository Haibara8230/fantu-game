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

## A store that reads back what it wrote without checking it against freshly loaded content: the
## life-ending choice below lives only in this session's content.
class TrustingStore extends "res://scripts/core/save_store.gd":
	func _candidates() -> Array[Dictionary]:
		var found: Array[Dictionary] = []
		for slot: int in [0, 1]:
			var path := directory.path_join("journey_%d.json" % slot)
			if FileAccess.file_exists(path):
				var parsed: Variant = JSON.parse_string(FileAccess.get_file_as_string(path))
				if parsed is Dictionary:
					found.append(parsed)
		found.sort_custom(func(a: Dictionary, b: Dictionary) -> bool: return int(a.generation) > int(b.generation))
		return found

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

## Texts in the window and on the place's scene together (a card floats on the scene when no spot is open).
func _screen(type: String) -> String:
	return _texts(main.center, type) + "
" + _texts(main.scene_layer, type)

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
	check(ids.call() == ["tournament", "foundation_xp", "serpent"] and filled.call(), "a new life starts with 潜龙会 two months off, a nearby cultivation goal, then the distant serpent")
	game.world.flags.rushi_done = true
	game.player.xp = 2000
	check(ids.call()[0] == "bottleneck" and not "foundation_xp" in ids.call(), "a bottleneck comes first and hides the plain xp goal")
	game.player.xp = 8000
	game.player.stage = 3
	check("foundation_pill" in ids.call() and Goals.current(game)[ids.call().find("foundation_pill")].text.contains("280 灵石"), "enough xp: the pill is next, with its price")
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
	game.world.day = Calendar.to_day(1, 8, 15)
	check("auction" in ids.call() and filled.call(), "two months ahead, the autumn auction is a goal")
	game.world.day = Calendar.to_day(1, 11, 1)
	check(not "auction" in ids.call() or Calendar.to_day(2, 10, 1) - int(game.world.day) <= 60, "and is forgotten once it has passed, until the next one draws near")
	# 潜龙会 is for 炼气 cultivators.
	game.player.realm = 0
	game.world.day = Calendar.to_day(5, 6, 1)
	var soon: Array[Dictionary] = Goals.current(game)
	check("tournament" in ids.call() and soon[ids.call().find("tournament")].text.contains("历元 6 年 3 月初一至十五"), "潜龙会 is mentioned within a year of it")
	game.player.realm = 1
	game.world.day = Calendar.to_day(6, 3, 16)
	check(not "tournament" in ids.call(), "and not again until the next one draws near")
	check(Goals.current(game).size() == ids.call().size(), "all current goals are available without a three-item cap")

## The guided start as a first-time player meets it: the mentor's words open it, the HUD's goal follows
## the step, the map holds the player to the step's place, the first retreat lasts the month asked for,
## and a 传音 later shows in the scroll and on the HUD.
func _guided() -> void:
	main.intro_finished_once = false
	main._show_welcome()
	check(main.skip_intro == null, "no skipping before the opening was finished once")
	var sensed := _texts(main.welcome_layer, "Label")
	check(sensed.contains("灵根 · ") and sensed.contains("资质 · ") and sensed.contains("先天天赋") and _welcome_button("重新感应（余 5 次）") != null, "the welcome senses roots, talents and aptitude")
	for i: int in 5:
		_welcome_button("重新感应（余 %d 次）" % (5 - i)).pressed.emit()
	check(_welcome_button("重新感应（余 0 次）") != null and _welcome_button("重新感应（余 0 次）").disabled, "and may sense again only five times")
	main.name_input.text = "新人"
	main.welcome_roots = ["metal", "wood", "fire"]
	main.welcome_born = {"talents": [], "flaws": []}
	main.begin()
	check(main.session.player.location == "town" and main.current_screen() == "full" and main.session.pending_event.get("id", "") == "rushi_inn" and _texts(main.center, "Label").contains("陆承舟"), "a new journey opens at the 青石镇 inn, where 陆承舟 cannot pay his rent")
	main.choose("watch")
	check(main.goal_label.text.begins_with("目标 · 入世") and main.goal_label.tooltip_text.contains("云溪"), "the HUD's goal is the way to 云溪")
	main.select_spot("inn")
	check(_button("闭关修炼") != null, "the inn lets a room to retreat in")
	main.set_view("retreat")
	check(_texts(main.center, "Label").contains("客栈静房") and _texts(main.center, "Label").contains("每月房钱"), "the retreat scroll names the room's rate and rent")
	main.set_view("map")
	main.select_map_target("ridge")
	check(not _button("启程前往松风岭").disabled, "nothing holds the road closed")
	main.set_view("place")
	main.session.world.letters.append({"npc": "xu_qinghe", "day": int(main.session.world.day), "read": false, "story": "errands", "step": "dew"})
	main.render()
	check(main.hud_icons.goals.text == "任务 · 传音 1", "an unread 传音 shows on the HUD")
	main.set_view("letters")
	check(_texts(main.center, "Label").contains("新 · 许清和") and _texts(main.center, "Label").contains("凝露草") and main.session.unread_letters() == 0, "the inbox shows it as new and reads it")
	main.session.world.invites.append({"id": "loan:0:xu_qinghe", "npc": "xu_qinghe", "kind": "loan", "made": 0, "deadline": 30, "amount": 20})
	main.render()
	check(_texts(main.center, "Label").contains("待 回 复") and _texts(main.center, "Label").contains("想借 20 灵石") and _button("借给他") != null and _button("婉拒") != null, "a friend's request waits for an answer at the top of the inbox")
	_button("婉拒").pressed.emit()
	check(main.session.open_invites().is_empty(), "and is answered there")
	main.set_view("stories")
	check(_texts(main.center, "Label").contains("入世 · 陆承舟") and _texts(main.center, "Label").contains("云溪"), "剧情 lists the opening with its step")
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

## The qi orb chip of an element in the duel's dock: its orb icon and "×count"; the element is named in
## its tooltip.
func _orb_chip(element_name: String, count: int) -> Button:
	for button: Button in main.center.find_children("*", "Button", true, false):
		if button.icon != null and button.text == "×%d" % count and button.tooltip_text.begins_with("%s灵气 %d 颗" % [element_name, count]):
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
	main.trial_store = SaveStore.new(test_path + "/trial")
	main.choice_store = SaveStore.new(test_path + "/choice")
	# Isolate preferences before _ready builds the welcome from the guide state.
	main.guide_path = test_path + "/guide.cfg"
	main.settings_path = test_path + "/settings.cfg"
	root.add_child(main)
	main.session.encounters_enabled = false
	main.audio.settings_path = test_path + "/settings.cfg"
	main.refresh_key_labels()
	# The welcome screen was built from the player's own guide file; build it again from the test's.
	main.close_welcome()
	main._show_welcome()
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
	check(main.session.story_state("rushi") == "done" and main.session.has_flag("rushi_done") and main.session.player.location == "town" and main.session.affiliation().is_empty(), "skipping the opening leaves a wanderer free at the 青石镇 inn")
	# The rest plays a disciple of 青云: to the sect and its recruiting terrace.
	main.run(func() -> String: return main.session.travel("sect"))
	while not main.session.pending_event.is_empty():
		main.choose(str(main.session.pending_definition().choices[0].id))
	main.story = {}
	main.run(main.session.join_sect)
	check(main.session.affiliation() == "qingyun" and main.session.story_state("lineage") == "active", "joining 青云 lets the sect's storylines follow")
	check(main.current_screen() == "full" and _texts(main.center, "Label").contains("顾长庚长老"), "the next storyline's words are told in a screen of their own")
	main.close_story()
	await _capture("sect")
	# Teaching cards: one at a time where it applies, some with pages; dismissed cards stay dismissed in
	# this journey.
	var tips: Array = main.Guide.tips()
	check(not tips.is_empty() and tips.all(func(tip: Dictionary) -> bool: return main.Guide.known(tip.id) and tip.title is String and tip.pages is Array and not tip.pages.is_empty() and not tip.where.is_empty()), "every card in the data has a known situation, a title and pages")
	check(not main.Guide.applies(main, "retreat") and not _screen("Label").contains("教学 · 闭关修炼"), "the retreat card waits until the chamber is entered")
	main.select_spot("chamber")
	check(main.Guide.applies(main, "retreat"), "the chamber opens the retreat teaching")
	check(_screen("Label").contains("教学 · 闭关修炼  1 / 2") and _button("下一页") != null and _button("知道了") == null, "a new journey first sees the retreat card, page one of two")
	_button("下一页").pressed.emit()
	check(_screen("Label").contains("一次闭关有上限") and _button("上一页") != null and _button("知道了") != null, "the last page explains the limits and can be dismissed")
	_button("知道了").pressed.emit()
	check("retreat" in main.session.player.taught and _screen("Label").contains("教学 · 此地人物"), "dismissing it brings the next card that applies here")
	var dismissed := 0
	while (_button("知道了") != null or _button("下一页") != null) and dismissed < 20:
		dismissed += 1
		(_button("知道了") if _button("知道了") != null else _button("下一页")).pressed.emit()
	var taught: Array = main.session.player.taught
	check(not _screen("Label").contains("教学 ·") and not "battle" in taught and "lineage" in taught and "stories" in taught, "cards for situations not met yet wait their turn")
	var copy = main.Session.new()
	check(copy.restore(JSON.parse_string(JSON.stringify(main.session.snapshot()))) and "people" in copy.player.taught, "dismissed cards are kept with the journey")
	main.set_guide_enabled(false)
	main.session.player.taught.erase("retreat")
	main.render()
	check(not _screen("Label").contains("教学 ·"), "the cards can be switched off")
	main.reset_guide()
	check(main.guide_enabled and main.session.player.taught.is_empty() and _screen("Label").contains("教学 · 闭关修炼"), "and every card of the journey can be shown again")
	main.set_guide_enabled(false)
	main.close_spot()
	# A place is a scene: its name on top, its spots as paper tags, the people in a drawer at the left.
	check(main.scene_layer.visible and _tag("静室") != null and _tag("演武坪") != null and _tag("传功堂") != null, "the sect's spots hang on its scene as paper tags")
	await process_frame
	var tags: Array = main.scene_layer.find_children("*", "Button", true, false).filter(func(button: Button) -> bool: return not button.tooltip_text.is_empty() and button.text.contains("
"))
	check(tags.all(func(tag: Button) -> bool: return not tag.get_global_rect().intersects(main.hud_left.get_global_rect()) and not tag.get_global_rect().intersects(main.hud_right.get_global_rect()) and main.get_global_rect().encloses(tag.get_global_rect())), "the tags keep clear of the HUD and stay on screen")
	check(not main.window.visible and not main.place_popup_open(), "with no spot open nothing covers the scene")
	check(_texts(main.scene_layer, "Label").contains("青云山") and _texts(main.scene_layer, "Label").contains("此地人物"), "the scene shows the place's name and the people drawer")
	_tag("传功堂").pressed.emit()
	check(_screen("Label").contains("本门传承") and _button("闭关修炼") == null, "a tag opens its spot, with only that spot's actions")
	check(_button("领取《") != null and _button("参悟") == null, "the hall hands out slips; studying is done in the chamber")
	_tag("执事堂").pressed.emit()
	check(_button("接下：") != null, "the 执事堂 board lists commissions")
	main.toggle_drawer()
	check(not _texts(main.scene_layer, "Label").contains("此地人物 ·") and _button("▶") != null, "the drawer folds to its tab")
	main.toggle_drawer()
	var disciple: String = main.session.present_npcs().filter(func(person_id: String) -> bool: return person_id.begins_with("g:"))[0]
	main.open_person(disciple)
	check(_screen("Label").contains(main.session.person(disciple).name) and _button("切磋") != null and _button("离开") != null and not _screen("Label").contains("神通 ·"), "facing a disciple: their portrait and name, what can be done, details kept back")
	_button("查看").pressed.emit()
	check(_screen("Label").contains("神通 ·") and _button("收起") != null, "查看 shows their arts")
	main.close_person()
	main.set_view("arts")
	await _capture("arts")
	var arts_text := _screen("Label") + _texts(main.center, "Button")
	check(arts_text.contains("主动神通  5 / 6") and arts_text.contains("[1]") and arts_text.contains("御剑诀"), "the 神通 page: slots with their keys, the arts learned")
	main.set_view("methods")
	check(_screen("Label").contains("心法  0 / 2"), "the 功法 page: the 心法 slots")
	main.set_arts_filter("fire")
	check(not (_texts(main.center, "Button")).contains("吐纳"), "the learned arts filter by element")
	main.set_arts_filter("all")
	main.set_view("place")
	_tag("静室").pressed.emit()
	check(main.status_label.get_global_rect().end.y <= main.get_global_rect().end.y + 1, "status line inside the window")
	# The world screen: only the HUD's corners stay on screen besides the window.
	check(main.current_screen() == "place" and main.hud_left.visible and main.hud_right.visible and main.window.get_global_rect().position.x >= main.hud_left.get_global_rect().end.x, "the world screen keeps the window clear of the HUD")
	check(main.clock_label.text == main.Calendar.date_text(int(main.session.world.day)) and main.place_label.text == "青云山", "the HUD shows the date and the place")
	check(main.journal_text.text == "\n".join(main.session.journal_lines().slice(-2)) and main.journal_text.text.contains("【1年1月"), "the latest records show at the corner")
	var hud := _texts(main.hud_status, "Label")
	check(hud.contains("青禾") and hud.contains("气血") and hud.contains("修为  0 / 2000"), "the HUD shows who you are and how you stand")
	check(_button("闭关修炼") != null and _button("突破境界") != null and _button("停留  ·  1 日") != null, "the chamber offers retreat, breakthrough and waiting")
	main.hud_icons.status.pressed.emit()
	check(main.current_screen() == "panel" and not main.hud_left.visible and main.tab_row.visible, "人物 opens the character panel over the world")
	var status := _screen("Label")
	check(status.contains("16 岁 · 寿元 120 · 尽于历元 105 年"), "age and lifespan shown")
	check(status.contains("0 / 0 · 闭关收益 100%") and status.contains("平和 · 闭关收益 100%") and status.contains("6 个月") and status.contains("历练") and status.contains("0 / 100"), "a fresh mind and no insight yet")
	check(status.contains("攻击加成") and status.contains("减伤") and status.contains("丹毒") and status.contains("资质") and status.contains("兵刃") and main.center.find_children("*", "TextureRect", true, false).size() > 0, "the character page shows the figure, the attributes in groups and the loadout")
	main.hud_icons.status.pressed.emit()
	check(main.view == "place" and main.hud_left.visible, "the same button closes the panel")
	check(main.goal_label.visible and main.goal_label.text.begins_with("目标 · " + str(Goals.current(main.session)[0].title)) and main.goal_label.text.contains("除去妖蟒"), "the HUD names the first goal")
	main.hud_icons.goals.pressed.emit()
	var goals_text := _screen("Label")
	check(main.current_screen() == "scroll" and goals_text.contains("除去妖蟒") and goals_text.contains("历元 12 年 3 月初一") and goals_text.contains("还有 11 年") and goals_text.contains("修为 0 / 8000"), "任务 opens the scroll: the serpent's deadline and breaking through")
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
	var scroll := _screen("Label")
	check(main.current_screen() == "retreat" and scroll.contains("每月修为") and scroll.contains("灵根 ·") and scroll.contains("近 期 大 事") and not scroll.contains("除去妖蟒 · 还有") and scroll.contains("远期约定"), "闭关修炼 names current constraints and keeps distant deadlines in the task calendar")
	check(scroll.contains("此番至多 6 个月") and scroll.contains("此阶段无心境门槛") and scroll.contains("当前修为  0 / 8000"), "the scroll names the longest retreat allowed and the mind")
	var length: HSlider = main.center.find_children("*", "HSlider", true, false)[0]
	check(int(length.max_value) == 18, "炼气初期 retreats run in ten-day steps up to half a year")
	main.session.player.xp = 1900
	length.value = 1
	length.value = 18
	check(_screen("Label").contains("6 个月") and _screen("Label").contains("触及瓶颈"), "a long retreat previews stopping at the bottleneck")
	main.close_overlay()
	main.session.player.xp = 2000
	main.set_view("retreat")
	check(_screen("Label").contains("修为卡在瓶颈") and _button("开始闭关") == null, "a bottleneck closes the retreat")
	main.set_view("status")
	check(_screen("Label").contains("瓶颈"), "and shows on the character page")
	main.close_overlay()
	main.session.player.xp = 0
	main.set_view("retreat")
	length = main.center.find_children("*", "HSlider", true, false)[0]
	length.value = 3
	var retreat_from := int(main.session.world.day)
	_button("开始闭关").pressed.emit()
	await process_frame
	# The rite that plays the retreat back is skipped in headless runs.
	check(int(main.session.world.day) == retreat_from + 30 and main.Rite.skipped(), "the rules run the retreat at once; its rite is only presentation")
	while main.presenting:
		await process_frame
	check(main.session.player.xp > 0 and not _screen("Label").contains("闭 关 中") and _screen("Label").contains("每月修为"), "and comes back to the scroll")
	# 领悟: the slips in the 行囊, the lineage and the layers, all studied here in the chamber.
	main.set_view("insight")
	check(main.current_screen() == "retreat" and _screen("Label").contains("研读玉简") and _screen("Label").contains("参悟功法") and _button("参悟 ·") != null, "the 领悟 page lists the slips and the layers of what is learned")
	main.session.add_item("j:t:breath:wood:1::0", 1)
	main.render()
	var study_from := int(main.session.world.day)
	_button("领悟 ·").pressed.emit()
	await process_frame
	while main.presenting:
		await process_frame
	check("t:breath:wood:1::0" in main.session.player.learned and int(main.session.world.day) > study_from and _screen("Label").contains("上次领悟"), "a slip is studied on the 领悟 page and takes its days")
	# Whatever an action brings is shown in the 获得 card until it is taken.
	check(main.gains_card != null and _texts(main.gains_card, "Label").contains("获  得") and _texts(main.gains_card, "Label").contains("习得心法"), "the 获得 card shows what was learned")
	main.GainsCard.close(main)
	main.run(func() -> String:
		main.session.add_item("huichun_grass", 3)
		main.session.player.stones = int(main.session.player.stones) + 12
		return "")
	var shown := _texts(main.gains_card, "Label") if main.gains_card != null else ""
	check(shown.contains("回春草") and shown.contains("×3") and shown.contains("灵石") and shown.contains("×12"), "items and stones gained show with their counts")
	main.run(func() -> String:
		main.session.add_item("huichun_grass", 2)
		return "")
	check(_texts(main.gains_card, "Label").contains("×5"), "gains while the card is open add up in it")
	main.run(func() -> String: return main.session.sell("huichun_grass", 1), false)
	main.GainsCard.close(main)
	main.run(func() -> String: return main.session.sell("huichun_grass", 1), false)
	check(main.gains_card == null, "a sale is not announced")
	main.close_overlay()
	main.session.player.xp = 0
	main.render()
	main._save_manual()
	var travel_from := int(main.session.world.day)
	main.run(func() -> String: return main.session.travel("wild"))
	await _capture("wild")
	check(main.clock_label.text == main.Calendar.date_text(travel_from + 7), "travel advances the calendar by route days")
	check(main.audio.music_key == "wild" and main.audio.ambience_key == "wild", "music and ambience follow the location")
	# The dock below reads 御剑诀, 离火术 and 回春诀 in its first three slots.
	for art: String in ["sword", "fire", "wood"]:
		if not art in main.session.player.learned:
			main.session.player.learned.append(art)
	main.session.player.arts = ["sword", "fire", "wood"]
	main.set_guide_enabled(true)
	main.run(func() -> String: return main.session.start_battle("wolf"))
	check(_screen("Label").contains("教学 · 斗法  1 / 3") and _screen("Label").contains("按 1 / 2 / 3 / 4 / 5 / 6 或点按钮") and _button("[1] ") != null, "the first duel explains the controls with the bound keys")
	check(_button("结束回合") != null and _button("结束回合").has_theme_stylebox_override("normal") and not _button("守御").has_theme_stylebox_override("normal"), "and points at the button it speaks of")
	for frame: int in 3:
		await process_frame
	var bubble: Rect2 = main.tip_card.get_global_rect() if main.tip_card != null else Rect2()
	var aimed: Rect2 = _button("结束回合").get_global_rect()
	var beside := bubble.end.y <= aimed.position.y + 1.0 or bubble.position.y >= aimed.end.y - 1.0
	check(main.tip_card != null and main.tip_card.top_level and beside and bubble.position.y - aimed.end.y < 40.0 and aimed.position.y - bubble.end.y < 40.0, "the card sits as a bubble just beside that button, not over it (%s by %s)" % [bubble, aimed])
	check(main.get_viewport_rect().encloses(bubble), "and stays on screen (%s in %s)" % [bubble, main.get_viewport_rect()])
	main.set_guide_enabled(false)
	check(main.current_screen() == "full" and not main.hud_left.visible and main.window.get_global_rect().size.is_equal_approx(main.get_global_rect().size) and _texts(main.center, "Label").contains("斗 法  ·  第 1 回合") and _button("守御") != null and _button("撤离") != null, "the duel takes the whole screen, with its dock along the bottom")
	check(_button("速战") != null, "the dock offers to finish the duel quickly")
	_button("记录").pressed.emit()
	check(main.battle_record_open and _texts(main.center, "Label").contains("展开斗法"), "记录 shows the duel's latest entries")
	check(_button("结束回合") != null and _texts(main.center, "Label").contains("对手下一回合：") and _button("[2] ").text.contains("火2"), "the dock shows 结束回合, the arts' orb costs, and the stage the opponent's intent")
	main.toggle_battle_record()
	main.session.battle.orbs = ["fire", "fire", "wood", "wood"]
	main.render()
	check(_orb_chip("木", 2) != null and not _orb_chip("木", 2).disabled and _button("[2] ") != null and not _button("[2] ").disabled, "the hand shows each element's orbs; an affordable art is ready")
	await main.battle_action("discard:wood")
	check(main.session.battle.orbs.count("wood") == 1 and _orb_chip("木", 1) != null, "clicking an element lets one of its orbs go")
	main.session.battle.orbs = ["fire", "fire", "wood", "wood", "fire"]
	main.render()
	await main.battle_action("end_turn")
	check(int(main.session.battle.turn) == 1 and _button("结束回合").text.contains("先散去 1 颗"), "over the cap the turn does not end until the player lets an orb go")
	await main.battle_action("discard:fire")
	check(main.session.battle.orbs.size() == 4 and _button("结束回合").text.contains(main.Settings.key_name(main, "end_turn")), "within the cap it can end")
	# 地利 in the foe's corner, and 神识探查 in the record's place (batch eight).
	check(_texts(main.center, "Label").contains("地利 · 山谷"), "the valley's favour for wood is shown")
	_button("神识探查").pressed.emit()
	var scouted: String = "神识压过对手" if main.session.Combat.scout(main.session).seen else "神识不及对手"
	check(main.battle_scout_open and _texts(main.center, "Label").contains(scouted) and _button("收起探查") != null, "探查 shows what 神识 makes of the wolf (%s)" % scouted)
	_button("收起探查").pressed.emit()
	check(not main.battle_scout_open and not main.battle_record_open, "and folds away")
	# 祭出 the worn 兵刃 and 符箓 from the dock (batch five), without taking the turn.
	var sword: String = main.session.Arsenal.equipment_id("sword", 2, "fire", [], 0)
	main.session.add_item(sword, 1)
	main.session.player.equipment.weapon = sword
	main.session.set_item_count("lei_fu", 1)
	main.render()
	check(_button("祭出 · 飞剑") != null and not _button("祭出 · 飞剑").disabled and _button("掌心雷符") != null and _button("掌心雷符").tooltip_text.contains("符箓"), "the dock offers to release the sword and the talisman")
	check(_button("撤离").tooltip_text.contains("能脱身"), "撤离 states the odds of getting away")
	var foe_hp := int(main.session.battle.hp)
	main.session.battle.hp = 500
	var turn := int(main.session.battle.turn)
	await main.battle_action("release")
	check(int(main.session.battle.get("hp", 0)) < 500 and _button("祭出 · 飞剑") != null and _button("祭出 · 飞剑").disabled, "releasing strikes once, then the button rests")
	if not main.session.battle.is_empty():
		await main.battle_action("pill:lei_fu")
		check(main.session.battle.is_empty() or (int(main.session.battle.turn) == turn and int(main.session.battle.talismans) == 1), "a talisman is used without ending the turn")
	main.session.player.equipment.weapon = ""
	if not main.session.battle.is_empty():
		main.session.battle.hp = foe_hp
		main.session.battle.orbs = ["fire", "fire", "fire"]
	main.render()
	await main.skill("fire")
	check(main.session.battle.orbs == ["fire"] and _button("[2] ").disabled, "a cast spends its orbs and disables what the hand no longer covers")
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
	check(record.contains("编 年 史  ·  %d 条" % main.session.chronicle.entries.size()) and record.contains("历元 1 年") and record.contains("从此踏上仙途"), "the chronicle view lists the whole record under years")
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
	check(main.current_screen() == "trade" and _button("筑基丹 · 280 灵石") != null and _button("回气丹 ·") != null, "交易 lays out the shop's goods")
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
	check(main.current_screen() == "map" and main.world_map.visible and main.window.get_global_rect().end.y < root.size.y * 0.65 and not main.window.get_global_rect().intersects(main.hud_right.get_global_rect()), "the map fills the screen, the route in a small window")
	_button("启程前往松风岭").pressed.emit()
	await process_frame
	check(main.presenting and main.world_map.visible and main.session.player.location == "ridge", "the rules walk the route at once; the map plays it back")
	var walk := await _watch_walk()
	check(walk.marked and walk.dates > 2, "the traveller walks the legs while the date moves")
	check(main.world_map.figure.get("texture") is Texture2D and main.world_map.figure.region.size.x > 0.0, "the traveller is the hero's figure, not a mark")
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
	var rampage_day: int = main.Calendar.to_day(12, 3, 1)
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
	check(main.story.is_empty() and main.current_screen() == "place" and _texts(main.scene_layer, "Label").contains("青石镇"), "继续 returns to the place")
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
	check(main.keys.guard == KEY_1 and main.keys.skill_1 == KEY_G, "taking another action's key swaps the two")
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
	# A file from before 结束回合: 守御 was on Space, which now ends the turn; other keys are kept.
	config.set_value("controls", "keys", {"save": KEY_F6, "load": KEY_F9, "skill_1": KEY_1, "skill_2": KEY_2, "skill_3": KEY_3, "skill_4": KEY_4, "guard": KEY_SPACE})
	config.save(test_path + "/settings.cfg")
	main.Settings.load_state(main)
	check(main.keys.save == KEY_F6 and main.keys.end_turn == KEY_SPACE and main.keys.guard == KEY_G, "an older key file gives Space to 结束回合 and keeps its other keys")
	config.set_value("controls", "keys", {"save": KEY_F5, "load": KEY_F9, "skill_1": KEY_1, "skill_2": KEY_2, "skill_3": KEY_3, "skill_4": KEY_4, "guard": KEY_Q})
	config.save(test_path + "/settings.cfg")
	main.Settings.load_state(main)
	check(main.keys.guard == KEY_Q and main.keys.end_turn == KEY_SPACE, "a 守御 the player rebound stays")
	main.Settings.reset_keys(main)
	main.close_overlay()
	# With auto-save off only manual saves are written, and 继续旅程 reads the newer save.
	main.Settings.set_autosave(main, false)
	var generation: int = main.auto_store.generation
	main.select_spot(str(main.session.content.locations[main.session.player.location].spots[0].id))
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
	# The sect's page: standing, promotion, stipend, exchange and donations, handled at the 执事堂.
	main.run(func() -> String: return main.session.travel("sect"))
	main.set_view("sect")
	var sect_text := _texts(main.center, "Label")
	check(sect_text.contains("青云剑宗 · 外门弟子") and sect_text.contains("晋升外门精英") and sect_text.contains("宗门兑换") and _button("申请晋升") != null and _button("申请晋升").disabled and _button("回气丹 · 8 贡献") != null, "the 宗门 page shows the standing, the next rank and the exchange")
	main.session.player.contribution = 20
	main.render()
	_button("回气丹 · 8 贡献").pressed.emit()
	check(main.session.item_count("huiqi_pill") >= 1 and int(main.session.player.contribution) == 12, "and exchanges there")
	# Alchemy at the 静室: the page sets out a brew and its odds before the furnace is lit.
	main.set_view("place")
	main.select_spot("chamber")
	check(_button("开炉炼丹") != null, "the 静室 offers alchemy")
	_button("开炉炼丹").pressed.emit()
	check(main.view == "alchemy" and _texts(main.center, "Label").contains("还不会任何丹方"), "without a recipe the page says where to find one")
	main.session.set_item_count("recipe_liaoshang", 1)
	main.set_view("bag")
	check(_button("研读") != null, "a 丹方 in the 行囊 is read, not swallowed")
	_button("研读").pressed.emit()
	main.session.set_item_count("huichun_grass", 4)
	main.open_alchemy()
	var brew_text := _texts(main.center, "Label")
	check(brew_text.contains("主药") and brew_text.contains("回春草（平）×3") and brew_text.contains("成丹把握 70%") and brew_text.contains("成丹 2–3 枚"), "the page shows the herbs and the odds")
	_button("不用药引").pressed.emit()
	check(_texts(main.center, "Label").contains("成丹 1–2 枚") and _texts(main.center, "Label").contains("上品 0%"), "leaving out the 药引 costs a pill and any fine one")
	_button("回春草（平）").pressed.emit()
	main.session.fortune = {"alchemy": 0.0, "alchemy_fine": 0.99}
	_button("开炉").pressed.emit()
	check(main.view == "alchemy" and main.session.item_count("liaoshang_pill") >= 2 and main.session.item_count("huichun_grass") == 0, "lighting the furnace brews and stays on the page")
	await _capture("alchemy")
	main.session.fortune = {}
	# The 灵田 at the 洞府, once an inner disciple.
	main.session.player.rank = main.session.Sect.rank_index(main.session, "inner")
	main.session.set_item_count("huichun_grass", 1)
	main.set_view("place")
	main.select_spot("abode")
	check(_button("照料灵田") != null, "an inner disciple's 洞府 has a field")
	_button("照料灵田").pressed.emit()
	check(main.view == "field" and _texts(main.center, "Label").contains("洞府灵田 · 下品灵田") and _button("种回春草") != null, "the field page shows the plots and what can be planted")
	_button("种回春草").pressed.emit()
	check(_texts(main.center, "Label").contains("回春草 · 还需"), "a planted herb shows when it ripens")
	await _capture("field")
	main.session.player.rank = 0
	main.session.player.field = {"grade": 0, "plots": []}
	main.set_view("place")
	# 消息 keeps what was said lately; 品级 colors follow 白绿蓝紫橙红.
	main.set_view("messages")
	check(_texts(main.center, "Label").contains("近来消息") and _texts(main.center, "Label").contains("灵田"), "the 消息 tab keeps the latest records")
	check(main.session.content.rarity_of(main.session.content.item("foundation_pill")) == 2 and main.grade_color(main.session.content.item("qiannian_shiru")) == Color("#e59d52") and main.session.content.rarity_of(main.session.content.technique("t:bolt:metal:1::15")) == 0, "items and techniques are graded by color")
	main.set_view("place")
	# An auction takes the screen: the lot, the price and who holds it, the bidders, and the raises.
	main.run(func() -> String: return main.session.travel("market"))
	# 云溪's own occasions may meet the arrival: watch them first.
	while not main.session.pending_event.is_empty():
		main.choose("watch" if main.session.pending_definition().choices.any(func(choice: Dictionary) -> bool: return choice.id == "watch") else str(main.session.pending_definition().choices[0].id))
	main.story = {}
	main.session.player.stones = 500
	main.session.Auctions.open(main.session, "night_market")
	main.render()
	check(main.current_screen() == "full" and _texts(main.center, "Label").contains("云溪夜市拍卖摊") and _texts(main.center, "Label").contains("第 1 / 3 件") and _button("出价") != null and _button("放弃此件") != null, "an auction takes the screen with the lot and the raises")
	check(main.session.auction.bidders.all(func(person_id: String) -> bool: return _texts(main.center, "Label").contains(main.session.person(person_id).name)), "the bidders sit around the room")
	main.set_guide_enabled(true)
	check(_texts(main.center, "Label").contains("教学 · 拍卖"), "the first auction explains the bidding")
	main.set_guide_enabled(false)
	await _capture("auction")
	var guard := 0
	while not main.session.auction.is_empty() and guard < 100:
		guard += 1
		if _button("放弃此件").disabled:
			break
		_button("放弃此件").pressed.emit()
	check(main.session.auction.is_empty() and main.current_screen() == "place", "letting every lot go ends it and returns to the place")
	# Breaking through: the rules decide, and a realm reached has its own screen until 确定.
	main.run(func() -> String: return main.session.travel("sect"))
	main.session.player.stage = 3
	main.session.player.xp = 8000
	main.session.set_item_count("foundation_pill", 1)
	main.session.refresh_realm_stats()
	main.set_view("breakthrough")
	var plan_text := _texts(main.center, "Label")
	check(plan_text.contains("✓  修为  8000 / 8000") and plan_text.contains("服筑基丹 1 枚") and plan_text.contains("成功率  ") and plan_text.contains("资质 · ") and not _button("开始突破").disabled, "the 突破 tab lays out the plan and its odds")
	check(plan_text.contains("若失败") and plan_text.contains("性命无碍"), "and what failing would cost")
	main.session.set_item_count("foundation_pill", 2)
	main.render()
	var odds_one: String = _texts(main.center, "Label")
	_button("＋").pressed.emit()
	check(_texts(main.center, "Label").contains("服筑基丹 2 枚") and _texts(main.center, "Label").contains("筑基丹 ×2 +40") and _texts(main.center, "Label") != odds_one, "a second pill raises the odds by less than the first")
	_button("－").pressed.emit()
	# A failed attempt: the pill is spent, xp falls back, and the outcome has its own screen.
	main.session.fortune = {"demon": 0.99, "breakthrough": 0.99}
	_button("开始突破").pressed.emit()
	check(main.current_screen() == "full" and _texts(main.center, "Label").contains("冲 关 失 败") and int(main.session.player.xp) == 7840 and main.session.injured() and main.session.player.realm == 0, "a failed breakthrough is shown on its own screen")
	_button("确定").pressed.emit()
	# 心魔 first, then success.
	main.session.player.xp = 8000
	main.session.player.mind = 10
	main.session.fortune = {"demon": 0.0, "breakthrough": 0.0}
	main.set_view("breakthrough")
	check(_texts(main.center, "Label").contains("前车之鉴") and _texts(main.center, "Label").contains("心魔"), "a lesson learned and the threat of 心魔 show in the odds")
	_button("开始突破").pressed.emit()
	check(main.current_screen() == "full" and not main.session.pending_event.is_empty() and _button("紧守灵台") != null, "心魔 comes as a choice")
	_button("紧守灵台").pressed.emit()
	check(main.current_screen() == "full" and _texts(main.center, "Label").contains("筑基") and _texts(main.center, "Label").contains("寿元 120 → 220 年") and _texts(main.center, "Label").contains("根基 · "), "a realm reached is shown on its own screen, with its grade")
	_button("确定").pressed.emit()
	check(main.ceremony.is_empty() and main.view == "place" and main.session.player.realm == 1, "确定 returns to the place")
	# 客卿 at a sect's gate (guest.gd): offered there, open to a 青云 disciple too (the sects do not clash).
	main.session.world.flags["tiannan_known"] = true
	main.session.world.flags["guest_invite_chixiao"] = true
	main.session.player.location = "chixiao_gate"
	main.set_view("place")
	main.select_spot("pavilion")
	var guest_button: Button = _button("应邀做赤霄门客卿")
	check(guest_button != null and not guest_button.disabled and guest_button.tooltip_text.contains("客卿"), "赤霄's 迎客亭 offers the guest's place, open to a 青云 disciple")
	# 护送 at 青石镇's 镇口木栅 (series.gd), fought as a pack with a target to pick (群敌).
	main.session.player.location = "town"
	var stage_was := int(main.session.player.stage)
	main.session.player.stage = maxi(stage_was, 2)
	# 筑基后期 brings 顾长庚's word on the 金丹 (结丹之备); let it come before the escort is taken.
	main.session.Storylines.update(main.session)
	main.set_view("place")
	main.select_spot("palisade")
	check(_button("接下 · 护送商队") != null and not _button("接下 · 护送商队").disabled and _button("接下 · 护送商队").tooltip_text.contains("云溪坊市"), "the 镇口 offers the caravan escort and says where it goes")
	_button("接下 · 护送商队").pressed.emit()
	check(not main.session.battle.is_empty() and str(main.session.battle.get("series", "")) == "escort_qingshi", "taking it starts the first ambush")
	# A second robber joins (the later ambush is a pack).
	main.session.Combat.add_pack(main.session, ["zhui_bing"])
	main.render()
	var rogue_name: String = main.session.content.enemies.rogue.name
	check(not main.session.battle.is_empty() and _button("◆ " + rogue_name) != null and _texts(main.center, "Label").contains("另有 1 个围攻"), "the ambush is a pack: the lead is aimed at, the other's blows are in the intent")
	await main.battle_action("target:1")
	check(int(main.session.battle.target) == 1 and _button("◆ ") != null and _button("◆ ").disabled, "picking the other one turns the arts on it")
	while not main.session.battle.is_empty():
		main.session.player.hp = main.session.player.max_hp
		await main.battle_action("flee")
	check(not main.session.player.has("series"), "fleeing gives the escort up")
	main.session.player.stage = stage_was
	# A grudge on the road (feuds.gd): the ambush speaks in the avenger's name and states its price.
	main.session.Feuds._add(main.session, {"name": "「独眼」韩青", "enemy": "rogue", "cause": "comrade", "region": "qingyun"})
	main.session.pending_event = {"id": "grudge_ambush", "day": int(main.session.world.day), "values": {"grudge": str(main.session.world.grudges.back().id), "foe": "「独眼」韩青", "words": str(main.session.content.feuds.causes.comrade), "pay": str(main.session.Feuds.pay(main.session))}}
	main.render()
	check(_texts(main.center, "Label").contains("「独眼」韩青拦在路中") and _button("交出 %d 灵石" % main.session.Feuds.pay(main.session)) != null, "the ambush names the avenger and the price of peace")
	main.choose("slip")
	check(main.session.pending_event.is_empty() and main.session.journal_lines().any(func(line: String) -> bool: return line.contains("「独眼」韩青没有追上")), "the choice is told in their name")
	main.session.world.grudges.clear()
	# 收尾抉择 after a road outlaw: let go, search, or press for the hoard.
	main.session.pending_event = {"id": "victory_terms", "day": int(main.session.world.day), "values": {"enemy": "rogue", "foe": str(main.session.content.enemies.rogue.name)}}
	main.render()
	check(_texts(main.center, "Label").contains(str(main.session.content.enemies.rogue.name) + "倒在地上") and _button("放他走") != null and _button("搜身") != null and _button("逼问") != null, "a beaten outlaw awaits the verdict: let go, search, or press")
	main.choose("release")
	check(main.session.pending_event.is_empty(), "the verdict is given")
	# 天劫 (B7): no fleeing, the bolts counted, the dispersal stated.
	main.session.player["tribulation"] = {"grade": 1, "days": 0, "xp": 0}
	main.session.Combat.begin_tribulation(main.session, "tribulation_core")
	main.render()
	check(_button("撤离") != null and _button("撤离").disabled and _texts(main.center, "Label").contains("第 1 道天雷") and _texts(main.center, "Label").contains("余 3 道天雷"), "the 天劫 cannot be fled and counts its bolts")
	main.session.battle.clear()
	main.session.player.erase("tribulation")
	main.render()
	# A 死斗 (combat.gd): its 劫前 save as it begins, the 禁忌秘术 at hand, and the fall.
	var realm_was := int(main.session.player.realm)
	main.session.player.realm = maxi(realm_was, 1)
	main.session.refresh_realm_stats()
	main.run(func() -> String:
		main.session.Events.apply(main.session, [{"battle": "xuesha_tu"}, {"deadly": true}])
		main.session.changed.emit()
		return "")
	check(main.trial_store.has_save() and _texts(main.center, "Label").contains("死斗：落败即身死"), "a 死斗 says so and leaves a 劫前 save as it begins")
	_button("禁忌秘术").pressed.emit()
	check(main.battle_secret_open and _button("燃血术") != null and _button("祭丹术") != null and _button("祭丹术").disabled, "the 秘术 are at hand, each with its price")
	main.toggle_battle_secret()
	main.run(func() -> String:
		main.session.player.hp = 0
		return main.session.Combat._lose(main.session))
	check(str(main.session.ended.get("kind", "")) == "fallen" and _texts(main.center, "Label").contains("斗 法 陨 落") and _button("读取劫前存档") != null, "lost, the life ends; the 劫前 save is offered")
	_button("读取劫前存档").pressed.emit()
	check(main.session.ended.is_empty() and not main.session.battle.is_empty() and bool(main.session.battle.get("deadly", false)), "and reading it returns to the fight's start")
	main.session.battle.clear()
	# A choice that would end the life (events.gd `final`): marked, saved before, and read back from the end.
	main.session.content.events["test_final"] = {"title": "终局", "trigger": "manual", "text": "此去再无回头路。", "choices": [
		{"id": "stay", "label": "留下", "chronicle": "你留了下来。"},
		{"id": "go", "label": "随他而去", "final": true, "effects": [{"end_life": "从此人间再无此人。"}], "chronicle": "你随他去了。"}]}
	var real_choice_store = main.choice_store
	main.choice_store = TrustingStore.new(real_choice_store.directory)
	main.story = {}
	main.session.pending_event = {"id": "test_final", "day": int(main.session.world.day)}
	main.session.changed.emit()
	main.render()
	check(main.choice_store.has_save() and _button("随他而去（此选将结束这一生）") != null and _button("留下") != null, "a life-ending choice says so and leaves a 抉择前 save before it is made")
	_button("随他而去").pressed.emit()
	check(str(main.session.ended.get("kind", "")) == "story" and _texts(main.center, "Label").contains("此 生 已 了") and _texts(main.center, "Label").contains("人间再无此人") and _button("读取抉择前存档") != null, "made, the life ends with its words; the 抉择前 save is offered")
	_button("读取抉择前存档").pressed.emit()
	check(main.session.ended.is_empty() and main.session.pending_event.get("id", "") == "test_final", "and reading it returns to the choice")
	main.session.pending_event = {}
	main.session.content.events.erase("test_final")
	main.choice_store = real_choice_store
	main.session.player.realm = realm_was
	main.session.refresh_realm_stats()
	main.render()
	main.session.player.location = "sect"
	main.set_view("place")
	# The end of a life.
	main.session.player.birth_day = int(main.session.world.day) + 30 - main.session.lifespan() * 360
	main.run(func() -> String: return main.session.cultivate(360))
	main.run(func() -> String: return main.session.cultivate(360))
	await _capture("ending")
	check(main.session.at_brink() and _texts(main.center, "Label").contains("大 限 将 至") and _button("逆天续命") != null, "the end first offers to defy fate")
	_button("就此坐化").pressed.emit()
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
