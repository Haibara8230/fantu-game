extends Control
## Plays a completed, authoritative turn as sequential readable animation events.
const Actor = preload("res://scripts/presentation/actor.gd")
const Effect = preload("res://scripts/presentation/effect.gd")
signal cue(kind: String)
signal hit_resolved(enemy_target: bool, amount: int, hp_after: int)
var art: Dictionary = {}
var skills: Dictionary = {}
var sects: Dictionary = {}
var profiles: Dictionary = {}
var recoil_handle: Tween
var flash_handle: Tween
var hero_sect: String = "wanderer"
var enemy_sect: String = "qingyun"
var world := Node2D.new()
var hero
var enemy
var background: Texture2D
var enemy_id := ""
var hero_name := ""
var enemy_name := ""
var hero_hp: int
var hero_max_hp: int
var enemy_hp: int
var enemy_max_hp: int
var phase := 0.0
var shake := 0.0
var busy := false
var motion_enabled := true
var last_cue := ""
var banner := ""
var cue_count := 0
var flash_alpha := 0.0
var effect_font := SystemFont.new()

func configure(snapshot: Dictionary, enemy_definition: Dictionary) -> void:
	art = JSON.parse_string(FileAccess.get_file_as_string("res://data/art.json"))
	background = load(art.background)
	var definitions: Dictionary = JSON.parse_string(FileAccess.get_file_as_string("res://data/world.json"))
	skills = definitions.skills
	sects = definitions.sects
	profiles = JSON.parse_string(FileAccess.get_file_as_string("res://data/vfx.json"))
	hero_sect = snapshot.player.get("sect", "wanderer")
	enemy_sect = snapshot.battle.get("opponent_sect", "qingyun")
	enemy_id = snapshot.battle.enemy_id
	hero_name = snapshot.player.name + " · " + str(sects[hero_sect].name)
	enemy_name = enemy_definition.name + (" · " + str(sects[enemy_sect].name) if snapshot.battle.enemy_id == "disciple" else "")
	hero_hp = int(snapshot.player.hp)
	hero_max_hp = int(snapshot.player.max_hp)
	enemy_hp = int(snapshot.battle.hp)
	enemy_max_hp = int(enemy_definition.hp)
	effect_font.font_names = PackedStringArray(["Microsoft YaHei", "Noto Sans CJK SC", "SimHei"])
	clip_contents = true
	mouse_filter = Control.MOUSE_FILTER_IGNORE
	add_child(world)
	hero = Actor.new()
	hero.configure(art.actors.hero, true)
	world.add_child(hero)
	enemy = Actor.new()
	enemy.configure(art.actors[enemy_id], false)
	world.add_child(enemy)
	resized.connect(_layout)
	_layout()

func _layout() -> void:
	if not is_instance_valid(hero):
		return
	hero.set_height(minf(size.y * float(art.actors.hero.height_ratio), maxf(0.0, size.y - 70.0)))
	enemy.set_height(minf(size.y * float(art.actors[enemy_id].height_ratio), maxf(0.0, size.y - 70.0)))
	hero.position = Vector2(size.x * 0.24, size.y * 0.94)
	enemy.position = Vector2(size.x * 0.76, size.y * 0.94)
	queue_redraw()

func _process(delta: float) -> void:
	phase += delta
	shake = maxf(0.0, shake - delta * 22.0)
	world.position = Vector2(sin(phase * 80) * shake, cos(phase * 67) * shake * 0.4) if motion_enabled else Vector2.ZERO
	flash_alpha = maxf(0.0, flash_alpha - delta * 2.4)
	queue_redraw()

func _draw() -> void:
	if background == null:
		return
	draw_texture_rect(background, Rect2(Vector2.ZERO, size), false)
	# Ground shadows remain separate from sprite art.
	for actor in [hero, enemy]:
		if actor == null:
			continue
		var width: float = actor.visual_height * (0.18 if actor == hero or enemy_id == "disciple" else 0.35)
		draw_set_transform(actor.position + Vector2(0, -5), 0, Vector2(1, 0.22))
		draw_circle(Vector2.ZERO, width, Color(0.1, 0.18, 0.14, 0.22))
	draw_set_transform(Vector2.ZERO)
	draw_rect(Rect2(0, 0, size.x, 54), Color(0.05, 0.12, 0.12, 0.8))
	_draw_health(Vector2(16, 9), size.x * 0.36, hero_name, hero_hp, hero_max_hp, Color("#90c49d"))
	_draw_health(Vector2(size.x * 0.64 - 16, 9), size.x * 0.36, enemy_name, enemy_hp, enemy_max_hp, Color("#d59075"))
	if not banner.is_empty():
		var text_size := effect_font.get_string_size(banner, HORIZONTAL_ALIGNMENT_LEFT, -1, 18)
		draw_rect(Rect2(size.x * 0.5 - text_size.x * 0.5 - 14, 62, text_size.x + 28, 32), Color(0.05, 0.12, 0.12, 0.72))
		draw_string(effect_font, Vector2(size.x * 0.5 - text_size.x * 0.5, 84), banner, HORIZONTAL_ALIGNMENT_LEFT, -1, 18, Color("#f3e4bd"))
	if flash_alpha > 0:
		draw_rect(Rect2(Vector2.ZERO, size), Color(1, 0.89, 0.65, flash_alpha))

