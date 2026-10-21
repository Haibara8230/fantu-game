extends RefCounted
## 客卿 (docs/GAME_OUTLINE.md 20.4, docs/SIDEQUESTS_DRAFT_20261020.md 2.3): a cultivator of 筑基 or
## above may stand as a sect's guest elder, at up to `most` sects at once. Operates on a Session; the
## terms live in data/guests.json.
## A disciple of a sect may stand as guest of another only where the two do not clash: not the own sect,
## not one of the same lineage element, not one on the other side of 正 and 魔 (sect.json `side`).
## An invitation comes from the sect's own story (world flag guest_invite_<sect>), from the 天南大比's
## crown (tiannan_champion, all four ask) or from the sect's first disciple trusting the player. Taken
## up at the sect's gate (the `guest` action), it gives a monthly stipend by realm, the sect's 客舍 (a
## free room to retreat and break through in, world flag guest_<sect> while it lasts) and one perk of
## the sect's own; it asks a 差遣 every few years (a commission on the sect's guest board, quest.guest)
## to be reported within its days. Missed too often, the bond is broken and the sect asks no more
## (guest_ended_<sect>). It may be laid down at any time and taken up again; joining a sect lays down
## the bonds that sect does not allow.
## player.guests: [{"sect", "since", "pay_day", "next_call", "missed"}], one per bond.

static func data(s) -> Dictionary:
	return s.content.guest_data

static func terms(s, sect: String) -> Dictionary:
	return data(s).get("sects", {}).get(sect, {})

## The bonds the player holds.
static func bonds(s) -> Array:
	return s.player.get("guests", [])

## The bond with `sect`, {} when there is none.
static func bond(s, sect: String) -> Dictionary:
	for held: Dictionary in bonds(s):
		if str(held.sect) == sect:
			return held
	return {}

## Whether the player stands as guest of `sect` ("" asks: of any sect).
static func is_guest(s, sect: String = "") -> bool:
	return not bonds(s).is_empty() if sect.is_empty() else not bond(s, sect).is_empty()

## The sects the player stands as guest of.
static func sects_held(s) -> Array[String]:
	var result: Array[String] = []
	for held: Dictionary in bonds(s):
		result.append(str(held.sect))
	return result

## The sect whose gate this is (where its invitation is taken up), or "".
static func sect_here(s) -> String:
	for sect: String in data(s).get("sects", {}):
		if str(terms(s, sect).location) == str(s.player.location):
			return sect
	return ""

## Whether `sect` has asked the player.
static func invited(s, sect: String) -> bool:
	if s.has_flag("guest_ended_" + sect):
		return false
	if s.has_flag("guest_invite_" + sect) or s.has_flag("tiannan_champion"):
		return true
	var person := str(terms(s, sect).get("person", ""))
	return not person.is_empty() and s.favor(person) >= int(data(s).invite_favor)

## Why the player's own sect does not allow standing as `sect`'s guest, or "".
static func clash(s, sect: String) -> String:
	if not s.Sect.member(s):
		return ""
	var own: String = s.Sect.own_id(s)
	var mine: Dictionary = s.Sect.info(s, own)
	var theirs: Dictionary = s.Sect.info(s, sect)
	if own == sect:
		return "你是%s弟子，不必做本门的客卿。" % mine.name
	if str(mine.element) == str(theirs.element):
		return "%s与%s同出一路传承，本门不许你去做客卿。" % [theirs.name, mine.name]
	if "demonic" in [str(mine.side), str(theirs.side)] and str(mine.side) != str(theirs.side):
		return "正魔不两立，%s弟子做不得%s的客卿。" % [mine.name, theirs.name]
	return ""

## Why the player cannot stand as `sect`'s guest now, or "".
static func block(s, sect: String) -> String:
	var reason: String = s.blocked()
	if not reason.is_empty():
		return reason
	var name: String = s.Sect.name_of(s, sect)
	if terms(s, sect).is_empty():
		return "此宗不请客卿。"
	if is_guest(s, sect):
		return "你已是%s的客卿。" % name
	if bonds(s).size() >= int(data(s).most):
		var names: Array[String] = []
		for held: String in sects_held(s):
			names.append(s.Sect.name_of(s, held))
		return "你已应了%s的客卿之约，至多同时应 %d 宗。" % ["、".join(names), int(data(s).most)]
	reason = clash(s, sect)
	if not reason.is_empty():
		return reason
	if int(s.player.realm) < int(data(s).min_realm):
		return "客卿须%s以上。" % s.content.realm_title(int(data(s).min_realm), 0)
	if s.has_flag("guest_ended_" + sect):
		return "%s已与你解约，不会再请你。" % name
	if not invited(s, sect):
		return "%s尚未向你发出客卿之邀。" % name
	return ""

## Stands as `sect`'s guest from today.
static func accept(s, sect: String) -> String:
	var reason := block(s, sect)
	if not reason.is_empty():
		return reason
	var day := int(s.world.day)
	var held: Array = bonds(s)
	held.append({"sect": sect, "since": day, "pay_day": day, "next_call": day + int(data(s).call_years) * s.Calendar.DAYS_PER_YEAR, "missed": 0})
	s.player["guests"] = held
	s.world.flags["guest_" + sect] = true
	var perk_flag := str(terms(s, sect).get("flag", ""))
	if not perk_flag.is_empty():
		s.world.flags[perk_flag] = true
	return s.finish(s.log_event("guest_join", {"sect": sect, "perk": str(terms(s, sect).perk_text)}, true))

