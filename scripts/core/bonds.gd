extends RefCounted
## Bonds with people, after 觅长生: what favor opens, and acquaintances who reach out on their own.
## Operates on a Session; the numbers and the letters' words live in data/bonds.json.
## Favor opens, stage by stage: 相熟 — a 传音符 with any acquaintance (key people keep their own
## thresholds); 友好 — 请教 (a few days learning from someone of one's own standing or above); 信赖 —
## guarding a breakthrough (breakthrough.gd) and, once, being taught one of their arts; 亲密 — calling
## them into a duel by 传音 (传音求援), once a duel.
## Every so often (visits.period_days) each generated acquaintance holding a 传音符 may write: to spar
## (come within a month), to ask for help (an herb or a pill within two months), to gather together
## (a trip to a place within a month brings twice the herbs), to borrow silver (repaid half again in
## half a year, unless they die first), or to send a gift. Such letters never end a retreat.
## world.invites holds the open ones ({"id", "npc", "kind", "made", "deadline", ...}); world.loans the
## silver lent ({"npc", "amount", "repay", "due"}); world.visit_period the last period written in.
const Events = preload("res://scripts/core/events.gd")
const Storylines = preload("res://scripts/core/storylines.gd")

static func data(s) -> Dictionary:
	return s.content.bonds_data

## The favor at which a person exchanges 传音符: key people's own, everyone else's from the rules.
static func sound_at(s, person_id: String) -> int:
	var someone: Dictionary = s.content.people.get(person_id, {})
	if not someone.is_empty():
		return int(someone.get("sound_at", -1))
	return int(data(s).sound_at) if s.is_generated(person_id) else -1

## Someone's standing as [realm, stage], or [] when it is not known in those terms (mortals).
static func standing(s, person_id: String) -> Array:
	var someone: Dictionary = s.person(person_id)
	if someone.get("generated", false):
		return [int(someone.realm), int(someone.stage)]
	return someone.get("standing", [])

static func _above_or_level(s, person_id: String) -> bool:
	var other := standing(s, person_id)
	return not other.is_empty() and int(other[0]) * 10 + int(other[1]) >= int(s.player.realm) * 10 + int(s.player.stage)

static func _alive(s, person_id: String) -> bool:
	if s.is_generated(person_id):
		var life: Dictionary = s.life_by_id(person_id)
		return not life.is_empty() and int(life.death) > int(s.world.day) and int(life.appear) <= int(s.world.day)
	return s.content.people.has(person_id)

## The options favor opens with someone, for npc_options: {"id", "label", "conditions"?, ...}.
static func options(s, person_id: String) -> Array[Dictionary]:
	var result: Array[Dictionary] = []
	var favor: int = s.favor(person_id)
	var rules := data(s)
	if favor >= int(rules.consult.favor) and _above_or_level(s, person_id):
		result.append({"id": "consult", "label": "请教（%d 日，得历练与心境）" % int(rules.consult.days), "cooldown_days": int(rules.consult.cooldown_days)})
	if favor >= int(rules.teach.favor) and s.is_generated(person_id):
		result.append({"id": "teach", "label": "求传功法（一生一次）", "once": true})
	for invite: Dictionary in s.world.get("invites", []):
		if invite.npc != person_id:
			continue
		match str(invite.kind):
			"spar":
				result.append({"id": "invite_spar", "label": "赴约切磋"})
			"help":
				result.append({"id": "invite_help", "label": "送上%s×%d" % [s.content.item(invite.item).name, int(invite.count)], "conditions": [{"item_at_least": [invite.item, int(invite.count)]}]})
	return result

## Why an opened option cannot be taken now beyond the usual checks, or "".
static func option_block(s, person_id: String, option_id: String) -> String:
	if option_id == "teach" and teachable(s, person_id).is_empty():
		return "此人所会，已没有能传给你的。"
	return ""

