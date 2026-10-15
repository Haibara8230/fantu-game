extends SceneTree
## Resource coverage plus the actual event/portrait/background consumers, without player saves.
const ArtLibrary = preload("res://scripts/ui/art_library.gd")
const PeopleView = preload("res://scripts/ui/people_view.gd")
const SaveStore = preload("res://scripts/core/save_store.gd")
var checks := 0
var failures := 0
# Spots whose picture is still to be drawn (docs/BACKLOG.md, 尚缺的素材); their window falls back to the
# location's picture until then.
const PENDING_SPOTS := ["ruin/depths", "wild/chenxia", "sect/gate", "ferry/crossing"]
# Places of a new region whose pictures are still to be drawn (docs/BACKLOG.md): the place view shows
# the code-drawn landscape until then.
const PENDING_LOCATIONS := ["nanming", "chifeng", "chixiao_gate"]

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
	for location_id: String in content.locations:
		if location_id in PENDING_LOCATIONS:
			check(ArtLibrary.texture(ArtLibrary.fullscreen_location_path(location_id)) == null, location_id + " is still pending; remove it from PENDING_LOCATIONS once drawn")
			continue
		var fullscreen := ArtLibrary.texture(ArtLibrary.fullscreen_location_path(location_id))
		check(fullscreen != null and fullscreen.resource_path.ends_with("_fullscreen.png"), location_id + " has its full-screen composition")
		if fullscreen != null:
			check(absf(float(fullscreen.get_width()) / fullscreen.get_height() - 16.0 / 9.0) < 0.02, location_id + " is 16:9")
		for spot: Dictionary in content.locations[location_id].spots:
			var drawn: bool = ArtLibrary.texture(ArtLibrary.scene_path(location_id, spot.id)) != null
			if location_id + "/" + str(spot.id) in PENDING_SPOTS:
				check(not drawn and ArtLibrary.texture(ArtLibrary.location_path(location_id)) != null, location_id + "/" + str(spot.id) + " falls back to the location's picture until its own is drawn")
			else:
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
		if location_id in PENDING_LOCATIONS:
			continue
		main.session.player.location = location_id
		main.render()
		check(main.backdrop.texture.resource_path == ArtLibrary.fullscreen_location_path(location_id), location_id + " full-screen art reaches the place view")
	check(main.window_style is StyleBoxTexture and main.window_style.get_minimum_size().y <= 80, "painted frame does not impose image-sized minimums, only room for its border")
	main.queue_free()
	await process_frame
	print("ART: %d checks, %d failures" % [checks, failures])
	quit(0 if failures == 0 else 1)
