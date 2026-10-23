extends Control
## Presentation only. Reservations never change the authoritative hand or random stream.
const Art = preload("res://scripts/ui/art_library.gd")
const Settings = preload("res://scripts/ui/settings.gd")
const QiMotion = preload("res://scripts/presentation/qi_motion.gd")
const ELEMENTS := ["metal", "water", "wood", "fire", "earth"]
const POOL := {"metal": Vector2(887, 77), "water": Vector2(940, 116), "wood": Vector2(920, 172), "fire": Vector2(850, 172), "earth": Vector2(833, 116)}
const CENTER := Vector2(655, 125)
# The extracted art has a wider dock than the approved full-screen mockup. Register the entire
# ornament/control group back to that mockup, rather than enlarging the approved left/right panels.
const REGISTER_SCALE := 0.85
const REGISTER_OFFSET := Vector2(84, 34.5)
var ui
var canvas := Control.new()
var controls := Control.new()
var flight_layer := Control.new()
var held: Array = []
var reserved: Array = []
var pool_reserved: Array = []
var flights: Array[Dictionary] = []
var art_buttons: Array[Button] = []
var pool_buttons: Dictionary = {}
var payment_buttons: Dictionary = {}
var confirm: Button
var cancel: Button
var turn_label: Label
var count_label: Label
var payment_hint: Label
var selected := ""
var busy := false
var pulse := 0.0
var motion: Dictionary = {}
var inscription := SystemFont.new()

func configure(owner_ui) -> void:
	ui = owner_ui
	inscription.font_names = PackedStringArray(["KaiTi", "STKaiti", "Microsoft YaHei"])
	var parsed: Variant = JSON.parse_string(FileAccess.get_file_as_string("res://data/battle_presentation.json"))
	motion = parsed if parsed is Dictionary else {}
	held = ui.session.battle.get("orbs", []).duplicate()
	selected = ui.battle_selection
	reserved = ui.battle_payment.duplicate()
	pool_reserved = reserved.duplicate()
	mouse_filter = Control.MOUSE_FILTER_IGNORE
	canvas.mouse_filter = Control.MOUSE_FILTER_IGNORE
	canvas.size = Vector2(1280, 230)
	add_child(canvas)
	var art := TextureRect.new()
	art.texture = Art.texture("res://assets/art/ui/battle/dock_v6.png")
	art.position = Vector2(0, -490)
	art.size = Vector2(1280, 720)
	art.expand_mode = TextureRect.EXPAND_IGNORE_SIZE
	art.mouse_filter = Control.MOUSE_FILTER_IGNORE
	var art_clip := Control.new()
	art_clip.position = REGISTER_OFFSET + Vector2(0, -40) * REGISTER_SCALE
	art_clip.scale = Vector2.ONE * REGISTER_SCALE
	art_clip.size = Vector2(1280, 270)
	art_clip.clip_contents = true
	art_clip.mouse_filter = Control.MOUSE_FILTER_IGNORE
	canvas.add_child(art_clip)
	art.position.y = -450
	art_clip.add_child(art)
	controls.mouse_filter = Control.MOUSE_FILTER_IGNORE
	controls.scale = Vector2.ONE * REGISTER_SCALE
	controls.position = REGISTER_OFFSET
	canvas.add_child(controls)
	flight_layer.mouse_filter = Control.MOUSE_FILTER_IGNORE
	flight_layer.scale = Vector2.ONE * REGISTER_SCALE
	flight_layer.position = REGISTER_OFFSET
	canvas.add_child(flight_layer)
	flight_layer.draw.connect(_draw_flights)
	resized.connect(_layout)
	_build()
	_layout()
	refresh()

func _layout() -> void:
	canvas.scale = Vector2.ONE * size.x / 1280.0
	canvas.position = Vector2(0, size.y - 230 * canvas.scale.y)

func _process(delta: float) -> void:
	pulse += delta
	flight_layer.queue_redraw()

