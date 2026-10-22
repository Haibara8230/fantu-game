extends Control
## Plays a completed, authoritative turn as sequential readable animation events.
## Hit feel (after the common "game feel" practice): a freeze on each hit (hit-stop), screen shake from
## a decaying trauma with a kick along the blow, an impact frame and a push of the camera on heavy hits,
## the target squashed and knocked back, afterimages behind fast moves, damage numbers that pop (larger
## on a heavy hit), and a health bar that leaves a pale chip behind before it catches up. Textured
## particles (sprite_fx.gd) are layered over the vector effects; sounds vary by element and weight.
const ArtLibrary = preload("res://scripts/ui/art_library.gd")
const Actor = preload("res://scripts/presentation/actor.gd")
const Effect = preload("res://scripts/presentation/effect.gd")
const SpriteFx = preload("res://scripts/presentation/sprite_fx.gd")
const Storm = preload("res://scripts/presentation/storm.gd")
# The most the screen moves at full trauma, in pixels, and how fast trauma fades per second.
const SHAKE_PIXELS := 18.0
const TRAUMA_DECAY := 1.8
# Hit-stop bounds in seconds, and the share of a target's health that makes a hit heavy.
const HIT_STOP := Vector2(0.04, 0.18)
const HEAVY_SHARE := 0.15
# Sounds by the visual of an art: which element's release and impact it plays.
const SOUND_ELEMENTS := {"sword": "sword", "sword_rain": "sword", "sword_arc": "sword", "flame_bolt": "fire", "fire": "fire", "fire_burst": "fire", "vine": "wood", "leaf_blade": "wood", "water": "water", "ice_lance": "ice", "earth": "earth", "rock_spire": "earth", "spear": "sword", "hammer": "earth", "whip": "wood", "enemy": "beast"}
signal cue(kind: String)
## What to play on the sound bus: the cue, or a cue of its element and weight ("impact_fire").
signal sound(kind: String)
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
var enemy_names := {}
var enemy_max_hps := {}
var enemy_id := ""
var enemy_art: Dictionary = {}
var human_enemy := false
var tier_layers: Array = []
# Each sect's signature motif for its own arts (data/vfx_tiers.json "legacy").
var legacy_motifs: Dictionary = {}
var hero_name := ""
var enemy_name := ""
var hero_hp: int
var hero_max_hp: int
var enemy_hp: int
var enemy_max_hp: int
var phase := 0.0
# Screen shake: trauma (0–1, the shake grows with its square) and a kick along the last blow.
var trauma := 0.0
var kick := Vector2.ZERO
# Health shown as a pale chip behind each bar, catching up with the health after a moment.
var hero_chip := 0.0
var enemy_chip := 0.0
var chip_hold := 0.0
# The impact frame of a heavy hit: where it landed and until when (real milliseconds) it shows.
var impact_point := Vector2.ZERO
var impact_until := 0
var overlay := Node2D.new()
# 天劫's clouds and bolts (storm.gd), only for a tribulation.
var storm: Control = null
var busy := false
var motion_enabled := true
var last_cue := ""
var banner := ""
var cue_count := 0
var flash_alpha := 0.0
# The high tiers' staging: the stage tinted toward the art's color, darkened behind the duel with
# streaks, the camera pushed in toward the target, and the art's name in close-up.
var tint_color := Color.WHITE
var tint_alpha := 0.0
var backdrop_alpha := 0.0
var zoom := 0.0
var zoom_focus := Vector2.ZERO
var closeup := ""
var effect_font := SystemFont.new()

