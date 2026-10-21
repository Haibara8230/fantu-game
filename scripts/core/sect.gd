extends RefCounted
## The player's standing in a sect, after 觅长生's 宗门: rank, contribution, stipend, the exchange and
## donations. Operates on a Session; the numbers live in data/sect.json, one table per sect under `sects`.
## Sects stand in tiers (`tiers`: 入流, 世家, 小宗, 中宗, 大宗, 上宗). Each has its own place, ranks,
## duties, exchange and board, and its own way of taking disciples (`join`: the most realm it takes, a
## spirit root it asks for, the years it recruits in, the 神识 or 气血 its trial wants).
## The player belongs to one sect at a time (player.affiliation, "" for a wanderer). Moving to a sect of a
## higher tier is leaving with the old sect's blessing; to one of the same or a lower tier is betrayal:
## the old sect is written in player.betrayed, takes the player back never, and its people think less
## of them (`betray_favor`). Either way the standing starts afresh in the new sect.
## Contribution (贡献) comes from the sect's commissions (patrols among them), the sect's errands,
## donations, the outer tournament and great deeds. It is kept twice: player.contribution is what can
## be spent at the exchange; player.merit only grows and decides promotion. A rank asks for merit and a
## stage of cultivation (and, for some, days served: `days`; a rank marked `story` is given only by the
## sect's own story); it pays a modest monthly stipend automatically as world time passes
## and makes retreats in the sect a little richer. Old unclaimed arrears retain their one-year cap. The exchange sells pills and rotating jade
## slips for contribution, each good within its own limit per period; some only to a rank.
## Ranks share their ids across sects (`rank_ids`), so a condition or a spot may ask for "inner" anywhere.
## From the inner court a disciple may hold one duty (职司, `duties`), changed at most once a year:
## the 丹房 (alchemy), the patrols (more contribution from commissions), the hall (faster study).
## player.duty is the duty's id ("" for none) and player.duty_day the day it was taken.
## player.rank is the rank's index; player.sect_day the day the player joined; player.stipend_day the
## day the uncollected stipend began; player.exchanged counts goods taken per period
## ("<good>:<period>[:<slot>]"); player.donated the contribution donated in the current donation period
## {"period", "amount"}.
const Arsenal = preload("res://scripts/core/arsenal.gd")

static func data(s) -> Dictionary:
	return s.content.sect_data

## Every sect's table by id.
static func sects(s) -> Dictionary:
	return data(s).sects

## A sect's table, {} when unknown.
static func info(s, sect_id: String) -> Dictionary:
	return sects(s).get(sect_id, {})

static func name_of(s, sect_id: String) -> String:
	return str(info(s, sect_id).get("name", sect_id))

## The order of a sect's tier, low to high.
static func tier_order(s, sect_id: String) -> int:
	return int(data(s).tiers.get(str(info(s, sect_id).get("tier", "")), {}).get("order", -1))

static func tier_name(s, sect_id: String) -> String:
	return str(data(s).tiers.get(str(info(s, sect_id).get("tier", "")), {}).get("name", ""))

## The sect the player belongs to, "" for a wanderer.
static func own_id(s) -> String:
	return str(s.player.get("affiliation", ""))

## The table of the player's sect; a wanderer reads the home sect's, which only the 宗门 page shows.
static func own(s) -> Dictionary:
	var table := info(s, own_id(s))
	return table if not table.is_empty() else info(s, str(s.content.rules.lineage.home))

## Whether the player is one of a sect's own; a wanderer has no rank, stipend or exchange.
static func member(s) -> bool:
	return not info(s, own_id(s)).is_empty()

## The sect that takes disciples here, or "".
static func here(s) -> String:
	for sect_id: String in sects(s):
		if str(info(s, sect_id).place) == str(s.player.location):
			return sect_id
	return ""

