extends Node2D
## Registered sprite poses; art can later be replaced by a rig without changing combat rules.
var sprite := Sprite2D.new()
var definition: Dictionary = {}
var visual_height: float = 250.0
var base_scale: float = 1.0
var phase: float = 0.0
var facing: float = 1.0
var idle_enabled := true
# A squash or stretch on top of the breathing idle: x and y factors easing back to 1.
var squash_scale := Vector2.ONE
var _squash_tween: Tween

func configure(art: Dictionary, faces_right: bool) -> void:
	definition = art
	facing = 1.0 if faces_right else -1.0
	sprite.texture = load(art.texture)
	sprite.hframes = 1 if art.has("frame_regions") else int(art.columns)
	sprite.vframes = 1 if art.has("frame_regions") else int(art.rows)
	sprite.region_enabled = art.has("frame_regions")
	sprite.region_filter_clip_enabled = true
	sprite.flip_h = bool(art.faces_right) != faces_right
	# A borrowed figure may be tinted to tell it apart (心魔 in the hero's shape, 天劫's pale light).
	if art.has("tint"):
		sprite.self_modulate = Color(str(art.tint))
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

## Squashes (or stretches) the sprite to `factors` at once and springs back over `seconds`: a hit lands
## with a squash, a lunge with a stretch.
func squash(factors: Vector2, seconds: float = 0.22) -> void:
	if _squash_tween != null and _squash_tween.is_running():
		_squash_tween.kill()
	squash_scale = factors
	_squash_tween = create_tween()
	_squash_tween.tween_property(self, "squash_scale", Vector2.ONE, seconds).set_trans(Tween.TRANS_BACK).set_ease(Tween.EASE_OUT)

## A fading copy of the current pose left where the actor stands (afterimages of a fast move).
func afterimage(parent: Node, color: Color, seconds: float = 0.28) -> void:
	var ghost := Sprite2D.new()
	ghost.texture = sprite.texture
	ghost.hframes = sprite.hframes
	ghost.vframes = sprite.vframes
	ghost.frame = sprite.frame
	ghost.region_enabled = sprite.region_enabled
	ghost.region_rect = sprite.region_rect
	ghost.offset = sprite.offset
	ghost.flip_h = sprite.flip_h
	ghost.scale = sprite.scale
	ghost.position = position + sprite.position
	ghost.modulate = Color(color, 0.45)
	var additive := CanvasItemMaterial.new()
	additive.blend_mode = CanvasItemMaterial.BLEND_MODE_ADD
	ghost.material = additive
	ghost.z_index = -1
	parent.add_child(ghost)
	var tween := ghost.create_tween()
	tween.tween_property(ghost, "modulate:a", 0.0, seconds)
	tween.tween_callback(ghost.queue_free)

func _process(delta: float) -> void:
	phase += delta
	var breathing := Vector2(1.0 + sin(phase * 1.8) * 0.004, 1.0 + sin(phase * 1.8) * 0.006) if idle_enabled else Vector2.ONE
	sprite.scale = base_scale * breathing * squash_scale
	sprite.position.y = -visual_height * 0.5 * squash_scale.y
