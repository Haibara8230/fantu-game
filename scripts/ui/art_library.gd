extends RefCounted
## Where painted art is expected. Anything missing falls back to code-drawn placeholders,
## so art can be dropped in later without code changes (see docs/ART_ASSETS.md).
const ROOT := "res://assets/art/"

static func map_path() -> String:
	return ROOT + "map/region_qingyun.png"

static func location_path(location_id: String) -> String:
	return ROOT + "locations/%s.png" % location_id

static func scene_path(location_id: String, spot_id: String) -> String:
	return ROOT + "scenes/%s_%s.png" % [location_id, spot_id]

## The imported texture at `path`, or null when that art has not been added yet.
static func texture(path: String) -> Texture2D:
	if not ResourceLoader.exists(path):
		return null
	return load(path) as Texture2D

static func portrait_path(person_id: String) -> String:
	return ROOT + "portraits/%s.png" % person_id

# Story illustrations are named for their scene, not their event, so data/art.json maps them.
static var _art_config := {}

static func _config() -> Dictionary:
	if _art_config.is_empty():
		var parsed: Variant = JSON.parse_string(FileAccess.get_file_as_string("res://data/art.json"))
		_art_config = parsed if parsed is Dictionary else {"event_art": {}, "person_art": {}}
	return _art_config

## One frame of a duel actor's atlas (data/art.json `actors`): {"texture", "region", "faces_right"}, or {}
## when the art is missing. The map's traveller is drawn with the hero's.
static func actor_frame(actor_id: String, frame: String) -> Dictionary:
	var definition: Dictionary = _config().get("actors", {}).get(actor_id, {})
	var sheet := texture(str(definition.get("texture", "")))
	if sheet == null:
		return {}
	var columns := int(definition.get("columns", 1))
	var rows := int(definition.get("rows", 1))
	var index := int(definition.get("frames", {}).get(frame, 0))
	var cell := Vector2(sheet.get_width() / float(columns), sheet.get_height() / float(rows))
	var region := Rect2(Vector2(index % columns, index / columns) * cell, cell)
	if definition.has("frame_regions") and index < definition.frame_regions.size():
		var r: Array = definition.frame_regions[index]
		region = Rect2(float(r[0]), float(r[1]), float(r[2]), float(r[3]))
	return {"texture": sheet, "region": region, "faces_right": bool(definition.get("faces_right", true))}

## The illustration of an event's key moment, or "" when it has none.
static func event_art(event_id: String) -> String:
	return str(_config().get("event_art", {}).get(event_id, ""))

## The illustration of the scene a person is met in (the storyteller on his stage), or "".
static func person_art(person_id: String) -> String:
	return str(_config().get("person_art", {}).get(person_id, ""))

# --- Local portrait pack (assets/local, committed with the project) -------------------
# Portrait images read straight from disk. The folder carries a .gdignore, so Godot does not import it;
# images are read straight from disk. Layout:
#   portraits/<person id>.png          replaces that person's portrait (":" written as "_", e.g. g_3.png)
#   portraits/pool/<gender>_<age>/*    pool for generated people; age is young, middle or old
#   portraits/pool/*                   pool images usable for anyone
# A file name starting with a role (disciple_, wanderer_, trader_, gatherer_, visitor_) is preferred
# for people of that role.
const LOCAL_PORTRAITS := "res://assets/local/portraits/"
const IMAGE_EXTENSIONS := ["png", "jpg", "jpeg", "webp"]
static var _local_cache := {}

## The image file for `base` (path without extension) if one exists, else "".
static func find_image(base: String) -> String:
	for extension: String in IMAGE_EXTENSIONS:
		if FileAccess.file_exists(base + "." + extension):
			return base + "." + extension
	return ""

static func local_texture(path: String) -> Texture2D:
	if path.is_empty():
		return null
	if _local_cache.has(path):
		return _local_cache[path]
	if not FileAccess.file_exists(path):
		return null
	var image := Image.load_from_file(ProjectSettings.globalize_path(path))
	if image == null or image.is_empty():
		return null
	var texture := ImageTexture.create_from_image(image)
	_local_cache[path] = texture
	return texture

## Pool images by group ("male_young", ..., or "any"), each list sorted for stable assignment.
static func pool_index(root: String) -> Dictionary:
	var groups := {}
	var pool := root.path_join("pool")
	if not DirAccess.dir_exists_absolute(ProjectSettings.globalize_path(pool)):
		return groups
	for folder: String in [""] + Array(DirAccess.get_directories_at(pool)):
		var directory := pool.path_join(folder) if not folder.is_empty() else pool
		var files: Array[String] = []
		for file_name: String in DirAccess.get_files_at(directory):
			if file_name.get_extension().to_lower() in IMAGE_EXTENSIONS:
				files.append(directory.path_join(file_name))
		files.sort()
		if not files.is_empty():
			groups["any" if folder.is_empty() else folder] = files
	return groups

static func age_band(age: int) -> String:
	return "young" if age < 35 else ("middle" if age < 55 else "old")

## A generated person's pool image: same gender and age band first, then same gender, then anything;
## images named for the person's role are preferred. A pure function of the person and the pool, so
## a person always keeps their face; with more people than images, faces repeat across people.
static func pick_portrait(person_id: String, person: Dictionary, world_seed: int, index: Dictionary) -> String:
	if index.is_empty() or person.is_empty():
		return ""
	var gender: String = person.get("gender", "male")
	var candidates: Array = index.get("%s_%s" % [gender, age_band(int(person.get("age", 30)))], [])
	if candidates.is_empty():
		for key: String in index:
			if key.begins_with(gender + "_"):
				candidates = candidates + index[key]
	if candidates.is_empty():
		for key: String in index:
			candidates = candidates + index[key]
	var role: String = str(person.get("kind", "")) + "_"
	var preferred := candidates.filter(func(path: String) -> bool: return path.get_file().begins_with(role))
	var choices: Array = preferred if not preferred.is_empty() else candidates
	return choices[absi(hash([world_seed, person_id])) % choices.size()]

## Pool images for several people at once (tools and tests).
static func assign_pool(people: Dictionary, world_seed: int, index: Dictionary) -> Dictionary:
	var assigned := {}
	for person_id: String in people:
		if people[person_id].get("generated", false):
			assigned[person_id] = pick_portrait(person_id, people[person_id], world_seed, index)
	return assigned
