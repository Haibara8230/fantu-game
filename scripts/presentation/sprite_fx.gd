extends RefCounted
## Textured effects over the vector ones: bursts of particles, flashes of a single sprite, and trails
## that follow a projectile. The textures are Kenney's Particle Pack (CC0, assets/art/vfx), greyscale so
## that any element's colour tints them, drawn added onto the scene so they glow. Recipes live in
## data/vfx_sprites.json; each is a list of layers:
##   {"type": "burst", "tex", "count", "life": [min, max], "speed": [min, max], "spread" (degrees),
##    "scale": [min, max], "gravity" (pixels/s²), "spin" (radians/s), "along" (follow the strike's
##    direction), "lighten", "alpha", "blend": "add" | "mix"}
##   {"type": "pop", "tex", "life", "scale": [from, to], "stretch" (x over y), "rotation": "dir" | "random"
##    | degrees, "turn" (radians over its life), "lighten", "alpha", "blend"}
## Any layer may name its own "color".
## `tex` may be a list: a burst takes one per particle batch, a pop picks one.
const ROOT := "res://assets/art/vfx/%s.png"
static var _textures: Dictionary = {}
static var _add: CanvasItemMaterial
static var _mix: CanvasItemMaterial
static var _recipes: Dictionary = {}

static func recipes() -> Dictionary:
	if _recipes.is_empty():
		var parsed: Variant = JSON.parse_string(FileAccess.get_file_as_string("res://data/vfx_sprites.json"))
		_recipes = parsed if parsed is Dictionary else {}
	return _recipes

## A recipe by group and name ("impact", "sword_hit"), or [] when there is none.
static func recipe(group: String, name: String) -> Array:
	return recipes().get(group, {}).get(name, [])

static func texture(name: String) -> Texture2D:
	if not _textures.has(name):
		var path := ROOT % name
		_textures[name] = load(path) if ResourceLoader.exists(path) else null
	return _textures[name]

static func material(blend: String) -> CanvasItemMaterial:
	if _add == null:
		_add = CanvasItemMaterial.new()
		_add.blend_mode = CanvasItemMaterial.BLEND_MODE_ADD
		_mix = CanvasItemMaterial.new()
	return _mix if blend == "mix" else _add

## Plays every layer of a recipe at `at`, coloured `color`, aimed along `direction`, scaled `size`.
static func play(parent: Node, at: Vector2, layers: Array, color: Color, direction: Vector2 = Vector2.RIGHT, size: float = 1.0) -> void:
	for layer: Dictionary in layers:
		match str(layer.get("type", "")):
			"burst":
				burst(parent, at, layer, color, direction, size)
			"pop":
				pop(parent, at, layer, color, direction, size)

## A layer's colour: its own `color` when it has one (embers stay orange whatever the art's hue), else
## the art's, lightened.
static func _tint(layer: Dictionary, color: Color) -> Color:
	var base := Color(str(layer.color)) if layer.has("color") else color
	var tinted := base.lightened(float(layer.get("lighten", 0.0)))
	tinted.a = float(layer.get("alpha", 1.0))
	return tinted

static func _pick(value: Variant, index: int = -1) -> String:
	if value is Array:
		return str(value[(index if index >= 0 else randi()) % value.size()])
	return str(value)

## A one-shot burst of particles that frees itself.
static func burst(parent: Node, at: Vector2, layer: Dictionary, color: Color, direction: Vector2, size: float) -> CPUParticles2D:
	var particles := CPUParticles2D.new()
	var tex := texture(_pick(layer.get("tex", "spark_05")))
	if tex == null:
		return null
	particles.texture = tex
	particles.material = material(str(layer.get("blend", "add")))
	particles.position = at
	particles.z_index = 6
	particles.one_shot = true
	particles.explosiveness = float(layer.get("explosive", 1.0))
	particles.amount = maxi(1, int(layer.get("count", 8)))
	var life: Array = layer.get("life", [0.2, 0.4])
	particles.lifetime = float(life[1])
	particles.lifetime_randomness = clampf(1.0 - float(life[0]) / maxf(0.01, float(life[1])), 0.0, 1.0)
	var aim := direction if bool(layer.get("along", false)) else Vector2.UP
	particles.direction = aim if not aim.is_zero_approx() else Vector2.UP
	particles.spread = float(layer.get("spread", 180.0))
	var speed: Array = layer.get("speed", [100, 300])
	particles.initial_velocity_min = float(speed[0]) * size
	particles.initial_velocity_max = float(speed[1]) * size
	particles.gravity = Vector2(0, float(layer.get("gravity", 0.0)))
	particles.damping_min = float(layer.get("damping", 0.0))
	particles.damping_max = float(layer.get("damping", 0.0))
	var scale: Array = layer.get("scale", [0.1, 0.2])
	particles.scale_amount_min = float(scale[0]) * size
	particles.scale_amount_max = float(scale[1]) * size
	var spin := float(layer.get("spin", 0.0))
	particles.angular_velocity_min = -spin * 57.3
	particles.angular_velocity_max = spin * 57.3
	particles.angle_min = 0.0
	particles.angle_max = 360.0 if bool(layer.get("turn", true)) else 0.0
	var fade := Gradient.new()
	var start := _tint(layer, color)
	fade.set_color(0, start)
	fade.set_color(1, Color(start, 0.0))
	particles.color_ramp = fade
	var shrink := Curve.new()
	shrink.add_point(Vector2(0, 1))
	shrink.add_point(Vector2(1, float(layer.get("end_scale", 0.4))))
	particles.scale_amount_curve = shrink
	parent.add_child(particles)
	particles.emitting = true
	var timer := parent.get_tree().create_timer(particles.lifetime + 0.2)
	timer.timeout.connect(particles.queue_free)
	return particles

