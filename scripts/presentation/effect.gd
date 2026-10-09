extends Node2D
## Deterministic vector VFX, kept independent of gameplay RNG.
var kind := "impact"
var start := Vector2.ZERO
var finish := Vector2.ZERO
var duration := 0.4
var elapsed := 0.0
var variation: int = 0
var tint := Color("#d8f8f1")
# Tier layers (data/vfx_tiers.json): extra glow, rings, sparks and trails on top of the base effect.
var layers: Dictionary = {}

func setup(effect_kind: String, origin: Vector2, target: Vector2, seconds: float, color: Color, variant: int = 0) -> void:
	kind = effect_kind
	start = origin
	finish = target
	duration = seconds
	tint = color
	variation = variant
	z_index = 5

func _process(delta: float) -> void:
	elapsed += delta
	queue_redraw()
	if elapsed >= duration:
		queue_free()

func _draw() -> void:
	var t := clampf(elapsed / duration, 0.0, 1.0)
	var fade := sin(t * PI)
	var direction := (finish - start).normalized()
	if direction.is_zero_approx():
		direction = Vector2.RIGHT
	var normal := Vector2(-direction.y, direction.x)
	_draw_layers(t, fade, direction)
	match kind:
		"sword":
			var point := start.lerp(finish, t)
			draw_line(point - direction * 100, point, Color(tint, 0.14), 22, true)
			draw_line(point - direction * 88, point, Color(tint, 0.45), 9, true)
			draw_line(point - direction * 75, point, Color("#f4ffef"), 3, true)
			draw_colored_polygon(PackedVector2Array([point + direction * 20, point - direction * 50 + normal * 6, point - direction * 50 - normal * 6]), Color("#efffe8"))
			for side: float in [-1.0, 1.0]:
				draw_line(point - direction * 70 + normal * side * 14, point - direction * 25 + normal * side * 14, Color(tint, 0.5), 2, true)
		"fire":
			var point := start.lerp(finish, t)
			for i: int in range(7):
				var trail := point - direction * i * 13 + normal * sin(t * 28 + i) * 5
				draw_circle(trail, 25 - i * 2.5, Color(1.0, 0.37, 0.12, 0.10 + (6 - i) * 0.035))
			draw_circle(point, 16, Color("#ff9c37"))
			draw_circle(point - direction * 3, 9, Color("#ffeb9d"))
			draw_colored_polygon(PackedVector2Array([point + direction * 30, point + normal * 8, point - direction * 15, point - normal * 8]), Color("#fff5b8"))
		"impact", "claw":
			var radius := 12.0 + t * 65.0
			draw_circle(finish, radius * 0.55, Color(tint, (1.0 - t) * 0.23))
			for i: int in range(9):
				var angle := float(i) * TAU / 9.0 + 0.15
				var axis := Vector2.from_angle(angle)
				draw_line(finish + axis * radius * 0.3, finish + axis * radius, Color(tint, 1.0 - t), 3.0 * (1.0 - t) + 1.0, true)
			if kind == "claw":
				for i: int in range(3):
					var offset := Vector2(i * 14 - 15, i * 5)
					draw_line(finish + offset + Vector2(-30, -45) * t, finish + offset + Vector2(25, 38) * t, Color("#ffe0b5", fade), 4, true)
		"heal":
			for i: int in range(16):
				var angle := i * TAU / 16 + t * 3
				var point := finish + Vector2(cos(angle) * (24 + t * 35), -t * 105 + sin(angle) * 13)
				var leaf := PackedVector2Array([point + Vector2(0, -6), point + Vector2(4, 0), point + Vector2(0, 6), point + Vector2(-4, 0)])
				draw_colored_polygon(leaf, Color(tint, fade))
			draw_arc(finish, 25 + t * 45, 0, TAU, 48, Color(tint, fade * 0.7), 2, true)
		"guard":
			var radius := 52.0 + sin(t * PI) * 5.0
			draw_circle(finish, radius, Color(tint, fade * 0.1))
			draw_arc(finish, radius, -PI * 0.7, PI * 0.7, 48, Color(tint, fade), 3, true)
			draw_arc(finish, radius - 8, -PI * 0.8, PI * 0.8, 48, Color(tint, fade * 0.6), 1, true)
			for i: int in range(8):
				var axis := Vector2.from_angle(i * TAU / 8)
				draw_line(finish + axis * (radius - 3), finish + axis * (radius + 3), Color(tint, fade), 2, true)

		"sword_rain":
			var point := start.lerp(finish, t) + normal * sin(t * PI) * (variation - 1) * 42
			_blade(point, direction, 84, Color(tint, fade))
			draw_line(point - direction * 95, point - direction * 30, Color(tint, fade * 0.3), 2, true)
		"sword_arc":
			var point := start.lerp(finish, t)
			var sweep := PackedVector2Array()
			for i: int in range(28):
				var angle := -1.3 + i * 2.6 / 27
				sweep.append(point + Vector2(cos(angle) * 24 * direction.x, sin(angle) * 76))
			draw_polyline(sweep, Color(tint, fade * 0.25), 18, true)
			draw_polyline(sweep, Color("#f1ffe8", fade), 3, true)
			for i: int in range(5):
				draw_line(point - direction * (20 + i * 10) + normal * (i * 9 - 18), point - direction * (55 + i * 9) + normal * (i * 9 - 18), Color(tint, fade * 0.35), 2, true)
		"flame_bolt":
			var point := start.lerp(finish, t)
			_flame(point, 22, tint, 1)
			for i: int in range(8):
				var p := point - direction * i * 8 + normal * sin(t * 24 + i * 2) * 8
				draw_circle(p, 2.0, Color("#ffd491", 1 - i / 9.0))
		"fire_burst":
			var rise := sin(t * PI)
			var base := finish + Vector2(0, 52)
			_rune(base, 44 + t * 25, tint, fade, true)
			for i: int in range(7):
				_flame(base + Vector2((i - 3) * 13, -rise * (15 + (3 - abs(i - 3)) * 13)), 18 + rise * 28, tint, fade)
		"vine":
			var tip := start.lerp(finish, t)
			var points := PackedVector2Array()
			for i: int in range(24):
				var ratio := i / 23.0
				points.append(start.lerp(tip, ratio) + normal * sin(ratio * 16 + t * 5) * 12 * sin(ratio * PI))
			draw_polyline(points, Color("#345c3a", fade), 7, true)
			draw_polyline(points, Color(tint, fade), 3, true)
			for i: int in range(7):
				var point := start.lerp(tip, i / 6.0) + normal * sin(i * 2.6 + t * 5) * 10
				_leaf(point, i * 0.9, 9, tint, fade)
		"leaf_blade":
			for i: int in range(4):
				var p := start.lerp(finish, t) + normal * sin(t * PI) * sin(i * 2.4 + variation) * 50
				draw_line(p - direction * 24, p, Color(tint, fade * 0.45), 2, true)
				_leaf(p, direction.angle() + t * 5, 12, tint, fade)
		"water":
			var point := start.lerp(finish, t)
			for i: int in range(5):
				var p := point - direction * i * 17
				draw_arc(p, 18 + i * 5, -1.2 + direction.angle(), 1.2 + direction.angle(), 24, Color(tint, (1.0 - i * 0.15) * fade), 4, true)
			draw_circle(point, 13, Color(tint, 0.35))
			draw_arc(point, 14, 0, TAU, 32, Color("#edffff", fade), 2, true)
		"ice_lance":
			var point := start.lerp(finish, t)
			var crystal := PackedVector2Array([point + direction * 46, point - direction * 35 + normal * 13, point - direction * 53, point - direction * 35 - normal * 13])
			draw_colored_polygon(crystal, Color("#8bbbd7", fade))
			draw_line(point - direction * 45, point + direction * 43, Color("#f2ffff", fade), 3, true)
			draw_colored_polygon(PackedVector2Array([point + direction * 46, point - direction * 35 + normal * 13, point - direction * 14]), Color("#dbf5ff", fade))
			for i: int in range(8):
				var p := point - direction * (i * 11 + 20) + normal * sin(i * 2.5) * 13
				draw_circle(p, 2, Color(tint, fade * 0.6))
		"earth", "rock_spire":
			var base := finish + Vector2(0, 62)
			var rise := sin(t * PI * 0.5)
			var count := 1 if kind == "earth" else 3
			for i: int in range(count):
				var x := (i - (count - 1) * 0.5) * 26
				var height: float = (68.0 if kind == "earth" else 115.0 - absf(x) * 0.9) * rise
				var points := PackedVector2Array([base + Vector2(x - 15, 0), base + Vector2(x - 12, -height * 0.8), base + Vector2(x + 2, -height), base + Vector2(x + 18, -height * 0.4), base + Vector2(x + 21, 0)])
				draw_colored_polygon(points, Color("#9f835d", fade))
				draw_line(base + Vector2(x + 2, -height), base + Vector2(x + 6, -12), Color(tint, fade), 3, true)
			for i: int in range(12):
				var p := base + Vector2(cos(i * 2.2) * t * 80, -sin(t * PI) * (14 + i * 4))
				draw_colored_polygon(PackedVector2Array([p + Vector2(-3,-2), p + Vector2(4,-3), p + Vector2(2,4)]), Color(tint, fade))
		"sigil", "sword_guard", "fire_guard", "wood_guard", "water_guard", "earth_guard":
			_rune(finish, 40 + sin(t * PI) * 12, tint, fade, false)
			if kind == "sword_guard":
				for i: int in range(5):
					var angle := i * TAU / 5 + t * 1.6
					_blade(finish + Vector2.from_angle(angle) * 54, Vector2.from_angle(angle + PI * 0.5), 34, Color(tint, fade))
			elif kind == "fire_guard":
				for i: int in range(8):
					_flame(finish + Vector2.from_angle(i * TAU / 8 + t) * 47, 14, tint, fade)
			elif kind == "wood_guard":
				for i: int in range(14):
					var angle := i * TAU / 14 + t * 2
					_leaf(finish + Vector2.from_angle(angle) * 49, angle + PI * 0.5, 9, tint, fade)
			elif kind == "water_guard":
				draw_circle(finish, 49, Color(tint, fade * 0.12))
				draw_arc(finish, 49, -1 + t, 3.5 + t, 40, Color("#defbff", fade), 3, true)
			elif kind == "earth_guard":
				for i: int in range(6):
					var angle := i * TAU / 6 + 0.5
					var point := finish + Vector2.from_angle(angle) * 47
					var points := PackedVector2Array([point + Vector2(-9,-7), point + Vector2(7,-10), point + Vector2(11,7), point + Vector2(-6,10)])
					draw_colored_polygon(points, Color("#ae936d", fade))
					draw_polyline(PackedVector2Array([points[0],points[1],points[2]]), Color(tint,fade), 2, true)
		"water_heal":
			for i: int in range(6):
				var center := finish + Vector2(0, 52 - i * 17 - t * 35)
				_rune(center, 16 + i * 5, tint, fade * 0.55, true)
			for i: int in range(12):
				var p := finish + Vector2(sin(i * 2.5 + t * 4) * 45, 40 - t * 125 + i % 3 * 13)
				draw_circle(p, 3.0, Color("#d9ffff", fade))
		"sword_hit", "ember_hit", "fire_explosion", "root_hit", "water_hit", "ice_shatter", "stone_hit":
			var radius := t * (85.0 if kind == "fire_explosion" else 56.0)
			for i: int in range(18):
				var angle := i * TAU / 18 + i * 0.23
				var axis := Vector2.from_angle(angle)
				var point := finish + axis * radius
				if kind == "root_hit":
					_leaf(point, angle + t * 4, 7, tint, 1 - t)
				elif kind in ["ice_shatter", "stone_hit"]:
					var points := PackedVector2Array([point + axis * 9, point + axis.orthogonal() * 4, point - axis * 5, point - axis.orthogonal() * 4])
					draw_colored_polygon(points, Color(tint, 1-t))
				elif kind == "water_hit":
					draw_circle(point, 3.0 * (1-t) + 1, Color(tint, 1-t))
				else:
					draw_line(point - axis * 14, point + axis * 5, Color(tint, 1-t), 2, true)
			if kind == "fire_explosion":
				draw_circle(finish, 18 + radius * 0.4, Color("#fff2ab", (1-t) * 0.35))
				for i: int in range(9):
					_flame(finish + Vector2.from_angle(i * TAU / 9) * radius * 0.65, 24 * (1-t) + 5, tint, 1-t)
			elif kind in ["water_hit", "ice_shatter"]:
				draw_arc(finish, radius, 0, TAU, 48, Color(tint, 1-t), 2, true)
			elif kind == "sword_hit":
				draw_line(finish + Vector2(-25,-36) * t, finish + Vector2(28,40) * t, Color("#ffffff", 1-t), 4, true)
			elif kind == "root_hit":
				for i: int in range(3):
					draw_arc(finish + Vector2(0,i*12-12), radius * 0.6, -PI * 0.7, PI * 0.4, 26, Color(tint, 1-t), 2, true)