func _draw_health(origin: Vector2, width: float, title: String, hp: int, maximum: int, color: Color) -> void:
	draw_string(effect_font, origin + Vector2(0, 15), "%s   %d / %d" % [title, hp, maximum], HORIZONTAL_ALIGNMENT_LEFT, -1, 15, Color("#f3eddd"))
	draw_rect(Rect2(origin + Vector2(0, 23), Vector2(width, 6)), Color("#243f3c"))
	draw_rect(Rect2(origin + Vector2(0, 23), Vector2(width * maxf(0, float(hp) / maximum), 6)), color)

func _emit_cue(kind: String) -> void:
	last_cue = kind
	cue_count += 1
	cue.emit(kind)

func _effect(kind: String, from: Vector2, to: Vector2, duration: float, color: Color, variation: int = 0) -> void:
	var effect = Effect.new()
	effect.setup(kind, from, to, duration, color, variation)
	world.add_child(effect)

func _number(actor, amount: int, healing: bool = false) -> void:
	var label := Label.new()
	label.text = ("+" if healing else "−") + str(amount)
	label.add_theme_font_override("font", effect_font)
	label.add_theme_font_size_override("font_size", 28)
	label.add_theme_color_override("font_color", Color("#8ff0a6") if healing else Color("#fff0cc"))
	label.add_theme_color_override("font_outline_color", Color("#322b28"))
	label.add_theme_constant_override("outline_size", 5)
	label.position = actor.chest() + Vector2(-12, -12)
	label.z_index = 8
	label.mouse_filter = Control.MOUSE_FILTER_IGNORE
	world.add_child(label)
	var tween := create_tween().set_parallel(true)
	tween.tween_property(label, "position:y", label.position.y - 65, 0.85).set_trans(Tween.TRANS_QUAD).set_ease(Tween.EASE_OUT)
	tween.tween_property(label, "modulate:a", 0.0, 0.85).set_delay(0.15)
	tween.chain().tween_callback(label.queue_free)

func _pause(seconds: float) -> void:
	await get_tree().create_timer(seconds).timeout

func play(events: Array[Dictionary]) -> void:
	busy = true
	# Container layout settles one frame after this stage is inserted.
	await get_tree().process_frame
	_layout()
	for event: Dictionary in events:
		match event.type:
			"attack":
				await _attack(event)
			"heal":
				var skill: Dictionary = skills.get(event.get("style", "wood"), skills.wood)
				var healing_profile: Dictionary = profiles[skill.vfx]
				banner = skill.name
				hero.set_pose("cast")
				_effect(healing_profile.kind, hero.chest(), hero.chest() + Vector2(0, 35), 0.85, Color(healing_profile.color))
				_emit_cue("heal")
				await _pause(0.3)
				hero_hp = int(event.hp_after)
				_number(hero, int(event.amount), true)
				await _pause(0.4)
				hero.set_pose("idle")
			"guard":
				var guard_skill: Dictionary = skills.get(event.get("style", ""), {})
				var sect: Dictionary = sects[hero_sect]
				banner = str(guard_skill.get("name", "凝神守御"))
				hero.set_pose("guard")
				_effect(sect.guard_vfx, hero.chest(), hero.chest(), 1.6, Color(sect.color))
				if event.has("hp_after"):
					hero_hp = int(event.hp_after)
					_number(hero, int(event.amount), true)
				_emit_cue("guard")
				await _pause(0.25)
			"end":
				banner = {"win": "斗法获胜", "lose": "斗法落败", "flee": "收势撤离"}.get(event.result, "")
				if event.result == "win":
					var tween := create_tween()
					tween.tween_property(enemy, "modulate:a", 0.0, 0.4)
				elif event.result == "lose":
					hero.set_pose("hit")
				_emit_cue(event.result)
				await _pause(0.55)
	banner = ""
	hero.set_pose("idle")
	enemy.set_pose("idle")
	busy = false

