extends RefCounted
## The 获得 card: whatever an action brought — items and 宝物, 灵石, 贡献, techniques learned, recipes —
## shown together in a card over the screen with each thing's picture, count and grade colour, so nothing
## gained slips by in the notice line. It closes on 收下 or a click outside; gains that come while it is
## open join it. Presentation only: it compares what the player held before an action with after.
const ArtLibrary = preload("res://scripts/ui/art_library.gd")
const SIDE := 64.0
const COLUMNS := 6
## The picture of the 灵石 entry (assets/art/icons/items/spirit_stones.svg).
const STONES_ICON := "spirit_stones"

## What the player holds, as the card compares it: possessions by type (an instance counts as its type,
## worn or carried, so refining or taking off a piece is no gain), stones, merit, techniques and recipes.
static func snapshot(session) -> Dictionary:
	var player: Dictionary = session.player
	if player.is_empty():
		return {}
	var held := {}
	for item_id: String in player.get("items", {}):
		var kind: String = session.Gear.type_of(session, item_id)
		held[kind] = int(held.get(kind, 0)) + int(player.items[item_id])
	for slot: String in player.get("equipment", {}):
		var worn := str(player.equipment[slot])
		if not worn.is_empty():
			var kind: String = session.Gear.type_of(session, worn)
			held[kind] = int(held.get(kind, 0)) + 1
	return {"held": held, "stones": int(player.get("stones", 0)), "contribution": int(player.get("contribution", 0)), "learned": player.get("learned", []).duplicate(), "recipes": player.get("recipes", []).duplicate()}

## What was gained since `before`, as card entries {"name", "count", "icon", "color", "note"}.
static func gains(session, before: Dictionary) -> Array[Dictionary]:
	var result: Array[Dictionary] = []
	var after := snapshot(session)
	if before.is_empty() or after.is_empty():
		return result
	for technique_id: Variant in after.learned:
		if not technique_id in before.learned:
			var t: Dictionary = session.held_technique(str(technique_id))
			if not t.is_empty():
				result.append({"name": str(t.name), "count": 0, "icon": ArtLibrary.technique_icon(t), "color": session.content.rarity_color(session.content.rarity_of(t)), "note": "习得" + ("心法" if str(t.get("slot", "art")) == "method" else "神通")})
	for recipe_id: Variant in after.recipes:
		if not recipe_id in before.recipes:
			var pill: Dictionary = session.content.item(str(session.content.alchemy_data.recipes.get(str(recipe_id), {}).get("pill", "")))
			result.append({"name": "%s丹方" % str(pill.get("name", recipe_id)), "count": 0, "icon": ArtLibrary.item_icon(session.content, pill) if not pill.is_empty() else null, "color": session.content.rarity_color(0), "note": "学会丹方"})
	var kinds: Array = after.held.keys()
	kinds.sort()
	for kind: String in kinds:
		var more := int(after.held[kind]) - int(before.held.get(kind, 0))
		if more <= 0:
			continue
		var item: Dictionary = session.content.item(kind)
		if item.is_empty():
			continue
		result.append({"name": str(item.name), "count": more, "icon": ArtLibrary.item_icon(session.content, item), "color": session.content.rarity_color(session.content.rarity_of(item)), "note": str(session.content.ITEM_CATEGORIES.get(str(item.get("category", "")), ""))})
	if int(after.stones) > int(before.stones):
		result.append({"name": "灵石", "count": int(after.stones) - int(before.stones), "icon": ArtLibrary.goods_icon(session.content, {"id": STONES_ICON, "rarity": 0}), "color": session.content.rarity_color(0), "note": ""})
	if int(after.contribution) > int(before.contribution):
		result.append({"name": "宗门贡献", "count": int(after.contribution) - int(before.contribution), "icon": null, "color": session.content.rarity_color(0), "note": ""})
	return result

## Shows `entries` in the card, opening it or adding to the one on screen.
static func show(ui, entries: Array[Dictionary]) -> void:
	if entries.is_empty():
		return
	for entry: Dictionary in entries:
		_merge(ui.gains, entry)
	if ui.gains_card != null and is_instance_valid(ui.gains_card):
		ui.gains_card.queue_free()
	ui.gains_card = _build(ui)
	ui.add_child(ui.gains_card)

