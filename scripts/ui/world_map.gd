extends Control
## Node map of one region (舆图分页: data/world.json `regions`). Routes, nodes and labels are drawn in code
## on top of either the painted background (when the art file exists) or a code-drawn ink placeholder;
## a road that leaves the region is drawn as a marked exit at the place it starts from. The player stands as a small
## figure (the hero's duel art) at the place they are; a journey is played back by walk(): the figure
## walks leg by leg along the route, stepping and turning toward where it goes, after 觅长生.
signal location_selected(location_id: String)
# Time to walk one leg on screen: per day of the road, within bounds.
const SECONDS_PER_DAY := 0.09
const LEG_SECONDS := Vector2(0.35, 1.2)
const ArtLibrary = preload("res://scripts/ui/art_library.gd")
const INK := Color("#e3e8dc")
const GOLD := Color("#d5b777")
const MUTED := Color("#97aaa4")
const DANGER := Color("#c9785f")
const NODE_RADIUS := 15.0
# The plate under a name or a road's days, so they read over any painted ground.
const PLATE := Color(0.04, 0.09, 0.1, 0.72)
var content
# Markers by terrain (assets/art/ui/map/*.svg), loaded once.
var _markers: Dictionary = {}
var _plate := StyleBoxFlat.new()
var flags: Dictionary = {}
var current := ""
var selected := ""
var journey_to := ""
var preview_path: Array[String] = []
# Acquaintances by location: location id -> names. Only people the player knows are shown.
var people_at: Dictionary = {}
var background: Texture2D
# The region shown, and the one whose background is loaded.
var region := ""
var _background_region := ""
var font := SystemFont.new()
# The traveller's point while a journey is played back (null when standing at `current`).
var traveller: Variant = null
# The figure: the hero's idle frame ({} without the art, then a seal is drawn), which way it faces
# (1 right, -1 left) and how far its steps have gone.
var figure: Dictionary = {}
var facing := 1.0
var stride := 0.0
# Riding a flying sword (御剑, from 金丹): the figure floats over a blade instead of walking.
var flying := false

func _ready() -> void:
	# The vector markers shrink smoothly (they are imported larger than drawn).
	texture_filter = CanvasItem.TEXTURE_FILTER_LINEAR_WITH_MIPMAPS
	font.font_names = PackedStringArray(["Microsoft YaHei", "Noto Sans CJK SC", "SimHei"])
	mouse_filter = Control.MOUSE_FILTER_STOP
	resized.connect(queue_redraw)
	figure = ArtLibrary.actor_frame("hero", "idle")

## `shown_region` is the region to draw (empty: the one the player is in).
func configure(source_content, world_flags: Dictionary, here: String, target: String, path: Array[String], journey: String, known_people: Dictionary = {}, shown_region: String = "") -> void:
	people_at = known_people
	content = source_content
	_show_region(shown_region if not shown_region.is_empty() else str(content.region_of(here)))
	flags = world_flags
	current = here
	selected = target
	preview_path = path
	journey_to = journey
	queue_redraw()

## The drawing area keeps the configured aspect ratio and covers the control (a wider screen crops a
## little off the top and bottom instead of leaving bars at the sides).
func _show_region(region_id: String) -> void:
	region = region_id
	if _background_region != region:
		_background_region = region
		background = ArtLibrary.texture(ArtLibrary.map_path(region))

func map_rect() -> Rect2:
	var aspect := 1.6
	if content != null:
		aspect = float(content.regions.get(region, content.map).get("aspect", content.map.aspect))
	var width := maxf(size.x, size.y * aspect)
	var height := width / aspect
	return Rect2((size - Vector2(width, height)) * 0.5, Vector2(width, height))

func node_position(location_id: String) -> Vector2:
	var rect := map_rect()
	var point: Array = content.locations[location_id].map
	return rect.position + Vector2(float(point[0]) * rect.size.x, float(point[1]) * rect.size.y)