func configure(snapshot: Dictionary, enemy_definition: Dictionary) -> void:
	art = JSON.parse_string(FileAccess.get_file_as_string("res://data/art.json"))
	background = load(art_path(background_candidates(art, snapshot.battle)))
	var definitions: Dictionary = JSON.parse_string(FileAccess.get_file_as_string("res://data/world.json"))
	skills = definitions.skills
	enemy_names = {}
	for id: String in definitions.enemies:
		enemy_names[id] = str(definitions.enemies[id].name)
		enemy_max_hps[id] = int(definitions.enemies[id].hp)
	sects = definitions.sects
	profiles = JSON.parse_string(FileAccess.get_file_as_string("res://data/vfx.json"))
	hero_sect = snapshot.player.get("sect", "wanderer")
	enemy_sect = snapshot.battle.get("opponent_sect", "qingyun")
	enemy_id = snapshot.battle.enemy_id
	human_enemy = bool(enemy_definition.get("human", false))
	hero_name = snapshot.player.name + " · " + str(sects[hero_sect].name)
	enemy_name = enemy_definition.name + (" · " + str(sects[enemy_sect].name) if enemy_definition.get("human", false) else "")
	# A named foe (an avenger, an outlaw) goes by their own name.
	if snapshot.battle.has("title"):
		enemy_name = "%s · %s" % [snapshot.battle.title, enemy_definition.name]
	hero_hp = int(snapshot.player.hp)
	hero_max_hp = int(snapshot.player.max_hp)
	enemy_hp = int(snapshot.battle.hp)
	enemy_max_hp = int(enemy_definition.hp)
	hero_chip = hero_hp
	enemy_chip = enemy_hp
	effect_font.font_names = PackedStringArray(["Microsoft YaHei", "Noto Sans CJK SC", "SimHei"])
	clip_contents = true
	mouse_filter = Control.MOUSE_FILTER_IGNORE
	add_child(world)
	hero = Actor.new()
	hero.configure(art.actors.hero, true)
	world.add_child(hero)
	enemy = Actor.new()
	enemy_art = _enemy_art(enemy_id, snapshot.battle)
	enemy.configure(enemy_art, false)
	world.add_child(enemy)
	if enemy_id.begins_with("tribulation"):
		storm = Storm.new()
		add_child(storm)
	overlay.z_index = 20
	overlay.draw.connect(_draw_overlay)
	add_child(overlay)
	resized.connect(_layout)
	_layout()

## The first image path that exists, so art dropped into its folder replaces the shared fallback.
## The duel's backdrop, best first: the contest's stage (潜龙会, a 擂台大会 by contest), the place's own
## picture, a picture another place lends it (data/art.json `place_battle_art`), then the default.
static func background_candidates(art_config: Dictionary, battle: Dictionary) -> Array:
	var stages: Dictionary = art_config.get("stage_background", {})
	var context := str(battle.get("context", ""))
	var place := str(battle.get("place", ""))
	var candidates := []
	for key: String in ["%s:%s" % [context, str(battle.get("contest", ""))], context]:
		if stages.has(key):
			candidates.append(str(stages[key]))
	candidates.append(str(art_config.place_background) % place)
	if art_config.get("place_battle_art", {}).has(place):
		candidates.append(str(art_config.place_battle_art[place]))
	candidates.append(art_config.background)
	return candidates

static func art_path(candidates: Array) -> String:
	for path: Variant in candidates:
		if ResourceLoader.exists(str(path)):
			return str(path)
	return str(candidates.back())

## The opponent's atlas: a generated person's sect-and-gender look, a named foe's own sprite,
## else the shared one. Preferred atlases can carry their own frame registration.
func _enemy_art(id: String, battle: Dictionary) -> Dictionary:
	var definition: Dictionary = art.actors[id].duplicate()
	var foe: Dictionary = battle.get("foe", {})
	var candidates: Array = []
	if definition.has("look") and foe.has("sect") and foe.has("gender"):
		candidates.append(str(definition.look) % [foe.sect, foe.gender])
	if definition.has("preferred"):
		candidates.append(definition.preferred)
	candidates.append(definition.texture)
	return ArtLibrary.selected_actor(definition, art_path(candidates))

func _layout() -> void:
	if not is_instance_valid(hero):
		return
	hero.set_height(minf(size.y * float(art.actors.hero.height_ratio), maxf(0.0, size.y - 70.0)))
	enemy.set_height(minf(size.y * float(enemy_art.height_ratio), maxf(0.0, size.y - 70.0)))
	hero.position = Vector2(size.x * 0.24, size.y * 0.94)
	enemy.position = Vector2(size.x * 0.76, size.y * 0.94)
	if storm != null:
		storm.fit(size)
	queue_redraw()

