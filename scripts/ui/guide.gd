extends RefCounted
## New-player guide: one tip at a time at the top of the centre panel, the first time its situation
## comes up (the first retreat, the market, a duel, a bottleneck...). Tips live in data/guide.json in
## the order they are offered; when each applies is decided here. Which tips were dismissed is kept in
## the player's own guide file, not in saves, so a new journey does not repeat them.
const TIPS_PATH := "res://data/guide.json"
const DEFAULT_PATH := "user://guide.cfg"
const Settings = preload("res://scripts/ui/settings.gd")
# The tips whose situation applies() knows; every tip in the data must be one of them.
const TIP_IDS := ["retreat", "people", "map", "battle", "event", "gather", "trade", "commissions", "fatigue", "bottleneck", "arts"]
static var _tips: Array = []

static func tips() -> Array:
	if _tips.is_empty():
		var parsed: Variant = JSON.parse_string(FileAccess.get_file_as_string(TIPS_PATH))
		_tips = parsed if parsed is Array else []
	return _tips

## Whether the tip's situation holds now.
static func applies(ui, tip_id: String) -> bool:
	var session = ui.session
	match tip_id:
		"retreat":
			return session.player.location == "sect"
		"people":
			return not session.present_npcs().is_empty()
		"map":
			return int(session.world.day) > 0
		"battle", "event":
			return true
		"gather":
			return session.available_here("gather")
		"trade":
			return session.available_here("shop") or session.available_here("sell")
		"commissions":
			return session.available_here("commissions")
		"fatigue":
			return session.retreat_efficiency() < 100
		"bottleneck":
			return session.at_bottleneck()
		"arts":
			return session.player.learned.size() > session.content.sects.wanderer.skills.size() or session.player.items.keys().any(func(item_id: String) -> bool: return str(session.content.item(item_id).get("category", "")) in ["manual", "equipment"])
	return false

static func known(tip_id: String) -> bool:
	return tip_id in TIP_IDS

## The first unseen tip for this part of the screen whose situation holds, or {}.
static func current(ui, where: String) -> Dictionary:
	if not ui.guide_enabled or where.is_empty():
		return {}
	for tip: Dictionary in tips():
		if not ui.guide_seen.has(tip.id) and where in tip.where and applies(ui, tip.id):
			return tip
	return {}

## The tip panel with its 知道了, when a tip is due.
static func render(ui, where: String) -> void:
	var tip := current(ui, where)
	if tip.is_empty():
		return
	var box := PanelContainer.new()
	box.add_theme_stylebox_override("panel", ui.style(Color("#1d2f2a"), ui.GOLD, 12))
	var row := HBoxContainer.new()
	row.add_theme_constant_override("separation", 14)
	box.add_child(row)
	var words := VBoxContainer.new()
	words.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	row.add_child(words)
	words.add_child(ui.label("指引 · " + str(tip.title), 16, ui.GOLD))
	# Tips that name keys say {save}, {load}, {skills} or {guard}, filled in with the current bindings.
	words.add_child(ui.paragraph(str(tip.text).format(Settings.key_hints(ui)), ui.INK))
	var tip_id: String = tip.id
	var done: Button = ui.button("知道了", func() -> void: ui.dismiss_tip(tip_id), "不再显示这条指引")
	done.size_flags_vertical = Control.SIZE_SHRINK_CENTER
	row.add_child(done)
	ui.center.add_child(box)

static func load_state(ui) -> void:
	var config := ConfigFile.new()
	ui.guide_seen = {}
	ui.guide_enabled = true
	if config.load(ui.guide_path) != OK:
		return
	var enabled: Variant = config.get_value("guide", "enabled", true)
	ui.guide_enabled = not (enabled is bool and not enabled)
	var seen: Variant = config.get_value("guide", "seen", [])
	if seen is Array:
		for tip_id: Variant in seen:
			if tip_id is String:
				ui.guide_seen[tip_id] = true

static func save_state(ui) -> void:
	var config := ConfigFile.new()
	config.set_value("guide", "enabled", ui.guide_enabled)
	config.set_value("guide", "seen", ui.guide_seen.keys())
	config.save(ui.guide_path)
