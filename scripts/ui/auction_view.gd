extends RefCounted
## The auction screen (auctions.gd): the lot on the block with its words, the price and who holds it,
## the bidders around the room, the lots still to come, and raising, letting a lot go or leaving.
const PeopleView = preload("res://scripts/ui/people_view.gd")
const LEAD := Color("#e8c46d")

static func render(ui) -> void:
	var session = ui.session
	var a: Dictionary = session.auction
	var auctions = session.Auctions
	var center: VBoxContainer = ui.center
	var lot: Dictionary = auctions.lot(session)
	var item: Dictionary = session.content.item(str(lot.item))
	var head := HBoxContainer.new()
	head.add_theme_constant_override("separation", 14)
	center.add_child(head)
	head.add_child(ui.label(str(auctions.definition(session, str(a.id)).name), 26, ui.GOLD))
	var count: Label = ui.label("第 %d / %d 件" % [int(a.index) + 1, a.lots.size()], 16, ui.MUTED)
	count.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	head.add_child(count)
	head.add_child(ui.label("灵石 %d" % int(session.player.stones), 18, ui.INK))
	# The lot on the block.
	var block := PanelContainer.new()
	block.add_theme_stylebox_override("panel", ui.style(Color(0.06, 0.1, 0.11, 0.85), Color("#6f6342"), 14))
	center.add_child(block)
	var words := VBoxContainer.new()
	words.add_theme_constant_override("separation", 6)
	block.add_child(words)
	var name: Label = ui.label(str(item.name) + (" ×%d" % int(lot.count) if int(lot.count) > 1 else ""), 24, ui.grade_color(item))
	words.add_child(name)
	words.add_child(ui.paragraph(str(item.get("description", "")), ui.INK))
	var leader := str(a.leader)
	var holder := "尚无人出价" if leader.is_empty() else ("你" if leader == "player" else str(session.person(leader).name))
	words.add_child(ui.label("底价 %d · 每口 %d 灵石    当前 %d 灵石 · %s" % [int(lot.start), int(lot.step), int(a.price), holder], 18, LEAD))
	# The bidders around the room.
	center.add_child(ui.label("在座", 16, ui.MUTED))
	var seats := HBoxContainer.new()
	seats.add_theme_constant_override("separation", 10)
	center.add_child(seats)
	for person_id: String in a.bidders:
		var someone: Dictionary = session.person(person_id)
		var seat := VBoxContainer.new()
		seat.size_flags_horizontal = Control.SIZE_EXPAND_FILL
		seats.add_child(seat)
		var face: Control = PeopleView._portrait(ui, person_id, someone, Vector2(84, 104))
		face.size_flags_horizontal = Control.SIZE_SHRINK_CENTER
		# The one holding the price glows a little.
		if person_id == leader:
			face.modulate = Color(1.15, 1.08, 0.9)
		seat.add_child(face)
		var about: Label = ui.label("%s\n%s · %s" % [someone.name, str(someone.get("personality", "")), str(someone.get("realm_text", ""))], 15, LEAD if person_id == leader else ui.INK)
		about.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
		seat.add_child(about)
	# What can be done.
	var row := HBoxContainer.new()
	row.add_theme_constant_override("separation", 10)
	center.add_child(row)
	for steps: int in [1, 3]:
		var amount: int = auctions.next_bid(session, steps)
		var reason: String = auctions.bid_block(session, steps)
		var raise: Button = ui.button(("出价 %d" if steps == 1 else "连加三口 · %d") % amount, func() -> void: ui.run(func() -> String: return session.auction_bid(steps)), reason if not reason.is_empty() else "无人应价便归你，灵石落槌时付")
		raise.disabled = not reason.is_empty()
		raise.size_flags_horizontal = Control.SIZE_EXPAND_FILL
		row.add_child(raise)
	var leading := leader == "player"
	var let_go: Button = ui.button("放弃此件", func() -> void: ui.run(session.auction_pass), "由在座的人去争")
	let_go.disabled = leading
	let_go.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	row.add_child(let_go)
	var leave: Button = ui.button("离场", func() -> void: ui.run(session.auction_leave), "余下的拍品不再参与")
	leave.disabled = leading
	row.add_child(leave)
	# The lots still to come.
	var later: Array[String] = []
	for index: int in range(int(a.index) + 1, a.lots.size()):
		var next: Dictionary = a.lots[index]
		later.append(str(session.content.item(str(next.item)).name) + (" ×%d" % int(next.count) if int(next.count) > 1 else ""))
	if not later.is_empty():
		center.add_child(ui.paragraph("稍后：" + "、".join(later), ui.MUTED))
