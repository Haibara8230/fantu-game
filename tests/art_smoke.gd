extends SceneTree
## Resource coverage plus the actual event/portrait/background consumers, without player saves.
const ArtLibrary = preload("res://scripts/ui/art_library.gd")
const Session = preload("res://scripts/core/session.gd")
const PeopleView = preload("res://scripts/ui/people_view.gd")
const SaveStore = preload("res://scripts/core/save_store.gd")
var checks := 0
var failures := 0
func _initialize() -> void:
	create_timer(60.0).timeout.connect(func() -> void: printerr("ART test timed out"); quit(1))
	call_deferred("_run")

func check(ok: bool, message: String) -> void:
	checks += 1
	if not ok:
		failures += 1
		printerr("FAIL: " + message)

func _run() -> void:
	var content: Dictionary = JSON.parse_string(FileAccess.get_file_as_string("res://data/world.json"))
	var art: Dictionary = JSON.parse_string(FileAccess.get_file_as_string("res://data/art.json"))
	var events: Dictionary = JSON.parse_string(FileAccess.get_file_as_string("res://data/events.json"))
	# Every foe can be drawn on the stage: its own entry, borrowing an atlas until its art comes.
	for enemy_id: String in content.enemies:
		check(art.actors.has(enemy_id), enemy_id + " has a stage figure")
	for location_id: String in content.locations:
		var fullscreen := ArtLibrary.texture(ArtLibrary.fullscreen_location_path(location_id))
		check(fullscreen != null and fullscreen.resource_path.ends_with("_fullscreen.png"), location_id + " has its full-screen composition")
		if fullscreen != null:
			check(absf(float(fullscreen.get_width()) / fullscreen.get_height() - 16.0 / 9.0) < 0.02, location_id + " is 16:9")
		for spot: Dictionary in content.locations[location_id].spots:
			var drawn: bool = ArtLibrary.texture(ArtLibrary.scene_path(location_id, spot.id)) != null
			check(drawn, location_id + "/" + str(spot.id) + " has dedicated art")
	for event_id: String in art.event_art:
		check(events.has(event_id) and ArtLibrary.texture(ArtLibrary.event_art(event_id)) != null, event_id + " points to a loadable illustration")
	var main = load("res://scenes/main.tscn").instantiate()
	var isolated := "res://.godot/art_saves_%d" % Time.get_ticks_usec()
	main.manual_store = SaveStore.new(isolated + "/manual")
	main.auto_store = SaveStore.new(isolated + "/auto")
	main.settings_path = isolated + "/settings.cfg"
	main.guide_path = isolated + "/guide.cfg"
	root.add_child(main)
	main.close_welcome()
	main.started = true
	main.guide_enabled = false
	main.session.encounters_enabled = false
	main.session.new_game("美术检查", 42, ["metal", "wood", "fire"])
	main.story = {}
	for viewport: Vector2i in [Vector2i(1280, 720), Vector2i(1920, 1080), Vector2i(2560, 1440)]:
		root.size = viewport
		for event_id: String in art.event_art:
			var event: Dictionary = events[event_id]
			if event.has("choices"):
				main.story = {}
				main.session.pending_event = {"id": event_id, "day": 0}
			else:
				main.session.pending_event = {}
				main.story = {"event": event_id, "title": event.title, "text": event.get("chronicle", ""), "mark": 0}
			main.render()
			await process_frame
			check(main.backdrop.visible and main.backdrop.texture != null and main.backdrop.texture.resource_path == art.event_art[event_id], event_id + " displays in " + str(viewport))
		main.story = {}
		main.session.pending_event = {}
		main.session.ended = {"kind": "ascension", "day": 0}
		main.render()
		await process_frame
		check(main.backdrop.visible and main.backdrop.texture.resource_path == ArtLibrary.event_art("ascension_opens"), "ascension ending displays its illustration in " + str(viewport))
		main.session.ended = {"kind": "lifespan", "day": 0}
		main.render()
		check(main._telling_art().is_empty() and not main.backdrop.visible, "other endings do not inherit the ascension picture")
		main.session.ended = {}
	for person_id: String in art.portrait_art:
		var portrait := PeopleView._portrait(main, person_id, main.session.person(person_id))
		check(portrait is TextureRect and portrait.texture.resource_path == art.portrait_art[person_id], person_id + " uses the dedicated portrait ahead of the old pool copy")
		portrait.free()
	var custom_root := isolated + "/custom_portraits"
	DirAccess.make_dir_recursive_absolute(ProjectSettings.globalize_path(custom_root))
	var face := Image.create(16, 20, false, Image.FORMAT_RGB8)
	face.save_png(custom_root.path_join("xu_qinghe.png"))
	main.portrait_root = custom_root
	var custom := PeopleView._portrait(main, "xu_qinghe", main.session.person("xu_qinghe"))
	check(custom is TextureRect and custom.texture.get_width() == 16, "a custom portrait still overrides the curated core portrait")
	custom.free()
	main.story = {}
	main.session.pending_event = {}
	main.view = "place"
	main.world_view = "place"
	for location_id: String in content.locations:
		main.session.player.location = location_id
		main.render()
		check(main.backdrop.texture.resource_path == ArtLibrary.fullscreen_location_path(location_id), location_id + " full-screen art reaches the place view")
	check(main.window_style is StyleBoxTexture and main.window_style.get_minimum_size().y <= 80, "painted frame does not impose image-sized minimums, only room for its border")
	main.queue_free()
	await process_frame
	_icons()
	_new_art_sources()
	await _painted_actors()
	print("ART: %d checks, %d failures" % [checks, failures])
	quit(0 if failures == 0 else 1)

