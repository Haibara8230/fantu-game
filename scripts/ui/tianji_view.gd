extends RefCounted
## 天骄榜: the 天机阁's scrolls as posted at a 榜亭 — the thirty names of a scroll, the player's seat, the
## 批注 beside their name, and a 战帖 for each name within reach (tianji.gd).
const Calendar = preload("res://scripts/core/calendar.gd")

static func render(ui) -> void:
	var session = ui.session
	var center: VBoxContainer = ui.center
	var tianji = session.Tianji
	var own: String = tianji.own_scroll(session)
	var shown: String = ui.tianji_scroll
	if not tianji.data(session).scrolls.has(shown):
		shown = own if not own.is_empty() else str(tianji.data(session).scrolls.keys()[0])
	var heading := HBoxContainer.new()
	heading.add_theme_constant_override("separation", 12)
	center.add_child(heading)
	heading.add_child(ui.label("%s · 天骄榜" % tianji.data(session).name, 24, ui.GOLD))
	for scroll_id: String in tianji.data(session).scrolls:
		var picked := scroll_id
		var tab: Button = ui.button(str(tianji.scroll(session, scroll_id).name).get_slice("·", 1), func() -> void:
			ui.tianji_scroll = picked
			ui.render())
		tab.disabled = scroll_id == shown
		heading.add_child(tab)
	var scroll: Dictionary = tianji.scroll(session, shown)
	var seat: int = tianji.rank(session, shown)
	var lines: Array[String] = ["本榜张于%s %d 年，下回大修在 %d 年。" % [Calendar.ERA, maxi(tianji.period(session), 1), tianji.next_revision(session)]]
	if seat > 0:
		lines.append("你在%s第 %d（最好第 %d）。" % [scroll.name, seat, maxi(tianji.best(session, shown), 1)])
	elif tianji.best(session, shown) > 0:
		lines.append("你曾列%s第 %d。" % [scroll.name, tianji.best(session, shown)])
	else:
		lines.append("榜上还没有你的名字。")
	lines.append("同境的修士可向排在前头 %d 名以内的人递战帖（未上榜的挑榜尾 %d 人），点到为止，胜了便坐他的位子，天机阁另送灵石 %d。前十每年得天机阁一份年礼，各城商铺让价；名次越高，越常有人来挑。" % [int(tianji.data(session).reach), int(tianji.data(session).reach), int(scroll.win.stones)])
	center.add_child(ui.paragraph(" ".join(lines)))
	if shown == own and seat > 0:
		var due: int = int(tianji.state(session).get("defend_day", 0)) - int(session.world.day)
		center.add_child(ui.paragraph("下一回有人来挑你的位子，约在%s后（到有榜亭的城中便会找上门来）。" % Calendar.duration_text(maxi(due, 0)) if due > 0 else "已有人等着挑你的位子，下回到了有榜亭的城中便会找上门来。", Color("#e3c08a")))
	var notes: Array = tianji.state(session).get("notes", [])
	if not notes.is_empty():
		center.add_child(ui.label("天机阁批注", 17, ui.GOLD))
		for entry: Dictionary in notes:
			center.add_child(ui.paragraph("%s　%s" % [Calendar.short_text(int(entry.day)), entry.text], ui.INK))
	center.add_child(HSeparator.new())
	var reason_all: String = tianji.block(session) if shown == own else ("天骄榜只许同境相挑。" if not own.is_empty() else "天骄榜只录筑基、金丹两境的修士。")
	var grid := GridContainer.new()
	grid.columns = 2
	grid.add_theme_constant_override("h_separation", 14)
	grid.add_theme_constant_override("v_separation", 6)
	center.add_child(grid)
	var rows: Array = tianji.order(session, shown)
	var span: Array = tianji.reach(session, shown) if shown == own else []
	for index: int in rows.size():
		var info: Dictionary = tianji.entry(session, shown, str(rows[index]))
		var place := index + 1
		var strength: Array = tianji.tier(session, place)
		var cell := HBoxContainer.new()
		cell.add_theme_constant_override("separation", 10)
		cell.size_flags_horizontal = Control.SIZE_EXPAND_FILL
		grid.add_child(cell)
		var color: Color = ui.GOLD if bool(info.get("player", false)) else (ui.INK if bool(info.get("prodigy", false)) else ui.MUTED)
		var name_text := "第 %d　%s" % [place, info.name] if bool(info.get("player", false)) else "第 %d　%s · %s（%s）" % [place, info.title, info.name, session.content.realm_title(int(scroll.realm), int(strength[0]))]
		var label: Label = ui.label(name_text, 15, color)
		label.size_flags_horizontal = Control.SIZE_EXPAND_FILL
		cell.add_child(label)
		if span.is_empty() or place < int(span[0]) or place > int(span[1]):
			continue
		var target := place
		var reason: String = reason_all if not reason_all.is_empty() else tianji.block(session, place)
		var send: Button = ui.button("递战帖", func() -> void: ui.run(func() -> String: return session.tianji_challenge(target)), reason if not reason.is_empty() else "点到为止；胜了坐第 %d，败了名次不变。" % place)
		send.disabled = not reason.is_empty()
		cell.add_child(send)