func _attack(event: Dictionary) -> void:
	var attacking = hero if event.actor == "player" else enemy
	var target = enemy if event.actor == "player" else hero
	var origin: Vector2 = attacking.position
	var target_home: Vector2 = target.position
	var push_direction: float = 1.0 if event.actor == "player" else -1.0
	var skill: Dictionary = skills.get(event.style, {})
	var visual_id: String = str(skill.get("vfx", event.style))
	var profile: Dictionary = profiles.get(visual_id, profiles.enemy)
	var color := Color(profile.color)
	var melee: bool = profile.delivery == "melee"
	var hit_count: int = int(skill.get("hits", 1))
	banner = str(skill.get("name", enemy_name)) + (" · 反击" if event.actor == "enemy" else "")
	attacking.idle_enabled = false
	attacking.set_pose(profile.prepare_pose)
	if not str(profile.charge).is_empty():
		_effect(profile.charge, attacking.chest(), attacking.chest(), float(profile.prepare) + 0.15, color)
	var prepare := create_tween().set_parallel(true)
	prepare.tween_property(attacking, "position:x", origin.x - push_direction * (10 if visual_id.begins_with("sword") else 3), float(profile.prepare)).set_trans(Tween.TRANS_QUAD)
	var stance_offset: float = 4.0 if visual_id in ["earth", "rock_spire"] else (-4.0 if visual_id in ["water", "ice_lance"] else 0.0)
	prepare.tween_property(attacking, "position:y", origin.y + stance_offset, float(profile.prepare))
	_emit_cue("prepare")
	await prepare.finished
	attacking.set_pose(profile.release_pose)
	var release := create_tween().set_parallel(true)
	var attack_x: float = target.position.x - push_direction * (target.visual_height * 0.25 + attacking.visual_height * 0.45) if melee else origin.x + push_direction * (18 if visual_id.begins_with("sword") else 5)
	release.tween_property(attacking, "position:x", attack_x, 0.12).set_trans(Tween.TRANS_QUAD).set_ease(Tween.EASE_OUT)
	release.tween_property(attacking, "position:y", origin.y, 0.12)
	var travel_time: float = float(profile.travel)
	# Effects begin before the cue, so frame capture and UI see the actual release.
	if not melee:
		_effect(profile.kind, attacking.chest(), target.chest(), travel_time + (0.3 if profile.delivery == "ground" else 0.0), color)
	_emit_cue("release")
	var before_hp: int = enemy_hp if event.actor == "player" else hero_hp
	var total: int = int(event.amount)
	for hit_index: int in range(hit_count):
		if hit_index > 0:
			attacking.set_pose(profile.release_pose)
			_effect(profile.kind, attacking.chest(), target.chest(), travel_time, color, hit_index)
			_emit_cue("release")
		await _pause(travel_time)
		var portion: int = total / hit_count + (1 if hit_index < total % hit_count else 0)
		before_hp = maxi(0, before_hp - portion)
		var displayed_hp: int = int(event.hp_after) if hit_index == hit_count - 1 else before_hp
		await _hit(target, target_home, event.actor == "player", portion, displayed_hp, push_direction, profile, color)
		if hit_index < hit_count - 1:
			await _pause(0.08)
	var recovery := create_tween()
	recovery.tween_property(attacking, "position", origin, 0.26).set_trans(Tween.TRANS_QUAD).set_ease(Tween.EASE_OUT)
	await _pause(0.28)
	attacking.position = origin
	target.position = target_home
	attacking.set_pose("idle")
	attacking.idle_enabled = true
	target.set_pose("idle")
	target.flash(0)
	await _pause(0.08)

func _hit(target, home: Vector2, enemy_target: bool, amount: int, hp_after: int, direction: float, profile: Dictionary, color: Color) -> void:
	if recoil_handle != null and recoil_handle.is_running():
		recoil_handle.kill()
	if flash_handle != null and flash_handle.is_running():
		flash_handle.kill()
	target.position = home
	target.set_pose("hit")
	target.flash(0.8, color.lightened(0.65))
	if enemy_target:
		enemy_hp = hp_after
	else:
		hero_hp = hp_after
	_number(target, amount)
	hit_resolved.emit(enemy_target, amount, hp_after)
	_effect(profile.impact, target.chest(), target.chest(), 0.48, color)
	shake = float(profile.shake) if motion_enabled else 0
	flash_alpha = 0.055 if profile.impact == "fire_explosion" and motion_enabled else 0
	_emit_cue("impact")
	await _pause(float(profile.hit_stop))
	recoil_handle = create_tween()
	recoil_handle.tween_property(target, "position:x", home.x + direction * float(profile.recoil), 0.06)
	recoil_handle.tween_property(target, "position:x", home.x, 0.18).set_trans(Tween.TRANS_QUAD).set_ease(Tween.EASE_OUT)
	flash_handle = create_tween()
	flash_handle.tween_method(func(value: float) -> void: target.flash(value, color.lightened(0.65)), 0.8, 0.0, 0.23)
	await _pause(0.1)
