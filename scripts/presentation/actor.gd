extends Node2D
## Registered sprite poses; art can later be replaced by a rig without changing combat rules.
var sprite := Sprite2D.new()
var definition: Dictionary = {}
var visual_height: float = 250.0
var base_scale: float = 1.0
var phase: float = 0.0
var facing: float = 1.0
var idle_enabled := true

func configure(art: Dictionary, faces_right: bool) -> void:
	definition = art
	facing = 1.0 if faces_right else -1.0
	sprite.texture = load(art.texture)
	sprite.hframes = 1 if art.has("frame_regions") else int(art.columns)
	sprite.vframes = 1 if art.has("frame_regions") else int(art.rows)
	sprite.region_enabled = art.has("frame_regions")
	sprite.region_filter_clip_enabled = true
	sprite.flip_h = bool(art.faces_right) != faces_right
	var material := ShaderMaterial.new()
	material.shader = load("res://assets/shaders/hit_flash.gdshader")
	sprite.material = material
	add_child(sprite)
	set_pose("idle")

func set_height(height: float) -> void:
	visual_height = height
	var cell_height := float(sprite.texture.get_height()) / int(definition.rows)
	base_scale = height / cell_height
	sprite.position.y = -height * 0.5
	sprite.scale = Vector2.ONE * base_scale

func set_pose(pose_name: String) -> void:
	var frame_index := int(definition.frames.get(pose_name, definition.frames.idle))
	if definition.has("frame_regions"):
		var region: Array = definition.frame_regions[frame_index]
		sprite.region_rect = Rect2(region[0], region[1], region[2], region[3])
		var cell_height := float(sprite.texture.get_height()) / int(definition.rows)
		var row_index: int = frame_index / int(definition.columns)
		# Keep original registration when excluding neighbouring sprites.
		sprite.offset.y = float(region[1]) - row_index * cell_height + (float(region[3]) - cell_height) * 0.5
	else:
		sprite.frame = frame_index

func flash(strength: float, color: Color = Color.WHITE) -> void:
	sprite.material.set_shader_parameter("flash_strength", strength)
	sprite.material.set_shader_parameter("flash_color", color)

func chest() -> Vector2:
	return position + Vector2(0, -visual_height * 0.57)

func _process(delta: float) -> void:
	phase += delta
	if idle_enabled:
		sprite.scale = Vector2(base_scale * (1.0 + sin(phase * 1.8) * 0.004), base_scale * (1.0 + sin(phase * 1.8) * 0.006))