func visible_ids() -> Array[String]:
	var ids: Array[String] = []
	for location_id: String in content.locations:
		if content.location_visible(location_id, flags) and content.region_of(location_id) == region:
			ids.append(location_id)
	return ids

func location_at(point: Vector2) -> String:
	for location_id: String in visible_ids():
		if node_position(location_id).distance_to(point) <= NODE_RADIUS * 1.8:
			return location_id
	return ""

## Seconds the leg of `days` days takes on screen.
static func leg_seconds(days: int) -> float:
	return clampf(days * SECONDS_PER_DAY, LEG_SECONDS.x, LEG_SECONDS.y)

## Plays a journey back: from `start`, the mark walks to each leg's `to` in turn ({"to", "days"});
## `on_leg` is called with each leg's index and progress (0–1) so the date can move with it.
func walk(start: String, legs: Array[Dictionary], on_leg: Callable) -> void:
	var from := start
	for index: int in legs.size():
		var to: String = legs[index].to
		# A road out of the region (a 传送阵): the map turns to the other region, the time still passes.
		if content.region_of(to) != content.region_of(from):
			traveller = null
			current = to
			from = to
			_show_region(str(content.region_of(to)))
			queue_redraw()
			var crossing := create_tween()
			crossing.tween_method(func(progress: float) -> void: on_leg.call(index, progress), 0.0, 1.0, leg_seconds(int(legs[index].days)))
			await crossing.finished
			continue
		var a := node_position(from)
		var b := node_position(to)
		if absf(b.x - a.x) > 1.0:
			facing = 1.0 if b.x > a.x else -1.0
		var steps := float(maxi(2, int(legs[index].days) * 2))
		flying = bool(legs[index].get("fly", false))
		var tween := create_tween()
		var seconds := leg_seconds(int(legs[index].days)) * (0.7 if flying else 1.0)
		tween.tween_method(func(progress: float) -> void:
			traveller = a.lerp(b, progress)
			stride = progress * steps
			on_leg.call(index, progress)
			queue_redraw(), 0.0, 1.0, seconds)
		await tween.finished
		current = to
		from = to
	traveller = null
	stride = 0.0
	flying = false
	queue_redraw()

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
	if traveller is Vector2:
		_draw_traveller(traveller, true)
	elif not current.is_empty() and content.locations.has(current) and content.region_of(current) == region:
		_draw_traveller(node_position(current) + Vector2(-NODE_RADIUS * 2.8, -NODE_RADIUS * 0.6), false)
	# The region's name at the top centre, clear of the HUD's corners.
	var title := str(content.regions.get(region, content.map).get("name", content.map.name))
	var width := font.get_string_size(title, HORIZONTAL_ALIGNMENT_LEFT, -1, 20).x
	draw_string(font, Vector2(rect.position.x + (rect.size.x - width) * 0.5, rect.position.y + 30), title, HORIZONTAL_ALIGNMENT_LEFT, -1, 20, GOLD)