## Where a sect's business is done: "<place><office>", e.g. 青云山执事堂.
static func office_text(s, sect_id: String = "") -> String:
	var table := info(s, sect_id) if not sect_id.is_empty() else own(s)
	return "%s%s" % [s.content.locations[str(table.place)].name, table.office]

## Where a sect takes disciples: the name of its recruiting spot.
static func gate_text(s, sect_id: String) -> String:
	var place: Dictionary = s.content.locations[str(info(s, sect_id).place)]
	for spot: Dictionary in place.spots:
		if "join_sect" in spot.actions:
			return "%s%s" % [place.name, spot.name]
	return str(place.name)

## The year a sect that recruits every few years next opens its gate, from `day`.
static func next_intake_year(s, sect_id: String, day: int) -> int:
	var every := int(info(s, sect_id).join.get("every_years", 1))
	var year: int = s.Calendar.year(day)
	return year if year % every == 0 else year + every - year % every

## Why the player cannot join `sect_id` here now, or "".
static func join_block(s, sect_id: String = "") -> String:
	if sect_id.is_empty():
		sect_id = here(s)
	var reason: String = s.blocked()
	if not reason.is_empty():
		return reason
	var table := info(s, sect_id)
	if table.is_empty():
		return "此处没有收徒的宗门。"
	if str(s.player.location) != str(table.place) or not s.available_here("join_sect"):
		return "须到%s。" % gate_text(s, sect_id)
	var name := str(table.name)
	if closed(s, sect_id):
		return "%s已经没有了。" % name
	if own_id(s) == sect_id:
		return "你已是%s弟子。" % name
	if sect_id in s.player.get("betrayed", []):
		return "你叛出过%s，那里不会再收你。" % name
	var join: Dictionary = table.join
	if int(s.player.realm) > int(join.get("realm_most", 1)):
		return "以你如今的修为，%s已收不下你做弟子；日后或可另谈客卿之约。" % name
	if join.has("root") and not str(join.root) in s.player.get("roots", []):
		return "%s只收身具%s灵根的弟子。" % [name, s.content.element_info(str(join.root)).get("name", join.root)]
	var year: int = s.Calendar.year(int(s.world.day))
	if year % int(join.get("every_years", 1)) != 0:
		return "%s每 %d 年收一次徒，下一回在历元 %d 年。" % [name, int(join.every_years), next_intake_year(s, sect_id, int(s.world.day))]
	if join.has("sense") and s.sense() < int(join.sense):
		return "%s考的阵图你看不透：神识须 %d（你 %d）。" % [name, int(join.sense), s.sense()]
	if join.has("hp") and int(s.player.get("max_hp", 0)) < int(join.hp):
		return "你扛不过%s的「负山」：气血须 %d（你 %d）。" % [name, int(join.hp), int(s.player.get("max_hp", 0))]
	return ""

## Whether joining `sect_id` would be betrayal of the sect the player is in now.
static func betrays(s, sect_id: String) -> bool:
	return member(s) and tier_order(s, sect_id) <= tier_order(s, own_id(s))

## Joins `sect_id` (the sect here by default): leaving the old sect, as a move up or a betrayal, and
## starting in the new one at the rank the player's cultivation already merits (up to the inner court).
static func join(s, sect_id: String = "") -> String:
	if sect_id.is_empty():
		sect_id = here(s)
	var reason := join_block(s, sect_id)
	if not reason.is_empty():
		return reason
	var texts: Array[String] = []
	var old := own_id(s) if member(s) else ""
	if not old.is_empty():
		if betrays(s, sect_id):
			var betrayed: Array = s.player.get("betrayed", [])
			betrayed.append(old)
			s.player["betrayed"] = betrayed
			for person_id: String in info(s, old).get("people", []):
				if s.is_person(person_id):
					s.Events.apply(s, [{"relation": [person_id, int(data(s).betray_favor)]}])
			texts.append(s.log_event("sect_betrayed", {"old": old, "faction": sect_id}, true))
		else:
			texts.append(s.log_event("sect_moved", {"old": old, "faction": sect_id}, true))
	texts.append_array(_enter(s, sect_id))
	texts.append(s.log_event("join_sect", {"faction": sect_id}, true))
	return s.finish(" ".join(texts.filter(func(text: String) -> bool: return not text.is_empty())))

