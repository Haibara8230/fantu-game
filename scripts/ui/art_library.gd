extends RefCounted
## Where painted art is expected. Anything missing falls back to code-drawn placeholders,
## so art can be dropped in later without code changes (see docs/ART_ASSETS.md).
const ROOT := "res://assets/art/"

static func map_path(region: String = "qingyun") -> String:
	return ROOT + "map/region_%s.png" % region

static func location_path(location_id: String) -> String:
	return ROOT + "locations/%s.png" % location_id

## Full-screen compositions stay separate from spot-window banners.
static func fullscreen_location_path(location_id: String) -> String:
	var path := ROOT + "locations/%s_fullscreen.png" % location_id
	return path if ResourceLoader.exists(path) else location_path(location_id)

static func scene_path(location_id: String, spot_id: String) -> String:
	return ROOT + "scenes/%s_%s.png" % [location_id, spot_id]

## The imported texture at `path`, or null when that art has not been added yet.
static func texture(path: String) -> Texture2D:
	if not ResourceLoader.exists(path):
		return null
	return load(path) as Texture2D

## The vector art drawn for the interface (assets/art/ui/*.svg): status badges, qi orbs, grade badges, map
## markers, the seal, the paper tag and the divider. `name` is the path under ui/ without ".svg".
static func ui_icon(name: String) -> Texture2D:
	return texture(ROOT + "ui/%s.svg" % name)

## A small picture for a control: the art at `name`, shown `side` pixels square, smoothed as it shrinks.
static func icon_rect(name: String, side: float) -> TextureRect:
	var rect := TextureRect.new()
	rect.texture = ui_icon(name)
	rect.custom_minimum_size = Vector2(side, side)
	rect.expand_mode = TextureRect.EXPAND_IGNORE_SIZE
	rect.stretch_mode = TextureRect.STRETCH_KEEP_ASPECT_CENTERED
	rect.texture_filter = CanvasItem.TEXTURE_FILTER_LINEAR_WITH_MIPMAPS
	rect.mouse_filter = Control.MOUSE_FILTER_PASS
	return rect

## An item's picture (docs/WORLD_EXPANSION.md 2.8): data/art.json `item_art` if it names one, else the
## item's own file, else a picture shared by its kind (gear by base, slips by the art they teach, then the
## category). "" until any of them is drawn; lists then show the name alone.
static func item_icon_path(item: Dictionary, include_category: bool = true) -> String:
	var id := str(item.get("id", ""))
	var candidates: Array[String] = []
	var mapped := str(_config().get("item_art", {}).get(id, ""))
	if not mapped.is_empty():
		candidates.append(mapped)
	candidates.append(ROOT + "items/%s.png" % id.replace(":", "_"))
	if id.begins_with("e:"):
		candidates.append(ROOT + "items/gear_%s.png" % id.get_slice(":", 1))
	if id.begins_with("j:"):
		candidates.append(ROOT + "items/manual_%s.png" % id.get_slice(":", 2))
	if include_category:
		candidates.append(ROOT + "items/category_%s.png" % str(item.get("category", "")))
	for path: String in candidates:
		if ResourceLoader.exists(path):
			return path
	return ""

# --- Technique and treasure icons, composed from vector parts (assets/art/icons) ---------------------
# Each icon stacks three 64x64 SVG parts — a back by element, a subject, a frame by grade (白绿蓝紫橙红)
# — after the square, framed icons of 觅长生 and 鬼谷八荒. The parts' text is joined into one SVG and
# rasterized once per kind (Image.load_svg_from_string), so it works headless and needs no texture
# import; an exported build must include the *.svg files (export filter). The parts are written by
# tools/art/make_item_icons.py (the other UI art by tools/art/make_ui_art.py).
const ICONS := "res://assets/art/icons/"
const ICON_SCALE := 2.0
static var _icon_cache := {}
static var _part_cache := {}

## What a technique's icon shows: its archetype (法术, 连击, 重击, 疗愈, 护体; 吐纳, 炼体, 凝神, 元气). A sect's
## handwritten art is read by what it does.
static func technique_kind(t: Dictionary) -> String:
	if t.has("archetype"):
		return str(t.archetype)
	match str(t.get("kind", "")):
		"heal":
			return "mend"
		"guard":
			return "ward"
		# 印 and 聚气 turn and gather qi: the 凝神 figure.
		"spirit":
			return "focus"
	if int(t.get("hits", 1)) > 1:
		return "barrage"
	var orbs := 0
	for key: String in t.get("cost", {}):
		orbs += int(t.cost[key])
	return "burst" if orbs >= 3 else "bolt"

## A technique's icon: its element's back, its kind, the frame of its tier. null if the parts are missing.
static func technique_icon(t: Dictionary) -> Texture2D:
	if t.is_empty():
		return null
	var element := str(t.get("element", "metal"))
	var kind := technique_kind(t)
	var grade := clampi(int(t.get("tier", 1)) - 1, 0, 5)
	return _composed("t:%s:%s:%d" % [kind, element, grade], ["backs/" + element, "arts/%s_%s" % [kind, element], "frames/grade_%d" % grade])

## A 宝物's icon: its element's back (plain without one), its base in the tier's material, the tier's frame.
static func gear_icon(item: Dictionary) -> Texture2D:
	var id := str(item.get("id", ""))
	if not id.begins_with("e:"):
		return null
	var base := id.get_slice(":", 1)
	var tier := clampi(int(item.get("tier", 1)), 1, 5)
	var element := str(item.get("element", "none"))
	return _composed("e:%s:%d:%s" % [base, tier, element], ["backs/" + element, "gear/%s_%d" % [base, tier], "frames/grade_%d" % (tier - 1)])