func _blade(point: Vector2, direction: Vector2, length: float, color: Color) -> void:
	var normal := direction.orthogonal()
	draw_line(point - direction * length * 0.5, point + direction * length * 0.5, Color(color, color.a * 0.2), 12, true)
	draw_colored_polygon(PackedVector2Array([point + direction * length * 0.65, point - direction * length * 0.4 + normal * 4, point - direction * length * 0.5, point - direction * length * 0.4 - normal * 4]), color)
	draw_line(point - direction * length * 0.4, point + direction * length * 0.5, Color("#f1fff8", color.a), 1, true)

func _leaf(point: Vector2, angle: float, radius: float, color: Color, alpha: float) -> void:
	var axis := Vector2.from_angle(angle)
	var normal := axis.orthogonal()
	draw_colored_polygon(PackedVector2Array([point + axis * radius, point + normal * radius * 0.42, point - axis * radius, point - normal * radius * 0.42]), Color(color, alpha))
	draw_line(point - axis * radius * 0.7, point + axis * radius * 0.7, Color("#e4ffd0",alpha), 1, true)

func _flame(point: Vector2, radius: float, color: Color, alpha: float) -> void:
	var points := PackedVector2Array([point + Vector2(0,-radius),point + Vector2(radius*0.25,-radius*0.3),point + Vector2(radius*0.48,-radius*0.58),point + Vector2(radius*0.58,radius*0.3),point + Vector2(0,radius*0.58),point + Vector2(-radius*0.56,radius*0.22),point + Vector2(-radius*0.35,-radius*0.55)])
	draw_colored_polygon(points, Color(color,alpha))
	draw_colored_polygon(PackedVector2Array([point + Vector2(0,-radius*0.3),point + Vector2(radius*0.2,radius*0.24),point + Vector2(0,radius*0.4),point + Vector2(-radius*0.23,radius*0.2)]), Color("#fff1b3",alpha))