## A single sprite that grows (or shrinks), turns to the strike, and fades.
static func pop(parent: Node, at: Vector2, layer: Dictionary, color: Color, direction: Vector2, size: float) -> Sprite2D:
	var tex := texture(_pick(layer.get("tex", "flare_01")))
	if tex == null:
		return null
	var sprite := Sprite2D.new()
	sprite.texture = tex
	sprite.material = material(str(layer.get("blend", "add")))
	sprite.position = at
	sprite.z_index = 6
	sprite.modulate = _tint(layer, color)
	var rotation: Variant = layer.get("rotation", 0)
	if str(rotation) == "dir":
		sprite.rotation = direction.angle()
	elif str(rotation) == "random":
		sprite.rotation = randf() * TAU
	else:
		sprite.rotation = deg_to_rad(float(rotation))
	var scale: Array = layer.get("scale", [0.3, 0.8])
	var stretch := float(layer.get("stretch", 1.0))
	sprite.scale = Vector2(stretch, 1.0) * float(scale[0]) * size
	parent.add_child(sprite)
	var life := float(layer.get("life", 0.25))
	var tween := sprite.create_tween().set_parallel(true)
	tween.tween_property(sprite, "scale", Vector2(stretch, 1.0) * float(scale[1]) * size, life).set_trans(Tween.TRANS_QUART).set_ease(Tween.EASE_OUT)
	tween.tween_property(sprite, "modulate:a", 0.0, life).set_trans(Tween.TRANS_QUAD).set_ease(Tween.EASE_IN)
	if layer.has("turn"):
		tween.tween_property(sprite, "rotation", sprite.rotation + float(layer.turn), life)
	tween.chain().tween_callback(sprite.queue_free)
	return sprite

## A trail that follows a projectile from `from` to `to` over `seconds`: particles left behind as it
## goes, then fading where they fell.
static func trail(parent: Node, from: Vector2, to: Vector2, seconds: float, layers: Array, color: Color, size: float = 1.0) -> void:
	for layer: Dictionary in layers:
		var tex := texture(_pick(layer.get("tex", "trace_01")))
		if tex == null:
			continue
		var particles := CPUParticles2D.new()
		particles.texture = tex
		particles.material = material(str(layer.get("blend", "add")))
		particles.local_coords = false
		particles.z_index = 5
		particles.position = from
		particles.amount = maxi(2, int(layer.get("count", 24)))
		var life: Array = layer.get("life", [0.15, 0.3])
		particles.lifetime = float(life[1])
		particles.lifetime_randomness = clampf(1.0 - float(life[0]) / maxf(0.01, float(life[1])), 0.0, 1.0)
		particles.spread = float(layer.get("spread", 20.0))
		particles.direction = (from - to).normalized()
		var speed: Array = layer.get("speed", [10, 60])
		particles.initial_velocity_min = float(speed[0]) * size
		particles.initial_velocity_max = float(speed[1]) * size
		particles.gravity = Vector2(0, float(layer.get("gravity", 0.0)))
		var scale: Array = layer.get("scale", [0.05, 0.12])
		particles.scale_amount_min = float(scale[0]) * size
		particles.scale_amount_max = float(scale[1]) * size
		if bool(layer.get("along", false)):
			particles.particle_flag_align_y = true
		var fade := Gradient.new()
		var start := _tint(layer, color)
		fade.set_color(0, start)
		fade.set_color(1, Color(start, 0.0))
		particles.color_ramp = fade
		parent.add_child(particles)
		particles.emitting = true
		var tween := particles.create_tween()
		tween.tween_property(particles, "position", to, seconds)
		tween.tween_callback(func() -> void: particles.emitting = false)
		tween.tween_interval(particles.lifetime + 0.1)
		tween.tween_callback(particles.queue_free)
