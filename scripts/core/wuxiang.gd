extends RefCounted
## 无相宝录 (docs/SIDEQUESTS_DRAFT3_20261020.md 散): the 散修 无相子 hid what he owned in seven places,
## each with a test (贫、信、智、仁、辨、勇、心), and tore his 宝录 into seven pages; every page tells the
## next place (data/wuxiang.json, the storyline `wuxiang`). Operates on a Session.
## - 影七, a sect's spy among the 散修, hunts the same pages: a place left too long after its step begins
##   (`race_years`) is lost to him, and he sells the page to a sect (`keeper`), where it is bought back,
##   asked for as a favor, stolen (`sense`) or taken by force (a guard; the page's `flags`). The seventh
##   he does not sell: he waits at the ferry for the last duel.
## - Met at 金丹, 影七 offers to share (`ally`: he takes the page `ally_takes` and races no more) or to buy
##   the pages for his sect (`sold`: the story closes, the 散修 count the player a traitor).
## - The well (贫) is gone down with ten stones at most: the rest waits at the top until the page is
##   found, or until the player leaves 青石镇 (the descent must be made again).
## - The pages found end as 散修之主 (`master`: all seven, no share), or shared with 影七 (`shared`).
## world.wuxiang: {"pages": {"<n>": "self" | "reclaimed" | "lost" | "ally"}, "rewarded": [n], "stash",
## "blade" (stages of 无相剑 given), "gambled" (the month of the last try at the stones), "favor" (the
## sect that owes the player), "met", "ally", "sold", "ending"}.
const Calendar = preload("res://scripts/core/calendar.gd")
const Storylines = preload("res://scripts/core/storylines.gd")
const STATES := ["self", "reclaimed", "lost", "ally"]
const ENDINGS := ["", "master", "shared"]

static func data(s) -> Dictionary:
	return s.content.wuxiang_data

static func state(s) -> Dictionary:
	if not s.world.get("wuxiang") is Dictionary:
		s.world["wuxiang"] = {}
	return s.world.wuxiang

## The page `n` (1 to 7) as written in the data.
static func page(s, n: int) -> Dictionary:
	return data(s).pages[n - 1]

static func page_state(s, n: int) -> String:
	return str(state(s).get("pages", {}).get(str(n), ""))

static func _set_page(s, n: int, how: String) -> void:
	if not state(s).has("pages"):
		state(s)["pages"] = {}
	state(s).pages[str(n)] = how

## The page is the player's: found, bought back, or won (a finding or a fallen guard, its `flags`).
static func held(s, n: int) -> bool:
	if page_state(s, n) in ["self", "reclaimed"]:
		return true
	return page(s, n).get("flags", []).any(func(flag: Variant) -> bool: return s.has_flag(str(flag)))

static func lost(s, n: int) -> bool:
	return page_state(s, n) == "lost" and not held(s, n)

## Conditions (events.gd `wuxiang`): "held:n", "lost:n", "decided:n" (held or lost), "own:n" (the
## first n all found by the player's own hand), "favor:<sect>", "can_gamble", "stash", "met", "ally",
## "sold", "master", "shared".
static func met(s, query: String) -> bool:
	var parts := query.split(":")
	match parts[0]:
		"held":
			return held(s, int(parts[1]))
		"lost":
			return lost(s, int(parts[1]))
		"decided":
			return held(s, int(parts[1])) or lost(s, int(parts[1]))
		"own":
			for n: int in range(1, int(parts[1]) + 1):
				if page_state(s, n) != "self":
					return false
			return true
		"favor":
			return str(state(s).get("favor", "")) == parts[1]
		"can_gamble":
			return int(state(s).get("gambled", -1)) != int(s.world.day) / Calendar.DAYS_PER_MONTH
		"stash":
			return int(state(s).get("stash", 0)) > 0
		"met", "ally", "sold":
			return bool(state(s).get(parts[0], false))
		"master", "shared":
			return str(state(s).get("ending", "")) == parts[0]
	return false