## Takes the player into `sect_id` with a fresh standing; returns the texts of 客卿 bonds the new sect
## does not allow, laid down (guest.gd).
static func _enter(s, sect_id: String) -> Array[String]:
	s.player.affiliation = sect_id
	s.player.rank = start_rank(s)
	s.player.contribution = 0
	s.player.merit = 0
	s.player.duty = ""
	s.player.duty_day = -1
	s.player.exchanged = {}
	s.player.donated = {}
	s.player.stipend_day = int(s.world.day)
	s.player.sect_day = int(s.world.day)
	return s.Guest.prune(s)

## Whether a sect is no more: merged into another or disbanded by its story (world flag
## sect_closed_<id>).
static func closed(s, sect_id: String) -> bool:
	return s.has_flag("sect_closed_" + sect_id)

## A sect's story ends it: merged into `into`, or disbanded when "". Its disciple goes with it into the
## other sect (no betrayal: the sect itself chose it) or is left a wanderer. Returns the chronicle text.
static func close(s, sect_id: String, into: String) -> String:
	s.world.flags["sect_closed_" + sect_id] = true
	if own_id(s) != sect_id:
		return ""
	if into.is_empty():
		s.player.affiliation = ""
		s.player.duty = ""
		return s.log_event("sect_dissolved", {"old": sect_id}, true)
	var texts: Array[String] = _enter(s, into)
	texts.append(s.log_event("sect_merged", {"old": sect_id, "faction": into}, true))
	return " ".join(texts.filter(func(text: String) -> bool: return not text.is_empty()))

## The rank a newcomer's cultivation merits: the highest whose stage is reached, at most the inner court;
## a rank that asks for days served (长青's year of chores) or is given by story is never skipped.
static func start_rank(s) -> int:
	var best := 0
	var cap: int = s.content.rank_index("inner")
	for index: int in mini(ranks(s).size(), cap + 1):
		var r: Dictionary = ranks(s)[index]
		if index > 0 and (bool(r.get("story", false)) or r.has("days")):
			break
		if _stage_reached(s, r.stage):
			best = index
	return best

static func _stage_reached(s, stage: Array) -> bool:
	return int(s.player.realm) > int(stage[0]) or (int(s.player.realm) == int(stage[0]) and int(s.player.stage) >= int(stage[1]))

static func ranks(s) -> Array:
	return own(s).ranks

static func rank(s) -> Dictionary:
	return ranks(s)[clampi(int(s.player.get("rank", 0)), 0, ranks(s).size() - 1)]

## A rank's index by id (ids are shared by every sect), -1 when unknown.
static func rank_index(s, rank_id: String) -> int:
	return s.content.rank_index(rank_id)

static func next_rank(s) -> Dictionary:
	var index := int(s.player.get("rank", 0)) + 1
	return ranks(s)[index] if index < ranks(s).size() else {}

## The player's sect's duties: {"rank", "change_days", "list"}.
static func duties(s) -> Dictionary:
	return own(s).duties

## The duty held, {} for none.
static func duty(s) -> Dictionary:
	return duties(s).list.get(str(s.player.get("duty", "")), {}) if member(s) else {}

## What the held duty adds to `key` (alchemy, contribution_percent, study), 0 without one.
static func duty_value(s, key: String) -> int:
	return int(duty(s).get(key, 0))

