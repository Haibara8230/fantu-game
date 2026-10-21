extends RefCounted
## 萧家麒麟子 (宿敌; docs/SIDEQUESTS_DRAFT_20261020.md 五, after the fourth draft's 「宿敌」): 萧凌云, the heir
## of 云溪's new 萧家, meets the player once in each realm. Operates on a Session; his numbers live in
## data/tianji.json `rival`, the story in storylines.json xiao_rival (its current step is the bout due).
## - 潜龙会 (炼气, step `qianlong`): the last round is fought against him (combat.gd begin_tournament).
## - 天南大比 (筑基, step `dabi`): a pill sent the night before may be poisoned (events.json xiao_poison:
##   神识, 叶知微 or a 解毒丹 find it out, which also undoes the rigged draw), every round is a little harder
##   while the draw stays rigged, and the final is fought against him (summit.gd).
## - 天骄榜金丹卷 (金丹, step `bang`): his seat on the scroll, with 萧家's 供奉 in the way (tianji.gd, the
##   prodigy's `intercept` and `bout`).
## - 萧家 (元婴, steps `house` and `fate`): a reckoning at his house (events.json xiao_house, xiao_fate).
## Each bout leaves world flags: xiao_bout<n> once fought, xiao_win<n> or xiao_loss<n>; xiao_spare<n> when
## the player let him keep his face after a win; xiao_ambush stands for a win on the third. Two wins and
## 萧家's shop in 云溪 smiles at the player (xiao_face, tianji.gd `favors`). The end follows from them
## (condition `rival`: "friend" for wins every time with his face spared, "beaten" for no win at all).
const Calendar = preload("res://scripts/core/calendar.gd")
const Storylines = preload("res://scripts/core/storylines.gd")
const BOUTS := 3

static func rules(s) -> Dictionary:
	return s.content.tianji_data.rival

## Whether the story is at a step (the bout due).
static func at_step(s, step_id: String) -> bool:
	return str(Storylines.current_step(s, str(rules(s).story)).get("id", "")) == step_id

static func _flag(s, flag: String) -> void:
	s.world.flags[flag] = true

static func wins(s) -> int:
	var count := 0
	for bout: int in range(1, BOUTS + 1):
		if s.has_flag("xiao_win%d" % bout) or (bout == 3 and s.has_flag("xiao_ambush")):
			count += 1
	return count

static func losses(s) -> int:
	var count := 0
	for bout: int in range(1, BOUTS + 1):
		if s.has_flag("xiao_loss%d" % bout):
			count += 1
	return count

static func spares(s) -> int:
	var count := 0
	for bout: int in range(1, BOUTS + 1):
		if s.has_flag("xiao_spare%d" % bout):
			count += 1
	return count

## The condition `rival`: "friend" (two wins at least, every one of them sparing him, no loss), "beaten"
## (fought and never won), "elder_known" (heard in a teahouse that 萧家 keeps a 供奉 in the way).
static func met(s, value: String) -> bool:
	match value:
		"friend":
			return losses(s) == 0 and wins(s) >= 2 and spares(s) == wins(s)
		"beaten":
			return wins(s) == 0 and losses(s) >= 1
		"elder_known":
			return s.world.get("rumors", {}).has("xiao_elder")
	return false

# --- 潜龙会 -------------------------------------------------------------------------------------------

## Whether the 潜龙会 bout is due: the story at it and 萧凌云 still of 炼气.
static func qianlong_due(s) -> bool:
	return at_step(s, "qianlong") and Calendar.year(int(s.world.day)) < int(rules(s).qianlong.until) and not s.has_flag("xiao_bout1")

## The last round of 潜龙会 against him (combat.gd begin_tournament).
static func begin_qianlong(s, round: int) -> void:
	var bout: Dictionary = rules(s).qianlong
	var foe: Dictionary = s.Summit.foe(s, "萧家嫡子 · 萧凌云", str(rules(s).sect), "male", int(bout.level[0]), int(bout.level[1]), float(bout.power), int(bout.xp))
	foe["npc"] = str(rules(s).person)
	s.battle = {"enemy_id": "cultivator", "hp": int(foe.hp), "turn": 1, "cooldowns": {}, "opponent_sect": str(rules(s).sect), "status": {}, "context": "tournament", "round": round, "npc": str(rules(s).person), "rival": true, "foe": foe, "place": s.Combat._battle_place(s)}
	s.combat_events.clear()
	s.Combat.open_hand(s)
	s.log_event("xiao_qianlong_start", {}, true)