## The player at `point` (their feet): the hero's figure with a shadow, bobbing with each step while
## `walking`; a small gold seal when the art is missing.
func _draw_traveller(point: Vector2, walking: bool) -> void:
	if not figure.is_empty():
		var height := clampf(map_rect().size.y * 0.1, 44.0, 96.0)
		var region: Rect2 = figure.region
		var width := height * region.size.x / region.size.y
		var lift := absf(sin(stride * PI)) * height * 0.06 if walking else 0.0
		var sway := sin(stride * PI) * 0.06 if walking else 0.0
		if walking and flying:
			# Aloft on the blade: steady, high above a fainter shadow, a streak of light behind.
			lift = height * 0.3 + sin(stride * 0.8) * height * 0.02
			sway = 0.0
			var blade := point + Vector2(0, -lift + 2)
			draw_line(blade + Vector2(-width * 0.55 * facing, 0), blade + Vector2(width * 0.55 * facing, 0), Color("#e8e2c4"), 3.0, true)
			draw_line(blade - Vector2(width * 0.6 * facing, 0), blade - Vector2(width * 2.2 * facing, -2), Color(0.91, 0.87, 0.7, 0.35), 2.0, true)
		draw_set_transform(point, 0.0, Vector2(1.0, 0.35))
		draw_circle(Vector2.ZERO, width * (0.22 if walking and flying else 0.32), Color(0, 0, 0, 0.18 if walking and flying else 0.3))
		var flip := facing * (1.0 if figure.faces_right else -1.0)
		draw_set_transform(point + Vector2(0, -lift), sway * facing, Vector2(flip, 1.0))
		draw_texture_rect_region(figure.texture, Rect2(-width * 0.5, -height, width, height), region)
		draw_set_transform(Vector2.ZERO, 0.0, Vector2.ONE)
		return
	draw_circle(point + Vector2(0, 3), 11.0, Color(0, 0, 0, 0.35))
	draw_circle(point, 10.0, GOLD)
	draw_arc(point, 10.0, 0, TAU, 24, Color("#1b3236"), 2.5, true)
	draw_circle(point, 3.5, Color("#1b3236"))

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
		var inside_a: bool = content.region_of(a) == region
		var inside_b: bool = content.region_of(b) == region
		if not inside_a and not inside_b:
			continue
		if inside_a != inside_b:
			_draw_exit(route, a if inside_a else b, b if inside_a else a)
			continue
		var from := node_position(a)
		var to := node_position(b)
		var highlighted := _on_preview(a, b)
		var color := GOLD if highlighted else Color(0.72, 0.8, 0.76, 0.45)
		draw_dashed_line(from, to, color, 3.0 if highlighted else 2.0, 9.0)
		var middle := (from + to) * 0.5
		var label := "%d 日" % int(route.days)
		# A plate holds the days, large enough to read over the painting, and the danger marks under them.
		var width := font.get_string_size(label, HORIZONTAL_ALIGNMENT_LEFT, -1, 17).x
		var plate_width := maxf(width, 8.0 * int(route.danger)) + 12.0
		_draw_plate(Rect2(middle + Vector2(-plate_width * 0.5, -24), Vector2(plate_width, 24 + (10 if int(route.danger) > 0 else 0))), highlighted)
		draw_string(font, middle + Vector2(-width * 0.5, -6), label, HORIZONTAL_ALIGNMENT_LEFT, -1, 17, GOLD if highlighted else INK)
		for mark: int in range(int(route.danger)):
			draw_circle(middle + Vector2(-(int(route.danger) - 1) * 4.0 + mark * 8.0, 4.0), 3.0, DANGER)

## A road out of the region, at the place it leaves from: an arrow off the map and where it goes.
func _draw_exit(route: Dictionary, here: String, there: String) -> void:
	var at := node_position(here)
	var highlighted := _on_preview(here, there)
	var color := GOLD if highlighted else Color(0.72, 0.8, 0.76, 0.75)
	# The arrow points away from the middle of the map, toward the edge the road leaves by.
	var away := (at - map_rect().get_center()).normalized()
	if away.is_zero_approx():
		away = Vector2.RIGHT
	var tip := at + away * NODE_RADIUS * 3.4
	draw_dashed_line(at, tip, color, 3.0 if highlighted else 2.0, 6.0)
	var side := away.orthogonal()
	draw_colored_polygon(PackedVector2Array([tip + away * 7.0, tip + side * 5.0, tip - side * 5.0]), color)
	# Kept short over the painted map; the days and the fee are in the route's window once a place is picked.
	var words := "%s往%s" % [str(route.get("by", "")), content.regions.get(content.region_of(there), {}).get("name", content.locations[there].name)]
	# Words run on from the arrow, or end at it when they would leave the screen on that side.
	var width := font.get_string_size(words, HORIZONTAL_ALIGNMENT_LEFT, -1, 13).x
	var left := tip.x + 10.0 if away.x >= 0.0 else tip.x - 10.0 - width
	if left + width > size.x - 8.0:
		left = tip.x - 10.0 - width
	elif left < 8.0:
		left = tip.x + 10.0
	draw_string(font, Vector2(left, tip.y + (16.0 if away.y > 0.3 else -6.0)), words, HORIZONTAL_ALIGNMENT_LEFT, -1, 13, GOLD if highlighted else INK)