## Why the duty cannot be taken now, or "".
static func duty_block(s, duty_id: String) -> String:
	var reason: String = s.blocked()
	if not reason.is_empty():
		return reason
	if not member(s):
		return "你没有宗门。"
	var table := duties(s)
	if not table.list.has(duty_id):
		return "没有这个职司。"
	if not s.available_here("sect"):
		return "须到%s领受职司。" % office_text(s)
	if int(s.player.get("rank", 0)) < rank_index(s, str(table.rank)):
		return "须是%s才能领受职司。" % ranks(s)[rank_index(s, str(table.rank))].name
	if str(s.player.get("duty", "")) == duty_id:
		return "你已担着此职。"
	var since := int(s.player.get("duty_day", -1))
	if since >= 0 and int(s.world.day) < since + int(table.change_days):
		return "职司一年一换，%s后可改。" % s.Calendar.duration_text(since + int(table.change_days) - int(s.world.day))
	return ""

static func take_duty(s, duty_id: String) -> String:
	var reason := duty_block(s, duty_id)
	if not reason.is_empty():
		return reason
	s.player["duty"] = duty_id
	s.player["duty_day"] = int(s.world.day)
	return s.finish(s.log_event("duty_taken", {"duty": str(duties(s).list[duty_id].name), "faction": own_id(s)}))

## Adds contribution (and merit) from the sect; returns the chronicle text, or "" for nothing.
static func gain(s, amount: int, reason: String = "") -> String:
	# Contribution is the sect's own reckoning: a wanderer earns none.
	if amount <= 0 or not member(s):
		return ""
	s.player["contribution"] = int(s.player.get("contribution", 0)) + amount
	s.player["merit"] = int(s.player.get("merit", 0)) + amount
	if reason.is_empty():
		return ""
	return s.log_event("contribution", {"amount": amount, "reason": reason})

## Why the player cannot be promoted now, or "".
static func promotion_block(s) -> String:
	var next := next_rank(s)
	if next.is_empty():
		return "已是宗门所能给的最高身份。"
	if bool(next.get("story", false)):
		return "%s之位不靠贡献，只能由门中大事定下。" % next.name
	var stage: Array = next.stage
	var short: Array[String] = []
	if int(s.player.get("merit", 0)) < int(next.merit):
		short.append("累计贡献 %d / %d" % [int(s.player.get("merit", 0)), int(next.merit)])
	if not _stage_reached(s, stage):
		short.append("修为需达%s" % s.content.realm_title(int(stage[0]), int(stage[1])))
	var served := int(s.world.day) - int(s.player.get("sect_day", 0))
	if next.has("days") and served < int(next.days):
		short.append("在门中再待%s" % s.Calendar.duration_text(int(next.days) - served))
	if not short.is_empty():
		return "晋升%s还需：%s。" % [next.name, "，".join(short)]
	return ""

static func promote(s) -> String:
	var reason: String = s.blocked()
	if reason.is_empty() and not member(s):
		reason = "你没有宗门。"
	if reason.is_empty() and not s.available_here("sect"):
		reason = "须到%s办理。" % office_text(s)
	if reason.is_empty():
		reason = promotion_block(s)
	if not reason.is_empty():
		return reason
	pay_passive(s, int(s.world.day))
	s.player["rank"] = int(s.player.get("rank", 0)) + 1
	return s.conclude(" ".join(_ranked(s).filter(func(text: String) -> bool: return not text.is_empty())))

## Raises the player to `rank_id` in their sect at once (a sect's story: 门主), with the usual words.
static func raise_to(s, rank_id: String) -> String:
	var index := rank_index(s, rank_id)
	if not member(s) or index < 0 or index >= ranks(s).size() or index <= int(s.player.get("rank", 0)):
		return ""
	pay_passive(s, int(s.world.day))
	s.player["rank"] = index
	return " ".join(_ranked(s).filter(func(text: String) -> bool: return not text.is_empty()))

## The chronicle of a new rank, the host's favour and the congratulations.
static func _ranked(s) -> Array[String]:
	var now := rank(s)
	var texts: Array[String] = [s.log_event("rank_up", {"rank": int(s.player.rank), "faction": own_id(s)}, true)]
	if now.has("host"):
		s.Events.apply(s, [{"relation": [str(now.host), 10]}])
	texts.append_array(s.congratulate("promotion"))
	return texts

