extends RefCounted
## The player's standing in the sect, after 觅长生's 宗门: rank, contribution, stipend, the exchange and
## donations. Operates on a Session; the numbers live in data/sect.json.
## Contribution (贡献) comes from the sect's commissions (patrols among them), the sect's errands,
## donations, the outer tournament and great deeds. It is kept twice: player.contribution is what can
## be spent at the exchange; player.merit only grows and decides promotion. A rank asks for merit and a
## stage of cultivation; it pays a modest monthly stipend automatically as world time passes
## and makes retreats in the sect a little richer. Old unclaimed arrears retain their one-year cap. The exchange sells pills and rotating jade
## slips for contribution, each good within its own limit per period; some only to a rank.
## From the inner court a disciple may hold one duty (职司, `duties`), changed at most once a year:
## 丹房执事 (alchemy), 巡山执事 (more contribution from commissions), 传功执事 (faster study).
## player.duty is the duty's id ("" for none) and player.duty_day the day it was taken.
## player.rank is the rank's index; player.stipend_day the day the uncollected stipend began;
## player.exchanged counts goods taken per period ("<good>:<period>[:<slot>]"); player.donated the
## contribution donated in the current donation period {"period", "amount"}.
const Arsenal = preload("res://scripts/core/arsenal.gd")

static func data(s) -> Dictionary:
	return s.content.sect_data

## Whether the player is one of the sect's own (player.affiliation); a wanderer has no rank, stipend or
## exchange.
static func member(s) -> bool:
	return str(s.player.get("affiliation", "")) == str(s.content.rules.lineage.home)

## Why the player cannot join 青云 here now, or "".
static func join_block(s) -> String:
	var reason: String = s.blocked()
	if not reason.is_empty():
		return reason
	if not s.available_here("join_sect"):
		return "须到青云山接引台。"
	if not str(s.player.get("affiliation", "")).is_empty():
		return "你已有宗门。"
	if int(s.player.realm) > int(data(s).get("join_most_realm", 1)):
		return "以你如今的修为，青云已收不下你做弟子；日后或可另谈客卿之约。"
	return ""

## Joins 青云 as an outer disciple: rank, stipend and the sect's places open to the player from today.
static func join(s) -> String:
	var reason := join_block(s)
	if not reason.is_empty():
		return reason
	s.player.affiliation = str(s.content.rules.lineage.home)
	s.player.rank = 0
	s.player.stipend_day = int(s.world.day)
	return s.finish(s.log_event("join_sect", {}, true))

static func ranks(s) -> Array:
	return data(s).ranks

static func rank(s) -> Dictionary:
	return ranks(s)[clampi(int(s.player.get("rank", 0)), 0, ranks(s).size() - 1)]

static func rank_index(s, rank_id: String) -> int:
	for index: int in ranks(s).size():
		if ranks(s)[index].id == rank_id:
			return index
	return -1

static func next_rank(s) -> Dictionary:
	var index := int(s.player.get("rank", 0)) + 1
	return ranks(s)[index] if index < ranks(s).size() else {}

## The duty held, {} for none.
static func duty(s) -> Dictionary:
	return data(s).duties.list.get(str(s.player.get("duty", "")), {})

## What the held duty adds to `key` (alchemy, contribution_percent, study), 0 without one.
static func duty_value(s, key: String) -> int:
	return int(duty(s).get(key, 0))

## Why the duty cannot be taken now, or "".
static func duty_block(s, duty_id: String) -> String:
	var reason: String = s.blocked()
	if not reason.is_empty():
		return reason
	var duties: Dictionary = data(s).duties
	if not duties.list.has(duty_id):
		return "没有这个职司。"
	if not s.available_here("sect"):
		return "须到青云山执事堂领受职司。"
	if int(s.player.get("rank", 0)) < rank_index(s, str(duties.rank)):
		return "须是%s才能领受职司。" % ranks(s)[rank_index(s, str(duties.rank))].name
	if str(s.player.get("duty", "")) == duty_id:
		return "你已担着此职。"
	var since := int(s.player.get("duty_day", -1))
	if since >= 0 and int(s.world.day) < since + int(duties.change_days):
		return "职司一年一换，%s后可改。" % s.Calendar.duration_text(since + int(duties.change_days) - int(s.world.day))
	return ""

static func take_duty(s, duty_id: String) -> String:
	var reason := duty_block(s, duty_id)
	if not reason.is_empty():
		return reason
	s.player["duty"] = duty_id
	s.player["duty_day"] = int(s.world.day)
	return s.finish(s.log_event("duty_taken", {"duty": str(data(s).duties.list[duty_id].name)}))

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
	var stage: Array = next.stage
	var short: Array[String] = []
	if int(s.player.get("merit", 0)) < int(next.merit):
		short.append("累计贡献 %d / %d" % [int(s.player.get("merit", 0)), int(next.merit)])
	if int(s.player.realm) < int(stage[0]) or (int(s.player.realm) == int(stage[0]) and int(s.player.stage) < int(stage[1])):
		short.append("修为需达%s" % s.content.realm_title(int(stage[0]), int(stage[1])))
	if not short.is_empty():
		return "晋升%s还需：%s。" % [next.name, "，".join(short)]
	return ""

static func promote(s) -> String:
	var reason: String = s.blocked()
	if reason.is_empty() and not s.available_here("sect"):
		reason = "须到青云山执事堂办理。"
	if reason.is_empty():
		reason = promotion_block(s)
	if not reason.is_empty():
		return reason
	pay_passive(s, int(s.world.day))
	s.player["rank"] = int(s.player.get("rank", 0)) + 1
	var now := rank(s)
	var texts: Array[String] = [s.log_event("rank_up", {"rank": int(s.player.rank)}, true)]
	if now.has("host"):
		s.Events.apply(s, [{"relation": [str(now.host), 10]}])
	texts.append_array(s.congratulate("promotion"))
	return s.conclude(" ".join(texts.filter(func(text: String) -> bool: return not text.is_empty())))

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
		reason = "月俸须到青云山执事堂领取。"
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
	return s.conclude(s.log_event("stipend", {"stones": int(due.stones), "months": int(due.periods), "rank": int(s.player.get("rank", 0))}))

# --- Exchange ------------------------------------------------------------------------------

## What the exchange offers now: [{"key", "item", "price", "left", "block"}], jade slips drawn afresh
## each period from the world seed.
static func goods(s) -> Array[Dictionary]:
	var result: Array[Dictionary] = []
	for good: Dictionary in data(s).exchange:
		var period := int(s.world.day) / int(good.per_days)
		var slots := int(good.get("count", 1))
		for slot: int in slots:
			var key := "%s:%d" % [good.id, period] if not good.has("manual") else "%s:%d:%d" % [good.id, period, slot]
			var item_id: String = good.get("item", "")
			if good.has("manual"):
				var rng := RandomNumberGenerator.new()
				rng.seed = hash([int(s.world.get("seed", 0)), "sect_exchange", good.id, period, slot])
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
		reason = "须到青云山执事堂兑换。"
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
	var longest := 0
	for good: Dictionary in data(s).exchange:
		longest = maxi(longest, int(good.per_days))
	for key: String in s.player.exchanged.keys():
		var parts := key.split(":")
		var per := 0
		for good: Dictionary in data(s).exchange:
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
		reason = "须到青云山执事堂捐献。"
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
