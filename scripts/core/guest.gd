extends RefCounted
## 客卿 (docs/GAME_OUTLINE.md 20.4): a wanderer of 筑基 or above may stand as a sect's guest elder, one
## sect at a time. Operates on a Session; the terms live in data/guests.json.
## An invitation comes from the sect's own story (world flag guest_invite_<sect>), from the 天南大比's
## crown (tiannan_champion, all four ask) or from the sect's first disciple trusting the player. Taken
## up at the sect's gate (the `guest` action), it gives a monthly stipend by realm, the sect's 客舍 (a
## free room to retreat and break through in, world flag guest_<sect> while it lasts) and one perk of
## the sect's own; it asks a 差遣 every few years (a commission on the sect's guest board, quest.guest)
## to be reported within its days. Missed too often, the bond is broken and the sect asks no more
## (guest_ended_<sect>). It may be laid down at any time and taken up again; joining 青云 lays it down.
## player.guest: {} or {"sect", "since", "pay_day", "next_call", "missed"}.

static func data(s) -> Dictionary:
	return s.content.guest_data

static func terms(s, sect: String) -> Dictionary:
	return data(s).get("sects", {}).get(sect, {})

## The sect the player stands as guest of, or "".
static func of(s) -> String:
	return str(s.player.get("guest", {}).get("sect", ""))

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

## Why the player cannot stand as `sect`'s guest now, or "".
static func block(s, sect: String) -> String:
	var reason: String = s.blocked()
	if not reason.is_empty():
		return reason
	var name := str(s.content.sects[sect].name)
	if terms(s, sect).is_empty():
		return "此宗不请客卿。"
	if of(s) == sect:
		return "你已是%s的客卿。" % name
	if not of(s).is_empty():
		return "你已是%s的客卿，一次只能应一宗之邀。" % s.content.sects[of(s)].name
	if not str(s.player.get("affiliation", "")).is_empty():
		return "宗门弟子不能做别宗的客卿。"
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
	s.player.guest = {"sect": sect, "since": day, "pay_day": day, "next_call": day + int(data(s).call_years) * s.Calendar.DAYS_PER_YEAR, "missed": 0}
	s.world.flags["guest_" + sect] = true
	var perk_flag := str(terms(s, sect).get("flag", ""))
	if not perk_flag.is_empty():
		s.world.flags[perk_flag] = true
	return s.finish(s.log_event("guest_join", {"sect": sect, "perk": str(terms(s, sect).perk_text)}, true))

## Lays the bond down; `ended` when the sect broke it (it asks no more).
static func leave(s, ended: bool = false) -> String:
	var sect := of(s)
	if sect.is_empty():
		return "你不是哪一宗的客卿。"
	s.world.flags.erase("guest_" + sect)
	s.player.guest = {}
	# A 差遣 still open goes with the bond.
	for quest: Dictionary in s.player.get("quests", []).duplicate():
		if str(quest.get("guest", "")) == sect:
			s.player.quests.erase(quest)
	if ended:
		s.world.flags["guest_ended_" + sect] = true
		return s.log_event("guest_dismissed", {"sect": sect}, true)
	return s.finish(s.log_event("guest_leave", {"sect": sect}))

## The stipend a month at the player's realm.
static func stipend(s) -> int:
	var table: Array = data(s).stipend
	return int(table[clampi(int(s.player.realm), 0, table.size() - 1)])

## Time passing: the stipend month by month since it was last paid, and a 差遣 whenever one falls due.
## Returns the message, "" when nothing happened.
static func pay_passive(s) -> String:
	var sect := of(s)
	if sect.is_empty():
		return ""
	var guest: Dictionary = s.player.guest
	var month: int = s.Calendar.DAYS_PER_MONTH
	var months: int = (int(s.world.day) - int(guest.pay_day)) / month
	var texts: Array[String] = []
	if months > 0:
		guest.pay_day = int(guest.pay_day) + months * month
		var stones: int = months * stipend(s)
		s.player.stones = int(s.player.stones) + stones
		texts.append(s.log_event("guest_stipend", {"sect": sect, "stones": stones, "months": months}))
	while int(s.world.day) >= int(guest.next_call) and of(s) == sect:
		texts.append(summon(s, sect, int(guest.next_call)))
		guest.next_call = int(guest.next_call) + int(data(s).call_years) * s.Calendar.DAYS_PER_YEAR
	return " ".join(texts)

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
	if of(s) != sect:
		return ""
	s.player.guest.missed = int(s.player.guest.get("missed", 0)) + 1
	if int(s.player.guest.missed) >= int(data(s).missed_most):
		return leave(s, true)
	return s.log_event("guest_lapsed", {"sect": sect, "left": int(data(s).missed_most) - int(s.player.guest.missed)})

## Whether the guest's perk `kind` applies here (赤霄's furnace, 长青's 丹坊): the sect's own gate.
static func perk_here(s, kind: String) -> bool:
	var sect := of(s)
	return not sect.is_empty() and str(terms(s, sect).get("perk", "")) == kind and str(s.player.location) in terms(s, sect).get("places", [terms(s, sect).location])

## The share of the price a guest pays at the sect's own shops (沧澜's 八折), 1.0 elsewhere.
static func discount(s) -> float:
	return float(terms(s, of(s)).get("discount", 1.0)) if perk_here(s, "discount") else 1.0