## Pays months elapsed during this action plus capped old arrears, keeping incomplete months.
## Called before a promotion as well, so an old rank's arrears cannot acquire the new rate.
static func pay_passive(s, from_day: int) -> String:
	var rule: Dictionary = data(s).stipend
	# A wanderer draws no stipend; the reckoning starts on the day one joins.
	if not member(s):
		s.player["stipend_day"] = int(s.world.day)
		return ""
	var since := int(s.player.get("stipend_day", from_day))
	var span := int(rule.period_days)
	var old_months := maxi(0, from_day - since) / span
	var total_months := maxi(0, int(s.world.day) - since) / span
	var paid := mini(old_months, int(rule.most_periods)) + total_months - old_months
	if total_months == 0:
		return ""
	s.player["stipend_day"] = since + total_months * span
	# player.sect selects a martial lineage; membership is player.affiliation, standing in it the rank.
	var stones := paid * int(rank(s).stipend)
	s.player.stones = int(s.player.stones) + stones
	return "月俸自动入账：%d 个月，共 %d 灵石。" % [paid, stones] if stones > 0 else ""

## The stipend waiting to be collected: {"periods", "stones"}.
static func stipend_due(s) -> Dictionary:
	if not member(s):
		return {"periods": 0, "stones": 0}
	var rule: Dictionary = data(s).stipend
	var periods := mini(int(rule.most_periods), maxi(0, int(s.world.day) - int(s.player.get("stipend_day", 0))) / int(rule.period_days))
	return {"periods": periods, "stones": periods * int(rank(s).stipend)}

static func collect_stipend(s) -> String:
	var reason: String = s.blocked()
	if reason.is_empty() and not s.available_here("sect"):
		reason = "月俸须到%s领取。" % office_text(s)
	if not reason.is_empty():
		return reason
	var due := stipend_due(s)
	if int(due.periods) < 1:
		return "这个月的月俸已经领过了。"
	var rule: Dictionary = data(s).stipend
	s.player.stones = int(s.player.stones) + int(due.stones)
	# Months beyond what piles up are lost; the next month starts from today's.
	var waited := int(s.world.day) - int(s.player.get("stipend_day", 0))
	if waited / int(rule.period_days) > int(rule.most_periods):
		s.player["stipend_day"] = int(s.world.day)
	else:
		s.player["stipend_day"] = int(s.player.get("stipend_day", 0)) + int(due.periods) * int(rule.period_days)
	return s.conclude(s.log_event("stipend", {"stones": int(due.stones), "months": int(due.periods), "rank": int(s.player.get("rank", 0)), "faction": own_id(s)}))

# --- Exchange ------------------------------------------------------------------------------

## What the player's sect's exchange offers now: [{"key", "item", "price", "left", "block"}], jade
## slips drawn afresh each period from the world seed.
static func goods(s) -> Array[Dictionary]:
	var result: Array[Dictionary] = []
	for good: Dictionary in own(s).exchange:
		var period := int(s.world.day) / int(good.per_days)
		var slots := int(good.get("count", 1))
		for slot: int in slots:
			var key := "%s:%d" % [good.id, period] if not good.has("manual") else "%s:%d:%d" % [good.id, period, slot]
			var item_id: String = good.get("item", "")
			if good.has("manual"):
				var rng := RandomNumberGenerator.new()
				rng.seed = hash([int(s.world.get("seed", 0)), "sect_exchange", good.id, period, slot] + ([] if own_id(s) == str(s.content.rules.lineage.home) else [own_id(s)]))
				item_id = "j:" + Arsenal.generate_technique(s.content, rng, int(good.manual))
			var left := int(good.limit) - int(s.player.get("exchanged", {}).get(key, 0))
			var block := ""
			if good.has("rank") and int(s.player.get("rank", 0)) < rank_index(s, str(good.rank)):
				block = "须为%s。" % ranks(s)[rank_index(s, str(good.rank))].name
			elif s.Alchemy.knows(s, str(_recipe_taught(s, item_id))):
				block = "你已通晓此丹方。"
			elif left <= 0:
				block = "此期已换完，%d 日后再来。" % ((period + 1) * int(good.per_days) - int(s.world.day))
			elif int(s.player.get("contribution", 0)) < int(good.price):
				block = "贡献不足。"
			result.append({"key": key, "item": item_id, "price": int(good.price), "left": maxi(0, left), "block": block})
	return result

