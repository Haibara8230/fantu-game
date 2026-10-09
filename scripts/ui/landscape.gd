extends Control
## Location or scene banner. Shows painted art when it exists (cropped to fill), otherwise a
## code-drawn ink placeholder shaped by the location's terrain.
const ArtLibrary = preload("res://scripts/ui/art_library.gd")
var location_id: String = "sect"
var terrain: String = "mountain"
var spot_id: String = ""
var art: Texture2D

func _ready() -> void:
	mouse_filter = Control.MOUSE_FILTER_IGNORE
	clip_contents = true
	resized.connect(queue_redraw)
	var path := ArtLibrary.scene_path(location_id, spot_id) if not spot_id.is_empty() else ArtLibrary.location_path(location_id)
	art = ArtLibrary.texture(path)
	if art == null and not spot_id.is_empty():
		art = ArtLibrary.texture(ArtLibrary.location_path(location_id))

func _draw() -> void:
	if art != null:
		_draw_cover(art)
		return
	var w := size.x
	var h := size.y
	var variant := absi(hash(location_id + spot_id)) % 7
	draw_rect(Rect2(Vector2.ZERO, size), Color("#11272d"))
	var moon := Vector2(w * (0.66 + variant * 0.03), h * 0.25)
	draw_circle(moon, h * 0.13, Color("#d2bb85"))
	draw_circle(moon + Vector2(h * 0.06, -h * 0.02), h * 0.12, Color("#11272d"))
	var far := 0.27 + (0.1 if terrain in ["town", "market", "ferry"] else 0.0)
	draw_colored_polygon(PackedVector2Array([Vector2(0, h), Vector2(0, h * 0.8), Vector2(w * 0.18, h * far), Vector2(w * 0.38, h * 0.74), Vector2(w * 0.62, h * (far + 0.08)), Vector2(w * 0.9, h * 0.72), Vector2(w, h * 0.5), Vector2(w, h)]), Color("#244548"))
	draw_colored_polygon(PackedVector2Array([Vector2(0, h), Vector2(0, h * 0.9), Vector2(w * 0.31, h * 0.55), Vector2(w * 0.48, h * 0.9), Vector2(w * 0.79, h * 0.58), Vector2(w, h * 0.86), Vector2(w, h)]), Color("#356060"))
	match terrain:
		"market", "town":
			var count := 5 if terrain == "market" else 3
			for i: int in range(count):
				var x := w * (0.4 + i * 0.09)
				var y := h * (0.7 + (i % 2) * 0.08)
				draw_rect(Rect2(x, y, w * 0.06, h * 0.15), Color("#152c30"))
				draw_colored_polygon(PackedVector2Array([Vector2(x - 8, y), Vector2(x + w * 0.03, y - 18), Vector2(x + w * 0.06 + 8, y)]), Color("#b39766"))
				if terrain == "market":
					draw_circle(Vector2(x + w * 0.03, y + 10), 4, Color("#d98a5c"))
		"ferry":
			draw_rect(Rect2(0, h * 0.8, w, h * 0.2), Color("#21474e"))
			for i: int in range(6):
				draw_line(Vector2(w * (0.05 + i * 0.16), h * 0.86), Vector2(w * (0.12 + i * 0.16), h * 0.86), Color(0.8, 0.88, 0.85, 0.2), 2)
			draw_colored_polygon(PackedVector2Array([Vector2(w * 0.42, h * 0.83), Vector2(w * 0.6, h * 0.83), Vector2(w * 0.56, h * 0.88), Vector2(w * 0.46, h * 0.88)]), Color("#b39766"))
			draw_line(Vector2(w * 0.55, h * 0.83), Vector2(w * 0.62, h * 0.6), Color("#d2bb85"), 2)
		"ridge":
			for i: int in range(7):
				var x := w * (0.1 + i * 0.13)
				var y := h * (0.62 + (i % 3) * 0.05)
				draw_rect(Rect2(x - 2, y, 4, h * 0.2), Color("#152c30"))
				for tier: int in range(3):
					draw_colored_polygon(PackedVector2Array([Vector2(x - 16 + tier * 3, y + 6 - tier * 12), Vector2(x, y - 14 - tier * 12), Vector2(x + 16 - tier * 3, y + 6 - tier * 12)]), Color("#1f4744"))
		"valley":
			draw_colored_polygon(PackedVector2Array([Vector2(w * 0.3, h), Vector2(w * 0.45, h * 0.6), Vector2(w * 0.55, h * 0.6), Vector2(w * 0.7, h)]), Color("#1b3a3c"))
			for i: int in range(9):
				draw_circle(Vector2(w * (0.12 + i * 0.09), h * (0.9 - (i % 3) * 0.03)), 3, Color("#7fbf8a"))
		"ruin":
			draw_rect(Rect2(w * 0.4, h * 0.5, w * 0.2, h * 0.5), Color("#152427"))
			draw_arc(Vector2(w * 0.5, h * 0.62), w * 0.06, PI, TAU, 24, Color("#6f8a82"), 3)
			draw_rect(Rect2(w * 0.455, h * 0.62, w * 0.09, h * 0.38), Color("#0b1719"))
		_:
			var x := w * 0.31
			var y := h * 0.68
			draw_rect(Rect2(x, y, 32, 48), Color("#152c30"))
			for i: int in range(3):
				var roof_y := y - 12 + i * 15
				draw_colored_polygon(PackedVector2Array([Vector2(x - 12, roof_y + 8), Vector2(x + 16, roof_y - 12), Vector2(x + 44, roof_y + 8)]), Color("#b39766"))
	for i: int in range(5):
		draw_line(Vector2(w * 0.08, h * (0.78 + i * 0.04)), Vector2(w * (0.55 + i * 0.04), h * (0.78 + i * 0.04)), Color(0.7, 0.8, 0.75, 0.06), 2)

func _draw_cover(texture: Texture2D) -> void:
	var source := Vector2(texture.get_width(), texture.get_height())
	var scale := maxf(size.x / source.x, size.y / source.y)
	var region_size := size / scale
	var region := Rect2((source - region_size) * 0.5, region_size)
	draw_texture_rect_region(texture, Rect2(Vector2.ZERO, size), region)