func _process(delta: float) -> void:
	phase += delta
	trauma = maxf(0.0, trauma - delta * TRAUMA_DECAY)
	kick = kick.lerp(Vector2.ZERO, minf(1.0, delta * 14.0))
	var amount := trauma * trauma * SHAKE_PIXELS
	var offset := Vector2(sin(phase * 83.0) + sin(phase * 37.0) * 0.5, cos(phase * 71.0) * 0.6 + sin(phase * 29.0) * 0.3) * amount + kick if motion_enabled else Vector2.ZERO
	world.scale = Vector2.ONE * (1.0 + zoom)
	world.position = offset - zoom_focus * zoom
	flash_alpha = maxf(0.0, flash_alpha - delta * 2.4)
	chip_hold = maxf(0.0, chip_hold - delta)
	if chip_hold <= 0.0:
		hero_chip = move_toward(hero_chip, hero_hp, delta * hero_max_hp * 0.9)
		enemy_chip = move_toward(enemy_chip, enemy_hp, delta * enemy_max_hp * 0.9)
	queue_redraw()
	overlay.queue_redraw()

## Shake from a blow: trauma added (it adds up to 1), with a kick along `direction`.
func add_trauma(amount: float, direction: Vector2 = Vector2.ZERO) -> void:
	if not motion_enabled:
		return
	trauma = minf(1.0, trauma + amount)
	kick += direction * amount * 22.0

## Freezes the duel for `seconds` of real time (hit-stop): everything, tweens and effects included,
## all but stops, then resumes.
func _freeze(seconds: float) -> void:
	if seconds <= 0.0 or not is_inside_tree():
		return
	Engine.time_scale = 0.02
	await get_tree().create_timer(seconds, true, false, true).timeout
	Engine.time_scale = 1.0

func _exit_tree() -> void:
	Engine.time_scale = 1.0

## The impact frame over everything: the screen darkened for an instant, and lines bursting from where
## a heavy blow landed.
func _draw_overlay() -> void:
	if Time.get_ticks_msec() >= impact_until:
		return
	overlay.draw_rect(Rect2(Vector2.ZERO, size), Color(0.02, 0.02, 0.03, 0.55))
	var center := world.position + impact_point * world.scale
	for i: int in range(26):
		var axis := Vector2.from_angle(TAU * i / 26.0 + i * 0.37)
		var near := 40.0 + float(i % 4) * 22.0
		overlay.draw_line(center + axis * near, center + axis * (near + 160.0 + float(i % 3) * 90.0), Color(1, 1, 1, 0.85), 2.0 + float(i % 3), true)
	overlay.draw_circle(center, 26.0, Color(1, 1, 1, 0.9))

func _draw() -> void:
	if background == null:
		return
	draw_texture_rect(background, Rect2(Vector2.ZERO, size), false)
	if tint_alpha > 0:
		draw_rect(Rect2(Vector2.ZERO, size), Color(tint_color, tint_alpha))
	if backdrop_alpha > 0:
		draw_rect(Rect2(Vector2.ZERO, size), Color(0.02, 0.03, 0.05, backdrop_alpha))
		for i: int in range(14):
			var y := fmod(i * 53.0, size.y)
			var x := fmod(phase * 900.0 + i * 197.0, size.x + 240.0) - 120.0
			draw_line(Vector2(x, y), Vector2(x + 120 + (i % 3) * 40, y), Color(tint_color, backdrop_alpha * 0.5), 2)
	# Ground shadows remain separate from sprite art.
	for actor in [hero, enemy]:
		if actor == null:
			continue
		var width: float = actor.visual_height * (0.18 if actor == hero or human_enemy else 0.35)
		draw_set_transform(actor.position + Vector2(0, -5), 0, Vector2(1, 0.22))
		draw_circle(Vector2.ZERO, width, Color(0.1, 0.18, 0.14, 0.22))
	draw_set_transform(Vector2.ZERO)
	draw_rect(Rect2(0, 0, size.x, 54), Color(0.05, 0.12, 0.12, 0.8))
	_draw_health(Vector2(16, 9), size.x * 0.36, hero_name, hero_hp, hero_max_hp, Color("#90c49d"), hero_chip)
	_draw_health(Vector2(size.x * 0.64 - 16, 9), size.x * 0.36, enemy_name, enemy_hp, enemy_max_hp, Color("#d59075"), enemy_chip)
	if not banner.is_empty():
		var text_size := effect_font.get_string_size(banner, HORIZONTAL_ALIGNMENT_LEFT, -1, 18)
		draw_rect(Rect2(size.x * 0.5 - text_size.x * 0.5 - 14, 62, text_size.x + 28, 32), Color(0.05, 0.12, 0.12, 0.72))
		draw_string(effect_font, Vector2(size.x * 0.5 - text_size.x * 0.5, 84), banner, HORIZONTAL_ALIGNMENT_LEFT, -1, 18, Color("#f3e4bd"))
	if not closeup.is_empty():
		var closeup_size := effect_font.get_string_size(closeup, HORIZONTAL_ALIGNMENT_LEFT, -1, 36)
		var band := Rect2(0, size.y * 0.3 - 30, size.x, 52)
		draw_rect(band, Color(0.02, 0.03, 0.05, 0.6))
		draw_string(effect_font, Vector2(size.x * 0.5 - closeup_size.x * 0.5, size.y * 0.3 + 10), closeup, HORIZONTAL_ALIGNMENT_LEFT, -1, 36, Color(tint_color.lightened(0.5), 1.0))
	if flash_alpha > 0:
		draw_rect(Rect2(Vector2.ZERO, size), Color(1, 0.89, 0.65, flash_alpha))

