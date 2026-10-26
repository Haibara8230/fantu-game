extends RefCounted
## Teaching cards: one card at a time at the top of the centre panel (or as a bubble beside the button it
## speaks of, when that button is on screen), the first time its situation comes
## up in a journey (the first retreat, the market, a duel, the mind falling short, the first 传音...).
## A card may have a few pages. Cards live in data/guide.json in the order they are offered; when each
## applies is decided here. Which cards were dismissed is kept in the journey (player.taught), so every
## new journey teaches again what it unlocks; the player's guide file keeps only whether cards are shown
## at all and whether this player has finished the introduction once (which lets a new journey skip it).
const TIPS_PATH := "res://data/guide.json"
const DEFAULT_PATH := "user://guide.cfg"
const Settings = preload("res://scripts/ui/settings.gd")
# The cards whose situation applies() knows; every card in the data must be one of them.
const TIP_IDS := ["retreat", "people", "map", "battle", "event", "gather", "trade", "commissions", "lineage", "mind", "fatigue", "bottleneck", "stories", "letters", "breakthrough", "sect", "bonds", "fortune", "talents", "arts", "alchemy", "field", "cave", "sense", "auction", "forge", "founding", "forming", "nascent", "deifying"]
static var _tips: Array = []
# A card beside its button: its width, the gap to the button and the margin kept from the screen's edge.
const BUBBLE_WIDTH := 460.0
const BUBBLE_GAP := 14.0
const BUBBLE_MARGIN := 12.0
# Room left beside the words for the card's paddings and its page buttons.
const BUBBLE_BUTTONS := 150.0

static func tips() -> Array:
	if _tips.is_empty():
		var parsed: Variant = JSON.parse_string(FileAccess.get_file_as_string(TIPS_PATH))
		_tips = parsed if parsed is Array else []
	return _tips

## Whether the card's situation holds now.
static func applies(ui, tip_id: String) -> bool:
	var session = ui.session
	var guided: Dictionary = session.guide_step()
	match tip_id:
		"retreat":
			# Any place to retreat: a sect's chamber, an inn's 静房, a dwelling.
			var spot: Array = session.content.locations[session.player.location].spots.filter(func(candidate: Dictionary) -> bool: return candidate.id == ui.selected_spot)
			var in_chamber: bool = ui.view == "retreat" or (ui.view == "place" and ui.selected_npc.is_empty() and not spot.is_empty() and "cultivate" in spot[0].actions)
			return session.available_here("cultivate") and in_chamber and (guided.is_empty() or guided.has("retreat_days"))
		"people":
			return not session.present_npcs().is_empty() and (guided.is_empty() or str(guided.id) != "retreat")
		"map":
			if not guided.is_empty():
				return str(guided.get("place", session.player.location)) != session.player.location
			return int(session.world.day) > 0
		"battle", "event":
			return true
		"gather":
			return session.available_here("gather")
		"trade":
			return session.available_here("shop") or session.available_here("sell")
		"commissions":
			return session.available_here("commissions")
		"lineage":
			return session.available_here("study")
		"mind":
			return session.mind_percent() < 100 or int(session.player.stage) > 0 or int(session.player.realm) > 0
		"fatigue":
			return session.retreat_efficiency() < 100
		"bottleneck":
			return session.at_bottleneck()
		"stories":
			return session.content.storylines.keys().any(func(story_id: String) -> bool: return not bool(session.content.storylines[story_id].get("guide", false)) and session.story_state(story_id) == "active" and not str(session.story_step(story_id).get("goal", "")).is_empty())
		"letters":
			return not session.world.get("letters", []).is_empty()
		"talents":
			return true
		"sect":
			return session.available_here("sect") or ui.view == "sect"
		"bonds":
			return session.known_npcs().any(func(person_id: String) -> bool: return session.favor(person_id) >= int(session.content.bonds_data.consult.favor))
		"fortune":
			return session.player.get("boons", {}).keys().any(func(id: String) -> bool: return not id.begins_with("humble_") or session.has_talent(str(session.content.rules.fortune[id].talent)))
		"breakthrough":
			return int(session.player.realm) == 0 and int(session.player.stage) >= session.content.realm(0).stages.size() - 1
		"alchemy", "field", "sense", "auction", "forge", "founding", "forming", "nascent", "deifying":
			return true
		"cave":
			return not session.cave_here().is_empty()
		"arts":
			return session.player.learned.size() > session.content.sects.wanderer.skills.size() or session.player.items.keys().any(func(item_id: String) -> bool: return str(session.content.item(item_id).get("category", "")) in ["manual", "equipment"])
	return false

static func known(tip_id: String) -> bool:
	return tip_id in TIP_IDS

## The first card for this part of the screen not yet dismissed in this journey whose situation holds,
## or {}.
static func current(ui, where: String) -> Dictionary:
	if not ui.guide_enabled or where.is_empty() or ui.session.player.is_empty():
		return {}
	var taught: Array = ui.session.player.get("taught", [])
	for tip: Dictionary in tips():
		if not tip.id in taught and where in tip.where and applies(ui, tip.id):
			return tip
	return {}

## Points at the button the due card speaks of (its `highlight`, a part of the button's text): a gold
## frame that breathes, until the card is dismissed. Looks through the window, the scene and the HUD.
static func highlight(ui, where: String) -> void:
	var tip := current(ui, where)
	var mark := str(tip.get("highlight", ""))
	if mark.is_empty():
		return
	var found: Array = []
	for root: Node in [ui.center, ui.scene_layer, ui.hud_left]:
		if root != null:
			found.append_array(root.find_children("*", "Button", true, false))
	for button: Button in found:
		if not button.text.contains(mark) or button.disabled or not button.is_visible_in_tree():
			continue
		var frame: StyleBoxFlat = ui.style(Color("#2c4a46"), ui.GOLD, 10)
		frame.set_border_width_all(2)
		button.add_theme_stylebox_override("normal", frame)
		var breathe := button.create_tween().set_loops()
		breathe.tween_property(button, "modulate", Color(1.2, 1.12, 0.9), 0.7)
		breathe.tween_property(button, "modulate", Color.WHITE, 0.7)
		_attach(ui, button)
		return