## A dark rounded plate under words drawn over the map; gold-edged on the route being previewed.
func _draw_plate(rect: Rect2, highlighted: bool = false) -> void:
	_plate.bg_color = PLATE
	_plate.set_corner_radius_all(5)
	_plate.set_border_width_all(1 if highlighted else 0)
	_plate.border_color = GOLD
	draw_style_box(_plate, rect)

## A place's marker by its terrain (宗门, town, ferry, market, ridge, valley, cave), null without the art.
func _marker(location_id: String) -> Texture2D:
	var terrain := str(content.locations[location_id].get("terrain", ""))
	if not _markers.has(terrain):
		_markers[terrain] = ArtLibrary.ui_icon("map/" + terrain)
	return _markers[terrain]

func _draw_nodes() -> void:
	for location_id: String in visible_ids():
		var center := node_position(location_id)
		var definition: Dictionary = content.locations[location_id]
		var is_current := location_id == current
		var is_selected := location_id == selected
		if is_current:
			draw_circle(center, NODE_RADIUS + 13, Color(0.84, 0.72, 0.47, 0.22))
		var marker := _marker(location_id)
		if marker != null:
			# The token is drawn a little larger than the old dot: its sign must read at a glance.
			var side := NODE_RADIUS * 3.2
			draw_texture_rect(marker, Rect2(center - Vector2(side, side) * 0.5, Vector2(side, side)), false)
			if is_current or is_selected:
				draw_arc(center, side * 0.5 + 2.0, 0, TAU, 40, GOLD, 3.0 if is_selected else 2.0, true)
		else:
			draw_circle(center, NODE_RADIUS, Color("#1b3236"))
			draw_arc(center, NODE_RADIUS, 0, TAU, 32, GOLD if is_current or is_selected else INK, 3.0 if is_selected else 2.0, true)
		if content.location_sealed(location_id, flags):
			draw_line(center + Vector2(-NODE_RADIUS, -NODE_RADIUS), center + Vector2(NODE_RADIUS, NODE_RADIUS), DANGER, 3.0)
			draw_line(center + Vector2(-NODE_RADIUS, NODE_RADIUS), center + Vector2(NODE_RADIUS, -NODE_RADIUS), DANGER, 3.0)
		if location_id == journey_to:
			draw_arc(center, NODE_RADIUS * 1.6 + 5, 0, TAU, 40, DANGER, 2.0, true)
		if marker == null:
			draw_circle(center, 4.5, GOLD if is_current else MUTED)
		# The name on its plate under the marker, large enough to read over the painting.
		var name_top := NODE_RADIUS * 1.6 + 2.0
		var name_width := font.get_string_size(str(definition.name), HORIZONTAL_ALIGNMENT_LEFT, -1, 19).x
		_draw_plate(Rect2(center + Vector2(-name_width * 0.5 - 8, name_top), Vector2(name_width + 16, 27)), is_current or is_selected)
		draw_string(font, center + Vector2(-name_width * 0.5, name_top + 21), definition.name, HORIZONTAL_ALIGNMENT_LEFT, -1, 19, GOLD if is_current or is_selected else INK)
		if people_at.has(location_id):
			var names: Array = people_at[location_id]
			var line := "、".join(names.slice(0, 2)) + (" 等%d人" % names.size() if names.size() > 2 else "")
			var line_width := font.get_string_size(line, HORIZONTAL_ALIGNMENT_LEFT, -1, 12).x
			_draw_plate(Rect2(center + Vector2(-line_width * 0.5 - 5, name_top + 30), Vector2(line_width + 10, 17)))
			draw_string(font, center + Vector2(-line_width * 0.5, name_top + 43), line, HORIZONTAL_ALIGNMENT_LEFT, -1, 12, INK)
