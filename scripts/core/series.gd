extends RefCounted
## 成串的战斗 (docs/COMBAT_PLAN.md, part two, B4): fights that come in waves (data/world.json `series`).
## 兽潮守镇 opens in its own window (an event in data/events.json names it); a 护送 can be taken again after
## its cooldown and ends at another place, the road's days passing once it is done. Each wave is one
## fight, often against a pack (群敌, combat.gd); between waves no time passes and some health and qi
## come back. A loss or a flight ends the series, with the usual cost of the fight.
## A `ranked` series (青云试剑崖) is a trial of floors: each floor won is kept (trials.gd) and may pay
## its own (`per_wave`); a loss keeps what was climbed.
## Operates on a Session. player.series: {"id", "wave"} while one is under way; player.series_last:
## {id: the day it was last taken} for cooldowns.

static func definition(s, series_id: String) -> Dictionary:
	return s.content.series.get(series_id, {})

## The series that can be offered where the player stands, in the data's order.
static func here(s) -> Array[String]:
	var found: Array[String] = []
	for series_id: String in s.content.series:
		if str(s.content.series[series_id].location) == str(s.player.location):
			found.append(series_id)
	return found

## Why the series cannot be taken now, or "".
static func block(s, series_id: String) -> String:
	var reason: String = s.blocked()
	if not reason.is_empty():
		return reason
	var series := definition(s, series_id)
	if series.is_empty() or str(series.location) != str(s.player.location) or not s.available_here("series"):
		return "此地没有这件事。"
	if series.has("affiliation") and s.affiliation() != str(series.affiliation):
		return "%s只许%s弟子登临。" % [series.name, s.content.sects[str(series.affiliation)].name]
	var need_realm := int(series.get("min_realm", 0))
	var need_stage := int(series.get("min_stage", 0))
	if int(s.player.realm) < need_realm or (int(s.player.realm) == need_realm and int(s.player.stage) < need_stage):
		return "%s凶险，需达到%s。" % [series.name, s.content.realm_title(need_realm, need_stage)]
	if series.has("event"):
		var event: Dictionary = s.content.events[series.event]
		var window: Dictionary = s.Events.window_at(event, int(s.world.day))
		if window.is_empty():
			return str(series.get("wait_text", "眼下太平，%s要到%s前后。")) % [series.name, s.Calendar.date_text(int(s.Events.next_window(event, int(s.world.day)).get("from", 0)))]
		if not s.Events.open_for(s, str(series.event), window, int(s.world.day)):
			return "这一回的%s已经过去了。" % series.name
	if series.has("cooldown_days"):
		var last := int(s.player.get("series_last", {}).get(series_id, -1))
		if last >= 0 and int(s.world.day) < last + int(series.cooldown_days):
			return "近来没有这样的差事，%s再来问。" % s.Calendar.date_text(last + int(series.cooldown_days))
	return ""

## Takes the series up from the place (the window's event is then counted as answered).
static func take(s, series_id: String) -> String:
	var reason := block(s, series_id)
	if not reason.is_empty():
		return reason
	var series := definition(s, series_id)
	if series.has("event"):
		var event: Dictionary = s.content.events[series.event]
		s.Events.mark_fired(s, str(series.event), s.Events.window_at(event, int(s.world.day)), int(s.world.day))
	return s.finish(begin(s, series_id))

## Starts the first wave (also an event's `series` effect).
static func begin(s, series_id: String) -> String:
	var series := definition(s, series_id)
	if not s.player.has("series_last"):
		s.player["series_last"] = {}
	s.player.series_last[series_id] = int(s.world.day)
	s.player["series"] = {"id": series_id, "wave": 0}
	return s.log_event("series_start", {"series_name": str(series.name)}) + " " + _wave(s)

static func _wave(s) -> String:
	var series := definition(s, str(s.player.series.id))
	var wave: Dictionary = series.waves[int(s.player.series.wave)]
	var foes: Array = wave.foes
	s.Combat.begin_battle(s, str(foes[0]), "event")
	s.battle.series = str(s.player.series.id)
	if foes.size() > 1:
		s.Combat.add_pack(s, foes.slice(1))
	return s.log_event("series_wave", {"wave_text": str(wave.text)})

## A wave is won (combat.gd, after the fight's own spoils): the next one comes at once, after a breath;
## after the last the reward is paid, the road's days pass and the player stands at its end.
static func wave_won(s, message: String) -> String:
	var series_id := str(s.player.series.id)
	var series := definition(s, series_id)
	s.player.series.wave = int(s.player.series.wave) + 1
	# A trial of floors (试剑崖, `ranked`): each floor won is kept as this sitting's mark, and may pay its own.
	if bool(series.get("ranked", false)):
		s.Trials.record(s, series_id, int(s.player.series.wave))
		var floor_reward: Dictionary = series.get("per_wave", {})
		if floor_reward.has("contribution"):
			message += " " + s.Sect.gain(s, int(floor_reward.contribution), "%s登上第 %d 层" % [series.name, int(s.player.series.wave)])
	if int(s.player.series.wave) < series.waves.size():
		var breath := float(series.get("breather", 0.3))
		s.player.hp = mini(int(s.player.max_hp), int(s.player.hp) + int(round(float(s.player.max_hp) * breath)))
		s.player.qi = mini(int(s.player.max_qi), int(s.player.qi) + int(round(float(s.player.max_qi) * breath)))
		return s.finish(message + " " + _wave(s))
	s.player.erase("series")
	var reward: Dictionary = series.get("reward", {})
	s.player.stones = int(s.player.stones) + int(reward.get("stones", 0))
	var found := {}
	for item_id: String in reward.get("items", {}):
		s.add_item(item_id, int(reward.items[item_id]))
		found[item_id] = int(reward.items[item_id])
	# A slip of the reward's tier, of the art and element it names (`manual`: {"tier", "slot", "element"}).
	if reward.has("manual"):
		var filters := {}
		for key: String in ["slot", "element"]:
			if reward.manual.has(key):
				filters[key] = str(reward.manual[key])
		var slip: String = "j:" + s.Arsenal.generate_technique(s.content, s.world_rng, int(reward.manual.tier), filters)
		s.add_item(slip, 1)
		found[slip] = 1
	var text: String = s.log_event("series_done", {"series_name": str(series.name), "stones": int(reward.get("stones", 0)), "done_text": str(series.done_text)})
	if not found.is_empty():
		text += " " + s.log_event("loot", {"loot": s.loot_code(found)})
	if reward.has("contribution"):
		text += " " + s.Sect.gain(s, int(reward.contribution), str(series.name))
	if series.has("to"):
		s.player.location = str(series.to)
	return s.conclude(message + " " + text, s.advance_days(int(series.get("days", 0))))

## The series ends unfinished (a lost or fled wave). Its words for the chronicle.
static func abandon(s) -> String:
	if not s.player.has("series"):
		return ""
	var series := definition(s, str(s.player.series.id))
	s.player.erase("series")
	return s.log_event("series_failed", {"series_name": str(series.get("name", ""))})