## The art someone would teach: the best of theirs the player can study and does not know, or "".
static func teachable(s, person_id: String) -> String:
	var someone: Dictionary = s.person(person_id)
	var best := ""
	var best_tier := 0
	for technique_id: Variant in someone.get("loadout", {}).get("arts", []) + someone.get("loadout", {}).get("methods", []):
		var t: Dictionary = s.content.technique(str(technique_id))
		if t.is_empty() or str(technique_id) in s.player.learned or int(t.min_realm) > int(s.player.realm):
			continue
		if int(t.tier) > best_tier:
			best = str(technique_id)
			best_tier = int(t.tier)
	return best

## Carries out an option this module opened; returns the texts, or "" when it is not one of them.
static func interact(s, person_id: String, option_id: String) -> String:
	var rules := data(s)
	match option_id:
		"consult":
			var passed: Dictionary = s.advance_days(int(rules.consult.days))
			var texts: Array[String] = [s.log_event("consult", {"npc": person_id, "days": passed.elapsed})]
			texts.append_array(s.gain_insight("consult"))
			return s.conclude(" ".join(texts), passed)
		"teach":
			var taught := teachable(s, person_id)
			s.add_item("j:" + taught, 1)
			Events.apply(s, [{"relation": [person_id, 5]}])
			return s.conclude(s.log_event("taught_by", {"npc": person_id, "technique": taught}, true))
		"invite_spar":
			var invite := invite_of(s, person_id, "spar")
			s.begin_spar(person_id)
			s.battle.invite = str(invite.id)
			return s.finish(s.log_event("invite_kept", {"npc": person_id}))
		"invite_help":
			var invite := invite_of(s, person_id, "help")
			var kind: Dictionary = rules.visits.kinds.help
			var stones := int(round(float(s.content.item(invite.item).price) * int(invite.count) * float(kind.reward_scale)))
			s.remove_item(str(invite.item), int(invite.count))
			s.player.stones = int(s.player.stones) + stones
			Events.apply(s, [{"relation": [person_id, int(kind.favor)]}, {"mind": 2}])
			s.record_deed("help")
			close_invite(s, str(invite.id))
			return s.conclude(s.log_event("help", {"npc": person_id, "loot": "%s:%d" % [invite.item, int(invite.count)], "favor": int(kind.favor), "stones": stones}))
	return ""

static func invite_of(s, person_id: String, kind: String) -> Dictionary:
	for invite: Dictionary in s.world.get("invites", []):
		if invite.npc == person_id and invite.kind == kind:
			return invite
	return {}

static func close_invite(s, invite_id: String) -> void:
	s.world.invites = s.world.get("invites", []).filter(func(invite: Dictionary) -> bool: return invite.id != invite_id)

## A spar kept by appointment: more favor and twice the xp. Called when the spar ends.
static func spar_kept(s, invite_id: String, person_id: String, won: bool) -> Array[String]:
	var texts: Array[String] = []
	var kind: Dictionary = data(s).visits.kinds.spar
	close_invite(s, invite_id)
	Events.apply(s, [{"relation": [person_id, int(kind.favor)]}])
	var xp := int(s.person(person_id).get("realm", 0)) * 30 + 10 * (int(s.person(person_id).get("stage", 0)) + 1)
	texts.append(s.log_event("invite_spar_done", {"npc": person_id, "favor": int(kind.favor)}))
	if won:
		texts.append_array(s.gain_xp(xp * (int(kind.xp_scale) - 1)))
	return texts

## Gathering where a friend asked to go together: twice the finds. Returns the invite, or {}.
static func outing_here(s) -> Dictionary:
	for invite: Dictionary in s.world.get("invites", []):
		if invite.kind == "outing" and invite.place == s.player.location:
			return invite
	return {}

static func finish_outing(s, invite: Dictionary) -> String:
	close_invite(s, str(invite.id))
	Events.apply(s, [{"relation": [str(invite.npc), int(data(s).visits.kinds.outing.favor)]}])
	return s.log_event("outing", {"npc": str(invite.npc), "location": str(invite.place)})