## The recipe a 丹方 item teaches, or "".
static func _recipe_taught(s, item_id: String) -> String:
	for effect: Dictionary in s.content.item(item_id).get("use", []):
		if effect.has("recipe"):
			return str(effect.recipe)
	return ""

static func exchange(s, key: String) -> String:
	var reason: String = s.blocked()
	if reason.is_empty() and not s.available_here("sect"):
		reason = "须到%s兑换。" % office_text(s)
	if not reason.is_empty():
		return reason
	for good: Dictionary in goods(s):
		if good.key != key:
			continue
		if not str(good.block).is_empty():
			return good.block
		s.player["contribution"] = int(s.player.contribution) - int(good.price)
		if not s.player.has("exchanged"):
			s.player["exchanged"] = {}
		s.player.exchanged[key] = int(s.player.exchanged.get(key, 0)) + 1
		_prune(s)
		s.add_item(str(good.item), 1)
		return s.conclude(s.log_event("exchange", {"item": str(good.item), "price": int(good.price)}))
	return "宗门没有此物可换。"

## Forgets counts from periods long past, so the save stays small.
static func _prune(s) -> void:
	for key: String in s.player.exchanged.keys():
		var parts := key.split(":")
		var per := 0
		for good: Dictionary in own(s).exchange:
			if good.id == parts[0]:
				per = int(good.per_days)
		if per <= 0 or int(parts[1]) < int(s.world.day) / per:
			s.player.exchanged.erase(key)

# --- Donations -----------------------------------------------------------------------------

## Contribution that can still be earned by donating in this period.
static func donation_left(s) -> int:
	var rule: Dictionary = data(s).donation
	var period := int(s.world.day) / int(rule.period_days)
	var donated: Dictionary = s.player.get("donated", {})
	var given := int(donated.get("amount", 0)) if int(donated.get("period", -1)) == period else 0
	return maxi(0, int(rule.most) - given)

## What donating `count` of an item would earn now (0 when the sect does not take it).
static func donation_value(s, item_id: String, count: int) -> int:
	var rule: Dictionary = data(s).donation
	var item: Dictionary = s.content.item(item_id)
	if item.is_empty() or not str(item.get("category", "")) in rule.categories:
		return 0
	return mini(donation_left(s), int(floor(float(item.price) * count * float(rule.rate))))

static func donate(s, item_id: String, count: int) -> String:
	var reason: String = s.blocked()
	if reason.is_empty() and not s.available_here("sect"):
		reason = "须到%s捐献。" % office_text(s)
	if not reason.is_empty():
		return reason
	if count < 1 or s.item_count(item_id) < count:
		return "行囊里没有那么多。"
	var value := donation_value(s, item_id, count)
	if value <= 0:
		return "本月的捐献已到上限，或宗门不收此物。"
	var rule: Dictionary = data(s).donation
	var period := int(s.world.day) / int(rule.period_days)
	s.remove_item(item_id, count)
	s.player["donated"] = {"period": period, "amount": int(rule.most) - donation_left(s) + value}
	var text: String = s.log_event("donate", {"loot": "%s:%d" % [item_id, count], "amount": value})
	gain(s, value)
	return s.conclude(text)

## How much faster retreats in the sect go for this rank, in percent.
static func retreat_bonus(s) -> int:
	return int(rank(s).get("retreat", 0)) if member(s) else 0