## A 玉简's icon: the technique it teaches, with a jade slip in the corner.
static func manual_icon(content, item: Dictionary) -> Texture2D:
	var taught: Dictionary = content.technique(str(item.get("teaches", "")))
	if taught.is_empty():
		return null
	var element := str(taught.get("element", "metal"))
	var kind := technique_kind(taught)
	var grade := clampi(int(taught.get("tier", 1)) - 1, 0, 5)
	return _composed("j:%s:%s:%d" % [kind, element, grade], ["backs/" + element, "arts/%s_%s" % [kind, element], "frames/grade_%d" % grade, "slip"])

## A catalogue item's icon (data/items.json): its own drawing with its back, in the frame of its 品级.
## null for an item nobody drew yet.
static func goods_icon(content, item: Dictionary) -> Texture2D:
	var id := str(item.get("id", ""))
	if id.is_empty() or id.contains(":"):
		return null
	var grade: int = content.rarity_of(item)
	return _composed("i:%s:%d" % [id, grade], ["items/" + id, "frames/grade_%d" % grade])

## Any item's picture: its own painted art first, then a composed icon (宝物, 玉简, catalogue items), then
## the category's painted picture. null when none exists.
static func item_icon(content, item: Dictionary) -> Texture2D:
	var own := item_icon_path(item, false)
	if not own.is_empty():
		return texture(own)
	var composed: Texture2D = null
	match str(item.get("category", "")):
		"equipment":
			composed = gear_icon(item)
		"manual":
			composed = manual_icon(content, item)
		_:
			composed = goods_icon(content, item)
	if composed != null:
		return composed
	var shared := item_icon_path(item)
	return texture(shared) if not shared.is_empty() else null

static func _composed(key: String, parts: Array) -> Texture2D:
	if _icon_cache.has(key):
		return _icon_cache[key]
	var body := ""
	for part: String in parts:
		var inner := _part(part)
		if inner.is_empty():
			_icon_cache[key] = null
			return null
		body += inner
	var image := Image.new()
	if image.load_svg_from_string('<svg xmlns="http://www.w3.org/2000/svg" width="64" height="64" viewBox="0 0 64 64">%s</svg>' % body, ICON_SCALE) != OK:
		_icon_cache[key] = null
		return null
	image.generate_mipmaps()
	var made := ImageTexture.create_from_image(image)
	_icon_cache[key] = made
	return made

## A part's drawing: the SVG file's content between its <svg> tags, "" when missing.
static func _part(part: String) -> String:
	if _part_cache.has(part):
		return _part_cache[part]
	var path := ICONS + part + ".svg"
	var inner := ""
	if FileAccess.file_exists(path):
		var text := FileAccess.get_file_as_string(path)
		var start := text.find(">", text.find("<svg")) + 1
		inner = text.substr(start, text.rfind("</svg>") - start)
	_part_cache[part] = inner
	return inner

static func preferred_portrait_path(person_id: String) -> String:
	return str(_config().get("portrait_art", {}).get(person_id, ""))

## Only the known old pool copies yield to curated art; custom portrait files still win.
static func placeholder_portrait(person_id: String, path: String) -> bool:
	var digest := str(_config().get("portrait_placeholders", {}).get(person_id, ""))
	return not digest.is_empty() and not path.is_empty() and FileAccess.get_sha256(path) == digest

static func portrait_path(person_id: String) -> String:
	return ROOT + "portraits/%s.png" % person_id

# Story illustrations are named for their scene, not their event, so data/art.json maps them.
static var _art_config := {}

static func _config() -> Dictionary:
	if _art_config.is_empty():
		var parsed: Variant = JSON.parse_string(FileAccess.get_file_as_string("res://data/art.json"))
		_art_config = parsed if parsed is Dictionary else {"event_art": {}, "person_art": {}}
	return _art_config

## Apply an atlas-specific layout only when that preferred texture was actually selected.
## Borrowed fallbacks and generated sect looks retain their original frame registration.
static func selected_actor(definition: Dictionary, path: String) -> Dictionary:
	var selected := definition.duplicate(true)
	selected.texture = path
	if not path.is_empty() and path == str(definition.get("preferred", "")):
		for key: String in definition.get("preferred_layout", {}):
			var value: Variant = definition.preferred_layout[key]
			if value == null:
				selected.erase(key)
			else:
				selected[key] = value
	return selected

static func actor_definition(actor_id: String) -> Dictionary:
	var definition: Dictionary = _config().get("actors", {}).get(actor_id, {})
	var preferred := str(definition.get("preferred", ""))
	var path := preferred if not preferred.is_empty() and ResourceLoader.exists(preferred) else str(definition.get("texture", ""))
	return selected_actor(definition, path)

## One frame of a duel actor's atlas (data/art.json `actors`): {"texture", "region", "faces_right"}, or {}
## when the art is missing. The map's traveller is drawn with the hero's.
static func actor_frame(actor_id: String, frame: String) -> Dictionary:
	var definition := actor_definition(actor_id)
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

## Small painted decorations for the scrolls, kept in the art catalog.
static func ui_art(art_id: String) -> String:
	return str(_config().get("ui_art", {}).get(art_id, ""))

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
