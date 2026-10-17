extends SceneTree
## Resource coverage plus the actual event/portrait/background consumers, without player saves.
const ArtLibrary = preload("res://scripts/ui/art_library.gd")
const Session = preload("res://scripts/core/session.gd")
const PeopleView = preload("res://scripts/ui/people_view.gd")
const SaveStore = preload("res://scripts/core/save_store.gd")
var checks := 0
var failures := 0
# Spots whose picture is still to be drawn (docs/BACKLOG.md, 尚缺的素材); their window falls back to the
# location's picture until then.
const PENDING_SPOTS := ["ruin/depths", "wild/chenxia", "sect/gate", "ferry/crossing", "town/palisade"]
# Places of a new region whose pictures are still to be drawn (docs/BACKLOG.md): the place view shows
# the code-drawn landscape until then.
const PENDING_LOCATIONS := ["nanming", "chifeng", "chixiao_gate", "changqing_valley", "canglan_pavilion", "xuanyue_gate"]

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
	_icons()
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
	var icon := ArtLibrary.technique_icon(content.technique("t:bolt:fire:2::0"))
	check(icon != null and icon.get_width() == 128 and icon == ArtLibrary.technique_icon(content.technique("t:bolt:fire:2:burn:3")), "an icon is 128 pixels and shared by techniques of one kind, element and tier")
	check(ArtLibrary.technique_kind(content.technique("sword_rain")) == "barrage" and ArtLibrary.technique_kind(content.technique("wood")) == "mend", "a sect's art is drawn by what it does")
	var slip: Dictionary = content.item("j:t:ward:earth:3::0")
	check(ArtLibrary.item_icon(content, slip) != null and ArtLibrary.item_icon(content, slip) != ArtLibrary.technique_icon(content.technique("t:ward:earth:3::0")), "a 玉简 shows the art it teaches with a slip over it")
