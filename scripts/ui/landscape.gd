extends Control
## Code-drawn placeholder landscape: can be replaced with final art later.
var location_id: String = "sect"

func _ready() -> void:
	mouse_filter = Control.MOUSE_FILTER_IGNORE
	resized.connect(queue_redraw)

func _draw() -> void:
	var w := size.x
	var h := size.y
	draw_rect(Rect2(Vector2.ZERO, size), Color("#11272d"))
	var moon := Vector2(w * 0.77, h * 0.25)
	draw_circle(moon, h * 0.13, Color("#d2bb85"))
	draw_circle(moon + Vector2(h * 0.06, -h * 0.02), h * 0.12, Color("#11272d"))
	draw_colored_polygon(PackedVector2Array([Vector2(0, h), Vector2(0, h * 0.8), Vector2(w * 0.18, h * 0.27), Vector2(w * 0.38, h * 0.74), Vector2(w * 0.62, h * 0.35), Vector2(w * 0.9, h * 0.72), Vector2(w, h * 0.5), Vector2(w, h)]), Color("#244548"))
	draw_colored_polygon(PackedVector2Array([Vector2(0, h), Vector2(0, h * 0.9), Vector2(w * 0.31, h * 0.55), Vector2(w * 0.48, h * 0.9), Vector2(w * 0.79, h * 0.58), Vector2(w, h * 0.86), Vector2(w, h)]), Color("#356060"))
	for i: int in range(5):
		draw_line(Vector2(w * 0.08, h * (0.78 + i * 0.04)), Vector2(w * (0.55 + i * 0.04), h * (0.78 + i * 0.04)), Color(0.7, 0.8, 0.75, 0.06), 2)
	if location_id == "market":
		for i: int in range(5):
			var x := w * (0.45 + i * 0.085)
			var y := h * (0.7 + (i % 2) * 0.08)
			draw_rect(Rect2(x, y, w * 0.06, h * 0.15), Color("#152c30"))
			draw_colored_polygon(PackedVector2Array([Vector2(x - 8, y), Vector2(x + w * 0.03, y - 18), Vector2(x + w * 0.06 + 8, y)]), Color("#b39766"))
	else:
		var x := w * 0.31
		var y := h * 0.68
		draw_rect(Rect2(x, y, 32, 48), Color("#152c30"))
		for i: int in range(3):
			var roof_y := y - 12 + i * 15
			draw_colored_polygon(PackedVector2Array([Vector2(x - 12, roof_y + 8), Vector2(x + 16, roof_y - 12), Vector2(x + 44, roof_y + 8)]), Color("#b39766"))
