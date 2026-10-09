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
