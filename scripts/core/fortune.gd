extends RefCounted
## 机缘: rare fortune on the way to a breakthrough, after the web novels. Operates on a Session.
## Each kind comes at most once in a life (player.boons) and only by chance, scaled by the talents for
## fortune; the chances live in rules.fortune.
## - 顿悟 (epiphany): staying a while at a place that stirs the mind, held at a bottleneck or at the
##   realm's most. Sitting in meditation breaks a sub-stage's bottleneck at once, or, before a
##   breakthrough, leaves it surer and the foundation better (ready until the attempt).
## - 生死之间 (brink): winning a duel against an equal or stronger foe with almost no health left, held
##   at the same thresholds: the same, without the choice.
## - 天材地宝: a 千年石乳 behind the old cave's dripstones (caves.gd: placed or not on the first visit,
##   found with 神识 enough), a 九曲灵参 on the valley's slope.
## - 灵眼: found while gathering in the valley, more often the keener the 神识; breaking through there
##   is surer.
## - 残魂灌顶: a remnant soul in the old cave's sealed chamber (caves.gd: placed or not on the first
##   visit) offers its blessing before foundation. Accepted with mind
##   enough, the next breakthrough is certain and a talent is left behind; without, it tries to take the
##   body and leaves a wound and a flaw. Refused, it leaves a jade slip.
## Some of these may also leave a talent behind (rules.fortune.*.talent).
const Talents = preload("res://scripts/core/talents.gd")

static func rules(s) -> Dictionary:
	return s.content.rules.fortune

static func met(s, id: String) -> bool:
	return s.player.get("boons", {}).has(id)

static func _mark(s, id: String, state: String) -> void:
	if not s.player.has("boons"):
		s.player["boons"] = {}
	s.player.boons[id] = state

## The chance of a kind of fortune, after the talents for it.
static func chance(s, id: String) -> float:
	return Talents.chance(float(rules(s)[id].chance), s.talent_modifier("boon"))

## Whether the roll for a kind of fortune comes up now (and it has not been met).
static func _comes(s, id: String, scale: float = 1.0) -> bool:
	return not met(s, id) and s.fortune_roll(id) < chance(s, id) * scale

## Held at a threshold fortune can help with: a sub-stage's bottleneck, or the realm's most before a
## breakthrough.
static func at_threshold(s) -> bool:
	return s.at_bottleneck() or (s.at_xp_cap() and not s.next_breakthrough().is_empty())

## After staying `days` somewhere: perhaps 顿悟 (a choice becomes pending). Returns texts.
static func after_wait(s, days: int) -> Array[String]:
	var texts: Array[String] = []
	var rule: Dictionary = rules(s).epiphany
	if not s.pending_event.is_empty() or not at_threshold(s) or not str(s.player.location) in rule.places:
		return texts
	if _comes(s, "epiphany", minf(1.0, float(days) / float(rule.per_days))):
		s.pending_event = {"id": str(rule.event), "day": int(s.world.day)}
	return texts

## After winning a duel against a foe of `foe_realm` or above with health nearly gone: perhaps 生死之间.
static func after_win(s, foe_realm: int) -> Array[String]:
	var texts: Array[String] = []
	var rule: Dictionary = rules(s).brink
	if foe_realm < int(s.player.realm) or int(s.player.hp) * 100 > int(s.player.max_hp) * int(rule.hp_percent) or not at_threshold(s):
		return texts
	if _comes(s, "brink"):
		texts.append(s.log_event("boon_brink", {}, true))
		texts.append_array(_insight(s, "brink"))
	return texts

## A 天材地宝 found (`shiru`, `lingshen`): into the pack, once in a life, a milestone.
static func grant_treasure(s, id: String) -> String:
	var item := str(rules(s)[id].item)
	_mark(s, id, "spent")
	s.add_item(item, 1)
	return s.log_event("boon_treasure", {"item": item, "location": str(s.player.location)}, true)

## After gathering: in the valley perhaps a 九曲灵参, perhaps the 灵眼.
static func after_gather(s) -> Array[String]:
	var texts: Array[String] = []
	var herb: Dictionary = rules(s).lingshen
	if str(s.player.location) == str(herb.location) and _comes(s, "lingshen"):
		texts.append(grant_treasure(s, "lingshen"))
	var eye: Dictionary = rules(s).spirit_eye
	if str(s.player.location) == str(eye.location) and not s.has_flag(str(eye.flag)) and _comes(s, "spirit_eye", float(s.sense()) / float(eye.sense_reference)):
		_mark(s, "spirit_eye", "spent")
		texts.append(s.Events.start(s, str(eye.event)))
	return texts

## What fortune leaves when taken up (the effect `fortune`): 顿悟 sat through, the remnant accepted.
static func bestow(s, id: String) -> void:
	match id:
		"epiphany":
			var rule: Dictionary = rules(s).epiphany
			s.advance_days(int(rule.days))
			_insight(s, "epiphany")
		"remnant":
			var rule: Dictionary = rules(s).remnant
			if int(s.player.get("mind", 0)) >= int(rule.mind):
				_mark(s, "remnant", "ready")
				s.log_event("remnant_blessed", {}, true)
				s.gain_talent(str(rule.talent))
			else:
				_mark(s, "remnant", "spent")
				s.player.hp = 1
				s.player["injury_until"] = maxi(int(s.player.get("injury_until", 0)), int(s.world.day) + int(rule.injury_days))
				s.log_event("remnant_seized", {"days": int(rule.injury_days)}, true)
				s.gain_talent(str(rule.flaw))

## 顿悟 or 生死之间 taken in: a sub-stage's bottleneck breaks at once; before a breakthrough it waits
## (ready) for the attempt. Either may leave a talent behind.
static func _insight(s, id: String) -> Array[String]:
	var texts: Array[String] = []
	var rule: Dictionary = rules(s)[id]
	if s.at_bottleneck():
		_mark(s, id, "spent")
		texts.append(s.log_event("boon_breach", {}))
		texts.append_array(s.breach())
	else:
		_mark(s, id, "ready")
		texts.append(s.log_event("boon_ready", {"boon": id}))
	if rule.has("talent") and s.fortune_roll(id + ":talent") < float(rule.talent_chance):
		var told: String = s.gain_talent(str(rule.talent))
		if not told.is_empty():
			texts.append(told)
	return texts
