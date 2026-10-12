extends RefCounted
## Teaching cards: one card at a time at the top of the centre panel, the first time its situation comes
## up in a journey (the first retreat, the market, a duel, the mind falling short, the first 传音...).
## A card may have a few pages. Cards live in data/guide.json in the order they are offered; when each
## applies is decided here. Which cards were dismissed is kept in the journey (player.taught), so every
## new journey teaches again what it unlocks; the player's guide file keeps only whether cards are shown
## at all and whether this player has finished the introduction once (which lets a new journey skip it).
const TIPS_PATH := "res://data/guide.json"
const DEFAULT_PATH := "user://guide.cfg"
const Settings = preload("res://scripts/ui/settings.gd")
# The cards whose situation applies() knows; every card in the data must be one of them.
const TIP_IDS := ["intro", "retreat", "people", "map", "battle", "event", "gather", "trade", "commissions", "lineage", "mind", "fatigue", "bottleneck", "stories", "letters", "breakthrough", "arts"]
static var _tips: Array = []

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
		"intro":
			return not guided.is_empty()
		"retreat":
			return session.player.location == "sect" and (guided.is_empty() or guided.has("retreat_days"))
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
		"breakthrough":
			return int(session.player.realm) == 0 and int(session.player.stage) >= session.content.realm(0).stages.size() - 1
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

## The card with its pages and 知道了, when one is due.
static func render(ui, where: String) -> void:
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
	# Cards that name keys say {save}, {load}, {skills} or {guard}, filled in with the current bindings.
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
	ui.center.add_child(box)

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
