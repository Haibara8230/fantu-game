extends RefCounted
## Presentation-only scroll frame. The old flat panel remains a safe missing-art fallback.
const ArtLibrary = preload("res://scripts/ui/art_library.gd")

static func scroll_style(padding: float = 18.0, opacity: float = 1.0) -> StyleBox:
	var texture := ArtLibrary.texture("res://assets/art/ui/scroll_panel.png")
	var box: StyleBox
	if texture == null:
		var flat := StyleBoxFlat.new()
		flat.bg_color = Color(0.06, 0.12, 0.14, opacity)
		flat.border_color = Color("#41615e")
		flat.set_border_width_all(1)
		flat.set_corner_radius_all(5)
		box = flat
	else:
		var painted := StyleBoxTexture.new()
		painted.texture = texture
		painted.modulate_color = Color(1, 1, 1, opacity)
		# A 9-slice: the rollers, their caps and the gold rails keep their drawn size on any panel, and
		# only the paper between them stretches.
		for side: int in FRAME:
			painted.set_texture_margin(side, FRAME[side])
		box = painted
	# Text keeps clear of the rollers at the sides and of the rails above and below.
	for side: int in [SIDE_LEFT, SIDE_RIGHT]:
		box.set_content_margin(side, padding + (0.0 if texture == null else FRAME[side]))
	for side: int in [SIDE_TOP, SIDE_BOTTOM]:
		box.set_content_margin(side, padding * (1.0 if texture == null else 0.5) + (0.0 if texture == null else FRAME[side]))
	return box

## The scroll frame's edges in assets/art/ui/scroll_panel.png pixels (894x427): the rollers and the rails.
const FRAME := {SIDE_LEFT: 52.0, SIDE_TOP: 37.0, SIDE_RIGHT: 52.0, SIDE_BOTTOM: 44.0}
