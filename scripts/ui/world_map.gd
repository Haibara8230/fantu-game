extends Control
## Node map of the region. Routes, nodes and labels are drawn in code on top of either the painted
## background (when the art file exists) or a code-drawn ink placeholder.
signal location_selected(location_id: String)
const ArtLibrary = preload("res://scripts/ui/art_library.gd")
const INK := Color("#e3e8dc")
const GOLD := Color("#d5b777")
const MUTED := Color("#97aaa4")
const DANGER := Color("#c9785f")
const NODE_RADIUS := 15.0
var content
var flags: Dictionary = {}
var current := ""
var selected := ""
var journey_to := ""
var preview_path: Array[String] = []
# Acquaintances by location: location id -> names. Only people the player knows are shown.
var people_at: Dictionary = {}
var background: Texture2D
var font := SystemFont.new()

func _ready() -> void:
	font.font_names = PackedStringArray(["Microsoft YaHei", "Noto Sans CJK SC", "SimHei"])
	mouse_filter = Control.MOUSE_FILTER_STOP
	resized.connect(queue_redraw)
	background = ArtLibrary.texture(ArtLibrary.map_path())

func configure(source_content, world_flags: Dictionary, here: String, target: String, path: Array[String], journey: String, known_people: Dictionary = {}) -> void:
	people_at = known_people
	content = source_content
	flags = world_flags
	current = here
	selected = target
	preview_path = path
	journey_to = journey
	queue_redraw()

## The drawing area keeps the configured aspect ratio inside the control.
func map_rect() -> Rect2:
	var aspect := float(content.map.aspect) if content != null else 1.6
	var width := minf(size.x, size.y * aspect)
	var height := width / aspect
	return Rect2((size - Vector2(width, height)) * 0.5, Vector2(width, height))

func node_position(location_id: String) -> Vector2:
	var rect := map_rect()
	var point: Array = content.locations[location_id].map
	return rect.position + Vector2(float(point[0]) * rect.size.x, float(point[1]) * rect.size.y)

func visible_ids() -> Array[String]:
	var ids: Array[String] = []
	for location_id: String in content.locations:
		if content.location_visible(location_id, flags):
			ids.append(location_id)
	return ids

func location_at(point: Vector2) -> String:
	for location_id: String in visible_ids():
		if node_position(location_id).distance_to(point) <= NODE_RADIUS * 1.8:
			return location_id
	return ""

func _gui_input(event: InputEvent) -> void:
	if event is InputEventMouseButton and event.pressed and event.button_index == MOUSE_BUTTON_LEFT:
		var hit := location_at(event.position)
		if not hit.is_empty():
			location_selected.emit(hit)
			accept_event()

func _draw() -> void:
	if content == null:
		return
	var rect := map_rect()
	if background != null:
		draw_texture_rect(background, rect, false)
	else:
		_draw_placeholder(rect)
	_draw_routes()
	_draw_nodes()
	draw_string(font, rect.position + Vector2(16, 30), str(content.map.name), HORIZONTAL_ALIGNMENT_LEFT, -1, 20, GOLD)

func _draw_placeholder(rect: Rect2) -> void:
	draw_rect(rect, Color("#13282d"))
	var w := rect.size.x
	var h := rect.size.y
	var o := rect.position
	# Distant ridges in layered ink washes.
	for layer: int in range(3):
		# A ridge line from left to right, closed along a base line below it.
		var points := PackedVector2Array()
		for step: int in range(13):
			var x := w * step / 12.0
			var y := h * (0.18 + layer * 0.06 + 0.07 * sin(step * 1.7 + layer * 2.1) + 0.04 * sin(step * 0.6 + layer))
			points.append(o + Vector2(x, y))
		var base := h * (0.46 + layer * 0.05)
		points.append(o + Vector2(w, base))
		points.append(o + Vector2(0, base))
		draw_colored_polygon(points, Color(0.17 + layer * 0.03, 0.29 + layer * 0.03, 0.3 + layer * 0.02, 0.55))
	# The Yunxi river winding past the ferry.
	var river := PackedVector2Array()
	for step: int in range(41):
		var t := step / 40.0
		river.append(o + Vector2(w * (0.52 + 0.14 * sin(t * 3.3) + 0.06 * t), h * t))
	draw_polyline(river, Color("#28525a"), maxf(10.0, w * 0.018), true)
	draw_polyline(river, Color("#3c6d71"), maxf(3.0, w * 0.005), true)
	# Mountain marks near highland nodes.
	for location_id: String in visible_ids():
		var terrain: String = content.locations[location_id].terrain
		if terrain in ["mountain", "ridge", "valley", "ruin"]:
			var base := node_position(location_id)
			for index: int in range(3):
				var peak := base + Vector2(-34 + index * 26, -26 - (index % 2) * 10)
				draw_colored_polygon(PackedVector2Array([peak + Vector2(-22, 26), peak, peak + Vector2(22, 26)]), Color(0.24, 0.39, 0.38, 0.65))
	draw_rect(rect, Color("#41615e"), false, 2.0)

func _on_preview(a: String, b: String) -> bool:
	for index: int in range(1, preview_path.size()):
		if (preview_path[index - 1] == a and preview_path[index] == b) or (preview_path[index - 1] == b and preview_path[index] == a):
			return true
	return false

func _draw_routes() -> void:
	for route: Dictionary in content.routes:
		var a: String = route.between[0]
		var b: String = route.between[1]
		if not content.location_visible(a, flags) or not content.location_visible(b, flags):
			continue
		var from := node_position(a)
		var to := node_position(b)
		var highlighted := _on_preview(a, b)
		var color := GOLD if highlighted else Color(0.72, 0.8, 0.76, 0.45)
		draw_dashed_line(from, to, color, 3.0 if highlighted else 2.0, 9.0)
		var middle := (from + to) * 0.5
		var label := "%d 日" % int(route.days)
		draw_string(font, middle + Vector2(-16, -6), label, HORIZONTAL_ALIGNMENT_LEFT, -1, 13, GOLD if highlighted else MUTED)
		for mark: int in range(int(route.danger)):
			draw_circle(middle + Vector2(-8 + mark * 8, 8), 3.0, DANGER)

func _draw_nodes() -> void:
	for location_id: String in visible_ids():
		var center := node_position(location_id)
		var definition: Dictionary = content.locations[location_id]
		var is_current := location_id == current
		var is_selected := location_id == selected
		if is_current:
			draw_circle(center, NODE_RADIUS + 9, Color(0.84, 0.72, 0.47, 0.22))
		draw_circle(center, NODE_RADIUS, Color("#1b3236"))
		draw_arc(center, NODE_RADIUS, 0, TAU, 32, GOLD if is_current or is_selected else INK, 3.0 if is_selected else 2.0, true)
		if location_id == journey_to:
			draw_arc(center, NODE_RADIUS + 5, 0, TAU, 32, DANGER, 2.0, true)
		draw_circle(center, 4.5, GOLD if is_current else MUTED)
		draw_string(font, center + Vector2(-NODE_RADIUS * 2, NODE_RADIUS + 20), definition.name, HORIZONTAL_ALIGNMENT_CENTER, NODE_RADIUS * 4, 15, GOLD if is_current or is_selected else INK)
		if people_at.has(location_id):
			var names: Array = people_at[location_id]
			var line := "、".join(names.slice(0, 2)) + (" 等%d人" % names.size() if names.size() > 2 else "")
			draw_string(font, center + Vector2(-NODE_RADIUS * 4, NODE_RADIUS + 38), line, HORIZONTAL_ALIGNMENT_CENTER, NODE_RADIUS * 8, 12, MUTED)