func _rune(point: Vector2, radius: float, color: Color, alpha: float, ground: bool) -> void:
	var ring := PackedVector2Array()
	for i: int in range(65):
		var angle := i * TAU / 64
		ring.append(point + Vector2(cos(angle) * radius, sin(angle) * radius * (0.28 if ground else 1.0)))
	draw_polyline(ring, Color(color,alpha * 0.7), 2, true)
	for i: int in range(8):
		var angle := i * TAU / 8 + elapsed
		var axis := Vector2(cos(angle), sin(angle) * (0.28 if ground else 1.0))
		draw_line(point + axis * (radius - 6), point + axis * (radius + 2), Color(color,alpha), 2, true)

## Higher tiers stack more of everything around the travelling point; tier 1 draws nothing extra.
func _draw_layers(t: float, fade: float, direction: Vector2) -> void:
	if layers.is_empty():
		return
	var point := start.lerp(finish, t)
	var size := float(layers.get("scale", 1.0))
	for index: int in int(layers.get("glow", 0)):
		draw_circle(point, (12.0 + index * 8.0) * size, Color(tint, 0.07 * fade))
	for index: int in int(layers.get("rings", 0)):
		draw_arc(point, (20.0 + index * 11.0) * size * (0.6 + 0.4 * t), 0.0, TAU, 40, Color(tint, 0.35 * fade), 2.0, true)
	var sparks := int(layers.get("sparks", 0))
	for index: int in sparks:
		var angle := TAU * float(index) / float(maxi(1, sparks)) + t * 4.0 + float(variation)
		var radius := (22.0 + float(index % 3) * 9.0) * size
		draw_circle(point + Vector2.from_angle(angle) * radius, 2.2, Color(tint.lightened(0.45), 0.85 * fade))
	for index: int in int(layers.get("trail", 0)):
		var near := (12.0 + index * 20.0) * size
		draw_line(point - direction * (near + 18.0 * size), point - direction * near, Color(tint, 0.3 * fade / float(index + 1)), 4.0, true)