## Effects (events.gd `wuxiang`): "descend" (into the well, the rest of the stones left at the top),
## "got:n" (found by the player's hand), "reclaim:n" (bought back, given or stolen), "page:n" (the page's
## reward, once, when it is held), "gamble" (one try at the stones), "save" (the poisoned disciple saved,
## the page lost to 影七 unless he is an ally), "cure" (saved with a pill, nothing lost), "refuse",
## "ally", "sold", "blade" (无相剑 to its next stage), "finish".
static func apply(s, what: String) -> void:
	var parts := what.split(":")
	match parts[0]:
		"descend":
			var keep := int(data(s).stash_keep)
			var left := maxi(0, int(s.player.stones) - keep)
			state(s).stash = int(state(s).get("stash", 0)) + left
			s.player.stones = int(s.player.stones) - left
			s.world.flags[str(data(s).well_flag)] = true
			s.log_event("wuxiang_descend", {"stones": left, "keep": mini(keep, int(s.player.stones))})
		"got":
			_set_page(s, int(parts[1]), "self")
		# Found, but the test failed in spirit (the river gone down alone): the page, not its gift.
		"plain":
			_set_page(s, int(parts[1]), "self")
			var given: Array = state(s).get("rewarded", [])
			if not int(parts[1]) in given:
				given.append(int(parts[1]))
			state(s).rewarded = given
		"reclaim":
			_set_page(s, int(parts[1]), "reclaimed")
		"page":
			_reward(s, int(parts[1]))
		"gamble":
			state(s).gambled = int(s.world.day) / Calendar.DAYS_PER_MONTH
			if s.seeded_roll(["wuxiang", "stones", int(state(s).gambled)]) < float(data(s).gamble_chance):
				_set_page(s, 3, "self")
				s.log_event("wuxiang_gamble_won", {})
			else:
				s.log_event("wuxiang_gamble_lost", {})
		"save":
			state(s).favor = str(page(s, 4).sect)
			if bool(state(s).get("ally", false)):
				_set_page(s, 4, "self")
			else:
				_lose(s, 4)
		"cure":
			state(s).favor = str(page(s, 4).sect)
			_set_page(s, 4, "self")
		"refuse":
			state(s).met = true
		"ally":
			state(s).met = true
			state(s).ally = true
			var taken := int(data(s).ally_takes)
			if not held(s, taken):
				_set_page(s, taken, "ally")
		"sold":
			state(s).met = true
			state(s).sold = true
		"blade":
			_blade(s)
		"finish":
			_finish(s)

## A page's reward, the first time it is held (a page lost and not yet bought back gives nothing). The
## well's stash comes back with the first page.
static func _reward(s, n: int) -> void:
	if n == 1:
		_unstash(s)
	var given: Array = state(s).get("rewarded", [])
	if not held(s, n) or n in given:
		return
	# Held by a finding (the well's last room, the beast below the sea) or by a keeper's guard felled.
	if page_state(s, n).is_empty():
		_set_page(s, n, "self")
	elif page_state(s, n) == "lost":
		_set_page(s, n, "reclaimed")
	given.append(n)
	state(s).rewarded = given
	s.Events.apply(s, page(s, n).reward)

## 无相剑 to its next stage: the blade held is mended in place; one sold or lost is given anew.
static func _blade(s) -> void:
	var blades: Array = data(s).blades
	var stage := int(state(s).get("blade", 0))
	if stage >= blades.size():
		return
	state(s).blade = stage + 1
	if stage > 0 and s.Gear.reforge(s, str(blades[stage - 1]), str(blades[stage])):
		return
	s.add_item(str(blades[stage]), 1)

## 影七 takes a page: sold to its keeper, or for the last one, waiting at the ferry.
static func _lose(s, n: int) -> void:
	_set_page(s, n, "lost")
	var keeper := str(page(s, n).get("keeper", ""))
	if keeper.is_empty():
		s.log_event("wuxiang_lost_last", {"place": str(page(s, n).name)}, true)
	else:
		s.log_event("wuxiang_lost", {"place": str(page(s, n).name), "keeper": str(s.content.locations[keeper].name)}, true)

static func _unstash(s) -> void:
	var kept := int(state(s).get("stash", 0))
	if kept <= 0:
		return
	state(s).stash = 0
	s.player.stones = int(s.player.stones) + kept
	s.log_event("wuxiang_unstash", {"stones": kept})

## How it ends: all seven by the player's own hand or bought back, else shared with 影七.
static func _finish(s) -> void:
	var all := true
	for n: int in range(1, data(s).pages.size() + 1):
		all = all and held(s, n)
	state(s).ending = "master" if all and not bool(state(s).get("ally", false)) else "shared"
	s.log_event("wuxiang_" + str(state(s).ending), {}, true)

## The step of the page being sought now: its number, or 0 when no place is being sought.
static func seeking(s) -> int:
	var step: Dictionary = Storylines.current_step(s, str(data(s).story))
	var id := str(step.get("id", ""))
	if not id.begins_with("p") or id.ends_with("r") or not bool(Storylines.progress(s, str(data(s).story)).get("begun", false)):
		return 0
	return int(id.trim_prefix("p"))

## Called with the location events: the stones left at the well come back once the player leaves 青石镇
## (to go down again, the descent is made again), and 影七 takes a page left too long.
static func check(s) -> void:
	if int(state(s).get("stash", 0)) > 0 and str(s.player.location) != str(data(s).well_place):
		s.world.flags.erase(str(data(s).well_flag))
		_unstash(s)
	var n := seeking(s)
	if n == 0 or bool(state(s).get("ally", false)) or held(s, n) or lost(s, n):
		return
	var since := int(Storylines.progress(s, str(data(s).story)).get("since", int(s.world.day)))
	if int(s.world.day) - since > int(page(s, n).race_years) * Calendar.DAYS_PER_YEAR:
		_lose(s, n)

# --- 散修之主 ----------------------------------------------------------------------------------------

## The share of the price a 散修之主 pays at the 鬼市 and for the alliance's rooms; 1.0 otherwise.
static func discount(s) -> float:
	return float(data(s).master.discount) if met(s, "master") else 1.0

## The share of the usual favor a 散修 asks before guarding a 散修之主's breakthrough.
static func guard_favor(s) -> float:
	return float(data(s).master.guard_favor) if met(s, "master") else 1.0