## Every technique and 宝物 has a composed icon (art_library.gd): each archetype in each element and tier,
## each sect's handwritten art, each base in each tier and element, a 玉简; the parts are the vector art in
## assets/art/icons. The same kind shares one texture.
func _icons() -> void:
	var game := Session.new()
	game.new_game("图标", 5, ["metal", "wood", "fire"])
	var content = game.content
	var missing: Array[String] = []
	for archetype: String in content.technique_data.archetypes:
		for element: String in content.technique_data.elements:
			for tier: int in range(1, content.technique_data.tiers.size() + 1):
				var t: Dictionary = content.technique("t:%s:%s:%d::0" % [archetype, element, tier])
				if ArtLibrary.technique_icon(t) == null:
					missing.append(t.id)
	for skill_id: String in content.skills:
		if ArtLibrary.technique_icon(content.technique(skill_id)) == null:
			missing.append(skill_id)
	for base: String in content.equipment_data.bases:
		for tier: int in range(1, content.equipment_data.tiers.size() + 1):
			for element: String in ["none"] + content.technique_data.elements.keys():
				var gear: Dictionary = content.equipment(game.Arsenal.equipment_id(base, tier, element, [], 0))
				if ArtLibrary.gear_icon(gear) == null:
					missing.append(gear.id)
	check(missing.is_empty(), "every technique and 宝物 has its icon (missing %s)" % str(missing.slice(0, 5)))
	var goods: Array = content.items.keys().filter(func(item_id: String) -> bool: return ArtLibrary.item_icon(content, content.item(item_id)) == null)
	check(goods.is_empty(), "every catalogue item has its icon (missing %s)" % str(goods.slice(0, 5)))
	check(ArtLibrary.item_icon_path(content.item("foundation_pill")).is_empty() and content.item("foundation_pill").get("id") == "foundation_pill", "a catalogue item knows its id, so painted art could replace its icon")
	var icon := ArtLibrary.technique_icon(content.technique("t:bolt:fire:2::0"))
	check(icon != null and icon.get_width() == 128 and icon == ArtLibrary.technique_icon(content.technique("t:bolt:fire:2:burn:3")), "an icon is 128 pixels and shared by techniques of one kind, element and tier")
	check(ArtLibrary.technique_kind(content.technique("sword_rain")) == "barrage" and ArtLibrary.technique_kind(content.technique("wood")) == "mend", "a sect's art is drawn by what it does")
	var slip: Dictionary = content.item("j:t:ward:earth:3::0")
	check(ArtLibrary.item_icon(content, slip) != null and ArtLibrary.item_icon(content, slip) != ArtLibrary.technique_icon(content.technique("t:ward:earth:3::0")), "a 玉简 shows the art it teaches with a slip over it")

## Source alpha and frame bounds catch cropped silhouettes even with the headless dummy renderer.
func _new_art_sources() -> void:
	var batch: Dictionary = JSON.parse_string(FileAccess.get_file_as_string("res://docs/ART_BATCH_20261017.json"))
	check(batch.jobs.size() == 48, "the approved batch contains 48 distinct art targets")
	for job: Dictionary in batch.jobs:
		var path := "res://" + str(job.target)
		check(ArtLibrary.texture(path) != null, str(job.id) + " is imported and loadable")
		if job.get("transparent_background", false):
			var source := Image.load_from_file(ProjectSettings.globalize_path(path))
			check(source.detect_alpha() != Image.ALPHA_NONE and source.get_pixel(0, 0).a < 0.01 and source.get_pixel(source.get_width() - 1, source.get_height() - 1).a < 0.01, str(job.id) + " has real transparent corners")
	var map := ArtLibrary.texture(ArtLibrary.map_path("tiannan"))
	check(map != null and absf(float(map.get_width()) / map.get_height() - 1.6) < 0.02, "Tiannan map matches the region aspect")
	var rite = load("res://scripts/presentation/rite.gd").new()
	root.add_child(rite)
	check(rite.figure.texture.resource_path == ArtLibrary.ui_art("rite_meditation") and rite.figure.region == Rect2(Vector2.ZERO, rite.figure.texture.get_size()), "retreat and breakthrough use the complete seated hero")
	check(rite.furnace_texture != null and rite.furnace_texture.resource_path == ArtLibrary.ui_art("rite_furnace"), "alchemy selects the painted furnace")
	rite.queue_free()