## Turns the card on screen into a bubble beside the button it speaks of: it leaves the flow of its
## panel (top_level, so containers no longer place it) and sits below the button, or above it when
## there is no room, with a small pointer. A card whose button is not on screen stays where it is.
static func _attach(ui, button: Button) -> void:
	var card: Control = ui.tip_card
	if card == null or not is_instance_valid(card) or not card.is_inside_tree():
		return
	card.top_level = true
	card.custom_minimum_size.x = BUBBLE_WIDTH
	# Wrapped words out of a container's flow need a width of their own, or they wrap at every character.
	for words: Label in card.find_children("*", "Label", true, false):
		if words.autowrap_mode != TextServer.AUTOWRAP_OFF:
			words.custom_minimum_size.x = BUBBLE_WIDTH - BUBBLE_BUTTONS
	card.reset_size()
	var pointer := Polygon2D.new()
	pointer.color = ui.GOLD
	card.add_child(pointer)
	var place := func() -> void:
		if not is_instance_valid(button) or not button.is_inside_tree():
			return
		# A control never shrinks by itself: once the words have wrapped, fit the card to them (resized
		# then places it again).
		var fit := Vector2(maxf(BUBBLE_WIDTH, card.get_combined_minimum_size().x), card.get_combined_minimum_size().y)
		if not card.size.is_equal_approx(fit):
			card.size = fit
			return
		var target := button.get_global_rect()
		var view: Rect2 = card.get_viewport_rect()
		var below := target.end.y + BUBBLE_GAP + card.size.y <= view.end.y - BUBBLE_MARGIN
		var x := clampf(target.get_center().x - card.size.x / 2.0, view.position.x + BUBBLE_MARGIN, view.end.x - card.size.x - BUBBLE_MARGIN)
		var y := target.end.y + BUBBLE_GAP if below else target.position.y - BUBBLE_GAP - card.size.y
		card.global_position = Vector2(x, y)
		var tip_x := clampf(target.get_center().x - x, 16.0, card.size.x - 16.0)
		var edge := 0.0 if below else card.size.y
		var reach := -BUBBLE_GAP + 2.0 if below else BUBBLE_GAP - 2.0
		pointer.polygon = PackedVector2Array([Vector2(tip_x - 9.0, edge), Vector2(tip_x + 9.0, edge), Vector2(tip_x, edge + reach)])
	# The card's height is known once its text has wrapped to the new width.
	card.resized.connect(place)
	place.call_deferred()

## The card with its pages and 知道了, when one is due; into the window, or into `parent` when the
## window is closed (a place's scene with no spot open).
static func render(ui, where: String, parent: Control = null) -> void:
	ui.tip_card = null
	var tip := current(ui, where)
	if tip.is_empty():
		return
	var tip_id: String = tip.id
	var pages: Array = tip.pages
	if ui.tip_page.get("id", "") != tip_id:
		ui.tip_page = {"id": tip_id, "page": 0}
	var page := clampi(int(ui.tip_page.page), 0, pages.size() - 1)
	var box := PanelContainer.new()
	box.add_theme_stylebox_override("panel", ui.style(Color("#1d2f2a"), ui.GOLD, 14))
	var row := HBoxContainer.new()
	row.add_theme_constant_override("separation", 14)
	box.add_child(row)
	var words := VBoxContainer.new()
	words.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	row.add_child(words)
	var title := "教学 · " + str(tip.title)
	if pages.size() > 1:
		title += "  %d / %d" % [page + 1, pages.size()]
	words.add_child(ui.label(title, 17, ui.GOLD))
	# Cards that name keys say {save}, {load}, {skills} or {end_turn}, filled in with the current bindings.
	words.add_child(ui.paragraph(str(pages[page]).format(Settings.key_hints(ui)), ui.INK))
	var buttons := VBoxContainer.new()
	buttons.add_theme_constant_override("separation", 6)
	buttons.size_flags_vertical = Control.SIZE_SHRINK_CENTER
	row.add_child(buttons)
	if page > 0:
		buttons.add_child(ui.button("上一页", func() -> void: ui.turn_tip(-1)))
	if page < pages.size() - 1:
		buttons.add_child(ui.button("下一页", func() -> void: ui.turn_tip(1)))
	else:
		buttons.add_child(ui.button("知道了", func() -> void: ui.dismiss_tip(tip_id), "这段旅程里不再显示这张教学"))
	(parent if parent != null else ui.center).add_child(box)
	ui.tip_card = box

static func load_state(ui) -> void:
	var config := ConfigFile.new()
	ui.guide_enabled = true
	ui.intro_finished_once = false
	if config.load(ui.guide_path) != OK:
		return
	var enabled: Variant = config.get_value("guide", "enabled", true)
	ui.guide_enabled = not (enabled is bool and not enabled)
	var finished: Variant = config.get_value("guide", "intro_finished", false)
	ui.intro_finished_once = finished is bool and finished

static func save_state(ui) -> void:
	var config := ConfigFile.new()
	config.set_value("guide", "enabled", ui.guide_enabled)
	config.set_value("guide", "intro_finished", ui.intro_finished_once)
	config.save(ui.guide_path)