## Lays the bond with `sect` down (the one here when ""); `ended` when the sect broke it (it asks no
## more). `quiet` returns the chronicle text without ending the action (a sect joined lays bonds down).
static func leave(s, sect: String = "", ended: bool = false, quiet: bool = false) -> String:
	if sect.is_empty():
		sect = sect_here(s)
	if not is_guest(s, sect):
		return "你不是这一宗的客卿。"
	s.world.flags.erase("guest_" + sect)
	s.player.guests = bonds(s).filter(func(held: Dictionary) -> bool: return str(held.sect) != sect)
	# A 差遣 still open goes with the bond.
	for quest: Dictionary in s.player.get("quests", []).duplicate():
		if str(quest.get("guest", "")) == sect:
			s.player.quests.erase(quest)
	if ended:
		s.world.flags["guest_ended_" + sect] = true
		return s.log_event("guest_dismissed", {"sect": sect}, true)
	var text: String = s.log_event("guest_leave", {"sect": sect})
	return text if quiet else s.finish(text)

## Lays down the bonds the player's sect does not allow; returns their chronicle texts.
static func prune(s) -> Array[String]:
	var texts: Array[String] = []
	for sect: String in sects_held(s):
		if not clash(s, sect).is_empty():
			texts.append(leave(s, sect, false, true))
	return texts

## The stipend a month at the player's realm, for each bond.
static func stipend(s) -> int:
	var table: Array = data(s).stipend
	return int(table[clampi(int(s.player.realm), 0, table.size() - 1)])

## Time passing: each bond's stipend month by month since it was last paid, and a 差遣 whenever one
## falls due. Returns the message, "" when nothing happened.
static func pay_passive(s) -> String:
	var texts: Array[String] = []
	var month: int = s.Calendar.DAYS_PER_MONTH
	for sect: String in sects_held(s):
		var held := bond(s, sect)
		var months: int = (int(s.world.day) - int(held.pay_day)) / month
		if months > 0:
			held.pay_day = int(held.pay_day) + months * month
			var stones: int = months * stipend(s)
			s.player.stones = int(s.player.stones) + stones
			texts.append(s.log_event("guest_stipend", {"sect": sect, "stones": stones, "months": months}))
		while is_guest(s, sect) and int(s.world.day) >= int(held.next_call):
			texts.append(summon(s, sect, int(held.next_call)))
			held.next_call = int(held.next_call) + int(data(s).call_years) * s.Calendar.DAYS_PER_YEAR
	return " ".join(texts.filter(func(text: String) -> bool: return not text.is_empty()))

## A 差遣 posted on `day`: one of the sect's guest commissions, to report at its 客舍 within its days.
static func summon(s, sect: String, day: int) -> String:
	var board := "guest_" + sect
	var kinds: Array = s.content.commission_data.templates.keys().filter(func(kind: String) -> bool: return board in s.content.commission_data.templates[kind].boards)
	kinds.sort()
	if kinds.is_empty():
		return ""
	var rng := RandomNumberGenerator.new()
	rng.seed = hash([int(s.world.get("seed", 0)), "guest", sect, day])
	var kind: String = kinds[rng.randi_range(0, kinds.size() - 1)]
	var quest: Dictionary = s.Commissions.make_offer(s, kind, board, "%s:%d" % [board, day], rng)
	if quest.is_empty():
		return ""
	quest.guest = sect
	quest.deadline = day + int(data(s).call_days)
	quest.progress = 0
	s.player.quests.append(quest)
	return s.log_event("guest_call", {"sect": sect, "quest_title": s.Commissions.text(s, quest).title, "days": int(data(s).call_days)}, true)

## A 差遣 reported.
static func served(s, quest: Dictionary) -> String:
	var person := str(terms(s, str(quest.guest)).get("person", ""))
	if not person.is_empty() and s.is_person(person):
		s.Events.apply(s, [{"relation": [person, int(data(s).served_favor)]}])
	return s.log_event("guest_served", {"sect": str(quest.guest)})

## A 差遣 let lapse: counted, and the bond broken once too many lapsed.
static func lapsed(s, quest: Dictionary) -> String:
	var sect := str(quest.guest)
	var held := bond(s, sect)
	if held.is_empty():
		return ""
	held.missed = int(held.get("missed", 0)) + 1
	if int(held.missed) >= int(data(s).missed_most):
		return leave(s, sect, true)
	return s.log_event("guest_lapsed", {"sect": sect, "left": int(data(s).missed_most) - int(held.missed)})

## The bond whose perk `kind` applies here (赤霄's furnace, 长青's 丹坊): at that sect's own places.
static func _perk_bond(s, kind: String) -> String:
	for sect: String in sects_held(s):
		if str(terms(s, sect).get("perk", "")) == kind and str(s.player.location) in terms(s, sect).get("places", [terms(s, sect).location]):
			return sect
	return ""

## Whether a guest's perk `kind` applies here.
static func perk_here(s, kind: String) -> bool:
	return not _perk_bond(s, kind).is_empty()

## The share of the price a guest pays at the sect's own shops (沧澜's 八折), 1.0 elsewhere.
static func discount(s) -> float:
	var sect := _perk_bond(s, "discount")
	return float(terms(s, sect).get("discount", 1.0)) if not sect.is_empty() else 1.0