func _button(text: String, at: Vector2, extent: Vector2, callback: Callable, tip: String = "") -> Button:
	var button: Button = ui.button(text, callback, tip)
	button.custom_minimum_size = Vector2.ZERO
	button.position = at
	button.size = extent
	button.add_theme_font_size_override("font_size", 16)
	button.add_theme_font_override("font", inscription)
	button.add_theme_color_override("font_color", Color("#e7d9a5"))
	for state: String in ["normal", "hover", "pressed", "disabled", "focus"]:
		button.add_theme_stylebox_override(state, StyleBoxEmpty.new())
	controls.add_child(button)
	return button

func _build() -> void:
	var session = ui.session
	var skills: Array[String] = session.active_skills()
	for index: int in 10:
		var at := Vector2(216 + (index % 5) * 65.5, 83 + (index / 5) * 67.5)
		var id: String = skills[index] if index < skills.size() else ""
		var button := _button("", at, Vector2(59, 59), func() -> void:
			if not id.is_empty():
				ui.skill(id))
		button.name = "ArtSlot%d" % (index + 1)
		var frame := StyleBoxFlat.new()
		frame.bg_color = Color(0.05, 0.13, 0.1, 0.15)
		frame.border_color = Color("#a89955")
		frame.set_border_width_all(0)
		frame.set_corner_radius_all(3)
		button.add_theme_stylebox_override("normal", frame)
		var hover := frame.duplicate()
		hover.border_color = Color("#f5d783")
		hover.set_border_width_all(2)
		button.add_theme_stylebox_override("hover", hover)
		button.add_theme_stylebox_override("focus", hover)
		var icon := TextureRect.new()
		icon.position = Vector2(2, 2)
		icon.size = Vector2(55, 55)
		icon.expand_mode = TextureRect.EXPAND_IGNORE_SIZE
		icon.mouse_filter = Control.MOUSE_FILTER_IGNORE
		button.add_child(icon)
		if not id.is_empty():
			var skill: Dictionary = session.held_technique(id)
			icon.texture = Art.technique_icon(skill)
			button.tooltip_text = "%s\n%s\n耗灵气：%s\n%s\n点击选招，再配气确认；再次点击切换配气。" % [skill.name, skill.tier_name, session.Arsenal.cost_text(session.content, skill.cost), skill.description]
			var key: Label = ui.label(Settings.key_name(ui, "skill_%d" % (index + 1)), 12, Color("#f4dfa2"))
			key.position = Vector2(3, 0)
			key.mouse_filter = Control.MOUSE_FILTER_IGNORE
			button.add_child(key)
		art_buttons.append(button)
	var release: Dictionary = session.Combat.release_of(session)
	var weapon := _button("", Vector2(113, 111), Vector2(59, 59), func() -> void: ui.battle_action("release"), "兵刃 · 祭出（D）")
	weapon.name = "WeaponRelease"
	var weapon_id := str(session.player.equipment.get("weapon", ""))
	if not weapon_id.is_empty():
		var icon := TextureRect.new()
		icon.texture = Art.gear_icon(session.gear_item(weapon_id))
		icon.expand_mode = TextureRect.EXPAND_IGNORE_SIZE
		icon.size = Vector2(57, 57)
		icon.mouse_filter = Control.MOUSE_FILTER_IGNORE
		weapon.add_child(icon)
	weapon.disabled = release.is_empty() or not session.Combat.release_block(session).is_empty()
	weapon.tooltip_text = session.Combat.release_block(session) if weapon.disabled else "祭出 · %s（D），约 %d 点伤害，余 %d 次" % [release.name, int(release.damage), int(release.left)]
	var weapon_key: Label = ui.label("D", 13, ui.GOLD)
	weapon.add_child(weapon_key)
	cancel = _button("取消", Vector2(571, 33), Vector2(83, 37), ui.cancel_battle_selection, "取消配气（Esc），不消耗灵气")
	cancel.rotation = -0.28
	confirm = _button("确定", Vector2(668, 6), Vector2(83, 37), ui.confirm_battle_selection, "确认当前配气（空格）")
	confirm.rotation = 0.28
	for element: String in ELEMENTS:
		var pool := _button("", POOL[element] - Vector2(22, 24), Vector2(44, 53), func() -> void: ui.battle_orb(element), "")
		pool.name = "QiPool_" + element
		var icon := Art.icon_rect("orbs/" + element, 35)
		icon.size = Vector2(35, 35)
		icon.position = Vector2(4, 0)
		icon.mouse_filter = Control.MOUSE_FILTER_IGNORE
		pool.add_child(icon)
		var count: Label = ui.label("0", 18, Color("#f5edcf"))
		count.position = Vector2(0, 30)
		count.size.x = 44
		count.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
		count.mouse_filter = Control.MOUSE_FILTER_IGNORE
		pool.add_child(count)
		pool_buttons[element] = {"button": pool, "icon": icon, "count": count}
		pool.gui_input.connect(func(event: InputEvent) -> void:
			if event is InputEventMouseButton and event.pressed and event.button_index == MOUSE_BUTTON_RIGHT:
				ui.battle_orb(element, true)
				pool.accept_event())
		var payment := _button("", CENTER, Vector2(44, 60), func() -> void: ui.battle_unreserve(element), "点击退回一颗灵气")
		var pay_icon := Art.icon_rect("orbs/" + element, 38)
		pay_icon.mouse_filter = Control.MOUSE_FILTER_IGNORE
		payment.add_child(pay_icon)
		var pay_count: Label = ui.label("", 18, Color("#fff1bf"))
		pay_count.position = Vector2(0, 35)
		pay_count.size.x = 38
		pay_count.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
		pay_count.mouse_filter = Control.MOUSE_FILTER_IGNORE
		payment.add_child(pay_count)
		payment_buttons[element] = {"button": payment, "icon": pay_icon, "count": pay_count}
	turn_label = ui.label("", 15, Color("#e7d9ac"))
	turn_label.position = Vector2(564, 99)
	turn_label.size = Vector2(182, 66)
	turn_label.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	turn_label.mouse_filter = Control.MOUSE_FILTER_IGNORE
	controls.add_child(turn_label)
	payment_hint = ui.label("", 15, Color("#efcf7d"))
	payment_hint.position = Vector2(567, 181)
	payment_hint.size = Vector2(176, 27)
	payment_hint.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	payment_hint.mouse_filter = Control.MOUSE_FILTER_PASS
	controls.add_child(payment_hint)
	count_label = ui.label("", 16, Color("#e5d49d"))
	count_label.position = Vector2(982, 72)
	count_label.tooltip_text = "回合末最多保留 %d 颗灵气" % session.Combat.hand_cap(session)
	controls.add_child(count_label)
	_button("记录", Vector2(993, 185), Vector2(44, 30), ui.toggle_battle_record, "查看斗法记录")
	_button("探查", Vector2(1043, 185), Vector2(44, 30), ui.toggle_battle_scout, "神识探查")
	_button("更多", Vector2(1093, 185), Vector2(44, 30), ui.toggle_battle_more, "撤离、符箓、求援和特殊招式")

