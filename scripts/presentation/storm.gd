extends Control
## 天劫's sky over the duel stage, drawn in code: an overcast band rolling slowly under the health bars,
## soft banks of cloud with light flickering inside them now and then, and when a 天雷 falls a forked
## bolt from the clouds to its mark, a glow about its core, and a white flash. battle_stage.gd adds it for
## a tribulation, below the stage's corner panels; it clips to its own rect, so the bars stay clear.

const BOLT_LIFE := 0.5
const CLOUD_ROWS := 3
const CLOUDS_PER_ROW := 10
# The stage's health bars take the top; the sky begins under them.
const TOP := 56.0

var time := 0.0
var flash := 0.0
# Bolts in the air: {"trunk": PackedVector2Array, "branches": Array[PackedVector2Array], "age": float}.
var bolts: Array[Dictionary] = []
# Where a cloud lights up from within, and how bright it still is.
var glow_at := Vector2.ZERO
var glow := 0.0
var rng := RandomNumberGenerator.new()
# The overcast's fall from dark to clear, as one smooth gradient.
var overcast := GradientTexture2D.new()

func _ready() -> void:
	rng.seed = 2026
	var fall := Gradient.new()
	fall.set_color(0, Color(0.05, 0.06, 0.12, 0.68))
	fall.set_color(1, Color(0.05, 0.06, 0.12, 0.0))
	overcast.gradient = fall
	overcast.fill_from = Vector2(0.5, 0.0)
	overcast.fill_to = Vector2(0.5, 1.0)
	overcast.width = 8
	overcast.height = 128
	clip_contents = true
	mouse_filter = Control.MOUSE_FILTER_IGNORE

## Fits the sky to the stage: from under the health bars to the floor.
func fit(stage_size: Vector2) -> void:
	position = Vector2(0, TOP)
	size = Vector2(stage_size.x, maxf(0.0, stage_size.y - TOP))

func _process(delta: float) -> void:
	time += delta
	flash = maxf(0.0, flash - delta * 2.8)
	glow = maxf(0.0, glow - delta * 1.6)
	for bolt: Dictionary in bolts:
		bolt.age = float(bolt.age) + delta
	bolts = bolts.filter(func(bolt: Dictionary) -> bool: return float(bolt.age) < BOLT_LIFE)
	# The clouds mutter between strikes.
	if glow <= 0.0 and rng.randf() < delta * 0.6:
		glow_at = Vector2(rng.randf_range(0.1, 0.9) * size.x, rng.randf_range(4.0, 40.0))
		glow = 0.7
	queue_redraw()

## A 天雷 falls on `to` (in the stage's coordinates): a forked bolt from the cloud above it.
func strike(to: Vector2) -> void:
	var mark := to - position
	var from := Vector2(clampf(mark.x + rng.randf_range(-160.0, 160.0), 20.0, size.x - 20.0), 20.0)
	var trunk := _jagged(from, mark, 0.22, 6)
	var branches: Array[PackedVector2Array] = []
	for i: int in 3:
		var start: Vector2 = trunk[rng.randi_range(trunk.size() / 5, trunk.size() * 3 / 5)]
		var away := Vector2(rng.randf_range(-1.0, 1.0), rng.randf_range(0.4, 1.0)).normalized()
		branches.append(_jagged(start, start + away * rng.randf_range(60.0, 140.0), 0.3, 4))
	bolts.append({"trunk": trunk, "branches": branches, "age": 0.0})
	flash = 1.0
	glow_at = from
	glow = 1.0

## A crooked line by midpoint displacement: each pass splits every segment and pushes its middle aside
## by `rough` of the segment's length.
func _jagged(from: Vector2, to: Vector2, rough: float, passes: int) -> PackedVector2Array:
	var points := PackedVector2Array([from, to])
	for pass_index: int in passes:
		var next := PackedVector2Array()
		for i: int in points.size() - 1:
			var a := points[i]
			var b := points[i + 1]
			var side := (b - a).orthogonal().normalized()
			next.append(a)
			next.append((a + b) * 0.5 + side * rng.randf_range(-rough, rough) * a.distance_to(b))
		next.append(points[points.size() - 1])
		points = next
	return points

## A puff of cloud with a soft edge: rings from wide and faint to small and dense.
func _puff(at: Vector2, radius: float, color: Color) -> void:
	for step: int in 4:
		var share := 1.0 - step * 0.18
		draw_circle(at, radius * share, Color(color, color.a * (0.22 + step * 0.16)))

func _draw() -> void:
	# The overcast: a band darkest at the top, fading out a third of the way down, breathing slowly.
	draw_texture_rect(overcast, Rect2(0, 0, size.x, size.y * 0.45), false, Color(1, 1, 1, 0.9 + 0.1 * sin(time * 0.8)))
	# Cloud banks: rows of soft puffs drifting at their own pace, the far row slowest and palest.
	for row: int in CLOUD_ROWS:
		var speed := 10.0 + row * 9.0
		var tone := 0.13 + row * 0.04
		for i: int in CLOUDS_PER_ROW:
			var span := size.x + 360.0
			var x := fmod(i * span / CLOUDS_PER_ROW + time * speed + row * 97.0, span) - 180.0
			var y := -6.0 + row * 18.0 + sin(i * 1.7 + time * 0.4 + row) * 5.0
			var radius := 46.0 + float((i * 37 + row * 19) % 34)
			var lit := 0.0
			if glow > 0.0:
				lit = glow * clampf(1.0 - Vector2(x, y).distance_to(glow_at) / 260.0, 0.0, 1.0)
			var color := Color(tone + lit * 0.45, tone + 0.01 + lit * 0.45, tone + 0.09 + lit * 0.5, 0.75)
			_puff(Vector2(x, y), radius, color)
			_puff(Vector2(x + radius * 0.75, y + 10.0), radius * 0.7, color)
	# Bolts: a wide soft glow, then the white core; branches thinner and fainter. They fade as they age.
	for bolt: Dictionary in bolts:
		var fade := 1.0 - float(bolt.age) / BOLT_LIFE
		var trunk: PackedVector2Array = bolt.trunk
		draw_polyline(trunk, Color(0.62, 0.74, 1.0, 0.28 * fade), 16.0, true)
		draw_polyline(trunk, Color(0.75, 0.85, 1.0, 0.6 * fade), 6.0, true)
		draw_polyline(trunk, Color(1, 1, 1, fade), 2.4, true)
		for branch: PackedVector2Array in bolt.branches:
			draw_polyline(branch, Color(0.7, 0.8, 1.0, 0.45 * fade), 4.0, true)
			draw_polyline(branch, Color(1, 1, 1, 0.8 * fade), 1.4, true)
		# Where it lands, a burst of light on the ground.
		draw_circle(trunk[trunk.size() - 1], 34.0 * fade, Color(0.85, 0.9, 1.0, 0.35 * fade))
	if flash > 0.0:
		draw_rect(Rect2(Vector2.ZERO, size), Color(0.9, 0.94, 1.0, 0.45 * flash * flash))