func _draw_health(origin: Vector2, width: float, title: String, hp: int, maximum: int, color: Color, chip: float = -1.0) -> void:
	draw_string(effect_font, origin + Vector2(0, 15), "%s   %d / %d" % [title, hp, maximum], HORIZONTAL_ALIGNMENT_LEFT, -1, 15, Color("#f3eddd"))
	draw_rect(Rect2(origin + Vector2(0, 23), Vector2(width, 6)), Color("#243f3c"))
	if chip > hp:
		draw_rect(Rect2(origin + Vector2(0, 23), Vector2(width * clampf(chip / maximum, 0.0, 1.0), 6)), Color("#f6e6c4"))
	draw_rect(Rect2(origin + Vector2(0, 23), Vector2(width * maxf(0, float(hp) / maximum), 6)), color)

## A beat of the duel: `kind` for the duel's own watchers, and a sound — `voice` when it has its own
## (an element's release or impact), else the beat's.
func _emit_cue(kind: String, voice: String = "") -> void:
	last_cue = kind
	cue_count += 1
	cue.emit(kind)
	sound.emit(kind if voice.is_empty() else voice)

func _effect(kind: String, from: Vector2, to: Vector2, duration: float, color: Color, variation: int = 0, tier: int = 1) -> void:
	var effect = Effect.new()
	effect.setup(kind, from, to, duration, color, variation)
	effect.layers = _layers(tier)
	world.add_child(effect)

## A supporting layer (the charge, a rune circle, a sect's signature, a mark left behind, a glow).
func _layer(kind: String, at: Vector2, duration: float, color: Color, extra: Dictionary = {}) -> void:
	var effect = Effect.new()
	effect.setup(kind, at, at, duration, color)
	effect.extra = extra
	world.add_child(effect)

## Tier layers from data/vfx_tiers.json (tier 1 adds nothing).
func _layers(tier: int) -> Dictionary:
	if tier_layers.is_empty():
		var data: Dictionary = JSON.parse_string(FileAccess.get_file_as_string("res://data/vfx_tiers.json"))
		tier_layers = data.tiers
		legacy_motifs = data.get("legacy", {})
	return tier_layers[clampi(tier - 1, 0, tier_layers.size() - 1)]

## Sets the high tiers' staging (0 clears it) over `seconds`.
func _stage_mood(color: Color, tint: float, backdrop: float, seconds: float) -> void:
	tint_color = color
	var mood := create_tween().set_parallel(true)
	mood.tween_property(self, "tint_alpha", tint, seconds)
	mood.tween_property(self, "backdrop_alpha", backdrop, seconds)

