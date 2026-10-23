extends SceneTree
const SaveStore = preload("res://scripts/core/save_store.gd")
var main
var checks := 0
var failures := 0

func _initialize() -> void:
	create_timer(60).timeout.connect(func() -> void: printerr("MCS panels timeout"); quit(1))
	call_deferred("run")

func check(ok: bool, message: String) -> void:
	checks += 1
	if not ok:
		failures += 1
		printerr("FAIL: " + message)

func button(text: String) -> Button:
	for node: Button in main.center.find_children("*", "Button", true, false):
		if node.text.begins_with(text):
			return node
	return null

func words() -> String:
	return "\n".join(main.center.find_children("*", "Label", true, false).map(func(node: Label) -> String: return node.text))

func settled(page: String) -> void:
	main.set_view(page)
	await process_frame
	await process_frame
	check(main.window.get_global_rect().end.x <= root.size.x + 1 and main.window.get_global_rect().position.x >= -1, page + " window fits viewport")
	check(main.center.get_combined_minimum_size().x <= main.window.size.x + 1, page + " content stays within window width")

func run() -> void:
	root.size = Vector2i(1920, 1080)
	main = load("res://scenes/main.tscn").instantiate()
	var folder := "res://.tmp/mcs_panels_%d" % Time.get_ticks_usec()
	main.manual_store = SaveStore.new(folder + "/manual")
	main.auto_store = SaveStore.new(folder + "/auto")
	main.trial_store = SaveStore.new(folder + "/trial")
	main.choice_store = SaveStore.new(folder + "/choice")
	main.guide_path = folder + "/guide.cfg"
	main.settings_path = folder + "/settings.cfg"
	root.add_child(main)
	main.close_welcome()
	main.session.encounters_enabled = false
	main.session.new_game("界面测试", 42, ["earth", "fire"])
	main.started = true
	main.session.player.stones = 3000
	await settled("dao")
	check(button("御土") != null and not button("御土").disabled, "initial understanding enables first earth node")
	button("御土").pressed.emit()
	check("earth_guard" in main.session.Dao.state(main.session).nodes and button("御土").text.contains("已领悟"), "node click allocates and updates its display")
	main.session.Dao.gain(main.session, "earth", 1200, true)
	main.session.player.location = "town"
	await settled("insight")
	check(button("感悟大道") != null, "retreat insight links pending understanding to Dao page")
	button("感悟大道").pressed.emit()
	check(main.view == "dao", "Dao shortcut opens correct page")
	await settled("arts")
	check(main.center.find_children("LoadoutSlot*", "Button", true, false).size() == 10, "ten configurable art slots")
	main.center.find_child("LoadoutSlot2", true, false).pressed.emit()
	check(main.arts_slot == 1, "slot selection changes replacement target")
	await settled("methods")
	check(main.center.find_children("LoadoutSlot*", "Button", true, false).size() == int(main.session.content.rules.method_slots), "method slots follow gameplay rules")
	main.session.add_item("longhu_dan", 1)
	await settled("bag")
	var cell: Button = main.center.find_child("BagCell_longhu_dan", true, false)
	check(cell != null, "preparation medicine appears as inventory cell")
	cell.pressed.emit()
	check(words().contains("龙虎丹") and button("服用") != null, "selected item exposes correct action")
	button("服用").pressed.emit()
	check("longhu_dan" in main.session.Prebattle.pending(main.session), "inventory action consumes preparation medicine before battle")
	main.session.Alchemy.learn(main.session, "liaoshang")
	main.session.add_item("huichun_grass", 8)
	main.session.add_item("lingzhi", 2)
	await settled("alchemy")
	button("调整丹方").button_pressed = true
	check(main.alchemy_plan.has("main") and words().contains("生机"), "custom formula toggle exposes potency and herb controls")
	main.session.player.location = "market"
	main.session.add_item("ore_qinggang", 4)
	main.session.add_item("silk_qing", 4)
	await settled("forge")
	button("组合多种材料").button_pressed = true
	check(main.forge_plan.has("materials") and words().contains("消耗"), "mixed material controls and actual costs are available")
	main.forge_plan.materials = {"ore_qinggang": 2, "silk_qing": 1}
	main.render()
	check(words().contains("青钢锭 ×2") and words().contains("青丝 ×1"), "forge preview lists each selected material count")
	main.session.player.location = "town"
	main.render()
	for person: String in main.session.present_npcs():
		main.open_person(person)
		await process_frame
		check(button("离开") != null and (button("查看") != null or button("收起") != null), "NPC commands preserve persistent profile and exit buttons")
		main.close_person()
		break
	root.size = Vector2i(2560, 1440)
	main.session.player.location = "market"
	for page: String in ["dao", "arts", "methods", "bag", "alchemy", "forge", "trade"]:
		await settled(page)
	print("MCS PANELS: %d checks, %d failures" % [checks, failures])
	quit(1 if failures else 0)