func _painted_actors() -> void:
	var game := Session.new()
	game.new_game("图集检查", 42, ["metal", "wood", "fire"])
	game.encounters_enabled = false
	game.start_battle("disciple")
	check(not game.battle.is_empty(), "presentation fixture has a battle snapshot")
	if game.battle.is_empty():
		return
	var Stage = load("res://scripts/presentation/battle_stage.gd")
	for place: String in ["nanming", "chifeng", "chixiao_gate", "changqing_valley", "canglan_pavilion", "xuanyue_gate"]:
		var snapshot: Dictionary = game.snapshot()
		snapshot.battle.place = place
		var stage = Stage.new()
		root.add_child(stage)
		stage.configure(snapshot, game.content.enemies.disciple)
		check(stage.background.resource_path == "res://assets/art/battle/%s.png" % place, place + " selects its dedicated battle background")
		stage.queue_free()
		await process_frame
	for enemy_id: String in ["huo_xi", "bear_king", "wolf_pack", "shan_xiao", "huo_ya", "qinglin_snake", "chilian_snake", "yanjia_xi", "chixiao_zhifa", "tribulation_core", "tribulation_nascent", "tribulation_deity"]:
		var definition: Dictionary = ArtLibrary._config().actors[enemy_id]
		var snapshot: Dictionary = game.snapshot()
		snapshot.battle.enemy_id = enemy_id
		var stage = Stage.new()
		root.add_child(stage)
		stage.configure(snapshot, game.content.enemies[enemy_id])
		check(stage.enemy.sprite.texture.resource_path == definition.preferred and stage.enemy_art == ArtLibrary.actor_definition(enemy_id), enemy_id + " uses the same preferred atlas in both consumers")
		check(not stage.enemy.sprite.flip_h, enemy_id + " faces toward the hero")
		var source := Image.load_from_file(ProjectSettings.globalize_path(str(definition.preferred)))
		for pose: String in ["idle", "prepare", "attack", "cast", "hit", "guard"]:
			stage.enemy.set_pose(pose)
			var frame := ArtLibrary.actor_frame(enemy_id, pose)
			var region: Rect2i = Rect2i(frame.region)
			check(Rect2i(Vector2i.ZERO, source.get_size()).encloses(region), enemy_id + "/" + pose + " stays inside the source image")
			check(_clear_frame_edge(source, region), enemy_id + "/" + pose + " does not cut an opaque silhouette")
			if stage.enemy.sprite.region_enabled:
				check(stage.enemy.sprite.region_rect == frame.region, enemy_id + "/" + pose + " shares its precise region with the library")
			else:
				check(stage.enemy.sprite.frame == stage.enemy_art.frames[pose], enemy_id + "/" + pose + " selects its registered cell")
		var fallback := ArtLibrary.selected_actor(definition, str(definition.texture))
		check(fallback.frames == definition.frames and fallback.get("frame_regions", []) == definition.get("frame_regions", []) and fallback.get("tint", "") == definition.get("tint", ""), enemy_id + " fallback retains its own registration and tint")
		stage.art.actors[enemy_id].preferred = "res://assets/art/missing_batch_actor.png"
		check(stage._enemy_art(enemy_id, {}).texture == definition.texture and stage._enemy_art(enemy_id, {}).frames == definition.frames, enemy_id + " selects a valid fallback if its preferred art is absent")
		stage.queue_free()
		await process_frame

func _clear_frame_edge(source: Image, region: Rect2i) -> bool:
	for x: int in range(region.position.x, region.end.x):
		if source.get_pixel(x, region.position.y).a > 0.75 or source.get_pixel(x, region.end.y - 1).a > 0.75:
			return false
	for y: int in range(region.position.y, region.end.y):
		if source.get_pixel(region.position.x, y).a > 0.75 or source.get_pixel(region.end.x - 1, y).a > 0.75:
			return false
	return true
