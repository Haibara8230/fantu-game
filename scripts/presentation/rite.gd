extends Control
## Short staged moments over the whole screen, in the flat hand-drawn style of the duels: a retreat (the
## figure in meditation, qi gathering, the days and the xp going by), a breakthrough (qi gathering
## harder and faster, then a golden burst with the realm's name or a red crack of backlash) and a brew
## (the furnace's fire, then the glow of what came out). Presentation only: the rules have already run.
## Each play_* returns when the moment is over; a click hurries it. Headless runs (the tests) skip it.
signal done
const ArtLibrary = preload("res://scripts/ui/art_library.gd")
const Calendar = preload("res://scripts/core/calendar.gd")
const INK := Color("#e3e8dc")
const GOLD := Color("#d5b777")
const JADE := Color("#8fd0c4")
const CRIMSON := Color("#c9574e")
const MOTES := 46

var kind := ""
var outcome := ""
var elapsed := 0.0
var length := 1.0
var hurry := false
var figure: Dictionary = {}
var title := ""
var subtitle := ""
var days := [0, 0]
var xp := [0, 0, 1]
var tint := JADE
var _motes: Array[Dictionary] = []
var _rng := RandomNumberGenerator.new()

func _ready() -> void:
	set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	mouse_filter = Control.MOUSE_FILTER_STOP
	z_index = 50
	figure = ArtLibrary.actor_frame("hero", "cast")
	_rng.seed = 7
	for index: int in MOTES:
		_motes.append({"angle": _rng.randf() * TAU, "radius": _rng.randf_range(0.55, 1.25), "speed": _rng.randf_range(0.5, 1.2), "size": _rng.randf_range(2.0, 5.0)})

static func skipped() -> bool:
	return DisplayServer.get_name() == "headless"

func _gui_input(event: InputEvent) -> void:
	if event is InputEventMouseButton and event.pressed:
		hurry = true
		accept_event()

## A retreat: the figure meditates while the date and the xp run from their old to their new values.
func play_retreat(from_day: int, to_day: int, from_xp: int, to_xp: int, xp_goal: int) -> void:
	kind = "retreat"
	title = "闭 关"
	days = [from_day, to_day]
	xp = [from_xp, to_xp, maxi(1, xp_goal)]
	tint = JADE
	await _run(clampf((to_day - from_day) * 0.006, 1.6, 3.2))

## A breakthrough: "success" with the realm reached and its grade, "failure", or "demon" (心魔 rises and
## the moment stops there for the choice).
func play_breakthrough(result: String, realm_title: String = "", grade: String = "") -> void:
	kind = "breakthrough"
	outcome = result
	title = realm_title
	subtitle = grade
	tint = GOLD
	await _run(3.4 if result != "demon" else 2.2)

## A brew: "fine", "done", "fail" or "burst".
func play_brew(result: String, pill_name: String) -> void:
	kind = "brew"
	outcome = result
	title = pill_name
	tint = {"fine": GOLD, "done": JADE, "fail": Color("#8b8f88"), "burst": CRIMSON}.get(result, JADE)
	await _run(2.2)

func _run(seconds: float) -> void:
	length = seconds
	elapsed = 0.0
	if skipped():
		return
	while elapsed < length:
		await get_tree().process_frame
		elapsed += get_process_delta_time() * (4.0 if hurry else 1.0)
		queue_redraw()
	done.emit()

## Progress through the moment in [0, 1].
func _t() -> float:
	return clampf(elapsed / maxf(0.01, length), 0.0, 1.0)

func _draw() -> void:
	var t := _t()
	var fade := minf(1.0, t * 6.0) * minf(1.0, (1.0 - t) * 8.0 + 0.2)
	draw_rect(Rect2(Vector2.ZERO, size), Color(0.02, 0.05, 0.06, 0.9 * fade))
	var heart := Vector2(size.x * 0.5, size.y * 0.52)
	match kind:
		"retreat":
			_draw_figure(heart, 0.62, fade)
			_draw_gathering(heart, t, fade, 1.0)
			_draw_retreat_text(t, fade)
		"breakthrough":
			_draw_breakthrough(heart, t, fade)
		"brew":
			_draw_brew(heart, t, fade)

## The hero's figure, centred on the dantian.
func _draw_figure(heart: Vector2, height_ratio: float, alpha: float, shake: Vector2 = Vector2.ZERO) -> void:
	if figure.is_empty():
		return
	var region: Rect2 = figure.region
	var height := size.y * height_ratio
	var width := height * region.size.x / region.size.y
	var rect := Rect2(heart + shake - Vector2(width * 0.5, height * 0.62), Vector2(width, height))
	draw_texture_rect_region(figure.texture, rect, region, Color(1, 1, 1, alpha))