static func close(ui) -> void:
	ui.gains.clear()
	if ui.gains_card != null and is_instance_valid(ui.gains_card):
		ui.gains_card.queue_free()
	ui.gains_card = null

## Gains of the same thing add up.
static func _merge(shown: Array, entry: Dictionary) -> void:
	for old: Dictionary in shown:
		if old.name == entry.name and old.note == entry.note:
			old.count = int(old.count) + int(entry.count)
			return
	shown.append(entry.duplicate())

static func _build(ui) -> Control:
	var veil := ColorRect.new()
	veil.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	veil.color = Color(0.02, 0.05, 0.06, 0.55)
	veil.z_index = 40
	veil.mouse_filter = Control.MOUSE_FILTER_STOP
	veil.gui_input.connect(func(event: InputEvent) -> void:
		if event is InputEventMouseButton and event.pressed and event.button_index == MOUSE_BUTTON_LEFT:
			close(ui))
	var holder := CenterContainer.new()
	holder.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	holder.mouse_filter = Control.MOUSE_FILTER_IGNORE
	veil.add_child(holder)
	var card := PanelContainer.new()
	card.add_theme_stylebox_override("panel", ui.style(Color("#1d2f2a"), ui.GOLD, 22))
	card.mouse_filter = Control.MOUSE_FILTER_STOP
	holder.add_child(card)
	var body := VBoxContainer.new()
	body.add_theme_constant_override("separation", 16)
	card.add_child(body)
	var title: Label = ui.label("获  得", 30, ui.GOLD)
	title.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	body.add_child(title)
	var grid := GridContainer.new()
	grid.columns = mini(COLUMNS, ui.gains.size())
	grid.add_theme_constant_override("h_separation", 18)
	grid.add_theme_constant_override("v_separation", 14)
	body.add_child(grid)
	for entry: Dictionary in ui.gains:
		grid.add_child(_cell(ui, entry))
	var take: Button = ui.button("收下", func() -> void: close(ui), "Esc 或点击空白处也可收起")
	take.custom_minimum_size.x = 160
	take.size_flags_horizontal = Control.SIZE_SHRINK_CENTER
	body.add_child(take)
	# The card rises in.
	card.modulate.a = 0.0
	card.pivot_offset = Vector2(SIDE * 2.0, SIDE)
	card.scale = Vector2(0.92, 0.92)
	var tween := card.create_tween().set_parallel()
	tween.tween_property(card, "modulate:a", 1.0, 0.18)
	tween.tween_property(card, "scale", Vector2.ONE, 0.22).set_trans(Tween.TRANS_BACK).set_ease(Tween.EASE_OUT)
	return veil

## One thing gained: its picture in a frame of its grade's colour, its name, and the count or what it is.
static func _cell(ui, entry: Dictionary) -> Control:
	var cell := VBoxContainer.new()
	cell.custom_minimum_size.x = 132
	cell.add_theme_constant_override("separation", 4)
	var frame := PanelContainer.new()
	var box: StyleBoxFlat = ui.style(Color("#11221f"), entry.color, 4)
	box.set_border_width_all(2)
	frame.add_theme_stylebox_override("panel", box)
	frame.size_flags_horizontal = Control.SIZE_SHRINK_CENTER
	cell.add_child(frame)
	var picture := TextureRect.new()
	picture.texture = entry.icon
	picture.custom_minimum_size = Vector2(SIDE, SIDE)
	picture.expand_mode = TextureRect.EXPAND_IGNORE_SIZE
	picture.stretch_mode = TextureRect.STRETCH_KEEP_ASPECT_CENTERED
	picture.texture_filter = CanvasItem.TEXTURE_FILTER_LINEAR_WITH_MIPMAPS
	frame.add_child(picture)
	if entry.icon == null:
		var initial: Label = ui.label(str(entry.name).left(1), 30, entry.color)
		initial.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
		initial.vertical_alignment = VERTICAL_ALIGNMENT_CENTER
		picture.add_child(initial)
		initial.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	var name: Label = ui.label(str(entry.name), 15, entry.color)
	name.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	name.autowrap_mode = TextServer.AUTOWRAP_ARBITRARY
	name.custom_minimum_size.x = 132
	cell.add_child(name)
	var count: Label = ui.label("×%d" % int(entry.count) if int(entry.count) > 0 else str(entry.note), 14, ui.INK)
	count.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	cell.add_child(count)
	return cell