## Answering a request for silver from the 传音 page.
static func answer_loan(s, invite_id: String, lend: bool) -> String:
	var reason: String = s.blocked()
	if not reason.is_empty():
		return reason
	var invite: Dictionary = {}
	for open: Dictionary in s.world.get("invites", []):
		if open.id == invite_id and open.kind == "loan":
			invite = open
	if invite.is_empty():
		return "这桩借贷已经作罢。"
	var kind: Dictionary = data(s).visits.kinds.loan
	if lend and int(s.player.stones) < int(invite.amount):
		return "灵石不够借给他。"
	close_invite(s, invite_id)
	if not lend:
		Events.apply(s, [{"relation": [str(invite.npc), int(kind.refused)]}])
		return s.finish(s.log_event("loan_refused", {"npc": str(invite.npc)}))
	s.player.stones = int(s.player.stones) - int(invite.amount)
	s.world.loans.append({"npc": str(invite.npc), "amount": int(invite.amount), "repay": int(round(float(invite.amount) * float(kind.rate))), "due": int(s.world.day) + int(kind.repay_days)})
	Events.apply(s, [{"relation": [str(invite.npc), int(kind.favor)]}])
	return s.finish(s.log_event("loan_made", {"npc": str(invite.npc), "amount": int(invite.amount)}))

# --- Letters on their own ------------------------------------------------------------------

## Generated acquaintances who hold a 传音符 and are alive, in a stable order.
static func friends(s) -> Array[String]:
	var found: Array[String] = []
	for person_id: String in s.world.people:
		if s.is_generated(person_id) and bool(s.world.people[person_id].get("sound", false)) and _alive(s, person_id):
			found.append(person_id)
	found.sort()
	return found

## The next day letters may be written ({"day", "kind": "visits"}), or silver comes due ("loan"); {} when
## nobody among the people holds a 传音符 and nothing is lent. Checked cheaply, since the scheduler asks
## after every due item.
static func next_due(s, from_day: int) -> Dictionary:
	var best := {}
	var period_days := int(data(s).visits.period_days)
	var last := int(s.world.get("visit_period", int(s.world.day) / period_days))
	var day := (last + 1) * period_days
	if s._writers < 0:
		s._writers = 0
		for person_id: String in s.world.get("people", {}):
			if bool(s.world.people[person_id].get("sound", false)) and person_id.begins_with("g:"):
				s._writers += 1
	if s._writers > 0:
		best = {"day": maxi(from_day, day), "kind": "visits"}
	for loan: Dictionary in s.world.get("loans", []):
		if best.is_empty() or int(loan.due) < int(best.day):
			best = {"day": maxi(from_day, int(loan.due)), "kind": "loan"}
	return best

## The period's letters: each friend may write (gifts arrive with theirs). Never ends a retreat.
static func write_letters(s) -> Array[String]:
	var texts: Array[String] = []
	var visits: Dictionary = data(s).visits
	var period := int(s.world.day) / int(visits.period_days)
	s.world["visit_period"] = period
	for person_id: String in friends(s):
		if s.world.invites.size() >= int(visits.most_open):
			break
		var rng := RandomNumberGenerator.new()
		rng.seed = hash([int(s.world.get("seed", 0)), "visit", person_id, period])
		if rng.randf() >= float(visits.chance):
			continue
		var close: bool = s.favor(person_id) >= int(data(s).aid.favor)
		var kinds: Array = visits.kinds.keys()
		kinds.sort()
		kinds = kinds.filter(func(kind: String) -> bool: return invite_of(s, person_id, kind).is_empty())
		if kinds.is_empty():
			continue
		var total := 0
		for kind: String in kinds:
			total += int(visits.kinds[kind].get("close_weight", visits.kinds[kind].weight)) if close else int(visits.kinds[kind].weight)
		var pick := rng.randi_range(1, total)
		var chosen: String = kinds[0]
		for kind: String in kinds:
			pick -= int(visits.kinds[kind].get("close_weight", visits.kinds[kind].weight)) if close else int(visits.kinds[kind].weight)
			if pick <= 0:
				chosen = kind
				break
		texts.append(_write(s, person_id, chosen, rng))
	return texts