## Motes of qi spiralling in toward the dantian, faster with `pace`, with a soft ring breathing there.
func _draw_gathering(heart: Vector2, t: float, alpha: float, pace: float) -> void:
	var reach := size.y * 0.48
	for mote: Dictionary in _motes:
		var phase := fposmod(float(mote.radius) - elapsed * 0.35 * float(mote.speed) * pace, 1.25)
		var angle := float(mote.angle) + elapsed * 0.9 * float(mote.speed) * pace
		var point := heart + Vector2(cos(angle), sin(angle) * 0.7) * reach * phase
		draw_circle(point, float(mote.size), Color(tint, alpha * clampf(phase * 1.4, 0.0, 0.85)))
	var breath := 0.5 + 0.5 * sin(elapsed * 3.0 * pace)
	draw_arc(heart, size.y * (0.05 + 0.02 * breath), 0.0, TAU, 48, Color(tint, alpha * 0.6), 3.0)
	draw_circle(heart, size.y * 0.018, Color(tint, alpha * (0.4 + 0.4 * breath)))

func _draw_retreat_text(t: float, alpha: float) -> void:
	var font := get_theme_default_font()
	var day := int(lerpf(float(days[0]), float(days[1]), t))
	var gained := int(lerpf(float(xp[0]), float(xp[1]), t))
	_centered(font, title, Vector2(size.x * 0.5, size.y * 0.12), 46, Color(GOLD, alpha))
	_centered(font, Calendar.date_text(day), Vector2(size.x * 0.5, size.y * 0.82), 24, Color(INK, alpha))
	var bar := Rect2(size.x * 0.32, size.y * 0.86, size.x * 0.36, 8.0)
	draw_rect(bar, Color(0.11, 0.21, 0.22, alpha))
	draw_rect(Rect2(bar.position, Vector2(bar.size.x * clampf(float(gained) / float(xp[2]), 0.0, 1.0), bar.size.y)), Color(GOLD, alpha))
	_centered(font, "修为  %d" % gained, Vector2(size.x * 0.5, size.y * 0.92), 20, Color(INK, alpha))

## Gathering for the first half, harder and with the figure trembling; then the burst or the crack.
func _draw_breakthrough(heart: Vector2, t: float, alpha: float) -> void:
	var font := get_theme_default_font()
	var climax := 0.55 if outcome != "demon" else 1.1
	var shake := Vector2.ZERO
	if t < climax:
		var strain := t / climax
		shake = Vector2(sin(elapsed * 61.0), cos(elapsed * 47.0)) * strain * size.y * 0.006
		_draw_figure(heart, 0.62, alpha, shake)
		_draw_gathering(heart, t, alpha, 1.0 + strain * 3.0)
		for ring: int in 3:
			var grow := fposmod(elapsed * 0.6 + ring / 3.0, 1.0)
			draw_arc(heart, size.y * (0.08 + grow * 0.4), 0.0, TAU, 64, Color(tint, alpha * (1.0 - grow) * strain), 2.0)
		_centered(font, "运 功 冲 关" if outcome != "demon" else "心 魔 丛 生", Vector2(size.x * 0.5, size.y * 0.12), 40, Color(GOLD if outcome != "demon" else CRIMSON, alpha))
		if outcome == "demon":
			draw_rect(Rect2(Vector2.ZERO, size), Color(CRIMSON, 0.18 * strain * alpha))
		return
	var after := (t - climax) / (1.0 - climax)
	if outcome == "success":
		draw_rect(Rect2(Vector2.ZERO, size), Color(1.0, 0.96, 0.85, maxf(0.0, 0.7 - after * 2.0)))
		for ray: int in 16:
			var angle := ray * TAU / 16.0 + after * 0.6
			var reach := size.y * (0.2 + after * 0.6)
			draw_line(heart + Vector2(cos(angle), sin(angle)) * size.y * 0.06, heart + Vector2(cos(angle), sin(angle)) * reach, Color(GOLD, alpha * (1.0 - after) * 0.8), 4.0)
		_draw_figure(heart, 0.62, alpha)
		_centered(font, title, Vector2(size.x * 0.5, size.y * 0.16), 96, Color(GOLD, alpha * minf(1.0, after * 3.0)))
		if not subtitle.is_empty():
			_centered(font, subtitle, Vector2(size.x * 0.5, size.y * 0.88), 30, Color(INK, alpha * minf(1.0, after * 2.0)))
	else:
		draw_rect(Rect2(Vector2.ZERO, size), Color(CRIMSON, maxf(0.0, 0.45 - after)))
		_draw_figure(heart, 0.62, alpha * (1.0 - after * 0.4), Vector2(sin(elapsed * 80.0), 0.0) * (1.0 - after) * size.y * 0.01)
		_rng.seed = 11
		for crack: int in 9:
			var angle := _rng.randf() * TAU
			var point := heart
			for step: int in 5:
				var next := point + Vector2(cos(angle), sin(angle)) * size.y * 0.06 * minf(1.0, after * 2.5)
				draw_line(point, next, Color(CRIMSON.lightened(0.3), alpha), 3.0)
				point = next
				angle += _rng.randf_range(-0.6, 0.6)
		for mote: Dictionary in _motes:
			var point := heart + Vector2(cos(float(mote.angle)), sin(float(mote.angle))) * size.y * after * float(mote.radius) * 0.6
			draw_circle(point, float(mote.size), Color(GOLD, alpha * (1.0 - after)))
		_centered(font, "冲 关 失 败", Vector2(size.x * 0.5, size.y * 0.16), 72, Color(CRIMSON.lightened(0.2), alpha * minf(1.0, after * 3.0)))

