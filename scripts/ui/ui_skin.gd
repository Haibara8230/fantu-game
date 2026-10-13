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
		# Compress the ornamental frame as a whole; it must not impose image-sized minimums.
		painted.set_texture_margin_all(0)
		box = painted
	box.content_margin_left = padding
	box.content_margin_right = padding
	box.content_margin_top = padding
	box.content_margin_bottom = padding
	return box