static func _write(s, person_id: String, kind_id: String, rng: RandomNumberGenerator) -> String:
	var kind: Dictionary = data(s).visits.kinds[kind_id]
	var invite := {"id": "%s:%d:%s" % [kind_id, int(s.world.day), person_id], "npc": person_id, "kind": kind_id, "made": int(s.world.day)}
	if kind.has("days"):
		invite.deadline = int(s.world.day) + int(kind.days)
	match kind_id:
		"help", "gift":
			invite.item = kind.items[rng.randi_range(0, kind.items.size() - 1)]
			invite.count = rng.randi_range(int(kind.count[0]), int(kind.count[1]))
		"outing":
			invite.place = kind.places[rng.randi_range(0, kind.places.size() - 1)]
		"loan":
			invite.amount = rng.randi_range(int(kind.amount[0]), int(kind.amount[1]))
	var letter := {"kind": "bond:" + kind_id}
	for key: String in ["item", "count", "place", "amount"]:
		if invite.has(key):
			letter[key] = invite[key]
	if kind_id == "gift":
		s.add_item(str(invite.item), int(invite.count))
	else:
		s.world.invites.append(invite)
	return Storylines.send_letter(s, person_id, letter)

## Silver lent comes back half again at its day, unless the borrower has died.
static func settle_loans(s) -> Array[String]:
	var texts: Array[String] = []
	for loan: Dictionary in s.world.get("loans", []).duplicate():
		if int(loan.due) > int(s.world.day):
			continue
		s.world.loans.erase(loan)
		if _alive(s, str(loan.npc)):
			s.player.stones = int(s.player.stones) + int(loan.repay)
			texts.append(Storylines.send_letter(s, str(loan.npc), {"kind": "bond:repaid", "amount": int(loan.amount), "repay": int(loan.repay)}))
		else:
			texts.append(s.log_event("loan_lost", {"npc": str(loan.npc), "amount": int(loan.amount)}))
	return texts

## Appointments past their day: a spar not kept costs some favor; the rest lapse quietly.
static func expire(s) -> Array[String]:
	var texts: Array[String] = []
	for invite: Dictionary in s.world.get("invites", []).duplicate():
		if not invite.has("deadline") or int(invite.deadline) >= int(s.world.day):
			continue
		close_invite(s, str(invite.id))
		if invite.kind == "spar":
			Events.apply(s, [{"relation": [str(invite.npc), int(data(s).visits.kinds.spar.missed)]}])
			texts.append(s.log_event("invite_missed", {"npc": str(invite.npc)}))
	return texts

## Friends among the generated who send word of a milestone, the closest first, a few at most.
static func congratulate(s) -> Array[String]:
	var texts: Array[String] = []
	var closest := friends(s)
	closest.sort_custom(func(a: String, b: String) -> bool: return s.favor(a) > s.favor(b) or (s.favor(a) == s.favor(b) and a < b))
	for person_id: String in closest.slice(0, int(data(s).most_letters)):
		texts.append(Storylines.send_letter(s, person_id, {"kind": "bond:congrats"}))
	return texts

# --- 传音求援 ------------------------------------------------------------------------------

## Close friends who can be called into a duel now: 亲密, holding a 传音符, alive, not the opponent.
static func allies(s) -> Array[String]:
	var found: Array[String] = []
	if s.battle.is_empty() or s.battle.get("context", "") in ["spar", "tournament"] or bool(s.battle.get("aid_used", false)):
		return found
	for person_id: String in s.world.people:
		if s.favor(person_id) >= int(data(s).aid.favor) and bool(s.world.people[person_id].get("sound", false)) and _alive(s, person_id) and person_id != str(s.battle.get("npc", "")) and not standing(s, person_id).is_empty():
			found.append(person_id)
	found.sort_custom(func(a: String, b: String) -> bool: return _strength(s, a) > _strength(s, b) or (_strength(s, a) == _strength(s, b) and a < b))
	return found

## How hard a friend strikes when called: their best art's harder end with their stage's bonus, raised.
static func _strength(s, person_id: String) -> int:
	var place := standing(s, person_id)
	var bonus := int(s.content.stage(int(place[0]), int(place[1])).attack_bonus)
	var base := 18 + 6 * int(place[1]) + 30 * int(place[0])
	if s.is_generated(person_id):
		base = int(s.Population.foe(s.content, person_id, s.person(person_id)).damage_max)
	return int(round(float(base + bonus) * float(data(s).aid.power)))