## A round of 潜龙会 ends while the bout is due: a loss anywhere is his day; the last round won is the
## player's (and asks how to end it, events.json xiao_after1). Returns the chronicle text or "".
static func tournament_over(s, won: bool, against_him: bool) -> String:
	if not qianlong_due(s) or (won and not against_him):
		return ""
	_flag(s, "xiao_bout1")
	if not won:
		_flag(s, "xiao_loss1")
		return s.log_event("xiao_qianlong_loss", {}, true)
	_flag(s, "xiao_win1")
	s.pending_event = {"id": "xiao_after1", "day": int(s.world.day)}
	return s.log_event("xiao_qianlong_win", {}, true) + " " + s.Tianji.note(s, str(rules(s).qianlong.note))

# --- 天南大比 -----------------------------------------------------------------------------------------

## Whether the 天南大比 bout is due: the story at it and 萧凌云 still of 筑基.
static func dabi_due(s) -> bool:
	return at_step(s, "dabi") and Calendar.year(int(s.world.day)) < int(rules(s).dabi.until) and not s.has_flag("xiao_bout2")

## Entering a contest (effect `contest`): 天南大比 with the bout due waits on the pill sent the night
## before; anything else begins at once.
static func contest(s, contest_id: String) -> void:
	if contest_id == str(rules(s).dabi.contest) and dabi_due(s):
		s.pending_event = {"id": str(rules(s).dabi.event), "day": int(s.world.day)}
		return
	s.Summit.begin(s, 1, contest_id)

## Past the pill (effect `rival`: "enter"), into the contest.
static func enter(s) -> void:
	s.Summit.begin(s, 1, str(rules(s).dabi.contest))

## The pill swallowed (effect `rival`: "poisoned"): the player comes to the first round drained.
static func poisoned(s) -> String:
	var share := float(rules(s).dabi.poison_percent) / 100.0
	s.player.hp = maxi(1, int(float(s.player.hp) * share))
	s.player.qi = maxi(0, int(float(s.player.qi) * share))
	return s.log_event("xiao_poisoned", {})

## The draw stays rigged unless the poison was found out: every round of the contest a little harder.
static func contest_power(s, contest_id: String) -> float:
	if contest_id == str(rules(s).dabi.contest) and dabi_due(s) and not s.has_flag("xiao_poison_found"):
		return float(rules(s).dabi.rigged)
	return 0.0

## The final's champion while the bout is due: 萧凌云 in 炎烈's place (summit.gd).
static func contest_champion(s, contest_id: String) -> Dictionary:
	if contest_id != str(rules(s).dabi.contest) or not dabi_due(s):
		return {}
	return {"sect": str(rules(s).sect), "name": "萧凌云", "title": "萧家嫡子", "gender": "male", "stage": "决赛"}

## A round of 天南大比 ends while the bout is due: a loss anywhere is his contest (and a seat up for him
## on the 筑基卷); the final won puts the player in his seat and asks how to end it (xiao_after2).
static func contest_over(s, contest_id: String, won: bool, final: bool) -> String:
	if contest_id != str(rules(s).dabi.contest) or not dabi_due(s) or (won and not final):
		return ""
	var scroll_id := str(rules(s).dabi.scroll)
	_flag(s, "xiao_bout2")
	if not won:
		_flag(s, "xiao_loss2")
		s.Tianji.promote(s, scroll_id, str(rules(s).prodigy))
		return s.log_event("xiao_dabi_loss", {}, true)
	_flag(s, "xiao_win2")
	s.Tianji.overtake(s, scroll_id, str(rules(s).prodigy))
	s.pending_event = {"id": "xiao_after2", "day": int(s.world.day)}
	face(s)
	return s.log_event("xiao_dabi_win", {}, true) + " " + s.Tianji.note(s, str(rules(s).dabi.note))

## Two wins over him, and 萧家's shop in 云溪 smiles at the player (tianji.gd `favors`).
static func face(s) -> void:
	if wins(s) >= 2:
		_flag(s, "xiao_face")

## A story's word on the rival (effect `rival`): "enter", "poisoned" or "face".
static func apply(s, what: String) -> String:
	match what:
		"enter":
			enter(s)
		"poisoned":
			return poisoned(s)
		"face":
			face(s)
	return ""
