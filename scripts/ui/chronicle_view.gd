extends RefCounted
## 编年史: the recorded life, newest first, under year headings, a page at a time. The filters are the
## groups in data/chronicle_groups.json: an entry kind can belong to several, and 大事 are the entries
## kept for the whole life.
const Calendar = preload("res://scripts/core/calendar.gd")
const Chronicle = preload("res://scripts/core/chronicle.gd")
const GROUPS_PATH := "res://data/chronicle_groups.json"
const PAGE_SIZE := 40
static var _groups: Array = []

static func groups() -> Array:
	if _groups.is_empty():
		var parsed: Variant = JSON.parse_string(FileAccess.get_file_as_string(GROUPS_PATH))
		_groups = parsed if parsed is Array else []
	return _groups

## Whether an entry belongs to a filter: "all" or a group id.
static func matches(entry: Dictionary, filter: String) -> bool:
	if filter == "all":
		return true
	for group: Dictionary in groups():
		if group.id == filter:
			return bool(entry.major) if bool(group.get("major", false)) else str(entry.id) in group.get("entries", [])
	return false

## The entries a filter shows, newest first.
## 「此地」 ("here") recalls what happened where the player now stands, as far as the record knows.
static func shown(ui) -> Array:
	var here: String = str(ui.session.player.get("location", ""))
	var result: Array = ui.session.chronicle.entries.filter(func(entry: Dictionary) -> bool: return str(entry.get("at", "")) == here if ui.chronicle_filter == "here" else matches(entry, ui.chronicle_filter))
	result.reverse()
	return result

static func page_count(ui) -> int:
	return maxi(1, ceili(shown(ui).size() / float(PAGE_SIZE)))

static func render(ui) -> void:
	var session = ui.session
	var center: VBoxContainer = ui.center
	var entries := shown(ui)
	center.add_child(ui.label("编 年 史  ·  %d 条" % entries.size(), 26, ui.GOLD))
	var filters := HFlowContainer.new()
	filters.add_theme_constant_override("h_separation", 8)
	filters.add_theme_constant_override("v_separation", 6)
	center.add_child(filters)
	var choices: Array = [{"id": "all", "name": "全部"}]
	choices.append_array(groups())
	choices.append({"id": "here", "name": "此地 · " + str(session.content.locations.get(str(session.player.location), {}).get("name", ""))})
	for group: Dictionary in choices:
		var filter_id: String = group.id
		var choice: Button = ui.button(str(group.name), func() -> void: ui.set_chronicle_filter(filter_id))
		choice.disabled = filter_id == ui.chronicle_filter
		filters.add_child(choice)
	var pages := page_count(ui)
	var page := clampi(ui.chronicle_page, 0, pages - 1)
	if entries.is_empty():
		center.add_child(ui.paragraph("尚无此类记载。"))
	var year := -1
	for entry: Dictionary in entries.slice(page * PAGE_SIZE, (page + 1) * PAGE_SIZE):
		var day := int(entry.day)
		if Calendar.year(day) != year:
			year = Calendar.year(day)
			center.add_child(ui.label("%s %d 年" % [Calendar.ERA, year], 17, ui.GOLD))
		var line: Label = ui.paragraph("%d 月%s　%s" % [Calendar.month(day), Calendar.day_name(Calendar.day_of_month(day)), session.chronicle.format(entry, session.content)], ui.INK if bool(entry.major) else ui.MUTED)
		center.add_child(line)
	var pager := HBoxContainer.new()
	pager.add_theme_constant_override("separation", 12)
	center.add_child(pager)
	var newer: Button = ui.button("较近", func() -> void: ui.set_chronicle_page(page - 1))
	newer.disabled = page <= 0
	pager.add_child(newer)
	pager.add_child(ui.label("第 %d / %d 页" % [page + 1, pages], 15, ui.MUTED))
	var older: Button = ui.button("较早", func() -> void: ui.set_chronicle_page(page + 1))
	older.disabled = page >= pages - 1
	pager.add_child(older)
	pager.add_child(ui.button("返回", func() -> void: ui.set_view("place")))
	center.add_child(ui.paragraph("日常琐事只保留最近 %d 条，大事终生保留。" % Chronicle.RECENT_LIMIT))