func refresh() -> void:
	var session = ui.session
	if session.battle.is_empty():
		confirm.disabled = true
		cancel.disabled = true
		turn_label.text = "斗法结束"
		for button: Button in art_buttons:
			button.disabled = true
		return
	var locked: bool = busy or ui.presenting
	var skills: Array[String] = session.active_skills()
	for index: int in art_buttons.size():
		var id: String = skills[index] if index < skills.size() else ""
		var button := art_buttons[index]
		button.disabled = locked or ui.battle_discarding or id.is_empty()
		if not id.is_empty():
			var art: Dictionary = session.held_technique(id)
			var reason: String = session.Combat.skill_block(session, art)
			var affordable: bool = session.Combat.affordable(held, art.cost) and reason.is_empty()
			button.disabled = button.disabled or not affordable
			button.tooltip_text = "%s\n%s%s" % [art.name, art.description, "\n" + reason if not reason.is_empty() else ""]
			button.get_child(0).modulate = Color(1, 1, 1, 1) if affordable else Color(0.38, 0.43, 0.4, 1)
			button.modulate = Color("#ffe5a4") if id == selected else Color.WHITE
	var groups: Array = ELEMENTS.filter(func(e: String) -> bool: return reserved.count(e) > 0)
	for element: String in ELEMENTS:
		var pool: Dictionary = pool_buttons[element]
		var count: int = held.count(element) - pool_reserved.count(element)
		pool.count.text = str(count)
		pool.icon.modulate.a = 1.0 if count > 0 else 0.2
		pool.button.disabled = locked or count <= 0 or (selected.is_empty() and not ui.battle_discarding)
		pool.button.tooltip_text = "%s灵气 %d 颗；%s" % [session.content.element_info(element).name, count, "点击配入中央" if not selected.is_empty() else "点击散去一颗，右键按需批量散去" if ui.battle_discarding else "选招后点击配气；结束回合时选择消散"]
		var payment: Dictionary = payment_buttons[element]
		payment.button.visible = element in groups
		payment.button.disabled = locked
		if element in groups:
			var diameter := minf(38, 150.0 / groups.size())
			payment.button.position = CENTER + Vector2((groups.find(element) - (groups.size() - 1) * 0.5) * minf(49, 164.0 / groups.size()) - diameter * 0.5, -25)
			payment.icon.custom_minimum_size = Vector2.ONE * diameter
			payment.icon.size = Vector2.ONE * diameter
			payment.count.position.y = diameter - 3
			payment.count.size.x = diameter
			payment.count.text = str(reserved.count(element))
	var cap: int = session.Combat.hand_cap(session)
	count_label.text = "%d/%d" % [held.size(), cap]
	if is_instance_valid(ui.battle_stage):
		ui.battle_stage.hero_qi = held.size()
		ui.battle_stage.qi_cap = cap
	cancel.visible = not selected.is_empty() or ui.battle_discarding
	confirm.text = "确定" if not selected.is_empty() or ui.battle_discarding else "回合结束"
	cancel.disabled = locked
	confirm.disabled = locked
	payment_hint.text = ""
	payment_hint.tooltip_text = ""
	if not selected.is_empty():
		var art: Dictionary = session.held_technique(selected)
		var reason: String = session.Combat.skill_block(session, art)
		var valid: bool = session.Combat.payment_valid(held, art.cost, reserved)
		confirm.disabled = locked or not valid or not reason.is_empty()
		if valid:
			var preview: Dictionary = session.Combat.payment_preview(session, art, reserved)
			payment_hint.text = " · ".join(preview.triggers.map(func(key: String) -> String: return "【%s】" % session.Combat.QiRelations.LABELS[key]))
			payment_hint.tooltip_text = session.Combat.QiRelations.describe(art, session.content.technique_data.elements)
		if not reason.is_empty():
			payment_hint.text = "条件未满足"
			payment_hint.tooltip_text = reason
	elif ui.battle_discarding:
		confirm.disabled = locked or held.size() > cap
	turn_label.visible = selected.is_empty()
	turn_label.text = "消散灵气\n还需散去 %d 颗" % maxi(0, held.size() - cap) if ui.battle_discarding else "第 %d 回合\n选 择 神 通" % int(session.battle.turn)
	flight_layer.queue_redraw()