## A number over an actor that pops in large and settles: a heavy hit's is bigger, golden and shaken.
func _number(actor, amount: int, healing: bool = false, heavy: bool = false, words: String = "") -> void:
	var label := Label.new()
	label.text = words if not words.is_empty() else ("+" if healing else "−") + str(amount) + ("！" if heavy else "")
	label.add_theme_font_override("font", effect_font)
	label.add_theme_font_size_override("font_size", 40 if heavy else 30)
	label.add_theme_color_override("font_color", Color("#9fd8ff") if not words.is_empty() else (Color("#8ff0a6") if healing else (Color("#ffd35c") if heavy else Color("#fff0cc"))))
	label.add_theme_color_override("font_outline_color", Color("#322b28"))
	label.add_theme_constant_override("outline_size", 7 if heavy else 5)
	label.position = actor.chest() + Vector2(-16 + randf_range(-14.0, 14.0), -20)
	label.z_index = 8
	label.mouse_filter = Control.MOUSE_FILTER_IGNORE
	label.pivot_offset = Vector2(24, 20)
	label.scale = Vector2.ONE * (2.0 if heavy else 1.6)
	world.add_child(label)
	var settle := create_tween()
	settle.tween_property(label, "scale", Vector2.ONE, 0.18).set_trans(Tween.TRANS_BACK).set_ease(Tween.EASE_OUT)
	var tween := create_tween().set_parallel(true)
	tween.tween_property(label, "position:y", label.position.y - 70, 0.9).set_trans(Tween.TRANS_QUAD).set_ease(Tween.EASE_OUT)
	tween.tween_property(label, "modulate:a", 0.0, 0.5).set_delay(0.45)
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
			"phase":
				# A boss changes its ways (combat.gd phases): its name over the stage and a shudder.
				banner = str(event.get("name", ""))
				enemy.squash(Vector2(1.08, 0.94), 0.5)
				_emit_cue("impact")
				await _pause(0.6)
			"heal":
				# Either side heals: the player's arts and pills, a generated opponent's arts.
				var foe_side: bool = event.get("actor", "player") == "enemy"
				var healer = enemy if foe_side else hero
				var skill: Dictionary = skills.get(event.get("style", "wood"), skills.wood)
				var healing_profile: Dictionary = profiles.get(str(event.get("vfx", skill.vfx)), profiles.heal)
				banner = str(event.get("name", skill.name))
				healer.set_pose("cast")
				_effect(healing_profile.kind, healer.chest(), healer.chest() + Vector2(0, 35), 0.85, Color(healing_profile.color), 0, int(event.get("tier", 1)))
				SpriteFx.play(world, healer.chest(), SpriteFx.recipes().get("heal", []), Color(healing_profile.color))
				healer.squash(Vector2(0.96, 1.05), 0.4)
				_emit_cue("heal")
				await _pause(0.3)
				if foe_side:
					enemy_hp = int(event.hp_after)
				else:
					hero_hp = int(event.hp_after)
				_number(healer, int(event.amount), true)
				await _pause(0.4)
				healer.set_pose("idle")
			"guard":
				var foe_guard: bool = event.get("actor", "player") == "enemy"
				var guarding = enemy if foe_guard else hero
				var guard_skill: Dictionary = skills.get(event.get("style", ""), {})
				var sect: Dictionary = sects[enemy_sect if foe_guard else hero_sect]
				banner = str(event.get("name", guard_skill.get("name", "凝神守御")))
				guarding.set_pose("guard")
				_effect(sect.guard_vfx, guarding.chest(), guarding.chest(), 1.6, Color(sect.color), 0, int(event.get("tier", 1)))
				SpriteFx.play(world, guarding.chest(), SpriteFx.recipes().get("guard", []), Color(sect.color))
				guarding.squash(Vector2(1.06, 0.95), 0.3)
				if int(event.get("shield", 0)) > 0:
					_number(guarding, int(event.shield), true, false, "护盾 %d" % int(event.shield))
				_emit_cue("guard")
				await _pause(0.25)
				guarding.set_pose("idle")
			"fell":
				# 群敌: one of the pack falls (the lead fades; the next steps up in "next_foe").
				banner = "%s 倒下" % enemy_names.get(str(event.enemy_id), "")
				_emit_cue("impact")
				await _pause(0.45)
			"next_foe":
				var fade := create_tween()
				fade.tween_property(enemy, "modulate:a", 0.0, 0.2)
				await fade.finished
				enemy_name = enemy_names.get(str(event.enemy_id), enemy_name)
				enemy_max_hp = int(enemy_max_hps.get(str(event.enemy_id), enemy_max_hp))
				enemy_hp = int(event.hp_after)
				enemy_chip = enemy_hp
				banner = "%s 顶了上来" % enemy_name
				var back := create_tween()
				back.tween_property(enemy, "modulate:a", 1.0, 0.25)
				await _pause(0.5)
			"combo":
				# 连击: the art followed one of the element its combo names.
				banner = "连击 · %s" % str(event.name)
				_emit_cue("chain")
				await _pause(0.4)
			"lead":
				# 遁速: the quicker opponent moves first.
				banner = "对手遁速更快，抢先出手"
				await _pause(0.6)
			"spirit":
				# 印 and 聚气: qi turned or gathered, no blow.
				hero.set_pose("cast")
				banner = str(event.get("name", ""))
				await _pause(0.35)
			"end":
				banner = {"win": "斗法获胜", "lose": "斗法落败", "flee": "收势撤离"}.get(event.result, "")
				if event.result == "win":
					SpriteFx.play(world, enemy.chest(), SpriteFx.recipes().get("dust", []), Color.WHITE, Vector2.UP, 1.4)
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
	var visual_id: String = str(event.get("vfx", skill.get("vfx", event.style)))
	var tier: int = int(event.get("tier", 1))
	var layers := _layers(tier)
	var profile: Dictionary = profiles.get(visual_id, profiles.enemy)
	var color := Color(profile.color)
	var melee: bool = profile.delivery == "melee"
	var hit_count: int = int(event.get("hits", skill.get("hits", 1)))
	var art_name: String = str(event.get("name", skill.get("name", enemy_name)))
	var lineage: String = str(event.get("legacy", ""))
	banner = art_name + (" · 传承" if not lineage.is_empty() else "") + (" · 反击" if event.actor == "enemy" else "") + {"克": " · 克制", "被克": " · 被克"}.get(str(event.get("counter", "")), "")
	# From 玄阶 an art gathers before it is released; from 地阶 a rune circle opens under the caster and
	# the stage takes the art's color; at 天阶 the duel darkens, slows and the camera pushes in.
	var charge := float(layers.get("charge", 0.0))
	var slow := float(layers.get("slow", 0.0))
	var prepare_time := float(profile.prepare) + charge
	var travel_time: float = float(profile.travel) * (1.0 + slow)
	attacking.idle_enabled = false
	attacking.set_pose(profile.prepare_pose)
	if not str(profile.charge).is_empty():
		_effect(profile.charge, attacking.chest(), attacking.chest(), prepare_time + 0.15, color)
	if prepare_time >= 0.25:
		SpriteFx.play(world, attacking.chest(), SpriteFx.recipes().get("charge", []), color, Vector2.RIGHT * push_direction, 0.8 + prepare_time)
	attacking.squash(Vector2(0.94, 1.06), prepare_time + 0.1)
	if charge > 0:
		_layer("gather", attacking.chest(), prepare_time, color, {"count": int(layers.get("swarm", 10))})
	if int(layers.get("rune", 0)) > 0:
		_layer("array", attacking.position + Vector2(0, -6), prepare_time + travel_time + 0.5, color, {"count": int(layers.rune)})
	if not lineage.is_empty() and sects.has(lineage):
		_layer("legacy", attacking.chest(), prepare_time + travel_time + 0.4, Color(sects[lineage].color), {"motif": str(legacy_motifs.get(lineage, ""))})
	if float(layers.get("tint", 0.0)) > 0 or float(layers.get("backdrop", 0.0)) > 0:
		_stage_mood(color, float(layers.get("tint", 0.0)), float(layers.get("backdrop", 0.0)), prepare_time)
	if float(layers.get("backdrop", 0.0)) > 0:
		closeup = art_name
	var prepare := create_tween().set_parallel(true)
	prepare.tween_property(attacking, "position:x", origin.x - push_direction * (10 if visual_id.begins_with("sword") else 3), prepare_time).set_trans(Tween.TRANS_QUAD)
	var stance_offset: float = 4.0 if visual_id in ["earth", "rock_spire"] else (-4.0 if visual_id in ["water", "ice_lance"] else 0.0)
	prepare.tween_property(attacking, "position:y", origin.y + stance_offset, prepare_time)
	_emit_cue("prepare", "prepare_sword" if visual_id.begins_with("sword") else "prepare")
	await prepare.finished
	attacking.set_pose(profile.release_pose)
	# A 天雷 comes down from the clouds onto its mark.
	if storm != null and event.actor == "enemy":
		storm.strike(world.position + target.chest() * world.scale)
	var aim: Vector2 = (target.chest() - attacking.chest()).normalized()
	# The release: a stretch toward the target, a flash at the hand, afterimages behind a fast move.
	attacking.squash(Vector2(1.12, 0.92), 0.2)
	SpriteFx.play(world, attacking.chest() + aim * attacking.visual_height * 0.2, SpriteFx.recipe("release", visual_id), color, aim)
	if melee or visual_id.begins_with("sword"):
		for ghost: int in range(3):
			get_tree().create_timer(0.03 * ghost).timeout.connect(func() -> void:
				if is_instance_valid(attacking):
					attacking.afterimage(world, color))
	if melee:
		SpriteFx.play(world, attacking.position, SpriteFx.recipes().get("dust", []), Color.WHITE, Vector2.RIGHT * push_direction)
	var release := create_tween().set_parallel(true)
	var attack_x: float = target.position.x - push_direction * (target.visual_height * 0.25 + attacking.visual_height * 0.45) if melee else origin.x + push_direction * (18 if visual_id.begins_with("sword") else 5)
	release.tween_property(attacking, "position:x", attack_x, 0.12).set_trans(Tween.TRANS_QUAD).set_ease(Tween.EASE_OUT)
	release.tween_property(attacking, "position:y", origin.y, 0.12)
	if float(layers.get("zoom", 0.0)) > 0 and motion_enabled:
		zoom_focus = target.chest()
		create_tween().tween_property(self, "zoom", float(layers.zoom), travel_time * 0.8).set_trans(Tween.TRANS_SINE)
	# Effects begin before the cue, so frame capture and UI see the actual release.
	if not melee:
		_effect(profile.kind, attacking.chest(), target.chest(), travel_time + (0.3 if profile.delivery == "ground" else 0.0), color, 0, tier)
		if profile.delivery != "ground":
			SpriteFx.trail(world, attacking.chest(), target.chest(), travel_time, SpriteFx.recipe("trail", visual_id), color, float(layers.get("scale", 1.0)))
	# The highest tier's own sound layer, under the release.
	if float(layers.get("surge", 0.0)) > 0:
		_emit_cue("surge")
	_emit_cue("release", "release_" + str(SOUND_ELEMENTS.get(visual_id, "beast")))
	var before_hp: int = enemy_hp if event.actor == "player" else hero_hp
	var total: int = int(event.amount)
	for hit_index: int in range(hit_count):
		if hit_index > 0:
			attacking.set_pose(profile.release_pose)
			_effect(profile.kind, attacking.chest(), target.chest(), travel_time, color, hit_index, tier)
			if not melee and profile.delivery != "ground":
				SpriteFx.trail(world, attacking.chest(), target.chest(), travel_time, SpriteFx.recipe("trail", visual_id), color, float(layers.get("scale", 1.0)))
			_emit_cue("release", "release_" + str(SOUND_ELEMENTS.get(visual_id, "beast")))
		await _pause(travel_time)
		var portion: int = total / hit_count + (1 if hit_index < total % hit_count else 0)
		before_hp = maxi(0, before_hp - portion)
		var displayed_hp: int = int(event.hp_after) if hit_index == hit_count - 1 else before_hp
		if hit_index == 0 and int(event.get("absorbed", 0)) > 0:
			_number(target, int(event.absorbed), false, false, "护盾 −%d" % int(event.absorbed))
		await _hit(target, target_home, event.actor == "player", portion, displayed_hp, push_direction, profile, color, layers, str(event.get("element", "")), visual_id, tier)
		if hit_index < hit_count - 1:
			await _pause(0.08)
	if zoom > 0 or tint_alpha > 0 or backdrop_alpha > 0:
		closeup = ""
		_stage_mood(tint_color, 0.0, 0.0, 0.3)
		create_tween().tween_property(self, "zoom", 0.0, 0.3).set_trans(Tween.TRANS_SINE)
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