## A tripod furnace with its fire; at the end the lid lifts on the result's glow.
func _draw_brew(heart: Vector2, t: float, alpha: float) -> void:
	var font := get_theme_default_font()
	var base := heart + Vector2(0.0, size.y * 0.12)
	var w := size.y * 0.2
	var flare := 0.5 + 0.5 * sin(elapsed * 14.0)
	for tongue: int in 5:
		var x := base.x + (tongue - 2) * w * 0.18
		var tall := size.y * (0.06 + 0.03 * sin(elapsed * 9.0 + tongue)) * (1.6 if outcome == "burst" and t > 0.6 else 1.0)
		draw_colored_polygon(PackedVector2Array([Vector2(x - w * 0.08, base.y + w * 0.62), Vector2(x, base.y + w * 0.62 - tall), Vector2(x + w * 0.08, base.y + w * 0.62)]), Color("#e8894a", alpha * (0.6 + 0.4 * flare)))
	var body := PackedVector2Array([Vector2(base.x - w * 0.6, base.y - w * 0.2), Vector2(base.x + w * 0.6, base.y - w * 0.2), Vector2(base.x + w * 0.48, base.y + w * 0.42), Vector2(base.x - w * 0.48, base.y + w * 0.42)])
	draw_colored_polygon(body, Color("#3e5a55", alpha))
	draw_polyline(body + PackedVector2Array([body[0]]), Color("#1c2b29", alpha), 3.0)
	for leg: int in [-1, 1]:
		draw_line(Vector2(base.x + leg * w * 0.4, base.y + w * 0.4), Vector2(base.x + leg * w * 0.5, base.y + w * 0.66), Color("#1c2b29", alpha), 6.0)
	var lift := maxf(0.0, (t - 0.6) / 0.4) * w * 0.35 if outcome != "burst" else 0.0
	var lid := PackedVector2Array([Vector2(base.x - w * 0.5, base.y - w * 0.2 - lift), Vector2(base.x + w * 0.5, base.y - w * 0.2 - lift), Vector2(base.x + w * 0.2, base.y - w * 0.42 - lift), Vector2(base.x - w * 0.2, base.y - w * 0.42 - lift)])
	draw_colored_polygon(lid, Color("#4d6f68", alpha))
	draw_polyline(lid + PackedVector2Array([lid[0]]), Color("#1c2b29", alpha), 3.0)
	_centered(font, "开 炉 炼 丹", Vector2(size.x * 0.5, size.y * 0.14), 40, Color(GOLD, alpha))
	if t > 0.6:
		var shown := (t - 0.6) / 0.4
		match outcome:
			"fine", "done":
				draw_circle(base - Vector2(0.0, w * 0.45), w * (0.15 + 0.25 * shown), Color(tint, alpha * 0.35))
				for ray: int in 12:
					var angle := ray * TAU / 12.0 + elapsed
					draw_line(base - Vector2(0.0, w * 0.45), base - Vector2(0.0, w * 0.45) + Vector2(cos(angle), sin(angle)) * w * (0.4 + shown), Color(tint, alpha * (1.0 - shown) * 0.7), 3.0)
				_centered(font, ("丹成 · 上品 " if outcome == "fine" else "丹成 · ") + title, Vector2(size.x * 0.5, size.y * 0.86), 34, Color(tint, alpha * minf(1.0, shown * 3.0)))
			"fail":
				for puff: int in 6:
					draw_circle(base - Vector2((puff - 2.5) * w * 0.12, w * (0.5 + shown * 0.6 + puff * 0.05)), w * (0.08 + shown * 0.1), Color(tint, alpha * (1.0 - shown) * 0.6))
				_centered(font, "火候失当 · 化作药渣", Vector2(size.x * 0.5, size.y * 0.86), 30, Color(INK, alpha * minf(1.0, shown * 3.0)))
			"burst":
				draw_rect(Rect2(Vector2.ZERO, size), Color(CRIMSON, maxf(0.0, 0.5 - shown)))
				_centered(font, "丹炉炸开", Vector2(size.x * 0.5, size.y * 0.86), 36, Color(CRIMSON.lightened(0.3), alpha * minf(1.0, shown * 3.0)))

func _centered(font: Font, text: String, at: Vector2, font_size: int, color: Color) -> void:
	var width := font.get_string_size(text, HORIZONTAL_ALIGNMENT_LEFT, -1, font_size).x
	draw_string_outline(font, at - Vector2(width * 0.5, 0.0), text, HORIZONTAL_ALIGNMENT_LEFT, -1, font_size, 6, Color(0.03, 0.06, 0.07, color.a * 0.85))
	draw_string(font, at - Vector2(width * 0.5, 0.0), text, HORIZONTAL_ALIGNMENT_LEFT, -1, font_size, color)