func set_payment(skill_id: String, payment: Array) -> void:
	busy = true
	flights.clear()
	var returning := reserved.duplicate()
	var entering := payment.duplicate()
	for element: Variant in reserved:
		if element in entering:
			entering.erase(element)
			returning.erase(element)
	selected = skill_id
	reserved = payment.duplicate()
	refresh()
	await _batch(returning, "return", false)
	await _batch(entering, "reserve", false)
	pool_reserved = payment.duplicate()
	busy = false
	refresh()

func play_event(event: Dictionary) -> void:
	if event.get("actor", "player") != "player":
		ui.battle_stage.enemy_qi = maxi(0, ui.battle_stage.enemy_qi + event.orbs.size() * (1 if event.type == "draw" else -1))
		await _batch(event.orbs, str(event.type), true, true)
		return
	busy = true
	refresh()
	match str(event.type):
		"draw":
			held.append_array(event.orbs)
		"discard":
			for element: String in event.orbs:
				held.erase(element)
		"spend":
			flights.clear()
			for element: String in event.orbs:
				held.erase(element)
			pool_reserved.clear()
			selected = ""
			refresh()
			if ui.battle_stage.motion_enabled and not reserved.is_empty():
				var fade := create_tween().set_parallel(true)
				var seconds := clampf(float(motion.profiles.spend.get("icon_fade", 0.033333)), 0.001, 0.2)
				for value: Dictionary in payment_buttons.values():
					if value.button.visible:
						fade.tween_property(value.button, "modulate:a", 0.0, seconds)
						fade.tween_property(value.button, "scale", Vector2.ONE * 0.35, seconds)
				await fade.finished
			reserved.clear()
			for value: Dictionary in payment_buttons.values():
				value.button.modulate.a = 1.0
				value.button.scale = Vector2.ONE
	refresh()
	await _batch(event.orbs, str(event.type), true)
	busy = false
	refresh()