func _hit(target, home: Vector2, enemy_target: bool, amount: int, hp_after: int, direction: float, profile: Dictionary, color: Color, layers: Dictionary = {}, element: String = "", visual_id: String = "", tier: int = 1) -> void:
	if recoil_handle != null and recoil_handle.is_running():
		recoil_handle.kill()
	if flash_handle != null and flash_handle.is_running():
		flash_handle.kill()
	var maximum: int = enemy_max_hp if enemy_target else hero_max_hp
	# A heavy blow: a large share of the target's health, a high tier, or a weighty art.
	var heavy: bool = float(amount) >= float(maximum) * HEAVY_SHARE or tier >= 4 or float(profile.hit_stop) >= 0.08
	target.position = home
	target.set_pose("hit")
	target.flash(1.0, color.lightened(0.75))
	target.squash(Vector2(1.18, 0.84) if heavy else Vector2(1.1, 0.9), 0.26)
	chip_hold = 0.35
	if enemy_target:
		enemy_hp = hp_after
	else:
		hero_hp = hp_after
	# A blow the shield took whole shows only the shield's number.
	if amount > 0:
		_number(target, amount, false, heavy)
	hit_resolved.emit(enemy_target, amount, hp_after)
	_effect(profile.impact, target.chest(), target.chest(), 0.48, color)
	var blow := Vector2(direction, -0.15).normalized()
	var size := float(layers.get("scale", 1.0)) * (1.25 if heavy else 1.0)
	SpriteFx.play(world, target.chest(), SpriteFx.recipe("impact", str(profile.impact)), color, blow, size)
	if heavy:
		SpriteFx.play(world, target.chest(), SpriteFx.recipes().get("heavy", []), color, blow, size)
		if motion_enabled:
			impact_point = target.chest()
			impact_until = Time.get_ticks_msec() + 70
	if float(layers.get("residue", 0.0)) > 0:
		_layer("residue", target.chest(), float(layers.residue), color, {"element": element})
	if float(layers.get("bloom", 0.0)) > 0:
		_layer("bloom", target.chest(), 0.6, color, {"strength": float(layers.bloom)})
	add_trauma(clampf(float(profile.shake) * float(layers.get("shake", 1.0)) * 0.09, 0.15, 0.6) + (0.25 if heavy else 0.0), blow)
	flash_alpha = (0.055 if profile.impact == "fire_explosion" else 0.0) + float(layers.get("flash", 0.0)) + (0.06 if heavy else 0.0) if motion_enabled else 0.0
	if heavy and motion_enabled and zoom < 0.02:
		zoom_focus = target.chest()
		var punch := create_tween()
		punch.tween_property(self, "zoom", 0.035, 0.05)
		punch.tween_property(self, "zoom", 0.0, 0.22).set_trans(Tween.TRANS_SINE)
	_emit_cue("impact", "impact_" + str(SOUND_ELEMENTS.get(visual_id, "beast")))
	if heavy:
		sound.emit("impact_heavy")
	var stop := clampf(float(profile.hit_stop) * (1.0 + float(layers.get("slow", 0.0)) * 2.0) + (0.05 if heavy else 0.0), HIT_STOP.x, HIT_STOP.y)
	await _freeze(stop)
	recoil_handle = create_tween()
	var knock := float(profile.recoil) * (1.6 if heavy else 1.0)
	recoil_handle.tween_property(target, "position:x", home.x + direction * knock, 0.07).set_trans(Tween.TRANS_QUAD).set_ease(Tween.EASE_OUT)
	recoil_handle.tween_property(target, "position:x", home.x, 0.22).set_trans(Tween.TRANS_BACK).set_ease(Tween.EASE_OUT)
	if heavy:
		SpriteFx.play(world, target.position, SpriteFx.recipes().get("dust", []), Color.WHITE, Vector2(direction, 0), 0.9)
	flash_handle = create_tween()
	flash_handle.tween_method(func(value: float) -> void: target.flash(value, color.lightened(0.75)), 1.0, 0.0, 0.2)
	await _pause(0.1)