func _batch(orbs: Array, kind: String, finish: bool, enemy: bool = false) -> void:
	if orbs.is_empty() or (is_instance_valid(ui.battle_stage) and not ui.battle_stage.motion_enabled):
		return
	var profile: Dictionary = motion.get("profiles", {}).get(kind, {})
	var duration := clampf(float(profile.get("duration", 0.6)), 0.05, 2.0)
	var batch: Array[Dictionary] = []
	for index: int in orbs.size():
		var element := str(orbs[index])
		var origin: Vector2 = POOL[element]
		var target := CENTER
		var fan := float(index % 5 - 2)
		match kind:
			"return":
				origin = CENTER
				target = POOL[element]
			"draw":
				target = origin
				origin += Vector2(fan * 18, -240)
			"spend":
				origin = CENTER
				target = CENTER + Vector2(fan * 18, -180)
			"discard":
				target = origin + Vector2(fan * 18, -140)
		if enemy:
			target = Vector2(1200, -450) if kind == "draw" else Vector2(1010 + fan * 18, -620)
			origin = Vector2(1080 + fan * 18, -680) if kind == "draw" else Vector2(1200, -450)
		var flight := {"element": element, "origin": origin, "target": target, "kind": kind, "index": index, "t": -1.0, "delay": minf(0.16, index * float(profile.get("stagger", 0.0)))}
		batch.append(flight)
		flights.append(flight)
	var seconds := QiMotion.batch_seconds(profile, orbs.size())
	var tween := create_tween()
	tween.tween_method(func(elapsed: float) -> void:
		for flight: Dictionary in batch:
			flight.t = (elapsed - float(flight.delay)) / duration, 0.0, seconds, seconds)
	tween.tween_callback(func() -> void:
		for flight: Dictionary in batch:
			flights.erase(flight))
	ui.audio.cue("qi_dissolve" if kind in ["spend", "discard"] else "qi_transfer")
	if finish:
		await tween.finished
	else:
		await get_tree().create_timer(clampf(float(profile.get("commit", 0.216667)), 0.001, seconds)).timeout

func _draw_flights() -> void:
	for flight: Dictionary in flights:
		var t := float(flight.t)
		if t < 0.0 or t > 1.0:
			continue
		var kind := str(flight.kind)
		var color := Color(ui.session.content.element_info(str(flight.element)).color)
		var alpha := minf(1.0, (1.0 - t) * 5.0)
		var head: Vector2 = QiMotion.point(flight.origin, flight.target, kind, t, int(flight.index))
		for segment: int in 14:
			var back := maxf(0.0, t - segment * 0.014)
			var tail := maxf(0.0, t - (segment + 1) * 0.014)
			var p: Vector2 = QiMotion.point(flight.origin, flight.target, kind, back, int(flight.index))
			var q: Vector2 = QiMotion.point(flight.origin, flight.target, kind, tail, int(flight.index))
			flight_layer.draw_line(p, q, Color(color, alpha * (1.0 - segment / 14.0)), maxf(0.5, 3.8 - segment * 0.25), true)
		flight_layer.draw_circle(head, 1.6, Color(1, 0.97, 0.85, alpha))
